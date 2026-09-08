"""块内数据流：寄存器拷贝/常量传播，折叠临时寄存器，还原表达式。"""
from .astutil import substitute, used_vars, eval_const, expr_lua, truthy

def stat_rw(stat):
    reads=set(); writes=set()
    k=stat[0]
    if k=='assign':
        lhs=stat[1]; rhs=stat[2]
        for L in lhs:
            if L[0]=='var': writes.add(L[1])
            else: used_vars(L,reads)
        for R in rhs: used_vars(R,reads)
    elif k=='local':
        for n in stat[1]: writes.add(n)
        for R in stat[2]: used_vars(R,reads)
    elif k=='return':
        for R in stat[1]: used_vars(R,reads)
    elif k=='callstmt':
        used_vars(stat[1],reads)
    return reads,writes

def expr_has_call(e):
    if not isinstance(e,tuple): return False
    if e[0] in ('call','selfcall'): return True
    if e[0]=='bin': return expr_has_call(e[2]) or expr_has_call(e[3])
    if e[0]=='un': return expr_has_call(e[2])
    if e[0]=='index': return expr_has_call(e[1]) or expr_has_call(e[2])
    if e[0]=='table': return any(expr_has_call(v) or (kk and expr_has_call(kk)) for kk,v in e[1])
    if e[0]=='call': return True
    return False

def first_roles(stats, posvar, retvar):
    """返回 name-> 'in'(块输入/变量) 或 'temp'(块内临时)。"""
    role={}
    for st in stats:
        r,w=stat_rw(st)
        for name in r:
            if name not in role: role[name]='in'
        for name in w:
            if name not in role: role[name]='temp'
    return role

def _alias_nonfinal_pos(stats, posvar, alias='_pt'):
    """块内 posvar 会被临时借用（计算），仅最后一次/两次赋值是真正跳转
    （for 循环用 D=X; D=D or final 两条实现分支）。其余写重命名为 alias。"""
    pos_writes=[i for i,st in enumerate(stats)
                if st[0]=='assign' and len(st[1])==1 and st[1][0]==('var',posvar)]
    if not pos_writes: return stats
    keep_last=1
    last_i=pos_writes[-1]
    last_rhs=stats[last_i][2][0]
    # D = D or X 自引用 or，需要保留前一条
    if isinstance(last_rhs,tuple) and last_rhs[0]=='bin' and last_rhs[1]=='or' and last_rhs[2]==('var',posvar):
        keep_last=2
    keep=set(pos_writes[-keep_last:])
    out=[]
    for i,st in enumerate(stats):
        if i in keep or st[0]!='assign':
            out.append(st); continue
        new_lhs=[]
        for L in st[1]:
            new_lhs.append(('var',alias) if L==('var',posvar) else L)
        def ren(e):
            if not isinstance(e,tuple): return e
            if e==('var',posvar): return ('var',alias)
            if e[0]=='bin': return ('bin',e[1],ren(e[2]),ren(e[3]))
            if e[0]=='un': return ('un',e[1],ren(e[2]))
            if e[0]=='index': return ('index',ren(e[1]),ren(e[2]))
            if e[0]=='call': return ('call',ren(e[1]),[ren(a) for a in e[2]])
            if e[0]=='selfcall': return ('selfcall',ren(e[1]),e[2],[ren(a) for a in e[3]])
            if e[0]=='table': return ('table',[(ren(k) if k else None,ren(v)) for k,v in e[1]])
            return e
        new_rhs=[ren(r) for r in st[2]]
        out.append(('assign',new_lhs,new_rhs))
    return out

