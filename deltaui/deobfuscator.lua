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
local deobfViewMode = "tools"
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
    { id = "hook_loadstring", name = "Hook Loadstring", icon = "link", desc = "拦截并记录所有 loadstring 调用", color = "accent" },
    { id = "rename_vars", name = "变量重命名", icon = "type", desc = "将混淆变量名替换为可读名称", color = "accent2" },
    { id = "string_decrypt", name = "字符串解密", icon = "unlock", desc = "解密加密的字符串常量", color = "green" },
    { id = "control_flow", name = "控制流还原", icon = "git-branch", desc = "还原被扁平化的控制流", color = "warn" },
    { id = "gc_clean", name = "垃圾代码清理", icon = "trash", desc = "移除无效的死代码和垃圾指令", color = "red" },
    { id = "format", name = "代码格式化", icon = "align-left", desc = "自动缩进和格式化代码", color = "accent" },
    { id = "analyze", name = "代码分析", icon = "search", desc = "分析代码结构和特征", color = "accent2" },
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
    for _, child in ipairs(deobfFileList:GetChildren()) do
        pcall(function() child:Destroy() end)
    end
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
        
        local icon = GetIcon("file-text", UDim2.new(0, 14, 0, 14), theme.textDim)
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

local function deobfRefreshHookLog()
    if not deobfHookLogList then return end
    for _, child in ipairs(deobfHookLogList:GetChildren()) do
        pcall(function() child:Destroy() end)
    end
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

local function deobfSaveCurrentFile()
    if not dataApi or not deobfEditorTextBox then return end
    
    if deobfViewingHookRecord then
        local fname = "hooked_" .. deobfViewingHookRecord.id .. ".lua"
        if dataApi.writeFile(fname, deobfEditorTextBox.Text) then
            deobfViewingHookRecord.source = deobfEditorTextBox.Text
            deobfSelectedFile = fname
            deobfViewingHookRecord = nil
            AddLog("已保存: " .. fname, "info")
            deobfRefreshFileList()
            if deobfEditorView then deobfEditorView.Visible = false end
            deobfShowTools()
        else
            AddLog("保存失败", "warn")
        end
        return
    end
    
    if not deobfSelectedFile then return end
    if dataApi.writeFile(deobfSelectedFile, deobfEditorTextBox.Text) then
        AddLog("已保存: " .. deobfSelectedFile, "info")
        deobfRefreshFileList()
        if deobfEditorView then deobfEditorView.Visible = false end
        deobfShowTools()
    else
        AddLog("保存失败", "warn")
    end
end

