"""Prometheus Vmify 反编译总管线。"""
from .vm_extract import extract_vm
from .constarray import recover_constants, make_inliner
from .cfg import build_cfg
from .container import analyze_container
from .string_decrypt import extract_lcg_params, collect_enc_pairs, LcgDecryptor, brute_key8
from .sema import rewrite_block, make_sema

def deobfuscate(code, verbose=False):
    cont=analyze_container(code)
    vm=extract_vm(code)
    pv=cont['posvar'] or vm['posvar']
    ci=recover_constants(code)
    inliner=make_inliner(ci)
    blocks0,unreach0,_=build_cfg(vm,pv,cont['returnvar'],decrypt=None,inliner=inliner)
    mul45,add45,mul8=extract_lcg_params(blocks0)
    decryptor=None;key8=None
    if mul45 is not None:
        pairs=collect_enc_pairs(blocks0)
        key8,d=brute_key8(mul45,add45,mul8,pairs)
        decryptor=lambda enc,seed: d.decrypt(enc,seed)
        if verbose: print(f"[pipeline] LCG=({mul45},{add45},{mul8}) key8={key8} pairs={len(pairs)}")
    blocks,unreach,id2stats=build_cfg(vm,pv,cont['returnvar'],decrypt=decryptor,inliner=inliner)
    # 语义层重写
    rw=make_sema(cont)
    for bid,b in blocks.items():
        b['body']=rewrite_block(b['body'],cont)
        tm=b['term']
        if tm and tm[0]=='branch':
            tmlist=list(tm); tmlist[1]=rw(tm[1]); b['term']=tuple(tmlist)
    if verbose:
        print(f"[pipeline] 块={len(blocks)} 入口={cont['startid']} 常量={ci['raw_count']} 不可达={len(unreach)}")
    return {
        'vm':vm,'cont':cont,'blocks':blocks,'unreachable':unreach,'constinfo':ci,
        'posvar':pv,'returnvar':cont['returnvar'],'lcg':(mul45,add45,mul8,key8),
        'decryptor':decryptor,'inliner':inliner,
    }
