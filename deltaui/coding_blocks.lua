local CODING_PAGE_SOURCE = [===[function codingObjPropOptions()
    local out, seen = {}, {}
    local function put(n)
        if type(n) ~= "string" or n == "" or seen[n] then return end
        seen[n] = true
        out[#out + 1] = n
    end
    for _, n in ipairs(CODING_OBJ_PROPS) do put(n) end
    pcall(function()
        for _, rec in ipairs(obStoredObjects or {}) do
            local node = obResolve(rec.path)
            if node then
                local ok, names = pcall(propListNames, node)
                if ok and type(names) == "table" then

                    for _, n in ipairs(CODING_OBJ_PROP_EXTRA) do
                        for _, real in ipairs(names) do
                            if real == n then put(n) break end
                        end
                    end
                end
            end
        end
    end)
    return out
end

codingPage.Name = "coding"

local CODING_RIGHT_W_DEFAULT = 280
local CODING_RIGHT_W_COLLAPSED = CODING_RIGHT_W_DEFAULT
local CODING_RIGHT_W_EXPANDED = 480
local CODING_ANIM_DUR = 0.28

codingPickerOpen = false

local function codingGetAvailableWidth()

    local pw = 960
    pcall(function()
        if codingPage and codingPage.Parent then
            pw = codingPage.AbsoluteSize.X
        end
    end)
    return math.max(480, pw)
end

local function codingApplyRightWidth(targetW, dur)
    dur = dur or CODING_ANIM_DUR
    if not (codingRightPanel and codingRightPanel.Parent) then return end
    local avail = codingGetAvailableWidth()
    local w = math.clamp(targetW, 240, math.max(240, avail - 120))
    local tw = TweenInfo.new(dur, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    svc.TweenService:Create(codingRightPanel, tw, {Size = UDim2.new(0, w, 1, 0)}):Play()
end

local function codingApplySearchWidth(fixedW)
    if not (codingPickerSearch and codingRightPanel and codingRightPanel.Parent) then return end
    local panelW = fixedW or codingRightPanel.AbsoluteSize.X
    if panelW <= 0 then
        pcall(function() panelW = codingRightPanel.Size.X.Offset end)
    end
    local inner = math.max(160, panelW - 24)
    codingPickerSearch.Size = UDim2.new(0, inner - 52, 1, 0)
    codingPickerInput.Size = UDim2.new(1, -((codingPickerSearchIcon and 28 or 10) + 12), 1, 0)
end

codingGridArea = create("Frame", {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, -CODING_RIGHT_W_COLLAPSED - 6, 1, 0),
    BackgroundColor3 = theme.surfaceLight,
    BackgroundTransparency = 0.55,
    BorderSizePixel = 0,
    ZIndex = 3,
})
corner(theme.radiusLg, codingGridArea)
stroke(theme.border, 1, codingGridArea)
codingGridArea.Parent = codingPage

codingEmptyIcon = GetIcon("flask-conical", UDim2.new(0, 30, 0, 30), theme.border)
if codingEmptyIcon then
    codingEmptyIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    codingEmptyIcon.Position = UDim2.new(0.5, 0, 0.5, -22)
    codingEmptyIcon.ZIndex = 4
    codingEmptyIcon.Parent = codingGridArea
end
codingEmptyLabel = create("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 16),
    Size = UDim2.new(1, -24, 0, 16),
    BackgroundTransparency = 1,
    Text = "当前未放置任何积木",
    TextColor3 = theme.textDim,
    TextSize = 11,
    Font = Enum.Font.SourceSans,
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 4,
    Parent = codingGridArea,
})

codingRightPanel = create("Frame", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, 0, 0, 0),
    Size = UDim2.new(0, CODING_RIGHT_W_COLLAPSED, 1, 0),
    BackgroundColor3 = theme.surfaceLight,
    BackgroundTransparency = 0.55,
    BorderSizePixel = 0,
    ZIndex = 3,
})
corner(theme.radiusLg, codingRightPanel)
stroke(theme.border, 1, codingRightPanel)
codingRightPanel.Parent = codingPage

codingGridArea.ClipsDescendants = true

CODING_Z_MIN, CODING_Z_MAX, CODING_Z_STEP = 0.5, 2.0, 0.1
codingView = { z = 1, panX = 0, panY = 0 }
CODING_DROPDOWN_OPEN = 0
codingBlocks = {}
codingBlockSeq = 0
CODING_VAR_ACCENT = Color3.fromRGB(139, 92, 246)

codingCanvas = create("Frame", {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 4,
})
codingCanvas.Name = "codingCanvas"
codingCanvas.Parent = codingGridArea

codingViewHint = create("TextButton", {
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -10, 1, -10),
    Size = UDim2.new(0, 46, 0, 22),
    BackgroundColor3 = theme.surface,
    BackgroundTransparency = 0.35,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 6,
})
corner(8, codingViewHint)
stroke(theme.border, 1, codingViewHint)
codingViewHint.Parent = codingCanvas
codingViewHintLabel = create("TextLabel", {
    Position = UDim2.new(0, 6, 0, 0),
    Size = UDim2.new(1, -12, 1, 0),
    BackgroundTransparency = 1,
    Text = "100%",
    TextColor3 = theme.textDim,
    TextSize = 10,
    Font = Enum.Font.SourceSans,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 7,
    Parent = codingViewHint,
})

function codingCanvasUsable()
    if currentPage ~= "coding" then return false end
    if buildSpaceActive then return false end
    if codingSettingsMode then return false end
    return (codingGridArea ~= nil and codingGridArea.Parent ~= nil)
end

function codingIsMouseTouch(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

function codingPointInCanvas(px, py)
    if not (codingGridArea and codingGridArea.Parent) then return false end
    local ap, asz = codingGridArea.AbsolutePosition, codingGridArea.AbsoluteSize
    if asz.X <= 0 or asz.Y <= 0 then return false end
    return px >= ap.X and px <= ap.X + asz.X and py >= ap.Y and py <= ap.Y + asz.Y
end

local function codingVisibleOnScreen(obj)
    local o = obj
    while o do
        if o:IsA("GuiObject") and not o.Visible then return false end
        o = o.Parent
    end
    return true
end

local function codingPointInObj(obj, px, py)
    if not (obj and obj.Parent) then return false end
    if not codingVisibleOnScreen(obj) then return false end
    local ok, ap, asz = pcall(function() return obj.AbsolutePosition, obj.AbsoluteSize end)
    if not ok or not ap or not asz then return false end
    if asz.X <= 0 or asz.Y <= 0 then return false end
    return px >= ap.X and px <= ap.X + asz.X and py >= ap.Y and py <= ap.Y + asz.Y
end

local function codingPointerBlocked(px, py)

    local ok, res = pcall(function()
        if obWindow and codingPointInObj(obWindow, px, py) then return true end
        if propWindow and codingPointInObj(propWindow, px, py) then return true end
        if codingSettingsMode and codingSettingsPanel and codingPointInObj(codingSettingsPanel, px, py) then return true end
        return false
    end)
    return (ok and res) or false
end

function codingAnyDropdownOpen()
    local open = false
    local t = _G.__DeltaUI_codingDDVeils
    if t then
        for i = #t, 1, -1 do
            local v = t[i]
            if v and v.Parent then
                open = true
            else
                table.remove(t, i)
            end
        end
    end
    local ov = _G.__DeltaUI_dropdownOverlay
    if ov then
        if ov.Parent then
            open = true
        else
            _G.__DeltaUI_dropdownOverlay = nil
        end
    end

    if (not open) and CODING_DROPDOWN_OPEN ~= 0 then
        CODING_DROPDOWN_OPEN = 0
    end
    return open
end

function codingCanvasCenter()
    local ap, asz = codingGridArea.AbsolutePosition, codingGridArea.AbsoluteSize
    return ap.X + asz.X * 0.5, ap.Y + asz.Y * 0.5
end

function codingUpdateCanvasEmptyState()
    local has = #codingBlocks > 0
    pcall(function() if codingEmptyIcon then codingEmptyIcon.Visible = (not has) end end)
    pcall(function() if codingEmptyLabel then codingEmptyLabel.Visible = (not has) end end)
end

function codingUpdateViewHint()
    pcall(function()
        if codingViewHintLabel then
            codingViewHintLabel.Text = math.floor(codingView.z * 100 + 0.5) .. "%"
        end
    end)
end

function codingApplyBlock(b)
    if not (b and b.root and b.root.Parent) then return end
    codingApplyBlockGeom(b)
end

function codingApplyView()
    for i = #codingBlocks, 1, -1 do
        local b = codingBlocks[i]
        if not (b and b.root and b.root.Parent) then
            table.remove(codingBlocks, i)
        else
            codingApplyBlock(b)
        end
    end
    codingUpdateCanvasEmptyState()
    codingUpdateViewHint()
end

function codingBlockHasFocusedInput(b)
    if not (b and b.eles) then return false end
    for _, e in ipairs(b.eles) do
        local o = e and e.o
        if o and o:IsA("TextBox") and o:IsFocused() then return true end
    end
    return false
end

function codingAnyBlockInputFocused()
    for _, b in ipairs(codingBlocks) do
        if codingBlockHasFocusedInput(b) then return true end
    end
    return false
end

function codingBlurBlockInputs()
    for _, b in ipairs(codingBlocks) do
        if b and b.eles then
            for _, e in ipairs(b.eles) do
                local o = e and e.o
                if o and o:IsA("TextBox") and o:IsFocused() then
                    pcall(function() o:ReleaseFocus(true) end)
                end
            end
        end
    end
end

function codingZoomAt(newZ, px, py)
    newZ = math.clamp(newZ, CODING_Z_MIN, CODING_Z_MAX)
    local oldZ = codingView.z
    if math.abs(newZ - oldZ) < 0.0001 then return end
    local cx, cy = codingCanvasCenter()
    local rx, ry = (px or cx) - cx, (py or cy) - cy
    local k = newZ / oldZ
    codingView.panX = rx - k * (rx - codingView.panX)
    codingView.panY = ry - k * (ry - codingView.panY)
    codingView.z = newZ

    codingZoomTarget = newZ
    codingApplyView()
end

CODING_DAMP_TAU_ZOOM = 0.11
CODING_DAMP_TAU_PAN  = 0.075
CODING_DAMP_PAN_MIN_V = 30
CODING_DAMP_MAX_V = 850
CODING_DAMP_VEL_WIN = 0.03

codingZoomTarget = 1
codingZoomAnchor = nil
codingPanVel = { x = 0, y = 0 }

function codingZoomRequest(targetZ, px, py)
    codingZoomTarget = math.clamp(targetZ or codingView.z, CODING_Z_MIN, CODING_Z_MAX)
    if px and py then
        codingZoomAnchor = Vector2.new(px, py)
    elseif not codingZoomAnchor then
        local cx, cy = codingCanvasCenter()
        codingZoomAnchor = Vector2.new(cx, cy)
    end
end

function codingDampStep(dt)
    dt = (type(dt) == "number" and dt > 0) and math.min(dt, 0.1) or (1 / 60)
    local moved = false

    local tz = codingZoomTarget
    if math.abs(tz - codingView.z) > 0.0004 then
        local k = 1 - math.exp(-dt / CODING_DAMP_TAU_ZOOM)
        local nz = codingView.z + (tz - codingView.z) * k
        if math.abs(tz - nz) < 0.0004 then nz = tz end
        local a = codingZoomAnchor

        codingZoomAt(nz, a and a.X, a and a.Y)
        codingZoomTarget = tz
        moved = true
    end

    local vx, vy = codingPanVel.x or 0, codingPanVel.y or 0
    if (not codingPanDrag) and (math.abs(vx) > CODING_DAMP_PAN_MIN_V or math.abs(vy) > CODING_DAMP_PAN_MIN_V) then
        codingView.panX = codingView.panX + vx * dt
        codingView.panY = codingView.panY + vy * dt
        local decay = math.exp(-dt / CODING_DAMP_TAU_PAN)
        codingPanVel.x, codingPanVel.y = vx * decay, vy * decay
        codingApplyView()
        moved = true
    elseif not codingPanDrag then
        codingPanVel.x, codingPanVel.y = 0, 0
    end
    return moved
end

pcall(function()
    svc.RunService.RenderStepped:Connect(function(dt)
        pcall(function()
            if not codingCanvasUsable() then
                codingZoomTarget = codingView.z
                codingPanVel.x, codingPanVel.y = 0, 0
                return
            end
            codingDampStep(dt)
        end)
    end)
end)

function codingResetView()

    codingZoomTarget = 1
    codingZoomAnchor = nil
    codingPanVel.x, codingPanVel.y = 0, 0
    codingView.z = 1
    codingView.panX = 0
    codingView.panY = 0
    codingApplyView()
end

function codingBeginDragObjMove(onMove, onEnd, startInput)
    local connMove, connEnd, connHeartbeat
    local finished = false
    local uis = svc.UserInputService
    local isTouch = startInput and startInput.UserInputType == Enum.UserInputType.Touch
    local accX, accY = 0, 0
    local function finish()
        if finished then return end
        finished = true
        if connMove then pcall(function() connMove:Disconnect() end); connMove = nil end
        if connEnd then pcall(function() connEnd:Disconnect() end); connEnd = nil end
        if connHeartbeat then pcall(function() connHeartbeat:Disconnect() end); connHeartbeat = nil end
        pcall(onEnd)
    end
    connMove = uis.InputChanged:Connect(function(inp)
        if finished then return end

        local ut = inp.UserInputType
        if ut ~= Enum.UserInputType.MouseMovement and ut ~= Enum.UserInputType.Touch then return end
        local dX, dY = 0, 0
        local ok, dxv, dyv = pcall(function() return inp.Delta.X, inp.Delta.Y end)
        if ok and type(dxv) == "number" and type(dyv) == "number" then
            dX, dY = dxv, dyv
        end
        accX, accY = accX + dX, accY + dY

        pcall(function() onMove(accX, accY, dX, dY) end)
    end)
    connEnd = uis.InputEnded:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        finish()
    end)

    if not isTouch then
        pcall(function()
            connHeartbeat = svc.RunService.RenderStepped:Connect(function()
                if finished then return end
                local down = false
                pcall(function() down = uis:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end)
                if not down then finish() end
            end)
        end)
    end
    return finish
end

function codingReg(b, obj, pos, size)
    local okP, curPos, curSize = pcall(function() return obj.Position, obj.Size end)
    local rec = {
        o = obj,
        pos = pos or (okP and curPos or nil),
        size = size or (okP and curSize or nil),
    }
    local okTs, ts = pcall(function() return obj.TextSize end)
    if okTs and type(ts) == "number" and ts > 0 then rec.ts = ts end
    table.insert(b.eles, rec)
    return obj
end

function codingPruneBlock(b)
    for i = #b.eles, 1, -1 do
        local o = b.eles[i].o
        if not (o and o.Parent) then table.remove(b.eles, i) end
    end
end

