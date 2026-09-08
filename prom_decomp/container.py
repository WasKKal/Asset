"""
解析 Prometheus Vmify 容器作用域函数，建立 变量名 -> 语义角色 映射。

结构:
  return(function(外部7项[乱序], 内部函数表[乱序])
    <内部多赋值: 名字... = containerFunc / closure工厂 / alloc / free / 表 / 0 ...>
    return createVarargClosure(startId,{})(unpack(arg))
  end)(env, unpack, newproxy, setmetatable, getmetatable, select, {...})
"""
from .lua_lexer import lex
from .lua_parser import Parser

def _func_body_text(toks, rng):
    if not rng: return []
    s,e=rng
    return toks[s:e]

def _body_has(toks, rng, pred):
    for t in _func_body_text(toks, rng):
        if pred(t): return True
    return False

def _inner_func_params(toks, rng):
    """closure工厂体: local x=proxy(p2) local f=function(INNER) ... end; 返回 INNER 参数列表token名。"""
    s,e=rng; depth=0; i=s
    while i<e:
        if toks[i].k=='function':
            # 其后 ( params )
            j=i+1
            if toks[j].k=='OP' and toks[j].v=='(':
                j+=1; ps=[]
                while j<e and not (toks[j].k=='OP' and toks[j].v==')'):
                    if toks[j].k=='NAME' or toks[j].k=='...' or (toks[j].k=='OP' and toks[j].v=='...'):
                        ps.append('...' if (toks[j].k=='...' or (toks[j].k=='OP' and toks[j].v=='...')) else toks[j].v)
                    j+=1
                return ps
        i+=1
    return None

