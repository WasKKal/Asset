# WeAreDev / Prometheus Vmify 通用反编译器 开发文档

## 项目概述

本项目目标：将 WeAreDevs.net 混淆器（后端为开源 Prometheus Lua Obfuscator 的 Vmify 步骤）混淆的 Lua 代码，**完全反编译回原始 Lua 源码**，且必须适配所有使用 WeAreDev 的混淆（通用化，非仅测试样本）。

最终产物：集成进 DeltaUI 的 `deobfuscator.lua` 远程页面，作为 Roblox Luau 工具运行。

## 仓库结构

```
WasKKal/Asset (master)
├── deltaui/
│   ├── deobfuscator.lua          # DeltaUI 反混淆工具页面（已集成 V2 入口）
│   ├── prom_decomp.lua           # Lua 版反编译器模块（核心算法已移植，开发中）
│   └── coding_blocks.lua         # DeltaUI 代码块模块
└── prom_decomp/                   # Python 参考原型（完整管线，已验证）
    ├── __init__.py
    ├── lua_lexer.py               # Lua 词法分析器
    ├── lua_parser.py              # 递归下降解析器
    ├── astutil.py                 # AST 工具（常量折叠、表达式渲染、替换）
    ├── vm_extract.py              # VM 容器定位与基本块提取
    ├── block_simplify.py          # 块内寄存器折叠与 terminator 分类
    ├── cfg.py                     # 控制流图构建
    ├── constarray.py              # 常量数组恢复（自定义 base64 + 区间反转）
    ├── string_decrypt.py          # LCG 字符串解密器（4 密钥 + key8 暴力）
    ├── container.py               # 容器作用域角色解析
    ├── sema.py                    # 语义层（env 全局名还原 + 闭包创建识别）
    ├── upvalue_restore.py         # upvalue 机制还原为局部变量
    ├── structure.py               # 控制流结构化（支配/后支配 + 自然循环）
    ├── short_circuit.py           # 短路表达式折叠（and/or/三元菱形合并）
    ├── codegen.py                 # 结构化节点 → Lua 代码生成
    ├── decompile.py               # 反编译驱动（递归函数处理）
    ├── pipeline.py                # 完整管线编排
    └── test/                      # 测试样本
        ├── test_obfuscated.lua        # 简单样本（local s=1 print(s)）
        ├── test_complex.lua           # 复杂样本原始源码（学生成绩管理系统）
        └── test_complex_obfuscated.lua # 复杂样本混淆（主测试对象）
```

## 混淆原理（Prometheus Vmify）

### 顶层固定结构

```lua
--[[ v1.0.0 https://wearedevs.net/obfuscator ]]
return(function(...)
    -- 常量数组前言：V + wrapper j + reverse + base64 decode do块
    return(function(外部7项[乱序], 内部函数表[乱序])
        -- 内部多赋值（alloc/free/proxy/gc/container/vclosure/closureN/upval_table/refcount/curupid）
        return vclosure(startId,{})(unpack(arg))
    end)(getfenv() or _ENV, unpack or table.unpack, newproxy, setmetatable, getmetatable, select, {...})
end)(...)
```

### 容器内部函数角色

| 角色 | 参数 | 特征 |
|------|------|------|
| alloc | 0 | `id=id+1; ref[id]=1; return id` |
| free | 1 | `ref[x]=ref[x]-1; if 0==ref[x] then ref[x],up[x]=nil,nil end` |
| proxy | 1 | 含 for 循环 + setmetatable/newproxy 建代理 |
| gc | 1 | 含 while 递归减引用计数 |
| container | 4 | VM 主函数，4 参依次 pos/args/currentUpvals/gc |
| vclosure | 2 | vararg 闭包工厂，内层函数参数为 `...` |
| closureN | 2 | 固定参数闭包工厂，N=真实参数数+random(0,5)（上界非精确） |
| upval_table | - | 空 {}，共享 upvalue 存储 |
| refcount | - | 空 {}，引用计数表 |
| curupid | - | 初值 0（含算术式 eval 后=0） |

### 控制流发射形状

- **顺序**：块末 `pos=nextId`（jmp）
- **if 无 else**：header `pos=cond and innerId or finalId`（branch）；inner 末 jmp final
- **if 有 else**：header branch(t=inner,f=nextElse)；inner/else 末 jmp final
- **while**：前驱 jmp check；check branch(cond,t=inner,f=final)；inner 末 jmp 回 check（后向边/latch）
- **数值 for**：初始化在当前块；check 块 current+=increment + 方向比较；inner 末 jmp check
- **generic for**：check 块先多赋值 `state,ctrl=iter(state,ctrl)`；再 branch(ctrl,t=body,f=final)
- **break**：块末 jmp 当前循环 final
- **continue**：块末 jmp 当前循环 check
- **return**：`returnVar={返回值表}`，随后 `pos=env[随机串]`（exit）

### 表达式短路（and/or/三元）