function codingCell(host, xScale, wScale)
    local cell = create("Frame", {
        Position = UDim2.new(xScale, 0, 0, 0),
        Size = UDim2.new(wScale, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 11,
    })
    cell.Parent = host
    return cell
end

function codingRegTextOnly(b, obj)
    return codingReg(b, obj, nil, nil)
end

function codingDropdown(b, cell, getOptions, initial, onPick)
    local btn = create("TextButton", {
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = theme.surfaceLight,
        BackgroundTransparency = 0.28,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 12,
    })
    corner(8, btn)
    stroke(theme.border, 1, btn)
    local lbl = create("TextLabel", {
        Position = UDim2.new(0, 8, 0, 0),
        Size = UDim2.new(1, -26, 1, 0),
        BackgroundTransparency = 1,
        Text = initial or "",
        TextColor3 = theme.text,
        TextSize = 12,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 13,
    })
    local arrow = GetIcon("chevron-down", UDim2.new(0, 12, 0, 12), theme.textDim)
    if arrow then
        arrow.AnchorPoint = Vector2.new(1, 0.5)
        arrow.Position = UDim2.new(1, -10, 0.5, 0)
        arrow.ZIndex = 13
        arrow.Parent = btn

        codingReg(b, arrow, nil, nil)
    end
    lbl.Parent = btn
    btn.Parent = cell

    local current = initial or ""

    local openFrame, openFollow, openVeil
    local api
    api = {
        close = function()
            local hadAny = (openFrame ~= nil) or (openFollow ~= nil) or (openVeil ~= nil)
            if openFollow then pcall(function() openFollow:Disconnect() end) end
            if openVeil then

                pcall(function()
                    local t = _G.__DeltaUI_codingDDVeils
                    if t then
                        for i = #t, 1, -1 do
                            if t[i] == openVeil then table.remove(t, i) break end
                        end
                    end
                end)
                pcall(function() if openVeil.Parent then openVeil:Destroy() end end)
            end
            if openFrame then pcall(function() if openFrame.Parent then openFrame:Destroy() end end) end

            openFollow, openVeil, openFrame = nil, nil, nil
            if hadAny then
                CODING_DROPDOWN_OPEN = math.max(0, CODING_DROPDOWN_OPEN - 1)
            end
        end,
        btn = btn,
        isOpen = function() return openFrame ~= nil end,
        set = function(txt) current = txt; lbl.Text = txt end,
        get = function() return current end,
    }

    pcall(function()
        btn.Destroying:Connect(function()
            if openVeil or openFrame or openFollow then api.close() end
            local list = _G.__DeltaUI_dropdowns
            if list then
                for i = #list, 1, -1 do
                    if list[i] == api then table.remove(list, i) break end
                end
            end
        end)
    end)

    btn.MouseButton1Click:Connect(function()
        if openFrame then api.close() return end
        for _, dd in ipairs(_G.__DeltaUI_dropdowns or {}) do
            if dd ~= api and dd.close then pcall(dd.close) end
        end
        local options = {}
        pcall(function() options = getOptions() or {} end)
        if #options == 0 then
            ShowNotification("先添加「定义变量」积木", 1)
            return
        end
        local sg = btn:FindFirstAncestorOfClass("ScreenGui")
        if not sg then return end
        local itemH = 28
        local veil = create("TextButton", {
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            BorderSizePixel = 0,
            AutoButtonColor = false,
            ZIndex = 998,
        })
        veil.Parent = sg
        local list = create("Frame", {
            BackgroundColor3 = theme.surfaceLight,
            BackgroundTransparency = 0.05,
            BorderSizePixel = 0,
            ZIndex = 999,
            Size = UDim2.fromOffset(btn.AbsoluteSize.X, #options * itemH + 8),
        })
        corner(8, list)
        stroke(theme.border, 1, list)
        list.Parent = sg
        local below = btn.AbsolutePosition.Y + btn.AbsoluteSize.Y + 4
        local sgH = 720
        pcall(function()
            if sg.AbsoluteSize.Y > 0 then sgH = sg.AbsoluteSize.Y end
        end)
        if sgH - below < list.AbsoluteSize.Y + 8 then
            below = math.max(8, btn.AbsolutePosition.Y - list.AbsoluteSize.Y - 4)
        end
        local function follow()
            if not (list and list.Parent and btn and btn.Parent) then api.close() return end
            list.Size = UDim2.fromOffset(btn.AbsoluteSize.X, #options * itemH + 8)
            list.Position = UDim2.fromOffset(btn.AbsolutePosition.X, below)
        end
        follow()
        openFollow = svc.RunService.RenderStepped:Connect(follow)
        for i, opt in ipairs(options) do
            local row = create("TextButton", {
                Position = UDim2.new(0, 4, 0, 4 + (i - 1) * itemH),
                Size = UDim2.new(1, -8, 0, itemH),
                BackgroundTransparency = 1,
                Text = "",
                AutoButtonColor = false,
                ZIndex = 1000,
            })
            corner(6, row)
            create("TextLabel", {
                Position = UDim2.new(0, 6, 0, 0),
                Size = UDim2.new(1, -12, 1, 0),
                BackgroundTransparency = 1,
                Text = opt,
                TextColor3 = (opt == current) and theme.accent or theme.text,
                TextSize = 12,
                Font = (opt == current) and Enum.Font.SourceSansBold or Enum.Font.SourceSans,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 1001,
                Parent = row,
            })
            row.MouseEnter:Connect(function()
                row.BackgroundColor3 = theme.accent2
                row.BackgroundTransparency = 0.8
            end)
            row.MouseLeave:Connect(function() row.BackgroundTransparency = 1 end)
            row.MouseButton1Click:Connect(function()
                current = opt
                lbl.Text = opt
                api.close()
                if onPick then pcall(onPick, opt) end
            end)
            row.Parent = list
        end
        veil.MouseButton1Click:Connect(api.close)
        openFrame = list
        openVeil = veil

        pcall(function()
            if not _G.__DeltaUI_codingDDVeils then _G.__DeltaUI_codingDDVeils = {} end
            table.insert(_G.__DeltaUI_codingDDVeils, veil)
        end)
        CODING_DROPDOWN_OPEN = CODING_DROPDOWN_OPEN + 1
    end)

    if not _G.__DeltaUI_dropdowns then _G.__DeltaUI_dropdowns = {} end
    table.insert(_G.__DeltaUI_dropdowns, api)
    if b.dd then table.insert(b.dd, api) end
    codingRegTextOnly(b, lbl)
    return api
end

function codingCloseAllDropdowns()
    local list = _G.__DeltaUI_dropdowns
    if not list then return end
    for i = #list, 1, -1 do
        local dd = list[i]
        if dd and dd.close then
            pcall(dd.close)
        else
            table.remove(list, i)
        end
    end

    if #list == 0 then CODING_DROPDOWN_OPEN = 0 end
end

function codingInput(b, cell, placeholder, text, onCommit)
    local box = create("TextBox", {
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = theme.surfaceLight,
        BackgroundTransparency = 0.34,
        BorderSizePixel = 0,
        PlaceholderText = placeholder or "",
        Text = text or "",
        TextColor3 = theme.text,
        PlaceholderColor3 = theme.textDim,
        TextSize = 12,
        Font = Enum.Font.SourceSans,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        ZIndex = 12,
    })
    corner(8, box)
    stroke(theme.border, 1, box)
    box.Parent = cell
    codingRegTextOnly(b, box)
    if onCommit then
        box.FocusLost:Connect(function() pcall(onCommit, box.Text) end)
    end
    return box
end

CODING_BLOCK_W = 302
CODING_INDENT_STR = "    "
CODING_VAR_ACCENT = CODING_VAR_ACCENT or Color3.fromRGB(139, 92, 246)
CODING_VALUE_TYPES = { "数字", "文本", "布尔", "列表", "字典" }
CODING_VALUE_HINT = { ["数字"] = "写作 1、-2.5", ["文本"] = "写作 \"你好\"" }
CODING_VALUE_OPTIONS = {
    ["布尔"] = { "true", "false" },
    ["列表"] = { "{} 空列表", "{1, 2, 3}", "{\"苹果\", \"香蕉\"}", "{true, false}" },
    ["字典"] = { "{} 空字典", '{["键"] = "值"}', "{等级 = 10, 名字 = \"玩家\"}" },
}
CODING_CMP_OPS = { "等于 ==", "不等于 ~=", "大于 >", "大于等于 >=", "小于 <", "小于等于 <=" }
CODING_MATH_OPS = { "加 +", "减 -", "乘 *", "除 /", "取余 %", "幂 ^" }
CODING_LOGIC_OPS = { "并且 and", "或者 or" }
CODING_KEYS = { "E", "Q", "R", "F", "T", "Y", "U", "I", "O", "P", "A", "S", "D", "W", "Space", "Enter", "Tab", "One", "Two", "Three" }
CODING_OBJ_PROPS = { "颜色", "位置", "大小", "透明度", "名字", "是否固定", "能否碰撞" }

CODING_OBJ_PROP_EXTRA = { "CFrame", "Position", "Size", "Color", "Transparency", "Anchored",
    "CanCollide", "Material", "Name", "Rotation", "Velocity", "Text", "Value" }
CODING_PROP_MAP = {
    ["颜色"]   = { "Color", "Color3.fromRGB(%s)" },
    ["位置"]   = { "Position", "Vector3.new(%s)" },
    ["大小"]   = { "Size", "Vector3.new(%s)" },
    ["透明度"] = { "Transparency", "%s" },
    ["名字"]   = { "Name", "%q" },
    ["是否固定"] = { "Anchored", "%s" },
    ["能否碰撞"] = { "CanCollide", "%s" },
}

CODING_CARD_ENTRIES = {
    ["变量类"]     = { "defineVar", "setVar", "bumpVar", "getVar" },
    ["Function类"] = { "defFunc", "callFunc", "retVal" },
    ["物体类"]     = { "spawnPart", "setProp", "delObj", "objVisible", "findObj", "objClick" },
    ["流程控制"]   = { "printMsg", "announce", "waitSec", "loopTimes", "loopEach", "condIf", "loopWhile" },
    ["逻辑运算"]   = { "opCompare", "opMath", "opLogic", "opConcat", "opLen", "opRandom", "opColor", "opTime", "opPlayers" },
    ["事件输入"]   = { "evtKey", "evtChat", "evtJoin", "playSound" },
}

CODING_CAT_ACCENTS = {
    ["变量类"]     = CODING_VAR_ACCENT,
    ["Function类"] = theme.accent,
    ["物体类"]     = theme.green,
    ["流程控制"]   = Color3.fromRGB(255, 196, 66),
    ["逻辑运算"]   = Color3.fromRGB(244, 114, 182),
    ["事件输入"]   = Color3.fromRGB(45, 212, 191),
}

function codingTrim(v)
    return tostring(v == nil and "" or v):gsub("^%s+", ""):gsub("%s+$", "")
end

function codingToString(v)
    if v == nil then return "" end
    return tostring(v)
end

function codingLocalName(v, fallback)
    local raw = codingTrim(v)
    local out = {}
    for i = 1, #raw do
        local byte = string.byte(raw, i)
        local ch = raw:sub(i, i)
        if byte >= 128 or ch:match("%w") or ch == "_" then
            table.insert(out, ch)
        end
    end
    local s = table.concat(out)
    if s:match("^%d") then s = "_" .. s end
    if s == "" then return fallback or "变量" end
    return s
end

function codingNumOr(v, default)
    local n = tonumber(tostring(v == nil and "" or v))
    if n == nil then return tostring(default or 0) end
    return tostring(n)
end

function codingNumListText(v, fallback)
    local s = codingTrim(v):gsub("%s+", "")
    if s == "" then return fallback or "" end
    for seg in s:gmatch("[^,]+") do
        if not tonumber(seg) then return fallback or "" end
    end
    return (s:gsub(",", ", "))
end

function codingOpSym(text)
    local s = codingTrim(text)
    if s:find("不等于") then return "~=" elseif s:find("大于等于") then return ">=" elseif s:find("小于等于") then return "<="
        elseif s:find("等于") then return "==" elseif s:find("大于") then return ">" elseif s:find("小于") then return "<" end
    if s:find("取余") then return "%" elseif s:find("幂") then return "^" elseif s:find("乘") then return "*"
        elseif s:find("除") then return "/" elseif s:find("减") then return "-" elseif s:find("加") then return "+" end
    if s:find("或者") then return "or" elseif s:find("并且") then return "and" end
    return "=="
end

function codingValueLua(vtype, raw)
    local v = codingTrim(raw)
    if vtype == "数字" then return codingNumOr(v, 0) end
    if vtype == "布尔" then
        local low = v:lower()
        if low:find("false") or low:find("否") or low == "0" then return "false" end
        return "true"
    end
    if v:sub(1, 1) == "{" or v:sub(1, 1) == '"' or v:sub(1, 1) == "'" then return v end
    if vtype == "列表" then
        if v == "" then return "{}" end
        if v:find("^%s*{") then return v end
        local items = {}
        for seg in v:gmatch("[^,，]+") do
            local one = codingTrim(seg)
            if one ~= "" then
                if tonumber(one) or one == "true" or one == "false" or one:sub(1, 1) == '"' then
                    table.insert(items, one)
                else
                    table.insert(items, '"' .. one .. '"')
                end
            end
        end
        return "{" .. table.concat(items, ", ") .. "}"
    end
    if vtype == "字典" then
        if v:find("^%s*{") then return v end
        return v ~= "" and v or "{}"
    end

    if v == "" then return '""' end
    if v:sub(1, 1) == '"' or v:sub(1, 1) == "'" then return v end
    return '"' .. v:gsub('"', '\\"') .. '"'
end

function codingObjRef(path)
    local p = codingTrim(path)
    if p == "" then return "nil" end
    local segs = {}
    for seg in p:gmatch("[^%.]+") do table.insert(segs, codingTrim(seg)) end
    local head = table.remove(segs, 1)
    if head ~= "workspace" and head ~= "game" and head ~= "script" then
        table.insert(segs, 1, head)
        head = "workspace"
    end
    local expr = head
    for _, seg in ipairs(segs) do
        if seg ~= "" then expr = expr .. ':FindFirstChild("' .. seg:gsub('"', '\\"') .. '")' end
    end
    return expr
end

function codingBlocksOfKind(kind)
    local out = {}
    for _, blk in ipairs(codingBlocks) do
        if blk.kind == kind and blk.root and blk.root.Parent then table.insert(out, blk) end
    end
    return out
end

function codingDefinedVarNames()
    local out, seen = {}, {}
    for _, blk in ipairs(codingBlocksOfKind("defineVar")) do
        local nm = codingLocalName(blk.data.varName, "")
        if nm ~= "" and not seen[nm] then seen[nm] = true; table.insert(out, nm) end
    end
    return out
end

function codingVarOptions()
    local out = codingDefinedVarNames()
    if #out == 0 then out[1] = "还没有定义的变量" end
    return out
end

function codingFuncOptions()
    local out, seen = {}, {}
    for _, blk in ipairs(codingBlocksOfKind("defFunc")) do
        local nm = codingLocalName(blk.data.name, "")
        if nm ~= "" and not seen[nm] then seen[nm] = true; table.insert(out, nm) end
    end
    if #out == 0 then out[1] = "还没有定义的函数" end
    return out
end

function codingObjOptions()
    local out, seen = {}, {}
    local function put(txt)
        if txt and txt ~= "" and not seen[txt] then seen[txt] = true; out[#out + 1] = txt end
    end

    pcall(function()
        for _, txt in ipairs(obStoredObjTexts()) do put(txt) end
    end)
    for _, blk in ipairs(codingBlocksOfKind("spawnPart")) do
        put("workspace." .. codingLocalName(blk.data.objName, ""))
    end
    put("workspace.零件")
    return out
end

function codingBlockBySeq(seq)
    if not seq then return nil end
    for _, blk in ipairs(codingBlocks) do
        if blk.seq == seq and blk.root and blk.root.Parent then return blk end
    end
    return nil
end

function codingFindVarBlock(name)
    for _, blk in ipairs(codingBlocksOfKind("defineVar")) do
        if codingLocalName(blk.data.varName, "") == name then return blk end
    end
    return nil
end

function codingArgOptions(owner)
    local out = { "自由输入" }
    for _, src in ipairs(codingBlocks) do
        if src ~= owner and src.root and src.root.Parent and src.spec and src.spec.value then
            table.insert(out, "值积木·" .. src.spec.title .. "#" .. src.seq)
        end
    end
    for _, nm in ipairs(codingDefinedVarNames()) do
        table.insert(out, "变量·" .. nm)
    end
    return out
end

function codingArgKind(b, field)
    return b.data[field .. "Src"] or "raw"
end

function codingArgLua(b, field, depth)
    depth = depth or 0
    local kind = codingArgKind(b, field)
    if kind == "valueBlock" then
        if depth >= 6 then return "nil -- 值积木嵌套过深" end
        local src = codingBlockBySeq(b.data[field .. "Seq"])
        if src and src == b then return "nil -- 值积木引用了自己" end
        if src and src.spec and src.spec.value and src.spec.expr then
            local ok, out = pcall(src.spec.expr, src, depth + 1)
            if ok and type(out) == "string" and out ~= "" then return out end
        end
        return "nil"
    end
    if kind == "var" then
        return codingLocalName(b.data[field .. "Var"], "nil")
    end
    local raw = codingTrim(b.data[field])
    if b.data[field .. "AsNum"] then return codingNumOr(raw, b.data[field .. "Def"]) end
    if raw == "" then return b.data[field .. "Empty"] or "nil" end
    if b.data[field .. "AsText"] then
        if raw:sub(1, 1) == '"' or raw:sub(1, 1) == "'" then return raw end
        return '"' .. raw:gsub('"', '\\"') .. '"'
    end
    return raw
end

function codingArgDisplay(b, field)
    local kind = codingArgKind(b, field)
    if kind == "var" then return "变量 " .. codingLocalName(b.data[field .. "Var"], "") end
    if kind == "valueBlock" then
        local src = codingBlockBySeq(b.data[field .. "Seq"])
        if src then return "值积木 " .. src.spec.title .. "#" .. src.seq end
        return "值积木 已删除"
    end
    return codingTrim(b.data[field])
end

function codingArgSync(b, field)
    local box = b.fields and b.fields[field]
    if not (box and box.Parent) then return end
    local kind = codingArgKind(b, field)
    if kind == "raw" then
        box.Text = codingTrim(b.data[field])
        box.PlaceholderText = (b.cellPh and b.cellPh[field]) or "值 / 表达式"
        return
    end
    box.Text = codingArgDisplay(b, field)
    box.PlaceholderText = "点右侧 fx 换来源"
end

function codingApplyArgChoice(b, field, choice)
    if choice == "自由输入" then
        b.data[field .. "Src"] = "raw"
    else
        local varName = choice:match("^变量·(.+)$")
        local seqText = choice:match("^值积木·.-#(%d+)$")
        if varName then
            b.data[field .. "Src"] = "var"
            b.data[field .. "Var"] = varName
        elseif seqText then
            b.data[field .. "Src"] = "valueBlock"
            b.data[field .. "Seq"] = tonumber(seqText)
        end
    end
    codingArgSync(b, field)
    codingRefreshBlockChip(b)
end

function codingRealOption(text)
    local s = tostring(text or "")
    return s ~= "" and not s:find("还没有")
end

function codingCellDefault(b, cell)
    local d = cell.def
    if type(d) == "function" then return tostring(d(b) or "") end
    if d == nil then return "" end
    return tostring(d)
end

function codingNumListText(v, fallback)
    local s = codingTrim(v):gsub("%s+", "")
    if s == "" then return fallback or "" end
    for seg in s:gmatch("[^,]+") do
        if not tonumber(seg) then return fallback or "" end
    end
    return (s:gsub(",", ", "))
end

CODING_IF_OPS = { "为真", "等于", "不等于", "大于", "大于等于", "小于", "小于等于" }

function codingCondOf(b, field)
    local lhs = codingArgLua(b, "lhs")
    local rhsField = b.data["rhs"]
    local rhsKind = b.data["rhsSrc"] or "raw"
    if codingTrim(b.data.op):find("为真") then return lhs end
    local rhs = (rhsField == nil and rhsKind == "raw") and "nil" or codingArgLua(b, "rhs")
    return string.format("%s %s %s", lhs, codingOpSym(b.data.op), rhs)
end

function codingCellPh(cell, kind)
    if cell.ph then return cell.ph end
    if kind == "num" then return "数字" end
    if kind == "txt" then return "文本" end
    return "值 / 表达式"
end

CODING_BLOCK_SPECS = {

    defineVar = {
        title = "定义变量", cat = "变量类",
        chip = function(b) return codingLocalName(b.data.varName, "") end,
        rows = {
            { "var", { kind = "txt", field = "varName", def = function() return "var" .. (codingBlockSeq + 1) end, ph = "变量名" } },
            { "为",   { kind = "dd", field = "vtype", options = CODING_VALUE_TYPES, w = 0.5, hint = "类型", revalue = "value" } },
            { "值为", { kind = "val", field = "value" } },
        },
        stmt = function(b, emit)
            emit("local %s = %s", codingLocalName(b.data.varName, "var"), codingValueLua(b.data.vtype, b.data.value))
        end,
    },
    setVar = {
        title = "修改变量", cat = "变量类",
        chip = function(b) return codingLocalName(b.data.refName, "") end,
        rows = {
            { "变量", { kind = "var", field = "refName", w = 0.55, hint = "已定义", retype = true } },
            { "值为", { kind = "val", field = "value" } },
        },
        stmt = function(b, emit)
            local nm = codingLocalName(b.data.refName, "")
            if nm == "" then emit("-- 修改变量：没有选中变量（先放一张「定义变量」）") return end
            emit("%s = %s", nm, codingValueLua(b.data.vtype, b.data.value))
        end,
    },
    bumpVar = {
        title = "变量增减", cat = "变量类",
        chip = function(b) return codingLocalName(b.data.refName, "") end,
        rows = {
            { "变量", { kind = "var", field = "refName", w = 0.5, hint = "自增减" }, { kind = "expr", field = "step", isNum = true, w = 0.5, def = 1, ph = "步长" } },
        },
        stmt = function(b, emit)
            local nm = codingLocalName(b.data.refName, "")
            if nm == "" then emit("-- 变量增减：没有选中变量") return end
            emit("%s = %s + (%s)", nm, nm, codingArgLua(b, "step"))
        end,
    },
    getVar = {
        title = "读取变量", cat = "变量类", value = true,
        chip = function(b) return codingLocalName(b.data.refName, "") end,
        rows = { { "变量", { kind = "var", field = "refName", hint = "取它的值" } } },
        expr = function(b) return codingLocalName(b.data.refName, "nil") end,
    },

    defFunc = {
        title = "定义函数", cat = "Function类", container = true,
        chip = function(b) return codingLocalName(b.data.name, "") end,
        rows = {
            { "名字", { kind = "txt", field = "name", w = 0.46, def = function() return "func" .. (codingBlockSeq + 1) end, ph = "函数名" },
                     { kind = "txt", field = "param", w = 0.54, ph = "形参(逗号分隔)" } },
            { false, { kind = "embed", label = "函数体" } },
        },
        stmt = function(b, emit, nest)
            emit("local function %s(%s)", codingLocalName(b.data.name, "func"), codingTrim(codingToString(b.data.param)):gsub("%s+", ""))
            nest("-- 空函数体")
            emit("end")
        end,
    },
    callFunc = {
        title = "调用函数", cat = "Function类",
        chip = function(b) return codingLocalName(b.data.name, "") end,
        rows = {
            { "调用", { kind = "fn", field = "name", w = 0.5, hint = "函数" }, { kind = "txt", field = "args", w = 0.5, ph = "实参(逗号分隔)" } },
        },
        stmt = function(b, emit)
            local nm = codingLocalName(b.data.name, "")
            if nm == "" then emit("-- 调用函数：还没有「定义函数」积木") return end
            emit("%s(%s)", nm, codingTrim(codingToString(b.data.args)))
        end,
    },
    retVal = {
        title = "返回值", cat = "Function类",
        rows = { { "返回", { kind = "arg", field = "expr", ph = "值 / 表达式" } } },
        stmt = function(b, emit) emit("return %s", codingArgLua(b, "expr")) end,
    },

    spawnPart = {
        title = "创建物体", cat = "物体类",
        chip = function(b) return codingLocalName(b.data.objName, "") end,
        objectName = function(b) return "workspace." .. codingLocalName(b.data.objName, "") end,
        rows = {
            { "名称", { kind = "txt", field = "objName", w = 0.46, def = function() return "part" .. (codingBlockSeq + 1) end, ph = "物体名" },
                     { kind = "txt", field = "color", w = 0.54, ph = "颜色 255,0,0 可空" } },
            { "位置", { kind = "txt", field = "pos", def = "0, 5, 0", ph = "x, y, z" } },
        },
        stmt = function(b, emit)
            local nm = codingLocalName(b.data.objName, "part")
            local pos = codingNumListText(b.data.pos, "0, 0, 0")
            emit("local %s = Instance.new(\"Part\")", nm)
            emit("%s.Name = \"%s\"", nm, codingLocalName(b.data.objName, ""))
            emit("%s.Anchored = true", nm)
            emit("%s.Position = Vector3.new(%s)", nm, pos)
            local col = codingNumListText(b.data.color, "")
            if col ~= "" then emit("%s.Color = Color3.fromRGB(%s)", nm, col) end
            emit("%s.Parent = workspace", nm)
        end,
    },
    setProp = {
        title = "设置属性", cat = "物体类",
        chip = function(b) return tostring(b.data.prop or "") end,
        rows = {
            { "目标", { kind = "obj", field = "object", w = 0.55, hint = "物体" },
                     { kind = "dd", field = "prop", options = codingObjPropOptions, w = 0.45 } },
            { "设为", { kind = "expr", field = "expr", ph = "值 / 表达式", def = "255, 0, 0" } },
        },
        stmt = function(b, emit)
            local prop = codingTrim(codingToString(b.data.prop))
            local pm = CODING_PROP_MAP[prop]
            emit("local target = %s", codingObjRef(b.data.object))

            if pm then
                emit("if target then target.%s = %s end", pm[1], string.format(pm[2], codingArgLua(b, "expr")))
            else
                if prop == "" then prop = "Name" end
                emit("if target then target.%s = %s end", prop, codingArgLua(b, "expr"))
            end
        end,
    },
    delObj = {
        title = "删除物体", cat = "物体类",
        rows = { { "目标", { kind = "obj", field = "object", hint = "销毁" } } },
        stmt = function(b, emit)
            emit("local target = %s if target then target:Destroy() end", codingObjRef(b.data.object))
        end,
    },
    objVisible = {
        title = "显示隐藏", cat = "物体类",
        rows = {
            { "目标", { kind = "obj", field = "object", w = 0.55, hint = "物体" },
                     { kind = "dd", field = "show", options = { "显示", "隐藏" }, w = 0.45 } },
        },
        stmt = function(b, emit)
            emit("local target = %s if target then target.Transparency = %s end",
                codingObjRef(b.data.object), b.data.show == "隐藏" and "1" or "0")
        end,
    },
    findObj = {
        title = "查找物体", cat = "物体类", value = true,
        chip = function(b) return codingTrim(codingToString(b.data.path)) end,
        rows = { { "路径", { kind = "txt", field = "path", def = "workspace.零件", ph = "workspace.父.子" } } },
        expr = function(b) return codingObjRef(b.data.path) end,
    },
    objClick = {
        title = "点击物体时", cat = "物体类", container = true,
        chip = function(b) return codingTrim(codingToString(b.data.object)) end,
        rows = {
            { "物体", { kind = "obj", field = "object", ph = "要点击的物体" } },
            { false, { kind = "embed", label = "被点后" } },
        },
        stmt = function(b, emit, nest)
            emit("local clickDetector = Instance.new(\"ClickDetector\")")
            emit("local target = %s", codingObjRef(b.data.object))
            emit("if target then clickDetector.Parent = target end")
            emit("clickDetector.MouseClick:Connect(function(player)")
            nest("-- 空事件体")
            emit("end)")
        end,
    },

    printMsg = {
        title = "打印消息", cat = "流程控制",
        rows = { { "打印", { kind = "arg", field = "text", ph = "表达式 · 文本要加引号" } } },
        stmt = function(b, emit) emit("print(%s)", codingArgLua(b, "text")) end,
    },
    announce = {
        title = "屏幕提示", cat = "流程控制",
        rows = {
            { "提示", { kind = "arg", field = "text", ph = "表达式 · 文本要加引号" }, { kind = "num", field = "secs", w = 0.24, def = 3, ph = "秒" } },
        },
        stmt = function(b, emit)
            emit("do local noticeFrame = Instance.new(\"TextLabel\")")
            emit("noticeFrame.Size = UDim2.new(1, 0, 0, 40)")
            emit("noticeFrame.Position = UDim2.new(0, 0, 0.82, 0)")
            emit("noticeFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 34)")
            emit("noticeFrame.TextColor3 = Color3.fromRGB(242, 245, 252)")
            emit("noticeFrame.TextSize = 20")
            emit("noticeFrame.Text = tostring(%s)", codingArgLua(b, "text"))
            emit("noticeFrame.Parent = game:GetService(\"CoreGui\")")
            emit("game:GetService(\"Debris\"):AddItem(noticeFrame, %s)", codingNumOr(b.data.secs, 3))
            emit("end")
        end,
    },
    waitSec = {
        title = "等待", cat = "流程控制",
        rows = { { "等待", { kind = "num", field = "sec", w = 0.3, def = 1, ph = "秒" }, { kind = "raw", text = "秒后继续往下" } } },
        stmt = function(b, emit) emit("task.wait(%s)", codingNumOr(b.data.sec, 1)) end,
    },
    loopTimes = {
        title = "重复执行", cat = "流程控制", container = true,
        chip = function(b) return "×" .. codingNumOr(b.data.times, 10) end,
        rows = {
            { "重复", { kind = "num", field = "times", w = 0.24, def = 10, ph = "次数" }, { kind = "raw", text = "次 · 计数变量" },
                   { kind = "txt", field = "idx", w = 0.2, def = "i", ph = "i" } },
            { false, { kind = "embed", label = "循环体" } },
        },
        stmt = function(b, emit, nest)
            emit("for %s = 1, %s do", codingLocalName(b.data.idx, "i"), codingNumOr(b.data.times, 10))
            nest("-- 空循环体")
            emit("end")
        end,
    },
    loopEach = {
        title = "遍历列表", cat = "流程控制", container = true,
        rows = {
            { "列表", { kind = "arg", field = "list", ph = "列表 / 变量" }, { kind = "txt", field = "iter", w = 0.24, def = "项", ph = "迭代变量" } },
            { false, { kind = "embed", label = "每一项" } },
        },
        stmt = function(b, emit, nest)
            emit("for _, %s in ipairs(%s) do", codingLocalName(b.data.iter, "item"), codingArgLua(b, "list"))
            nest("-- 空循环体")
            emit("end")
        end,
    },
    condIf = {
        title = "如果", cat = "流程控制", container = true,

        chip = function(b)
            local op = codingTrim(codingToString(b.data.op))
            if op:find("为真") then return "为真" end
            return codingOpSym(op)
        end,
        rows = {

            { "如果", { kind = "arg", field = "lhs", def = "true", ph = "值" },
                    { kind = "dd", field = "op", options = CODING_IF_OPS, w = 0.28 },
                    { kind = "arg", field = "rhs", ph = "比较值" } },
            { false, { kind = "embed", label = "成立时执行" } },
        },
        stmt = function(b, emit, nest)
            emit("if %s then", codingCondOf(b))
            nest("-- 成立时执行 · 点「嵌入」放子积木")
            emit("end")
        end,
    },
    loopWhile = {
        title = "当循环", cat = "流程控制", container = true,
        rows = {
            { "当",   { kind = "expr", field = "lhs", def = "true", ph = "值 / 表达式" } },
            { "每次", { kind = "num", field = "gap", w = 0.26, def = 0.1, ph = "秒" }, { kind = "raw", text = "秒后重新判断" } },
            { false,    { kind = "embed", label = "循环体" } },
        },
        stmt = function(b, emit, nest)
            emit("task.spawn(function() while %s do", codingArgLua(b, "lhs"))
            nest("-- 空循环体")
            emit("    task.wait(%s)", codingNumOr(b.data.gap, 0))
            emit("end end)")
        end,
    },

    opCompare = {
        title = "比较", cat = "逻辑运算", value = true,
        rows = {
            { "左侧", { kind = "arg", field = "lhs", isNum = true, def = 1 },
                    { kind = "dd", field = "op", options = CODING_CMP_OPS, w = 0.38 } },
            { "右侧", { kind = "arg", field = "rhs", isNum = true, def = 1 } },
        },
        expr = function(b)
            return string.format("(%s %s %s)", codingArgLua(b, "lhs"), codingOpSym(b.data.op), codingArgLua(b, "rhs"))
        end,
    },
    opMath = {
        title = "数学运算", cat = "逻辑运算", value = true,
        rows = {
            { "数值", { kind = "arg", field = "lhs", isNum = true, def = 1 },
                    { kind = "dd", field = "op", options = CODING_MATH_OPS, w = 0.38 } },
            { "另一", { kind = "arg", field = "rhs", isNum = true, def = 1 } },
        },
        expr = function(b)
            return string.format("(%s %s %s)", codingArgLua(b, "lhs"), codingOpSym(b.data.op), codingArgLua(b, "rhs"))
        end,
    },
    opLogic = {
        title = "逻辑组合", cat = "逻辑运算", value = true,
        rows = {
            { "左条件", { kind = "expr", field = "lhs", def = "true", ph = "值 / 表达式" },
                      { kind = "dd", field = "op", options = { "并且 and", "或者 or" }, w = 0.38 } },
            { "右条件", { kind = "arg", field = "rhs", def = "true" } },
        },
        expr = function(b)
            return string.format("(%s %s %s)", codingArgLua(b, "lhs"), codingOpSym(b.data.op), codingArgLua(b, "rhs"))
        end,
    },
    opConcat = {
        title = "文本拼接", cat = "逻辑运算", value = true,
        rows = {
            { "前段", { kind = "arg", field = "lhs", isText = true, def = "你好" } },
            { "后段", { kind = "arg", field = "rhs", isText = true, def = "世界" } },
        },
        expr = function(b)
            return string.format("tostring(%s) .. tostring(%s)", codingArgLua(b, "lhs"), codingArgLua(b, "rhs"))
        end,
    },
    opLen = {
        title = "取长度", cat = "逻辑运算", value = true,
        rows = { { "对象", { kind = "arg", field = "expr", ph = "文本 / 列表变量" } } },
        expr = function(b) return "#tostring(" .. codingArgLua(b, "expr") .. ")" end,
    },
    opRandom = {
        title = "随机数", cat = "逻辑运算", value = true,
        rows = {
            { "范围", { kind = "num", field = "lo", w = 0.24, def = 1, ph = "最小" }, { kind = "raw", text = "到" },
                   { kind = "num", field = "hi", w = 0.24, def = 10, ph = "最大" } },
        },
        expr = function(b)
            return string.format("math.random(%s, %s)", codingNumOr(b.data.lo, 1), codingNumOr(b.data.hi, 10))
        end,
    },
    opColor = {
        title = "随机颜色", cat = "逻辑运算", value = true,
        expr = function() return "Color3.fromRGB(math.random(0,255), math.random(0,255), math.random(0,255))" end,
    },
    opTime = {
        title = "运行秒数", cat = "逻辑运算", value = true,
        expr = function() return "os.clock()" end,
    },
    opPlayers = {
        title = "玩家人数", cat = "逻辑运算", value = true,
        expr = function() return "#game:GetService(\"Players\"):GetPlayers()" end,
    },

    evtKey = {
        title = "按键时执行", cat = "事件输入", container = true,
        chip = function(b) return codingTrim(codingToString(b.data.key)) end,
        rows = {
            { "按下", { kind = "dd", field = "key", options = CODING_KEYS, w = 0.34 },
                    { kind = "dd", field = "once", options = { "只一次", "每次" }, w = 0.3, hint = "触发次数" } },
            { false, { kind = "embed", label = "按下后" } },
        },
        stmt = function(b, emit, nest)
            local flag = "已触发" .. tostring(b.seq)
            emit("local %s = false", flag)
            emit("game:GetService(\"UserInputService\").InputBegan:Connect(function(input, gameProcessed)")
            emit("    if gameProcessed then return end")
            emit("    if input.KeyCode ~= Enum.KeyCode.%s then return end", codingTrim(codingToString(b.data.key)))
            if b.data.once ~= "每次" then
                emit("    if %s then return end", flag)
                emit("    %s = true", flag)
            end
            nest("    -- 空事件体")
            emit("end)")
        end,
    },
    evtChat = {
        title = "收到消息时", cat = "事件输入", container = true,
        rows = {
            { "内容", { kind = "txt", field = "text", ph = "只要这些字 · 留空=任意消息" } },
            { false, { kind = "embed", label = "收到后" } },
        },
        stmt = function(b, emit, nest)
            local want = codingTrim(codingToString(b.data.text))
            emit("game:GetService(\"Players\").PlayerAdded:Connect(function(player)")
            emit("    player.Chatted:Connect(function(message)")
            if want ~= "" then emit("        if message ~= %q then return end", want) end
            nest("        -- 空事件体")
            emit("    end)")
            emit("end)")
        end,
    },
    evtJoin = {
        title = "玩家进入时", cat = "事件输入", container = true,
        rows = {
            { "参数", { kind = "txt", field = "pname", w = 0.34, def = "玩家", ph = "参数名" } },
            { false, { kind = "embed", label = "进入后" } },
        },
        stmt = function(b, emit, nest)
            emit("game:GetService(\"Players\").PlayerAdded:Connect(function(%s)", codingLocalName(b.data.pname, "player"))
            nest("    -- 空事件体")
            emit("end)")
        end,
    },
    playSound = {
        title = "播放音效", cat = "事件输入",
        rows = {
            { "音效", { kind = "num", field = "id", w = 0.3, ph = "asset id" },
                    { kind = "num", field = "pitch", w = 0.22, def = 1, ph = "音调" }, { kind = "raw", text = "倍速" } },
        },
        stmt = function(b, emit)
            local id = codingTrim(codingToString(b.data.id))
            if not tonumber(id) then emit("-- 播放sound：填一个 rbxassetid 数字") return end
            emit("local sound = Instance.new(\"Sound\")")
            emit("sound.SoundId = \"rbxassetid://%s\"", id)
            emit("sound.PlaybackSpeed = %s", codingNumOr(b.data.pitch, 1))
            emit("sound.Parent = game:GetService(\"Workspace\")")
            emit("sound:Play()")
        end,
    },
}

CODING_BLOCK_ROW_H = 30
CODING_BLOCK_LABEL_W = 44
CODING_CELL_GAP = 4

codingBaseCache = setmetatable({}, {__mode = "k"})
local function setBase(host, x, y, w)
	codingBaseCache[host] = {x = x, y = y, w = w}
end
local function getBase(host)
	return codingBaseCache[host] or {x = 0, y = 0, w = 0}
end

function codingBlockHeight(b)
    return 40 + #(b.spec.rows or {}) * 36
end

function codingSubCell(host, xScale, wScale)
    local cell = create("Frame", {
        Position = UDim2.new(xScale, 0, 0, 0),
        Size = UDim2.new(wScale, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 11,
        Parent = host,
    })
    return cell
end

function codingValueEditor(b, host, field, vtypeField)
    if not (host and host.Parent) then return end
    for _, c in ipairs(host:GetChildren()) do pcall(function() c:Destroy() end) end
    codingPruneBlock(b)
    if type(b.data[field]) ~= "string" then b.data[field] = "" end
    local vt = b.data[vtypeField] or "数字"
    local opts = CODING_VALUE_OPTIONS[vt]
    if not opts then
        b.fields[field] = codingInput(b, host, CODING_VALUE_HINT[vt] or "输入值", b.data[field], function(v)
            b.data[field] = v
        end)
        return
    end
    local keep = false
    for _, o in ipairs(opts) do if o == b.data[field] then keep = true end end
    if not keep then b.data[field] = opts[1] end
    b.fields[field] = codingDropdown(b, host, function()
        return CODING_VALUE_OPTIONS[b.data[vtypeField]] or opts
    end, b.data[field], function(v)
        b.data[field] = v
    end)
end

function codingRenderValueField(b, field)
    for _, slot in ipairs(b.valSlots or {}) do
        if slot.field == field then
            codingValueEditor(b, slot.host, field, slot.vt or "vtype")
            return
        end
    end
end

function codingRefreshValueFields(b)
    for _, slot in ipairs(b.valSlots or {}) do
        codingValueEditor(b, slot.host, slot.field, slot.vt or "vtype")
    end
    if b.bodyBlock then codingRefreshValueFields(b.bodyBlock) end
end

function codingRenderBlockRow(b, index, row)
    local y = 36 + (index - 1) * 36
    local label = row[1]
    local startX, rowW = 12, b.w - 24
    if label ~= nil and label ~= "" and label ~= false then
        local lab = create("TextLabel", {
            BackgroundTransparency = 1,
            Text = label,
            TextColor3 = theme.textDim,
            TextSize = 12,
            Font = Enum.Font.SourceSansBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 10,
            Parent = b.root,
        })
        codingReg(b, lab, UDim2.fromOffset(10, y), UDim2.fromOffset(CODING_BLOCK_LABEL_W, CODING_BLOCK_ROW_H))
        startX = 10 + CODING_BLOCK_LABEL_W + 8
        rowW = b.w - startX - 12
    end
    local cells = {}
    for ci = 2, #row do table.insert(cells, row[ci]) end
    local usedFrac, flexCount = 0, 0
    for _, c in ipairs(cells) do
        if c.kind ~= "raw" then
            if c.w then usedFrac = usedFrac + c.w else flexCount = flexCount + 1 end
        end
    end
    local flexFrac = flexCount > 0 and math.max(0.1, (1 - usedFrac - (CODING_CELL_GAP * #cells) / rowW) / flexCount) or 0
    local cursor = 0
    for _, cell in ipairs(cells) do
        local frac = cell.w
        if not frac then
            frac = (cell.kind == "raw") and 0.24 or flexFrac
        end
        local cw = math.floor(rowW * frac + 0.5)
        local host = create("Frame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 10,
            Parent = b.root,
        })
        codingReg(b, host, UDim2.fromOffset(startX + cursor, y), UDim2.fromOffset(cw, CODING_BLOCK_ROW_H))

        setBase(host, startX + cursor, y, cw)
        codingBuildBlockCell(b, host, cell)
        cursor = cursor + cw + CODING_CELL_GAP
    end
end

function codingBuildBlockCell(b, host, cell)
    local kind, field = cell.kind, cell.field
    b.fields = b.fields or {}

    if kind == "raw" then
        create("TextLabel", {
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = cell.text or "",
            TextColor3 = theme.textDim,
            TextSize = 10,
            Font = Enum.Font.SourceSans,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 11,
            Parent = host,
        })
        return
    end

    if kind == "txt" or kind == "num" then
        if b.data[field] == nil then b.data[field] = codingCellDefault(b, cell) end
        b.cellPh = b.cellPh or {}
        b.cellPh[field] = cell.ph or (kind == "num" and "数字" or "文本")
        if kind == "num" then
            b.data[field .. "AsNum"] = true
            b.data[field .. "Def"] = cell.def
        end
        b.fields[field] = codingInput(b, host, b.cellPh[field], tostring(b.data[field]), function(v)
            b.data[field] = v
            codingRefreshBlockChip(b)
        end)
        return
    end

    if kind == "val" then
        local vt = cell.vt or "vtype"
        if b.data[vt] == nil then b.data[vt] = "数字" end
        if b.data[field] == nil then b.data[field] = "" end
        b.valSlots = b.valSlots or {}
        table.insert(b.valSlots, { host = host, field = field, vt = vt })
        codingValueEditor(b, host, field, vt)
        return
    end

    if kind == "dd" or kind == "var" or kind == "fn" or kind == "obj" then
        local providers = { var = codingVarOptions, fn = codingFuncOptions, obj = codingObjOptions }
        local provider = providers[kind]
        if not provider then
            if type(cell.options) == "function" then
                provider = cell.options
            else
                provider = function() return cell.options or {} end
            end
        end
        local list = provider()
        if b.data[field] == nil or b.data[field] == "" then
            b.data[field] = codingRealOption(list[1]) and list[1] or ""
        end
        local ddFrac = cell.ddw or (cell.hint and 0.55 or 1)
        local ddHost = host
        if ddFrac < 1 then
            ddHost = codingSubCell(host, 0, ddFrac)
            local hint = create("TextLabel", {
                Position = UDim2.new(ddFrac, 0, 0, 0),
                Size = UDim2.new(1 - ddFrac, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = cell.hint,
                TextColor3 = theme.textDim,
                TextSize = 10,
                Font = Enum.Font.SourceSans,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 11,
                Parent = host,
            })
            codingReg(b, hint, nil, nil)
        end
        b.fields[field] = codingDropdown(b, ddHost, provider, (b.data[field] ~= "" and b.data[field]) or (list[1] or ""), function(val)
            if not codingRealOption(val) then
                ShowNotification("现在还没有可选项：先放对应的积木卡", 2)
                return
            end
            b.data[field] = val

            if kind == "var" then
                local src = codingFindVarBlock(val)
                b.data.vtype = (src and src.data.vtype) or b.data.vtype or "数字"
                codingRefreshValueFields(b)
            end
            if cell.revalue then codingRefreshValueFields(b) end
            codingRefreshBlockChip(b)
            codingRefreshRefBoxes(b)
        end)
        return
    end

    if kind == "arg" then
        if b.data[field] == nil then b.data[field] = codingCellDefault(b, cell) end
        b.data[field .. "Src"] = b.data[field .. "Src"] or "raw"
        if cell.isNum then
            b.data[field .. "AsNum"] = true
            b.data[field .. "Def"] = cell.def
        end
        if cell.isText then b.data[field .. "AsText"] = true end
        b.fields[field] = codingInput(b, codingSubCell(host, 0, 0.7), cell.ph or "值 / 表达式", codingArgDisplay(b, field), function(v)
            if codingArgKind(b, field) == "raw" then b.data[field] = v end
        end)
        b.fields[field .. "Menu"] = codingDropdown(b, codingSubCell(host, 0.73, 0.27), function()
            return codingArgOptions(b)
        end, "fx", function(choice)
            codingApplyArgChoice(b, field, choice)
            codingRefreshBlockChip(b)
        end)
        codingArgSync(b, field)
        return
    end

    if kind == "embed" then
        b.isContainer = true
        local slot = create("Frame", {
            BackgroundColor3 = theme.surfaceLight,
            BackgroundTransparency = 0.62,
            BorderSizePixel = 0,
            ZIndex = 11,
            Parent = host,
        })
        corner(7, slot)
        stroke(theme.border, 1, slot)
        b.slotLabel = create("TextLabel", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 9, 0.5, 0),
            Size = UDim2.new(0.34, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = cell.label or "嵌入",
            TextColor3 = theme.textDim,
            TextSize = 11,
            Font = Enum.Font.SourceSansBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 12,
            Parent = slot,
        })
        b.slotState = create("TextLabel", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0.36, 0, 0.5, 0),
            Size = UDim2.new(0.3, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "空",
            TextColor3 = theme.textDim,
            TextSize = 10,
            Font = Enum.Font.SourceSans,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 12,
            Parent = slot,
        })
        b.slotBtn = create("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -6, 0.5, 0),
            Size = UDim2.fromOffset(58, 20),
            BackgroundColor3 = CODING_CAT_ACCENTS[b.spec.cat] or CODING_VAR_ACCENT,
            BackgroundTransparency = 0.3,
            BorderSizePixel = 0,
            Text = "嵌入",
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextSize = 11,
            Font = Enum.Font.SourceSansBold,
            AutoButtonColor = false,
            ZIndex = 13,
            Parent = slot,
        })
        corner(6, b.slotBtn)
        b.slotBtn.MouseButton1Click:Connect(function()
            if b.bodyBlock then codingDetachBody(b.bodyBlock) else codingOpenEmbedPicker(b) end
        end)
        codingReg(b, slot, UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0))
        b.slotBox = slot
        local hb = getBase(host)
        b.slotRelX = hb.x + hb.w * 0.5 - b.w * 0.5
        b.slotRelY = hb.y + CODING_BLOCK_ROW_H * 0.5 - b.h * 0.5
        codingUpdateSlotState(b)
        return
    end
end

function codingUpdateSlotState(b)
    pcall(function()
        if not (b.slotState and b.slotState.Parent) then return end
        if b.bodyBlock then
            b.slotState.Text = "已嵌「" .. tostring(b.bodyBlock.spec.title) .. "」"
            if b.slotBtn then b.slotBtn.Text = "取出" end
        else
            b.slotState.Text = "空"
            if b.slotBtn then b.slotBtn.Text = "嵌入" end
        end
    end)
end

function codingReferrersOf(target)
    local out = {}
    for _, b in ipairs(codingBlocks) do
        if b ~= target and b.root and b.root.Parent then
            for field, _ in pairs(b.data) do
                local base = field:match("^(.-)Src$")
                if base and codingArgKind(b, base) ~= "raw" then
                    local hit = false
                    if b.data[base .. "Seq"] == target.seq then hit = true end
                    if b.data[base .. "Var"] ~= nil and codingLocalName(b.data[base .. "Var"], "") == codingLocalName(target.data.varName, "\0") then hit = true end
                    if hit then
                        local dup = false
                        for _, have in ipairs(out) do if have == b then dup = true end end
                        if not dup then table.insert(out, b) end
                    end
                end
            end
            if b.parentBlock == target then table.insert(out, b) end
        end
    end
    return out
end

function codingRefreshRefBoxes(src)
    for _, b in ipairs(codingBlocks) do
        if b ~= src and b.root and b.root.Parent then
            for field, _ in pairs(b.data) do
                local base = field:match("^(.-)Src$")
                if base and b.fields and b.fields[base] then
                    codingArgSync(b, base)
                end
            end
        end
    end
end

function codingCreateBlock(kind)
    local spec = CODING_BLOCK_SPECS[kind]
    if not spec then return nil end
    codingBlockSeq = codingBlockSeq + 1
    local b = {
        kind = kind,
        spec = spec,
        eles = {},
        data = {},
        fields = {},
        valSlots = {},
        dd = {},
        w = CODING_BLOCK_W,
        x = 0,
        y = 0,
        seq = codingBlockSeq,
    }
    b.h = codingBlockHeight(b)
    codingInitBlockData(b)
    codingMakeBlockShell(b, spec.title, CODING_CAT_ACCENTS[spec.cat])
    for ri, row in ipairs(spec.rows or {}) do
        codingRenderBlockRow(b, ri, row)
    end
    codingRefreshBlockChip(b)

    local areaW, areaH = 520, 420
    pcall(function()
        local asz = codingGridArea.AbsoluteSize
        if asz.X > 0 and asz.Y > 0 then areaW, areaH = asz.X, asz.Y end
    end)
    local step = (codingBlockSeq - 1) % 6
    b.x = -areaW * 0.5 + b.w * 0.5 + 18 + step * 22
    b.y = -areaH * 0.5 + b.h * 0.5 + 18 + step * 22
    b.root.Parent = codingCanvas
    table.insert(codingBlocks, b)
    codingApplyView()
    pcall(function()
        b.root.BackgroundTransparency = 1
        svc.TweenService:Create(b.root, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0.06,
        }):Play()
    end)
    return b
end

function codingInitBlockData(b)
    local spec = b.spec
    for _, row in ipairs(spec.rows or {}) do
        for ci = 2, #row do
            local cell = row[ci]
            if cell.field and b.data[cell.field] == nil then
                b.data[cell.field] = codingCellDefault(b, cell)
            end
        end
    end
    if b.spec.value then b.data.vtype = b.data.vtype or "数字" end
end

function codingRemoveBlock(b)
    if not (b and b.root) then return end
    local refs = codingReferrersOf(b)

    if b.dd then
        for _, dd in ipairs(b.dd) do
            if dd and dd.close then pcall(dd.close) end
        end
        b.dd = nil
    end
    if b.bodyBlock then codingDetachBody(b.bodyBlock) end
    for i, blk in ipairs(codingBlocks) do
        if blk == b then table.remove(codingBlocks, i) break end
    end
    codingDetachBody(b)
    pcall(function() b.root:Destroy() end)
    codingApplyView()
    for _, host in ipairs(refs) do
        for field, _ in pairs(host.data) do
            local base = field:match("^(.-)Src$")
            if base and host.data[base .. "Seq"] == b.seq then
                host.data[base .. "Src"] = "raw"
                host.data[base .. "Seq"] = nil
            end
        end
        codingRefreshRefBoxes(b)
        codingRefreshBlockChip(host)
    end
    if #refs > 0 then
        ShowNotification("已移除「" .. tostring(b.spec.title) .. "」，" .. #refs .. " 处引用已退回自由输入", 3)
    else
        ShowNotification("已移除积木：" .. tostring(b.spec.title), 1)
    end
    codingApplyView()
end

function codingIsInChain(node, target)
    local guard = 0
    local cur = node
    while cur and guard < 80 do
        if cur == target then return true end
        cur = cur.parentBlock
        guard = guard + 1
    end
    return false
end

function codingAttachBody(host, child)
    if not (host and child) or host == child then return false end
    if not host.isContainer then
        ShowNotification("「" .. host.spec.title .. "」没有嵌入槽", 2)
        return false
    end
    if child.spec.value then
        ShowNotification("「" .. child.spec.title .. "」是值积木，请用参数右侧的 fx 引用", 3)
        return false
    end
    if codingIsInChain(host, child) then
        ShowNotification("不能嵌进自己的子积木里", 2)
        return false
    end
    if child.parentBlock then codingDetachBody(child) end
    if host.bodyBlock and host.bodyBlock ~= child then
        codingDetachBody(host.bodyBlock)
    end
    host.bodyBlock = child
    child.parentBlock = host
    child.attached = true
    if child.root and child.root.Parent then child.root.ZIndex = 9 end
    codingUpdateSlotState(host)
    codingApplyView()
    ShowNotification("已嵌入「" .. child.spec.title .. "」", 1)
    return true
end

function codingDetachBody(child)
    if not child then return false end

    local parent = child.parentBlock
    if not parent then return false end
    child.parentBlock = nil
    child.attached = nil
    if parent.bodyBlock == child then parent.bodyBlock = nil end
    codingUpdateSlotState(parent)
    if child.root and child.root.Parent then child.root.ZIndex = 8 end
    codingApplyView()
    return true
end

function codingOpenEmbedPicker(host)
    local opts = {}
    for _, blk in ipairs(codingBlocks) do
        if blk ~= host and blk.root and blk.root.Parent and not blk.parentBlock and not blk.spec.value then
            table.insert(opts, blk.spec.title .. " #" .. blk.seq)
        end
    end
    if #opts == 0 then
        ShowNotification("预览框里没有可嵌入的积木", 2)
        return
    end
    if host.pickerCell and host.pickerCell.Parent then host.pickerCell:Destroy() end
    local cell = codingSubCell(host.slotBox or host.root, 0.36, 0.34)
    host.pickerCell = cell
    local stub = { eles = {}, dd = {}, fields = {}, data = {}, root = host.root, spec = host.spec, seq = -1 }
    codingDropdown(stub, cell, function()
        local fresh = {}
        for _, blk in ipairs(codingBlocks) do
            if blk ~= host and blk.root and blk.root.Parent and not blk.parentBlock and not blk.spec.value then
                table.insert(fresh, blk.spec.title .. " #" .. blk.seq)
            end
        end
        return fresh
    end, "选择积木", function(choice)
        local seq = tonumber(choice:match("#(%d+)$"))
        local blk = codingBlockBySeq(seq)
        if cell and cell.Parent then cell:Destroy() end
        host.pickerCell = nil
        if blk then codingAttachBody(host, blk) end
    end)
    return cell
end

function codingMakeBlockShell(b, title, accent)
    b.root = create("Frame", {
        BackgroundColor3 = theme.surface,
        BackgroundTransparency = 0.06,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true,
        ZIndex = 8,
    })
    corner(12, b.root)
    stroke(accent, 1, b.root)

    b.header = create("TextButton", {
        BackgroundColor3 = accent,
        BackgroundTransparency = 0.78,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 9,
        Parent = b.root,
    })

    corner(12, b.header)
    b.header.ClipsDescendants = true
    local headTitle = create("TextLabel", {
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -74, 1, 0),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 12,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 10,
        Parent = b.header,
    })
    b.chip = create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -34, 0.5, 0),
        Size = UDim2.new(0, 68, 0, 16),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = accent,
        TextSize = 11,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 10,
        Parent = b.header,
    })
    b.delBtn = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.new(0, 20, 0, 20),
        BackgroundColor3 = theme.surfaceLight,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 11,
        Parent = b.header,
    })
    corner(6, b.delBtn)
    local delIcon = GetIcon("x", UDim2.new(0, 11, 0, 11), Color3.fromRGB(214, 218, 230))
    if delIcon then
        delIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        delIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
        delIcon.ZIndex = 12
        delIcon.Parent = b.delBtn
    end
    b.delBtn.MouseEnter:Connect(function()
        if b.delBtn then
            b.delBtn.BackgroundColor3 = theme.red
            b.delBtn.BackgroundTransparency = 0.15
        end
    end)
    b.delBtn.MouseLeave:Connect(function()
        if b.delBtn then
            b.delBtn.BackgroundColor3 = theme.surfaceLight
            b.delBtn.BackgroundTransparency = 0.4
        end
    end)
    b.delBtn.MouseButton1Click:Connect(function()
        codingRemoveBlock(b)
    end)

    codingReg(b, b.header, UDim2.new(0, 0, 0, 0), UDim2.fromOffset(b.w, 28))
    codingReg(b, headTitle, nil, nil)
    codingReg(b, b.chip, nil, nil)

    codingReg(b, b.delBtn, nil, nil)
    if delIcon then codingReg(b, delIcon, nil, nil) end

    local headDrag = false
    b.header.InputBegan:Connect(function(inp)
        if headDrag then return end
        if not codingIsMouseTouch(inp) or not codingCanvasUsable() then return end

        if codingBlockHasFocusedInput(b) then return end

        if inp.UserInputType ~= Enum.UserInputType.Touch then
            codingPinchActive = false
        end

        if codingPinchActive then return end
        local dp, dsz = b.delBtn.AbsolutePosition, b.delBtn.AbsoluteSize
        if inp.Position.X >= dp.X and inp.Position.X <= dp.X + dsz.X
            and inp.Position.Y >= dp.Y and inp.Position.Y <= dp.Y + dsz.Y then
            return
        end
        headDrag = true
        b.root.ZIndex = 16
        codingDetachBody(b)

        local originX, originY = b.x, b.y
        codingBeginDragObjMove(function(dx, dy)
            b.x = originX + dx / codingView.z
            b.y = originY + dy / codingView.z
            codingApplyBlock(b)
        end, function()
            headDrag = false
            if b.root and b.root.Parent then b.root.ZIndex = 8 end
            codingApplyView()
        end, inp)
    end)

    if b.root then
        b.root.InputBegan:Connect(function(inp)
            if inp.UserInputType ~= Enum.UserInputType.MouseButton2 then return end
            if not codingCanvasUsable() then return end
            if b.parentBlock then
                codingDetachBody(b)
                ShowNotification("已拿出「" .. tostring(b.spec.title) .. "」", 1)
            elseif b.bodyBlock then
                codingDetachBody(b.bodyBlock)
                ShowNotification("已取出子积木", 1)
            end
        end)
        b.root.Active = true
    end
