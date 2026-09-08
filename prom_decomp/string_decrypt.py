"""Prometheus EncryptStrings LCG 解密（严格按 Lua double 运算顺序）。"""
import math

M45=35184372088832.0   # 2^45
M32=4294967296.0       # 2^32
M16=65536.0

class LcgDecryptor:
    def __init__(self,mul45,add45,mul8,key8):
        self.mul45=float(mul45); self.add45=float(add45)
        self.mul8=float(mul8); self.key8=key8&255
    def _set_seed(self,seed):
        self.s45=float(seed)%M45
        self.s8=float(seed)%255.0+2.0
        self.prev=[]
    def _rand32(self):
        self.s45=(self.s45*self.mul45+self.add45)%M45
        while True:
            self.s8=self.s8*self.mul8%257.0
            if self.s8!=1.0: break
        r=self.s8%32.0
        shift=13.0-(self.s8-r)/32.0
        n=math.floor(self.s45/2.0**shift)%M32/2.0**r
        return math.floor(n%1.0*M32)+math.floor(n)
    def _next_byte(self):
        if not self.prev:
            rnd=self._rand32()
            low=rnd%M16
            high=(rnd-low)/M16
            b1=low%256.0
            b2=(low-b1)/256.0
            b3=high%256.0
            b4=(high-b3)/256.0
            # table.remove 取末尾 => b4,b3,b2,b1
            self.prev=[b1,b2,b3,b4]
        return self.prev.pop()
    def decrypt(self,enc,seed):
        if isinstance(enc,str): enc=enc.encode('latin1')
        self._set_seed(seed)
        prev=self.key8
        out=bytearray()
        for byte in enc:
            prb=self._next_byte()
            prev=(byte+prb+prev)%256
            out.append(int(prev))
        return bytes(out)

def printable_score(b):
    if not b: return -1
    good=sum(1 for x in b if 32<=x<127 or x in (9,10,13))
    return good/len(b)

def _utf8_ok(b):
    try:
        s=b.decode('utf-8')
        return all(c.isprintable() or c in '\n\t\r' for c in s)
    except Exception:
        return False

def brute_key8(mul45,add45,mul8,pairs):
    """pairs: [(enc,seed)]。用全部样本选让最多串成为合法 UTF-8 的 key。
    返回 (best_key, decryptor)。"""
    sample=pairs if len(pairs)<=400 else pairs[:400]
    best=None;bestscore=-1
    for k in range(256):
        d=LcgDecryptor(mul45,add45,mul8,k)
        sc=0
        for enc,seed in sample:
            try:
                if _utf8_ok(d.decrypt(enc,seed)): sc+=1
                else: sc-=1
            except Exception:
                sc-=2
        if sc>bestscore: bestscore=sc;best=k
    return best,LcgDecryptor(mul45,add45,mul8,best)

def _walk_all(e, out):
    if isinstance(e,tuple):
        out.append(e)
        for p in e[1:]:
            if isinstance(p,tuple): _walk_all(p,out)
            elif isinstance(p,list):
                for x in p:
                    if isinstance(x,tuple): _walk_all(x,out)
                    elif isinstance(x,list):
                        for y in x:
                            if isinstance(y,tuple): _walk_all(y,out)

def extract_lcg_params(blocks):
    """从折叠块中识别 LCG 参数。
    state45: (x*MUL45+ADD45)%2^45 ; state8: x*MUL8%257。"""
    mul45=add45=mul8=None
    M45=35184372088832
    for bid,b in blocks.items():
        for s in b['body']:
            roots=[s[2]] if s[0] in('let','setvar') else (s[1]+s[2] if s[0]=='assign' else [])
            for r in roots:
                nodes=[];_walk_all(r,nodes)
                for e in nodes:
                    # (.. * a + b) % M45
                    if e[0]=='bin' and e[1]=='%' and e[3][0]=='num' and abs(e[3][1]-M45)<0.5:
                        inner=e[2]
                        if inner[0]=='bin' and inner[1]=='+':
                            mul=inner[2]
                            if mul[0]=='bin' and mul[1]=='*' and mul[3][0]=='num':
                                mul45=int(mul[3][1])
                            if inner[3][0]=='num': add45=int(inner[3][1])
                    # x * m % 257
                    if e[0]=='bin' and e[1]=='%' and e[3][0]=='num' and abs(e[3][1]-257)<0.5:
                        inner=e[2]
                        if inner[0]=='bin' and inner[1]=='*' and inner[3][0]=='num':
                            mul8=int(inner[3][1])
    return mul45,add45,mul8

def collect_enc_pairs(blocks):
    """收集所有 f(encbytes, seed) 两参数调用（enc 含非可打印字节）。"""
    pairs=[]
    for bid,b in blocks.items():
        for s in b['body']:
            roots=[s[2]] if s[0] in('let','setvar') else (s[1]+s[2] if s[0]=='assign' else [s[1]] if s[0]=='callstmt' else [])
            for r in roots:
                nodes=[];_walk_all(r,nodes)
                for e in nodes:
                    if e[0]=='call' and len(e[2])==2 and e[2][0][0]=='str' and e[2][1][0]=='num':
                        ss=e[2][0][1]
                        if any(ord(c)<32 or ord(c)>126 for c in ss):
                            pairs.append((ss.encode('latin1'),int(e[2][1][1])))
    # 去重
    seen=set();out=[]
    for p in pairs:
        if p not in seen: seen.add(p);out.append(p)
    return out
