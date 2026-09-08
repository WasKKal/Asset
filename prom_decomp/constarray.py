"""静态恢复 Prometheus ConstantArray：数组、wrapper偏移、区间反转、自定义base64解码。"""
import math
from .lua_lexer import lex
from .lua_parser import Parser
from .astutil import eval_const, expr_lua

def _parse_toks(toks):
    p=Parser(toks)
    return p

def find_const_array(code, toks=None):
    """找 local NAME = { ... }（首个大字符串数组）。返回 (arrvar, [str...])。"""
    if toks is None: toks=lex(code)
    for i in range(len(toks)-3):
        if toks[i].k=='local' and toks[i+1].k=='NAME' and toks[i+2].k=='OP' and toks[i+2].v=='=' and toks[i+3].k=='OP' and toks[i+3].v=='{':
            name=toks[i+1].v
            # 用parser从 { 开始解析table
            p=Parser(toks[i+3:]+[toks[-1]])
            node=p.parse_table()
            if node[0]=='table' and len(node[1])>10:
                vals=[]
                ok=True
                for k,v in node[1]:
                    if k is not None or v[0]!='str': ok=False;break
                    vals.append(v[1].encode('latin1'))
                if ok: return name,vals,i
    return None,None,None

def find_wrapper(code, arrvar, toks=None):
    """local function NAME(a) return ARR[a ± off] end => (name, offset)。"""
    if toks is None: toks=lex(code)
    for i in range(len(toks)-8):
        if toks[i].k=='local' and toks[i+1].k=='function' and toks[i+2].k=='NAME':
            # 简化：正则在源码层做
            pass
    import re
    pat=re.compile(r'local function (\w+)\(\w+\)\s*return\s+'+re.escape(arrvar)+r'\[\w+([+-])\(([^)]*)\)\]')
    m=pat.search(code)
    if not m:
        pat2=re.compile(r'local function (\w+)\((\w+)\)\s*return\s+'+re.escape(arrvar)+r'\[\2([+-])([^]]*)\]')
        m=pat2.search(code)
        if not m: return None,0
        fname=m.group(1); sign=m.group(3); expr=m.group(4)
        off=_eval_arith(expr)
        return fname,(off if sign=='+' else -off)
    fname=m.group(1); sign=m.group(2); expr=m.group(3)
    off=_eval_arith(expr)
    return fname,(off if sign=='+' else -off)

def _eval_arith(expr):
    try:
        p=Parser(lex(expr))
        e=p.expr(); c=eval_const(e)
        return c[1] if c else 0
    except Exception:
        return 0

def find_reverse_ranges(code, toks=None):
    """for x,y in ipairs({{a,b},...}) do while y[1]<y[2] do ARR[...]交换 end end。
    返回 [[lo,hi],...]（已常量折叠）。"""
    if toks is None: toks=lex(code)
    ranges=[]
    # 找 ipairs( { 起始
    for i in range(len(toks)-2):
        if toks[i].k=='NAME' and toks[i].v=='ipairs' and toks[i+1].k=='OP' and toks[i+1].v=='(' and toks[i+2].k=='OP' and toks[i+2].v=='{':
            p=Parser(toks[i+2:]+[toks[-1]])
            node=p.parse_table()
            if node[0]=='table':
                rr=[]
                ok=True
                for k,v in node[1]:
                    if k is not None or v[0]!='table' or len(v[1])!=2: ok=False;break
                    a=eval_const(v[1][0][1]); b=eval_const(v[1][1][1])
                    if not a or not b: ok=False;break
                    rr.append([int(a[1]),int(b[1])])
                if ok and rr:
                    ranges=rr;break
    return ranges

def apply_reverse(arr, ranges):
    """arr 0-indexed list，ranges 1-indexed 闭区间，原地反转。"""
    a=list(arr)
    for lo,hi in ranges:
        i,j=lo-1,hi-1
        while i<j:
            a[i],a[j]=a[j],a[i]; i+=1;j-=1
    return a

def find_lookup_table(code, toks=None):
    """前言中唯一的 {单字符键->0..63值} 表。返回 char(str)->idx(int)。"""
    if toks is None: toks=lex(code)
    best=None
    for i in range(len(toks)):
        if toks[i].k=='OP' and toks[i].v=='{':
            try:
                p=Parser(toks[i:]+[toks[-1]])
                node=p.parse_table()
            except Exception:
                continue
            if node[0]!='table': continue
            mp={};ok=True;cnt=0
            for k,v in node[1]:
                if k is None or k[0]!='str' or len(k[1])!=1: ok=False;break
                c=eval_const(v)
                if not c or c[0]!='num': ok=False;break
                mp[k[1]]=int(c[1]);cnt+=1
            if ok and cnt>=60:
                vals=set(mp.values())
                if vals>=set(range(64)):
                    best=mp
    return best

def b64_decode(s, char2val):
    """严格按 Prometheus decode 逻辑（自定义字母表）。s: bytes，返回 bytes。"""
    out=bytearray(); value=0;count=0;length=len(s)
    for index in range(length):
        ch=chr(s[index])
        code=char2val.get(ch)
        if code is not None:
            value=value+code*(64**(3-count));count+=1
            if count==4:
                count=0
                c1=math.floor(value/65536)
                c2=math.floor((value%65536)/256)
                c3=value%256
                out+=bytes([c1,c2,c3]);value=0
        elif ch=='=':
            out+=bytes([math.floor(value/65536)])
            nextch=chr(s[index+1]) if index+1<length else ''
            if index>=length-1 or nextch!='=':
                out+=bytes([math.floor((value%65536)/256)])
            break
    return bytes(out)

def recover_constants(code):
    """完整恢复常量数组。返回 dict(arrvar, wrapper, offset, final: 1-indexed dict idx->bytes)。"""
    toks=lex(code)
    arrvar,raw,_=find_const_array(code,toks)
    if not raw: raise RuntimeError("未找到常量数组")
    wname,off=find_wrapper(code,arrvar,toks)
    ranges=find_reverse_ranges(code,toks)
    rev=apply_reverse(raw,ranges)
    lookup=find_lookup_table(code,toks)
    if not lookup: raise RuntimeError("未找到base64字母表")
    final={}
    for i,elem in enumerate(rev,1):
        try: final[i]=b64_decode(elem,lookup)
        except Exception: final[i]=elem
    return {'arrvar':arrvar,'wrapper':wname,'offset':off,'final':final,'raw_count':len(raw)}

def _bytes_node(b):
    try: return ('str',b.decode('utf-8'))
    except Exception: return ('str',b.decode('latin1'))

def make_inliner(ci):
    """返回 (e)->e，把 wrapper(num) / arrvar[num] 内联为常量字面量。"""
    from .astutil import walk, eval_const
    final=ci['final']; off=ci['offset']; w=ci['wrapper']; av=ci['arrvar']
    def _idx(e):
        c=eval_const(e)
        if c and c[0]=='num':
            v=c[1]; return int(v) if float(v).is_integer() else v
        return None
    def fn(e):
        if e[0]=='call' and e[1]==('var',w) and len(e[2])==1:
            idx=_idx(e[2][0])
            if idx is not None and idx+off in final:
                return _bytes_node(final[idx+off])
        if e[0]=='index' and e[1]==('var',av):
            idx=_idx(e[2])
            if idx is not None and idx in final:
                return _bytes_node(final[idx])
        return e
    return lambda e: walk(e,fn)