Prometheus 把非常量右值的 and/or 编译成跨块菱形：
- header: `resReg=lhs; pos=lhs and block1 or block2`
- block1（then）: `resReg=rhs; jmp final`
- block2（false/or的rhs）: 直接 jmp final（resReg 保持 lhs）
- 三元：两分支都赋值后 jmp final

**关键区分**：真循环回边必须是 latch 块末尾**无条件 jmp** 回到 header；短路菱形的"回边"是 branch 条件边。

## 反编译管线（已验证）

### 阶段 1：前端（100% 验证通过）

1. **基本块提取** (`vm_extract.py`)
   - 定位 VM 容器函数，解析分发树（id 排序二分，len<=4 用 elseif 链否则 mid 分裂）
   - 复杂样本：125 叶子 = 123 有效块 + 2 空块，入口 11557609
   - 简单样本：72 叶子 = 71 + 1 空块，入口 4504287

2. **寄存器折叠** (`block_simplify.py`)
   - D/B 寄存器块内临时借用只认最后一次 D 赋值
   - 含调用副作用不内联
   - terminator 100% 正确分类（jmp/branch/exit/dynamic）
   - **关键修复**：数值 for 的双 D 赋值合并为 branch

3. **CFG 构建** (`cfg.py`)
   - 123 有效块 + 2 不可达空块，跳转零缺失

4. **常量数组恢复** (`constarray.py`)
   - 自定义 base64（标准 64 字符洗牌）+ 三区间反转
   - wrapper `function j(a) return V[a+offset] end`
   - 复杂样本：arrvar=V, wrapper=j, offset=19368, 161 常量
   - **关键修复**：base64 单 '=' 输出 2 字节（看下一字符是否=），旧版只输出 1 字节导致明文恒少最后字符

5. **LCG 字符串解密** (`string_decrypt.py`)
   - 4 密钥：secret_key_6(0..63)、_7(0..127)、_44(0..17592186044415)、_8(0..255)
   - param_mul_45=key6*4+1, param_add_45=key44*2+1, param_mul_8=primitive_root_257(key7)
   - DECRYPT 每字节 `prevVal=(encByte+rndByte+prevVal)%256`，初值 secret_key_8
   - **关键修复 1**：key8 暴力必须全量统计合法 UTF-8 数量，不能只取前若干对（会选到"短串恰好可打印"的错 key）
   - **关键修复 2**：复杂样本真实 key8=74（不是 25），78 对全部正确（含中文）
   - Python 与 Lua 双精度运算逐字节一致（已用 lupa 2.8 验证）

6. **容器作用域解析** (`container.py`)
   - 解析顶层第二个 `return(function(外部7项乱序, 内部函数表乱序)`
   - 角色判定规则：0 参=alloc；1 参按体含 for→proxy、含 while→gc、含 nil→free；4 参含 while=container；2 参内层参数为 `...`→vclosure 否则 closureN
   - 两样本 100% 正确

7. **语义层** (`sema.py`)
   - `env["name"]/env.name` → 全局变量还原
   - `closureN(id,{upvals})/vclosure(id,{...})` → mkclosure 标记（含目标块 id、upval 表、参数数）
   - `alloc()` → alloc 标记
   - 全样本识别 19 个 mkclosure

### 阶段 2：中端（已实现，部分验证）

8. **upvalue 还原** (`upvalue_restore.py`)
   - `local x=alloc()` → `local x`（x 成为 slot 变量）
   - `UpTable[slot]=v` → `slot=v`
   - `UpTable[slot]`（读）→ `slot`
   - `CurUp[数字]` → 父作用域捕获表达式（curmap）
   - `free(x)` → 删除（块末释放）
   - `proxy(...)/setmetatable` → 删除（GC 代理）

9. **短路折叠** (`short_circuit.py`)
   - 识别纯值选择菱形（分支块只写单一结果寄存器、无副作用、末尾 jmp join）
   - and: T 赋值 F 空 → `R=L and R0`
   - or: T 空 F 赋值 → `R=L or R0`
   - 三元: 两分支都赋值 → `R=C and A or B`
   - 迭代到不动点

### 阶段 3：后端（已实现，待完整验证）

10. **控制流结构化** (`structure.py`)
    - 支配树 + 后支配树（精确求分支汇合点）
    - 自然循环识别（header 支配 latch 且 latch 末尾无条件 jmp 回 header）
    - 区域递归下降（jmp/branch/exit，break/continue 识别）
    - 节点类：If/While/LoopCtrl/Return

11. **代码生成** (`codegen.py`)
    - 结构化节点 + 表达式 AST → 缩进 Lua
    - mkclosure 递归生成内嵌函数（参数由 infer_params 推断）

12. **反编译驱动** (`decompile.py`)
    - 递归处理每个函数（入口块 + curmap）
    - infer_params：argsVar[数字] 最大索引 → 真实参数个数
    - collect_entries：顶层 startid + 所有 mkclosure 目标

## 关键参数（测试样本）

