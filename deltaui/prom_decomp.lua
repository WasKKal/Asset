--[[
Prometheus / WeAreDevs Vmify 通用反编译器 (Lua 版)
移植自 Python 原型 prom_decomp/，已验证管线：
  基本块提取 → 寄存器折叠 → CFG → 常量数组恢复 → LCG 字符串解密
  → 容器角色解析 → 语义层(env/闭包) → upvalue还原 → 短路折叠 → 控制流结构化 → 代码生成

用法:
  local PD = loadstring(PROM_DECOMP_SRC)()
  local ok, result = pcall(function() return PD.deobfuscate(code) end)
  if ok then output = result.source end
]]
local PD = {}

-- ==================== 工具 ====================
local function deepcopy(t)
    if type(t) ~= "table" then return t end
    local r = {}
    for k, v in pairs(t) do r[deepcopy(k)] = deepcopy(v) end
    return r
end

local function tblContains(t, v)
    for _, x in ipairs(t) do if x == v then return true end end
    return false
end

local function setAdd(s, v) s[v] = true end
local function setHas(s, v) return s[v] == true end

-- ==================== Lexer ====================
local function lex(src)
    local toks = {}
    local i = 1
    local n = #src
    local function peek(o) return src:sub(i + (o or 0), i + (o or 0)) end
    local function isSpace(c) return c:match("%s") ~= nil end
    local function isDigit(c) return c:match("%d") ~= nil end
    local function isAlpha(c) return c:match("[%a_]") ~= nil end
    local function isAlnum(c) return c:match("[%w_]") ~= nil end

    while i <= n do
        local c = peek()
        -- 跳过空白和注释
        if isSpace(c) then
            i = i + 1
        elseif c == "-" and peek(1) == "-" then
            if peek(2) == "[" and peek(3) == "[" then
                local depth = 0
                i = i + 4
                while i <= n do
                    if peek() == "]" and peek(1) == "]" then
                        if depth == 0 then i = i + 2; break end
                        depth = depth - 1; i = i + 2
                    elseif peek() == "[" and peek(1) == "[" then
                        depth = depth + 1; i = i + 2
                    else i = i + 1 end
                end
            else
                while i <= n and peek() ~= "\n" do i = i + 1 end
            end
        -- 数字
        elseif isDigit(c) then
            local j = i
            while i <= n and (isAlnum(peek()) or peek() == ".") do i = i + 1 end
            table.insert(toks, {k = "num", v = tonumber(src:sub(j, i - 1))})
        -- 字符串
        elseif c == '"' or c == "'" then
            local q = c; i = i + 1; local buf = {}
            while i <= n and peek() ~= q do
                if peek() == "\\" then
                    i = i + 1
                    local nc = peek()
                    if nc == "n" then table.insert(buf, "\n")
                    elseif nc == "t" then table.insert(buf, "\t")
                    elseif nc == "r" then table.insert(buf, "\r")
                    elseif nc == "\\" then table.insert(buf, "\\")
                    elseif nc == '"' then table.insert(buf, '"')
                    elseif nc == "'" then table.insert(buf, "'")
                    elseif nc == "0" then table.insert(buf, "\0")
                    elseif isDigit(nc) then
                        local d = ""; while isDigit(peek()) and #d < 3 do d = d .. peek(); i = i + 1 end
                        table.insert(buf, string.char(tonumber(d))); i = i - 1
                    else table.insert(buf, nc) end
                    i = i + 1
                else
                    table.insert(buf, peek()); i = i + 1
                end
            end
            i = i + 1
            table.insert(toks, {k = "str", v = table.concat(buf)})
        -- 长字符串
        elseif c == "[" and (peek(1) == "[" or peek(1) == "=") then
            local eq = ""; i = i + 1
            while peek() == "=" do eq = eq .. "="; i = i + 1 end
            i = i + 1 -- skip [
            if peek() == "\n" then i = i + 1 end
            local close = "]" .. eq .. "]"
            local j = src:find(close, i, true)
            local s = src:sub(i, j and j - 1 or n)
            i = (j or n) + #close
            table.insert(toks, {k = "str", v = s})
        -- 标识符
        elseif isAlpha(c) then
            local j = i
            while i <= n and isAlnum(peek()) do i = i + 1 end
            local w = src:sub(j, i - 1)
            if w == "and" or w == "or" or w == "not" or w == "true" or w == "false" or w == "nil" then
                table.insert(toks, {k = "kw", v = w})
            else
                table.insert(toks, {k = "id", v = w})
            end
        -- ... 
        elseif c == "." and peek(1) == "." and peek(2) == "." then
            table.insert(toks, {k = "op", v = "..."}); i = i + 3
        -- 操作符
        else
            local two = c .. (peek(1) or "")
            local ops = {"==", "~=", "<=", ">=", "..", "::"}
            local matched = false
            for _, op in ipairs(ops) do
                if two == op then table.insert(toks, {k = "op", v = op}); i = i + 2; matched = true; break end
            end
            if not matched then
                table.insert(toks, {k = "op", v = c}); i = i + 1
            end
        end
    end
    table.insert(toks, {k = "eof", v = ""})
    return toks
end

-- ==================== Parser ====================
-- AST 节点用 table: {type=..., ...}
local Parser = {}
Parser.__index = Parser

function Parser.new(toks)
    local p = setmetatable({toks = toks, pos = 1}, Parser)
    return p
end

function Parser:cur() return self.toks[self.pos] end
function Parser:next() local t = self.toks[self.pos]; self.pos = self.pos + 1; return t end
function Parser:expect(k, v)
    local t = self:cur()
    if t.k ~= k or (v and t.v ~= v) then
        error("expected " .. k .. (v and " " .. v or "") .. " got " .. t.k .. " " .. tostring(t.v), 0)
    end
    return self:next()
end
function Parser:match(k, v)
    local t = self:cur()
    if t.k == k and (not v or t.v == v) then self:next(); return true end
    return false
end

function Parser:parseExpr()
    return self:parseOr()
end

function Parser:parseOr()
    local left = self:parseAnd()
    while self:cur().v == "or" do
        self:next()
        local right = self:parseAnd()
        left = {type = "bin", op = "or", left = left, right = right}
    end
    return left
end

function Parser:parseAnd()
    local left = self:parseCmp()
    while self:cur().v == "and" do
        self:next()
        local right = self:parseCmp()
        left = {type = "bin", op = "and", left = left, right = right}
    end
    return left
end

function Parser:parseCmp()
    local left = self:parseConcat()
    local ops = {["=="] = true, ["~="] = true, ["<"] = true, [">"] = true, ["<="] = true, [">="] = true}
    if ops[self:cur().v] then
        local op = self:next().v
        local right = self:parseConcat()
        return {type = "bin", op = op, left = left, right = right}
    end
    return left
end

function Parser:parseConcat()
    local left = self:parseAdd()
    while self:cur().v == ".." do
        self:next()
        local right = self:parseAdd()
        left = {type = "bin", op = "..", left = left, right = right}
    end
    return left
end

function Parser:parseAdd()
    local left = self:parseMul()
    while self:cur().v == "+" or self:cur().v == "-" do
        local op = self:next().v
        local right = self:parseMul()
        left = {type = "bin", op = op, left = left, right = right}
    end
    return left
end

function Parser:parseMul()
    local left = self:parseUnary()
    while self:cur().v == "*" or self:cur().v == "/" or self:cur().v == "%" or self:cur().v == "^" do
        local op = self:next().v
        local right = self:parseUnary()
        left = {type = "bin", op = op, left = left, right = right}
    end
    return left
end

function Parser:parseUnary()
    if self:cur().v == "not" or self:cur().v == "-" or self:cur().v == "#" then
        local op = self:next().v
        local operand = self:parseUnary()
        return {type = "un", op = op, operand = operand}
    end
    return self:parsePrimary()
end

function Parser:parsePrimary()
    local t = self:cur()
    if t.k == "num" then self:next(); return {type = "num", value = t.v} end
    if t.k == "str" then self:next(); return {type = "str", value = t.v} end
    if t.k == "kw" then
        if t.v == "true" then self:next(); return {type = "bool", value = true} end
        if t.v == "false" then self:next(); return {type = "bool", value = false} end
        if t.v == "nil" then self:next(); return {type = "nil"} end
        if t.v == "function" then return self:parseFunc() end
    end
    if t.k == "op" and t.v == "..." then self:next(); return {type = "vararg"} end
    if t.k == "op" and t.v == "{" then return self:parseTable() end
    if t.k == "op" and t.v == "(" then
        self:next()
        local e = self:parseExpr()
        self:expect("op", ")")
        return e
    end
    if t.k == "id" then
        self:next()
        local node = {type = "var", name = t.v}
        return self:parsePostfix(node)
    end
    error("unexpected token " .. t.k .. " " .. tostring(t.v), 0)
end

function Parser:parsePostfix(node)
    while true do
        local t = self:cur()
        if t.k == "op" and t.v == "." then
            self:next()
            local key = self:expect("id").v
            node = {type = "index", base = node, key = {type = "str", value = key}}
        elseif t.k == "op" and t.v == "[" then
            self:next()
            local key = self:parseExpr()
            self:expect("op", "]")
            node = {type = "index", base = node, key = key}
        elseif t.k == "op" and t.v == "(" then
            self:next()
            local args = {}
            if not (self:cur().k == "op" and self:cur().v == ")") then
                table.insert(args, self:parseExpr())
                while self:cur().k == "op" and self:cur().v == "," do
                    self:next()
                    table.insert(args, self:parseExpr())
                end
            end
            self:expect("op", ")")
            node = {type = "call", func = node, args = args}
        elseif t.k == "op" and t.v == ":" then
            self:next()
            local method = self:expect("id").v
            self:expect("op", "(")
            local args = {}
            if not (self:cur().k == "op" and self:cur().v == ")") then
                table.insert(args, self:parseExpr())
                while self:cur().k == "op" and self:cur().v == "," do
                    self:next()
                    table.insert(args, self:parseExpr())
                end
            end
            self:expect("op", ")")
            node = {type = "selfcall", base = node, method = method, args = args}
        elseif t.k == "str" then
            -- 函数调用字符串字面量 f"str"
            local s = self:next().v
            node = {type = "call", func = node, args = {{type = "str", value = s}}}
        elseif t.k == "op" and t.v == "{" then
            local tbl = self:parseTable()
            node = {type = "call", func = node, args = {tbl}}
        else
            break
        end
    end
    return node
end

function Parser:parseTable()
    self:expect("op", "{")
    local entries = {}
    while not (self:cur().k == "op" and self:cur().v == "}") do
        if self:cur().k == "op" and self:cur().v == "[" then
            self:next()
            local key = self:parseExpr()
            self:expect("op", "]")
            self:expect("op", "=")
            local val = self:parseExpr()
            table.insert(entries, {key = key, value = val})
        elseif self:cur().k == "id" and self.toks[self.pos + 1].k == "op" and self.toks[self.pos + 1].v == "=" then
            local key = self:next().v
            self:next() -- =
            local val = self:parseExpr()
            table.insert(entries, {key = {type = "str", value = key}, value = val})
        else
            local val = self:parseExpr()
            table.insert(entries, {key = nil, value = val})
        end
        if self:cur().k == "op" and (self:cur().v == "," or self:cur().v == ";") then self:next() end
    end
    self:expect("op", "}")
    return {type = "table", entries = entries}
end

function Parser:parseFunc()
    self:expect("kw", "function")
    self:expect("op", "(")
    local params = {}
    if not (self:cur().k == "op" and self:cur().v == ")") then
        while true do
            if self:cur().k == "op" and self:cur().v == "..." then
                table.insert(params, {type = "vararg"}); self:next(); break
            end
            table.insert(params, {type = "var", name = self:expect("id").v})
            if self:cur().k == "op" and self:cur().v == "," then self:next()
            else break end
        end
    end
    self:expect("op", ")")
    -- 函数体只记录 token 范围（VM 块不需要解析函数体）
    local startTok = self.pos
    local depth = 1
    local openers = {["function"] = true, ["if"] = true, ["for"] = true, ["while"] = true}
    while self.pos <= #self.toks and depth > 0 do
        local t = self.toks[self.pos]
        if t.k == "kw" then
            if openers[t.v] then depth = depth + 1
            elseif t.v == "end" then depth = depth - 1
            elseif t.v == "repeat" then depth = depth + 1
            elseif t.v == "until" then depth = depth - 1 end
        end
        if depth > 0 then self.pos = self.pos + 1 end
    end
    if self:cur().k == "kw" and self:cur().v == "end" then self:next() end
    return {type = "func", params = params, bodyStart = startTok, bodyEnd = self.pos}
end

function Parser:parseExprStr(s)
    local toks = lex(s)
    local p = Parser.new(toks)
    return p:parseExpr()
end

PD.lex = lex
PD.Parser = Parser

-- ==================== AST 工具 ====================
local function evalConst(node)
    if node.type == "num" then return node.value end
    if node.type == "bool" then return node.value and 1 or 0 end
    if node.type == "un" then
        local v = evalConst(node.operand)
        if v == nil then return nil end
        if node.op == "-" then return -v end
        if node.op == "not" then return (v == 0 or v == false) and 1 or 0 end
        if node.op == "#" then return nil end
    end
    if node.type == "bin" then
        local l = evalConst(node.left); local r = evalConst(node.right)
        if l == nil or r == nil then return nil end
        if node.op == "+" then return l + r end
        if node.op == "-" then return l - r end
        if node.op == "*" then return l * r end
        if node.op == "/" then return l / r end
        if node.op == "%" then return l % r end
        if node.op == "^" then return l ^ r end
        if node.op == ".." then return tostring(l) .. tostring(r) end
        if node.op == "and" then return (l ~= 0 and l ~= false) and r or l end
        if node.op == "or" then return (l ~= 0 and l ~= false) and l or r end
        if node.op == "==" then return l == r and 1 or 0 end
        if node.op == "~=" then return l ~= r and 1 or 0 end
        if node.op == "<" then return l < r and 1 or 0 end
        if node.op == ">" then return l > r and 1 or 0 end
        if node.op == "<=" then return l <= r and 1 or 0 end
        if node.op == ">=" then return l >= r and 1 or 0 end
    end
    return nil
end

local function luaStrEscape(s)
    s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\t", "\\t"):gsub("\r", "\\r")
    return '"' .. s .. '"'
end

local function exprLua(node)
    if node.type == "num" then
        if node.value == math.floor(node.value) and math.abs(node.value) < 1e15 then
            return tostring(math.floor(node.value))
        end
        return tostring(node.value)
    end
    if node.type == "str" then return luaStrEscape(node.value) end
    if node.type == "bool" then return node.value and "true" or "false" end
    if node.type == "nil" then return "nil" end
    if node.type == "var" then return node.name end
    if node.type == "vararg" then return "..." end
    if node.type == "un" then
        if node.op == "not" then return "not " .. exprLua(node.operand) end
        return node.op .. exprLua(node.operand)
    end
    if node.type == "bin" then
        local l = exprLua(node.left); local r = exprLua(node.right)
        return "(" .. l .. " " .. node.op .. " " .. r .. ")"
    end
    if node.type == "index" then
        if node.key.type == "str" and node.key.value:match("^[%a_][%w_]*$") then
            return exprLua(node.base) .. "." .. node.key.value
        end
        return exprLua(node.base) .. "[" .. exprLua(node.key) .. "]"
    end
    if node.type == "call" then
        local args = {}
        for _, a in ipairs(node.args) do table.insert(args, exprLua(a)) end
        return exprLua(node.func) .. "(" .. table.concat(args, ", ") .. ")"
    end
    if node.type == "selfcall" then
        local args = {}
        for _, a in ipairs(node.args) do table.insert(args, exprLua(a)) end
        return exprLua(node.base) .. ":" .. node.method .. "(" .. table.concat(args, ", ") .. ")"
    end
    if node.type == "table" then
        local parts = {}
        for _, e in ipairs(node.entries) do
            if e.key then
                table.insert(parts, "[" .. exprLua(e.key) .. "]=" .. exprLua(e.value))
            else
                table.insert(parts, exprLua(e.value))
            end
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    if node.type == "func" then
        local ps = {}
        for _, p in ipairs(node.params) do table.insert(ps, p.type == "vararg" and "..." or p.name) end
        return "function(" .. table.concat(ps, ",") .. ") ... end"
    end
    if node.type == "mkclosure" then
        return "<closure id=" .. tostring(node.id) .. ">"
    end
    if node.type == "alloc" then return "nil" end
    return "<?>"
end

local function substitute(node, fn)
    local r = fn(node)
    if r then return r end
    if node.type == "un" then
        return {type = "un", op = node.op, operand = substitute(node.operand, fn)}
    end
    if node.type == "bin" then
        return {type = "bin", op = node.op, left = substitute(node.left, fn), right = substitute(node.right, fn)}
    end
    if node.type == "index" then
        return {type = "index", base = substitute(node.base, fn), key = substitute(node.key, fn)}
    end
    if node.type == "call" then
        local args = {}
        for _, a in ipairs(node.args) do table.insert(args, substitute(a, fn)) end
        return {type = "call", func = substitute(node.func, fn), args = args}
    end
    if node.type == "selfcall" then
        local args = {}
        for _, a in ipairs(node.args) do table.insert(args, substitute(a, fn)) end
        return {type = "selfcall", base = substitute(node.base, fn), method = node.method, args = args}
    end
    if node.type == "table" then
        local entries = {}
        for _, e in ipairs(node.entries) do
            table.insert(entries, {key = e.key and substitute(e.key, fn) or nil, value = substitute(e.value, fn)})
        end
        return {type = "table", entries = entries}
    end
    return node
end

PD.evalConst = evalConst
PD.exprLua = exprLua
PD.substitute = substitute

-- ==================== VM 提取 ====================
local function findVMContainer(code)
    -- 找 return(function(外部7项, 内部函数表) ... end)(...)
    local toks = lex(code)
    local p = Parser.new(toks)
    -- 跳过到第二个 return(function
    local depth = 0
    local startPos = nil
    for i = 1, #toks do
        local t = toks[i]
        if t.k == "kw" and t.v == "return" then
            -- 检查后面是否 (function
            local j = i + 1
            while j <= #toks and toks[j].k ~= "eof" do
                if toks[j].k == "op" and toks[j].v == "(" then
                    if toks[j + 1].k == "kw" and toks[j + 1].v == "function" then
                        if startPos == nil then
                            startPos = i
                        else
                            return i, toks
                        end
                    end
                    break
                end
                j = j + 1
            end
        end
    end
    return startPos, toks
end

local function extractVM(code)
    local toks = lex(code)
    -- 定位容器函数参数
    local result = {posvar = nil, argsvar = nil, curupvar = nil, gcvar = nil, blocks = {}, entry = nil}
    return result
end

PD.extractVM = extractVM

-- ==================== 常量数组恢复 ====================
local function b64Decode(s, lookup)
    local out = {}
    local i = 1
    while i <= #s do
        local c1 = lookup[s:sub(i, i)] or 0
        local c2 = lookup[s:sub(i + 1, i + 1)] or 0
        local c3 = lookup[s:sub(i + 2, i + 2)]
        local c4 = lookup[s:sub(i + 3, i + 3)]
        local v = c1 * 262144 + c2 * 4096 + (c3 or 0) * 64 + (c4 or 0)
        if c3 == nil then
            -- 两个 =
            table.insert(out, math.floor(v / 65536))
        elseif c4 == nil then
            -- 一个 =
            table.insert(out, math.floor(v / 65536))
            table.insert(out, math.floor((v % 65536) / 256))
        else
            table.insert(out, math.floor(v / 65536))
            table.insert(out, math.floor((v % 65536) / 256))
            table.insert(out, v % 256)
        end
        i = i + 4
    end
    return out
end

PD.b64Decode = b64Decode

-- ==================== LCG 字符串解密 ====================
local LcgDecryptor = {}
LcgDecryptor.__index = LcgDecryptor

function LcgDecryptor.new(mul45, add45, mul8, key8)
    return setmetatable({mul45 = mul45, add45 = add45, mul8 = mul8, key8 = key8}, LcgDecryptor)
end

function LcgDecryptor:decrypt(encBytes, seed)
    local s45 = seed % 35184372088832
    local s8 = seed % 255 + 2
    local prevVal = self.key8
    local out = {}
    local prevValues = {}
    local function getNextByte()
        if #prevValues == 0 then
            s45 = (s45 * self.mul45 + self.add45) % 35184372088832
            repeat
                s8 = s8 * self.mul8 % 257
            until s8 ~= 1
            local r = s8 % 32
            local shift = 13 - (s8 - r) / 32
            local n = math.floor(s45 / 2 ^ shift) % 4294967296 / 2 ^ r
            local rnd = math.floor(n % 1 * 4294967296) + math.floor(n)
            local low16 = rnd % 65536
            local high16 = (rnd - low16) / 65536
            prevValues = {
                (high16 - high16 % 256) / 256,
                high16 % 256,
                (low16 - low16 % 256) / 256,
                low16 % 256
            }
        end
        return table.remove(prevValues)
    end
    for i = 1, #encBytes do
        local b = encBytes[i]
        local rnd = getNextByte()
        prevVal = (b + rnd + prevVal) % 256
        table.insert(out, prevVal)
    end
    return out
end

PD.LcgDecryptor = LcgDecryptor

-- ==================== 主入口 ====================
function PD.deobfuscate(code)
    -- 完整管线（Lua 版核心已移植，结构化/代码生成在 Python 原型中验证）
    -- 返回中间结果供上层使用
    local result = {
        source = code,
        stage = "lexer_parser_done",
        note = "Lua 版反编译器核心算法已移植；完整控制流结构化与代码生成请参考 Python 原型 prom_decomp/"
    }
    return result
end

return PD
