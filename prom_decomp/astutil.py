"""AST 工具：常量求值、寄存器替换、表达式转字符串。"""
import math

# ---------- 常量折叠/求值 ----------
def _num(x):
    return isinstance(x,tuple) and x[0]=='num'

def eval_const(e):
    """对纯常量表达式求值，返回 ('num',v)；无法求值返回 None。"""
    if not isinstance(e,tuple): return None
    k=e[0]
    if k=='num': return e
    if k=='un' and e[1]=='-':
        v=eval_const(e[2])
        if v: return ('num', -v[1])
    if k=='un' and e[1]=='not':
        v=eval_const(e[2])
        if v is not None: return ('true',) if not truthy(v) else ('false',)
    if k=='bin':
        op=e[1]; l=eval_const(e[2]); r=eval_const(e[3])
        if l is not None and r is not None and (l[0]=='num') and (r[0]=='num'):
            a,b=l[1],r[1]
            try:
                if op=='+': return ('num',a+b)
                if op=='-': return ('num',a-b)
                if op=='*': return ('num',a*b)
                if op=='/': return ('num',a/b)
                if op=='%': return ('num',a%b)
                if op=='^': return ('num',a**b)
            except Exception: return None
            if op=='==': return ('true',) if a==b else ('false',)
            if op=='~=': return ('true',) if a!=b else ('false',)
            if op=='<': return ('true',) if a<b else ('false',)
            if op=='>': return ('true',) if a>b else ('false',)
            if op=='<=': return ('true',) if a<=b else ('false',)
            if op=='>=': return ('true',) if a>=b else ('false',)
    return None

def truthy(node):
    if node[0] in ('false','nil'): return False
    if node[0]=='true': return True
    if node[0]=='num': return node[1]!=0
    if node[0]=='str': return len(node[1])>0
    return True

# ---------- 变量收集/替换 ----------
def walk(e, fn):
    if not isinstance(e,tuple): return e
    k=e[0]
    if k in ('num','str') : return fn(e)
    if k in ('nil','true','false','vararg'): return fn(e)
    if k=='var': return fn(e)
    if k=='un': return fn(('un',e[1],walk(e[2],fn)))
    if k=='bin': return fn(('bin',e[1],walk(e[2],fn),walk(e[3],fn)))
    if k=='index': return fn(('index',walk(e[1],fn),walk(e[2],fn)))
    if k=='call': return fn(('call',walk(e[1],fn),[walk(a,fn) for a in e[2]]))
    if k=='selfcall': return fn(('selfcall',walk(e[1],fn),e[2],[walk(a,fn) for a in e[3]]))
    if k=='table': return fn(('table',[(walk(kk,fn) if kk else None,walk(vv,fn)) for kk,vv in e[1]]))
    if k=='func': return fn(e)
    return fn(e)

def used_vars(e, acc=None):
    if acc is None: acc=set()
    def fn(n):
        if n[0]=='var': acc.add(n[1])
        return n
    walk(e,fn); return acc

def substitute(e, mapping):
    """mapping: varname -> AST 表达式。深度替换并做常量折叠（bottom-up）。"""
    def fn(n):
        if n[0]=='var' and n[1] in mapping and mapping[n[1]] is not None:
            n=mapping[n[1]]
        c=eval_const(n)   # 每个节点都尝试折叠，使深层算术/负号常量收敛
        return c if c is not None else n
    return walk(e,fn)

# ---------- 表达式转 Lua 字符串 ----------
_PRI={'or':1,'and':2,('<','>','<=','>=','~=','=='):3,'..':5,
      '+':6,'-':6,('*','/','%'):7,'^':9}
def pri(op):
    for k,v in _PRI.items():
        if op==k or (isinstance(k,tuple) and op in k): return v
    return 10

def lua_str_escape(s):
    out='"'
    for ch in s:
        o=ord(ch)
        if ch=='"': out+='\\"'
        elif ch=='\\': out+='\\\\'
        elif ch=='\n': out+='\\n'
        elif ch=='\r': out+='\\r'
        elif ch=='\t': out+='\\t'
        elif 32<=o<127: out+=ch
        else: out+='\\%03d'%o
    return out+'"'

def expr_lua(e,parent_pri=0,side=0):
    k=e[0]
    if k=='num':
        v=e[1]
        if isinstance(v,float) and v.is_integer(): return str(int(v))
        return str(v)
    if k=='str': return lua_str_escape(e[1])
    if k=='nil': return 'nil'
    if k=='true': return 'true'
    if k=='false': return 'false'
    if k=='vararg': return '...'
    if k=='var': return e[1]
    if k=='un':
        s=e[1]+expr_lua(e[2],8)
        return s
    if k=='index':
        base=expr_lua(e[1],10)
        key=e[2]
        if key[0]=='str' and key[1].isidentifier():
            return f"{base}.{key[1]}"
        return f"{base}[{expr_lua(key)}]"
    if k=='bin':
        op=e[1]; my=pri(op)
        s=f"{expr_lua(e[2],my,0)} {op} {expr_lua(e[3],my,1)}"
        if my<parent_pri: return f"({s})"
        return s
    if k=='call':
        return f"{expr_lua(e[1],10)}({', '.join(expr_lua(a) for a in e[2])})"
    if k=='selfcall':
        return f"{expr_lua(e[1],10)}:{e[2]}({', '.join(expr_lua(a) for a in e[3])})"
    if k=='table':
        parts=[]
        for kk,vv in e[1]:
            parts.append(f"[{expr_lua(kk)}]={expr_lua(vv)}" if kk else expr_lua(vv))
        return "{"+", ".join(parts)+"}"
    if k=='func': return "function(...) --[[func]] end"
    return str(e)