end

function codingRefreshBlockChip(b)
    pcall(function()
        if not (b and b.chip and b.chip.Parent and b.spec and b.spec.chip) then return end
        b.chip.Text = b.spec.chip(b) or ""
    end)
end

function codingAddBlockToPreview(kind)
    local b = codingCreateBlock(kind)
    if not b then return nil end
    ShowNotification("已添加到预览框", 1)
    if b.spec.cat and codingEntriesCard and codingCardEntryList(codingEntriesCard) then
        codingScrollEntriesToBottom()
    end
    return b
end

if codingCanvas then
    pcall(function() codingCanvas.Active = false end)
end

codingPanCatcher = create("TextButton", {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 3,
})
codingPanCatcher.Name = "codingPanCatcher"
codingPanCatcher.Parent = codingGridArea

function codingApplyBlockGeom(b)
    local z = codingView.z

    local function rp(v) return math.floor(v + 0.5) end
    b.root.Position = UDim2.new(0.5, rp(codingView.panX + b.x * z), 0.5, rp(codingView.panY + b.y * z))
    b.root.Size = UDim2.fromOffset(rp(b.w * z), rp(b.h * z))
    for _, e in ipairs(b.eles) do
        local o = e.o
        if o and o.Parent then

            if e.pos then
                o.Position = UDim2.new(e.pos.X.Scale, rp(e.pos.X.Offset * z), e.pos.Y.Scale, rp(e.pos.Y.Offset * z))
            end
            if e.size then
                o.Size = UDim2.new(e.size.X.Scale, rp(e.size.X.Offset * z), e.size.Y.Scale, rp(e.size.Y.Offset * z))
            end
            if e.ts then

                pcall(function() o.TextSize = math.max(4, math.floor(e.ts * z * 4) / 4) end)
            end
        end
    end
