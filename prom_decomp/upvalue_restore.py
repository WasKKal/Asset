"""把 Prometheus 的 upvaluesTable/alloc/free/proxy 机制还原为原生局部变量与闭包 upvalue。

变换（单个函数内，curmap: 当前闭包第n个捕获 -> 父作用域 slot 表达式）:
  local x = alloc()          -> local x            （x 成为 slot 变量）
  UpTable[slot] = v          -> slot = v
  UpTable[slot]  (读)         -> slot
  CurUp[数字]                -> curmap[数字]
  free(x)                    -> 删除（块末释放，等价于生命周期结束）
  proxy(...) / setmetatable  -> 删除（GC 代理，反编译不需要）
"""

class UpvalueRestorer:
    def __init__(self, cont, curmap=None):
        self.cont=cont
        self.curmap=dict(curmap or {})
        self.ut=cont['upval_table']
        self.cu=cont['curupvar']
        self.free=set(n for n,r in cont['role'].items() if r=='free')
        self.proxy=set(n for n,r in cont['role'].items() if r=='proxy')
        self.slots={}
        self.slot_n=0

    def new_slot(self):
        self.slot_n+=1
        return f"u{self.slot_n}"

    def rw_expr(self,e):
        if not isinstance(e,tuple): return e
        k=e[0]
        if k=='index':
            base=self.rw_expr(e[1]); key=self.rw_expr(e[2])
            # UpTable[slot] -> slot
            if base==('var',self.ut):
                return key
            # CurUp[数字] -> 父捕获表达式
            if base==('var',self.cu) and key[0]=='num':
                n=int(key[1])
                if n in self.curmap: return self.curmap[n]
            return ('index',base,key)
        if k=='bin': return ('bin',e[1],self.rw_expr(e[2]),self.rw_expr(e[3]))
        if k=='un': return ('un',e[1],self.rw_expr(e[2]))
        if k=='table':
            return ('table',[ (None,self.rw_expr(v)) if kk is None else (self.rw_expr(kk),self.rw_expr(v)) for kk,v in e[1]])
        if k=='call':
            fn=e[1]; args=[self.rw_expr(a) for a in e[2]]
            if fn[0]=='var' and fn[1] in self.free and len(args)==1:
                return ('free',args[0])
            if fn[0]=='var' and fn[1] in self.proxy:
                return ('drop',)
            if fn[0]=='var' and (fn[1]=='setmetatable' or fn[1]=='newproxy'):
                # setmetatable({},{__index=...}) GC 代理：丢弃
                return ('drop',)
            return ('call',fn,args)
        if k=='selfcall': return ('selfcall',self.rw_expr(e[1]),e[2],[self.rw_expr(a) for a in e[3]])
        # mkclosure / alloc 保持，由上层处理
        return e

    def restore_body(self, body):
        out=[]
        # 第一遍：表达式重写 + alloc 绑定 slot
        for s in body:
            ns=self._stat(s)
            if ns is None: continue
            if isinstance(ns,list): out.extend(ns)
            else: out.append(ns)
        return out

    def _stat(self,s):
        k=s[0]
        if k=='let':
            name=s[1]; val=self.rw_expr(s[2])
            if val==('alloc',):
                self.slots[name]=self.new_slot()
                return ('local',[name],[])        # local slot 声明
            if val==('drop',): return None
            if val[0]=='free': return None
            return ('let',name,val)
        if k=='setvar':
            val=self.rw_expr(s[2])
            if val==('drop',) or (isinstance(val,tuple) and val[0]=='free'): return None
            return ('setvar',s[1],val)
        if k=='assign':
            lhs=[self.rw_expr(x) for x in s[1]]; rhs=[self.rw_expr(x) for x in s[2]]
            keep=[(l,r) for l,r in zip(lhs,rhs) if not (r==('drop',) or (isinstance(r,tuple) and r[0]=='free'))]
            if not keep: return None
            return ('assign',[l for l,_ in keep],[r for _,r in keep])
        if k=='callstmt':
            v=self.rw_expr(s[1])
            if v==('drop',) or (isinstance(v,tuple) and v[0]=='free'): return None
            return ('callstmt',v)
        if k=='return': return ('return',[self.rw_expr(x) for x in s[1]])
        if k=='local': return ('local',s[1],[self.rw_expr(x) for x in s[2]])
        return s
