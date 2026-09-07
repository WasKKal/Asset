DeltaPageInfo = {
    name = "deobfuscator",
    title = "反混淆工具",
    icon = "shield-check",
    dataFolder = "deobfuscator",
    version = "1.0.0",
}
local pageInfo = DeltaPageInfo

local function deobfSplitLines(src)
    local t = {}
    local pos = 1
    while pos <= #src do
        local nl = src:find("\n", pos, true)
        if nl then
            table.insert(t, src:sub(pos, nl - 1))
            pos = nl + 1
        else
            table.insert(t, src:sub(pos))
            break
        end
    end
    if #src == 0 or src:sub(-1) == "\n" then
        table.insert(t, "")
    end
    return t
end

local function deobfIsTypeColon(code, colonPos)
    local before = code:sub(1, colonPos - 1):match("%s*(%S+)%s*$")
    if not before then return false end

    local lastWord = before:match("([%a_][%w_]*)$")
    if lastWord then
        local prefix = before:sub(1, #before - #lastWord)
        local lastChar = prefix:sub(-1)
        if lastChar == "" then

            if lastWord == "local" or lastWord == "function" or lastWord == "for" or lastWord == "in" or lastWord == "return" then
                return false
            end
            return true
        end

        if lastChar:match("[%(%[%{%s,]") then
            if lastWord == "local" or lastWord == "function" or lastWord == "for" or lastWord == "in" or lastWord == "return" then
                return false
            end
            return true
        end
        return false
    end
    return before == ")" or before == "," or before == "(" or before == "[" or before == "{"
end

local function deobfSanitizeTypeAnnotations(src)
    if type(src) ~= "string" then return src end
    local out = {}
    for _, line in ipairs(deobfSplitLines(src)) do
        local s = line



        s = s:gsub("%)%s*:%s*%d[%d%.]*", ")")

        s = s:gsub(":%s*%d[%d%.]*", function(m)
            local colonPos = s:find(m, 1, true)
            if colonPos and deobfIsTypeColon(s, colonPos) then
                return ""
            end
            return m
        end)

        s = s:gsub("([^%w_])as%s+%d[%d%.]*", "%1")

        s = s:gsub("<%s*%d[%d%.]*[%s%d%,%.]*>", "<>")
        table.insert(out, s)
    end
    return table.concat(out, "\n")
end

local function deobfFixForInConstAssign(src)
    if type(src) ~= "string" then return src end
    local lines = {}
    for l in (src .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end

    local loops = {}
    for i = 1, #lines do
        local var = lines[i]:match("^%s*for%s+([%w_]+)%s+in%s+")
        if var then
            local depth = 0
            local started = false
            local bodyStart, bodyEnd
            for k = i, #lines do
                local K = lines[k]
                local blockOpen = 0
                for _ in K:gmatch("%f[%w_]do%f[^%w_]") do blockOpen = blockOpen + 1 end
                if not started then
                    if K:match("%f[%w_]do%f[^%w_]") then
                        started = true
                        depth = 1
                        bodyStart = k + 1
                    end
                else
                    depth = depth + blockOpen
                    if K:match("%f[%w_]end%f[^%w_]") then
                        depth = depth - 1
                        if depth == 0 then
                            bodyEnd = k - 1
                            break
                        end
                    end
                end
            end
            if bodyStart and bodyEnd and bodyEnd >= bodyStart then
                local reassigned = false
                for k = bodyStart, bodyEnd do
                    if lines[k]:match("[^=%w_]" .. var .. "%s*=[^=]")
                        or lines[k]:match("^%s*" .. var .. "%s*=[^=]") then
                        reassigned = true
                        break
                    end
                end
                if reassigned then
                    loops[#loops + 1] = { var = var, headerLine = i, bodyStart = bodyStart }
                end
            end
        end
    end

    if #loops == 0 then return src end

    table.sort(loops, function(a, b) return a.headerLine > b.headerLine end)
    for _, loop in ipairs(loops) do
        local hdr = lines[loop.headerLine]
        local newHdr = hdr:gsub("(for%s+)([%w_]+)(%s+in%s)", function(kw, v, rest)
            if v == loop.var then return kw .. "_" .. rest else return nil end
        end)
        if newHdr ~= hdr then
            lines[loop.headerLine] = newHdr
            table.insert(lines, loop.bodyStart, "    local " .. loop.var .. " = _")
        end
    end
    return table.concat(lines, "\n")
end

local DEOBFUSCATOR_PAGE_SOURCE = [===[
deobfPage.Name = "deobfuscator"

local svc = nil
local theme = nil
local AddLog = nil
local dataApi = nil

local DEOBF_LEFT_W = 260
local DEOBF_ANIM_DUR = 0.2

local DEOBF_LONG_PRESS = 0.5

local deobfSwitchPage = nil
local deobfHouseFileMap = {}
local deobfHouseLastFile = nil
local deobfHouseSaveTimer = nil
local deobfHouseSyncConnected = false
local deobfNotify = nil

local function deobfGetHouseCurrentTabName()
    local api = _G
    if api.__DeltaUI_getCurrentTabName then
        local ok, r = pcall(api.__DeltaUI_getCurrentTabName)
        if ok then return r end
    end
    if api.__DeltaUI_currentTab then return api.__DeltaUI_currentTab end
    if api.__DeltaUI_activeTab then return api.__DeltaUI_activeTab end
    if api.__DeltaUI_selectedTab then return api.__DeltaUI_selectedTab end
    return nil
end

local function deobfSetupHouseSync()
    if deobfHouseSyncConnected then return end
    local cb = _G.__DeltaUI_codeBox
    if not cb then return end
    deobfHouseSyncConnected = true
    cb:GetPropertyChangedSignal("Text"):Connect(function()
        if _G.__DeltaUI_isProgrammaticTextChange then return end
        local fileName = nil
        local tabName = deobfGetHouseCurrentTabName()
        if tabName and deobfHouseFileMap[tabName] then
            fileName = deobfHouseFileMap[tabName]
        else
            local attrName = cb:GetAttribute("deobfFileName")
            if attrName then fileName = attrName end
        end
        if not fileName or not dataApi then return end
        if deobfHouseSaveTimer then
            pcall(task.cancel, deobfHouseSaveTimer)
        end
        deobfHouseSaveTimer = task.delay(0.5, function()
            pcall(function()
                dataApi.writeFile(fileName, cb.Text)
            end)
        end)
    end)
end


local function deobfOpenInHouseEditor(name, content)
    name = tostring(name or "untitled")
    local tabName = name:gsub("%.[^%.]+$", ""):gsub("[^%w_%-%. ]", "_")
    if tabName == "" then tabName = "deobf_result" end
    content = tostring(content or "")
    local api = _G
    if not (api.__DeltaUI_addTab and api.__DeltaUI_codeBox and api.__DeltaUI_saveCurrentTab) then
        if deobfNotify then deobfNotify("主页编辑器未就绪，无法打开", 2) end
        warn("[Deobf] HouseEditor bridge not ready")
        return false
    end

    api.__DeltaUI_addTab()
    deobfHouseFileMap[tabName] = name
    deobfHouseLastFile = name

    local cb = api.__DeltaUI_codeBox
    _G.__DeltaUI_isProgrammaticTextChange = true
    cb.Text = content
    _G.__DeltaUI_isProgrammaticTextChange = false
    pcall(function() cb:SetAttribute("deobfFileName", name) end)
    deobfSetupHouseSync()
    pcall(api.__DeltaUI_saveCurrentTab)

    if api.__DeltaUI_setCurrentTabName then
        pcall(api.__DeltaUI_setCurrentTabName, tabName)
    end

    if api.__DeltaUI_renderTabs then pcall(api.__DeltaUI_renderTabs) end

    if deobfSwitchPage then deobfSwitchPage("house") end
    if deobfNotify then deobfNotify("已在主页新建代码页: " .. tabName, 1) end
    return true
end

local deobfEditorBridge = {
    Text = "",
    _getValue = function(self)
        if deobfSelectedFile and dataApi then
            return dataApi.readFile(deobfSelectedFile) or ""
        end
        return self.Text or ""
    end,
}
setmetatable(deobfEditorBridge, {
    __index = function(t, k)
        if k == "Text" then return rawget(t, "Text") or "" end
        return rawget(t, k)
    end,
    __newindex = function(t, k, v)
        if k == "Text" then
            rawset(t, "Text", v)
            local ok = deobfOpenInHouseEditor(deobfSelectedFile or "deobf_result.lua", v)
            if not ok and deobfNotify then
                deobfNotify("无法打开主页编辑器（未安装桥接）", 2)
            end
        else
            rawset(t, k, v)
        end
    end,
})

local function ensureDeps()
    if not svc then
        svc = {
            Players = game:GetService("Players"),
            UserInputService = game:GetService("UserInputService"),
            CoreGui = game:GetService("CoreGui"),
            ReplicatedStorage = game:GetService("ReplicatedStorage"),
            TweenService = game:GetService("TweenService"),
            RunService = game:GetService("RunService"),
            HttpService = game:GetService("HttpService"),
            TextService = game:GetService("TextService"),
        }
    end
    if not theme then
        theme = {
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
    if not AddLog then AddLog = function(msg, lvl) print("[Deobf]", msg) end end
    if not deobfNotify then deobfNotify = function(msg, lvl) AddLog(msg, (lvl == 1) and "info" or "warn") end end
    if deobfDataApi then dataApi = deobfDataApi end
    if DeltaPage and DeltaPage.switchPage then deobfSwitchPage = DeltaPage.switchPage end
    if not deobfSwitchPage and _G.__DeltaUI_switchPage then deobfSwitchPage = _G.__DeltaUI_switchPage end
    if DeltaPage then
        if not _G.create and DeltaPage.create then _G.create = DeltaPage.create end
        if not _G.corner and DeltaPage.corner then _G.corner = DeltaPage.corner end
        if not _G.stroke and DeltaPage.stroke then _G.stroke = DeltaPage.stroke end
        if not _G.GetIcon and DeltaPage.GetIcon then _G.GetIcon = DeltaPage.GetIcon end
        if not _G.safeConnect and DeltaPage.safeConnect then _G.safeConnect = DeltaPage.safeConnect end
        if not _G.t and DeltaPage.t then _G.t = DeltaPage.t end
    end
end

local function deobfTween(obj, props, dur)
    dur = dur or DEOBF_ANIM_DUR
    local tw = TweenInfo.new(dur, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    svc.TweenService:Create(obj, tw, props):Play()
end

local deobfLeftPanel = nil
local deobfFileList = nil
local deobfFileListScroll = nil
local deobfLeftTitle = nil
local deobfNewFileBtn = nil
local deobfNewFileInput = nil
local deobfNewFileInputBox = nil
local deobfIsCreatingNew = false
local deobfSelectedFile = nil
local deobfViewingHookRecord = nil
local deobfFileItems = {}
local deobfFiles = {}

local deobfRightPanel = nil
local deobfViewMode = "tools"
local deobfToolsView = nil
local deobfHookLogView = nil
local deobfHookLogList = nil
local deobfHookLogScroll = nil
local deobfHookLogItems = {}
local deobfHookRecords = {}
local deobfEditorTextBox = deobfEditorBridge
local deobfToolButtons = {}
local deobfBehaviorArmed = nil

local DEOBF_TOOLS = {
    { id = "detect_obf", name = "混淆检测", icon = "scan-search", desc = "检测代码使用的混淆器类型", color = "accent2" },
    { id = "wearedev_full", name = "WeAreDev 完全反混淆", icon = "wand-sparkles", desc = "一键完全反混淆 WeAreDev 脚本", color = "green" },
    { id = "wearedev_behavior", name = "WeAreDev 行为还原", icon = "scan-search", desc = "执行脚本并还原它实际运行的语句（会真的跑起来）", color = "red" },
    { id = "hook_loadstring", name = "Hook Loadstring", icon = "link", desc = "拦截并记录所有 loadstring 调用", color = "accent" },
    { id = "rename_vars", name = "变量重命名", icon = "pencil", desc = "将混淆变量名替换为可读名称", color = "accent2" },
    { id = "string_decrypt", name = "字符串解密", icon = "key-round", desc = "解密加密的字符串常量", color = "green" },
    { id = "luraph_clean", name = "Luraph 清理", icon = "eraser", desc = "清理 Luraph 特征代码", color = "warn" },
    { id = "control_flow", name = "控制流还原", icon = "git-branch", desc = "还原被扁平化的控制流", color = "accent" },
    { id = "gc_clean", name = "垃圾代码清理", icon = "trash-2", desc = "移除无效的死代码和垃圾指令", color = "red" },
    { id = "prometheus_full", name = "Prometheus 完全反混淆", icon = "wand-2", desc = "一键完全反混淆 Prometheus 脚本", color = "green" },
    { id = "num_expr", name = "数字表达式还原", icon = "binary", desc = "将算术表达式还原为数字常量", color = "accent2" },
    { id = "unsplit_str", name = "分割字符串合并", icon = "git-merge", desc = "合并被拆分的字符串片段", color = "green" },
    { id = "unwrap_func", name = "函数包装解除", icon = "package-open", desc = "解除外层函数包装", color = "accent" },
    { id = "const_array", name = "常量数组内联", icon = "list", desc = "将常量数组引用内联为原始值", color = "accent2" },
    { id = "unproxify", name = "代理变量还原", icon = "link-2-off", desc = "解除 Proxy 代理恢复原始变量", color = "warn" },
    { id = "format", name = "代码格式化", icon = "align-left", desc = "自动缩进和格式化代码", color = "accent" },
    { id = "analyze", name = "代码分析", icon = "search-code", desc = "分析代码结构和特征", color = "accent2" },
}

local function deobfLoadFiles()
    if not dataApi then return {} end
    local result = {}
    local files = dataApi.listFiles("") or {}
    for _, fpath in ipairs(files) do
        local fname = fpath:match("([^/\\]+)$") or fpath
        if fname and fname ~= "" and not fname:match("^%.") then
            table.insert(result, fname)
        end
    end
    table.sort(result, function(a, b) return a:lower() < b:lower() end)
    return result
end

local function deobfRefreshFileList()
    if not deobfFileList then return end
    for _, item in pairs(deobfFileItems) do
        pcall(function() item:Destroy() end)
    end
    deobfFileItems = {}

    deobfFiles = deobfLoadFiles()
    local count = #deobfFiles

    if count == 0 then
        local EMPTY_H = 130
        local emptyFrame = create("Frame", {
            Size = UDim2.new(1, 0, 0, EMPTY_H),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1,
            ZIndex = 5,
        })
        emptyFrame.Parent = deobfFileList

        local emptyIcon = GetIcon("folder", UDim2.new(0, 32, 0, 32), theme.textDim)
        if emptyIcon then
            emptyIcon.AnchorPoint = Vector2.new(0.5, 1)
            emptyIcon.Position = UDim2.new(0.5, 0, 0.5, -14)
            emptyIcon.ZIndex = 6
            emptyIcon.Parent = emptyFrame
        end

        local emptyTitle = create("TextLabel", {
            Size = UDim2.new(1, -24, 0, 20),
            Position = UDim2.new(0, 12, 0.5, 6),
            BackgroundTransparency = 1,
            Text = "暂无文件",
            TextColor3 = theme.text,
            TextSize = 13,
            Font = Enum.Font.SourceSansBold,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 6,
        })
        emptyTitle.Parent = emptyFrame

        local emptyHint = create("TextLabel", {
            Size = UDim2.new(1, -24, 0, 32),
            Position = UDim2.new(0, 12, 0.5, 26),
            BackgroundTransparency = 1,
            Text = "点击右上角 + 新建文件\n或从右侧工具导入脚本",
            TextColor3 = theme.textDim,
            TextSize = 11,
            Font = Enum.Font.SourceSans,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = 6,
        })
        emptyHint.Parent = emptyFrame

        deobfFileList.Size = UDim2.new(1, 0, 0, EMPTY_H)
        if deobfFileListScroll then
            deobfFileListScroll.CanvasSize = UDim2.new(0, 0, 0, EMPTY_H)
        end
        return
    end

    for i, fname in ipairs(deobfFiles) do
        local row = create("TextButton", {
            Size = UDim2.new(1, -16, 0, 32),
            Position = UDim2.new(0, 8, 0, 8 + (i - 1) * 36),
            BackgroundColor3 = theme.surface,
            BackgroundTransparency = 0.4,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 5,
        })
        corner(8, row)

        local icon = GetIcon("file-code", UDim2.new(0, 14, 0, 14), theme.textDim)
        if icon then
            icon.Position = UDim2.new(0, 10, 0.5, -7)
            icon.ZIndex = 6
            icon.Parent = row
        end

        local label = create("TextLabel", {
            Position = UDim2.new(0, 32, 0, 0),
            Size = UDim2.new(1, -44, 1, 0),
            BackgroundTransparency = 1,
            Text = fname,
            TextColor3 = theme.text,
            TextSize = 12,
            Font = Enum.Font.SourceSans,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 6,
        })
        label.Parent = row

        local delBtn = create("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -6, 0.5, 0),
            Size = UDim2.new(0, 24, 0, 24),
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 7,
            Visible = false,
        })
        local delIcon = GetIcon("trash-2", UDim2.new(0, 14, 0, 14), theme.red)
        if delIcon then
            delIcon.AnchorPoint = Vector2.new(0.5, 0.5)
            delIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
            delIcon.ZIndex = 8
            delIcon.Parent = delBtn
        end
        delBtn.Parent = row

        local longPressCancelled = false
        local isLongPressed = false

        local function startLongPress()
            longPressCancelled = false
            isLongPressed = false
            task.spawn(function()
                task.wait(DEOBF_LONG_PRESS)
                if not longPressCancelled then
                    isLongPressed = true
                    deobfSelectedFile = fname
                    local content = (dataApi and dataApi.readFile(fname)) or ""
                    deobfOpenInHouseEditor(fname, content)
                    deobfRefreshFileList()
                end
            end)
        end

        local function cancelLongPress()
            longPressCancelled = true
        end

        row.MouseEnter:Connect(function()
            deobfTween(row, {BackgroundColor3 = theme.accent, BackgroundTransparency = 0.8}, 0.15)
            delBtn.Visible = true
        end)
        row.MouseLeave:Connect(function()
            cancelLongPress()
            if deobfSelectedFile ~= fname then
                deobfTween(row, {BackgroundColor3 = theme.surface, BackgroundTransparency = 0.4}, 0.15)
            end
            delBtn.Visible = false
        end)
        row.MouseButton1Down:Connect(function()
            startLongPress()
        end)
        row.MouseButton1Up:Connect(function()
            if not isLongPressed then
                deobfSelectedFile = fname
                deobfRefreshFileList()
            end
            cancelLongPress()
        end)
        delBtn.MouseButton1Click:Connect(function()
            if dataApi and dataApi.deleteFile(fname) then
                AddLog("已删除: " .. fname, "info")
        deobfHouseFileMap[fname:gsub("%.[^%.]+$", ""):gsub("[^%w_%-%. ]", "_")] = nil
        if deobfHouseLastFile == fname then deobfHouseLastFile = nil end
                if deobfSelectedFile == fname then
                    deobfSelectedFile = nil
                end
                deobfRefreshFileList()
            end
        end)

        if deobfSelectedFile == fname then
            row.BackgroundColor3 = theme.accent
            row.BackgroundTransparency = 0.75
        end

        row.Parent = deobfFileList
        deobfFileItems[fname] = row
    end

    local contentH = count * 36 + 16
    deobfFileList.Size = UDim2.new(1, 0, 0, contentH)
    if deobfFileListScroll then
        deobfFileListScroll.CanvasSize = UDim2.new(0, 0, 0, contentH)
    end
end

local deobfCreatingFile = false

local function deobfShowNewFileInput()
    deobfIsCreatingNew = true
    deobfCreatingFile = false
    if deobfNewFileBtn then
        deobfNewFileBtn.Visible = true
        local twInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        svc.TweenService:Create(deobfNewFileBtn, twInfo, {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 0, 0, 28),
            Rotation = 90,
        }):Play()
    end
    if deobfLeftTitle then
        local twInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        svc.TweenService:Create(deobfLeftTitle, twInfo, {
            TextTransparency = 1,
            Position = UDim2.new(0, -20, 0, 0),
        }):Play()
    end
    if deobfNewFileInput then
        local input = deobfNewFileInput
        input.Visible = true
        input.BackgroundTransparency = 1
        input.Position = UDim2.new(1, 0, 0.5, 0)
        input.Size = UDim2.new(0, 0, 0, 32)
        task.wait()
        local twInfo = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        svc.TweenService:Create(input, twInfo, {
            BackgroundTransparency = 0.15,
            Position = UDim2.new(0, 12, 0.5, 0),
            Size = UDim2.new(1, -56, 0, 32),
        }):Play()
    end
    if deobfNewFileInputBox then
        deobfNewFileInputBox.Text = ""
        task.spawn(function()
            task.wait(0.2)
            pcall(function() deobfNewFileInputBox:CaptureFocus() end)
        end)
    end
end

local function deobfHideNewFileInput(reset)
    deobfIsCreatingNew = false
    deobfCreatingFile = false
    if reset and deobfNewFileInputBox then
        deobfNewFileInputBox.Text = ""
    end
    if deobfNewFileBtn then
        deobfNewFileBtn.Visible = true
        local twInfo = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        svc.TweenService:Create(deobfNewFileBtn, twInfo, {
            BackgroundTransparency = 0.3,
            Size = UDim2.new(0, 32, 0, 28),
            Rotation = 0,
        }):Play()
    end
    if deobfLeftTitle then
        local twInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        svc.TweenService:Create(deobfLeftTitle, twInfo, {
            TextTransparency = 0,
            Position = UDim2.new(0, 14, 0, 0),
        }):Play()
    end
    if deobfNewFileInput then
        local input = deobfNewFileInput
        local twInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
        svc.TweenService:Create(input, twInfo, {
            BackgroundTransparency = 1,
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(0, 0, 0, 32),
        }):Play()
        task.spawn(function()
            task.wait(0.2)
            if not deobfIsCreatingNew then
                input.Visible = false
                input.BackgroundTransparency = 1
                input.Position = UDim2.new(0, 12, 0.5, 0)
                input.Size = UDim2.new(1, -56, 0, 32)
            end
        end)
    end
end


local function deobfCreateNewFile()
    if deobfCreatingFile then return end
    deobfCreatingFile = true
    local ok, err = pcall(function()
        if not deobfNewFileInputBox then
            deobfHideNewFileInput(true)
            return
        end
        local raw = (deobfNewFileInputBox.Text or ""):match("^%s*(.-)%s*$") or ""
        if raw == "" then
            AddLog("请输入文件名", "warn")
            deobfNotify("请输入文件名", 2)
            pcall(function() deobfNewFileInputBox:CaptureFocus() end)
            deobfCreatingFile = false
            return
        end
        local fname = raw
        if not fname:match("%.lua$") and not fname:match("%.txt$") then
            if not fname:match("%.") then
                fname = fname .. ".lua"
            else
                AddLog("文件名格式不正确", "warn")
                deobfNotify("文件名格式不正确", 2)
                deobfHideNewFileInput(true)
                return
            end
        end
        if not dataApi then
            AddLog("存储不可用，无法创建文件", "warn")
            deobfNotify("存储不可用", 2)
            deobfHideNewFileInput(true)
            return
        end
        local exists = false
        local existsOk, existsErr = pcall(function()
            if dataApi.isFile then exists = dataApi.isFile(fname) end
        end)
        if not existsOk then
            AddLog("检查文件存在性出错: " .. tostring(existsErr), "warn")
        end
        if exists then
            AddLog("文件已存在: " .. fname, "warn")
            deobfNotify("文件已存在", 2)
            deobfHideNewFileInput(true)
            return
        end
        local writeOk, writeErr = pcall(function() return dataApi.writeFile(fname, "") end)
        if not writeOk then
            AddLog("写入文件出错: " .. tostring(writeErr), "warn")
            deobfNotify("写入失败: " .. tostring(writeErr):sub(1, 30), 2)
            deobfHideNewFileInput(true)
            return
        end
        if writeOk and deobfSelectedFile ~= fname then
            AddLog("已创建: " .. fname .. "（长按文件即可编辑）", "info")
            deobfNotify("已创建 " .. fname, 1)
            deobfSelectedFile = fname
            deobfHideNewFileInput(false)
            pcall(function() deobfRefreshFileList() end)
        else
            AddLog("创建失败: " .. fname, "warn")
            deobfNotify("创建失败", 2)
            deobfHideNewFileInput(true)
        end
    end)
    if not ok then
        AddLog("创建文件出错: " .. tostring(err), "warn")
        deobfNotify("创建出错", 2)
        deobfHideNewFileInput(true)
    end
    deobfCreatingFile = false
end

function deobfShowTools()
    deobfViewMode = "tools"
    if deobfToolsView then deobfToolsView.Visible = true end
    if deobfHookLogView then deobfHookLogView.Visible = false end
end

function deobfOpenEditor(fname)
    deobfViewMode = "editor"
    deobfSelectedFile = fname
    deobfViewingHookRecord = nil
    if deobfToolsView then deobfToolsView.Visible = false end
    if deobfHookLogView then deobfHookLogView.Visible = false end
    local content = (dataApi and dataApi.readFile(fname)) or ""
    deobfOpenInHouseEditor(fname, content)
end

function deobfShowHookLog()
    deobfViewMode = "hooklog"
    if deobfToolsView then deobfToolsView.Visible = false end
    if deobfHookLogView then deobfHookLogView.Visible = true end
    deobfRefreshHookLog()
end

function deobfEditorFromHook(record)
    if not record then return end
    deobfViewMode = "editor"
    deobfViewingHookRecord = record
    deobfSelectedFile = nil
    if deobfToolsView then deobfToolsView.Visible = false end
    if deobfHookLogView then deobfHookLogView.Visible = false end
    local name = "#" .. record.id .. "_" .. tostring(record.chunkname or "hook"):gsub("[^%w_%-]", "_") .. ".lua"
    deobfOpenInHouseEditor(name, tostring(record.source or ""))
end

local function deobfRefreshHookLog()
    if not deobfHookLogList then return end
    for _, item in pairs(deobfHookLogItems) do
        pcall(function() item:Destroy() end)
    end
    deobfHookLogItems = {}

    local count = #deobfHookRecords

    if count == 0 then
        local empty = create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 40),
            Position = UDim2.new(0, 0, 0, 30),
            BackgroundTransparency = 1,
            Text = "暂无拦截记录\n启动 Hook Loadstring 后自动记录",
            TextColor3 = theme.textDim,
            TextSize = 11,
            Font = Enum.Font.SourceSans,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 5,
        })
        empty.Parent = deobfHookLogList
        deobfHookLogList.Size = UDim2.new(1, 0, 0, 120)
        if deobfHookLogScroll then
            deobfHookLogScroll.CanvasSize = UDim2.new(0, 0, 0, 120)
        end
        return
    end

    for i = count, 1, -1 do
        local record = deobfHookRecords[i]
        local idx = count - i + 1
        local rowY = 12 + (idx - 1) * 64

        local row = create("TextButton", {
            Size = UDim2.new(1, -24, 0, 56),
            Position = UDim2.new(0, 12, 0, rowY),
            BackgroundColor3 = theme.surface,
            BackgroundTransparency = 0.4,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 5,
        })
        corner(10, row)

        local idLabel = create("TextLabel", {
            Position = UDim2.new(0, 12, 0, 8),
            Size = UDim2.new(0, 40, 0, 18),
            BackgroundTransparency = 1,
            Text = "#" .. record.id,
            TextColor3 = theme.accent,
            TextSize = 12,
            Font = Enum.Font.SourceSansBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 6,
        })
        idLabel.Parent = row

        local nameLabel = create("TextLabel", {
            Position = UDim2.new(0, 56, 0, 8),
            Size = UDim2.new(1, -120, 0, 18),
            BackgroundTransparency = 1,
            Text = tostring(record.chunkname or "unknown"),
            TextColor3 = theme.text,
            TextSize = 12,
            Font = Enum.Font.SourceSans,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 6,
        })
        nameLabel.Parent = row

        local sizeLabel = create("TextLabel", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -12, 0, 8),
            Size = UDim2.new(0, 60, 0, 18),
            BackgroundTransparency = 1,
            Text = tostring(#record.source) .. " B",
            TextColor3 = theme.textDim,
            TextSize = 11,
            Font = Enum.Font.SourceSans,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 6,
        })
        sizeLabel.Parent = row

        local timeLabel = create("TextLabel", {
            Position = UDim2.new(0, 12, 0, 30),
            Size = UDim2.new(1, -24, 0, 16),
            BackgroundTransparency = 1,
            Text = record.time or "",
            TextColor3 = theme.textDim,
            TextSize = 10,
            Font = Enum.Font.SourceSans,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 6,
        })
        timeLabel.Parent = row

        local viewBtn = create("TextButton", {
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -60, 1, -6),
            Size = UDim2.new(0, 48, 0, 22),
            BackgroundColor3 = theme.accent,
            BackgroundTransparency = 0.3,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 7,
        })
        corner(6, viewBtn)
        local viewLabel = create("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "编辑",
            TextColor3 = Color3.fromRGB(255,255,255),
            TextSize = 10,
            Font = Enum.Font.SourceSansBold,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 8,
        })
        viewLabel.Parent = viewBtn
        viewBtn.Parent = row
        viewBtn.MouseButton1Click:Connect(function()
            deobfEditorFromHook(record)
        end)

        local runBtn = create("TextButton", {
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -8, 1, -6),
            Size = UDim2.new(0, 48, 0, 22),
            BackgroundColor3 = theme.green,
            BackgroundTransparency = 0.3,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 7,
        })
        corner(6, runBtn)
        local runLabel = create("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "执行",
            TextColor3 = Color3.fromRGB(255,255,255),
            TextSize = 10,
            Font = Enum.Font.SourceSansBold,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 8,
        })
        runLabel.Parent = runBtn
        runBtn.Parent = row
        runBtn.MouseButton1Click:Connect(function()
            local fn, err = loadstring(record.source, "@replay_" .. record.id)
            if fn then
                pcall(fn)
                AddLog("已重新执行 #" .. record.id, "info")
            else
                AddLog("执行失败: " .. tostring(err), "warn")
            end
        end)

        row.MouseEnter:Connect(function()
            deobfTween(row, {BackgroundColor3 = theme.accent, BackgroundTransparency = 0.85}, 0.15)
        end)
        row.MouseLeave:Connect(function()
            deobfTween(row, {BackgroundColor3 = theme.surface, BackgroundTransparency = 0.4}, 0.15)
        end)
        row.MouseButton1Click:Connect(function()
            deobfEditorFromHook(record)
        end)

        row.Parent = deobfHookLogList
        deobfHookLogItems[record.id] = row
    end

    local contentH = count * 64 + 24
    deobfHookLogList.Size = UDim2.new(1, 0, 0, contentH)
    if deobfHookLogScroll then
        deobfHookLogScroll.CanvasSize = UDim2.new(0, 0, 0, contentH)
    end
