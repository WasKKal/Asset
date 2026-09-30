 

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
        local theme = env and env.theme
        from = from or (theme and theme.accent) or Color3.fromRGB(56, 189, 248)
        to = to or (theme and theme.accent2) or Color3.fromRGB(139, 92, 246)
        local g
        local ok, inst = pcall(function()
            local make = (env and env.create) or create
            if type(make) == "function" then
                return make("UIGradient", {Rotation = rotation or 45})
            end
            return Instance.new("UIGradient")
        end)
        if ok and inst then g = inst end
        if not g then return nil end
        pcall(function() g.Color = ColorSequence.new(from, to) end)
        pcall(function() frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255) end)
        pcall(function() g.Parent = frame end)
        
        local G = env and env._G
        if type(G) == "table" then
            pcall(function()
                G.__DeltaUI_gradients = G.__DeltaUI_gradients or {}
                table.insert(G.__DeltaUI_gradients, g)
            end)
        end
        return g
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
--       theme / svc / v7 / wasaiPage / contentFrame 由宿主提供。
-- ============================================================
local wasaiPage = __AGENTLESS_FRAME
if contentFrame then wasaiPage.Parent = contentFrame end

local wasaiPromptResumeChat
local wasaiMessageFrame
local wasaiInputBox
local wasaiSendButton
local wasaiFinalizeMessage
local wasaiShowScriptResult
local wasaiAddMessage
local wasaiTypewriteMessage
local wasaiRenderMessageWithCode
local wasaiSendMessage
do
local wasaiChatMemory = { lastPath = nil, lastObj = nil, lastDeletedDir = nil }
local wasaiResumeParent = nil


local function wasaiValidatePath(path)
    if type(path) ~= "string" or path == "" then return false end
    
    if path:find("%.%.%/") or path:find("%.%.\\") or path:find("%.%.%.$") then return false end
    if path:find("\x00") or path:find("\\") then return false end
    
    if not path:match("^[%w_./ %-]+$") then return false end
    return true
end


local function wasaiGetInstanceFromPath(path)
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

local function wasaiGetChildNames(instance)
    if not instance then return {} end
    local names = {}
    for _, child in ipairs(instance:GetChildren()) do
        table.insert(names, child.Name .. " (" .. child.ClassName .. ")")
    end
    return names
end

local function wasaiTryDecompile(scriptObj)
    if not scriptObj:IsA("LuaSourceContainer") then return nil, "不是脚本/模块" end
    if not decompile then return nil, "当前环境不支持反编译 (decompile 函数缺失)" end
    local success, source = pcall(decompile, scriptObj)
    if not success then return nil, "反编译失败: " .. tostring(source) end
    return source, nil
end

local function wasaiGetAllScripts(container)
    
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


local function wasaiSafeSegment(seg)
    seg = tostring(seg or ""):gsub("[\\/:*?\"<>|%c\r\n\t]", "_")
    if seg == "" then seg = "_" end
    if #seg > 40 then seg = seg:sub(1, 40) end
    return seg
end

local function wasaiSaveScriptToFile(script, baseDir, rootName)
    if not writefile or not makefolder or not isfolder then return false, "文件系统函数不可用" end
    local source, err = wasaiTryDecompile(script)
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
        table.insert(segs, wasaiSafeSegment(seg))
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
    wasaiTrackFileOp(fullPath)
    return true, fullPath
end

local function wasaiListAllProperties(instance)
    if not instance then return {} end
    local props = {}
    for _, prop in ipairs(instance:GetProperties()) do
        local success, val = pcall(function() return instance[prop] end)
        if success then table.insert(props, prop .. " = " .. tostring(val))
        else table.insert(props, prop .. " = <无法读取>") end
    end
    return props
end

local function wasaiFindObjectsByName(name, container)
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

local function wasaiListChildrenDepth(instance, maxDepth)
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


local function wasaiExecWithTimeout(func, seconds)
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

local function wasaiExecuteLuaCode(code)
    local func, err = loadstring(code)
    if not func then return nil, "编译错误: " .. err end
    local execTimeout = tonumber(wasaiLocalAIConfig.executeTimeout) or 15

    
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
            
            local success, result = wasaiExecWithTimeout(func, execTimeout)
            if not success then return nil, "执行错误: " .. tostring(result) end
            if result ~= nil then table.insert(out, tostring(result)) end
            return table.concat(out, "\n"), nil
        end
    else
        local okSet = pcall(setfenv, func, {print = makePrint()})
        if not okSet then
            local success, result = wasaiExecWithTimeout(func, execTimeout)
            if not success then return nil, "执行错误: " .. tostring(result) end
            if result ~= nil then table.insert(out, tostring(result)) end
            return table.concat(out, "\n"), nil
        end
    end

    local success, result = wasaiExecWithTimeout(func, execTimeout)
    if not success then return nil, "执行错误: " .. tostring(result) end
    if result ~= nil then table.insert(out, tostring(result)) end
    return table.concat(out, "\n"), nil
end

local function wasaiTrim(str)
    local i, j = 1, #str
    while i <= j and string.byte(str:sub(i,i)) <= 32 do i = i + 1 end
    while j >= i and string.byte(str:sub(j,j)) <= 32 do j = j - 1 end
    return str:sub(i, j)
end

