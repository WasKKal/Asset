"""
精简 Lua 表达式/语句解析器，产出元组形式 AST，服务于 Prometheus VM 反编译。
表达式节点:
  ('nil',) ('true',) ('false',) ('vararg',)
  ('num', float|int) ('str', str) ('var', name)
  ('index', base, key)
  ('bin', op, l, r) ('un', op, v)
  ('call', f, [args]) ('selfcall', base, method, [args])
  ('table', [(key_or_None, val), ...])
  ('func', [params], body_raw)
语句节点:
  ('assign', [lhs], [rhs])
  ('local', [names], [rhs])
  ('return', [exprs])
  ('callstmt', expr)
  ('do',...) / 控制流由分发树解析器处理
"""
from .lua_lexer import lex, Tok

class ParseError(Exception): pass

class Parser:
    def __init__(self, toks):
        self.t=toks; self.i=0
    def peek(self,k=0): return self.t[min(self.i+k,len(self.t)-1)]
    def next(self):
        t=self.t[self.i]; self.i+=1; return t
    def accept(self,v):
        if self.peek().k==v or (v in ('OP',) and self.peek().k=='OP'):
            pass
        t=self.peek()
        if t.k==v: return self.next()
        # OP 值匹配
        if self.peek().k=='OP' and t.v==v: return self.next()
        return None
    def expect(self,v):
        t=self.peek()
        if t.k==v or (t.k=='OP' and t.v==v): return self.next()
        raise ParseError(f"期望 {v} 得到 {t} @语句位置")
    def atOp(self,v): return self.peek().k=='OP' and self.peek().v==v
    def atKw(self,v): return self.peek().k==v

    # ---------- 表达式 ----------
    BIN_PRI = {'or':(1,1),'and':(2,2),
               '<':(3,3),'>':(3,3),'<=':(3,3),'>=':(3,3),'~=':(3,3),'==':(3,3),
               '..':(5,4),  # 右结合
               '+':(6,6),'-':(6,6),
               '*':(7,7),'/':(7,7),'%':(7,7),
               '^':(9,8)}   # 右结合
    def expr(self,limit=0):
        # 一元
        t=self.peek()
        if t.k=='not' or (t.k=='OP' and t.v in ('-','#')):
            op=self.next().v if t.k=='OP' else self.next().k
            v=self.expr(8)
            left=('un',op,v)
        else:
            left=self.simple()
        # 二元
        while True:
            t=self.peek()
            op = t.v if t.k=='OP' else (t.k if t.k in ('and','or') else None)
            if op not in self.BIN_PRI: break
            lp,rp=self.BIN_PRI[op]
            if lp<=limit: break
            self.next()
            right=self.expr(rp)
            left=('bin',op,left,right)
        return left
    def simple(self):
        t=self.peek()
        if t.k=='NUMBER':
            self.next()
            txt=t.v
            if txt.lower().startswith('0x'): val=int(txt,16)
            elif ('.' in txt) or ('e' in txt.lower()): val=float(txt)
            else: val=int(txt)
            e=('num',val)
        elif t.k=='STRING':
            self.next(); e=('str',t.v)
        elif t.k=='nil': self.next(); e=('nil',)
        elif t.k=='true': self.next(); e=('true',)
        elif t.k=='false': self.next(); e=('false',)
        elif t.k=='...' or self.atOp('...'): self.next(); e=('vararg',)
        elif t.k=='function':
            e=self.parse_func()
        elif self.atOp('('):
            self.next(); e=self.expr(0); self.expect(')')
        elif t.k=='NAME':
            self.next(); e=('var',t.v)
        elif self.atOp('{'):
            e=self.parse_table()
        else:
            raise ParseError(f"无法解析表达式开头 {t}")
        # 后缀
        while True:
            if self.atOp('['):
                self.next(); k=self.expr(0); self.expect(']')
                e=('index',e,k)
            elif self.atOp('.'):
                self.next(); name=self.expect('NAME').v
                e=('index',e,('str',name))
            elif self.atOp(':'):
                self.next(); meth=self.expect('NAME').v
                args=self.parse_call_args()
                e=('selfcall',e,meth,args)
            elif self.atOp('(') or self.atOp('{') or (self.peek().k=='STRING'):
                args=self.parse_call_args(); e=('call',e,args)
            else: break
        return e
    def parse_call_args(self):
        if self.atOp('('):
            self.next(); args=[]
            if not self.atOp(')'):
                args.append(self.expr(0))
                while self.atOp(','):
                    self.next(); args.append(self.expr(0))
            self.expect(')')
            return args
        if self.atOp('{'):
            return [self.parse_table()]
        if self.peek().k=='STRING':
            return [('str',self.next().v)]
        raise ParseError(f"调用参数错误 {self.peek()}")
    def parse_table(self):
        self.expect('{'); entries=[]
        while not self.atOp('}'):
            if self.atOp('['):
                self.next(); k=self.expr(0); self.expect(']'); self.expect('=')
                v=self.expr(0); entries.append((k,v))
            else:
                # name = value 或 纯值
                if self.peek().k=='NAME' and self.peek(1).k=='OP' and self.peek(1).v=='=':
                    name=self.next().v; self.next()
                    v=self.expr(0); entries.append((('str',name),v))
                else:
                    v=self.expr(0); entries.append((None,v))
            if self.atOp(',') or self.atOp(';'): self.next()
            else: break
        self.expect('}')
        return ('table',entries)
    def parse_func(self):
        self.expect('function'); self.expect('(')
        params=[]
        if not self.atOp(')'):
            while True:
                t=self.next()
                params.append(t.v if not (t.k=='...' or (t.k=='OP' and t.v=='...')) else '...')
                if not self.atOp(','): break
                self.next()
        self.expect(')')
        # 函数体由外层块结构处理，这里仅占位；平衡块开关键字与其 end
        # （for/while 自带的 do 不重复计数；这些内部函数无独立 do 块）
        depth=1
        start=self.i
        opener={'function','if','for','while'}
        while self.i<len(self.t) and depth>0:
            k=self.next().k
            if k in opener: depth+=1
            elif k=='repeat': depth+=1
            elif k in ('end','until'): depth-=1
        return ('func',params,(start,self.i))

    # ---------- 语句列表（线性块内）----------
    def parse_linestats(self, stop_kws=('elseif','else','end','until')):
        stats=[]
        while True:
            t=self.peek()
            if t.k=='EOF': break
            if t.k in stop_kws: break
            stats.append(self.one_statement())
        return stats
    def one_statement(self):
        t=self.peek()
        if t.k=='local':
            self.next()
            self.accept('function')
            names=[]
            names.append(self.expect('NAME').v)
            while self.atOp(','):
                self.next(); names.append(self.expect('NAME').v)
            exprs=[]
            if self.atOp('='):
                self.next(); exprs.append(self.expr(0))
                while self.atOp(','): self.next(); exprs.append(self.expr(0))
            return ('local',names,exprs)
        if t.k=='return':
            self.next(); exprs=[]
            if not (self.peek().k in ('end','else','elseif','until','EOF') or
                    (self.peek().k=='OP' and self.peek().v in (';',))):
                exprs.append(self.expr(0))
                while self.atOp(','): self.next(); exprs.append(self.expr(0))
            self.accept(';')
            return ('return',exprs)
        if t.k=='do':
            # 罕见，跳过匹配
            self.next(); body=self.parse_linestats(('end',)); self.expect('end')
            return ('do',body)
        # 否则：表达式起始，可能是 赋值 或 调用语句
        lhs=[self.parse_lvalue_or_expr()]
        while self.atOp(','):
            self.next(); lhs.append(self.parse_lvalue_or_expr())
        if self.atOp('='):
            self.next(); rhs=[self.expr(0)]
            while self.atOp(','): self.next(); rhs.append(self.expr(0))
            return ('assign',lhs,rhs)
        # 调用语句
        if len(lhs)==1: return ('callstmt',lhs[0])
        raise ParseError(f"意外的多表达式语句 {lhs}")
    def parse_lvalue_or_expr(self):
        # 解析 左值：Name 或 prefixexp[exp]；否则普通表达式
        e=self.simple()
        # 继续后缀，但不包含调用（左值场景）；为稳妥走完整expr
        # 重新用expr逻辑：此处simple已处理后缀，补二元
        while True:
            tt=self.peek()
            op = tt.v if tt.k=='OP' else (tt.k if tt.k in ('and','or') else None)
            if op not in self.BIN_PRI: break
            lp,rp=self.BIN_PRI[op]; self.next()
            r=self.expr(rp); e=('bin',op,e,r)
        return e

def parse_expr_str(s):
    p=Parser(lex(s)); return p.expr(0)