end

local function deobfDetectObfuscation(code)
    local results = {}
    local totalScore = 0

    local luraphScore = 0
    if code:match("Luraph") or code:match("luraph") then
        luraphScore = luraphScore + 30
        table.insert(results, "Luraph 特征: 找到 'Luraph' 标记")
    end
    if code:match("__Luraph") then
        luraphScore = luraphScore + 20
        table.insert(results, "Luraph 特征: 找到全局变量 __Luraph")
    end
    if code:match("L0_") or code:match("L1_") or code:match("L2_") then
        luraphScore = luraphScore + 15
        table.insert(results, "Luraph 特征: 找到 L0_, L1_, L2_ 变量模式")
    end
    if luraphScore > 0 then
        table.insert(results, "Luraph 置信度: " .. math.min(100, luraphScore) .. "%")
        totalScore = totalScore + luraphScore
    end

    local wearedevScore = 0
    if code:match("WeAreDev") or code:match("wearedev") then
        wearedevScore = wearedevScore + 25
        table.insert(results, "WeAreDev 特征: 找到 'WeAreDev' 标记")
    end
    if code:match("wearedev%.net") or code:match("wearedev%.org") then
        wearedevScore = wearedevScore + 20
        table.insert(results, "WeAreDev 特征: 找到 wearedev.net/org 引用")
    end
    if code:match("oOoOOo") or code:match("OOoOOo") then
        wearedevScore = wearedevScore + 15
        table.insert(results, "WeAreDev 特征: 找到特征性变量名模式")
    end
    if wearedevScore > 0 then
        table.insert(results, "WeAreDev 置信度: " .. math.min(100, wearedevScore) .. "%")
        totalScore = totalScore + wearedevScore
    end

    local obfCount = 0
    local patterns = {
        {"____", "四下划线变量"},
        {"obfuscated", "obfuscated 标记"},
        {"_G%[%\"", "全局变量字符串访问"},
        {"v_%d+", "v_数字变量模式"},
        {"_%d+_", "下划线数字下划线模式"},
    }
    for _, p in ipairs(patterns) do
        local count = select(2, code:gsub(p[1], ""))
        if count > 0 then
            obfCount = obfCount + count
            table.insert(results, "混淆特征: " .. p[2] .. " (出现 " .. count .. " 次)")
        end
    end

    if obfCount > 10 then
        totalScore = totalScore + 30
    elseif obfCount > 5 then
        totalScore = totalScore + 15
    elseif obfCount > 0 then
        totalScore = totalScore + 5
    end

    local strEncPatterns = {
        {"string%.char%s*%(", "string.char() 加密"},
        {"loadstring%s*%(%s*loadstring", "双重 loadstring"},
        {"getfenv%s*%(%s*0%s*%)", "getfenv(0) 沙箱"},
        {"setfenv%s*%(%s*0%s*%)", "setfenv(0) 沙箱"},
    }
    for _, p in ipairs(strEncPatterns) do
        if code:match(p[1]) then
            table.insert(results, "字符串加密: " .. p[2])
            totalScore = totalScore + 10
        end
    end

    if code:match("debugger") or code:match("debug%.get") then
        table.insert(results, "反调试: 检测到调试器检测代码")
        totalScore = totalScore + 15
    end

    local emptyLines = select(2, code:gsub("^%s*\n", ""))
    if emptyLines > 100 then
        table.insert(results, "垃圾代码: 大量空行 (" .. emptyLines .. ")")
        totalScore = totalScore + 10
    end

    local prometheusScore = 0
    if code:match("Prometheus") or code:match("prometheus") or code:match("levno%-710") then
        prometheusScore = prometheusScore + 35
        table.insert(results, "Prometheus 特征: 找到 Watermark 标记")
    end
    local constArrMatches = select(2, code:gsub('local%s+[%w_]+%s*=%s*{', ""))
    if constArrMatches >= 3 then
        prometheusScore = prometheusScore + 15
        table.insert(results, "Prometheus 特征: 检测到 " .. constArrMatches .. " 处常量数组构造")
    end
    local numExprCount = select(2, code:gsub('0x[%x]+%s*[%%+%-%*/]', ""))
    if numExprCount > 10 then
        prometheusScore = prometheusScore + 15
        table.insert(results, "Prometheus 特征: 检测到 " .. numExprCount .. " 处数字表达式混淆")
    end
    if code:match("return%s*%(?%s*function%s*%(%.%.%.%)") then
        prometheusScore = prometheusScore + 20
        table.insert(results, "Prometheus 特征: 检测到函数包装 (WrapInFunction)")
    end
    local splitStrCount = select(2, code:gsub('table%.concat', ""))
    if splitStrCount > 5 then
        prometheusScore = prometheusScore + 10
        table.insert(results, "Prometheus 特征: 检测到 " .. splitStrCount .. " 处 table.concat 字符串拼接")
    end
    local proxifyCount = select(2, code:gsub('setmetatable', ""))
    if proxifyCount > 5 then
        prometheusScore = prometheusScore + 15
        table.insert(results, "Prometheus 特征: 检测到 " .. proxifyCount .. " 处 setmetatable 代理")
    end
    local strCharCount = select(2, code:gsub('string%.char', ""))
    if strCharCount > 20 then
        prometheusScore = prometheusScore + 15
        table.insert(results, "Prometheus 特征: 检测到 " .. strCharCount .. " 处 string.char 加密")
    end
    if prometheusScore > 0 then
        table.insert(results, "Prometheus 置信度: " .. math.min(100, prometheusScore) .. "%")
        totalScore = totalScore + prometheusScore
    end

    table.insert(results, "")
    table.insert(results, "=== 总体评估 ===")
    if totalScore >= 80 then
        table.insert(results, "重度混淆 (置信度 " .. math.min(100, totalScore) .. "%)")
    elseif totalScore >= 50 then
        table.insert(results, "中度混淆 (置信度 " .. math.min(100, totalScore) .. "%)")
    elseif totalScore >= 20 then
        table.insert(results, "轻度混淆 (置信度 " .. math.min(100, totalScore) .. "%)")
    else
        table.insert(results, "基本无混淆 (置信度 " .. math.min(100, totalScore) .. "%)")
    end

    return results, {
        confidence = math.min(100, totalScore),
        prometheus = prometheusScore,
        wearedev = wearedevScore,
        luraph = luraphScore,
        results = results,
    }