end

function codingApplyBlock(b, depth)
    if not (b and b.root and b.root.Parent) then return end
    codingApplyBlockGeom(b)

    depth = depth or 0
    if b.bodyBlock and b.bodyBlock.root and b.bodyBlock.root.Parent and depth < 24 then
        local c = b.bodyBlock
        c.x = b.x + (b.slotRelX or 0)
        c.y = b.y + (b.slotRelY or 0) + 6 + c.h * 0.5
        codingApplyBlock(c, depth + 1)
    end
end

function codingApplyView()
    for i = #codingBlocks, 1, -1 do
        local b = codingBlocks[i]
        if not (b and b.root and b.root.Parent) then
            table.remove(codingBlocks, i)
        end
    end
    for _, b in ipairs(codingBlocks) do
        if b.root and b.root.Parent and not b.parentBlock then
            codingApplyBlock(b)
        end
    end

    for _, b in ipairs(codingBlocks) do
        if b.root and b.root.Parent and b.parentBlock and b.parentBlock.bodyBlock ~= b then
            b.parentBlock = nil
            b.attached = nil
            codingApplyBlock(b)
        end
    end
    codingUpdateCanvasEmptyState()
    codingUpdateViewHint()
    codingScrollEntriesToBottom()
end

function codingLayoutTree()
    codingApplyView()
