 

DeltaPageInfo = {
    name = "agentless",
    title = "AgentLess",
    icon = "atom",
    dataFolder = "AgentLess",
    version = "1.0.0",
    official = true,        
    unrestricted = true,    
}

local pageDef = {
    name = DeltaPageInfo.name,
    title = DeltaPageInfo.title,
    icon = DeltaPageInfo.icon,
    dataFolder = DeltaPageInfo.dataFolder,
    version = DeltaPageInfo.version,
    official = true,
    unrestricted = true,
}

local function getGlobalEnv()
    local g
    if type(getgenv) == "function" then
        local ok, env = pcall(getgenv)
        if ok and type(env) == "table" then g = env end
    end
    if type(g) ~= "table" then
        local ok, env = pcall(function() return _G end)
        if ok and type(env) == "table" then g = env end
    end
    return g or {}
end

















local function hostChunkEnv()
    if type(getfenv) ~= "function" then return nil end
    local probe = function() end
    local ok, e = pcall(getfenv, probe)
    if ok and type(e) == "table" then return e end
    return nil
end

local HOST_ROOTS = (function()
    local roots, seen = {}, {}
    local function push(t)
        if type(t) == "table" and not seen[t] then
            seen[t] = true
            roots[#roots + 1] = t
        end
    end
    push(hostChunkEnv())
    push(getGlobalEnv())
    local okG, g = pcall(function() return _G end)
    if okG then push(g) end
    return roots
end)()


local function hostSymbol(name, helpers)
    if type(name) ~= "string" then return nil end
    for _, root in ipairs(HOST_ROOTS) do
        local v = root[name]
        if v == nil then v = root["__DeltaUI_" .. name] end
        if v ~= nil then return v end
    end
    if type(helpers) == "table" then
        local v = helpers[name]
        if v ~= nil then return v end
    end
    return nil
end



local HOST_BINDINGS = {
    "create", "corner", "stroke", "applyGradient", "GetIcon",
    "ShowNotification", "AddLog", "t", "loadConfig", "saveConfig",
    "registerTranslation", "pages", "navButtons", "switchPage",
}




local HOST_CONFIG_FILE = "DeltaUI/Config.json"

local function getHttpService()
    local ok, svc = pcall(function() return game:GetService("HttpService") end)
    if ok and svc then return svc end
    return nil
end

local function makeFallbackLoadConfig(G)
    return function()
        if type(G) == "table" and type(G.__DeltaUI_cachedConfig) == "table" then
            return G.__DeltaUI_cachedConfig
        end
        local okRaw, raw = pcall(function()
            if type(isfile) == "function" and isfile(HOST_CONFIG_FILE) then
                return readfile(HOST_CONFIG_FILE)
            end
            return nil
        end)
        if not okRaw or type(raw) ~= "string" or raw == "" then return {} end
        local http = getHttpService()
        if not http then return {} end
        local ok, data = pcall(function() return http:JSONDecode(raw) end)
        if ok and type(data) == "table" then
            if type(G) == "table" then pcall(function() G.__DeltaUI_cachedConfig = data end) end
            return data
        end
        return {}
    end
end

local function makeFallbackSaveConfig(G)
    return function(data)
        if type(data) ~= "table" then return end
        if type(G) == "table" then pcall(function() G.__DeltaUI_cachedConfig = data end) end
        local http = getHttpService()
        if not http then return end
        local ok, raw = pcall(function() return http:JSONEncode(data) end)
        if not ok or type(raw) ~= "string" then return end
        pcall(function()
            if type(isfolder) == "function" and not isfolder("DeltaUI") then makefolder("DeltaUI") end
            writefile(HOST_CONFIG_FILE, raw)
        end)
    end
end

local function makeFallbackApplyGradient(env)
    return function(frame, from, to, rotation)
        if not frame then return nil end
        local make = env and env.create
        if type(make) ~= "function" then return nil end
        local theme = env and env.theme
        from = from or (theme and theme.accent) or Color3.fromRGB(56, 189, 248)
        to = to or (theme and theme.accent2) or Color3.fromRGB(139, 92, 246)
        local ok, inst = pcall(function() return make("UIGradient", {Rotation = rotation or 45}) end)
        if not (ok and inst) then return nil end
        pcall(function() inst.Color = ColorSequence.new(from, to) end)
        pcall(function() frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255) end)
        pcall(function() inst.Parent = frame end)
        local G = env and env._G
        if type(G) == "table" then
            pcall(function()
                G.__DeltaUI_gradients = G.__DeltaUI_gradients or {}
                table.insert(G.__DeltaUI_gradients, inst)
            end)
        end
        return inst
    end
end


local function builtinTheme()
    return {
        bg = Color3.fromRGB(7, 9, 15),
        surface = Color3.fromRGB(18, 22, 34),
        surfaceLight = Color3.fromRGB(30, 36, 52),
        accent = Color3.fromRGB(56, 189, 248),
        accent2 = Color3.fromRGB(139, 92, 246),
        text = Color3.fromRGB(242, 245, 252),
        textDim = Color3.fromRGB(150, 160, 184),
        border = Color3.fromRGB(52, 62, 88),
        red = Color3.fromRGB(255, 82, 104),
        green = Color3.fromRGB(57, 214, 146),
        warn = Color3.fromRGB(255, 196, 66),
        glow = Color3.fromRGB(56, 189, 248),
        glow2 = Color3.fromRGB(139, 92, 246),
        radius = 14,
        radiusLg = 20,
    }
end






