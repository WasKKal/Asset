"""语义层重写：在折叠后的表达式 AST 上还原 Prometheus 运行时结构。"""

def make_sema(cont):
    env_names={n for n,r in cont['ext_role'].items() if r=='env'}
    upval_table=cont['upval_table']
    alloc=[n for n,r in cont['role'].items() if r=='alloc']
    free=[n for n,r in cont['role'].items() if r=='free']
    closures=dict(cont['closures'])           # name -> narg
    vclosures=set(cont['vclosure'])
    curup=cont['curupvar']

    def rw(e):
        if not isinstance(e,tuple): return e
        k=e[0]
        if k=='index':
            base=rw(e[1]); key=rw(e[2])
            # env["name"] / env.name -> 全局变量 name
            if base[0]=='var' and base[1] in env_names and key[0]=='str':
                return ('var',key[1])
            return ('index',base,key)
        if k=='call':
            fn=rw(e[1]); args=[rw(a) for a in e[2]]
            # 闭包创建 closureX(id,{upvals})
            if fn[0]=='var':
                nm=fn[1]
                if nm in closures and len(args)==2 and args[1][0]=='table':
                    cid=_const_id(args[0])
                    if cid is not None:
                        return ('mkclosure',cid,args[1],closures[nm],False)
                if nm in vclosures and len(args)==2 and args[1][0]=='table':
                    cid=_const_id(args[0])
                    if cid is not None:
                        return ('mkclosure',cid,args[1],-1,True)
                if nm in alloc and len(args)==0:
                    return ('alloc',)
            return ('call',fn,args)
        if k=='bin': return ('bin',e[1],rw(e[2]),rw(e[3]))
        if k=='un': return ('un',e[1],rw(e[2]))
        if k=='table': return ('table',[(rw(a) if a is None else (rw(a[0]),rw(a[1])) if isinstance(a,tuple) else a) for a in e[1]])
        if k=='selfcall':
            return ('selfcall',rw(e[1]),e[2],[rw(a) for a in e[3]])
        if k=='func': return e
        return e
    return rw

def _const_id(e):
    from .astutil import eval_const
    c=eval_const(e)
    if c and c[0]=='num':
        v=float(c[1]); return int(v) if v.is_integer() else v
    return None

def rewrite_statement(s, rw):
    k=s[0]
    if k=='let': return ('let',s[1],rw(s[2]))
    if k=='setvar': return ('setvar',s[1],rw(s[2]))
    if k=='assign': return ('assign',[rw(x) for x in s[1]],[rw(x) for x in s[2]])
    if k=='callstmt': return ('callstmt',rw(s[1]))
    if k=='return': return ('return',[rw(x) for x in s[1]])
    if k=='local': return ('local',s[1],[rw(x) for x in s[2]])
    return s

def rewrite_block(body, cont):
    rw=make_sema(cont)
    return [rewrite_statement(s,rw) for s in body]