end

local function deobfRenameVars(code)
    local varMap = {}
    local varCount = 0
    local reserved = {
        ["local"]=1,["function"]=1,["end"]=1,["if"]=1,["then"]=1,["else"]=1,
        ["elseif"]=1,["return"]=1,["for"]=1,["while"]=1,["do"]=1,["repeat"]=1,
        ["until"]=1,["break"]=1,["true"]=1,["false"]=1,["nil"]=1,["and"]=1,
        ["or"]=1,["not"]=1,["in"]=1,["print"]=1,["pairs"]=1,["ipairs"]=1,
        ["table"]=1,["string"]=1,["math"]=1,["tostring"]=1,["tonumber"]=1,
        ["type"]=1,["pcall"]=1,["xpcall"]=1,["error"]=1,["require"]=1,
        ["game"]=1,["workspace"]=1,["script"]=1,["_G"]=1,["task"]=1,["wait"]=1,
        ["Instance"]=1,["Vector2"]=1,["Vector3"]=1,["UDim2"]=1,["Color3"]=1,
        ["Enum"]=1,["TweenInfo"]=1,["CFrame"]=1,["UDim"]=1,["BrickColor"]=1,
        ["spawn"]=1,["delay"]=1,["random"]=1,["clock"]=1,
    }

    for var in code:gmatch("[%a_][%w_]*") do
        if not reserved[var] then
            if #var <= 3 or var:match("^_$") or var:match("^_[%d]+$")
               or var:match("^v_") or var:match("^_v")
               or var:match("^O0+") or var:match("^l_")
               or var:match("^L0_") or var:match("^L1_")
               or var:match("^____") then
                if not varMap[var] then
                    varCount = varCount + 1
                    varMap[var] = "v" .. string.format("%03d", varCount)
                end
            end
        end
    end

    local result = code
    for old, new in pairs(varMap) do
        result = result:gsub("%f[%a_]" .. old .. "%f[^%w_]", new)
    end
    return result, varCount