-- ========== 反混淆工具 ==========
local function deobfRenameVars(code)
    local varMap = {}
    local varCount = 0
    local patterns = {
        {"[%a_][%w_]*", function(m)
            if not varMap[m] and not ({["local"]=1,["function"]=1,["end"]=1,["if"]=1,["then"]=1,["else"]=1,["elseif"]=1,["return"]=1,["for"]=1,["while"]=1,["do"]=1,["repeat"]=1,["until"]=1,["break"]=1,["true"]=1,["false"]=1,["nil"]=1,["and"]=1,["or"]=1,["not"]=1,["in"]=1,["print"]=1,["pairs"]=1,["ipairs"]=1,["table"]=1,["string"]=1,["math"]=1,["tostring"]=1,["tonumber"]=1,["type"]=1,["pcall"]=1,["xpcall"]=1,["error"]=1,["require"]=1,["game"]=1,["workspace"]=1,["script"]=1,["_G"]=1,["task"]=1,["wait"]=1,["Instance"]=1,["Vector2"]=1,["Vector3"]=1,["UDim2"]=1,["Color3"]=1,["Enum"]=1,["TweenInfo"]=1})[m] then
                if #m <= 3 or m:match("^[a-z]$") or m:match("^_[%d]+") or m:match("^obfuscated") then
                    varCount = varCount + 1
                    varMap[m] = "var_" .. string.format("%03d", varCount)
                end
            end
            return m
        end}
    }
    local result = code
    for _, pair in ipairs(patterns) do
        result = result:gsub(pair[1], pair[2])
    end
    for old, new in pairs(varMap) do
        result = result:gsub("%f[%a_]" .. old .. "%f[^%w_]", new)
    end
    return result, varCount
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
            local startsBlock = trimmed:match("^function") or trimmed:match("^if.*then$") or trimmed:match("^for.*do$") or trimmed:match("^while.*do$") or trimmed:match("^do$") or trimmed:match("^repeat$")
            local endsBlock = trimmed:match("^end") or trimmed:match("^else") or trimmed:match("^elseif") or trimmed:match("^until")
            
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
    
    local keywords = {"function", "local", "if", "for", "while", "repeat", "do", "end", "return", "break"}
    stats.keywordCount = 0
    for _, kw in ipairs(keywords) do
        stats.keywordCount = stats.keywordCount + select(2, code:gsub("%f[%a]" .. kw .. "%f[^%w]", ""))
    end
    
    local varNames = {}
    for var in code:gmatch("local%s+([%a_][%w_]*)") do
        table.insert(varNames, var)
    end
    stats.localCount = #varNames
    
    local funcCount = select(2, code:gsub("function%s*[%a_%.%:]*[%w_]*%s*%(", ""))
    stats.functionCount = funcCount
    
    local strCount = select(2, code:gsub('"[^"]*"', "")) + select(2, code:gsub("'[^']*'", ""))
    stats.stringCount = strCount
    
    local hasObfuscation = false
    local obMarkers = {"obfuscated", "____", "_G[\"", "L0_", "L1_", "v_", "_v"}
    for _, marker in ipairs(obMarkers) do
        if code:find(marker, 1, true) then
            hasObfuscation = true
            break
        end
    end
    stats.likelyObfuscated = hasObfuscation
    
    return stats
end

local function deobfGcClean(code)
    local lines = {}
    for line in code:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    
    local result = {}
    for _, line in ipairs(lines) do
        local trimmed = line:match("^%s*(.-)%s*$")
        local skip = false
        if trimmed == "" then
            -- 空行保留
        elseif trimmed:match("^local%s+[%a_][%w_]*%s*=%s*nil%s*$") then
            skip = true
        elseif trimmed:match("^[%a_][%w_]*%s*=%s*nil%s*$") then
            skip = true
        elseif trimmed:match("^if%s+false%s+then") then
            skip = true
        end
        if not skip then
            table.insert(result, line)
        end
    end
    
    return table.concat(result, "\n")
end

local function deobfStringDecrypt(code)
    local result = code
    local count = 0
    
    result = result:gsub('string%.char%(([%d,%s]+)%)', function(nums)
        local chars = {}
        for num in nums:gmatch("%d+") do
            table.insert(chars, string.char(tonumber(num)))
        end
        count = count + 1
        return '"' .. table.concat(chars) .. '"'
    end)
    
    result = result:gsub("(%d+)%s*%.%.%s*(%d+)", function(a, b)
        return tostring(tonumber(a) + tonumber(b))
    end)
    
    return result, count
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
    
    if toolId == "rename_vars" then
        newContent, count = deobfRenameVars(content)
        info = "重命名了 " .. count .. " 个变量"
    elseif toolId == "string_decrypt" then
        newContent, count = deobfStringDecrypt(content)
        info = "解密了 " .. count .. " 个字符串"
    elseif toolId == "control_flow" then
        AddLog("控制流还原功能开发中", "info")
        return
    elseif toolId == "gc_clean" then
        newContent = deobfGcClean(content)
        info = "已清理垃圾代码"
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
    
    deobfEditorView = create("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ZIndex = 4,
        Visible = false,
    })
    deobfEditorView.Parent = deobfRightPanel
    
    local editorHeader = create("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        ZIndex = 5,
    })
    editorHeader.Parent = deobfEditorView
    
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
    
    deobfRefreshFileList()
end

buildUI()
]===]

local pageDef = {
    name = "deobfuscator",
    title = "反混淆工具",
    icon = "shield-check",
    dataFolder = "deobfuscator",
    version = "1.0.3",
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
    
    if _G.__DeltaUI_AddLog then _G.__DeltaUI_AddLog("[反混淆] 页面构建完成", "info") end
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