end

function codingStartPanFrom(inputObj)
    if codingPanDrag then return end
    local startPanX, startPanY = codingView.panX, codingView.panY
    local movedOnce = false

    codingPanVel.x, codingPanVel.y = 0, 0

    local lastT = os.clock()

    local velT = lastT
    local velDx, velDy = 0, 0
    codingPanDrag = codingBeginDragObjMove(function(dx, dy)
        local now = os.clock()
        codingView.panX = startPanX + dx
        codingView.panY = startPanY + dy
        movedOnce = true
        codingApplyView()
        local gap = now - velT
        if gap >= CODING_DAMP_VEL_WIN then
            local vx, vy = (dx - velDx) / gap, (dy - velDy) / gap
            velT, velDx, velDy = now, dx, dy

            codingPanVel.x = (codingPanVel.x or 0) * 0.4 + vx * 0.6
            codingPanVel.y = (codingPanVel.y or 0) * 0.4 + vy * 0.6
        end
        lastT = now
    end, function()
        codingPanDrag = nil

        if (os.clock() - lastT) > 0.09 then
            codingPanVel.x, codingPanVel.y = 0, 0
        else

            local sp = math.sqrt((codingPanVel.x or 0) ^ 2 + (codingPanVel.y or 0) ^ 2)
            if sp > CODING_DAMP_MAX_V then
                local s = CODING_DAMP_MAX_V / sp
                codingPanVel.x, codingPanVel.y = codingPanVel.x * s, codingPanVel.y * s
            end
        end
    end, inputObj)
    return movedOnce
end

codingPanCatcher.InputBegan:Connect(function(inp)

    pcall(function()
    if not codingIsMouseTouch(inp) or not codingCanvasUsable() then return end

    if codingAnyBlockInputFocused() then return end

    if inp.UserInputType ~= Enum.UserInputType.Touch then
        codingPinchActive = false
    end

    if codingPinchActive then return end
    local mp = inp.Position

    local last = codingCanvasLastClick
    if last and (os.clock() - last.t) < 0.35
        and math.abs(mp.X - last.x) < 6 and math.abs(mp.Y - last.y) < 6 then
        codingCanvasLastClick = nil
        codingResetView()
        ShowNotification("预览框视图已复位", 1)
        return
    end
    codingCanvasLastClick = { t = os.clock(), x = mp.X, y = mp.Y }
    codingStartPanFrom(inp)
    end)
end)

if codingCanvas then
    codingCanvas.InputBegan:Connect(function(inp)
        pcall(function()
        if not codingIsMouseTouch(inp) or not codingCanvasUsable() then return end

        if codingAnyBlockInputFocused() then return end

        if inp.UserInputType ~= Enum.UserInputType.Touch then
            codingPinchActive = false
        end
        if codingPinchActive then return end
        codingStartPanFrom(inp)
        end)
    end)
end

if codingViewHint then
    codingViewHint.MouseButton1Click:Connect(function()
        codingResetView()
        ShowNotification("预览框视图已复位", 1)
    end)
end

pcall(function()
    svc.UserInputService.InputChanged:Connect(function(inp)
        pcall(function()
            if inp.UserInputType ~= Enum.UserInputType.MouseWheel then return end
            if not codingCanvasUsable() then return end

            local px, py = inp.Position.X, inp.Position.Y
            if (not px) or (not py) or (px == 0 and py == 0) then
                local ok, ml = pcall(function() return svc.UserInputService:GetMouseLocation() end)
                if ok and ml then px, py = ml.X, ml.Y end
            end
            if not codingPointInCanvas(px, py) then return end

            local blocked = false
            pcall(function() blocked = codingPointerBlocked(px, py) and true or false end)
            if blocked then return end
            local ddOpen = false
            pcall(function() ddOpen = codingAnyDropdownOpen() and true or false end)
            if ddOpen then return end

            local dir = inp.Position.Z
            if type(dir) ~= "number" or dir == 0 then
                local ok, dz = pcall(function() return inp.Delta.Z end)
                if ok and type(dz) == "number" and dz ~= 0 then dir = dz end
            end
            if type(dir) ~= "number" or dir == 0 then dir = 1 end

            codingZoomRequest(codingZoomTarget + (dir > 0 and CODING_Z_STEP or -CODING_Z_STEP), px, py)
        end)
    end)
end)

pcall(function()
    local uis = svc.UserInputService

    codingTouchMap = {}
    codingPinchDist = nil
    codingPinchActive = false
    local CODING_TOUCH_STALE = 5

    local function codingTouchPoints()
        local pts, now = {}, os.clock()
        for k, r in pairs(codingTouchMap) do
            if type(r) == "table" and r.t and (now - r.t) <= CODING_TOUCH_STALE then
                table.insert(pts, r)
            else
                codingTouchMap[k] = nil
            end
        end
        return pts
    end

    local function codingPinchPair()
        local pts = codingTouchPoints()
        if #pts < 2 then return nil end
        local best, ax, ay, bx, by = -1
        for i = 1, #pts - 1 do
            for j = i + 1, #pts do
                local dx, dy = pts[i].x - pts[j].x, pts[i].y - pts[j].y
                local d = math.sqrt(dx * dx + dy * dy)
                if d > best then best, ax, ay, bx, by = d, pts[i].x, pts[i].y, pts[j].x, pts[j].y end
            end
        end
        if best < 0 then return nil end
        return best, ax, ay, bx, by
    end

    function codingResetPinchState()
        codingPinchDist = nil
        codingPinchActive = false
    end

    local function codingAbortPanForPinch()
        pcall(function() if codingPanDrag then codingPanDrag() end end)
        codingPanDrag = nil
        codingPanVel.x, codingPanVel.y = 0, 0
    end

    local function codingPinchCheck()
        pcall(function()
            local dist, ax, ay, bx, by = codingPinchPair()
            if not dist or dist < 1 then
                codingResetPinchState()
                return
            end
            local cx, cy = (ax + bx) * 0.5, (ay + by) * 0.5

            if not (codingPointInCanvas(ax, ay) and codingPointInCanvas(bx, by)) then
                codingResetPinchState()
                return
            end
            if not codingCanvasUsable() then
                codingResetPinchState()
                return
            end

            if codingPointerBlocked(cx, cy) or codingAnyDropdownOpen() then
                codingResetPinchState()
                return
            end
            codingPinchActive = true
            if not codingPinchDist then

                codingPinchDist = dist
                codingAbortPanForPinch()
                return
            end
            local ratio = dist / codingPinchDist
            codingPinchDist = dist
            if math.abs(ratio - 1) < 0.002 then return end

            codingZoomAt(codingView.z * ratio, cx, cy)
        end)
    end

    local function codingTouchSet(inp)
        codingTouchMap[inp] = { x = inp.Position.X, y = inp.Position.Y, t = os.clock() }
    end
    uis.TouchStarted:Connect(function(inp)
        pcall(function()
            codingTouchSet(inp)

            codingPinchDist = nil
            codingPinchCheck()
        end)
    end)
    uis.TouchMoved:Connect(function(inp)
        pcall(function()
            codingTouchSet(inp)
            codingPinchCheck()
        end)
    end)
    local function onTouchGone(inp)
        pcall(function()
            codingTouchMap[inp] = nil
            local n = 0
            for _ in pairs(codingTouchMap) do n = n + 1 end

            codingPinchDist = nil
            if n < 2 then codingPinchActive = false end
        end)
    end
    uis.TouchEnded:Connect(onTouchGone)
    uis.TouchCanceled:Connect(onTouchGone)
end)

function codingResetViewIfHidden()
    if currentPage ~= "coding" then

        pcall(function()
            if codingTouchMap then
                for k in pairs(codingTouchMap) do codingTouchMap[k] = nil end
            end
        end)
        pcall(codingResetPinchState)
        codingPinchActive = false
        codingResetView()
    end
end

function codingValueBlockReferenced(target)
    for _, other in ipairs(codingBlocks) do
        if other ~= target and other.root and other.root.Parent then
            for key, val in pairs(other.data) do
                local base = key:match("^(.-)Src$")
                if base and val == "valueBlock" and other.data[base .. "Seq"] == target.seq then
                    return true
                end
            end
        end
    end
    return false
end

function codingBlockLines(b, depth, bag, seen)
    if not (b and b.spec) then return end
    depth = depth or 0
    bag = bag or {}
    seen = seen or {}
    if seen[b] then
        table.insert(bag, "-- 检测到循环引用，已截断：" .. tostring(b.spec.title))
        return
    end
    seen[b] = true
    if b.spec.value and not b.spec.stmt then

        if not codingValueBlockReferenced(b) then
            local okExpr, expr = pcall(b.spec.expr, b)
            table.insert(bag, "print(" .. ((okExpr and expr) or "nil") .. ") -- 值积木「" .. tostring(b.spec.title) .. "」")
        end
        return
    end
    if not b.spec.stmt then return end
    local pad = string.rep(CODING_INDENT_STR, depth)
    local function emit(fmt, ...)
        local line = fmt
        if select("#", ...) > 0 then
            local okFormat, outFormat = pcall(string.format, fmt, ...)
            line = okFormat and outFormat or tostring(fmt)
        end
        for _, one in ipairs(codingSplitLines(line)) do
            table.insert(bag, pad .. one)
        end
    end
    local function nest(emptyComment)
        if not b.bodyBlock then
            if emptyComment then emit("%s", emptyComment) end
            return
        end
        codingBlockLines(b.bodyBlock, depth + 1, bag, seen)
    end
    local okRun, errRun = pcall(b.spec.stmt, b, emit, nest)
    if not okRun then
        table.insert(bag, "-- 「" .. tostring(b.spec.title) .. "」生成失败：" .. tostring(errRun))
    end
end

function codingSplitLines(text)
    local out = {}
    for line in tostring(text or ""):gmatch("[^\n]+") do
        table.insert(out, line)
    end
    if #out == 0 then out[1] = "" end
    return out
end

function codingCompileBlocks()
    local bag = {}
    local roots = {}
    for _, b in ipairs(codingBlocks) do
        if b.root and b.root.Parent and not b.parentBlock then
            table.insert(roots, b)
        end
    end
    if #roots == 0 then return nil, 0 end
    for _, b in ipairs(roots) do
        codingBlockLines(b, 0, bag, {})
    end
    local head = {}
    table.insert(head, "-- 由「编程积木」预览框生成")
    table.insert(head, "-- 顶层积木 " .. #roots .. " 张 · 画布内共 " .. #codingBlocks .. " 张")
    table.insert(head, "-- 变量与函数都是局部名；物体按「目标」里的路径 FindFirstChild 查找")
    for _, line in ipairs(bag) do
        table.insert(head, line)
    end
    return table.concat(head, "\n") .. "\n", #roots
end

function codingBlocksToText()
    return codingCompileBlocks()
end

CODING_CLIP_FNS = {
    "setclipboard", "toclipboard", "setClipboard", "SetClipboard",
    "toClipboard", "writeclipboard", "set_clipboard", "copy",
    "Clipboard", "setToClipboard", "writeToClipboard",
}

function codingClipboardDiagnose()
    local info = {}
    local env = getgenv and getgenv() or _G
    for _, name in ipairs(CODING_CLIP_FNS) do
        local v = env[name]
        info[#info + 1] = name .. " = " .. type(v)
    end
    if env.syn then info[#info + 1] = "syn.setclipboard = " .. type(env.syn.setclipboard) end
    if env.clipboard then info[#info + 1] = "clipboard.set = " .. type(env.clipboard.set) end

    local rawKind = type(setclipboard)
    info[#info + 1] = "裸标识符 setclipboard = " .. rawKind
    return table.concat(info, " | ")
end

local function codingResolveClipFn()

    local bare = setclipboard or toclipboard
    if type(bare) == "function" then return bare end

    local env = getgenv and getgenv() or _G
    for _, name in ipairs(CODING_CLIP_FNS) do
        local f = env[name]
        if type(f) == "function" then return f end
    end
    if type(env.syn) == "table" and type(env.syn.setclipboard) == "function" then
        return env.syn.setclipboard
    end
    if type(env.clipboard) == "table" and type(env.clipboard.set) == "function" then
        return env.clipboard.set
    end
    return nil
end

function codingTryClipboard(text)
    local f = codingResolveClipFn()
    if type(f) ~= "function" then return false end
    local ok = pcall(f, text)
    return ok == true
end

function codingCopyToClipboard(text)

    if codingTryClipboard(text) then return true end

    local result = { false }
    task.spawn(function()
        task.wait()
        result[1] = codingTryClipboard(text)
    end)
    local deadline = os.clock() + 0.3
    while os.clock() < deadline do
        if result[1] then break end
        task.wait()
    end
    if result[1] then return true end
    return false
end

function codingBlocksFileName()
    local n = 0
    for _, b in ipairs(codingBlocks) do
        if b.root and b.root.Parent and not b.parentBlock then n = n + 1 end
    end
    return "delta_blocks_" .. os.date("%Y%m%d_%H%M%S") .. "_" .. n .. ".lua"
end

function codingWriteBlocksFile(text)
    local dir = "DeltaUI/Blocks"
    pcall(function() if not isfolder("DeltaUI") then makefolder("DeltaUI") end end)
    pcall(function() if not isfolder(dir) then makefolder(dir) end end)
    local name = codingBlocksFileName()
    local path = dir .. "/" .. name
    local ok = pcall(function() writefile(path, text) end)
    return ok, path
end

function codingBuildBlockToolbar()
    local row = create("Frame", {
        Position = UDim2.new(0, 12, 0, 98),
        Size = UDim2.new(1, -24, 0, 30),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 5,
    })
    row.Name = "codingToolRow"
    row.Parent = codingRightPanel
    codingToolRow = row

    local function toolBtn(xFrac, wFrac, label, iconName, tint)
        local btn = create("TextButton", {
            Position = UDim2.new(xFrac, 0, 0, 0),
            Size = UDim2.new(wFrac, 0, 1, 0),
            BackgroundColor3 = theme.surface,
            BackgroundTransparency = 0.15,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 6,
            Parent = row,
        })
        corner(10, btn)
        stroke(tint, 1, btn)
        local ic = GetIcon(iconName, UDim2.new(0, 13, 0, 13), tint)
        local textX = 8
        if ic then
            ic.Position = UDim2.new(0, 8, 0.5, -6)
            ic.ZIndex = 7
            ic.Parent = btn
            textX = 26
        end
        local lbl = create("TextLabel", {
            Position = UDim2.new(0, textX, 0, 0),
            Size = UDim2.new(1, -(textX + 6), 1, 0),
            BackgroundTransparency = 1,
            Text = label,
            TextColor3 = theme.text,
            TextSize = 12,
            Font = Enum.Font.SourceSansBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 7,
            Parent = btn,
        })
        btn.MouseEnter:Connect(function()
            if codingIsFadedOut(btn) then return end
            svc.TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundTransparency = 0.02 }):Play()
        end)
        btn.MouseLeave:Connect(function()
            if codingIsFadedOut(btn) then return end
            svc.TweenService:Create(btn, TweenInfo.new(0.2), { BackgroundTransparency = 0.15 }):Play()
        end)
        return btn, lbl
    end

    local copyBtn = toolBtn(0, 0.7, "复制为 Lua 脚本", "copy", theme.accent)
    copyBtn.MouseButton1Click:Connect(function()
        local code, rootCount = codingCompileBlocks()
        if not code then
            ShowNotification("预览框里还没有积木", 2)
            return
        end

        local function forceBareSync()
            local setclip = setclipboard or toclipboard or (syn and syn.setclipboard) or (clipboard and clipboard.set)
            if type(setclip) ~= "function" then return false end
            local ok = pcall(setclip, code)
            return ok == true
        end
        if forceBareSync() then
            ShowNotification("已复制 Lua 脚本（" .. rootCount .. " 张积木）", 2)
            return
        end

        if codingCopyToClipboard(code) then
            ShowNotification("已复制 Lua 脚本（" .. rootCount .. " 张积木）", 2)
            return
        end
        local okFile, path = codingWriteBlocksFile(code)
        if okFile then
            ShowNotification("剪贴板不可用，已存到文件:\n" .. path, 4)
        else
            ShowNotification("复制失败，剪贴板不可用且无法写入文件", 3)
        end
    end)

    local clearBtn = toolBtn(0.72, 0.28, "清空", "trash-2", theme.red)
    clearBtn.MouseButton1Click:Connect(function()
        if #codingBlocks == 0 then
            ShowNotification("预览框已经是空的", 1)
            return
        end
        if not codingClearArm then
            codingClearArm = true
            ShowNotification("再点一次「清空」确认清空预览框", 2)
            task.delay(2.5, function() codingClearArm = nil end)
            return
        end
        codingClearArm = nil
        local n = #codingBlocks
        for i = #codingBlocks, 1, -1 do
            local b = codingBlocks[i]
            if b and b.root and b.root.Parent then b.root:Destroy() end
        end
        codingBlocks = {}
        codingApplyView()
        ShowNotification("已清空预览框（" .. n .. " 张积木）", 2)
    end)

    if codingRunBtn then
        codingRunBtn.MouseButton1Click:Connect(function()
            local code, rootCount = codingCompileBlocks()
            if not code then
                ShowNotification("预览框里还没有积木", 2)
                return
            end
            AddLog("[Blocks] 积木 -> Lua（" .. rootCount .. " 张）:\n" .. code, "info")
            local fn, compileErr = loadstring(code)
            if not fn then
                ShowNotification("积木转 Lua 失败，见控制台", 4)
                AddLog("[Blocks][Error] " .. tostring(compileErr), "error")
                return
            end
            local ok, runErr = xpcall(fn, function(err) return debug.traceback(tostring(err), 2) end)
            if ok then
                ShowNotification("积木脚本已运行", 2)
            else
                ShowNotification("积木脚本报错，见控制台", 4)
                AddLog("[Blocks][Error] " .. tostring(runErr), "error")
            end
        end)
    end
    pcall(function() codingFadeEntries(codingToolRow) end)
    return codingToolRow
end

codingFadeBase = codingFadeBase or setmetatable({}, {__mode = "k"})
codingFadeCache = codingFadeCache or setmetatable({}, {__mode = "k"})

local function codingProp(obj, name)
    local ok, val = pcall(function() return obj[name] end)
    if ok and type(val) == "number" then return val end
    return nil
end

local function codingBaseOf(obj)
    local b = codingFadeBase[obj]
    if b then return b end
    b = {
        bg = codingProp(obj, "BackgroundTransparency"),
        text = codingProp(obj, "TextTransparency"),
        image = codingProp(obj, "ImageTransparency"),
    }
    local s = obj:FindFirstChildOfClass("UIStroke")
    if s then
        b.strokeObj = s
        b.stroke = codingProp(s, "Transparency")
    end
    codingFadeBase[obj] = b
    return b
end

local CODING_FADE_SKIP = {UIStroke = true, UICorner = true, UIGradient = true, UIPadding = true, UIListLayout = true, UIGridLayout = true, UITextSizeConstraint = true}

function codingFadeEntries(root)
    if not root then return {} end
    local entries = {}
    local function add(o)
        if o and not CODING_FADE_SKIP[o.ClassName] then
            local b = codingBaseOf(o)
            if b.bg ~= nil or b.text ~= nil or b.image ~= nil or b.strokeObj then
                table.insert(entries, {obj = o, base = b})
            end
        end
    end
    add(root)
    for _, d in ipairs(root:GetDescendants()) do
        add(d)
    end
    codingFadeCache[root] = entries
    return entries
end

codingFadeOutRoots = {}

function codingIsFadedOut(obj)
    local o = obj
    while o do
        if codingFadeOutRoots[o] then return true end
        o = o.Parent
    end
    return false
end

codingHoverTint = codingHoverTint or {}

function codingRegHoverTint(btn, enterProps)
    if not btn then return end
    local base = {}
    for k in pairs(enterProps or {}) do
        local ok, v = pcall(function() return btn[k] end)
        if ok then base[k] = v end
    end
    codingHoverTint[btn] = base
end

function codingResetHoverTint(btn)
    local base = codingHoverTint and btn and codingHoverTint[btn]
    if not base then return end
    pcall(function()
        if not btn.Parent then return end
        local props = {}
        for k, v in pairs(base) do
            if k ~= "BackgroundTransparency" and k ~= "TextTransparency" and k ~= "ImageTransparency" then
                props[k] = v
            end
        end
        if next(props) then
            svc.TweenService:Create(btn, TweenInfo.new(0.15), props):Play()
        end
    end)
end

function codingResetHoverTintFull(btn)
    local base = codingHoverTint and btn and codingHoverTint[btn]
    if not base then return end
    pcall(function()
        if not btn.Parent then return end
        svc.TweenService:Create(btn, TweenInfo.new(0.15), base):Play()
    end)
end

local function codingResetHoverTintIn(root)
    if not root then return end
    pcall(function()
        for btn in pairs(codingHoverTint) do
            if btn.Parent and (btn == root or btn:IsDescendantOf(root)) then
                codingResetHoverTint(btn)
            end
        end
    end)
end

function codingFadeGroup(root, show, duration)
    if not root then return end
    duration = duration or 0.2

    if show then codingFadeOutRoots[root] = nil else codingFadeOutRoots[root] = true end
    local entries = codingFadeEntries(root)
    local ti = TweenInfo.new(math.max(duration, 0.01), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local function apply(inst, prop, orig)
        if orig == nil then return end
        if show then
            inst[prop] = 1
            svc.TweenService:Create(inst, ti, {[prop] = orig}):Play()
        else
            svc.TweenService:Create(inst, ti, {[prop] = 1}):Play()
        end
    end
    if show then root.Visible = true end

    pcall(function()
        if root:IsA("ScrollingFrame") then
            codingBaseScrollBar = codingBaseScrollBar or {}
            if codingBaseScrollBar[root] == nil then
                codingBaseScrollBar[root] = root.ScrollBarThickness
            end
            root.ScrollBarThickness = show and (codingBaseScrollBar[root] or 4) or 0
        end
    end)
    for _, e in ipairs(entries) do
        local o, b = e.obj, e.base

        if o == root or o.Parent then
            apply(o, "BackgroundTransparency", b.bg)
            apply(o, "TextTransparency", b.text)
            apply(o, "ImageTransparency", b.image)
            if b.strokeObj then apply(b.strokeObj, "Transparency", b.stroke) end
        end
    end
    if not show then

        codingResetHoverTintIn(root)
        task.delay(duration + 0.02, function()
            if root and root.Parent then root.Visible = false end
        end)
    end
end

codingAddBlockBtn = create("TextButton", {
    Position = UDim2.new(0, 12, 0, 12),
    Size = UDim2.new(1, -24, 0, 36),
    BackgroundColor3 = theme.accent,
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 5,
})
corner(12, codingAddBlockBtn)
applyGradient(codingAddBlockBtn, theme.accent, theme.accent2, 120)
stroke(theme.accent, 1, codingAddBlockBtn)
codingAddBlockInner = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, 118, 0, 20),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 6,
    Parent = codingAddBlockBtn,
})
create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    SortOrder = Enum.SortOrder.LayoutOrder,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 7),
    Parent = codingAddBlockInner,
})
codingAddBlockIcon = GetIcon("plus", UDim2.new(0, 16, 0, 16), Color3.fromRGB(255, 255, 255))
if codingAddBlockIcon then
    codingAddBlockIcon.LayoutOrder = 1
    codingAddBlockIcon.ZIndex = 7
    codingAddBlockIcon.Parent = codingAddBlockInner