local AGENTLESS_SOURCE = [==[
-- ============================================================
-- AgentLess 页面本体（从 DeltaUI_LanguageCore.lua 剥离）
-- 说明：运行在官方页面宿主注入的环境里，
--       theme / svc / v7 / AgentPage / contentFrame 由宿主提供。
-- ============================================================
local AgentPage = __AGENTLESS_FRAME
if contentFrame then AgentPage.Parent = contentFrame end

local AgentPromptResumeChat
local AgentMessageFrame
local AgentInputBox
local AgentSendButton
local AgentFinalizeMessage
local AgentShowScriptResult
local AgentAddMessage
local AgentTypewriteMessage
local AgentRenderMessageWithCode
local AgentSendMessage
do
local AgentChatMemory = { lastPath = nil, lastObj = nil, lastDeletedDir = nil }
local AgentResumeParent = nil


local function AgentValidatePath(path)
    if type(path) ~= "string" or path == "" then return false end
    
    if path:find("%.%.%/") or path:find("%.%.\\") or path:find("%.%.%.$") then return false end
    if path:find("\x00") or path:find("\\") then return false end
    
    if not path:match("^[%w_./ %-]+$") then return false end
    return true
end


local function AgentGetInstanceFromPath(path)
    local i2, j2 = 1, #path
    while i2 <= j2 and string.byte(path:sub(i2,i2)) <= 32 do i2 = i2 + 1 end
    while j2 >= i2 and string.byte(path:sub(j2,j2)) <= 32 do j2 = j2 - 1 end
    path = path:sub(i2, j2)
    local env = {
        game = game,
        workspace = workspace,
        Players = svc.Players,
        ReplicatedStorage = game:GetService("ReplicatedStorage"),
        ServerScriptService = game:GetService("ServerScriptService"),
        StarterGui = game:GetService("StarterGui"),
        StarterPack = game:GetService("StarterPack"),
        StarterPlayer = game:GetService("StarterPlayer"),
        Lighting = game:GetService("Lighting"),
        SoundService = game:GetService("SoundService"),
    }
    local func, err = loadstring("return " .. path)
    if not func then return nil, "路径解析失败: " .. err end
    setfenv(func, env)
    local success, result = pcall(func)
    if not success then return nil, "路径执行错误: " .. tostring(result) end
    return result, nil
end

local function AgentGetChildNames(instance)
    if not instance then return {} end
    local names = {}
    for _, child in ipairs(instance:GetChildren()) do
        table.insert(names, child.Name .. " (" .. child.ClassName .. ")")
    end
    return names
end

local function AgentTryDecompile(scriptObj)
    if not scriptObj:IsA("LuaSourceContainer") then return nil, "不是脚本/模块" end
    if not decompile then return nil, "当前环境不支持反编译 (decompile 函数缺失)" end
    local success, source = pcall(decompile, scriptObj)
    if not success then return nil, "反编译失败: " .. tostring(source) end
    return source, nil
end

local function AgentGetAllScripts(container)
    
    local scripts = {}
    local stack = {container}
    while #stack > 0 do
        local obj = stack[#stack]
        stack[#stack] = nil
        if obj then
            local children = obj:GetChildren()
            for i = #children, 1, -1 do
                local child = children[i]
                if child:IsA("LuaSourceContainer") then table.insert(scripts, child) end
                stack[#stack + 1] = child
            end
        end
    end
    return scripts
end


local function AgentSafeSegment(seg)
    seg = tostring(seg or ""):gsub("[\\/:*?\"<>|%c\r\n\t]", "_")
    if seg == "" then seg = "_" end
    if #seg > 40 then seg = seg:sub(1, 40) end
    return seg
end

local function AgentSaveScriptToFile(script, baseDir, rootName)
    if not writefile or not makefolder or not isfolder then return false, "文件系统函数不可用" end
    local source, err = AgentTryDecompile(script)
    if not source then return false, err end

    local fullName = script:GetFullName()
    local relativePath = fullName:gsub("^game%.", "")

        if rootName then
        local rootPrefix = rootName .. "."
        if relativePath:sub(1, #rootPrefix) == rootPrefix then
            relativePath = relativePath:sub(#rootPrefix + 1)
        end
    else
                local lastDot = nil
        for i = #relativePath, 1, -1 do
            if relativePath:sub(i, i) == "." then
                lastDot = i
                break
            end
        end
        relativePath = lastDot and relativePath:sub(lastDot + 1) or relativePath
    end

    
    local segs = {}
    for seg in relativePath:gmatch("[^%.]+") do
        table.insert(segs, AgentSafeSegment(seg))
    end
    local fullPath = baseDir .. "/" .. table.concat(segs, "/") .. ".lua"
    if #fullPath > 200 then
        fullPath = baseDir .. "/" .. table.concat(segs, "/"):sub(1, math.max(10, 200 - #baseDir)) .. ".lua"
    end

    local pathParts = {}
    for part in fullPath:gmatch("([^/]+)") do table.insert(pathParts, part) end
    table.remove(pathParts, #pathParts)
    local currentPath = ""
    for _, part in ipairs(pathParts) do
        currentPath = currentPath .. part .. "/"
        local okDir = pcall(function()
            if not isfolder(currentPath) then makefolder(currentPath) end
        end)
        if not okDir then return false, "目录创建失败: " .. tostring(currentPath) end
    end
    if isfolder(fullPath) then fullPath = fullPath .. "_" .. tostring(os.time()) .. ".lua" end
    local successWrite, errWrite = pcall(writefile, fullPath, source)
    if not successWrite then return false, tostring(errWrite) end
    AgentTrackFileOp(fullPath)
    return true, fullPath
end

local function AgentListAllProperties(instance)
    if not instance then return {} end
    local props = {}
    for _, prop in ipairs(instance:GetProperties()) do
        local success, val = pcall(function() return instance[prop] end)
        if success then table.insert(props, prop .. " = " .. tostring(val))
        else table.insert(props, prop .. " = <无法读取>") end
    end
    return props
end

local function AgentFindObjectsByName(name, container)
    local results = {}
    local function recurse(obj)
        if obj.Name:lower():find(name:lower(), 1, true) then
            table.insert(results, obj:GetFullName() .. " (" .. obj.ClassName .. ")")
        end
        for _, child in ipairs(obj:GetChildren()) do recurse(child) end
    end
    recurse(container)
    return results
end

local function AgentListChildrenDepth(instance, maxDepth)
    local result = {}
    local function recurse(obj, depth)
        if depth > maxDepth then return end
        local indent = string.rep("  ", depth)
        table.insert(result, indent .. obj.Name .. " (" .. obj.ClassName .. ")")
        for _, child in ipairs(obj:GetChildren()) do recurse(child, depth + 1) end
    end
    recurse(instance, 0)
    return result
end


local function AgentExecWithTimeout(func, seconds)
    local done = false
    local okRes, ret, err = nil, nil, nil
    local th = task.spawn(function()
        local ok, a, b = pcall(func)
        okRes, ret, err = ok, a, b
        done = true
    end)
    local waited = 0
    local limit = tonumber(seconds) or 15
    while not done and waited < limit do
        task.wait(0.1)
        waited = waited + 0.1
    end
    if not done then
        pcall(task.cancel, th)
        return nil, "执行超时（可能 WaitForChild 等待的对象不存在，已中断）"
    end
    if okRes then return ret, nil else return nil, tostring(err) end
end

local function AgentExecuteLuaCode(code)
    local func, err = loadstring(code)
    if not func then return nil, "编译错误: " .. err end
    local execTimeout = tonumber(AgentLocalAIConfig.executeTimeout) or 15

    
    local out = {}
    local realPrint = print
    local realRconPrint = rconsoleprint
    local function makePrint()
        return function(...)
            local parts = {}
            for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
            local line = table.concat(parts, " ")
            table.insert(out, line)
            
            pcall(realPrint, line)
            if type(realRconPrint) == "function" then pcall(realRconPrint, line .. "\n") end
        end
    end

    
    local okEnv, realEnv = pcall(getfenv)
    if okEnv and type(realEnv) == "table" then
        local env = setmetatable({print = makePrint()}, {__index = realEnv})
        local okSet = pcall(setfenv, func, env)
        if not okSet then
            
            local success, result = AgentExecWithTimeout(func, execTimeout)
            if not success then return nil, "执行错误: " .. tostring(result) end
            if result ~= nil then table.insert(out, tostring(result)) end
            return table.concat(out, "\n"), nil
        end
    else
        local okSet = pcall(setfenv, func, {print = makePrint()})
        if not okSet then
            local success, result = AgentExecWithTimeout(func, execTimeout)
            if not success then return nil, "执行错误: " .. tostring(result) end
            if result ~= nil then table.insert(out, tostring(result)) end
            return table.concat(out, "\n"), nil
        end
    end

    local success, result = AgentExecWithTimeout(func, execTimeout)
    if not success then return nil, "执行错误: " .. tostring(result) end
    if result ~= nil then table.insert(out, tostring(result)) end
    return table.concat(out, "\n"), nil
end

local function AgentTrim(str)
    local i, j = 1, #str
    while i <= j and string.byte(str:sub(i,i)) <= 32 do i = i + 1 end
    while j >= i and string.byte(str:sub(j,j)) <= 32 do j = j - 1 end
    return str:sub(i, j)
end

local function AgentIsPathInput(text)
    local trimmed = AgentTrim(text)
    local pathPrefixes = {"game.", "workspace.", "Players.", "ReplicatedStorage.", "ServerScriptService.", "StarterGui.", "StarterPack.", "StarterPlayer.", "Lighting.", "SoundService."}
    for _, prefix in ipairs(pathPrefixes) do
        if trimmed:sub(1, #prefix) == prefix then
            return true
        end
    end
    if trimmed:find(".", 1, true) and #trimmed > 5 then
        local test, _ = AgentGetInstanceFromPath(trimmed)
        if test then return true end
    end
    return false
end


local AgentConversationState = {
    topic = nil, topicEntities = {}, userMood = "neutral", contextMemory = {}, lastAction = nil, }

local function AgentUpdateConversationState(input, intent, entities)
        if entities.path then
        AgentConversationState.topic = "instance"
        AgentConversationState.topicEntities.path = entities.path
    elseif intent == "search" then
        AgentConversationState.topic = "search"
        AgentConversationState.topicEntities.target = entities.target
    end

        AgentConversationState.lastAction = {
        intent = intent,
        entities = entities,
        timestamp = os.time()
    }

        if input:match("谢谢|感谢|好棒|太棒了") then
        AgentConversationState.userMood = "happy"
    elseif input:match("算了|不用了|错误|失败|糟糕") then
        AgentConversationState.userMood = "frustrated"
    elseif input:match("为什么|怎么|如何") then
        AgentConversationState.userMood = "curious"
    else
        AgentConversationState.userMood = "neutral"
    end
end


local AgentChineseSensitiveWords = {
    "他妈的", "他妈", "草你妈", "操你妈", "傻逼", "煞笔", "傻b", "cnm", "qnmd", "tmd",
    "废物", "去死", "脑残", "弱智", "白痴", "神经病", "杂种", "王八蛋",
    "操你", "操蛋", "草你", "草泥马", "贱人", "贱货", "贱逼", "婊子",
    "狗东西", "狗娘", "狗日", "狗屎", "狗屁", "傻狗", "狗杂种",
    "猪头", "猪脑", "笨猪", "猪狗", "蠢猪",
    "滚蛋", "滚开", "滚犊子",
}

local AgentEnglishSensitiveWords = {
    "fuck", "fucking", "fucked", "fucker", "shit", "shitting", "bitch", "bitchy",
    "asshole", "dickhead", "cock", "cunt", "nigger", "faggot", "retard", "damn", "dammit", "sb",
}

local AgentContextSensitiveWords = { "草", "操", "滚", "贱", "狗", "猪" }

local function isBoundary(c)
    if c == "" then return true end
    if c:match("%s") then return true end
    local b = c:byte()
    if b < 128 then

        if (b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b == 95 then
            return false
        end
        return true
    end

    local cnPunct = "，。！？、；：“”‘’（）【】《》…—·"
    return cnPunct:find(c, 1, true) ~= nil
end

local function isWholeWord(text, pos, len)
    local before = pos > 1 and text:sub(pos - 1, pos - 1) or ""
    local after = pos + len <= #text and text:sub(pos + len, pos + len) or ""
    return isBoundary(before) and isBoundary(after)
end

local function AgentCheckSensitive(text)
    if not text or text == "" then return false end
    local lower = string.lower(text)

    for _, w in ipairs(AgentEnglishSensitiveWords) do
        local pos = 1
        while true do
            local s, e = lower:find(w, pos, true)
            if not s then break end
            if isWholeWord(lower, s, #w) then return true end
            pos = e + 1
        end
    end

    for _, w in ipairs(AgentChineseSensitiveWords) do
        if lower:find(w, 1, true) then return true end
    end

    for _, w in ipairs(AgentContextSensitiveWords) do
        local pos = 1
        while true do
            local s, e = lower:find(w, pos, true)
            if not s then break end
            if isWholeWord(lower, s, #w) then return true end
            pos = e + 1
        end
    end
    return false
end

local AgentThinkingPhases = {
    instruction = {
        "分析指令意图...",
        "解析参数结构...",
        "构建执行方案...",
        "验证操作安全性...",
        "准备返回结果...",
        "正在执行操作...",
    },
    path = {
        "识别路径格式...",
        "验证路径有效性...",
        "查询对象层级...",
        "检查访问权限...",
        "整理返回信息...",
        "定位目标对象...",
    },
    chat = {
        "理解对话内容...",
        "匹配情感状态...",
        "检索相关记忆...",
        "组织回复语言...",
        "优化表达方式...",
    },
    code = {
        "分析代码片段...",
        "检查语法结构...",
        "评估执行效率...",
        "准备输出结果...",
        "验证安全性...",
    },
    search = {
        "确定搜索范围...",
        "遍历目标容器...",
        "匹配目标对象...",
        "整理搜索结果...",
    },
    decompile = {
        "定位脚本位置...",
        "读取源码内容...",
        "处理反编译请求...",
        "格式化输出结果...",
    },
    fallback = {
        "仍在思考...",
        "让我想想...",
        "理解你的意思...",
        "组织回复...",
    }
}

local AgentRobloxKnowledge = {
    services = {
        game = {"Workspace", "Players", "ReplicatedStorage", "ServerScriptService", "StarterGui", "StarterPack", "Lighting", "SoundService", "TextChatService"},
        Workspace = {"BasePart", "Model", "Terrain", "Camera"},
        Players = {"Player", "LocalPlayer"},
        Player = {"Character", "Backpack", "PlayerGui", "PlayerScripts"},
        Character = {"Humanoid", "HumanoidRootPart", "Head", "Torso", "LeftArm", "RightArm"},
        Humanoid = {"Health", "MaxHealth", "WalkSpeed", "JumpPower"},
        BasePart = {"Position", "Size", "BrickColor", "Transparency", "Anchored", "CanCollide"},
        Model = {"PrimaryPart", "GetChildren", "GetDescendants"},
    },
    commonPatterns = {
        "game.Workspace.%w+",
        "game.Players.LocalPlayer.Character",
        "game.ReplicatedStorage.%w+",
        "game.Workspace.%w+.Humanoid",
    }
}

local AgentMetrics = {
    thinkingStartTime = 0, toolCalls = 0, fileOperations = 0, }

local AgentThinkingPhase = ""
local AgentCustomProgressMsg = ""
local AgentLastToolName = ""
local AgentLastToolPhase = ""
local AgentLastToolOp = {}

local AgentRecentSavedFiles = {}
local AgentLastDecompileDir = nil

local function AgentResetMetrics()
    AgentMetrics.thinkingStartTime = 0
    AgentMetrics.toolCalls = 0
    AgentMetrics.fileOperations = 0
end

local function AgentStartTiming()
    AgentMetrics.thinkingStartTime = tick()
end

local function AgentTrackToolCall()
    AgentMetrics.toolCalls = AgentMetrics.toolCalls + 1
end

function AgentTrackFileOp(filePath) -- [官方页面] 提为全局：原文件部分引用早于 local 声明
    AgentMetrics.fileOperations = AgentMetrics.fileOperations + 1
    if filePath and type(filePath) == "string" then
        table.insert(AgentRecentSavedFiles, filePath)
        if #AgentRecentSavedFiles > 500 then
            table.remove(AgentRecentSavedFiles, 1)
        end
    end
end

local function AgentClearSavedFilesTracking()
    AgentRecentSavedFiles = {}
    AgentLastDecompileDir = nil
end

local function AgentGetThinkingDuration()
    local elapsed
    if AgentMetrics.thinkingStartTime == 0 then
        elapsed = AgentLocalAIState.lastLatency or 0
    else
        elapsed = math.floor((tick() - AgentMetrics.thinkingStartTime) * 100) / 100
    end
    local complexity = AgentMetrics.toolCalls * 0.8 + AgentMetrics.fileOperations * 0.4
    local minTime = math.floor((1.5 + math.min(complexity, 3.0)) * 100) / 100
    local float = math.floor(math.random() * 0.5 * 100) / 100
    return math.floor(math.max(elapsed, minTime) * 100 + float * 100) / 100
end

local function AgentGenerateStatsText(done)
    local duration = AgentGetThinkingDuration()
    local durationStr = string.format("%.2f", duration)
    local prefix = done and "思考完成" or "仍在思考"
    if AgentMetrics.toolCalls == 0 and AgentMetrics.fileOperations == 0 then
        return prefix .. " " .. durationStr .. "s"
    end
    local parts = {prefix .. " " .. durationStr .. "s"}
    if AgentMetrics.toolCalls > 0 then
        table.insert(parts, "执行了 " .. AgentMetrics.toolCalls .. " 次 lua")
    end
    if AgentMetrics.fileOperations > 0 then
        table.insert(parts, "操作 " .. AgentMetrics.fileOperations .. " 次文件系统")
    end
    return table.concat(parts, " · ")
end

local AgentCurrentSession = {
    sessionDir = nil,
    sessionFile = nil,
    placeId = nil,
    sessionTitle = nil,
    sessionTime = nil,
    isFirstRound = true,
    titleTried = false,
}

local function AgentGenerateTitle(userInput)
    if not userInput or userInput == "" then return "新对话" end
    local cleaned = tostring(userInput):gsub("[，。！？、,%.!?：:；;…—%-]+", " ")
    cleaned = cleaned:gsub("%s+", " ")
    local title = cleaned:sub(1, 24)
    if #cleaned > 24 then title = title .. "…" end
    title = title:gsub("^%s+", ""):gsub("%s+$", "")
    return title ~= "" and title or "新对话"
end

local function AgentEnsureAgentFolders()
    if not makefolder then return false end
    pcall(function()
        if not isfolder("DeltaUI") then makefolder("DeltaUI") end
        if not isfolder("DeltaUI/Agent") then makefolder("DeltaUI/Agent") end
        if not isfolder("DeltaUI/Agent/Chat") then makefolder("DeltaUI/Agent/Chat") end
        if not isfolder("DeltaUI/Agent/Remember") then makefolder("DeltaUI/Agent/Remember") end
    end)
    return true
end

local function AgentInitSessionDir()
    if AgentCurrentSession.sessionDir then return AgentCurrentSession.sessionDir end

    AgentEnsureAgentFolders()

    local placeId = tostring(game.PlaceId or 0)
    local baseDir = "DeltaUI/Agent/Chat/对话_" .. placeId

    if not isfolder(baseDir) and makefolder then
        pcall(function() makefolder(baseDir) end)
    end

    AgentCurrentSession.sessionDir = baseDir
    AgentCurrentSession.placeId = tonumber(placeId) or 0
    AgentCurrentSession.sessionTime = os.time()

    local titleName = AgentCurrentSession.sessionTitle or "新对话"
    local safeTitle = tostring(titleName):gsub("[/\\:*?\"<>|\r\n\t ]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if safeTitle == "" then safeTitle = "default" end
    if #safeTitle > 40 then safeTitle = safeTitle:sub(1, 40) end
    local filePath = baseDir .. "/" .. safeTitle .. ".chat"
    if isfile(filePath) then
        filePath = baseDir .. "/" .. safeTitle .. "_" .. os.time() .. ".chat"
    end
    AgentCurrentSession.sessionFile = filePath
    AgentCurrentSession.sessionKey = safeTitle

    return baseDir
end

local function AgentRenameSessionDir(title)
    AgentCurrentSession.sessionTitle = title or AgentCurrentSession.sessionTitle or "新对话"
end

local function AgentReadChatFile(path)
    if not path or not isfile or not readfile or not isfile(path) then return nil end
    local ok, content = pcall(readfile, path)
    if not ok or not content or content == "" then return nil end

    local data
    local decoded = pcall(function()
        data = svc.HttpService:JSONDecode(content)
    end)
    if decoded and type(data) == "table" and type(data.messages) == "table" then
        return data
    end
    return nil
end

local function AgentFindLatestChat()
    AgentEnsureAgentFolders()
    local placeId = tostring(game.PlaceId or 0)
    local folder = "DeltaUI/Agent/Chat/对话_" .. placeId
    if not isfolder(folder) or not listfiles then return nil end

    local candidates = {}
    local ok, files = pcall(listfiles, folder)
    if not ok or type(files) ~= "table" then return nil end

    for _, path in ipairs(files) do
        if isfile(path) and path:match("%.chat$") then
            local data = AgentReadChatFile(path)
            if data and data.messages and #data.messages > 0 then
                local name = path:match("([^/\\]+)$") or path
                local modified = 0
                if data.updatedAt then modified = tonumber(data.updatedAt) or 0 end
                if modified == 0 then
                    local n = name:match("session_(%d+)")
                    modified = tonumber(n) or (name == "default.chat" and 0 or 1)
                end
                candidates[#candidates + 1] = {
                    path = folder,
                    chatFile = path,
                    name = name:gsub("%.chat$", ""),
                    data = data,
                    modified = modified
                }
            end
        end
    end

    if #candidates == 0 then return nil end
    table.sort(candidates, function(a, b)
        if a.modified == b.modified then return a.name > b.name end
        return a.modified > b.modified
    end)
    return candidates[1]
end

local function AgentLoadChatHistory(chatFolder)
    if not chatFolder then return false end
    local data = chatFolder.data or AgentReadChatFile(chatFolder.chatFile)
    if not data or type(data.messages) ~= "table" then return false end

    AgentChatMemory.conversationHistory = data.messages
    if data.metadata then
        AgentChatMemory.lastPath = data.metadata.lastPath
        AgentChatMemory.lastDeletedDir = data.metadata.lastDeletedDir
    end

    AgentCurrentSession.sessionDir = chatFolder.path
    AgentCurrentSession.sessionFile = chatFolder.chatFile
    AgentCurrentSession.sessionKey = chatFolder.name
    AgentCurrentSession.sessionTitle = data.metadata and data.metadata.title or chatFolder.name
    AgentCurrentSession.sessionTime = data.createdAt or os.time()
    AgentCurrentSession.placeId = tonumber(game.PlaceId or 0) or 0
    AgentCurrentSession.isFirstRound = false
    return true
end

AgentPromptResumeChat = function()
    local latest = AgentFindLatestChat()
    if not latest then return false end
    if not AgentResumeParent or not AgentResumeParent.Parent then return false end

    local title = ""
    local summary = ""
    local data = latest.data or AgentReadChatFile(latest.chatFile)
    if data then
        title = data.metadata and data.metadata.title or latest.name or "未知对话"
        if data.messages then
            for i = #data.messages, 1, -1 do
                if data.messages[i].role == "user" then
                    summary = tostring(data.messages[i].content or "")
                    if #summary > 40 then summary = summary:sub(1, 40) .. "…" end
                    break
                end
            end
        end
    end

    local card = create("Frame", {
        Name = "ResumeCard",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 44),
        Size = UDim2.new(0, 340, 0, 132),
        BackgroundColor3 = theme.surface,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        ZIndex = 60,
        Active = true,
        Parent = AgentResumeParent
    })
    corner(12, card)
    stroke(theme.border, 1, card)

    local headTxt = create("TextLabel", {
        Position = UDim2.new(0, 16, 0, 12),
        Size = UDim2.new(1, -32, 0, 22),
        BackgroundTransparency = 1,
        Text = "检测到可加载的对话历史",
        TextColor3 = theme.text,
        TextSize = 15,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 61,
        Parent = card
    })
    local subTxt = create("TextLabel", {
        Position = UDim2.new(0, 16, 0, 40),
        Size = UDim2.new(1, -32, 0, 54),
        BackgroundTransparency = 1,
        Text = (title ~= "" and ("对话：" .. title) or "未知对话") .. (summary ~= "" and ("\n最近：\"" .. summary .. "\"") or ""),
        TextColor3 = theme.textDim,
        TextSize = 12,
        Font = Enum.Font.SourceSans,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        ZIndex = 61,
        Parent = card
    })

    local cancelBtn = create("TextButton", {
        Position = UDim2.new(0, 16, 1, -40),
        Size = UDim2.new(0.5, -20, 0, 30),
        BackgroundColor3 = theme.surfaceLight,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        Text = "",
        ZIndex = 62,
        Parent = card
    })
    corner(8, cancelBtn)
    create("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "取消",
        TextColor3 = theme.text,
        TextSize = 13,
        Font = Enum.Font.SourceSansBold,
        ZIndex = 63,
        Parent = cancelBtn
    })

    local confirmBtn = create("TextButton", {
        Position = UDim2.new(0.5, 4, 1, -40),
        Size = UDim2.new(0.5, -20, 0, 30),
        BackgroundColor3 = theme.accent,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        Text = "",
        ZIndex = 62,
        Parent = card
    })
    applyGradient(confirmBtn, theme.accent, theme.accent2, 120)
    corner(8, confirmBtn)
    create("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "确认",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 13,
        Font = Enum.Font.SourceSansBold,
        ZIndex = 63,
        Parent = confirmBtn
    })

    cancelBtn.MouseButton1Click:Connect(function()
        card:Destroy()
    end)

    confirmBtn.MouseButton1Click:Connect(function()
        card:Destroy()
        if AgentLoadChatHistory(latest) then
            AgentCurrentSession.isFirstRound = false
            task.spawn(function()
                local history = AgentChatMemory.conversationHistory or {}
                for _, msg in ipairs(history) do
                    AgentAddMessage(msg.content, msg.role == "user")
                    task.wait(0.05)
                end
            end)
        end
    end)

    return true
end

local function AgentSaveChatHistory()
    if not writefile or not svc.HttpService then return end

    local sessionDir = AgentInitSessionDir()
    if not AgentCurrentSession.sessionFile then
        AgentCurrentSession.sessionFile = sessionDir .. "/default.chat"
        AgentCurrentSession.sessionKey = "default"
    end

    local messages = AgentChatMemory.conversationHistory or {}
    
    local modelsUsed = {}
    local lastModel = nil
    for _, m in ipairs(messages) do
        local lbl = m.modelLabel
        if lbl and lbl ~= "" then
            if modelsUsed[lbl] == nil then modelsUsed[lbl] = true end
            lastModel = lbl
        end
    end
    local modelList = {}
    for label in pairs(modelsUsed) do table.insert(modelList, label) end
    table.sort(modelList)
    local chatData = {
        version = 2,
        sessionKey = AgentCurrentSession.sessionKey,
        placeId = AgentCurrentSession.placeId or game.PlaceId or 0,
        createdAt = AgentCurrentSession.sessionTime or os.time(),
        updatedAt = os.time(),
        messages = messages,
        metadata = {
            lastPath = AgentChatMemory.lastPath,
            lastDeletedDir = AgentChatMemory.lastDeletedDir,
            totalRounds = #messages,
            title = AgentCurrentSession.sessionTitle or "新对话",
            model = lastModel,
            models = modelList
        }
    }

    local ok, jsonStr = pcall(function()
        return svc.HttpService:JSONEncode(chatData)
    end)
    if ok and jsonStr then
        pcall(function() writefile(AgentCurrentSession.sessionFile, jsonStr) end)
    end
end

local AgentMemoryDBPath = "DeltaUI/Agent/Remember/memory_v3.db"
local AgentMemoryCache = nil
local AgentMemoryCachePath = nil
local AgentMemoryDBPathFallback = AgentMemoryDBPath



local function AgentGetMemoryDBPath()
    local dir = AgentCurrentSession and AgentCurrentSession.sessionDir
    if dir and dir ~= "" then
        return dir .. "/memory.db"
    end
    return AgentMemoryDBPathFallback
end
local AgentMemoryDirty = false
local AgentMemoryCategories = {
    fact = {decayRate = 0.005, minImportance = 0.3},
    preference = {decayRate = 0.002, minImportance = 0.5},
    decision = {decayRate = 0.003, minImportance = 0.4},
    tool_result = {decayRate = 0.01, minImportance = 0.2},
    entity = {decayRate = 0.004, minImportance = 0.3},
    context = {decayRate = 0.015, minImportance = 0.1},
}

local function AgentMemoryNormalize(text)
    return tostring(text or ""):lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function AgentMemoryTokenize(text)
    local tokens = {}
    local normalized = AgentMemoryNormalize(text)
    for word in normalized:gmatch("[%a_]+") do
        if #word >= 2 then
            tokens[#tokens + 1] = word
        end
    end
    local compact = normalized:gsub("%s+", "")
    if #compact >= 3 then
        for i = 1, #compact - 2 do
            local triple = compact:sub(i, i + 2)
            if triple:match("[\228-\255]") then
                tokens[#tokens + 1] = triple
            end
        end
    end
    return tokens
end
local function AgentExtractMemories(input, output, context)
    local memories = {}
    local userInput = tostring(input or "")
    local aiOutput = tostring(output or "")
    local combined = userInput .. " " .. aiOutput
    local now = os.time()
    local topic = AgentConversationState and AgentConversationState.topic or nil
    for scriptPath, byteCount in aiOutput:gmatch("已反编译%s*([^\n，,]+)[^%d]*(%d+)%s*字节") do
        memories[#memories + 1] = {
            category = "tool_result",
            content = "用户反编译了脚本 " .. scriptPath .. "，源码 " .. byteCount .. " 字节",
            tags = {"decompile", scriptPath},
            importance = 0.6,
            time = now,
            lastAccess = now,
            accessCount = 0,
        }
    end
    for filePath in aiOutput:gmatch("已保存到：([^\n]+)") do
        filePath = AgentTrim(filePath)
        if filePath ~= "" then
            memories[#memories + 1] = {
                category = "tool_result",
                content = "反编译源码保存路径：" .. filePath,
                tags = {"decompile", "filepath", filePath},
                importance = 0.4,
                time = now,
                lastAccess = now,
                accessCount = 0,
            }
        end
    end
    for count in aiOutput:gmatch("共保存%s*(%d+)%s*个脚本") do
        memories[#memories + 1] = {
            category = "tool_result",
            content = "批量反编译完成，共保存 " .. count .. " 个脚本",
            tags = {"decompile_all", "batch"},
            importance = 0.5,
            time = now,
            lastAccess = now,
            accessCount = 0,
        }
    end
    for path in combined:gmatch("(game%.[%w%.]+)") do
        if #path > 8 and #path < 200 then
            memories[#memories + 1] = {
                category = "entity",
                content = "用户提及的 Roblox 对象路径：" .. path,
                tags = {"path", path},
                importance = 0.4,
                time = now,
                lastAccess = now,
                accessCount = 0,
            }
        end
    end
    for _, svc in ipairs({"PlayerScripts", "ReplicatedStorage", "ServerScriptService", "Workspace", "StarterGui"}) do
        if combined:find(svc, 1, true) then
            memories[#memories + 1] = {
                category = "entity",
                content = "对话中涉及 " .. svc .. " 服务",
                tags = {"service", svc},
                importance = 0.3,
                time = now,
                lastAccess = now,
                accessCount = 0,
            }
        end
    end
    if userInput:match("我喜欢|我偏好|我习惯|我总是|我喜欢用|帮我用") then
        local prefContent = userInput:match("我喜欢(.+)") or userInput:match("我偏好(.+)") or userInput:match("我习惯(.+)") or ""
        prefContent = AgentTrim(prefContent)
        if prefContent ~= "" and #prefContent < 200 then
            memories[#memories + 1] = {
                category = "preference",
                content = "用户偏好：" .. prefContent,
                tags = {"preference"},
                importance = 0.8,
                time = now,
                lastAccess = now,
                accessCount = 0,
            }
        end
    end

    if userInput:match("那就用|决定|选择|那就这么") then
        local decisionContent = userInput:match("那就用(.+)") or userInput:match("决定(.+)") or userInput:match("选择(.+)") or ""
        decisionContent = AgentTrim(decisionContent)
        if decisionContent ~= "" and #decisionContent < 200 then
            memories[#memories + 1] = {
                category = "decision",
                content = "用户决策：" .. decisionContent,
                tags = {"decision"},
                importance = 0.7,
                time = now,
                lastAccess = now,
                accessCount = 0,
            }
        end
    end
    for fact in aiOutput:gmatch("([^\n。！？]+[是包含有][^\n。！？]+)") do
        fact = AgentTrim(fact)
        if #fact > 10 and #fact < 300 then
            if not fact:find("已反编译") and not fact:find("已保存") and not fact:find("共保存") then
                memories[#memories + 1] = {
                    category = "fact",
                    content = fact,
                    tags = {"knowledge"},
                    importance = 0.5,
                    time = now,
                    lastAccess = now,
                    accessCount = 0,
                }
            end
        end
    end

    
    local contextSummary = AgentTrim(userInput:sub(1, 80))
    if contextSummary ~= "" then
        memories[#memories + 1] = {
            category = "context",
            content = "用户曾问过：" .. contextSummary,
            tags = topic and {topic} or {"conversation"},
            importance = 0.2,
            time = now,
            lastAccess = now,
            accessCount = 0,
        }
    end

    return memories
end
local function AgentMemorySimilarity(memA, memB)
    local tokensA = AgentMemoryTokenize(memA.content)
    local tokensB_set = {}
    for _, t in ipairs(AgentMemoryTokenize(memB.content)) do
        tokensB_set[t] = true
    end
    if #tokensA == 0 then return 0 end
    local hits = 0
    for _, t in ipairs(tokensA) do
        if tokensB_set[t] then hits = hits + 1 end
    end
    return hits / #tokensA
end


local function AgentLoadMemoryDB()
    local path = AgentGetMemoryDBPath()
    
    if AgentMemoryCache and AgentMemoryCachePath == path then return AgentMemoryCache end
    AgentMemoryCache = {}
    AgentMemoryCachePath = path
    if not isfile or not readfile or not isfile(path) then
        return AgentMemoryCache
    end
    local ok, content = pcall(readfile, path)
    if not ok or not content then return AgentMemoryCache end
    for line in tostring(content):gmatch("[^\r\n]+") do
        local data
        local decoded = pcall(function() data = svc.HttpService:JSONDecode(line) end)
        if decoded and type(data) == "table" and data.content and data.category then
            AgentMemoryCache[#AgentMemoryCache + 1] = data
        end
    end
    return AgentMemoryCache
end


local function AgentSaveMemoryDB()
    if not AgentMemoryDirty or not writefile then return end
    AgentEnsureAgentFolders()
    local path = AgentGetMemoryDBPath()
    
    local dir = AgentCurrentSession and AgentCurrentSession.sessionDir
    if dir and dir ~= "" and isfolder and not isfolder(dir) then
        pcall(function() makefolder(dir) end)
    end
    local lines = {}
    for _, mem in ipairs(AgentMemoryCache or {}) do
        local ok, encoded = pcall(function() return svc.HttpService:JSONEncode(mem) end)
        if ok and encoded then
            lines[#lines + 1] = encoded
        end
    end
    pcall(function() writefile(path, table.concat(lines, "\n")) end)
    AgentMemoryDirty = false
end


local function AgentAddMemory(mem)
    local db = AgentLoadMemoryDB()
    
    for i, existing in ipairs(db) do
        if existing.category == mem.category then
            local sim = AgentMemorySimilarity(existing, mem)
            if sim >= 0.75 then
                
                if #mem.content > #existing.content then
                    db[i].content = mem.content
                end
                db[i].importance = math.min(1.0, (existing.importance or 0.3) + 0.1)
                db[i].time = mem.time
                db[i].lastAccess = mem.time
                
                if mem.tags then
                    db[i].tags = db[i].tags or {}
                    for _, tag in ipairs(mem.tags) do
                        local found = false
                        for _, etag in ipairs(db[i].tags) do
                            if etag == tag then found = true; break end
                        end
                        if not found then table.insert(db[i].tags, tag) end
                    end
                end
                AgentMemoryDirty = true
                return
            end
        end
    end
    
    db[#db + 1] = mem
    AgentMemoryDirty = true
    
    local maxMemories = 500
    if #db > maxMemories then
        
        table.sort(db, function(a, b)
            local scoreA = (a.importance or 0.3) * 0.7 + (a.accessCount or 0) * 0.05
            local scoreB = (b.importance or 0.3) * 0.7 + (b.accessCount or 0) * 0.05
            return scoreA > scoreB
        end)
        local trimmed = {}
        for i = 1, maxMemories do trimmed[i] = db[i] end
        AgentMemoryCache = trimmed
    end
end


local function AgentMemoryScore(query, mem)
    if type(mem) ~= "table" then return 0 end
    local qTokens = {}
    for _, t in ipairs(AgentMemoryTokenize(query)) do qTokens[t] = true end
    if next(qTokens) == nil then return 0 end

    local memText = AgentMemoryNormalize((mem.content or "") .. " " .. table.concat(mem.tags or {}, " "))
    if memText == "" then return 0 end

    
    local hits, total = 0, 0
    for token in pairs(qTokens) do
        total = total + 1
        if memText:find(token, 1, true) then hits = hits + 1 end
    end
    local tokenScore = total > 0 and (hits / total) or 0

    
    local tagBoost = 0
    if mem.tags then
        for _, tag in ipairs(mem.tags) do
            if #tag >= 3 and query:lower():find(tag:lower(), 1, true) then
                tagBoost = tagBoost + 0.15
            end
        end
    end

    
    local importance = mem.importance or 0.3

    
    local age = math.max(0, os.time() - tonumber(mem.time or 0)) / 86400
    local category = mem.category or "context"
    local decayRate = (AgentMemoryCategories[category] or {}).decayRate or 0.01
    local decay = math.max(0.2, 1 - age * decayRate)

    
    local accessBoost = math.min(0.2, (mem.accessCount or 0) * 0.02)

    local score = (tokenScore * 0.6 + tagBoost) * importance * decay + accessBoost
    return math.min(1.0, score)
end



local AgentSafeString


local function AgentRetrieveMemory(query, limit)
    local db = AgentLoadMemoryDB()
    if #db == 0 then return {} end

    local scored = {}
    for _, mem in ipairs(db) do
        local score = AgentMemoryScore(query, mem)
        if score > 0.05 then
            scored[#scored + 1] = {score = score, record = mem}
        end
    end
    table.sort(scored, function(a, b)
        if a.score == b.score then
            return tonumber(a.record.time or 0) > tonumber(b.record.time or 0)
        end
        return a.score > b.score
    end)

    local result, totalLen = {}, 0
    local maxCount = tonumber(limit) or 8
    for i = 1, math.min(#scored, maxCount) do
        local r = scored[i].record
        
        r.accessCount = (r.accessCount or 0) + 1
        r.content = r.content or ""
        r.lastAccess = os.time()
        AgentMemoryDirty = true
        local item = {
            score = scored[i].score,
            content = AgentSafeString(r.content or "", 800),
            category = r.category or "unknown",
            tags = r.tags or {},
        }
        totalLen = totalLen + #item.content
        if totalLen > 6000 then break end
        result[#result + 1] = item
    end
    
    AgentSaveMemoryDB()
    return result
end


local function AgentSaveMemory(input, output)
    if not input or not output then return end
    AgentEnsureAgentFolders()
    local memories = AgentExtractMemories(input, output, AgentConversationState)
    for _, mem in ipairs(memories) do
        AgentAddMemory(mem)
    end
    AgentSaveMemoryDB()
end


local function AgentLoadMemoryRecords(limit)
    local db = AgentLoadMemoryDB()
    local max = limit or 80
    local start = math.max(1, #db - max + 1)
    local trimmed = {}
    for i = start, #db do
        local mem = db[i]
        trimmed[#trimmed + 1] = {
            input = mem.content or "",
            output = "",
            topic = mem.category or "",
            time = mem.time or os.time(),
        }
    end
    return trimmed
end

local function AgentGetOutputDir()
    local sessionDir = AgentInitSessionDir()
    local outputDir = sessionDir .. "/Output"
    if not isfolder(outputDir) and makefolder then pcall(function() makefolder(outputDir) end) end
    return outputDir
end

local function AgentCalculateThinkingDuration(steps, inputType)
    local base = 0.25
    local typeMultiplier = {
        instruction = 1.1,
        path = 1.0,
        chat = 0.7,
        code = 1.3,
        search = 1.1,
        decompile = 1.2,
        fallback = 1.0
    }
    local m = typeMultiplier[inputType] or 1.0
    local total = #steps * base * m
    return math.min(2.5, math.max(0.8, total))
end


local function AgentResolveDecompileTarget(targetStr)
    if not targetStr or targetStr == "" then return nil, "未提供目标" end
    targetStr = AgentTrim(targetStr)

    
    if targetStr:find("^game%.") or targetStr:find("^workspace") then
        local obj, err = AgentGetInstanceFromPath(targetStr)
        if obj then return obj, nil, targetStr end
        return nil, err or "路径不可达", targetStr
    end

    
    local function getPS()
        local lp = svc.Players.LocalPlayer
        return lp and lp:FindFirstChild("PlayerScripts"), "PlayerScripts"
    end
    local function getRS()
        return game:GetService("ReplicatedStorage"), "ReplicatedStorage"
    end
    local function getSSS()
        return game:GetService("ServerScriptService"), "ServerScriptService"
    end
    local function getSG()
        return game:GetService("StarterGui"), "StarterGui"
    end
    local function getSP()
        return game:GetService("StarterPlayer"), "StarterPlayer"
    end
    local serviceMap = {
        ["playerscripts"] = getPS, ["player_scripts"] = getPS, ["玩家脚本"] = getPS, ["玩家脚本服务"] = getPS,
        ["replicatedstorage"] = getRS, ["复制储存"] = getRS, ["复制存储"] = getRS,
        ["复制储存服务"] = getRS, ["复制存储服务"] = getRS, ["副本存储"] = getRS,
        ["serverscriptservice"] = getSSS, ["server_script_service"] = getSSS,
        ["服务器脚本服务"] = getSSS, ["服务器脚本"] = getSSS,
        ["startergui"] = getSG, ["starter_gui"] = getSG, ["初始gui"] = getSG, ["启动gui"] = getSG,
        ["starterplayer"] = getSP, ["starter_player"] = getSP, ["初始玩家"] = getSP, ["启动玩家"] = getSP,
    }

    local lower = targetStr:lower():gsub("%s+", "")
    local lowerNoSpace = targetStr:gsub("%s+", "")
    if serviceMap[lower] then
        local obj, name = serviceMap[lower]()
        if obj then return obj, nil, name end
        return nil, name .. " 未找到", name
    end
    if serviceMap[lowerNoSpace] then
        local obj, name = serviceMap[lowerNoSpace]()
        if obj then return obj, nil, name end
        return nil, name .. " 未找到", name
    end
    if serviceMap[targetStr] then
        local obj, name = serviceMap[targetStr]()
        if obj then return obj, nil, name end
        return nil, name .. " 未找到", name
    end

    
    local searchRoots = {}
    local lp = svc.Players.LocalPlayer
    if lp then
        local ps = lp:FindFirstChild("PlayerScripts")
        if ps then table.insert(searchRoots, {obj = ps, name = "PlayerScripts"}) end
    end
    table.insert(searchRoots, {obj = game:GetService("ReplicatedStorage"), name = "ReplicatedStorage"})

    for _, root in ipairs(searchRoots) do
        if root.obj then
            
            local child = root.obj:FindFirstChild(targetStr)
            if child then
                return child, nil, child:GetFullName()
            end
            
            local desc = root.obj:FindFirstChild(targetStr, true)
            if desc then
                return desc, nil, desc:GetFullName()
            end
        end
    end

    return nil, "在 PlayerScripts 和 ReplicatedStorage 中均未找到名为「" .. targetStr .. "」的对象", targetStr
end


local function AgentDecompileSmart(targetStr)
    local obj, err, resolvedPath = AgentResolveDecompileTarget(targetStr)
    if not obj then
        return "找不到目标：" .. tostring(err or "未知错误") .. "。请提供脚本路径或名称，例如「反编译 game.Workspace.Script」或「反编译 PlayerScripts 下的某脚本」。"
    end

    local isScript = obj:IsA("LuaSourceContainer")
    local childCount = #obj:GetChildren()
    local childScripts = AgentGetAllScripts(obj)
    local hasChildScripts = #childScripts > 0

    
    if not isfolder("DeltaUI") then makefolder("DeltaUI") end
    if not isfolder("DeltaUI/Agent") then makefolder("DeltaUI/Agent") end
    local od = AgentGetOutputDir()
    if not isfolder(od) then makefolder(od) end

    
    if isScript and not hasChildScripts then
        local source, derr = AgentTryDecompile(obj)
        if not source then
            return "反编译失败：" .. tostring(derr) .. "\n目标：" .. resolvedPath
        end
        AgentTrackToolCall()
        local savedPath = nil
        if writefile and makefolder and isfolder then
            local okSave, saveOk, savePath = pcall(AgentSaveScriptToFile, obj, od, nil)
            if okSave and saveOk then
                savedPath = savePath
                AgentLastDecompileDir = od
            end
        end
        local msg = "已反编译 " .. resolvedPath .. "，源码共 " .. #source .. " 字节。"
        if savedPath then msg = msg .. "已保存到：" .. tostring(savedPath) end
        return msg

    
    elseif isScript and hasChildScripts then
        local source, derr = AgentTryDecompile(obj)
        if source then
            AgentTrackToolCall()
            local savedPath = nil
            if writefile and makefolder and isfolder then
                local okSave, saveOk, savePath = pcall(AgentSaveScriptToFile, obj, od, nil)
                if okSave and saveOk then
                    savedPath = savePath
                    AgentLastDecompileDir = od
                end
            end
            local msg = "已反编译 " .. resolvedPath .. "，源码共 " .. #source .. " 字节。"
            if savedPath then msg = msg .. "已保存到：" .. tostring(savedPath) end
            msg = msg .. "\n\n我注意到它下方还有 " .. #childScripts .. " 个子脚本。需要我继续反编译这些子脚本吗？"
            return msg
        else
            return "反编译失败：" .. tostring(derr) .. "\n目标：" .. resolvedPath
        end

    
    elseif not isScript and hasChildScripts then
        local placeId = game.PlaceId or 0
        local folderName = obj.Name or "Unknown"
        local baseDir = od .. "/反编译_" .. placeId .. "_" .. os.time() .. "/" .. folderName
        if not isfolder(baseDir) then
            local parts = {}
            for part in baseDir:gmatch("([^/]+)") do
                table.insert(parts, part)
            end
            local cur = ""
            for _, part in ipairs(parts) do
                cur = cur .. part .. "/"
                if not isfolder(cur) then makefolder(cur) end
            end
        end

        local saved = 0
        local errors = {}
        for _, sc in ipairs(childScripts) do
            local src, serr = AgentTryDecompile(sc)
            if src then
                AgentTrackToolCall()
                local fullName = sc:GetFullName()
                local escapedName = obj:GetFullName():gsub("([^%w])", "%%%1")
                local relPath = fullName:gsub("^" .. escapedName .. "%.?", ""):gsub("%.", "/")
                local filePath = baseDir .. "/" .. relPath .. ".lua"
                local dir = filePath:match("^(.*)/[^/]+$")
                if dir and not isfolder(dir) then
                    local cur = ""
                    for part in dir:gmatch("([^/]+)") do
                        cur = cur .. part .. "/"
                        if not isfolder(cur) then makefolder(cur) end
                    end
                end
                local okw = pcall(writefile, filePath, src)
                if okw then saved = saved + 1; AgentTrackFileOp(filePath) end
            else
                table.insert(errors, sc:GetFullName() .. ": " .. tostring(serr))
            end
        end
        AgentLastDecompileDir = baseDir

        local msg = "已反编译 " .. resolvedPath .. " 下的所有脚本，共完成 " .. saved .. " 个"
        if #errors > 0 then
            msg = msg .. "，" .. #errors .. " 个失败"
        end
        msg = msg .. "。\n保存路径：" .. baseDir
        return msg

    
    else
        return resolvedPath .. " 既不是脚本，其下方也没有找到任何脚本。无法反编译。"
    end
end

local function AgentExtractContext(text, keyword)
    local s, e = tostring(text or ""):find(keyword, 1, true)
    if not s then return nil end
    local after = tostring(text):sub(e + 1)
    return AgentTrim(after)
end
local function AgentDecompileAll(input)
    local lowerInput = string.lower(input or "")
    local function ensureDir()
        if not isfolder("DeltaUI") then makefolder("DeltaUI") end
        if not isfolder("DeltaUI/Agent") then makefolder("DeltaUI/Agent") end
        local od = AgentGetOutputDir()
        if not isfolder(od) then makefolder(od) end
    end
    local function saveScript(script, baseDir, rootName)
        if not script:IsA("LuaSourceContainer") then return false, "不是脚本" end
        if not decompile then return false, "当前环境不支持反编译" end
        local source, err = AgentTryDecompile(script)
        if not source then return false, err end
        AgentTrackToolCall()
        local fullName = script:GetFullName()
        local relativePath = fullName:gsub("^game%.", "")
        local rootPrefix = rootName .. "."
        if relativePath:sub(1, #rootPrefix) == rootPrefix then
            relativePath = relativePath:sub(#rootPrefix + 1)
        end
        if rootName == "Players" then
            relativePath = relativePath:gsub("^LocalPlayer%.", "")
        end
        local segs = {}
        for seg in relativePath:gmatch("[^%.]+") do
            table.insert(segs, AgentSafeSegment(seg))
        end
        local outFolder = rootName == "Players" and "PlayerScripts" or rootName
        local safeOut = AgentSafeSegment(outFolder)
        local joined = table.concat(segs, "/")
        local filePath = baseDir .. "/" .. safeOut .. "/" .. joined .. ".lua"
        if #filePath > 200 then
            local cut = 200 - #(baseDir .. "/" .. safeOut .. "/")
            filePath = baseDir .. "/" .. safeOut .. "/" .. joined:sub(1, math.max(10, cut)) .. ".lua"
        end

        local dirParts = {}
        for part in filePath:gmatch("([^/]+)") do table.insert(dirParts, part) end
        table.remove(dirParts, #dirParts)
        local cur = ""
        for _, part in ipairs(dirParts) do
            cur = cur .. part .. "/"
            local okDir = pcall(function()
                if not isfolder(cur) then makefolder(cur) end
            end)
            if not okDir then return false, "目录创建失败: " .. tostring(cur) end
        end
        local okw, errw = pcall(writefile, filePath, source)
        if not okw then return false, tostring(errw) end
        AgentTrackFileOp(filePath)
        return true, filePath
    end
    local function decompileContainer(container, rootName, baseDir, cap)
        if not container then return 0, {}, 0 end
        local scripts = AgentGetAllScripts(container)
        local saved = 0
        local errors = {}
        local maxN = tonumber(cap) or math.huge
        local throttle = tonumber(AgentLocalAIConfig.decompileAllThrottle) or 0.05
        for i, sc in ipairs(scripts) do
            if i > maxN then break end
            if i > 1 then task.wait(throttle) end
            local ok, res = saveScript(sc, baseDir, rootName)
            if ok then saved = saved + 1 else table.insert(errors, sc:GetFullName() .. ": " .. res) end
            task.wait()
        end
        return saved, errors, #scripts
    end

    if lowerInput:find("所有脚本") or lowerInput:find("全部脚本") then
        ensureDir()
        local placeId = game.PlaceId or 0
        local baseDir = AgentGetOutputDir() .. "/反编译_" .. placeId .. "_" .. os.time()
        if not isfolder(baseDir) then makefolder(baseDir) end
        AgentLastDecompileDir = baseDir
        local totalSaved = 0
        local allErrors = {}
        local results = {}
        local globalCap = tonumber(AgentLocalAIConfig.decompileAllMaxScripts) or 600
        local remaining = globalCap
        local playerScripts = v7:FindFirstChild("PlayerScripts")
        if playerScripts then
            local count, errs = decompileContainer(playerScripts, "Players", baseDir, remaining)
            remaining = remaining - count
            totalSaved = totalSaved + count
            for _, e in ipairs(errs) do table.insert(allErrors, e) end
            table.insert(results, "PlayerScripts: " .. count .. " 个脚本")
        else
            table.insert(results, "PlayerScripts: 未找到")
        end
        local repStorage = game:GetService("ReplicatedStorage")
        local count2, errs2 = decompileContainer(repStorage, "ReplicatedStorage", baseDir, remaining)
        remaining = remaining - count2
        totalSaved = totalSaved + count2
        for _, e in ipairs(errs2) do table.insert(allErrors, e) end
        table.insert(results, "ReplicatedStorage: " .. count2 .. " 个脚本")
        local msg = "反编译完成！共保存 " .. totalSaved .. " 个脚本\n路径: " .. baseDir
        for _, r in ipairs(results) do msg = msg .. "\n" .. r end
        if #allErrors > 0 then msg = msg .. "\n有 " .. #allErrors .. " 个脚本保存失败" end
        if totalSaved >= globalCap then
            msg = msg .. "\n（已到达单次批量上限 " .. globalCap .. " 个，可再次输入以继续处理剩余脚本）"
        end
        msg = msg .. "\n\n你可以输入「列出 " .. baseDir .. "」查看已保存的脚本，或输入「反编译 路径」反编译某个具体容器。"
        return msg
    end
    local tokens = {"反编译所有", "全部反编译", "整个解出来"}
    local path = nil
    for _, kw in ipairs(tokens) do
        local ex = AgentExtractContext(input, kw)
        if ex and ex ~= "" then path = ex break end
    end
    if not path then path = AgentChatMemory.lastPath end
    if not path or path == "" then return "要反编译哪个目录下的所有脚本？说清楚。" end
    local container, err = AgentGetInstanceFromPath(path)
    if not container then return "找不到这个容器：" .. (err or "") end
    ensureDir()
    local placeId = game.PlaceId or 0
    local folderName = path:match("([^%.]+)$") or "Unknown"
    local baseDir = AgentGetOutputDir() .. "/反编译_" .. placeId .. "_" .. os.time() .. "/" .. folderName
    if not isfolder(baseDir) then makefolder(baseDir) end
    AgentLastDecompileDir = baseDir
    local scripts = AgentGetAllScripts(container)
    if #scripts == 0 then return path .. " 下面没找到任何脚本" end
    local saved = 0
    local errors = {}
    local throttle = tonumber(AgentLocalAIConfig.decompileAllThrottle) or 0.05
    for i, sc in ipairs(scripts) do
        if i > 1 then task.wait(throttle) end
        local ok, res = saveScript(sc, baseDir, folderName)
        if ok then saved = saved + 1 else table.insert(errors, sc:GetFullName() .. ": " .. res) end
        task.wait()
    end
    local msg = "搞定了！存了 " .. saved .. " 个脚本到 " .. baseDir
    if #errors > 0 then msg = msg .. "\n有几个没存上：" .. table.concat(errors, string.char(10)) end
    msg = msg .. "\n\n你可以输入「列出 " .. baseDir .. "」查看已保存的脚本，或继续输入「反编译 路径」反编译其他容器。"
    return msg
end







local function AgentDecompileModules(targetStr)
    local decompileFn = getgenv and getgenv().decompile or decompile
    if not decompileFn then
        return "当前环境不支持反编译（decompile 函数缺失）"
    end
    
    local function safeDecompile(obj)
        if not obj then return nil end
        local okDesc = pcall(function() return obj:IsDescendantOf(game) end)
        if not okDesc or not obj:IsDescendantOf(game) then return nil end
        local ok, res = pcall(decompileFn, obj)
        return ok and res or nil
    end

    
    local function collectModules(root)
        local mods = {}
        local stack = {root}
        while #stack > 0 do
            local obj = stack[#stack]
            stack[#stack] = nil
            if obj then
                local children = obj:GetChildren()
                for i = #children, 1, -1 do
                    local child = children[i]
                    if child:IsA("ModuleScript") then table.insert(mods, child) end
                    stack[#stack + 1] = child
                end
            end
        end
        return mods
    end

    
    local function ensureDir()
        if not isfolder("DeltaUI") then makefolder("DeltaUI") end
        if not isfolder("DeltaUI/Agent") then makefolder("DeltaUI/Agent") end
        local od = AgentGetOutputDir()
        if not isfolder(od) then makefolder(od) end
        return od
    end

    
    local function saveModule(mod, baseDir, rootName)
        if not mod:IsA("ModuleScript") then return false, "不是 ModuleScript" end
        local source = safeDecompile(mod)
        if not source then return false, "反编译失败" end
        AgentTrackToolCall()
        local fullName = mod:GetFullName()
        local relativePath = fullName:gsub("^game%.", "")
        if rootName then
            local rootPrefix = rootName .. "."
            if relativePath:sub(1, #rootPrefix) == rootPrefix then
                relativePath = relativePath:sub(#rootPrefix + 1)
            end
        end
        if rootName == "Players" then
            relativePath = relativePath:gsub("^LocalPlayer%.", "")
        end
        local segs = {}
        for seg in relativePath:gmatch("[^%.]+") do
            table.insert(segs, AgentSafeSegment(seg))
        end
        local safeOut = AgentSafeSegment(rootName == "Players" and "PlayerScripts" or (rootName or mod.Name))
        local joined = table.concat(segs, "/")
        local filePath = baseDir .. "/" .. safeOut .. "/" .. joined .. ".lua"
        if #filePath > 200 then
            local cut = 200 - #(baseDir .. "/" .. safeOut .. "/")
            filePath = baseDir .. "/" .. safeOut .. "/" .. joined:sub(1, math.max(10, cut)) .. ".lua"
        end
        local dirParts = {}
        for part in filePath:gmatch("([^/]+)") do table.insert(dirParts, part) end
        table.remove(dirParts, #dirParts)
        local cur = ""
        for _, part in ipairs(dirParts) do
            cur = cur .. part .. "/"
            local okDir = pcall(function()
                if not isfolder(cur) then makefolder(cur) end
            end)
            if not okDir then return false, "目录创建失败: " .. tostring(cur) end
        end
        local okw, errw = pcall(writefile, filePath, source)
        if not okw then return false, tostring(errw) end
        AgentTrackFileOp(filePath)
        return true, filePath
    end

    
    local function decompileBatch(mods, baseDir, rootName, throttle)
        local saved = 0
        local errors = {}
        local delay = tonumber(throttle)
        if not delay or delay < 0 then delay = 0.05 end
        for i, mod in ipairs(mods) do
            if i > 1 then task.wait(delay) end
            local ok, res = saveModule(mod, baseDir, rootName)
            if ok then saved = saved + 1 else table.insert(errors, mod:GetFullName() .. ": " .. tostring(res)) end
            task.wait()
        end
        return saved, errors
    end

    
    if targetStr and tostring(targetStr):gsub("%s", "") ~= "" then
        local obj, err = AgentResolveDecompileTarget(tostring(targetStr))
        if not obj then
            obj, err = AgentGetInstanceFromPath(tostring(targetStr))
        end
        if not obj then
            return "找不到目标：" .. tostring(err or "未知错误") .. "。请提供 ModuleScript 路径，例如「反编译模块 game.ReplicatedStorage.Module」"
        end
        local od = ensureDir()
        local placeId = game.PlaceId or 0
        local baseDir = od .. "/模块反编译_" .. placeId .. "_" .. os.time()
        if not isfolder(baseDir) then makefolder(baseDir) end
        AgentLastDecompileDir = baseDir

        if obj:IsA("ModuleScript") then
            local source = safeDecompile(obj)
            if not source then return "反编译失败：" .. obj:GetFullName() end
            AgentTrackToolCall()
            local savedPath = nil
            if writefile and makefolder and isfolder then
                local okSave, saveOk, savePath = pcall(saveModule, obj, baseDir, nil)
                if okSave and saveOk then savedPath = savePath end
            end
            local msg = "已反编译 ModuleScript " .. obj:GetFullName() .. "，源码共 " .. #source .. " 字节。"
            if savedPath then msg = msg .. "已保存到：" .. tostring(savedPath) end
            return msg
        end

        
        local mods = collectModules(obj)
        if #mods == 0 then return obj:GetFullName() .. " 下方没有找到任何 ModuleScript" end
        local saved, errors = decompileBatch(mods, baseDir, obj.Name, AgentLocalAIConfig.decompileAllThrottle)
        local msg = "已反编译 " .. obj:GetFullName() .. " 下的所有 ModuleScript，共 " .. #mods .. " 个，成功 " .. saved .. " 个。"
        if #errors > 0 then
            msg = msg .. "\n失败：" .. table.concat(errors, string.char(10))
        end
        msg = msg .. "\n保存路径：" .. baseDir
        return msg
    end

    
    local od = ensureDir()
    local placeId = game.PlaceId or 0
    local baseDir = od .. "/模块反编译_" .. placeId .. "_" .. os.time()
    if not isfolder(baseDir) then makefolder(baseDir) end
    AgentLastDecompileDir = baseDir

    local throttle = AgentLocalAIConfig.decompileAllThrottle
    local totalSaved = 0
    local allErrors = {}
    local results = {}
    local globalCap = tonumber(AgentLocalAIConfig.decompileAllMaxScripts) or 600
    local remaining = globalCap

    
    local scanList = {}
    local lp = v7
    local ps = lp and lp:FindFirstChild("PlayerScripts")
    if ps then scanList[#scanList + 1] = {name = "PlayerScripts", container = ps} end
    scanList[#scanList + 1] = {name = "ReplicatedStorage", container = game:GetService("ReplicatedStorage")}
    scanList[#scanList + 1] = {name = "ReplicatedFirst", container = game:GetService("ReplicatedFirst")}

    for _, entry in ipairs(scanList) do
        local mods = collectModules(entry.container)
        if remaining > 0 and #mods > remaining then
            for i = #mods, remaining + 1, -1 do mods[i] = nil end
        end
        local count, errs = decompileBatch(mods, baseDir, entry.name, throttle)
        remaining = remaining - count
        totalSaved = totalSaved + count
        for _, e in ipairs(errs) do table.insert(allErrors, e) end
        table.insert(results, entry.name .. ": " .. count .. " 个 ModuleScript")
    end

    
    local cache = getgenv and getgenv().SavedScripts
    if remaining > 0 and type(cache) == "table" then
        local cachedMods = {}
        for _, s in ipairs(cache) do
            local isMod = pcall(function() return s and s:IsA("ModuleScript") end)
            if isMod then cachedMods[#cachedMods + 1] = s end
            if #cachedMods >= remaining then break end
        end
        local count, errs = decompileBatch(cachedMods, baseDir, "SavedScripts", throttle)
        totalSaved = totalSaved + count
        remaining = remaining - count
        for _, e in ipairs(errs) do table.insert(allErrors, e) end
        table.insert(results, "SavedScripts: " .. count .. " 个 ModuleScript")
    end

    local msg = "ModuleScript 反编译完成！共保存 " .. totalSaved .. " 个模块\n路径: " .. baseDir
    for _, r in ipairs(results) do msg = msg .. "\n" .. r end
    if #allErrors > 0 then msg = msg .. "\n有 " .. #allErrors .. " 个模块保存失败" end
    if totalSaved >= globalCap then
        msg = msg .. "\n（已到达单次批量上限 " .. globalCap .. " 个，可再次输入以继续处理剩余模块）"
    end
    print("Finish decompile all ModuleScript")
    return msg
end

local function AgentCountOutputFiles()
    local dir = AgentGetOutputDir()
    if not isfolder(dir) then return 0 end
    local count = 0
    local function rec(p)
        for _, f in ipairs(listfiles(p) or {}) do
            if isfile(f) then count = count + 1
            elseif isfolder(f) then rec(f) end
        end
    end
    rec(dir)
    return count
end

local function AgentDeleteRecentFiles()
    local deleted = 0
    local deletedDirs = {}
    if #AgentRecentSavedFiles > 0 then
        for _, fp in ipairs(AgentRecentSavedFiles) do
            if isfile and isfile(fp) then
                local ok = pcall(delfile, fp)
                if ok then deleted = deleted + 1 end
            end
        end
    end
    if AgentLastDecompileDir and isfolder and isfolder(AgentLastDecompileDir) then
        local dirDeleted = 0
        local function recDir(p)
            for _, it in ipairs(listfiles(p) or {}) do
                if isfile(it) then
                    if pcall(delfile, it) then dirDeleted = dirDeleted + 1 end
                elseif isfolder(it) then
                    recDir(it)
                    pcall(delfolder, it)
                end
            end
        end
        recDir(AgentLastDecompileDir)
        pcall(delfolder, AgentLastDecompileDir)
        deleted = deleted + dirDeleted
        table.insert(deletedDirs, AgentLastDecompileDir)
    end
    if deleted == 0 then
        local dir = AgentGetOutputDir()
        if isfolder and isfolder(dir) then
            local function rec(p)
                for _, it in ipairs(listfiles(p) or {}) do
                    if isfile(it) then
                        if pcall(delfile, it) then deleted = deleted + 1 end
                    elseif isfolder(it) then
                        rec(it)
                        pcall(delfolder, it)
                    end
                end
            end
            rec(dir)
        end
    end

    AgentClearSavedFilesTracking()

    if deleted == 0 then
        return false, "没有找到可删除的文件。可能反编译时未成功保存文件。"
    end
    return true, deleted
end


AgentLocalAIConfig = { -- [官方页面] 提为全局：原文件部分引用早于 local 声明
    enabled = true,
    endpoint = "https://api.deepseek.com/chat/completions",
    model = "",

    activeModel = "flash",
    
    isClaude = false,
    
    apiKey = "",
    timeout = 30,
    thinkingDisabled = true,
    noThinking = false,
    bypassPoints = false,
    temperature = 0.72,
    maxTokens = 4096,
    maxToolIterations = 200,
    executeTimeout = 15,
    maxFailuresBeforeFallback = 2,
    maxContextMessages = 6,
    maxMemoryRecords = 3,
    maxPromptChars = 8000,
    maxHistoryMessages = 20,
    decompileAllThrottle = 0.05,   
    decompileAllMaxScripts = 600,
}


-- 配置读写辅助（必须定义在所有调用它的函数之前，否则会被解析为全局变量而为 nil）
local function AgentReadCfg()
    local ok, c = pcall(loadConfig)
    if ok and type(c) == "table" then return c end
    return {}
end
local function AgentWriteCfg(k, v)
    local c = AgentReadCfg()
    c[k] = v
    pcall(saveConfig, c)
end

local AGENT_PROVIDERS = {
    flash = {
        label = "DeepSeek",
        endpoint = "https://api.deepseek.com/chat/completions",
        apiKey = "",
        isClaude = false,
    },
    claude = {
        label = "Anthropic",
        endpoint = "https://api.anthropic.com/v1/messages",
        apiKey = "",
        isClaude = true,
    },
    aiagent = {
        label = "Agnes",
        endpoint = "https://api.agnes-ai.cn/v1/chat/completions",
        apiKey = "",
        isClaude = false,
        noThinking = true,
        bypassPoints = false,
    },
    -- ===== 国内主流 AI 预设（填 API Key 即可用，OpenAI 兼容） =====
    -- 注意：以下预设不内置任何模型名，模型列表由对应服务商 API 拉取后手动选择
    qwen = {
        label = "阿里通义千问",
        endpoint = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",
        apiKey = "",
        isClaude = false,
    },
    glm = {
        label = "智谱 GLM",
        endpoint = "https://open.bigmodel.cn/api/paas/v4/chat/completions",
        apiKey = "",
        isClaude = false,
    },
    kimi = {
        label = "月之暗面 Kimi",
        endpoint = "https://api.moonshot.cn/v1/chat/completions",
        apiKey = "",
        isClaude = false,
    },
    minimax = {
        label = "MiniMax",
        endpoint = "https://api.minimax.chat/v1/chat/completions",
        apiKey = "",
        isClaude = false,
    },
    baichuan = {
        label = "百川智能",
        endpoint = "https://api.baichuan-ai.com/v1/chat/completions",
        apiKey = "",
        isClaude = false,
    },
    doubao = {
        label = "火山方舟 豆包",
        endpoint = "https://ark.cn-beijing.volces.com/api/v3/chat/completions",
        apiKey = "",
        isClaude = false,
    },
    hunyuan = {
        label = "腾讯混元",
        endpoint = "https://api.hunyuan.cloud.tencent.com/v1/chat/completions",
        apiKey = "",
        isClaude = false,
    },
}

-- ===== 思考级别能力表（依据各服务商官方 API 文档整理的「思考 / 推理」能力）=====
-- switchable = false 表示当前模型不支持「思考级别切换」，界面将显示「当前模型不支持该操作」
-- style 决定请求体中如何注入级别参数：qwen/hunyuan 用 thinking_budget，其余用 OpenAI 风格 reasoning_effort
-- 注：以下均为全局，避免主函数局部变量超过 Lua 5.1 的 200 上限
AgentUI = { objects = {}, presetFrame = nil, presetStatus = nil, presetArea = nil, thinkFrame = nil, currentPresetId = nil }
AGENT_THINKING_CAPS = {
    flash   = {switchable = false},
    claude  = {switchable = false},
    aiagent = {switchable = false},
    qwen    = {switchable = true, levels = {"低", "中", "高"}, style = "qwen"},
    glm     = {switchable = false},
    kimi    = {switchable = false},
    minimax = {switchable = false},
    baichuan= {switchable = false},
    doubao  = {switchable = true, levels = {"低", "中", "高"}, style = "reasoning_effort"},
    hunyuan = {switchable = true, levels = {"低", "中", "高"}, style = "hunyuan"},
    custom  = {switchable = true, levels = {"低", "中", "高"}, style = "reasoning_effort"},
    _params = {
        budget = {["低"] = 2048, ["中"] = 4096, ["高"] = 8192},
        effort = {["低"] = "low", ["中"] = "medium", ["高"] = "high"},
    },
}

-- 从 chat/completions（或 messages）端点推导出 API 基址（用于拼接 /models）
function AgentBaseFromEndpoint(endpoint)
    endpoint = tostring(endpoint or ""):gsub("%s+", "")
    endpoint = endpoint:gsub("/+$", "")
    endpoint = endpoint:gsub("/chat/completions$", ""):gsub("/chat/completions", "")
    endpoint = endpoint:gsub("/messages$", "")
    return endpoint
end

-- 持久化某预设服务商拉取到的模型列表
function AgentPersistPresetModels(id, list)
    if type(list) ~= "table" then return end
    local cfg = AgentReadCfg()
    cfg.providerModels = cfg.providerModels or {}
    cfg.providerModels[tostring(id)] = list
    pcall(saveConfig, cfg)
end

-- 选中预设服务商下的某个具体模型
function AgentApplyPresetModel(id, model)
    pcall(AgentApplyModel, id)
    if not model then return true end
    AgentLocalAIConfig.model = model
    local cfg = AgentReadCfg()
    cfg.providerSelectedModel = cfg.providerSelectedModel or {}
    cfg.providerSelectedModel[tostring(id)] = model
    cfg.activeModel = id
    pcall(saveConfig, cfg)
    pcall(function()
        if AgentModelLabel then
            local m = AGENT_PROVIDERS[id] or {}
            AgentModelLabel.Text = (m.label or id)
            AgentModelLabel.TextColor3 = (m.isClaude == true) and Color3.fromRGB(255, 200, 60) or (theme.textDim or Color3.fromRGB(150, 160, 184))
        end
    end)
    return true
end

-- 拉取某预设服务商的模型列表
function AgentFetchPresetModels(id)
    local m = AGENT_PROVIDERS[id]
    if not m then return end
    local base = AgentBaseFromEndpoint(m.endpoint)
    local key = m.apiKey or ""
    pcall(function()
        if AgentUI.presetStatus then
            AgentUI.presetStatus.Text = "正在拉取 " .. AgentProviderLabel(id) .. " 模型列表..."
            AgentUI.presetStatus.TextColor3 = theme.textDim or Color3.fromRGB(150, 160, 184)
        end
    end)
    local okF, a, b = pcall(AgentFetchModels, base, key)
    if not okF then
        pcall(function() if AgentUI.presetStatus then AgentUI.presetStatus.Text = "拉取异常: " .. tostring(a); AgentUI.presetStatus.TextColor3 = theme.red or Color3.fromRGB(255, 82, 104) end end)
        return
    end
    if a == false then
        pcall(function() if AgentUI.presetStatus then AgentUI.presetStatus.Text = "拉取失败: " .. tostring(b); AgentUI.presetStatus.TextColor3 = theme.red or Color3.fromRGB(255, 82, 104) end end)
        return
    end
    local models = b
    if type(models) ~= "table" or #models == 0 then
        pcall(function() if AgentUI.presetStatus then AgentUI.presetStatus.Text = "未获取到模型"; AgentUI.presetStatus.TextColor3 = theme.red or Color3.fromRGB(255, 82, 104) end end)
        return
    end
    -- 尚无选中模型时，以拉取到的第一个模型作为默认（来源是 API，非内置）
    local cfg = AgentReadCfg()
    local savedSel = (cfg.providerSelectedModel and type(cfg.providerSelectedModel[tostring(id)]) == "string") and cfg.providerSelectedModel[tostring(id)] or ""
    if savedSel == "" and models[1] then
        savedSel = tostring(models[1])
        cfg.providerSelectedModel = cfg.providerSelectedModel or {}
        cfg.providerSelectedModel[tostring(id)] = savedSel
        pcall(saveConfig, cfg)
        AgentLocalAIConfig.model = savedSel
    end
    AgentPersistPresetModels(id, models)
    if AgentUI.currentPresetId == id then AgentRenderPresetModelList(id, models) end
    pcall(function() if AgentUI.presetStatus then AgentUI.presetStatus.Text = "已拉取 " .. tostring(#models) .. " 个模型，点击选择"; AgentUI.presetStatus.TextColor3 = theme.accent or Color3.fromRGB(56, 189, 248) end end)
end

-- 把模型列表渲染到共享面板
function AgentRenderPresetModelList(id, list)
    if not AgentUI.presetFrame then return end
    pcall(function()
        for _, c in ipairs(AgentUI.presetFrame:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
        end
        if AgentUI.presetArea then AgentUI.presetArea.Visible = true end
        local cfg = AgentReadCfg()
        local sel = (cfg.providerSelectedModel and type(cfg.providerSelectedModel[tostring(id)]) == "string" and cfg.providerSelectedModel[tostring(id)]) or ""
        for _, mid in ipairs(list) do
            local active = (mid == sel)
            local mb = create("TextButton", {
                Name = "PM_" .. tostring(mid),
                Size = UDim2.new(1, 0, 0, 26),
                BackgroundColor3 = active and (theme.accent or Color3.fromRGB(56, 189, 248)) or (theme.surface or Color3.fromRGB(22, 27, 40)),
                BackgroundTransparency = active and 0 or 0.3,
                BorderSizePixel = 0,
                Text = tostring(mid),
                TextColor3 = active and Color3.fromRGB(255, 255, 255) or (theme.text or Color3.fromRGB(242, 245, 252)),
                Font = Enum.Font.SourceSans,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = AgentUI.presetFrame,
            })
            corner(6, mb)
            create("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = mb })
            mb.MouseButton1Click:Connect(function()
                pcall(function()
                    local okA, ca = pcall(AgentApplyPresetModel, id, mid)
                    if okA and ca ~= false then
                        pcall(function() if AgentUI.presetStatus then AgentUI.presetStatus.Text = "已应用：" .. tostring(mid); AgentUI.presetStatus.TextColor3 = theme.accent or Color3.fromRGB(56, 189, 248) end end)
                        AgentRefreshPresetModels(id)
                        AgentRefreshThinkingControl()
                    end
                end)
            end)
        end
    end)
end

-- 刷新共享预设模型面板（优先缓存；无缓存且有 Key 时自动拉取）
function AgentRefreshPresetModels(id)
    AgentUI.currentPresetId = id
    if not AgentUI.presetFrame then return end
    pcall(function()
        for _, c in ipairs(AgentUI.presetFrame:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end
        end
        local cfg = AgentReadCfg()
        local cached = (cfg.providerModels and type(cfg.providerModels[tostring(id)]) == "table") and cfg.providerModels[tostring(id)] or nil
        local m = AGENT_PROVIDERS[id]
        if cached and #cached > 0 then
            AgentRenderPresetModelList(id, cached)
            pcall(function() if AgentUI.presetStatus then AgentUI.presetStatus.Text = "已加载 " .. tostring(#cached) .. " 个模型（来自缓存）"; AgentUI.presetStatus.TextColor3 = theme.textDim or Color3.fromRGB(150, 160, 184) end end)
            if AgentUI.presetArea then AgentUI.presetArea.Visible = true end
        else
            -- 未拉取到模型列表：隐藏整个模型列表区域
            if AgentUI.presetArea then AgentUI.presetArea.Visible = false end
            pcall(function() if AgentUI.presetStatus then AgentUI.presetStatus.Text = "" end end)
            if m and m.apiKey and m.apiKey ~= "" then
                if type(task) == "table" and type(task.spawn) == "function" then
                    task.spawn(AgentFetchPresetModels, id)
                else
                    pcall(AgentFetchPresetModels, id)
                end
            end
        end
    end)
end

-- 读取当前模型的思考级别能力（自定义模型会从官方 API 读取到的能力覆盖）
function AgentGetThinkingCaps(id)
    id = tostring(id or AgentLocalAIConfig.activeModel or "flash")
    local caps = AGENT_THINKING_CAPS[id] or AGENT_THINKING_CAPS.flash
    if id == "custom" then
        local saved = AgentReadCfg()
        if saved and type(saved.customThinkingSwitchable) == "boolean" then
            caps = { switchable = saved.customThinkingSwitchable, levels = AGENT_THINKING_CAPS.custom.levels, style = AGENT_THINKING_CAPS.custom.style }
        end
    end
    return caps
end

-- 从官方 API 返回的原始模型对象推断其是否支持思考级别切换
function AgentDetectCustomThinking(modelId, obj)
    local switchable = true
    if type(obj) == "table" then
        if type(obj.capabilities) == "table" then
            local hasReasoning = false
            for _, c in ipairs(obj.capabilities) do
                if tostring(c):lower():find("reason") then hasReasoning = true end
            end
            if #obj.capabilities > 0 and not hasReasoning then switchable = false end
        end
    end
    return switchable
end

-- 按当前模型能力与所选级别，把思考参数注入请求体
function AgentInjectThinkingLevel(body)
    if type(body) ~= "table" then return end
    local cfg = AgentReadCfg()
    local lvl = cfg.thinkingLevel
    local caps = AgentGetThinkingCaps(AgentLocalAIConfig.activeModel)
    if not (caps and caps.switchable) then return end
    if type(lvl) ~= "string" then return end
    local thinkingOn = (AgentLocalAIConfig.thinkingDisabled == false) or (cfg.thinkingMode == true)
    if not thinkingOn then return end
    if caps.style == "qwen" or caps.style == "hunyuan" then
        body.enable_thinking = true
        body.thinking_budget = AGENT_THINKING_CAPS._params.budget[lvl] or 4096
    else
        body.reasoning_effort = AGENT_THINKING_CAPS._params.effort[lvl] or "medium"
    end
end

-- 刷新「思考级别」控件（不支持时显示「当前模型不支持该操作」）
function AgentRefreshThinkingControl()
    if not AgentUI.thinkFrame then return end
    pcall(function()
        for _, c in ipairs(AgentUI.thinkFrame:GetChildren()) do c:Destroy() end
        local id = AgentLocalAIConfig.activeModel or "flash"
        local caps = AgentGetThinkingCaps(id)
        create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            Text = "当前模型：" .. AgentProviderLabel(id) .. " · " .. tostring(AgentLocalAIConfig.model or ""),
            TextColor3 = theme.textDim or Color3.fromRGB(150, 160, 184),
            Font = Enum.Font.SourceSans,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = AgentUI.thinkFrame,
        })
        if not (caps and caps.switchable) then
            create("TextLabel", {
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundTransparency = 1,
                Text = "当前模型不支持该操作",
                TextColor3 = theme.red or Color3.fromRGB(255, 82, 104),
                Font = Enum.Font.SourceSansBold,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = AgentUI.thinkFrame,
            })
            return
        end
        local row = create("Frame", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            Parent = AgentUI.thinkFrame,
        })
        create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = row })
        local levels = caps.levels or {"低", "中", "高"}
        local cur = AgentReadCfg().thinkingLevel
        for _, lv in ipairs(levels) do
            local active = (cur == lv)
            local b = create("TextButton", {
                Size = UDim2.new(0, 60, 0, 26),
                BackgroundColor3 = active and (theme.accent or Color3.fromRGB(56, 189, 248)) or (theme.surfaceLight or Color3.fromRGB(30, 36, 52)),
                BackgroundTransparency = active and 0 or 0.3,
                BorderSizePixel = 0,
                Text = tostring(lv),
                TextColor3 = active and Color3.fromRGB(255, 255, 255) or (theme.text or Color3.fromRGB(242, 245, 252)),
                Font = Enum.Font.SourceSans,
                TextSize = 12,
                Parent = row,
            })
            corner(8, b)
            b.MouseButton1Click:Connect(function()
                pcall(function()
                    AgentWriteCfg("thinkingLevel", lv)
                    AgentApplyThinkPill(true)
                    local setter = _G.__DeltaAI_setThinkingMode
                    if type(setter) == "function" then pcall(setter, true) end
                    AgentRefreshThinkingControl()
                    if type(ShowNotification) == "function" then ShowNotification("思考级别：" .. lv, 1.0) end
                end)
            end)
        end
    end)
end

function AgentApplyModel(id)
    local m = AGENT_PROVIDERS[id] or AGENT_PROVIDERS.flash
    -- 不内置模型名：model 交由 API 拉取后手动选择；仅在已保存过选择时恢复
    local cfg = AgentReadCfg()
    local savedSel = (cfg.providerSelectedModel and type(cfg.providerSelectedModel[tostring(id)]) == "string") and cfg.providerSelectedModel[tostring(id)] or ""
    AgentLocalAIConfig.model = savedSel
    AgentLocalAIConfig.endpoint = m.endpoint
    AgentLocalAIConfig.apiKey = m.apiKey

    AgentLocalAIConfig.isClaude = (id == "claude") or (m.isClaude == true)
    AgentLocalAIConfig.noThinking = (m.noThinking == true)
    AgentLocalAIConfig.bypassPoints = (m.bypassPoints == true)
    AgentLocalAIConfig.activeModel = id
    if AgentModelLabel then
        pcall(function()
            AgentModelLabel.Text = m.label

            AgentModelLabel.TextColor3 = m.isClaude and Color3.fromRGB(255, 200, 60) or theme.textDim
        end)
    end
end

local _aiModelSaved = loadConfig()
if _aiModelSaved and _aiModelSaved.activeModel and AGENT_PROVIDERS[_aiModelSaved.activeModel] then
    AgentApplyModel(_aiModelSaved.activeModel)
    -- 恢复该服务商此前手动选中的具体模型（来自 API 列表，非内置）
    local selMap = _aiModelSaved.providerSelectedModel
    if type(selMap) == "table" and type(selMap[_aiModelSaved.activeModel]) == "string" then
        AgentLocalAIConfig.model = selMap[_aiModelSaved.activeModel]
    end
end

local AgentLocalAIState = {
    available = false,
    lastError = nil,
    lastLatency = 0,
    failures = 0,
    mode = "api",            
    lastToolCalls = 0,       
    lastReasoning = nil,     
}



math.randomseed(os.time())


_G.__DeltaAI_setThinkingMode = function(enabled)
    AgentLocalAIConfig.thinkingDisabled = not enabled
end

local _aiSavedCfg = loadConfig()
if _aiSavedCfg and _aiSavedCfg.thinkingMode then
    AgentLocalAIConfig.thinkingDisabled = false
end
_G.__DeltaAI_AgentConfig = AgentLocalAIConfig





LOCAL_MODEL = {
    fileName = "DeltaUI_Local.lua",
    dir = "DeltaUI/Model",
    remoteUrl = "https://gitee.com/WasKKalWe/return/raw/master/DeltaUI_Local.lua",
    remoteVersion = "1.1",
    displayName = "Neuromorphic Cognitive AI",
}
_remoteModelSizeBytes = nil  

function fetchRemoteModelSize(cb)
    if type(cb) ~= "function" then return end
    if _remoteModelSizeBytes then cb(_remoteModelSizeBytes); return end
    task.spawn(function()
        local size = nil
        local ok, content = pcall(function()
            return game:HttpGet(LOCAL_MODEL.remoteUrl)
        end)
        if ok and content then size = #content end
        if size then _remoteModelSizeBytes = size end
        cb(size)
    end)
end
function localModelPath()
    return LOCAL_MODEL.dir .. "/" .. LOCAL_MODEL.fileName
end

B85_CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&()*+-;<=>?@^_`{|}~"
B85_VALS = {}
for _bi = 1, #B85_CHARS do B85_VALS[B85_CHARS:sub(_bi, _bi)] = _bi - 1 end
function base85Encode(data)
    data = tostring(data or "")
    local out = {}
    local n = #data
    local i = 1
    while i <= n do
        local chunk = math.min(4, n - i + 1)
        local val = 0
        for k = 0, 3 do
            val = val * 256
            if i + k <= n then val = val + data:byte(i + k) end
        end
        
        local d = {}
        for k = 5, 1, -1 do
            d[k] = (val % 85) + 1
            val = math.floor(val / 85)
        end
        local count = (chunk == 4) and 5 or (chunk + 1)
        for k = 1, count do out[#out + 1] = B85_CHARS:sub(d[k], d[k]) end
        i = i + 4
    end
    return table.concat(out)
end
function base85Decode(s)
    s = tostring(s or "")
    local out = {}
    local n = #s
    local i = 1
    while i <= n do
        local count = math.min(5, n - i + 1)
        local val = 0
        for k = 0, count - 1 do
            val = val * 85
            local v = B85_VALS[s:sub(i + k, i + k)]
            if not v then return nil end
            val = val + v
        end
        
        for k = count, 4 do
            val = val * 85 + 84
        end
        local bytes = count - 1
        
        for k = 1, bytes do
            local shift = 8 * (4 - k)
            out[#out + 1] = string.char(math.floor(val / (2 ^ shift)) % 256)
        end
        i = i + 5
    end
    return table.concat(out)
end
_localModelInstance = nil
_localModelLoadState = nil  
_localModelLoadError = nil  

function localModelLoad()
    if _localModelLoadState == true and _localModelInstance then return true end
    _localModelLoadState = false
    _localModelLoadError = nil
    local p = localModelPath()
    if not (isfile and readfile and isfile(p)) then
        _localModelLoadError = "模型文件不存在"
        return false
    end
    local okR, raw = pcall(function() return readfile(p) end)
    if not okR then
        _localModelLoadError = "读取文件失败"
        return false
    end
    local okD, content = pcall(function() return base85Decode(raw) end)
    if not okD or not content or #content < 5000 then
        _localModelLoadError = "Base85 解码失败或内容为空"
        return false
    end
    local fn, lerr = loadstring(content)
    if not fn then
        _localModelLoadError = "loadstring 失败: " .. tostring(lerr)
        return false
    end
    local okA, API = pcall(fn)
    if not okA or type(API) ~= "table" or type(API.default) ~= "function" then
        _localModelLoadError = "模型模块无效: " .. tostring(okA and "结构不符合预期" or API)
        return false
    end
    local okI, inst = pcall(API.default)
    if not okI or not inst then
        _localModelLoadError = "模型初始化失败: " .. tostring(okI and "返回了空实例" or inst)
        return false
    end
    _localModelInstance = inst
    _localModelLoadState = true
    return true
end

function localModelInstalled()
    return localModelLoad() == true
end

function parseLocalModelInfo()
    if not (isfile and readfile) or not isfile(localModelPath()) then return nil end
    local raw = readfile(localModelPath())
    local content = base85Decode(raw) or raw
    local info = {
        name = content:match('name%s*=%s*"([^"]+)"') or LOCAL_MODEL.displayName,
        version = content:match('version%s*=%s*"([^"]+)"') or "?",
    }
    local bytes = content:match('sizeBytes%s*=%s*(%d+)')
    info.sizeBytes = tonumber(bytes) or #content
    info.sizeMB = string.format("%.2f", info.sizeBytes / 1048576)
    return info
end
function localModelNeedsUpdate()
    local info = parseLocalModelInfo()
    if not info then return true end
    return tostring(info.version) ~= tostring(LOCAL_MODEL.remoteVersion)
end
function getHttpRequest()
    return (syn and syn.request) or (http and http.request) or http_request or request
end

function downloadLocalModel(onProgress, onDone)
    local req = getHttpRequest()
    task.spawn(function()
        local content, total = nil, nil
        local function readResp(resp)
            if resp and resp.Body and #tostring(resp.Body) > 0 then
                content = resp.Body
                total = tonumber(resp.Headers and resp.Headers["Content-Length"]) or #content
                return true
            end
            return false
        end
        if req then
            
            local opts = { Url = LOCAL_MODEL.remoteUrl, Method = "GET" }
            if type(onProgress) == "function" then opts.onProgress = onProgress end
            local okReq, resp = pcall(function() return req(opts) end)
            if not (okReq and readResp(resp)) then
                
                local ok2, resp2 = pcall(function() return req({ Url = LOCAL_MODEL.remoteUrl, Method = "GET" }) end)
                if ok2 then readResp(resp2) end
            end
        end
        
        if not content then
            local ok3, c = pcall(function() return game:HttpGet(LOCAL_MODEL.remoteUrl) end)
            if ok3 and c then content = c; total = #c end
        end
        if not content or #content < 5000 then
            if onDone then onDone(false, "下载失败，请检查网络后重试") end
            return
        end
        if type(onProgress) == "function" then
            pcall(onProgress, #content, total or #content)
        end
        local okW = pcall(function()
            if not isfolder(LOCAL_MODEL.dir) then makefolder(LOCAL_MODEL.dir) end
            writefile(localModelPath(), base85Encode(content))
        end)
        _localModelInstance = nil
        _localModelLoadState = nil
        if not okW then
            if onDone then onDone(false, "写入失败，请检查文件权限") end
            return
        end
        
        if localModelLoad() then
            if onDone then onDone(true, "") end
        else
            local errMsg = "模型已下载但无法加载：" .. tostring(_localModelLoadError or "未知错误")
            pcall(function() warn("[DeltaUI] " .. errMsg) end)
            if onDone then onDone(false, errMsg) end
        end
    end)
end

function localModelChat(input)
    if not localModelLoad() then return nil end
    local ok2, reply = pcall(function()
        return _localModelInstance:Chat(input, { max = 14 })
    end)
    if not ok2 then return nil end
    local s = tostring(reply or "")
    s = (s:gsub("^%s+", "")):gsub("%s+$", "")
    
    s = s:gsub("[ \t]+", "")
    return s
end

function showLocalModelCard(kind)
    if _G.__DeltaUI_modelCardShown then return end
    _G.__DeltaUI_modelCardShown = true
    local installed = parseLocalModelInfo()
    local curVer = installed and installed.version or "未安装"
    local isInstall = (kind == "install")
    
    local curSize = installed and installed.sizeMB or "计算中..."

    local dialog = create("ScreenGui", {
        Name = "LocalModelDialog",
        Parent = svc.CoreGui,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false,
        DisplayOrder = 1000001,
        IgnoreGuiInset = true,
    })
    local panel = create("Frame", {
        Name = "LocalModelPanel",
        Size = UDim2.new(0, 380, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(28, 32, 40),
        BorderSizePixel = 0,
        Parent = dialog,
        ZIndex = 100,
    })
    corner(14, panel)
    stroke(Color3.fromRGB(50, 55, 70), 1, panel)

    local function addLine(text, y, color, size, bold)
        create("TextLabel", {
            Size = UDim2.new(1, -32, 0, 20),
            Position = UDim2.new(0, 16, 0, y),
            BackgroundTransparency = 1,
            Text = text,
            TextColor3 = color or Color3.fromRGB(200, 205, 220),
            TextSize = size or 12,
            Font = bold and Enum.Font.SourceSansBold or Enum.Font.SourceSans,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            Parent = panel,
            ZIndex = 101,
        })
    end

    addLine(isInstall and "需要安装模型" or "模型有新版本", 12, Color3.fromRGB(230, 232, 240), 16, true)
    local y = 42
    addLine("模型：" .. tostring(installed and installed.name or LOCAL_MODEL.displayName), y, nil, 11)
    y = y + 20
    addLine("当前版本：" .. tostring(curVer) .. "    最新版本：" .. tostring(LOCAL_MODEL.remoteVersion), y, nil, 11)
    y = y + 20
    local sizeLabel = create("TextLabel", {
        Size = UDim2.new(1, -32, 0, 20),
        Position = UDim2.new(0, 16, 0, y),
        BackgroundTransparency = 1,
        Text = "模型大小：约 " .. tostring(curSize) .. " MB",
        TextColor3 = Color3.fromRGB(200, 205, 220),
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = panel,
        ZIndex = 101,
    })
    
    if not installed then
        fetchRemoteModelSize(function(sz)
            if sz then
                sizeLabel.Text = "模型大小：约 " .. string.format("%.2f", sz / 1048576) .. " MB"
            end
        end)
    end
    y = y + 20
    addLine(isInstall
        and "在开启外部API模式前,你只能安装模型来进行对话"
        or "检测到新版本模型，建议更新以获得更好效果。", y, Color3.fromRGB(140, 150, 170), 10)
    y = y + 20

    local btnY = y + 2
    
    local status = create("TextLabel", {
        Size = UDim2.new(1, -32, 0, 18),
        Position = UDim2.new(0, 16, 0, btnY),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = Color3.fromRGB(255, 200, 120),
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = panel,
        ZIndex = 102,
    })

    local function close()
        pcall(function() dialog:Destroy() end)
        _G.__DeltaUI_modelCardShown = false
    end

    local btnH = 38
    local btnY2 = btnY + 20
    
    local cancelBtn = create("TextButton", {
        Size = UDim2.new(0.5, -15, 0, btnH),
        Position = UDim2.new(0, 10, 0, btnY2),
        BackgroundColor3 = Color3.fromRGB(60, 65, 80),
        Text = "取消",
        TextColor3 = Color3.fromRGB(200, 200, 210),
        Font = Enum.Font.SourceSansBold,
        TextSize = 13,
        BorderSizePixel = 0,
        Parent = panel,
        ZIndex = 102,
    })
    corner(8, cancelBtn)
    cancelBtn.MouseButton1Click:Connect(close)

    
    local installBtn = create("TextButton", {
        Size = UDim2.new(0.5, -15, 0, btnH),
        Position = UDim2.new(0.5, 5, 0, btnY2),
        BackgroundColor3 = Color3.fromRGB(59, 130, 246),
        Text = "",
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = panel,
        ZIndex = 102,
    })
    corner(8, installBtn)
    local installFill = create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(57, 214, 146),
        BorderSizePixel = 0,
        ZIndex = 1,
        Parent = installBtn,
    })
    corner(8, installFill)
    local installText = create("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = isInstall and "安装" or "更新",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.SourceSansBold,
        TextSize = 13,
        ZIndex = 2,
        Parent = installBtn,
    })

    local downloading = false
    local realProgress = false
    installBtn.MouseButton1Click:Connect(function()
        if downloading then return end
        downloading = true
        installBtn.Active = false
        installText.TextColor3 = Color3.fromRGB(220, 220, 230)
        
        svc.TweenService:Create(installBtn, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = Color3.fromRGB(90, 95, 110) }):Play()
        status.TextColor3 = Color3.fromRGB(255, 200, 120)
        status.TextTransparency = 0
        installFill.Size = UDim2.new(0, 0, 1, 0)
        realProgress = false

        
        local totalBytes = _remoteModelSizeBytes
        local gotTotal = totalBytes ~= nil
        if not gotTotal then
            fetchRemoteModelSize(function(sz)
                if sz then totalBytes = sz; gotTotal = true end
            end)
        end
        local totalKB = totalBytes and math.max(1, math.floor(totalBytes / 1024)) or 0

        
        local function onProgress(done, total)
            realProgress = true
            local t = tonumber(total) or totalBytes or 0
            local d = tonumber(done) or 0
            local frac = (t and t > 0) and math.min(1, d / t) or 0
            installFill.Size = UDim2.new(frac, 0, 1, 0)
            local curKB = math.max(0, math.floor(d / 1024))
            local tk = math.max(1, math.floor((t or 0) / 1024))
            status.Text = string.format("%dkb / %dkb", curKB, tk)
        end

        
        local animStart = tick()
        local fallbackConn = svc.RunService.Heartbeat:Connect(function()
            if not downloading then return end
            if realProgress then return end
            local frac = math.min(1, (tick() - animStart) / 3.0) * 0.95
            installFill.Size = UDim2.new(frac, 0, 1, 0)
            if totalKB > 0 then
                local curKB = math.max(0, math.floor(totalKB * frac))
                status.Text = string.format("%dkb / %dkb", curKB, totalKB)
            else
                status.Text = string.format("%d%%", math.floor(frac * 100))
            end
        end)

        downloadLocalModel(onProgress, function(success, msg)
            downloading = false
            if fallbackConn then pcall(function() fallbackConn:Disconnect() end) end
            if success then
                installFill.Size = UDim2.new(1, 0, 1, 0)
                if totalKB > 0 then
                    status.Text = string.format("%dkb / %dkb", totalKB, totalKB)
                else
                    status.Text = "100%"
                end
                
                svc.TweenService:Create(status, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 1 }):Play()
                task.delay(0.25, function()
                    status.TextTransparency = 0
                    status.Text = "完成!"
                    status.TextColor3 = Color3.fromRGB(120, 230, 150)
                end)
                
                task.delay(0.7, function()
                    for _, elem in ipairs(panel:GetDescendants()) do
                        if elem:IsA("GuiObject") then
                            svc.TweenService:Create(elem, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
                        end
                        if elem:IsA("TextLabel") or elem:IsA("TextButton") then
                            svc.TweenService:Create(elem, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 1 }):Play()
                        end
                    end
                    svc.TweenService:Create(panel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
                    task.delay(0.45, close)
                end)
            else
                status.TextTransparency = 0
                status.Text = msg or "安装失败"
                status.TextColor3 = Color3.fromRGB(255, 120, 120)
                installFill.Size = UDim2.new(0, 0, 1, 0)
                installBtn.Active = true
                installBtn.BackgroundColor3 = Color3.fromRGB(59, 130, 246)
                installText.TextColor3 = Color3.fromRGB(255, 255, 255)
                downloading = false
            end
        end)
    end)

    panel.Size = UDim2.new(0, 380, 0, btnY2 + btnH + 18)
end


local AgentLastUsage = nil

local AgentTotalTokens = 0


function AgentSafeString(v, maxLen)
    local s = tostring(v or "")
    if maxLen and #s > maxLen then s = s:sub(1, maxLen) .. "…" end
    return s
end

local function AgentNormalizeAIText(v)
    return tostring(v or ""):lower():gsub("%s+", ""):gsub(
        "[，。！？、,.!?：:；;“”\"'‘’（）()%[%]{}<>《》]", ""
    )
end




local function AgentGetRecentContext(maxCount)
    local result = {}
    local history = AgentChatMemory and AgentChatMemory.conversationHistory or {}
    local n = tonumber(maxCount) or 12
    local start = math.max(1, #history - n + 1)
    for i = start, #history do
        local m = history[i]
        if type(m) == "table" then
            local content = AgentSafeString(m.content or m.text or "", 900)
            if content ~= "" then
                result[#result + 1] = {
                    role = m.role == "assistant" and "assistant" or "user",
                    content = content
                }
            end
        end
    end
    return result
end


local function AgentBuildSystemPrompt()
    return table.concat({
        "# AgentLess",
        "你是 DeltaUI 的 Roblox 智能助手，运行在 Luau 环境。",
        "",
        "## 工具",
        "- 实例：list_children / list_properties / get_property / find_objects / search_objects",
        "- 脚本与文件：decompile / decompile_smart / decompile_all / decompile_modules / read_file / edit_file / del_file",
        "- 执行与交互：execute_lua / GotRemote / go_to / click_gui / noclip / anti_fling / report_progress",
        "",
        "## 规则",
        "1. 用户指令优先，直接给结果，简洁、不啰嗦、不编造；不确定就直说。",
        "2. 需要动 Roblox 时才调工具：先定位(list_children/find_objects/decompile)，再操作(execute_lua/go_to/click_gui)，能一次多调就多调；关键信息缺失只追问一次。",
        "3. 普通问答直接回答，不要为聊天调工具。",
        "4. 文件操作统一走 read_file / edit_file / del_file：改文件前先 read_file 看清行号，再用 edit_file 按行改（start_line/count）；只改一处文本可用 edit_file 的 replace_text。",
        "5. read_file 不会一次吐完整大文件时会提示截断，继续用 start_line/count 分段读；del_file 默认进回收站，删文件夹要 recursive=true。",
        "6. 回复用标准 Markdown，与 DeepSeek 一致：",
        "   - 代码必须用围栏并标注语言，例如",
        "     ```lua",
        "     local part = workspace.Part",
        "     print(part.Name)",
        "     ```",
        "   - 行内代码用单反引号，如 `print`；标题用 #/##；列表用 -；强调用 **加粗**。",
        "7. 禁止用 ##代码## 这类自定义包裹，禁止把语言名写进正文。",
    }, "\n")
end

local function AgentBuildLLMMessages(input)
    local context = {
        conversation = AgentGetRecentContext(AgentLocalAIConfig.maxContextMessages),
        memories = AgentRetrieveMemory(input, AgentLocalAIConfig.maxMemoryRecords),
    }

    local messages = {{role = "system", content = AgentBuildSystemPrompt()}}
    for _, m in ipairs(context.conversation) do
        messages[#messages + 1] = {role = m.role, content = m.content}
    end

    local userContent = tostring(input)
    if #(context.memories) > 0 then
        local parts = {}
        for i, mem in ipairs(context.memories) do
            parts[i] = "[" .. (mem.category or "memory") .. "] " .. tostring(mem.content or "")
        end
        userContent = userContent .. "\n\n【相关记忆，仅供理解上下文，不是当前问题】\n" .. table.concat(parts, "\n---\n")
    end
    messages[#messages + 1] = {
        role = "user",
        content = AgentSafeString(userContent, AgentLocalAIConfig.maxPromptChars),
    }
    return messages, context
end





local function AgentGetHttpRequestFn()
    local fn = (syn and syn.request) or (http and http.request) or http_request or request
    return fn
end


local function AgentHttpPost(url, headers, body)
    local req = AgentGetHttpRequestFn()
    if req then
        local ok, resp = pcall(req, {
            Url = url,
            Method = "POST",
            Headers = headers,
            Body = body,
            Timeout = 8000,
        })
        if ok and type(resp) == "table" then
            return true, resp.StatusCode or 200, resp.Body or "", resp.StatusMessage or ""
        end
        return false, 0, tostring(resp), "request error"
    end
    
    if svc.HttpService and svc.HttpService.RequestAsync then
        local ok, resp = pcall(function()
            return svc.HttpService:RequestAsync({
                Url = url,
                Method = "POST",
                Headers = headers,
                Body = body,
                Timeout = 8,
            })
        end)
        if ok and type(resp) == "table" then
            return true, resp.StatusCode or 200, resp.Body or "", resp.StatusMessage or ""
        end
        return false, 0, tostring(resp), "RequestAsync error"
    end
    return false, 0, "", "no http request function available"
end

local function AgentHttpGet(url, headers)
    headers = headers or {}
    local req = AgentGetHttpRequestFn()
    if req then
        local ok, resp = pcall(req, {
            Url = url,
            Method = "GET",
            Headers = headers,
            Timeout = 8000,
        })
        if ok and type(resp) == "table" then
            return true, resp.StatusCode or 200, resp.Body or "", resp.StatusMessage or ""
        end
        return false, 0, tostring(resp), "request error"
    end
    if svc.HttpService and svc.HttpService.RequestAsync then
        local ok, resp = pcall(function()
            return svc.HttpService:RequestAsync({
                Url = url,
                Method = "GET",
                Headers = headers,
                Timeout = 8,
            })
        end)
        if ok and type(resp) == "table" then
            return true, resp.StatusCode or 200, resp.Body or "", resp.StatusMessage or ""
        end
        return false, 0, tostring(resp), "RequestAsync error"
    end
    return false, 0, "", "no http request function available"
end

local function AgentResolveUrl(base, suffix)
    base = tostring(base or ""):gsub("%s+", "")
    if base == "" then return "" end
    base = base:gsub("/+$", "")
    suffix = tostring(suffix or ""):gsub("^/+", "")
    if suffix == "" then return base end
    return base .. "/" .. suffix
end

local function AgentFetchModels(baseUrl, apiKey)
    baseUrl = AgentSafeString(tostring(baseUrl or ""), 400)
    if baseUrl == "" then
        return false, "请先填写 BaseURL"
    end
    local headers = { ["Content-Type"] = "application/json" }
    if apiKey and tostring(apiKey) ~= "" then
        headers["Authorization"] = "Bearer " .. tostring(apiKey)
    end
    local okM, codeM, bodyM = AgentHttpGet(AgentResolveUrl(baseUrl, "/models"), headers)
    if not okM then
        return false, "网络请求失败: " .. tostring(bodyM)
    end
    if codeM < 200 or codeM >= 300 then
        return false, "拉取模型失败 (HTTP " .. tostring(codeM) .. "): " .. AgentSafeString(bodyM, 220)
    end
    local dec
    local dOk = pcall(function() dec = svc.HttpService:JSONDecode(bodyM) end)
    if not dOk or type(dec) ~= "table" then
        return false, "返回数据解析失败"
    end
    local list = {}
    AgentUI.objects[baseUrl] = AgentUI.objects[baseUrl] or {}
    local objMap = AgentUI.objects[baseUrl]
    local function ingest(t)
        if type(t) ~= "table" then return end
        for _, it in ipairs(t) do
            if type(it) == "table" and type(it.id) == "string" and it.id ~= "" then
                list[#list + 1] = it.id
                objMap[it.id] = it
            elseif type(it) == "string" and it ~= "" then
                list[#list + 1] = it
            end
        end
    end
    if type(dec.data) == "table" then
        ingest(dec.data)
    elseif type(dec.models) == "table" then
        ingest(dec.models)
    elseif type(dec) == "table" then
        ingest(dec)
    end
    if #list == 0 then
        return false, "未获取到任何模型（该服务商可能不支持 /models 列表接口）"
    end
    return true, list
end

local function AgentProviderLabel(id)
    if id == "custom" then return "自定义服务商" end
    local m = AGENT_PROVIDERS[id]
    return (m and m.label) or tostring(id or "")
end

local function AgentPersistProviderKey(id, key)
    if type(loadConfig) ~= "function" or type(saveConfig) ~= "function" then return end
    pcall(function()
        local cfg = loadConfig()
        cfg.providerKeys = cfg.providerKeys or {}
        cfg.providerKeys[tostring(id)] = tostring(key or "")
        saveConfig(cfg)
    end)
end

function AgentApplyCustomProvider(baseUrl, apiKey, model)
    baseUrl = AgentSafeString(tostring(baseUrl or ""), 400)
    apiKey = tostring(apiKey or "")
    model = AgentSafeString(tostring(model or ""), 200)
    if baseUrl == "" or model == "" then
        return false, "BaseURL 与模型均不能为空"
    end
    local endpoint = AgentResolveUrl(baseUrl, "/chat/completions")
    AgentLocalAIConfig.endpoint = endpoint
    AgentLocalAIConfig.model = model
    AgentLocalAIConfig.apiKey = apiKey
    AgentLocalAIConfig.isClaude = false
    AgentLocalAIConfig.noThinking = false
    AgentLocalAIConfig.bypassPoints = false
    AgentLocalAIConfig.activeModel = "custom"
    if type(loadConfig) == "function" and type(saveConfig) == "function" then
        pcall(function()
            local cfg = loadConfig()
            cfg.activeModel = "custom"
            cfg.customBaseUrl = baseUrl
            cfg.customApiKey = apiKey
            cfg.customActiveModel = model
            saveConfig(cfg)
        end)
    end
    pcall(function()
        if AgentModelLabel then
            AgentModelLabel.Text = AgentProviderLabel("custom")
            AgentModelLabel.TextColor3 = theme.textDim or Color3.fromRGB(150, 160, 184)
        end
    end)
    -- 从官方 API 返回的原始模型对象推断该自定义模型是否支持思考级别切换
    pcall(function()
        local obj = (AgentUI.objects[baseUrl] and AgentUI.objects[baseUrl][model]) or nil
        local sw = AgentDetectCustomThinking(model, obj)
        local cfg = AgentReadCfg()
        cfg.customThinkingSwitchable = sw
        pcall(saveConfig, cfg)
    end)
    return true
end

do
    local okS, saved = pcall(loadConfig)
    if okS and type(saved) == "table" then
        if type(saved.providerKeys) == "table" then
            for k, v in pairs(saved.providerKeys) do
                if AGENT_PROVIDERS[k] then
                    AGENT_PROVIDERS[k].apiKey = tostring(v)
                end
            end
        end
        if saved.activeModel == "custom" and saved.customBaseUrl and saved.customActiveModel then
            pcall(AgentApplyCustomProvider, saved.customBaseUrl, saved.customApiKey, saved.customActiveModel)
        end
    end
end

local AGENT_DEEPSEEK_TOOLS = {
    {type="function", ["function"]={name="list_children", description="列子对象", parameters={type="object", properties={path={type="string"}, depth={type="number"}}, required={"path"}}}},
    {type="function", ["function"]={name="decompile", description="反编译脚本", parameters={type="object", properties={path={type="string"}}, required={"path"}}}},
    {type="function", ["function"]={name="decompile_smart", description="智能反编译", parameters={type="object", properties={target={type="string"}}, required={"target"}}}},
    {type="function", ["function"]={name="decompile_all", description="反编译全部脚本", parameters={type="object"}}},
    {type="function", ["function"]={name="decompile_modules", description="反编译 ModuleScript（目标可选）：省略 target 时批量反编译 Players/ReplicatedStorage/ReplicatedFirst 及 getgenv().SavedScripts 缓存中的所有 ModuleScript；指定 target 时反编译该 ModuleScript 或该容器下的所有 ModuleScript。为性能会在每个模块之间加入延迟。", parameters={type="object", properties={target={type="string", description="要反编译的 ModuleScript 路径或容器路径，可省略"}}}}},
    {type="function", ["function"]={name="get_property", description="读属性", parameters={type="object", properties={path={type="string"}, property={type="string"}}, required={"path","property"}}}},
    {type="function", ["function"]={name="list_properties", description="列属性", parameters={type="object", properties={path={type="string"}}, required={"path"}}}},
    {type="function", ["function"]={name="execute_lua", description="执行Lua(需用户授权)", parameters={type="object", properties={code={type="string"}}, required={"code"}}}},
    {type="function", ["function"]={name="find_objects", description="全局找对象", parameters={type="object", properties={name={type="string"}}, required={"name"}}}},
    {type="function", ["function"]={name="search_objects", description="搜索对象", parameters={type="object", properties={name={type="string"}}, required={"name"}}}},
    {type="function", ["function"]={name="count_output_files", description="统计输出文件数", parameters={type="object"}}},
    {type="function", ["function"]={name="list_output_files", description="列出输出文件", parameters={type="object"}}},
    {type="function", ["function"]={name="delete_recent_files", description="删除最近文件", parameters={type="object"}}},
    {type="function", ["function"]={name="noclip", description="穿墙", parameters={type="object", properties={enabled={type="boolean"}}}}},
    {type="function", ["function"]={name="anti_fling", description="防甩飞", parameters={type="object", properties={enabled={type="boolean"}}}}},
    -- ===== 文件工具（read_file / edit_file / del_file）=====
    {type="function", ["function"]={name="read_file", description="读取文件内容。可整读，也可按行读：start_line 起始行(1起)，count 读多少行或 end_line 结束行（二选一，count 优先）。默认带行号返回，便于配合 edit_file 精确改行。", parameters={type="object", properties={path={type="string", description="文件路径，如 DeltaUI/Script/a.lua"}, start_line={type="number", description="起始行号，1 起，默认 1"}, count={type="number", description="读取行数；与 end_line 同时省略时读到文件末尾"}, end_line={type="number", description="结束行号(含)，与 count 二选一"}, number={type="boolean", description="是否带行号，默认 true"}, max_chars={type="number", description="单次返回字符上限，默认 12000"}}, required={"path"}}}},
    {type="function", ["function"]={name="edit_file", description="编辑文件（默认先备份为 .bak）。mode：create/overwrite 整文件写入；append/prepend 末尾追加/开头插入；insert 在第 start_line 行后插入 content；replace_range 用 content 替换第 start_line~end_line 行；replace_text 把 old 换成 new（count 次数，默认 1，0=全部）。省略 mode 时按参数自动判断。", parameters={type="object", properties={path={type="string", description="文件路径"}, mode={type="string", description="create|overwrite|append|prepend|insert|replace_range|replace_text"}, content={type="string", description="写入/替换/插入的文本"}, start_line={type="number", description="起始行号，1 起"}, end_line={type="number", description="结束行号(含)"}, count={type="number", description="replace_range 的行数，或 replace_text 的替换次数"}, old={type="string", description="replace_text：被替换的原文（纯文本，不是模式串）"}, new={type="string", description="replace_text：替换后的文本"}, backup={type="boolean", description="是否备份 .bak，默认 true"}}, required={"path"}}}},
    {type="function", ["function"]={name="del_file", description="删除文件（默认先存入回收站 DeltaUI/Trash，backup=false 可关闭）。删除文件夹必须传 recursive=true。", parameters={type="object", properties={path={type="string", description="文件或文件夹路径"}, recursive={type="boolean", description="删除文件夹时必须为 true"}, backup={type="boolean", description="是否存入回收站，默认 true"}}, required={"path"}}}},
    {type="function", ["function"]={name="report_progress", description="向用户汇报当前处理进度", parameters={type="object", properties={message={type="string", description="进度说明"}}, required={"message"}}}},
    {type="function", ["function"]={name="GotRemote", description="捕获FireServer/InvokeServer调用。进入等待交互后提示用户手动操作一次，AI自动捕获并生成Lua。忽略ping/fps等无用Remote。", parameters={type="object", properties={goal={type="string", description="目标操作说明，如'出售物品'/'领取奖励'"}, timeout={type="number", description="等待秒数，默认30，最大120"}}, required={"goal"}}}},

{type="function",["function"]={name="go_to",description="移动玩家到目标。策略：直接传送→平滑传送→慢速传送→步行。目标可用path、position{x,y,z}或x/y/z，三者互斥仅填其一。",parameters={type="object",properties={path={type="string",description="目标实例路径，如game.Workspace.SellPoint"},position={type="object",description="目标坐标{x,y,z}",properties={x={type="number"},y={type="number"},z={type="number"}}},x={type="number",description="x坐标，必须搭配y、z同时使用"},y={type="number",description="y坐标，必须搭配x、z同时使用"},z={type="number",description="z坐标，必须搭配x、y同时使用"}}}}},
    {type="function", ["function"]={name="click_gui", description="模拟点击GUI按钮。参数三选一：path(实例路径)、scaleX/scaleY(0-1相对坐标)、x/y(屏幕绝对像素)。", parameters={type="object", properties={path={type="string", description="GUI元素实例路径"}, scaleX={type="number", description="相对X(0-1)"}, scaleY={type="number", description="相对Y(0-1)"}, x={type="number", description="屏幕绝对X像素"}, y={type="number", description="屏幕绝对Y像素"}}}}},
    {type="function", ["function"]={name="ask_user", description="向用户提问并等待回复。当需要用户补充信息、确认关键决策或选择方向时调用。调用后交互会暂停，等待用户在界面中输入回复后再继续。", parameters={type="object", properties={question={type="string", description="要问用户的问题"}, options={type="array", description="可选：提供的选项（字符串数组）", items={type="string"}}}, required={"question"}}}},
    {type="function", ["function"]={name="work_plan", description="以 JSON 制定或更新任务计划与进度。请在 plan 中返回结构化任务列表，每项含 id/title/status/progress/description/subtasks。status: pending 待办 / in_progress 进行中 / done 已完成；progress: 0-100。", parameters={type="object", properties={plan={type="array", description="任务列表", items={type="object", properties={id={type="string", description="任务唯一 id"}, title={type="string", description="任务标题"}, status={type="string", description="pending 待办 / in_progress 进行中 / done 已完成"}, progress={type="number", description="进度 0-100"}, description={type="string", description="任务说明"}, subtasks={type="array", description="子任务（可选）", items={type="object", properties={title={type="string", description="子任务标题"}, done={type="boolean", description="是否完成"}}}}}}}}, required={"plan"}}}}

}

local function AgentSanitizeUTF8(s)
    s = tostring(s or "")
    local out = {}
    local i = 1
    local n = #s
    while i <= n do
        local b = s:byte(i)
        if b < 0x80 then
            out[#out + 1] = s:sub(i, i)
            i = i + 1
        elseif b >= 0xC2 and b <= 0xDF then
            local b2 = s:byte(i + 1)
            if b2 and b2 >= 0x80 and b2 <= 0xBF then
                out[#out + 1] = s:sub(i, i + 1)
                i = i + 2
            else
                out[#out + 1] = "\xEF\xBF\xBD"
                i = i + 1
            end
        elseif b >= 0xE0 and b <= 0xEF then
            local b2, b3 = s:byte(i + 1), s:byte(i + 2)
            if b2 and b3 and b2 >= 0x80 and b2 <= 0xBF and b3 >= 0x80 and b3 <= 0xBF then
                out[#out + 1] = s:sub(i, i + 2)
                i = i + 3
            else
                out[#out + 1] = "\xEF\xBF\xBD"
                i = i + 1
            end
        elseif b >= 0xF0 and b <= 0xF4 then
            local b2, b3, b4 = s:byte(i + 1), s:byte(i + 2), s:byte(i + 3)
            if b2 and b3 and b4
                and b2 >= 0x80 and b2 <= 0xBF
                and b3 >= 0x80 and b3 <= 0xBF
                and b4 >= 0x80 and b4 <= 0xBF then
                out[#out + 1] = s:sub(i, i + 3)
                i = i + 4
            else
                out[#out + 1] = "\xEF\xBF\xBD"
                i = i + 1
            end
        else
            out[#out + 1] = "\xEF\xBF\xBD"
            i = i + 1
        end
    end
    return table.concat(out)
end

local function AgentJSONEscape(s)
    s = AgentSanitizeUTF8(s)
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    s = s:gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
    s = s:gsub("\b", "\\b"):gsub("\f", "\\f")
    s = s:gsub("[%c]", function(c) return string.format("\\u%04x", c:byte()) end)
    return s
end

local function AgentJSONEncode(v)
    local t = type(v)
    if v == nil then return "null" end
    if t == "boolean" then return v and "true" or "false" end
    if t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return "null" end
        return tostring(v)
    end
    if t == "string" then return '"' .. AgentJSONEscape(v) .. '"' end
    if t == "table" then
        
        local isArray = true
        local count = 0
        for k in pairs(v) do
            count = count + 1
            if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
                isArray = false
            end
        end
        if isArray and count > 0 then
            for i = 1, count do
                if v[i] == nil then isArray = false break end
            end
        end
        if isArray and count > 0 then
            local parts = {}
            for i = 1, count do parts[i] = AgentJSONEncode(v[i]) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        
        local parts = {}
        for k, val in pairs(v) do
            parts[#parts + 1] = '"' .. AgentJSONEscape(k) .. '":' .. AgentJSONEncode(val)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null" 
end








local function AgentTokenizeDSML(content)
    local seq = {}
    
    local TAG = '<[/]?[%s|]*DSML[%s|]*(.-)>'
    local last = 1
    local pos = 1
    while true do
        local s, e, cmd = content:find(TAG, pos)
        if not s then break end
        local between = content:sub(last, s - 1)
        if between ~= "" then seq[#seq + 1] = between end
        if cmd and cmd ~= "" then seq[#seq + 1] = cmd end
        last = e + 1
        pos = e + 1
    end
    local tail = content:sub(last)
    if tail ~= "" then seq[#seq + 1] = tail end
    return seq
end

local function AgentParseDSMLToolCalls(content)
    if type(content) ~= "string" then return nil end
    local calls = {}
    local currentCall = nil   
    local paramName = nil     
    local paramVal = nil      
    local inCalls = false     

    local seq = AgentTokenizeDSML(content)
    for _, raw in ipairs(seq) do
        local tok = raw:gsub('^%s+', ''):gsub('%s+$', '')
        if tok ~= '' then
            if tok == 'tool_calls' then
                
                if inCalls then
                    inCalls = false
                    currentCall, paramName, paramVal = nil, nil, nil
                else
                    inCalls = true
                end
            elseif tok:match('^/+tool_calls') then
                
                inCalls = false
                currentCall, paramName, paramVal = nil, nil, nil
            elseif inCalls then
                local invokeName = tok:match('^invoke%s+name="([^"]+)"')
                if invokeName then
                    currentCall = { id = 'dsml_' .. tostring(#calls + 1), name = invokeName, args = {} }
                    calls[#calls + 1] = currentCall
                    paramName, paramVal = nil, nil
                else
                    local pname = tok:match('^parameter%s+name="([^"]+)"')
                    if pname then
                        paramName, paramVal = pname, nil
                    elseif tok == 'invoke' or tok:match('^/+invoke') then
                        
                        currentCall, paramName, paramVal = nil, nil, nil
                    elseif tok == 'parameter' or tok:match('^/+parameter') then
                        
                        if currentCall and paramName then
                            currentCall.args[paramName] = paramVal or ''
                        end
                        paramName, paramVal = nil, nil
                    elseif currentCall and paramName then
                        
                        paramVal = (paramVal and (paramVal .. tok)) or tok
                    end
                end
            end
        end
    end
    if #calls > 0 then return calls end

    
    
    
    
    local invokes = {}
    local ipos = 1
    while true do
        local s, e, invName = content:find('invoke%s+name="([^"]+)"', ipos)
        if not s then break end
        invokes[#invokes + 1] = { s = s, e = e, name = invName }
        ipos = e + 1
    end
    if #invokes == 0 then return nil end
    local lcalls = {}
    for i, inv in ipairs(invokes) do
        local segStart = inv.e + 1
        local segEnd = (i < #invokes) and (invokes[i + 1].s - 1) or #content
        local seg = content:sub(segStart, segEnd)
        local call = { id = 'dsml_' .. tostring(i), name = inv.name, args = {} }
        local ppos = 1
        while true do
            local ps, pe, pname = seg:find('parameter%s+name="([^"]+)"', ppos)
            if not ps then break end
            local gt = seg:find('>', pe)
            local lt = gt and seg:find('<', gt + 1)
            local val = ""
            if gt then
                val = seg:sub(gt + 1, lt and (lt - 1) or -1)
            end
            val = val:gsub('^%s+', ''):gsub('%s+$', '')
            
            local mstart = val:find('<[%s|/]*DSML', 1)
            if mstart then val = val:sub(1, mstart - 1) end
            if pname and pname ~= '' then call.args[pname] = val end
            ppos = pe + 1
        end
        lcalls[#lcalls + 1] = call
    end
    if #lcalls == 0 then return nil end
    return lcalls
end


local function AgentStripDSML(content)
    if type(content) ~= "string" then return content end
    local s = content
    
    local OT = '<[%s|/]*DSML[%s|/]*/?[%s|/]*tool_calls[%s|/]*>'
    s = s:gsub(OT .. '.-' .. OT, '')
    
    local OA = '<[%s|]*DSML[%s|]*>[%s]*tool_calls'
    local CA = '<[%s|]*DSML[%s|]*>[%s]*/[%s]*tool_calls[%s]*<[%s|]*DSML[%s|]*>'
    s = s:gsub(OA .. '.-' .. CA, '')
    
    s = s:gsub('<[/]?[%s|]*DSML[%s|]*[^>]*>', '')
    
    s = s:gsub('[%s]*/[%s]*tool_calls', '')
    s = s:gsub('[%s]*tool_calls', '')
    s = s:gsub('[%s]*/[%s]*invoke', '')
    s = s:gsub('[%s]*invoke%s+name="[^"]*"', '')
    s = s:gsub('[%s]*/[%s]*parameter', '')
    s = s:gsub('[%s]*parameter%s+name="[^"]*"[^\n]*', '')
    return s
end



local function AgentDeepSeekChat(messages, tools, opts)
    opts = opts or {}
    local isClaude = AgentLocalAIConfig.isClaude
    local body
    if isClaude then
        
        local sys = ""
        local msgs = {}
        for _, m in ipairs(messages) do
            local role = m.role
            if role == "system" then
                local c = m.content
                if type(c) == "table" then
                    local parts = {}
                    for _, part in ipairs(c) do if type(part) == "table" and part.text then table.insert(parts, part.text) end end
                    c = table.concat(parts, "\n")
                end
                sys = sys .. tostring(c or "") .. "\n"
            elseif role == "user" or role == "assistant" then
                local c = m.content
                if type(c) == "table" then
                    local parts = {}
                    for _, part in ipairs(c) do if type(part) == "table" and part.text then table.insert(parts, part.text) end end
                    c = table.concat(parts, "\n")
                end
                table.insert(msgs, {role = role, content = tostring(c or "")})
            end
        end
        body = {
            model = AgentLocalAIConfig.model,
            max_tokens = opts.maxTokens or AgentLocalAIConfig.maxTokens or 4096,
            messages = msgs,
        }
        if sys ~= "" then body.system = sys end
        if tools and #tools > 0 then
            local ctools = {}
            for _, t in ipairs(tools) do
                local fn = (type(t) == "table" and type(t["function"]) == "table") and t["function"] or t
                ctools[#ctools + 1] = {
                    name = tostring(fn.name or t.name or ""),
                    description = tostring(fn.description or ""),
                    input_schema = fn.parameters or { type = "object", properties = {} },
                }
            end
            body.tools = ctools
            body.tool_choice = { type = "auto" }
        end
        
        if not AgentLocalAIConfig.thinkingDisabled then
            body.thinking = { type = "enabled", budget_tokens = 1024 }
        end
    else
        body = {
            model = AgentLocalAIConfig.model,
            messages = messages,
            temperature = opts.temperature or AgentLocalAIConfig.temperature,
            stream = false,
        }
        
        if not AgentLocalAIConfig.noThinking and AgentLocalAIConfig.thinkingDisabled then
            body.thinking = {type = "disabled"}
        end
        local maxTok = opts.maxTokens or AgentLocalAIConfig.maxTokens
        if maxTok and maxTok > 0 then
            body.max_tokens = maxTok
        end
        if tools and #tools > 0 then
            body.tools = tools
            body.tool_choice = "auto"
        end
    end

    -- 注入思考级别参数（按当前模型能力判定是否支持）
    pcall(AgentInjectThinkingLevel, body)

    local okEnc, bodyJson = pcall(AgentJSONEncode, body)
    if not okEnc or type(bodyJson) ~= "string" or bodyJson == "" then
        return nil, nil, "JSON编码失败: " .. tostring(bodyJson)
    end

    
    local reqUrl = AgentLocalAIConfig.endpoint
    local reqHeaders
    if isClaude then
        reqHeaders = {
            ["Content-Type"] = "application/json",
            ["x-api-key"] = tostring(AgentLocalAIConfig.apiKey),
            ["anthropic-version"] = "2023-06-01",
        }
    else
        reqHeaders = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. tostring(AgentLocalAIConfig.apiKey),
        }
    end

    local ok, code, respBody, statusMsg = AgentHttpPost(
        reqUrl, reqHeaders, bodyJson
    )
    if not ok then
        return nil, nil, "网络请求失败: " .. tostring(respBody or statusMsg)
    end
    if code < 200 or code >= 300 then
        local errObj
        local eOk = pcall(function() errObj = svc.HttpService:JSONDecode(respBody) end)
        if eOk and type(errObj) == "table" and type(errObj.error) == "table" then
            if errObj.error.code == "insufficient_quota" or errObj.error.type == "insufficient_quota" then
                return nil, nil, "AI 服务额度不足，请联系管理员"
            end
        end
        local hint = statusMsg ~= "" and statusMsg or ("HTTP " .. tostring(code))
        if respBody and respBody ~= "" then
            hint = hint .. " " .. AgentSafeString(respBody, 300)
        end
        return nil, nil, hint
    end
    if not respBody or respBody == "" then
        return nil, nil, "空响应体"
    end

    local okDec, data = pcall(function()
        return svc.HttpService:JSONDecode(respBody)
    end)
    if not okDec or type(data) ~= "table" then
        return nil, nil, "响应解析失败: " .. AgentSafeString(respBody, 200)
    end

    

    
    if type(data.usage) == "table" then
        AgentLastUsage = data.usage
        if isClaude then
            AgentTotalTokens = AgentTotalTokens + (tonumber(data.usage.input_tokens) or 0) + (tonumber(data.usage.output_tokens) or 0)
        else
            AgentTotalTokens = AgentTotalTokens + (tonumber(data.usage.total_tokens) or 0)
        end
    end

    local content, toolCalls
    if isClaude then
        
        content = ""
        toolCalls = nil
        local reasoningBuf = ""
        for _, block in ipairs(data.content or {}) do
            if block.type == "text" then
                content = content .. tostring(block.text or "")
            elseif block.type == "thinking" then
                reasoningBuf = reasoningBuf .. tostring(block.thinking or "")
            elseif block.type == "tool_use" then
                toolCalls = toolCalls or {}
                toolCalls[#toolCalls + 1] = {
                    id = tostring(block.id or "call_" .. tostring(#toolCalls + 1)),
                    name = tostring(block.name or ""),
                    args = (type(block.input) == "table") and block.input or {},
                }
            end
        end
        if reasoningBuf ~= "" then
            AgentLocalAIState.lastReasoning = reasoningBuf
        else
            AgentLocalAIState.lastReasoning = nil
        end
        return content, toolCalls, nil
    end

    if not (data.choices and data.choices[1] and data.choices[1].message) then
        return nil, nil, "响应缺少 choices.message 字段"
    end

    local msg = data.choices[1].message
    content = tostring(msg.content or "")
    
    local reasoning = tostring(msg.reasoning_content or "")
    if reasoning ~= "" and reasoning ~= "nil" then
        AgentLocalAIState.lastReasoning = reasoning
    else
        AgentLocalAIState.lastReasoning = nil
    end
    toolCalls = nil

    if type(msg.tool_calls) == "table" and #msg.tool_calls > 0 then
        toolCalls = {}
        for _, tc in ipairs(msg.tool_calls) do
            local t = type(tc) == "table" and tc or {}
            local fn = type(t["function"]) == "table" and t["function"] or {}
            local args = {}
            if fn.arguments and fn.arguments ~= "" then
                local okA, parsedA = pcall(function()
                    return svc.HttpService:JSONDecode(fn.arguments)
                end)
                if okA and type(parsedA) == "table" then args = parsedA end
            end
            toolCalls[#toolCalls + 1] = {
                id = tostring(t.id or "call_" .. tostring(#toolCalls + 1)),
                name = tostring(fn.name or ""),
                args = args,
            }
        end
    elseif content:find("<[%s|]-DSML", 1) then
        
        local dsml = AgentParseDSMLToolCalls(content)
        if dsml then
            toolCalls = dsml
            content = AgentStripDSML(content)
        end
    end

    return content, toolCalls, nil
end


local function AgentSetSessionTitle(title)
    if not title or title == "" then return end
    AgentCurrentSession.sessionTitle = tostring(title)
    if AgentCurrentSession.sessionFile and isfile and listfiles then
        local dir = AgentCurrentSession.sessionDir
        local safeTitle = tostring(title):gsub("[/\\:*?\"<>|\r\n\t ]+", "_"):gsub("^_+", ""):gsub("_+$", "")
        if safeTitle == "" then safeTitle = "default" end
        if #safeTitle > 40 then safeTitle = safeTitle:sub(1, 40) end
        local newPath = dir .. "/" .. safeTitle .. ".chat"
        if newPath ~= AgentCurrentSession.sessionFile and isfile(newPath) then
            newPath = dir .. "/" .. safeTitle .. "_" .. os.time() .. ".chat"
        end
        if newPath ~= AgentCurrentSession.sessionFile then
            pcall(function()
                if isfile(AgentCurrentSession.sessionFile) then
                    local content = readfile(AgentCurrentSession.sessionFile)
                    if content then writefile(newPath, content) end
                    delfile(AgentCurrentSession.sessionFile)
                end
            end)
            AgentCurrentSession.sessionFile = newPath
            AgentCurrentSession.sessionKey = safeTitle
        end
    end
    AgentSaveChatHistory()
end


local function AgentListAllChats()
    AgentEnsureAgentFolders()
    local placeId = tostring(game.PlaceId or 0)
    local folder = "DeltaUI/Agent/Chat/对话_" .. placeId
    local list = {}
    if not isfolder(folder) or not listfiles then return list end
    local ok, files = pcall(listfiles, folder)
    if not ok or type(files) ~= "table" then return list end
    for _, path in ipairs(files) do
        if isfile(path) and path:match("%.chat$") then
            local data = AgentReadChatFile(path)
            local name = (path:match("([^/\\]+)$") or path):gsub("%.chat$", "")
            local title = (data and data.metadata and data.metadata.title) or name
            if title == "" or title == "null" then title = name end
            local t = (data and data.updatedAt) or (data and data.createdAt) or 0
            if tonumber(t) then t = tonumber(t) else t = 0 end
            list[#list + 1] = {
                path = folder,
                file = path,
                name = name,
                title = title,
                time = t,
                count = (data and type(data.messages) == "table" and #data.messages) or 0,
                model = (data and data.metadata and data.metadata.model) or nil,
                models = (data and data.metadata and type(data.metadata.models) == "table" and data.metadata.models) or nil,
            }
        end
    end
    table.sort(list, function(a, b)
        if a.time == b.time then return a.title > b.title end
        return a.time > b.time
    end)
    return list
end


local function AgentCallLLM(messages)
    local started = tick()
    if AgentMetrics.thinkingStartTime == 0 then
        AgentMetrics.thinkingStartTime = started
    end
    local input = ""
    if type(messages) == "table" then
        for i = #messages, 1, -1 do
            if messages[i].role == "user" then
                input = messages[i].content or ""
                break
            end
        end
    end

    local content, _, apiErr = AgentDeepSeekChat(messages, nil)
    local answer
    if content and content ~= "" then
        AgentLocalAIState.mode = "api"
        answer = content
    else
        warn("[DeltaUI][AI] API 不可用(" .. tostring(apiErr) .. ")")
        AgentLocalAIState.mode = "api"
        AgentLocalAIState.lastError = apiErr
        AgentLocalAIState.failures = (AgentLocalAIState.failures or 0) + 1
        answer = "抱歉，当前无法连接到 AI 服务（" .. tostring(apiErr) .. "）。请稍后重试。"
    end

    do 
        local forbidden = {"我结合了之前的对话上下文","我是 DeltaUI 内置智能助手","我分析了你的请求","我会继续推理","根据上下文判断","我是基于关键词","关键词匹配","关键词触发","关键词感知","我的意图识别系统","根据意图评分","根据语义特征权重","我的回复库","从回复模板"}
        for _, word in ipairs(forbidden) do answer = answer:gsub(word, "") end
        answer = answer:gsub("^%s+", ""):gsub("%s+$", "")
    end

    AgentLocalAIState.available = true
    AgentLocalAIState.lastLatency = math.max(0, tick() - started)
    return answer
end

local function AgentTryParseToolCall(text)
    if type(text) ~= "string" then return nil end
    local trimmed = text:gsub("^%s+", ""):gsub("%s+$", "")

    local candidates = {trimmed}
    local fence = trimmed:match("```%w*%s*\n(.-)\n%s*```")
    if fence then table.insert(candidates, fence) end
    local s = trimmed:find("{", 1, true)
    if s then
        for i = #trimmed, s, -1 do
            if trimmed:sub(i, i) == "}" then
                table.insert(candidates, trimmed:sub(s, i))
                break
            end
        end
    end

    for _, cand in ipairs(candidates) do
        local ok, decoded = pcall(function() return svc.HttpService:JSONDecode(cand) end)
        if ok and type(decoded) == "table" and type(decoded.tool) == "string" then
            return decoded.tool, type(decoded.args) == "table" and decoded.args or {}
        end
    end
    return nil
end

local function AgentShowConfirmDialog(code)
    local confirmed = false
    local done = false
    local dialog = create("ScreenGui", {
        Name = "ConfirmDialog",
        Parent = game:GetService("CoreGui"),
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        ResetOnSpawn = false,
        DisplayOrder = 1000000, 
        IgnoreGuiInset = true,
    })

    
    local panel = create("Frame", {
        Name = "ConfirmPanel",
        Size = UDim2.new(0, 360, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),   
        BackgroundColor3 = Color3.fromRGB(28, 32, 40),
        BorderSizePixel = 0,
        Parent = dialog,
        ZIndex = 100
    })
    corner(14, panel)
    stroke(Color3.fromRGB(50, 55, 70), 1, panel)
    create("TextLabel", {
        Size = UDim2.new(1, -32, 0, 28),
        Position = UDim2.new(0, 16, 0, 14),
        BackgroundTransparency = 1,
        Text = "Agent 想要执行 Lua 代码",
        TextColor3 = Color3.fromRGB(230, 232, 240),
        Font = Enum.Font.SourceSansBold,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = panel,
        ZIndex = 101
    })

    
    local codeStr = tostring(code or "")
    local lineCount = 1
    for _ in codeStr:gmatch("\n") do lineCount = lineCount + 1 end
    local codeH = math.max(60, math.min(220, lineCount * 18 + 16))

    local codeBox = create("ScrollingFrame", {
        Name = "CodeBox",
        Size = UDim2.new(1, -32, 0, codeH),
        Position = UDim2.new(0, 16, 0, 50),
        BackgroundColor3 = Color3.fromRGB(18, 22, 30),
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Color3.fromRGB(80, 90, 110),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Parent = panel,
        ZIndex = 101
    })
    corner(8, codeBox)
    create("UIListLayout", {Padding = UDim.new(0, 0), Parent = codeBox})
    local codeLabel = create("TextLabel", {
        Size = UDim2.new(1, -20, 0, 0),
        BackgroundTransparency = 1,
        Text = codeStr,
        TextColor3 = Color3.fromRGB(180, 200, 220),
        Font = Enum.Font.Code,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = codeBox,
        ZIndex = 102
    })
    create("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        PaddingTop = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 8),
        Parent = codeLabel
    })

    local btnY = 50 + codeH + 12
    create("TextLabel", {
        Size = UDim2.new(1, -32, 0, 20),
        Position = UDim2.new(0, 16, 0, btnY),
        BackgroundTransparency = 1,
        Text = "你想怎么做？",
        TextColor3 = Color3.fromRGB(140, 150, 170),
        Font = Enum.Font.SourceSans,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = panel,
        ZIndex = 101
    })

    local cancelBtn = create("TextButton", {
        Size = UDim2.new(0, 100, 0, 32),
        Position = UDim2.new(1, -116, 0, btnY + 28),
        BackgroundColor3 = Color3.fromRGB(60, 65, 80),
        Text = "取消",
        TextColor3 = Color3.fromRGB(200, 200, 210),
        Font = Enum.Font.SourceSansBold,
        TextSize = 13,
        BorderSizePixel = 0,
        Parent = panel,
        ZIndex = 102
    })
    corner(8, cancelBtn)

    local confirmBtn = create("TextButton", {
        Size = UDim2.new(0, 100, 0, 32),
        Position = UDim2.new(1, -228, 0, btnY + 28),
        BackgroundColor3 = Color3.fromRGB(59, 130, 246),
        Text = "确认",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.SourceSansBold,
        TextSize = 13,
        BorderSizePixel = 0,
        Parent = panel,
        ZIndex = 102
    })
    corner(8, confirmBtn)

    panel.Size = UDim2.new(0, 360, 0, (btnY + 28) + 32 + 16)

    cancelBtn.MouseButton1Click:Connect(function()
        confirmed = false
        done = true
    end)
    confirmBtn.MouseButton1Click:Connect(function()
        confirmed = true
        done = true
    end)

    local timeout = 30
    local waited = 0
    while not done and waited < timeout do
        task.wait(0.1)
        waited = waited + 0.1
    end
    dialog:Destroy()
    return confirmed
end


local AgentToolState = {
    noclip = {active = false, conn = nil},
    antiFling = {active = false, conn = nil},
}


local function AgentSetNoclip(enabled)
    local state = AgentToolState.noclip
    if enabled then
        if state.active then return "穿墙已处于开启状态" end
        state.active = true
        state.conn = svc.RunService.Stepped:Connect(function()
            local lp = svc.Players.LocalPlayer
            local char = lp and lp.Character
            if not char then return end
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("BasePart") then v.CanCollide = false end
            end
            local root = char:FindFirstChild("HumanoidRootPart")
            if root and root:IsA("BasePart") then root.CanCollide = false end
        end)
        return "穿墙已开启（noclip）"
    else
        if not state.active then return "穿墙已是关闭状态" end
        state.active = false
        if state.conn then pcall(function() state.conn:Disconnect() end) end
        state.conn = nil
        local lp = svc.Players.LocalPlayer
        local char = lp and lp.Character
        if char then
            for _, v in ipairs(char:GetDescendants()) do
                if v:IsA("BasePart") then v.CanCollide = true end
            end
        end
        return "穿墙已关闭"
    end
end


local function AgentSetAntiFling(enabled)
    local state = AgentToolState.antiFling
    if enabled then
        if state.active then return "防甩飞已处于开启状态" end
        state.active = true
        state.conn = svc.RunService.Stepped:Connect(function()
            local lp = svc.Players.LocalPlayer
            for _, plr in ipairs(svc.Players:GetPlayers()) do
                if plr ~= lp then
                    local char = plr.Character
                    if char then
                        for _, v in ipairs(char:GetDescendants()) do
                            if v:IsA("BasePart") then v.CanCollide = false end
                        end
                    end
                end
            end
        end)
        return "防甩飞已开启（已关闭其他玩家的碰撞）"
    else
        if not state.active then return "防甩飞已是关闭状态" end
        state.active = false
        if state.conn then pcall(function() state.conn:Disconnect() end) end
        state.conn = nil
        return "防甩飞已关闭"
    end
end







local AgentRemoteCapture
do
    local AgentRemoteHookInstalled = false
    local AgentRemoteHookOldNamecall = nil
    local AgentRemoteCaptureEnabled = false
    local AgentRemoteBuffer = {}
    local AgentRemoteNoise = {"ping", "fps", "heartbeat", "heart", "latency", "requestping", "updateping", "getping", "sendping", "clientheartbeat"}

    local function AgentRemoteGetInstancePath(inst)
        if not inst then return "nil" end
        if not inst:IsA("Instance") then return tostring(inst) end
        local root = inst
        local parts = {}
        while root.Parent and root.Parent ~= game do
            table.insert(parts, 1, string.format("%q", root.Name))
            root = root.Parent
        end
        local parent = root.Parent
        local prefix
        if parent == game then
            local name = root.Name
            if name == "Workspace" then prefix = "workspace"
            elseif name == "ReplicatedStorage" then prefix = 'game:GetService("ReplicatedStorage")'
            elseif name == "Players" then prefix = 'game:GetService("Players")'
            elseif name == "Lighting" then prefix = 'game:GetService("Lighting")'
            elseif name == "ServerScriptService" then prefix = 'game:GetService("ServerScriptService")'
            elseif name == "ServerStorage" then prefix = 'game:GetService("ServerStorage")'
            elseif name == "TeleportService" then prefix = 'game:GetService("TeleportService")'
            else prefix = 'game:GetService(' .. string.format("%q", name) .. ')'
            end
        elseif parent == nil then
            prefix = "game"
        else
            prefix = AgentRemoteGetInstancePath(parent)
        end
        local path = prefix
        for _, pname in ipairs(parts) do
            path = path .. ":WaitForChild(" .. pname .. ")"
        end
        return path
    end

    local function AgentRemoteFormatArg(arg)
        if type(arg) == "table" then
            if getmetatable(arg) and getmetatable(arg).__tostring then
                return tostring(arg)
            end
            return "{...}"
        elseif type(arg) == "Instance" then
            return AgentRemoteGetInstancePath(arg)
        elseif type(arg) == "string" then
            return string.format("%q", arg)
        elseif type(arg) == "nil" then
            return "nil"
        else
            return tostring(arg)
        end
    end

    local function AgentRemoteFormatCall(remoteObject, methodName, args)
        local remotePath = AgentRemoteGetInstancePath(remoteObject)
        local argStrings = {}
        for i, v in ipairs(args) do
            argStrings[i] = AgentRemoteFormatArg(v)
        end
        local lines = {}
        lines[#lines + 1] = "local args = {"
        for i, argStr in ipairs(argStrings) do
            if i > 20 then
                lines[#lines + 1] = "\t--...(args 过多已截断)"
                break
            end
            local line = "\t" .. argStr
            if i < #argStrings then line = line .. "," end
            lines[#lines + 1] = line
        end
        lines[#lines + 1] = "}"
        lines[#lines + 1] = remotePath .. ":" .. methodName .. "(unpack(args))"
        return table.concat(lines, "\n")
    end

    local function AgentRemoteInstallHook()
        if AgentRemoteHookInstalled then return true end
        if not getrawmetatable or not setreadonly or not getnamecallmethod or not newcclosure then return false end
        local meta = getrawmetatable(game)
        if not meta then return false end
        local ok = pcall(function()
            setreadonly(meta, false)
            AgentRemoteHookOldNamecall = meta.__namecall
            meta.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                local result
                if AgentRemoteCaptureEnabled and (method == "FireServer" or method == "InvokeServer") then
                    local args = {...}
                    pcall(function()
                        local low = AgentRemoteGetInstancePath(self):lower()
                        local skip = false
                        for _, n in ipairs(AgentRemoteNoise) do
                            if low:find(n, 1, true) then skip = true break end
                        end
                        if not skip then
                            table.insert(AgentRemoteBuffer, {
                                path = low,
                                method = method,
                                script = AgentRemoteFormatCall(self, method, args),
                                time = os.time(),
                            })
                            if #AgentRemoteBuffer > 60 then table.remove(AgentRemoteBuffer, 1) end
                        end
                    end)
                end
                if AgentRemoteHookOldNamecall then
                    result = AgentRemoteHookOldNamecall(self, ...)
                else
                    result = self[method](self, ...)
                end
                return result
            end)
        end)
        if ok then AgentRemoteHookInstalled = true end
        return ok
    end

    AgentRemoteCapture = function(args)
        if not AgentRemoteInstallHook() then
            return "无法安装 Remote 捕获钩子：当前执行器缺少 getrawmetatable/setreadonly/getnamecallmethod/newcclosure。"
        end
        local goal = tostring(args.goal or "")
        local timeout = tonumber(args.timeout) or 30
        if timeout < 3 then timeout = 3 elseif timeout > 120 then timeout = 120 end

        AgentRemoteBuffer = {}
        AgentRemoteCaptureEnabled = true
        local waitMsg = goal ~= "" and ("等待用户交互：请在游戏内操作「" .. goal .. "」以捕获 Remote…") or "等待用户交互：请在游戏内进行操作以捕获 Remote…"
        AgentThinkingPhase = waitMsg
        AgentCustomProgressMsg = waitMsg
        AgentLastToolPhase = waitMsg

        local deadline = tick() + timeout
        local captured = {}
        while tick() < deadline do
            task.wait(0.2)
            if #AgentRemoteBuffer > 0 then
                captured = AgentRemoteBuffer
                AgentRemoteBuffer = {}
                break
            end
        end
        AgentRemoteCaptureEnabled = false

        if #captured == 0 then
            AgentThinkingPhase = "未捕获到相关 Remote"
            return "已等待 " .. tostring(timeout) .. " 秒，未捕获到相关 Remote（已自动忽略 ping/fps/心跳/状态检查等无用 Remote）。请让用户在游戏内执行目标操作后重试，或加长 timeout。"
        end

        local lines = { "已捕获到 " .. #captured .. " 个相关 Remote 调用：\n" }
        for i, c in ipairs(captured) do
            if i > 2 then
                lines[#lines + 1] = "\n…其余 " .. (#captured - 2) .. " 个 Remote 已折叠，如需可再次调用 GotRemote"
                break
            end
            local script = c.script
            if #script > 900 then script = script:sub(1, 900) .. "\n--...(脚本已截断)" end
            lines[#lines + 1] = "【" .. i .. "】" .. c.path .. "  [" .. c.method .. "]"
            lines[#lines + 1] = script
            lines[#lines + 1] = ""
        end
        AgentThinkingPhase = "已捕获 Remote，继续处理"
        return table.concat(lines, "\n")
    end
end







local AgentGoTo
do
    local function AgentResolveTarget(args)
        args = args or {}
        local path = tostring(args.path or "")
        if path ~= "" then
            local obj, err = AgentGetInstanceFromPath(path)
            if obj then
                local cframe = obj.CFrame
                if cframe then return cframe.Position end
                local pos = obj.Position
                if pos then return pos end
                if obj:IsA("Model") then
                    local primary = obj.PrimaryPart
                    if primary and primary.CFrame then return primary.CFrame.Position end
                    local okP, pcf = pcall(function() return obj:GetPrimaryPartCFrame() end)
                    if okP and typeof(pcf) == "CFrame" then return pcf.Position end
                end
                return nil, "对象无位置: " .. path
            end
            return nil, err
        end
        local p = args.position
        if type(p) == "table" and p.x ~= nil then
            return Vector3.new(tonumber(p.x) or 0, tonumber(p.y) or 0, tonumber(p.z) or 0)
        end
        if args.x ~= nil then
            return Vector3.new(tonumber(args.x) or 0, tonumber(args.y) or 0, tonumber(args.z) or 0)
        end
        return nil, "未提供有效目标（path 或 position{x,y,z} 或 x/y/z）"
    end

    local function AgentSmoothTo(root, targetPos, step, waitTime)
        local start = root.Position
        local dist = (targetPos - start).Magnitude
        if dist < 0.5 then
            root.CFrame = CFrame.new(targetPos)
            task.wait(0.2)
            return (root.Position - targetPos).Magnitude < 5
        end
        local n = math.max(1, math.ceil(dist / step))
        for i = 1, n do
            local pos = start:Lerp(targetPos, i / n)
            root.CFrame = CFrame.new(pos)
            task.wait(waitTime)
        end
        task.wait(0.3)
        return (root.Position - targetPos).Magnitude < 5
    end

    local function AgentPathwalk(humanoid, root, targetPos, timeout)
        humanoid:MoveTo(targetPos)
        local reached = false
        local conn = humanoid.MoveToFinished:Connect(function(ok) if ok then reached = true end end)
        local deadline = tick() + (timeout or 15)
        while tick() < deadline do
            task.wait(0.2)
            if (root.Position - targetPos).Magnitude < 5 then reached = true break end
        end
        conn:Disconnect()
        humanoid:MoveTo(root.Position)
        return (root.Position - targetPos).Magnitude < 6
    end

    AgentGoTo = function(args)
        local targetPos, err = AgentResolveTarget(args)
        if not targetPos then return "无法解析目标位置: " .. tostring(err) end

        local lp = svc.Players and svc.Players.LocalPlayer
        if not lp then return "没有本地玩家" end
        local char = lp.Character
        if not char then return "角色不存在，请等待角色加载" end
        local root = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid then return "找不到 HumanoidRootPart 或 Humanoid" end

        AgentThinkingPhase = "正在移动玩家到目标位置…"
        AgentLastToolPhase = "正在移动玩家到目标位置…"
        local targetStr = string.format("(%.1f, %.1f, %.1f)", targetPos.X, targetPos.Y, targetPos.Z)
        local report = {}
        local orig = root.Position

        
        pcall(function() root.CFrame = CFrame.new(targetPos) end)
        task.wait(0.35)
        if (root.Position - targetPos).Magnitude < 5 then
            AgentThinkingPhase = "已直接传送到目标"
            return "已直接传送到 " .. targetStr .. "。"
        end
        table.insert(report, "直接传送被拉回（当前距目标 " .. string.format("%.1f", (root.Position - targetPos).Magnitude) .. "），改用平滑传送…")

        
        local okSmooth = pcall(AgentSmoothTo, root, targetPos, 3, 0.05)
        if okSmooth then
            AgentThinkingPhase = "已平滑传送到目标"
            return "已通过平滑传送到达 " .. targetStr .. "。"
        end
        table.insert(report, "平滑传送仍被拉回，改用更慢的平滑传送…")

        
        local okSlow = pcall(AgentSmoothTo, root, targetPos, 1, 0.1)
        if okSlow then
            AgentThinkingPhase = "已慢速传送到目标"
            return "已通过慢速平滑传送到达 " .. targetStr .. "。"
        end
        table.insert(report, "慢速传送仍被拉回，改用自动寻路步行…")

        
        local okWalk = pcall(AgentPathwalk, humanoid, root, targetPos, 15)
        if okWalk then
            AgentThinkingPhase = "已步行到达目标"
            return "已通过自动寻路步行到达 " .. targetStr .. "。"
        end

        return "所有移动方式均失败，最终位置 " .. tostring(root.Position) .. "，目标 " .. targetStr .. "。\n尝试记录：\n" .. table.concat(report, "\n")
    end
end






local AgentClickGui
do
    local function AgentClickAt(x, y)
        local ok = pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendMouseButtonEvent(x, y, 0, true, game, 1)
            task.wait(0.05)
            vim:SendMouseButtonEvent(x, y, 0, false, game, 1)
        end)
        return ok
    end

    local function AgentResolveAbs(args)
        args = args or {}
        local x = tonumber(args.x)
        local y = tonumber(args.y)
        local path = tostring(args.path or "")
        if path ~= "" then
            local obj, err = AgentGetInstanceFromPath(path)
            if obj then
                local absPos, absSize = obj.AbsolutePosition, obj.AbsoluteSize
                if absPos and absSize and absSize.X > 0 and absSize.Y > 0 then
                    return absPos.X + absSize.X / 2, absPos.Y + absSize.Y / 2, "GUI:" .. path
                end
                return nil, nil, "对象无绝对位置(非GUI元素): " .. path
            end
            return nil, nil, err
        end
        local sx, sy = tonumber(args.scaleX), tonumber(args.scaleY)
        if sx and sy then
            local sg = nil
            local lp = svc.Players and svc.Players.LocalPlayer
            if lp and lp:FindFirstChild("PlayerGui") then
                for _, c in ipairs(lp.PlayerGui:GetChildren()) do
                    if c:IsA("ScreenGui") then sg = c break end
                end
            end
            local w = (sg and sg.AbsoluteSize and sg.AbsoluteSize.X > 0 and sg.AbsoluteSize.X) or (workspace and workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X) or 1280
            local h = (sg and sg.AbsoluteSize and sg.AbsoluteSize.Y > 0 and sg.AbsoluteSize.Y) or (workspace and workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y) or 720
            local ax, ay = math.floor(sx * w + 0.5), math.floor(sy * h + 0.5)
            return ax, ay, string.format("scale(%.3f,%.3f)→绝对(%d,%d)", sx, sy, ax, ay)
        end
        if x and y then return math.floor(x), math.floor(y), "绝对坐标" end
        return nil, nil, "未提供目标（path 或 scaleX/scaleY 或 x/y）"
    end

    AgentClickGui = function(args)
        local ax, ay, desc = AgentResolveAbs(args)
        if not ax then return desc end
        AgentThinkingPhase = "正在点击界面元素…"
        AgentLastToolPhase = "正在点击界面元素…"

        
        
        local wasMainVisible = main and main.Visible
        local wasOrbVisible = orbFrame and orbFrame.Visible
        if wasMainVisible then main.Visible = false end
        if wasOrbVisible then orbFrame.Visible = false end
        task.wait() 

        local clicked = AgentClickAt(ax, ay)

        
        if wasMainVisible then main.Visible = true end
        if wasOrbVisible then orbFrame.Visible = true end

        local base = "目标: " .. tostring(desc) .. "，屏幕绝对位置(" .. tostring(ax) .. "," .. tostring(ay) .. ")。"
        if clicked then
            return "已点击成功。" .. base
        end
        return "执行器缺少鼠标模拟 API，无法实际点击。" .. base .. " 如需点击，请用 execute_lua 结合 GUI 的 Click 事件触发。"
    end
end


-- ============================================================================
--  文件工具：read_file / edit_file / del_file
--  统一约定（规范）：
--    path        文件路径（必填，可用 DeltaUI/... 相对路径）
--    start_line  起始行号，1 起（read_file / edit_file 通用）
--    end_line    结束行号（含）；与 count 二选一，count 优先
--    count       行数；read_file 表示读多少行，edit_file 表示替换多少行
--    content     写入/替换/插入的文本
--    old/new     replace_text 模式的查找与替换文本（纯文本，非模式串）
--    backup      默认 true：改动前留备份（edit_file → .bak，del_file → 回收站）
--  所有工具统一以 [OK] / [ERR] / [WARN] 开头返回，便于模型判断结果。
-- ============================================================================
AGENT_FILE_TOOLS_MAX_CHARS = 12000   -- read_file 单次返回字符上限

local function AgentFileSplitLines(text)
    local out = {}
    text = tostring(text or "")
    local pos = 1
    while true do
        local s = text:find("\n", pos, true)
        if s then
            out[#out + 1] = text:sub(pos, s - 1)
            pos = s + 1
        else
            out[#out + 1] = text:sub(pos)
            break
        end
    end
    return out
end

local function AgentFileJoinLines(lines)
    return table.concat(lines, "\n")
end

-- 文本内容切成行数组；若以换行结尾，去掉尾部多出的空元素（避免多插一个空行）
local function AgentFileContentToLines(content)
    content = tostring(content or "")
    local lines = AgentFileSplitLines(content)
    if #lines > 1 and lines[#lines] == "" and content:sub(-1) == "\n" then
        table.remove(lines)
    end
    return lines
end

local function AgentFileLineCount(text)
    return select(2, tostring(text or ""):gsub("\n", "")) + 1
end

local function AgentFileCheckFs()
    if type(isfile) ~= "function" or type(readfile) ~= "function" or type(writefile) ~= "function" then
        return false, "当前执行器不支持文件读写接口（isfile/readfile/writefile）"
    end
    return true
end

local function AgentFileReadRaw(path)
    local okFs, fsErr = AgentFileCheckFs()
    if not okFs then return nil, fsErr end
    if not isfile(path) then return nil, "文件不存在: " .. tostring(path) end
    local ok, content = pcall(readfile, path)
    if not ok or type(content) ~= "string" then
        return nil, "读取失败: " .. tostring(content)
    end
    return content
end

local function AgentFileEnsureParent(path)
    if type(isfolder) ~= "function" or type(makefolder) ~= "function" then return end
    local folder = tostring(path):match("^(.*)[/\\][^/\\]+$")
    if folder and folder ~= "" and not isfolder(folder) then
        pcall(makefolder, folder)
    end
end

local function AgentEscapeLuaPattern(s)
    return (tostring(s or ""):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

-- ---------------------------------------------------------------- read_file
local function AgentToolReadFile(args)
    args = args or {}
    local path = tostring(args.path or "")
    if path == "" then return "[ERR] read_file: 缺少参数 path" end

    local content, err = AgentFileReadRaw(path)
    if not content then return "[ERR] read_file: " .. tostring(err) end

    local lines = AgentFileSplitLines(content)
    local total = #lines

    local startLine = math.floor(tonumber(args.start_line) or tonumber(args.start) or 1)
    if startLine < 1 then startLine = 1 end
    if startLine > total then startLine = total end

    local count = tonumber(args.count) or tonumber(args.line_count)
    local endLine
    if count and count > 0 then
        endLine = startLine + math.floor(count) - 1
    else
        endLine = math.floor(tonumber(args.end_line) or tonumber(args["end"]) or total)
    end
    if endLine > total then endLine = total end
    if endLine < startLine then endLine = startLine end

    local numbered = args.number
    if numbered == nil then numbered = true end

    local maxChars = tonumber(args.max_chars) or AGENT_FILE_TOOLS_MAX_CHARS
    local buf = {}
    local used = 0
    local truncated = false
    local lastLine = startLine - 1
    for i = startLine, endLine do
        local text = lines[i] or ""
        local piece = numbered and string.format("%4d| %s", i, text) or text
        if used + #piece + 1 > maxChars then
            truncated = true
            break
        end
        buf[#buf + 1] = piece
        used = used + #piece + 1
        lastLine = i
    end

    local head = string.format("[OK] read_file %s | 共 %d 行 | 返回第 %d-%d 行%s",
        path, total, startLine, math.max(startLine, lastLine),
        truncated and ("（超出 " .. maxChars .. " 字符已截断，可指定 start_line/count 继续读）") or "")
    return head .. "\n" .. table.concat(buf, "\n")
end

-- ---------------------------------------------------------------- edit_file
local function AgentToolEditFile(args)
    args = args or {}
    if type(isfile) ~= "function" or type(writefile) ~= "function" then
        return "[ERR] edit_file: 当前执行器不支持文件读写接口"
    end
    local path = tostring(args.path or "")
    if path == "" then return "[ERR] edit_file: 缺少参数 path" end

    local exists = isfile(path)
    local original = ""
    if exists then
        local content, err = AgentFileReadRaw(path)
        if not content then return "[ERR] edit_file: " .. tostring(err) end
        original = content
    end

    local mode = tostring(args.mode or ""):lower()
    if mode == "" then
        if args.old ~= nil then mode = "replace_text"
        elseif args.append == true then mode = "append"
        elseif args.prepend == true then mode = "prepend"
        elseif args.start_line ~= nil then mode = "replace_range"
        elseif args.content ~= nil then mode = exists and "overwrite" or "create"
        else
            return "[ERR] edit_file: 无法判断编辑模式，请给出 mode（create/overwrite/append/prepend/insert/replace_range/replace_text）或对应参数"
        end
    end

    if not exists and mode ~= "create" and mode ~= "overwrite" then
        return "[ERR] edit_file: 文件不存在，新建请用 mode=\"create\": " .. path
    end

    local beforeLines = AgentFileLineCount(original)
    local newContent = original
    local detail = ""
    local wrote = true

    if mode == "create" or mode == "overwrite" then
        newContent = tostring(args.content or "")
        detail = "整文件写入 " .. AgentFileLineCount(newContent) .. " 行"

    elseif mode == "append" then
        local add = tostring(args.content or "")
        if add == "" then return "[ERR] edit_file: append 需要 content" end
        if original ~= "" and original:sub(-1) ~= "\n" then original = original .. "\n" end
        newContent = original .. add
        detail = "末尾追加 " .. AgentFileLineCount(add) .. " 行"

    elseif mode == "prepend" then
        local add = tostring(args.content or "")
        if add == "" then return "[ERR] edit_file: prepend 需要 content" end
        newContent = add .. original
        detail = "开头插入"

    elseif mode == "insert" then
        local add = tostring(args.content or "")
        if add == "" then return "[ERR] edit_file: insert 需要 content" end
        local lines = AgentFileSplitLines(original)
        local at = math.floor(tonumber(args.start_line) or tonumber(args.after_line) or 0)
        if at < 0 then at = 0 end
        if at > #lines then at = #lines end
        local addLines = AgentFileContentToLines(add)
        local merged = {}
        for i = 1, at do merged[#merged + 1] = lines[i] end
        for _, l in ipairs(addLines) do merged[#merged + 1] = l end
        for i = at + 1, #lines do merged[#merged + 1] = lines[i] end
        newContent = AgentFileJoinLines(merged)
        detail = string.format("在第 %d 行后插入 %d 行", at, #addLines)

    elseif mode == "replace_range" then
        local lines = AgentFileSplitLines(original)
        local s = math.floor(tonumber(args.start_line) or tonumber(args.from_line) or 1)
        local e = tonumber(args.end_line)
        if not e then
            local c = tonumber(args.count)
            e = c and (s + math.floor(c) - 1) or s
        end
        e = math.floor(e)
        if s < 1 then s = 1 end
        if s > #lines then s = #lines end
        if e < s then e = s end
        if e > #lines then e = #lines end
        local newLines = AgentFileContentToLines(tostring(args.content or ""))
        local merged = {}
        for i = 1, s - 1 do merged[#merged + 1] = lines[i] end
        for _, l in ipairs(newLines) do merged[#merged + 1] = l end
        for i = e + 1, #lines do merged[#merged + 1] = lines[i] end
        newContent = AgentFileJoinLines(merged)
        detail = string.format("替换第 %d-%d 行 → %d 行", s, e, #newLines)

    elseif mode == "replace_text" then
        local old = tostring(args.old or "")
        if old == "" then return "[ERR] edit_file: replace_text 需要参数 old" end
        local new = tostring(args.new or args.content or "")
        local pat = AgentEscapeLuaPattern(old)
        local limit = tonumber(args.count) or 1
        local replaced = 0
        if limit <= 0 then
            newContent, replaced = original:gsub(pat, function() return new end)
        else
            local done = 0
            newContent = original:gsub(pat, function()
                if done >= limit then return nil end
                done = done + 1
                return new
            end)
            replaced = done
        end
        if replaced == 0 then
            return "[ERR] edit_file: 未找到待替换文本（" .. string.format("%d", #old) .. " 字符），请先 read_file 确认内容"
        end
        detail = string.format("文本替换 %d 处", replaced)

    else
        return "[ERR] edit_file: 不支持的模式 " .. mode
    end

    if newContent == original then
        return "[WARN] edit_file: 内容无变化（" .. detail .. "）"
    end

    AgentFileEnsureParent(path)

    local backupPath = nil
    if exists and args.backup ~= false then
        backupPath = path .. ".bak"
        pcall(writefile, backupPath, original)
    end

    local okW, werr = pcall(writefile, path, newContent)
    if not okW then
        wrote = false
        return "[ERR] edit_file 写入失败: " .. tostring(werr)
    end

    AgentTrackFileOp(path)
    local afterLines = AgentFileLineCount(newContent)
    return string.format("[OK] edit_file %s | %s | 行数 %d → %d%s",
        path, detail, beforeLines, afterLines,
        backupPath and (" | 备份: " .. backupPath) or "")
end

-- ---------------------------------------------------------------- del_file
local function AgentToolDelFile(args)
    args = args or {}
    local path = tostring(args.path or "")
    if path == "" then return "[ERR] del_file: 缺少参数 path" end

    local isDir = type(isfolder) == "function" and isfolder(path)
    local isF = type(isfile) == "function" and isfile(path)
    if not isDir and not isF then return "[ERR] del_file: 路径不存在: " .. path end

    -- 回收站：删除前把文件内容备份到 DeltaUI/Trash/（backup=false 可关闭）
    local trashed = nil
    if isF and args.backup ~= false and type(readfile) == "function" and type(writefile) == "function" then
        local okR, content = pcall(readfile, path)
        if okR and type(content) == "string" then
            local trashDir = "DeltaUI/Trash"
            if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(trashDir) then
                pcall(makefolder, trashDir)
            end
            local name = path:match("([^/\\]+)$") or "file"
            trashed = trashDir .. "/" .. tostring(os.time()) .. "_" .. name
            pcall(writefile, trashed, content)
        end
    end

    if isDir then
        if args.recursive ~= true and args.force ~= true then
            return "[ERR] del_file: " .. path .. " 是文件夹，确认整目录删除请传 recursive=true"
        end
        if type(delfolder) ~= "function" then
            return "[ERR] del_file: 当前执行器不支持删除文件夹（delfolder）"
        end
        local okD, derr = pcall(delfolder, path)
        if not okD then return "[ERR] del_file 删除文件夹失败: " .. tostring(derr) end
        return "[OK] del_file 已删除文件夹: " .. path .. (trashed and (" | 回收站: " .. trashed) or "")
    end

    if type(delfile) ~= "function" then
        return "[ERR] del_file: 当前执行器不支持 delfile"
    end
    local okD, derr = pcall(delfile, path)
    if not okD then return "[ERR] del_file 删除失败: " .. tostring(derr) end
    AgentTrackFileOp(path)
    return "[OK] del_file 已删除: " .. path .. (trashed and (" | 回收站: " .. trashed) or "")
end

local function AgentExecuteToolCall(tool, args)
    AgentTrackToolCall()
    local ok, result = pcall(function()
        if tool == "list_children" then
            local path = tostring(args.path or "")
            local obj, err = AgentGetInstanceFromPath(path)
            if not obj then return "路径不可达: " .. tostring(err) end
            AgentChatMemory.lastPath = path
            local depth = tonumber(args.depth) or 1
            if depth < 1 then depth = 1 elseif depth > 3 then depth = 3 end
            local rows = AgentListChildrenDepth(obj, depth)
            local shown = {}
            for i = 1, math.min(#rows, 80) do shown[i] = rows[i] end
            local text = table.concat(shown, "\n")
            if #rows > 80 then text = text .. "\n…共 " .. #rows .. " 行，仅显示前 80 行" end
            return text

        elseif tool == "decompile" then
            local path = tostring(args.path or "")
            local obj, err = AgentGetInstanceFromPath(path)
            if not obj then return "路径不可达: " .. tostring(err) end
            AgentChatMemory.lastPath = path
            local source, derr = AgentTryDecompile(obj)
            if not source then return "反编译失败: " .. tostring(derr) end
            local savedPath = nil
            if writefile and makefolder and isfolder then
                local okSave, saveOk, savePath = pcall(AgentSaveScriptToFile, obj, AgentGetOutputDir(), nil)
                if okSave and saveOk then
                    savedPath = savePath
                    AgentLastDecompileDir = AgentGetOutputDir()
                end
            end
            local summary = "反编译成功，源码共 " .. #source .. " 字节。"
            if savedPath then summary = summary .. "已保存到: " .. tostring(savedPath) end
            return summary .. "\n源码开头预览:\n" .. source:sub(1, 2500)

        elseif tool == "decompile_all" then
            return tostring(AgentDecompileAll("反编译所有脚本"))

        elseif tool == "decompile_smart" then
            local target = tostring(args.target or "")
            AgentChatMemory.lastPath = target
            return tostring(AgentDecompileSmart(target))

        elseif tool == "decompile_modules" then
            local target = tostring(args.target or "")
            if target ~= "" then AgentChatMemory.lastPath = target end
            return tostring(AgentDecompileModules(target))

        elseif tool == "get_property" then
            local obj, err = AgentGetInstanceFromPath(tostring(args.path or ""))
            if not obj then return "路径不可达: " .. tostring(err) end
            local prop = tostring(args.property or "")
            local okRead, value = pcall(function() return obj[prop] end)
            if not okRead then return "属性读取失败: " .. tostring(value) end
            return prop .. " = " .. tostring(value)

        elseif tool == "list_properties" then
            local obj, err = AgentGetInstanceFromPath(tostring(args.path or ""))
            if not obj then return "路径不可达: " .. tostring(err) end
            local props = AgentListAllProperties(obj)
            local shown = {}
            for i = 1, math.min(#props, 60) do shown[i] = props[i] end
            local text = table.concat(shown, "\n")
            if #props > 60 then text = text .. "\n…共 " .. #props .. " 项，仅显示前 60 项" end
            return text

        elseif tool == "execute_lua" then
            local code = tostring(args.code or "")
            if code == "" then return "未提供要执行的代码" end
            local cfg = loadConfig()
            if not cfg.autoAcceptExec then
                if not AgentShowConfirmDialog(code) then
                    return "__PERMISSION_DENIED__"
                end
            else
                AgentThinkingPhase = "正在执行 Lua 代码"
                AgentLastToolPhase = "正在执行 Lua 代码"
                task.wait()
            end
            local out, cerr = AgentExecuteLuaCode(code)
            if not out then return "执行失败: " .. tostring(cerr) end
            return "执行成功: " .. out

        elseif tool == "find_objects" then
            local name = tostring(args.name or "")
            if name == "" then return "未提供搜索名称" end
            local matches = AgentFindObjectsByName(name, game)
            if #matches == 0 then return "没有找到名称包含 " .. name .. " 的对象" end
            local shown = {}
            for i = 1, math.min(#matches, 40) do shown[i] = matches[i] end
            return "找到 " .. #matches .. " 个匹配:\n" .. table.concat(shown, "\n")

        elseif tool == "search_objects" then
            local name = tostring(args.name or "")
            if name == "" then return "未提供搜索名称" end
            local searchRoots = {}
            table.insert(searchRoots, {obj = workspace, name = "Workspace"})
            local lp = svc.Players.LocalPlayer
            if lp then
                local ps = lp:FindFirstChild("PlayerScripts")
                if ps then table.insert(searchRoots, {obj = ps, name = "PlayerScripts"}) end
            end
            table.insert(searchRoots, {obj = game:GetService("ReplicatedStorage"), name = "ReplicatedStorage"})
            table.insert(searchRoots, {obj = game:GetService("ServerScriptService"), name = "ServerScriptService"})
            local allMatches = {}
            for _, root in ipairs(searchRoots) do
                local found = AgentFindObjectsByName(name, root.obj)
                for _, m in ipairs(found) do
                    table.insert(allMatches, m)
                end
            end
            if #allMatches == 0 then
                return "在 Workspace、PlayerScripts、ReplicatedStorage、ServerScriptService 中没有找到名称包含「" .. name .. "」的对象"
            end
            if #allMatches > 10 then
                local shown = {}
                for i = 1, 10 do shown[i] = allMatches[i] end
                local msg = "在 Workspace、PlayerScripts、ReplicatedStorage、ServerScriptService 中搜索「" .. name .. "」，共找到 " .. #allMatches .. " 个匹配对象：\n"
                msg = msg .. table.concat(shown, "\n")
                msg = msg .. "\n\n该名称对象太多了，需要我全部列出吗？"
                return msg
            end
            return "在 Workspace、PlayerScripts、ReplicatedStorage、ServerScriptService 中搜索「" .. name .. "」，共找到 " .. #allMatches .. " 个匹配对象：\n" .. table.concat(allMatches, "\n")

        elseif tool == "count_output_files" then
            return "输出目录共有 " .. tostring(AgentCountOutputFiles()) .. " 个文件"

        elseif tool == "list_output_files" then
            local dir = AgentGetOutputDir()
            local files = {}
            if isfolder and listfiles and isfile and isfolder(dir) then
                local function rec(p)
                    for _, f in ipairs(listfiles(p) or {}) do
                        if isfile(f) then table.insert(files, f)
                        elseif isfolder(f) then rec(f) end
                    end
                end
                rec(dir)
            end
            if #files == 0 then return "输出目录里还没有文件" end
            local shown = {}
            for i = 1, math.min(#files, 30) do shown[i] = files[i] end
            return "共 " .. #files .. " 个文件:\n" .. table.concat(shown, "\n")

        elseif tool == "delete_recent_files" then
            local okDel, deleted = AgentDeleteRecentFiles()
            if okDel then return "已删除最近生成的文件，共清理 " .. tostring(deleted) .. " 个" end
            return "删除失败: " .. tostring(deleted)

        elseif tool == "noclip" then
            return AgentSetNoclip(args.enabled ~= false)

        elseif tool == "anti_fling" then
            return AgentSetAntiFling(args.enabled ~= false)

        elseif tool == "read_file" then
            return AgentToolReadFile(args)

        elseif tool == "edit_file" then
            return AgentToolEditFile(args)

        elseif tool == "del_file" or tool == "delete_file" or tool == "remove_file" then
            return AgentToolDelFile(args)

        elseif tool == "report_progress" then
            local msg = AgentSafeString(tostring(args.message or ""), 80)
            if msg ~= "" then
                AgentThinkingPhase = msg
                AgentCustomProgressMsg = msg
            end
            return "已向用户汇报进度: " .. msg

        elseif tool == "GotRemote" or tool == "gotremote" then
            return AgentRemoteCapture(args)

        elseif tool == "go_to" or tool == "teleport" or tool == "move" then
            return AgentGoTo(args)

        elseif tool == "click_gui" or tool == "click" then
            return AgentClickGui(args)
        elseif tool == "ask_user" then
            local q = AgentSafeString(tostring(args.question or "我有个问题想问你"), 200)
            local opts = {}
            if type(args.options) == "table" then
                for _, o in ipairs(args.options) do
                    if tostring(o) ~= "" then opts[#opts + 1] = tostring(o) end
                end
            end
            pcall(AgentShowAskCard, q, opts)
            return "[ASK_USER] 已向用户弹出提问框，等待用户在界面中输入回复。请简短确认你已提问完毕，不要继续调用工具或执行操作，等待用户回复后再继续。"
        elseif tool == "work_plan" then
            local plan = args.plan
            if type(plan) == "string" then
                local okP, p = pcall(function() return svc.HttpService:JSONDecode(plan) end)
                if okP then plan = p end
            end
            if type(plan) ~= "table" then
                return "work_plan 错误：plan 参数不是有效的数组/对象"
            end
            pcall(AgentRenderWorkPlan, plan)
            return "已生成任务计划，共 " .. tostring(#plan) .. " 个任务，已在界面以看板形式展示。"
        end

        return "未知工具: " .. tostring(tool)
    end)
    if not ok then return "工具执行出错: " .. tostring(result) end
    return tostring(result)
end


local function AgentLooksIntermediate(content, toolCount)
    content = tostring(content or "")
    local compact = content:gsub("%s+", "")
    if #compact == 0 then return false end
    if content:find("##", 1, true) or content:find("```", 1, true) then return false end
    
    if (toolCount or 0) > 0 and #content < 60 then
        return false
    end
    
    local resultMarkers = {
        "已完成", "已修改", "修改为", "已设置", "已执行", "已保存",
        "已找到", "已获取", "已生成", "已处理", "已解决", "已更新",
        "结果是", "结果：", "答案：", "结论：", "总结：",
        "搞定", "完成", "好了", "ok", "done", "success",
    }
    for _, m in ipairs(resultMarkers) do
        if content:find(m, 1, true) then return false end
    end
    
    local markers = {
        "我已了解", "已了解", "了解你的", "了解您", "尝试解决", "正在尝试",
        "我来帮你", "我来处理", "让我先", "让我来", "我先",
        "好的，我来", "好的，我先", "嗯，我来",
        "开始处理", "先来看", "我来实现", "让我看看", "我来看看", "我正在",
        "正在为你", "好的，我正在", "我看看", "让我来解决", "我来帮你实现",
        "让我搜索", "让我查找", "让我查看", "让我检查", "让我分析",
        "让我读取", "让我获取", "让我调用",
        "让我换个", "让我尝试", "我可以试着", "由于我的工具", "让我看看有哪些",
        "我先来看", "让我先看", "我可以尝试", "让我接着", "我需要先",
    }
    for _, m in ipairs(markers) do
        if content:find(m, 1, true) then return true end
    end
    local lastChar = content:sub(-1)
    if lastChar == ":" or lastChar == "：" then
        return true
    end
    return false
end

local function AgentGenerateResponseCore(input, authToken)
    
    
    local _aWAuthZx9K7 = "Dlt" .. "7kZq" .. "W2m9vR4x" .. "Q9n"
    if authToken ~= _aWAuthZx9K7 then
        return "拒绝执行：核心生成函数不允许外部调用。", {{phase = "auth", output = "外部调用被拒绝"}}
    end
    local safeInput = tostring(input or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if safeInput == "" then
        return "请告诉我你想解决什么，我会结合当前对话和已有记忆来回答。", {}
    end

    local steps = {}
    local started = tick()

    local messages, context
    local okBuild, buildErr = pcall(function()
        messages, context = AgentBuildLLMMessages(safeInput)
    end)
    if not okBuild then
        return "处理时遇到了内部异常，请重试一下。", {{phase = "error", output = tostring(buildErr)}}
    end
    table.insert(steps, {phase = "understand", output = "理解当前问题与多轮上下文"})
    table.insert(steps, {phase = "memory", output = "载入 " .. tostring(#(context.conversation or {})) .. " 条对话历史、" .. tostring(#(context.memories or {})) .. " 条相关长期记忆"})

    
    
    
    local maxIter = math.max(1, tonumber(AgentLocalAIConfig.maxToolIterations) or 6)
    local finalAnswer = nil
    local toolCount = 0
    local apiFailed = false
    local apiError = nil
    local callHist = {}          
    local maxRepeats = 5
    local stallWarned = false    

    for iter = 1, maxIter do
        if AgentCustomProgressMsg ~= "" then
            AgentThinkingPhase = AgentCustomProgressMsg
        elseif AgentLastToolPhase ~= "" then
            AgentThinkingPhase = AgentLastToolPhase
        else
            AgentThinkingPhase = "正在请求模型"
        end
        local content, toolCalls, apiErr = AgentDeepSeekChat(messages, AGENT_DEEPSEEK_TOOLS)
        if apiErr then
            apiFailed = true
            apiError = apiErr
            break
        end

        AgentLocalAIState.mode = "api"

        if toolCalls and #toolCalls > 0 then
            
            
            local assistantToolCalls = {}
            for _, tc in ipairs(toolCalls) do
                local fnArgsJson = "{}"
                local hasArgs = false
                if type(tc.args) == "table" then
                    for _k in pairs(tc.args) do hasArgs = true break end
                end
                if hasArgs then
                    pcall(function()
                        fnArgsJson = svc.HttpService:JSONEncode(tc.args)
                    end)
                end
                assistantToolCalls[#assistantToolCalls + 1] = {
                    id = tc.id or ("call_" .. tostring(#assistantToolCalls + 1)),
                    type = "function",
                    ["function"] = {
                        name = tc.name or "",
                        arguments = fnArgsJson,
                    },
                }
            end
            table.insert(messages, {
                role = "assistant",
                content = (content and content ~= "") and content or nil,
                tool_calls = assistantToolCalls,
            })

            for _, tc in ipairs(toolCalls) do
                toolCount = toolCount + 1
                local toolName = tc.name or ""
                local toolArgs = tc.args or {}

                table.insert(steps, {phase = "tool", output = "模型自主决策调用工具: " .. toolName})
                AgentThinkingPhase = "正在调用工具: " .. toolName
                AgentLastToolName = toolName
                AgentLastToolPhase = "正在调用工具: " .. toolName
                -- 文件类工具结果更大，单独放宽上限（read_file 默认最多返回 12000 字符）
                local resultCap = 2500
                if toolName == "read_file" then
                    resultCap = 12000
                elseif toolName == "list_output_files" or toolName == "edit_file" then
                    resultCap = 4000
                end
                local toolResult = AgentSafeString(AgentExecuteToolCall(toolName, toolArgs), resultCap)

                
                local sig = toolName
                pcall(function()
                    if type(toolArgs) == "table" then
                        sig = toolName .. "|" .. svc.HttpService:JSONEncode(toolArgs)
                    end
                end)
                callHist[sig] = (callHist[sig] or 0) + 1
                if callHist[sig] > maxRepeats then
                    table.insert(steps, {phase = "execute", output = "检测到重复工具调用(" .. toolName .. ")，已终止循环"})
                    AgentLocalAIState.lastToolCalls = toolCount
                    AgentLocalAIState.lastLatency = math.max(0, tick() - started)
                    return "检测到重复的工具调用，为避免继续消耗积分已停止。请换一个更具体或不同的指令再试。", steps
                end

                AgentLastToolOp.name = toolName
                AgentLastToolOp.result = AgentSafeString(toolResult, 500)
                AgentLastToolOp.time = os.time()

                if toolResult == "__PERMISSION_DENIED__" then
                    local denyReplies = {
                        "执行权限被拒绝，我无法完成这个操作。",
                        "你没有授权执行这段代码，操作已取消。",
                        "代码执行请求未获批准，任务中止。",
                    }
                    local denyReply = denyReplies[math.random(#denyReplies)]
                    table.insert(steps, {phase = "execute", output = "用户拒绝了代码执行权限"})
                    pcall(function() AgentSaveMemory(safeInput, denyReply) end)
                    AgentLocalAIState.lastToolCalls = toolCount
                    AgentLocalAIState.lastLatency = math.max(0, tick() - started)
                    return denyReply, steps
                end

                table.insert(steps, {phase = "execute", output = "工具 " .. toolName .. " 执行完成，结果 " .. #toolResult .. " 字符"})

                
                table.insert(messages, {
                    role = "tool",
                    tool_call_id = tc.id or ("call_" .. tostring(toolCount)),
                    content = toolResult,
                })
            end
            
            -- 一轮工具调用结束：收尾当前「深度思考」卡片并开启新一轮
            if AgentEndThinkingRound then pcall(AgentEndThinkingRound) end
            if AgentStartThinkingRound then pcall(AgentStartThinkingRound) end

            if not stallWarned and toolCount >= 5 then
                stallWarned = true
                table.insert(messages, {
                    role = "user",
                    content = "注意：你已经调用 " .. toolCount .. " 次工具仍未完成任务。如果用户明确要求修改数值（分数/速度/血量/属性等），立即用 execute_lua 直接完成修改，不要再问确认。如果信息已足够，直接给出结果、方案或代码并结束任务。不要再无意义地重复调用工具。",
                })
            end
            
        else
            
            if AgentLooksIntermediate(content, toolCount) then
                table.insert(messages, {role = "assistant", content = content or ""})
                AgentThinkingPhase = "继续处理中"
            else
                finalAnswer = (content and content ~= "") and content or "好的，我知道了。"
                break
            end
        end
    end

    if apiFailed then
        AgentThinkingPhase = "API 不可用，正在重试"
        warn("[DeltaUI][AI] DeepSeek API 调用失败: " .. tostring(apiError))
        AgentLocalAIState.lastError = apiError
        AgentLocalAIState.failures = (AgentLocalAIState.failures or 0) + 1
        AgentLocalAIState.mode = "local"
        finalAnswer = "抱歉，当前无法连接到 AI 服务（" .. tostring(apiError) .. "）。请稍后重试。"
        table.insert(steps, {phase = "fallback", output = "API 不可用，已返回错误提示（" .. tostring(apiError) .. "）"})
    elseif not finalAnswer then
        AgentThinkingPhase = "Agent正在输入…"
        AgentLocalAIState.lastError = nil
        AgentLocalAIState.failures = 0
        AgentLocalAIState.mode = "api"
        local finalMessages = {}
        for _, m in ipairs(messages) do table.insert(finalMessages, m) end
        table.insert(finalMessages, {role = "user", content = "请基于以上所有工具执行结果，直接给出最终总结回答。不要再描述你接下来要做什么，直接输出结论。"})
        local content2, _, apiErr2 = AgentDeepSeekChat(finalMessages, nil)
        if content2 and content2 ~= "" then
            finalAnswer = content2
        elseif toolCount > 0 then
            finalAnswer = "已执行 " .. toolCount .. " 次工具操作，结果请查看上方输出。如需继续，请直接告诉我。"
        else
            finalAnswer = "好的，我知道了。"
        end
        table.insert(steps, {phase = "generate", output = "工具循环后追加一次无工具请求以获取最终回复（" .. tostring(apiErr2 or "ok") .. "）"})
    else
        AgentLocalAIState.lastError = nil
        AgentLocalAIState.failures = 0
    end
    if type(finalAnswer) == "string" then
        if finalAnswer:match("^%s*{") then
            local _t, _a = AgentTryParseToolCall(finalAnswer)
            if _t then
                finalAnswer = "好的，已处理你的请求。" .. (toolCount > 0 and ("（调用了 " .. toolCount .. " 次工具）") or "")
            end
        end
        
        if finalAnswer:find("<[%s|]-DSML", 1) or finalAnswer:find('invoke%s+name="', 1)
           or finalAnswer:find('parameter%s+name="', 1) then
            local stripped = AgentStripDSML(finalAnswer)
            
            stripped = stripped:gsub('<[^>]*DSML[^>]*>', '')
            stripped = stripped:gsub('%s*tool_calls', '')
            stripped = stripped:gsub('%s*[//]*[%s]*invoke%s*name="[^"]*"', '')
            stripped = stripped:gsub('%s*[//]*[%s]*parameter%s*name="[^"]*"', '')
            stripped = stripped:gsub('%s*[//][%s]*parameter', '')
            stripped = stripped:gsub('%s*[//][%s]*invoke', '')
            stripped = stripped:gsub('^%s+', ''):gsub('%s+$', '')
            if stripped == "" then
                finalAnswer = "好的，已处理你的请求。" .. (toolCount > 0 and ("（调用了 " .. toolCount .. " 次工具）") or "")
            else
                finalAnswer = stripped
            end
        end
    end

    AgentLocalAIState.lastToolCalls = toolCount
    AgentLocalAIState.available = true
    AgentLocalAIState.lastLatency = math.max(0, tick() - started)
    table.insert(steps, {phase = "generate", output = "DeepSeek API 生成回复（共调用 " .. toolCount .. " 次工具，模式: " .. AgentLocalAIState.mode .. "）"})

    pcall(function() AgentSaveMemory(safeInput, finalAnswer) end)
    return finalAnswer, steps
end

local AgentMainFrame = create("Frame", {
    Name = "MainFrame",
    Size = UDim2.new(1, 0, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Visible = true,
    Parent = AgentPage,
    ZIndex = 3
})
AgentResumeParent = AgentMainFrame

local AgentTitleBar = create("Frame", {
    Name = "TitleBar",
    Size = UDim2.new(1, 0, 0, 32),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = theme.surfaceLight,
    BackgroundTransparency = 0.5,
    BorderSizePixel = 0,
    Parent = AgentMainFrame,
    ZIndex = 4
})
corner(theme.radius, AgentTitleBar)
stroke(theme.border, 1, AgentTitleBar)

local AgentTitleLabel = create("TextLabel", {
    Name = "TitleLabel",
    Size = UDim2.new(1, -60, 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text = "AgentLess",
    TextColor3 = theme.textDim,
    Font = Enum.Font.SourceSansBold,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    Parent = AgentTitleBar,
    ZIndex = 5
})


AgentModelLabel = create("TextLabel", {
    Name = "ModelLabel",
    Size = UDim2.new(0, 96, 0, 20),
    Position = UDim2.new(1, -230, 0.5, -10),
    BackgroundTransparency = 1,
    Text = "DeepSeek",
    TextColor3 = theme.textDim,
    Font = Enum.Font.SourceSansBold,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Right,
    TextYAlignment = Enum.TextYAlignment.Center,
    Parent = AgentTitleBar,
    ZIndex = 5
})
do
    local _m = AGENT_PROVIDERS[AgentLocalAIConfig.activeModel or "flash"]
    if _m then
        AgentModelLabel.Text = _m.label
        AgentModelLabel.TextColor3 = _m.isClaude and Color3.fromRGB(255, 200, 60) or theme.textDim
    end
end

if type(updateExternalApiUI) == "function" then
    updateExternalApiUI()
end


local AgentManageMode = false   -- 对话管理面板保留，暂时不开放入口
local AgentSettingsButton = create("TextButton", {
    Name = "SettingsButton",
    Size = UDim2.new(0, 24, 0, 24),
    Position = UDim2.new(1, -30, 0.5, -12),
    BackgroundColor3 = theme.surfaceLight,
    BackgroundTransparency = 0.4,
    BorderSizePixel = 0,
    Text = "",
    Parent = AgentTitleBar,
    ZIndex = 6
})
corner(6, AgentSettingsButton)
local AgentSettingsIcon = GetIcon("settings", UDim2.new(0, 15, 0, 15), theme.textDim)
if AgentSettingsIcon then
    AgentSettingsIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    AgentSettingsIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    AgentSettingsIcon.Parent = AgentSettingsButton
end

local AgentStatsButton = create("TextButton", {
    Name = "StatsButton",
    Size = UDim2.new(0, 24, 0, 24),
    Position = UDim2.new(1, -58, 0.5, -12),
    BackgroundColor3 = theme.surfaceLight,
    BackgroundTransparency = 0.4,
    BorderSizePixel = 0,
    Text = "",
    Parent = AgentTitleBar,
    ZIndex = 6
})
corner(6, AgentStatsButton)
local AgentStatsIcon = GetIcon("chart-pie", UDim2.new(0, 15, 0, 15), theme.textDim)
if AgentStatsIcon then
    AgentStatsIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    AgentStatsIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    AgentStatsIcon.Parent = AgentStatsButton
else
    create("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "📊",
        TextColor3 = theme.textDim or Color3.fromRGB(150, 160, 184),
        Font = Enum.Font.SourceSans,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = AgentStatsButton,
    })
end


local AgentSettingsOpen = false
local AgentSettingsUi = nil

local function AgentTween(obj, props, dur)
    local ts = svc and svc.TweenService
    if not ts then
        pcall(function() for k, v in pairs(props) do obj[k] = v end end)
        return
    end
    local ok, t = pcall(function()
        return ts:Create(obj, TweenInfo.new(dur or 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    end)
    if ok and t then pcall(function() t:Play() end) end
end

-- 分区卡片：结构完全对齐 DeltaUI 本体设置页的 addSection / makeSectionCard。
-- 分区稳定的关键：标题栏与内容区都是「卡片自身 UIListLayout 的普通子项」——
--   标题栏 LayoutOrder = -1，永远排在第一位；内容区紧随其后。
--   两者都是显式尺寸 / 自动高度，不用绝对定位，因此不会互相覆盖或错位。
local function AgentMakeCard(parent, title)
    local card = create("Frame", {
        Name = "Card_" .. tostring(title or ""),
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = theme.surfaceLight or Color3.fromRGB(30, 36, 52),
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = parent,
    })
    corner(theme.radiusLg or 18, card)
    stroke(theme.border or Color3.fromRGB(52, 62, 88), 1, card)

    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = card,
    })
    create("UIPadding", {
        PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
        PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10),
        Parent = card,
    })

    -- ① 分区标题栏：LayoutOrder = -1，固定位于卡片最顶部
    local header = create("Frame", {
        Name = "CardHeader",
        Size = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        LayoutOrder = -1,
        ZIndex = 4,
        Parent = card,
    })
    local accentBar = create("Frame", {
        Size = UDim2.new(0, 3, 0, 16),
        Position = UDim2.new(0, 2, 0.5, -8),
        BackgroundColor3 = theme.accent or Color3.fromRGB(56, 189, 248),
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = header,
    })
    corner(2, accentBar)
    pcall(function() applyGradient(accentBar, theme.accent, theme.accent2, 90) end)
    create("TextLabel", {
        Position = UDim2.new(0, 14, 0, 0),
        Size = UDim2.new(1, -20, 1, 0),
        BackgroundTransparency = 1,
        Text = tostring(title or ""),
        TextColor3 = theme.text or Color3.fromRGB(242, 245, 252),
        Font = Enum.Font.SourceSansBold,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 5,
        Parent = header,
    })

    -- ② 内容区：自动高度，排在标题栏之后
    local body = create("Frame", {
        Name = "CardBody",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = card,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = body,
    })
    return card, body
end

local function AgentMakeToggleRow(parent, label, getVal, setVal)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
        Parent = parent,
    })
    create("TextLabel", {
        Size = UDim2.new(1, -60, 1, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = theme.text or Color3.fromRGB(242, 245, 252),
        Font = Enum.Font.SourceSans,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })
    local track = create("Frame", {
        Size = UDim2.new(0, 44, 0, 22),
        Position = UDim2.new(1, -44, 0.5, -11),
        BackgroundColor3 = theme.surfaceLight or Color3.fromRGB(30, 36, 52),
        BorderSizePixel = 0,
        Parent = row,
    })
    corner(11, track)
    local knob = create("Frame", {
        Size = UDim2.new(0, 18, 0, 18),
        Position = UDim2.new(0, 2, 0.5, -9),
        BackgroundColor3 = theme.text or Color3.fromRGB(242, 245, 252),
        BorderSizePixel = 0,
        Parent = track,
    })
    corner(9, knob)
    local on = false
    local function paint()
        on = not not getVal()
        track.BackgroundColor3 = on and (theme.accent or Color3.fromRGB(56, 189, 248)) or (theme.surfaceLight or Color3.fromRGB(30, 36, 52))
        AgentTween(knob, { Position = on and UDim2.new(0, 24, 0.5, -9) or UDim2.new(0, 2, 0.5, -9) }, 0.2)
    end
    paint()
    local btn = create("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        Parent = track,
    })
    btn.MouseButton1Click:Connect(function()
        pcall(function()
            setVal(not on)
            paint()
        end)
    end)
    return row
end

local function AgentRenderWorkPlan(plan)
    if not AgentMessageFrame then return end
    local wrap = create("Frame", {
        Name = "WorkPlanCard",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = theme.surface,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = AgentMessageFrame,
    })
    corner(theme.radius or 14, wrap)
    stroke(theme.accent or Color3.fromRGB(56, 189, 248), 1, wrap)
    create("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), Parent = wrap})
    create("UIListLayout", {FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 8), Parent = wrap})
    create("TextLabel", {Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Text = "◆ 任务计划", TextColor3 = theme.accent or Color3.fromRGB(56, 189, 248), Font = Enum.Font.SourceSansBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Parent = wrap})
    if type(plan) ~= "table" then return end
    local total = 0
    local done = 0
    for i, t in ipairs(plan) do
        if type(t) ~= "table" then t = {title = tostring(t)} end
        local status = tostring(t.status or "pending")
        local prog = tonumber(t.progress) or 0
        total = total + 1
        if status == "done" then done = done + 1 end
        local bc = status == "done" and Color3.fromRGB(34, 197, 94) or (status == "in_progress" and Color3.fromRGB(56, 189, 248) or Color3.fromRGB(148, 163, 184))
        local row = create("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = wrap})
        create("UIListLayout", {FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 4), Parent = row})
        local titleRow = create("Frame", {Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Parent = row})
        create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = titleRow})
        local badge = create("TextLabel", {Size = UDim2.new(0, 78, 0, 18), BackgroundTransparency = 0.15, BackgroundColor3 = bc, Text = status == "done" and "已完成" or (status == "in_progress" and "进行中" or "待办"), TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.SourceSansBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, Parent = titleRow})
        corner(9, badge)
        create("TextLabel", {Size = UDim2.new(1, -86, 0, 18), BackgroundTransparency = 1, Text = tostring(t.title or ("任务 " .. i)), TextColor3 = theme.text or Color3.fromRGB(242, 245, 252), Font = Enum.Font.SourceSansBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = titleRow})
        local barBg = create("Frame", {Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = theme.surfaceLight or Color3.fromRGB(30, 36, 52), BorderSizePixel = 0, Parent = row})
        corner(3, barBg)
        local bar = create("Frame", {Size = UDim2.new(math.max(0, math.min(1, prog / 100)), 0, 1, 0), BackgroundColor3 = bc, BorderSizePixel = 0, Parent = barBg})
        corner(3, bar)
        create("TextLabel", {Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = tostring(prog) .. "%", TextColor3 = theme.textDim or Color3.fromRGB(150, 160, 184), Font = Enum.Font.SourceSans, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, Parent = row})
        if t.description and tostring(t.description) ~= "" then
            create("TextLabel", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Text = tostring(t.description), TextColor3 = theme.textDim or Color3.fromRGB(150, 160, 184), Font = Enum.Font.SourceSans, TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = row})
        end
        if type(t.subtasks) == "table" then
            for _, st in ipairs(t.subtasks) do
                local sd = type(st) == "table" and st or {title = tostring(st)}
                local stTxt = (sd.done and "[x] " or "[ ] ") .. tostring(sd.title or "")
                create("TextLabel", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Text = "    " .. stTxt, TextColor3 = sd.done and Color3.fromRGB(34, 197, 94) or (theme.textDim or Color3.fromRGB(150, 160, 184)), Font = Enum.Font.SourceSans, TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = row})
            end
        end
    end
    create("TextLabel", {Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = "进度总览：" .. done .. " / " .. total .. " 已完成", TextColor3 = theme.accent or Color3.fromRGB(56, 189, 248), Font = Enum.Font.SourceSansBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = wrap})
end

local function AgentShowAskCard(question, options)
    if not AgentMessageFrame then return end
    local wrap = create("Frame", {
        Name = "AskUserCard",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = theme.surface,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = AgentMessageFrame,
    })
    corner(theme.radius or 14, wrap)
    stroke(Color3.fromRGB(250, 204, 21), 1, wrap)
    create("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), Parent = wrap})
    create("UIListLayout", {FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 8), Parent = wrap})
    create("TextLabel", {Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = "● AI 提问", TextColor3 = Color3.fromRGB(250, 204, 21), Font = Enum.Font.SourceSansBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = wrap})
    create("TextLabel", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Text = tostring(question or ""), TextColor3 = theme.text or Color3.fromRGB(242, 245, 252), Font = Enum.Font.SourceSans, TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = wrap})
    local input = create("TextBox", {Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = theme.surfaceLight or Color3.fromRGB(30, 36, 52), BackgroundTransparency = 0.3, BorderColor3 = theme.border or Color3.fromRGB(52, 62, 88), BorderSizePixel = 1, TextColor3 = theme.text or Color3.fromRGB(242, 245, 252), PlaceholderText = "在此输入你的回复…", PlaceholderColor3 = theme.textDim or Color3.fromRGB(150, 160, 184), Font = Enum.Font.SourceSans, TextSize = 13, ClearTextOnFocus = false, Text = "", Parent = wrap})
    corner(8, input)
    local ip = create("UIPadding", {PaddingLeft = UDim.new(0, 10)})
    ip.Parent = input
    local sendBtn = create("TextButton", {Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = theme.accent or Color3.fromRGB(56, 189, 248), Text = "发送回复", TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 13, Font = Enum.Font.SourceSansBold, BorderSizePixel = 0, Parent = wrap})
    corner(10, sendBtn)
    applyGradient(sendBtn, theme.accent, theme.accent2, 120)
    local function doReply()
        local reply = input.Text or ""
        if reply == "" then return end
        pcall(function() wrap.Visible = false end)
        pcall(AgentAddMessage, reply, true)
        local gen = AgentGenerateResponse
        if type(gen) == "function" then pcall(gen, reply) end
    end
    sendBtn.MouseButton1Click:Connect(doReply)
    if type(options) == "table" and #options > 0 then
        local optWrap = create("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = wrap})
        create("UIListLayout", {FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 6), Parent = optWrap})
        for _, o in ipairs(options) do
            local ob = create("TextButton", {Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = theme.surfaceLight or Color3.fromRGB(30, 36, 52), BackgroundTransparency = 0.3, Text = tostring(o), TextColor3 = theme.text or Color3.fromRGB(242, 245, 252), TextSize = 12, Font = Enum.Font.SourceSans, BorderSizePixel = 0, Parent = optWrap})
            corner(8, ob)
            ob.MouseButton1Click:Connect(function()
                pcall(function() input.Text = tostring(o) end)
                doReply()
            end)
        end
    end
end

local function AgentShowToolPreview(toolDef)
    if not AgentMessageFrame then return end
    if type(toolDef) ~= "table" then return end
    local fn = toolDef["function"] or toolDef
    local name = tostring(fn.name or toolDef.name or "")
    local desc = tostring(fn.description or "")
    local params = (type(fn.parameters) == "table" and fn.parameters.properties) or nil
    local wrap = create("Frame", {
        Name = "ToolPreview_" .. name,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = theme.surface,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = AgentMessageFrame,
    })
    corner(theme.radius or 14, wrap)
    stroke(theme.border or Color3.fromRGB(52, 62, 88), 1, wrap)
    create("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), Parent = wrap})
    create("UIListLayout", {FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 8), Parent = wrap})
    local head = create("Frame", {Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Parent = wrap})
    create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = head})
    local ic = GetIcon("terminal", UDim2.new(0, 16, 0, 16), theme.textDim)
    if ic then ic.Parent = head end
    create("TextLabel", {Size = UDim2.new(1, -24, 0, 20), BackgroundTransparency = 1, Text = "◆ " .. name, TextColor3 = theme.accent or Color3.fromRGB(56, 189, 248), Font = Enum.Font.SourceSansBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = head})
    if desc ~= "" then
        create("TextLabel", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Text = desc, TextColor3 = theme.textDim or Color3.fromRGB(150, 160, 184), Font = Enum.Font.SourceSans, TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = wrap})
    end
    if type(params) == "table" then
        local plist = {}
        for k in pairs(params) do plist[#plist + 1] = k end
        if #plist > 0 then
            create("TextLabel", {Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = "参数: " .. table.concat(plist, ", "), TextColor3 = theme.text or Color3.fromRGB(242, 245, 252), Font = Enum.Font.SourceSans, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = wrap})
        end
    end
    local sample = {name = name}
    if type(params) == "table" then
        for k, v in pairs(params) do
            local t = (type(v) == "table" and v.type) or "string"
            sample[k] = (t == "number" and 0) or (t == "boolean" and true) or "示例"
        end
    end
    local sampleJson = "{}"
    pcall(function() sampleJson = svc.HttpService:JSONEncode(sample) end)
    local codeBg = create("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = theme.bg or Color3.fromRGB(7, 9, 15), BackgroundTransparency = 0.5, BorderSizePixel = 0, Parent = wrap})
    corner(8, codeBg)
    create("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = codeBg})
    create("TextLabel", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Text = "调用示例:\n" .. sampleJson, TextColor3 = Color3.fromRGB(125, 211, 252), Font = Enum.Font.SourceSans, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Parent = codeBg})
    create("TextLabel", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Text = "[模拟结果] 该工具调用后，将在此区域展示其返回数据 / 终端输出 / 文件内容等 UI。", TextColor3 = theme.textDim or Color3.fromRGB(150, 160, 184), Font = Enum.Font.SourceSans, TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = wrap})
end


local AgentDebugBar = nil
local function AgentEnsureDebugBar()
    if AgentDebugBar then return end
    local bar = create("ScrollingFrame", {
        Name = "DebugToolBar",
        Size = UDim2.new(1, -134, 0, 30),
        Position = UDim2.new(0, 122, 1, -90),
        BackgroundColor3 = theme.surfaceLight or Color3.fromRGB(30, 36, 52),
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollingDirection = Enum.ScrollingDirection.X,
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        VerticalScrollBarInset = Enum.ScrollBarInset.None,
        Parent = AgentMainFrame,
        ZIndex = 7,
        Visible = false,
    })
    corner(8, bar)
    create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = bar })
    create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = bar})
    -- 调试模式标识：明确提示当前已开启调试模式（之前纯透明条，开启后几乎看不出变化）
    create("TextLabel", {
        Size = UDim2.new(0, 38, 1, 0),
        BackgroundTransparency = 1,
        Text = "调试",
        TextColor3 = theme.accent or Color3.fromRGB(56, 189, 248),
        Font = Enum.Font.SourceSansBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = bar,
    })
    local tools = AGENT_DEEPSEEK_TOOLS or {}
    for _, td in ipairs(tools) do
        local fn = td["function"] or td
        local nm = tostring(fn.name or "")
        if nm ~= "" then
            local b = create("TextButton", {Size = UDim2.new(0, 18 + #nm * 9, 0, 22), BackgroundColor3 = theme.surface or Color3.fromRGB(18, 22, 34), BackgroundTransparency = 0.6, BorderSizePixel = 0, Text = nm, TextColor3 = theme.text or Color3.fromRGB(242, 245, 252), TextSize = 11, Font = Enum.Font.SourceSans, AutoButtonColor = false, Parent = bar})
            corner(7, b)
            b.MouseButton1Click:Connect(function()
                pcall(AgentShowToolPreview, td)
                pcall(function() if AgentMessageFrame and AgentMessageFrame.CanvasSize then AgentMessageFrame.CanvasPosition = Vector2.new(0, AgentMessageFrame.CanvasSize.Y.Offset) end end)
            end)
        end
    end
    AgentDebugBar = bar
end

local function AgentApplyDebugBar()
    AgentEnsureDebugBar()
    local on = not not AgentReadCfg().debug_mode
    pcall(function() if AgentDebugBar then AgentDebugBar.Visible = on end end)
end


local function AgentBuildProviderSection(panel)
    local card, body = AgentMakeCard(panel, "AI 服务商管理")
    -- 服务商列表容器：外部 API 未开启时收起（不展开）
    local providerBody = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = body,
    })
    create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 10), Parent = providerBody })
    local cur = (AgentLocalAIConfig and AgentLocalAIConfig.activeModel) or "flash"
    local info = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "当前服务商：" .. AgentProviderLabel(cur),
        TextColor3 = theme.textDim or Color3.fromRGB(150, 160, 184),
        Font = Enum.Font.SourceSans,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = providerBody,
    })

    create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = "预设服务商（点击左侧选择，右侧填 API Key 即可用）",
        TextColor3 = theme.text or Color3.fromRGB(242, 245, 252),
        Font = Enum.Font.SourceSans,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = providerBody,
    })

    local listFrame = create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 190),
        BackgroundColor3 = theme.surfaceLight or Color3.fromRGB(30, 36, 52),
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = theme.textDim or Color3.fromRGB(150, 160, 184),
        Parent = providerBody,
    })
    corner(8, listFrame)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 6),
        Parent = listFrame,
    })
    create("UIPadding", {
        PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
        PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
        Parent = listFrame,
    })

    local providerIds = {}
    for id, _ in pairs(AGENT_PROVIDERS) do
        providerIds[#providerIds + 1] = id
    end
    table.sort(providerIds)
    local providerButtons = {}
    for _, id in ipairs(providerIds) do
        local m = AGENT_PROVIDERS[id]
        local row = create("Frame", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            Parent = listFrame,
        })
        local sel = create("TextButton", {
            Size = UDim2.new(0, 120, 0, 26),
            Position = UDim2.new(0, 0, 0, 2),
            BackgroundColor3 = (cur == id) and (theme.accent or Color3.fromRGB(56, 189, 248)) or (theme.surfaceLight or Color3.fromRGB(30, 36, 52)),
            BackgroundTransparency = (cur == id) and 0 or 0.3,
            BorderSizePixel = 0,
            Text = (m and m.label) or id,
            TextColor3 = (cur == id) and Color3.fromRGB(255, 255, 255) or (theme.text or Color3.fromRGB(242, 245, 252)),
            Font = Enum.Font.SourceSans,
            TextSize = 11,
            Parent = row,
        })
        corner(8, sel)
        local keyBox = create("TextBox", {
            Size = UDim2.new(1, -188, 0, 26),
            Position = UDim2.new(0, 126, 0, 2),
            BackgroundColor3 = theme.surfaceLight or Color3.fromRGB(30, 36, 52),
            BackgroundTransparency = 0.3,
            BorderColor3 = theme.border or Color3.fromRGB(52, 62, 88),
            BorderSizePixel = 1,
            Text = (m and m.apiKey) or "",
            PlaceholderText = "填你的 API Key",
            PlaceholderColor3 = theme.textDim or Color3.fromRGB(150, 160, 184),
            TextColor3 = theme.text or Color3.fromRGB(242, 245, 252),
            Font = Enum.Font.SourceSans,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            Parent = row,
        })
        corner(6, keyBox)
        create("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = keyBox })
        local fetchBtn = create("TextButton", {
            Size = UDim2.new(0, 60, 0, 26),
            Position = UDim2.new(1, -60, 0, 2),
            BackgroundColor3 = theme.surface or Color3.fromRGB(22, 27, 40),
            BackgroundTransparency = 0.3,
            BorderSizePixel = 0,
            Text = "拉取",
            TextColor3 = theme.text or Color3.fromRGB(242, 245, 252),
            Font = Enum.Font.SourceSans,
            TextSize = 11,
            Parent = row,
        })
        corner(6, fetchBtn)
        sel.MouseButton1Click:Connect(function()
            pcall(function()
                AgentApplyModel(id)
                for _, b in ipairs(providerButtons) do
                    b.BackgroundColor3 = theme.surfaceLight or Color3.fromRGB(30, 36, 52)
                    b.BackgroundTransparency = 0.3
                    b.TextColor3 = theme.text or Color3.fromRGB(242, 245, 252)
                end
                sel.BackgroundColor3 = theme.accent or Color3.fromRGB(56, 189, 248)
                sel.BackgroundTransparency = 0
                sel.TextColor3 = Color3.fromRGB(255, 255, 255)
                info.Text = "当前服务商：" .. AgentProviderLabel(id)
                AgentRefreshPresetModels(id)
                AgentRefreshThinkingControl()
            end)
        end)
        fetchBtn.MouseButton1Click:Connect(function()
            pcall(AgentFetchPresetModels, id)
        end)
        keyBox.FocusLost:Connect(function()
            pcall(function()
                local key = keyBox.Text or ""
                if AGENT_PROVIDERS[id] then AGENT_PROVIDERS[id].apiKey = key end
                AgentPersistProviderKey(id, key)
                if AgentLocalAIConfig.activeModel == id then
                    AgentLocalAIConfig.apiKey = key
                end
            end)
        end)
        providerButtons[#providerButtons + 1] = sel
    end

    -- ===== 预设服务商模型列表（选择服务商后自动加载 / 点「拉取」刷新）=====
    -- 未拉取到模型列表时不显示该区域（presetArea.Visible 由刷新逻辑控制）
    local presetArea = create("Frame", {
        Name = "PresetModelArea",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = providerBody,
        Visible = false,
    })
    AgentUI.presetArea = presetArea
    create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 6), Parent = presetArea })
    create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = "预设模型列表（选择服务商后自动加载，或点右侧「拉取」）",
        TextColor3 = theme.text or Color3.fromRGB(242, 245, 252),
        Font = Enum.Font.SourceSans,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = presetArea,
    })
    AgentUI.presetStatus = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = theme.textDim or Color3.fromRGB(150, 160, 184),
        Font = Enum.Font.SourceSans,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = presetArea,
    })
    AgentUI.presetFrame = create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 130),
        BackgroundColor3 = theme.surfaceLight or Color3.fromRGB(30, 36, 52),
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = theme.textDim or Color3.fromRGB(150, 160, 184),
        Parent = presetArea,
        Visible = true,
    })
    corner(8, AgentUI.presetFrame)
    create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 5), Parent = AgentUI.presetFrame })
    create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = AgentUI.presetFrame })

    -- ===== 自定义服务商 =====
    create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 16),
        BackgroundTransparency = 1,
        Text = "自定义服务商（填 BaseURL + API Key，自动拉取模型列表）",
        TextColor3 = theme.text or Color3.fromRGB(242, 245, 252),
        Font = Enum.Font.SourceSans,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = providerBody,
    })
    local savedCfg = AgentReadCfg()
    local baseBox = create("TextBox", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = theme.surfaceLight or Color3.fromRGB(30, 36, 52),
        BackgroundTransparency = 0.3,
        BorderColor3 = theme.border or Color3.fromRGB(52, 62, 88),
        BorderSizePixel = 1,
        Text = tostring(savedCfg.customBaseUrl or ""),
        PlaceholderText = "BaseURL，例如 https://api.moonshot.cn/v1",
        PlaceholderColor3 = theme.textDim or Color3.fromRGB(150, 160, 184),
        TextColor3 = theme.text or Color3.fromRGB(242, 245, 252),
        Font = Enum.Font.SourceSans,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Parent = providerBody,
    })
    corner(6, baseBox)
    create("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = baseBox })
    local keyBoxC = create("TextBox", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = theme.surfaceLight or Color3.fromRGB(30, 36, 52),
        BackgroundTransparency = 0.3,
        BorderColor3 = theme.border or Color3.fromRGB(52, 62, 88),
        BorderSizePixel = 1,
        Text = tostring(savedCfg.customApiKey or ""),
        PlaceholderText = "API Key",
        PlaceholderColor3 = theme.textDim or Color3.fromRGB(150, 160, 184),
        TextColor3 = theme.text or Color3.fromRGB(242, 245, 252),
        Font = Enum.Font.SourceSans,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Parent = providerBody,
    })
    corner(6, keyBoxC)
    create("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = keyBoxC })

    local fetchBtn = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = theme.accent or Color3.fromRGB(56, 189, 248),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Text = "拉取模型列表",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.SourceSansBold,
        TextSize = 13,
        Parent = providerBody,
    })
    corner(8, fetchBtn)
    local statusLabel = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = theme.textDim or Color3.fromRGB(150, 160, 184),
        Font = Enum.Font.SourceSans,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = providerBody,
    })
    local modelList = create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 150),
        BackgroundColor3 = theme.surfaceLight or Color3.fromRGB(30, 36, 52),
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = theme.textDim or Color3.fromRGB(150, 160, 184),
        Parent = providerBody,
        Visible = false,
    })
    corner(8, modelList)
    create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 5), Parent = modelList })
    create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = modelList })

    local function refreshCustomHighlight()
        pcall(function()
            for _, c in ipairs(modelList:GetChildren()) do
                if c:IsA("TextButton") then
                    local active = (c.Name == "M_" .. tostring(AgentLocalAIConfig.customActiveModel or ""))
                    c.BackgroundColor3 = active and (theme.accent or Color3.fromRGB(56, 189, 248)) or (theme.surface or Color3.fromRGB(22, 27, 40))
                    c.BackgroundTransparency = active and 0 or 0.3
                    c.TextColor3 = active and Color3.fromRGB(255, 255, 255) or (theme.text or Color3.fromRGB(242, 245, 252))
                end
            end
        end)
    end

    fetchBtn.MouseButton1Click:Connect(function()
        pcall(function()
            local base = baseBox.Text or ""
            local key = keyBoxC.Text or ""
            statusLabel.Text = "正在拉取模型列表..."
            statusLabel.TextColor3 = theme.textDim or Color3.fromRGB(150, 160, 184)
            if type(loadConfig) == "function" and type(saveConfig) == "function" then
                pcall(function()
                    local cfg = loadConfig()
                    cfg.customBaseUrl = base
                    cfg.customApiKey = key
                    saveConfig(cfg)
                end)
            end
            local okF, a, b = pcall(AgentFetchModels, base, key)
            if not okF then
                statusLabel.Text = "拉取异常: " .. tostring(a)
                statusLabel.TextColor3 = theme.red or Color3.fromRGB(255, 82, 104)
                return
            end
            if a == false then
                statusLabel.Text = "拉取失败: " .. tostring(b)
                statusLabel.TextColor3 = theme.red or Color3.fromRGB(255, 82, 104)
                return
            end
            local models = b
            if type(models) ~= "table" or #models == 0 then
                statusLabel.Text = "未获取到模型"
                statusLabel.TextColor3 = theme.red or Color3.fromRGB(255, 82, 104)
                return
            end
            for _, c in ipairs(modelList:GetChildren()) do
                if c:IsA("TextButton") then c:Destroy() end
            end
            for _, mid in ipairs(models) do
                local mb = create("TextButton", {
                    Name = "M_" .. tostring(mid),
                    Size = UDim2.new(1, 0, 0, 26),
                    BackgroundColor3 = theme.surface or Color3.fromRGB(22, 27, 40),
                    BackgroundTransparency = 0.3,
                    BorderSizePixel = 0,
                    Text = tostring(mid),
                    TextColor3 = theme.text or Color3.fromRGB(242, 245, 252),
                    Font = Enum.Font.SourceSans,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = modelList,
                })
                corner(6, mb)
                create("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = mb })
                mb.MouseButton1Click:Connect(function()
                    pcall(function()
                        local okA, ca, cb = pcall(AgentApplyCustomProvider, base, key, mid)
                        if not okA then
                            statusLabel.Text = "应用异常: " .. tostring(ca)
                            statusLabel.TextColor3 = theme.red or Color3.fromRGB(255, 82, 104)
                            return
                        end
                        if ca == false then
                            statusLabel.Text = "应用失败: " .. tostring(cb)
                            statusLabel.TextColor3 = theme.red or Color3.fromRGB(255, 82, 104)
                            return
                        end
                        info.Text = "当前服务商：" .. AgentProviderLabel("custom")
                        refreshCustomHighlight()
                        statusLabel.Text = "已应用自定义模型：" .. tostring(mid)
                        statusLabel.TextColor3 = theme.accent or Color3.fromRGB(56, 189, 248)
                        AgentRefreshThinkingControl()
                    end)
                end)
            end
            -- 尚无选中模型时，以拉取到的第一个模型作为默认（来源是 API，非内置）
            if not (AgentLocalAIConfig.customActiveModel) and models[1] then
                local first = tostring(models[1])
                AgentLocalAIConfig.customActiveModel = first
                AgentLocalAIConfig.model = first
                if type(loadConfig) == "function" and type(saveConfig) == "function" then
                    pcall(function()
                        local cfg = loadConfig()
                        cfg.customActiveModel = first
                        saveConfig(cfg)
                    end)
                end
                info.Text = "当前服务商：" .. AgentProviderLabel("custom")
                statusLabel.Text = "已应用自定义模型：" .. first
                statusLabel.TextColor3 = theme.accent or Color3.fromRGB(56, 189, 248)
            end
            modelList.Visible = true
            refreshCustomHighlight()
            statusLabel.Text = "已拉取 " .. tostring(#models) .. " 个模型，点击选择"
            statusLabel.TextColor3 = theme.accent or Color3.fromRGB(56, 189, 248)
        end)
    end)

    pcall(function()
        if AgentLocalAIConfig.activeModel == "custom" and AgentLocalAIConfig.customActiveModel then
            modelList.Visible = true
            local mb = create("TextButton", {
                Name = "M_" .. tostring(AgentLocalAIConfig.customActiveModel),
                Size = UDim2.new(1, 0, 0, 26),
                BackgroundColor3 = theme.accent or Color3.fromRGB(56, 189, 248),
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                Text = "当前：" .. tostring(AgentLocalAIConfig.customActiveModel),
                TextColor3 = Color3.fromRGB(255, 255, 255),
                Font = Enum.Font.SourceSans,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = modelList,
            })
            corner(6, mb)
            create("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = mb })
            mb.MouseButton1Click:Connect(function()
                pcall(function()
                    local okA, ca = pcall(AgentApplyCustomProvider, savedCfg.customBaseUrl or baseBox.Text, savedCfg.customApiKey or keyBoxC.Text, AgentLocalAIConfig.customActiveModel)
                    if okA and ca ~= false then
                        statusLabel.Text = "已应用：" .. tostring(AgentLocalAIConfig.customActiveModel)
                        statusLabel.TextColor3 = theme.accent or Color3.fromRGB(56, 189, 248)
                        AgentRefreshThinkingControl()
                    end
                end)
            end)
        end
    end)

    -- ===== 思考级别切换 =====
    do
        local thinkCard, thinkBody = AgentMakeCard(providerBody, "思考级别")
        create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundTransparency = 1,
            Text = "支持的模型可切换 低 / 中 / 高 思考级别；不支持的模型将提示「当前模型不支持该操作」",
            TextColor3 = theme.textDim or Color3.fromRGB(150, 160, 184),
            Font = Enum.Font.SourceSans,
            TextSize = 11,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = thinkBody,
        })
        AgentUI.thinkFrame = create("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Parent = thinkBody,
        })
        create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 6), Parent = AgentUI.thinkFrame })
    end

    AgentMakeToggleRow(body, "启用外部 API", function() return AgentReadCfg().useExternalApi == true end,
        function(v) AgentWriteCfg("useExternalApi", v); if providerBody then providerBody.Visible = v end; pcall(updateExternalApiUI, v) end)

    -- 初始化：恢复当前服务商的模型列表与思考级别控件
    pcall(AgentRefreshPresetModels, cur)
    pcall(AgentRefreshThinkingControl)
    -- 外部 API 未开启时收起服务商列表（不展开）
    if providerBody then providerBody.Visible = (AgentReadCfg().useExternalApi == true) end
    return card
end

local function AgentBuildMemorySection(panel)
    local card, body = AgentMakeCard(panel, "全局记忆管理")
    local okDb, db = pcall(AgentLoadMemoryDB)
    db = (okDb and type(db) == "table") and db or {}
    local count = #db
    local cats = {}
    for _, m in ipairs(db) do if m and m.category then cats[m.category] = true end end
    local catCount = 0
    for _ in pairs(cats) do catCount = catCount + 1 end
    local stat = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        Text = "已存储记忆：" .. count .. " 条    分类：" .. catCount .. " 类\n全局记忆用于让 AI 记住你的偏好与上下文",
        TextColor3 = theme.textDim or Color3.fromRGB(150, 160, 184),
        Font = Enum.Font.SourceSans,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = body,
    })
    local clearBtn = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = theme.red or Color3.fromRGB(255, 82, 104),
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Text = "清空全部全局记忆",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.SourceSansBold,
        TextSize = 13,
        Parent = body,
    })
    corner(8, clearBtn)
    local confirming = false
    clearBtn.MouseButton1Click:Connect(function()
        pcall(function()
            if not confirming then
                confirming = true
                clearBtn.Text = "再次点击确认清空（不可恢复）"
                task.delay(3, function()
                    confirming = false
                    pcall(function() clearBtn.Text = "清空全部全局记忆" end)
                end)
                return
            end
            confirming = false
            AgentMemoryCache = {}
            AgentMemoryDirty = true
            pcall(AgentSaveMemoryDB)
            clearBtn.Text = "已清空"
            stat.Text = "已存储记忆：0 条    分类：0 类\n全局记忆用于让 AI 记住你的偏好与上下文"
            pcall(ShowNotification, "已清空全局记忆", 2)
            task.delay(1.5, function() pcall(function() clearBtn.Text = "清空全部全局记忆" end) end)
        end)
    end)
    return card
end

local function AgentBuildGeneralSection(panel)
    local card, body = AgentMakeCard(panel, "通用")
    AgentMakeToggleRow(body, "调试模式", function() return AgentReadCfg().debug_mode == true end,
        function(v) AgentWriteCfg("debug_mode", v); AgentApplyDebugBar() end)
    create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        Text = "AgentLess 官方页面 · 版本 1.0.0",
        TextColor3 = theme.textDim or Color3.fromRGB(150, 160, 184),
        Font = Enum.Font.SourceSans,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = body,
    })
    return card
end

-- 用两个旋转 Frame 绘制 Lucide 风格 X 图标（避免依赖字体字形，渲染稳定）
local function AgentMakeLucideX(parent, size, color)
    local len = size * 0.62
    local thick = math.max(2, math.floor(size * 0.12))
    local base = {
        BorderSizePixel = 0,
        BackgroundColor3 = color,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Parent = parent,
    }
    local a = create("Frame", base)
    a.Size = UDim2.new(0, thick, 0, len)
    a.Rotation = 45
    corner(thick / 2, a)
    local b = create("Frame", base)
    b.Size = UDim2.new(0, thick, 0, len)
    b.Rotation = -45
    corner(thick / 2, b)
    return a, b
end

local function AgentEnsureSettingsUI()
    if AgentSettingsUi then return end
    local scrim = create("TextButton", {
        Name = "SettingsScrim",
        Size = UDim2.new(1, 0, 1, -52),
        Position = UDim2.new(0, 0, 0, 52),
        BackgroundColor3 = theme.bg or Color3.fromRGB(7, 9, 15),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Parent = AgentMainFrame,
        ZIndex = 8,
        Visible = false,
    })
    local panel = create("ScrollingFrame", {
        Name = "SettingsPanel",
        Size = UDim2.new(1, -24, 1, -52 - 16),
        Position = UDim2.new(0, 12, 0, 52 + 8),
        BackgroundColor3 = theme.surface or Color3.fromRGB(18, 22, 34),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = theme.textDim or Color3.fromRGB(150, 160, 184),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Parent = AgentMainFrame,
        ZIndex = 9,
        Visible = false,
    })
    corner(theme.radius or 14, panel)
    stroke(theme.border or Color3.fromRGB(52, 62, 88), 1, panel)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 10),
        Parent = panel,
    })
    create("UIPadding", {
        PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12),
        Parent = panel,
    })
    pcall(AgentBuildProviderSection, panel)
    pcall(AgentBuildMemorySection, panel)
    pcall(AgentBuildGeneralSection, panel)
    local closeBtn = create("TextButton", {
        Name = "SettingsCloseButton",
        Size = UDim2.new(0, 32, 0, 32),
        Position = UDim2.new(1, -44, 0, 60),
        BackgroundColor3 = theme.surfaceLight or Color3.fromRGB(30, 36, 52),
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        Text = "",
        Parent = AgentMainFrame,
        ZIndex = 12,
        Visible = false,
    })
    corner(6, closeBtn)
    AgentMakeLucideX(closeBtn, 16, theme.text or Color3.fromRGB(242, 245, 252))
    scrim.MouseButton1Click:Connect(function() pcall(AgentCloseSettings) end)
    closeBtn.MouseButton1Click:Connect(function() pcall(AgentCloseSettings) end)
    AgentSettingsUi = { scrim = scrim, panel = panel, closeBtn = closeBtn }
end

local function AgentOpenSettings()
    if AgentSettingsOpen then AgentCloseSettings(); return end
    AgentEnsureSettingsUI()
    AgentSettingsOpen = true
    pcall(function() AgentTitleLabel.Text = "设置" end)
    pcall(function() AgentSettingsUi.scrim.Visible = true end)
    pcall(function() AgentSettingsUi.panel.Visible = true end)
    pcall(function() if AgentSettingsUi.closeBtn then AgentSettingsUi.closeBtn.Visible = true end end)
    AgentTween(AgentSettingsUi.scrim, { BackgroundTransparency = 0.6 }, 0.3)
    AgentTween(AgentSettingsUi.panel, { BackgroundTransparency = 0 }, 0.3)
    pcall(function() AgentMessageFrame.Visible = false end)
    pcall(function() AgentInputFrame.Visible = false end)
end

local function AgentCloseSettings()
    AgentSettingsOpen = false
    pcall(function() AgentTitleLabel.Text = "AgentLess" end)
    if AgentSettingsUi then
        -- 立即停止 scrim 拦截输入，避免淡出期间点不掉
        pcall(function() AgentSettingsUi.scrim.Active = false end)
        AgentTween(AgentSettingsUi.scrim, { BackgroundTransparency = 1 }, 0.25)
        AgentTween(AgentSettingsUi.panel, { BackgroundTransparency = 1 }, 0.25)
    end
    pcall(function() AgentMessageFrame.Visible = true end)
    pcall(function() AgentInputFrame.Visible = true end)
    task.delay(0.3, function()
        pcall(function()
            if (not AgentSettingsOpen) and AgentSettingsUi then
                AgentSettingsUi.scrim.Visible = false
                AgentSettingsUi.panel.Visible = false
                if AgentSettingsUi.closeBtn then AgentSettingsUi.closeBtn.Visible = false end
            end
        end)
    end)
end

pcall(function()
local AgentStatsUi = nil
local AgentStatsOpen = false

local function AgentComputeContext()
    local hist = AgentChatMemory and AgentChatMemory.conversationHistory
    local msgs, chars = 0, 0
    if type(hist) == "table" then
        for _, m in ipairs(hist) do
            msgs = msgs + 1
            local c = m and m.content
            if type(c) == "string" then
                chars = chars + #c
            elseif type(c) == "table" then
                for _, part in ipairs(c) do
                    if type(part) == "table" then
                        chars = chars + #tostring(part.text or part.content or "")
                    else
                        chars = chars + #tostring(part)
                    end
                end
            end
        end
    end
    return msgs, chars
end

local function AgentFormatDuration(sec)
    sec = math.max(0, math.floor(sec or 0))
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    if h > 0 then return string.format("%d时%d分%d秒", h, m, s) end
    if m > 0 then return string.format("%d分%d秒", m, s) end
    return string.format("%d秒", s)
end

local function AgentMakeStatRow(parent, label, valueText)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = theme.surfaceLight or Color3.fromRGB(30, 36, 52),
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Parent = parent,
    })
    corner(8, row)
    create("TextLabel", {
        Size = UDim2.new(1, -24, 0, 16),
        Position = UDim2.new(0, 12, 0, 6),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = theme.textDim or Color3.fromRGB(150, 160, 184),
        Font = Enum.Font.SourceSans,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })
    local val = create("TextLabel", {
        Size = UDim2.new(1, -24, 0, 18),
        Position = UDim2.new(0, 12, 0, 22),
        BackgroundTransparency = 1,
        Text = valueText,
        TextColor3 = theme.accent or Color3.fromRGB(56, 189, 248),
        Font = Enum.Font.SourceSansBold,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = row,
    })
    return row, val
end

local function AgentEnsureStatsUI()
    if AgentStatsUi then return end
    local panelW = 300
    local scrim = create("TextButton", {
        Name = "StatsScrim",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        Parent = AgentMainFrame,
        ZIndex = 10,
        Visible = false,
    })
    local panel = create("Frame", {
        Name = "StatsPanel",
        Size = UDim2.new(0, panelW, 1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = theme.surface or Color3.fromRGB(18, 22, 34),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = AgentMainFrame,
        ZIndex = 11,
        Visible = false,
    })
    corner(theme.radius or 14, panel)
    stroke(theme.border or Color3.fromRGB(52, 62, 88), 1, panel)
    local header = create("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundTransparency = 1,
        Parent = panel,
    })
    create("TextLabel", {
        Size = UDim2.new(1, -48, 1, 0),
        Position = UDim2.new(0, 14, 0, 0),
        BackgroundTransparency = 1,
        Text = "运行数据",
        TextColor3 = theme.text or Color3.fromRGB(242, 245, 252),
        Font = Enum.Font.SourceSansBold,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header,
    })
    local closeBtn = create("TextButton", {
        Name = "StatsCloseButton",
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -40, 0, 7),
        BackgroundColor3 = theme.surfaceLight or Color3.fromRGB(30, 36, 52),
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Text = "",
        Parent = header,
        ZIndex = 12,
    })
    corner(6, closeBtn)
    AgentMakeLucideX(closeBtn, 15, theme.text or Color3.fromRGB(242, 245, 252))
    local list = create("Frame", {
        Size = UDim2.new(1, 0, 1, -52),
        Position = UDim2.new(0, 0, 0, 48),
        BackgroundTransparency = 1,
        Parent = panel,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, 8),
        Parent = list,
    })
    create("UIPadding", {
        PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 12),
        Parent = list,
    })
    local rows = {}
    rows.tokens, rows.tokensVal = AgentMakeStatRow(list, "消耗的 Token", "0")
    rows.commands, rows.commandsVal = AgentMakeStatRow(list, "执行的命令（次数）", "0")
    rows.files, rows.filesVal = AgentMakeStatRow(list, "创建/写入文件（数量）", "0")
    rows.time, rows.timeVal = AgentMakeStatRow(list, "任务总耗时", "0")
    rows.context, rows.contextVal = AgentMakeStatRow(list, "对话上下文长度", "0")
    AgentStatsUi = { scrim = scrim, panel = panel, closeBtn = closeBtn, rows = rows, panelW = panelW }
    scrim.MouseButton1Click:Connect(function() pcall(AgentCloseStats) end)
    closeBtn.MouseButton1Click:Connect(function() pcall(AgentCloseStats) end)
end

local function AgentRefreshStats()
    if not AgentStatsUi then return end
    local r = AgentStatsUi.rows
    pcall(function() r.tokensVal.Text = tostring(math.floor(AgentTotalTokens or 0)) end)
    pcall(function() r.commandsVal.Text = tostring(AgentMetrics and AgentMetrics.toolCalls or 0) end)
    pcall(function() r.filesVal.Text = tostring(AgentMetrics and AgentMetrics.fileOperations or 0) end)
    pcall(function() r.timeVal.Text = AgentFormatDuration(AgentWorkElapsed()) end)
    pcall(function()
        local msgs, chars = AgentComputeContext()
        r.contextVal.Text = tostring(chars) .. " 字符 / " .. tostring(msgs) .. " 条"
    end)
end

local function AgentOpenStats()
    if AgentStatsOpen then AgentCloseStats(); return end
    AgentEnsureStatsUI()
    AgentStatsOpen = true
    pcall(AgentRefreshStats)
    pcall(function()
        -- 从右侧滑入：先置于屏幕外并设为可见，再 tween 到目标位置
        AgentStatsUi.scrim.Visible = true
        AgentStatsUi.scrim.Active = true
        AgentStatsUi.panel.Visible = true
        AgentStatsUi.panel.Position = UDim2.new(1, 0, 0, 0)
    end)
    AgentTween(AgentStatsUi.scrim, { BackgroundTransparency = 0.5 }, 0.3)
    AgentTween(AgentStatsUi.panel, { BackgroundTransparency = 0 }, 0.3)
    AgentTween(AgentStatsUi.panel, { Position = UDim2.new(1, -AgentStatsUi.panelW, 0, 0) }, 0.3)
end

local function AgentCloseStats()
    AgentStatsOpen = false
    if not AgentStatsUi then return end
    -- 立即让面板不再拦截输入 / 不可见，避免 tween 未执行时“关不掉”
    pcall(function()
        AgentStatsUi.scrim.Active = false
        AgentStatsUi.scrim.Visible = false
        AgentStatsUi.panel.Visible = false
        AgentStatsUi.panel.Position = UDim2.new(1, 0, 0, 0)
        AgentStatsUi.panel.BackgroundTransparency = 1
    end)
    -- 再做一次淡出/滑出（若 TweenService 不可用，上面的直接赋值已保证关闭）
    AgentTween(AgentStatsUi.scrim, { BackgroundTransparency = 1 }, 0.28)
    AgentTween(AgentStatsUi.panel, { Position = UDim2.new(1, 0, 0, 0) }, 0.28)
    AgentTween(AgentStatsUi.panel, { BackgroundTransparency = 1 }, 0.28)
    task.delay(0.3, function()
        pcall(function()
            if (not AgentStatsOpen) and AgentStatsUi then
                AgentStatsUi.scrim.Visible = false
                AgentStatsUi.panel.Visible = false
            end
        end)
    end)
end

pcall(function()
    if AgentStatsButton then
        AgentStatsButton.MouseButton1Click:Connect(function()
            pcall(AgentOpenStats)
        end)
    end
end)


    AgentSettingsButton.MouseButton1Click:Connect(function()
        pcall(AgentOpenSettings)
    end)
end)




task.spawn(function()
    task.wait(1.0)
    local loader = _G.__DeltaAI_loadRemoteModels
    if type(loader) == "function" then pcall(loader) end
end)

AgentMessageFrame = create("ScrollingFrame", {
    Name = "MessageFrame",
    Size = UDim2.new(1, -20, 1, -48 - 56 - 8),
    Position = UDim2.new(0, 10, 0, 52),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = theme.textDim,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    Parent = AgentMainFrame,
    ZIndex = 3
})

local AgentMessageListLayout = create("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment = Enum.VerticalAlignment.Top,
    Padding = UDim.new(0, 6),
    Parent = AgentMessageFrame
})

local AgentMessagePadding = create("UIPadding", {
    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6),
    PaddingTop = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),
    Parent = AgentMessageFrame
})

AgentMessageListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    if AgentMessageFrame and AgentMessageFrame.Parent then
        AgentMessageFrame.CanvasSize = UDim2.new(0, 0, 0, AgentMessageListLayout.AbsoluteContentSize.Y + 12)
    end
end)

local AgentInputFrame = create("Frame", {
    Name = "InputFrame",
    Size = UDim2.new(1, -20, 0, 44),
    Position = UDim2.new(0, 10, 1, -54),
    BackgroundColor3 = theme.surface,
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    Parent = AgentMainFrame,
    ZIndex = 4
})
corner(12, AgentInputFrame)

AgentInputBox = create("TextBox", {
    Name = "InputBox",
    Size = UDim2.new(1, -70, 1, -8),
    Position = UDim2.new(0, 8, 0, 4),
    BackgroundColor3 = theme.surfaceLight,
    BackgroundTransparency = 0.3,
    BorderColor3 = theme.border,
    BorderSizePixel = 1,
    TextColor3 = theme.text,
    PlaceholderText = "输入问题、指令或闲聊...",
    PlaceholderColor3 = theme.textDim,
    Font = Enum.Font.SourceSans,
    TextSize = 14,
    ClearTextOnFocus = false,
    Text = "",
    Parent = AgentInputFrame,
    ZIndex = 5
})
corner(20, AgentInputBox)
create("UIPadding", {PaddingLeft = UDim.new(0, 12)}).Parent = AgentInputBox
AgentInputBox.Focused:Connect(function()
    if AgentInputBox.Text == "" then
        AgentInputBox.PlaceholderText = "输入问题、指令或闲聊..."
    end
end)
AgentInputBox.FocusLost:Connect(function()
    if AgentInputBox.Text == "" then
        AgentInputBox.PlaceholderText = "输入问题、指令或闲聊..."
    end
end)

AgentSendButton = create("TextButton", {
    Name = "SendButton",
    Size = UDim2.new(0, 52, 0, 32),
    Position = UDim2.new(1, -58, 0.5, -16),
    BackgroundColor3 = theme.accent,
    Text = "",
    BorderSizePixel = 0,
    Parent = AgentInputFrame,
    ZIndex = 5
})
applyGradient(AgentSendButton, theme.accent, theme.accent2, 120)
corner(16, AgentSendButton)
-- 文字覆盖层：置于渐变图层之上，避免被渐变 ImageLabel 遮挡
create("TextLabel", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "发送",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 13,
    Font = Enum.Font.SourceSansBold,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 6,
    Parent = AgentSendButton,
})


-- ===== 深度思考开关（胶囊按钮，位于输入框栏上方最左侧）=====
AgentDeepThinkingEnabled = not AgentLocalAIConfig.thinkingDisabled

local AgentThinkPill = create("TextButton", {
    Name = "DeepThinkingPill",
    Size = UDim2.new(0, 106, 0, 26),
    Position = UDim2.new(0, 10, 1, -86),
    BackgroundColor3 = theme.surfaceLight,
    BackgroundTransparency = 0.45,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    Parent = AgentMainFrame,
    ZIndex = 6
})
corner(13, AgentThinkPill)   -- 13 = 高度一半，胶囊形

local AgentThinkStroke = stroke(theme.border, 1, AgentThinkPill)
local AgentThinkGradient = applyGradient(AgentThinkPill, theme.accent, theme.accent2, 120)
if AgentThinkGradient then AgentThinkGradient.Enabled = false end

local AgentThinkIcon = GetIcon("atom", UDim2.new(0, 14, 0, 14), theme.textDim)
if AgentThinkIcon then
    AgentThinkIcon.Position = UDim2.new(0, 10, 0.5, -7)
    AgentThinkIcon.Parent = AgentThinkPill
end

local AgentThinkText = create("TextLabel", {
    Position = UDim2.new(0, 29, 0, 0),
    Size = UDim2.new(1, -34, 1, 0),
    BackgroundTransparency = 1,
    Text = "深度思考",
    TextColor3 = theme.textDim,
    Font = Enum.Font.SourceSansBold,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    Parent = AgentThinkPill,
    ZIndex = 7
})

AgentApplyThinkPill = function(state)
    AgentDeepThinkingEnabled = state and true or false
    if AgentThinkGradient then AgentThinkGradient.Enabled = AgentDeepThinkingEnabled end
    AgentThinkPill.BackgroundColor3 = AgentDeepThinkingEnabled and Color3.fromRGB(255, 255, 255) or theme.surfaceLight
    AgentThinkPill.BackgroundTransparency = AgentDeepThinkingEnabled and 0 or 0.45
    if AgentThinkStroke then
        AgentThinkStroke.Color = AgentDeepThinkingEnabled and theme.accent or theme.border
        AgentThinkStroke.Transparency = AgentDeepThinkingEnabled and 0.1 or 0.4
    end
    if AgentThinkIcon then
        AgentThinkIcon.ImageColor3 = AgentDeepThinkingEnabled and Color3.fromRGB(255, 255, 255) or theme.textDim
    end
    AgentThinkText.TextColor3 = AgentDeepThinkingEnabled and Color3.fromRGB(255, 255, 255) or theme.textDim
    return AgentDeepThinkingEnabled
end

AgentApplyThinkPill(AgentDeepThinkingEnabled)

AgentApplyDebugBar()

-- 供设置卡等外部开关同步胶囊状态
_G.__DeltaAI_updateThinkPill = AgentApplyThinkPill

AgentThinkPill.MouseButton1Click:Connect(function()
    local nextState = not AgentDeepThinkingEnabled
    AgentApplyThinkPill(nextState)

    local setter = _G.__DeltaAI_setThinkingMode
    if type(setter) == "function" then pcall(setter, nextState) end

    if type(loadConfig) == "function" and type(saveConfig) == "function" then
        pcall(function()
            local cfg = loadConfig()
            cfg.thinkingMode = nextState
            saveConfig(cfg)
        end)
    end

    if type(ShowNotification) == "function" then
        ShowNotification(nextState and "已开启深度思考" or "已关闭深度思考", 1.2)
    end
end)


local AgentManageFrame = create("ScrollingFrame", {
    Name = "ManageFrame",
    Size = UDim2.new(1, -20, 1, -44),
    Position = UDim2.new(0, 10, 0, 34),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = theme.textDim,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    Visible = false,
    Parent = AgentMainFrame,
    ZIndex = 3
})
local AgentManageLayout = create("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Top,
    Padding = UDim.new(0, 8),
    Parent = AgentManageFrame
})
create("UIPadding", {
    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6),
    PaddingTop = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),
    Parent = AgentManageFrame
})
AgentManageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    if AgentManageFrame and AgentManageFrame.Parent then
        AgentManageFrame.CanvasSize = UDim2.new(0, 0, 0, AgentManageLayout.AbsoluteContentSize.Y + 12)
    end
end)


local AgentRefreshConversationList
local AgentSetManageMode


local function AgentLoadConversationEntry(entry)
    local ok = AgentLoadChatHistory({path = entry.path, chatFile = entry.file, name = entry.name})
    if not ok then return end
    AgentCurrentSession.isFirstRound = false
    for _, child in ipairs(AgentMessageFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name == "MessageContainer" then child:Destroy() end
    end
    local history = AgentChatMemory.conversationHistory or {}
    for _, msg in ipairs(history) do
        AgentAddMessage(msg.content, msg.role == "user")
        task.wait(0.04)
    end
end


AgentRefreshConversationList = function()
    for _, child in ipairs(AgentManageFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    local entries = AgentListAllChats()
    if #entries == 0 then
        local empty = create("Frame", {
            Name = "EmptyRow",
            Size = UDim2.new(1, -16, 0, 90),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = AgentManageFrame
        })
        create("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "暂无已保存的对话",
            TextColor3 = theme.textDim,
            TextSize = 13,
            Font = Enum.Font.SourceSans,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            Parent = empty
        })
        return
    end
    for _, e in ipairs(entries) do
        local row = create("Frame", {
            Name = "ManageRow",
            Size = UDim2.new(1, -6, 0, 64),
            BackgroundColor3 = theme.surface,
            BackgroundTransparency = 0.08,
            BorderSizePixel = 0,
            Parent = AgentManageFrame
        })
        corner(10, row)
        stroke(theme.border, 1, row)
        local folderIcon = GetIcon("folder", UDim2.new(0, 28, 0, 28))
        if folderIcon then
            folderIcon.AnchorPoint = Vector2.new(0, 0.5)
            folderIcon.Position = UDim2.new(0, 14, 0.5, 0)
            folderIcon.Parent = row
        end
        local titleLbl = create("TextLabel", {
            Size = UDim2.new(1, -140, 0, 22),
            Position = UDim2.new(0, 50, 0, 14),
            BackgroundTransparency = 1,
            Text = AgentSafeString(e.title, 26),
            TextColor3 = theme.text,
            TextSize = 14,
            Font = Enum.Font.SourceSansBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = row
        })
        local timeStr = "未知时间"
        if e.time and e.time > 0 then
            local okDate, date = pcall(os.date, "%Y-%m-%d %H:%M", e.time)
            if okDate and date then timeStr = date end
        end
        
        local modelStr = ""
        if e.models and #e.models > 0 then
            modelStr = " · 模型: " .. table.concat(e.models, " → ")
        elseif e.model and e.model ~= "" then
            modelStr = " · 模型: " .. tostring(e.model)
        end
        create("TextLabel", {
            Size = UDim2.new(1, -140, 0, 18),
            Position = UDim2.new(0, 50, 0, 38),
            BackgroundTransparency = 1,
            Text = timeStr .. (e.count > 0 and (" · " .. e.count .. " 条") or "") .. modelStr,
            TextColor3 = theme.textDim,
            TextSize = 11,
            Font = Enum.Font.SourceSans,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = row
        })
        local deleteBtn = create("TextButton", {
            Size = UDim2.new(0, 30, 0, 30),
            Position = UDim2.new(1, -36, 0.5, -15),
            BackgroundColor3 = theme.surfaceLight,
            BackgroundTransparency = 0.3,
            BorderSizePixel = 0,
            Text = "",
            ZIndex = 5,
            Parent = row
        })
        corner(8, deleteBtn)
        local delIcon = GetIcon("trash-2", UDim2.new(0, 16, 0, 16))
        if delIcon then delIcon.AnchorPoint = Vector2.new(0.5, 0.5); delIcon.Position = UDim2.new(0.5, 0, 0.5, 0); delIcon.Parent = deleteBtn end
        deleteBtn.MouseButton1Click:Connect(function()
            pcall(delfile, e.file)
            AgentRefreshConversationList()
        end)

        local loadBtn = create("TextButton", {
            Size = UDim2.new(0, 30, 0, 30),
            Position = UDim2.new(1, -74, 0.5, -15),
            BackgroundColor3 = theme.accent,
            BackgroundTransparency = 0.25,
            BorderSizePixel = 0,
            Text = "",
            ZIndex = 5,
            Parent = row
        })
        applyGradient(loadBtn, theme.accent, theme.accent2, 120)
        corner(8, loadBtn)
        local loadIcon = GetIcon("database-arrow-down", UDim2.new(0, 16, 0, 16))
        if loadIcon then loadIcon.AnchorPoint = Vector2.new(0.5, 0.5); loadIcon.Position = UDim2.new(0.5, 0, 0.5, 0); loadIcon.Parent = loadBtn end
        loadBtn.MouseButton1Click:Connect(function()
            AgentLoadConversationEntry(e)
            AgentSetManageMode(false)
        end)
    end
end


AgentSetManageMode = function(on)
    AgentManageMode = on
    AgentManageFrame.Visible = on
    AgentMessageFrame.Visible = not on
    AgentInputFrame.Visible = not on
    if AgentThinkPill then AgentThinkPill.Visible = not on end
    if AgentSettingsButton then
        AgentSettingsButton.BackgroundColor3 = on and theme.accent or theme.surfaceLight
    end
    AgentTitleLabel.Text = on and "对话管理" or "AgentLess"
    if on then AgentRefreshConversationList() end
end

-- 对话管理入口已移除（右上角改为设置按钮，暂不绑定事件）

AgentFinalizeMessage = function(container, isUser)
    local avatar = container:FindFirstChild("Avatar")
    local bubble = container:FindFirstChild("Bubble")
    if not bubble then return end
    local noAvatar = (avatar == nil)
    task.defer(function()
        local frameW = AgentMessageFrame.AbsoluteSize.X
        local maxWidth = math.min(400, math.max(160, frameW * 0.7))
        if bubble.AbsoluteSize.X > maxWidth then
            local label = bubble:FindFirstChild("TextLabel")
            if label then
                label.Size = UDim2.new(0, maxWidth - 24, 0, 0)
                label.AutomaticSize = Enum.AutomaticSize.Y
            end
        end
        if noAvatar then
            -- 续接气泡：位置在创建时已定好，这里不再重设
        elseif isUser then
            avatar.AnchorPoint = Vector2.new(1, 0)
            avatar.Position = UDim2.new(1, -8, 0, 0)
            bubble.AnchorPoint = Vector2.new(1, 0)
            bubble.Position = UDim2.new(1, -52, 0, 0)
        else
            avatar.AnchorPoint = Vector2.new(0, 0)
            avatar.Position = UDim2.new(0, 8, 0, 0)
            bubble.AnchorPoint = Vector2.new(0, 0)
            bubble.Position = UDim2.new(0, 52, 0, 0)
        end
        task.defer(function()
            AgentMessageFrame.CanvasPosition = Vector2.new(0, AgentMessageFrame.CanvasSize.Y.Offset)
        end)
    end)
end


local function AgentEscapeRich(s)
    s = tostring(s or "")
    s = s:gsub("&", "&amp;")
    s = s:gsub("<", "&lt;")
    s = s:gsub(">", "&gt;")
    return s
end

-- DeepSeek 标准围栏语言名 -> 统一短标签（卡片右上角显示）
AGENT_LANG_TAGS = {
    lua = "lua", luau = "luau", lua_u = "lua", roblox = "lua", rbx = "lua",
    js = "js", javascript = "js", ts = "ts", typescript = "ts", jsx = "jsx", tsx = "tsx",
    py = "py", python = "py", rb = "rb", ruby = "rb",
    json = "json", yaml = "yaml", yml = "yaml", toml = "toml", xml = "xml", html = "html",
    css = "css", scss = "scss", sql = "sql", sh = "sh", bash = "bash", shell = "bash",
    zsh = "bash", cmd = "cmd", bat = "bat", ps1 = "ps1", powershell = "ps1",
    c = "c", h = "c", cpp = "cpp", cxx = "cpp", cc = "cpp", cs = "cs", csharp = "cs",
    java = "java", kt = "kt", go = "go", rs = "rs", rust = "rs", swift = "swift",
    php = "php", diff = "diff", patch = "diff", ini = "ini", conf = "conf",
    md = "md", markdown = "md", txt = "txt", text = "text", plain = "text", plaintext = "text",
}

function AgentNormalizeLang(lang)
    if type(lang) ~= "string" then return "text" end
    lang = lang:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if lang == "" then return "text" end
    if AGENT_LANG_TAGS[lang] then return AGENT_LANG_TAGS[lang] end
    if #lang <= 12 and lang:match("^[%w_%+%-%.#]+$") then return lang end
    return "text"
end

-- 语言标签在卡片标题里的显示名
AGENT_LANG_TITLES = {
    lua = "Lua 代码", luau = "Luau 代码", text = "代码",
    json = "JSON", yaml = "YAML", html = "HTML", css = "CSS", sql = "SQL",
    sh = "Shell", bash = "Shell", js = "JavaScript", ts = "TypeScript", py = "Python",
}

function AgentLangTitle(lang)
    return AGENT_LANG_TITLES[lang] or (string.upper(tostring(lang)) .. " 代码")
end

-- 行内 Markdown -> RichText（正文部分）
local function AgentRenderAI(text)
    local s = AgentEscapeRich(text):gsub("^\r?\n", "")
    -- 前后补换行：Lua 模式没有分组选择，用 \n 锚定才能匹配「行首」
    s = "\n" .. s .. "\n"

    -- 行内代码 `code`
    s = s:gsub("`([^`\r\n]-)`", "<font color=\"#7dd3fc\">%1</font>")
    -- 粗体 / 下划线 / 斜体
    s = s:gsub("%*%*(.-)%*%*", "<b>%1</b>")
    s = s:gsub("__(.-)__", "<u>%1</u>")
    s = s:gsub("([^%w_])%*(%S[^*\r\n]-)%*([^%w_])", "%1<i>%2</i>%3")
    -- 标题（### / ## / #）
    s = s:gsub("\n%s*###+%s*([^\r\n]+)", "\n<b>%1</b>")
    s = s:gsub("\n%s*##%s*([^\r\n]+)", "\n<b>%1</b>")
    s = s:gsub("\n%s*#%s*([^\r\n]+)", "\n<b>%1</b>")
    -- 分隔线
    s = s:gsub("\n%s*%-%-%-[%-%s]*", "\n────────────\n")
    s = s:gsub("\n%s*%*%*%*[%*%s]*", "\n────────────\n")
    -- 引用（> 已在转义阶段变成 &gt;）与无序列表
    s = s:gsub("\n%s*&gt;%s?", "\n▎ ")
    s = s:gsub("\n%s*[%-%*+]%s+", "\n• ")
    -- 收尾：去掉补进去的首尾换行
    s = s:gsub("^\n", ""):gsub("\n$", "")
    return s
end

-- 解析回复：标准 ```lang 围栏（兼容旧版 ##code## 单行/多行）
function AgentIsLegacyCodeStart(reply, pos)
    local nxt = reply:sub(pos + 2, pos + 2)
    if nxt == "" or nxt == " " or nxt == "#" or nxt == "\n" or nxt == "\r" then return false end
    local close = reply:find("##", pos + 2, true)
    if not close then return false end
    local body = reply:sub(pos + 2, close - 1)
    if body == "" then return false end
    return body:find("[\n%(%=:]") ~= nil or body:find("print") ~= nil or body:find("local") ~= nil
end

function AgentSplitReply(reply)
    local parts = {}
    local hasCode = false
    local pos = 1
    local len = #reply

    while pos <= len do
        local fence = reply:find("```", pos, true)
        local hash = reply:find("##", pos, true)
        local start, mode
        if fence and hash then
            if fence <= hash then start, mode = fence, "fence" else start, mode = hash, "hash" end
        elseif fence then
            start, mode = fence, "fence"
        elseif hash then
            start, mode = hash, "hash"
        else
            break
        end

        local legacyHeading = (mode == "hash") and not AgentIsLegacyCodeStart(reply, start)

        if legacyHeading then
            -- 普通 Markdown 标题里的 ## ，当正文处理
            local plain = reply:sub(pos, start + 1)
            if plain ~= "" then parts[#parts + 1] = {type = "text", text = plain} end
            pos = start + 2
        else
            local before = reply:sub(pos, start - 1)
            if before ~= "" then parts[#parts + 1] = {type = "text", text = before} end

            if mode == "fence" then
                local close = reply:find("```", start + 3, true)
                local body, nextPos
                if close then
                    body = reply:sub(start + 3, close - 1)
                    nextPos = close + 3
                else
                    body = reply:sub(start + 3)
                    nextPos = len + 1
                end
                body = body:gsub("^\r?\n", "")
                local lang = nil
                local firstLine, rest = body:match("^([^\r\n]*)\r?\n(.*)$")
                if firstLine and #firstLine <= 20 and firstLine:match("^[%a][%w_%+%-%.#]*%s*$") then
                    lang = firstLine
                    body = rest
                elseif body:match("^[%a][%w_%+%-%.#]*%s*$") then
                    lang = body
                    body = ""
                end
                body = body:gsub("%s+$", "")
                if body ~= "" then
                    hasCode = true
                    local tag = lang
                    if tag == nil or tag == "" then
                        -- 没写语言时猜一下：像 Lua 就标 lua，否则标 text
                        if body:find("%f[%w]local%s") or body:find("%f[%w]function%s") or body:find("%f[%w]end%f[%A]")
                            or body:find("game%.") or body:find("workspace%.") or body:find("print%s*%(")
                            or body:find("^%s*%-%-") or body:find("%f[%w]then%f[%A]") then
                            tag = "lua"
                        else
                            tag = "text"
                        end
                    end
                    parts[#parts + 1] = {type = "code", text = body, lang = AgentNormalizeLang(tag)}
                end
                pos = nextPos
            else
                local close = reply:find("##", start + 2, true)
                local body = reply:sub(start + 2, close - 1)
                body = body:gsub("^%s*\r?\n", ""):gsub("%s+$", "")
                if body ~= "" then
                    hasCode = true
                    parts[#parts + 1] = {type = "code", text = body, lang = "lua"}
                end
                pos = close + 2
            end
        end
    end

    local tail = reply:sub(pos)
    if tail ~= "" then parts[#parts + 1] = {type = "text", text = tail} end
    return parts, hasCode
end

function AgentAddMessage(text, isUser, stats, noAvatar)
    local container, bubble = AgentCreateMessageContainer(text, isUser, nil, noAvatar)
    local label = create("TextLabel", {
        Name = "TextLabel",
        BackgroundTransparency = 1,
        Text = isUser and text or AgentRenderAI(text),
        TextColor3 = isUser and Color3.new(1, 1, 1) or theme.text,
        Font = Enum.Font.SourceSans,
        TextSize = 14,
        TextWrapped = true,
        RichText = not isUser,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        AutomaticSize = Enum.AutomaticSize.XY,
        Size = UDim2.new(0, 0, 0, 0),
        Parent = bubble,
        ZIndex = 4
    })
    local textPadding = create("UIPadding", {
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),

        PaddingTop = UDim.new(0, (not isUser and stats) and 14 or (not isUser and 8 or 6)),
        PaddingBottom = UDim.new(0, not isUser and 8 or 6),
        Parent = label
    })

    if not isUser and stats then
        local statsLabel = create("TextLabel", {
            Name = "StatsLabel",
            BackgroundTransparency = 1,
            Text = stats,
            TextColor3 = Color3.fromRGB(120, 120, 130),
            Font = Enum.Font.SourceSans,
            TextSize = 10,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            AutomaticSize = Enum.AutomaticSize.XY,
            Size = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(0, 0, 0, 1.5),
            Parent = bubble,
            ZIndex = 4
        })
        create("UIPadding", {
            PaddingLeft = UDim.new(0, 12),
            PaddingRight = UDim.new(0, 12),
            PaddingTop = UDim.new(0, 2),
            PaddingBottom = UDim.new(0, 8),
            Parent = statsLabel
        })
    end

    AgentFinalizeMessage(container, isUser)
    return container
end

AgentTypewriteMessage = function(text, isUser, stats)
    if isUser then return AgentAddMessage(text, true) end
    local container, bubble = AgentCreateMessageContainer("", false)

    local label = create("TextLabel", {
        Name = "TextLabel",
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = theme.text,
        Font = Enum.Font.SourceSans,
        TextSize = 14,
        TextWrapped = true,
        RichText = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Size = UDim2.new(0, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        Parent = bubble,
        ZIndex = 4
    })
    local textPadding = create("UIPadding", {
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),

        PaddingTop = UDim.new(0, (stats and 14) or 8),
        PaddingBottom = UDim.new(0, 8),
        Parent = label
    })

        local cursor = create("Frame", {
        Name = "Cursor",
        Size = UDim2.new(0, 2, 0, 16),
        BackgroundColor3 = theme.accent,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = bubble,
        Visible = false
    })
        applyGradient(cursor, theme.accent, theme.accent2, 120)
    corner(1, cursor)

        
        local fullText = AgentEscapeRich(text)
    local displayedText = ""
    local charIndex = 1
    local totalChars = #fullText

    local baseDelay = 0.018

        local cursorBlinking = true
    local cursorConn = nil
    local function startCursorBlink()
        cursorBlinking = true
        cursor.Visible = true
        local blinkState = true
        cursorConn = task.spawn(function()
            while cursorBlinking do
                blinkState = not blinkState
                cursor.BackgroundTransparency = blinkState and 0.7 or 0
                task.wait(0.35)
            end
            cursor.Visible = false
        end)
    end

    local function stopCursorBlink()
        cursorBlinking = false
        if cursorConn then
            pcall(function() task.cancel(cursorConn) end)
        end
        cursor.Visible = false
    end

    if stats then
        local statsLabel = create("TextLabel", {
            Name = "StatsLabel",
            BackgroundTransparency = 1,
            Text = stats,
            TextColor3 = Color3.fromRGB(120, 120, 130),
            Font = Enum.Font.SourceSans,
            TextSize = 10,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            AutomaticSize = Enum.AutomaticSize.XY,
            Size = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(0, 0, 0, 1.5),
            Parent = bubble,
            ZIndex = 4
        })
        create("UIPadding", {
            PaddingLeft = UDim.new(0, 12),
            PaddingRight = UDim.new(0, 12),
            PaddingTop = UDim.new(0, 2),
            PaddingBottom = UDim.new(0, 8),
            Parent = statsLabel
        })
    end

    startCursorBlink()

    local chars = {}
    if utf8 and utf8.codes then
        local ok, iter = pcall(function()
            local result = {}
            for _, cp in utf8.codes(fullText) do
                result[#result + 1] = utf8.char(cp)
            end
            return result
        end)
        if ok and iter then
            chars = iter
        else
            local bi = 1
            while bi <= #fullText do
                local b = fullText:byte(bi)
                local len = 1
                if b >= 240 then len = 4
                elseif b >= 224 then len = 3
                elseif b >= 192 then len = 2 end
                table.insert(chars, fullText:sub(bi, math.min(bi + len - 1, #fullText)))
                bi = bi + len
            end
        end
    else
        local bi = 1
        while bi <= #fullText do
            local b = fullText:byte(bi)
            local len = 1
            if b >= 240 then len = 4
            elseif b >= 224 then len = 3
            elseif b >= 192 then len = 2 end
            table.insert(chars, fullText:sub(bi, math.min(bi + len - 1, #fullText)))
            bi = bi + len
        end
    end
    local charCount = #chars

    local segments = {}
    local currentSeg = {}
    local segLen = 0
    for idx = 1, charCount do
        local c = chars[idx]
        table.insert(currentSeg, c)
        segLen = segLen + 1
        if c:match("[。！？.!?]") or c == "\n" or c == "\r" or segLen >= 10 then
            table.insert(segments, currentSeg)
            currentSeg = {}
            segLen = 0
        end
    end
    if #currentSeg > 0 then
        table.insert(segments, currentSeg)
    end

    if #segments < 5 and charCount > 300 then
        segments = {}
        local chunkSize = math.max(10, math.floor(charCount / 15))
        for i = 1, charCount, chunkSize do
            local seg = {}
            for j = i, math.min(i + chunkSize - 1, charCount) do
                table.insert(seg, chars[j])
            end
            table.insert(segments, seg)
        end
    end

    local displayParts = {}
    local displayLen = 0
    for _, seg in ipairs(segments) do
        for _, char in ipairs(seg) do
            displayLen = displayLen + 1
            displayParts[displayLen] = char
            displayedText = table.concat(displayParts, nil, 1, displayLen)
            label.Text = displayedText

            local textBounds = label.TextBounds
            local topPad = (stats and 14) or 8
            cursor.Position = UDim2.new(0, textBounds.X + 12, 0, topPad + textBounds.Y - 14)

            local delay = baseDelay
            if char:match("[。！？.!?]") then
                delay = delay * 2
            elseif char:match("[，,;；：:]") then
                delay = delay * 1.2
            elseif char == " " then
                delay = delay * 0.5
            else
                delay = delay * (0.8 + math.random() * 0.4)
            end
            task.wait(delay)
        end
        task.defer(function()
            AgentMessageFrame.CanvasPosition = Vector2.new(0, AgentMessageFrame.CanvasSize.Y.Offset)
        end)
    end
    stopCursorBlink()

    
    pcall(function()
        label.Text = AgentRenderAI(text)
    end)

    AgentFinalizeMessage(container, false)
    return container
end

local function AgentShowDecompileResult(fullPath, source)
    local container, bubble = AgentCreateMessageContainer("", false, theme.surfaceLight)
    local displayName = fullPath:match("([^/]+)$") or fullPath
    local button = create("TextButton", {
        Name = "CopyButton",
        BackgroundTransparency = 1,
        Text = displayName,
        TextColor3 = theme.accent,
        Font = Enum.Font.SourceSansBold,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        AutomaticSize = Enum.AutomaticSize.XY,
        Size = UDim2.new(0, 0, 0, 0),
        Parent = bubble,
        ZIndex = 4
    })

    local hint = create("TextLabel", {
        Name = "Hint",
        BackgroundTransparency = 1,
        Text = "（点击复制完整源码）",
        TextColor3 = theme.textDim,
        Font = Enum.Font.SourceSans,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutomaticSize = Enum.AutomaticSize.XY,
        Size = UDim2.new(0, 0, 0, 0),
        Parent = bubble,
        ZIndex = 4
    })

    local padding = create("UIPadding", {
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 8),
        Parent = bubble
    })

    local layout = create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        Padding = UDim.new(0, 2),
        Parent = bubble
    })

    button.MouseButton1Click:Connect(function()
        if setclipboard then
            setclipboard(source)
            button.Text = displayName .. " ✅ 已复制"
                        local notifyReplies = {
                "源码已复制到剪贴板！",
                "复制成功，去粘贴吧～",
                "已复制，记得保存好哦",
                "剪贴板已收到源码！",
                "复制完成！可以去编辑器里粘贴了",
            }
            ShowNotification(notifyReplies[math.random(#notifyReplies)], 1.5)
            task.delay(2, function()
                button.Text = displayName
            end)
        else
            button.Text = displayName .. " ❌ 剪贴板不可用"
            ShowNotification("剪贴板 API 不可用，无法复制", 2)
        end
    end)

    AgentFinalizeMessage(container, false)
    return container
end




local _aWAuthZx9K7 = "Dlt" .. "7kZq" .. "W2m9vR4x" .. "Q9n"

-- ===== AI 工作时长计时（仅统计 AI 真正开始工作到结束的耗时，累计）=====
AgentTotalWorkTime = AgentTotalWorkTime or 0
AgentWorkStart = 0
function AgentWorkTimerStart()
    if AgentWorkStart == 0 then AgentWorkStart = tick() end
end
function AgentWorkTimerStop()
    if AgentWorkStart ~= 0 then
        AgentTotalWorkTime = AgentTotalWorkTime + (tick() - AgentWorkStart)
        AgentWorkStart = 0
    end
end
local function AgentWorkElapsed()
    local wt = AgentTotalWorkTime or 0
    if (AgentWorkStart or 0) ~= 0 then wt = wt + (tick() - AgentWorkStart) end
    return wt
end

local function AgentGenerateResponse(userInput, authToken)
    
    if authToken ~= _aWAuthZx9K7 then
        return "该接口仅允许 UI 内部调用，外部调用已被拒绝。", {
            {phase = "auth", output = "外部调用被拒绝，未消耗任何 token"}
        }
    end
    local input = tostring(userInput or "")
    if input:match("^%s*$") then return nil end

    if AgentCheckSensitive(input) then
        return "针对这个问题我无法为你提供相应解答。你可以尝试提供其他话题，我会尽力为你提供支持和解答。", {
            {phase = "safety", output = "检测到敏感内容，已拒绝并引导到其他话题"}
        }
    end

    -- AI 真正开始工作：启动耗时计时（空输入 / 敏感内容不计入）
    AgentWorkTimerStart()

    local cfgLocalUseApi = loadConfig()
    if not cfgLocalUseApi.useExternalApi then
        local lr = localModelChat(input)
        if lr and lr ~= "" then
            AgentWorkTimerStop()
            return lr, { {phase = "local", output = "本地模型回复（工具功能受限）"} }
        end
        AgentWorkTimerStop()
        return "本地模型暂时无法回复，请检查模型是否安装正确，或在设置中开启外部API。", {
            {phase = "error", output = "本地模型无有效输出"}
        }
    end

    local ok, reply, steps = pcall(AgentGenerateResponseCore, input, _aWAuthZx9K7)
    if ok and reply and tostring(reply) ~= "" then
        AgentWorkTimerStop()
        return reply, steps or {}
    end

    local errText
    if ok then
        errText = "模型未返回有效回答"
    else
        errText = tostring(reply or "未知错误")
    end
    local errReplies = {
        "抱歉，处理时出现了问题：" .. errText .. "，可以重试一下。",
        "出了点状况：" .. errText .. "，换个说法试试？",
        "处理遇到障碍：" .. errText .. "，请稍后再试。",
    }
    AgentWorkTimerStop()
    return errReplies[math.random(#errReplies)], {
        {phase = "error", output = errText}
    }
end

local AgentShowThinkingBubble
local AgentRemoveThinkingBubble

-- ============================================================================
--  深度思考卡片（workbuddy / DeepSeek 风格）
--  · 头部：图标 + 「深度思考」+ 状态（进行中显示秒数与阶段 / 完成后显示用时）+ 折叠箭头
--  · 主体：推理内容（流式刷新），可点击头部展开或收起，超长时内部滚动
--  · 完成后自动收起，卡片保留在对话流里
-- ============================================================================
do
    local currentThinkingContainer = nil
    local currentThinkingThread = nil
    local currentThinkingBody = nil
    local currentThinkingLabel = nil
    local currentThinkingStatus = nil
    local currentThinkingChevron = nil
    local currentThinkingStartTime = 0
    local currentThinkingLastText = ""
    local currentThinkingExpanded = true

    local function AgentThinkBodyHeight(text)
        local frameW = 320
        pcall(function()
            if AgentMessageFrame and AgentMessageFrame.AbsoluteSize.X > 0 then
                frameW = AgentMessageFrame.AbsoluteSize.X
            end
        end)
        local availW = math.max(120, frameW - 120)
        local TextService = game:GetService("TextService")
        local ok, size = pcall(function()
            return TextService:GetTextSize(text, 12, Enum.Font.SourceSans, Vector2.new(availW, 100000))
        end)
        local textH = (ok and size and size.Y) or 40
        return math.clamp(textH + 18, 26, 280)
    end

    local function AgentThinkSetBody(text)
        if not currentThinkingBody or not currentThinkingLabel then return end
        text = tostring(text or "")
        if text == currentThinkingLastText then return end
        currentThinkingLastText = text
        pcall(function()
            currentThinkingLabel.Text = text
            currentThinkingBody.Size = UDim2.new(1, -20, 0, AgentThinkBodyHeight(text))
        end)
    end

    local function AgentThinkSetExpanded(expanded)
        currentThinkingExpanded = expanded and true or false
        if currentThinkingBody then currentThinkingBody.Visible = currentThinkingExpanded end
        if currentThinkingChevron then
            currentThinkingChevron.Rotation = currentThinkingExpanded and 90 or 0
        end
    end

    AgentThinkingSetExpanded = AgentThinkSetExpanded

    AgentShowThinkingBubble = function()
        -- 上一张还在进行中的卡片先收尾
        if currentThinkingContainer then
            pcall(AgentRemoveThinkingBubble)
        end

        local container, bubble = AgentCreateMessageContainer("", false, nil, true)
        currentThinkingContainer = container
        currentThinkingLastText = ""
        currentThinkingExpanded = true
        currentThinkingStartTime = tick()

        if bubble then
            -- 整行卡片：宽度铺满、只按内容高度增长
            bubble.AutomaticSize = Enum.AutomaticSize.Y
            bubble.Size = UDim2.new(1, -16, 0, 0)
            bubble.BackgroundTransparency = 0.55
        end

        local header = create("TextButton", {
            Name = "ThinkHeader",
            Size = UDim2.new(1, 0, 0, 28),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            Parent = bubble,
            ZIndex = 5
        })

        local headIcon = GetIcon("brain", UDim2.new(0, 14, 0, 14), theme.textDim)
        if not headIcon then
            headIcon = GetIcon("atom", UDim2.new(0, 14, 0, 14), theme.textDim)
        end
        if headIcon then
            headIcon.Position = UDim2.new(0, 10, 0, 7)
            headIcon.Parent = header
        end

        local titleLabel = create("TextLabel", {
            Name = "ThinkTitle",
            Position = UDim2.new(0, 30, 0, 0),
            Size = UDim2.new(0, 68, 1, 0),
            BackgroundTransparency = 1,
            Text = "深度思考",
            TextColor3 = theme.textDim,
            Font = Enum.Font.SourceSansBold,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            Parent = header,
            ZIndex = 6
        })

        currentThinkingStatus = create("TextLabel", {
            Name = "ThinkStatus",
            Position = UDim2.new(0, 96, 0, 0),
            Size = UDim2.new(1, -130, 1, 0),
            BackgroundTransparency = 1,
            Text = "思考中…",
            TextColor3 = theme.textDim,
            Font = Enum.Font.SourceSans,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = header,
            ZIndex = 6
        })

        currentThinkingChevron = GetIcon("chevron-right", UDim2.new(0, 14, 0, 14), theme.textDim)
        if currentThinkingChevron then
            currentThinkingChevron.AnchorPoint = Vector2.new(0.5, 0.5)
            currentThinkingChevron.Position = UDim2.new(1, -16, 0.5, 0)
            currentThinkingChevron.Rotation = 90
            currentThinkingChevron.Parent = header
            currentThinkingChevron.ZIndex = 6
        end

        -- 左侧竖线 + 推理正文（超长时内部滚动）
        local bodyWrap = create("ScrollingFrame", {
            Name = "ThinkBody",
            Position = UDim2.new(0, 10, 0, 30),
            Size = UDim2.new(1, -20, 0, 40),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = theme.textDim,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingEnabled = true,
            ClipsDescendants = true,
            Parent = bubble,
            ZIndex = 4
        })
        currentThinkingBody = bodyWrap

        local bar = create("Frame", {
            Name = "ThinkBar",
            Position = UDim2.new(0, 0, 0, 2),
            Size = UDim2.new(0, 2, 1, -4),
            BackgroundColor3 = theme.accent,
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            Parent = bodyWrap,
            ZIndex = 5
        })
        corner(1, bar)

        currentThinkingLabel = create("TextLabel", {
            Name = "ThinkText",
            Position = UDim2.new(0, 10, 0, 0),
            Size = UDim2.new(1, -14, 0, 0),
            BackgroundTransparency = 1,
            Text = "",
            TextColor3 = theme.textDim,
            Font = Enum.Font.SourceSans,
            TextSize = 12,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            AutomaticSize = Enum.AutomaticSize.Y,
            Parent = bodyWrap,
            ZIndex = 5
        })

        AgentThinkSetExpanded(true)
        AgentFinalizeMessage(container, false)

        header.MouseButton1Click:Connect(function()
            AgentThinkSetExpanded(not currentThinkingExpanded)
        end)

        -- 运行中：刷新计时 / 阶段文字 / 流式推理
        local startTime = currentThinkingStartTime
        currentThinkingThread = task.spawn(function()
            while currentThinkingContainer == container do
                local elapsed = tick() - startTime
                local phase = AgentThinkingPhase or ""
                local reasoning = tostring(AgentLocalAIState and AgentLocalAIState.lastReasoning or "")

                if reasoning ~= "" then
                    AgentThinkSetBody(reasoning)
                elseif phase ~= "" then
                    AgentThinkSetBody(phase .. "…")
                end

                if currentThinkingStatus then
                    local suffix = phase ~= "" and (" · " .. phase) or ""
                    local ok = pcall(function()
                        currentThinkingStatus.Text = string.format("%.1fs", elapsed) .. suffix
                    end)
                    if not ok then break end
                end
                pcall(function()
                    AgentMessageFrame.CanvasPosition = Vector2.new(0, AgentMessageFrame.CanvasSize.Y.Offset)
                end)
                task.wait(0.1)
            end
        end)

        return container
    end

    AgentRemoveThinkingBubble = function()
        AgentThinkingPhase = ""
        AgentCustomProgressMsg = ""
        AgentLastToolName = ""
        AgentLastToolPhase = ""

        if currentThinkingThread then
            pcall(function() task.cancel(currentThinkingThread) end)
            currentThinkingThread = nil
        end

        local container = currentThinkingContainer
        currentThinkingContainer = nil
        if not container then return end

        local elapsed = math.max(0, tick() - (currentThinkingStartTime or tick()))

        -- 固化的正文：优先推理内容，其次最后的阶段文字
        local finalText = ""
        pcall(function()
            local reasoning = tostring(AgentLocalAIState and AgentLocalAIState.lastReasoning or "")
            if reasoning ~= "" then
                finalText = reasoning
            elseif currentThinkingLastText ~= "" then
                finalText = currentThinkingLastText
            end
        end)
        if finalText ~= "" then
            pcall(AgentThinkSetBody, finalText)
        else
            pcall(AgentThinkSetBody, "（本轮没有返回思考内容）")
        end

        if currentThinkingStatus then
            pcall(function()
                currentThinkingStatus.Text = string.format("（用时 %.1f 秒）", elapsed)
            end)
        end

        -- 完成后自动收起，卡片留在对话里
        pcall(AgentThinkSetExpanded, false)
    end

    -- 供工具循环使用：每完成一轮工具调用就收尾当前卡片、开启新一轮「深度思考」
    AgentStartThinkingRound = function()
        return AgentShowThinkingBubble()
    end
    AgentEndThinkingRound = function()
        return AgentRemoveThinkingBubble()
    end
end


local function AgentSafeSpawn(fn, ...)
    local args = {...}
    return task.spawn(function()
        local ok, err = pcall(fn, unpack(args))
        if not ok then
            warn("[DeltaUI Agent] task.spawn error: " .. tostring(err))
        end
    end)
end


local trainingUploadRemoteName = "DeltaUITrainingUpload"
local trainingUploadQueue = {}
local trainingUploadBusy = false

local function AgentTrainingConsent()
    local cfg = loadConfig()
    return cfg and cfg.trainingUploadConsent == true
end

local function AgentQueueTrainingPair(userText, assistantText)
    if not AgentTrainingConsent() then return end
    local u = tostring(userText or "")
    local a = tostring(assistantText or "")
    if u == "" or a == "" then return end
    if #u > 4000 then u = u:sub(1, 4000) end
    if #a > 8000 then a = a:sub(1, 8000) end
    trainingUploadQueue[#trainingUploadQueue + 1] = {
        user = u,
        assistant = a,
        timestamp = os.time(),
    }
    if trainingUploadBusy then return end
    trainingUploadBusy = true
    task.spawn(function()
        while #trainingUploadQueue > 0 do
            if not AgentTrainingConsent() then
                table.clear(trainingUploadQueue)
                break
            end
            local remote = nil
            pcall(function()
                remote = svc.ReplicatedStorage:FindFirstChild(trainingUploadRemoteName)
            end)
            if not remote or not remote:IsA("RemoteEvent") then
                break
            end
            local batch = {}
            for i = 1, math.min(10, #trainingUploadQueue) do
                batch[#batch + 1] = table.remove(trainingUploadQueue, 1)
            end
            local ok = pcall(function()
                remote:FireServer(batch)
            end)
            if not ok then
                for i = #batch, 1, -1 do
                    table.insert(trainingUploadQueue, 1, batch[i])
                end
                break
            end
            task.wait(1)
        end
        trainingUploadBusy = false
    end)
end

local function AgentTrainingQueueStatus()
    return #trainingUploadQueue
end

local function AgentSaveLastScript()
    local history = AgentChatMemory.conversationHistory or {}
    if #history == 0 then
        return false, "没有找到对话历史，无法保存脚本。"
    end

    
    local lastAssistantMsg = nil
    for i = #history, 1, -1 do
        if history[i].role == "assistant" then
            lastAssistantMsg = history[i].content
            break
        end
    end

    if not lastAssistantMsg or lastAssistantMsg == "" then
        return false, "没有找到 AI 提供的脚本内容。"
    end

    
    local code = nil
    -- 优先标准 Markdown 围栏（```lua / ```luau / 无语言）
    local fence = "`" .. "`" .. "`"
    local fStart, fEnd = lastAssistantMsg:find(fence .. "%s*[%w_%+%-%.]-%s*\n(.-)\n%s*" .. fence)
    if fStart then
        local inner = lastAssistantMsg:sub(fStart, fEnd)
        inner = inner:gsub("^" .. fence .. "%s*[%w_%+%-%.]-%s*\n", ""):gsub("\n%s*" .. fence .. "$", "")
        code = inner
    else
        -- 兼容旧版 ##code##
        local codeStart, codeEnd = lastAssistantMsg:find("##(.-)##")
        if codeStart then
            code = lastAssistantMsg:sub(codeStart + 2, codeEnd - 2)
        end
    end

    if not code or code:match("^%s*$") then
        return false, "最近一条 AI 回复中没有检测到脚本代码块（##...## 或 ```...```）。"
    end

    
    local placeId = tostring(game.PlaceId or 0)
    local sessionTitle = AgentCurrentSession.sessionTitle or "新对话"
    local safeTitle = tostring(sessionTitle):gsub("[/\\:*?\"<>|\r\n\t ]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if safeTitle == "" then safeTitle = "default" end
    if #safeTitle > 40 then safeTitle = safeTitle:sub(1, 40) end

    local baseDir = "DeltaUI/Agent/Chat/对话_" .. placeId .. "/" .. safeTitle
    if not isfolder(baseDir) and makefolder then
        local ok = pcall(function()
            if not isfolder("DeltaUI/Agent/Chat/对话_" .. placeId) then
                makefolder("DeltaUI/Agent/Chat/对话_" .. placeId)
            end
            makefolder(baseDir)
        end)
        if not ok then
            return false, "创建保存目录失败: " .. baseDir
        end
    end

    local timestamp = os.time()
    local fileName = "Script_" .. timestamp .. ".lua"
    local filePath = baseDir .. "/" .. fileName

    
    local okWrite, errWrite = pcall(function()
        writefile(filePath, code)
    end)

    if okWrite then
        return true, filePath
    else
        return false, "保存文件失败: " .. tostring(errWrite)
    end
end

AgentSendMessage = function()
    local text = AgentInputBox.Text
    if not text or text:match("^%s*$") then return end

    
    
    local cfgSendUseApi = loadConfig()
    if not cfgSendUseApi.useExternalApi then
        if not localModelInstalled() then
            AgentInputBox.Text = ""
            AgentAddMessage(text, true)
            showLocalModelCard("install")
            return
        elseif localModelNeedsUpdate() and not _G.__DeltaUI_modelUpdateNotified then
            _G.__DeltaUI_modelUpdateNotified = true
            showLocalModelCard("update")
        end
    end

    
    local saveKeywords = {"保存脚本", "保存到本地", "存到本地", "保存代码", "存一下脚本", "把脚本保存"}
    local isSaveRequest = false
    local lowerText = text:lower()
    for _, kw in ipairs(saveKeywords) do
        if lowerText:find(kw:lower(), 1, true) then
            isSaveRequest = true
            break
        end
    end

    if isSaveRequest then
        AgentInputBox.Text = ""
        AgentAddMessage(text, true)
        AgentSafeSpawn(function()
            task.wait(0.2)
            local ok, result = AgentSaveLastScript()
            if ok then
                AgentAddMessage("✅ 脚本已保存到本地\n路径: " .. result, false)
            else
                AgentAddMessage("❌ " .. result, false)
            end
        end)
        return
    end

        if text:match("^[加恢][载复]") and (AgentCurrentSession.isFirstRound or not AgentChatMemory.conversationHistory or #AgentChatMemory.conversationHistory == 0) then
        local latest = AgentFindLatestChat()
        if latest and AgentLoadChatHistory(latest) then
            AgentInputBox.Text = ""
            AgentAddMessage("加载", true)
                        for _, child in ipairs(AgentMessageFrame:GetChildren()) do
                if child:IsA("Frame") and child.Name == "MessageContainer" then
                    child:Destroy()
                end
            end
                        AgentSafeSpawn(function()
                AgentAddMessage("已恢复上次对话", false)
                if AgentChatMemory.conversationHistory then
                    for i, msg in ipairs(AgentChatMemory.conversationHistory) do
                        if i <= 20 then AgentAddMessage(msg.content, msg.role == "user")
                        end
                    end
                end
                task.wait(0.5)
                local title = latest.name:gsub("^对话_", "")
                AgentAddMessage("对话已加载: " .. title, false)
            end)
            return
        else
            AgentInputBox.Text = ""
            AgentAddMessage(text, true)
            AgentSafeSpawn(function()
                task.wait(0.3)
                AgentAddMessage("没有找到可恢复的历史对话", false)
            end)
            return
        end
    end

    

        AgentResetMetrics()
    AgentStartTiming()
    AgentTotalTokens = 0  

    AgentInputBox.Text = ""
    AgentAddMessage(text, true)

        if AgentCurrentSession.isFirstRound then
        local title = AgentGenerateTitle(text)
        AgentCurrentSession.sessionTitle = title
                AgentInitSessionDir()
        AgentRenameSessionDir(title)
        AgentCurrentSession.isFirstRound = false
    end

        if not AgentChatMemory.conversationHistory then
        AgentChatMemory.conversationHistory = {}
    end
    table.insert(AgentChatMemory.conversationHistory, {
        role = "user",
        content = text,
        timestamp = os.time()
    })

        local maxHist = tonumber(AgentLocalAIConfig.maxHistoryMessages) or 20
        if #AgentChatMemory.conversationHistory > maxHist then
            table.remove(AgentChatMemory.conversationHistory, 1)
        end

    AgentSafeSpawn(function()

        AgentShowThinkingBubble()

        local okReply, reply = pcall(AgentGenerateResponse, text, _aWAuthZx9K7)
        if not okReply or not reply or reply == "" then
            local errFallbacks = {
                "抱歉，处理时出现了问题，请稍后重试。",
                "出了点小状况，换个方式再试试？",
                "处理遇到异常，请重试或换个说法。",
            }
            reply = errFallbacks[math.random(#errFallbacks)]
        end

        if reply then
                            table.insert(AgentChatMemory.conversationHistory, {
                role = "assistant",
                content = tostring(reply),
                model = AgentLocalAIConfig.activeModel,
                modelLabel = (AGENT_PROVIDERS[AgentLocalAIConfig.activeModel] and AGENT_PROVIDERS[AgentLocalAIConfig.activeModel].label) or AgentLocalAIConfig.model,
                timestamp = os.time()
            })
            AgentQueueTrainingPair(text, tostring(reply))

            
            local elapsed = AgentMetrics.thinkingStartTime > 0 and (tick() - AgentMetrics.thinkingStartTime) or 0
            local complexity = AgentMetrics.toolCalls * 0.8 + AgentMetrics.fileOperations * 0.4
            local target = math.max(1.5, 1.5 + math.min(complexity, 3.0))
            if elapsed < target then
                task.wait(target - elapsed)
            end

            AgentRemoveThinkingBubble()

            
            -- 思考内容已由「深度思考」卡片承载，不再单独发一条消息
            AgentLocalAIState.lastReasoning = nil

            local statsText = AgentGenerateStatsText(true)

                            AgentSaveChatHistory()
            AgentSaveMemory(text, tostring(reply))

            

            if type(reply) == "table" and reply.__type == "decompile" then
                AgentShowDecompileResult(reply.filename, reply.source)
            elseif type(reply) == "table" and reply.__type == "script" then
                AgentShowScriptResult(reply.title, reply.source)
            else
                local replyStr = tostring(reply)
                
                local usedCode = AgentRenderMessageWithCode(replyStr, statsText)
                if not usedCode then
                    AgentTypewriteMessage(replyStr, false, statsText)
                end
            end
        end
    end)
end
end

AgentSendButton.MouseButton1Click:Connect(AgentSendMessage)
AgentInputBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then AgentSendMessage() end
end)

AgentShowScriptResult = function(title, source, lang, noAvatar)
    source = tostring(source or "")
    lang = tostring(lang or "lua")
    local lineCount = select(2, source:gsub("\n", "")) + 1
    local cardTitle = AgentLangTitle(lang)
    if type(title) == "string" and title ~= "" and title ~= "代码" then
        cardTitle = title
    end

    local container, bubble = AgentCreateMessageContainer("", false, nil, noAvatar)
    local card = create("Frame", {
        Size = UDim2.new(0, 420, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Color3.fromRGB(13, 17, 23),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = bubble,
        ZIndex = 4
    })
    corner(8, card)
    stroke(Color3.fromRGB(48, 54, 61), 1, card)

    local head = create("Frame", {
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Color3.fromRGB(22, 27, 34),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Parent = card,
        ZIndex = 5
    })

    local tagW = math.clamp(12 + #lang * 7, 36, 76)
    local langTag = create("TextLabel", {
        Position = UDim2.new(0, 10, 0.5, -9),
        Size = UDim2.new(0, tagW, 0, 18),
        BackgroundColor3 = Color3.fromRGB(40, 47, 62),
        BackgroundTransparency = 0,
        Text = lang,
        TextColor3 = Color3.fromRGB(120, 170, 255),
        Font = Enum.Font.Code,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = head,
        ZIndex = 6
    })
    corner(4, langTag)

    local titleLabel = create("TextLabel", {
        Position = UDim2.new(0, tagW + 20, 0, 0),
        Size = UDim2.new(1, -(tagW + 92), 1, 0),
        BackgroundTransparency = 1,
        Text = cardTitle .. " · " .. lineCount .. " 行",
        TextColor3 = Color3.fromRGB(200, 210, 225),
        Font = Enum.Font.SourceSansBold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = head,
        ZIndex = 6
    })

    local copyBtn = create("TextButton", {
        Position = UDim2.new(1, -62, 0.5, -10),
        Size = UDim2.new(0, 52, 0, 20),
        BackgroundColor3 = theme.accent,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        Text = "",
        Parent = head,
        ZIndex = 6
    })
    applyGradient(copyBtn, theme.accent, theme.accent2, 120)
    corner(6, copyBtn)
    local copyTxt = create("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "复制",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 11,
        Font = Enum.Font.SourceSansBold,
        Parent = copyBtn,
        ZIndex = 7
    })

    local codeLabel = create("TextLabel", {
        Position = UDim2.new(0, 10, 0, 38),
        Size = UDim2.new(1, -20, 0, 0),
        BackgroundTransparency = 1,
        RichText = false,
        Text = source,
        TextColor3 = Color3.fromRGB(220, 225, 235),
        Font = Enum.Font.Code,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = card,
        ZIndex = 5
    })
    create("UIPadding", {
        PaddingBottom = UDim.new(0, 10),
        Parent = card
    })

    copyBtn.MouseButton1Click:Connect(function()
        if setclipboard then
            pcall(setclipboard, source)
            copyTxt.Text = "已复制"
            ShowNotification("脚本已复制到剪贴板", 1.5)
            task.delay(1.5, function() copyTxt.Text = "复制" end)
        else
            copyTxt.Text = "不可用"
            ShowNotification("剪贴板 API 不可用", 2)
        end
    end)

    AgentFinalizeMessage(container, false)
    return container
end


-- 渲染整条回复：文本走气泡，围栏代码走代码卡（DeepSeek 标准排版）
AgentRenderMessageWithCode = function(reply, stats)
    if type(reply) ~= "string" or reply == "" then return nil end

    local parts, hasCode = AgentSplitReply(reply)
    if not hasCode then return nil end

    local blocks = {}
    local pending = nil
    local function flushText()
        if pending then
            local txt = pending:gsub("^%s+", ""):gsub("%s+$", "")
            if txt ~= "" then
                blocks[#blocks + 1] = {type = "text", text = txt}
            end
            pending = nil
        end
    end
    for _, part in ipairs(parts) do
        if part.type == "code" then
            flushText()
            blocks[#blocks + 1] = part
        else
            -- 相邻文本原样拼接（后续整体裁剪），避免 Markdown 结构被破坏
            pending = (pending or "") .. tostring(part.text or "")
        end
    end
    flushText()
    if #blocks == 0 then return nil end

    local statsShown = false
    local rendered = 0
    for _, block in ipairs(blocks) do
        local isFirst = (rendered == 0)
        if block.type == "text" then
            local st = (not statsShown) and stats or nil
            AgentAddMessage(block.text, false, st, not isFirst)
            if st then statsShown = true end
        else
            local title = (block.lang == "lua" or block.lang == "luau") and "脚本" or "代码"
            AgentShowScriptResult(title, block.text, block.lang, not isFirst)
        end
        rendered = rendered + 1
    end

    if not statsShown and stats then
        AgentAddMessage("", false, stats, true)
    end
    return true
end

function AgentCreateMessageContainer(text, isUser, customBubbleColor, noAvatar)
    local container = create("Frame", {
        Name = "MessageContainer",
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = AgentMessageFrame,
        ZIndex = 3
    })

    local avatar = nil
    if not noAvatar then
        avatar = create("Frame", {
            Name = "Avatar",
            Size = UDim2.new(0, 28, 0, 28),
            BackgroundColor3 = isUser and theme.accent or theme.surfaceLight,
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            ZIndex = 4
        })
        corner(14, avatar)
        avatar.Parent = container

        local avatarIcon = GetIcon(isUser and "user" or "terminal", UDim2.new(0, 16, 0, 16), isUser and Color3.new(1,1,1) or theme.text)
        if avatarIcon then
            avatarIcon.Position = UDim2.new(0.5, -8, 0.5, -8)
            avatarIcon.Parent = avatar
        end
    end

    local bubble = create("Frame", {
        Name = "Bubble",
        BackgroundColor3 = customBubbleColor or (isUser and theme.accent or theme.surfaceLight),
        BackgroundTransparency = isUser and 0.25 or 0.4,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.XY,
        Parent = container,
        ZIndex = 3
    })
    corner(12, bubble)

    if isUser then
        if avatar then
            avatar.AnchorPoint = Vector2.new(1, 0)
            avatar.Position = UDim2.new(1, -8, 0, 0)
        end
        bubble.AnchorPoint = Vector2.new(1, 0)
        bubble.Position = noAvatar and UDim2.new(1, -8, 0, 0) or UDim2.new(1, -52, 0, 0)
    elseif noAvatar then
        bubble.AnchorPoint = Vector2.new(0, 0)
        bubble.Position = UDim2.new(0, 8, 0, 0)
    else
        avatar.AnchorPoint = Vector2.new(0, 0)
        avatar.Position = UDim2.new(0, 8, 0, 0)
        bubble.AnchorPoint = Vector2.new(0, 0)
        bubble.Position = UDim2.new(0, 52, 0, 0)
    end

    return container, bubble
end
]==]

local AGENTLESS_TRANSLATIONS = {
    agentless_settings = {en = "AgentLess Settings", zh = "AgentLess 设置", ko = "AgentLess 설정", ja = "AgentLess 設定"},
    thinking_mode = {en = "Thinking Mode", zh = "思考模式", ko = "사고 모드", ja = "思考モード"},
    thinking_mode_desc = {en = "Enable the model's thinking mode and visualize its reasoning process", zh = "开启模型思考模式，可视化思考过程", ko = "모델의 사고 모드를 켜고 추론 과정을 시각화", ja = "モデルの思考モードを有効化し推論プロセスを可視化"},
    model_switch = {en = "Model", zh = "选择模型", ko = "모델 선택", ja = "モデル"},
    model_switch_desc = {en = "Switch the AI model used by AgentLess", zh = "切换 AgentLess 使用的 AI 模型", ko = "AgentLess가 사용하는 AI 모델 전환", ja = "AgentLessが使用するAIモデルを切り替え"},
    model_flash = {en = "DeepSeek", zh = "DeepSeek", ko = "DeepSeek", ja = "DeepSeek"},
    model_claude = {en = "Anthropic", zh = "Anthropic", ko = "Anthropic", ja = "Anthropic"},
    use_external_api = {en = "Use External API", zh = "使用外部API", ko = "외부 API 사용", ja = "外部APIを使用"},
    use_external_api_desc = {en = "Show model & thinking mode settings. Model name stays hidden while off", zh = "启用后显示模型/思考模式设置；关闭时不显示模型名称", ko = "켜면 모델/사고 모드 설정 표시, 끄면 모델명 숨김", ja = "ONでモデル/思考モードを表示、OFF時はモデル名を非表示"},
    training_upload = {en = "Upload Training Data", zh = "上传训练数据", ko = "학습 데이터 업로드", ja = "学習データをアップロード"},
    training_upload_desc = {en = "With your consent, upload anonymized conversation pairs to the game server for training", zh = "开启后，在你同意的情况下把匿名化的对话问答上传到游戏服务器用于训练", ko = "동의하면 익명화된 대화 데이터를 게임 서버로 업로드", ja = "同意した場合、匿名化した会話データをゲームサーバーへ送信"},
}


local function buildAgentLessSettings(env, G)
    if type(makeSectionCard) ~= "function" or type(makeSettingRow) ~= "function" then
        return false
    end
    if G.__DeltaUI_agentlessSettingsBuilt then return true end

    local registerTranslationFn = hostSymbol("registerTranslation")
    if type(registerTranslationFn) ~= "function" then
        registerTranslationFn = env and env.registerTranslation
    end
    if type(registerTranslationFn) == "function" then
        for key, entry in pairs(AGENTLESS_TRANSLATIONS) do
            pcall(registerTranslationFn, key, entry)
        end
    end

    local loadConfigFn = hostSymbol("loadConfig") or (env and env.loadConfig)
    local saveConfigFn = hostSymbol("saveConfig") or (env and env.saveConfig)
    local notifyFn = hostSymbol("ShowNotification")
    local tFn = hostSymbol("t")

    local function tr(key)
        if type(tFn) == "function" then
            local ok, v = pcall(tFn, key)
            if ok and type(v) == "string" then return v end
        end
        return key
    end
    local function notify(msg, dur)
        if type(notifyFn) == "function" then pcall(notifyFn, msg, dur or 2) end
    end
    local function readCfg()
        if type(loadConfigFn) == "function" then
            local ok, cfg = pcall(loadConfigFn)
            if ok and type(cfg) == "table" then return cfg end
        end
        return {}
    end
    local function writeCfg(k, v)
        if type(saveConfigFn) ~= "function" then return end
        local cfg = readCfg()
        cfg[k] = v
        pcall(saveConfigFn, cfg)
    end

    local card = makeSectionCard(tr("agentless_settings"), nil, "atom", 3)
    if not card then return false end
    G.__DeltaUI_agentlessSettingsBuilt = true

    local modelIds = {"flash", "claude", "aiagent", "qwen", "glm", "kimi", "minimax", "baichuan", "doubao", "hunyuan", "custom"}
    local modelLabels = {"model_flash", "model_claude", nil, nil, nil, nil, nil, nil, nil, nil, nil}
    local modelOptions = {tr("model_flash"), tr("model_claude"), "Agnes", "阿里通义千问", "智谱 GLM", "月之暗面 Kimi", "MiniMax", "百川智能", "火山方舟 豆包", "腾讯混元", "自定义服务商"}

    local rowExtApi = makeSettingRow("use_external_api", "use_external_api_desc", 1)
    if rowExtApi then rowExtApi.Parent = card end

    local rowModel = makeSettingRow("model_switch", "model_switch_desc", 2)
    if rowModel then rowModel.Parent = card end

    local rowThinkingLevel = makeSettingRow("thinking_level", "thinking_level_desc", 5)
    if rowThinkingLevel then rowThinkingLevel.Parent = card end

    local function applyModelLabelVisible(state)
        local lbl = env.AgentModelLabel
        if lbl then pcall(function() lbl.Visible = state end) end
    end

    local function refreshExternalRows(state)
        if rowModel then
            rowModel.Visible = state
            rowModel.Size = UDim2.new(1, 0, 0, state and 54 or 0)
        end
        if rowThinkingLevel then
            rowThinkingLevel.Visible = state
            rowThinkingLevel.Size = UDim2.new(1, 0, 0, state and 54 or 0)
        end
        applyModelLabelVisible(state)
    end

    local function refreshThinkingLevelRow()
        if not rowThinkingLevel then return end
        pcall(function()
            for _, c in ipairs(rowThinkingLevel:GetChildren()) do c:Destroy() end
            local id = readCfg().activeModel or "flash"
            local caps = AgentGetThinkingCaps(id)
            if not (caps and caps.switchable) then
                local note = create("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 28),
                    BackgroundTransparency = 1,
                    Text = "当前模型不支持该操作",
                    TextColor3 = Color3.fromRGB(255, 82, 104),
                    Font = Enum.Font.SourceSansBold,
                    TextSize = 13,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = rowThinkingLevel,
                })
                return
            end
            if type(makeDropdown) == "function" then
                local levels = caps.levels or {"低", "中", "高"}
                local cfgL = readCfg()
                local cur = cfgL.thinkingLevel
                local defaultIdx = 1
                for i, lv in ipairs(levels) do if lv == cur then defaultIdx = i break end end
                makeDropdown(rowThinkingLevel, levels, defaultIdx, function(val)
                    writeCfg("thinkingLevel", val)
                    local setter = G.__DeltaAI_setThinkingMode
                    if type(setter) == "function" then pcall(setter, true) end
                    local pill = G.__DeltaAI_updateThinkPill
                    if type(pill) == "function" then pcall(pill, true) end
                    notify("思考级别：" .. tostring(val), 1.0)
                end)
            end
        end)
    end

    local cfg = readCfg()
    local extEnabled = cfg.useExternalApi == true

    if type(makeToggle) == "function" and rowExtApi then
        makeToggle(rowExtApi, extEnabled, function(state)
            writeCfg("useExternalApi", state)
            refreshExternalRows(state)
        end, "useExternalApi")
    end

    if type(makeDropdown) == "function" and rowModel then
        local savedModel = cfg.activeModel
        local defaultIdx = 1
        for i, id in ipairs(modelIds) do
            if id == savedModel then defaultIdx = i break end
        end
        makeDropdown(rowModel, modelOptions, defaultIdx, function(val)
            for i = 1, #modelOptions do
                if modelOptions[i] == val then
                    local id = modelIds[i]
                    writeCfg("activeModel", id)
                    if id == "custom" then
                        if type(env.AgentApplyCustomProvider) == "function" then
                            pcall(env.AgentApplyCustomProvider, cfg.customBaseUrl or "", cfg.customApiKey or "", cfg.customActiveModel or "")
                        end
                    else
                        if type(env.AgentApplyModel) == "function" then
                            pcall(env.AgentApplyModel, id)
                        end
                    end
                    refreshThinkingLevelRow()
                    break
                end
            end
        end)
    end

    refreshExternalRows(extEnabled)
    refreshThinkingLevelRow()
    return true
end

local function buildAgentLessEnv(frame, helpers)
    local G = getGlobalEnv()
    local env = {}
    env.__AGENTLESS_FRAME = frame
    env.__AGENTLESS_HELPERS = helpers
    env.__AGENTLESS_HOST = G

    local services = {
        Players = game:GetService("Players"),
        UserInputService = game:GetService("UserInputService"),
        CoreGui = game:GetService("CoreGui"),
        ReplicatedStorage = game:GetService("ReplicatedStorage"),
        TweenService = game:GetService("TweenService"),
        RunService = game:GetService("RunService"),
        Stats = game:GetService("Stats"),
        HttpService = game:GetService("HttpService"),
    }
    env.svc = services
    env.v7 = services.Players.LocalPlayer
    env.theme = hostSymbol("theme", helpers) or builtinTheme()
    env.contentFrame = frame.Parent or hostSymbol("contentFrame", helpers) or frame

    
    
    env._G = G

    
    
    for _, key in ipairs(HOST_BINDINGS) do
        local v = hostSymbol(key, helpers)
        if v ~= nil then env[key] = v end
    end

    local fallbackUsed = {}
    if type(env.loadConfig) ~= "function" then
        env.loadConfig = makeFallbackLoadConfig(G)
        fallbackUsed[#fallbackUsed + 1] = "loadConfig"
    end
    if type(env.saveConfig) ~= "function" then
        env.saveConfig = makeFallbackSaveConfig(G)
        fallbackUsed[#fallbackUsed + 1] = "saveConfig"
    end
    if type(env.applyGradient) ~= "function" then
        env.applyGradient = makeFallbackApplyGradient(env)
        fallbackUsed[#fallbackUsed + 1] = "applyGradient"
    end
    if type(env.registerTranslation) ~= "function" then
        env.registerTranslation = function() end
        fallbackUsed[#fallbackUsed + 1] = "registerTranslation"
    end
    if #fallbackUsed > 0 then
        warn("[AgentLess] 宿主未提供以下符号，已用页面内置兜底: " .. table.concat(fallbackUsed, ", "))
    end

    
    env.updateExternalApiUI = function(forceState)
        local enabled = forceState
        if enabled == nil then
            local loader = env.loadConfig
            if type(loader) == "function" then
                local ok, cfg = pcall(loader)
                cfg = ok and cfg or nil
                if type(cfg) == "table" then enabled = cfg.useExternalApi == true end
            end
        end
        if env.AgentModelLabel then
            pcall(function() env.AgentModelLabel.Visible = enabled end)
        end
        return enabled
    end

    setmetatable(env, {
        __index = function(_, key)
            return hostSymbol(key, helpers)
        end,
    })
    return env, G
end

function pageDef.build(frame, helpers)
    frame.Name = pageDef.name
    helpers = helpers or {}
    local G = getGlobalEnv()

    local function fail(msg)
        if type(helpers.ShowNotification) == "function" then
            pcall(helpers.ShowNotification, msg, 5)
        elseif type(hostSymbol("ShowNotification")) == "function" then
            pcall(hostSymbol("ShowNotification"), msg, 5)
        else
            warn("[AgentLess] " .. msg)
        end
    end

    
    if type(setfenv) ~= "function" then
        fail("AgentLess 需要在主环境(免沙箱)加载：请升级 DeltaUI 的官方页面放行，或在设置中关闭「页面安全模式」")
        return
    end

    local env = buildAgentLessEnv(frame, helpers)
    local loadOk, chunk, compileErr = pcall(loadstring, AGENTLESS_SOURCE, "@DeltaUI_AgentLess")
    if not loadOk or type(chunk) ~= "function" then
        fail("AgentLess 页面编译/加载失败(沙箱?): " .. tostring(compileErr or chunk))
        return
    end
    setfenv(chunk, env)

    local ok, runErr = pcall(chunk)
    if not ok then
        fail("AgentLess 页面构建失败: " .. tostring(runErr))
        warn("[AgentLess] runtime error: " .. tostring(runErr))
        return
    end

    pcall(buildAgentLessSettings, env, G)

    if type(hostSymbol("AddLog")) == "function" then
        pcall(hostSymbol("AddLog"), "[AgentLess] 官方页面已加载 v" .. tostring(pageDef.version), "info")
    end
end

local function register()
    if type(DeltaRegisterPage) == "function" then
        DeltaRegisterPage(pageDef)
        return true
    end
    local G = getGlobalEnv()
    if G and type(G.DeltaRegisterPage) == "function" then
        G.DeltaRegisterPage(pageDef)
        return true
    end
    return false
end

register()

return pageDef
