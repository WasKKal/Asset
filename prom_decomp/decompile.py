"""整体反编译驱动：递归还原每个函数（upvalue + 结构化 + 嵌套闭包）。"""
from .structure import Structurer
from .upvalue_restore import UpvalueRestorer

def collect_mkclosures(blocks):
    """child_entry -> 该闭包的 upval 表达式表（原始，待父函数重写）。"""
    m={}
    def walk(e):
        if isinstance(e,tuple):
            if e[0]=='mkclosure':
                m[e[1]]=(e[2],e[3],e[4])   # table,narg,isvararg
            for p in e[1:]:
                if isinstance(p,tuple): walk(p)
                elif isinstance(p,list):
                    for x in p:
                        if isinstance(x,tuple): walk(x)
                        elif isinstance(x,list):
                            for y in x:
                                if isinstance(y,tuple): walk(y)
    for b in blocks.values():
        for s in b['body']:
            for p in s[1:]:
                if isinstance(p,tuple): walk(p)
                elif isinstance(p,list):
                    for x in p:
                        if isinstance(x,tuple): walk(x)
    return m

class Decompiler:
    def __init__(self,R):
        self.blocks=R['blocks']; self.cont=R['cont']
        self.retvar=R['returnvar']; self.pv=R['posvar']
        self.top=self.cont['startid']
        self.mk=collect_mkclosures(self.blocks)
        self.done={}
        self.restorers={}

    def reachable(self,entry):
        seen={entry};st=[entry]
        while st:
            x=st.pop()
            if x not in self.blocks: continue
            t=self.blocks[x]['term']
            for y in ([t[1]] if t and t[0]=='jmp' else [t[2],t[3]] if t and t[0]=='branch' else []):
                if y in self.blocks and y not in seen: seen.add(y);st.append(y)
        return seen

    def infer_params(self,reach,argsvar):
        maxn=0
        def walk(e):
            nonlocal maxn
            if isinstance(e,tuple):
                if e[0]=='index' and e[1]==('var',argsvar) and e[2][0]=='num':
                    maxn=max(maxn,int(e[2][1]))
                for p in e[1:]:
                    if isinstance(p,tuple): walk(p)
                    elif isinstance(p,list):
                        for x in p:
                            if isinstance(x,tuple): walk(x)
                            elif isinstance(x,list):
                                for y in x:
                                    if isinstance(y,tuple): walk(y)
        for bid in reach:
            for s in self.blocks[bid]['body']:
                for p in s[1:]:
                    if isinstance(p,tuple): walk(p)
                    elif isinstance(p,list):
                        for x in p:
                            if isinstance(x,tuple): walk(x)
        return maxn

    def decompile_func(self,entry,curmap=None):
        if entry in self.done: return self.done[entry]
        curmap=curmap or {}
        rest=UpvalueRestorer(self.cont,curmap)
        reach=self.reachable(entry)
        # 就地还原本函数块
        for bid in reach:
            self.blocks[bid]['body']=rest.restore_body(self.blocks[bid]['body'])
        # 迭代折叠短路表达式菱形（fold 后 CFG 改变需重算支配）
        from .short_circuit import fold_short_circuits
        for _ in range(60):
            probe=Structurer(self.blocks,entry,self.retvar,self.pv,self.cont)
            pd={n:probe.ipostdom(n) for n in probe.reachable}
            nf=fold_short_circuits(self.blocks,pd,set(probe.loops))
            if nf==0: break
        st=Structurer(self.blocks,entry,self.retvar,self.pv,self.cont)
        body=st.structure()
        narg=self.infer_params(reach,self.cont['argsvar'])
        self.done[entry]=(narg,body,rest,reach)
        self.restorers[entry]=rest
        return self.done[entry]

    def run(self):
        return self.decompile_func(self.top)
