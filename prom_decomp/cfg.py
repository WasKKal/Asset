"""构建 id->基本块 映射与控制流图 CFG。"""
from .astutil import walk
from .vm_extract import locate_block_id
from .block_simplify import simplify_block, extract_terminator

def simplify_leaf(leaf, posvar='D', retvar='B', decrypt=None, inliner=None):
    out,role=simplify_block(leaf['stats'],posvar,retvar,decrypt=decrypt,inliner=inliner)
    body,term=extract_terminator(out,posvar)
    return body,term

def collect_ids_from_expr(e, ids):
    if not isinstance(e,tuple): return
    # 闭包创建: f(<块id>, <upval表>)，第二参数必须是 table
    if e[0]=='call' and len(e[2])==2 and e[2][0][0]=='num' and e[2][1][0]=='table':
        v=e[2][0][1]
        ids.add(int(v) if float(v).is_integer() else v)
    for part in e[1:]:
        if isinstance(part,tuple): collect_ids_from_expr(part,ids)
        elif isinstance(part,list):
            for x in part:
                if isinstance(x,tuple): collect_ids_from_expr(x,ids)
                elif isinstance(x,list):
                    for y in x:
                        if isinstance(y,tuple): collect_ids_from_expr(y,ids)

def block_body_ids(body):
    ids=set()
    for s in body:
        if s[0]=='let': collect_ids_from_expr(s[2],ids)
        elif s[0]=='setvar': collect_ids_from_expr(s[2],ids)
        elif s[0]=='assign':
            for x in s[1]: collect_ids_from_expr(x,ids)
            for x in s[2]: collect_ids_from_expr(x,ids)
        elif s[0]=='callstmt': collect_ids_from_expr(s[1],ids)
    return ids

def build_cfg(vm, posvar='D', retvar='B', decrypt=None, inliner=None):
    # 折叠每个叶子
    simplified=[]
    for leaf in vm['leaves']:
        body,term=simplify_leaf(leaf,posvar,retvar,decrypt,inliner)
        simplified.append((leaf,body,term))
    # 收集所有引用id
    ids=set()
    if vm.get('entry') is not None: ids.add(vm['entry'])  # 入口在 while 外的顶层闭包调用
    for leaf,body,term in simplified:
        ids|=block_body_ids(body)
        if term:
            if term[0]=='jmp': ids.add(term[1])
            elif term[0]=='branch': ids.add(term[2]); ids.add(term[3])
    # id -> leaf stats（locate_block_id 返回 ('leaf',stats)）
    id2stats={}
    for bid in ids:
        node=locate_block_id(vm['tree'],bid)
        if node and node[0]=='leaf':
            id2stats[bid]=node[1]
    stats2id={id(st):bid for bid,st in id2stats.items()}
    blocks={}
    unreachable=[]
    for leaf,body,term in simplified:
        bid=stats2id.get(id(leaf['stats']))
        if bid is None:
            unreachable.append((leaf,body,term)); continue
        blocks[bid]={'body':body,'term':term}
    return blocks,unreachable,id2stats

def succ(term):
    if not term: return []
    if term[0]=='jmp': return [term[1]]
    if term[0]=='branch': return [term[2],term[3]]
    return []
