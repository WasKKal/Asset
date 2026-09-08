"""短路表达式折叠：把 and/or/三元表达式编译出的纯值选择菱形合并回表达式。

形态（寄存器折叠后）:
  and:  h: ... R=L        branch(L, T, F)
        T: R=R0 ; jmp J    F: (空) ; jmp J     => R = L and R0 ; h jmp J
  or :  h: ... R=L        branch(L, T, F)
        T: (空) ; jmp J    F: R=R0 ; jmp J     => R = L or R0
  三元: h: branch(C,T,F)  T:R=A;jmp J  F:R=B;jmp J => R=C and A or B
分支路径必须无副作用（无 call、只写同一个结果寄存器）。
"""
from .astutil import walk

def _has_call(e):
    found=[False]
    def w(x):
        if isinstance(x,tuple):
            if x[0] in('call','selfcall','mkclosure','alloc'): found[0]=True
            for p in x[1:]:
                if isinstance(p,tuple): w(p)
                elif isinstance(p,list):
                    for y in p:
                        if isinstance(y,tuple): w(y)
                        elif isinstance(y,list):
                            for z in y:
                                if isinstance(z,tuple): w(z)
    w(e); return found[0]

def _pure_assign_block(b, jmp_target):
    """块是否为纯赋值块：term=jmp jmp_target，body 只写单一寄存器（无副作用）。
    返回 (寄存器名, 赋值表达式) 或 (None,None)=空块，否则 None（不纯）。"""
    t=b['term']
    if not (t and t[0]=='jmp' and t[1]==jmp_target): return 'IMPURE'
    writes=[]
    for s in b['body']:
        if s[0]=='let':
            if _has_call(s[2]): return 'IMPURE'
            writes.append((s[1],s[2]))
        elif s[0]=='setvar':
            if _has_call(s[2]): return 'IMPURE'
            writes.append((s[1],s[2]))
        elif s[0]=='assign':
            for r in s[2]:
                if _has_call(r): return 'IMPURE'
            for l,r in zip(s[1],s[2]):
                if l[0]=='var': writes.append((l[1],r))
                else: return 'IMPURE'
        else:
            return 'IMPURE'
    if not writes: return (None,None)
    names={w[0] for w in writes}
    if len(names)!=1: return 'IMPURE'
    # 多次写同一寄存器，取最后一次赋值
    name=writes[-1][0]
    # 若中途读了该寄存器再写（R=f(R)），保留最后表达式即可（and/or 只赋一次）
    return (name, writes[-1][1])

def fold_short_circuits(blocks, postdom, loop_headers, maxround=10000):
    """就地折叠。postdom: bid->ipostdom。返回折叠次数。"""
    folded=0
    for _ in range(maxround):
        did=False
        for h in list(blocks):
            if h in loop_headers: continue
            b=blocks[h]; t=b['term']
            if not (t and t[0]=='branch'): continue
            cond,T,F=t[1],t[2],t[3]
            if T not in blocks or F not in blocks: continue
            join=postdom.get(h)
            if join is None or join not in blocks: continue
            tP=_pure_assign_block(blocks[T],join)
            fP=_pure_assign_block(blocks[F],join)
            if tP=='IMPURE' or fP=='IMPURE': continue
            # 三种形态
            newexpr=None; resreg=None
            if tP[0] is None and fP[0] is None:
                continue  # 两空，无值选择，可能是空if，结构化阶段处理
            if tP[0] is not None and fP[0] is None:
                # and: T赋值,F空
                resreg=rhs=tP
                newexpr=('bin','and',cond,tP[1]); resreg=tP[0]
            elif fP[0] is not None and tP[0] is None:
                # or: T空,F赋值
                newexpr=('bin','or',cond,fP[1]); resreg=fP[0]
            elif tP[0]==fP[0]:
                # 三元
                resreg=tP[0]
                newexpr=('bin','or',('bin','and',cond,tP[1]),fP[1])
            else:
                continue
            # 移除 header 中已有的对 resreg 赋值（and/or 的 R=L），统一写一条
            newbody=[]
            for s in b['body']:
                iswrite=(s[0] in('let','setvar') and s[1]==resreg) or \
                        (s[0]=='assign' and len(s[1])==1 and s[1][0]==('var',resreg))
                if not iswrite: newbody.append(s)
            newbody.append(('let',resreg,newexpr))
            b['body']=newbody
            b['term']=('jmp',join)
            # 删除分支块（标记，稍后统一清理）
            blocks.pop(T,None); blocks.pop(F,None)
            folded+=1; did=True
        if not did: break
    return folded

def _already_let(b,name):
    for s in b['body']:
        if s[0] in('let','setvar') and s[1]==name: return True
        if s[0]=='assign' and any(x==('var',name) for x in s[1]): return True
    return False
