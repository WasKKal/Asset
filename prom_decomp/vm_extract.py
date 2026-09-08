"""
从 Prometheus Vmify 容器主函数中提取基本块。
分发树是对随机块id的二叉搜索: if D<bound then <左> else <右> end
叶子 = 线性寄存器语句序列。
"""
import re
from .lua_lexer import lex
from .lua_parser import Parser, ParseError

def find_vm_container(toks):
    """定位 VM 主函数 function(pos,args,upvals,gc) ... 及其 while 循环。
    返回 (posvar, header_local_names, while_start_idx, end_idx)。"""
    # 找所有 function( <4参数> )
    best=None
    i=0
    while i<len(toks):
        if toks[i].k=='function' and toks[i+1].k=='OP' and toks[i+1].v=='(':
            j=i+2; params=[]
            while toks[j].k=='NAME':
                params.append(toks[j].v); j+=1
                if toks[j].k=='OP' and toks[j].v==',': j+=1
                else: break
            if toks[j].k=='OP' and toks[j].v==')' and len(params)==4:
                # 向后找最近的 while NAME do
                k=j+1
                while k<len(toks) and not (toks[k].k=='while'): k+=1
                if k<len(toks) and toks[k+1].k=='NAME' and toks[k+2].k=='do':
                    # 收集 local 名（function 到 while 之间）
                    names=[]
                    m=j+1
                    while m<k:
                        if toks[m].k=='local':
                            m+=1
                            while toks[m].k=='NAME':
                                names.append(toks[m].v); m+=1
                                if toks[m].k=='OP' and toks[m].v==',': m+=1
                                else: break
                        m+=1
                    best=(params[0],params[1],params[2],params[3],names,k,j,i)
            i=j; continue
        i+=1
    return best

def match_block_end(toks, start):
    """从 do/then 之后开始，找到匹配的 end（处理嵌套 if/function/do/while/for）。返回 end 的索引。"""
    depth=0; i=start
    opener={'if','function','do','while','for'}
    # repeat..until 单独
    while i<len(toks):
        k=toks[i].k
        if k in opener:
            # 'do' 可能是 for/while 的一部分，统一按块处理，遇到对应end/until减
            depth+=1
        elif k=='repeat':
            depth+=1
        elif k=='end' or k=='until':
            depth-=1
            if depth==0: return i
        i+=1
    return -1

class DispatchParser:
    def __init__(self,toks,posvar,start):
        self.t=toks; self.pv=posvar; self.i=start
    def peek(self,k=0): return self.t[min(self.i+k,len(self.t)-1)]
    def next(self): x=self.t[self.i]; self.i+=1; return x
    def _find_then(self):
        """从当前(if之后)找到同层 then，返回 then 索引，条件区间为 [self.i, then)。"""
        depth=0; j=self.i
        while j<len(self.t):
            k=self.t[j].k
            if k=='OP' and self.t[j].v in ('(','{'): depth+=1
            elif k=='OP' and self.t[j].v in (')','}'): depth-=1
            elif k=='then' and depth==0: return j
            j+=1
        return -1
    def _parse_cond(self, lo, hi):
        """解析条件token区间，识别 pos<const / const>pos，返回(kind,bound)或None。"""
        p=Parser(self.t[lo:hi]+[self.t[-1]])
        e=p.expr()
        if e[0]=='bin' and e[1] in ('<','>','<=','>='):
            l,r=e[2],e[3]
            from .astutil import eval_const
            if l==('var',self.pv):
                c=eval_const(r)
                if c and c[0]=='num': return ('lt' if e[1]=='<' else 'le', c[1])
            if r==('var',self.pv):
                c=eval_const(l)
                if c and c[0]=='num': return ('lt' if e[1]=='>' else 'le', c[1])
        return None
    def is_dispatch_if(self):
        if self.peek().k!='if': return False
        ti=self._find_then()
        if ti<0: return False
        return self._parse_cond(self.i+1,ti)
    def parse_node(self):
        d=self.is_dispatch_if()
        if not d:
            return self.parse_leaf()
        kind,bound=d
        ti=self._find_then()
        self.i=ti+1  # 跳过条件与 then
        left=self.parse_branch()
        branches=[(True,left)]
        while self.peek().k=='elseif':
            self.next()
            ti2=self._find_then()
            cond=self._parse_cond(self.i,ti2)
            self.i=ti2+1
            body=self.parse_branch()
            branches.append((cond,body))
        right=None
        if self.peek().k=='else':
            self.next(); right=self.parse_branch()
        self.expect_kw('end')
        return ('node',kind,bound,branches,right)
    def parse_branch(self):
        return self.parse_node()
    def parse_leaf(self):
        # 收集 token 直到同层 else/elseif/end，用 Parser 解析线性语句
        buf=[]; depth=0
        while self.i<len(self.t):
            k=self.peek().k
            if depth==0 and k in ('else','elseif','end'): break
            if k in ('if','function','do','while','for'): depth+=1
            elif k=='end': depth-=1
            buf.append(self.next())
        p=Parser(buf+[self.t[-1]])
        stats=[]
        while p.peek().k!='EOF':
            stats.append(p.one_statement())
        return ('leaf',stats)
    def expect_kw(self,kw):
        if self.peek().k==kw: self.next(); return
        raise ParseError(f"分发树期望 {kw}，得到 {self.peek()}")