end
codingAddBlockLabel = create("TextLabel", {
    LayoutOrder = 2,
    Size = UDim2.new(0, 64, 1, 0),
    BackgroundTransparency = 1,
    Text = "添加积木",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 15,
    Font = Enum.Font.SourceSansBold,
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 7,
    Parent = codingAddBlockInner,
})
codingAddBlockBtn.Parent = codingRightPanel

codingActionSmall = create("Frame", {
    Position = UDim2.new(0, 12, 0, 56),
    Size = UDim2.new(1, -24, 0, 36),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 5,
})
codingActionSmall.Parent = codingRightPanel

codingEnterBtn = create("TextButton", {
    AnchorPoint = Vector2.new(0, 0),
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(0.5, -4, 1, 0),
    BackgroundColor3 = theme.surface,
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 6,
})
corner(10, codingEnterBtn)
stroke(theme.border, 1, codingEnterBtn)
codingEnterIcon = GetIcon("box", UDim2.new(0, 14, 0, 14), theme.accent)
if codingEnterIcon then
    codingEnterIcon.Position = UDim2.new(0, 8, 0.5, -7)
    codingEnterIcon.ZIndex = 7
    codingEnterIcon.Parent = codingEnterBtn
end
create("TextLabel", {
    Position = UDim2.new(0, (codingEnterIcon and 26 or 8), 0, 0),
    Size = UDim2.new(1, -(codingEnterIcon and 34 or 14), 1, 0),
    BackgroundTransparency = 1,
    Text = "进入建造空间",
    TextColor3 = theme.text,
    TextSize = 12,
    Font = Enum.Font.SourceSansBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextWrapped = false,
    ZIndex = 7,
    Parent = codingEnterBtn,
})
codingEnterBtn.Parent = codingActionSmall

codingRunBtn = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, 0, 0, 0),
    Size = UDim2.new(0.5, -4, 1, 0),
    BackgroundColor3 = theme.green,
    BackgroundTransparency = 0.78,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 6,
})
corner(10, codingRunBtn)
stroke(theme.green, 1, codingRunBtn)
codingRunIcon = GetIcon("play", UDim2.new(0, 14, 0, 14), theme.green)
if codingRunIcon then
    codingRunIcon.Position = UDim2.new(0, 8, 0.5, -7)
    codingRunIcon.ZIndex = 7
    codingRunIcon.Parent = codingRunBtn
end
create("TextLabel", {
    Position = UDim2.new(0, (codingRunIcon and 26 or 8), 0, 0),
    Size = UDim2.new(1, -(codingRunIcon and 34 or 14), 1, 0),
    BackgroundTransparency = 1,
    Text = "运行",
    TextColor3 = theme.text,
    TextSize = 12,
    Font = Enum.Font.SourceSansBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 7,
    Parent = codingRunBtn,
})
codingRunBtn.Parent = codingActionSmall

codingPickerBar = create("Frame", {
    Position = UDim2.new(0, 12, 0, 12),
    Size = UDim2.new(1, -24, 0, 36),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 5,
    Visible = false,
})
codingPickerBar.Name = "codingPicker"
codingPickerBar.Parent = codingRightPanel

codingPickerSearch = create("Frame", {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(0, CODING_RIGHT_W_COLLAPSED - 24 - 52, 1, 0),
    BackgroundColor3 = theme.surface,
    BackgroundTransparency = 0.2,
    BorderSizePixel = 0,
    ZIndex = 6,
})
corner(12, codingPickerSearch)
stroke(theme.border, 1, codingPickerSearch)
codingPickerSearch.Parent = codingPickerBar

codingPickerSearchIcon = GetIcon("search", UDim2.new(0, 14, 0, 14), theme.textDim)
if codingPickerSearchIcon then
    codingPickerSearchIcon.Position = UDim2.new(0, 10, 0.5, -7)
    codingPickerSearchIcon.ZIndex = 7
    codingPickerSearchIcon.Parent = codingPickerSearch
end
codingPickerInput = create("TextBox", {
    Position = UDim2.new(0, (codingPickerSearchIcon and 28 or 10), 0, 0),
    Size = UDim2.new(1, -((codingPickerSearchIcon and 28 or 10) + 12), 1, 0),
    BackgroundTransparency = 1,
    PlaceholderText = "搜索组件",
    Text = "",
    TextColor3 = theme.text,
    PlaceholderColor3 = theme.textDim,
    TextSize = 12,
    Font = Enum.Font.SourceSans,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    ZIndex = 7,
    Parent = codingPickerSearch,
})

pcall(function()
    codingRightPanel:GetPropertyChangedSignal("AbsoluteSize"):Connect(codingApplySearchWidth)
    codingRightPanel:GetPropertyChangedSignal("Size"):Connect(codingApplySearchWidth)
end)

codingBackBtn = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, 0, 0, 0),
    Size = UDim2.new(0, 44, 1, 0),
    BackgroundColor3 = theme.surface,
    BackgroundTransparency = 0.2,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 6,
})
corner(12, codingBackBtn)
stroke(theme.border, 1, codingBackBtn)
codingBackIcon = GetIcon("undo-2", UDim2.new(0, 16, 0, 16), theme.text)
if codingBackIcon then
    codingBackIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    codingBackIcon.Position = UDim2.new(0.5, 0, 0.5, -1)
    codingBackIcon.ZIndex = 7
    codingBackIcon.Parent = codingBackBtn
else
    create("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 44, 0, 20),
        BackgroundTransparency = 1,
        Text = "返回",
        TextColor3 = theme.text,
        TextSize = 12,
        Font = Enum.Font.SourceSansBold,
        ZIndex = 7,
        Parent = codingBackBtn,
    })
end
codingBackBtn.Parent = codingPickerBar

local CODING_CARD_PURPLE = Color3.fromRGB(139, 92, 246)

codingCardAnimLock = false
codingCardAnimQueue = {}

local codingGridSortRefCount = 0
local codingSavedGridProps = nil

local codingCardWaitLayoutStable

local CODING_CELL_H = 88
local CODING_CELL_PAD = 8
local CODING_CELL_COLS = 2

local function codingSaveGridProps(grid)

    return {
        CellSize = grid.CellSize,
        CellPadding = grid.CellPadding,
        SortOrder = grid.SortOrder,
        HorizontalAlignment = grid.HorizontalAlignment,
        VerticalAlignment = grid.VerticalAlignment,
        FillDirection = grid.FillDirection,
    }
end

local function codingFreezeGridSort()
    if not codingPickerCards then return end
    codingGridSortRefCount = codingGridSortRefCount + 1
    if codingGridSortRefCount == 1 then

        codingSavedCanvasY = codingCardsScrollY()

        pcall(function()
            local cellW = math.max(0, codingPickerCards.AbsoluteSize.X * 0.5 - 4)
            for _, ch in ipairs(codingPickerCards:GetChildren()) do
                if ch:IsA("TextButton") then
                    local idx = math.max(0, (ch.LayoutOrder or 1) - 1)
                    local col = idx % CODING_CELL_COLS
                    local row = math.floor(idx / CODING_CELL_COLS)
                    ch.AnchorPoint = Vector2.new(0, 0)
                    ch.Size = UDim2.new(0.5, -4, 0, CODING_CELL_H)
                    ch.Position = UDim2.fromOffset(col * (cellW + CODING_CELL_PAD), row * (CODING_CELL_H + CODING_CELL_PAD))
                end
            end
        end)

        local grid = codingPickerCards:FindFirstChildOfClass("UIGridLayout")
        if grid then
            codingSavedGridProps = codingSaveGridProps(grid)
            grid:Destroy()
        else
            codingSavedGridProps = nil
        end
    end
end

local function codingThawGridSort()
    if codingGridSortRefCount <= 0 then
        codingGridSortRefCount = 0
        return
    end
    codingGridSortRefCount = codingGridSortRefCount - 1
    if codingGridSortRefCount == 0 then

        codingCardWaitLayoutStable(function()
            if not codingPickerCards then return end
            if codingPickerCards:FindFirstChildOfClass("UIGridLayout") then return end
            if not codingSavedGridProps then return end
            local grid = Instance.new("UIGridLayout")
            grid.CellSize = codingSavedGridProps.CellSize
            grid.CellPadding = codingSavedGridProps.CellPadding
            grid.SortOrder = codingSavedGridProps.SortOrder
            grid.HorizontalAlignment = codingSavedGridProps.HorizontalAlignment
            grid.VerticalAlignment = codingSavedGridProps.VerticalAlignment
            grid.FillDirection = codingSavedGridProps.FillDirection
            grid.Parent = codingPickerCards
            codingSavedGridProps = nil

            codingCardWaitLayoutStable(function()
                if not (codingPickerCards and codingPickerCards.Parent) then
                    codingSavedCanvasY = nil
                    return
                end
                pcall(function()
                    local canvasH = codingPickerCards.CanvasSize.Y.Offset
                    local viewH = codingPickerCards.AbsoluteSize.Y
                    local y = math.clamp(codingSavedCanvasY or 0, 0, math.max(0, canvasH - viewH))
                    codingPickerCards.CanvasPosition = Vector2.new(0, y)
                end)
                codingSavedCanvasY = nil
            end)
        end)
    end
end

codingCardWaitLayoutStable = function(callback)
    local runs = 0
    local conn
    conn = svc.RunService.Heartbeat:Connect(function()
        runs = runs + 1
        if runs >= 2 then
            conn:Disconnect()
            if callback then callback() end
        end
    end)
end

local function codingWaitAllTweens(tweens, callback)
    local pending = 0
    for _ in pairs(tweens) do pending = pending + 1 end
    if pending == 0 then
        if callback then callback() end
        return
    end
    local done = 0
    local fired = false
    local function check()
        done = done + 1
        if done >= pending and not fired then
            fired = true

            if callback then callback() end
        end
    end
    for _, tw in pairs(tweens) do
        local ok, conn = pcall(function()
            return tw.Completed:Connect(check)
        end)
        if not ok or not conn then

            check()
        else

            local ok2, st = pcall(function() return tw.PlaybackState end)
            if ok2 and st == Enum.PlaybackState.Completed then
                check()
            end
        end
    end

    for _, tw in pairs(tweens) do
        local info = tw and tw.TweenInfo
        task.delay((info and info.Time or 0) + 0.1, check)
    end
end

codingPickerCards = create("ScrollingFrame", {
    Position = UDim2.new(0, 12, 0, 56),

    Size = UDim2.new(1, -24, 1, -(56 + 8)),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollBarThickness = 4,
    ScrollBarImageTransparency = 0.65,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    ElasticBehavior = Enum.ElasticBehavior.Never,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 5,
})
codingPickerCards.Name = "codingCards"
codingPickerCards.Parent = codingRightPanel

create("UIGridLayout", {
    CellSize = UDim2.new(0.5, -4, 0, 88),
    CellPadding = UDim2.new(0, 8, 0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    Parent = codingPickerCards,
})

local function codingSyncCardsCanvasX()
    if not (codingPickerCards and codingPickerCards.Parent) then return end
    pcall(function()
        codingPickerCards.CanvasSize = UDim2.new(0, codingPickerCards.AbsoluteSize.X, 0, 0)
    end)
end
pcall(function()
    codingPickerCards:GetPropertyChangedSignal("AbsoluteSize"):Connect(codingSyncCardsCanvasX)
end)
task.defer(codingSyncCardsCanvasX)

local CARD_BG_TRANSPARENCY = 0.25

codingCardRefs = codingCardRefs or {}
codingExpandedCard = nil
local function makeCodingCard(order, title, subtitle, iconName, accent)
    local card = create("TextButton", {
        LayoutOrder = order,
        Size = UDim2.new(0.5, -4, 0, 88),
        BackgroundColor3 = theme.surface,
        BackgroundTransparency = CARD_BG_TRANSPARENCY,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        ZIndex = 6,
    })
    corner(14, card)
    stroke(theme.border, 1, card)

    local colorBar = create("Frame", {
        Position = UDim2.new(0, 12, 0, 10),
        Size = UDim2.new(1, -24, 0, 3),
        BackgroundColor3 = accent,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        ZIndex = 7,
        Parent = card,
    })

    local icon = GetIcon(iconName, UDim2.new(0, 18, 0, 18), accent)
    if icon then
        icon.Position = UDim2.new(0, 12, 0, 20)
        icon.ZIndex = 8
        icon.Parent = card
    end
    local titleLabel = create("TextLabel", {
        Position = UDim2.new(0, (icon and 36 or 12), 0, 20),
        Size = UDim2.new(1, -(icon and 44 or 20) - 10, 0, 20),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 8,
        Parent = card,
    })

    local engLabel
    if subtitle and subtitle ~= "" then
        engLabel = create("TextLabel", {

            Position = UDim2.new(0, 12, 0, 64),
            Size = UDim2.new(1, -22, 0, 16),
            BackgroundTransparency = 1,
            Text = subtitle,
            TextColor3 = theme.textDim,
            TextSize = 10,
            Font = Enum.Font.SourceSans,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Bottom,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 8,
            Parent = card,
        })
    end

    local collapseBtn = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0),

        Position = UDim2.new(1, -8, 0, 8),
        Size = UDim2.new(0, 26, 0, 26),
        BackgroundColor3 = Color3.fromRGB(30, 36, 52),
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Visible = false,
        ZIndex = 40,
        Parent = card,
    })
    corner(8, collapseBtn)
    stroke(theme.border, 1, collapseBtn)
    local collapseIcon = GetIcon("x", UDim2.new(0, 14, 0, 14), Color3.fromRGB(230, 232, 240))
    if collapseIcon then
        collapseIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        collapseIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
        collapseIcon.ZIndex = 41
        collapseIcon.Parent = collapseBtn
    end

    codingRegHoverTint(collapseBtn, { BackgroundTransparency = 0 })

    pcall(function()
        card.Destroying:Connect(function()
            if codingHoverTint then codingHoverTint[collapseBtn] = nil end
        end)
    end)
    collapseBtn.MouseEnter:Connect(function()
        if not collapseBtn.Visible then return end
        svc.TweenService:Create(collapseBtn, TweenInfo.new(0.14), {BackgroundTransparency = 0}):Play()
    end)
    collapseBtn.MouseLeave:Connect(function()
        if not collapseBtn.Visible then return end
        svc.TweenService:Create(collapseBtn, TweenInfo.new(0.18), {BackgroundTransparency = 0.15}):Play()
    end)
    collapseBtn.MouseButton1Click:Connect(function()

        if codingExpandedCard == card then
            codingCollapseCard(card)
        end
    end)

    card.MouseEnter:Connect(function()
        if codingIsFadedOut(card) then return end
        svc.TweenService:Create(card, TweenInfo.new(0.15), {
            BackgroundTransparency = 0.05,
        }):Play()
    end)
    card.MouseLeave:Connect(function()
        if codingIsFadedOut(card) then return end
        svc.TweenService:Create(card, TweenInfo.new(0.2), {
            BackgroundTransparency = CARD_BG_TRANSPARENCY,
        }):Play()
    end)

    card.MouseButton1Click:Connect(function()
        if codingPickerBusy or codingSettingsMode then return end
        codingExpandCard(card)
    end)

    card.Parent = codingPickerCards
    codingCardRefs[card] = { title = titleLabel, collapseBtn = collapseBtn, colorBar = colorBar,
        eng = engLabel,

        title0 = title, accent = accent }
    return card