### 复杂样本（学生成绩管理系统）
- 入口：11557609
- posvar=D, argsvar=f, curupvar=W, gcvar=h
- returnVar=B, unpack=E
- 常量数组：arrvar=V, wrapper=j, offset=19368, 161 常量
- LCG：mul45=105, add45=2868902282551, mul8=105, **key8=74**
- 78 个加密对全部正确（含中文：张三/李四/王五/成绩报告/最高分）
- 原始源码函数：addStudent/removeStudent/listAll/getAverage/getTopStudent/exportReport/_calcGrade

### 简单样本（local s=1 print(s)）
- 入口：4504287
- posvar=t, 等（参数名随机，必须自动识别勿硬编码）
- LCG：mul45=125, add45=16469789531637, mul8=55, key8=0（无加密字符串）

## 已验证做不通（勿重复）

1. **纯静态手工追状态扁平化**：124/125 状态无法手动追
2. **纯 Lua 完整执行**：深度依赖 Roblox + 防篡改，修了 11+ 环境错误仍不通
3. **error 在 VM 主循环抛状态**：被内部 pcall 吞
4. **复用 V1 数字化简结果**：块 id 算错（3003399→-4574505），必须自己常量折叠
5. **brute_key8 只取前若干对**：会选到"短串恰好可打印"的错 key，必须全量统计合法 UTF-8
6. **MC chorus_flower 透视**：FPS7 卡顿 + 边缘消失

## 未完成项（下一步开发）

### 高优先级

1. **短路折叠完整验证**：当前折叠后 if 数仍过多（简单样本 183 if/184 while），需验证折叠是否正确处理嵌套短路
2. **运行时噪音消除**：EncryptStrings/ConstantArray 注入的运行时闭包（DECRYPT/base64 decode/charmap 初始化）需识别并删除
   - 特征：DECRYPT 闭包体含 35184372088832 魔数；base64 decode 含自定义字母表；charmap 初始化是 256 次 repeat 循环
   - 策略：死代码消除（DCE），从用户输出动作反向标记有用语句
3. **数值 for 还原**：check 块 current+=increment + 方向比较需识别还原为 `for v=init,final,inc`
4. **generic for 还原**：check 块迭代器多赋值还原为 `for k,v in iter`
5. **elseif 链还原**：分发树的 elseif 链需识别

### 中优先级

6. **upvalue 跨闭包共享还原**：当前 W[n]→curmap 已处理，但更深层 upvalue（currentUpvalues[higherId]）需细读 compiler/upvalue.lua
7. **源码变量名还原**：跨块 getVarRegister 变量、local 提升
8. **代码生成完整化**：astutil.expr_lua 补 mkclosure/alloc 渲染、布尔恒比较折叠、selfcall、多返回 unpack
9. **双样本验证标准**：语法正确 + 执行输出一致 + 函数/变量名与 test_complex.lua 一致

### 低优先级

10. **Lua 版完整移植**：当前 prom_decomp.lua 只移植了词法/解析/常量数组/LCG 核心，需完整移植结构化/代码生成
11. **性能优化**：Luau 环境下大脚本反编译速度

## 开发环境

- Python：/opt/python3.12/bin/python3（lupa 2.8 已安装）
- Lua：/usr/bin/lua 5.3.6（测试脚本需 `loadstring=load, unpack=table.unpack` 兼容层）
- lupa 用法：`from lupa import LuaRuntime; lua=LuaRuntime(encoding=None)`（返回字节表避开 utf8 解码报错）
- 读混淆文件：`open(fn,'rb').read().decode('latin1')`（含非 UTF-8 字节）
- WeAreDev API：POST https://wearedevs.net/api/obfuscate，body `{"script":"..."}`，必须带浏览器头否则 403
- GitHub：WasKKal/Asset，推送用 Python 脚本（curl 参数过长会失败），Token 由用户提供，勿硬编码到仓库

## 运行 Python 原型

```bash
cd /path/to/github_work
python3 -c "
import sys; sys.path.insert(0,'.')
from prom_decomp.pipeline import deobfuscate
from prom_decomp.decompile import Decompiler
from prom_decomp.codegen import CodeGen

R = deobfuscate(open('prom_decomp/test/test_complex_obfuscated.lua','rb').read().decode('latin1'))
dc = Decompiler(R)
dc.run()
cg = CodeGen(dc)
print(cg.gen_top())
"
```

## 参考资料

- Prometheus 源码：github_work/prometheus_src/（逆向依据）
  - compiler/compiler.lua、compile_top.lua、emit.lua
  - compiler/statements/*.lua（控制流发射形状）
  - compiler/expressions/*.lua（表达式编译，含 and/or/if_else/boolean）
  - compiler/upvalue.lua（upvalue 机制）
  - steps/EncryptStrings.lua、ConstantArray.lua（注入结构）
- 对口开源工具：disrobe、Prometheus-DeobfuscatorV2（仅参考）

## 版本记录

- v1.0.0：DeltaUI 反混淆工具页面基础功能（V1 数字化简 + 沙箱执行 + VM 状态追踪）
- 当前：V2 通用反编译器开发中，Python 原型前端管线 100% 验证通过，中端/后端已实现待完整验证
