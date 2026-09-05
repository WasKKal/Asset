local DEOBFUSCATOR_PAGE_SOURCE = [===[
deobfPage.Name = "deobfuscator"

local svc = nil
local theme = nil
local AddLog = nil
local dataApi = nil

local DEOBF_LEFT_W = 260
local DEOBF_ANIM_DUR = 0.25

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
end

local function deobfTween(obj, props, dur)
    dur = dur or DEOBF_ANIM_DUR
    local tw = TweenInfo.new(dur, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    svc.TweenService:Create(obj, tw, props):Play()
end

local deobfLeftPanel = nil
local deobfFileList = nil
local deobfFileListScroll = nil
local deobfNewFileBtn = nil
local deobfNewFileInput = nil
local deobfNewFileInputBox = nil
local deobfLeftHeader = nil
local deobfIsCreatingNew = false
local deobfSelectedFile = nil
local deobfFileItems = {}

local function deobfRefreshFileList()
    if not deobfFileList or not dataApi then return end
    for _, item in pairs(deobfFileItems) do
        pcall(function() item:Destroy() end)
    end
    deobfFileItems = {}
    
    local files = dataApi.listFiles("") or {}
    local count = 0
    
    for _, fpath in ipairs(files) do
        local fname = fpath:match("([^/\\]+)$") or fpath
        if fname and fname ~= "" and not fname:match("^%.") then
            count = count + 1
            local row = create("TextButton", {
                Size = UDim2.new(1, -16, 0, 32),
                Position = UDim2.new(0, 8, 0, 8 + (count - 1) * 36),
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
                deobfRefreshFileList()
                if AddLog then AddLog("选中文件: " .. fname, "info") end
            end)
            delBtn.MouseButton1Click:Connect(function()
                if dataApi and dataApi.deleteFile(fname) then
                    if AddLog then AddLog("已删除: " .. fname, "info") end
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
    end
    
    local contentH = math.max(60, count * 36 + 16)
    deobfFileList.Size = UDim2.new(1, 0, 0, contentH)
    if deobfFileListScroll then
        deobfFileListScroll.CanvasSize = UDim2.new(0, 0, 0, contentH)
    end
    
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
    end
end

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
        if AddLog then AddLog("请输入文件名", "warn") end
        return
    end
    if not fname:match("^[%w_%-%s]+%.lua$") and not fname:match("^[%w_%-%s]+%.txt$") then
        if not fname:match("%.") then
            fname = fname .. ".lua"
        else
            if AddLog then AddLog("文件名格式不正确", "warn") end
            return
        end
    end
    if dataApi.isFile(fname) then
        if AddLog then AddLog("文件已存在", "warn") end
        return
    end
    if dataApi.writeFile(fname, "") then
        if AddLog then AddLog("已创建: " .. fname, "info") end
        deobfSelectedFile = fname
        deobfHideNewFileInput()
        deobfRefreshFileList()
    end
end

local deobfRightPanel = nil
local deobfRightContent = nil
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

local function deobfRunTool(toolId)
    if AddLog then AddLog("执行工具: " .. toolId, "info") end
    if not deobfSelectedFile then
        if AddLog then AddLog("请先选择一个文件", "warn") end
        return
    end
    if AddLog then AddLog("功能待实现", "info") end
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
    
    deobfLeftHeader = create("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        ZIndex = 4,
    })
    deobfLeftHeader.Parent = deobfLeftPanel
    
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
    leftTitle.Parent = deobfLeftHeader
    
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
    deobfNewFileBtn.Parent = deobfLeftHeader
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
    
    local rightHeader = create("Frame", {
        Size = UDim2.new(1, 0, 0, 44),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        ZIndex = 4,
    })
    rightHeader.Parent = deobfRightPanel
    
    local rightTitle = create("TextLabel", {
        Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(1, -32, 0, 44),
        BackgroundTransparency = 1,
        Text = "反混淆工具",
        TextColor3 = theme.text,
        TextSize = 13,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 5,
    })
    rightTitle.Parent = rightHeader
    
    deobfRightContent = create("ScrollingFrame", {
        Position = UDim2.new(0, 0, 0, 52),
        Size = UDim2.new(1, 0, 1, -60),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = theme.textDim,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ClipsDescendants = true,
        ZIndex = 4,
    })
    deobfRightContent.Parent = deobfRightPanel
    
    local rightList = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        ZIndex = 5,
    })
    rightList.Parent = deobfRightContent
    
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
            ZIndex = 5,
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
            ZIndex = 6,
        })
        corner(8, iconBg)
        iconBg.Parent = btn
        
        local icon = GetIcon(tool.icon, UDim2.new(0, 16, 0, 16), Color3.fromRGB(255,255,255))
        if icon then
            icon.AnchorPoint = Vector2.new(0.5, 0.5)
            icon.Position = UDim2.new(0.5, 0, 0.5, 0)
            icon.ZIndex = 7
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
            ZIndex = 6,
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
            ZIndex = 6,
        })
        descLbl.Parent = btn
        
        local arrowIcon = GetIcon("chevron-right", UDim2.new(0, 12, 0, 12), theme.textDim)
        if arrowIcon then
            arrowIcon.AnchorPoint = Vector2.new(1, 0.5)
            arrowIcon.Position = UDim2.new(1, -10, 0.5, 0)
            arrowIcon.ZIndex = 6
            arrowIcon.Parent = btn
        end
        
        btn.MouseEnter:Connect(function()
            deobfTween(btn, {BackgroundColor3 = iconColor, BackgroundTransparency = 0.85}, 0.15)
        end)
        btn.MouseLeave:Connect(function()
            deobfTween(btn, {BackgroundColor3 = theme.surface, BackgroundTransparency = 0.4}, 0.15)
        end)
        btn.MouseButton1Click:Connect(function()
            deobfRunTool(tool.id)
        end)
        
        btn.Parent = rightList
        deobfToolButtons[tool.id] = btn
    end
    
    local toolCount = #DEOBF_TOOLS
    local rightContentH = toolCount * 62 + 24
    rightList.Size = UDim2.new(1, 0, 0, rightContentH)
    deobfRightContent.CanvasSize = UDim2.new(0, 0, 0, rightContentH)
    
    deobfRefreshFileList()
end

buildUI()
]===]

local pageDef = {
    name = "deobfuscator",
    title = "反混淆工具",
    icon = "shield-check",
    dataFolder = "deobfuscator",
}

function pageDef.build(frame, helpers)
    deobfDataApi = helpers and helpers.data
    deobfPage = frame
    frame.Name = "deobfuscator"

    local fn, err = loadstring(DEOBFUSCATOR_PAGE_SOURCE, "@deobfuscator")
    if not fn then
        return
    end

    local ok, runErr = pcall(fn)
    if not ok then
        return
    end
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