end

makeCodingCard(1, "变量类", "Variable", "variable", CODING_CARD_PURPLE)

makeCodingCard(2, "Function类", "Function", "braces", theme.accent)

makeCodingCard(3, "物体类", "Object", "box", theme.green)

makeCodingCard(4, "流程控制", "Flow", "repeat", CODING_CAT_ACCENTS["流程控制"])
makeCodingCard(5, "逻辑运算", "Logic", "sigma", CODING_CAT_ACCENTS["逻辑运算"])
makeCodingCard(6, "事件输入", "Event", "zap", CODING_CAT_ACCENTS["事件输入"])

CODING_ENTRY_H = 32
CODING_ENTRY_GAP = 6

function codingCardEntryList(card)
    local ref = card and codingCardRefs and codingCardRefs[card]
    local name = ref and ref.title0
    return name and CODING_CARD_ENTRIES[name] or nil
end

function codingEntriesTitleFor(kind)
    local spec = CODING_BLOCK_SPECS[kind]
    return spec and spec.title or tostring(kind)
end

function codingEnsureEntriesHost()
    if codingEntriesHost and codingEntriesHost.Parent then return codingEntriesHost end

    codingEntriesHost = create("ScrollingFrame", {
        BackgroundColor3 = theme.surface,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Visible = false,
        ZIndex = 62,
    })
    codingEntriesHost.Name = "codingCardEntries"
    codingEntriesHost.Parent = codingRightPanel
    pcall(function()
        codingEntriesHost:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
            codingEntriesScrollY = codingEntriesHost.CanvasPosition.Y
        end)
    end)
    return codingEntriesHost
end

function codingClearCardEntries()
    for _, row in ipairs(codingEntriesRows or {}) do
        pcall(function() if row and row.Parent then row:Destroy() end end)
    end
    codingEntriesRows = {}
    codingEntriesKind = nil
    codingEntriesHost = codingEntriesHost
    if codingEntriesSizeConn then
        pcall(function() codingEntriesSizeConn:Disconnect() end)
        codingEntriesSizeConn = nil
    end
    pcall(function() if codingEntriesHost then codingEntriesHost.Visible = false end end)
end

function codingLayoutCardEntries()
    local card = codingEntriesCard
    if not (card and card.Parent) then return end
    local host = codingRightPanel
    if not (host and host.Parent) then return end
    if card.Parent ~= host then return end
    local entries = codingCardEntryList(card)
    if not entries then return end
    local veil = codingEntriesHost
    local hAbs = host.AbsolutePosition
    local cAbs, cSize = card.AbsolutePosition, card.AbsoluteSize
    local left = cAbs.X - hAbs.X + card.AnchorPoint.X * cSize.X
    local top = cAbs.Y - hAbs.Y + card.AnchorPoint.Y * cSize.Y
    local ref = codingCardRefs and codingCardRefs[card]
    local titleObj = ref and ref.title
    local capY = top + 44
    if titleObj and titleObj.Parent then
        capY = titleObj.AbsolutePosition.Y - hAbs.Y + titleObj.AbsoluteSize.Y + 8
    end

    local listTop = capY + 6
    local bottomPad = 8
    pcall(function()
        veil.Position = UDim2.fromOffset(left + 8, listTop)
        veil.Size = UDim2.fromOffset(cSize.X - 16, math.max(40, cSize.Y - (listTop - top) - ((ref and ref.colorBar and ref.colorBar.Parent) and 0 or 0) - bottomPad))
    end)
    local y = 4
    for i, row in ipairs(codingEntriesRows) do
        if row and row.Parent then
            row.Position = UDim2.fromOffset(0, y + (i - 1) * (CODING_ENTRY_H + CODING_ENTRY_GAP))
            row.Size = UDim2.new(1, 0, 0, CODING_ENTRY_H)
        end
    end
    local total = (CODING_ENTRY_H + CODING_ENTRY_GAP) * #codingEntriesRows + 8
    pcall(function()
        if veil:IsA("ScrollingFrame") then
            veil.CanvasSize = UDim2.fromOffset(0, total)
        end
    end)
    codingEntriesScrollY = math.clamp(codingEntriesScrollY or 0, 0, math.max(0, total - veil.AbsoluteSize.Y))
    pcall(function()
        if math.abs((veil.CanvasPosition and veil.CanvasPosition.Y or 0) - codingEntriesScrollY) > 1 then
            veil:ScrollTo(codingEntriesScrollY)
        end
    end)
end

function codingScrollEntriesToBottom()
    local veil = codingEntriesHost
    if not (veil and veil.Parent and veil.Visible) then return end
    pcall(function()
        local total = (CODING_ENTRY_H + CODING_ENTRY_GAP) * #codingEntriesRows + 8
        codingEntriesScrollY = math.max(0, total - veil.AbsoluteSize.Y)
        veil:ScrollTo(codingEntriesScrollY)
    end)
end

function codingMakeEntryRow(kind, accent)
    local row = create("TextButton", {
        BackgroundColor3 = theme.surfaceLight,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = 0,
        ZIndex = 70,
    })
    corner(8, row)
    stroke(theme.border, 1, row)
    create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 8, 0.5, 0),
        Size = UDim2.new(0, 3, 0, 13),
        BackgroundColor3 = accent,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        ZIndex = 71,
        Parent = row,
    })
    create("TextLabel", {
        Position = UDim2.new(0, 17, 0, 0),
        Size = UDim2.new(1, -52, 1, 0),
        BackgroundTransparency = 1,
        Text = codingEntriesTitleFor(kind),
        TextColor3 = theme.text,
        TextSize = 12,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 71,
        Parent = row,
    })
    local plus = GetIcon("circle-plus", UDim2.new(0, 15, 0, 15), accent)
    if plus then
        plus.AnchorPoint = Vector2.new(1, 0.5)
        plus.Position = UDim2.new(1, -10, 0.5, 0)
        plus.ZIndex = 72
        plus.Parent = row
    else
        create("TextLabel", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.new(0, 15, 0, 15),
            BackgroundTransparency = 1,
            Text = "+",
            TextColor3 = accent,
            TextSize = 15,
            Font = Enum.Font.SourceSansBold,
            ZIndex = 72,
            Parent = row,
        })
    end
    row.MouseEnter:Connect(function()
        svc.TweenService:Create(row, TweenInfo.new(0.14), { BackgroundTransparency = 0.1 }):Play()
        if plus then svc.TweenService:Create(plus, TweenInfo.new(0.14), { ImageColor3 = theme.text }):Play() end
    end)
    row.MouseLeave:Connect(function()
        svc.TweenService:Create(row, TweenInfo.new(0.18), { BackgroundTransparency = 0.35 }):Play()
        if plus then svc.TweenService:Create(plus, TweenInfo.new(0.18), { ImageColor3 = accent }):Play() end
    end)
    row.MouseButton1Click:Connect(function()
        codingAddBlockToPreview(kind)
    end)
    return row, plus
end

function codingShowCardEntries(card)
    if not (card and card.Parent) then return end
    local kinds = codingCardEntryList(card)
    if not kinds then return end
    codingClearCardEntries()
    local ref = codingCardRefs and codingCardRefs[card]
    local accent = (ref and ref.accent) or CODING_VAR_ACCENT
    local veil = codingEnsureEntriesHost()
    codingEntriesHost = veil
    veil.Visible = true
    for _, ch in ipairs(veil:GetChildren()) do pcall(function() ch:Destroy() end) end
    codingEntriesRows = {}

    for _, kind in ipairs(kinds) do
        local row = codingMakeEntryRow(kind, accent)
        row.Parent = veil
        table.insert(codingEntriesRows, row)
    end

    codingEntriesCard = card
    codingEntriesKind = nil
    codingLayoutCardEntries()
    pcall(function()
        codingEntriesSizeConn = card:GetPropertyChangedSignal("AbsoluteSize"):Connect(codingLayoutCardEntries)
    end)
    if not codingEntriesSizeConn then
        pcall(function()
            codingEntriesSizeConn = svc.RunService.RenderStepped:Connect(codingLayoutCardEntries)
        end)
    end

    veil.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        local startScroll = codingEntriesScrollY or 0
        codingBeginDragObjMove(function(_, dy)
            codingEntriesScrollY = math.max(0, startScroll - dy)
            pcall(function() veil:ScrollTo(codingEntriesScrollY) end)
        end)
    end)
end

function codingShowCards(show, duration)
    if not codingPickerCards then return end
    duration = duration or 0.24
    codingFadeGroup(codingPickerCards, show, duration)
end

local CODING_CARD_TOP_SAFE = 56
local CODING_CARD_MARGIN = 8

local function codingCardExpandedRect(host)
    local hSize = (host and host.AbsoluteSize) or Vector2.new(0, 0)
    local w = math.max(0, hSize.X - CODING_CARD_MARGIN * 2)
    local h = math.max(0, (hSize.Y - CODING_CARD_MARGIN) - CODING_CARD_TOP_SAFE)
    return CODING_CARD_MARGIN, CODING_CARD_TOP_SAFE, w, h
end

local function codingCardCellLocal(card)
    local cont = codingPickerCards
    if not (card and cont) then return 0, 0 end
    local cellW = math.max(0, cont.AbsoluteSize.X * 0.5 - 4)

    local order = card.LayoutOrder
    if type(order) == "number" then
        local idx = math.max(0, order - 1)
        local col = idx % CODING_CELL_COLS
        local row = math.floor(idx / CODING_CELL_COLS)
        return col * (cellW + CODING_CELL_PAD), row * (CODING_CELL_H + CODING_CELL_PAD)
    end
    local ref = codingCardRefs and codingCardRefs[card]
    if ref and ref.origLocalPos then
        return ref.origLocalPos.X, ref.origLocalPos.Y
    end
    return 0, 0
end

function codingCardsScrollY()
    if not codingPickerCards then return 0 end
    local ok, y = pcall(function() return codingPickerCards.CanvasPosition.Y end)
    return (ok and type(y) == "number") and y or 0
end

function codingCardsMetrics()
    if not codingPickerCards then return 0, 0 end
    local ok, viewH, canvasH = pcall(function()
        return codingPickerCards.AbsoluteSize.Y, codingPickerCards.CanvasSize.Y.Offset
    end)
    if not ok then return 0, 0 end
    return viewH or 0, canvasH or 0
end

local function codingCardCellRect(card)
    local cont = codingPickerCards
    if not (card and cont) then return nil end
    local lx, ly = codingCardCellLocal(card)
    local cAbs = cont.AbsolutePosition
    local cellW = math.max(0, cont.AbsoluteSize.X * 0.5 - 4)
    return cAbs.X + lx, cAbs.Y + ly - codingCardsScrollY(), cellW, CODING_CELL_H
end

local function codingCardReturnToCell(card)
    if not (card and codingPickerCards) then return end
    local lx, ly = codingCardCellLocal(card)
    card.AnchorPoint = Vector2.new(0, 0)
    card.Size = UDim2.new(0.5, -4, 0, CODING_CELL_H)
    card.Position = UDim2.fromOffset(lx, ly)
    if card.Parent ~= codingPickerCards then card.Parent = codingPickerCards end
    card.ZIndex = 6
end

local function codingEnsureCardVisible(card)
    if not (card and codingPickerCards) then return end
    pcall(function()
        local _, ly = codingCardCellLocal(card)
        local viewH, canvasH = codingCardsMetrics()
        local maxY = math.max(0, canvasH - viewH)
        local cur = codingCardsScrollY()
        local target = cur
        if ly < cur then
            target = ly
        elseif ly + CODING_CELL_H > cur + viewH then
            target = ly + CODING_CELL_H - viewH
        end
        target = math.clamp(target, 0, maxY)
        if math.abs(target - cur) > 1 then
            codingPickerCards.CanvasPosition = Vector2.new(0, target)
        end
    end)
end

function codingExpandCard(card)
    if not (card and card.Parent) then return end

    pcall(codingCloseAllDropdowns)
    if codingExpandedCard == card then
        codingCollapseCard(card)
        return
    end

    if codingCardAnimLock then
        table.insert(codingCardAnimQueue, {"expand", card})
        return
    end
    codingCardAnimLock = true

    codingFreezeGridSort()

    if codingExpandedCard then
        local prev = codingExpandedCard
        codingExpandedCard = nil
        local prevRef = codingCardRefs[prev]
        if prevRef and prevRef.sub then
            svc.TweenService:Create(prevRef.sub, TweenInfo.new(0.12), {TextTransparency = 0}):Play()
        end

        if prevRef and prevRef.eng and prevRef.eng.Parent then
            svc.TweenService:Create(prevRef.eng, TweenInfo.new(0.12), {TextTransparency = 0}):Play()
        end
        if prev and prev.Parent then

            local pBtn = prevRef and prevRef.collapseBtn
            if pBtn and pBtn.Parent then
                pBtn.Visible = false

                codingResetHoverTintFull(pBtn)
            end
            codingCardReturnToCell(prev)
        end

        local prevColorBar = prevRef and prevRef.colorBar
        if prevColorBar and prevColorBar.Parent then
            prevColorBar.Size = UDim2.new(1, -24, 0, 3)
        end
    end
    codingExpandedCard = card
    local ref = codingCardRefs[card]

    codingClearCardEntries()

    local groupTweens = {}

    for _, other in ipairs(codingPickerCards:GetChildren()) do
        if other ~= card and other:IsA("TextButton") then
            codingFadeGroup(other, false, 0.22)
        end
    end

    if ref and ref.sub then
        local subTween = svc.TweenService:Create(ref.sub, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1})
        groupTweens.sub = subTween
        subTween:Play()
    end

    if ref and ref.eng and ref.eng.Parent then
        local engTween = svc.TweenService:Create(ref.eng, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1})
        groupTweens.eng = engTween
        engTween:Play()
    end

    local absSize = card.AbsoluteSize
    local absPos = card.AbsolutePosition
    local host = codingRightPanel

    if ref then
        ref.origAbsPos = Vector2.new(absPos.X, absPos.Y)
        ref.origSize = Vector2.new(absSize.X, absSize.Y)
        if codingPickerCards then
            local gp = codingPickerCards.AbsolutePosition
            ref.origLocalPos = Vector2.new(absPos.X - gp.X, absPos.Y - gp.Y + codingCardsScrollY())
        end
    end

    for _, sib in ipairs(codingPickerCards:GetChildren()) do
        if sib:IsA("GuiObject") and sib ~= card then
            sib.ZIndex = 5
        end
    end
    card.ZIndex = 60

    if card and card.Parent then
        card.Parent = host
    end

    card.AnchorPoint = Vector2.new(0, 0)
    card.Size = UDim2.fromOffset(absSize.X, absSize.Y)
    card.Position = UDim2.fromOffset(absPos.X - host.AbsolutePosition.X, absPos.Y - host.AbsolutePosition.Y)

    local cBtn = codingCardRefs[card] and codingCardRefs[card].collapseBtn
    if cBtn and cBtn.Parent then
        cBtn.Visible = true
        cBtn.ZIndex = 40
        if cBtn:IsA("GuiObject") then cBtn.Parent = card end
    end

    local colorBar = ref and ref.colorBar
    if colorBar and colorBar.Parent then
        svc.TweenService:Create(colorBar, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, -56, 0, 3),
        }):Play()
    end

    local exX, exY, fullW, fullH = codingCardExpandedRect(host)
    local tw = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local expandTween = svc.TweenService:Create(card, tw, {
        Size = UDim2.fromOffset(fullW, fullH),
        Position = UDim2.fromOffset(exX, exY),
    })
    groupTweens.main = expandTween
    expandTween:Play()

    codingWaitAllTweens(groupTweens, function()
        codingThawGridSort()
        codingCardAnimLock = false

        codingShowCardEntries(card)
        codingCardProcessQueue()
    end)
end

function codingCardProcessQueue()
    if codingCardAnimLock then return end
    local next = table.remove(codingCardAnimQueue, 1)
    if not next then return end
    if next[1] == "expand" then
        codingExpandCard(next[2])
    else
        codingCollapseCard(next[2])
    end
end

function codingCollapseCard(card)
    if codingExpandedCard ~= card then return end

    if codingCardAnimLock then
        table.insert(codingCardAnimQueue, {"collapse", card})
        return
    end
    codingCardAnimLock = true
    codingExpandedCard = nil

    pcall(codingCloseAllDropdowns)
    local ref = codingCardRefs[card]

    codingClearCardEntries()

    local groupTweens = {}

    if ref and ref.sub then
        local subTween = svc.TweenService:Create(ref.sub, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0})
        groupTweens.sub = subTween
        subTween:Play()
    end

    if ref and ref.eng and ref.eng.Parent then
        local engTween = svc.TweenService:Create(ref.eng, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0})
        groupTweens.eng = engTween
        engTween:Play()
    end

    for _, other in ipairs(codingPickerCards:GetChildren()) do
        if other ~= card and other:IsA("TextButton") then
            codingFadeGroup(other, true, 0.2)
        end
    end

    codingFreezeGridSort()

    local finishCollapse
    finishCollapse = function()
        codingWaitAllTweens(groupTweens, function()
            codingThawGridSort()
            codingCardAnimLock = false
            codingCardProcessQueue()
        end)
    end

    local cBtn = codingCardRefs[card] and codingCardRefs[card].collapseBtn
    if cBtn and cBtn.Parent then
        cBtn.Visible = false

        codingResetHoverTintFull(cBtn)
    end

    local colorBar = codingCardRefs[card] and codingCardRefs[card].colorBar
    if colorBar and colorBar.Parent then
        local colorTween = svc.TweenService:Create(colorBar, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {
            Size = UDim2.new(1, -24, 0, 3),
        })
        groupTweens.colorBar = colorTween
        colorTween:Play()
    end
    if not (card and card.Parent) or card.Parent == codingPickerCards or not codingRightPanel then

        pcall(function()
            if card and card.Parent == codingPickerCards then
                codingCardReturnToCell(card)
            end
        end)
        finishCollapse()
        return
    end
    do

        local host = codingRightPanel
        local curAbs, curSize = card.AbsolutePosition, card.AbsoluteSize
        local hostAbs = host.AbsolutePosition
        card.ZIndex = 6
        card.AnchorPoint = Vector2.new(0, 0)
        card.Size = UDim2.fromOffset(curSize.X, curSize.Y)
        card.Position = UDim2.fromOffset(curAbs.X - hostAbs.X, curAbs.Y - hostAbs.Y)

        local cellX, cellY, cellW, cellH = codingCardCellRect(card)
        local props = {Size = UDim2.fromOffset(cellW or curSize.X, cellH or CODING_CELL_H)}
        if cellX then
            props.Position = UDim2.fromOffset(cellX - hostAbs.X, cellY - hostAbs.Y)
        end
        local tw = TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
        local tween = svc.TweenService:Create(card, tw, props)
        groupTweens.retract = tween
        tween:Play()
        tween.Completed:Connect(function()

            if card and card.Parent then
                codingCardReturnToCell(card)

                codingEnsureCardVisible(card)
            end

            finishCollapse()
        end)
    end
end

function codingResetExpandedCard()
    if codingExpandedCard then
        codingCollapseCard(codingExpandedCard)
    end