def simplify_block(stats, posvar='D', retvar=None, decrypt=None, special_globals=None, inliner=None):
    """decrypt: callable(enc_bytes,seed)->plain_bytes 或 dict。
    inliner: (e)->e 常量数组内联函数。D/B 正常折叠，末尾跳转由 extract_terminator 识别。"""
    special_globals = special_globals or set()
    stats=_alias_nonfinal_pos(stats,posvar)
    role=first_roles(stats,posvar,retvar)
    known={}
    out=[]
    def sub(e):
        if inliner is not None:
            e=inliner(e)
        return substitute(e,known)
    for st in stats:
        k=st[0]
        if k=='assign':
            lhs=st[1]; rhs=[sub(r) for r in st[2]]
            lhs=[sub(L) if L[0]!='var' else L for L in lhs]
            if len(lhs)==1 and lhs[0][0]=='var':
                name=lhs[0][1]; val=rhs[0]
                if name==posvar:
                    out.append(('setvar',name,val)); known[name]=None; continue
                if role.get(name)=='temp' and name not in special_globals:
                    plain=try_decrypt(val,decrypt)
                    if plain is not None:
                        known[name]=('str',plain); continue
                    # 含副作用（调用）：保留为 local 绑定，但不可内联复制（否则重复调用）
                    if expr_has_call(val):
                        out.append(('let',name,val)); known[name]=None; continue
                    known[name]=val
                    continue
                else:
                    # 源码变量寄存器：保留名字，不用块内旧值错误内联
                    out.append(('setvar',name,val)); known[name]=None; continue
            out.append(('assign',lhs,rhs)); continue
        if k=='local':
            rhs=[sub(r) for r in st[2]]
            out.append(('local',st[1],rhs)); continue
        if k=='return':
            out.append(('return',[sub(r) for r in st[1]])); continue
        if k=='callstmt':
            out.append(('callstmt',sub(st[1]))); continue
        out.append(st)
    return out,role

def extract_terminator(out, posvar='D'):
    """提取块末尾控制流。支持 for 循环的双赋值模式 D=X; D=D or finalId。"""
    pos_idx=[i for i,s in enumerate(out)
             if (s[0]=='setvar' and s[1]==posvar) or (s[0]=='let' and s[1]==posvar)]
    if not pos_idx:
        return out,None
    last=pos_idx[-1]
    termexpr=out[last][2]
    # for 模式：最后是 D or num，且上一条写 D 给出 X => 合并 (X or num)
    if termexpr[0]=='bin' and termexpr[1]=='or' and termexpr[2]==('var',posvar):
        if len(pos_idx)>=2:
            prev=pos_idx[-2]
            x=out[prev][2]
            termexpr=('bin','or',x,termexpr[3])
            out=out[:prev]+out[prev+1:last]+out[last+1:]
        else:
            out=out[:last]+out[last+1:]
    else:
        out=out[:last]+out[last+1:]
    return out,classify_terminator(termexpr)

def classify_terminator(e):
    # D = 数字
    if e[0]=='num':
        return ('jmp', int(e[1]) if float(e[1]).is_integer() else e[1])
    # D = cond and A or B
    if e[0]=='bin' and e[1]=='or':
        right=e[3]
        if e[2][0]=='bin' and e[2][1]=='and':
            cond=e[2][2]; t=e[2][3]
            def asid(x):
                return int(x[1]) if x[0]=='num' and float(x[1]).is_integer() else None
            a,b=asid(t),asid(right)
            if a is not None and b is not None:
                return ('branch',cond,a,b)
    # D = env[随机字符串]  => 访问不存在全局 => nil 退出
    if e[0]=='index' and e[2][0]=='str':
        return ('exit',e)
    if e[0]=='index':
        return ('exit',e)
    return ('dynamic',e)

def try_decrypt(e,decrypt):
    """识别 DECRYPT("enc",seed) 调用并返回明文字符串。decrypt 为 callable 或 dict。"""
    if not decrypt or not isinstance(e,tuple): return None
    if e[0]=='call' and len(e[2])==2:
        a,b=e[2]
        if a[0]=='str' and b[0]=='num':
            enc=a[1].encode('latin1')
            seed=int(b[1]) if float(b[1]).is_integer() else b[1]
            try:
                if callable(decrypt):
                    plain=decrypt(enc,seed)
                else:
                    plain=decrypt.get((a[1],seed))
                if plain is None: return None
                if isinstance(plain,bytes):
                    text=plain.decode('utf-8')  # 非法UTF-8说明并非真正的加密串
                else:
                    text=plain
                # 真正的源码字符串均为可打印文本（允许常见空白）
                if all(c.isprintable() or c in '\n\r\t' for c in text):
                    return text
                return None
            except Exception:
                return None
    return None
