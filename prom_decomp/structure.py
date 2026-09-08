"""CFG -> 结构化 Lua（基于支配/后支配的区域分析）。"""

class If:
    def __init__(self,cond,then,els=None): self.cond=cond;self.then=then;self.els=els
class While:
    def __init__(self,cond,body,kind='while',head=None):
        self.cond=cond;self.body=body;self.kind=kind;self.head=head
class LoopCtrl:
    def __init__(self,k): self.k=k
class Return:
    def __init__(self,args): self.args=args

VEXIT=-1  # 虚拟出口

class Structurer:
    def __init__(self, blocks, entry, retvar, posvar, cont):
        self.B=blocks; self.entry=entry; self.retvar=retvar
        self.pv=posvar; self.cont=cont
        self._succ_cache={}
        self.reachable=self._reachable()
        self.dom=self._dom_on(self._pred_succ(self.reachable,False),entry)
        self.pdom=self._postdom()
        self.loops=self._find_loops()

    def succs(self,bid):
        if bid in self._succ_cache: return self._succ_cache[bid]
        t=self.B[bid]['term']; out=[]
        if t:
            if t[0]=='jmp': out=[t[1]]
            elif t[0]=='branch': out=[t[2],t[3]]
        self._succ_cache[bid]=out; return out

    def _reachable(self):
        seen={self.entry};st=[self.entry]
        while st:
            x=st.pop()
            if x not in self.B: continue
            for y in self.succs(x):
                if y in self.B and y not in seen: seen.add(y);st.append(y)
        return seen

    def _pred_succ(self,nodes,reverse):
        adj={n:set() for n in nodes}
        for n in nodes:
            for s in self.succs(n):
                if s in nodes:
                    if reverse: adj[s].add(n)
                    else: adj[n].add(s)
        return adj

    def _dom_on(self,adj,entry):
        nodes=set(adj)
        dom={n:set(nodes) for n in nodes}
        if entry not in dom: return dom
        dom[entry]={entry}; changed=True
        while changed:
            changed=False
            for n in nodes:
                if n==entry: continue
                ps=[dom[p] for p in adj[n] if p in dom]
                new=set(nodes)
                for p in ps: new&=p
                new.add(n)
                if new!=dom[n]: dom[n]=new;changed=True
        return dom

    def _immdom(self,dom,n):
        preds=dom[n]-{n}
        # 立即支配 = 支配 n 且被其他所有支配者支配的那个
        cand=None
        for p in preds:
            if all(p in dom[q] for q in preds): cand=p;break
        return cand

    def _postdom(self):
        # 反图 + 虚拟出口
        nodes=set(self.reachable)|{VEXIT}
        radj={n:set() for n in nodes}
        for n in self.reachable:
            ss=self.succs(n)
            if not ss: radj[n].add(VEXIT)
            for s in ss:
                if s in self.B and s in self.reachable: radj[s].add(n)
                else: radj[n].add(VEXIT) if False else None
            t=self.B[n]['term']
            if t and t[0]=='exit': radj[VEXIT].add(n) if False else radj[n].add(VEXIT)
        # 在反图上以 VEXIT 为根求支配 = 原图后支配
        pdom=self._dom_on(radj,VEXIT)
        self.pdom_adj=radj
        return pdom

    def ipostdom(self,n):
        if n not in self.pdom: return None
        preds=self.pdom[n]-{n}
        for p in preds:
            if all(p in self.pdom[q] for q in preds): return p
        return None

    def _find_loops(self):
        # 真循环回边必须是 latch 块末尾【无条件 jmp】回到 header（while/for 体末跳 check）；
        # 布尔 and/or 短路菱形回边是 branch 条件边，不算循环。
        loops={}
        for latch in list(self.reachable):
            lt=self.B[latch]['term']
            if not (lt and lt[0]=='jmp'): continue
            h=lt[1]
            if h in self.dom and latch in self.dom[h]:
                ht=self.B[h]['term']
                if ht and ht[0]=='branch':
                    tb,fb=ht[2],ht[3]
                    if self._can_reach(tb,latch): loops[h]=(latch,fb,tb)
                    elif self._can_reach(fb,latch): loops[h]=(latch,tb,fb)
        return loops

    def _can_reach(self,a,b):
        seen={a};st=[a]
        while st:
            x=st.pop()
            if x==b: return True
            for y in self.succs(x):
                if y in self.B and y not in seen: seen.add(y);st.append(y)
        return False

    def _split_body(self,bid):
        body=self.B[bid]['body']; normal=[]; retargs=None
        for s in body:
            if s[0] in('let','setvar') and s[1]==self.retvar and isinstance(s[2],tuple) and s[2][0]=='table':
                retargs=[v for k,v in s[2][1]]
            elif s[0]=='assign' and len(s[1])==1 and s[1][0]==('var',self.retvar):
                if s[2][0][0]=='table': retargs=[v for k,v in s[2][0][1]]
                else: normal.append(s)
            else: normal.append(s)
        return normal,retargs

    def structure(self):
        stmts,_=self._region(self.entry,set(),None)
        return stmts

    def _region(self,cur,stop,loopctx):
        out=[]; guard=0
        while cur is not None and cur not in stop:
            guard+=1
            if guard>200000: raise RuntimeError("结构化死循环")
            if cur not in self.B: return out,cur
            b=self.B[cur]; normal,retargs=self._split_body(cur); term=b['term']
            if term is None:
                out.extend(normal); return out,None
            if term[0]=='exit':
                out.extend(normal); out.append(Return(retargs or [])); return out,None
            if term[0]=='jmp':
                tgt=term[1]
                if loopctx:
                    h,fin=loopctx
                    if tgt==h: out.extend(normal);out.append(LoopCtrl('continue'));return out,None
                    if tgt==fin: out.extend(normal);out.append(LoopCtrl('break'));return out,None
                if tgt in stop: out.extend(normal); return out,tgt
                out.extend(normal); cur=tgt; continue
            if term[0]=='branch':
                cond,t,f=term[1],term[2],term[3]
                out.extend(normal)
                if cur in self.loops:
                    latch,final,body_entry=self.loops[cur]
                    body,_=self._region(body_entry,{cur,final},(cur,final))
                    body=[x for x in body if not (isinstance(x,LoopCtrl) and x.k=='continue')]
                    out.append(While(cond,body))
                    if final in stop: return out,final
                    cur=final; continue
                # 用后支配点求汇合
                join=self.ipostdom(cur)
                # then / else 区域，边界=join 与外层 stop
                bound=set(stop); 
                if join is not None and join!=VEXIT: bound.add(join)
                then_stmts,t_next=self._region(t,bound,loopctx)
                else_stmts,e_next=self._region(f,bound,loopctx)
                # 空分支判定：分支首块==join
                t_empty=(t==join); f_empty=(f==join)
                if f_empty:
                    out.append(If(cond,then_stmts))
                elif t_empty:
                    out.append(If(('un','not',cond),else_stmts))
                else:
                    out.append(If(cond,then_stmts,else_stmts))
                if join is not None and join in stop: return out,join
                if join==VEXIT or join is None: return out,None
                cur=join; continue
            out.extend(normal); return out,None
        return out,cur