end

local function deobfStringDecrypt(code)
    local result = code
    local count = 0

    result = result:gsub('string%.char%s*%(%s*([%d%s,]+)%s*%)%s*%.%s*(")', function(nums, suffix)
        local chars = {}
        for num in nums:gmatch("%d+") do
            local c = tonumber(num)
            if c and c >= 0 and c <= 255 then
                table.insert(chars, string.char(c))
            end
        end
        if #chars > 0 then
            count = count + 1
            return '"' .. table.concat(chars) .. '"'
        end
        return "string.char(" .. nums .. ")" .. suffix
    end)

    result = result:gsub('"%s*%.%.%s*"', function()
        count = count + 1
        return '"'
    end)

    result = result:gsub('"([^"]*)"', function(str)
        local hex, replacements = string.gsub(str, "\\x(%x%x)", function(hex)
            count = count + 1
            return string.char(tonumber(hex, 16))
        end)
        if replacements > 0 then
            return '"' .. hex .. '"'
        end
        return '"' .. str .. '"'
    end)

    result = result:gsub('utf8%.char%s*%(%s*([%d%s,]+)%s*%)', function(nums)
        local chars = {}
        for num in nums:gmatch("%d+") do
            local c = tonumber(num)
            if c then
                table.insert(chars, utf8.char(c))
            end
        end
        if #chars > 0 then
            count = count + 1
            return '"' .. table.concat(chars) .. '"'
        end
        return "utf8.char(" .. nums .. ")"
    end)

    return result, count
end

local function deobfCleanLuraph(code)
    local result = code
    local count = 0

    if result:match("__LuraphPrefixCleaned") then
        count = count + 1
        result = result:gsub("_G%.__LuraphPrefixCleaned%s*=%s*true", "")
    end

    result = result:gsub('local%s+function%s+cleanLuraphPrefix%s*%([^)]*%).-end%s*\n', function(m)
        count = count + 1
        return ""
    end)

    result = result:gsub('_G%.error%s*=%s*function%s*%([^)]*%).-end', function(m)
        count = count + 1
        return ""
    end)

    result = result:gsub("%-%-[^\n]*[Ll]uraph[^\n]*\n", function(m)
        count = count + 1
        return ""
    end)

    result = result:gsub('"[^"]*Luraph[^"]*"', function(m)
        count = count + 1
        return '""'
    end)

    result = result:gsub('oOoOOo%s*=', 'local ')

    result = result:gsub('string%s*%.[%w_]+%s*=%s*function%s*%([^)]*%).-end', function(m)
        if m:match("reverse") or m:match("sub") then
            count = count + 1
            return ""
        end
        return m
    end)

    return result, count
end

local function deobfRestoreControlFlow(code)
    local result = code
    local changes = 0

    result = result:gsub("goto%s+(%w+)", function(label)
        changes = changes + 1
        return "-- goto " .. label
    end)

    local switchPattern = "repeat%s*%n%s*local%s+_%w+%s*=%s*(%d+)%s*%n%s*until%s+false%s*%n%s*%-%-%n%s*if%s+_%w+%s*==%s*(%d+)"
    local switchRepl = "switch(%1) case %2"

    result = result:gsub("repeat%s*\n%s*until%s+false", function(m)
        changes = changes + 1
        return ""
    end, 1)

    result = result:gsub("if%s+false%s+then%s*[^\n]*\n%s*[^\n]*\n%s*end", function(m)
        changes = changes + 1
        return "-- [dead code removed]"
    end)

    return result, changes
end

local DEOBF_ARITH_LIMIT = 5000000

local function deobfScanStrings(s)
	local inners = {}
	local i = 1
	local n = #s
	while i <= n do
		local b = s:byte(i)
		if b == 34 then
			local j = i + 1
			while j <= n do
				local c = s:byte(j)
				if c == 92 then
					j = j + 2
				elseif c == 34 then
					break
				else
					j = j + 1
				end
			end
			local innerEnd = math.min(j, n + 1) - 1
			table.insert(inners, s:sub(i + 1, innerEnd))
			i = j + 1
		else
			i = i + 1
		end
	end
	return inners
end

