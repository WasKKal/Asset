"""结构化节点 + 表达式 AST -> Lua 文本（支持 mkclosure 递归生成内嵌函数）。"""
from .structure import If, While, LoopCtrl, Return
from .astutil import expr_lua

class CodeGen:
    def __init__(self, decompiler, param_names=None, indent='  '):
        self.dc=decompiler
        self.ind=indent
        self.param_names=param_names or {}

    def expr(self,e):
        if not isinstance(e,tuple): return str(e)
        if e[0]=='mkclosure':
            cid=e[1]; table=e[2]; isvar=e[4]
            curmap={i+1:v for i,(k,v) in enumerate(table[1])}
            narg,body,rest,reach=self.dc.decompile_func(cid,curmap)
            names=self.param_names.get(cid) or [f"a{i}" for i in range(1,narg+1)]
            if isvar: names=names+['...']
            lines=self._stmts(body,1)
            return f"function({', '.join(names)})\n"+"\n".join(lines)+"\n"+self.ind+ "end"
        if e[0]=='alloc': return 'nil'
        if e[0]=='drop': return 'nil'
        if e[0]=='free': return self.expr(e[1])
        return expr_lua(e)

    def _stmts(self,stmts,depth):
        out=[]
        for s in stmts: out.extend(self._stmt(s,depth))
        return out

    def _inline(self,e): return self.expr(e)

    def _stmt(self,s,depth):
        pad=self.ind*depth
        if isinstance(s,If):
            lines=[pad+f"if {self.expr(s.cond)} then"]
            lines+=self._stmts(s.then,depth+1)
            if s.els:
                lines.append(pad+"else")
                lines+=self._stmts(s.els,depth+1)
            lines.append(pad+"end"); return lines
        if isinstance(s,While):
            key='while' if s.kind=='while' else s.kind
            lines=[pad+f"{key} {self.expr(s.cond)} do"]
            lines+=self._stmts(s.body,depth+1)
            lines.append(pad+"end"); return lines
        if isinstance(s,LoopCtrl): return [pad+s.k]
        if isinstance(s,Return):
            return [pad+("return "+', '.join(self.expr(a) for a in s.args) if s.args else "return")]
        k=s[0]
        if k=='let': return [pad+f"local {s[1]} = {self.expr(s[2])}"]
        if k=='setvar': return [pad+f"{s[1]} = {self.expr(s[2])}"]
        if k=='assign':
            l=', '.join(self.expr(x) for x in s[1]); r=', '.join(self.expr(x) for x in s[2])
            return [pad+f"{l} = {r}"]
        if k=='callstmt': return [pad+self.expr(s[1])]
        if k=='local':
            names=', '.join(s[1]); vals=', '.join(self.expr(x) for x in s[2])
            return [pad+f"local {names}"+(" = "+vals if s[2] else "")]
        if k=='return': return [pad+"return "+', '.join(self.expr(x) for x in s[1])]
        return [pad+f"-- {s}"]

    def gen_top(self):
        narg,body,rest,reach=self.dc.decompile_func(self.dc.top)
        return "\n".join(self._stmts(body,0))