local function wasaiIsPathInput(text)
    local trimmed = wasaiTrim(text)
    local pathPrefixes = {"game.", "workspace.", "Players.", "ReplicatedStorage.", "ServerScriptService.", "StarterGui.", "StarterPack.", "StarterPlayer.", "Lighting.", "SoundService."}
    for _, prefix in ipairs(pathPrefixes) do
        if trimmed:sub(1, #prefix) == prefix then
            return true
        end
    end
    if trimmed:find(".", 1, true) and #trimmed > 5 then
        local test, _ = wasaiGetInstanceFromPath(trimmed)
        if test then return true end
    end
    return false
end


local wasaiConversationState = {
    topic = nil, topicEntities = {}, userMood = "neutral", contextMemory = {}, lastAction = nil, }

local function wasaiUpdateConversationState(input, intent, entities)
        if entities.path then
        wasaiConversationState.topic = "instance"
        wasaiConversationState.topicEntities.path = entities.path
    elseif intent == "search" then
        wasaiConversationState.topic = "search"
        wasaiConversationState.topicEntities.target = entities.target
    end

        wasaiConversationState.lastAction = {
        intent = intent,
        entities = entities,
        timestamp = os.time()
    }

        if input:match("谢谢|感谢|好棒|太棒了") then
        wasaiConversationState.userMood = "happy"
    elseif input:match("算了|不用了|错误|失败|糟糕") then
        wasaiConversationState.userMood = "frustrated"
    elseif input:match("为什么|怎么|如何") then
        wasaiConversationState.userMood = "curious"
    else
        wasaiConversationState.userMood = "neutral"
    end
end


local wasaiChineseSensitiveWords = {
    "他妈的", "他妈", "草你妈", "操你妈", "傻逼", "煞笔", "傻b", "cnm", "qnmd", "tmd",
    "废物", "去死", "脑残", "弱智", "白痴", "神经病", "杂种", "王八蛋",
    "操你", "操蛋", "草你", "草泥马", "贱人", "贱货", "贱逼", "婊子",
    "狗东西", "狗娘", "狗日", "狗屎", "狗屁", "傻狗", "狗杂种",
    "猪头", "猪脑", "笨猪", "猪狗", "蠢猪",
    "滚蛋", "滚开", "滚犊子",
}

local wasaiEnglishSensitiveWords = {
    "fuck", "fucking", "fucked", "fucker", "shit", "shitting", "bitch", "bitchy",
    "asshole", "dickhead", "cock", "cunt", "nigger", "faggot", "retard", "damn", "dammit", "sb",
}

local wasaiContextSensitiveWords = { "草", "操", "滚", "贱", "狗", "猪" }

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

local function wasaiCheckSensitive(text)
    if not text or text == "" then return false end
    local lower = string.lower(text)

    for _, w in ipairs(wasaiEnglishSensitiveWords) do
        local pos = 1
        while true do
            local s, e = lower:find(w, pos, true)
            if not s then break end
            if isWholeWord(lower, s, #w) then return true end
            pos = e + 1
        end
    end

    for _, w in ipairs(wasaiChineseSensitiveWords) do
        if lower:find(w, 1, true) then return true end
    end

    for _, w in ipairs(wasaiContextSensitiveWords) do
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

local wasaiThinkingPhases = {
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

local wasaiRobloxKnowledge = {
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

local wasaiMetrics = {
    thinkingStartTime = 0, toolCalls = 0, fileOperations = 0, }

local wasaiThinkingPhase = ""
local wasaiCustomProgressMsg = ""
local wasaiLastToolName = ""
local wasaiLastToolPhase = ""
local wasaiLastToolOp = {}

local wasaiRecentSavedFiles = {}
local wasaiLastDecompileDir = nil

local function wasaiResetMetrics()
    wasaiMetrics.thinkingStartTime = 0
    wasaiMetrics.toolCalls = 0
    wasaiMetrics.fileOperations = 0
end

local function wasaiStartTiming()
    wasaiMetrics.thinkingStartTime = tick()
end

local function wasaiTrackToolCall()
    wasaiMetrics.toolCalls = wasaiMetrics.toolCalls + 1
end

function wasaiTrackFileOp(filePath) -- [官方页面] 提为全局：原文件部分引用早于 local 声明
    wasaiMetrics.fileOperations = wasaiMetrics.fileOperations + 1
    if filePath and type(filePath) == "string" then
        table.insert(wasaiRecentSavedFiles, filePath)
        if #wasaiRecentSavedFiles > 500 then
            table.remove(wasaiRecentSavedFiles, 1)
        end
    end
end

local function wasaiClearSavedFilesTracking()
    wasaiRecentSavedFiles = {}
    wasaiLastDecompileDir = nil
end

local function wasaiGetThinkingDuration()
    local elapsed
    if wasaiMetrics.thinkingStartTime == 0 then
        elapsed = wasaiLocalAIState.lastLatency or 0
    else
        elapsed = math.floor((tick() - wasaiMetrics.thinkingStartTime) * 100) / 100
    end
    local complexity = wasaiMetrics.toolCalls * 0.8 + wasaiMetrics.fileOperations * 0.4
    local minTime = math.floor((1.5 + math.min(complexity, 3.0)) * 100) / 100
    local float = math.floor(math.random() * 0.5 * 100) / 100
    return math.floor(math.max(elapsed, minTime) * 100 + float * 100) / 100
end

local function wasaiGenerateStatsText(done)
    local duration = wasaiGetThinkingDuration()
    local durationStr = string.format("%.2f", duration)
    local prefix = done and "思考完成" or "仍在思考"
    if wasaiMetrics.toolCalls == 0 and wasaiMetrics.fileOperations == 0 then
        return prefix .. " " .. durationStr .. "s"
    end
    local parts = {prefix .. " " .. durationStr .. "s"}
    if wasaiMetrics.toolCalls > 0 then
        table.insert(parts, "执行了 " .. wasaiMetrics.toolCalls .. " 次 lua")
    end
    if wasaiMetrics.fileOperations > 0 then
        table.insert(parts, "操作 " .. wasaiMetrics.fileOperations .. " 次文件系统")
    end
    return table.concat(parts, " · ")
end

local wasaiCurrentSession = {
    sessionDir = nil,
    sessionFile = nil,
    placeId = nil,
    sessionTitle = nil,
    sessionTime = nil,
    isFirstRound = true,
    titleTried = false,
}

local function wasaiGenerateTitle(userInput)
    if not userInput or userInput == "" then return "新对话" end
    local cleaned = tostring(userInput):gsub("[，。！？、,%.!?：:；;…—%-]+", " ")
    cleaned = cleaned:gsub("%s+", " ")
    local title = cleaned:sub(1, 24)
    if #cleaned > 24 then title = title .. "…" end
    title = title:gsub("^%s+", ""):gsub("%s+$", "")
    return title ~= "" and title or "新对话"
end

local function wasaiEnsureAgentFolders()
    if not makefolder then return false end
    pcall(function()
        if not isfolder("DeltaUI") then makefolder("DeltaUI") end
        if not isfolder("DeltaUI/Agent") then makefolder("DeltaUI/Agent") end
        if not isfolder("DeltaUI/Agent/Chat") then makefolder("DeltaUI/Agent/Chat") end
        if not isfolder("DeltaUI/Agent/Remember") then makefolder("DeltaUI/Agent/Remember") end
    end)
    return true
end

local function wasaiInitSessionDir()
    if wasaiCurrentSession.sessionDir then return wasaiCurrentSession.sessionDir end

    wasaiEnsureAgentFolders()

    local placeId = tostring(game.PlaceId or 0)
    local baseDir = "DeltaUI/Agent/Chat/对话_" .. placeId

    if not isfolder(baseDir) and makefolder then
        pcall(function() makefolder(baseDir) end)
    end

    wasaiCurrentSession.sessionDir = baseDir
    wasaiCurrentSession.placeId = tonumber(placeId) or 0
    wasaiCurrentSession.sessionTime = os.time()

    local titleName = wasaiCurrentSession.sessionTitle or "新对话"
    local safeTitle = tostring(titleName):gsub("[/\\:*?\"<>|\r\n\t ]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if safeTitle == "" then safeTitle = "default" end
    if #safeTitle > 40 then safeTitle = safeTitle:sub(1, 40) end
    local filePath = baseDir .. "/" .. safeTitle .. ".chat"
    if isfile(filePath) then
        filePath = baseDir .. "/" .. safeTitle .. "_" .. os.time() .. ".chat"
    end
    wasaiCurrentSession.sessionFile = filePath
    wasaiCurrentSession.sessionKey = safeTitle

    return baseDir
end

local function wasaiRenameSessionDir(title)
    wasaiCurrentSession.sessionTitle = title or wasaiCurrentSession.sessionTitle or "新对话"
end

local function wasaiReadChatFile(path)
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

local function wasaiFindLatestChat()
    wasaiEnsureAgentFolders()
    local placeId = tostring(game.PlaceId or 0)
    local folder = "DeltaUI/Agent/Chat/对话_" .. placeId
    if not isfolder(folder) or not listfiles then return nil end

    local candidates = {}
    local ok, files = pcall(listfiles, folder)
    if not ok or type(files) ~= "table" then return nil end

    for _, path in ipairs(files) do
        if isfile(path) and path:match("%.chat$") then
            local data = wasaiReadChatFile(path)
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

local function wasaiLoadChatHistory(chatFolder)
    if not chatFolder then return false end
    local data = chatFolder.data or wasaiReadChatFile(chatFolder.chatFile)
    if not data or type(data.messages) ~= "table" then return false end

    wasaiChatMemory.conversationHistory = data.messages
    if data.metadata then
        wasaiChatMemory.lastPath = data.metadata.lastPath
        wasaiChatMemory.lastDeletedDir = data.metadata.lastDeletedDir
    end

    wasaiCurrentSession.sessionDir = chatFolder.path
    wasaiCurrentSession.sessionFile = chatFolder.chatFile
    wasaiCurrentSession.sessionKey = chatFolder.name
    wasaiCurrentSession.sessionTitle = data.metadata and data.metadata.title or chatFolder.name
    wasaiCurrentSession.sessionTime = data.createdAt or os.time()
    wasaiCurrentSession.placeId = tonumber(game.PlaceId or 0) or 0
    wasaiCurrentSession.isFirstRound = false
    return true
end

wasaiPromptResumeChat = function()
    local latest = wasaiFindLatestChat()
    if not latest then return false end
    if not wasaiResumeParent or not wasaiResumeParent.Parent then return false end

    local title = ""
    local summary = ""
    local data = latest.data or wasaiReadChatFile(latest.chatFile)
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
        Parent = wasaiResumeParent
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
        if wasaiLoadChatHistory(latest) then
            wasaiCurrentSession.isFirstRound = false
            task.spawn(function()
                local history = wasaiChatMemory.conversationHistory or {}
                for _, msg in ipairs(history) do
                    wasaiAddMessage(msg.content, msg.role == "user")
                    task.wait(0.05)
                end
            end)
        end
    end)

    return true
end

local function wasaiSaveChatHistory()
    if not writefile or not svc.HttpService then return end

    local sessionDir = wasaiInitSessionDir()
    if not wasaiCurrentSession.sessionFile then
        wasaiCurrentSession.sessionFile = sessionDir .. "/default.chat"
        wasaiCurrentSession.sessionKey = "default"
    end

    local messages = wasaiChatMemory.conversationHistory or {}
    
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
        sessionKey = wasaiCurrentSession.sessionKey,
        placeId = wasaiCurrentSession.placeId or game.PlaceId or 0,
        createdAt = wasaiCurrentSession.sessionTime or os.time(),
        updatedAt = os.time(),
        messages = messages,
        metadata = {
            lastPath = wasaiChatMemory.lastPath,
            lastDeletedDir = wasaiChatMemory.lastDeletedDir,
            totalRounds = #messages,
            title = wasaiCurrentSession.sessionTitle or "新对话",
            model = lastModel,
            models = modelList
        }
    }

    local ok, jsonStr = pcall(function()
        return svc.HttpService:JSONEncode(chatData)
    end)
    if ok and jsonStr then
        pcall(function() writefile(wasaiCurrentSession.sessionFile, jsonStr) end)
    end
end

local wasaiMemoryDBPath = "DeltaUI/Agent/Remember/memory_v3.db"
local wasaiMemoryCache = nil
local wasaiMemoryCachePath = nil
local wasaiMemoryDBPathFallback = wasaiMemoryDBPath



local function wasaiGetMemoryDBPath()
    local dir = wasaiCurrentSession and wasaiCurrentSession.sessionDir
    if dir and dir ~= "" then
        return dir .. "/memory.db"
    end
    return wasaiMemoryDBPathFallback
end
local wasaiMemoryDirty = false
local wasaiMemoryCategories = {
    fact = {decayRate = 0.005, minImportance = 0.3},
    preference = {decayRate = 0.002, minImportance = 0.5},
    decision = {decayRate = 0.003, minImportance = 0.4},
    tool_result = {decayRate = 0.01, minImportance = 0.2},
    entity = {decayRate = 0.004, minImportance = 0.3},
    context = {decayRate = 0.015, minImportance = 0.1},
}

local function wasaiMemoryNormalize(text)
    return tostring(text or ""):lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function wasaiMemoryTokenize(text)
    local tokens = {}
    local normalized = wasaiMemoryNormalize(text)
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
local function wasaiExtractMemories(input, output, context)
    local memories = {}
    local userInput = tostring(input or "")
    local aiOutput = tostring(output or "")
    local combined = userInput .. " " .. aiOutput
    local now = os.time()
    local topic = wasaiConversationState and wasaiConversationState.topic or nil
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
        filePath = wasaiTrim(filePath)
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
        prefContent = wasaiTrim(prefContent)
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
        decisionContent = wasaiTrim(decisionContent)
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
        fact = wasaiTrim(fact)
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

    
    local contextSummary = wasaiTrim(userInput:sub(1, 80))
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
local function wasaiMemorySimilarity(memA, memB)
    local tokensA = wasaiMemoryTokenize(memA.content)
    local tokensB_set = {}
    for _, t in ipairs(wasaiMemoryTokenize(memB.content)) do
        tokensB_set[t] = true
    end
    if #tokensA == 0 then return 0 end
    local hits = 0
    for _, t in ipairs(tokensA) do
        if tokensB_set[t] then hits = hits + 1 end
    end
    return hits / #tokensA
end


local function wasaiLoadMemoryDB()
    local path = wasaiGetMemoryDBPath()
    
    if wasaiMemoryCache and wasaiMemoryCachePath == path then return wasaiMemoryCache end
    wasaiMemoryCache = {}
    wasaiMemoryCachePath = path
    if not isfile or not readfile or not isfile(path) then
        return wasaiMemoryCache
    end
    local ok, content = pcall(readfile, path)
    if not ok or not content then return wasaiMemoryCache end
    for line in tostring(content):gmatch("[^\r\n]+") do
        local data
        local decoded = pcall(function() data = svc.HttpService:JSONDecode(line) end)
        if decoded and type(data) == "table" and data.content and data.category then
            wasaiMemoryCache[#wasaiMemoryCache + 1] = data
        end
    end
    return wasaiMemoryCache
end


local function wasaiSaveMemoryDB()
    if not wasaiMemoryDirty or not writefile then return end
    wasaiEnsureAgentFolders()
    local path = wasaiGetMemoryDBPath()
    
    local dir = wasaiCurrentSession and wasaiCurrentSession.sessionDir
    if dir and dir ~= "" and isfolder and not isfolder(dir) then
        pcall(function() makefolder(dir) end)
    end
    local lines = {}
    for _, mem in ipairs(wasaiMemoryCache or {}) do
        local ok, encoded = pcall(function() return svc.HttpService:JSONEncode(mem) end)
        if ok and encoded then
            lines[#lines + 1] = encoded
        end
    end
    pcall(function() writefile(path, table.concat(lines, "\n")) end)
    wasaiMemoryDirty = false
end


local function wasaiAddMemory(mem)
    local db = wasaiLoadMemoryDB()
    
    for i, existing in ipairs(db) do
        if existing.category == mem.category then
            local sim = wasaiMemorySimilarity(existing, mem)
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
                wasaiMemoryDirty = true
                return
            end
        end
    end
    
    db[#db + 1] = mem
    wasaiMemoryDirty = true
    
    local maxMemories = 500
    if #db > maxMemories then
        
        table.sort(db, function(a, b)
            local scoreA = (a.importance or 0.3) * 0.7 + (a.accessCount or 0) * 0.05
            local scoreB = (b.importance or 0.3) * 0.7 + (b.accessCount or 0) * 0.05
            return scoreA > scoreB
        end)
        local trimmed = {}
        for i = 1, maxMemories do trimmed[i] = db[i] end
        wasaiMemoryCache = trimmed
    end
end


local function wasaiMemoryScore(query, mem)
    if type(mem) ~= "table" then return 0 end
    local qTokens = {}
    for _, t in ipairs(wasaiMemoryTokenize(query)) do qTokens[t] = true end
    if next(qTokens) == nil then return 0 end

    local memText = wasaiMemoryNormalize((mem.content or "") .. " " .. table.concat(mem.tags or {}, " "))
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
    local decayRate = (wasaiMemoryCategories[category] or {}).decayRate or 0.01
    local decay = math.max(0.2, 1 - age * decayRate)

    
    local accessBoost = math.min(0.2, (mem.accessCount or 0) * 0.02)

    local score = (tokenScore * 0.6 + tagBoost) * importance * decay + accessBoost
    return math.min(1.0, score)
end



local wasaiSafeString


local function wasaiRetrieveMemory(query, limit)
    local db = wasaiLoadMemoryDB()
    if #db == 0 then return {} end

    local scored = {}
    for _, mem in ipairs(db) do
        local score = wasaiMemoryScore(query, mem)
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
        wasaiMemoryDirty = true
        local item = {
            score = scored[i].score,
            content = wasaiSafeString(r.content or "", 800),
            category = r.category or "unknown",
            tags = r.tags or {},
        }
        totalLen = totalLen + #item.content
        if totalLen > 6000 then break end
        result[#result + 1] = item
    end
    
    wasaiSaveMemoryDB()
    return result
end


local function wasaiSaveMemory(input, output)
    if not input or not output then return end
    wasaiEnsureAgentFolders()
    local memories = wasaiExtractMemories(input, output, wasaiConversationState)
    for _, mem in ipairs(memories) do
        wasaiAddMemory(mem)
    end
    wasaiSaveMemoryDB()
end


local function wasaiLoadMemoryRecords(limit)
    local db = wasaiLoadMemoryDB()
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

local function wasaiGetOutputDir()
    local sessionDir = wasaiInitSessionDir()
    local outputDir = sessionDir .. "/Output"
    if not isfolder(outputDir) and makefolder then pcall(function() makefolder(outputDir) end) end
    return outputDir
end

local function wasaiCalculateThinkingDuration(steps, inputType)
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


local function wasaiResolveDecompileTarget(targetStr)
    if not targetStr or targetStr == "" then return nil, "未提供目标" end
    targetStr = wasaiTrim(targetStr)

    
    if targetStr:find("^game%.") or targetStr:find("^workspace") then
        local obj, err = wasaiGetInstanceFromPath(targetStr)
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


local function wasaiDecompileSmart(targetStr)
    local obj, err, resolvedPath = wasaiResolveDecompileTarget(targetStr)
    if not obj then
        return "找不到目标：" .. tostring(err or "未知错误") .. "。请提供脚本路径或名称，例如「反编译 game.Workspace.Script」或「反编译 PlayerScripts 下的某脚本」。"
    end

    local isScript = obj:IsA("LuaSourceContainer")
    local childCount = #obj:GetChildren()
    local childScripts = wasaiGetAllScripts(obj)
    local hasChildScripts = #childScripts > 0

    
    if not isfolder("DeltaUI") then makefolder("DeltaUI") end
    if not isfolder("DeltaUI/Agent") then makefolder("DeltaUI/Agent") end
    local od = wasaiGetOutputDir()
    if not isfolder(od) then makefolder(od) end

    
    if isScript and not hasChildScripts then
        local source, derr = wasaiTryDecompile(obj)
        if not source then
            return "反编译失败：" .. tostring(derr) .. "\n目标：" .. resolvedPath
        end
        wasaiTrackToolCall()
        local savedPath = nil
        if writefile and makefolder and isfolder then
            local okSave, saveOk, savePath = pcall(wasaiSaveScriptToFile, obj, od, nil)
            if okSave and saveOk then
                savedPath = savePath
                wasaiLastDecompileDir = od
            end
        end
        local msg = "已反编译 " .. resolvedPath .. "，源码共 " .. #source .. " 字节。"
        if savedPath then msg = msg .. "已保存到：" .. tostring(savedPath) end
        return msg

    
    elseif isScript and hasChildScripts then
        local source, derr = wasaiTryDecompile(obj)
        if source then
            wasaiTrackToolCall()
            local savedPath = nil
            if writefile and makefolder and isfolder then
                local okSave, saveOk, savePath = pcall(wasaiSaveScriptToFile, obj, od, nil)
                if okSave and saveOk then
                    savedPath = savePath
                    wasaiLastDecompileDir = od
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
            local src, serr = wasaiTryDecompile(sc)
            if src then
                wasaiTrackToolCall()
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
                if okw then saved = saved + 1; wasaiTrackFileOp(filePath) end
            else
                table.insert(errors, sc:GetFullName() .. ": " .. tostring(serr))
            end
        end
        wasaiLastDecompileDir = baseDir

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

local function wasaiExtractContext(text, keyword)
    local s, e = tostring(text or ""):find(keyword, 1, true)
    if not s then return nil end
    local after = tostring(text):sub(e + 1)
    return wasaiTrim(after)
end
local function wasaiDecompileAll(input)
    local lowerInput = string.lower(input or "")
    local function ensureDir()
        if not isfolder("DeltaUI") then makefolder("DeltaUI") end
        if not isfolder("DeltaUI/Agent") then makefolder("DeltaUI/Agent") end
        local od = wasaiGetOutputDir()
        if not isfolder(od) then makefolder(od) end
    end
    local function saveScript(script, baseDir, rootName)
        if not script:IsA("LuaSourceContainer") then return false, "不是脚本" end
        if not decompile then return false, "当前环境不支持反编译" end
        local source, err = wasaiTryDecompile(script)
        if not source then return false, err end
        wasaiTrackToolCall()
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
            table.insert(segs, wasaiSafeSegment(seg))
        end
        local outFolder = rootName == "Players" and "PlayerScripts" or rootName
        local safeOut = wasaiSafeSegment(outFolder)
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
        wasaiTrackFileOp(filePath)
        return true, filePath
    end
    local function decompileContainer(container, rootName, baseDir, cap)
        if not container then return 0, {}, 0 end
        local scripts = wasaiGetAllScripts(container)
        local saved = 0
        local errors = {}
        local maxN = tonumber(cap) or math.huge
        local throttle = tonumber(wasaiLocalAIConfig.decompileAllThrottle) or 0.05
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
        local baseDir = wasaiGetOutputDir() .. "/反编译_" .. placeId .. "_" .. os.time()
        if not isfolder(baseDir) then makefolder(baseDir) end
        wasaiLastDecompileDir = baseDir
        local totalSaved = 0
        local allErrors = {}
        local results = {}
        local globalCap = tonumber(wasaiLocalAIConfig.decompileAllMaxScripts) or 600
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
        local ex = wasaiExtractContext(input, kw)
        if ex and ex ~= "" then path = ex break end
    end
    if not path then path = wasaiChatMemory.lastPath end
    if not path or path == "" then return "要反编译哪个目录下的所有脚本？说清楚。" end
    local container, err = wasaiGetInstanceFromPath(path)
    if not container then return "找不到这个容器：" .. (err or "") end
    ensureDir()
    local placeId = game.PlaceId or 0
    local folderName = path:match("([^%.]+)$") or "Unknown"
    local baseDir = wasaiGetOutputDir() .. "/反编译_" .. placeId .. "_" .. os.time() .. "/" .. folderName
    if not isfolder(baseDir) then makefolder(baseDir) end
    wasaiLastDecompileDir = baseDir
    local scripts = wasaiGetAllScripts(container)
    if #scripts == 0 then return path .. " 下面没找到任何脚本" end
    local saved = 0
    local errors = {}
    local throttle = tonumber(wasaiLocalAIConfig.decompileAllThrottle) or 0.05
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







local function wasaiDecompileModules(targetStr)
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
        local od = wasaiGetOutputDir()
        if not isfolder(od) then makefolder(od) end
        return od
    end

    
    local function saveModule(mod, baseDir, rootName)
        if not mod:IsA("ModuleScript") then return false, "不是 ModuleScript" end
        local source = safeDecompile(mod)
        if not source then return false, "反编译失败" end
        wasaiTrackToolCall()
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
            table.insert(segs, wasaiSafeSegment(seg))
        end
        local safeOut = wasaiSafeSegment(rootName == "Players" and "PlayerScripts" or (rootName or mod.Name))
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
        wasaiTrackFileOp(filePath)
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
        local obj, err = wasaiResolveDecompileTarget(tostring(targetStr))
        if not obj then
            obj, err = wasaiGetInstanceFromPath(tostring(targetStr))
        end
        if not obj then
            return "找不到目标：" .. tostring(err or "未知错误") .. "。请提供 ModuleScript 路径，例如「反编译模块 game.ReplicatedStorage.Module」"
        end
        local od = ensureDir()
        local placeId = game.PlaceId or 0
        local baseDir = od .. "/模块反编译_" .. placeId .. "_" .. os.time()
        if not isfolder(baseDir) then makefolder(baseDir) end
        wasaiLastDecompileDir = baseDir

        if obj:IsA("ModuleScript") then
            local source = safeDecompile(obj)
            if not source then return "反编译失败：" .. obj:GetFullName() end
            wasaiTrackToolCall()
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
        local saved, errors = decompileBatch(mods, baseDir, obj.Name, wasaiLocalAIConfig.decompileAllThrottle)
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
    wasaiLastDecompileDir = baseDir

    local throttle = wasaiLocalAIConfig.decompileAllThrottle
    local totalSaved = 0
    local allErrors = {}
    local results = {}
    local globalCap = tonumber(wasaiLocalAIConfig.decompileAllMaxScripts) or 600
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

local function wasaiCountOutputFiles()
    local dir = wasaiGetOutputDir()
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

local function wasaiDeleteRecentFiles()
    local deleted = 0
    local deletedDirs = {}
    if #wasaiRecentSavedFiles > 0 then
        for _, fp in ipairs(wasaiRecentSavedFiles) do
            if isfile and isfile(fp) then
                local ok = pcall(delfile, fp)
                if ok then deleted = deleted + 1 end
            end
        end
    end
    if wasaiLastDecompileDir and isfolder and isfolder(wasaiLastDecompileDir) then
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
        recDir(wasaiLastDecompileDir)
        pcall(delfolder, wasaiLastDecompileDir)
        deleted = deleted + dirDeleted
        table.insert(deletedDirs, wasaiLastDecompileDir)
    end
    if deleted == 0 then
        local dir = wasaiGetOutputDir()
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

    wasaiClearSavedFilesTracking()

    if deleted == 0 then
        return false, "没有找到可删除的文件。可能反编译时未成功保存文件。"
    end
    return true, deleted
end


wasaiLocalAIConfig = { -- [官方页面] 提为全局：原文件部分引用早于 local 声明
    enabled = true,
    endpoint = "https://api.deepseek.com/chat/completions",
    model = "deepseek-v4-flash",
    
    activeModel = "flash",
    
    isClaude = false,
    
    apiKey = "sk-eb2bb64f6a3c4d0ea916c26b053c2835",
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


local WASAAI_MODELS = {
    flash = {
        label = "Deepseek-V4-Flash",
        model = "deepseek-v4-flash",
        endpoint = "https://api.deepseek.com/chat/completions",
        apiKey = "sk-eb2bb64f6a3c4d0ea916c26b053c2835",
        isClaude = false,
    },
    pro = {
        label = "Deepseek-V4-Pro",
        model = "deepseek-v4-pro",
        endpoint = "https://api.deepseek.com/chat/completions",
        apiKey = "sk-eb2bb64f6a3c4d0ea916c26b053c2835",
        isClaude = false,
    },
    claude = {
        label = "Claude Haiku4.5",
        model = "claude-haiku-4-5",
        endpoint = "https://api.anthropic.com/v1/messages",
        apiKey = "sk-ant-api03-xxxxxxxxxxxxxxxxxxxx",  
        isClaude = true,
    },
    aiagent = {
        label = "Agent-2.5-flash",
        model = "agnes-2.5-flash",
        endpoint = "https://api.agnes-ai.cn/v1/chat/completions",
        apiKey = "sk-mkvUEEWp8sIFVTKjJt232s20BV4DO7mqzxpQPfJZMrJvoBn0",
        isClaude = false,
        noThinking = true,
        bypassPoints = false,
    },
}

function wasaiApplyModel(id)
    local m = WASAAI_MODELS[id] or WASAAI_MODELS.flash
    wasaiLocalAIConfig.model = m.model
    wasaiLocalAIConfig.endpoint = m.endpoint
    wasaiLocalAIConfig.apiKey = m.apiKey
    
    wasaiLocalAIConfig.isClaude = (id == "claude") or (m.isClaude == true)
    wasaiLocalAIConfig.noThinking = (m.noThinking == true)
    wasaiLocalAIConfig.bypassPoints = (m.bypassPoints == true)
    wasaiLocalAIConfig.activeModel = id
    if wasaiModelLabel then
        pcall(function()
            wasaiModelLabel.Text = m.label
            
            wasaiModelLabel.TextColor3 = m.isClaude and Color3.fromRGB(255, 200, 60) or theme.textDim
        end)
    end
    if _G.__DeltaAI_updateBadge then
        pcall(function() _G.__DeltaAI_updateBadge() end)
    end
end

local _aiModelSaved = loadConfig()
if _aiModelSaved and _aiModelSaved.activeModel and WASAAI_MODELS[_aiModelSaved.activeModel] then
    wasaiApplyModel(_aiModelSaved.activeModel)
end

local wasaiLocalAIState = {
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
    wasaiLocalAIConfig.thinkingDisabled = not enabled
end

local _aiSavedCfg = loadConfig()
if _aiSavedCfg and _aiSavedCfg.thinkingMode then
    wasaiLocalAIConfig.thinkingDisabled = false
end
_G.__DeltaAI_wasaiConfig = wasaiLocalAIConfig





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


local wasaiLastUsage = nil

local wasaiTotalTokens = 0


function wasaiSafeString(v, maxLen)
    local s = tostring(v or "")
    if maxLen and #s > maxLen then s = s:sub(1, maxLen) .. "…" end
    return s
end

local function wasaiNormalizeAIText(v)
    return tostring(v or ""):lower():gsub("%s+", ""):gsub(
        "[，。！？、,.!?：:；;“”\"'‘’（）()%[%]{}<>《》]", ""
    )
end




local function wasaiGetRecentContext(maxCount)
    local result = {}
    local history = wasaiChatMemory and wasaiChatMemory.conversationHistory or {}
    local n = tonumber(maxCount) or 12
    local start = math.max(1, #history - n + 1)
    for i = start, #history do
        local m = history[i]
        if type(m) == "table" then
            local content = wasaiSafeString(m.content or m.text or "", 900)
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


local function wasaiBuildSystemPrompt()
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

local function wasaiBuildLLMMessages(input)
    local context = {
        conversation = wasaiGetRecentContext(wasaiLocalAIConfig.maxContextMessages),
        memories = wasaiRetrieveMemory(input, wasaiLocalAIConfig.maxMemoryRecords),
    }

    local messages = {{role = "system", content = wasaiBuildSystemPrompt()}}
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
        content = wasaiSafeString(userContent, wasaiLocalAIConfig.maxPromptChars),
    }
    return messages, context
end





local function wasaiGetHttpRequestFn()
    local fn = (syn and syn.request) or (http and http.request) or http_request or request
    return fn
end


local function wasaiHttpPost(url, headers, body)
    local req = wasaiGetHttpRequestFn()
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

local WASAI_DEEPSEEK_TOOLS = {
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
    {type="function", ["function"]={name="click_gui", description="模拟点击GUI按钮。参数三选一：path(实例路径)、scaleX/scaleY(0-1相对坐标)、x/y(屏幕绝对像素)。", parameters={type="object", properties={path={type="string", description="GUI元素实例路径"}, scaleX={type="number", description="相对X(0-1)"}, scaleY={type="number", description="相对Y(0-1)"}, x={type="number", description="屏幕绝对X像素"}, y={type="number", description="屏幕绝对Y像素"}}}}}
}

local function wasaiSanitizeUTF8(s)
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

local function wasaiJSONEscape(s)
    s = wasaiSanitizeUTF8(s)
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    s = s:gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
    s = s:gsub("\b", "\\b"):gsub("\f", "\\f")
    s = s:gsub("[%c]", function(c) return string.format("\\u%04x", c:byte()) end)
    return s
end

local function wasaiJSONEncode(v)
    local t = type(v)
    if v == nil then return "null" end
    if t == "boolean" then return v and "true" or "false" end
    if t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return "null" end
        return tostring(v)
    end
    if t == "string" then return '"' .. wasaiJSONEscape(v) .. '"' end
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
            for i = 1, count do parts[i] = wasaiJSONEncode(v[i]) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        
        local parts = {}
        for k, val in pairs(v) do
            parts[#parts + 1] = '"' .. wasaiJSONEscape(k) .. '":' .. wasaiJSONEncode(val)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null" 
end








local function wasaiTokenizeDSML(content)
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

local function wasaiParseDSMLToolCalls(content)
    if type(content) ~= "string" then return nil end
    local calls = {}
    local currentCall = nil   
    local paramName = nil     
    local paramVal = nil      
    local inCalls = false     

    local seq = wasaiTokenizeDSML(content)
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


local function wasaiStripDSML(content)
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



local function wasaiDeepSeekChat(messages, tools, opts)
    opts = opts or {}
    local isClaude = wasaiLocalAIConfig.isClaude
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
            model = wasaiLocalAIConfig.model,
            max_tokens = opts.maxTokens or wasaiLocalAIConfig.maxTokens or 4096,
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
        
        if not wasaiLocalAIConfig.thinkingDisabled then
            body.thinking = { type = "enabled", budget_tokens = 1024 }
        end
    else
        body = {
            model = wasaiLocalAIConfig.model,
            messages = messages,
            temperature = opts.temperature or wasaiLocalAIConfig.temperature,
            stream = false,
        }
        
        if not wasaiLocalAIConfig.noThinking and wasaiLocalAIConfig.thinkingDisabled then
            body.thinking = {type = "disabled"}
        end
        local maxTok = opts.maxTokens or wasaiLocalAIConfig.maxTokens
        if maxTok and maxTok > 0 then
            body.max_tokens = maxTok
        end
        if tools and #tools > 0 then
            body.tools = tools
            body.tool_choice = "auto"
        end
    end

    local okEnc, bodyJson = pcall(wasaiJSONEncode, body)
    if not okEnc or type(bodyJson) ~= "string" or bodyJson == "" then
        return nil, nil, "JSON编码失败: " .. tostring(bodyJson)
    end

    
    local reqUrl = wasaiLocalAIConfig.endpoint
    local reqHeaders
    if isClaude then
        reqHeaders = {
            ["Content-Type"] = "application/json",
            ["x-api-key"] = tostring(wasaiLocalAIConfig.apiKey),
            ["anthropic-version"] = "2023-06-01",
        }
    else
        reqHeaders = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. tostring(wasaiLocalAIConfig.apiKey),
        }
    end
    if _G.__DeltaUI_pointsEnabled and not wasaiLocalAIConfig.bypassPoints then
        local precheck = _G.__DeltaUI_precheck
        if type(precheck) == "function" then
            local okBal, curBal, needCost, reason = precheck(messages)
            if not okBal then
                if reason == "sync" then
                    warn("[DeltaUI][Points] 预检同步失败: " .. tostring(wasaiGHLastErr))
                    return nil, nil, "积分同步失败：" .. tostring(wasaiGHLastErr)
                end
                return nil, nil, "积分不足，本次对话需 " .. tostring(needCost or 0) .. " 积分，当前余额 " .. tostring(curBal or 0)
            end
        end
    end

    local ok, code, respBody, statusMsg = wasaiHttpPost(
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
            hint = hint .. " " .. wasaiSafeString(respBody, 300)
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
        return nil, nil, "响应解析失败: " .. wasaiSafeString(respBody, 200)
    end

    
    if _G.__DeltaUI_pointsEnabled and not wasaiLocalAIConfig.bypassPoints and type(data.usage) == "table" then
        local used
        if isClaude then
            used = (tonumber(data.usage.input_tokens) or 0) + (tonumber(data.usage.output_tokens) or 0)
        else
            used = tonumber(data.usage.total_tokens) or 1
        end
        if used < 1 then used = 1 end
        local deduct = _G.__DeltaUI_deduct
        if type(deduct) == "function" then deduct(used) end
    end

    
    if type(data.usage) == "table" then
        wasaiLastUsage = data.usage
        if isClaude then
            wasaiTotalTokens = wasaiTotalTokens + (tonumber(data.usage.input_tokens) or 0) + (tonumber(data.usage.output_tokens) or 0)
        else
            wasaiTotalTokens = wasaiTotalTokens + (tonumber(data.usage.total_tokens) or 0)
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
            wasaiLocalAIState.lastReasoning = reasoningBuf
        else
            wasaiLocalAIState.lastReasoning = nil
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
        wasaiLocalAIState.lastReasoning = reasoning
    else
        wasaiLocalAIState.lastReasoning = nil
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
        
        local dsml = wasaiParseDSMLToolCalls(content)
        if dsml then
            toolCalls = dsml
            content = wasaiStripDSML(content)
        end
    end

    return content, toolCalls, nil
end


local function wasaiSetSessionTitle(title)
    if not title or title == "" then return end
    wasaiCurrentSession.sessionTitle = tostring(title)
    if wasaiCurrentSession.sessionFile and isfile and listfiles then
        local dir = wasaiCurrentSession.sessionDir
        local safeTitle = tostring(title):gsub("[/\\:*?\"<>|\r\n\t ]+", "_"):gsub("^_+", ""):gsub("_+$", "")
        if safeTitle == "" then safeTitle = "default" end
        if #safeTitle > 40 then safeTitle = safeTitle:sub(1, 40) end
        local newPath = dir .. "/" .. safeTitle .. ".chat"
        if newPath ~= wasaiCurrentSession.sessionFile and isfile(newPath) then
            newPath = dir .. "/" .. safeTitle .. "_" .. os.time() .. ".chat"
        end
        if newPath ~= wasaiCurrentSession.sessionFile then
            pcall(function()
                if isfile(wasaiCurrentSession.sessionFile) then
                    local content = readfile(wasaiCurrentSession.sessionFile)
                    if content then writefile(newPath, content) end
                    delfile(wasaiCurrentSession.sessionFile)
                end
            end)
            wasaiCurrentSession.sessionFile = newPath
            wasaiCurrentSession.sessionKey = safeTitle
        end
    end
    wasaiSaveChatHistory()
end


local function wasaiListAllChats()
    wasaiEnsureAgentFolders()
    local placeId = tostring(game.PlaceId or 0)
    local folder = "DeltaUI/Agent/Chat/对话_" .. placeId
    local list = {}
    if not isfolder(folder) or not listfiles then return list end
    local ok, files = pcall(listfiles, folder)
    if not ok or type(files) ~= "table" then return list end
    for _, path in ipairs(files) do
        if isfile(path) and path:match("%.chat$") then
            local data = wasaiReadChatFile(path)
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


local function wasaiCallLLM(messages)
    local started = tick()
    if wasaiMetrics.thinkingStartTime == 0 then
        wasaiMetrics.thinkingStartTime = started
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

    local content, _, apiErr = wasaiDeepSeekChat(messages, nil)
    local answer
    if content and content ~= "" then
        wasaiLocalAIState.mode = "api"
        answer = content
    else
        warn("[DeltaUI][AI] API 不可用(" .. tostring(apiErr) .. ")")
        wasaiLocalAIState.mode = "api"
        wasaiLocalAIState.lastError = apiErr
        wasaiLocalAIState.failures = (wasaiLocalAIState.failures or 0) + 1
        answer = "抱歉，当前无法连接到 AI 服务（" .. tostring(apiErr) .. "）。请稍后重试。"
    end

    do 
        local forbidden = {"我结合了之前的对话上下文","我是 DeltaUI 内置智能助手","我分析了你的请求","我会继续推理","根据上下文判断","我是基于关键词","关键词匹配","关键词触发","关键词感知","我的意图识别系统","根据意图评分","根据语义特征权重","我的回复库","从回复模板"}
        for _, word in ipairs(forbidden) do answer = answer:gsub(word, "") end
        answer = answer:gsub("^%s+", ""):gsub("%s+$", "")
    end

    wasaiLocalAIState.available = true
    wasaiLocalAIState.lastLatency = math.max(0, tick() - started)
    return answer
end

local function wasaiTryParseToolCall(text)
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

local function wasaiShowConfirmDialog(code)
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


local wasaiToolState = {
    noclip = {active = false, conn = nil},
    antiFling = {active = false, conn = nil},
}


local function wasaiSetNoclip(enabled)
    local state = wasaiToolState.noclip
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


local function wasaiSetAntiFling(enabled)
    local state = wasaiToolState.antiFling
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







local wasaiRemoteCapture
do
    local wasaiRemoteHookInstalled = false
    local wasaiRemoteHookOldNamecall = nil
    local wasaiRemoteCaptureEnabled = false
    local wasaiRemoteBuffer = {}
    local wasaiRemoteNoise = {"ping", "fps", "heartbeat", "heart", "latency", "requestping", "updateping", "getping", "sendping", "clientheartbeat"}

    local function wasaiRemoteGetInstancePath(inst)
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
            prefix = wasaiRemoteGetInstancePath(parent)
        end
        local path = prefix
        for _, pname in ipairs(parts) do
            path = path .. ":WaitForChild(" .. pname .. ")"
        end
        return path
    end

    local function wasaiRemoteFormatArg(arg)
        if type(arg) == "table" then
            if getmetatable(arg) and getmetatable(arg).__tostring then
                return tostring(arg)
            end
            return "{...}"
        elseif type(arg) == "Instance" then
            return wasaiRemoteGetInstancePath(arg)
        elseif type(arg) == "string" then
            return string.format("%q", arg)
        elseif type(arg) == "nil" then
            return "nil"
        else
            return tostring(arg)
        end
    end

    local function wasaiRemoteFormatCall(remoteObject, methodName, args)
        local remotePath = wasaiRemoteGetInstancePath(remoteObject)
        local argStrings = {}
        for i, v in ipairs(args) do
            argStrings[i] = wasaiRemoteFormatArg(v)
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

    local function wasaiRemoteInstallHook()
        if wasaiRemoteHookInstalled then return true end
        if not getrawmetatable or not setreadonly or not getnamecallmethod or not newcclosure then return false end
        local meta = getrawmetatable(game)
        if not meta then return false end
        local ok = pcall(function()
            setreadonly(meta, false)
            wasaiRemoteHookOldNamecall = meta.__namecall
            meta.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                local result
                if wasaiRemoteCaptureEnabled and (method == "FireServer" or method == "InvokeServer") then
                    local args = {...}
                    pcall(function()
                        local low = wasaiRemoteGetInstancePath(self):lower()
                        local skip = false
                        for _, n in ipairs(wasaiRemoteNoise) do
                            if low:find(n, 1, true) then skip = true break end
                        end
                        if not skip then
                            table.insert(wasaiRemoteBuffer, {
                                path = low,
                                method = method,
                                script = wasaiRemoteFormatCall(self, method, args),
                                time = os.time(),
                            })
                            if #wasaiRemoteBuffer > 60 then table.remove(wasaiRemoteBuffer, 1) end
                        end
                    end)
                end
                if wasaiRemoteHookOldNamecall then
                    result = wasaiRemoteHookOldNamecall(self, ...)
                else
                    result = self[method](self, ...)
                end
                return result
            end)
        end)
        if ok then wasaiRemoteHookInstalled = true end
        return ok
    end

    wasaiRemoteCapture = function(args)
        if not wasaiRemoteInstallHook() then
            return "无法安装 Remote 捕获钩子：当前执行器缺少 getrawmetatable/setreadonly/getnamecallmethod/newcclosure。"
        end
        local goal = tostring(args.goal or "")
        local timeout = tonumber(args.timeout) or 30
        if timeout < 3 then timeout = 3 elseif timeout > 120 then timeout = 120 end

        wasaiRemoteBuffer = {}
        wasaiRemoteCaptureEnabled = true
        local waitMsg = goal ~= "" and ("等待用户交互：请在游戏内操作「" .. goal .. "」以捕获 Remote…") or "等待用户交互：请在游戏内进行操作以捕获 Remote…"
        wasaiThinkingPhase = waitMsg
        wasaiCustomProgressMsg = waitMsg
        wasaiLastToolPhase = waitMsg

        local deadline = tick() + timeout
        local captured = {}
        while tick() < deadline do
            task.wait(0.2)
            if #wasaiRemoteBuffer > 0 then
                captured = wasaiRemoteBuffer
                wasaiRemoteBuffer = {}
                break
            end
        end
        wasaiRemoteCaptureEnabled = false

        if #captured == 0 then
            wasaiThinkingPhase = "未捕获到相关 Remote"
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
        wasaiThinkingPhase = "已捕获 Remote，继续处理"
        return table.concat(lines, "\n")
    end
end







local wasaiGoTo
do
    local function wasaiResolveTarget(args)
        args = args or {}
        local path = tostring(args.path or "")
        if path ~= "" then
            local obj, err = wasaiGetInstanceFromPath(path)
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

    local function wasaiSmoothTo(root, targetPos, step, waitTime)
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

    local function wasaiPathwalk(humanoid, root, targetPos, timeout)
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

    wasaiGoTo = function(args)
        local targetPos, err = wasaiResolveTarget(args)
        if not targetPos then return "无法解析目标位置: " .. tostring(err) end

        local lp = svc.Players and svc.Players.LocalPlayer
        if not lp then return "没有本地玩家" end
        local char = lp.Character
        if not char then return "角色不存在，请等待角色加载" end
        local root = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not root or not humanoid then return "找不到 HumanoidRootPart 或 Humanoid" end

        wasaiThinkingPhase = "正在移动玩家到目标位置…"
        wasaiLastToolPhase = "正在移动玩家到目标位置…"
        local targetStr = string.format("(%.1f, %.1f, %.1f)", targetPos.X, targetPos.Y, targetPos.Z)
        local report = {}
        local orig = root.Position

        
        pcall(function() root.CFrame = CFrame.new(targetPos) end)
        task.wait(0.35)
        if (root.Position - targetPos).Magnitude < 5 then
            wasaiThinkingPhase = "已直接传送到目标"
            return "已直接传送到 " .. targetStr .. "。"
        end
        table.insert(report, "直接传送被拉回（当前距目标 " .. string.format("%.1f", (root.Position - targetPos).Magnitude) .. "），改用平滑传送…")

        
        local okSmooth = pcall(wasaiSmoothTo, root, targetPos, 3, 0.05)
        if okSmooth then
            wasaiThinkingPhase = "已平滑传送到目标"
            return "已通过平滑传送到达 " .. targetStr .. "。"
        end
        table.insert(report, "平滑传送仍被拉回，改用更慢的平滑传送…")

        
        local okSlow = pcall(wasaiSmoothTo, root, targetPos, 1, 0.1)
        if okSlow then
            wasaiThinkingPhase = "已慢速传送到目标"
            return "已通过慢速平滑传送到达 " .. targetStr .. "。"
        end
        table.insert(report, "慢速传送仍被拉回，改用自动寻路步行…")

        
        local okWalk = pcall(wasaiPathwalk, humanoid, root, targetPos, 15)
        if okWalk then
            wasaiThinkingPhase = "已步行到达目标"
            return "已通过自动寻路步行到达 " .. targetStr .. "。"
        end

        return "所有移动方式均失败，最终位置 " .. tostring(root.Position) .. "，目标 " .. targetStr .. "。\n尝试记录：\n" .. table.concat(report, "\n")
    end
end






local wasaiClickGui
do
    local function wasaiClickAt(x, y)
        local ok = pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendMouseButtonEvent(x, y, 0, true, game, 1)
            task.wait(0.05)
            vim:SendMouseButtonEvent(x, y, 0, false, game, 1)
        end)
        return ok
    end

    local function wasaiResolveAbs(args)
        args = args or {}
        local x = tonumber(args.x)
        local y = tonumber(args.y)
        local path = tostring(args.path or "")
        if path ~= "" then
            local obj, err = wasaiGetInstanceFromPath(path)
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

    wasaiClickGui = function(args)
        local ax, ay, desc = wasaiResolveAbs(args)
        if not ax then return desc end
        wasaiThinkingPhase = "正在点击界面元素…"
        wasaiLastToolPhase = "正在点击界面元素…"

        
        
        local wasMainVisible = main and main.Visible
        local wasOrbVisible = orbFrame and orbFrame.Visible
        if wasMainVisible then main.Visible = false end
        if wasOrbVisible then orbFrame.Visible = false end
        task.wait() 

        local clicked = wasaiClickAt(ax, ay)

        
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
WASAI_FILE_TOOLS_MAX_CHARS = 12000   -- read_file 单次返回字符上限

local function wasaiFileSplitLines(text)
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

local function wasaiFileJoinLines(lines)
    return table.concat(lines, "\n")
end

-- 文本内容切成行数组；若以换行结尾，去掉尾部多出的空元素（避免多插一个空行）
local function wasaiFileContentToLines(content)
    content = tostring(content or "")
    local lines = wasaiFileSplitLines(content)
    if #lines > 1 and lines[#lines] == "" and content:sub(-1) == "\n" then
        table.remove(lines)
    end
    return lines
end

local function wasaiFileLineCount(text)
    return select(2, tostring(text or ""):gsub("\n", "")) + 1
end

local function wasaiFileCheckFs()
    if type(isfile) ~= "function" or type(readfile) ~= "function" or type(writefile) ~= "function" then
        return false, "当前执行器不支持文件读写接口（isfile/readfile/writefile）"
    end
    return true
end

local function wasaiFileReadRaw(path)
    local okFs, fsErr = wasaiFileCheckFs()
    if not okFs then return nil, fsErr end
    if not isfile(path) then return nil, "文件不存在: " .. tostring(path) end
    local ok, content = pcall(readfile, path)
    if not ok or type(content) ~= "string" then
        return nil, "读取失败: " .. tostring(content)
    end
    return content
end

local function wasaiFileEnsureParent(path)
    if type(isfolder) ~= "function" or type(makefolder) ~= "function" then return end
    local folder = tostring(path):match("^(.*)[/\\][^/\\]+$")
    if folder and folder ~= "" and not isfolder(folder) then
        pcall(makefolder, folder)
    end
end

local function wasaiEscapeLuaPattern(s)
    return (tostring(s or ""):gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

-- ---------------------------------------------------------------- read_file
local function wasaiToolReadFile(args)
    args = args or {}
    local path = tostring(args.path or "")
    if path == "" then return "[ERR] read_file: 缺少参数 path" end

    local content, err = wasaiFileReadRaw(path)
    if not content then return "[ERR] read_file: " .. tostring(err) end

    local lines = wasaiFileSplitLines(content)
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

    local maxChars = tonumber(args.max_chars) or WASAI_FILE_TOOLS_MAX_CHARS
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
local function wasaiToolEditFile(args)
    args = args or {}
    if type(isfile) ~= "function" or type(writefile) ~= "function" then
        return "[ERR] edit_file: 当前执行器不支持文件读写接口"
    end
    local path = tostring(args.path or "")
    if path == "" then return "[ERR] edit_file: 缺少参数 path" end

    local exists = isfile(path)
    local original = ""
    if exists then
        local content, err = wasaiFileReadRaw(path)
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

    local beforeLines = wasaiFileLineCount(original)
    local newContent = original
    local detail = ""
    local wrote = true

    if mode == "create" or mode == "overwrite" then
        newContent = tostring(args.content or "")
        detail = "整文件写入 " .. wasaiFileLineCount(newContent) .. " 行"

    elseif mode == "append" then
        local add = tostring(args.content or "")
        if add == "" then return "[ERR] edit_file: append 需要 content" end
        if original ~= "" and original:sub(-1) ~= "\n" then original = original .. "\n" end
        newContent = original .. add
        detail = "末尾追加 " .. wasaiFileLineCount(add) .. " 行"

    elseif mode == "prepend" then
        local add = tostring(args.content or "")
        if add == "" then return "[ERR] edit_file: prepend 需要 content" end
        newContent = add .. original
        detail = "开头插入"

    elseif mode == "insert" then
        local add = tostring(args.content or "")
        if add == "" then return "[ERR] edit_file: insert 需要 content" end
        local lines = wasaiFileSplitLines(original)
        local at = math.floor(tonumber(args.start_line) or tonumber(args.after_line) or 0)
        if at < 0 then at = 0 end
        if at > #lines then at = #lines end
        local addLines = wasaiFileContentToLines(add)
        local merged = {}
        for i = 1, at do merged[#merged + 1] = lines[i] end
        for _, l in ipairs(addLines) do merged[#merged + 1] = l end
        for i = at + 1, #lines do merged[#merged + 1] = lines[i] end
        newContent = wasaiFileJoinLines(merged)
        detail = string.format("在第 %d 行后插入 %d 行", at, #addLines)

    elseif mode == "replace_range" then
        local lines = wasaiFileSplitLines(original)
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
        local newLines = wasaiFileContentToLines(tostring(args.content or ""))
        local merged = {}
        for i = 1, s - 1 do merged[#merged + 1] = lines[i] end
        for _, l in ipairs(newLines) do merged[#merged + 1] = l end
        for i = e + 1, #lines do merged[#merged + 1] = lines[i] end
        newContent = wasaiFileJoinLines(merged)
        detail = string.format("替换第 %d-%d 行 → %d 行", s, e, #newLines)

    elseif mode == "replace_text" then
        local old = tostring(args.old or "")
        if old == "" then return "[ERR] edit_file: replace_text 需要参数 old" end
        local new = tostring(args.new or args.content or "")
        local pat = wasaiEscapeLuaPattern(old)
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

    wasaiFileEnsureParent(path)

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

    wasaiTrackFileOp(path)
    local afterLines = wasaiFileLineCount(newContent)
    return string.format("[OK] edit_file %s | %s | 行数 %d → %d%s",
        path, detail, beforeLines, afterLines,
        backupPath and (" | 备份: " .. backupPath) or "")
end

-- ---------------------------------------------------------------- del_file
local function wasaiToolDelFile(args)
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
    wasaiTrackFileOp(path)
    return "[OK] del_file 已删除: " .. path .. (trashed and (" | 回收站: " .. trashed) or "")
end

local function wasaiExecuteToolCall(tool, args)
    wasaiTrackToolCall()
    local ok, result = pcall(function()
        if tool == "list_children" then
            local path = tostring(args.path or "")
            local obj, err = wasaiGetInstanceFromPath(path)
            if not obj then return "路径不可达: " .. tostring(err) end
            wasaiChatMemory.lastPath = path
            local depth = tonumber(args.depth) or 1
            if depth < 1 then depth = 1 elseif depth > 3 then depth = 3 end
            local rows = wasaiListChildrenDepth(obj, depth)
            local shown = {}
            for i = 1, math.min(#rows, 80) do shown[i] = rows[i] end
            local text = table.concat(shown, "\n")
            if #rows > 80 then text = text .. "\n…共 " .. #rows .. " 行，仅显示前 80 行" end
            return text

        elseif tool == "decompile" then
            local path = tostring(args.path or "")
            local obj, err = wasaiGetInstanceFromPath(path)
            if not obj then return "路径不可达: " .. tostring(err) end
            wasaiChatMemory.lastPath = path
            local source, derr = wasaiTryDecompile(obj)
            if not source then return "反编译失败: " .. tostring(derr) end
            local savedPath = nil
            if writefile and makefolder and isfolder then
                local okSave, saveOk, savePath = pcall(wasaiSaveScriptToFile, obj, wasaiGetOutputDir(), nil)
                if okSave and saveOk then
                    savedPath = savePath
                    wasaiLastDecompileDir = wasaiGetOutputDir()
                end
            end
            local summary = "反编译成功，源码共 " .. #source .. " 字节。"
            if savedPath then summary = summary .. "已保存到: " .. tostring(savedPath) end
            return summary .. "\n源码开头预览:\n" .. source:sub(1, 2500)

        elseif tool == "decompile_all" then
            return tostring(wasaiDecompileAll("反编译所有脚本"))

        elseif tool == "decompile_smart" then
            local target = tostring(args.target or "")
            wasaiChatMemory.lastPath = target
            return tostring(wasaiDecompileSmart(target))

        elseif tool == "decompile_modules" then
            local target = tostring(args.target or "")
            if target ~= "" then wasaiChatMemory.lastPath = target end
            return tostring(wasaiDecompileModules(target))

        elseif tool == "get_property" then
            local obj, err = wasaiGetInstanceFromPath(tostring(args.path or ""))
            if not obj then return "路径不可达: " .. tostring(err) end
            local prop = tostring(args.property or "")
            local okRead, value = pcall(function() return obj[prop] end)
            if not okRead then return "属性读取失败: " .. tostring(value) end
            return prop .. " = " .. tostring(value)

        elseif tool == "list_properties" then
            local obj, err = wasaiGetInstanceFromPath(tostring(args.path or ""))
            if not obj then return "路径不可达: " .. tostring(err) end
            local props = wasaiListAllProperties(obj)
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
                if not wasaiShowConfirmDialog(code) then
                    return "__PERMISSION_DENIED__"
                end
            else
                wasaiThinkingPhase = "正在执行 Lua 代码"
                wasaiLastToolPhase = "正在执行 Lua 代码"
                task.wait()
            end
            local out, cerr = wasaiExecuteLuaCode(code)
            if not out then return "执行失败: " .. tostring(cerr) end
            return "执行成功: " .. out

        elseif tool == "find_objects" then
            local name = tostring(args.name or "")
            if name == "" then return "未提供搜索名称" end
            local matches = wasaiFindObjectsByName(name, game)
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
                local found = wasaiFindObjectsByName(name, root.obj)
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
            return "输出目录共有 " .. tostring(wasaiCountOutputFiles()) .. " 个文件"

        elseif tool == "list_output_files" then
            local dir = wasaiGetOutputDir()
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
            local okDel, deleted = wasaiDeleteRecentFiles()
            if okDel then return "已删除最近生成的文件，共清理 " .. tostring(deleted) .. " 个" end
            return "删除失败: " .. tostring(deleted)

        elseif tool == "noclip" then
            return wasaiSetNoclip(args.enabled ~= false)

        elseif tool == "anti_fling" then
            return wasaiSetAntiFling(args.enabled ~= false)

        elseif tool == "read_file" then
            return wasaiToolReadFile(args)

        elseif tool == "edit_file" then
            return wasaiToolEditFile(args)

        elseif tool == "del_file" or tool == "delete_file" or tool == "remove_file" then
            return wasaiToolDelFile(args)

        elseif tool == "report_progress" then
            local msg = wasaiSafeString(tostring(args.message or ""), 80)
            if msg ~= "" then
                wasaiThinkingPhase = msg
                wasaiCustomProgressMsg = msg
            end
            return "已向用户汇报进度: " .. msg

        elseif tool == "GotRemote" or tool == "gotremote" then
            return wasaiRemoteCapture(args)

        elseif tool == "go_to" or tool == "teleport" or tool == "move" then
            return wasaiGoTo(args)

        elseif tool == "click_gui" or tool == "click" then
            return wasaiClickGui(args)
        end

        return "未知工具: " .. tostring(tool)
    end)
    if not ok then return "工具执行出错: " .. tostring(result) end
    return tostring(result)
end


local function wasaiLooksIntermediate(content, toolCount)
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

local function wasaiGenerateResponseCore(input, authToken)
    
    
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
        messages, context = wasaiBuildLLMMessages(safeInput)
    end)
    if not okBuild then
        return "处理时遇到了内部异常，请重试一下。", {{phase = "error", output = tostring(buildErr)}}
    end
    table.insert(steps, {phase = "understand", output = "理解当前问题与多轮上下文"})
    table.insert(steps, {phase = "memory", output = "载入 " .. tostring(#(context.conversation or {})) .. " 条对话历史、" .. tostring(#(context.memories or {})) .. " 条相关长期记忆"})

    
    
    
    local maxIter = math.max(1, tonumber(wasaiLocalAIConfig.maxToolIterations) or 6)
    local finalAnswer = nil
    local toolCount = 0
    local apiFailed = false
    local apiError = nil
    local callHist = {}          
    local maxRepeats = 5
    local stallWarned = false    

    for iter = 1, maxIter do
        if wasaiCustomProgressMsg ~= "" then
            wasaiThinkingPhase = wasaiCustomProgressMsg
        elseif wasaiLastToolPhase ~= "" then
            wasaiThinkingPhase = wasaiLastToolPhase
        else
            wasaiThinkingPhase = "正在请求模型"
        end
        local content, toolCalls, apiErr = wasaiDeepSeekChat(messages, WASAI_DEEPSEEK_TOOLS)
        if apiErr then
            apiFailed = true
            apiError = apiErr
            break
        end

        wasaiLocalAIState.mode = "api"

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
                wasaiThinkingPhase = "正在调用工具: " .. toolName
                wasaiLastToolName = toolName
                wasaiLastToolPhase = "正在调用工具: " .. toolName
                -- 文件类工具结果更大，单独放宽上限（read_file 默认最多返回 12000 字符）
                local resultCap = 2500
                if toolName == "read_file" then
                    resultCap = 12000
                elseif toolName == "list_output_files" or toolName == "edit_file" then
                    resultCap = 4000
                end
                local toolResult = wasaiSafeString(wasaiExecuteToolCall(toolName, toolArgs), resultCap)

                
                local sig = toolName
                pcall(function()
                    if type(toolArgs) == "table" then
                        sig = toolName .. "|" .. svc.HttpService:JSONEncode(toolArgs)
                    end
                end)
                callHist[sig] = (callHist[sig] or 0) + 1
                if callHist[sig] > maxRepeats then
                    table.insert(steps, {phase = "execute", output = "检测到重复工具调用(" .. toolName .. ")，已终止循环"})
                    wasaiLocalAIState.lastToolCalls = toolCount
                    wasaiLocalAIState.lastLatency = math.max(0, tick() - started)
                    return "检测到重复的工具调用，为避免继续消耗积分已停止。请换一个更具体或不同的指令再试。", steps
                end

                wasaiLastToolOp.name = toolName
                wasaiLastToolOp.result = wasaiSafeString(toolResult, 500)
                wasaiLastToolOp.time = os.time()

                if toolResult == "__PERMISSION_DENIED__" then
                    local denyReplies = {
                        "执行权限被拒绝，我无法完成这个操作。",
                        "你没有授权执行这段代码，操作已取消。",
                        "代码执行请求未获批准，任务中止。",
                    }
                    local denyReply = denyReplies[math.random(#denyReplies)]
                    table.insert(steps, {phase = "execute", output = "用户拒绝了代码执行权限"})
                    pcall(function() wasaiSaveMemory(safeInput, denyReply) end)
                    wasaiLocalAIState.lastToolCalls = toolCount
                    wasaiLocalAIState.lastLatency = math.max(0, tick() - started)
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
            if wasaiEndThinkingRound then pcall(wasaiEndThinkingRound) end
            if wasaiStartThinkingRound then pcall(wasaiStartThinkingRound) end

            if not stallWarned and toolCount >= 5 then
                stallWarned = true
                table.insert(messages, {
                    role = "user",
                    content = "注意：你已经调用 " .. toolCount .. " 次工具仍未完成任务。如果用户明确要求修改数值（分数/速度/血量/属性等），立即用 execute_lua 直接完成修改，不要再问确认。如果信息已足够，直接给出结果、方案或代码并结束任务。不要再无意义地重复调用工具。",
                })
            end
            
        else
            
            if wasaiLooksIntermediate(content, toolCount) then
                table.insert(messages, {role = "assistant", content = content or ""})
                wasaiThinkingPhase = "继续处理中"
            else
                finalAnswer = (content and content ~= "") and content or "好的，我知道了。"
                break
            end
        end
    end

    if apiFailed then
        wasaiThinkingPhase = "API 不可用，正在重试"
        warn("[DeltaUI][AI] DeepSeek API 调用失败: " .. tostring(apiError))
        wasaiLocalAIState.lastError = apiError
        wasaiLocalAIState.failures = (wasaiLocalAIState.failures or 0) + 1
        wasaiLocalAIState.mode = "local"
        finalAnswer = "抱歉，当前无法连接到 AI 服务（" .. tostring(apiError) .. "）。请稍后重试。"
        table.insert(steps, {phase = "fallback", output = "API 不可用，已返回错误提示（" .. tostring(apiError) .. "）"})
    elseif not finalAnswer then
        wasaiThinkingPhase = "Agent正在输入…"
        wasaiLocalAIState.lastError = nil
        wasaiLocalAIState.failures = 0
        wasaiLocalAIState.mode = "api"
        local finalMessages = {}
        for _, m in ipairs(messages) do table.insert(finalMessages, m) end
        table.insert(finalMessages, {role = "user", content = "请基于以上所有工具执行结果，直接给出最终总结回答。不要再描述你接下来要做什么，直接输出结论。"})
        local content2, _, apiErr2 = wasaiDeepSeekChat(finalMessages, nil)
        if content2 and content2 ~= "" then
            finalAnswer = content2
        elseif toolCount > 0 then
            finalAnswer = "已执行 " .. toolCount .. " 次工具操作，结果请查看上方输出。如需继续，请直接告诉我。"
        else
            finalAnswer = "好的，我知道了。"
        end
        table.insert(steps, {phase = "generate", output = "工具循环后追加一次无工具请求以获取最终回复（" .. tostring(apiErr2 or "ok") .. "）"})
    else
        wasaiLocalAIState.lastError = nil
        wasaiLocalAIState.failures = 0
    end
    if type(finalAnswer) == "string" then
        if finalAnswer:match("^%s*{") then
            local _t, _a = wasaiTryParseToolCall(finalAnswer)
            if _t then
                finalAnswer = "好的，已处理你的请求。" .. (toolCount > 0 and ("（调用了 " .. toolCount .. " 次工具）") or "")
            end
        end
        
        if finalAnswer:find("<[%s|]-DSML", 1) or finalAnswer:find('invoke%s+name="', 1)
           or finalAnswer:find('parameter%s+name="', 1) then
            local stripped = wasaiStripDSML(finalAnswer)
            
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

    wasaiLocalAIState.lastToolCalls = toolCount
    wasaiLocalAIState.available = true
    wasaiLocalAIState.lastLatency = math.max(0, tick() - started)
    table.insert(steps, {phase = "generate", output = "DeepSeek API 生成回复（共调用 " .. toolCount .. " 次工具，模式: " .. wasaiLocalAIState.mode .. "）"})

    pcall(function() wasaiSaveMemory(safeInput, finalAnswer) end)
    return finalAnswer, steps
end

local wasaiMainFrame = create("Frame", {
    Name = "MainFrame",
    Size = UDim2.new(1, 0, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Visible = true,
    Parent = wasaiPage,
    ZIndex = 3
})
wasaiResumeParent = wasaiMainFrame

local wasaiTitleBar = create("Frame", {
    Name = "TitleBar",
    Size = UDim2.new(1, 0, 0, 32),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = theme.surfaceLight,
    BackgroundTransparency = 0.5,
    BorderSizePixel = 0,
    Parent = wasaiMainFrame,
    ZIndex = 4
})
corner(theme.radius, wasaiTitleBar)
stroke(theme.border, 1, wasaiTitleBar)

local wasaiTitleLabel = create("TextLabel", {
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
    Parent = wasaiTitleBar,
    ZIndex = 5
})


wasaiModelLabel = create("TextLabel", {
    Name = "ModelLabel",
    Size = UDim2.new(0, 96, 0, 20),
    Position = UDim2.new(1, -230, 0.5, -10),
    BackgroundTransparency = 1,
    Text = "Deepseek-V4-Flash",
    TextColor3 = theme.textDim,
    Font = Enum.Font.SourceSansBold,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Right,
    TextYAlignment = Enum.TextYAlignment.Center,
    Parent = wasaiTitleBar,
    ZIndex = 5
})
do
    local _m = WASAAI_MODELS[wasaiLocalAIConfig.activeModel or "flash"]
    if _m then
        wasaiModelLabel.Text = _m.label
        wasaiModelLabel.TextColor3 = _m.isClaude and Color3.fromRGB(255, 200, 60) or theme.textDim
    end
end

if type(updateExternalApiUI) == "function" then
    updateExternalApiUI()
end


local wasaiManageMode = false   -- 对话管理面板保留，暂时不开放入口
local wasaiSettingsButton = create("TextButton", {
    Name = "SettingsButton",
    Size = UDim2.new(0, 24, 0, 24),
    Position = UDim2.new(1, -30, 0.5, -12),
    BackgroundColor3 = theme.surfaceLight,
    BackgroundTransparency = 0.4,
    BorderSizePixel = 0,
    Text = "",
    Parent = wasaiTitleBar,
    ZIndex = 6
})
corner(6, wasaiSettingsButton)
local wasaiSettingsIcon = GetIcon("settings", UDim2.new(0, 15, 0, 15), theme.textDim)
if wasaiSettingsIcon then
    wasaiSettingsIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    wasaiSettingsIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
    wasaiSettingsIcon.Parent = wasaiSettingsButton
end
-- 设置按钮：暂不绑定任何事件


local wasaiPointsLabel
wasaiPointsBadgeRef = nil        
wasaiPointsBadgeStroke = nil     
wasaiPointsBadgeGradient = nil   
do
    local wasaiPointsBadge = create("Frame", {
        Name = "PointsBadge",
        Size = UDim2.new(0, 78, 0, 24),
        Position = UDim2.new(1, -114, 0.5, -12),  
        BackgroundColor3 = theme.accent,
        BackgroundTransparency = 0.78,
        BorderSizePixel = 0,
        Parent = wasaiTitleBar,
        ZIndex = 6
    })
    wasaiPointsBadgeRef = wasaiPointsBadge
    wasaiPointsBadgeGradient = applyGradient(wasaiPointsBadge, theme.accent, theme.accent2, 120)
    corner(12, wasaiPointsBadge)
    wasaiPointsBadgeStroke = stroke(theme.accent, 1, wasaiPointsBadge)
    wasaiPointsIcon = GetIcon("sparkles", UDim2.new(0, 15, 0, 15))
    if wasaiPointsIcon then
        wasaiPointsIcon.AnchorPoint = Vector2.new(0, 0.5)
        wasaiPointsIcon.Position = UDim2.new(0, 7, 0.5, 0)
        
        wasaiPointsIcon.ImageColor3 = wasaiLocalAIConfig.isClaude and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(230, 232, 240)
        wasaiPointsIcon.Parent = wasaiPointsBadge
    end
    wasaiPointsLabel = create("TextLabel", {
        Name = "PointsLabel",
        Size = UDim2.new(1, -26, 1, 0),
        Position = UDim2.new(0, 20, 0, 0),
        BackgroundTransparency = 1,
        Text = "0",
        TextColor3 = theme.text,
        TextSize = 12,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 7,
        Parent = wasaiPointsBadge
    })
end



local WASAI_POINTS_ENABLED = false
local wasaiPointsBalance = 0
local wasaiClaudeBalance = 0   
local wasaiPointsSynced = false
local wasaiPointsConsume
local wasaiEstimateTokens

do
    WASAI_GITEE_OWNER   = "WasKKalWe"
    WASAI_GITEE_REPO    = "return"
    WASAI_GITEE_BRANCH  = "master"
    WASAI_GITEE_TOKEN   = "ca3c508f3c95c480f903cede2cadd152"
    WASAI_POINTS_PATH   = "points"      
    WASAI_POINTS_ENABLED = (WASAI_GITEE_OWNER ~= "" and WASAI_GITEE_REPO ~= "" and WASAI_GITEE_TOKEN ~= "")
    wasaiPointsHwid = nil
    wasaiGHLastErr = ""
    local function wasaiHttpReq(method, url, headers, body)
        local function okResp(resp)
            if type(resp) == "table" then
                return true, resp.StatusCode or 200, resp.Body or "", resp.StatusMessage or ""
            end
            return false, 0, "", ""
        end
        
        local function optsFor(timeout)
            local o = { Url = url, Method = method, Headers = headers, Timeout = timeout }
            if body and body ~= "" then o.Body = body end
            return o
        end
        
        local execFn = (syn and syn.request) or (http and http.request) or http_request or request
        local channels = {}
        if execFn then
            channels[#channels + 1] = { run = function(o) return execFn(o) end, timeout = 20000, tag = "request" }
        end
        if svc.HttpService and svc.HttpService.RequestAsync then
            channels[#channels + 1] = { run = function(o) return svc.HttpService:RequestAsync(o) end, timeout = 20, tag = "RequestAsync" }
        end
        
        if #channels == 0 then
            wasaiGHLastErr = "[no-http] 无可用 HTTP 通道"
            return false, 0, wasaiGHLastErr, ""
        end
        local errs = {}
        for attempt = 1, 3 do
            for _, ch in ipairs(channels) do
                local ok, resp = pcall(ch.run, optsFor(ch.timeout))
                if ok then
                    local good, code, rbody, smsg = okResp(resp)
                    if good then return true, code, rbody, smsg end
                    errs[#errs + 1] = "[" .. ch.tag .. "] " .. tostring(resp)
                else
                    errs[#errs + 1] = "[" .. ch.tag .. " throw] " .. tostring(resp)
                end
            end
            if attempt < 3 then task.wait(0.4 * attempt) end
        end
        wasaiGHLastErr = table.concat(errs, " | ")
        return false, 0, wasaiGHLastErr, ""
    end

    
    local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local B64_IDX = {}
    for _i = 1, 64 do B64_IDX[B64_CHARS:sub(_i, _i)] = _i - 1 end
    local function wasaiBase64Encode(s)
        s = tostring(s or "")
        local out = {}
        local i = 1
        local n = #s
        while i <= n do
            local b1 = s:byte(i) or 0
            local b2 = s:byte(i + 1) or 0
            local b3 = s:byte(i + 2) or 0
            local c1 = math.floor(b1 / 4)
            local c2 = (b1 % 4) * 16 + math.floor(b2 / 16)
            local c3 = (b2 % 16) * 4 + math.floor(b3 / 64)
            local c4 = b3 % 64
            out[#out + 1] = B64_CHARS:sub(c1 + 1, c1 + 1) .. B64_CHARS:sub(c2 + 1, c2 + 1)
            if (i + 1) <= n then out[#out] = out[#out] .. B64_CHARS:sub(c3 + 1, c3 + 1) else out[#out] = out[#out] .. "=" end
            if (i + 2) <= n then out[#out] = out[#out] .. B64_CHARS:sub(c4 + 1, c4 + 1) else out[#out] = out[#out] .. "=" end
            i = i + 3
        end
        return table.concat(out)
    end
    local function wasaiBase64Decode(s)
        s = tostring(s or ""):gsub("%s", "")
        local out = {}
        local i = 1
        local n = #s
        while i <= n do
            local c1 = B64_IDX[s:sub(i, i)]
            local c2 = B64_IDX[s:sub(i + 1, i + 1)]
            local c3s = s:sub(i + 2, i + 2)
            local c4s = s:sub(i + 3, i + 3)
            local c3 = (c3s ~= "" and c3s ~= "=") and B64_IDX[c3s] or nil
            local c4 = (c4s ~= "" and c4s ~= "=") and B64_IDX[c4s] or nil
            if c1 and c2 then
                out[#out + 1] = string.char(c1 * 4 + math.floor(c2 / 16))
                if c3 then out[#out + 1] = string.char((c2 % 16) * 16 + math.floor(c3 / 4)) end
                if c4 then out[#out + 1] = string.char((c3 % 4) * 64 + c4) end
            end
            i = i + 4
        end
        return table.concat(out)
    end

    local function wasaiJSONDecode(s)
        if type(s) ~= "string" or s == "" then return nil end
        local d
        local ok = pcall(function() d = svc.HttpService:JSONDecode(s) end)
        if ok then return d end
        return nil
    end

    
    local function wasaiGHContentsUrl(path)
        return "https://gitee.com/api/v5/repos/" .. WASAI_GITEE_OWNER .. "/" .. WASAI_GITEE_REPO .. "/contents/" .. path
    end
    local function wasaiGHReadUrl(path)
        return wasaiGHContentsUrl(path) .. "?access_token=" .. WASAI_GITEE_TOKEN .. "&ref=" .. WASAI_GITEE_BRANCH
    end
    local function wasaiGHHeaders()
        return { ["Content-Type"] = "application/json" }
    end
    
    local function wasaiGHReadFile(path)
        local ok, code, respBody = wasaiHttpReq("GET", wasaiGHReadUrl(path), wasaiGHHeaders(), "")
        if not ok then
            wasaiGHLastErr = "read-net " .. tostring(wasaiGHLastErr)
            return nil, nil
        end
        if code < 200 or code >= 300 then
            wasaiGHLastErr = "read-http " .. tostring(code) .. " " .. tostring(wasaiSafeString(respBody, 160))
            return nil, nil
        end
        local d = wasaiJSONDecode(respBody)
        if type(d) ~= "table" or type(d.content) ~= "string" then
            wasaiGHLastErr = "read-parse"
            return nil, nil
        end
        local obj = wasaiJSONDecode(wasaiBase64Decode(d.content))
        if type(obj) ~= "table" then
            wasaiGHLastErr = "read-json"
            return nil, nil
        end
        return obj, d.sha
    end
    
    local function wasaiGHWriteFile(path, content, sha)
        local function writeOnce(s)
            local method = s and "PUT" or "POST"
            local b = {
                access_token = WASAI_GITEE_TOKEN,
                message = "DeltaUI points update",
                content = wasaiBase64Encode(content),
                branch = WASAI_GITEE_BRANCH,
            }
            if s then b.sha = s end
            return wasaiHttpReq(method, wasaiGHContentsUrl(path), wasaiGHHeaders(), wasaiJSONEncode(b))
        end
        local ok, code, respBody = writeOnce(sha)
        if not ok then
            wasaiGHLastErr = "write-net " .. tostring(wasaiGHLastErr)
            return false
        end
        
        if code >= 400 and code < 500 then
            local _, s2 = wasaiGHReadFile(path)
            if s2 then ok, code, respBody = writeOnce(s2) end
        end
        if not ok then
            wasaiGHLastErr = "write-net " .. tostring(wasaiGHLastErr)
            return false
        end
        if code < 200 or code >= 300 then
            wasaiGHLastErr = "write-http " .. tostring(code) .. " " .. tostring(wasaiSafeString(respBody, 160))
            return false
        end
        return true
    end

    local function wasaiPointsPath(name)
        local base = (WASAI_POINTS_PATH == "") and "" or (WASAI_POINTS_PATH .. "/")
        return base .. name
    end

    local wasaiPointsConfigData = nil
    local function wasaiPointsConfigCached()
        if wasaiPointsConfigData then return wasaiPointsConfigData end
        local def = {
            dailyReward = 0, newUserReward = 0, costPerToken = 0.1,
            minCostPerRequest = 1, maxCostPerRequest = 3000, maxUserBalance = 100000000,
            
            claudeCostPerToken = 0.15, claudeMinCostPerRequest = 1, claudeMaxCostPerRequest = 5000,
        }
        local cfg = wasaiGHReadFile(wasaiPointsPath("config.json"))
        if type(cfg) == "table" then
            wasaiPointsConfigData = {
                dailyReward = tonumber(cfg.dailyReward) or def.dailyReward,
                newUserReward = tonumber(cfg.newUserReward) or def.newUserReward,
                costPerToken = tonumber(cfg.costPerToken) or def.costPerToken,
                minCostPerRequest = tonumber(cfg.minCostPerRequest) or def.minCostPerRequest,
                maxCostPerRequest = tonumber(cfg.maxCostPerRequest) or def.maxCostPerRequest,
                maxUserBalance = tonumber(cfg.maxUserBalance) or def.maxUserBalance,
                claudeCostPerToken = tonumber(cfg.claudeCostPerToken) or def.claudeCostPerToken,
                claudeMinCostPerRequest = tonumber(cfg.claudeMinCostPerRequest) or def.claudeMinCostPerRequest,
                claudeMaxCostPerRequest = tonumber(cfg.claudeMaxCostPerRequest) or def.claudeMaxCostPerRequest,
            }
        else
            wasaiPointsConfigData = def
        end
        return wasaiPointsConfigData
    end

    
    
    local function wasaiLoadRemoteModels()
        local cfg = wasaiGHReadFile(wasaiPointsPath("config.json"))
        if type(cfg) ~= "table" or type(cfg.models) ~= "table" then return end
        for id, prof in pairs(cfg.models) do
            local cur = WASAAI_MODELS[id]
            if cur and type(prof) == "table" then
                if prof.label then cur.label = tostring(prof.label) end
                if prof.model then cur.model = tostring(prof.model) end
                if prof.endpoint then cur.endpoint = tostring(prof.endpoint) end
                if prof.isClaude ~= nil then cur.isClaude = (prof.isClaude == true or prof.isClaude == "true") end
            end
        end
        
        wasaiApplyModel(wasaiLocalAIConfig.activeModel or "flash")
    end
    _G.__DeltaAI_loadRemoteModels = wasaiLoadRemoteModels

    local function wasaiPointsCalcCost(cfg, tokens, isClaude)
        local raw
        if isClaude then
            raw = math.ceil(tokens * tonumber(cfg.claudeCostPerToken or cfg.costPerToken or 0))
        else
            raw = math.ceil(tokens * tonumber(cfg.costPerToken or 0))
        end
        local minc = isClaude and (tonumber(cfg.claudeMinCostPerRequest) or 1) or (tonumber(cfg.minCostPerRequest) or 1)
        local maxc = isClaude and (tonumber(cfg.claudeMaxCostPerRequest) or 500) or (tonumber(cfg.maxCostPerRequest) or 500)
        
        return math.max(minc, math.min(raw, maxc))
    end


local function wasaiGetHwid()
    if wasaiPointsHwid then return wasaiPointsHwid end
    local file = "DeltaUI/hwid.dat"
    local stored = nil
    if isfile and readfile and isfile(file) then
        stored = readfile(file)
    end
    local hwid
    if stored and stored ~= "" then
        
        hwid = stored
    else
        
        local real = nil
        local getgenv_ = getgenv or function() return _G end
        for _, fnName in ipairs({"gethwid", "get_hwid", "getdeviceid", "get_device_id"}) do
            local fn = getgenv_()[fnName] or _G[fnName]
            if type(fn) == "function" then
                local ok, v = pcall(fn)
                if ok and type(v) == "string" and v ~= "" then real = v break end
            end
        end
        local seed = tostring(os.time()) .. "|" .. tostring(math.random()) .. "|" .. tostring(game.PlaceId or 0)
        if real and real ~= "" then seed = seed .. "|hwid:" .. real end
        local acc = 5381
        for i = 1, #seed do acc = ((acc * 33) + seed:byte(i)) % 2147483647 end
        hwid = "d" .. tostring(acc)
        if writefile then
            pcall(function()
                if not isfolder("DeltaUI") then makefolder("DeltaUI") end
                writefile(file, hwid)
            end)
        end
    end
    wasaiPointsHwid = hwid
    return hwid
end

    local function wasaiPointsUserPath()
        return wasaiPointsPath("users/" .. wasaiGetHwid() .. ".json")
    end
    
    local function wasaiPointsMutateUser(mutator)
        local path = wasaiPointsUserPath()
        for attempt = 1, 3 do
            local u, sha = wasaiGHReadFile(path)
            local existed = type(u) == "table"
            if not existed then
                u = {
                    deviceId = wasaiGetHwid(),
                    balance = 0, claudeBalance = 0, totalEarned = 0, totalSpent = 0,
                    lastLoginDate = nil, totalRequests = 0, totalTokens = 0,
                    createdAt = os.time() * 1000, updatedAt = os.time() * 1000,
                }
            end
            local result, skipWrite = mutator(u, existed)
            u.updatedAt = os.time() * 1000
            if skipWrite then return u, result end
            if wasaiGHWriteFile(path, wasaiJSONEncode(u), sha) then
                return u, result
            end
            task.wait(0.4)
        end
        return nil, nil
    end

    
    local function wasaiPointsEnsureUser()
        local cfg = wasaiPointsConfigCached()
        local grantedToday = 0
        local u = wasaiPointsMutateUser(function(user, existed)
            local today = os.date("%Y-%m-%d")
            if not existed then
                user.balance = (user.balance or 0) + cfg.newUserReward
                user.claudeBalance = (user.claudeBalance or 0) + cfg.newUserReward
                user.totalEarned = (user.totalEarned or 0) + cfg.newUserReward
                grantedToday = grantedToday + cfg.newUserReward
                user.lastLoginDate = today
            elseif (user.lastLoginDate or "") ~= today then
                user.balance = (user.balance or 0) + cfg.dailyReward
                user.claudeBalance = (user.claudeBalance or 0) + cfg.dailyReward
                user.totalEarned = (user.totalEarned or 0) + cfg.dailyReward
                grantedToday = grantedToday + cfg.dailyReward
                user.lastLoginDate = today
            end
            user.balance = math.min(user.balance or 0, cfg.maxUserBalance)
            user.claudeBalance = math.min(user.claudeBalance or 0, cfg.maxUserBalance)
            
            if grantedToday == 0 and existed then return grantedToday, true end
            return grantedToday, false
        end)
        return u, grantedToday
    end

    
    local function wasaiPointsDeduct(tokens)
        local isClaude = wasaiLocalAIConfig.isClaude
        local cfg = wasaiPointsConfigCached()
        local cost = wasaiPointsCalcCost(cfg, tokens, isClaude)
        local u, costApplied = wasaiPointsMutateUser(function(user, existed)
            local bal = isClaude and (user.claudeBalance or 0) or (user.balance or 0)
            if not existed or bal < cost then return nil, true end
            if isClaude then
                user.claudeBalance = user.claudeBalance - cost
            else
                user.balance = user.balance - cost
            end
            user.totalSpent = (user.totalSpent or 0) + cost
            user.totalRequests = (user.totalRequests or 0) + 1
            user.totalTokens = (user.totalTokens or 0) + tokens
            return cost, false
        end)
        if u and costApplied then
            wasaiPointsBalance = tonumber(u.balance) or 0
            wasaiClaudeBalance = tonumber(u.claudeBalance) or 0
            wasaiPointsSynced = true
            if wasaiPointsLabel then
                wasaiPointsLabel.Text = tostring(isClaude and wasaiClaudeBalance or wasaiPointsBalance)
            end
        end
        return costApplied
    end

    
    local function wasaiPointsRefresh()
        if not WASAI_POINTS_ENABLED then return end
        task.spawn(function()
            for attempt = 1, 3 do
                local u, grantedToday = wasaiPointsEnsureUser()
                if type(u) == "table" then
                    wasaiPointsBalance = tonumber(u.balance) or 0
                    wasaiClaudeBalance = tonumber(u.claudeBalance) or 0
                    wasaiPointsSynced = true
                    local function applyLabel()
                        if wasaiPointsLabel then
                            wasaiPointsLabel.Text = tostring(wasaiLocalAIConfig.isClaude and wasaiClaudeBalance or wasaiPointsBalance)
                        end
                    end
                    applyLabel()
                    if not wasaiPointsLabel then
                        task.delay(1, function() applyLabel() end)
                        task.delay(3, function() applyLabel() end)
                    end
                    if grantedToday and grantedToday > 0 then
                        local ndate = os.date("%Y-%m-%d")
                        local nfile = "DeltaUI/last_daily.dat"
                        local shown = false
                        if isfile and readfile and isfile(nfile) then
                            shown = (readfile(nfile) == ndate)
                        end
                        if not shown then
                            ShowNotification("每日登录 +" .. tostring(grantedToday) .. " 积分", 2.5)
                            if writefile then
                                pcall(function()
                                    if not isfolder("DeltaUI") then makefolder("DeltaUI") end
                                    writefile(nfile, ndate)
                                end)
                            end
                        end
                    end
                    return
                end
                task.wait(2)
            end
            if wasaiPointsLabel then wasaiPointsLabel.Text = "0" end
            wasaiPointsSynced = false
            warn("[DeltaUI][Points] 同步失败: " .. tostring(wasaiGHLastErr))
            ShowNotification("积分同步失败：" .. tostring(wasaiGHLastErr), 4)
        end)
    end

    
    wasaiEstimateTokens = function(text)
        local s = tostring(text or "")
        local cjk = 0
        local latin = 0
        for _ in s:gmatch("[\228-\235][\128-\191][\128-\191]") do cjk = cjk + 1 end
        for _ in s:gmatch("[%z\1-\127]") do latin = latin + 1 end
        return math.max(1, cjk + math.ceil(latin / 4) + 3)
    end

    
    task.spawn(function()
        task.wait(1.5)
        wasaiPointsRefresh()
    end)

    
    _G.__DeltaUI_tryResumeChat = wasaiPromptResumeChat

    
    _G.__DeltaUI_redeemToken = function(key, statusCallback)
        if not WASAI_POINTS_ENABLED then
            if statusCallback then statusCallback("积分系统未启用，请先填写 GitHub 配置", false) end
            return
        end
        key = tostring(key or ""):gsub("[^%w]", ""):upper()
        if key == "" then
            if statusCallback then statusCallback("请输入兑换码", false) end
            return
        end
        task.spawn(function()
            local ok = false
            local msg = "兑换失败：无法连接 GitHub"
            local granted = 0
            for attempt = 1, 3 do
                local tokens, sha = wasaiGHReadFile(wasaiPointsPath("tokens.json"))
                if type(tokens) ~= "table" then break end
                local pkgs = tokens.packages or {}
                local pkg = pkgs[key]
                if not pkg then msg = "兑换码无效" break end
                if pkg.usedBy and pkg.usedBy ~= "" then msg = "兑换码已被使用" break end
                local pointsVal = tonumber(pkg.points) or 0
                if pointsVal <= 0 then msg = "兑换码无效" break end
                local isClaude = (pkg.type == "claude")
                pkgs[key] = nil
                tokens.packages = pkgs
                if wasaiGHWriteFile(wasaiPointsPath("tokens.json"), wasaiJSONEncode(tokens), sha) then
                    local u, costApplied = wasaiPointsMutateUser(function(user, existed)
                        if isClaude then
                            
                            if existed then
                                user.claudeBalance = (user.claudeBalance or 0) + pointsVal
                            else
                                user.claudeBalance = pointsVal
                            end
                            user.claudeBalance = math.min(user.claudeBalance or 0, wasaiPointsConfigCached().maxUserBalance)
                        else
                            if existed then
                                user.balance = (user.balance or 0) + pointsVal
                                user.totalEarned = (user.totalEarned or 0) + pointsVal
                            else
                                user.balance = pointsVal
                                user.totalEarned = pointsVal
                            end
                            user.balance = math.min(user.balance or 0, wasaiPointsConfigCached().maxUserBalance)
                        end
                        return pointsVal, false
                    end)
                    if u and costApplied then
                        granted = pointsVal
                        wasaiPointsBalance = tonumber(u.balance) or 0
                        wasaiClaudeBalance = tonumber(u.claudeBalance) or 0
                        wasaiPointsSynced = true
                        if _G.__DeltaAI_updateBadge then
                            pcall(function() _G.__DeltaAI_updateBadge() end)
                        elseif wasaiPointsLabel then
                            wasaiPointsLabel.Text = tostring(isClaude and wasaiClaudeBalance or wasaiPointsBalance)
                        end
                        ok = true
                    else
                        msg = "兑换失败：写入积分失败"
                    end
                    break
                end
                task.wait(0.4)
            end
            if statusCallback then
                if ok then
                    statusCallback("兑换成功 +" .. tostring(granted) .. (isClaude and " Claude积分" or " 积分"), true)
                else statusCallback(msg, false) end
            end
        end)
    end

    
    _G.__DeltaUI_pointsEnabled = WASAI_POINTS_ENABLED
    _G.__DeltaUI_setBalance = function(b)
        wasaiPointsBalance = b
        wasaiPointsSynced = true
        if wasaiPointsLabel then wasaiPointsLabel.Text = tostring(b) end
    end
    
    _G.__DeltaUI_precheck = function(messages)
        local isClaude = wasaiLocalAIConfig.isClaude
        local estTokens = 0
        if type(messages) == "table" then
            for _, m in ipairs(messages) do
                local c = (type(m) == "table") and (m.content or "") or ""
                if type(c) == "table" then
                    for _, part in ipairs(c) do
                        if type(part) == "table" then c = part.text or part.content or "" end
                    end
                end
                if type(c) == "string" and c ~= "" then estTokens = estTokens + wasaiEstimateTokens(c) end
            end
        end
        if estTokens < 1 then estTokens = 1 end
        local cfg = wasaiPointsConfigCached()
        local cost = wasaiPointsCalcCost(cfg, estTokens, isClaude)
        
        local u = wasaiPointsEnsureUser()
        if type(u) ~= "table" then
            return false, 0, cost, "sync"
        end
        local bal = isClaude and (tonumber(u.claudeBalance) or 0) or (tonumber(u.balance) or 0)
        if bal < cost then return false, bal, cost, "insufficient" end
        return true, bal, cost, "ok"
    end
    
    _G.__DeltaUI_deduct = function(tokens)
        return wasaiPointsDeduct(tokens)
    end
    
    _G.__DeltaUI_ensureInit = function()
        if not WASAI_POINTS_ENABLED then return end
        if wasaiPointsSynced then return end
        local u = wasaiPointsEnsureUser()
        if type(u) == "table" then
            wasaiPointsBalance = tonumber(u.balance) or 0
            wasaiClaudeBalance = tonumber(u.claudeBalance) or 0
            wasaiPointsSynced = true
            if wasaiPointsLabel then wasaiPointsLabel.Text = tostring(wasaiLocalAIConfig.isClaude and wasaiClaudeBalance or wasaiPointsBalance) end
        end
    end
    
    
    _G.__DeltaAI_updateBadge = function()
        local isClaude = wasaiLocalAIConfig.isClaude
        local gold = Color3.fromRGB(255, 200, 60)
        local m = WASAAI_MODELS[wasaiLocalAIConfig.activeModel or "flash"]
        if wasaiModelLabel then
            wasaiModelLabel.Text = (m and m.label) or wasaiLocalAIConfig.model
            wasaiModelLabel.TextColor3 = isClaude and gold or theme.textDim
        end
        if wasaiPointsLabel then
            wasaiPointsLabel.Text = tostring(isClaude and wasaiClaudeBalance or wasaiPointsBalance)
            wasaiPointsLabel.TextColor3 = isClaude and gold or theme.text
        end
        if wasaiPointsIcon then
            wasaiPointsIcon.ImageColor3 = isClaude and gold or Color3.fromRGB(230, 232, 240)
        end
        if wasaiPointsBadgeGradient then
            local from = isClaude and gold or theme.accent
            local to = isClaude and Color3.fromRGB(255, 230, 150) or theme.accent2
            pcall(function()
                wasaiPointsBadgeGradient.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, from),
                    ColorSequenceKeypoint.new(1, to),
                })
            end)
        end
        if wasaiPointsBadgeStroke then
            wasaiPointsBadgeStroke.Color = isClaude and gold or theme.accent
        end
    end
    
    _G.__DeltaAI_updateBadge()
    
    
    __lastGoldState = nil
    task.spawn(function()
        while true do
            task.wait(0.4)
            local ic = wasaiLocalAIConfig.isClaude
            if ic ~= __lastGoldState then
                __lastGoldState = ic
                if _G.__DeltaAI_updateBadge then
                    pcall(_G.__DeltaAI_updateBadge)
                end
            end
        end
    end)
    _G.__DeltaAI_getBalance = function()
        if wasaiLocalAIConfig.isClaude then return wasaiClaudeBalance end
        return wasaiPointsBalance
    end

end


task.spawn(function()
    task.wait(1.0)
    local loader = _G.__DeltaAI_loadRemoteModels
    if type(loader) == "function" then pcall(loader) end
end)

local wasaiDivider = create("Frame", {
    Size = UDim2.new(1, -32, 0, 1),
    Position = UDim2.new(0, 16, 0, 30),
    BackgroundColor3 = theme.border,
    BackgroundTransparency = 0.4,
    BorderSizePixel = 0,
    Parent = wasaiMainFrame,
    ZIndex = 4
})

wasaiMessageFrame = create("ScrollingFrame", {
    Name = "MessageFrame",
    Size = UDim2.new(1, -20, 1, -48 - 56 - 8),
    Position = UDim2.new(0, 10, 0, 52),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = theme.textDim,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    Parent = wasaiMainFrame,
    ZIndex = 3
})

local wasaiMessageListLayout = create("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment = Enum.VerticalAlignment.Top,
    Padding = UDim.new(0, 6),
    Parent = wasaiMessageFrame
})

local wasaiMessagePadding = create("UIPadding", {
    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6),
    PaddingTop = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),
    Parent = wasaiMessageFrame
})

wasaiMessageListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    if wasaiMessageFrame and wasaiMessageFrame.Parent then
        wasaiMessageFrame.CanvasSize = UDim2.new(0, 0, 0, wasaiMessageListLayout.AbsoluteContentSize.Y + 12)
    end
end)

local wasaiInputFrame = create("Frame", {
    Name = "InputFrame",
    Size = UDim2.new(1, -20, 0, 44),
    Position = UDim2.new(0, 10, 1, -54),
    BackgroundColor3 = theme.surface,
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    Parent = wasaiMainFrame,
    ZIndex = 4
})
corner(12, wasaiInputFrame)

wasaiInputBox = create("TextBox", {
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
    Parent = wasaiInputFrame,
    ZIndex = 5
})
corner(20, wasaiInputBox)
create("UIPadding", {PaddingLeft = UDim.new(0, 12)}).Parent = wasaiInputBox
wasaiInputBox.Focused:Connect(function()
    if wasaiInputBox.Text == "" then
        wasaiInputBox.PlaceholderText = "输入问题、指令或闲聊..."
    end
end)
wasaiInputBox.FocusLost:Connect(function()
    if wasaiInputBox.Text == "" then
        wasaiInputBox.PlaceholderText = "输入问题、指令或闲聊..."
    end
end)

wasaiSendButton = create("TextButton", {
    Name = "SendButton",
    Size = UDim2.new(0, 52, 0, 32),
    Position = UDim2.new(1, -58, 0.5, -16),
    BackgroundColor3 = theme.accent,
    Text = "发送",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 13,
    Font = Enum.Font.SourceSansBold,
    BorderSizePixel = 0,
    Parent = wasaiInputFrame,
    ZIndex = 5
})
applyGradient(wasaiSendButton, theme.accent, theme.accent2, 120)
corner(16, wasaiSendButton)


-- ===== 深度思考开关（胶囊按钮，位于输入框栏上方最左侧）=====
wasaiDeepThinkingEnabled = not wasaiLocalAIConfig.thinkingDisabled

local wasaiThinkPill = create("TextButton", {
    Name = "DeepThinkingPill",
    Size = UDim2.new(0, 106, 0, 26),
    Position = UDim2.new(0, 10, 1, -86),
    BackgroundColor3 = theme.surfaceLight,
    BackgroundTransparency = 0.45,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    Parent = wasaiMainFrame,
    ZIndex = 6
})
corner(13, wasaiThinkPill)   -- 13 = 高度一半，胶囊形

local wasaiThinkStroke = stroke(theme.border, 1, wasaiThinkPill)
local wasaiThinkGradient = applyGradient(wasaiThinkPill, theme.accent, theme.accent2, 120)
if wasaiThinkGradient then wasaiThinkGradient.Enabled = false end

local wasaiThinkIcon = GetIcon("atom", UDim2.new(0, 14, 0, 14), theme.textDim)
if wasaiThinkIcon then
    wasaiThinkIcon.Position = UDim2.new(0, 10, 0.5, -7)
    wasaiThinkIcon.Parent = wasaiThinkPill
end

local wasaiThinkText = create("TextLabel", {
    Position = UDim2.new(0, 29, 0, 0),
    Size = UDim2.new(1, -34, 1, 0),
    BackgroundTransparency = 1,
    Text = "深度思考",
    TextColor3 = theme.textDim,
    Font = Enum.Font.SourceSansBold,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    Parent = wasaiThinkPill,
    ZIndex = 7
})

wasaiApplyThinkPill = function(state)
    wasaiDeepThinkingEnabled = state and true or false
    if wasaiThinkGradient then wasaiThinkGradient.Enabled = wasaiDeepThinkingEnabled end
    wasaiThinkPill.BackgroundColor3 = wasaiDeepThinkingEnabled and Color3.fromRGB(255, 255, 255) or theme.surfaceLight
    wasaiThinkPill.BackgroundTransparency = wasaiDeepThinkingEnabled and 0 or 0.45
    if wasaiThinkStroke then
        wasaiThinkStroke.Color = wasaiDeepThinkingEnabled and theme.accent or theme.border
        wasaiThinkStroke.Transparency = wasaiDeepThinkingEnabled and 0.1 or 0.4
    end
    if wasaiThinkIcon then
        wasaiThinkIcon.ImageColor3 = wasaiDeepThinkingEnabled and Color3.fromRGB(255, 255, 255) or theme.textDim
    end
    wasaiThinkText.TextColor3 = wasaiDeepThinkingEnabled and Color3.fromRGB(255, 255, 255) or theme.textDim
    return wasaiDeepThinkingEnabled
end

wasaiApplyThinkPill(wasaiDeepThinkingEnabled)

-- 供设置卡等外部开关同步胶囊状态
_G.__DeltaAI_updateThinkPill = wasaiApplyThinkPill

wasaiThinkPill.MouseButton1Click:Connect(function()
    local nextState = not wasaiDeepThinkingEnabled
    wasaiApplyThinkPill(nextState)

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


local wasaiManageFrame = create("ScrollingFrame", {
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
    Parent = wasaiMainFrame,
    ZIndex = 3
})
local wasaiManageLayout = create("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Top,
    Padding = UDim.new(0, 8),
    Parent = wasaiManageFrame
})
create("UIPadding", {
    PaddingLeft = UDim.new(0, 6),
    PaddingRight = UDim.new(0, 6),
    PaddingTop = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),
    Parent = wasaiManageFrame
})
wasaiManageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    if wasaiManageFrame and wasaiManageFrame.Parent then
        wasaiManageFrame.CanvasSize = UDim2.new(0, 0, 0, wasaiManageLayout.AbsoluteContentSize.Y + 12)
    end
end)


local wasaiRefreshConversationList
local wasaiSetManageMode


local function wasaiLoadConversationEntry(entry)
    local ok = wasaiLoadChatHistory({path = entry.path, chatFile = entry.file, name = entry.name})
    if not ok then return end
    wasaiCurrentSession.isFirstRound = false
    for _, child in ipairs(wasaiMessageFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name == "MessageContainer" then child:Destroy() end
    end
    local history = wasaiChatMemory.conversationHistory or {}
    for _, msg in ipairs(history) do
        wasaiAddMessage(msg.content, msg.role == "user")
        task.wait(0.04)
    end
end


wasaiRefreshConversationList = function()
    for _, child in ipairs(wasaiManageFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    local entries = wasaiListAllChats()
    if #entries == 0 then
        local empty = create("Frame", {
            Name = "EmptyRow",
            Size = UDim2.new(1, -16, 0, 90),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = wasaiManageFrame
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
            Parent = wasaiManageFrame
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
            Text = wasaiSafeString(e.title, 26),
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
            wasaiRefreshConversationList()
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
            wasaiLoadConversationEntry(e)
            wasaiSetManageMode(false)
        end)
    end
end


wasaiSetManageMode = function(on)
    wasaiManageMode = on
    wasaiManageFrame.Visible = on
    wasaiMessageFrame.Visible = not on
    wasaiInputFrame.Visible = not on
    if wasaiThinkPill then wasaiThinkPill.Visible = not on end
    if wasaiSettingsButton then
        wasaiSettingsButton.BackgroundColor3 = on and theme.accent or theme.surfaceLight
    end
    wasaiTitleLabel.Text = on and "对话管理" or "AgentLess"
    if on then wasaiRefreshConversationList() end
end

-- 对话管理入口已移除（右上角改为设置按钮，暂不绑定事件）

wasaiFinalizeMessage = function(container, isUser)
    local avatar = container:FindFirstChild("Avatar")
    local bubble = container:FindFirstChild("Bubble")
    if not bubble then return end
    local noAvatar = (avatar == nil)
    task.defer(function()
        local frameW = wasaiMessageFrame.AbsoluteSize.X
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
            wasaiMessageFrame.CanvasPosition = Vector2.new(0, wasaiMessageFrame.CanvasSize.Y.Offset)
        end)
    end)
end


local function wasaiEscapeRich(s)
    s = tostring(s or "")
    s = s:gsub("&", "&amp;")
    s = s:gsub("<", "&lt;")
    s = s:gsub(">", "&gt;")
    return s
end

-- DeepSeek 标准围栏语言名 -> 统一短标签（卡片右上角显示）
WASAI_LANG_TAGS = {
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

function wasaiNormalizeLang(lang)
    if type(lang) ~= "string" then return "text" end
    lang = lang:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if lang == "" then return "text" end
    if WASAI_LANG_TAGS[lang] then return WASAI_LANG_TAGS[lang] end
    if #lang <= 12 and lang:match("^[%w_%+%-%.#]+$") then return lang end
    return "text"
end

-- 语言标签在卡片标题里的显示名
WASAI_LANG_TITLES = {
    lua = "Lua 代码", luau = "Luau 代码", text = "代码",
    json = "JSON", yaml = "YAML", html = "HTML", css = "CSS", sql = "SQL",
    sh = "Shell", bash = "Shell", js = "JavaScript", ts = "TypeScript", py = "Python",
}

function wasaiLangTitle(lang)
    return WASAI_LANG_TITLES[lang] or (string.upper(tostring(lang)) .. " 代码")
end

-- 行内 Markdown -> RichText（正文部分）
local function wasaiRenderAI(text)
    local s = wasaiEscapeRich(text):gsub("^\r?\n", "")
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
function wasaiIsLegacyCodeStart(reply, pos)
    local nxt = reply:sub(pos + 2, pos + 2)
    if nxt == "" or nxt == " " or nxt == "#" or nxt == "\n" or nxt == "\r" then return false end
    local close = reply:find("##", pos + 2, true)
    if not close then return false end
    local body = reply:sub(pos + 2, close - 1)
    if body == "" then return false end
    return body:find("[\n%(%=:]") ~= nil or body:find("print") ~= nil or body:find("local") ~= nil
end

function wasaiSplitReply(reply)
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

        local legacyHeading = (mode == "hash") and not wasaiIsLegacyCodeStart(reply, start)

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
                    parts[#parts + 1] = {type = "code", text = body, lang = wasaiNormalizeLang(tag)}
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

function wasaiAddMessage(text, isUser, stats, noAvatar)
    local container, bubble = wasaiCreateMessageContainer(text, isUser, nil, noAvatar)
    local label = create("TextLabel", {
        Name = "TextLabel",
        BackgroundTransparency = 1,
        Text = isUser and text or wasaiRenderAI(text),
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

    wasaiFinalizeMessage(container, isUser)
    return container
end

wasaiTypewriteMessage = function(text, isUser, stats)
    if isUser then return wasaiAddMessage(text, true) end
    local container, bubble = wasaiCreateMessageContainer("", false)

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

        
        local fullText = wasaiEscapeRich(text)
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
            wasaiMessageFrame.CanvasPosition = Vector2.new(0, wasaiMessageFrame.CanvasSize.Y.Offset)
        end)
    end
    stopCursorBlink()

    
    pcall(function()
        label.Text = wasaiRenderAI(text)
    end)

    wasaiFinalizeMessage(container, false)
    return container
end

local function wasaiShowDecompileResult(fullPath, source)
    local container, bubble = wasaiCreateMessageContainer("", false, theme.surfaceLight)
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

    wasaiFinalizeMessage(container, false)
    return container
end




local _aWAuthZx9K7 = "Dlt" .. "7kZq" .. "W2m9vR4x" .. "Q9n"

local function wasaiGenerateResponse(userInput, authToken)
    
    if authToken ~= _aWAuthZx9K7 then
        return "该接口仅允许 UI 内部调用，外部调用已被拒绝。", {
            {phase = "auth", output = "外部调用被拒绝，未消耗任何 token"}
        }
    end
    local input = tostring(userInput or "")
    if input:match("^%s*$") then return nil end

    if wasaiCheckSensitive(input) then
        return "针对这个问题我无法为你提供相应解答。你可以尝试提供其他话题，我会尽力为你提供支持和解答。", {
            {phase = "safety", output = "检测到敏感内容，已拒绝并引导到其他话题"}
        }
    end

    
    local cfgLocalUseApi = loadConfig()
    if not cfgLocalUseApi.useExternalApi then
        local lr = localModelChat(input)
        if lr and lr ~= "" then
            return lr, { {phase = "local", output = "本地模型回复（工具功能受限）"} }
        end
        return "本地模型暂时无法回复，请检查模型是否安装正确，或在设置中开启外部API。", {
            {phase = "error", output = "本地模型无有效输出"}
        }
    end

    local ok, reply, steps = pcall(wasaiGenerateResponseCore, input, _aWAuthZx9K7)
    if ok and reply and tostring(reply) ~= "" then
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
    return errReplies[math.random(#errReplies)], {
        {phase = "error", output = errText}
    }
end

local wasaiShowThinkingBubble
local wasaiRemoveThinkingBubble

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

    local function wasaiThinkBodyHeight(text)
        local frameW = 320
        pcall(function()
            if wasaiMessageFrame and wasaiMessageFrame.AbsoluteSize.X > 0 then
                frameW = wasaiMessageFrame.AbsoluteSize.X
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

    local function wasaiThinkSetBody(text)
        if not currentThinkingBody or not currentThinkingLabel then return end
        text = tostring(text or "")
        if text == currentThinkingLastText then return end
        currentThinkingLastText = text
        pcall(function()
            currentThinkingLabel.Text = text
            currentThinkingBody.Size = UDim2.new(1, -20, 0, wasaiThinkBodyHeight(text))
        end)
    end

    local function wasaiThinkSetExpanded(expanded)
        currentThinkingExpanded = expanded and true or false
        if currentThinkingBody then currentThinkingBody.Visible = currentThinkingExpanded end
        if currentThinkingChevron then
            currentThinkingChevron.Rotation = currentThinkingExpanded and 90 or 0
        end
    end

    wasaiThinkingSetExpanded = wasaiThinkSetExpanded

    wasaiShowThinkingBubble = function()
        -- 上一张还在进行中的卡片先收尾
        if currentThinkingContainer then
            pcall(wasaiRemoveThinkingBubble)
        end

        local container, bubble = wasaiCreateMessageContainer("", false, nil, true)
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

        wasaiThinkSetExpanded(true)
        wasaiFinalizeMessage(container, false)

        header.MouseButton1Click:Connect(function()
            wasaiThinkSetExpanded(not currentThinkingExpanded)
        end)

        -- 运行中：刷新计时 / 阶段文字 / 流式推理
        local startTime = currentThinkingStartTime
        currentThinkingThread = task.spawn(function()
            while currentThinkingContainer == container do
                local elapsed = tick() - startTime
                local phase = wasaiThinkingPhase or ""
                local reasoning = tostring(wasaiLocalAIState and wasaiLocalAIState.lastReasoning or "")

                if reasoning ~= "" then
                    wasaiThinkSetBody(reasoning)
                elseif phase ~= "" then
                    wasaiThinkSetBody(phase .. "…")
                end

                if currentThinkingStatus then
                    local suffix = phase ~= "" and (" · " .. phase) or ""
                    local ok = pcall(function()
                        currentThinkingStatus.Text = string.format("%.1fs", elapsed) .. suffix
                    end)
                    if not ok then break end
                end
                pcall(function()
                    wasaiMessageFrame.CanvasPosition = Vector2.new(0, wasaiMessageFrame.CanvasSize.Y.Offset)
                end)
                task.wait(0.1)
            end
        end)

        return container
    end

    wasaiRemoveThinkingBubble = function()
        wasaiThinkingPhase = ""
        wasaiCustomProgressMsg = ""
        wasaiLastToolName = ""
        wasaiLastToolPhase = ""

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
            local reasoning = tostring(wasaiLocalAIState and wasaiLocalAIState.lastReasoning or "")
            if reasoning ~= "" then
                finalText = reasoning
            elseif currentThinkingLastText ~= "" then
                finalText = currentThinkingLastText
            end
        end)
        if finalText ~= "" then
            pcall(wasaiThinkSetBody, finalText)
        else
            pcall(wasaiThinkSetBody, "（本轮没有返回思考内容）")
        end

        if currentThinkingStatus then
            pcall(function()
                currentThinkingStatus.Text = string.format("（用时 %.1f 秒）", elapsed)
            end)
        end

        -- 完成后自动收起，卡片留在对话里
        pcall(wasaiThinkSetExpanded, false)
    end

    -- 供工具循环使用：每完成一轮工具调用就收尾当前卡片、开启新一轮「深度思考」
    wasaiStartThinkingRound = function()
        return wasaiShowThinkingBubble()
    end
    wasaiEndThinkingRound = function()
        return wasaiRemoveThinkingBubble()
    end
end


local function wasaiSafeSpawn(fn, ...)
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

local function wasaiTrainingConsent()
    local cfg = loadConfig()
    return cfg and cfg.trainingUploadConsent == true
end

local function wasaiQueueTrainingPair(userText, assistantText)
    if not wasaiTrainingConsent() then return end
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
            if not wasaiTrainingConsent() then
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

local function wasaiTrainingQueueStatus()
    return #trainingUploadQueue
end

local function wasaiSaveLastScript()
    local history = wasaiChatMemory.conversationHistory or {}
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
    local sessionTitle = wasaiCurrentSession.sessionTitle or "新对话"
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

wasaiSendMessage = function()
    local text = wasaiInputBox.Text
    if not text or text:match("^%s*$") then return end

    
    
    local cfgSendUseApi = loadConfig()
    if not cfgSendUseApi.useExternalApi then
        if not localModelInstalled() then
            wasaiInputBox.Text = ""
            wasaiAddMessage(text, true)
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
        wasaiInputBox.Text = ""
        wasaiAddMessage(text, true)
        wasaiSafeSpawn(function()
            task.wait(0.2)
            local ok, result = wasaiSaveLastScript()
            if ok then
                wasaiAddMessage("✅ 脚本已保存到本地\n路径: " .. result, false)
            else
                wasaiAddMessage("❌ " .. result, false)
            end
        end)
        return
    end

        if text:match("^[加恢][载复]") and (wasaiCurrentSession.isFirstRound or not wasaiChatMemory.conversationHistory or #wasaiChatMemory.conversationHistory == 0) then
        local latest = wasaiFindLatestChat()
        if latest and wasaiLoadChatHistory(latest) then
            wasaiInputBox.Text = ""
            wasaiAddMessage("加载", true)
                        for _, child in ipairs(wasaiMessageFrame:GetChildren()) do
                if child:IsA("Frame") and child.Name == "MessageContainer" then
                    child:Destroy()
                end
            end
                        wasaiSafeSpawn(function()
                wasaiAddMessage("已恢复上次对话", false)
                if wasaiChatMemory.conversationHistory then
                    for i, msg in ipairs(wasaiChatMemory.conversationHistory) do
                        if i <= 20 then wasaiAddMessage(msg.content, msg.role == "user")
                        end
                    end
                end
                task.wait(0.5)
                local title = latest.name:gsub("^对话_", "")
                wasaiAddMessage("对话已加载: " .. title, false)
            end)
            return
        else
            wasaiInputBox.Text = ""
            wasaiAddMessage(text, true)
            wasaiSafeSpawn(function()
                task.wait(0.3)
                wasaiAddMessage("没有找到可恢复的历史对话", false)
            end)
            return
        end
    end

    
    local useExtForPoints = (loadConfig()).useExternalApi == true
    if useExtForPoints and WASAI_POINTS_ENABLED and not wasaiLocalAIConfig.bypassPoints and wasaiPointsSynced and wasaiPointsBalance <= 0 then
        wasaiInputBox.Text = ""
        wasaiAddMessage(text, true)
        wasaiSafeSpawn(function()
            task.wait(0.2)
            wasaiAddMessage("积分不足，暂时无法继续对话。请充值积分后重试。", false)
        end)
        return
    end

        wasaiResetMetrics()
    wasaiStartTiming()
    wasaiTotalTokens = 0  

    wasaiInputBox.Text = ""
    wasaiAddMessage(text, true)

        if wasaiCurrentSession.isFirstRound then
        local title = wasaiGenerateTitle(text)
        wasaiCurrentSession.sessionTitle = title
                wasaiInitSessionDir()
        wasaiRenameSessionDir(title)
        wasaiCurrentSession.isFirstRound = false
    end

        if not wasaiChatMemory.conversationHistory then
        wasaiChatMemory.conversationHistory = {}
    end
    table.insert(wasaiChatMemory.conversationHistory, {
        role = "user",
        content = text,
        timestamp = os.time()
    })

        local maxHist = tonumber(wasaiLocalAIConfig.maxHistoryMessages) or 20
        if #wasaiChatMemory.conversationHistory > maxHist then
            table.remove(wasaiChatMemory.conversationHistory, 1)
        end

    wasaiSafeSpawn(function()

        wasaiShowThinkingBubble()

        local okReply, reply = pcall(wasaiGenerateResponse, text, _aWAuthZx9K7)
        if not okReply or not reply or reply == "" then
            local errFallbacks = {
                "抱歉，处理时出现了问题，请稍后重试。",
                "出了点小状况，换个方式再试试？",
                "处理遇到异常，请重试或换个说法。",
            }
            reply = errFallbacks[math.random(#errFallbacks)]
        end

        if reply then
                            table.insert(wasaiChatMemory.conversationHistory, {
                role = "assistant",
                content = tostring(reply),
                model = wasaiLocalAIConfig.activeModel,
                modelLabel = (WASAAI_MODELS[wasaiLocalAIConfig.activeModel] and WASAAI_MODELS[wasaiLocalAIConfig.activeModel].label) or wasaiLocalAIConfig.model,
                timestamp = os.time()
            })
            wasaiQueueTrainingPair(text, tostring(reply))

            
            local elapsed = wasaiMetrics.thinkingStartTime > 0 and (tick() - wasaiMetrics.thinkingStartTime) or 0
            local complexity = wasaiMetrics.toolCalls * 0.8 + wasaiMetrics.fileOperations * 0.4
            local target = math.max(1.5, 1.5 + math.min(complexity, 3.0))
            if elapsed < target then
                task.wait(target - elapsed)
            end

            wasaiRemoveThinkingBubble()

            
            -- 思考内容已由「深度思考」卡片承载，不再单独发一条消息
            wasaiLocalAIState.lastReasoning = nil

            local statsText = wasaiGenerateStatsText(true)

                            wasaiSaveChatHistory()
            wasaiSaveMemory(text, tostring(reply))

            

            if type(reply) == "table" and reply.__type == "decompile" then
                wasaiShowDecompileResult(reply.filename, reply.source)
            elseif type(reply) == "table" and reply.__type == "script" then
                wasaiShowScriptResult(reply.title, reply.source)
            else
                local replyStr = tostring(reply)
                
                local usedCode = wasaiRenderMessageWithCode(replyStr, statsText)
                if not usedCode then
                    wasaiTypewriteMessage(replyStr, false, statsText)
                end
            end
        end
    end)
end
end

wasaiSendButton.MouseButton1Click:Connect(wasaiSendMessage)
wasaiInputBox.FocusLost:Connect(function(enterPressed)
    if enterPressed then wasaiSendMessage() end
end)

wasaiShowScriptResult = function(title, source, lang, noAvatar)
    source = tostring(source or "")
    lang = tostring(lang or "lua")
    local lineCount = select(2, source:gsub("\n", "")) + 1
    local cardTitle = wasaiLangTitle(lang)
    if type(title) == "string" and title ~= "" and title ~= "代码" then
        cardTitle = title
    end

    local container, bubble = wasaiCreateMessageContainer("", false, nil, noAvatar)
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

    wasaiFinalizeMessage(container, false)
    return container
end


-- 渲染整条回复：文本走气泡，围栏代码走代码卡（DeepSeek 标准排版）
wasaiRenderMessageWithCode = function(reply, stats)
    if type(reply) ~= "string" or reply == "" then return nil end

    local parts, hasCode = wasaiSplitReply(reply)
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
            wasaiAddMessage(block.text, false, st, not isFirst)
            if st then statsShown = true end
        else
            local title = (block.lang == "lua" or block.lang == "luau") and "脚本" or "代码"
            wasaiShowScriptResult(title, block.text, block.lang, not isFirst)
        end
        rendered = rendered + 1
    end

    if not statsShown and stats then
        wasaiAddMessage("", false, stats, true)
    end
    return true
end

function wasaiCreateMessageContainer(text, isUser, customBubbleColor, noAvatar)
    local container = create("Frame", {
        Name = "MessageContainer",
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = wasaiMessageFrame,
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
    model_flash = {en = "Deepseek-V4-Flash", zh = "Deepseek-V4-Flash", ko = "Deepseek-V4-Flash", ja = "Deepseek-V4-Flash"},
    model_pro = {en = "Deepseek-V4-Pro", zh = "Deepseek-V4-Pro", ko = "Deepseek-V4-Pro", ja = "Deepseek-V4-Pro"},
    model_claude = {en = "Claude Haiku4.5", zh = "Claude Haiku4.5", ko = "Claude Haiku4.5", ja = "Claude Haiku4.5"},
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

    local modelIds = {"flash", "pro", "claude", "aiagent"}
    local modelLabels = {"model_flash", "model_pro", "model_claude", nil}
    local modelOptions = {tr("model_flash"), tr("model_pro"), tr("model_claude"), "Agent-2.5-flash"}

    local rowExtApi = makeSettingRow("use_external_api", "use_external_api_desc", 1)
    if rowExtApi then rowExtApi.Parent = card end

    local rowModel = makeSettingRow("model_switch", "model_switch_desc", 2)
    if rowModel then rowModel.Parent = card end

    local rowThinking = makeSettingRow("thinking_mode", "thinking_mode_desc", 3)
    if rowThinking then rowThinking.Parent = card end

    local rowTraining = makeSettingRow("training_upload", "training_upload_desc", 4)
    if rowTraining then rowTraining.Parent = card end

    local function applyModelLabelVisible(state)
        local lbl = env.wasaiModelLabel
        if lbl then pcall(function() lbl.Visible = state end) end
    end

    local function refreshExternalRows(state)
        if rowModel then
            rowModel.Visible = state
            rowModel.Size = UDim2.new(1, 0, 0, state and 54 or 0)
        end
        if rowThinking then
            rowThinking.Visible = state
            rowThinking.Size = UDim2.new(1, 0, 0, state and 54 or 0)
        end
        applyModelLabelVisible(state)
    end

    local cfg = readCfg()
    local extEnabled = cfg.useExternalApi == true
    local trainingEnabled = cfg.trainingUploadConsent == true
    local thinkingEnabled = cfg.thinkingMode == true

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
                    writeCfg("activeModel", modelIds[i])
                    if type(env.wasaiApplyModel) == "function" then
                        pcall(env.wasaiApplyModel, modelIds[i])
                    end
                    break
                end
            end
        end)
    end

    if type(makeToggle) == "function" and rowThinking then
        makeToggle(rowThinking, thinkingEnabled, function(state)
            writeCfg("thinkingMode", state)
            local setter = G.__DeltaAI_setThinkingMode
            if type(setter) == "function" then pcall(setter, state) end
            
            local pill = G.__DeltaAI_updateThinkPill
            if type(pill) == "function" then pcall(pill, state) end
        end, "thinkingMode")
    end

    if type(makeToggle) == "function" and rowTraining then
        makeToggle(rowTraining, trainingEnabled, function(state)
            writeCfg("trainingUploadConsent", state == true)
            notify(state and "训练数据上传已开启" or "训练数据上传已关闭", 2)
        end, "trainingUploadConsent")
    end

    refreshExternalRows(extEnabled)
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
        if env.wasaiModelLabel then
            pcall(function() env.wasaiModelLabel.Visible = enabled end)
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