def collect_leaves(tree, leaves=None, path=None):
    """中序遍历，leaves: list of dict(stats, path)。返回有序叶子。"""
    if leaves is None: leaves=[]; path=[]
    if tree[0]=='leaf':
        leaves.append({'stats':tree[1],'path':list(path)})
        return leaves
    _,kind,bound,branches,right=tree
    # branches[0]=(True,leftTree), 其余 elseif
    for idx,(cond,sub) in enumerate(branches):
        collect_leaves(sub,leaves,path+[(idx,bound)])
    if right is not None:
        collect_leaves(right,leaves,path+[('else',bound)])
    return leaves

def locate_block_id(tree, target):
    """给定块id，按二叉搜索定位叶子（模拟VM分发）。"""
    node=tree
    while node[0]=='node':
        _,kind,bound,branches,right=node
        go_left = (target < bound) if kind=='lt' else (target<=bound)
        if go_left:
            node=branches[0][1]
        else:
            # elseif 链情况：依次判断，这里简化走 else 链
            if right is not None: node=right
            elif len(branches)>1: node=branches[1][1]
            else: node=branches[0][1]
    return node

def extract_vm(code):
    toks=lex(code)
    info=find_vm_container(toks)
    if not info: raise RuntimeError("未找到VM主函数")
    pv,av,uv,gv,regnames,while_idx,paren_idx,func_idx=info
    # while PV do 在 while_idx，do 在 +2
    dp=DispatchParser(toks,pv,while_idx+3)
    tree=dp.parse_node()
    leaves=collect_leaves(tree)
    # 入口块id：createVarargClosure(<expr>,{})(...) 模式，即 token 序列 , { } ) (
    entry=None
    from .astutil import eval_const
    for idx in range(len(toks)-4):
        # createClosure(<expr>,{}) 后立即调用：{ } 后跳过 1~2 个 ')' 紧跟 '('
        if not (toks[idx].k=='OP' and toks[idx].v=='{' and toks[idx+1].k=='OP' and toks[idx+1].v=='}'):
            continue
        q=idx+2; nclose=0
        while q<len(toks) and toks[q].k=='OP' and toks[q].v==')':
            q+=1; nclose+=1
        if not (1<=nclose<=2 and q<len(toks) and toks[q].k=='OP' and toks[q].v=='('):
            continue
        # 向前找匹配 '('
        d=0; j=idx-1
        while j>=0:
            if toks[j].k=='OP' and toks[j].v==')': d+=1
            elif toks[j].k=='OP' and toks[j].v=='(':
                if d==0: break
                d-=1
            j-=1
        # j 是 '('，其后到第一个顶层 ',' 为入口表达式
        lo=j+1; d2=0; k=lo
        while k<idx:
            if toks[k].k=='OP' and toks[k].v in ('(','{'): d2+=1
            elif toks[k].k=='OP' and toks[k].v in (')','}'): d2-=1
            elif toks[k].k=='OP' and toks[k].v==',' and d2==0: break
            k+=1
        p=Parser(toks[lo:k]+[toks[-1]])
        try:
            e=p.expr(); c=eval_const(e)
            if c and c[0]=='num':
                v=c[1]; entry=int(v) if float(v).is_integer() else v
        except Exception:
            pass
    return {
        'posvar':pv,'argsvar':av,'upvalsvar':uv,'gcvar':gv,
        'regnames':regnames,'tree':tree,'leaves':leaves,
        'entry':entry,'toks':toks
    }
