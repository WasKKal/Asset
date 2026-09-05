local DEOBFUSCATOR_PAGE_SOURCE = [===[
deobfPage.Name = "deobfuscator"

local svc = nil
local theme = nil
local AddLog = nil
local dataApi = nil

local DEOBF_LEFT_W = 260
local DEOBF_ANIM_DUR = 0.2

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
    if deobfDataApi then dataApi = deobfDataApi end
    -- 从 DeltaPage helpers 获取 UI 工具函数
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

-- ========== 状态 ==========
local deobfLeftPanel = nil
local deobfFileList = nil
local deobfFileListScroll = nil
local deobfNewFileBtn = nil
local deobfNewFileInput = nil
local deobfNewFileInputBox = nil
local deobfIsCreatingNew = false
local deobfSelectedFile = nil
local deobfViewingHookRecord = nil
local deobfFileItems = {}
local deobfFiles = {}

local deobfRightPanel = nil
local deobfViewMode = "tools" -- "tools" | "editor" | "hooklog"
local deobfToolsView = nil
local deobfEditorView = nil
local deobfHookLogView = nil
local deobfHookLogList = nil
local deobfHookLogScroll = nil
local deobfHookLogItems = {}
local deobfHookRecords = {}
local deobfEditorTextBox = nil
local deobfEditorTitle = nil
local deobfEditorSaveBtn = nil
local deobfEditorBackBtn = nil
local deobfToolButtons = {}

local DEOBF_TOOLS = {
    { id = "detect_obf", name = "混淆检测", icon = "scan-search", desc = "检测代码使用的混淆器类型", color = "accent2" },
    { id = "wearedev_full", name = "WeAreDev 完全反混淆", icon = "wand-sparkles", desc = "一键完全反混淆 WeAreDev 脚本", color = "green" },
    { id = "hook_loadstring", name = "Hook Loadstring", icon = "link", desc = "拦截并记录所有 loadstring 调用", color = "accent" },
    { id = "rename_vars", name = "变量重命名", icon = "pencil", desc = "将混淆变量名替换为可读名称", color = "accent2" },
    { id = "string_decrypt", name = "字符串解密", icon = "key-round", desc = "解密加密的字符串常量", color = "green" },
    { id = "luraph_clean", name = "Luraph 清理", icon = "eraser", desc = "清理 Luraph 特征代码", color = "warn" },
    { id = "wearedev_clean", name = "WeAreDev 清理", icon = "sparkles", desc = "清理 WeAreDev 混淆特征", color = "warn" },
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

-- ========== 文件列表 ==========
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
        local empty = create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 20),
            Position = UDim2.new(0, 0, 0, 20),
            BackgroundTransparency = 1,
            Text = "暂无文件，点击上方新建",
            TextColor3 = theme.textDim,
            TextSize = 11,
            Font = Enum.Font.SourceSans,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 5,
        })
        empty.Parent = deobfFileList
        deobfFileList.Size = UDim2.new(1, 0, 0, 60)
        if deobfFileListScroll then
            deobfFileListScroll.CanvasSize = UDim2.new(0, 0, 0, 60)
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
        
        row.MouseEnter:Connect(function()
            deobfTween(row, {BackgroundColor3 = theme.accent, BackgroundTransparency = 0.8}, 0.15)
            delBtn.Visible = true
        end)
        row.MouseLeave:Connect(function()
            if deobfSelectedFile ~= fname then
                deobfTween(row, {BackgroundColor3 = theme.surface, BackgroundTransparency = 0.4}, 0.15)
            end
            delBtn.Visible = false
        end)
        row.MouseButton1Click:Connect(function()
            deobfSelectedFile = fname
            deobfOpenEditor(fname)
            deobfRefreshFileList()
        end)
        delBtn.MouseButton1Click:Connect(function()
            if dataApi and dataApi.deleteFile(fname) then
                AddLog("已删除: " .. fname, "info")
                if deobfSelectedFile == fname then
                    deobfSelectedFile = nil
                    if deobfViewMode == "editor" then
                        deobfShowTools()
                    end
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

-- ========== 新建文件 ==========
local function deobfShowNewFileInput()
    deobfIsCreatingNew = true
    deobfNewFileBtn.Visible = false
    deobfNewFileInput.Visible = true
    if deobfNewFileInputBox then
        deobfNewFileInputBox.Text = ""
        task.spawn(function()
            task.wait()
            pcall(function() deobfNewFileInputBox:CaptureFocus() end)
        end)
    end
end

local function deobfHideNewFileInput()
    deobfIsCreatingNew = false
    deobfNewFileBtn.Visible = true
    deobfNewFileInput.Visible = false
end

local function deobfCreateNewFile()
    if not deobfNewFileInputBox or not dataApi then return end
    local fname = deobfNewFileInputBox.Text
    if not fname or fname == "" then
        AddLog("请输入文件名", "warn")
        return
    end
    if not fname:match("^[%w_%-%s]+%.lua$") and not fname:match("^[%w_%-%s]+%.txt$") then
        if not fname:match("%.") then
            fname = fname .. ".lua"
        else
            AddLog("文件名格式不正确", "warn")
            return
        end
    end
    if dataApi.isFile(fname) then
        AddLog("文件已存在", "warn")
        return
    end
    if dataApi.writeFile(fname, "") then
        AddLog("已创建: " .. fname, "info")
        deobfSelectedFile = fname
        deobfHideNewFileInput()
        deobfRefreshFileList()
        deobfOpenEditor(fname)
    end
end

-- ========== 视图切换 ==========
function deobfShowTools()
    deobfViewMode = "tools"
    if deobfToolsView then deobfToolsView.Visible = true end
    if deobfEditorView then deobfEditorView.Visible = false end
    if deobfHookLogView then deobfHookLogView.Visible = false end
end

function deobfOpenEditor(fname)
    deobfViewMode = "editor"
    deobfSelectedFile = fname
    deobfViewingHookRecord = nil
    if deobfToolsView then deobfToolsView.Visible = false end
    if deobfEditorView then deobfEditorView.Visible = true end
    if deobfHookLogView then deobfHookLogView.Visible = false end
    if deobfEditorTitle then deobfEditorTitle.Text = fname end
    
    if dataApi and deobfEditorTextBox then
        local content = dataApi.readFile(fname) or ""
        deobfEditorTextBox.Text = content
    end
end

function deobfShowHookLog()
    deobfViewMode = "hooklog"
    if deobfToolsView then deobfToolsView.Visible = false end
    if deobfEditorView then deobfEditorView.Visible = false end
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
    if deobfEditorView then deobfEditorView.Visible = true end
    if deobfEditorTitle then deobfEditorTitle.Text = "#" .. record.id .. " " .. tostring(record.chunkname or "unknown") end
    if deobfEditorTextBox then
        deobfEditorTextBox.Text = tostring(record.source or "")
    end
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
        
        -- 查看按钮
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
            Text = "查看",
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
        
        -- 执行按钮
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

local function deobfSaveCurrentFile()
    if not dataApi or not deobfEditorTextBox then return end
    
    if deobfViewingHookRecord then
        local fname = "hooked_" .. deobfViewingHookRecord.id .. ".lua"
        if dataApi.writeFile(fname, deobfEditorTextBox.Text) then
            deobfViewingHookRecord.source = deobfEditorTextBox.Text
            deobfSelectedFile = fname
            deobfViewingHookRecord = nil
            if deobfEditorTitle then deobfEditorTitle.Text = fname end
            AddLog("已保存: " .. fname, "info")
            deobfRefreshFileList()
        else
            AddLog("保存失败", "warn")
        end
        return
    end
    
    if not deobfSelectedFile then return end
    if dataApi.writeFile(deobfSelectedFile, deobfEditorTextBox.Text) then
        AddLog("已保存: " .. deobfSelectedFile, "info")
    else
        AddLog("保存失败", "warn")
    end
end

-- ========== 反混淆工具 ==========

-- 混淆检测
local function deobfDetectObfuscation(code)
    local results = {}
    local totalScore = 0
    
    -- Luraph 检测
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
    
    -- WeAreDev 检测
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
    
    -- 一般混淆特征
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
    
    -- 字符串加密检测
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
    
    -- 反调试检测
    if code:match("debugger") or code:match("debug%.get") then
        table.insert(results, "反调试: 检测到调试器检测代码")
        totalScore = totalScore + 15
    end
    
    -- 垃圾代码检测
    local emptyLines = select(2, code:gsub("^%s*\n", ""))
    if emptyLines > 100 then
        table.insert(results, "垃圾代码: 大量空行 (" .. emptyLines .. ")")
        totalScore = totalScore + 10
    end
    
    -- Prometheus 检测
    local prometheusScore = 0
    -- Prometheus Watermark
    if code:match("Prometheus") or code:match("prometheus") or code:match("levno%-710") then
        prometheusScore = prometheusScore + 35
        table.insert(results, "Prometheus 特征: 找到 Watermark 标记")
    end
    -- ConstantArray: 大量 table 构造器 + 索引引用
    local constArrMatches = select(2, code:gsub('local%s+[%w_]+%s*=%s*{', ""))
    if constArrMatches >= 3 then
        prometheusScore = prometheusScore + 15
        table.insert(results, "Prometheus 特征: 检测到 " .. constArrMatches .. " 处常量数组构造")
    end
    -- NumbersToExpressions: 复杂算术表达式替代数字
    local numExprCount = select(2, code:gsub('0x[%x]+%s*[%%+%-%*/]', ""))
    if numExprCount > 10 then
        prometheusScore = prometheusScore + 15
        table.insert(results, "Prometheus 特征: 检测到 " .. numExprCount .. " 处数字表达式混淆")
    end
    -- WrapInFunction: return (function(...) ... end)(...)
    if code:match("return%s*%(?%s*function%s*%(%.%.%.%)") then
        prometheusScore = prometheusScore + 20
        table.insert(results, "Prometheus 特征: 检测到函数包装 (WrapInFunction)")
    end
    -- SplitStrings: table.concat 拼接片段
    local splitStrCount = select(2, code:gsub('table%.concat', ""))
    if splitStrCount > 5 then
        prometheusScore = prometheusScore + 10
        table.insert(results, "Prometheus 特征: 检测到 " .. splitStrCount .. " 处 table.concat 字符串拼接")
    end
    -- ProxifyLocals: setmetatable + __index
    local proxifyCount = select(2, code:gsub('setmetatable', ""))
    if proxifyCount > 5 then
        prometheusScore = prometheusScore + 15
        table.insert(results, "Prometheus 特征: 检测到 " .. proxifyCount .. " 处 setmetatable 代理")
    end
    -- EncryptStrings: string.char 大量使用
    local strCharCount = select(2, code:gsub('string%.char', ""))
    if strCharCount > 20 then
        prometheusScore = prometheusScore + 15
        table.insert(results, "Prometheus 特征: 检测到 " .. strCharCount .. " 处 string.char 加密")
    end
    if prometheusScore > 0 then
        table.insert(results, "Prometheus 置信度: " .. math.min(100, prometheusScore) .. "%")
        totalScore = totalScore + prometheusScore
    end

    -- 最终判断
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

    -- 返回 results 数组和 detection 对象
    return results, {
        confidence = math.min(100, totalScore),
        prometheus = prometheusScore,
        wearedev = wearedevScore,
        luraph = luraphScore,
        results = results,
    }
end

-- 变量重命名
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
    
    -- 匹配短变量名或混淆变量名
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

-- 字符串解密
local function deobfStringDecrypt(code)
    local result = code
    local count = 0
    
    -- string.char() 解密
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
    
    -- 字符串连接解密
    result = result:gsub('"%s*%.\.%s*"', function()
        count = count + 1
        return '"'
    end)
    
    -- 十六进制字符串解密
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
    
    -- utf8.char 解密
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

-- Luraph 清理
local function deobfCleanLuraph(code)
    local result = code
    local count = 0
    
    -- 清理 Luraph 全局清理代码
    if result:match("__LuraphPrefixCleaned") then
        count = count + 1
        result = result:gsub("_G%.__LuraphPrefixCleaned%s*=%s*true", "")
    end
    
    -- 清理 cleanLuraphPrefix 函数
    result = result:gsub('local%s+function%s+cleanLuraphPrefix%s*%([^)]*%).-end%s*\n', function(m)
        count = count + 1
        return ""
    end)
    
    -- 清理 Luraph 错误处理
    result = result:gsub('_G%.error%s*=%s*function%s*%([^)]*%).-end', function(m)
        count = count + 1
        return ""
    end)
    
    -- 清理 Luraph 相关注释
    result = result:gsub("%-%-[^\n]*[Ll]uraph[^\n]*\n", function(m)
        count = count + 1
        return ""
    end)
    
    -- 清理 Luraph 字符串
    result = result:gsub('"[^"]*Luraph[^"]*"', function(m)
        count = count + 1
        return '""'
    end)
    
    return result, count
end

-- WeAreDev 清理
local function deobfCleanWeAreDev(code)
    local result = code
    local count = 0
    
    -- 清理 WeAreDev 相关代码
    if result:match("WeAreDev") or result:match("wearedev") then
        -- 清理环境变量混淆
        result = result:gsub('getgenv%s*%(%s*%)(%s*)[;,]%s*getgenv', "%1;")
        result = result:gsub('getgenv%s*%(%s*%)(%s*)[;,]%s*%[[^\]]*%]%s*=%s*getgenv', "%1;")
        
        -- 清理长变量名混淆模式
        result = result:gsub('"([^"]*)"%]%s*%[%s*"([^"]*)"%]%s*%[%s*"([^"]*)"%]%s*=%s*"([^"]*)"', function(a, b, c, d)
            if #a > 20 or #b > 20 or #c > 20 then
                count = count + 1
                return "" .. a .. "".. b .. "".. c .."='".. d .."'"
            end
            return '"'.. a ..'"]["'.. b ..'"]["'.. c ..'"]="'.. d ..'"'
        end)
        
        count = count + 1
    end
    
    -- 清理 oOoOOo 模式变量
    result = result:gsub('oOoOOo%s*=', 'local ')
    
    -- 清理字符串反转函数
    result = result:gsub('string%s*%.[%w_]+%s*=%s*function%s*%([^)]*%).-end', function(m)
        if m:match("reverse") or m:match("sub") then
            count = count + 1
            return ""
        end
        return m
    end)
    
    return result, count
end

-- 控制流还原 (简化版)
local function deobfRestoreControlFlow(code)
    local result = code
    local changes = 0
    
    -- 简化 goto 语句 (如果有)
    result = result:gsub("goto%s+(%w+)", function(label)
        changes = changes + 1
        return "-- goto " .. label
    end)
    
    -- 简化 switch/case 结构 (检测 goto 模拟的 switch)
    local switchPattern = "repeat%s*%n%s*local%s+_%w+%s*=%s*(%d+)%s*%n%s*until%s+false%s*%n%s*%-%-%n%s*if%s+_%w+%s*==%s*(%d+)"
    local switchRepl = "switch(%1) case %2"
    
    -- 清理无用的 repeat-until false 结构
    result = result:gsub("repeat%s*\n%s*until%s+false", function(m)
        changes = changes + 1
        return ""
    end, 1)
    
    -- 清理死代码块 (if false then ... end)
    result = result:gsub("if%s+false%s+then%s*[^\n]*\n%s*[^\n]*\n%s*end", function(m)
        changes = changes + 1
        return "-- [dead code removed]"
    end)
    
    return result, changes
end

-- ========== WeAreDev 沙箱反混淆引擎 ==========

-- 在沙箱中安全执行 Lua 代码，返回执行结果或 nil + 错误信息
local function deobfSandboxExec(code, env)
    local fn, err = loadstring(code)
    if not fn then return nil, err end
    setfenv(fn, env or {})
    local ok, result = pcall(fn)
    if ok then return result end
    return nil, result
end

-- 提取并执行 WeAreDev 常量数组解密逻辑
-- Prometheus 混淆输出结构:
--   return(function(...)
--     local u={"..." ; "..." ; ...}     -- 常量数组
--     local function G(G)return u[G-OFFSET]end  -- 索引函数
--     do <shuffle> end                  -- shuffle/rotate
--     <B table + base64 decoder>        -- 自定义 base64 解码器
--     <main code>                       -- VM + 业务逻辑
--   end)(...)
local function deobfWeAreDevSandboxDeobfuscate(code)
    local results = {}
    local count = 0
    local result_code = code

    -- Step 1: 移除 Watermark
    result_code = result_code:gsub("%-%-%[%[.-https://wearedevs%.net/obfuscator.-%]%]%s*", "")
    count = count + 1
    table.insert(results, "移除 Watermark 标记")

    -- Step 2: 提取常量数组 u 的原始内容
    -- 匹配: local u={...}
    local u_match = result_code:match("local%s+u%s*=%s*({.-})")
    if not u_match then
        -- 尝试其他变量名
        u_match = result_code:match("local%s+(%w+)%s*=%s*({[^\n]-})")
        if u_match then
            u_match = result_code:match("local%s+" .. u_match .. "%s*=%s*({.-})")
        end
    end

    if not u_match then
        table.insert(results, "警告: 未找到常量数组")
        return result_code, count, results
    end

    -- Step 3: 提取 G 函数中的偏移量
    -- local function G(G)return u[G-(EXPR)]end
    local g_offset_str = result_code:match("local%s+function%s+G%(G%)return%s+u%[G%-(.-)%]end")
    local g_offset = 0
    if g_offset_str then
        -- 评估偏移表达式
        local expr = g_offset_str:gsub("%s", "")
        -- 安全评估: 只包含数字和 +-*/
local function safeEvalNumber(expr)
    -- 兼容 Lua 5.1 / Luau：安全求值数字/位运算表达式。
    -- 返回 number 表示成功；nil 表示无法静态求值（调用方保留原始代码）。
    -- 修复 bEjbN-@deobfuscator:998 报 "Expected identifier when parsing expression, got '~'"：
    -- 含 ~ & | 的表达式不再直接交给宿主的 loadstring。
    if type(expr) ~= "string" then return nil end
    -- 去除所有空白，使 "10 & 3"、"~ 1" 等也能被纯 Lua 回退求值器正确 tokenize
    local compact = expr:gsub("%s+", "")
    if compact == "" then return nil end
    local asNum = tonumber(compact)
    if asNum then return asNum end
    if compact:match("^[0-9%+%-%*/%(%)%.]+$") then
        local fn, err = loadstring("return " .. compact)
        if fn then
            local ok, val = pcall(fn)
            if ok and type(val) == "number" then return val end
        end
    end
    local floor = math.floor
    local function toB(x) return floor(tonumber(x) or 0) % 0x100000000 end
    local function bnot(x) return 0xFFFFFFFF - toB(x) end
    local function band(x, y)
        x, y = toB(x), toB(y); local r, b = 0, 1
        for i = 0, 31 do
            if x % 2 == 1 and y % 2 == 1 then r = r + b end
            x = floor(x / 2); y = floor(y / 2); b = b * 2
        end
        return r
    end
    local function bor(x, y)
        x, y = toB(x), toB(y); local r, b = 0, 1
        for i = 0, 31 do
            if x % 2 == 1 or y % 2 == 1 then r = r + b end
            x = floor(x / 2); y = floor(y / 2); b = b * 2
        end
        return r
    end
    local function bxor(x, y)
        x, y = toB(x), toB(y); local r, b = 0, 1
        for i = 0, 31 do
            if x % 2 ~= y % 2 then r = r + b end
            x = floor(x / 2); y = floor(y / 2); b = b * 2
        end
        return r
    end
    -- 纯 Lua 5.1 / Luau 递归下降求值器（用本地表 F 存放互相递归函数，避免前向引用，
    -- 兼容 Lua 5.1 与严格宿主；不使用 ~ & | 运算符，避免 Lua 5.1 编译错误）。
    local p = 1
    local len = #compact
    local function peek() return compact:sub(p, p) end
    local F = {}
    function F.parseFact()
        local t = peek()
        if t == "" then return nil end
        if t == "~" then p = p + 1; return bnot(F.parseFact() or 0) end
        if t == "-" then p = p + 1; return -(F.parseFact() or 0) end
        if t == "+" then p = p + 1; return F.parseFact() or 0 end
        if t == "(" then
            p = p + 1
            local v = F.parseExpr()
            if p <= len and peek() == ")" then p = p + 1 end
            return v
        end
        if t:match("[0-9]") then
            local s = p
            while p <= len and compact:sub(p, p):match("[0-9%.]") do p = p + 1 end
            return tonumber(compact:sub(s, p - 1)) or 0
        end
        return nil
    end
    function F.parseTerm()
        local val = F.parseFact()
        while p <= len do
            local t = peek()
            if t == "*" then p = p + 1; val = (val or 0) * (F.parseFact() or 0)
            elseif t == "/" then p = p + 1; val = (val or 0) / (F.parseFact() or 0)
            else break end
        end
        return val
    end
    function F.parseExpr()
        local val = F.parseTerm()
        while p <= len do
            local t = peek()
            if t == "+" then p = p + 1; val = (val or 0) + (F.parseTerm() or 0)
            elseif t == "-" then p = p + 1; val = (val or 0) - (F.parseTerm() or 0)
            elseif t == "~" then p = p + 1; val = bxor(val or 0, F.parseTerm() or 0)
            elseif t == "&" then p = p + 1; val = band(val or 0, F.parseTerm() or 0)
            elseif t == "|" then p = p + 1; val = bor(val or 0, F.parseTerm() or 0)
            else break end
        end
        return val
    end
    local ok, val = pcall(parseExpr)
    if ok and type(val) == "number" and p >= len then return val end
    return nil
end
        local ok, val = pcall(function() return safeEvalNumber(expr) end)
        if ok and type(val) == "number" then
            g_offset = val
        end
    end
    table.insert(results, "G 函数偏移量: " .. tostring(g_offset))

    -- Step 4: 提取 shuffle/rotate 操作
    -- 格式: do for G,V in ipairs({{a,b};{c,d};...}) do while V[1]<V[2] do u[...],u[...],... end end end
    local shuffle_pairs = {}
    -- 匹配 shuffle 对: {expr1, expr2}
    for a, b in result_code:gmatch("{([^,}]+),([^}]+)}") do
        -- 评估表达式
        local ok_a, val_a = pcall(function() return safeEvalNumber(a:gsub("%s","")) end)
        local ok_b, val_b = pcall(function() return safeEvalNumber(b:gsub("%s","")) end)
        if ok_a and ok_b and type(val_a) == "number" and type(val_b) == "number" then
            if val_a < val_b then
                table.insert(shuffle_pairs, {val_a, val_b})
            end
        end
    end
    table.insert(results, "Shuffle 对数: " .. #shuffle_pairs)

    -- Step 5: 构造沙箱代码来解码常量数组
    -- 我们需要在沙箱中执行: local u={...}; <shuffle>; <base64 decode>
    -- 但不能执行整个混淆代码（包含 VM）
    -- 策略: 提取从 local u={...} 到 base64 解码循环结束的部分

    -- 提取从 local u= 到 B 表和解码循环的完整初始化代码
    local init_start = result_code:find("local%s+u%s*=%s*{")
    if not init_start then
        table.insert(results, "警告: 未找到常量数组起始位置")
        return result_code, count, results
    end

    -- 找到 base64 解码循环的结束位置
    -- 解码循环格式: for u=1,#G,1 do ... end
    -- 我们需要找到这段代码的结束位置
    -- 策略: 找到 "local function G(G)return u[" 之前的部分就是初始化代码
    local g_func_pos = result_code:find("local%s+function%s+G%(G%)return%s+u%[")
    local init_end = nil

    if g_func_pos then
        -- G 函数在 shuffle 之后，我们需要包含 shuffle
        -- 找到 shuffle do...end 块的结束
        -- 搜索 "end end" 在 G 函数之前的位置
        local search_end = g_func_pos
        local end_end_pos = result_code:find("end end", init_start)
        if end_end_pos and end_end_pos < search_end then
            init_end = end_end_pos + 7 -- "end end" 的长度
        end
    end

    if not init_end then
        -- 回退: 尝试找到 base64 解码器部分
        -- 搜索 "for" 循环后的 "end" 
        init_end = result_code:find("local%s+function%s+G%(G%)") or #result_code
    end

    -- 提取初始化代码
    local init_code = result_code:sub(init_start, init_end)

    -- Step 6: 提取自定义 base64 字母表
    -- B 表格式: B={P=0;M=5;c=14;["\054"]=51;...}
    local b_table_code = init_code:match("(B=%b{})")
    if not b_table_code then
        table.insert(results, "警告: 未找到 B 表 (自定义 base64 字母表)")
    end

    -- Step 7: 构造沙箱执行代码
    -- 沙箱代码: 执行初始化部分，然后输出解码后的常量数组
    local sandbox_code = [[
        local math = math
        local string = string
        local table = table
        local ipairs = ipairs
        local tonumber = tonumber
        local tostring = tostring
        local type = type
        local pairs = pairs
        local assert = assert

        -- 执行初始化代码
        ]] .. init_code .. [[

        -- 收集解码后的常量数组
        local decoded = {}
        for i = 1, #u do
            decoded[i] = u[i]
        end

        -- 也提供 G 函数
        local function G(x)
            return u[x - ]] .. tostring(g_offset) .. [[]
        end

        -- 返回解码结果
        return decoded, G
    ]]

    -- Step 8: 在沙箱中执行
    local sandbox_env = {
        math = math,
        string = string,
        table = table,
        ipairs = ipairs,
        tonumber = tonumber,
        tostring = tostring,
        type = type,
        pairs = pairs,
        assert = assert,
        print = function() end,
        error = function() end,
        pcall = pcall,
        select = select,
        rawget = rawget,
        rawset = rawset,
        rawequal = rawequal,
        setmetatable = setmetatable,
        getmetatable = getmetatable,
        unpack = unpack or table.unpack,
    }

    local fn, err = loadstring(sandbox_code)
    if not fn then
        table.insert(results, "沙箱编译失败: " .. tostring(err))
        -- 回退到静态解码
        return result_code, count, results
    end
    setfenv(fn, sandbox_env)

    local ok, decoded, g_func = pcall(fn)
    if not ok or type(decoded) ~= "table" then
        table.insert(results, "沙箱执行失败: " .. tostring(decoded))
        -- 回退到静态解码
        return result_code, count, results
    end

    table.insert(results, "成功解码 " .. #decoded .. " 个常量")
    count = count + #decoded

    -- Step 9: 替换 G(number_expr) 调用为实际字符串值
    -- 匹配: G(<arithmetic expression>)
    local g_replacements = 0
    result_code = result_code:gsub("G%(([-+%d%s%*%/%(%)]+)%)", function(expr)
        -- 评估算术表达式
        local clean_expr = expr:gsub("%s", "")
        local ok_eval, val = pcall(function() return safeEvalNumber(clean_expr) end)
        if ok_eval and type(val) == "number" and g_func then
            local str = g_func(val)
            if type(str) == "string" then
                g_replacements = g_replacements + 1
                -- 转义字符串中的特殊字符
                local escaped = str:gsub("\\", "\\\\")
                escaped = escaped:gsub('"', '\\"')
                escaped = escaped:gsub("\n", "\\n")
                escaped = escaped:gsub("\r", "\\r")
                escaped = escaped:gsub("\t", "\\t")
                return '"' .. escaped .. '"'
            end
        end
        return "G(" .. expr .. ")"
    end)

    table.insert(results, "替换 G() 调用: " .. g_replacements .. " 处")
    count = count + g_replacements

    -- Step 10: 评估并替换数字表达式
    -- 匹配: NNN+-NNN 或 NNN-(-NNN) 等模式
    local num_replacements = 0
    result_code = result_code:gsub("%(([-+]?(%d+)%s*([%+%-])%s*%(?([-+]?%d+)%s*%)?%)", function(full, a, op, b)
        local na, nb = tonumber(a), tonumber(b)
        if na and nb then
            local val
            if op == "+" then val = na + nb
            elseif op == "-" then val = na - nb
            end
            if val then
                num_replacements = num_replacements + 1
                return tostring(val)
            end
        end
        return full
    end)

    -- 递归简化多层嵌套表达式
    for _ = 1, 5 do
        local prev = result_code
        result_code = result_code:gsub("%(([-+]?(%d+)%s*([%+%-])%s*%(?([-+]?%d+)%s*%)?%)", function(full, a, op, b)
            local na, nb = tonumber(a), tonumber(b)
            if na and nb then
                local val
                if op == "+" then val = na + nb
                elseif op == "-" then val = na - nb
                end
                if val then return tostring(val) end
            end
            return full
        end)
        if result_code == prev then break end
    end

    table.insert(results, "还原数字表达式: " .. num_replacements .. " 处")
    count = count + num_replacements

    -- Step 11: 移除 WrapInFunction 包装
    -- 移除开头的: return(function(...)
    result_code = result_code:gsub("^return%(function%(%.%.%.%)", "do\n", 1)
    -- 移除结尾的: end)(getfenv...end)(...)
    result_code = result_code:gsub("end%)%(getfenv.-%)end%)%(%%.%.%.%)%s*$", "\nend", 1)
    -- 更通用的结尾移除
    result_code = result_code:gsub("end%)%([^)]*%)%s*end%)%(%%.%.%.%)%s*$", "\nend", 1)
    count = count + 2
    table.insert(results, "移除 WrapInFunction 包装")

    -- Step 12: 移除常量数组定义和 G 函数定义
    -- 移除: local u={...} (使用 %b{} 匹配平衡大括号)
    result_code = result_code:gsub("local%s+u%s*=%s*%b{}%s*", "", 1)
    -- 移除: local function G(G)return u[G-(EXPR)]end
    result_code = result_code:gsub("local%s+function%s+G%(G%)return%s+u%[G%-.-%]end%s*", "", 1)
    table.insert(results, "移除常量数组和 G 函数定义")

    -- Step 13: 移除 shuffle do...end 块
    -- 格式: do for G,V in ipairs({...}) do while V[..]<V[..] do u[...],u[...],... end end end
    result_code = result_code:gsub("^do%s+for%s+%w+,%w+%s+in%s+ipairs%(.-%s*do%s+while.-%s+end%s+end%s+end%s*", "", 1)
    table.insert(results, "移除 shuffle 块")

    -- Step 14: 移除 base64 解码器块
    -- 格式: do local G=u local V=string.len ... end (在 shuffle 之后)
    local decoder_start = result_code:find("do local")
    if decoder_start and decoder_start < 500 then
        -- 通过 do/end 深度跟踪找到匹配的 end
        local depth = 0
        local pos = decoder_start
        local decoder_end = nil
        while pos <= #result_code do
            local ch = result_code:sub(pos, pos + 2)
            if ch == "do " or ch == "do\n" or ch == "do\t" then
                depth = depth + 1
                pos = pos + 2
            elseif result_code:sub(pos, pos + 3) == "end " or result_code:sub(pos, pos + 3) == "end\n" or result_code:sub(pos, pos + 3) == "end\t" or result_code:sub(pos, pos + 3) == "end)" then
                depth = depth - 1
                pos = pos + 3
                if depth <= 0 then
                    decoder_end = pos + 1
                    break
                end
            else
                pos = pos + 1
            end
        end
        if decoder_end then
            result_code = result_code:sub(1, decoder_start - 1) .. result_code:sub(decoder_end)
            count = count + 1
            table.insert(results, "移除 base64 解码器块")
        end
    end

    -- Step 15: 标记 VM 代码区域
    local vm_start = result_code:find("local%s+function%s+[A-Z]%b()")
    if vm_start then
        table.insert(results, "检测到 VM 代码区域 (位置 " .. vm_start .. ")")
    end

    -- Step 14: 格式化
    table.insert(results, "执行代码格式化")

    return result_code, count, results
end

-- ========== Prometheus 反混淆功能 ==========

-- 数字表达式还原: 将 NumbersToExpressions 生成的算术表达式还原为数字常量
local function deobfNumExprRestore(code)
    local result = code
    local count = 0

    -- 还原 hex 数字: 0xFF -> 255
    result = result:gsub("0x(%x+)", function(hex)
        local n = tonumber(hex, 16)
        if n then
            count = count + 1
            return tostring(n)
        end
        return "0x" .. hex
    end)

    -- 还原科学计数法: 1e3 -> 1000
    result = result:gsub("(%d+)%s*[eE]%s*([%+%-]?%d+)", function(mantissa, exp)
        local n = tonumber(mantissa .. "e" .. exp)
        if n and n == math.floor(n) and math.abs(n) < 1e15 then
            count = count + 1
            return tostring(n)
        end
        return mantissa .. "e" .. exp
    end)

    -- 还原简单加法表达式: (a + b) -> a+b
    result = result:gsub("%(%s*(%-?%d+)%s*%+%s*(%-?%d+)%s*%)", function(a, b)
        local n = tonumber(a) + tonumber(b)
        count = count + 1
        return tostring(n)
    end)

    -- 还原简单减法表达式: (a - b) -> a-b
    result = result:gsub("%(%s*(%-?%d+)%s*%-%s*(%-?%d+)%s*%)", function(a, b)
        local n = tonumber(a) - tonumber(b)
        count = count + 1
        return tostring(n)
    end)

    -- 还原乘法表达式: (a * b) -> a*b
    result = result:gsub("%(%s*(%-?%d+)%s*%*%s*(%-?%d+)%s*%)", function(a, b)
        local n = tonumber(a) * tonumber(b)
        count = count + 1
        return tostring(n)
    end)

    -- 还原取模表达式: (a % b) -> a%b 的结果（仅在能确定时）
    result = result:gsub("%(%s*(%-?%d+)%s*%%%%%s*(%-?%d+)%s*%)", function(a, b)
        local na, nb = tonumber(a), tonumber(b)
        if nb ~= 0 then
            local n = na % nb
            count = count + 1
            return tostring(n)
        end
        return "(" .. a .. "%" .. b .. ")"
    end)

    -- 还原位运算表达式: (a ~ b) -> XOR 结果 (Luau)
    result = result:gsub("%(%s*(%-?%d+)%s*%~%s*(%-?%d+)%s*%)", function(a, b)
        local na, nb = tonumber(a), tonumber(b)
        if na >= 0 and nb >= 0 and na < 2^32 and nb < 2^32 then
            local n = na ~ nb
            count = count + 1
            return tostring(n)
        end
        return "(" .. a .. "~" .. b .. ")"
    end)

    -- 多层嵌套表达式递归还原 (最多3层)
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

-- 分割字符串合并: 将 SplitStrings 拆分的片段重新合并
local function deobfUnsplitStrings(code)
    local result = code
    local count = 0

    -- 合并 table.concat({...}) 模式
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

    -- 合并连续字符串拼接: "a" .. "b" -> "ab"
    repeat
        local prev = result
        result = result:gsub('"([^"]*)"%s*%.%.%s*"([^"]*)"', function(a, b)
            count = count + 1
            return '"' .. a .. b .. '"'
        end)
    until result == prev

    -- 合并 string.rep("x", n) -> "xxx" (小 n)
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

-- 函数包装解除: 解除 WrapInFunction 的外层包装
local function deobfUnwrapFunction(code)
    local result = code
    local count = 0

    -- 匹配: return (function(...) <body> end)(...)
    -- 也匹配: local <var> = (function(...) <body> end)(...)
    local function unwrapPattern(prefix, suffix)
        local pattern = prefix .. '%(%s*function%s*%(%.%.%.%)%s*(.-)%s*end%)%s*%(%.%.%.%)' .. suffix
        return pattern
    end

    -- 简化版: return (function(...) <body> end)(...)
    result = result:gsub('return%s*%(?%s*function%s*%(%.%.%.%)%s*\n', function()
        count = count + 1
        return ""
    end)

    -- 移除尾部的 end)(...) 包装
    if count > 0 then
        -- 找到最后的 end)(...) 并移除
        result = result:gsub('%s*end%s*%)*%s*%(%.%.%.%)%s*$', function()
            return ""
        end)
    end

    -- 解除 local var = (function(...) body end)(...) 模式
    result = result:gsub('local%s+([%w_]+)%s*=%s*%(%s*function%s*%(%s*%)%s*\n', function(varname)
        count = count + 1
        return "do\n"
    end)

    -- 如果没有匹配到复杂模式，尝试简单的一行包装
    if count == 0 then
        result = result:gsub('^%s*return%s+function%s*%(%.%.%.%)%s*\n(.-)\n%s*end%s*%(%.%.%.%)%s*$', function(body)
            count = count + 1
            return body
        end)
    end

    return result, count
end

-- 常量数组内联: 将 ConstantArray 提取的常量引用替换回原始值
local function deobfConstantArrayInline(code)
    local result = code
    local count = 0

    -- 查找常量数组定义: local <arr> = { "val1", "val2", ... } 或 local <arr> = { val1, val2, ... }
    -- 然后替换所有 <arr>[<idx>] 为对应值
    local arrays = {}

    -- 匹配字符串常量数组
    result = result:gsub('local%s+([%w_]+)%s*=%s*{%s*([^}]-)%s*}', function(arrName, content)
        -- 仅处理看起来像常量数组的（全字符串或全数字）
        local items = {}
        local allStrings = true
        local allNumbers = true
        for item in content:gmatch('%s*([^,]+)') do
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
            return "" -- 移除数组定义
        end
        return "local " .. arrName .. " = {" .. content .. "}"
    end)

    -- 替换数组索引引用: <arr>[<idx>]
    for arrName, items in pairs(arrays) do
        result = result:gsub(arrName .. '%s*%[%s*(%d+)%s*%]', function(idx)
            local i = tonumber(idx)
            if i and items[i + 1] then -- Lua 1-indexed
                count = count + 1
                return items[i + 1]
            end
            return arrName .. "[" .. idx .. "]"
        end)
    end

    return result, count
end

-- 代理变量还原: 解除 ProxifyLocals 的 setmetatable 代理
local function deobfUnproxify(code)
    local result = code
    local count = 0

    -- 匹配 proxy 对象创建: local <proxy> = setmetatable({}, { __index = function(_, k) return <original>[k] end })
    local proxies = {}

    result = result:gsub('local%s+([%w_]+)%s*=%s*setmetatable%s*%(%s*{}%s*,%s*{%s*__index%s*=%s*function%s*%([^)]*%)%s*return%s+([%w_]+)%s*%%[k%]%s*end%s*}%s*%)', function(proxyName, origName)
        proxies[proxyName] = origName
        count = count + 1
        return ""
    end)

    -- 更宽泛的匹配
    result = result:gsub('local%s+([%w_]+)%s*=%s*setmetatable%s*%(%s*{}%s*,%s*{%s*__index%s*=%s*function%s*%(%s*[%w_,%s]*%)%s*return%s+([%w_]+)', function(proxyName, origName)
        if not proxies[proxyName] then
            proxies[proxyName] = origName
            count = count + 1
            return ""
        end
        return "local " .. proxyName .. " = setmetatable({}, {__index = function() return " .. origName
    end)

    -- 替换 proxy 引用为原始变量
    for proxyName, origName in pairs(proxies) do
        result = result:gsub("%f[%a_]" .. proxyName .. "%f[^%w_]", origName)
    end

    -- 清理空的 setmetatable 调用
    result = result:gsub('setmetatable%s*%(%s*{}%s*,%s*{%s*__index%s*=%s*function%s*%([^)]*%)%s*end%s*}%s*%)%s*\n', function()
        count = count + 1
        return ""
    end)

    return result, count
end

-- Prometheus 完全反混淆: 一键执行全部 Prometheus 反混淆步骤
local function deobfPrometheusFull(code)
    local result = code
    local totalChanges = 0
    local stepCount = 0

    -- Step 1: 常量数组内联
    local r1, c1 = deobfConstantArrayInline(result)
    result = r1
    totalChanges = totalChanges + c1
    stepCount = stepCount + 1
    AddLog("[Step " .. stepCount .. "] 常量数组内联: " .. c1 .. " 处", "info")

    -- Step 2: 字符串解密
    local r2, c2 = deobfStringDecrypt(result)
    result = r2
    totalChanges = totalChanges + c2
    stepCount = stepCount + 1
    AddLog("[Step " .. stepCount .. "] 字符串解密: " .. c2 .. " 处", "info")

    -- Step 3: 分割字符串合并
    local r3, c3 = deobfUnsplitStrings(result)
    result = r3
    totalChanges = totalChanges + c3
    stepCount = stepCount + 1
    AddLog("[Step " .. stepCount .. "] 分割字符串合并: " .. c3 .. " 处", "info")

    -- Step 4: 数字表达式还原
    local r4, c4 = deobfNumExprRestore(result)
    result = r4
    totalChanges = totalChanges + c4
    stepCount = stepCount + 1
    AddLog("[Step " .. stepCount .. "] 数字表达式还原: " .. c4 .. " 处", "info")

    -- Step 5: 代理变量还原
    local r5, c5 = deobfUnproxify(result)
    result = r5
    totalChanges = totalChanges + c5
    stepCount = stepCount + 1
    AddLog("[Step " .. stepCount .. "] 代理变量还原: " .. c5 .. " 处", "info")

    -- Step 6: 函数包装解除
    local r6, c6 = deobfUnwrapFunction(result)
    result = r6
    totalChanges = totalChanges + c6
    stepCount = stepCount + 1
    AddLog("[Step " .. stepCount .. "] 函数包装解除: " .. c6 .. " 处", "info")

    -- Step 7: 控制流还原
    local r7, c7 = deobfRestoreControlFlow(result)
    result = r7
    totalChanges = totalChanges + c7
    stepCount = stepCount + 1
    AddLog("[Step " .. stepCount .. "] 控制流还原: " .. c7 .. " 处", "info")

    -- Step 8: 变量重命名
    local r8, c8 = deobfRenameVars(result)
    result = r8
    totalChanges = totalChanges + c8
    stepCount = stepCount + 1
    AddLog("[Step " .. stepCount .. "] 变量重命名: " .. c8 .. " 处", "info")

    -- Step 9: 垃圾代码清理
    local r9, c9 = deobfGcClean(result)
    result = r9
    totalChanges = totalChanges + c9
    stepCount = stepCount + 1
    AddLog("[Step " .. stepCount .. "] 垃圾代码清理: " .. c9 .. " 处", "info")

    -- Step 10: 格式化
    result = deobfFormatCode(result)
    stepCount = stepCount + 1
    AddLog("[Step " .. stepCount .. "] 代码格式化完成", "info")

    return result, totalChanges
end

-- 垃圾代码清理
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
        
        -- 空行保留
        if trimmed == "" then
            -- 保留单行空行，最多连续3个
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
        -- nil 赋值清理
        elseif trimmed:match("^local%s+[%a_][%w_]*%s*=%s*nil%s*$") then
            skip = true
            removed = removed + 1
        elseif trimmed:match("^[%a_][%w_]*%s*=%s*nil%s*$") then
            if not trimmed:match("^local%s+") then
                skip = true
                removed = removed + 1
            end
        -- if false then 清理
        elseif trimmed:match("^if%s+false%s+then$") then
            skip = true
            removed = removed + 1
        -- 注释行清理 (可选)
        elseif trimmed:match("^%-%-[%s]*$") then
            -- 保留有意义的注释
        end
        
        if not skip then
            table.insert(result, line)
        end
    end
    
    return table.concat(result, "\n"), removed
end

-- 代码格式化
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

-- 代码分析
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
    
    -- 检测混淆类型
    stats.obfuscators = {}
    if code:match("[Ll]uraph") then table.insert(stats.obfuscators, "Luraph") end
    if code:match("[Ww]earedev") then table.insert(stats.obfuscators, "WeAreDev") end
    if code:match("obfuscate") then table.insert(stats.obfuscators, "通用混淆") end
    
    return stats
end

-- Hook Loadstring
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
        return
    end

    -- Prometheus 完全反混淆
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
            local backupName = deobfSelectedFile:gsub("%.([^%.]+)$", "_deobfuscated.%1")
            dataApi.writeFile(backupName, formatted)
            if deobfViewMode == "editor" and deobfEditorTextBox then
                deobfEditorTextBox.Text = formatted
            end
            AddLog("=== 反混淆完成 ===", "info")
            AddLog("总计 " .. totalChanges .. " 处修改", "info")
            AddLog("结果已保存到: " .. backupName, "info")
        else
            AddLog("=== 反混淆完成 ===", "info")
            AddLog("总计 " .. totalChanges .. " 处修改", "info")
        end
        return
    end

    -- WeAreDev 完全反混淆 (沙箱引擎)
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

        -- Step 1: 沙箱执行反混淆
        local deobfResult, changeCount, stepResults = deobfWeAreDevSandboxDeobfuscate(content)

        -- 输出沙箱引擎步骤结果
        for _, stepInfo in ipairs(stepResults) do
            AddLog("  " .. stepInfo, "info")
        end

        AddLog("沙箱引擎完成: " .. changeCount .. " 处修改", "info")

        -- Step 2: 对沙箱输出做后处理
        local totalChanges = changeCount

        -- 数字表达式还原
        local r2, c2 = deobfNumExprRestore(deobfResult)
        deobfResult = r2
        totalChanges = totalChanges + c2
        if c2 > 0 then AddLog("数字表达式还原: " .. c2 .. " 处", "info") end

        -- 分割字符串合并
        local r3, c3 = deobfUnsplitStrings(deobfResult)
        deobfResult = r3
        totalChanges = totalChanges + c3
        if c3 > 0 then AddLog("分割字符串合并: " .. c3 .. " 处", "info") end

        -- 变量重命名
        local r4, c4 = deobfRenameVars(deobfResult)
        deobfResult = r4
        totalChanges = totalChanges + c4
        if c4 > 0 then AddLog("变量重命名: " .. c4 .. " 处", "info") end

        -- 垃圾代码清理
        local r5, c5 = deobfGcClean(deobfResult)
        deobfResult = r5
        totalChanges = totalChanges + c5
        if c5 > 0 then AddLog("垃圾代码清理: " .. c5 .. " 行", "info") end

        -- 格式化
        local formatted = deobfFormatCode(deobfResult)

        -- 保存结果
        if dataApi and deobfSelectedFile then
            local backupName = deobfSelectedFile:gsub("%.([^%.]+)$", "_deobfuscated.%1")
            dataApi.writeFile(backupName, formatted)

            if deobfViewMode == "editor" and deobfEditorTextBox then
                deobfEditorTextBox.Text = formatted
            end

            AddLog("=== 反混淆完成 ===", "info")
            AddLog("总计 " .. totalChanges .. " 处修改", "info")
            AddLog("结果已保存到: " .. backupName, "info")
        else
            if deobfViewMode == "editor" and deobfEditorTextBox then
                deobfEditorTextBox.Text = formatted
            end
            AddLog("=== 反混淆完成 ===", "info")
            AddLog("总计 " .. totalChanges .. " 处修改", "info")
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
    elseif toolId == "wearedev_clean" then
        newContent, count = deobfCleanWeAreDev(content)
        info = "清理了 " .. count .. " 处 WeAreDev 特征"
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
        
        if deobfViewMode == "editor" and deobfEditorTextBox then
            deobfEditorTextBox.Text = newContent
        end
    else
        AddLog("没有需要修改的内容", "info")
    end
end

-- ========== 构建 UI ==========
local function buildUI()
    ensureDeps()
    
    -- 左侧面板
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
    
    -- 新建文件按钮
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
    
    -- 新建文件输入框
    deobfNewFileInput = create("Frame", {
        Size = UDim2.new(1, -16, 0, 36),
        Position = UDim2.new(0, 8, 0, 52),
        BackgroundColor3 = theme.surface,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        ZIndex = 6,
        Visible = false,
    })
    corner(10, deobfNewFileInput)
    stroke(theme.accent, 1, deobfNewFileInput)
    deobfNewFileInput.Parent = deobfLeftPanel
    
    deobfNewFileInputBox = create("TextBox", {
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -76, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = "输入文件名...",
        PlaceholderColor3 = theme.textDim,
        TextColor3 = theme.text,
        TextSize = 12,
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
        Position = UDim2.new(1, -34, 0.5, 0),
        Size = UDim2.new(0, 24, 0, 24),
        BackgroundColor3 = theme.green,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Text = "",
        ZIndex = 7,
    })
    corner(6, confirmBtn)
    local confirmIcon = GetIcon("check", UDim2.new(0, 12, 0, 12), Color3.fromRGB(255,255,255))
    if confirmIcon then
        confirmIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        confirmIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
        confirmIcon.ZIndex = 8
        confirmIcon.Parent = confirmBtn
    end
    confirmBtn.Parent = deobfNewFileInput
    confirmBtn.MouseButton1Click:Connect(deobfCreateNewFile)
    
    local cancelBtn = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -6, 0.5, 0),
        Size = UDim2.new(0, 24, 0, 24),
        BackgroundColor3 = theme.red,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Text = "",
        ZIndex = 7,
    })
    corner(6, cancelBtn)
    local cancelIcon = GetIcon("x", UDim2.new(0, 12, 0, 12), Color3.fromRGB(255,255,255))
    if cancelIcon then
        cancelIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        cancelIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
        cancelIcon.ZIndex = 8
        cancelIcon.Parent = cancelBtn
    end
    cancelBtn.Parent = deobfNewFileInput
    cancelBtn.MouseButton1Click:Connect(deobfHideNewFileInput)
    
    -- 文件列表滚动区
    deobfFileListScroll = create("ScrollingFrame", {
        Position = UDim2.new(0, 0, 0, 96),
        Size = UDim2.new(1, 0, 1, -108),
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
    
    -- 分隔线
    local divV = create("Frame", {
        Position = UDim2.new(0, DEOBF_LEFT_W + 4, 0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundColor3 = theme.border,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 2,
    })
    divV.Parent = deobfPage
    
    -- 右侧面板
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
    
    -- ===== 工具视图 =====
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
    
    -- ===== 拦截记录视图 =====
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
    
    -- 返回按钮
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
    
    -- 状态标签
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
    
    -- ===== 编辑器视图 =====
    deobfEditorView = create("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ZIndex = 4,
        Visible = false,
    })
    deobfEditorView.Parent = deobfRightPanel
    
    -- 编辑器头部
    local editorHeader = create("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        ZIndex = 5,
    })
    editorHeader.Parent = deobfEditorView
    
    -- 返回按钮
    deobfEditorBackBtn = create("TextButton", {
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
    corner(8, deobfEditorBackBtn)
    local backIcon = GetIcon("chevron-left", UDim2.new(0, 14, 0, 14), theme.text)
    if backIcon then
        backIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        backIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
        backIcon.ZIndex = 7
        backIcon.Parent = deobfEditorBackBtn
    end
    deobfEditorBackBtn.Parent = editorHeader
    deobfEditorBackBtn.MouseButton1Click:Connect(deobfShowTools)
    
    -- 文件名
    deobfEditorTitle = create("TextLabel", {
        Position = UDim2.new(0, 52, 0, 0),
        Size = UDim2.new(1, -120, 0, 44),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = theme.text,
        TextSize = 13,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 6,
    })
    deobfEditorTitle.Parent = editorHeader
    
    -- 保存按钮
    deobfEditorSaveBtn = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.new(0, 64, 0, 32),
        BackgroundColor3 = theme.green,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 6,
    })
    corner(8, deobfEditorSaveBtn)
    local saveLabel = create("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "保存",
        TextColor3 = Color3.fromRGB(255,255,255),
        TextSize = 12,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 7,
    })
    saveLabel.Parent = deobfEditorSaveBtn
    deobfEditorSaveBtn.Parent = editorHeader
    deobfEditorSaveBtn.MouseButton1Click:Connect(deobfSaveCurrentFile)
    
    -- 编辑器文本框
    local editorBg = create("Frame", {
        Position = UDim2.new(0, 12, 0, 52),
        Size = UDim2.new(1, -24, 1, -64),
        BackgroundColor3 = theme.bg,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        ZIndex = 5,
    })
    corner(12, editorBg)
    stroke(theme.border, 1, editorBg)
    editorBg.Parent = deobfEditorView
    
    deobfEditorTextBox = create("TextBox", {
        Position = UDim2.new(0, 12, 0, 10),
        Size = UDim2.new(1, -24, 1, -20),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = theme.text,
        TextSize = 12,
        Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ClearTextOnFocus = false,
        MultiLine = true,
        TextWrapped = false,
        ZIndex = 6,
    })
    deobfEditorTextBox.Parent = editorBg
    
    -- 初始化
    deobfRefreshFileList()
end

buildUI()
]===]

local pageDef = {
    name = "deobfuscator",
    title = "反混淆工具",
    icon = "shield-check",
    dataFolder = "deobfuscator",
    version = "1.0.0",
}

function pageDef.build(frame, helpers)
    deobfDataApi = helpers and helpers.data
    deobfPage = frame
    frame.Name = "deobfuscator"

    local fn, err = loadstring(DEOBFUSCATOR_PAGE_SOURCE, "@deobfuscator")
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
    
    if _G.__DeltaUI_AddLog then _G.__DeltaUI_AddLog("[反混淆] 页面构建完成 v1.0.0", "info") end
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
