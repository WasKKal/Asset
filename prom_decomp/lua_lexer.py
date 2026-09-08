"""
Lua 5.1 / Luau 精简词法分析器，专门用于解析 Prometheus Vmify 生成的规整代码。
产出 token 流：(kind, value, pos)
kind: NAME NUMBER STRING OP EOF
"""
import re

class Tok:
    __slots__ = ('k','v','p')
    def __init__(self,k,v,p): self.k,self.v,self.p=k,v,p
    def __repr__(self): return f"{self.k}:{self.v!r}"

KEYWORDS = {
 'and','break','do','else','elseif','end','false','for','function','if','in',
 'local','nil','not','or','repeat','return','then','true','until','while','continue'
}

# 多字符运算符优先
_OPS = ['...','..','==','~=','<=','>=','::','->',
        '+','-','*','/','%','^','#','(',')','{','}','[',']',';',':',',','.','=','<','>']

class LexError(Exception): pass

def _read_long_bracket(s, i):
    """在 s[i] 处尝试读取长括号 [=*[ ，返回 (等级, 内容起始) 或 None"""
    if s[i] != '[': return None
    j = i+1
    eq = 0
    while j < len(s) and s[j] == '=':
        eq += 1; j += 1
    if j < len(s) and s[j] == '[':
        return eq, j+1
    return None

def _match_long_close(s, i, eq):
    if s[i] != ']': return False
    j = i+1
    cnt = 0
    while j < len(s) and s[j]=='=' and cnt<eq:
        cnt+=1; j+=1
    return cnt==eq and j<len(s) and s[j]==']'

def lex(s):
    toks=[]
    i=0; n=len(s)
    while i<n:
        c=s[i]
        # 空白
        if c in ' \t\r\n':
            i+=1; continue
        # 注释
        if c=='-' and i+1<n and s[i+1]=='-':
            # 长注释?
            lb = _read_long_bracket(s,i+2) if i+2<n else None
            if lb:
                eq,start = lb
                close = ']'+'='*eq+']'
                k = s.find(close,start)
                i = (k+len(close)) if k>=0 else n
                continue
            # 行注释
            j=s.find('\n',i)
            i = n if j<0 else j
            continue
        # 数字
        if c.isdigit() or (c=='.' and i+1<n and s[i+1].isdigit()):
            m=re.match(r'0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?', s[i:])
            num=m.group(0)
            toks.append(Tok('NUMBER',num,i)); i+=len(num); continue
        # 标识符/关键字
        if c.isalpha() or c=='_':
            m=re.match(r'[A-Za-z_][A-Za-z0-9_]*', s[i:])
            w=m.group(0)
            kind = w if w in KEYWORDS else 'NAME'
            toks.append(Tok(kind,w,i)); i+=len(w); continue
        # 字符串
        if c=='"' or c=="'":
            quote=c; j=i+1; buf=[]
            while j<n:
                ch=s[j]
                if ch==quote:
                    j+=1; break
                if ch=='\\':
                    nx=s[j+1] if j+1<n else ''
                    if nx.isdigit():
                        m=re.match(r'\d{1,3}', s[j+1:])
                        val=int(m.group(0)); buf.append(chr(val)); j+=1+len(m.group(0)); continue
                    esc={'n':'\n','t':'\t','r':'\r','a':'\a','b':'\b','f':'\f','v':'\v',
                         '\\':'\\','"':'"',"'":"'",'\n':'\n'}
                    buf.append(esc.get(nx,nx)); j+=2; continue
                buf.append(ch); j+=1
            toks.append(Tok('STRING',''.join(buf),i)); i=j; continue
        # 长字符串
        lb=_read_long_bracket(s,i)
        if lb:
            eq,start=lb
            close=']'+'='*eq+']'
            k=s.find(close,start)
            content=s[start:k] if k>=0 else ''
            toks.append(Tok('STRING',content,i))
            i=(k+len(close)) if k>=0 else n
            continue
        # 运算符
        for op in _OPS:
            if s.startswith(op,i):
                toks.append(Tok('OP',op,i)); i+=len(op); break
        else:
            raise LexError(f"无法识别字符 {c!r} @ {i}: ...{s[max(0,i-20):i+20]}...")
    toks.append(Tok('EOF',None,n))
    return toks