def analyze_container(code):
    toks=lex(code)
    # 定位第二个 return(function
    idxs=[]
    for i in range(len(toks)-2):
        if toks[i].k=='return' and toks[i+1].k=='OP' and toks[i+1].v=='(' and toks[i+2].k=='function':
            idxs.append(i)
    if len(idxs)<2:
        # 退化：找 return(function 至少一个
        if not idxs: raise RuntimeError("未找到容器函数")
        ci=idxs[0]
    else:
        ci=idxs[1]
    p=Parser(toks)
    p.i=ci
    p.next()  # return
    p.next()  # (
    p.next()  # function
    p.expect('(')
    params=[]
    if not p.atOp(')'):
        params.append(p.next().v)
        while p.atOp(','):
            p.next(); params.append(p.next().v)
    p.expect(')')
    # 第一个语句：内部多赋值
    stmt=p.one_statement()
    assert stmt[0]=='assign', f"容器首语句应为多赋值, 得到 {stmt[0]}"
    lhs=[e[1] for e in stmt[1]]
    rhs=stmt[2]
    role={}
    container_name=None; container_params=None; container_range=None
    closure_names={}   # 名 -> 参数个数(0=vararg)
    def tkset(rng): return [t.k for t in _func_body_text(toks,rng)]
    def has_nil(rng): return _body_has(toks,rng,lambda t:t.k=='nil')
    def has_kw(rng,k): return _body_has(toks,rng,lambda t:t.k==k)
    from .astutil import eval_const
    for name,val in zip(lhs,rhs):
        c=eval_const(val)
        if c and c[0]=='num' and float(c[1])==0:
            role[name]='curupid'
        elif val[0]=='table' and len(val[1])==0:
            role[name]='emptytable'
        elif val[0]=='func':
            fparams=val[1]; rng=val[2]
            if len(fparams)==0:
                role[name]='alloc'
            elif len(fparams)==1:
                if has_kw(rng,'for'): role[name]='proxy'
                elif has_kw(rng,'while'): role[name]='gc'
                elif has_nil(rng): role[name]='free'
                else: role[name]='onefunc'
            elif len(fparams)==4 and has_kw(rng,'while'):
                role[name]='container'; container_name=name
                container_params=fparams; container_range=rng
            elif len(fparams)==2:
                inner=_inner_func_params(toks,rng)
                if inner is None:
                    role[name]='closure?'
                elif '...' in inner:
                    role[name]='vclosure'
                else:
                    role[name]=f'closure{len(inner)}'
                    closure_names[name]=len(inner)
            else:
                role[name]='otherfunc'
        else:
            role[name]='other'
    # 容器体内 return 语句: return vclosure(start,{})(unpack(retvar))
    ret=p.one_statement()
    # ret = ('return',[ call(call(vclosure,[startid,{}]),[call(unpack,[retvar])]) ])
    retvar=None; startid=None; vclosure_name=None; unpack_name=None
    try:
        outer_call=ret[1][0]                 # inner(start,{})(unpack(retvar))
        inner_call=outer_call[1]             # ('call', vclosure, [start,{}])
        vclosure_name=inner_call[1][1]
        start_expr=inner_call[2][0]
        unpack_call=outer_call[2][0]         # ('call', unpack, [retvar])
        unpack_name=unpack_call[1][1]
        retvar=unpack_call[2][0][1]
        c=eval_const(start_expr)
        if c and c[0]=='num':
            v=float(c[1]); startid=int(v) if v.is_integer() else v
    except Exception:
        pass
    # 容器 end ) ( 外部实参 )
    p.expect('end'); p.expect(')'); p.expect('(')
    ext=[]
    if not p.atOp(')'):
        ext.append(p.expr(0))
        while p.atOp(','):
            p.next(); ext.append(p.expr(0))
    p.expect(')')
    # 识别外部7项角色
    ext_role={}
    def names_in(e,acc):
        if isinstance(e,tuple):
            if e[0]=='var': acc.append(e[1])
            elif e[0]=='index' and e[1][0]=='var': acc.append(e[1][1]); names_in(e[2],acc)
            else:
                for x in e[1:]:
                    if isinstance(x,tuple): names_in(x,acc)
                    elif isinstance(x,list):
                        for y in x:
                            if isinstance(y,tuple): names_in(y,acc)
    for pname,e in zip(params[:len(ext)],ext):
        ns=[]; names_in(e,ns)
        txt=' '.join(ns)
        if 'getfenv' in txt or '_ENV' in txt: ext_role[pname]='env'
        elif 'unpack' in txt: ext_role[pname]='unpack'
        elif 'newproxy' in ns: ext_role[pname]='newproxy'
        elif 'setmetatable' in ns: ext_role[pname]='setmeta'
        elif 'getmetatable' in ns: ext_role[pname]='getmeta'
        elif 'select' in ns: ext_role[pname]='select'
        elif e[0]=='table': ext_role[pname]='arg'
        else: ext_role[pname]='ext?'
    # upvaluesTable / refcount 表：从 free 函数体模式 R[x],U[x]=nil,nil 提取
    upval_table=None; refcount_table=None
    def _op(t,i,v): return i<len(t) and t[i].k=='OP' and t[i].v==v
    def _nm(t,i): return i<len(t) and t[i].k=='NAME'
    for name,val in zip(lhs,rhs):
        if val[0]=='func' and role.get(name)=='free':
            bt=_func_body_text(toks,val[2])
            for i in range(len(bt)-10):
                if (_nm(bt,i) and _op(bt,i+1,'[') and _nm(bt,i+2) and _op(bt,i+3,']')
                    and _op(bt,i+4,',') and _nm(bt,i+5) and _op(bt,i+6,'[') and _nm(bt,i+7)
                    and _op(bt,i+8,']') and _op(bt,i+9,'=') and bt[i+10].k=='nil'):
                    refcount_table=bt[i].v; upval_table=bt[i+5].v; break
            break
    return {
        'params':params,'role':role,'ext_role':ext_role,
        'container':container_name,'container_params':container_params,
        'posvar':container_params[0] if container_params else None,
        'argsvar':container_params[1] if container_params else None,
        'curupvar':container_params[2] if container_params else None,
        'gcvar':container_params[3] if container_params else None,
        'closures':closure_names,'vclosure':[n for n,r in role.items() if r=='vclosure'],
        'upval_table':upval_table,'refcount':refcount_table,
        'returnvar':retvar,'unpack':unpack_name,'startid':startid,
        'lhs':lhs,'rhs':rhs,
    }