end

function codingSetCollapseBtnVisible(card, visible)
    if not card then return end
    local cBtn = codingCardRefs[card] and codingCardRefs[card].collapseBtn
    if cBtn and cBtn.Parent then cBtn.Visible = not not visible end
end

codingPickerBusy = false

codingFadeEntries(codingAddBlockBtn)
codingFadeEntries(codingActionSmall)
codingFadeEntries(codingPickerBar)
codingFadeEntries(codingPickerCards)

function codingSetPickerOpen(on)
    if codingPickerBusy or codingPickerOpen == on then return end
    codingPickerOpen = on
    codingPickerBusy = true
    local dur = 0.24
    if on then

        codingPickerBar.Visible = true
        codingFadeGroup(codingPickerBar, true, 0)
        codingShowCards(true, 0)

        codingApplyRightWidth(CODING_RIGHT_W_EXPANDED, dur)
        if codingGridArea and codingGridArea.Parent then
            svc.TweenService:Create(codingGridArea, TweenInfo.new(dur, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                {Size = UDim2.new(1, -CODING_RIGHT_W_EXPANDED - 6, 1, 0)}):Play()
        end

        task.delay(dur + 0.02, function()
            if codingPickerOpen then codingApplySearchWidth() end
        end)

        codingFadeGroup(codingAddBlockBtn, false, dur)
        codingFadeGroup(codingActionSmall, false, dur)
        codingFadeGroup(codingPickerBar, true, dur)
        codingShowCards(true, dur)

        if codingSettingsBtn then codingFadeGroup(codingSettingsBtn, false, dur) end
        task.delay(dur + 0.06, function()
            codingPickerBusy = false
        end)
    else

        codingResetExpandedCard()
        codingFadeGroup(codingPickerBar, false, dur)
        codingShowCards(false, dur)
        pcall(function() codingPickerInput:ReleaseFocus() end)
        task.delay(dur + 0.06, function()
            if not codingPickerOpen then
                codingFadeGroup(codingAddBlockBtn, true, dur)
                codingFadeGroup(codingActionSmall, true, dur)

                if codingSettingsBtn then codingFadeGroup(codingSettingsBtn, true, dur) end
            end
            codingPickerBusy = false
        end)

        codingApplySearchWidth(CODING_RIGHT_W_COLLAPSED)
        task.delay(0.03, function()
            if not codingPickerOpen then
                codingApplyRightWidth(CODING_RIGHT_W_COLLAPSED, dur)
                if codingGridArea and codingGridArea.Parent then
                    svc.TweenService:Create(codingGridArea, TweenInfo.new(dur, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                        {Size = UDim2.new(1, -CODING_RIGHT_W_COLLAPSED - 6, 1, 0)}):Play()
                end
            end
        end)
    end
end

pcall(codingBuildBlockToolbar)

if codingToolRow and not CODING_TOOLROW_FADE_HOOKED then
    CODING_TOOLROW_FADE_HOOKED = true
    local oldSetPickerOpen = codingSetPickerOpen
    codingSetPickerOpen = function(on)
        if on then
            codingFadeGroup(codingToolRow, false, 0.24)
        elseif not codingSettingsMode then
            codingFadeGroup(codingToolRow, true, 0.24)
        end
        if oldSetPickerOpen then oldSetPickerOpen(on) end
    end
end

codingAddBlockBtn.MouseButton1Click:Connect(function()

    if not codingPickerOpen then
        codingRightPanel.Size = UDim2.new(0, CODING_RIGHT_W_COLLAPSED, 1, 0)
        codingGridArea.Size = UDim2.new(1, -CODING_RIGHT_W_COLLAPSED - 6, 1, 0)
    end
    codingSetPickerOpen(true)
end)
codingBackBtn.MouseButton1Click:Connect(function()
    codingSetPickerOpen(false)
end)

codingRegHoverTint(codingBackBtn, { BackgroundColor3 = theme.accent })
codingBackBtn.MouseEnter:Connect(function()
    if codingIsFadedOut(codingBackBtn) then return end
    svc.TweenService:Create(codingBackBtn, TweenInfo.new(0.15), {BackgroundColor3 = theme.accent, BackgroundTransparency = 0.62}):Play()
end)
codingBackBtn.MouseLeave:Connect(function()
    if codingIsFadedOut(codingBackBtn) then return end
    svc.TweenService:Create(codingBackBtn, TweenInfo.new(0.2), {BackgroundColor3 = theme.surface, BackgroundTransparency = 0.2}):Play()
end)
codingAddBlockBtn.MouseEnter:Connect(function()
    if codingIsFadedOut(codingAddBlockBtn) then return end
    svc.TweenService:Create(codingAddBlockBtn, TweenInfo.new(0.16), {BackgroundTransparency = 0}):Play()
end)
codingAddBlockBtn.MouseLeave:Connect(function()
    if codingIsFadedOut(codingAddBlockBtn) then return end
    svc.TweenService:Create(codingAddBlockBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.15}):Play()
end)

codingEnterBtnFading = false
if codingEnterBtn then
    local baseTint = theme.surface
    local baseTransparency = 0.15

    local function resetToBase()
        codingEnterBtnFading = false
        svc.TweenService:Create(codingEnterBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = baseTint,
            BackgroundTransparency = baseTransparency,
        }):Play()
    end
    codingEnterBtn.MouseButton1Click:Connect(function()

        resetToBase()
        enterBuildSpace()
    end)

    codingRegHoverTint(codingEnterBtn, { BackgroundColor3 = theme.accent })
    do
        codingEnterBtn.MouseEnter:Connect(function()
            if codingEnterBtnFading or codingIsFadedOut(codingEnterBtn) then return end
            svc.TweenService:Create(codingEnterBtn, TweenInfo.new(0.15), {BackgroundColor3 = theme.accent, BackgroundTransparency = 0.62}):Play()
        end)
        codingEnterBtn.MouseLeave:Connect(function()
            if codingEnterBtnFading or codingIsFadedOut(codingEnterBtn) then return end
            svc.TweenService:Create(codingEnterBtn, TweenInfo.new(0.2), {BackgroundColor3 = baseTint, BackgroundTransparency = baseTransparency}):Play()
        end)
    end
end

codingSettingsBtn = create("TextButton", {
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 12, 1, -12),
    Size = UDim2.new(1, -24, 0, 40),
    BackgroundColor3 = theme.surface,
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 5,
})
corner(12, codingSettingsBtn)
stroke(theme.border, 1, codingSettingsBtn)
codingSettingsIcon = GetIcon("sliders-horizontal", UDim2.new(0, 15, 0, 15), theme.accent)
if codingSettingsIcon then
    codingSettingsIcon.Position = UDim2.new(0, 12, 0.5, -7)
    codingSettingsIcon.ZIndex = 6
    codingSettingsIcon.Parent = codingSettingsBtn
end
create("TextLabel", {
    Position = UDim2.new(0, (codingSettingsIcon and 34 or 12), 0, 0),
    Size = UDim2.new(1, -(codingSettingsIcon and 42 or 20), 1, 0),
    BackgroundTransparency = 1,
    Text = "附加设置",
    TextColor3 = theme.text,
    TextSize = 13,
    Font = Enum.Font.SourceSansBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 6,
    Parent = codingSettingsBtn,
})
codingSettingsBtn.Parent = codingRightPanel

codingSettingsPanel = create("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = theme.surfaceLight,
    BackgroundTransparency = 0.55,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 12,
})
codingSettingsPanel.Name = "BuildSettings"
corner(theme.radiusLg, codingSettingsPanel)
stroke(theme.border, 1, codingSettingsPanel)
codingSettingsPanel.Parent = codingPage

codingSettingsHeader = create("Frame", {
    Size = UDim2.new(1, 0, 0, 40),
    BackgroundColor3 = theme.surfaceLight,
    BackgroundTransparency = 0.45,
    BorderSizePixel = 0,
    ZIndex = 13,
})
corner(theme.radiusLg, codingSettingsHeader)
codingSettingsHeader.Parent = codingSettingsPanel
local csHeaderIcon = GetIcon("sliders-horizontal", UDim2.new(0, 15, 0, 15), theme.accent)
if csHeaderIcon then
    csHeaderIcon.Position = UDim2.new(0, 14, 0.5, -7)
    csHeaderIcon.ZIndex = 14
    csHeaderIcon.Parent = codingSettingsHeader
end
create("TextLabel", {
    Position = UDim2.new(0, (csHeaderIcon and 36 or 14), 0, 0),
    Size = UDim2.new(1, -90, 1, 0),
    BackgroundTransparency = 1,
    Text = "附加设置",
    TextColor3 = theme.text,
    TextSize = 14,
    Font = Enum.Font.SourceSansBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 14,
    Parent = codingSettingsHeader,
})
codingSettingsExitBtn = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -12, 0.5, 0),
    Size = UDim2.new(0, 88, 0, 30),
    BackgroundColor3 = theme.red,
    BackgroundTransparency = 0.72,
    BorderSizePixel = 0,
    Text = "",
    AutoButtonColor = false,
    ZIndex = 14,
})
corner(15, codingSettingsExitBtn)
stroke(theme.red, 1, codingSettingsExitBtn)
local csExitIcon = GetIcon("log-out", UDim2.new(0, 13, 0, 13), theme.red)
if csExitIcon then
    csExitIcon.Position = UDim2.new(0, 9, 0.5, -6)
    csExitIcon.ZIndex = 15
    csExitIcon.Parent = codingSettingsExitBtn
end
create("TextLabel", {
    Position = UDim2.new(0, (csExitIcon and 26 or 10), 0, 0),
    Size = UDim2.new(1, -(csExitIcon and 34 or 14), 1, 0),
    BackgroundTransparency = 1,
    Text = "退出设置",
    TextColor3 = theme.text,
    TextSize = 12,
    Font = Enum.Font.SourceSansBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 15,
    Parent = codingSettingsExitBtn,
})
codingSettingsExitBtn.Parent = codingSettingsHeader

codingSettingsScroll = create("ScrollingFrame", {
    Position = UDim2.new(0, 14, 0, 52),
    Size = UDim2.new(1, -28, 1, -66),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = theme.textDim,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ZIndex = 13,
})
codingSettingsScroll.Parent = codingSettingsPanel
local csList = create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10)})
csList.Parent = codingSettingsScroll
create("UIPadding", {PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 12)}).Parent = codingSettingsScroll
csList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    if codingSettingsScroll and codingSettingsScroll.Parent then
        local abs = csList.AbsoluteContentSize
        if abs then codingSettingsScroll.CanvasSize = UDim2.new(0, 0, 0, abs.Y + 20) end
    end
end)

local csCard = create("Frame", {
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundColor3 = theme.surfaceLight,
    BackgroundTransparency = 0.55,
    BorderSizePixel = 0,
    LayoutOrder = 1,
    ZIndex = 13,
    Parent = codingSettingsScroll,
})
corner(theme.radiusLg, csCard)
stroke(theme.border, 1, csCard)
local csCardList = create("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 6),
})
csCardList.Parent = csCard
create("UIPadding", {
    PaddingLeft = UDim.new(0, 10),
    PaddingRight = UDim.new(0, 10),
    PaddingTop = UDim.new(0, 8),
    PaddingBottom = UDim.new(0, 10),
}).Parent = csCard
local csCardHeader = create("Frame", {Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = -1, ZIndex = 14})
csCardHeader.Parent = csCard
local csCardAccent = create("Frame", {Size = UDim2.new(0, 3, 0, 14), Position = UDim2.new(0, 2, 0.5, -7), BackgroundColor3 = theme.accent, BorderSizePixel = 0, ZIndex = 15})
applyGradient(csCardAccent, theme.accent, theme.accent2, 90)
corner(2, csCardAccent)
csCardAccent.Parent = csCardHeader
local csCardIcon = GetIcon("sliders-horizontal", UDim2.new(0, 15, 0, 15))
if csCardIcon then
    csCardIcon.Position = UDim2.new(0, 13, 0.5, -7)
    csCardIcon.ImageColor3 = theme.accent
    csCardIcon.Parent = csCardHeader
end
create("TextLabel", {
    Position = UDim2.new(0, csCardIcon and 34 or 12, 0, 0),
    Size = UDim2.new(1, -(csCardIcon and 40 or 20), 1, 0),
    BackgroundTransparency = 1,
    Text = "通用",
    TextColor3 = theme.text,
    TextSize = 13,
    Font = Enum.Font.SourceSansBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 15,
    Parent = csCardHeader,
})

local csPropRow = create("Frame", {
    Size = UDim2.new(1, 0, 0, 54),
    BackgroundColor3 = theme.surface,
    BackgroundTransparency = 0.3,
    BorderSizePixel = 0,
    LayoutOrder = 2,
    ZIndex = 14,
})
corner(12, csPropRow)
create("TextLabel", {
    Position = UDim2.new(0, 16, 0, 8),
    Size = UDim2.new(0.5, -10, 0, 20),
    BackgroundTransparency = 1,
    Text = "属性窗口",
    TextColor3 = theme.text,
    TextSize = 13,
    Font = Enum.Font.SourceSansBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 15,
    Parent = csPropRow,
})
create("TextLabel", {
    Position = UDim2.new(0, 16, 0, 28),
    Size = UDim2.new(0.5, -10, 0, 18),
    BackgroundTransparency = 1,
    Text = "在建造空间内显示属性窗口，跟随对象树的选中项实时刷新",
    TextColor3 = theme.textDim,
    TextSize = 10,
    Font = Enum.Font.SourceSans,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 15,
    Parent = csPropRow,
})
local csPropToggle, csPropGetState = makeToggle(csPropRow, false, function(state)

    propWindowSetVisible(state and buildSpaceActive == true)
end, "propWindow")
csPropRow.Parent = csCard

CODING_PREVIEW_TYPES = { "面板", "视图" }
local csPreviewRow = create("Frame", {
    Size = UDim2.new(1, 0, 0, 54),
    BackgroundColor3 = theme.surface,
    BackgroundTransparency = 0.3,
    BorderSizePixel = 0,
    LayoutOrder = 3,
    ZIndex = 14,
})
corner(12, csPreviewRow)
create("TextLabel", {
    Position = UDim2.new(0, 16, 0, 8),
    Size = UDim2.new(0.5, -10, 0, 20),
    BackgroundTransparency = 1,
    Text = "预览类型",
    TextColor3 = theme.text,
    TextSize = 13,
    Font = Enum.Font.SourceSansBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 15,
    Parent = csPreviewRow,
})
create("TextLabel", {
    Position = UDim2.new(0, 16, 0, 28),
    Size = UDim2.new(0.5, -10, 0, 18),
    BackgroundTransparency = 1,
    Text = "切换积木预览框的呈现方式",
    TextColor3 = theme.textDim,
    TextSize = 10,
    Font = Enum.Font.SourceSans,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 15,
    Parent = csPreviewRow,
})

local csPreviewBtn, csPreviewGet = makeDropdown(csPreviewRow, CODING_PREVIEW_TYPES, 1, function() end, "codingPreviewType")
pcall(function()
    csPreviewBtn.ZIndex = 15
    for _, c in ipairs(csPreviewBtn:GetChildren()) do
        if c:IsA("TextLabel") or c:IsA("ImageLabel") then c.ZIndex = 16 end
    end
end)
csPreviewRow.Parent = csCard

function codingPreviewTypeGet()
    if csPreviewGet then
        local ok, v = pcall(csPreviewGet)
        if ok and type(v) == "string" and v ~= "" then return v end
    end
    return CODING_PREVIEW_TYPES[1]
end

codingFadeEntries(codingSettingsPanel)
codingFadeEntries(codingGridArea)
codingFadeEntries(codingRightPanel)

codingFadeEntries(codingSettingsBtn)

codingSettingsMode = false
codingSettingsBusy = false

function codingOpenSettings()
    if codingSettingsBusy or codingSettingsMode then return end
    codingSettingsMode = true
    codingSettingsBusy = true
    if codingPickerOpen then codingSetPickerOpen(false) end

    if codingSettingsBtn then
        svc.TweenService:Create(codingSettingsBtn, TweenInfo.new(0.1), {BackgroundColor3 = theme.surface, BackgroundTransparency = 0.15}):Play()
    end
    codingFadeGroup(codingGridArea, false, 0.2)
    codingFadeGroup(codingRightPanel, false, 0.2)
    task.delay(0.24, function()
        if codingSettingsMode and codingSettingsPanel then
            codingSettingsPanel.Visible = true
            codingFadeGroup(codingSettingsPanel, true, 0.22)
        end
        codingSettingsBusy = false
    end)
end

function codingCloseSettings()
    if codingSettingsBusy or not codingSettingsMode then return end
    codingSettingsMode = false
    codingSettingsBusy = true

    pcall(codingCloseAllDropdowns)

    if codingSettingsBtn then
        svc.TweenService:Create(codingSettingsBtn, TweenInfo.new(0.1), {BackgroundColor3 = theme.surface, BackgroundTransparency = 0.15}):Play()
    end
    codingFadeGroup(codingSettingsPanel, false, 0.2)
    task.delay(0.24, function()
        if not codingSettingsMode then
            codingFadeGroup(codingGridArea, true, 0.22)
            codingFadeGroup(codingRightPanel, true, 0.22)
        end
        codingSettingsBusy = false
    end)
end

codingSettingsBtn.MouseButton1Click:Connect(function()

    if codingPickerOpen or codingPickerBusy then return end
    codingOpenSettings()
end)

codingRegHoverTint(codingSettingsBtn, { BackgroundColor3 = theme.accent })
codingSettingsBtn.MouseEnter:Connect(function()

    if codingPickerOpen or codingPickerBusy or codingSettingsMode or codingIsFadedOut(codingSettingsBtn) then return end
    svc.TweenService:Create(codingSettingsBtn, TweenInfo.new(0.15), {BackgroundColor3 = theme.accent, BackgroundTransparency = 0.62}):Play()
end)
codingSettingsBtn.MouseLeave:Connect(function()
    if codingIsFadedOut(codingSettingsBtn) then return end
    svc.TweenService:Create(codingSettingsBtn, TweenInfo.new(0.2), {BackgroundColor3 = theme.surface, BackgroundTransparency = 0.15}):Play()
end)
codingSettingsExitBtn.MouseButton1Click:Connect(function()
    codingCloseSettings()
end)
]===]

local function ensureDependencies()
    if not svc then
        svc = {
            Players = game:GetService("Players"),
            UserInputService = game:GetService("UserInputService"),
            CoreGui = game:GetService("CoreGui"),
            ReplicatedStorage = game:GetService("ReplicatedStorage"),
            TweenService = game:GetService("TweenService"),
            RunService = game:GetService("RunService"),
            Stats = game:GetService("Stats"),
            HttpService = game:GetService("HttpService"),
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
    if not obStoredObjects then obStoredObjects = {} end
    if not obStoredObjTexts then obStoredObjTexts = function() return {} end end
    if not buildSpaceActive then buildSpaceActive = false end
    if not AddLog then AddLog = function(msg, lvl) print("[Coding]", msg) end end
    if not currentPage then currentPage = "" end
end

local pageDef = {
    name = "coding_blocks",
    title = "积木编程",
    icon = "blocks",
}

function pageDef.build(frame, helpers)
    ensureDependencies()
    codingPage = frame
    frame.Name = "coding_blocks"

    local fn, err = loadstring(CODING_PAGE_SOURCE, "@coding_blocks")
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
