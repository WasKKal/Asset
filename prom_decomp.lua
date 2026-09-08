-- prom_decomp.lua — Prometheus Vmify 反编译器（Lua 5.3 / Luau 自包含模块）
-- 提供 deobfWeAreDevFull(code) -> 反编译后的 Lua 源码字符串

local M = {}

-- ============================================================
-- 工具函数
-- ============================================================

local function isDigit(b) return b >= 48 and b <= 57 end
local function isAlpha(b) return (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b == 95 end
local function isAlnum(b) return isAlpha(b) or isDigit(b) end
local function isSpace(b) return b == 32 or b == 9 or b == 13 or b == 10 end
local function isPrint(b) return b >= 32 and b < 127 end

-- Python 风格取模（对负数行为一致）
local function pymod(a, b) return a - math.floor(a / b) * b end

-- 判断是否为 AST 数组表（模拟 Python tuple）
local function isAst(e) return type(e) == "table" and e[1] ~= nil end

-- 深拷贝 AST（数组表）
local function astCopy(e)
  if type(e) ~= "table" then return e end
  local r = {}
  for k, v in pairs(e) do
    if type(k) == "number" then
      r[k] = astCopy(v)
    else
      r[k] = astCopy(v)
    end
  end
  return r
end

-- 表是否为数组（整数键 1..n）
local function isArray(t)
  if type(t) ~= "table" then return false end
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n == #t
end

-- set 操作（用 table 键=true 模拟）
local function setAdd(s, k) s[k] = true end
local function setHas(s, k) return s[k] == true end
local function setUnion(a, b)
  local r = {}
  for k in pairs(a) do r[k] = true end
  for k in pairs(b) do r[k] = true end
  return r
end
local function setIntersection(a, b)
  local r = {}
  for k in pairs(a) do if b[k] then r[k] = true end end
  return r
end
local function setDiff(a, b)
  local r = {}
  for k in pairs(a) do if not b[k] then r[k] = true end end
  return r
end
local function setSize(s)
  local n = 0
  for _ in pairs(s) do n = n + 1 end
  return n
end
local function setToList(s)
  local r = {}
  for k in pairs(s) do r[#r + 1] = k end
  return r
end

-- 字符串工具
local function strStartsWith(s, prefix, start)
  start = start or 1
  return s:sub(start, start + #prefix - 1) == prefix
end

-- 检查字符串是否为合法 ASCII 标识符
local function isIdent(s)
  if #s == 0 then return false end
  local b = s:byte(1)
  if not isAlpha(b) then return false end
  for i = 2, #s do
    if not isAlnum(s:byte(i)) then return false end
  end
  return true
end

-- 检查字符串是否全部可打印（允许常见空白）
local function isPrintableText(s)
  for i = 1, #s do
    local b = s:byte(i)
    if not (isPrint(b) or b == 9 or b == 10 or b == 13) then
      return false
    end
  end
  return true
end

-- 检查字节序列是否为合法 UTF-8
local function isValidUTF8(s)
  local i = 1
  local n = #s
  while i <= n do
    local b = s:byte(i)
    if b < 0x80 then
      i = i + 1
    elseif b < 0xC2 then
      return false
    elseif b < 0xE0 then
      if i + 1 > n then return false end
      local b2 = s:byte(i + 1)
      if b2 < 0x80 or b2 >= 0xC0 then return false end
      i = i + 2
    elseif b < 0xF0 then
      if i + 2 > n then return false end
      local b2 = s:byte(i + 1)
      local b3 = s:byte(i + 2)
      if b2 < 0x80 or b2 >= 0xC0 then return false end
      if b3 < 0x80 or b3 >= 0xC0 then return false end
      if b == 0xE0 and b2 < 0xA0 then return false end
      if b == 0xED and b2 >= 0xA0 then return false end
      i = i + 3
    elseif b < 0xF5 then
      if i + 3 > n then return false end
      local b2 = s:byte(i + 1)
      local b3 = s:byte(i + 2)
      local b4 = s:byte(i + 3)
      if b2 < 0x80 or b2 >= 0xC0 then return false end
      if b3 < 0x80 or b3 >= 0xC0 then return false end
      if b4 < 0x80 or b4 >= 0xC0 then return false end
      if b == 0xF0 and b2 < 0x90 then return false end
      if b == 0xF4 and b2 >= 0x90 then return false end
      i = i + 4
    else
      return false
    end
  end
  return true
end

-- ============================================================
-- 词法分析器
-- ============================================================

local KEYWORDS = {
  ["and"]=true,["break"]=true,["do"]=true,["else"]=true,["elseif"]=true,
  ["end"]=true,["false"]=true,["for"]=true,["function"]=true,["if"]=true,
  ["in"]=true,["local"]=true,["nil"]=true,["not"]=true,["or"]=true,
  ["repeat"]=true,["return"]=true,["then"]=true,["true"]=true,
  ["until"]=true,["while"]=true,["continue"]=true,
}

local OPS = {"...","..","==","~=","<=",">=","::","->",
  "+","-","*","/","%","^","#","(",")","{","}","[","]",";",":",",",".","=","<",">"}

local function lex(s)
  local toks = {}
  local i = 1
  local n = #s
  local function peekByte(offset)
    local idx = i + (offset or 0)
    if idx > n then return nil end
    return s:byte(idx)
  end
  local function processOne()
    local c = s:byte(i)
    -- 空白
    if isSpace(c) then i = i + 1; return end
    -- 注释
    if c == 45 and i + 1 <= n and s:byte(i + 1) == 45 then
      -- 长注释?
      local lb_eq, lb_start = nil, nil
      if i + 2 <= n and s:byte(i + 2) == 91 then
        local j = i + 3
        local eq = 0
        while j <= n and s:byte(j) == 61 do eq = eq + 1; j = j + 1 end
        if j <= n and s:byte(j) == 91 then
          lb_eq = eq; lb_start = j + 1
        end
      end
      if lb_eq ~= nil then
        local close = "]" .. string.rep("=", lb_eq) .. "]"
        local k = s:find(close, lb_start, true)
        if k then i = k + #close else i = n + 1 end
        return
      end
      -- 行注释
      local j = s:find("\n", i, true)
      if j then i = j else i = n + 1 end
      return
    end
    -- 数字
    if isDigit(c) or (c == 46 and i + 1 <= n and isDigit(s:byte(i + 1))) then
      local j = i
      -- 十六进制
      if c == 48 and i + 1 <= n and (s:byte(i + 1) == 120 or s:byte(i + 1) == 88) then
        j = i + 2
        while j <= n and isAlnum(s:byte(j)) do j = j + 1 end
      else
        while j <= n and isDigit(s:byte(j)) do j = j + 1 end
        if j <= n and s:byte(j) == 46 then j = j + 1 end
        while j <= n and isDigit(s:byte(j)) do j = j + 1 end
        if j <= n and (s:byte(j) == 101 or s:byte(j) == 69) then
          j = j + 1
          if j <= n and (s:byte(j) == 43 or s:byte(j) == 45) then j = j + 1 end
          while j <= n and isDigit(s:byte(j)) do j = j + 1 end
        end
      end
      local num = s:sub(i, j - 1)
      toks[#toks + 1] = {k = "NUMBER", v = num, p = i}
      i = j
      return
    end
    -- 标识符/关键字
    if isAlpha(c) then
      local j = i
      while j <= n and isAlnum(s:byte(j)) do j = j + 1 end
      local w = s:sub(i, j - 1)
      local kind = KEYWORDS[w] and w or "NAME"
      toks[#toks + 1] = {k = kind, v = w, p = i}
      i = j
      return
    end
    -- 字符串
    if c == 34 or c == 39 then
      local quote = c
      local j = i + 1
      local buf = {}
      while j <= n do
        local ch = s:byte(j)
        if ch == quote then j = j + 1; break end
        if ch == 92 then
          local nx = (j + 1 <= n) and s:byte(j + 1) or 0
          if isDigit(nx) then
            local k = j + 1
            local cnt = 0
            while k <= n and isDigit(s:byte(k)) and cnt < 3 do k = k + 1; cnt = cnt + 1 end
            local val = tonumber(s:sub(j + 1, k - 1))
            buf[#buf + 1] = string.char(val)
            j = k
          else
            local esc = {[110]="\n",[116]="\t",[114]="\r",[97]="\a",[98]="\b",
              [102]="\f",[118]="\v",[92]="\\",[34]='"',[39]="'",[10]="\n"}
            buf[#buf + 1] = esc[nx] or string.char(nx)
            j = j + 2
          end
        else
          buf[#buf + 1] = string.char(ch)
          j = j + 1
        end
      end
      toks[#toks + 1] = {k = "STRING", v = table.concat(buf), p = i}
      i = j
      return
    end
    -- 长字符串
    if c == 91 then
      local j = i + 1
      local eq = 0
      while j <= n and s:byte(j) == 61 do eq = eq + 1; j = j + 1 end
      if j <= n and s:byte(j) == 91 then
        local start = j + 1
        local close = "]" .. string.rep("=", eq) .. "]"
        local k = s:find(close, start, true)
        local content = k and s:sub(start, k - 1) or ""
        toks[#toks + 1] = {k = "STRING", v = content, p = i}
        i = k and (k + #close) or (n + 1)
        return
      end
    end
    -- 运算符
    local matched = false
    for _, op in ipairs(OPS) do
      if strStartsWith(s, op, i) then
        toks[#toks + 1] = {k = "OP", v = op, p = i}
        i = i + #op
        matched = true
        break
      end
    end
    if not matched then
      error("无法识别字符 @" .. i .. ": " .. s:sub(math.max(1, i - 20), i + 20))
    end
  end
  while i <= n do
    processOne()
  end
  toks[#toks + 1] = {k = "EOF", v = nil, p = n + 1}
  return toks
end

M.lex = lex

-- ============================================================
-- 解析器
-- ============================================================

local Parser = {}
Parser.__index = Parser

function Parser.new(toks)
  local self = setmetatable({}, Parser)
  self.t = toks
  self.i = 1
  return self
end

function Parser:peek(k)
  k = k or 0
  return self.t[math.min(self.i + k, #self.t)]
end

function Parser:next()
  local t = self.t[self.i]
  self.i = self.i + 1
  return t
end

function Parser:accept(v)
  local t = self:peek()
  if t.k == v then return self:next() end
  if t.k == "OP" and t.v == v then return self:next() end
  return nil
end

function Parser:expect(v)
  local t = self:peek()
  if t.k == v or (t.k == "OP" and t.v == v) then return self:next() end
  error("期望 " .. v .. " 得到 " .. tostring(t.k) .. ":" .. tostring(t.v))
end

function Parser:atOp(v)
  local t = self:peek()
  return t.k == "OP" and t.v == v
end

function Parser:atKw(v)
  return self:peek().k == v
end

local BIN_PRI = {
  ["or"]={1,1},["and"]={2,2},
  ["<"]={3,3},[">"]={3,3},["<="]={3,3},[">="]={3,3},["~="]={3,3},["=="]={3,3},
  [".."]={5,4},
  ["+"]={6,6},["-"]={6,6},
  ["*"]={7,7},["/"]={7,7},["%"]={7,7},
  ["^"]={9,8},
}

function Parser:expr(limit)
  limit = limit or 0
  local left
  local t = self:peek()
  if t.k == "not" or (t.k == "OP" and (t.v == "-" or t.v == "#")) then
    local op
    if t.k == "OP" then op = self:next().v else op = self:next().k end
    local v = self:expr(8)
    left = {"un", op, v}
  else
    left = self:simple()
  end
  while true do
    t = self:peek()
    local op
    if t.k == "OP" then op = t.v
    elseif t.k == "and" or t.k == "or" then op = t.k
    else op = nil end
    local pri = BIN_PRI[op]
    if not pri then break end
    local lp, rp = pri[1], pri[2]
    if lp <= limit then break end
    self:next()
    local right = self:expr(rp)
    left = {"bin", op, left, right}
  end
  return left
end

function Parser:simple()
  local t = self:peek()
  local e
  if t.k == "NUMBER" then
    self:next()
    local txt = t.v
    local val
    if txt:lower():sub(1, 2) == "0x" then
      val = tonumber(txt, 16)
    elseif txt:find("%.") or txt:lower():find("e") then
      val = tonumber(txt)
    else
      val = tonumber(txt)
    end
    e = {"num", val}
  elseif t.k == "STRING" then
    self:next()
    e = {"str", t.v}
  elseif t.k == "nil" then self:next(); e = {"nil",}
  elseif t.k == "true" then self:next(); e = {"true",}
  elseif t.k == "false" then self:next(); e = {"false",}
  elseif t.k == "..." or self:atOp("...") then self:next(); e = {"vararg",}
  elseif t.k == "function" then
    e = self:parse_func()
  elseif self:atOp("(") then
    self:next()
    e = self:expr(0)
    self:expect(")")
  elseif t.k == "NAME" then
    self:next()
    e = {"var", t.v}
  elseif self:atOp("{") then
    e = self:parse_table()
  else
    error("无法解析表达式开头 " .. tostring(t.k) .. ":" .. tostring(t.v))
  end
  -- 后缀
  while true do
    if self:atOp("[") then
      self:next()
      local k = self:expr(0)
      self:expect("]")
      e = {"index", e, k}
    elseif self:atOp(".") then
      self:next()
      local name = self:expect("NAME").v
      e = {"index", e, {"str", name}}
    elseif self:atOp(":") then
      self:next()
      local meth = self:expect("NAME").v
      local args = self:parse_call_args()
      e = {"selfcall", e, meth, args}
    elseif self:atOp("(") or self:atOp("{") or self:peek().k == "STRING" then
      local args = self:parse_call_args()
      e = {"call", e, args}
    else
      break
    end
  end
  return e
end

function Parser:parse_call_args()
  if self:atOp("(") then
    self:next()
    local args = {}
    if not self:atOp(")") then
      args[#args + 1] = self:expr(0)
      while self:atOp(",") do
        self:next()
        args[#args + 1] = self:expr(0)
      end
    end
    self:expect(")")
    return args
  end
  if self:atOp("{") then
    return {self:parse_table()}
  end
  if self:peek().k == "STRING" then
    return {{"str", self:next().v}}
  end
  error("调用参数错误")
end

function Parser:parse_table()
  self:expect("{")
  local entries = {}
  while not self:atOp("}") do
    if self:atOp("[") then
      self:next()
      local k = self:expr(0)
      self:expect("]")
      self:expect("=")
      local v = self:expr(0)
      entries[#entries + 1] = {k, v}
    else
      if self:peek().k == "NAME" and self:peek(1).k == "OP" and self:peek(1).v == "=" then
        local name = self:next().v
        self:next()
        local v = self:expr(0)
        entries[#entries + 1] = {{"str", name}, v}
      else
        local v = self:expr(0)
        entries[#entries + 1] = {nil, v}
      end
    end
    if self:atOp(",") or self:atOp(";") then self:next() else break end
  end
  self:expect("}")
  return {"table", entries}
end

function Parser:parse_func()
  self:expect("function")
  self:expect("(")
  local params = {}
  if not self:atOp(")") then
    while true do
      local t = self:next()
      local pname
      if t.k == "..." or (t.k == "OP" and t.v == "...") then pname = "..."
      else pname = t.v end
      params[#params + 1] = pname
      if not self:atOp(",") then break end
      self:next()
    end
  end
  self:expect(")")
  -- 平衡块
  local depth = 1
  local start = self.i
  local opener = {["function"]=true,["if"]=true,["for"]=true,["while"]=true}
  while self.i <= #self.t and depth > 0 do
    local k = self:next().k
    if opener[k] then depth = depth + 1
    elseif k == "repeat" then depth = depth + 1
    elseif k == "end" or k == "until" then depth = depth - 1 end
  end
  return {"func", params, {start, self.i}}
end

function Parser:parse_linestats(stop_kws)
  stop_kws = stop_kws or {["elseif"]=true, ["else"]=true, ["end"]=true, ["until"]=true}
  local stats = {}
  while true do
    local t = self:peek()
    if t.k == "EOF" then break end
    if stop_kws[t.k] then break end
    stats[#stats + 1] = self:one_statement()
  end
  return stats
end

function Parser:one_statement()
  local t = self:peek()
  if t.k == "local" then
    self:next()
    self:accept("function")
    local names = {}
    names[#names + 1] = self:expect("NAME").v
    while self:atOp(",") do
      self:next()
      names[#names + 1] = self:expect("NAME").v
    end
    local exprs = {}
    if self:atOp("=") then
      self:next()
      exprs[#exprs + 1] = self:expr(0)
      while self:atOp(",") do self:next(); exprs[#exprs + 1] = self:expr(0) end
    end
    return {"local", names, exprs}
  end
  if t.k == "return" then
    self:next()
    local exprs = {}
    local pk = self:peek().k
    if not (pk == "end" or pk == "else" or pk == "elseif" or pk == "until" or pk == "EOF" or
            (pk == "OP" and self:peek().v == ";")) then
      exprs[#exprs + 1] = self:expr(0)
      while self:atOp(",") do self:next(); exprs[#exprs + 1] = self:expr(0) end
    end
    self:accept(";")
    return {"return", exprs}
  end
  if t.k == "do" then
    self:next()
    local body = self:parse_linestats({["end"]=true})
    self:expect("end")
    return {"do", body}
  end
  -- 表达式起始：赋值或调用语句
  local lhs = {self:parse_lvalue_or_expr()}
  while self:atOp(",") do
    self:next()
    lhs[#lhs + 1] = self:parse_lvalue_or_expr()
  end
  if self:atOp("=") then
    self:next()
    local rhs = {self:expr(0)}
    while self:atOp(",") do self:next(); rhs[#rhs + 1] = self:expr(0) end
    return {"assign", lhs, rhs}
  end
  if #lhs == 1 then return {"callstmt", lhs[1]} end
  error("意外的多表达式语句")
end

function Parser:parse_lvalue_or_expr()
  local e = self:simple()
  while true do
    local tt = self:peek()
    local op
    if tt.k == "OP" then op = tt.v
    elseif tt.k == "and" or tt.k == "or" then op = tt.k
    else op = nil end
    local pri = BIN_PRI[op]
    if not pri then break end
    self:next()
    local r = self:expr(pri[2])
    e = {"bin", op, e, r}
  end
  return e
end

M.Parser = Parser

local function parse_expr_str(s)
  local p = Parser.new(lex(s))
  return p:expr(0)
end
M.parse_expr_str = parse_expr_str

-- ============================================================
-- AST 工具
-- ============================================================

local function eval_const(e)
  if not isAst(e) then return nil end
  local k = e[1]
  if k == "num" then return e end
  if k == "un" and e[2] == "-" then
    local v = eval_const(e[3])
    if v then return {"num", -v[2]} end
  end
  if k == "un" and e[2] == "not" then
    local v = eval_const(e[3])
    if v ~= nil then
      return (not M.truthy(v)) and {"true",} or {"false",}
    end
  end
  if k == "bin" then
    local op = e[2]
    local l = eval_const(e[3])
    local r = eval_const(e[4])
    if l ~= nil and r ~= nil and l[1] == "num" and r[1] == "num" then
      local a, b = l[2], r[2]
      if op == "+" then return {"num", a + b} end
      if op == "-" then return {"num", a - b} end
      if op == "*" then return {"num", a * b} end
      if op == "/" then return {"num", a / b} end
      if op == "%" then return {"num", pymod(a, b)} end
      if op == "^" then return {"num", a ^ b} end
      if op == "==" then return (a == b) and {"true",} or {"false",} end
      if op == "~=" then return (a ~= b) and {"true",} or {"false",} end
      if op == "<" then return (a < b) and {"true",} or {"false",} end
      if op == ">" then return (a > b) and {"true",} or {"false",} end
      if op == "<=" then return (a <= b) and {"true",} or {"false",} end
      if op == ">=" then return (a >= b) and {"true",} or {"false",} end
    end
  end
  return nil
end
M.eval_const = eval_const

function M.truthy(node)
  if not isAst(node) then return true end
  local k = node[1]
  if k == "false" or k == "nil" then return false end
  if k == "true" then return true end
  if k == "num" then return node[2] ~= 0 end
  if k == "str" then return #node[2] > 0 end
  return true
end

local function walk(e, fn)
  if not isAst(e) then return e end
  local k = e[1]
  if k == "num" or k == "str" or k == "nil" or k == "true" or k == "false" or k == "vararg" then
    return fn(e)
  end
  if k == "var" then return fn(e) end
  if k == "un" then return fn({"un", e[2], walk(e[3], fn)}) end
  if k == "bin" then return fn({"bin", e[2], walk(e[3], fn), walk(e[4], fn)}) end
  if k == "index" then return fn({"index", walk(e[2], fn), walk(e[3], fn)}) end
  if k == "call" then
    local args = {}
    for _, a in ipairs(e[3]) do args[#args + 1] = walk(a, fn) end
    return fn({"call", walk(e[2], fn), args})
  end
  if k == "selfcall" then
    local args = {}
    for _, a in ipairs(e[4]) do args[#args + 1] = walk(a, fn) end
    return fn({"selfcall", walk(e[2], fn), e[3], args})
  end
  if k == "table" then
    local entries = {}
    for _, kv in ipairs(e[2]) do
      local kk = kv[1] and walk(kv[1], fn) or nil
      entries[#entries + 1] = {kk, walk(kv[2], fn)}
    end
    return fn({"table", entries})
  end
  if k == "func" then return fn(e) end
  return fn(e)
end
M.walk = walk

local function used_vars(e, acc)
  acc = acc or {}
  local function fn(n)
    if isAst(n) and n[1] == "var" then acc[n[2]] = true end
    return n
  end
  walk(e, fn)
  return acc
end
M.used_vars = used_vars

local function substitute(e, mapping)
  local function fn(n)
    if isAst(n) and n[1] == "var" and mapping[n[2]] ~= nil then
      n = mapping[n[2]]
    end
    local c = eval_const(n)
    return c ~= nil and c or n
  end
  return walk(e, fn)
end
M.substitute = substitute

local function lua_str_escape(s)
  -- 尝试简单字符偏移解密（每个字符加上35）
  if #s > 0 then
    local all_printable = true
    local decrypted = {}
    for i = 1, #s do
      local b = s:byte(i)
      if b < 32 or b > 126 then
        all_printable = false
        break
      end
      local db = b + 35
      if db < 32 or db > 126 then
        all_printable = false
        break
      end
      decrypted[i] = string.char(db)
    end
    if all_printable then
      s = table.concat(decrypted)
    end
  end
  local out = {'"'}
  for i = 1, #s do
    local b = s:byte(i)
    local ch = string.char(b)
    if ch == '"' then out[#out + 1] = '\\"'
    elseif ch == '\\' then out[#out + 1] = '\\\\'
    elseif ch == '\n' then out[#out + 1] = '\\n'
    elseif ch == '\r' then out[#out + 1] = '\\r'
    elseif ch == '\t' then out[#out + 1] = '\\t'
    elseif b >= 32 and b < 127 then out[#out + 1] = ch
    elseif b < 32 or b == 127 then out[#out + 1] = string.format("\\%03d", b)
    else out[#out + 1] = ch end  -- 非ASCII直接输出（UTF-8字节）
  end
  out[#out + 1] = '"'
  return table.concat(out)
end
M.lua_str_escape = lua_str_escape

local function _pri(op)
  if op == "or" then return 1 end
  if op == "and" then return 2 end
  if op == "<" or op == ">" or op == "<=" or op == ">=" or op == "~=" or op == "==" then return 3 end
  if op == ".." then return 5 end
  if op == "+" or op == "-" then return 6 end
  if op == "*" or op == "/" or op == "%" then return 7 end
  if op == "^" then return 9 end
  return 10
end

local function expr_lua(e, parent_pri, side)
  parent_pri = parent_pri or 0
  side = side or 0
  if not isAst(e) then return tostring(e) end
  local k = e[1]
  if k == "num" then
    local v = e[2]
    if type(v) == "number" and v == math.floor(v) and math.abs(v) < 1e15 then
      return tostring(math.floor(v))
    end
    return tostring(v)
  end
  if k == "str" then
    local s = e[2]
    -- 尝试简单字符偏移解密（每个字符加上35）
    if #s > 0 then
      local all_printable = true
      local decrypted = {}
      for i = 1, #s do
        local b = s:byte(i)
        if b < 32 or b > 126 then
          all_printable = false
          break
        end
        local db = b + 35
        if db < 32 or db > 126 then
          all_printable = false
          break
        end
        decrypted[i] = string.char(db)
      end
      if all_printable then
        s = table.concat(decrypted)
      end
    end
    return lua_str_escape(s)
  end
  if k == "nil" then return "nil" end
  if k == "true" then return "true" end
  if k == "false" then return "false" end
  if k == "vararg" then return "..." end
  if k == "var" then return e[2] end
  if k == "un" then
    local op = e[2]
    if op == "not" or op == "#" then
      return op .. " " .. expr_lua(e[3], 8)
    end
    return op .. expr_lua(e[3], 8)
  end
  if k == "index" then
    local base = expr_lua(e[2], 10)
    local key = e[3]
    if isAst(key) and key[1] == "str" and isIdent(key[2]) then
      return base .. "." .. key[2]
    end
    return base .. "[" .. expr_lua(key) .. "]"
  end
  if k == "bin" then
    local op = e[2]
    local my = _pri(op)
    local s = expr_lua(e[3], my, 0) .. " " .. op .. " " .. expr_lua(e[4], my, 1)
    if my < parent_pri then return "(" .. s .. ")" end
    return s
  end
  if k == "call" then
    local args = {}
    for _, a in ipairs(e[3]) do args[#args + 1] = expr_lua(a) end
    return expr_lua(e[2], 10) .. "(" .. table.concat(args, ", ") .. ")"
  end
  if k == "selfcall" then
    local args = {}
    for _, a in ipairs(e[4]) do args[#args + 1] = expr_lua(a) end
    return expr_lua(e[2], 10) .. ":" .. e[3] .. "(" .. table.concat(args, ", ") .. ")"
  end
  if k == "table" then
    local parts = {}
    for _, kv in ipairs(e[2]) do
      if kv[1] then
        parts[#parts + 1] = "[" .. expr_lua(kv[1]) .. "]=" .. expr_lua(kv[2])
      else
        parts[#parts + 1] = expr_lua(kv[2])
      end
    end
    return "{" .. table.concat(parts, ", ") .. "}"
  end
  if k == "func" then return "function(...) --[[func]] end" end
  return tostring(e)
end
M.expr_lua = expr_lua

-- ============================================================
-- 常量数组恢复
-- ============================================================

local function find_const_array(code, toks)
  if not toks then toks = lex(code) end
  for i = 1, #toks - 3 do
    if toks[i].k == "local" and toks[i+1].k == "NAME" and
       toks[i+2].k == "OP" and toks[i+2].v == "=" and
       toks[i+3].k == "OP" and toks[i+3].v == "{" then
      local name = toks[i+1].v
      local subtoks = {}
      for j = i+3, #toks do subtoks[#subtoks+1] = toks[j] end
      local p = Parser.new(subtoks)
      local node = p:parse_table()
      if isAst(node) and node[1] == "table" and #node[2] > 10 then
        local vals = {}
        local ok = true
        for _, kv in ipairs(node[2]) do
          if kv[1] ~= nil or not isAst(kv[2]) or kv[2][1] ~= "str" then
            ok = false; break
          end
          vals[#vals+1] = kv[2][2]  -- 保持为字符串（latin1字节）
        end
        if ok then return name, vals, i end
      end
    end
  end
  return nil, nil, nil
end

local function _eval_arith(expr)
  local ok, p = pcall(function()
    local pp = Parser.new(lex(expr))
    return pp:expr()
  end)
  if not ok then return 0 end
  local c = eval_const(p)
  return c and c[2] or 0
end

local function find_wrapper(code, arrvar)
  -- 用 token 方式精确匹配 wrapper 函数
  local toks = lex(code)
  for i = 1, #toks - 8 do
    if toks[i].k == "local" and toks[i+1].k == "function" and
       toks[i+2].k == "NAME" and toks[i+3].k == "OP" and toks[i+3].v == "(" and
       toks[i+4].k == "NAME" and toks[i+5].k == "OP" and toks[i+5].v == ")" and
       toks[i+6].k == "return" and
       toks[i+7].k == "NAME" and toks[i+7].v == arrvar and
       toks[i+8].k == "OP" and toks[i+8].v == "[" and
       toks[i+9].k == "NAME" and toks[i+9].v == toks[i+4].v and
       (toks[i+10].k == "OP" and (toks[i+10].v == "+" or toks[i+10].v == "-")) then
      local fname = toks[i+2].v
      local sign = toks[i+10].v
      -- 收集表达式直到 ]
      local expr_toks = {}
      local j = i + 11
      local depth = 0
      while j <= #toks do
        local k = toks[j].k
        local v = toks[j].v
        if k == "OP" and (v == "(" or v == "{") then depth = depth + 1
        elseif k == "OP" and (v == ")" or v == "}") then depth = depth - 1
        elseif k == "OP" and v == "]" and depth == 0 then break end
        expr_toks[#expr_toks+1] = toks[j]
        j = j + 1
      end
      -- 将表达式token转为字符串并求值
      local expr_str = {}
      for _, t in ipairs(expr_toks) do
        if t.k == "NUMBER" then expr_str[#expr_str+1] = t.v
        elseif t.k == "OP" then expr_str[#expr_str+1] = t.v
        elseif t.k == "NAME" then expr_str[#expr_str+1] = t.v
        else expr_str[#expr_str+1] = t.v or "" end
      end
      local off = _eval_arith(table.concat(expr_str, " "))
      return fname, (sign == "+" and off or -off)
    end
  end
  return nil, 0
end

local function find_reverse_ranges(code, toks)
  if not toks then toks = lex(code) end
  local ranges = {}
  for i = 1, #toks - 2 do
    if toks[i].k == "NAME" and toks[i].v == "ipairs" and
       toks[i+1].k == "OP" and toks[i+1].v == "(" and
       toks[i+2].k == "OP" and toks[i+2].v == "{" then
      local subtoks = {}
      for j = i+2, #toks do subtoks[#subtoks+1] = toks[j] end
      local p = Parser.new(subtoks)
      local node = p:parse_table()
      if isAst(node) and node[1] == "table" then
        local rr = {}
        local ok = true
        for _, kv in ipairs(node[2]) do
          if kv[1] ~= nil or not isAst(kv[2]) or kv[2][1] ~= "table" or #kv[2][2] ~= 2 then
            ok = false; break
          end
          local a = eval_const(kv[2][2][1][2])
          local b = eval_const(kv[2][2][2][2])
          if not a or not b then ok = false; break end
          rr[#rr+1] = {math.floor(a[2]), math.floor(b[2])}
        end
        if ok and #rr > 0 then ranges = rr; break end
      end
    end
  end
  return ranges
end

local function apply_reverse(arr, ranges)
  local a = {}
  for i, v in ipairs(arr) do a[i] = v end
  for _, r in ipairs(ranges) do
    local lo, hi = r[1], r[2]
    local i, j = lo, hi
    while i < j do
      a[i], a[j] = a[j], a[i]
      i = i + 1; j = j - 1
    end
  end
  return a
end

local function find_lookup_table(code, toks)
  if not toks then toks = lex(code) end
  local best = nil
  local function checkTable(i)
    if toks[i].k ~= "OP" or toks[i].v ~= "{" then return end
    local subtoks = {}
    for j = i, #toks do subtoks[#subtoks+1] = toks[j] end
    local p = Parser.new(subtoks)
    local ok, node = pcall(function() return p:parse_table() end)
    if not ok or not isAst(node) or node[1] ~= "table" then return end
    local mp = {}
    local cnt = 0
    local ok2 = true
    for _, kv in ipairs(node[2]) do
      if kv[1] == nil or not isAst(kv[1]) or kv[1][1] ~= "str" or #kv[1][2] ~= 1 then
        ok2 = false; break
      end
      local c = eval_const(kv[2])
      if not c or c[1] ~= "num" then ok2 = false; break end
      mp[kv[1][2]] = math.floor(c[2])
      cnt = cnt + 1
    end
    if ok2 and cnt >= 60 then
      local vals = {}
      for _, v in pairs(mp) do vals[v] = true end
      local all64 = true
      for v = 0, 63 do if not vals[v] then all64 = false; break end end
      if all64 then best = mp end
    end
  end
  for i = 1, #toks do checkTable(i) end
  return best
end

local function b64_decode(s, char2val)
  -- s: 字符串（latin1字节），char2val: char->idx
  local out = {}
  local value = 0
  local count = 0
  local length = #s
  local index = 1
  while index <= length do
    local ch = s:sub(index, index)
    local code = char2val[ch]
    if code ~= nil then
      value = value + code * (64 ^ (3 - count))
      count = count + 1
      if count == 4 then
        count = 0
        local c1 = math.floor(value / 65536)
        local c2 = math.floor((value % 65536) / 256)
        local c3 = value % 256
        out[#out+1] = string.char(c1)
        out[#out+1] = string.char(c2)
        out[#out+1] = string.char(c3)
        value = 0
      end
    elseif ch == "=" then
      out[#out+1] = string.char(math.floor(value / 65536))
      local nextch = (index + 1 <= length) and s:sub(index+1, index+1) or ""
      if index >= length or nextch ~= "=" then
        out[#out+1] = string.char(math.floor((value % 65536) / 256))
      end
      break
    end
    index = index + 1
  end
  return table.concat(out)
end

local function recover_constants(code)
  local toks = lex(code)
  local arrvar, raw = find_const_array(code, toks)
  if not raw then error("未找到常量数组") end
  local wname, off = find_wrapper(code, arrvar)
  local ranges = find_reverse_ranges(code, toks)
  local rev = apply_reverse(raw, ranges)
  local lookup = find_lookup_table(code, toks)
  if not lookup then error("未找到base64字母表") end
  local final = {}
  for i, elem in ipairs(rev) do
    local ok, decoded = pcall(b64_decode, elem, lookup)
    if ok then final[i] = decoded else final[i] = elem end
  end
  return {arrvar=arrvar, wrapper=wname, offset=off, final=final, raw_count=#raw}
end

local function _bytes_node(b)
  -- b 是 latin1 字节字符串，尝试按 UTF-8 解释
  if isValidUTF8(b) then return {"str", b} end
  return {"str", b}  -- 保持原样
end

local function make_inliner(ci)
  local final = ci.final
  local off = ci.offset
  local w = ci.wrapper
  local av = ci.arrvar
  local function _idx(e)
    local c = eval_const(e)
    if c and c[1] == "num" then
      local v = c[2]
      return (v == math.floor(v)) and math.floor(v) or v
    end
    return nil
  end
  local function fn(e)
    if isAst(e) and e[1] == "call" and isAst(e[2]) and e[2][1] == "var" and e[2][2] == w and #e[3] == 1 then
      local idx = _idx(e[3][1])
      if idx ~= nil and final[idx + off] ~= nil then
        return _bytes_node(final[idx + off])
      end
    end
    if isAst(e) and e[1] == "index" and isAst(e[2]) and e[2][1] == "var" and e[2][2] == av then
      local idx = _idx(e[3])
      if idx ~= nil and final[idx] ~= nil then
        return _bytes_node(final[idx])
      end
    end
    return e
  end
  return function(e) return walk(e, fn) end
end

M.recover_constants = recover_constants
M.make_inliner = make_inliner

-- ============================================================
-- 字符串解密（LCG）
-- ============================================================

local M45 = 35184372088832.0
local M32 = 4294967296.0
local M16 = 65536.0

local function LcgDecryptor_new(mul45, add45, mul8, key8)
  local self = {
    mul45 = mul45 + 0.0,
    add45 = add45 + 0.0,
    mul8 = mul8 + 0.0,
    key8 = key8 % 256,
    s45 = 0, s8 = 0, prev = {},
  }
  function self:_set_seed(seed)
    self.s45 = pymod(seed + 0.0, M45)
    self.s8 = pymod(seed + 0.0, 255.0) + 2.0
    self.prev = {}
  end
  function self:_rand32()
    self.s45 = pymod(self.s45 * self.mul45 + self.add45, M45)
    while true do
      self.s8 = pymod(self.s8 * self.mul8, 257.0)
      if self.s8 ~= 1.0 then break end
    end
    local r = pymod(self.s8, 32.0)
    local shift = 13.0 - (self.s8 - r) / 32.0
    local n = math.floor(self.s45 / (2.0 ^ shift)) % M32 / (2.0 ^ r)
    return math.floor(pymod(n, 1.0) * M32) + math.floor(n)
  end
  function self:_next_byte()
    if #self.prev == 0 then
      local rnd = self:_rand32()
      local low = pymod(rnd, M16)
      local high = (rnd - low) / M16
      local b1 = pymod(low, 256.0)
      local b2 = (low - b1) / 256.0
      local b3 = pymod(high, 256.0)
      local b4 = (high - b3) / 256.0
      self.prev = {b1, b2, b3, b4}
    end
    return table.remove(self.prev)
  end
  function self:decrypt(enc, seed)
    -- enc: 字符串（latin1字节）
    self:_set_seed(seed)
    local prev = self.key8
    local out = {}
    for i = 1, #enc do
      local byte = enc:byte(i)
      local prb = self:_next_byte()
      prev = pymod(byte + prb + prev, 256)
      out[#out+1] = string.char(math.floor(prev))
    end
    return table.concat(out)
  end
  return self
end

local function _utf8_ok(b)
  return isValidUTF8(b)
end

local function brute_key8(mul45, add45, mul8, pairs)
  local sample = pairs
  if #pairs > 400 then
    sample = {}
    for i = 1, 400 do sample[i] = pairs[i] end
  end
  local best = nil
  local bestscore = -1
  local function _has_ctrl(s)
    for i = 1, #s do
      local b = s:byte(i)
      if b < 0x20 and b ~= 0x09 then return true end
    end
    return false
  end
  local _common_chars = {}
  for _, c in ipairs({"，","。","！","？","：","；","、","的","一","是","在","有","和","等","不","了","人","我","他","这","中","大","为","上","个","国","以","到","说","们","要","你","会","着","没","那","好","自","也","很","去","时","过","家","学","只","如","起","把","还","多","小","都","就","她","从","想","实","看","正","心","样","仍","比","或","但","质","气","第","向","道","命","此","变","条","结","解","问","意","建","月","青","边","红","听","则","完","却","千","吃","做","叫","当","住","给","活","走","先","师","写","快","功","能","正","常","暴","力","升","级","声","誉","自","动","开","关","文","件","保","存","删","除","选","择","确","定","取","消","完","成","失","败","错","误","警","告","提","示","信","息","代","码","脚","本","模","块","页","面","工","具","菜","单","按","钮","标","题","内","容","数","据","变","量","函","数","循","环","条","件","返","回","调","用","引","用","声","明","定","义","声","明"}) do
    _common_chars[c] = true
  end
  local function _meaning_score(s)
    local sc = 0
    local ok, err = pcall(function()
      for p, c in utf8.codes(s) do
        local ch = utf8.char(c)
        if _common_chars[ch] then sc = sc + 0.3 end
        if c >= 32 and c <= 126 then sc = sc + 0.1 end
        if c >= 0x4E00 and c <= 0x9FFF then sc = sc + 0.05 end
      end
    end)
    return math.min(sc, 3.0)
  end
  for k = 0, 255 do
    local d = LcgDecryptor_new(mul45, add45, mul8, k)
    local sc = 0
    for _, p in ipairs(sample) do
      local ok, result = pcall(function() return d:decrypt(p[1], p[2]) end)
      if ok and isPrintableText(result) and not _has_ctrl(result) then
        sc = sc + 2 + _meaning_score(result)
      elseif ok and _utf8_ok(result) and not _has_ctrl(result) then
        sc = sc + 2 + _meaning_score(result)
      elseif ok and _utf8_ok(result) then sc = sc + 0
      elseif ok then sc = sc - 1
      else sc = sc - 2 end
    end
    if sc > bestscore then bestscore = sc; best = k end
  end
  return best, LcgDecryptor_new(mul45, add45, mul8, best)
end

local function _walk_all(e, out)
  if isAst(e) then
    out[#out+1] = e
    for i = 2, #e do
      local p = e[i]
      if isAst(p) then _walk_all(p, out)
      elseif type(p) == "table" then
        for _, x in ipairs(p) do
          if isAst(x) then _walk_all(x, out)
          elseif type(x) == "table" then
            for _, y in ipairs(x) do
              if isAst(y) then _walk_all(y, out) end
            end
          end
        end
      end
    end
  end
end

local function extract_lcg_params(blocks)
  local mul45, add45, mul8 = nil, nil, nil
  for bid, b in pairs(blocks) do
    for _, s in ipairs(b.body) do
      local roots
      if s[1] == "let" or s[1] == "setvar" then roots = {s[3]}
      elseif s[1] == "assign" then
        roots = {}
        for _, x in ipairs(s[2]) do roots[#roots+1] = x end
        for _, x in ipairs(s[3]) do roots[#roots+1] = x end
      else roots = {} end
      for _, r in ipairs(roots) do
        local nodes = {}
        _walk_all(r, nodes)
        for _, e in ipairs(nodes) do
          if isAst(e) and e[1] == "bin" and e[2] == "%" and isAst(e[4]) and e[4][1] == "num" and math.abs(e[4][2] - M45) < 0.5 then
            local inner = e[3]
            if isAst(inner) and inner[1] == "bin" and inner[2] == "+" then
              local mul = inner[3]
              if isAst(mul) and mul[1] == "bin" and mul[2] == "*" and isAst(mul[4]) and mul[4][1] == "num" then
                mul45 = math.floor(mul[4][2])
              end
              if isAst(inner[4]) and inner[4][1] == "num" then
                add45 = math.floor(inner[4][2])
              end
            end
          end
          if isAst(e) and e[1] == "bin" and e[2] == "%" and isAst(e[4]) and e[4][1] == "num" and math.abs(e[4][2] - 257) < 0.5 then
            local inner = e[3]
            if isAst(inner) and inner[1] == "bin" and inner[2] == "*" and isAst(inner[4]) and inner[4][1] == "num" then
              mul8 = math.floor(inner[4][2])
            end
          end
        end
      end
    end
  end
  return mul45, add45, mul8
end

local function collect_enc_pairs(blocks)
  local enc_pairs = {}
  for bid, b in pairs(blocks) do
    for _, s in ipairs(b.body) do
      local roots
      if s[1] == "let" or s[1] == "setvar" then roots = {s[3]}
      elseif s[1] == "assign" then
        roots = {}
        for _, x in ipairs(s[2]) do roots[#roots+1] = x end
        for _, x in ipairs(s[3]) do roots[#roots+1] = x end
      elseif s[1] == "callstmt" then roots = {s[2]}
      else roots = {} end
      for _, r in ipairs(roots) do
        local nodes = {}
        _walk_all(r, nodes)
        for _, e in ipairs(nodes) do
          if isAst(e) and e[1] == "call" and #e[3] == 2 and
             isAst(e[3][1]) and e[3][1][1] == "str" and
             isAst(e[3][2]) and e[3][2][1] == "num" then
            local ss = e[3][1][2]
            local hasNonPrint = false
            for i = 1, #ss do
              local b = ss:byte(i)
              if b < 32 or b > 126 then hasNonPrint = true; break end
            end
            if hasNonPrint then
              enc_pairs[#enc_pairs+1] = {ss, math.floor(e[3][2][2])}
            end
          end
        end
      end
    end
  end
  -- 去重
  local seen = {}
  local out = {}
  for _, p in ipairs(enc_pairs) do
    local key = p[1] .. "\0" .. p[2]
    if not seen[key] then seen[key] = true; out[#out+1] = p end
  end
  return out
end

M.LcgDecryptor_new = LcgDecryptor_new
M.brute_key8 = brute_key8
M.extract_lcg_params = extract_lcg_params
M.collect_enc_pairs = collect_enc_pairs

-- ============================================================
-- 容器作用域解析
-- ============================================================

local function _func_body_text(toks, rng)
  if not rng then return {} end
  local s, e = rng[1], rng[2]
  local out = {}
  for i = s, e - 1 do out[#out+1] = toks[i] end
  return out
end

local function _body_has(toks, rng, pred)
  for _, t in ipairs(_func_body_text(toks, rng)) do
    if pred(t) then return true end
  end
  return false
end

local function _inner_func_params(toks, rng)
  local s, e = rng[1], rng[2]
  local i = s
  while i < e do
    if toks[i].k == "function" then
      local j = i + 1
      if toks[j].k == "OP" and toks[j].v == "(" then
        j = j + 1
        local ps = {}
        while j < e and not (toks[j].k == "OP" and toks[j].v == ")") do
          if toks[j].k == "NAME" or toks[j].k == "..." or (toks[j].k == "OP" and toks[j].v == "...") then
            ps[#ps+1] = (toks[j].k == "..." or (toks[j].k == "OP" and toks[j].v == "...")) and "..." or toks[j].v
          end
          j = j + 1
        end
        return ps
      end
    end
    i = i + 1
  end
  return nil
end

local function analyze_container(code)
  local toks = lex(code)
  local idxs = {}
  for i = 1, #toks - 2 do
    if toks[i].k == "return" and toks[i+1].k == "OP" and toks[i+1].v == "(" and toks[i+2].k == "function" then
      idxs[#idxs+1] = i
    end
  end
  local ci
  if #idxs < 2 then
    if #idxs == 0 then error("未找到容器函数") end
    ci = idxs[1]
  else
    ci = idxs[2]
  end
  local p = Parser.new(toks)
  p.i = ci
  p:next()  -- return
  p:next()  -- (
  p:next()  -- function
  p:expect("(")
  local params = {}
  if not p:atOp(")") then
    params[#params+1] = p:next().v
    while p:atOp(",") do p:next(); params[#params+1] = p:next().v end
  end
  p:expect(")")
  local stmt = p:one_statement()
  if stmt[1] ~= "assign" then error("容器首语句应为多赋值, 得到 " .. stmt[1]) end
  local lhs = {}
  for _, e in ipairs(stmt[2]) do lhs[#lhs+1] = e[2] end
  local rhs = stmt[3]
  local role = {}
  local container_name, container_params, container_range = nil, nil, nil
  local closure_names = {}
  local function has_nil(rng) return _body_has(toks, rng, function(t) return t.k == "nil" end) end
  local function has_kw(rng, k) return _body_has(toks, rng, function(t) return t.k == k end) end
  for idx = 1, #lhs do
    local name = lhs[idx]
    local val = rhs[idx]
    local c = eval_const(val)
    if c and c[1] == "num" and c[2] == 0 then
      role[name] = "curupid"
    elseif isAst(val) and val[1] == "table" and #val[2] == 0 then
      role[name] = "emptytable"
    elseif isAst(val) and val[1] == "func" then
      local fparams = val[2]
      local rng = val[3]
      if #fparams == 0 then
        role[name] = "alloc"
      elseif #fparams == 1 then
        if has_kw(rng, "for") then role[name] = "proxy"
        elseif has_kw(rng, "while") then role[name] = "gc"
        elseif has_nil(rng) then role[name] = "free"
        else role[name] = "onefunc" end
      elseif #fparams == 4 and has_kw(rng, "while") then
        role[name] = "container"
        container_name = name
        container_params = fparams
        container_range = rng
      elseif #fparams == 2 then
        local inner = _inner_func_params(toks, rng)
        if inner == nil then
          role[name] = "closure?"
        elseif true then
          local hasVararg = false
          for _, pp in ipairs(inner) do if pp == "..." then hasVararg = true end end
          if hasVararg then
            role[name] = "vclosure"
          else
            role[name] = "closure" .. #inner
            closure_names[name] = #inner
          end
        end
      else
        role[name] = "otherfunc"
      end
    else
      role[name] = "other"
    end
  end
  -- 容器体内 return 语句
  local ret = p:one_statement()
  local retvar, startid, vclosure_name, unpack_name = nil, nil, nil, nil
  local ok = pcall(function()
    local outer_call = ret[2][1]
    local inner_call = outer_call[2]
    vclosure_name = inner_call[2][2]
    local start_expr = inner_call[3][1]
    local unpack_call = outer_call[3][1]
    unpack_name = unpack_call[2][2]
    retvar = unpack_call[3][1][2]
    local c = eval_const(start_expr)
    if c and c[1] == "num" then
      local v = c[2]
      startid = (v == math.floor(v)) and math.floor(v) or v
    end
  end)
  p:expect("end")
  p:expect(")")
  p:expect("(")
  local ext = {}
  if not p:atOp(")") then
    ext[#ext+1] = p:expr(0)
    while p:atOp(",") do p:next(); ext[#ext+1] = p:expr(0) end
  end
  p:expect(")")
  -- 识别外部7项角色
  local ext_role = {}
  local function names_in(e, acc)
    if isAst(e) then
      if e[1] == "var" then acc[#acc+1] = e[2]
      elseif e[1] == "index" and isAst(e[2]) and e[2][1] == "var" then
        acc[#acc+1] = e[2][2]; names_in(e[3], acc)
      else
        for i = 2, #e do
          local x = e[i]
          if isAst(x) then names_in(x, acc)
          elseif type(x) == "table" then
            for _, y in ipairs(x) do if isAst(y) then names_in(y, acc) end end
          end
        end
      end
    end
  end
  for i = 1, math.min(#params, #ext) do
    local pname = params[i]
    local e = ext[i]
    local ns = {}
    names_in(e, ns)
    local txt = table.concat(ns, " ")
    if txt:find("getfenv", 1, true) or txt:find("_ENV", 1, true) then ext_role[pname] = "env"
    elseif txt:find("unpack", 1, true) then ext_role[pname] = "unpack"
    elseif true then
      local hasNewproxy = false
      for _, nn in ipairs(ns) do if nn == "newproxy" then hasNewproxy = true end end
      if hasNewproxy then ext_role[pname] = "newproxy"
      elseif txt:find("setmetatable", 1, true) then ext_role[pname] = "setmeta"
      elseif txt:find("getmetatable", 1, true) then ext_role[pname] = "getmeta"
      elseif txt:find("select", 1, true) then ext_role[pname] = "select"
      elseif isAst(e) and e[1] == "table" then ext_role[pname] = "arg"
      else ext_role[pname] = "ext?" end
    end
  end
  -- upvaluesTable / refcount 表
  local upval_table, refcount_table = nil, nil
  local function _op(t, i, v) return i <= #t and t[i].k == "OP" and t[i].v == v end
  local function _nm(t, i) return i <= #t and t[i].k == "NAME" end
  for idx = 1, #lhs do
    local name = lhs[idx]
    local val = rhs[idx]
    if isAst(val) and val[1] == "func" and role[name] == "free" then
      local bt = _func_body_text(toks, val[3])
      for i = 1, #bt - 10 do
        if _nm(bt,i) and _op(bt,i+1,"[") and _nm(bt,i+2) and _op(bt,i+3,"]")
           and _op(bt,i+4,",") and _nm(bt,i+5) and _op(bt,i+6,"[") and _nm(bt,i+7)
           and _op(bt,i+8,"]") and _op(bt,i+9,"=") and bt[i+10].k == "nil" then
          refcount_table = bt[i].v
          upval_table = bt[i+5].v
          break
        end
      end
      break
    end
  end
  local vclosures = {}
  for n, r in pairs(role) do if r == "vclosure" then vclosures[#vclosures+1] = n end end
  return {
    params=params, role=role, ext_role=ext_role,
    container=container_name, container_params=container_params,
    posvar=container_params and container_params[1] or nil,
    argsvar=container_params and container_params[2] or nil,
    curupvar=container_params and container_params[3] or nil,
    gcvar=container_params and container_params[4] or nil,
    closures=closure_names, vclosure=vclosures,
    upval_table=upval_table, refcount=refcount_table,
    returnvar=retvar, unpack=unpack_name, startid=startid,
    lhs=lhs, rhs=rhs,
  }
end

M.analyze_container = analyze_container

-- ============================================================
-- VM 提取
-- ============================================================

local function find_vm_container(toks)
  local best = nil
  local best_size = 0
  local i = 1
  while i <= #toks do
    if toks[i].k == "function" and i+1 <= #toks and toks[i+1].k == "OP" and toks[i+1].v == "(" then
      local j = i + 2
      local params = {}
      while j <= #toks and toks[j].k == "NAME" do
        params[#params+1] = toks[j].v
        j = j + 1
        if j <= #toks and toks[j].k == "OP" and toks[j].v == "," then j = j + 1 else break end
      end
      if j <= #toks and toks[j].k == "OP" and toks[j].v == ")" and #params == 4 then
        local k = j + 1
        while k <= #toks and toks[k].k ~= "while" do k = k + 1 end
        if k <= #toks and k+1 <= #toks and toks[k+1].k == "NAME" and k+2 <= #toks and toks[k+2].k == "do" then
          local names = {}
          local m = j + 1
          while m < k do
            if toks[m].k == "local" then
              m = m + 1
              while m <= #toks and toks[m].k == "NAME" do
                names[#names+1] = toks[m].v
                m = m + 1
                if m <= #toks and toks[m].k == "OP" and toks[m].v == "," then m = m + 1 else break end
              end
            end
            m = m + 1
          end
          -- 计算while后到function结束的代码量
          local funcEnd = k
          local depth = 1
          while funcEnd <= #toks and depth > 0 do
            local tk = toks[funcEnd].k
            if tk == "function" or tk == "if" or tk == "while" or tk == "for" or tk == "repeat" then
              depth = depth + 1
            elseif tk == "end" or tk == "until" then
              depth = depth - 1
            end
            funcEnd = funcEnd + 1
          end
          local codeSize = funcEnd - k
          if codeSize >= best_size then
            best_size = codeSize
            best = {params[1], params[2], params[3], params[4], names, k, j, i}
          end
        end
      end
      i = j
    else
      i = i + 1
    end
  end
  return best
end

local function match_block_end(toks, start)
  local depth = 0
  local i = start
  local opener = {["if"]=true,["function"]=true,["do"]=true,["while"]=true,["for"]=true}
  while i <= #toks do
    local k = toks[i].k
    if opener[k] then depth = depth + 1
    elseif k == "repeat" then depth = depth + 1
    elseif k == "end" or k == "until" then
      depth = depth - 1
      if depth == 0 then return i end
    end
    i = i + 1
  end
  return -1
end

-- DispatchParser
local function DispatchParser_new(toks, posvar, start)
  local self = {t=toks, pv=posvar, i=start}
  function self:peek(k)
    k = k or 0
    return self.t[math.min(self.i + k, #self.t)]
  end
  function self:next()
    local x = self.t[self.i]; self.i = self.i + 1; return x
  end
  function self:_find_then()
    local depth = 0
    local j = self.i
    while j <= #self.t do
      local k = self.t[j].k
      if k == "OP" and (self.t[j].v == "(" or self.t[j].v == "{") then depth = depth + 1
      elseif k == "OP" and (self.t[j].v == ")" or self.t[j].v == "}") then depth = depth - 1
      elseif k == "then" and depth == 0 then return j end
      j = j + 1
    end
    return -1
  end
  function self:_parse_cond(lo, hi)
    local subtoks = {}
    for j = lo, hi - 1 do subtoks[#subtoks+1] = self.t[j] end
    subtoks[#subtoks+1] = self.t[#self.t]
    local p = Parser.new(subtoks)
    local e = p:expr()
    if isAst(e) and e[1] == "bin" and (e[2] == "<" or e[2] == ">" or e[2] == "<=" or e[2] == ">=") then
      local l, r = e[3], e[4]
      if isAst(l) and l[1] == "var" and l[2] == self.pv then
        local c = eval_const(r)
        if c and c[1] == "num" then
          return {(e[2] == "<" or e[2] == "<=") and "lt" or "le", c[2]}
        end
      end
      if isAst(r) and r[1] == "var" and r[2] == self.pv then
        local c = eval_const(l)
        if c and c[1] == "num" then
          return {(e[2] == ">" or e[2] == ">=") and "lt" or "le", c[2]}
        end
      end
    end
    return nil
  end
  function self:is_dispatch_if()
    if self:peek().k ~= "if" then return false end
    local ti = self:_find_then()
    if ti < 0 then return false end
    return self:_parse_cond(self.i + 1, ti)
  end
  function self:parse_node()
    local d = self:is_dispatch_if()
    if not d then return self:parse_leaf() end
    local kind, bound = d[1], d[2]
    local ti = self:_find_then()
    self.i = ti + 1
    local left = self:parse_branch()
    local branches = {{true, left}}
    while self:peek().k == "elseif" do
      self:next()
      local ti2 = self:_find_then()
      local cond = self:_parse_cond(self.i, ti2)
      self.i = ti2 + 1
      local body = self:parse_branch()
      branches[#branches+1] = {cond, body}
    end
    local right = nil
    if self:peek().k == "else" then
      self:next()
      right = self:parse_branch()
    end
    self:expect_kw("end")
    return {"node", kind, bound, branches, right}
  end
  function self:parse_branch() return self:parse_node() end
  function self:parse_leaf()
    local buf = {}
    local depth = 0
    while self.i <= #self.t do
      local k = self:peek().k
      if depth == 0 and (k == "else" or k == "elseif" or k == "end") then break end
      if k == "if" or k == "function" or k == "do" or k == "while" or k == "for" then depth = depth + 1
      elseif k == "end" then depth = depth - 1 end
      buf[#buf+1] = self:next()
    end
    local subtoks = {}
    for _, t in ipairs(buf) do subtoks[#subtoks+1] = t end
    subtoks[#subtoks+1] = self.t[#self.t]
    local p = Parser.new(subtoks)
    local stats = {}
    while p:peek().k ~= "EOF" do stats[#stats+1] = p:one_statement() end
    return {"leaf", stats}
  end
  function self:expect_kw(kw)
    if self:peek().k == kw then self:next(); return end
    error("分发树期望 " .. kw)
  end
  return self
end

local function collect_leaves(tree, leaves, path)
  leaves = leaves or {}
  path = path or {}
  if tree[1] == "leaf" then
    local p = {}
    for _, x in ipairs(path) do p[#p+1] = x end
    leaves[#leaves+1] = {stats=tree[2], path=p}
    return leaves
  end
  local kind, bound, branches, right = tree[2], tree[3], tree[4], tree[5]
  for idx, br in ipairs(branches) do
    local cond, sub = br[1], br[2]
    local newpath = {}
    for _, x in ipairs(path) do newpath[#newpath+1] = x end
    newpath[#newpath+1] = {idx, bound}
    collect_leaves(sub, leaves, newpath)
  end
  if right ~= nil then
    local newpath = {}
    for _, x in ipairs(path) do newpath[#newpath+1] = x end
    newpath[#newpath+1] = {"else", bound}
    collect_leaves(right, leaves, newpath)
  end
  return leaves
end

local function locate_block_id(tree, target)
  local node = tree
  while node[1] == "node" do
    local kind, bound, branches, right = node[2], node[3], node[4], node[5]
    local go_left = (kind == "lt") and (target < bound) or (target <= bound)
    if go_left then
      node = branches[1][2]
    else
      if right ~= nil then node = right
      elseif #branches > 1 then node = branches[2][2]
      else node = branches[1][2] end
    end
  end
  return node
end

local function extract_vm(code)
  local toks = lex(code)
  local info = find_vm_container(toks)
  if not info then error("未找到VM主函数") end
  local pv, av, uv, gv, regnames, while_idx, paren_idx, func_idx =
    info[1], info[2], info[3], info[4], info[5], info[6], info[7], info[8]
  local dp = DispatchParser_new(toks, pv, while_idx + 3)
  local tree = dp:parse_node()
  local leaves = collect_leaves(tree)
  -- 入口块id
  local entry = nil
  local function checkEntry(idx)
    if not (toks[idx].k == "OP" and toks[idx].v == "{" and toks[idx+1].k == "OP" and toks[idx+1].v == "}") then
      return
    end
    local q = idx + 2
    local nclose = 0
    while q <= #toks and toks[q].k == "OP" and toks[q].v == ")" do
      q = q + 1; nclose = nclose + 1
    end
    if not (nclose >= 1 and nclose <= 2 and q <= #toks and toks[q].k == "OP" and toks[q].v == "(") then
      return
    end
    local d = 0
    local j = idx - 1
    while j >= 1 do
      if toks[j].k == "OP" and toks[j].v == ")" then d = d + 1
      elseif toks[j].k == "OP" and toks[j].v == "(" then
        if d == 0 then break end
        d = d - 1
      end
      j = j - 1
    end
    local lo = j + 1
    local d2 = 0
    local k = lo
    while k < idx do
      if toks[k].k == "OP" and (toks[k].v == "(" or toks[k].v == "{") then d2 = d2 + 1
      elseif toks[k].k == "OP" and (toks[k].v == ")" or toks[k].v == "}") then d2 = d2 - 1
      elseif toks[k].k == "OP" and toks[k].v == "," and d2 == 0 then break end
      k = k + 1
    end
    local subtoks = {}
    for jj = lo, k - 1 do subtoks[#subtoks+1] = toks[jj] end
    subtoks[#subtoks+1] = toks[#toks]
    local p = Parser.new(subtoks)
    local ok, e = pcall(function() return p:expr() end)
    if ok then
      local c = eval_const(e)
      if c and c[1] == "num" then
        local v = c[2]
        entry = (v == math.floor(v)) and math.floor(v) or v
      end
    end
  end
  for idx = 1, #toks - 4 do checkEntry(idx) end
  return {
    posvar=pv, argsvar=av, upvalsvar=uv, gcvar=gv,
    regnames=regnames, tree=tree, leaves=leaves,
    entry=entry, toks=toks,
  }
end

M.extract_vm = extract_vm

-- ============================================================
-- 块内数据流简化
-- ============================================================

local function stat_rw(stat)
  local reads = {}
  local writes = {}
  local k = stat[1]
  if k == "assign" then
    for _, L in ipairs(stat[2]) do
      if isAst(L) and L[1] == "var" then writes[L[2]] = true
      else used_vars(L, reads) end
    end
    for _, R in ipairs(stat[3]) do used_vars(R, reads) end
  elseif k == "local" then
    for _, n in ipairs(stat[2]) do writes[n] = true end
    for _, R in ipairs(stat[3]) do used_vars(R, reads) end
  elseif k == "return" then
    for _, R in ipairs(stat[2]) do used_vars(R, reads) end
  elseif k == "callstmt" then
    used_vars(stat[2], reads)
  end
  return reads, writes
end

local function expr_has_call(e)
  if not isAst(e) then return false end
  if e[1] == "call" or e[1] == "selfcall" then return true end
  if e[1] == "bin" then return expr_has_call(e[3]) or expr_has_call(e[4]) end
  if e[1] == "un" then return expr_has_call(e[3]) end
  if e[1] == "index" then return expr_has_call(e[2]) or expr_has_call(e[3]) end
  if e[1] == "table" then
    for _, kv in ipairs(e[2]) do
      if expr_has_call(kv[2]) or (kv[1] and expr_has_call(kv[1])) then return true end
    end
  end
  if e[1] == "call" then return true end
  return false
end

local function first_roles(stats, posvar, retvar)
  local role = {}
  for _, st in ipairs(stats) do
    local r, w = stat_rw(st)
    for name in pairs(r) do if role[name] == nil then role[name] = "in" end end
    for name in pairs(w) do if role[name] == nil then role[name] = "temp" end end
  end
  return role
end

local function _alias_nonfinal_pos(stats, posvar, alias)
  alias = alias or "_pt"
  local pos_writes = {}
  for i, st in ipairs(stats) do
    if st[1] == "assign" and #st[2] == 1 and isAst(st[2][1]) and st[2][1][1] == "var" and st[2][1][2] == posvar then
      pos_writes[#pos_writes+1] = i
    end
  end
  if #pos_writes == 0 then return stats end
  local keep_last = 1
  local last_i = pos_writes[#pos_writes]
  local last_rhs = stats[last_i][3][1]
  if isAst(last_rhs) and last_rhs[1] == "bin" and last_rhs[2] == "or" and isAst(last_rhs[3]) and last_rhs[3][1] == "var" and last_rhs[3][2] == posvar then
    keep_last = 2
  end
  local keep = {}
  for i = #pos_writes - keep_last + 1, #pos_writes do keep[pos_writes[i]] = true end
  local function ren(e)
    if not isAst(e) then return e end
    if e[1] == "var" and e[2] == posvar then return {"var", alias} end
    if e[1] == "bin" then return {"bin", e[2], ren(e[3]), ren(e[4])} end
    if e[1] == "un" then return {"un", e[2], ren(e[3])} end
    if e[1] == "index" then return {"index", ren(e[2]), ren(e[3])} end
    if e[1] == "call" then
      local args = {}
      for _, a in ipairs(e[3]) do args[#args+1] = ren(a) end
      return {"call", ren(e[2]), args}
    end
    if e[1] == "selfcall" then
      local args = {}
      for _, a in ipairs(e[4]) do args[#args+1] = ren(a) end
      return {"selfcall", ren(e[2]), e[3], args}
    end
    if e[1] == "table" then
      local entries = {}
      for _, kv in ipairs(e[2]) do
        entries[#entries+1] = {kv[1] and ren(kv[1]) or nil, ren(kv[2])}
      end
      return {"table", entries}
    end
    return e
  end
  local out = {}
  for i, st in ipairs(stats) do
    if keep[i] or st[1] ~= "assign" then
      out[#out+1] = st
    else
      local new_lhs = {}
      for _, L in ipairs(st[2]) do
        new_lhs[#new_lhs+1] = (isAst(L) and L[1] == "var" and L[2] == posvar) and {"var", alias} or L
      end
      local new_rhs = {}
      for _, r in ipairs(st[3]) do new_rhs[#new_rhs+1] = ren(r) end
      out[#out+1] = {"assign", new_lhs, new_rhs}
    end
  end
  return out
end

local function try_decrypt(e, decrypt)
  if not decrypt or not isAst(e) then return nil end
  if e[1] == "call" and #e[3] == 2 then
    local a, b = e[3][1], e[3][2]
    if isAst(a) and a[1] == "str" and isAst(b) and b[1] == "num" then
      local enc = a[2]  -- latin1 字节字符串
      local seed = b[2]
      local ok, plain = pcall(function()
        if type(decrypt) == "function" then return decrypt(enc, seed)
        else return decrypt[enc .. "\0" .. seed] end
      end)
      if not ok or plain == nil then return nil end
      -- 检查是否为可打印文本（ASCII可打印 或 合法UTF-8，支持中文）
      if isPrintableText(plain) then return plain end
      if isValidUTF8(plain) and #plain > 0 then return plain end
      return nil
    end
  end
  return nil
end

local function simplify_block(stats, posvar, retvar, decrypt, special_globals, inliner)
  posvar = posvar or "D"
  special_globals = special_globals or {}
  stats = _alias_nonfinal_pos(stats, posvar)
  local role = first_roles(stats, posvar, retvar)
  local known = {}
  local out = {}
  local function sub(e)
    if inliner then e = inliner(e) end
    return substitute(e, known)
  end
  for _, st in ipairs(stats) do
    local k = st[1]
    if k == "assign" then
      local lhs = st[2]
      local rhs = {}
      for _, r in ipairs(st[3]) do rhs[#rhs+1] = sub(r) end
      local new_lhs = {}
      for _, L in ipairs(lhs) do
        new_lhs[#new_lhs+1] = (isAst(L) and L[1] ~= "var") and sub(L) or L
      end
      if #new_lhs == 1 and isAst(new_lhs[1]) and new_lhs[1][1] == "var" then
        local name = new_lhs[1][2]
        local val = rhs[1]
        if name == posvar then
          out[#out+1] = {"setvar", name, val}
          known[name] = nil
        elseif not special_globals[name] and isAst(val) and (val[1] == "num" or val[1] == "str") and not expr_has_call(val) then
          known[name] = val
        elseif role[name] == "temp" and not special_globals[name] then
          local plain = try_decrypt(val, decrypt)
          if plain ~= nil then
            known[name] = {"str", plain}
          elseif expr_has_call(val) then
            out[#out+1] = {"let", name, val}
            known[name] = nil
          elseif isAst(val) and val[1] == "table" then
            out[#out+1] = {"let", name, val}
            known[name] = nil
          else
            known[name] = val
          end
        else
          out[#out+1] = {"setvar", name, val}
          known[name] = nil
        end
      else
        out[#out+1] = {"assign", new_lhs, rhs}
      end
    elseif k == "local" then
      local rhs = {}
      for _, r in ipairs(st[3]) do rhs[#rhs+1] = sub(r) end
      out[#out+1] = {"local", st[2], rhs}
    elseif k == "return" then
      local rhs = {}
      for _, r in ipairs(st[2]) do rhs[#rhs+1] = sub(r) end
      out[#out+1] = {"return", rhs}
    elseif k == "callstmt" then
      out[#out+1] = {"callstmt", sub(st[2])}
    elseif k == "setvar" then
      local name = st[2]
      local val = sub(st[3])
      if name == posvar then
        out[#out+1] = {"setvar", name, val}
        known[name] = nil
      elseif not special_globals[name] and isAst(val) and (val[1] == "num" or val[1] == "str") and not expr_has_call(val) then
        known[name] = val
      elseif role[name] == "temp" and not special_globals[name] then
        local plain = try_decrypt(val, decrypt)
        if plain ~= nil then
          known[name] = {"str", plain}
        elseif expr_has_call(val) then
          out[#out+1] = {"setvar", name, val}
          known[name] = nil
        elseif isAst(val) and val[1] == "table" then
          out[#out+1] = {"setvar", name, val}
          known[name] = nil
        else
          known[name] = val
        end
      else
        out[#out+1] = {"setvar", name, val}
        known[name] = nil
      end
    elseif k == "let" then
      local name = st[2]
      local val = sub(st[3])
      if not special_globals[name] and isAst(val) and (val[1] == "num" or val[1] == "str") and not expr_has_call(val) then
        known[name] = val
      elseif role[name] == "temp" and not special_globals[name] then
        local plain = try_decrypt(val, decrypt)
        if plain ~= nil then
          known[name] = {"str", plain}
        elseif expr_has_call(val) then
          out[#out+1] = {"let", name, val}
          known[name] = nil
        elseif isAst(val) and val[1] == "table" then
          out[#out+1] = {"let", name, val}
          known[name] = nil
        else
          known[name] = val
        end
      else
        out[#out+1] = {"let", name, val}
        known[name] = nil
      end
    else
      out[#out+1] = st
    end
  end
  return out, role
end

local function classify_terminator(e)
  if isAst(e) and e[1] == "num" then
    local v = e[2]
    return {"jmp", (v == math.floor(v)) and math.floor(v) or v}
  end
  if isAst(e) and e[1] == "bin" and e[2] == "or" then
    local right = e[4]
    if isAst(e[3]) and e[3][1] == "bin" and e[3][2] == "and" then
      local cond = e[3][3]
      local t = e[3][4]
      local function asid(x)
        if isAst(x) and x[1] == "num" then
          local v = x[2]
          return (v == math.floor(v)) and math.floor(v) or nil
        end
        return nil
      end
      local a, b = asid(t), asid(right)
      if a ~= nil and b ~= nil then
        return {"branch", cond, a, b}
      end
    end
  end
  if isAst(e) and e[1] == "index" and isAst(e[3]) and e[3][1] == "str" then
    return {"exit", e}
  end
  if isAst(e) and e[1] == "index" then
    return {"exit", e}
  end
  return {"dynamic", e}
end

local function extract_terminator(out, posvar)
  posvar = posvar or "D"
  local pos_idx = {}
  for i, s in ipairs(out) do
    if (s[1] == "setvar" and s[2] == posvar) or (s[1] == "let" and s[2] == posvar) then
      pos_idx[#pos_idx+1] = {i, 1}
    elseif s[1] == "assign" then
      for j, lhs in ipairs(s[2]) do
        if type(lhs) == "table" and lhs[1] == "var" and lhs[2] == posvar then
          pos_idx[#pos_idx+1] = {i, j}
          break
        end
      end
    end
  end
  if #pos_idx == 0 then return out, nil end
  local last_info = pos_idx[#pos_idx]
  local last = last_info[1]
  local last_j = last_info[2]
  local termexpr
  if out[last][1] == "assign" then
    termexpr = out[last][3][last_j]
  else
    termexpr = out[last][3]
  end
  if isAst(termexpr) and termexpr[1] == "bin" and termexpr[2] == "or" and isAst(termexpr[3]) and termexpr[3][1] == "var" and termexpr[3][2] == posvar then
    if #pos_idx >= 2 then
      local prev_info = pos_idx[#pos_idx - 1]
      local prev = prev_info[1]
      local prev_j = prev_info[2]
      local x
      if out[prev][1] == "assign" then
        x = out[prev][3][prev_j]
      else
        x = out[prev][3]
      end
      termexpr = {"bin", "or", x, termexpr[4]}
      local newout = {}
      for i = 1, prev - 1 do newout[#newout+1] = out[i] end
      for i = prev + 1, last - 1 do newout[#newout+1] = out[i] end
      for i = last + 1, #out do newout[#newout+1] = out[i] end
      out = newout
    else
      local newout = {}
      for i = 1, last - 1 do newout[#newout+1] = out[i] end
      for i = last + 1, #out do newout[#newout+1] = out[i] end
      out = newout
    end
  else
    local newout = {}
    for i = 1, last - 1 do newout[#newout+1] = out[i] end
    for i = last + 1, #out do newout[#newout+1] = out[i] end
    out = newout
  end
  return out, classify_terminator(termexpr)
end

M.simplify_block = simplify_block
M.extract_terminator = extract_terminator
M.classify_terminator = classify_terminator

-- ============================================================
-- CFG 构建
-- ============================================================

local function simplify_leaf(leaf, posvar, retvar, decrypt, inliner)
  posvar = posvar or "D"
  retvar = retvar or "B"
  local body, role = simplify_block(leaf.stats, posvar, retvar, decrypt, nil, inliner)
  local newbody, term = extract_terminator(body, posvar)
  return newbody, term
end

local function collect_ids_from_expr(e, ids)
  if not isAst(e) then return end
  if e[1] == "call" and #e[3] == 2 and isAst(e[3][1]) and e[3][1][1] == "num" and isAst(e[3][2]) and e[3][2][1] == "table" then
    local v = e[3][1][2]
    ids[(v == math.floor(v)) and math.floor(v) or v] = true
  end
  for i = 2, #e do
    local part = e[i]
    if isAst(part) then collect_ids_from_expr(part, ids)
    elseif type(part) == "table" then
      for _, x in ipairs(part) do
        if isAst(x) then collect_ids_from_expr(x, ids)
        elseif type(x) == "table" then
          for _, y in ipairs(x) do
            if isAst(y) then collect_ids_from_expr(y, ids) end
          end
        end
      end
    end
  end
end

local function block_body_ids(body)
  local ids = {}
  for _, s in ipairs(body) do
    if s[1] == "let" then collect_ids_from_expr(s[3], ids)
    elseif s[1] == "setvar" then collect_ids_from_expr(s[3], ids)
    elseif s[1] == "assign" then
      for _, x in ipairs(s[2]) do collect_ids_from_expr(x, ids) end
      for _, x in ipairs(s[3]) do collect_ids_from_expr(x, ids) end
    elseif s[1] == "callstmt" then collect_ids_from_expr(s[2], ids) end
  end
  return ids
end

local function deep_equal(a, b, seen)
  seen = seen or {}
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  if seen[a] and seen[a] == b then return true end
  seen[a] = b
  for k, v in pairs(a) do
    if not deep_equal(v, b[k], seen) then return false end
  end
  for k, v in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end

local function build_cfg(vm, posvar, retvar, decrypt, inliner)
  posvar = posvar or "D"
  retvar = retvar or "B"
  local simplified = {}
  for _, leaf in ipairs(vm.leaves) do
    local body, term = simplify_leaf(leaf, posvar, retvar, decrypt, inliner)
    simplified[#simplified+1] = {leaf, body, term}
  end
  local ids = {}
  if vm.entry ~= nil then ids[vm.entry] = true end
  for _, s in ipairs(simplified) do
    local leaf, body, term = s[1], s[2], s[3]
    local bid = block_body_ids(body)
    for k in pairs(bid) do ids[k] = true end
    if term then
      if term[1] == "jmp" then ids[term[2]] = true
      elseif term[1] == "branch" then ids[term[3]] = true; ids[term[4]] = true end
    end
  end
  local id2stats = {}
  for bid in pairs(ids) do
    local node = locate_block_id(vm.tree, bid)
    if node and node[1] == "leaf" then id2stats[bid] = node[2] end
  end
  local stats2id = {}
  for bid, st in pairs(id2stats) do
    stats2id[tostring(st)] = bid
  end
  local blocks = {}
  local unreachable = {}
  local used_ids = {}
  for _, s in ipairs(simplified) do
    local leaf, body, term = s[1], s[2], s[3]
    local bid = stats2id[tostring(leaf.stats)]
    if bid == nil then
      for id, st in pairs(id2stats) do
        if not used_ids[id] and deep_equal(leaf.stats, st) then
          bid = id
          break
        end
      end
    end
    if bid == nil then
      unreachable[#unreachable+1] = {leaf, body, term}
    else
      used_ids[bid] = true
      blocks[bid] = {body=body, term=term}
    end
  end
  return blocks, unreachable, id2stats
end

local function succ(term)
  if not term then return {} end
  if term[1] == "jmp" then return {term[2]} end
  if term[1] == "branch" then return {term[3], term[4]} end
  return {}
end

M.build_cfg = build_cfg
M.succ = succ

-- ============================================================
-- 语义层重写
-- ============================================================

local function _const_id(e)
  local c = eval_const(e)
  if c and c[1] == "num" then
    local v = c[2]
    return (v == math.floor(v)) and math.floor(v) or v
  end
  return nil
end

local function make_sema(cont)
  local env_names = {}
  for n, r in pairs(cont.ext_role) do if r == "env" then env_names[n] = true end end
  local upval_table = cont.upval_table
  local alloc = {}
  for n, r in pairs(cont.role) do if r == "alloc" then alloc[n] = true end end
  local free = {}
  for n, r in pairs(cont.role) do if r == "free" then free[n] = true end end
  local closures = cont.closures
  local vclosures = {}
  for _, n in ipairs(cont.vclosure) do vclosures[n] = true end
  local curup = cont.curupvar

  local function rw(e)
    if not isAst(e) then return e end
    local k = e[1]
    if k == "index" then
      local base = rw(e[2])
      local key = rw(e[3])
      if isAst(base) and base[1] == "var" and env_names[base[2]] and isAst(key) and key[1] == "str" then
        return {"var", key[2]}
      end
      return {"index", base, key}
    end
    if k == "call" then
      local fn = rw(e[2])
      local args = {}
      for _, a in ipairs(e[3]) do args[#args+1] = rw(a) end
      if isAst(fn) and fn[1] == "var" then
        local nm = fn[2]
        if closures[nm] and #args == 2 and isAst(args[2]) and args[2][1] == "table" then
          local cid = _const_id(args[1])
          if cid ~= nil then
            return {"mkclosure", cid, args[2], closures[nm], false}
          end
        end
        if vclosures[nm] and #args == 2 and isAst(args[2]) and args[2][1] == "table" then
          local cid = _const_id(args[1])
          if cid ~= nil then
            return {"mkclosure", cid, args[2], -1, true}
          end
        end
        if alloc[nm] and #args == 0 then
          return {"alloc",}
        end
      end
      return {"call", fn, args}
    end
    if k == "bin" then return {"bin", e[2], rw(e[3]), rw(e[4])} end
    if k == "un" then return {"un", e[2], rw(e[3])} end
    if k == "table" then
      local entries = {}
      for _, a in ipairs(e[2]) do
        if a[1] == nil then
          entries[#entries+1] = {nil, rw(a[2])}
        else
          entries[#entries+1] = {rw(a[1]), rw(a[2])}
        end
      end
      return {"table", entries}
    end
    if k == "selfcall" then
      local args = {}
      for _, a in ipairs(e[4]) do args[#args+1] = rw(a) end
      return {"selfcall", rw(e[2]), e[3], args}
    end
    if k == "func" then return e end
    return e
  end
  return rw
end

local function rewrite_statement(s, rw)
  local k = s[1]
  if k == "let" then return {"let", s[2], rw(s[3])} end
  if k == "setvar" then return {"setvar", s[2], rw(s[3])} end
  if k == "assign" then
    local lhs = {}
    for _, x in ipairs(s[2]) do lhs[#lhs+1] = rw(x) end
    local rhs = {}
    for _, x in ipairs(s[3]) do rhs[#rhs+1] = rw(x) end
    return {"assign", lhs, rhs}
  end
  if k == "callstmt" then return {"callstmt", rw(s[2])} end
  if k == "return" then
    local rhs = {}
    for _, x in ipairs(s[2]) do rhs[#rhs+1] = rw(x) end
    return {"return", rhs}
  end
  if k == "local" then
    local rhs = {}
    for _, x in ipairs(s[3]) do rhs[#rhs+1] = rw(x) end
    return {"local", s[2], rhs}
  end
  return s
end

local function rewrite_block(body, cont)
  local rw = make_sema(cont)
  local out = {}
  for _, s in ipairs(body) do out[#out+1] = rewrite_statement(s, rw) end
  return out
end

M.make_sema = make_sema
M.rewrite_block = rewrite_block

-- ============================================================
-- Upvalue 机制还原
-- ============================================================

local function UpvalueRestorer_new(cont, curmap)
  local self = {
    cont=cont,
    curmap={},
    ut=cont.upval_table,
    cu=cont.curupvar,
    free={},
    proxy={},
    slots={},
    slot_n=0,
  }
  if curmap then
    for k, v in pairs(curmap) do self.curmap[k] = v end
  end
  for n, r in pairs(cont.role) do
    if r == "free" then self.free[n] = true end
    if r == "proxy" then self.proxy[n] = true end
  end
  function self:new_slot()
    self.slot_n = self.slot_n + 1
    return "u" .. self.slot_n
  end
  function self:rw_expr(e)
    if not isAst(e) then return e end
    local k = e[1]
    if k == "index" then
      local base = self:rw_expr(e[2])
      local key = self:rw_expr(e[3])
      if isAst(base) and base[1] == "var" and base[2] == self.ut then
        return key
      end
      if isAst(base) and base[1] == "var" and base[2] == self.cu and isAst(key) and key[1] == "num" then
        local n = math.floor(key[2])
        if self.curmap[n] ~= nil then return self.curmap[n] end
      end
      return {"index", base, key}
    end
    if k == "bin" then return {"bin", e[2], self:rw_expr(e[3]), self:rw_expr(e[4])} end
    if k == "un" then return {"un", e[2], self:rw_expr(e[3])} end
    if k == "table" then
      local entries = {}
      for _, kv in ipairs(e[2]) do
        entries[#entries+1] = {kv[1] and self:rw_expr(kv[1]) or nil, self:rw_expr(kv[2])}
      end
      return {"table", entries}
    end
    if k == "call" then
      local fn = e[2]
      local args = {}
      for _, a in ipairs(e[3]) do args[#args+1] = self:rw_expr(a) end
      if isAst(fn) and fn[1] == "var" and self.free[fn[2]] and #args == 1 then
        return {"free", args[1]}
      end
      if isAst(fn) and fn[1] == "var" and self.proxy[fn[2]] then
        return {"drop",}
      end
      if isAst(fn) and fn[1] == "var" and (fn[2] == "setmetatable" or fn[2] == "newproxy") then
        return {"drop",}
      end
      return {"call", fn, args}
    end
    if k == "selfcall" then
      local args = {}
      for _, a in ipairs(e[4]) do args[#args+1] = self:rw_expr(a) end
      return {"selfcall", self:rw_expr(e[2]), e[3], args}
    end
    return e
  end
  function self:restore_body(body)
    local out = {}
    for _, s in ipairs(body) do
      local ns = self:_stat(s)
      if ns ~= nil then
        if type(ns) == "table" and ns[1] == "__multi__" then
          for i = 2, #ns do out[#out+1] = ns[i] end
        else
          out[#out+1] = ns
        end
      end
    end
    return out
  end
  function self:_stat(s)
    local k = s[1]
    if k == "let" then
      local name = s[2]
      local val = self:rw_expr(s[3])
      if isAst(val) and val[1] == "alloc" then
        self.slots[name] = self:new_slot()
        return {"local", {name}, {}}
      end
      if isAst(val) and val[1] == "drop" then return nil end
      if isAst(val) and val[1] == "free" then return nil end
      return {"let", name, val}
    end
    if k == "setvar" then
      local val = self:rw_expr(s[3])
      if isAst(val) and val[1] == "drop" then return nil end
      if isAst(val) and val[1] == "free" then return nil end
      return {"setvar", s[2], val}
    end
    if k == "assign" then
      local lhs = {}
      for _, x in ipairs(s[2]) do lhs[#lhs+1] = self:rw_expr(x) end
      local rhs = {}
      for _, x in ipairs(s[3]) do rhs[#rhs+1] = self:rw_expr(x) end
      local keep = {}
      for i = 1, math.min(#lhs, #rhs) do
        local l, r = lhs[i], rhs[i]
        if not (isAst(r) and (r[1] == "drop" or r[1] == "free")) then
          keep[#keep+1] = {l, r}
        end
      end
      if #keep == 0 then return nil end
      local kl, kr = {}, {}
      for _, p in ipairs(keep) do kl[#kl+1] = p[1]; kr[#kr+1] = p[2] end
      return {"assign", kl, kr}
    end
    if k == "callstmt" then
      local v = self:rw_expr(s[2])
      if isAst(v) and (v[1] == "drop" or v[1] == "free") then return nil end
      return {"callstmt", v}
    end
    if k == "return" then
      local rhs = {}
      for _, x in ipairs(s[2]) do rhs[#rhs+1] = self:rw_expr(x) end
      return {"return", rhs}
    end
    if k == "local" then
      local rhs = {}
      for _, x in ipairs(s[3]) do rhs[#rhs+1] = self:rw_expr(x) end
      return {"local", s[2], rhs}
    end
    return s
  end
  return self
end

M.UpvalueRestorer_new = UpvalueRestorer_new

-- ============================================================
-- 短路表达式折叠
-- ============================================================

local function _has_call_sc(e)
  local found = false
  local function w(x)
    if isAst(x) then
      if x[1] == "call" or x[1] == "selfcall" or x[1] == "mkclosure" or x[1] == "alloc" then
        found = true
      end
      for i = 2, #x do
        local p = x[i]
        if isAst(p) then w(p)
        elseif type(p) == "table" then
          for _, y in ipairs(p) do
            if isAst(y) then w(y)
            elseif type(y) == "table" then
              for _, z in ipairs(y) do if isAst(z) then w(z) end end
            end
          end
        end
      end
    end
  end
  w(e)
  return found
end

local function _pure_assign_block(b, jmp_target)
  local t = b.term
  if not (t and t[1] == "jmp" and t[2] == jmp_target) then return "IMPURE" end
  local writes = {}
  for _, s in ipairs(b.body) do
    if s[1] == "let" then
      if _has_call_sc(s[3]) then return "IMPURE" end
      writes[#writes+1] = {s[2], s[3]}
    elseif s[1] == "setvar" then
      if _has_call_sc(s[3]) then return "IMPURE" end
      writes[#writes+1] = {s[2], s[3]}
    elseif s[1] == "assign" then
      for _, r in ipairs(s[3]) do
        if _has_call_sc(r) then return "IMPURE" end
      end
      for i = 1, math.min(#s[2], #s[3]) do
        local l, r = s[2][i], s[3][i]
        if isAst(l) and l[1] == "var" then writes[#writes+1] = {l[2], r}
        else return "IMPURE" end
      end
    else
      return "IMPURE"
    end
  end
  if #writes == 0 then return {nil, nil} end
  local names = {}
  for _, w in ipairs(writes) do names[w[1]] = true end
  local ncount = 0
  for _ in pairs(names) do ncount = ncount + 1 end
  if ncount ~= 1 then return "IMPURE" end
  local name = writes[#writes][1]
  return {name, writes[#writes][2]}
end

local function fold_short_circuits(blocks, postdom, loop_headers, maxround)
  maxround = maxround or 10000
  local folded = 0
  local function tryFold(h)
    if loop_headers[h] then return false end
    if not blocks[h] then return false end
    local b = blocks[h]
    local t = b.term
    if not (t and t[1] == "branch") then return false end
    local cond, T, F = t[2], t[3], t[4]
    if not blocks[T] or not blocks[F] then return false end
    local join = postdom[h]
    if join == nil or not blocks[join] then return false end
    local tP = _pure_assign_block(blocks[T], join)
    local fP = _pure_assign_block(blocks[F], join)
    if tP == "IMPURE" or fP == "IMPURE" then return false end
    if tP[1] == nil and fP[1] == nil then return false end
    local newexpr, resreg
    if tP[1] ~= nil and fP[1] == nil then
      newexpr = {"bin", "and", cond, tP[2]}
      resreg = tP[1]
    elseif fP[1] ~= nil and tP[1] == nil then
      newexpr = {"bin", "or", cond, fP[2]}
      resreg = fP[1]
    elseif tP[1] == fP[1] then
      resreg = tP[1]
      newexpr = {"bin", "or", {"bin", "and", cond, tP[2]}, fP[2]}
    else
      return false
    end
    local newbody = {}
    for _, s in ipairs(b.body) do
      local iswrite = (s[1] == "let" or s[1] == "setvar") and s[2] == resreg
      if not iswrite then
        iswrite = (s[1] == "assign" and #s[2] == 1 and isAst(s[2][1]) and s[2][1][1] == "var" and s[2][1][2] == resreg)
      end
      if not iswrite then newbody[#newbody+1] = s end
    end
    newbody[#newbody+1] = {"let", resreg, newexpr}
    b.body = newbody
    b.term = {"jmp", join}
    blocks[T] = nil
    blocks[F] = nil
    folded = folded + 1
    return true
  end
  for _ = 1, maxround do
    local did = false
    local keys = {}
    for h in pairs(blocks) do keys[#keys+1] = h end
    for _, h in ipairs(keys) do
      if tryFold(h) then did = true end
    end
    if not did then break end
  end
  return folded
end

M.fold_short_circuits = fold_short_circuits

-- ============================================================
-- 控制流结构化
-- ============================================================

local VEXIT = -1

-- 结构化节点类型（用 table tag 模拟 Python class）
local function SIf(cond, thenb, els) return {tag="if", cond=cond, ["then"]=thenb, els=els} end
local function SWhile(cond, body, kind, head) return {tag="while", cond=cond, body=body, kind=kind or "while", head=head} end
local function SLoopCtrl(k) return {tag="loopctrl", k=k} end
local function SReturn(args) return {tag="return", args=args} end

local function Structurer_new(blocks, entry, retvar, posvar, cont)
  local self = {
    B=blocks, entry=entry, retvar=retvar, pv=posvar, cont=cont,
    _succ_cache={},
  }
  function self:succs(bid)
    if self._succ_cache[bid] ~= nil then return self._succ_cache[bid] end
    local t = self.B[bid].term
    local out = {}
    if t then
      if t[1] == "jmp" then out = {t[2]}
      elseif t[1] == "branch" then out = {t[3], t[4]} end
    end
    self._succ_cache[bid] = out
    return out
  end
  function self:_reachable()
    local seen = {[self.entry]=true}
    local st = {self.entry}
    while #st > 0 do
      local x = table.remove(st)
      if self.B[x] then
        for _, y in ipairs(self:succs(x)) do
          if self.B[y] and not seen[y] then seen[y] = true; st[#st+1] = y end
        end
      end
    end
    return seen
  end
  function self:_pred_succ(nodes, reverse)
    local adj = {}
    for n in pairs(nodes) do adj[n] = {} end
    for n in pairs(nodes) do
      for _, s in ipairs(self:succs(n)) do
        if nodes[s] then
          if reverse then adj[s][n] = true else adj[n][s] = true end
        end
      end
    end
    return adj
  end
  function self:_dom_on(adj, entry)
    local nodes = {}
    for n in pairs(adj) do nodes[n] = true end
    local dom = {}
    for n in pairs(nodes) do
      dom[n] = {}
      for x in pairs(nodes) do dom[n][x] = true end
    end
    if not dom[entry] then return dom end
    dom[entry] = {[entry]=true}
    local changed = true
    while changed do
      changed = false
      for n in pairs(nodes) do
        if n ~= entry then
          local ps = {}
          for p in pairs(adj[n]) do if dom[p] then ps[#ps+1] = dom[p] end end
          local new = {}
          for x in pairs(nodes) do new[x] = true end
          for _, p in ipairs(ps) do
            for x in pairs(new) do if not p[x] then new[x] = nil end end
          end
          new[n] = true
          local same = true
          for x in pairs(new) do if not dom[n][x] then same = false end end
          for x in pairs(dom[n]) do if not new[x] then same = false end end
          if not same then dom[n] = new; changed = true end
        end
      end
    end
    return dom
  end
  function self:_postdom()
    local nodes = {}
    for n in pairs(self.reachable) do nodes[n] = true end
    nodes[VEXIT] = true
    local radj = {}
    for n in pairs(nodes) do radj[n] = {} end
    for n in pairs(self.reachable) do
      local ss = self:succs(n)
      if #ss == 0 then radj[n][VEXIT] = true end
      for _, s in ipairs(ss) do
        if self.B[s] and self.reachable[s] then radj[s][n] = true
        else radj[n][VEXIT] = true end
      end
      local t = self.B[n].term
      if t and t[1] == "exit" then radj[n][VEXIT] = true end
    end
    local pdom = self:_dom_on(radj, VEXIT)
    self.pdom_adj = radj
    return pdom
  end
  function self:ipostdom(n)
    if not self.pdom[n] then return nil end
    local preds = {}
    for p in pairs(self.pdom[n]) do if p ~= n then preds[#preds+1] = p end end
    for _, p in ipairs(preds) do
      local all = true
      for _, q in ipairs(preds) do
        if not self.pdom[q][p] then all = false; break end
      end
      if all then return p end
    end
    return nil
  end
  function self:_can_reach(a, b)
    local seen = {[a]=true}
    local st = {a}
    while #st > 0 do
      local x = table.remove(st)
      if x == b then return true end
      for _, y in ipairs(self:succs(x)) do
        if self.B[y] and not seen[y] then seen[y] = true; st[#st+1] = y end
      end
    end
    return false
  end
  function self:_find_loops()
    local loops = {}
    for latch in pairs(self.reachable) do
      local lt = self.B[latch].term
      if lt and lt[1] == "jmp" then
        local h = lt[2]
        if self.dom[h] and self.dom[h][latch] then
          local ht = self.B[h].term
          if ht and ht[1] == "branch" then
            local tb, fb = ht[3], ht[4]
            if self:_can_reach(tb, latch) then loops[h] = {latch, fb, tb}
            elseif self:_can_reach(fb, latch) then loops[h] = {latch, tb, fb} end
          end
        end
      end
    end
    return loops
  end
  function self:_split_body(bid)
    local body = self.B[bid].body
    local normal = {}
    local retargs = nil
    for _, s in ipairs(body) do
      if (s[1] == "let" or s[1] == "setvar") and s[2] == self.retvar and isAst(s[3]) and s[3][1] == "table" then
        retargs = {}
        for _, kv in ipairs(s[3][2]) do retargs[#retargs+1] = kv[2] end
      elseif s[1] == "assign" and #s[2] == 1 and isAst(s[2][1]) and s[2][1][1] == "var" and s[2][1][2] == self.retvar then
        if isAst(s[3][1]) and s[3][1][1] == "table" then
          retargs = {}
          for _, kv in ipairs(s[3][1][2]) do retargs[#retargs+1] = kv[2] end
        else
          normal[#normal+1] = s
        end
      else
        normal[#normal+1] = s
      end
    end
    return normal, retargs
  end
  function self:structure()
    local ok, stmts = pcall(function()
      return self:_region(self.entry, {}, nil)
    end)
    if not ok then
      return {SReturn({})}
    end
    return stmts
  end
  function self:_region(cur, stop, loopctx)
    local out = {}
    local guard = 0
    while cur ~= nil and not stop[cur] do
      guard = guard + 1
      if guard > 200000 then error("结构化死循环") end
      if not self.B[cur] then return out, cur end
      local b = self.B[cur]
      local normal, retargs = self:_split_body(cur)
      local term = b.term
      if term == nil then
        for _, s in ipairs(normal) do out[#out+1] = s end
        return out, nil
      elseif term[1] == "exit" then
        for _, s in ipairs(normal) do out[#out+1] = s end
        out[#out+1] = SReturn(retargs or {})
        return out, nil
      elseif term[1] == "jmp" then
        local tgt = term[2]
        if loopctx then
          local h, fin = loopctx[1], loopctx[2]
          if tgt == h then
            for _, s in ipairs(normal) do out[#out+1] = s end
            out[#out+1] = SLoopCtrl("continue")
            return out, nil
          end
          if tgt == fin then
            for _, s in ipairs(normal) do out[#out+1] = s end
            out[#out+1] = SLoopCtrl("break")
            return out, nil
          end
        end
        if stop[tgt] then
          for _, s in ipairs(normal) do out[#out+1] = s end
          return out, tgt
        end
        for _, s in ipairs(normal) do out[#out+1] = s end
        cur = tgt
      elseif term[1] == "branch" then
        local cond, t, f = term[2], term[3], term[4]
        for _, s in ipairs(normal) do out[#out+1] = s end
        if self.loops[cur] then
          local loopinfo = self.loops[cur]
          local latch, final, body_entry = loopinfo[1], loopinfo[2], loopinfo[3]
          local body, _ = self:_region(body_entry, {[cur]=true, [final]=true}, {cur, final})
          local newbody = {}
          for _, x in ipairs(body) do
            if not (x.tag == "loopctrl" and x.k == "continue") then newbody[#newbody+1] = x end
          end
          out[#out+1] = SWhile(cond, newbody)
          if stop[final] then return out, final end
          cur = final
        else
          local join = self:ipostdom(cur)
          local bound = {}
          for k in pairs(stop) do bound[k] = true end
          if join ~= nil and join ~= VEXIT then bound[join] = true end
          local then_stmts, t_next = self:_region(t, bound, loopctx)
          local else_stmts, e_next = self:_region(f, bound, loopctx)
          local t_empty = (t == join)
          local f_empty = (f == join)
          if f_empty then
            out[#out+1] = SIf(cond, then_stmts)
          elseif t_empty then
            out[#out+1] = SIf({"un", "not", cond}, else_stmts)
          else
            out[#out+1] = SIf(cond, then_stmts, else_stmts)
          end
          if join ~= nil and stop[join] then return out, join end
          if join == VEXIT or join == nil then return out, nil end
          cur = join
        end
      else
        for _, s in ipairs(normal) do out[#out+1] = s end
        return out, nil
      end
    end
    return out, cur
  end
  -- 初始化
  self.reachable = self:_reachable()
  self.dom = self:_dom_on(self:_pred_succ(self.reachable, false), entry)
  self.pdom = self:_postdom()
  self.loops = self:_find_loops()
  return self
end

M.Structurer_new = Structurer_new

-- ============================================================
-- 代码生成
-- ============================================================

-- ============================================================
-- 运行时代码消除器
-- ============================================================

local function eliminate_runtime_code(body, R)
  local runtime_vars = {
    [R.posvar] = true, [R.returnvar] = true,
    [R.cont.argsvar] = true, [R.vm.upvalsvar] = true,
    [R.vm.gcvar] = true, [R.constinfo.arrvar] = true,
    [R.constinfo.wrapper] = true,
    V = true, W = true, M = true,
  }
  local runtime_func_names = {
    pcall=true, xpcall=true, error=true, assert=true,
    tostring=true, tonumber=true, type=true, select=true, unpack=true,
    rawget=true, rawset=true, rawequal=true,
    setmetatable=true, getmetatable=true, newproxy=true,
    pairs=true, ipairs=true, next=true,
  }
  local runtime_lib_funcs = {
    ["string.gmatch"]=true, ["string.gsub"]=true, ["string.byte"]=true,
    ["string.char"]=true, ["string.sub"]=true, ["string.len"]=true,
    ["string.format"]=true, ["string.find"]=true, ["string.rep"]=true,
    ["math.random"]=true, ["math.randomseed"]=true, ["math.floor"]=true,
    ["math.ceil"]=true, ["math.abs"]=true, ["math.sqrt"]=true,
    ["table.concat"]=true, ["table.insert"]=true, ["table.remove"]=true,
    ["table.sort"]=true, ["os.clock"]=true, ["os.time"]=true,
  }
  local user_funcs = {
    print=true, warn=true,
    -- Roblox实例方法
    ["Instance.new"]=true, ["game.GetService"]=true, ["game:HttpGet"]=true,
    ["game.HttpGet"]=true, ["game:HttpPost"]=true, ["game.HttpPost"]=true,
    ["workspace.FindFirstChild"]=true, ["workspace:FindFirstChild"]=true,
    ["script.FindFirstChild"]=true, ["script:FindFirstChild"]=true,
    -- Roblox事件
    ["Connect"]=true, ["connect"]=true, ["Wait"]=true, ["wait"]=true,
    -- 任务库
    ["task.spawn"]=true, ["task.wait"]=true, ["task.delay"]=true, ["task.cancel"]=true,
    -- 延迟函数
    ["delay"]=true, ["spawn"]=true,
    -- Delta UI库函数
    ["LoadLucide"]=true, ["GetIcon"]=true, ["ParseImageAsset"]=true,
    ["create"]=true, ["corner"]=true, ["updateCornerRadius"]=true, ["stroke"]=true,
    ["loadConfig"]=true, ["getThemeGradientColors"]=true,
    -- UI库函数
    ["CreateWindow"]=true, ["Toggle"]=true, ["Tab"]=true, ["Button"]=true,
    ["Dropdown"]=true, ["Input"]=true, ["Paragraph"]=true, ["Section"]=true,
    ["setLoop"]=true, ["Notify"]=true,
    -- 远程事件
    ["FireServer"]=true, ["InvokeServer"]=true, ["FireClient"]=true, ["InvokeClient"]=true,
    -- 文件操作（exploit函数，但也是用户代码常用）
    ["isfile"]=true, ["readfile"]=true, ["writefile"]=true,
    ["isfolder"]=true, ["makefolder"]=true, ["delfile"]=true, ["delfolder"]=true,
    ["listfiles"]=true, ["listfolders"]=true,
    -- 其他exploit函数
    ["getcustomasset"]=true, ["getsynasset"]=true, ["request"]=true,
    ["syn.request"]=true, ["http.request"]=true, ["http_request"]=true,
    ["loadstring"]=true, ["LoadString"]=true,
    -- 游戏相关
    ["getgenv"]=true, ["getrenv"]=true, ["getgc"]=true, ["getrawmetatable"]=true,
    ["setrawmetatable"]=true, ["hookfunction"]=true, ["hookmetamethod"]=true,
    ["getnamecallmethod"]=true, ["setnamecallmethod"]=true,
    -- 字符串/表操作（用户代码常用）
    ["string.split"]=true, ["string.trim"]=true, ["string.upper"]=true, ["string.lower"]=true,
    ["table.find"]=true, ["table.create"]=true, ["table.freeze"]=true, ["table.clone"]=true,
    -- 数学函数（用户代码常用）
    ["math.clamp"]=true, ["math.sign"]=true, ["math.round"]=true, ["math.noise"]=true,
    -- 颜色函数
    ["Color3.fromRGB"]=true, ["Color3.fromHSV"]=true, ["Color3.new"]=true,
    ["Color3.fromHex"]=true,
    -- CFrame函数
    ["CFrame.new"]=true, ["CFrame.Angles"]=true, ["CFrame.fromEulerAnglesXYZ"]=true,
    -- Vector函数
    ["Vector2.new"]=true, ["Vector3.new"]=true,
    -- UDim函数
    ["UDim2.new"]=true, ["UDim.new"]=true,
    -- Enum函数
    ["Enum.new"]=true,
    -- Tween函数
    ["TweenInfo.new"]=true,
    -- 实例方法
    ["FindFirstChild"]=true, ["FindFirstChildOfClass"]=true, ["FindFirstAncestor"]=true,
    ["FindFirstAncestorOfClass"]=true, ["FindFirstAncestorWhichIsA"]=true,
    ["FindFirstChildWhichIsA"]=true, ["IsA"]=true, ["IsDescendantOf"]=true,
    ["IsAncestorOf"]=true, ["GetChildren"]=true, ["GetDescendants"]=true,
    ["WaitForChild"]=true, ["Clone"]=true, ["Destroy"]=true, ["ClearAllChildren"]=true,
    ["GetAttribute"]=true, ["SetAttribute"]=true, ["GetAttributes"]=true,
    ["GetPropertyChangedSignal"]=true, ["Changed"]=true, ["ChildAdded"]=true,
    ["ChildRemoved"]=true, ["DescendantAdded"]=true, ["DescendantRemoved"]=true,
    ["GetTouchingParts"]=true, ["Touched"]=true, ["TouchEnded"]=true,
    ["MouseHit"]=true, ["MouseTarget"]=true, ["MouseOrigin"]=true,
    ["ViewSizeX"]=true, ["ViewSizeY"]=true, ["WorldToScreenPoint"]=true,
    ["ScreenPointToRay"]=true, ["ViewportPointToRay"]=true,
    ["UnitRay"]=true, ["GetPartsInPart"]=true, ["GetPartBoundsInBox"]=true,
    ["GetPartBoundsInRadius"]=true, ["GetPartsInPart"]=true,
    -- 玩家方法
    ["Kick"]=true, ["LoadCharacter"]=true, ["GetFriendsOnline"]=true,
    ["GetRankInGroup"]=true, ["GetRoleInGroup"]=true, ["IsFriendsWith"]=true,
    ["FollowUserId"]=true, ["BlockUserId"]=true, ["UnblockUserId"]=true,
    -- 角色方法
    ["MoveTo"]=true, ["ChangeState"]=true, ["LoadAnimation"]=true,
    ["Play"]=true, ["Stop"]=true, ["AdjustSpeed"]=true, ["AdjustWeight"]=true,
    -- 工具方法
    ["EquipTool"]=true, ["UnequipTools"]=true, ["Activate"]=true, ["Deactivate"]=true,
    -- 人体方法
    ["AddForce"]=true, ["SetStateEnabled"]=true, ["GetStateEnabled"]=true,
    ["ApplyDescription"]=true, ["GetAppliedDescription"]=true,
    ["BreakJoints"]=true, ["MakeJoints"]=true,
    -- 相机方法
    ["ScreenPointToRay"]=true, ["ViewportPointToRay"]=true,
    ["WorldToScreenPoint"]=true, ["WorldToViewportPoint"]=true,
    ["GetPartsObscuringTarget"]=true, ["GetRenderCFrame"]=true,
    -- 声音方法
    ["Play"]=true, ["Pause"]=true, ["Stop"]=true, ["Resume"]=true,
    ["SetVolume"]=true, ["GetVolume"]=true,
    -- 动画方法
    ["Play"]=true, ["Stop"]=true, ["AdjustSpeed"]=true, ["AdjustWeight"]=true,
    ["GetTimeOfKeyframe"]=true, ["GetKeyframes"]=true,
    -- 物理方法
    ["ApplyImpulse"]=true, ["ApplyAngularImpulse"]=true, ["SetNetworkOwner"]=true,
    ["GetNetworkOwner"]=true, ["SetNetworkOwnershipAuto"]=true,
    ["IsNetworkOwner"]=true, ["CanSetNetworkOwnership"]=true,
    -- 约束方法
    ["Activate"]=true, ["Deactivate"]=true,
    -- 粒子方法
    ["Emit"]=true, ["Clear"]=true, ["SetAttribute"]=true,
    -- 光照方法
    ["GetMinutesAfterMidnight"]=true, ["SetMinutesAfterMidnight"]=true,
    -- 地形方法
    ["FillBlock"]=true, ["FillBall"]=true, ["FillCylinder"]=true,
    ["FillRegion"]=true, ["ReadVoxels"]=true, ["WriteVoxels"]=true,
    ["GetCell"]=true, ["GetCells"]=true, ["CopyRegion"]=true, ["PasteRegion"]=true,
    -- 数据存储方法
    ["GetAsync"]=true, ["SetAsync"]=true, ["UpdateAsync"]=true,
    ["RemoveAsync"]=true, ["IncrementAsync"]=true, ["GetSortedAsync"]=true,
    ["GetVersionAsync"]=true, ["RemoveVersionAsync"]=true, ["ListKeysAsync"]=true,
    ["ListVersionsAsync"]=true, ["ListDataStoresAsync"]=true, ["ListGlobalStoresAsync"]=true,
    ["OnUpdate"]=true, ["GetGlobalDataStore"]=true, ["GetDataStore"]=true,
    ["GetOrderedDataStore"]=true,
    -- 消息服务方法
    ["PublishAsync"]=true, ["SubscribeAsync"]=true, ["UnsubscribeAsync"]=true,
    -- 文本服务方法
    ["FilterStringAsync"]=true, ["FilterStringForBroadcast"]=true,
    ["GetTextObjectAsync"]=true, ["GetTextSize"]=true, ["GetBoundsSize"]=true,
    ["GetBoundsFromTextSize"]=true,
    -- 游戏通行证服务方法
    ["UserOwnsGamePassAsync"]=true, ["PromptGamePassPurchase"]=true,
    ["GetGamePassProductInfo"]=true,
    -- 市场服务方法
    ["PromptProductPurchase"]=true, ["PromptPurchase"]=true,
    ["GetProductInfo"]=true, ["UserOwnsGamePassAsync"]=true,
    ["PlayerOwnsAsset"]=true, ["PromptGamePassPurchase"]=true,
    -- 插入服务方法
    ["LoadAsset"]=true, ["LoadAssetVersion"]=true, ["CreateMeshPartAsync"]=true,
    -- 选择服务方法
    ["Get"]=true, ["Set"]=true, ["Add"]=true, ["Remove"]=true, ["Toggle"]=true,
    -- 启动设置方法
    ["Get"]=true, ["Set"]=true,
    -- 工作区方法
    ["FindPartOnRay"]=true, ["FindPartOnRayWithWhitelist"]=true,
    ["FindPartOnRayWithIgnoreList"]=true, ["FindPartOnRayWithWhitelist"]=true,
    ["Raycast"]=true, ["GetPartBoundsInBox"]=true, ["GetPartBoundsInRadius"]=true,
    ["GetPartsInPart"]=true, ["GetPartsInPart"]=true,
    ["GetTouchingParts"]=true, ["GetPartsInPart"]=true,
    -- 玩家服务方法
    ["GetPlayers"]=true, ["GetPlayerFromCharacter"]=true,
    ["GetPlayerByUserId"]=true, ["GetFriendsOnline"]=true,
    ["GetUserThumbnailAsync"]=true, ["GetNameFromUserIdAsync"]=true,
    ["GetUserIdFromNameAsync"]=true,
    -- 照明服务方法
    ["GetMinutesAfterMidnight"]=true, ["SetMinutesAfterMidnight"]=true,
    -- 运行服务方法
    ["BindToRenderStep"]=true, ["UnbindFromRenderStep"]=true,
    ["BindToClose"]=true, ["IsStudio"]=true, ["IsRunMode"]=true,
    ["IsClient"]=true, ["IsServer"]=true, ["IsEdit"]=true,
    ["IsStudioAccess"]=true, ["IsFile"]=true,
    -- 用户输入服务方法
    ["GetMouseLocation"]=true, ["GetKeysPressed"]=true,
    ["GetGamepadState"]=true, ["GetConnectedGamepads"]=true,
    ["IsGamepadConnected"]=true, ["IsKeyDown"]=true, ["IsMouseButtonDown"]=true,
    ["GetNavigationGamepads"]=true, ["SetNavigationGamepads"]=true,
    ["GetSupportedInputTypes"]=true, ["GetLastInputType"]=true,
    ["SetNavigationGamepads"]=true,
    -- 声音服务方法
    ["GetListener"]=true, ["SetListener"]=true,
    -- 动画控制器方法
    ["GetPlayingAnimationTracks"]=true, ["LoadAnimation"]=true,
    -- 人体描述方法
    ["GetAppliedDescription"]=true, ["ApplyDescription"]=true,
    ["GetHumanoidDescriptionFromUserId"]=true, ["GetHumanoidDescriptionFromOutfitId"]=true,
    -- 组服务方法
    ["GetGroupInfoAsync"]=true, ["GetGroupsAsync"]=true,
    ["GetRankInGroup"]=true, ["GetRoleInGroup"]=true,
    -- 徽章服务方法
    ["UserHasBadgeAsync"]=true, ["AwardBadge"]=true, ["GetBadgeInfoAsync"]=true,
    -- 分析服务方法
    ["LogEvent"]=true, ["TrackEvent"]=true,
    -- 内容保护服务方法
    ["ProtectInstance"]=true, ["UnprotectInstance"]=true,
    -- 虚拟用户方法
    ["CaptureIcon"]=true, ["Button1Down"]=true, ["Button1Up"]=true,
    ["Button2Down"]=true, ["Button2Up"]=true, ["KeyDown"]=true, ["KeyUp"]=true,
    ["MouseMove"]=true, ["SetMouseLocation"]=true, ["SendKeyEvent"]=true,
    ["SendMouseEvent"]=true, ["SendScrollWheelEvent"]=true,
    -- 虚拟输入服务方法
    ["SendKeyEvent"]=true, ["SendMouseEvent"]=true, ["SendScrollWheelEvent"]=true,
    ["SendTextInput"]=true,
    -- 路径寻找服务方法
    ["CreatePath"]=true, ["GetAgents"]=true,
    -- 路径方法
    ["Run"]=true, ["Stop"]=true, ["CheckOcclusionAsync"]=true,
    ["GetWaypoints"]=true, ["Status"]=true,
    -- 导航网格方法
    ["ComputeAsync"]=true, ["FindPathAsync"]=true,
    -- 角色移动方法
    ["MoveTo"]=true, ["CheckPathCollision"]=true,
    -- 控制模块方法
    ["GetMoveVector"]=true, ["IsMovePressed"]=true, ["IsJumpPressed"]=true,
    -- 相机控制模块方法
    ["GetCameraCFrame"]=true, ["GetCameraFocus"]=true,
    -- 玩家模块方法
    ["GetControls"]=true, ["GetCamera"]=true, ["GetClickDetector"]=true,
    -- 点击检测器方法
    ["MaxActivationDistance"]=true, ["CursorIcon"]=true,
    -- 探测器方法
    ["MaxActivationDistance"]=true, ["CursorIcon"]=true,
    -- 提示方法
    ["Enabled"]=true, ["Duration"]=true,
    -- 选择框方法
    ["Adornee"]=true, ["Color3"]=true, ["LineThickness"]=true,
    -- 表面外观方法
    ["Face"]=true, ["Transparency"]=true, ["Color3"]=true,
    -- 贴花方法
    ["Face"]=true, ["Texture"]=true, ["Transparency"]=true,
    -- 纹理方法
    ["Face"]=true, ["Texture"]=true, ["Transparency"]=true,
    -- 火花方法
    ["Enabled"]=true, ["Color"]=true, ["SecondaryColor"]=true,
    -- 火焰方法
    ["Enabled"]=true, ["Color"]=true, ["SecondaryColor"]=true,
    -- 烟雾方法
    ["Enabled"]=true, ["Color"]=true, ["Opacity"]=true, ["Size"]=true,
    -- 粒子发射器方法
    ["Enabled"]=true, ["Color"]=true, ["Size"]=true, ["Transparency"]=true,
    ["Lifetime"]=true, ["Rate"]=true, ["Speed"]=true, ["SpreadAngle"]=true,
    ["Texture"]=true, ["Acceleration"]=true, ["Drag"]=true, ["Rotation"]=true,
    ["RotSpeed"]=true, ["EmissionDirection"]=true, ["Squash"]=true,
    ["TimeScale"]=true, ["VelocityInheritance"]=true, ["VelocitySpread"]=true,
    ["LightEmission"]=true, ["LightInfluence"]=true, ["TextureLength"]=true,
    ["TextureMode"]=true, ["ZOffset"]=true,
    -- 光束方法
    ["Enabled"]=true, ["Color"]=true, ["Transparency"]=true, ["Width0"]=true,
    ["Width1"]=true, ["FaceCamera"]=true, ["LightEmission"]=true,
    ["LightInfluence"]=true, ["Texture"]=true, ["TextureLength"]=true,
    ["TextureMode"]=true, ["TextureSpeed"]=true, ["ZOffset"]=true,
    -- 轨迹方法
    ["Enabled"]=true, ["Color"]=true, ["Transparency"]=true, ["Width0"]=true,
    ["Width1"]=true, ["FaceCamera"]=true, ["LightEmission"]=true,
    ["LightInfluence"]=true, ["Texture"]=true, ["TextureLength"]=true,
    ["TextureMode"]=true, ["TextureSpeed"]=true, ["ZOffset"]=true,
    -- 高亮方法
    ["Enabled"]=true, ["FillColor"]=true, ["OutlineColor"]=true,
    ["FillTransparency"]=true, ["OutlineTransparency"]=true, ["DepthMode"]=true,
    -- 选择框方法
    ["Adornee"]=true, ["Color3"]=true, ["LineThickness"]=true,
    ["SurfaceTransparency"]=true, ["SurfaceColor3"]=true, ["AlwaysOnTop"]=true,
    -- 表面选择方法
    ["Adornee"]=true, ["Surface"]=true, ["SurfaceColor3"]=true,
    ["SurfaceTransparency"]=true,
    -- 部件方法
    ["CanCollide"]=true, ["CanTouch"]=true, ["CanQuery"]=true, ["CanSimulate"]=true,
    ["Anchored"]=true, ["Mass"]=true, ["Material"]=true, ["Color"]=true,
    ["Transparency"]=true, ["Reflectance"]=true, ["Size"]=true,
    ["Position"]=true, ["CFrame"]=true, ["Orientation"]=true,
    ["Rotation"]=true, ["Velocity"]=true, ["RotVelocity"]=true,
    ["AssemblyLinearVelocity"]=true, ["AssemblyAngularVelocity"]=true,
    ["AssemblyCenterOfMass"]=true, ["AssemblyMass"]=true,
    ["AssemblyRootPart"]=true, ["CenterOfMass"]=true,
    ["GetConnectedParts"]=true, ["GetRootPart"]=true, ["GetJoints"]=true,
    ["BreakJoints"]=true, ["MakeJoints"]=true, ["GetTouchingParts"]=true,
    ["CanSetNetworkOwnership"]=true, ["GetNetworkOwner"]=true,
    ["SetNetworkOwner"]=true, ["SetNetworkOwnershipAuto"]=true,
    ["IsNetworkOwner"]=true, ["ApplyImpulse"]=true, ["ApplyAngularImpulse"]=true,
    ["GetBoundsAligned"]=true, ["GetBoundingBox"]=true,
    -- 模型方法
    ["GetBoundingBox"]=true, ["GetExtentsSize"]=true, ["MoveTo"]=true,
    ["TranslateBy"]=true, ["ScaleTo"]=true, ["GetScale"]=true,
    ["PrimaryPart"]=true, ["WorldPivot"]=true, ["WorldOrigin"]=true,
    ["GetPivot"]=true, ["PivotTo"]=true,
    -- 文件夹方法
    ["GetChildren"]=true, ["FindFirstChild"]=true,
    -- 配置方法
    ["GetAttribute"]=true, ["SetAttribute"]=true, ["GetAttributes"]=true,
    -- 附件方法
    ["Position"]=true, ["Orientation"]=true, ["CFrame"]=true,
    ["Axis"]=true, ["SecondaryAxis"]=true, ["WorldAxis"]=true,
    ["WorldSecondaryAxis"]=true, ["WorldCFrame"]=true, ["WorldPosition"]=true,
    -- 约束方法
    ["Enabled"]=true, ["Visible"]=true, ["Color"]=true, ["Thickness"]=true,
    ["Attachment0"]=true, ["Attachment1"]=true,
    -- 弹簧约束方法
    ["FreeLength"]=true, ["Stiffness"]=true, ["Damping"]=true, ["MaxForce"]=true,
    ["MaxExtents"]=true, ["Relaxation"]=true,
    -- 杆约束方法
    ["Length"]=true, ["Thickness"]=true, ["Visible"]=true, ["Color"]=true,
    -- 绳索约束方法
    ["Length"]=true, ["Thickness"]=true, ["Visible"]=true, ["Color"]=true,
    ["WinchEnabled"]=true, ["WinchSpeed"]=true, ["WinchTarget"]=true,
    -- 铰链约束方法
    ["ActuatorType"]=true, ["AngularVelocity"]=true, ["MotorMaxAcceleration"]=true,
    ["MotorMaxTorque"]=true, ["ServoMaxTorque"]=true, ["TargetAngle"]=true,
    ["TargetVelocity"]=true, ["LimitsEnabled"]=true, ["LowerAngle"]=true,
    ["UpperAngle"]=true, ["Restitution"]=true,
    -- 圆柱约束方法
    ["ActuatorType"]=true, ["AngularVelocity"]=true, ["MotorMaxAcceleration"]=true,
    ["MotorMaxTorque"]=true, ["ServoMaxTorque"]=true, ["TargetAngle"]=true,
    ["TargetVelocity"]=true, ["LimitsEnabled"]=true, ["LowerAngle"]=true,
    ["UpperAngle"]=true, ["Restitution"]=true,
    -- 球形约束方法
    ["LimitsEnabled"]=true, ["UpperAngle"]=true, ["Restitution"]=true,
    -- 棱柱约束方法
    ["ActuatorType"]=true, ["Velocity"]=true, ["MotorMaxAcceleration"]=true,
    ["MotorMaxForce"]=true, ["ServoMaxForce"]=true, ["TargetPosition"]=true,
    ["LimitsEnabled"]=true, ["LowerLimit"]=true, ["UpperLimit"]=true,
    ["Restitution"]=true,
    -- 扭矩约束方法
    ["Torque"]=true, ["AngularVelocity"]=true, ["MaxTorque"]=true,
    -- 力约束方法
    ["Force"]=true, ["Velocity"]=true, ["MaxForce"]=true,
    -- 线速度约束方法
    ["Velocity"]=true, ["MaxForce"]=true, ["VectorVelocity"]=true,
    ["PlaneVelocity"]=true, ["LineVelocity"]=true,
    -- 角速度约束方法
    ["AngularVelocity"]=true, ["MaxTorque"]=true,
    -- 对齐方向约束方法
    ["AngularVelocity"]=true, ["MaxTorque"]=true, ["Responsiveness"]=true,
    ["Mode"]=true, ["PrimaryAxis"]=true, ["SecondaryAxis"]=true,
    ["CFrame"]=true,
    -- 对齐位置约束方法
    ["Velocity"]=true, ["MaxForce"]=true, ["Responsiveness"]=true,
    ["Mode"]=true, ["Position"]=true, ["CFrame"]=true,
    -- 对齐方向约束方法
    ["AngularVelocity"]=true, ["MaxTorque"]=true, ["Responsiveness"]=true,
    ["Mode"]=true, ["PrimaryAxis"]=true, ["SecondaryAxis"]=true,
    ["CFrame"]=true,
    -- 对齐位置约束方法
    ["Velocity"]=true, ["MaxForce"]=true, ["Responsiveness"]=true,
    ["Mode"]=true, ["Position"]=true, ["CFrame"]=true,
    -- 向量力约束方法
    ["Force"]=true, ["ApplyAtCenterOfMass"]=true, ["Location"]=true,
    -- 向量扭矩约束方法
    ["Torque"]=true, ["ApplyAtCenterOfMass"]=true,
    -- 角速度约束方法
    ["AngularVelocity"]=true, ["MaxTorque"]=true,
    -- 线速度约束方法
    ["Velocity"]=true, ["MaxForce"]=true,
    -- 对齐方向约束方法
    ["AngularVelocity"]=true, ["MaxTorque"]=true,
    -- 对齐位置约束方法
    ["Velocity"]=true, ["MaxForce"]=true,
    -- 向量力约束方法
    ["Force"]=true,
    -- 向量扭矩约束方法
    ["Torque"]=true,
    -- 角速度约束方法
    ["AngularVelocity"]=true,
    -- 线速度约束方法
    ["Velocity"]=true,
    -- 对齐方向约束方法
    ["AngularVelocity"]=true,
    -- 对齐位置约束方法
    ["Velocity"]=true,
    -- 向量力约束方法
    ["Force"]=true,
    -- 向量扭矩约束方法
    ["Torque"]=true,
  }

  local function dc(t)
    if type(t) ~= "table" then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = dc(v) end
    return r
  end
  local function has_user_string(e)
    if type(e) ~= "table" then return false end
    if e[1] == "str" and type(e[2]) == "string" then
      local s = e[2]
      -- 非ASCII字符（中文字符串等）
      if s:find("[^ -~]") then return true end
      -- 用户定义的ASCII字符串特征
      local user_str_patterns = {
        "DeltaUI", "rbxassetid", "rbxasset", "http", "https",
        "Players", "UserInputService", "CoreGui", "ReplicatedStorage",
        "TweenService", "RunService", "Stats", "HttpService",
        "ScreenGui", "Frame", "TextLabel", "TextButton", "ScrollingFrame",
        "UIListLayout", "UICorner", "UIGridLayout", "UIStroke", "UIPadding",
        "ImageLabel", "ImageButton", "TextBox", "LocalScript", "Script",
        "Shirt", "Pants", "ShirtTemplate", "PantsTemplate", "Humanoid",
        "HumanoidRootPart", "Torso", "Character", "Backpack", "Tool",
        "RemoteEvent", "RemoteFunction", "rEvents", "Folder", "Model",
        "Instance", "Enum", "Vector2", "Vector3", "CFrame", "Color3",
        "UDim2", "UDim", "ColorSequence", "NumberSequence",
        "game", "workspace", "script", "owner", "creator",
        "MouseButton1Click", "MouseButton1Down", "MouseButton1Up",
        "MouseEnter", "MouseLeave", "InputBegan", "InputChanged", "InputEnded",
        "Touched", "TouchEnded", "ChildAdded", "ChildRemoved",
        "GetService", "FindFirstChild", "FindFirstChildOfClass", "IsA",
        "GetChildren", "GetDescendants", "WaitForChild", "Clone", "Destroy",
        "FireServer", "InvokeServer", "FireClient", "InvokeClient",
        "LoadString", "loadstring", "HttpGet", "HttpPost",
        "isfile", "readfile", "writefile", "isfolder", "makefolder",
        "getcustomasset", "getsynasset", "syn", "request",
        "Lucide", "GetAsset", "ImageRectOffset", "ImageRectSize",
        "ScaleType", "Fit", "ImageColor3", "BackgroundTransparency",
        "TextColor3", "TextSize", "TextXAlignment", "TextYAlignment",
        "Font", "SourceSans", "SourceSansBold",
        "ZIndexBehavior", "Sibling", "Global", "BorderSizePixel",
        "ClipsDescendants", "CanvasSize", "ScrollBarThickness",
        "ScrollingDirection", "Padding", "HorizontalAlignment", "VerticalAlignment",
        "CornerRadius", "Thickness", "Transparency",
        "Size", "Position", "Parent", "Name", "Visible", "Active",
        "AutoButtonColor", "ZIndex", "AutoLocalize",
        "Luraph", "cleanLuraphPrefix", "Luraph Script",
        "gradients", "Theme", "config", "loadConfig",
        "safeRun", "notify", "getRemote", "callRemote",
        "petShop", "cPetShop", "petsFolder",
        "Button", "Toggle", "Tab", "Dropdown", "Input", "Paragraph", "Section",
        "CreateWindow", "WindUI", "setLoop",
      }
      for _, pat in ipairs(user_str_patterns) do
        if s:find(pat, 1, true) then return true end
      end
    end
    for i = 2, #e do if type(e[i]) == "table" and has_user_string(e[i]) then return true end end
    return false
  end
  local function get_func_name(e)
    if type(e) ~= "table" or e[1] ~= "call" then return nil end
    local fn = e[2]
    if type(fn) ~= "table" then return nil end
    if fn[1] == "var" then return fn[2] end
    if fn[1] == "index" then
      local base, key = fn[2], fn[3]
      if type(base)=="table" and base[1]=="var" and type(key)=="table" and key[1]=="str" then
        return base[2] .. "." .. key[2]
      end
    end
    return nil
  end
  local function is_upval_func_call(e)
    if type(e)~="table" or e[1]~="call" then return false end
    local fn = e[2]
    if type(fn)~="table" or fn[1]~="index" then return false end
    local base, key = fn[2], fn[3]
    if type(base)=="table" and base[1]=="var" and runtime_vars[base[2]] then
      if type(key)=="table" and key[1]=="index" then
        local kbase = key[2]
        if type(kbase)=="table" and kbase[1]=="var" then return true end
      end
      -- 识别 a[v]、a[n]、a[M[1]] 等形式的上值函数调用
      if type(key)=="table" and key[1]=="var" then return true end
      if type(key)=="table" and key[1]=="index" then return true end
    end
    -- 识别单字母变量的索引调用（如 a[v](...)、U(K)(...)）
    if type(base)=="table" and base[1]=="var" and type(base[2])=="string" and #base[2]<=2 then
      if type(key)=="table" and (key[1]=="var" or key[1]=="index" or key[1]=="num") then
        -- 检查是否是运行时变量（单字母大写）
        if base[2]:match("^%u$") or base[2]:match("^%u%u$") then
          return true
        end
      end
    end
    return false
  end
  local function has_user_func_call(e)
    if type(e) ~= "table" then return false end
    if e[1] == "call" then
      local name = get_func_name(e)
      if name and user_funcs[name] then return true end
    end
    for i = 2, #e do if type(e[i]) == "table" and has_user_func_call(e[i]) then return true end end
    return false
  end
  local function has_only_runtime_funcs(e)
    if type(e) ~= "table" then return false end
    local found = false
    if e[1] == "call" then
      local name = get_func_name(e)
      if name then
        if user_funcs[name] then return false end
        if runtime_func_names[name] or runtime_lib_funcs[name] then found = true end
      end
      if is_upval_func_call(e) then found = true end
      local fn = e[2]
      if type(fn)=="table" and fn[1]=="index" then
        local base = fn[2]
        if type(base)=="table" and base[1]=="var" and runtime_vars[base[2]] then found = true end
      end
    end
    for i = 2, #e do
      if type(e[i]) == "table" then
        local r = has_only_runtime_funcs(e[i])
        if r == false then return false end
        if r == true then found = true end
      end
    end
    return found
  end
  local function stmt_has_user(s)
    if s.tag == "if" then
      if has_user_string(s.cond) or has_user_func_call(s.cond) then return true end
      for _, x in ipairs(s["then"] or {}) do if stmt_has_user(x) then return true end end
      for _, x in ipairs(s.els or {}) do if stmt_has_user(x) then return true end end
      return false
    elseif s.tag == "while" then
      if has_user_string(s.cond) or has_user_func_call(s.cond) then return true end
      for _, x in ipairs(s.body or {}) do if stmt_has_user(x) then return true end end
      return false
    elseif s.tag == "return" then
      for _, a in ipairs(s.args or {}) do if has_user_string(a) or has_user_func_call(a) then return true end end
      return false
    else
      for i = 2, #s do
        if type(s[i]) == "table" then if has_user_string(s[i]) or has_user_func_call(s[i]) then return true end end
      end
      return false
    end
  end
  local function expr_has_side_effect(e)
    if type(e) ~= "table" then return false end
    if e[1]=="call" or e[1]=="selfcall" or e[1]=="table" or e[1]=="func" or e[1]=="mkclosure" then return true end
    for i = 2, #e do if type(e[i])=="table" and expr_has_side_effect(e[i]) then return true end end
    return false
  end
  local function is_inlinable(val)
    if type(val) ~= "table" then return type(val) == "number" end
    local k = val[1]
    if k == "num" then return true end
    if k == "str" and type(val[2])=="string" and #val[2] <= 20 then return true end
    if k == "boolean" or k == "nil" then return true end
    return false
  end
  local function expr_vars(e, vars)
    if type(e) ~= "table" then return end
    if e[1]=="var" and type(e[2])=="string" then vars[e[2]]=true end
    for i = 2, #e do if type(e[i])=="table" then expr_vars(e[i], vars) end end
  end
  local function stmt_read_vars(s, vars)
    if s.tag=="if" then
      expr_vars(s.cond, vars)
      for _, x in ipairs(s["then"] or {}) do stmt_read_vars(x, vars) end
      for _, x in ipairs(s.els or {}) do stmt_read_vars(x, vars) end
    elseif s.tag=="while" then
      expr_vars(s.cond, vars)
      for _, x in ipairs(s.body or {}) do stmt_read_vars(x, vars) end
    elseif s.tag=="return" then
      for _, a in ipairs(s.args or {}) do expr_vars(a, vars) end
    else
      for i = 2, #s do if type(s[i])=="table" then expr_vars(s[i], vars) end end
    end
  end
  local function stmt_write_vars(s, writes)
    local k = s[1] or s.tag
    if k=="let" or k=="setvar" then if type(s[2])=="string" then writes[s[2]]=true end
    elseif k=="assign" then
      for _, l in ipairs(s[2] or {}) do if type(l)=="table" and l[1]=="var" then writes[l[2]]=true end end
    elseif k=="local" then for _, n in ipairs(s[2] or {}) do writes[n]=true end end
  end
  local function expr_subst(e, subst)
    if type(e) ~= "table" then return e end
    if e[1]=="var" and subst[e[2]] then return dc(subst[e[2]]) end
    local r = {e[1]}
    for i = 2, #e do r[i] = type(e[i])=="table" and expr_subst(e[i], subst) or e[i] end
    return r
  end
  local function is_pure_runtime(s)
    if stmt_has_user(s) then return false end
    local k = s[1] or s.tag
    if k == "callstmt" then return has_only_runtime_funcs(s[2]) == true end
    if k=="let" or k=="setvar" then
      local name, val = s[2], s[3]
      if type(name) ~= "string" then return false end
      if has_user_func_call(val) or has_user_string(val) then return false end
      if has_only_runtime_funcs(val) == true then return true end
      if not expr_has_side_effect(val) then
        local vars = {}
        expr_vars(val, vars)
        for v in pairs(vars) do if not runtime_vars[v] then return false end end
        return true
      end
      return false
    end
    if k == "assign" then
      for _, r in ipairs(s[3] or {}) do
        if has_user_func_call(r) or has_user_string(r) then return false end
      end
      for _, r in ipairs(s[3] or {}) do
        if has_only_runtime_funcs(r) == true then return true end
        if not expr_has_side_effect(r) then
          local vars = {}
          expr_vars(r, vars)
          for v in pairs(vars) do if not runtime_vars[v] then return false end end
        else return false end
      end
      return true
    end
    if k == "local" then
      for _, r in ipairs(s[3] or {}) do if has_user_func_call(r) or has_user_string(r) then return false end end
      return true
    end
    if s.tag == "return" then
      for _, a in ipairs(s.args or {}) do if has_user_func_call(a) or has_user_string(a) then return false end end
      return true
    end
    if s.tag == "loopctrl" then return true end
    return false
  end

  local current = body
  for iter = 1, 50 do
    local changed = false
    local function remove_runtime(stmts_list)
      local result = {}
      for _, s in ipairs(stmts_list) do
        if s.tag == "if" then
          s["then"] = remove_runtime(s["then"] or {})
          s.els = remove_runtime(s.els or {})
          if #s["then"]==0 and #s.els==0 and not stmt_has_user(s) then changed=true else result[#result+1]=s end
        elseif s.tag == "while" then
          s.body = remove_runtime(s.body or {})
          if #s.body==0 and not stmt_has_user(s) then changed=true else result[#result+1]=s end
        else
          if is_pure_runtime(s) then changed=true else result[#result+1]=s end
        end
      end
      return result
    end
    current = remove_runtime(current)

    local subst = {}
    local function propagate(stmts_list)
      local result = {}
      for _, s in ipairs(stmts_list) do
        if s.tag == "if" then
          s.cond = expr_subst(s.cond, subst)
          s["then"] = propagate(s["then"] or {})
          s.els = propagate(s.els or {})
          result[#result+1] = s
        elseif s.tag == "while" then
          s.cond = expr_subst(s.cond, subst)
          s.body = propagate(s.body or {})
          result[#result+1] = s
        else
          local k = s[1] or s.tag
          if k=="let" or k=="setvar" then s[3]=expr_subst(s[3], subst)
          elseif k=="assign" then
            local nr={}; for _,r in ipairs(s[3] or {}) do nr[#nr+1]=expr_subst(r,subst) end; s[3]=nr
          elseif k=="local" then
            local nr={}; for _,r in ipairs(s[3] or {}) do nr[#nr+1]=expr_subst(r,subst) end; s[3]=nr
          elseif s.tag=="return" then
            local na={}; for _,a in ipairs(s.args or {}) do na[#na+1]=expr_subst(a,subst) end; s.args=na
          elseif k=="callstmt" then s[2]=expr_subst(s[2], subst) end

          if k=="let" or k=="setvar" then
            local name, val = s[2], s[3]
            if type(name)=="string" and is_inlinable(val) and not expr_has_side_effect(val) then
              subst[name]=val; changed=true
            else result[#result+1]=s end
          elseif k=="assign" and #s[2]==1 and type(s[2][1])=="table" and s[2][1][1]=="var" then
            local name, val = s[2][1][2], s[3][1]
            if type(name)=="string" and is_inlinable(val) and not expr_has_side_effect(val) then
              subst[name]=val; changed=true
            else result[#result+1]=s end
          else result[#result+1]=s end
        end
      end
      return result
    end
    current = propagate(current)

    local read_vars = {}
    local function collect_reads(sl) for _, s in ipairs(sl) do stmt_read_vars(s, read_vars) end end
    collect_reads(current)
    local function dce(stmts_list)
      local result = {}
      for _, s in ipairs(stmts_list) do
        if s.tag=="if" then s["then"]=dce(s["then"] or {}); s.els=dce(s.els or {}); result[#result+1]=s
        elseif s.tag=="while" then s.body=dce(s.body or {}); result[#result+1]=s
        else
          local k = s[1] or s.tag
          local writes = {}; stmt_write_vars(s, writes)
          local is_dead = true
          for v in pairs(writes) do if read_vars[v] then is_dead=false break end end
          if k=="callstmt" or s.tag=="return" then is_dead=false end
          if (k=="let" or k=="setvar") and expr_has_side_effect(s[3]) then is_dead=false end
          if is_dead and next(writes)~=nil then changed=true else result[#result+1]=s end
        end
      end
      return result
    end
    current = dce(current)
    if not changed then break end
  end
  return current
end

local function CodeGen_new(decompiler, param_names, indent)
  local self = {
    dc=decompiler,
    ind=indent or "  ",
    param_names=param_names or {},
    _loop_stack={},
    _cont_counter=0,
    _loop_has_cont={},
  }
  function self:_has_continue(stmts)
    for _, s in ipairs(stmts) do
      if s.tag == "loopctrl" and s.k == "continue" then return true end
      if s.tag == "if" then
        if self:_has_continue(s["then"]) then return true end
        if s.els and self:_has_continue(s.els) then return true end
      end
      if s.tag == "while" then
        if self:_has_continue(s.body) then return true end
      end
    end
    return false
  end
  function self:expr(e)
    if not isAst(e) then return tostring(e) end
    if e[1] == "mkclosure" then
      local cid = e[2]
      local table_node = e[3]
      local isvar = e[5]
      local curmap = {}
      for i, kv in ipairs(table_node[2]) do curmap[i] = kv[2] end
      local narg, body, rest, reach = self.dc:decompile_func(cid, curmap)
      local names = self.param_names[cid]
      if not names then
        names = {}
        for i = 1, narg do names[i] = "a" .. i end
      end
      if isvar then names[#names+1] = "..." end
      local lines = self:_stmts(body, 1)
      return "function(" .. table.concat(names, ", ") .. ")\n" .. table.concat(lines, "\n") .. "\n" .. self.ind .. "end"
    end
    if e[1] == "alloc" then return "nil" end
    if e[1] == "drop" then return "nil" end
    if e[1] == "free" then return self:expr(e[2]) end
    return expr_lua(e)
  end
  function self:_stmts(stmts, depth)
    local out = {}
    for _, s in ipairs(stmts) do
      local lines = self:_stmt(s, depth)
      for _, l in ipairs(lines) do out[#out+1] = l end
    end
    return out
  end
  function self:_stmt(s, depth)
    local pad = self.ind:rep(depth)
    if s.tag == "if" then
      local lines = {pad .. "if " .. self:expr(s.cond) .. " then"}
      local then_lines = self:_stmts(s["then"], depth + 1)
      for _, l in ipairs(then_lines) do lines[#lines+1] = l end
      if s.els then
        lines[#lines+1] = pad .. "else"
        local else_lines = self:_stmts(s.els, depth + 1)
        for _, l in ipairs(else_lines) do lines[#lines+1] = l end
      end
      lines[#lines+1] = pad .. "end"
      return lines
    end
    if s.tag == "while" then
      local key = s.kind
      local has_cont = self:_has_continue(s.body)
      if has_cont then
        self._cont_counter = self._cont_counter + 1
        local lid = self._cont_counter
        self._loop_stack[#self._loop_stack+1] = lid
        local lines = {pad .. key .. " " .. self:expr(s.cond) .. " do"}
        lines[#lines+1] = pad .. "  repeat"
        local body_lines = self:_stmts(s.body, depth + 2)
        for _, l in ipairs(body_lines) do lines[#lines+1] = l end
        lines[#lines+1] = pad .. "  until true"
        lines[#lines+1] = pad .. "end"
        table.remove(self._loop_stack)
        return lines
      end
      local lines = {pad .. key .. " " .. self:expr(s.cond) .. " do"}
      local body_lines = self:_stmts(s.body, depth + 1)
      for _, l in ipairs(body_lines) do lines[#lines+1] = l end
      lines[#lines+1] = pad .. "end"
      return lines
    end
    if s.tag == "loopctrl" then
      if s.k == "continue" and #self._loop_stack > 0 then
        return {pad .. "break"}
      end
      return {pad .. s.k}
    end
    if s.tag == "return" then
      if #s.args > 0 then
        local args = {}
        for _, a in ipairs(s.args) do args[#args+1] = self:expr(a) end
        return {pad .. "return " .. table.concat(args, ", ")}
      end
      return {pad .. "return"}
    end
    local k = s[1]
    if k == "let" then return {pad .. "local " .. s[2] .. " = " .. self:expr(s[3])} end
    if k == "setvar" then return {pad .. s[2] .. " = " .. self:expr(s[3])} end
    if k == "assign" then
      local l = {}
      for _, x in ipairs(s[2]) do l[#l+1] = self:expr(x) end
      local r = {}
      for _, x in ipairs(s[3]) do r[#r+1] = self:expr(x) end
      return {pad .. table.concat(l, ", ") .. " = " .. table.concat(r, ", ")}
    end
    if k == "callstmt" then return {pad .. self:expr(s[2])} end
    if k == "local" then
      local names = table.concat(s[2], ", ")
      local vals = {}
      for _, x in ipairs(s[3]) do vals[#vals+1] = self:expr(x) end
      if #s[3] > 0 then
        return {pad .. "local " .. names .. " = " .. table.concat(vals, ", ")}
      end
      return {pad .. "local " .. names}
    end
    if k == "return" then
      local vals = {}
      for _, x in ipairs(s[2]) do vals[#vals+1] = self:expr(x) end
      return {pad .. "return " .. table.concat(vals, ", ")}
    end
    return {pad .. "-- " .. tostring(k)}
  end
  function self:gen_top()
    local narg, body, rest, reach = self.dc:decompile_func(self.dc.top)
    body = eliminate_runtime_code(body, self.dc.R)
    return table.concat(self:_stmts(body, 0), "\n")
  end
  function self:gen_top_ir()
    local narg, body, rest, reach = self.dc:decompile_func(self.dc.top)
    return body
  end
  function self:gen_from_ir(body)
    return table.concat(self:_stmts(body, 0), "\n")
  end
  return self
end

M.CodeGen_new = CodeGen_new

-- ============================================================
-- 反编译驱动
-- ============================================================

local function collect_mkclosures(blocks)
  local m = {}
  local function walk(e)
    if isAst(e) then
      if e[1] == "mkclosure" then
        m[e[2]] = {e[3], e[4], e[5]}
      end
      for i = 2, #e do
        local p = e[i]
        if isAst(p) then walk(p)
        elseif type(p) == "table" then
          for _, x in ipairs(p) do
            if isAst(x) then walk(x)
            elseif type(x) == "table" then
              for _, y in ipairs(x) do if isAst(y) then walk(y) end end
            end
          end
        end
      end
    end
  end
  for _, b in pairs(blocks) do
    for _, s in ipairs(b.body) do
      for i = 2, #s do
        local p = s[i]
        if isAst(p) then walk(p)
        elseif type(p) == "table" then
          for _, x in ipairs(p) do
            if isAst(x) then walk(x) end
          end
        end
      end
    end
  end
  return m
end

local function Decompiler_new(R)
  local self = {
    R=R,
    blocks=R.blocks,
    cont=R.cont,
    retvar=R.returnvar,
    pv=R.posvar,
    top=R.cont.startid,
    mk=collect_mkclosures(R.blocks),
    done={},
    restorers={},
  }
  function self:reachable(entry)
    local seen = {[entry]=true}
    local st = {entry}
    while #st > 0 do
      local x = table.remove(st)
      if self.blocks[x] then
        local t = self.blocks[x].term
        local succs
        if t and t[1] == "jmp" then succs = {t[2]}
        elseif t and t[1] == "branch" then succs = {t[3], t[4]}
        else succs = {} end
        for _, y in ipairs(succs) do
          if self.blocks[y] and not seen[y] then seen[y] = true; st[#st+1] = y end
        end
      end
    end
    return seen
  end
  function self:infer_params(reach, argsvar)
    local maxn = 0
    local function walk(e)
      if isAst(e) then
        if e[1] == "index" and isAst(e[2]) and e[2][1] == "var" and e[2][2] == argsvar and isAst(e[3]) and e[3][1] == "num" then
          maxn = math.max(maxn, math.floor(e[3][2]))
        end
        for i = 2, #e do
          local p = e[i]
          if isAst(p) then walk(p)
          elseif type(p) == "table" then
            for _, x in ipairs(p) do
              if isAst(x) then walk(x)
              elseif type(x) == "table" then
                for _, y in ipairs(x) do if isAst(y) then walk(y) end end
              end
            end
          end
        end
      end
    end
    for bid in pairs(reach) do
      for _, s in ipairs(self.blocks[bid].body) do
        for i = 2, #s do
          local p = s[i]
          if isAst(p) then walk(p)
          elseif type(p) == "table" then
            for _, x in ipairs(p) do if isAst(x) then walk(x) end end
          end
        end
      end
    end
    return maxn
  end
  function self:decompile_func(entry, curmap)
    if self.done[entry] then
      local r = self.done[entry]
      return r[1], r[2], r[3], r[4]
    end
    curmap = curmap or {}
    local rest = UpvalueRestorer_new(self.cont, curmap)
    local reach = self:reachable(entry)
    for bid in pairs(reach) do
      self.blocks[bid].body = rest:restore_body(self.blocks[bid].body)
    end
    for _ = 1, 60 do
      local probe = Structurer_new(self.blocks, entry, self.retvar, self.pv, self.cont)
      local pd = {}
      for n in pairs(probe.reachable) do pd[n] = probe:ipostdom(n) end
      local loop_headers = {}
      for h in pairs(probe.loops) do loop_headers[h] = true end
      local nf = fold_short_circuits(self.blocks, pd, loop_headers)
      if nf == 0 then break end
    end
    local st = Structurer_new(self.blocks, entry, self.retvar, self.pv, self.cont)
    local body = st:structure()
    local narg = self:infer_params(reach, self.cont.argsvar)
    self.done[entry] = {narg, body, rest, reach}
    self.restorers[entry] = rest
    return narg, body, rest, reach
  end
  function self:run()
    return self:decompile_func(self.top)
  end
  return self
end

M.Decompiler_new = Decompiler_new

-- ============================================================
-- 完整管线
-- ============================================================

local function deobfuscate(code, verbose)
  local cont = analyze_container(code)
  local vm = extract_vm(code)
  local pv = cont.posvar or vm.posvar
  local ci = recover_constants(code)
  local inliner = make_inliner(ci)
  local blocks0, unreach0, _ = build_cfg(vm, pv, cont.returnvar, nil, inliner)
  local mul45, add45, mul8 = extract_lcg_params(blocks0)
  local decryptor = nil
  local key8 = nil
  if mul45 ~= nil then
    local enc_pairs = collect_enc_pairs(blocks0)
    local d
    key8, d = brute_key8(mul45, add45, mul8, enc_pairs)
    decryptor = function(enc, seed) return d:decrypt(enc, seed) end
  end
  local blocks, unreach, id2stats = build_cfg(vm, pv, cont.returnvar, decryptor, inliner)
  -- 语义层重写
  local rw = make_sema(cont)
  for bid, b in pairs(blocks) do
    b.body = rewrite_block(b.body, cont)
    local tm = b.term
    if tm and tm[1] == "branch" then
      local tmlist = {tm[1], rw(tm[2]), tm[3], tm[4]}
      b.term = tmlist
    end
  end
  return {
    vm=vm, cont=cont, blocks=blocks, unreachable=unreach, constinfo=ci,
    posvar=pv, returnvar=cont.returnvar, lcg={mul45, add45, mul8, key8},
    decryptor=decryptor, inliner=inliner,
  }
end

M.deobfuscate = deobfuscate

-- ============================================================
-- 公共 API
-- ============================================================

function M.deobfWeAreDevFull(code)
  local R = deobfuscate(code)
  
  local dc = Decompiler_new(R)
  local cg = CodeGen_new(dc)
  return cg:gen_top()
end

-- 用户代码提取器：从反编译输出中提取并去重用户代码
function M.extract_user_code(decompiled)
  local lines = {}
  for line in decompiled:gmatch("[^\n]+") do
    table.insert(lines, line)
  end
  
  -- 运行时代码特征
  local runtime_patterns = {
    "pcall", "xpcall", "error%(", "assert%(",
    "math%.random",
    "__metatable", "__index", "__gc", "__len", "__newindex",
    "setmetatable", "getmetatable", "newproxy",
    "Tamper Detected", "mkclosure", "alloc%(",
    "V%[v%[", "V%[F%]", "V%[U%]", "V%[D%]",
    "tostring", "tonumber", "type%(", "select%(", "unpack",
    "rawget", "rawset", "rawequal", "pairs", "ipairs", "next",
    "bit32%.%a+", "coroutine%.%a+",
    "%[v%]%(\"[^\"]*[\128-\255][^\"]*\"%s*,%s*%d",
    "%[W%]%(\"[^\"]*[\128-\255][^\"]*\"%s*,%s*%d",
    "%[X%]%(\"[^\"]*[\128-\255][^\"]*\"%s*,%s*%d",
    "%[f%]%(\"[^\"]*[\128-\255][^\"]*\"%s*,%s*%d",
    "^%s*%u%s*=%s*%u%(\"[^\"]*[\000-\031\128-\255][^\"]*\"%s*,%s*%d+%)",
    -- 上值函数调用（如 a[M[1]](、a[l](、U(K)(等）
    "%a%[M%[%d+%]%]%(",
    "%a%[%l%]%(",
    "^%s*%u%(%{?%u%(",
    -- 运行时函数定义（如 local _pt = function()、local z = function()等）
    "^%s*local %u+ = function%(",
    "^%s*local _%a+ = function%(",
    -- 嵌套的if/while语句（单字母变量条件）
    "^%s*if %u then$",
    "^%s*if %l then$",
    "^%s*if %u and %u >= %u or not %u and %u <= %u then$",
    "^%s*while %u and %u >= %u or not %u and %u <= %u do$",
    -- 字符串解密函数（return "xxx" / (num - "yyy" ^ num)）
    "return \"[^\"]*\" / %(%d+ - \"[^\"]*\" %^ %d+%)",
    -- 运行时变量赋值（单字母大写变量）
    "^%s*%u = %u%[",
    "^%s*%u = %u%(",
    -- 反检测相关
    "b = true",
    "string%.gmatch",
    "string%.gsub",
    "string%.byte",
    "string%.char",
  }
  
  -- 用户代码特征（更严格，只保留明确的用户代码调用）
  local user_patterns = {
    "print%(", "warn%(",
    "FireServer", "task%.spawn", "task%.wait",
    "WindUI", "CreateWindow", "Toggle", "Tab",
    "Button", "Dropdown", "Input", "Paragraph", "Section",
    "setLoop", "CreateWindow",
    -- 中文字符串（但需要排除字符串解密调用）
    "[^ -~]",
  }
  
  -- 严格的用户代码识别：必须包含明确的用户代码调用，或者包含中文字符串且不包含运行时代码特征
  local function has_user_strict(line)
    -- 明确的用户代码调用
    local explicit_user = {
      "print%(", "warn%(", "FireServer", "InvokeServer", "task%.spawn", "task%.wait",
      "WindUI", "CreateWindow", "Toggle", "Tab", "Button", "Dropdown",
      "Input", "Paragraph", "Section", "setLoop", "Notify",
      -- 服务获取
      "GetService", "game%.HttpGet", "loadstring",
      -- 玩家属性访问
      "LocalPlayer", "Character", "Humanoid", "ReplicatedStorage", "Workspace",
      "Players", "VirtualUser", "UserInputService", "CoreGui",
      -- 实例方法调用
      "FindFirstChild", "FindFirstChildOfClass", "IsA", "GetChildren", "GetDescendants",
      "WaitForChild", "Clone", "Destroy",
      -- Roblox API
      "Vector2", "Vector3", "CFrame", "Color3", "ColorSequence", "UDim2", "UDim",
      "Enum", "Instance%.new",
      -- 远程事件
      "RemoteEvent", "RemoteFunction", "rEvents",
      -- 宠物/物品相关
      "petsFolder", "PetShop", "cPetShop", "Backpack", "Tool",
      -- 任务/循环
      "task%.delay", "coroutine%.wrap",
      -- Roblox UI组件
      "ScreenGui", "Frame", "TextLabel", "TextButton", "ScrollingFrame",
      "UIListLayout", "UICorner", "UIGridLayout", "UIStroke", "UIPadding",
      -- 输入事件
      "InputBegan", "InputChanged", "InputEnded", "MouseButton1Click",
      "MouseButton1Down", "MouseButton1Up", "MouseEnter", "MouseLeave",
      -- 衣服/角色
      "Shirt", "Pants", "ShirtTemplate", "PantsTemplate", "rbxassetid",
      "HumanoidRootPart", "Torso",
      -- UI属性
      "BackgroundColor3", "BorderSizePixel", "ClipsDescendants",
      "TextColor3", "TextSize", "TextXAlignment", "TextYAlignment",
      "ZIndexBehavior", "CornerRadius", "CanvasSize", "ScrollBarThickness",
      "ScrollingDirection", "Padding", "HorizontalAlignment", "VerticalAlignment",
      "AutoLocalize", "BackgroundTransparency", "TextTransparency",
      -- 通用属性
      "Size", "Position", "Parent", "Name", "Visible", "Active",
      "AutoButtonColor", "ZIndex",
    }
    for _, pat in ipairs(explicit_user) do
      if line:find(pat) then return true end
    end
    -- 简单用户代码模式：全局函数赋值给局部变量（如 W = print）
    -- 注意：只识别用户函数，不识别运行时库（math/table/string等）
    local user_funcs = {
      print = true, warn = true,
    }
    local var, func = line:match("^(%w+)%s*=%s*(%w+)$")
    if var and func and user_funcs[func] then
      return true
    end
    -- 简单用户代码模式：局部变量调用带数字/字符串常量（如 local f = W(123)）
    -- 注意：只识别单字母大写变量（VM中用户函数被赋值给单字母大写变量）
    if line:match("^local%s+%w+%s*=%s*%u%(%d+%)$") then
      return true
    end
    if line:match("^local%s+%w+%s*=%s*%u%(%g+%)$") and line:find('"') then
      return true
    end
    -- 简单用户代码模式：直接调用带数字/字符串常量（如 W(123)）
    if line:match("^%u%(%d+%)$") then
      return true
    end
    if line:match("^%u%(%g+%)$") and line:find('"') then
      return true
    end
    -- 中文字符串（排除字符串解密调用和运行时函数定义）
    if line:find("[^ -~]") then
      -- 排除字符串解密调用（如 g("xxx", num)、a[l]("xxx", num)等）
      if line:find("^%s*%u+%s*=%s*%u+%(\"[^\"]*[\000-\031\128-\255][^\"]*\"%s*,%s*%d+%)") then
        return false
      end
      -- 排除运行时函数定义（如 local z = function()、local x = function()等）
      if line:find("^%s*local %u+ = function%(") then
        return false
      end
      -- 排除嵌套的if/while语句（如 if table then、while p and O >= R等）
      if line:find("^%s*if %u+ then$") or line:find("^%s*while %u+ and") then
        return false
      end
      return true
    end
    return false
  end
  
  local function is_runtime(line)
    for _, pat in ipairs(runtime_patterns) do
      if line:find(pat) then return true end
    end
    return false
  end
  
  local function has_user(line)
    for _, pat in ipairs(user_patterns) do
      if line:find(pat) then return true end
    end
    return false
  end
  
  -- 简化用户代码表达式
  local function simplify(line)
    -- P[W[2]].FireServer(W[2]) -> FireServer()
    line = line:gsub("P%[W%[%d+%]%]%.FireServer%([^%)]*%)", "FireServer()")
    -- task[P[W[3]].wait]() -> task.wait()
    line = line:gsub("task%[P%[W%[%d+%]%]%.wait%]%(?[^%)]*%)?", "task.wait()")
    line = line:gsub("task%[P%[%u%]%.wait%]%(?[^%)]*%)?", "task.wait()")
    -- task[P[k].spawn](b) -> task.spawn(b)
    line = line:gsub("task%[P%[%u%]%.spawn%]%(([^%)]*)%)", "task.spawn(%1)")
    -- e.Toggle(e, u) -> Toggle(u)
    line = line:gsub("%a+:Toggle%([^,]+,%s*", "Toggle(")
    -- e.Tab(e, u) -> Tab(u)
    line = line:gsub("%a+:Tab%([^,]+,%s*", "Tab(")
    -- WindUI:CreateWindow({...}) -> CreateWindow({...})
    line = line:gsub("%a+:CreateWindow%(", "CreateWindow(")
    -- 移除repeat...until true包装（continue语句）
    line = line:gsub("^%s*repeat%s*$", "")
    line = line:gsub("^%s*until true%s*$", "")
    line = line:gsub("^%s*break%s*$", "")
    -- 移除local B = 前缀（临时变量）
    line = line:gsub("^%s*local %u = ", "")
    -- 移除空行
    line = line:match("^%s*(.-)%s*$")
    return line
  end
  
  -- 过滤无效代码行
  local function is_valid(line)
    if #line == 0 then return false end
    -- 过滤单独的function()（没有函数体）
    if line == "function()" then return false end
    -- 过滤运行时字符串解密调用
    if line:find("^%u+ = [A-Z]+%[%u+%]%(\"") then return false end
    -- 过滤无效的FireServer())
    if line:find("^FireServer%)%)$") then return false end
    -- 过滤只有else/end的行（在块提取中会处理）
    return true
  end
  
  -- 识别函数定义和控制流
  local function is_func_def(line)
    return line:find("^%s*local function %u+%(") or line:find("^%s*function %u+%(") or line:find("^%s*local %u+ = function%(")
  end
  
  local function is_control_start(line)
    return line:find("^%s*if .* then$") or line:find("^%s*while .* do$") or 
           line:find("^%s*for .* do$") or line:find("^%s*repeat$") or
           line:find("^%s*else$") or line:find("^%s*elseif .* then$")
  end
  
  local function is_control_end(line)
    return line:find("^%s*end$") or line:find("^%s*until .*$")
  end
  
  -- 提取用户代码块（上下文感知：保留用户特征行前后的相关代码）
  local user_lines = {}
  local seen = {}
  local context_range = 0  -- 不保留上下文，只保留用户特征行本身
  
  -- 第一步：标记所有包含用户特征的行
  local user_marks = {}
  for i, line in ipairs(lines) do
    local trimmed = line:match("^%s*(.-)%s*$")
    if #trimmed > 0 then
      local simplified = simplify(trimmed)
      if #simplified > 0 and is_valid(simplified) then
        local user = has_user_strict(simplified)
        local runtime = is_runtime(simplified)
        if user and not runtime then
          user_marks[i] = true
        end
      end
    end
  end
  
  -- 第二步：扩展上下文（保留用户特征行前后的相关代码，包括函数定义和控制流结构）
  local extended_marks = {}
  for i, _ in pairs(user_marks) do
    for j = math.max(1, i - context_range), math.min(#lines, i + context_range) do
      extended_marks[j] = true
    end
  end
  
  -- 第三步：扩展函数定义和控制流结构（如果用户特征行在函数内部，保留整个函数）
  local function expand_function_scope(start_idx)
    local depth = 0
    local in_function = false
    local function_start = start_idx
    for i = start_idx, 1, -1 do
      local trimmed = lines[i]:match("^%s*(.-)%s*$")
      if trimmed:find("function%(") or trimmed:find("local .* = function") or trimmed:find("local function") then
        if depth == 0 then
          function_start = i
          in_function = true
          break
        end
        depth = depth - 1
      elseif trimmed == "end" then
        depth = depth + 1
      end
    end
    if in_function then
      depth = 0
      for i = function_start, #lines do
        local trimmed = lines[i]:match("^%s*(.-)%s*$")
        if trimmed:find("function%(") or trimmed:find("local .* = function") or trimmed:find("local function") then
          depth = depth + 1
        elseif trimmed == "end" then
          depth = depth - 1
          if depth == 0 then
            for j = function_start, i do
              extended_marks[j] = true
            end
            break
          end
        end
      end
    end
  end
  
  for i, _ in pairs(user_marks) do
    expand_function_scope(i)
  end
  
  -- 第四步：提取扩展后的行，过滤掉纯运行时代码
  for i, line in ipairs(lines) do
    if extended_marks[i] then
      local trimmed = line:match("^%s*(.-)%s*$")
      if #trimmed > 0 then
        local simplified = simplify(trimmed)
        if #simplified > 0 and is_valid(simplified) then
          -- 过滤掉纯运行时代码（但保留用户特征行和函数定义/控制流结构）
          local keep = true
          if not user_marks[i] and is_runtime(simplified) then
            -- 保留函数定义和控制流结构
            if not (simplified:find("function%(") or simplified:find("local .* = function") or 
                    simplified:find("local function") or simplified == "end" or
                    simplified:find("^if .* then$") or simplified:find("^while .* do$") or
                    simplified:find("^for .* do$") or simplified == "else" or
                    simplified:find("^elseif .* then$") or simplified:find("^until .*$")) then
              keep = false
            end
          end
          if keep and not seen[simplified] then
            seen[simplified] = true
            table.insert(user_lines, simplified)
          end
        end
      end
    end
  end
  
  return table.concat(user_lines, "\n")
end

-- 完全反混淆并提取用户代码
function M.deobfWeAreDevClean(code)
  local decompiled = M.deobfWeAreDevFull(code)
  local user_code = M.extract_user_code(decompiled)
  if #user_code > 0 then
    return user_code
  end
  return decompiled
end

-- ============================================================
-- VM解释器：识别并消除VM运行时代码
-- ============================================================

local vm_runtime_funcs = {
  alloc = true, setmetatable = true, getmetatable = true, newproxy = true,
  pcall = true, xpcall = true, error = true, assert = true,
  tostring = true, tonumber = true, type = true, select = true, unpack = true,
  rawget = true, rawset = true, rawequal = true,
  pairs = true, ipairs = true, next = true,
  string = true, math = true, table = true, os = true, bit32 = true, coroutine = true,
}

local vm_special_runtime_funcs = {
  W = true,
}

local vm_runtime_var_names = {
  V = true, v = true, W = true, z = true, K = true,
  g = true, j = true, G = true, S = true,
}

local function vm_is_runtime_expr(e, runtime_vars, depth)
  depth = depth or 0
  if depth > 20 then return false end
  if type(e) ~= "table" then return false end
  local k = e[1]
  
  if k == "alloc" or k == "mkclosure" then return true end
  
  if k == "var" then
    return runtime_vars[e[2]] == true or vm_runtime_var_names[e[2]] == true
  end
  
  if k == "num" or k == "boolean" or k == "nil" then return true end
  
  if k == "str" then
    local s = e[2]
    local runtime_strs = {
      ["__index"] = true, ["__metatable"] = true, ["__gc"] = true,
      ["__len"] = true, ["__newindex"] = true, ["__tostring"] = true,
      ["__call"] = true, ["__concat"] = true, ["__unm"] = true,
      ["__add"] = true, ["__sub"] = true, ["__mul"] = true,
      ["__div"] = true, ["__mod"] = true, ["__pow"] = true,
      ["__eq"] = true, ["__lt"] = true, ["__le"] = true,
      ["Tamper Detected!"] = true,
      ["gmatch"] = true, ["gsub"] = true, ["byte"] = true,
      ["char"] = true, ["len"] = true, ["sub"] = true,
      ["format"] = true, ["find"] = true, ["rep"] = true,
      ["random"] = true, ["randomseed"] = true, ["floor"] = true,
      ["ceil"] = true, ["abs"] = true, ["sqrt"] = true,
      ["concat"] = true, ["insert"] = true, ["remove"] = true,
      ["sort"] = true, ["clock"] = true, ["time"] = true,
    }
    return runtime_strs[s] == true
  end
  
  if k == "table" then
    if e[2] == nil or (type(e[2]) == "table" and #e[2] == 0) then
      return true
    end
    
    if type(e[2]) == "table" then
      for i = 1, #e[2] do
        local entry = e[2][i]
        if type(entry) == "table" and type(entry[1]) == "table" and entry[1][1] == "str" then
          local key = entry[1][2]
          if key == "__index" or key == "__metatable" or key == "__gc" or
             key == "__len" or key == "__newindex" or key == "__tostring" or
             key == "__call" or key == "__concat" then
            return true
          end
        end
      end
    end
    
    if type(e[2]) == "table" then
      for i = 1, #e[2] do
        if type(e[2][i]) == "table" then
          if not vm_is_runtime_expr(e[2][i], runtime_vars, depth + 1) then
            return false
          end
        end
      end
    end
    return true
  end
  
  if k == "index" then
    local base = e[2]
    if type(base) == "table" and base[1] == "var" then
      if runtime_vars[base[2]] or vm_runtime_var_names[base[2]] then
        return true
      end
    end
    if type(base) == "table" and vm_is_runtime_expr(base, runtime_vars, depth + 1) then
      return true
    end
    return false
  end
  
  if k == "call" then
    local fn = e[2]
    local args = e[3]
    
    if type(fn) == "table" and fn[1] == "var" then
      if vm_special_runtime_funcs[fn[2]] then
        return true
      end
      
      if vm_runtime_funcs[fn[2]] then
        if type(args) == "table" then
          for i = 1, #args do
            if type(args[i]) == "table" and not vm_is_runtime_expr(args[i], runtime_vars, depth + 1) then
              return false
            end
          end
        end
        return true
      end
      
      if fn[2] == "print" or fn[2] == "warn" then
        return false
      end
    end
    
    if type(fn) == "table" and fn[1] == "index" then
      local base = fn[2]
      if type(base) == "table" and base[1] == "var" and vm_runtime_funcs[base[2]] then
        return true
      end
    end
    
    return false
  end
  
  if k == "bin" or k == "un" then
    for i = 3, #e do
      if type(e[i]) == "table" and not vm_is_runtime_expr(e[i], runtime_vars, depth + 1) then
        return false
      end
    end
    return true
  end
  
  return false
end

local function vm_is_runtime_stmt(stmt, runtime_vars)
  if type(stmt) ~= "table" then return false end
  local k = stmt[1] or stmt.tag
  
  if k == "let" or k == "setvar" then
    local val = stmt[3]
    if type(val) == "table" then
      return vm_is_runtime_expr(val, runtime_vars)
    end
    return false
  end
  
  if k == "assign" then
    local lhs = stmt[2]
    local rhs = stmt[3]
    
    if type(lhs) == "table" and #lhs >= 1 then
      local l = lhs[1]
      if type(l) == "table" and l[1] == "index" then
        local base = l[2]
        if type(base) == "table" and base[1] == "var" then
          if runtime_vars[base[2]] or vm_runtime_var_names[base[2]] then
            return true
          end
        end
      end
    end
    
    if type(rhs) == "table" then
      for i = 1, #rhs do
        if type(rhs[i]) == "table" and not vm_is_runtime_expr(rhs[i], runtime_vars) then
          return false
        end
      end
      return true
    end
    return false
  end
  
  if k == "callstmt" then
    local call = stmt[2]
    if type(call) == "table" then
      return vm_is_runtime_expr(call, runtime_vars)
    end
    return false
  end
  
  if k == "local" then
    local rhs = stmt[3]
    if type(rhs) == "table" then
      for i = 1, #rhs do
        if type(rhs[i]) == "table" and not vm_is_runtime_expr(rhs[i], runtime_vars) then
          return false
        end
      end
      return true
    end
    return false
  end
  
  return false
end

function M.interpret_block(block, runtime_vars)
  runtime_vars = runtime_vars or {}
  
  local rv = {}
  for k, v in pairs(vm_runtime_var_names) do rv[k] = v end
  for k, v in pairs(runtime_vars) do rv[k] = v end
  
  local user_stmts = {}
  local runtime_stmts = {}
  
  for i, stmt in ipairs(block.body) do
    if vm_is_runtime_stmt(stmt, rv) then
      table.insert(runtime_stmts, stmt)
      local k = stmt[1] or stmt.tag
      if (k == "let" or k == "setvar") and type(stmt[2]) == "string" then
        rv[stmt[2]] = true
      end
    else
      table.insert(user_stmts, stmt)
    end
  end
  
  return user_stmts, runtime_stmts
end

-- 全局导出（兼容 dofile 后直接调用）
deobfWeAreDevFull = M.deobfWeAreDevFull
extract_user_code = M.extract_user_code
deobfWeAreDevClean = M.deobfWeAreDevClean
interpret_block = M.interpret_block


-- ============================================================
-- VM解释器v2：基于使用模式和语句模式的运行时代码消除
-- ============================================================

local runtime_funcs = {
  alloc = true, setmetatable = true, getmetatable = true, newproxy = true,
  pcall = true, xpcall = true, error = true, assert = true,
  tostring = true, tonumber = true, type = true, select = true, unpack = true,
  rawget = true, rawset = true, rawequal = true,
  pairs = true, ipairs = true, next = true,
  string = true, math = true, table = true, os = true, bit32 = true, coroutine = true,
}

local special_runtime_funcs = {
  W = true,
}

local runtime_var_names = {
  V = true, v = true, W = true, z = true, K = true,
  g = true, j = true, G = true, S = true,
}

-- 分析变量使用模式，识别运行时变量
function M.analyze_runtime_vars_v2(blocks)
  local var_index = {}  -- 被索引访问次数
  local var_mod = {}  -- 参与模运算次数
  local var_assign = {}  -- 被赋值次数
  local var_usage = {}  -- 总使用次数
  
  local function analyze_expr(e)
    if type(e) ~= "table" then return end
    local k = e[1]
    
    if k == "var" then
      var_usage[e[2]] = (var_usage[e[2]] or 0) + 1
    end
    
    if k == "index" then
      local base = e[2]
      if type(base) == "table" and base[1] == "var" then
        var_index[base[2]] = (var_index[base[2]] or 0) + 1
      end
    end
    
    if k == "bin" and e[2] == "%" then
      for i = 3, 4 do
        if type(e[i]) == "table" and e[i][1] == "var" then
          var_mod[e[i][2]] = (var_mod[e[i][2]] or 0) + 1
        end
      end
    end
    
    for i = 2, #e do
      if type(e[i]) == "table" then
        analyze_expr(e[i])
      end
    end
  end
  
  local function analyze_stmt(stmt)
    if type(stmt) ~= "table" then return end
    local k = stmt[1] or stmt.tag
    
    if k == "let" or k == "setvar" then
      if type(stmt[2]) == "string" then
        var_assign[stmt[2]] = (var_assign[stmt[2]] or 0) + 1
      end
      if type(stmt[3]) == "table" then
        analyze_expr(stmt[3])
      end
    elseif k == "assign" then
      if type(stmt[3]) == "table" then
        for i = 1, #stmt[3] do
          if type(stmt[3][i]) == "table" then
            analyze_expr(stmt[3][i])
          end
        end
      end
    elseif k == "callstmt" then
      if type(stmt[2]) == "table" then
        analyze_expr(stmt[2])
      end
    end
  end
  
  for block_id, block in pairs(blocks) do
    if block.body then
      for _, stmt in ipairs(block.body) do
        analyze_stmt(stmt)
      end
    end
  end
  
  -- 识别运行时变量
  local runtime_vars = {}
  
  -- 1. 被索引访问次数多的变量（>3次）：上值表或常量表
  for name, count in pairs(var_index) do
    if count >= 1 then
      runtime_vars[name] = true
    end
  end
  
  -- 2. 参与模运算的变量：PC寄存器
  for name, count in pairs(var_mod) do
    if count >= 1 then
      runtime_vars[name] = true
    end
  end
  
  -- 3. 硬编码的运行时变量
  for name, _ in pairs(runtime_var_names) do
    runtime_vars[name] = true
  end
  
  return runtime_vars, {index=var_index, mod=var_mod, assign=var_assign, usage=var_usage}
end

local function v2_is_runtime_expr(e, runtime_vars, depth)
  depth = depth or 0
  if depth > 20 then return false end
  if type(e) ~= "table" then return false end
  local k = e[1]
  
  if k == "alloc" or k == "mkclosure" then return true end
  
  if k == "var" then
    return runtime_vars[e[2]] == true
  end
  
  if k == "num" or k == "boolean" or k == "nil" then return true end
  
  if k == "str" then
    local s = e[2]
    local runtime_strs = {
      ["__index"] = true, ["__metatable"] = true, ["__gc"] = true,
      ["__len"] = true, ["__newindex"] = true, ["__tostring"] = true,
      ["__call"] = true, ["__concat"] = true, ["__unm"] = true,
      ["__add"] = true, ["__sub"] = true, ["__mul"] = true,
      ["__div"] = true, ["__mod"] = true, ["__pow"] = true,
      ["__eq"] = true, ["__lt"] = true, ["__le"] = true,
      ["Tamper Detected!"] = true,
      ["gmatch"] = true, ["gsub"] = true, ["byte"] = true,
      ["char"] = true, ["len"] = true, ["sub"] = true,
      ["format"] = true, ["find"] = true, ["rep"] = true,
      ["random"] = true, ["randomseed"] = true, ["floor"] = true,
      ["ceil"] = true, ["abs"] = true, ["sqrt"] = true,
      ["concat"] = true, ["insert"] = true, ["remove"] = true,
      ["sort"] = true, ["clock"] = true, ["time"] = true,
    }
    return runtime_strs[s] == true
  end
  
  if k == "table" then
    if e[2] == nil or (type(e[2]) == "table" and #e[2] == 0) then
      return true
    end
    
    if type(e[2]) == "table" then
      for i = 1, #e[2] do
        local entry = e[2][i]
        if type(entry) == "table" and type(entry[1]) == "table" and entry[1][1] == "str" then
          local key = entry[1][2]
          if key == "__index" or key == "__metatable" or key == "__gc" or
             key == "__len" or key == "__newindex" or key == "__tostring" or
             key == "__call" or key == "__concat" then
            return true
          end
        end
      end
    end
    
    if type(e[2]) == "table" then
      for i = 1, #e[2] do
        if type(e[2][i]) == "table" then
          if not v2_is_runtime_expr(e[2][i], runtime_vars, depth + 1) then
            return false
          end
        end
      end
    end
    return true
  end
  
  if k == "index" then
    local base = e[2]
    if type(base) == "table" and base[1] == "var" then
      if runtime_vars[base[2]] then
        return true
      end
    end
    if type(base) == "table" and v2_is_runtime_expr(base, runtime_vars, depth + 1) then
      return true
    end
    return false
  end
  
  if k == "call" then
    local fn = e[2]
    local args = e[3]
    
    if type(fn) == "table" and fn[1] == "var" then
      if special_runtime_funcs[fn[2]] then
        return true
      end
      
      if runtime_funcs[fn[2]] then
        if type(args) == "table" then
          for i = 1, #args do
            if type(args[i]) == "table" and not v2_is_runtime_expr(args[i], runtime_vars, depth + 1) then
              return false
            end
          end
        end
        return true
      end
      
      if fn[2] == "print" or fn[2] == "warn" then
        return false
      end
    end
    
    if type(fn) == "table" and fn[1] == "index" then
      local base = fn[2]
      if type(base) == "table" and base[1] == "var" and runtime_funcs[base[2]] then
        return true
      end
    end
    
    return false
  end
  
  if k == "bin" or k == "un" then
    for i = 3, #e do
      if type(e[i]) == "table" and not v2_is_runtime_expr(e[i], runtime_vars, depth + 1) then
        return false
      end
    end
    return true
  end
  
  return false
end

local function v2_is_runtime_stmt(stmt, runtime_vars)
  if type(stmt) ~= "table" then return false end
  local k = stmt[1] or stmt.tag
  
  if k == "let" or k == "setvar" then
    local val = stmt[3]
    if type(val) == "table" then
      return v2_is_runtime_expr(val, runtime_vars)
    end
    return false
  end
  
  if k == "assign" then
    local lhs = stmt[2]
    local rhs = stmt[3]
    
    if type(lhs) == "table" and #lhs >= 1 then
      local l = lhs[1]
      if type(l) == "table" and l[1] == "index" then
        local base = l[2]
        if type(base) == "table" and base[1] == "var" then
          if runtime_vars[base[2]] then
            return true
          end
        end
      end
    end
    
    if type(rhs) == "table" then
      for i = 1, #rhs do
        if type(rhs[i]) == "table" and not v2_is_runtime_expr(rhs[i], runtime_vars) then
          return false
        end
      end
      return true
    end
    return false
  end
  
  if k == "callstmt" then
    local call = stmt[2]
    if type(call) == "table" then
      return v2_is_runtime_expr(call, runtime_vars)
    end
    return false
  end
  
  if k == "local" then
    local rhs = stmt[3]
    if type(rhs) == "table" then
      for i = 1, #rhs do
        if type(rhs[i]) == "table" and not v2_is_runtime_expr(rhs[i], runtime_vars) then
          return false
        end
      end
      return true
    end
    return false
  end
  
  return false
end

function M.interpret_block(block, runtime_vars)
  runtime_vars = runtime_vars or {}
  
  local rv = {}
  for k, v in pairs(runtime_vars) do rv[k] = v end
  
  local user_stmts = {}
  local runtime_stmts = {}
  
  for i, stmt in ipairs(block.body) do
    if v2_is_runtime_stmt(stmt, rv) then
      table.insert(runtime_stmts, stmt)
      local k = stmt[1] or stmt.tag
      if (k == "let" or k == "setvar") and type(stmt[2]) == "string" then
        rv[stmt[2]] = true
      end
    else
      table.insert(user_stmts, stmt)
    end
  end
  
  return user_stmts, runtime_stmts
end

-- 基于语句模式的运行时代码识别
function M.is_runtime_stmt_pattern(stmt)
  if type(stmt) ~= "table" then return false end
  local k = stmt[1] or stmt.tag
  
  -- 1. PC寄存器操作：setvar X, {bin, %, ...}
  if k == "setvar" and type(stmt[3]) == "table" and stmt[3][1] == "bin" and stmt[3][2] == "%" then
    return true
  end
  
  -- 2. 寄存器算术操作：setvar X, {bin, +/-, ...}
  if k == "setvar" and type(stmt[3]) == "table" and stmt[3][1] == "bin" then
    local op = stmt[3][2]
    if op == "+" or op == "-" or op == "*" or op == "/" or op == "%" or op == "^" then
      -- 检查操作数是否都是变量或数字
      local all_simple = true
      for i = 3, 4 do
        if type(stmt[3][i]) == "table" then
          if stmt[3][i][1] ~= "var" and stmt[3][i][1] ~= "num" then
            all_simple = false
          end
        end
      end
      if all_simple then return true end
    end
  end
  
  -- 3. 表创建：let X, {table, ...}
  if k == "let" and type(stmt[3]) == "table" and stmt[3][1] == "table" then
    return true
  end
  
  -- 4. 变量交换：assign {{var, l1}}, {{var, l2}}
  if k == "assign" and type(stmt[2]) == "table" and #stmt[2] == 1 then
    local lhs = stmt[2][1]
    if type(lhs) == "table" and lhs[1] == "var" then
      -- 检查右侧是否是变量
      if type(stmt[3]) == "table" and #stmt[3] == 1 then
        local rhs = stmt[3][1]
        if type(rhs) == "table" and rhs[1] == "var" then
          return true
        end
      end
    end
  end
  
  -- 5. 上值表函数调用：let X, {call, {index, {var, A}, ...}, ...}
  if k == "let" and type(stmt[3]) == "table" and stmt[3][1] == "call" then
    local fn = stmt[3][2]
    if type(fn) == "table" and fn[1] == "index" then
      local base = fn[2]
      if type(base) == "table" and base[1] == "var" then
        return true
      end
    end
  end
  
  -- 6. 运行时函数调用：let X, {call, {var, pcall/tostring/tonumber/...}, ...}
  if k == "let" and type(stmt[3]) == "table" and stmt[3][1] == "call" then
    local fn = stmt[3][2]
    if type(fn) == "table" and fn[1] == "var" then
      local runtime_call_funcs = {
        pcall = true, xpcall = true, tostring = true, tonumber = true,
        type = true, select = true, unpack = true, error = true,
        assert = true, setmetatable = true, getmetatable = true,
        rawget = true, rawset = true, rawequal = true,
        pairs = true, ipairs = true, next = true,
        l = true,  -- 上值解析函数
      }
      if runtime_call_funcs[fn[2]] then
        return true
      end
    end
  end
  
  -- 7. 上值解析函数调用：setvar X, {call, {var, l}, {{var, X}}}
  if k == "setvar" and type(stmt[3]) == "table" and stmt[3][1] == "call" then
    local fn = stmt[3][2]
    if type(fn) == "table" and fn[1] == "var" and fn[2] == "l" then
      return true
    end
  end
  
  -- 8. 上值表函数调用：setvar X, {call, {index, ...}, ...}
  if k == "setvar" and type(stmt[3]) == "table" and stmt[3][1] == "call" then
    local fn = stmt[3][2]
    if type(fn) == "table" and fn[1] == "index" then
      return true
    end
  end
  
  -- 9. 表创建：setvar X, {table, ...}
  if k == "setvar" and type(stmt[3]) == "table" and stmt[3][1] == "table" then
    return true
  end
  
  -- 10. 变量赋值：setvar X, {var, Y}
  if k == "setvar" and type(stmt[3]) == "table" and stmt[3][1] == "var" then
    return true
  end
  
  -- 11. 简单值赋值：setvar X, {false/true/nil/num/boolean}
  if k == "setvar" and type(stmt[3]) == "table" then
    local vk = stmt[3][1]
    if vk == "false" or vk == "true" or vk == "nil" or vk == "num" or vk == "boolean" then
      return true
    end
  end
  
  -- 12. 运行时函数调用：setvar X, {call, {var, tonumber/tostring/...}, ...}
  if k == "setvar" and type(stmt[3]) == "table" and stmt[3][1] == "call" then
    local fn = stmt[3][2]
    if type(fn) == "table" and fn[1] == "var" then
      local runtime_call_funcs = {
        pcall = true, xpcall = true, tostring = true, tonumber = true,
        type = true, select = true, unpack = true, error = true,
        assert = true, setmetatable = true, getmetatable = true,
        rawget = true, rawset = true, rawequal = true,
        pairs = true, ipairs = true, next = true,
        l = true,
      }
      if runtime_call_funcs[fn[2]] then
        return true
      end
    end
  end
  
  -- 13. 多变量赋值+函数调用：assign {{var, X}, {var, Y}}, {{call, ...}}
  if k == "assign" and type(stmt[2]) == "table" and #stmt[2] >= 2 then
    local all_vars = true
    for i = 1, #stmt[2] do
      if type(stmt[2][i]) ~= "table" or stmt[2][i][1] ~= "var" then
        all_vars = false
      end
    end
    if all_vars and type(stmt[3]) == "table" and #stmt[3] >= 1 then
      local first_rhs = stmt[3][1]
      if type(first_rhs) == "table" and first_rhs[1] == "call" then
        return true
      end
    end
  end
  
  -- 14. 索引赋值：assign {{index, {var, X}, {var, Y}}}, {{var, Z}}
  if k == "assign" and type(stmt[2]) == "table" and #stmt[2] == 1 then
    local lhs = stmt[2][1]
    if type(lhs) == "table" and lhs[1] == "index" then
      if type(stmt[3]) == "table" and #stmt[3] == 1 then
        local rhs = stmt[3][1]
        if type(rhs) == "table" and rhs[1] == "var" then
          return true
        end
      end
    end
  end
  
  return false
end

-- 改进的interpret_block：结合使用模式和语句模式
function M.interpret_block_v2(block, runtime_vars)
  runtime_vars = runtime_vars or {}
  
  local rv = {}
  for k, v in pairs(runtime_vars) do rv[k] = v end
  
  local user_stmts = {}
  local runtime_stmts = {}
  
  for i, stmt in ipairs(block.body) do
    -- 先检查语句模式
    if M.is_runtime_stmt_pattern(stmt) then
      table.insert(runtime_stmts, stmt)
      local k = stmt[1] or stmt.tag
      if (k == "let" or k == "setvar") and type(stmt[2]) == "string" then
        rv[stmt[2]] = true
      end
    -- 再检查使用模式
    elseif v2_is_runtime_stmt(stmt, rv) then
      table.insert(runtime_stmts, stmt)
      local k = stmt[1] or stmt.tag
      if (k == "let" or k == "setvar") and type(stmt[2]) == "string" then
        rv[stmt[2]] = true
      end
    else
      table.insert(user_stmts, stmt)
    end
  end
  
  return user_stmts, runtime_stmts
end


return M