local function deobfProtectStrings(s)
	local inners = {}
	local out = {}
	local i = 1
	local n = #s
	local last = 1
	while i <= n do
		local b = s:byte(i)
		if b == 34 then
			local j = i + 1
			while j <= n do
				local c = s:byte(j)
				if c == 92 then
					j = j + 2
				elseif c == 34 then
					break
				else
					j = j + 1
				end
			end
			local innerEnd = math.min(j, n + 1) - 1
			table.insert(inners, s:sub(i + 1, innerEnd))
			table.insert(out, s:sub(last, i - 1))
			table.insert(out, '\0S' .. (#inners - 1) .. '\0')
			i = j + 1
			last = i
		else
			i = i + 1
		end
	end
	table.insert(out, s:sub(last))
	return table.concat(out), inners
end

local function deobfArithReplace(s, pattern, compute, countRef)
	return s:gsub(pattern, function(pos1, a, b, pos2)
		local num = compute(tonumber(a), tonumber(b))
		local result
		if num == math.floor(num) and math.abs(num) < 1000000000000000 then
			result = string.format('%.0f', num)
		else
			result = tostring(num)
		end
		countRef.value = countRef.value + 1

		local prefix = ''
		if pos1 > 1 then
			local before = s:sub(pos1 - 1, pos1 - 1)
			if before:match('^[%w_]$') and result:match('^%d') then
				prefix = ' '
			end
		end

		local suffix = ''
		if pos2 <= #s then
			local after = s:sub(pos2, pos2)
			if after:match('^[A-Za-z_]$') then
				local isExp = (after == 'e' or after == 'E')
					and s:sub(pos2, pos2 + 3):match('^[eE][+-]?%d') ~= nil
				if not isExp then suffix = ' ' end
			end
		end
		return prefix .. result .. suffix
	end)
end

local function deobfDecodeCustom(b64, S)
	local out = {}
	local buf = 0
	local bits = 0
	for i = 1, #b64 do
		local c = b64:sub(i, i)
		if c == '=' then break end
		local v = S[c]
		if v == nil then return nil end
		buf = bit32.bor(bit32.lshift(buf, 6), v)
		bits = bits + 6
		if bits >= 8 then
			bits = bits - 8
			table.insert(out, string.char(bit32.band(bit32.rshift(buf, bits), 0xff)))
		end
	end
	return table.concat(out)
end

local function deobfLuaEscape(str)
	local out = {}
	for i = 1, #str do
		local c = str:byte(i)
		if c == 34 then
			table.insert(out, '\\"')
		elseif c == 92 then
			table.insert(out, '\\\\')
		elseif c == 10 then
			table.insert(out, '\\n')
		elseif c == 13 then
			table.insert(out, '\\r')
		elseif c == 9 then
			table.insert(out, '\\t')
		elseif c == 123 or c == 125 then
			table.insert(out, '\\' .. string.format('%03d', c))
		elseif c >= 32 and c <= 126 then
			table.insert(out, str:sub(i, i))
		else
			table.insert(out, '\\' .. string.format('%03d', c))
		end
	end
	return table.concat(out)
end

local evalNumericLocal = nil

local function wearedevProtectStrings(s)
    local inners, out, i, last = {}, {}, 1, 1
    local n = #s
    while i <= n do
        local b = s:byte(i)
        if b == 34 or b == 39 then
            local q = b
            local j = i + 1
            while j <= n do
                local c = s:byte(j)
                if c == 92 then j = j + 2
                elseif c == q then break
                else j = j + 1 end
            end
            inners[#inners + 1] = s:sub(i + 1, math.min(j, n + 1) - 1)
            out[#out + 1] = s:sub(last, i - 1)
            out[#out + 1] = "\1Q" .. (#inners - 1) .. "\1"
            i, last = j + 1, j + 1
        else
            i = i + 1
        end
    end
    out[#out + 1] = s:sub(last)
    return table.concat(out), inners
end

local function wearedevUnprotectStrings(s, strings)
    return (s:gsub("\1Q(%d+)\1", function(idx)
        local v = strings[tonumber(idx) + 1]
        return v and ('"' .. v .. '"') or '""'
    end))
end

local function wearedevEvalNumeric(expr)
    if expr:find("[A-Za-z_%[%]\"']") then return nil end
    local s = expr:gsub("%s", "")
    if #s == 0 or not s:find("%d") then return nil end
    local pos = 1
    local peek, pFact, pTerm, pExpr
    function peek() return s:sub(pos, pos) end
    function pFact()
        local c = peek()
        if c == "" then return nil end
        if c == "-" then pos = pos + 1; local v = pFact(); return v and -v end
        if c == "+" then pos = pos + 1; return pFact() end
        if c == "(" then
            pos = pos + 1
            local v = pExpr()
            if peek() == ")" then pos = pos + 1 end
            return v
        end
        local num = s:match("^[%d%.]+", pos)
        if not num then return nil end
        pos = pos + #num
        return tonumber(num)
    end
    function pTerm()
        local v = pFact()
        if v == nil then return nil end
        while true do
            local c = peek()
            if c == "*" then
                pos = pos + 1
                local r = pFact()
                if r == nil then return nil end
                v = v * r
            elseif c == "/" then
                pos = pos + 1
                local r = pFact()
                if r == nil or r == 0 then return nil end
                v = v / r
            else break end
        end
        return v
    end
    function pExpr()
        local v = pTerm()
        if v == nil then return nil end
        while true do
            local c = peek()
            if c == "+" or c == "-" then
                pos = pos + 1
                local r = pTerm()
                if r == nil then return nil end
                v = (c == "+") and (v + r) or (v - r)
            else break end
        end
        return v
    end
    local v = pExpr()
    if v == nil or pos <= #s then return nil end
    if v ~= v or v == math.huge or v == -math.huge then return nil end
    return v
end

local function wearedevFmtNum(n)
    if n == math.floor(n) and math.abs(n) < 1e15 then return string.format("%.0f", n) end
    return tostring(n)
end

local function wearedevSimplify(s)
    local count, guard, changed = 0, 0, true
    while changed and guard < 14 do
        changed = false
        guard = guard + 1
        local out, i = {}, 1
        while i <= #s do
            local ch = s:sub(i, i)
            if ch == "(" then
                local pre = i > 1 and s:sub(i - 1, i - 1) or ""
                local group = s:sub(i):match("^%b()")
                local inner = group and group:sub(2, -2)
                if group and pre:match("[%w_)%]]") == nil and inner:find("%d")
                    and not inner:find("[A-Za-z_%[%]\"'/]") then
                    local v = wearedevEvalNumeric(inner)
                    if v ~= nil then
                        local txt = wearedevFmtNum(v)
                        if v < 0 then txt = "(" .. txt .. ")" end

                        if s:sub(i + #group, i + #group):match("[%w_.]") then txt = txt .. " " end
                        out[#out + 1] = txt
                        i = i + #group
                        count = count + 1
                        changed = true
                    else
                        out[#out + 1] = "("; i = i + 1
                    end
                else
                    out[#out + 1] = "("; i = i + 1
                end
            else
                out[#out + 1] = ch
                i = i + 1
            end
        end
        s = table.concat(out)
    end
    return s, count
end

local function wearedevUnescapeDec(s)
    return (s:gsub("\\(%d%d%d)", function(d) return string.char(tonumber(d)) end))
end

local function wearedevEscapeInner(str)
    local out = {}
    local q, bs = string.byte('"'), string.byte('\\')
    for i = 1, #str do
        local b = str:byte(i)
        if b == q then out[#out + 1] = '\\"'
        elseif b == bs then out[#out + 1] = '\\\\'
        elseif b >= 32 and b <= 126 then out[#out + 1] = str:sub(i, i)
        else out[#out + 1] = string.format('\\%03d', b) end
    end
    return table.concat(out)
end
wearedevEscapeInner = wearedevEscapeInner
wearedevLuaEscape = function(s) return '"' .. wearedevEscapeInner(s) .. '"' end

local function wearedevFindAccessor(s)
    for acc, param, arr, iv, sign, num in s:gmatch(
        "local%s+function%s+([%a_][%w_]*)%(([%a_][%w_]*)%)return%s+([%a_][%w_]*)%[([%a_][%w_]*)%s*([%-+]?)%s*(%d+)%]end") do
        if param == iv then
            local off = tonumber(num) or 0
            if sign == "+" then off = -off end
            return acc, arr, off
        end
    end
    return nil
end

local function wearedevApplyShuffle(s, entries)
    local body = s:match("ipairs%s*%((%b{})%)")
    if not body then
            return entries, 0
    end
    if not (body:find("%d") and body:match("^[%d%s%+%-%(%)%,;{}]+$")) then
            return entries, 0
    end
    local chunk = loadstring("return " .. body)
    if not chunk then return entries, 0 end
    local ok, pairsList = pcall(chunk)
    if not ok or type(pairsList) ~= "table" then
        return entries, 0
    end
    local n = 0
    for _, pr in ipairs(pairsList) do
        if type(pr) == "table" and type(pr[1]) == "number" and type(pr[2]) == "number" then
            local i, j = math.floor(pr[1]), math.floor(pr[2])
            while i < j and entries[i] and entries[j] do
                entries[i], entries[j] = entries[j], entries[i]
                i, j = i + 1, j - 1
            end
            n = n + 1
        end
    end
    return entries, n
end

local function wearedevFindAlphabet(s)
    local best
    for body in s:gmatch("local%s+[%a_][%w_]*%s*=%s*%{([^{}]*)%}") do
        local map, n = {}, 0
        for key, val in body:gmatch('%[%"([^"]+)"%]%s*=%s*([%-+%d%s%(%)]+)') do
            local ch = wearedevUnescapeDec(key)
            local v = wearedevEvalNumeric(val)
            if #ch == 1 and v ~= nil and map[ch] == nil then map[ch] = v; n = n + 1 end
        end
        for key, val in body:gmatch('([%a_])%s*=%s*([%-+%d%s%(%)]+)') do
            local v = wearedevEvalNumeric(val)
            if v ~= nil and map[key] == nil then map[key] = v; n = n + 1 end
        end
        if n >= 60 and n <= 96 and (not best or n > best.n) then
            best = { map = map, n = n }
        end
    end
    return best
end

local function wearedevDecodeB64(s, alpha)

    local out, buf, bits, i = {}, 0, 0, 1
    local n = #s
    while i <= n do
        local ch = s:sub(i, i)
        if ch == "=" then
            local k = buf * 2 ^ (24 - bits)
            out[#out + 1] = string.char(math.floor(k / 65536) % 256)

            if i >= n or s:sub(i + 1, i + 1) ~= "=" then
                out[#out + 1] = string.char(math.floor((k % 65536) / 256))
            end
            break
        end
        local idx = alpha[ch]
        if idx == nil then return nil end
        buf = buf * 64 + idx
        bits = bits + 6
        if bits >= 24 then
            out[#out + 1] = string.char(math.floor(buf / 65536) % 256)
            out[#out + 1] = string.char(math.floor(buf / 256) % 256)
            out[#out + 1] = string.char(buf % 256)
            buf, bits = 0, 0
        end
        i = i + 1
    end
    return table.concat(out)
end

function deobfWeAreDevV1(code)
    local stats = { arith = 0, accessor = nil, array = nil, offset = 0, entries = 0,
        decoded = 0, printable = 0, inlined = 0, alphabet = false, b64 = false, shuffles = 0,
        constSample = {},
    }
    local prot, strings = wearedevProtectStrings(code)
    prot, stats.arith = wearedevSimplify(prot)

    local acc, arr, off = wearedevFindAccessor(prot)
    stats.accessor, stats.array, stats.offset = acc, arr, off

    local entries = {}
    if arr then
        local body = prot:match("local%s+" .. arr .. "%s*=%s*(%b{})")
        if body then
            for ph in body:gmatch("\1Q(%d+)\1") do
                local raw = strings[tonumber(ph) + 1]
                if raw then entries[#entries + 1] = wearedevUnescapeDec(raw) end
            end
        end
    end
    entries, stats.shuffles = wearedevApplyShuffle(prot, entries)
    stats.entries = #entries

    local b64ish = 0
    for _, e in ipairs(entries) do
        if #e >= 2 and e:match('^[%w%+/%=]+$') then b64ish = b64ish + 1 end
    end
    stats.b64 = #entries > 0 and b64ish >= math.ceil(#entries * 0.7)

    local alpha = wearedevFindAlphabet(code) or wearedevFindAlphabet(wearedevUnprotectStrings(prot, strings))
    stats.alphabet = alpha ~= nil
    local decodedList, byIndex = {}, {}
    if acc and alpha and stats.b64 then
        for i, e in ipairs(entries) do
            local d = wearedevDecodeB64(e, alpha.map)
            byIndex[i] = d
            decodedList[#decodedList + 1] = d
            if d and #d > 0 and not d:find("[\1-\8\14-\31]") then
            stats.printable = stats.printable + 1
            if #stats.constSample < 40 and #d < 48 then stats.constSample[#stats.constSample + 1] = d end
        end
        end
        stats.decoded = #decodedList
        prot = prot:gsub("%f[%w_]" .. acc .. "%s*%(([%d%s%+%-%*%/%(%)]+)%)", function(argTxt)
            local v = wearedevEvalNumeric(argTxt)
            if v == nil then return nil end
            local s = byIndex[math.floor(v - off)]
            if s == nil then return nil end
            stats.inlined = stats.inlined + 1
            strings[#strings + 1] = wearedevEscapeInner(s)
            return "\1Q" .. (#strings - 1) .. "\1"
        end)

    end
    return wearedevUnprotectStrings(prot, strings), stats, decodedList
end

local WEAREDEV_RUNTIME_GLOBALS = {
    type = true, pcall = true, xpcall = true, error = true, select = true, unpack = true,
    next = true, pairs = true, ipairs = true, rawget = true, rawset = true, tostring = true,
    tonumber = true, setmetatable = true, getmetatable = true, newproxy = true,
    getfenv = true, setfenv = true, loadstring = true, require = true, assert = true,
    string = true, table = true, math = true, os = true, coroutine = true, io = true,
}

local function deobfWeAreDevTrace(code)
    if type(code) ~= "string" or #code == 0 then return nil, nil, "空代码" end
    local statements, constants, namesOf, seenConst = {}, {}, {}, {}
    local ENV

    local function noteValue(v)
        if type(v) == "string" and #v > 0 and #v < 256 and not seenConst[v] then
            seenConst[v] = true
            constants[#constants + 1] = v
        end
    end

    local function toText(v)
        if type(v) == "function" then
            if namesOf[v] then return "<fn:" .. namesOf[v] .. ">" end
            return "<function>"
        elseif type(v) == "table" then
            local parts, n = {}, 0
            for i = 1, 12 do
                if v[i] == nil then break end
                n = n + 1
                parts[n] = toText(v[i])
            end
            if n > 0 then return "{" .. table.concat(parts, ", ") .. "}" end
            return "<table>"
        elseif type(v) == "string" then
            noteValue(v)
            return '"' .. wearedevEscapeInner(v) .. '"'
        end
        return tostring(v)
    end

    ENV = setmetatable({}, {
        __index = function(t, key)
            local own = rawget(t, key)
            if own ~= nil then return own end
            if type(key) ~= "string" then return nil end
            local v = _G[key]
            if v == nil then return nil end
            if WEAREDEV_RUNTIME_GLOBALS[key] then return v end
            if type(v) == "function" then
                local wrapped = function(...)
                    local args, cnt = { ... }, select("#", ...)
                    local parts = {}
                    for i = 1, cnt do parts[i] = toText(args[i]) end
                    statements[#statements + 1] = key .. "(" .. table.concat(parts, ", ") .. ")"
                    return v(...)
                end
                namesOf[wrapped] = key
                return wrapped
            end
            if type(v) == "table" then
                local copy = {}
                for k, val in pairs(v) do copy[k] = val end
                return copy
            end
            return v
        end,
        __newindex = function(t, key, val)
            rawset(t, key, val)
            if type(key) == "string" then
                statements[#statements + 1] = key .. " = " .. toText(val)
            end
        end,
    })

    local chunk, lerr = loadstring(code, "@wearedev_trace")
    if not chunk then return nil, nil, "载入失败: " .. tostring(lerr) end
    pcall(setfenv, chunk, ENV)
    local ok, rerr = pcall(chunk)
    if not ok then return statements, constants, "执行中断: " .. tostring(rerr) end
    return statements, constants, nil
end

local function deobfNumExprRestore(code)
    local result = code
    local count = 0

    result = result:gsub("0x(%x+)", function(hex)
        local n = tonumber(hex, 16)
        if n then
            count = count + 1
            return tostring(n)
        end
        return "0x" .. hex
    end)

    result = result:gsub("(%d+)%s*[eE]%s*([%+%-]?%d+)", function(mantissa, exp)
        local n = tonumber(mantissa .. "e" .. exp)
        if n and n == math.floor(n) and math.abs(n) < 1e15 then
            count = count + 1
            return tostring(n)
        end
        return mantissa .. "e" .. exp
    end)

    result = result:gsub("%(%s*(%-?%d+)%s*%+%s*(%-?%d+)%s*%)", function(a, b)
        local n = tonumber(a) + tonumber(b)
        count = count + 1
        return tostring(n)
    end)

    result = result:gsub("%(%s*(%-?%d+)%s*%-%s*(%-?%d+)%s*%)", function(a, b)
        local n = tonumber(a) - tonumber(b)
        count = count + 1
        return tostring(n)
    end)

    result = result:gsub("%(%s*(%-?%d+)%s*%*%s*(%-?%d+)%s*%)", function(a, b)
        local n = tonumber(a) * tonumber(b)
        count = count + 1
        return tostring(n)
    end)

    result = result:gsub("%(%s*(%-?%d+)%s*%%%%%s*(%-?%d+)%s*%)", function(a, b)
        local na, nb = tonumber(a), tonumber(b)
        if nb ~= 0 then
            local n = na % nb
            count = count + 1
            return tostring(n)
        end
        return "(" .. a .. "%" .. b .. ")"
    end)

    local function bit_xor32(x, y)
        x = math.floor(tonumber(x) or 0) % 0x100000000
        y = math.floor(tonumber(y) or 0) % 0x100000000
        local r, b = 0, 1
        for i = 0, 31 do
            if (x % 2 == 1) ~= (y % 2 == 1) then r = r + b end
            x = math.floor(x / 2); y = math.floor(y / 2); b = b * 2
        end
        return r
    end
    result = result:gsub("%(%s*(%-?%d+)%s*%~%s*(%-?%d+)%s*%)", function(a, b)
        local na, nb = tonumber(a), tonumber(b)
        if na and nb and na >= 0 and nb >= 0 and na < 2^32 and nb < 2^32 then
            local n = bit_xor32(na, nb)
            count = count + 1
            return tostring(n)
        end
        return "(" .. a .. "~" .. b .. ")"
    end)

    for _ = 1, 3 do
        local prev = result
        result = result:gsub("%(%s*(%-?%d+)%s*([%+%-%*])%s*(%-?%d+)%s*%)", function(a, op, b)
            local na, nb = tonumber(a), tonumber(b)
            local n
            if op == "+" then n = na + nb
            elseif op == "-" then n = na - nb
            elseif op == "*" then n = na * nb
            end
            if n and n == math.floor(n) and math.abs(n) < 1e15 then
                count = count + 1
                return tostring(n)
            end
            return "(" .. a .. op .. b .. ")"
        end)
        if result == prev then break end
    end

    return result, count
end

local function deobfUnsplitStrings(code)
    local result = code
    local count = 0

    result = result:gsub('table%.concat%s*%(%s*{%s*([^}]*)}%s*%)', function(entries)
        local parts = {}
        for str in entries:gmatch('"([^"]*)"') do
            table.insert(parts, str)
        end
        if #parts > 1 then
            count = count + 1
            return '"' .. table.concat(parts) .. '"'
        end
        return 'table.concat({' .. entries .. '})'
    end)

    repeat
        local prev = result
        result = result:gsub('"([^"]*)"%s*%.%.%s*"([^"]*)"', function(a, b)
            count = count + 1
            return '"' .. a .. b .. '"'
        end)
    until result == prev

    result = result:gsub('string%.rep%s*%(%s*"([^"]*)"%s*,%s*(%d+)%s*%)', function(str, n)
        local nn = tonumber(n)
        if nn and nn <= 100 then
            count = count + 1
            return '"' .. string.rep(str, nn) .. '"'
        end
        return 'string.rep("' .. str .. '",' .. n .. ')'
    end)

    return result, count
end

local function deobfUnwrapFunction(code)
    local result = code
    local count = 0

    local function unwrapPattern(prefix, suffix)
        local pattern = prefix .. '%(%s*function%s*%(%.%.%.%)%s*(.-)%s*end%)%s*%(%.%.%.%)' .. suffix
        return pattern
    end

    result = result:gsub('return%s*%(?%s*function%s*%(%.%.%.%)%s*\n', function()
        count = count + 1
        return ""
    end)

    if count > 0 then
        result = result:gsub('%s*end%s*%)*%s*%(%.%.%.%)%s*$', function()
            return ""
        end)
    end

    result = result:gsub('local%s+([%w_]+)%s*=%s*%(%s*function%s*%(%s*%)%s*\n', function(varname)
        count = count + 1
        return "do\n"
    end)

    if count == 0 then
        result = result:gsub('^%s*return%s+function%s*%(%.%.%.%)%s*\n(.-)\n%s*end%s*%(%.%.%.%)%s*$', function(body)
            count = count + 1
            return body
        end)
    end

    return result, count
end

local function deobfConstantArrayInline(code)
    local result = code
    local count = 0

    local arrays = {}

    result = result:gsub('local%s+([%w_]+)%s*=%s*{%s*([^}]-)%s*}', function(arrName, content)
        local items = {}
        local allStrings = true
        local allNumbers = true
        for _item in content:gmatch('%s*([^,]+)') do
    local item = _item
            item = item:match("^%s*(.-)%s*$")
            if item ~= "" then
                table.insert(items, item)
                if not item:match('^".*"$') and not item:match("^'.*'$") then
                    allStrings = false
                end
                if not item:match("^%-?%d+%.?%d*$") then
                    allNumbers = false
                end
            end
        end
        if (allStrings or allNumbers) and #items > 0 then
            arrays[arrName] = items
            count = count + 1
            return ""
        end
        return "local " .. arrName .. " = {" .. content .. "}"
    end)

    for arrName, items in pairs(arrays) do
        result = result:gsub(arrName .. '%s*%[%s*(%d+)%s*%]', function(idx)
            local i = tonumber(idx)
            if i and items[i + 1] then
                count = count + 1
                return items[i + 1]
            end
            return arrName .. "[" .. idx .. "]"
        end)
    end

    return result, count
end

local function deobfUnproxify(code)
    local result = code
    local count = 0

    local proxies = {}

    result = result:gsub('local%s+([%w_]+)%s*=%s*setmetatable%s*%(%s*{}%s*,%s*{%s*__index%s*=%s*function%s*%([^)]*%)%s*return%s+([%w_]+)%s*%%[k%]%s*end%s*}%s*%)', function(proxyName, origName)
        proxies[proxyName] = origName
        count = count + 1
        return ""
    end)

    result = result:gsub('local%s+([%w_]+)%s*=%s*setmetatable%s*%(%s*{}%s*,%s*{%s*__index%s*=%s*function%s*%(%s*[%w_,%s]*%)%s*return%s+([%w_]+)', function(proxyName, origName)
        if not proxies[proxyName] then
            proxies[proxyName] = origName
            count = count + 1
            return ""
        end
        return "local " .. proxyName .. " = setmetatable({}, {__index = function() return " .. origName
    end)

    for proxyName, origName in pairs(proxies) do
        result = result:gsub("%f[%a_]" .. proxyName .. "%f[^%w_]", origName)
    end

    result = result:gsub('setmetatable%s*%(%s*{}%s*,%s*{%s*__index%s*=%s*function%s*%([^)]*%)%s*end%s*}%s*%)%s*\n', function()
        count = count + 1
        return ""
    end)

    return result, count
end

local function deobfPrometheusFull(code)
    local result = code
    local totalChanges = 0
    local stepCount = 0

    local r1, c1 = deobfConstantArrayInline(result)
    result = r1
    totalChanges = totalChanges + c1
    stepCount = stepCount + 1
    AddLog("[Step " .. stepCount .. "] 常量数组内联: " .. c1 .. " 处", "info")

    local r2, c2 = deobfStringDecrypt(result)
    result = r2
    totalChanges = totalChanges + c2
    stepCount = stepCount + 1
    AddLog("[Step " .. stepCount .. "] 字符串解密: " .. c2 .. " 处", "info")

    local r3, c3 = deobfUnsplitStrings(result)
    result = r3
    totalChanges = totalChanges + c3
    stepCount = stepCount + 1
    AddLog("[Step " .. stepCount .. "] 分割字符串合并: " .. c3 .. " 处", "info")

    local r4, c4 = deobfNumExprRestore(result)
    result = r4
    totalChanges = totalChanges + c4
    stepCount = stepCount + 1
    AddLog("[Step " .. stepCount .. "] 数字表达式还原: " .. c4 .. " 处", "info")

    local r5, c5 = deobfUnproxify(result)
    result = r5
    totalChanges = totalChanges + c5
    stepCount = stepCount + 1
    AddLog("[Step " .. stepCount .. "] 代理变量还原: " .. c5 .. " 处", "info")

    local r6, c6 = deobfUnwrapFunction(result)
    result = r6
    totalChanges = totalChanges + c6
    stepCount = stepCount + 1
    AddLog("[Step " .. stepCount .. "] 函数包装解除: " .. c6 .. " 处", "info")

    local r7, c7 = deobfRestoreControlFlow(result)
    result = r7
    totalChanges = totalChanges + c7
    stepCount = stepCount + 1
    AddLog("[Step " .. stepCount .. "] 控制流还原: " .. c7 .. " 处", "info")

    local r8, c8 = deobfRenameVars(result)
    result = r8
    totalChanges = totalChanges + c8
    stepCount = stepCount + 1
    AddLog("[Step " .. stepCount .. "] 变量重命名: " .. c8 .. " 处", "info")

    local r9, c9 = deobfGcClean(result)
    result = r9
    totalChanges = totalChanges + c9
    stepCount = stepCount + 1
    AddLog("[Step " .. stepCount .. "] 垃圾代码清理: " .. c9 .. " 处", "info")

    result = deobfFormatCode(result)
    stepCount = stepCount + 1
    AddLog("[Step " .. stepCount .. "] 代码格式化完成", "info")

    return result, totalChanges
end

local function deobfGcClean(code)
    local lines = {}
    for line in code:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local result = {}
    local removed = 0

    for _, line in ipairs(lines) do
        local trimmed = line:match("^%s*(.-)%s*$")
        local skip = false

        if trimmed == "" then
            local lastLines = {}
            for i = #result - 2, #result do
                if i > 0 then table.insert(lastLines, result[i]) end
            end
            local emptyCount = 0
            for _, l in ipairs(lastLines) do
                if l:match("^%s*$") then emptyCount = emptyCount + 1 end
            end
            if emptyCount < 3 then
                table.insert(result, line)
            else
                skip = true
            end
        elseif trimmed:match("^local%s+[%a_][%w_]*%s*=%s*nil%s*$") then
            skip = true
            removed = removed + 1
        elseif trimmed:match("^[%a_][%w_]*%s*=%s*nil%s*$") then
            if not trimmed:match("^local%s+") then
                skip = true
                removed = removed + 1
            end
        elseif trimmed:match("^if%s+false%s+then$") then
            skip = true
            removed = removed + 1
        elseif trimmed:match("^%-%-[%s]*$") then
        end

        if not skip then
            table.insert(result, line)
        end
    end

    return table.concat(result, "\n"), removed
end

local function deobfFormatCode(code)
    local lines = {}
    for line in code:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local result = {}
    local indent = 0
    local indentStr = "    "

    for _, line in ipairs(lines) do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed == "" then
            table.insert(result, "")
        else
            local startsBlock = trimmed:match("^function") or trimmed:match("^if%s+")
                or trimmed:match("^for%s+") or trimmed:match("^while%s+")
                or trimmed:match("^do%s*$") or trimmed:match("^repeat%s*$")
            local endsBlock = trimmed:match("^end%s*$") or trimmed:match("^else%s*$")
                or trimmed:match("^elseif%s+") or trimmed:match("^until%s+")

            if endsBlock and not startsBlock then
                indent = math.max(0, indent - 1)
            end

            table.insert(result, indentStr:rep(indent) .. trimmed)

            if startsBlock then
                indent = indent + 1
            end
            if trimmed:match("^else") or trimmed:match("^elseif") then
                indent = indent + 1
            end
        end
    end

    return table.concat(result, "\n")
end

local function deobfAnalyzeCode(code)
    local stats = {}
    stats.totalLines = select(2, code:gsub("\n", "\n")) + 1
    stats.totalChars = #code

    local keywords = {"function", "local", "if", "for", "while", "repeat", "do", "end", "return", "break", "and", "or", "not"}
    stats.keywordCount = 0
    for _, kw in ipairs(keywords) do
        stats.keywordCount = stats.keywordCount + select(2, code:gsub("%f[%a]" .. kw .. "%f[^%w]", ""))
    end

    local varNames = {}
    for var in code:gmatch("local%s+([%a_][%w_]*)") do
        if not varNames[var] then
            varNames[var] = 1
        else
            varNames[var] = varNames[var] + 1
        end
    end
    stats.localCount = 0
    for _ in pairs(varNames) do stats.localCount = stats.localCount + 1 end
    stats.localTotalUses = 0
    for _, c in pairs(varNames) do stats.localTotalUses = stats.localTotalUses + c end

    local funcCount = select(2, code:gsub("function%s", ""))
    stats.functionCount = funcCount

    local strCount = select(2, code:gsub('"[^"]*"', "")) + select(2, code:gsub("'[^']*'", ""))
    stats.stringCount = strCount

    local hasObfuscation = false
    local obMarkers = {
        "obfuscated", "____", "_G[\"", "L0_", "L1_", "L2_",
        "v_%d+", "_v%d+", "oOoOOo", "OOoOOo"
    }
    for _, marker in ipairs(obMarkers) do
        if code:match(marker) then
            hasObfuscation = true
            break
        end
    end
    stats.likelyObfuscated = hasObfuscation

    stats.obfuscators = {}
    if code:match("[Ll]uraph") then table.insert(stats.obfuscators, "Luraph") end
    if code:match("[Ww]earedev") then table.insert(stats.obfuscators, "WeAreDev") end
    if code:match("obfuscate") then table.insert(stats.obfuscators, "通用混淆") end

    return stats
end

local deobfHookActive = false
local deobfHookCount = 0
local deobfHookedLoadstring = nil

local function deobfHookLoadstring()
    if deobfHookActive then
        AddLog("Hook Loadstring 已停止，共拦截 " .. deobfHookCount .. " 次调用", "info")
        deobfHookActive = false
        if deobfHookedLoadstring then
            loadstring = deobfHookedLoadstring
            deobfHookedLoadstring = nil
        end
        if deobfToolButtons["hook_loadstring"] then
            deobfToolButtons["hook_loadstring"].BackgroundColor3 = theme.surface
            deobfToolButtons["hook_loadstring"].BackgroundTransparency = 0.4
        end
        return
    end

    deobfHookedLoadstring = loadstring
    deobfHookCount = 0
    deobfHookActive = true

    local original = loadstring
    loadstring = function(src, chunkname)
        deobfHookCount = deobfHookCount + 1
        local srcStr = tostring(src)
        local cn = tostring(chunkname or "unknown")
        local now = os.date("%H:%M:%S")
        AddLog("[Loadstring #" .. deobfHookCount .. "] " .. cn .. " (" .. #srcStr .. " bytes)", "info")
        table.insert(deobfHookRecords, {
            id = deobfHookCount,
            source = srcStr,
            chunkname = cn,
            time = now,
            size = #srcStr,
        })
        if deobfViewMode == "hooklog" then
            task.spawn(deobfRefreshHookLog)
        end
        if dataApi then
            local fname = "hooked_" .. deobfHookCount .. ".lua"
            dataApi.writeFile(fname, srcStr)
        end
        return original(src, chunkname)
    end

    AddLog("Hook Loadstring 已启动，正在监听...", "info")
    if deobfToolButtons["hook_loadstring"] then
        deobfToolButtons["hook_loadstring"].BackgroundColor3 = theme.green
        deobfToolButtons["hook_loadstring"].BackgroundTransparency = 0.7
    end
end

local function deobfRunTool(toolId)
    if toolId == "hook_loadstring" then
        local wasActive = deobfHookActive
        deobfHookLoadstring()
        if not wasActive then
            deobfShowHookLog()
        end
        return
    end

    if toolId == "detect_obf" then
        local content = ""
        if deobfSelectedFile and dataApi then
            content = dataApi.readFile(deobfSelectedFile) or ""
        end
        if content == "" then
            content = deobfEditorTextBox and deobfEditorTextBox.Text or ""
        end
        if content == "" then
            AddLog("请先选择文件或输入代码", "warn")
            return
        end

        AddLog("=== 混淆检测报告 ===", "info")
        local results = deobfDetectObfuscation(content)
        for _, line in ipairs(results) do
            AddLog(line, "info")
        end
        deobfNotify("混淆检测完成，查看日志详情", 1)
        return
    end

    if toolId == "prometheus_full" then
        local content = ""
        if deobfSelectedFile and dataApi then
            content = dataApi.readFile(deobfSelectedFile) or ""
        end
        if content == "" then
            content = deobfEditorTextBox and deobfEditorTextBox.Text or ""
        end
        if content == "" then
            AddLog("请先选择文件或输入代码", "warn")
            return
        end

        AddLog("=== Prometheus 完全反混淆 ===", "info")
        AddLog("开始处理...", "info")

        local formatted, totalChanges = deobfPrometheusFull(content)

        if dataApi and deobfSelectedFile then
            local backupName = deobfSelectedFile:gsub("%.([^%.]+)$", "_backup.%1")
            dataApi.writeFile(backupName, content)
            dataApi.writeFile(deobfSelectedFile, formatted)
            if deobfViewMode == "editor" and deobfEditorTextBox then
                deobfEditorTextBox.Text = formatted
            end
            AddLog("=== 反混淆完成 ===", "info")
            AddLog("总计 " .. totalChanges .. " 处修改", "info")
            AddLog("已应用到: " .. deobfSelectedFile .. " (备份: " .. backupName .. ")", "info")
            deobfNotify("反混淆完成，已应用到 " .. deobfSelectedFile, 1)
        else
            AddLog("=== 反混淆完成 ===", "info")
            AddLog("总计 " .. totalChanges .. " 处修改", "info")
        end
        return
    end

    if toolId == "wearedev_full" then
        local content = ""
        if deobfSelectedFile and dataApi then
            content = dataApi.readFile(deobfSelectedFile) or ""
        end
        if content == "" then
            content = deobfEditorTextBox and deobfEditorTextBox.Text or ""
        end
        if content == "" then
            AddLog("请先选择文件或输入代码", "warn")
            return
        end

        AddLog("=== WeAreDev 沙箱反混淆引擎 ===", "info")
        AddLog("开始处理...", "info")

        local deobfResult, v1Stats = deobfWeAreDevV1(content)
        local totalChanges = 0

        if v1Stats.alphabet and v1Stats.entries > 0 then
            AddLog(string.format("新版结构还原: 常量数组 %s 共 %d 条，洗牌 %d 段，base64 解出 %d 条（可打印 %d）",
                tostring(v1Stats.array), v1Stats.entries, v1Stats.shuffles, v1Stats.decoded, v1Stats.printable), "info")
            AddLog(string.format("  取串器 %s(%s[]) 偏移 %s，数字化简 %d 处，取串调用内联 %d 处",
                tostring(v1Stats.accessor), tostring(v1Stats.array), tostring(v1Stats.offset),
                v1Stats.arith, v1Stats.inlined), "info")
            totalChanges = totalChanges + v1Stats.arith + v1Stats.inlined
            if #v1Stats.constSample > 0 then
                AddLog("  还原文本常量: " .. table.concat(v1Stats.constSample, ", "):sub(1, 400), "info")
            end
        else
            AddLog("未识别为 WeAreDev v1.0 结构（缺 64 键字母表或常量数组），仅执行后续通用清理", "warn")
        end

        local r2, c2 = deobfNumExprRestore(deobfResult)
        deobfResult = r2
        totalChanges = totalChanges + c2
        if c2 > 0 then AddLog("数字表达式还原: " .. c2 .. " 处", "info") end

        local r3, c3 = deobfUnsplitStrings(deobfResult)
        deobfResult = r3
        totalChanges = totalChanges + c3
        if c3 > 0 then AddLog("分割字符串合并: " .. c3 .. " 处", "info") end

        local formatted = deobfFormatCode(deobfResult)

        if dataApi and deobfSelectedFile then
            local backupName = deobfSelectedFile:gsub("%.([^%.]+)$", "_backup.%1")
            dataApi.writeFile(backupName, content)
            dataApi.writeFile(deobfSelectedFile, formatted)

            if deobfViewMode == "editor" and deobfEditorTextBox then
                deobfEditorTextBox.Text = formatted
            end

            AddLog("=== 反混淆完成 ===", "info")
            AddLog("总计 " .. totalChanges .. " 处修改", "info")
            AddLog("已应用到: " .. deobfSelectedFile .. " (备份: " .. backupName .. ")", "info")
            deobfNotify("反混淆完成，已应用到 " .. deobfSelectedFile, 1)
        else
            if deobfViewMode == "editor" and deobfEditorTextBox then
                deobfEditorTextBox.Text = formatted
            end
            AddLog("=== 反混淆完成 ===", "info")
            AddLog("总计 " .. totalChanges .. " 处修改", "info")
        end
        return
    end

    if toolId == "wearedev_behavior" then
        local srcText = ""
        if deobfSelectedFile and dataApi then
            srcText = dataApi.readFile(deobfSelectedFile) or ""
        end
        if srcText == "" then
            srcText = deobfEditorTextBox and deobfEditorTextBox.Text or ""
        end
        if srcText == "" then
            AddLog("请先选择文件或输入代码", "warn")
            return
        end
        local now = os.clock()
        if deobfBehaviorArmed ~= nil and (now - deobfBehaviorArmed) < 12 then
            deobfBehaviorArmed = nil
            AddLog("=== WeAreDev 行为还原（正在执行脚本）===", "info")
            local stmts, consts, err = deobfWeAreDevTrace(srcText)
            if err then AddLog(err, "warn") end
            if stmts and #stmts > 0 then
                local body = table.concat(stmts, "\n")
                AddLog("还原出 " .. #stmts .. " 条外部行为语句", "info")
                if consts and #consts > 0 then
                    body = body .. "\n\n-- 运行期出现的字符串常量\n"
                    for _, c in ipairs(consts) do
                        body = body .. "-- " .. tostring(c):gsub("[%c]", ".") .. "\n"
                    end
                end
                if deobfViewMode == "editor" and deobfEditorTextBox then
                    deobfEditorTextBox.Text = body
                end
                if dataApi and deobfSelectedFile then
                    local backupName = deobfSelectedFile:gsub("%.([^%.]+)$", "_backup.%1")
                    dataApi.writeFile(backupName, srcText)
                    dataApi.writeFile(deobfSelectedFile, body)
                    AddLog("行为还原已应用到: " .. deobfSelectedFile .. " (备份: " .. backupName .. ")", "info")
                    deobfNotify("行为还原完成，已应用到 " .. deobfSelectedFile, 1)
                end
            else
                AddLog("未捕获到外部行为（脚本只改了自身局部变量，或已在执行前报错）", "warn")
            end
        else
            deobfBehaviorArmed = now
            AddLog("行为还原会真实执行该脚本（游戏 API 调用会发生）。12 秒内再点一次确认。", "warn")
            task.delay(12, function()
                if deobfBehaviorArmed ~= nil and (os.clock() - deobfBehaviorArmed) >= 11 then
                    deobfBehaviorArmed = nil
                end
            end)
        end
        return
    end

    if not deobfSelectedFile or not dataApi then
        AddLog("请先选择一个文件", "warn")
        return
    end

    local content = dataApi.readFile(deobfSelectedFile) or ""
    if content == "" then
        AddLog("文件为空", "warn")
        return
    end

    local newContent = content
    local info = ""
    local count = 0

    if toolId == "rename_vars" then
        newContent, count = deobfRenameVars(content)
        info = "重命名了 " .. count .. " 个变量"
    elseif toolId == "string_decrypt" then
        newContent, count = deobfStringDecrypt(content)
        info = "解密了 " .. count .. " 个字符串"
    elseif toolId == "luraph_clean" then
        newContent, count = deobfCleanLuraph(content)
        info = "清理了 " .. count .. " 处 Luraph 特征"
    elseif toolId == "control_flow" then
        newContent, count = deobfRestoreControlFlow(content)
        info = "还原了 " .. count .. " 处控制流"
    elseif toolId == "num_expr" then
        newContent, count = deobfNumExprRestore(content)
        info = "还原了 " .. count .. " 处数字表达式"
    elseif toolId == "unsplit_str" then
        newContent, count = deobfUnsplitStrings(content)
        info = "合并了 " .. count .. " 处分割字符串"
    elseif toolId == "unwrap_func" then
        newContent, count = deobfUnwrapFunction(content)
        info = "解除了 " .. count .. " 层函数包装"
    elseif toolId == "const_array" then
        newContent, count = deobfConstantArrayInline(content)
        info = "内联了 " .. count .. " 个常量数组引用"
    elseif toolId == "unproxify" then
        newContent, count = deobfUnproxify(content)
        info = "还原了 " .. count .. " 个代理变量"
    elseif toolId == "gc_clean" then
        newContent, count = deobfGcClean(content)
        info = "清理了 " .. count .. " 行垃圾代码"
    elseif toolId == "format" then
        newContent = deobfFormatCode(content)
        info = "代码已格式化"
    elseif toolId == "analyze" then
        local stats = deobfAnalyzeCode(content)
        AddLog("=== 代码分析报告 ===", "info")
        AddLog("总行数: " .. stats.totalLines, "info")
        AddLog("总字符: " .. stats.totalChars, "info")
        AddLog("函数数量: " .. stats.functionCount, "info")
        AddLog("局部变量: " .. stats.localCount, "info")
        AddLog("字符串数量: " .. stats.stringCount, "info")
        AddLog("疑似混淆: " .. tostring(stats.likelyObfuscated), "info")
        if #stats.obfuscators > 0 then
            AddLog("检测到的混淆器: " .. table.concat(stats.obfuscators, ", "), "info")
        end
        return
    end

    if newContent ~= content then
        local backupName = deobfSelectedFile:gsub("%.([^%.]+)$", "_backup.%1")
        dataApi.writeFile(backupName, content)
        dataApi.writeFile(deobfSelectedFile, newContent)
        AddLog(info .. " (备份: " .. backupName .. ")", "info")
        deobfNotify(info .. "，已应用到 " .. deobfSelectedFile, 1)

        if deobfViewMode == "editor" and deobfEditorTextBox then
            deobfEditorTextBox.Text = newContent
        end
    else
        AddLog("没有需要修改的内容", "info")
        deobfNotify("没有需要修改的内容", 2)
    end
end

local function buildUI()
    ensureDeps()

    deobfLeftPanel = create("Frame", {
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(0, DEOBF_LEFT_W, 1, 0),
        BackgroundColor3 = theme.surfaceLight,
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        ZIndex = 3,
    })
    corner(theme.radiusLg, deobfLeftPanel)
    stroke(theme.border, 1, deobfLeftPanel)
    deobfLeftPanel.Parent = deobfPage

    local leftHeader = create("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        ZIndex = 4,
    })
    leftHeader.Parent = deobfLeftPanel

    local leftTitle = create("TextLabel", {
        Position = UDim2.new(0, 14, 0, 0),
        Size = UDim2.new(1, -28, 0, 44),
        BackgroundTransparency = 1,
        Text = "文件管理",
        TextColor3 = theme.text,
        TextSize = 13,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 5,
    })
    leftTitle.Parent = leftHeader
    deobfLeftTitle = leftTitle

    deobfNewFileBtn = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.new(0, 32, 0, 28),
        BackgroundColor3 = theme.accent,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 5,
    })
    corner(8, deobfNewFileBtn)
    local newFileIcon = GetIcon("plus", UDim2.new(0, 14, 0, 14), theme.text)
    if newFileIcon then
        newFileIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        newFileIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
        newFileIcon.ZIndex = 6
        newFileIcon.Parent = deobfNewFileBtn
    end
    deobfNewFileBtn.Parent = leftHeader
    deobfNewFileBtn.MouseButton1Click:Connect(deobfShowNewFileInput)

    deobfNewFileInput = create("Frame", {
        Size = UDim2.new(1, -56, 0, 32),
        Position = UDim2.new(0, 12, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = theme.surface,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 6,
        Visible = false,
        ClipsDescendants = true,
    })
    corner(12, deobfNewFileInput)
    stroke(theme.accent, 1, deobfNewFileInput)
    deobfNewFileInput.Parent = leftHeader

    deobfNewFileInputBox = create("TextBox", {
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(1, -76, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = "输入文件名...",
        PlaceholderColor3 = theme.textDim,
        TextColor3 = theme.text,
        TextSize = 13,
        Font = Enum.Font.SourceSans,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ClearTextOnFocus = false,
        ZIndex = 7,
    })
    deobfNewFileInputBox.Parent = deobfNewFileInput
    deobfNewFileInputBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            deobfCreateNewFile()
        end
    end)

    local confirmBtn = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -40, 0.5, 0),
        Size = UDim2.new(0, 26, 0, 26),
        BackgroundColor3 = theme.green,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        Text = "",
        ZIndex = 7,
    })
    corner(8, confirmBtn)
    local confirmIcon = GetIcon("check", UDim2.new(0, 14, 0, 14), Color3.fromRGB(255,255,255))
    if confirmIcon then
        confirmIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        confirmIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
        confirmIcon.ZIndex = 8
        confirmIcon.Active = false
        confirmIcon.Parent = confirmBtn
    end
    confirmBtn.Parent = deobfNewFileInput
    confirmBtn.AutoButtonColor = true
    confirmBtn.Activated:Connect(function()
        deobfCreateNewFile()
    end)
    confirmBtn.MouseButton1Click:Connect(deobfCreateNewFile)

    local cancelBtn = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.new(0, 26, 0, 26),
        BackgroundColor3 = theme.text,
        BackgroundTransparency = 0.85,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = true,
        ZIndex = 7,
    })
    corner(8, cancelBtn)
    local cancelIcon = GetIcon("x", UDim2.new(0, 14, 0, 14), theme.text)
    if cancelIcon then
        cancelIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        cancelIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
        cancelIcon.ZIndex = 8
        cancelIcon.Active = false
        cancelIcon.Parent = cancelBtn
    end
    cancelBtn.Parent = deobfNewFileInput
    cancelBtn.Activated:Connect(function()
        deobfHideNewFileInput(true)
    end)

    deobfFileListScroll = create("ScrollingFrame", {
        Position = UDim2.new(0, 0, 0, 48),
        Size = UDim2.new(1, 0, 1, -60),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = theme.textDim,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ClipsDescendants = true,
        ZIndex = 4,
    })
    deobfFileListScroll.Parent = deobfLeftPanel

    deobfFileList = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        ZIndex = 5,
    })
    deobfFileList.Parent = deobfFileListScroll

    local divV = create("Frame", {
        Position = UDim2.new(0, DEOBF_LEFT_W + 4, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = theme.border,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 2,
    })
    divV.Parent = deobfPage

    local rightX = DEOBF_LEFT_W + 8
    deobfRightPanel = create("Frame", {
        Position = UDim2.new(0, rightX, 0, 0),
        Size = UDim2.new(1, -rightX, 1, 0),
        BackgroundColor3 = theme.surfaceLight,
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        ZIndex = 3,
    })
    corner(theme.radiusLg, deobfRightPanel)
    stroke(theme.border, 1, deobfRightPanel)
    deobfRightPanel.Parent = deobfPage

    deobfToolsView = create("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ZIndex = 4,
        Visible = true,
    })
    deobfToolsView.Parent = deobfRightPanel

    local toolsHeader = create("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        ZIndex = 5,
    })
    toolsHeader.Parent = deobfToolsView

    local toolsTitle = create("TextLabel", {
        Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(1, -32, 0, 44),
        BackgroundTransparency = 1,
        Text = "反混淆工具",
        TextColor3 = theme.text,
        TextSize = 13,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 6,
    })
    toolsTitle.Parent = toolsHeader

    local toolsScroll = create("ScrollingFrame", {
        Position = UDim2.new(0, 0, 0, 52),
        Size = UDim2.new(1, 0, 1, -60),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = theme.textDim,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ClipsDescendants = true,
        ZIndex = 5,
    })
    toolsScroll.Parent = deobfToolsView

    local toolsList = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        ZIndex = 6,
    })
    toolsList.Parent = toolsScroll

    local colorMap = {
        accent = theme.accent,
        accent2 = theme.accent2,
        green = theme.green,
        warn = theme.warn,
        red = theme.red,
    }

    for i, tool in ipairs(DEOBF_TOOLS) do
        local row = i - 1
        local btnY = 12 + row * 62

        local btn = create("TextButton", {
            Position = UDim2.new(0, 16, 0, btnY),
            Size = UDim2.new(1, -32, 0, 52),
            BackgroundColor3 = theme.surface,
            BackgroundTransparency = 0.4,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 6,
        })
        corner(10, btn)

        local iconColor = colorMap[tool.color] or theme.accent

        local iconBg = create("Frame", {
            Position = UDim2.new(0, 10, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            Size = UDim2.new(0, 32, 0, 32),
            BackgroundColor3 = iconColor,
            BackgroundTransparency = 0.8,
            BorderSizePixel = 0,
            ZIndex = 7,
        })
        corner(8, iconBg)
        iconBg.Parent = btn

        local icon = GetIcon(tool.icon, UDim2.new(0, 16, 0, 16), Color3.fromRGB(255,255,255))
        if icon then
            icon.AnchorPoint = Vector2.new(0.5, 0.5)
            icon.Position = UDim2.new(0.5, 0, 0.5, 0)
            icon.ZIndex = 8
            icon.Parent = iconBg
        end

        local nameLbl = create("TextLabel", {
            Position = UDim2.new(0, 52, 0, 8),
            Size = UDim2.new(1, -64, 0, 18),
            BackgroundTransparency = 1,
            Text = tool.name,
            TextColor3 = theme.text,
            TextSize = 12,
            Font = Enum.Font.SourceSansBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 7,
        })
        nameLbl.Parent = btn

        local descLbl = create("TextLabel", {
            Position = UDim2.new(0, 52, 0, 26),
            Size = UDim2.new(1, -64, 0, 16),
            BackgroundTransparency = 1,
            Text = tool.desc,
            TextColor3 = theme.textDim,
            TextSize = 10,
            Font = Enum.Font.SourceSans,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 7,
        })
        descLbl.Parent = btn

        local arrowIcon = GetIcon("chevron-right", UDim2.new(0, 12, 0, 12), theme.textDim)
        if arrowIcon then
            arrowIcon.AnchorPoint = Vector2.new(1, 0.5)
            arrowIcon.Position = UDim2.new(1, -10, 0.5, 0)
            arrowIcon.ZIndex = 7
            arrowIcon.Parent = btn
        end

        btn.MouseEnter:Connect(function()
            deobfTween(btn, {BackgroundColor3 = iconColor, BackgroundTransparency = 0.85}, 0.15)
        end)
        btn.MouseLeave:Connect(function()
            if toolId == "hook_loadstring" and deobfHookActive then return end
            deobfTween(btn, {BackgroundColor3 = theme.surface, BackgroundTransparency = 0.4}, 0.15)
        end)
        btn.MouseButton1Click:Connect(function()
            deobfRunTool(tool.id)
        end)

        btn.Parent = toolsList
        deobfToolButtons[tool.id] = btn
    end

    local toolCount = #DEOBF_TOOLS
    local toolsContentH = toolCount * 62 + 24
    toolsList.Size = UDim2.new(1, 0, 0, toolsContentH)
    toolsScroll.CanvasSize = UDim2.new(0, 0, 0, toolsContentH)

    deobfHookLogView = create("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ZIndex = 4,
        Visible = false,
    })
    deobfHookLogView.Parent = deobfRightPanel

    local hookLogHeader = create("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        ZIndex = 5,
    })
    hookLogHeader.Parent = deobfHookLogView

    local hookLogBackBtn = create("TextButton", {
        Position = UDim2.new(0, 12, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        Size = UDim2.new(0, 32, 0, 32),
        BackgroundColor3 = theme.surface,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 6,
    })
    corner(8, hookLogBackBtn)
    local hookBackIcon = GetIcon("chevron-left", UDim2.new(0, 14, 0, 14), theme.text)
    if hookBackIcon then
        hookBackIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        hookBackIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
        hookBackIcon.ZIndex = 7
        hookBackIcon.Parent = hookLogBackBtn
    end
    hookLogBackBtn.Parent = hookLogHeader
    hookLogBackBtn.MouseButton1Click:Connect(deobfShowTools)

    local hookLogTitle = create("TextLabel", {
        Position = UDim2.new(0, 52, 0, 0),
        Size = UDim2.new(1, -120, 0, 44),
        BackgroundTransparency = 1,
        Text = "拦截记录",
        TextColor3 = theme.text,
        TextSize = 13,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 6,
    })
    hookLogTitle.Parent = hookLogHeader

    local hookStatusLabel = create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.new(0, 80, 0, 24),
        BackgroundTransparency = 1,
        Text = "监听中",
        TextColor3 = theme.green,
        TextSize = 11,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 6,
    })
    hookStatusLabel.Parent = hookLogHeader

    deobfHookLogScroll = create("ScrollingFrame", {
        Position = UDim2.new(0, 0, 0, 52),
        Size = UDim2.new(1, 0, 1, -60),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = theme.textDim,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ClipsDescendants = true,
        ZIndex = 5,
    })
    deobfHookLogScroll.Parent = deobfHookLogView

    deobfHookLogList = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        ZIndex = 6,
    })
    deobfHookLogList.Parent = deobfHookLogScroll

    deobfRefreshFileList()
end

buildUI()
]===]

local pageDef = {
    name = pageInfo.name,
    title = pageInfo.title,
    icon = pageInfo.icon,
    dataFolder = pageInfo.dataFolder,
    version = pageInfo.version,
}

function pageDef.build(frame, helpers)
    deobfDataApi = helpers and helpers.data
    deobfPage = frame
    frame.Name = pageInfo.name
    if helpers then
        deobfSwitchPage = helpers.switchPage
        deobfNotify = helpers.ShowNotification
    end





    local function tryCompile(src)
        return loadstring(src, "@deobfuscator")
    end

    local fn, err = tryCompile(DEOBFUSCATOR_PAGE_SOURCE)
    if not fn and err then
        local src = DEOBFUSCATOR_PAGE_SOURCE
        local e = tostring(err)

        for _attempt = 1, 3 do
            local cur = src
            local changed = false


            if e:find("Expected type", 1, true) then
                local cleaned = deobfSanitizeTypeAnnotations(cur)
                if cleaned ~= cur then
                    cur = cleaned
                    changed = true
                end
            end


            if e:find("const variable", 1, true) or e:find("Expected type", 1, true) then
                local fixed = deobfFixForInConstAssign(cur)
                if fixed ~= cur then
                    cur = fixed
                    changed = true
                end
            end

            if not changed then break end
            src = cur
            local fn2, err2 = tryCompile(src)
            if fn2 then
                fn, err = fn2, nil
                if _G.__DeltaUI_AddLog then
                    _G.__DeltaUI_AddLog("[反混淆] 已自动清理 Luraph 残留损坏并重新编译", "info")
                end
                break
            end
            e = tostring(err2 or "")
        end
    end
    if not fn then
        if helpers and helpers.ShowNotification then helpers.ShowNotification("Deobf: loadstring失败 " .. tostring(err), 4) end
        warn("[Deobf] loadstring failed:", err)
        return
    end

    local ok, runErr = pcall(fn)
    if not ok then
        if helpers and helpers.ShowNotification then helpers.ShowNotification("Deobf: 运行错误 " .. tostring(runErr), 4) end
        warn("[Deobf] runtime error:", runErr)
        if _G.__DeltaUI_AddLog then _G.__DeltaUI_AddLog("[反混淆] 构建失败: " .. tostring(runErr), "error") end
        return
    end

    if _G.__DeltaUI_AddLog then _G.__DeltaUI_AddLog("[反混淆] 页面构建完成 v" .. tostring(pageInfo.version), "info") end
end

local function register()
    if DeltaRegisterPage then
        DeltaRegisterPage(pageDef)
        return true
    end
    if _G and _G.DeltaRegisterPage then
        _G.DeltaRegisterPage(pageDef)
        return true
    end
    return false
end

local regOk = register()
return pageDef
