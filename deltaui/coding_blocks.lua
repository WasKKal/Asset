-- DeltaUI 外部页面：积木编程 (Coding Blocks)
-- 安装方式：DeltaUI 设置 → 页面扩展 → 粘贴 URL / 从官方预设一键安装
-- 注意：需要关闭"页面安全模式"（使用了 game / loadstring / writefile 等 API）
-- CDN: https://cdn.jsdelivr.net/gh/WasKKal/Asset@master/deltaui/coding_blocks.lua

local CODING_PAGE_SOURCE = [===[
function codingObjPropOptions()
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
                    -- 只取白名单内的：对象没了、或枚举失败都静默跳过，
                    -- 绝不能让一处报错毁掉整个下拉（下拉取不到选项会卡住整张卡）
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

-- 左侧预览框 = 可自由滑动/缩放的积木画布；右侧操作栏 = 添加积木 / 进入建造空间 / 运行
codingPage.Name = "coding"

-- ---------- 左侧：原积木树区域（无积木内容） ----------
-- 点击「添加积木」进入选择模式时，右侧操作栏向左展开、左侧预览区相应缩小。
-- 采用固定像素宽度 + 响应式兜底，避免 main 尺寸未最终确定(例如窗口缩放、初始化阶段)
-- 时右侧面板过宽或过窄。宽度的“锚”在面板左边缘，故只需改 Size.X.Offset，
-- Position 保持不变，面板自然向左增长。
local CODING_RIGHT_W_DEFAULT = 280   -- 常态宽度(像素)，未进入「添加积木」时的窄态（已收窄）
local CODING_RIGHT_W_COLLAPSED = CODING_RIGHT_W_DEFAULT  -- 收起态宽度(点击「添加积木」前)，与默认一致
local CODING_RIGHT_W_EXPANDED = 480  -- 进入添加模式后的宽度(像素)，向左吃掉左侧预览区
local CODING_ANIM_DUR = 0.28

codingPickerOpen = false  -- 初始为「未展开」状态，与 codingSetPickerOpen(false) 一致

local function codingGetAvailableWidth()
    -- 以 codingPage 的实际像素宽度为准，缩放窗口时也能自适应
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

-- 搜索框自适应：宽度跟随右侧操作栏内部可用宽度，避免右侧展开后搜索框仍是旧 1/3 宽度。
-- 可选传入 fixedW 时(如收起瞬间)，直接按指定面板宽计算，避免读到正在补间中的中间值。
local function codingApplySearchWidth(fixedW)
    if not (codingPickerSearch and codingRightPanel and codingRightPanel.Parent) then return end
    local panelW = fixedW or codingRightPanel.AbsoluteSize.X
    if panelW <= 0 then
        pcall(function() panelW = codingRightPanel.Size.X.Offset end)
    end
    local inner = math.max(160, panelW - 24)   -- 与 codingPickerBar 的左右 12 边距一致
    codingPickerSearch.Size = UDim2.new(0, inner - 52, 1, 0)  -- 为右侧「返回」按钮留出 44 + 8 间距
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

-- 空状态：无积木时显示 flask-conical 图标 + 说明小字
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

-- ---------- 右侧：操作栏 ----------
-- AnchorPoint 锚定右边缘(1,0)：Position 用 (1,0,0,0) 让右边缘始终贴右边界，
-- 宽度增加时面板向左（屏幕内）展开，而非向右溢出。这是「添加积木向左展开」的关键。
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

-- 预览框是画布视口：卡片放大/平移后会超出，必须裁掉溢出部分，否则会盖到右侧面板上
codingGridArea.ClipsDescendants = true

-- ---------- 积木画布：左侧预览框可自由滑动 / 缩放 ----------
-- 从右侧「分类卡片 → 条目」添加的积木卡都落在预览框里。画布只有两个视图量：
--   z = 缩放倍率，panX/panY = 相对画布中心的像素偏移。
-- 空白处按住左键拖动 = 平移；滚轮 = 以光标为锚点缩放（光标下的内容不跑位）。
-- 缩放刻意不用 UIScale：UIScale 只缩放几何、不缩放 TextSize，缩小时文字会溢出去。
-- 因此每张卡都登记「基准几何 + 基准字号」，统一由 codingApplyBlock 按倍率重算。
-- 积木卡坐标保存为「未缩放像素、原点=画布中心」，所以预览区被右侧面板挤压变窄时不会跑位。
CODING_Z_MIN, CODING_Z_MAX, CODING_Z_STEP = 0.5, 2.0, 0.1
codingView = { z = 1, panX = 0, panY = 0 }
CODING_DROPDOWN_OPEN = 0
codingBlocks = {}
codingBlockSeq = 0
CODING_VAR_ACCENT = Color3.fromRGB(139, 92, 246)   -- 变量类色带同款紫色

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

-- 右下角的倍率指示，同时是「复位视图」按钮（点击复位）
-- 只显示百分数，宽度按内容收窄，不再留一长条空背景
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

-- 沿父链确认控件「真的显示在屏幕上」：自身 Visible=true 还不够，
-- 任一祖先隐藏(如整组淡出后 Visible=false)时它其实并不可见。
local function codingVisibleOnScreen(obj)
    local o = obj
    while o do
        if o:IsA("GuiObject") and not o.Visible then return false end
        o = o.Parent
    end
    return true
end

-- 屏幕点是否落在某个控件的矩形内
local function codingPointInObj(obj, px, py)
    if not (obj and obj.Parent) then return false end
    if not codingVisibleOnScreen(obj) then return false end
    local ok, ap, asz = pcall(function() return obj.AbsolutePosition, obj.AbsoluteSize end)
    if not ok or not ap or not asz then return false end
    if asz.X <= 0 or asz.Y <= 0 then return false end
    return px >= ap.X and px <= ap.X + asz.X and py >= ap.Y and py <= ap.Y + asz.Y
end

-- 【修复「无法缩放」的根因】旧逻辑用 `if propWindow and propWindow.Visible then return end`
-- 屏蔽滚轮。但 obWindow / propWindow 挂在 buildSpaceRoot 下：用户在建造空间里打开过属性窗口
-- 后，配置会把 propWindow.Visible 持久设为 true；回到 coding 页时 buildSpaceRoot 整组隐藏、
-- 子窗口自身的 Visible 仍是 true → 滚轮缩放被永久屏蔽，怎么滚都没反应。
-- 改为「真的可见」+「光标确实落在窗口矩形内」双重判定，只有指针压在浮窗上才让位。
local function codingPointerBlocked(px, py)
    -- 内部任何一步出错都按「不阻挡」处理：守卫的职责是避免误触，
    -- 出错时若按"阻挡"兜底，等于把缩放/平移整个废掉，代价远大于偶尔误缩放。
    local ok, res = pcall(function()
        if obWindow and codingPointInObj(obWindow, px, py) then return true end
        if propWindow and codingPointInObj(propWindow, px, py) then return true end
        if codingSettingsMode and codingSettingsPanel and codingPointInObj(codingSettingsPanel, px, py) then return true end
        return false
    end)
    return (ok and res) or false
end

-- 是否有下拉菜单正展开（含整屏遮罩）。
-- 【自愈】不直接信 CODING_DROPDOWN_OPEN 计数：该计数一旦因积木被删除等异常漏减就会永久 >0，
-- 把缩放/平移全部锁死。这里以「遮罩对象是否真的还挂在树上」为准，顺手清理失效引用。
function codingAnyDropdownOpen()
    local open = false
    local t = _G.__DeltaUI_codingDDVeils
    if t then
        for i = #t, 1, -1 do
            local v = t[i]
            if v and v.Parent then
                open = true
            else
                table.remove(t, i)   -- 已销毁，顺手清掉
            end
        end
    end
    local ov = _G.__DeltaUI_dropdownOverlay
    if ov then
        if ov.Parent then
            open = true
        else
            _G.__DeltaUI_dropdownOverlay = nil  -- 已销毁，清掉残留引用
        end
    end
    -- 自愈：实际已无遮罩、计数却不为 0，说明此前漏减过一次。
    -- 这里直接归零，否则缩放/平移会被一个"幽灵计数"永久锁死。
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

-- 本文件后文会再定义一次 codingApplyBlock（加入「子卡跟随父卡嵌入格」的递归排布），
-- 生效的是后者。两版必须共用同一套几何算法，否则缩放时会同时存在两套不一致的位置。
-- 这里直接委托给 codingApplyBlockGeom，杜绝逻辑再次分叉（旧实现 root 用四舍五入、
-- 子控件用截断，本身就与 Geom 版相反）。
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

-- 积木输入框焦点检测：某张卡的文本框正被编辑时，平移/拖动起手应让位，
-- 否则 CaptureFocus 与 pan 逻辑互相抢占 → 表现就是「只能缩放、无法平移」、
-- 「点了输入框再拖画面完全不动」。遍历所有卡的登记项，命中 TextBox 且在焦点态即返回真。
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

-- 主动结束编辑：清空焦点、让键盘收起；平移起手前若确需抢焦点可调用。默认采用「让位」策略，
-- 故此函数主要给外部快捷键（Esc）和未来调用使用，避免 FocusLost 残留死锁。
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

-- 以屏幕点 (px,py) 为锚改变倍率：光标底下的那点保持不动
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
    -- 同步阻尼目标：否则阻尼循环会拿旧目标把刚设好的倍率又拉回去（捏合等直接调用的场合）
    codingZoomTarget = newZ
    codingApplyView()
end

-- ---------- 视图阻尼：滚轮缩放平滑逼近 + 平移松手惯性 ----------
-- 阻尼【只服务滚轮】：滚轮是离散步进输入，直接跳变倍率会"一格一跳"，
-- 故让 z 指数逼近目标值，每帧仍走 codingZoomAt(锚点) → 锚点补偿连续，视觉平滑推拉。
-- 双指捏合是连续输入，必须 1:1 跟手，走阻尼会恒定滞后（详见 codingPinchCheck 处注释），
-- 因此捏合直接调 codingZoomAt，不进这条管线。
-- 平移同样保持 1:1 跟手（加延迟反而黏手），只在松手后按指数衰减滑一小段再停。
-- 惯性滑行距离 ≈ 初速 × TAU，据此调参：850 × 0.075 ≈ 64px（克制的"轻微"阻尼感）
CODING_DAMP_TAU_ZOOM = 0.11    -- 缩放逼近时间常数(秒)：越小越跟手，越大越绵
CODING_DAMP_TAU_PAN  = 0.075   -- 平移惯性衰减时间常数(秒)：越大滑得越远
CODING_DAMP_PAN_MIN_V = 30     -- 惯性速度低于此值(px/s)即停，避免末尾长时间微动拖尾
CODING_DAMP_MAX_V = 850        -- 惯性初速上限，防止猛甩把画布甩出视野
CODING_DAMP_VEL_WIN = 0.03     -- 测速窗口(秒)：跨满这么久才采样一次速度，抑制高帧率噪声

codingZoomTarget = 1
codingZoomAnchor = nil
codingPanVel = { x = 0, y = 0 }

-- 请求以 (px,py) 为锚点缩放到 targetZ（只记目标，实际位移交给阻尼循环逐帧逼近）
function codingZoomRequest(targetZ, px, py)
    codingZoomTarget = math.clamp(targetZ or codingView.z, CODING_Z_MIN, CODING_Z_MAX)
    if px and py then
        codingZoomAnchor = Vector2.new(px, py)
    elseif not codingZoomAnchor then
        local cx, cy = codingCanvasCenter()
        codingZoomAnchor = Vector2.new(cx, cy)
    end
end

-- 单步阻尼推进，返回本次是否真的改动了视图。dt 为帧间隔(秒)。
function codingDampStep(dt)
    dt = (type(dt) == "number" and dt > 0) and math.min(dt, 0.1) or (1 / 60)
    local moved = false

    -- ① 缩放逼近：每帧都过一遍 codingZoomAt，锚点始终不动
    local tz = codingZoomTarget
    if math.abs(tz - codingView.z) > 0.0004 then
        local k = 1 - math.exp(-dt / CODING_DAMP_TAU_ZOOM)
        local nz = codingView.z + (tz - codingView.z) * k
        if math.abs(tz - nz) < 0.0004 then nz = tz end
        local a = codingZoomAnchor
        -- codingZoomAt 内部会把 target 同步成传入值（供外部直接调用时不回弹）。
        -- 但阻尼逼近走的是"每帧挪一小步"，若让它同步，target 会被逐帧改写成本帧的 nz，
        -- 于是 target-z 恒等于 0 → 倍率再也推不动。故这里调用后把目标原样写回。
        codingZoomAt(nz, a and a.X, a and a.Y)
        codingZoomTarget = tz
        moved = true
    end

    -- ② 平移惯性：拖动中不接管（拖动本身 1:1 跟手），松手后才滑行
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

-- 阻尼主循环。页面不可用时把状态归零，避免切走再回来时画面还在自己滑。
-- 【关键】整段包 pcall：滚轮只负责设目标倍率，真正推进画面的是这个循环。
-- 一旦它因异常被断开连接，画面就再也不会动 → 表现为「滚轮毫无反应」（缩放彻底失效）。
-- 与滚轮/捏合一致，异常必须吞在回调内部，绝不允许冒泡断开连接。
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
    -- 复位时同步清掉阻尼状态，否则惯性/缩放逼近会在复位后继续把画面拉走
    codingZoomTarget = 1
    codingZoomAnchor = nil
    codingPanVel.x, codingPanVel.y = 0, 0
    codingView.z = 1
    codingView.panX = 0
    codingView.panY = 0
    codingApplyView()
end

-- 按住某处开始一段拖拽：move(dx,dy) 收设备像素增量。
-- 用 UserInputService 而不是控件自身的 InputChanged：指针滑出控件矩形后控件级事件会断流，
-- 表现就是「拖到一半卡住」。
-- 拖动一段距离：move(dx,dy) 收设备像素增量。
-- 关键稳健性（修复「拖动某积木后所有控件无法交互」）：
--   1) onMove / onEnd 都套 pcall —— 某些积木（val/arg/embed 等特殊行）在拖动重绘
--      (codingApplyView → codingRefreshBlockChip → spec.chip 等) 路径上一旦报错，
--      错误会冒泡到 InputChanged 处理器，Roblox 会断开该连接，导致 finish() 永远
--      不被调用：headDrag 卡在 true、b.root.ZIndex 永远停在 16、Active=true 的卡
--      悬浮在顶层把下方所有按钮的点击全部吞掉 → 全局控件「假死」。
--   2) 用 RenderStepped 心跳持续检测「主按钮已释放」作为兜底收尾 —— 拖动中积木
--      移动到屏幕外 / Parent 链变化 / 捕获对象变更时，InputEnded 可能根本不来，
--      单靠它不可靠。每帧检查 MouseButton1（鼠标）是否已抬起，抬起即收尾。
-- 接受可选的 startInput：若它是 Touch 输入则走「纯 InputEnded 收尾」（心跳兜底禁用），
-- 避免纯触摸设备上 IsMouseButtonPressed(MouseButton1) 恒为 false 而在首帧误判「已释放」，
-- 进而把正在进行的拖动立刻 finish()、拖动完全失效。
-- 拖动回调签名：onMove(accX, accY, deltaX, deltaY)
--   accX/accY   = 从按下那一刻起的「累计位移」（绝大多数调用方要的就是这个）
--   deltaX/deltaY = 本帧增量（仅在确实需要逐帧增量时使用）
-- 【修复】旧实现只把单帧 inp.Delta 当成 dx/dy 传出去，而画布平移按
--   「起始值 + dx」计算 → 每帧都被重置成「起点 + 这一帧的几像素」，
--   画布永远挪不动，表现为「预览区域无法滑动」。这里统一累计后再回传。
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
        pcall(onEnd)  -- 这里若再报错，连接也已释放，不会死锁
    end
    connMove = uis.InputChanged:Connect(function(inp)
        if finished then return end
        -- 【修复】触摸拖动时引擎发出的是 Touch 而非 MouseMovement，
        -- 旧实现只认 MouseMovement，触屏下 onMove 一次都不触发 → 移动端完全拖不动。
        local ut = inp.UserInputType
        if ut ~= Enum.UserInputType.MouseMovement and ut ~= Enum.UserInputType.Touch then return end
        local dX, dY = 0, 0
        local ok, dxv, dyv = pcall(function() return inp.Delta.X, inp.Delta.Y end)
        if ok and type(dxv) == "number" and type(dyv) == "number" then
            dX, dY = dxv, dyv
        end
        accX, accY = accX + dX, accY + dY
        -- 拖动重绘链路上任何报错都必须被吞掉，绝不能让它冒泡断开 connMove，
        -- 否则 finish() 无法执行 → 全局输入锁死（见函数头注释）。
        pcall(function() onMove(accX, accY, dX, dY) end)
    end)
    connEnd = uis.InputEnded:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 and inp.UserInputType ~= Enum.UserInputType.Touch then return end
        finish()
    end)
    -- 心跳兜底（仅鼠标拖动启用）：每帧检测 MouseButton1 是否仍按下。捕获对象变更 /
    -- 手势丢失导致 InputEnded 不来时，靠此主动收尾，避免 headDrag、ZIndex=16、Active
    -- 遮挡残留而全局锁死。触摸拖动不启用（isTouch 时不注册），完全依赖 InputEnded。
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

-- ---------- 积木卡：定义变量 / 修改变量 / 读取变量 ----------
-- 积木卡是画布上的自由浮层：按住头部可拖动，右上角 x 可删除。
-- 缩放的做法：卡片本身与「行」按基准像素登记（codingReg），重算时把位置/尺寸的像素偏移
-- 与字号一起乘倍率；行内部的控件全部用 Scale 定位，跟着宿主自动缩放，无需登记。
-- 登记一个「按基准像素摆放」的控件；带 TextSize 的控件顺带记录基准字号
-- pos / size 省略时【自动取控件创建时的当前几何】，于是它的 Offset 分量也会随倍率缩放。
-- 【修复「文字位移且比例失衡」】旧实现里 headTitle / chip / 下拉文字都登记成
-- codingReg(b, obj, nil, nil)，只记了字号。可它们的 UDim2 混着 Offset
-- （左内边距 8/10、右内边距 -74/-26，chip 更是纯 Offset 的 68x16），
-- 这些分量不乘 z，而字号却乘了 z → 放大时文字变大、框的内边距与尺寸却不变，
-- 于是文字相对框偏移、字号与框比例失调（z=0.5 时标题可用宽度只剩应有的一半）。
-- 补上几何登记后，Offset 随 z 等比缩放，与字号同步，卡片整体严格等比。
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

-- 丢弃已销毁控件的登记项（切换类型时会重建「值为」控件）
function codingPruneBlock(b)
    for i = #b.eles, 1, -1 do
        local o = b.eles[i].o
        if not (o and o.Parent) then table.remove(b.eles, i) end
    end
end

-- 行内的一个比例格：全部 Scale 定位，缩放时随宿主自动变化
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

-- 只登记字号的控件（几何以 Scale 为主）。
-- 注：codingReg 会自动补上当前几何，故 UDim2 里若混有 Offset（内边距等），
-- 这些 Offset 同样会随倍率缩放 —— 这正是等比所要求的，见 codingReg 处说明。
function codingRegTextOnly(b, obj)
    return codingReg(b, obj, nil, nil)
end

-- 积木卡里的下拉菜单。选项每次展开时现取，所以「变量」下拉能跟着已定义的变量实时变化；
-- 列表挂在 ScreenGui 上，不受卡片裁剪，并且逐帧跟随按钮，平移/缩放时不会脱节。
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
        -- 登记几何：尺寸 12x12 与右偏移 -10 都是 Offset，不随倍率缩放的话
        -- 放大卡片后箭头会显得过小、贴边距离也失准。
        codingReg(b, arrow, nil, nil)
    end
    lbl.Parent = btn
    btn.Parent = cell

    local current = initial or ""
    -- openVeil = 整屏透明遮罩(ZIndex 998)，用于「点空白处关闭下拉」。
    -- 【修复】旧实现只记了 openFrame，close() 从不销毁 openVeil → 选完一项后遮罩永久留在
    -- ScreenGui 里吞掉所有点击，且二次调用因 openFrame 为 nil 直接 return，再无补救路径，
    -- 表现为「下拉里选完一项后整个界面任何按钮都点不动」。遮罩必须与列表一起销毁。
    local openFrame, openFollow, openVeil
    local api
    api = {
        close = function()
            local hadAny = (openFrame ~= nil) or (openFollow ~= nil) or (openVeil ~= nil)
            if openFollow then pcall(function() openFollow:Disconnect() end) end
            if openVeil then
                -- 遮罩还要从全局登记表里摘掉：codingAnyDropdownOpen 以该表为准判定
                -- 「是否真有下拉展开」，漏摘会让缩放/平移误判为被下拉挡住。
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
            -- 统一在读取 hadAny 之后再清空：旧实现先置 nil 再取快照，openFollow 恒为 nil，
            -- 计数可能漏减 → CODING_DROPDOWN_OPEN 永远 >0，滚轮缩放等交互被永久屏蔽。
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

    -- 下拉所属积木被删除时自动收尾：先关遮罩，再从全局表里摘掉自己，避免表无限增长、
    -- 也避免对已销毁按钮反复调用 close。
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
        -- 遮罩登记到全局表：供 codingAnyDropdownOpen 做「是否真有下拉展开」的自愈判定，
        -- 不依赖 CODING_DROPDOWN_OPEN 计数（计数异常时会永久锁死缩放/平移）。
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

-- 关闭所有已打开的下拉(含整屏遮罩)，并把已失效的条目从全局表里清掉。
-- 切分类卡片 / 收起卡片 / 关闭 picker / 切 tab 等场景统一调用：
-- 下拉开着时遮罩会吞掉后续所有点击，这些场景必须先把遮罩撤掉。
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
    -- 计数兜底：表已清空时不应再有"打开中"的下拉
    if #list == 0 then CODING_DROPDOWN_OPEN = 0 end
end

-- 积木卡里的输入框
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

-- 卡片目录：kind = 一种积木；rows 描述每一行的控件；stmt 描述生成什么 Lua。
-- 行 = { "行标签"或nil, 控件1, 控件2 ... }；控件 kind：
--   txt 文本框 · num 数字框 · select 下拉 · value 值编辑器(数字/文本=输入框，其它类型=下拉)
--   arg 表达式(右侧内嵌 fx 菜单，可改成引用某张值积木/某个变量) · embed 嵌入槽(容器卡) · note 灰字
-- 值积木（spec.value）不生成语句，只作为别的卡参数的来源被内联展开。
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
-- 允许直接以「属性原名」写进「设置属性」的候选白名单。
-- 对象树里储存过的对象，其真实属性名只要落在这里就会追加进下拉。
-- 属性浏览器枚举出的往往有上百个（含内部/只读项），全放进来只会淹没列表，
-- 故限定为这几个高频可写属性。
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
-- 分类卡片 -> 条目顺序（卡片标题必须与 makeCodingCard 的第 2 个参数一致）
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



-- ---------- 小工具 ----------
function codingTrim(v)
    return tostring(v == nil and "" or v):gsub("^%s+", ""):gsub("%s+$", "")
end

function codingToString(v)
    if v == nil then return "" end
    return tostring(v)
end

-- Lua 标识符：变量名/函数名/形参直接当代码用，先洗一遍防止破坏语法
-- Luau 允许中文标识符，所以这里只剔掉真正会破坏语法的字符（空白和标点），
-- 用 %w 会把中文一并删光，变量名就全变回退名了。
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

-- 逗号分隔的数字串（位置/颜色用），非法输入退回默认值
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

-- 类型 + 面板原文 -> Lua 字面量
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
    -- 文本
    if v == "" then return '""' end
    if v:sub(1, 1) == '"' or v:sub(1, 1) == "'" then return v end
    return '"' .. v:gsub('"', '\\"') .. '"'
end

-- "workspace.父.子" / "game.A.B" -> 一层层 FindFirstChild，取不到就是 nil
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

-- ---------- 卡片之间互相引用 ----------
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

-- 物体候选：对象树里「储存」过的优先（省得手抄长路径），
-- 再是预览框里「创建物体」做出来过的，最后兜一个通用写法。
function codingObjOptions()
    local out, seen = {}, {}
    local function put(txt)
        if txt and txt ~= "" and not seen[txt] then seen[txt] = true; out[#out + 1] = txt end
    end
    -- 选项每次展开下拉时现取，所以对象树里新储存的立刻就能选到
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

-- fx 菜单的可选项：自由输入 + 所有值积木卡 + 所有已定义变量
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

-- 参数 -> 写进 Lua 的片段；引用值积木时递归内联它的表达式，并防住自引用/环
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

-- 参数在卡片上显示成什么：引用模式直接把来源写进框里，一眼看得出接的是谁
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

-- 引用型参数：输入框只读，改内容请回 fx 菜单，否则用户会以为改了却进不了代码
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

-- 逗号分隔数字串（位置/颜色），非法就退回默认
function codingNumListText(v, fallback)
    local s = codingTrim(v):gsub("%s+", "")
    if s == "" then return fallback or "" end
    for seg in s:gmatch("[^,]+") do
        if not tonumber(seg) then return fallback or "" end
    end
    return (s:gsub(",", ", "))
end

-- 只留中文：重复的符号后缀由卡片右上角的 chip 补上（chip 显示 codingOpSym 的结果），
-- 下拉里再写一遍 "大于等于 >=" 既占宽度又与 chip 重复。
-- 旧的存档值形如 "大于等于 >=" 仍能被 codingOpSym / codingCondOf 正确识别，功能不受影响。
CODING_IF_OPS = { "为真", "等于", "不等于", "大于", "大于等于", "小于", "小于等于" }

-- 「如果」卡的条件：选「为真」时只看左侧表达式本体
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

-- ---------- 目录：一种积木一段声明 ----------
-- rows 的每一行 = { "行标签" 或 nil, {kind=..., field=...}, ... }
--   txt 文本框 | num 数字框 | val 值编辑器(数字/文本=输入框，其它类型=下拉，可选项随类型变)
--   var 已定义变量下拉 | fn 已定义函数下拉 | obj 物体下拉 | dd 固定选项下拉(options)
--   expr 表达式框 + fx 菜单(引用值积木/变量) | embed 嵌入槽 | raw 灰色说明字
CODING_BLOCK_SPECS = {
    -- ===== 变量类 =====
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

    -- ===== Function类 =====
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

    -- ===== 物体类 =====
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
            -- 有映射表按映射走（颜色/位置这类需要包一层构造）；
            -- 没映射的是对象树储存对象的真实属性名，直接按原名赋值，值原样输出。
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

    -- ===== 流程控制 =====
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
        -- chip 显示运算符符号：下拉里是中文（等于/大于等于…），chip 补符号，互补不重复，
        -- 且 "==" / ">=" 很短，正好填满 chip 那 68px。「为真」不参与比较，直接显示原词。
        chip = function(b)
            local op = codingTrim(codingToString(b.data.op))
            if op:find("为真") then return "为真" end
            return codingOpSym(op)
        end,
        rows = {
            -- 条件合并为一行「如果 A 运算符 B」：原来拆成「如果 A 运算符」+「成立 B」两行，
            -- 两个标签语义重复、卡片也偏高（3 行 148px）。合并后 2 行 112px，一眼读全整句。
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

    -- ===== 逻辑运算（全是值积木）=====
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

    -- ===== 事件输入 =====
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

-- 卡片按目录 rows 渲染；所有控件登记「基准像素 + 基准字号」，预览框缩放时统一重算。
CODING_BLOCK_ROW_H = 30
CODING_BLOCK_LABEL_W = 44
CODING_CELL_GAP = 4

-- 缓存每个 host(Frame) 的布局基准值。
-- 不能用 host._baseX 之类直接挂在 Instance 上：Roblox 禁止以下划线开头的属性名，
-- 会报 "_baseX is not a valid member of Frame"。改用弱表以 host 为 key 存储。
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

-- 按比例切一格（内部控件全用 Scale，缩放时自动跟随）
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

-- 值编辑器：数字/文本 -> 输入框；布尔/列表/字典 -> 下拉（可选项随类型变）
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

-- 一行 = 行标签 + 若干单元格；没写 w 的单元格平分剩余宽度
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
        -- 登记式排版要到 codingApplyBlock 才落到 host 上，这里先记住基准值给嵌入格用
        -- 原写法 host._baseX/_baseY/_baseW 会触发 "not a valid member" 报错，改为缓存
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
            -- 「修改变量」选中变量后，值的编辑方式要跟着那个变量的类型走
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

    -- 嵌入槽：容器卡用它收一张语句卡，生成时内联到本卡的代码块里
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

-- ---------- 引用关系：哪些卡正在被引用（删卡时用来提示） ----------
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

-- 引用方的显示框要跟着来源卡的变化刷新
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

-- ---------- 建卡 / 删卡 / 嵌入 / 脱离 ----------
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

-- 初始数据：defaults 里写了函数的（比如「变量2」这种带序号的）建卡时才算
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
    -- 先撤掉该积木上开着的整屏下拉遮罩：它挂在 ScreenGui 上、不属于积木本体，
    -- 不显式关闭就会在积木销毁后继续吞掉所有点击。
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

-- 把语句卡嵌进容器卡：子卡位置从此跟随父卡
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
    -- 先读 parentBlock：写成 `a or a.parentBlock` 这种形式时，a 非 nil 会拿实例去和字符串比较而报错
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

-- 嵌入菜单：只列还没被嵌进别的卡的卡，避免同一张卡被塞进两个地方
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

-- ---------- 卡片外壳：头部（拖动手柄 / 拖出即脱离）+ 角标 + 删除 ----------
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
    -- 标题栏圆角：必须与 b.root 顶部的 corner(12) 匹配，否则直角 header 会盖在
    -- 圆角 root 之上，视觉上表现为「标题栏没有圆角」。同时裁剪子节点（chip/delBtn）
    -- 防止其溢出圆角边缘。
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
    -- 删除按钮与它的叉号图标：尺寸(20x20 / 11x11)与位置偏移(-8)都是纯 Offset，
    -- 不登记的话缩放时它们保持原大小 → 相对卡片越缩越小/越放越大，是「比例失衡」的一部分。
    codingReg(b, b.delBtn, nil, nil)
    if delIcon then codingReg(b, delIcon, nil, nil) end

    -- 按住头部：自由卡 = 搬家；被嵌着的子卡 = 先脱离父卡再搬家（这就是「拖出来」）
    local headDrag = false
    b.header.InputBegan:Connect(function(inp)
        if headDrag then return end
        if not codingIsMouseTouch(inp) or not codingCanvasUsable() then return end
        -- 文本框正在编辑时，首下点击属于「结束编辑 / 放置光标」，不能当成拖动起手：
        -- 否则 CaptureFocus 后紧接着 pan 逻辑抢走指针，输入框焦点既没清、pan 也没真正起手，
        -- 表现为「点了输入框再想平移 → 完全不动」。这里直接放行给文本框处理。
        if codingBlockHasFocusedInput(b) then return end
        -- 防御性复位（与 PanCatcher 同源）：单指/鼠标按下即说明双指缩放已结束，
        -- 清除可能残留的 pinch 标志位，避免它永久屏蔽拖动 → 全局控件锁死。
        if inp.UserInputType ~= Enum.UserInputType.Touch then
            codingPinchActive = false
        end
        -- 双指缩放手势活跃时，不把第一根指头当作拖拽起手，否则 header（Active 的
        -- TextButton）会抢占 Touch 事件，导致第二根指头到来时 pinch 无法识别。
        if codingPinchActive then return end
        local dp, dsz = b.delBtn.AbsolutePosition, b.delBtn.AbsoluteSize
        if inp.Position.X >= dp.X and inp.Position.X <= dp.X + dsz.X
            and inp.Position.Y >= dp.Y and inp.Position.Y <= dp.Y + dsz.Y then
            return
        end
        headDrag = true
        b.root.ZIndex = 16
        codingDetachBody(b)
        -- 用「按下时的世界坐标 + 累计位移 / 缩放」定位：逐帧增量叠加会随丢帧而漂移，
        -- 累计式则始终与指针严格对应。
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

    -- 卡身右键：也能把这张卡从父卡里拿出来（卡片被挡住时比抓头部好点）
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

-- 点分类条目 = 往预览框放一张卡；通知文案按需求固定
function codingAddBlockToPreview(kind)
    local b = codingCreateBlock(kind)
    if not b then return nil end
    ShowNotification("已添加到预览框", 1)
    if b.spec.cat and codingEntriesCard and codingCardEntryList(codingEntriesCard) then
        codingScrollEntriesToBottom()
    end
    return b
end


-- 画布状态只有 z（缩放倍率）与 panX/panY（相对画布中心的像素偏移）。
-- 积木卡记的是「未缩放像素」的世界坐标（x/y = 卡片中心相对画布中心），
-- 显示时统一：屏幕位置 = 画布中心 + pan + 世界坐标 * z，所以缩放/平移只是重算，不会漂。
-- 嵌在父卡里的子卡：世界坐标由父卡的嵌入格算出来，父卡一动子卡就跟 ▲（拖动子卡则自动脱离）。

-- codingCanvas 保持 Passive（Active=false），空白处的点击交给下面的平移垫片：
-- 实测 Active 遮罩式拖动画布不稳，改成「透明 TextButton 兜底接收点击」是本项目里验证过的做法。
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

-- 只保留登记项的几何重算（父卡排布时先定位、再逐层往下算）
function codingApplyBlockGeom(b)
    local z = codingView.z
    -- 【统一四舍五入】旧实现里 root 用 floor(v+0.5)、子控件用 floor(v) 截断，两者不一致；
    -- 且截断对负 Offset（右/下内边距写法 (1,-74,...)）会系统性偏向 -∞，误差恒为单向的
    -- 0~1px，并随 z 连续变化 → 缩放时卡内元素相对本体来回漂移。统一后误差降为 ±0.5px 双向。
    local function rp(v) return math.floor(v + 0.5) end
    b.root.Position = UDim2.new(0.5, rp(codingView.panX + b.x * z), 0.5, rp(codingView.panY + b.y * z))
    b.root.Size = UDim2.fromOffset(rp(b.w * z), rp(b.h * z))
    for _, e in ipairs(b.eles) do
        local o = e.o
        if o and o.Parent then
            -- 只重算 Offset 分量，Scale 分量保持不动：Scale 会由父级缩放自动带上倍率，
            -- 这样「混合 UDim2」也能严格等比（像素 = Scale*父基准*z + Offset*z）。
            if e.pos then
                o.Position = UDim2.new(e.pos.X.Scale, rp(e.pos.X.Offset * z), e.pos.Y.Scale, rp(e.pos.Y.Offset * z))
            end
            if e.size then
                o.Size = UDim2.new(e.size.X.Scale, rp(e.size.X.Offset * z), e.size.Y.Scale, rp(e.size.Y.Offset * z))
            end
            if e.ts then
                -- 字号量化由 0.5 台阶细化到 0.25：0.5 台阶在基准字号 12 时相当于 4% 的突跳，
                -- 而同帧的框体是连续缩放的，两者不同步 → 文字在框内轻微跳动。
                -- 下限由 5 降到 4：z 最小 0.5，基准字号 9~11 的控件正好落在 4.5~5.5，
                -- 被 5 抬住后文字会相对卡片偏大，破坏等比。
                pcall(function() o.TextSize = math.max(4, math.floor(e.ts * z * 4) / 4) end)
            end
        end
    end
end

-- 覆盖前面那版：加入「子卡跟随父卡嵌入格」的递归排布
function codingApplyBlock(b, depth)
    if not (b and b.root and b.root.Parent) then return end
    codingApplyBlockGeom(b)
    -- 子卡沿父卡嵌入格一层层往下挂，层数上限只是防脏数据死循环
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
    -- 父卡销毁后可能留下「认父但父不认它」的子卡，这里把它们放回自由摆放
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

-- 平移：按住空白处，用「按下时的指针位置 + 累计位移」，比逐帧增量稳（也不会拖动时抖动）
function codingStartPanFrom(inputObj)
    if codingPanDrag then return end
    local startPanX, startPanY = codingView.panX, codingView.panY
    local movedOnce = false
    -- 起手先掐掉惯性，否则上一次的余速会和本次拖动叠加
    codingPanVel.x, codingPanVel.y = 0, 0
    -- 拖动过程 1:1 跟手（加平滑会发黏），同时用「位移差 / 时间差」估算瞬时速度，
    -- 松手后交给阻尼循环做一小段惯性滑行。用指数平滑抹掉单帧抖动。
    local lastT = os.clock()
    -- 速度估计用「跨窗口的平均速度」而非逐帧 Δ/Δt。
    -- 【修复惯性过大】逐帧估算在高帧率下会被严重放大：144Hz 时单帧 dt≈0.007s，
    -- 同样移动 4px 会被算成 570px/s，而 60Hz 下只有 240px/s —— 帧率越高惯性越夸张。
    -- 现在至少要跨满 CODING_DAMP_VEL_WIN(30ms) 才采样一次，速度稳定且可预期。
    local velT = lastT          -- 上次采样速度的时刻
    local velDx, velDy = 0, 0   -- 上次采样时的累计位移
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
            -- 指数平滑：新样本权重 0.6，兼顾跟手与抗抖
            codingPanVel.x = (codingPanVel.x or 0) * 0.4 + vx * 0.6
            codingPanVel.y = (codingPanVel.y or 0) * 0.4 + vy * 0.6
        end
        lastT = now
    end, function()
        codingPanDrag = nil
        -- 松手前已静止（按住不动再松开）→ 不该有惯性，直接归零
        if (os.clock() - lastT) > 0.09 then
            codingPanVel.x, codingPanVel.y = 0, 0
        else
            -- 限制初速，避免猛甩一下把画布甩出视野（滑行距离 ≈ 初速 × TAU）
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
    -- 同滚轮：回调内异常会断开连接 → 平移永久失效，故整段 pcall 兜住
    pcall(function()
    if not codingIsMouseTouch(inp) or not codingCanvasUsable() then return end
    -- 有积木内输入框正持有焦点：让点击优先用于「结束编辑 / 点击定位」，不抢平移。
    -- 不在这里强清焦点，避免正在输入时被突然打断；用户点空白或按 Esc 自行结束编辑即可。
    if codingAnyBlockInputFocused() then return end
    -- 防御性复位：鼠标按下 / 单指按下 都说明双指缩放已不可能进行中，
    -- 强制清除可能残留的 pinch 标志位（计数器漏计数等极端情况下的自愈），
    -- 避免标志位卡 true 导致全局平移/拖动被永久屏蔽。
    -- （鼠标不可能产生 pinch；单指 Touch 已在 TouchEnded 计数器处复位，此处再兜底一次）
    if inp.UserInputType ~= Enum.UserInputType.Touch then
        codingPinchActive = false
    end
    -- 双指捏合缩放期间（手势已被捏合接管），不启动平移，避免与缩放抢同一批
    -- 触控点导致「添加积木后无法缩放」：积木的 header/root 是 Active 的 TextButton，
    -- 会优先收到 Touch 事件并冒泡到 PanCatcher，把 pinch 吞掉。这里显式让位。
    if codingPinchActive then return end
    local mp = inp.Position
    -- 双击空白 = 复位视图
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
        -- 有积木输入框正被编辑时，把首下点击交给输入框（结束编辑/选词），不启动平移，
        -- 否则 CaptureFocus 与 pan 起手互相抢占 → 平移卡死、输入框也无法正常操作。
        if codingAnyBlockInputFocused() then return end
        -- 防御性复位：鼠标按下说明双指缩放已不可能进行中
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

-- 滚轮：光标必须落在预览框里；压在浮窗上 / 下拉展开时才让位（均按"真实可见 + 命中矩形"判定）
-- 【关键】整个回调体再用一层 pcall 包住。Roblox 中连接回调抛异常会【断开该连接】，
-- 一旦断开，此后所有滚轮事件都收不到 → 表现为「缩放彻底失灵且再也无法恢复」。
-- 守卫里要遍历父链读 IsA/Visible、遍历全局表，任何一环都可能对已销毁对象报错；
-- 因此必须把异常吞在回调内部，且守卫出错时按「不阻挡」处理——
-- 宁可偶尔误缩放，也绝不能让异常把缩放功能整个废掉。
pcall(function()
    svc.UserInputService.InputChanged:Connect(function(inp)
        pcall(function()
            if inp.UserInputType ~= Enum.UserInputType.MouseWheel then return end
            if not codingCanvasUsable() then return end
            -- 光标位置：优先用事件自带坐标，缺失时回落到鼠标位置，避免坐标为 0 误判在画布外
            local px, py = inp.Position.X, inp.Position.Y
            if (not px) or (not py) or (px == 0 and py == 0) then
                local ok, ml = pcall(function() return svc.UserInputService:GetMouseLocation() end)
                if ok and ml then px, py = ml.X, ml.Y end
            end
            if not codingPointInCanvas(px, py) then return end
            -- 守卫失败 = 放行（默认不阻挡）
            local blocked = false
            pcall(function() blocked = codingPointerBlocked(px, py) and true or false end)
            if blocked then return end
            local ddOpen = false
            pcall(function() ddOpen = codingAnyDropdownOpen() and true or false end)
            if ddOpen then return end
            -- 滚动方向：Position.Z 在部分执行器里恒为 0，逐级回落到 Delta.Z，最后才给默认值，
            -- 避免"方向永远判定为缩小"这类只朝一个方向走的问题。
            local dir = inp.Position.Z
            if type(dir) ~= "number" or dir == 0 then
                local ok, dz = pcall(function() return inp.Delta.Z end)
                if ok and type(dz) == "number" and dz ~= 0 then dir = dz end
            end
            if type(dir) ~= "number" or dir == 0 then dir = 1 end
            -- 以当前光标为锚点：阻尼循环会逐帧走 codingZoomAt，光标下的内容始终不跑位
            codingZoomRequest(codingZoomTarget + (dir > 0 and CODING_Z_STEP or -CODING_Z_STEP), px, py)
        end)
    end)
end)

-- ---------- 移动端双指捏合缩放（自实现，不依赖引擎手势） ----------
-- 【为什么不再用 uis.TouchPinch】
-- 原实现完全依赖引擎的 TouchPinch 事件，而它在移动端极不可靠：
--   · 积木卡的 header/root 是 Active 的 TextButton，会先把 Touch 事件吃掉，
--     TouchPinch 经常根本不派发（本文件上方原有注释也记载了这点）；
--   · 部分执行器 / 低端机压根不发这个事件。
-- 手机端又没有滚轮 → TouchPinch 一旦失效，手机上就彻底无法缩放。
-- 改为直接用 UserInputService 的 Touch 系列事件自行追踪活跃触控点，
-- 不依赖任何手势识别，可靠性由自己保证；PC 端滚轮走的是同一条缩放管线。
pcall(function()
    local uis = svc.UserInputService

    codingTouchMap = {}        -- [InputObject] = {x, y, t}；同一手指的事件共用同一 InputObject 实例
    codingPinchDist = nil      -- 上一次采样的两指间距(nil = 尚未进入捏合)
    codingPinchActive = false
    local CODING_TOUCH_STALE = 5   -- 手指「超时未更新」判定(秒)

    -- 收集活跃触控点，顺手剔除陈旧记录。
    -- 【必须清理】TouchEnded 携带的 InputObject 未必与 TouchStarted 是同一实例
    -- （执行器差异），一旦对不上就会删不掉 → 手指记录泄漏 →
    -- 永远满足「≥2 指」→ 捏合永久激活 → 平移/拖动被无期限屏蔽（旧实现的经典死锁）。
    -- 加时间戳兜底后，即使 TouchEnded 完全收不到，5 秒后也会自动失效。
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

    -- 取跨度最大的一对手指（>2 指时最稳），返回 距离 + 两点坐标
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

    -- 退出捏合：清空基准与标志位。所有分支都必须走这里，避免标志位卡 true
    -- 把全局平移 / 积木拖动永久屏蔽（旧实现就栽在这上面）。
    function codingResetPinchState()
        codingPinchDist = nil
        codingPinchActive = false
    end

    -- 第二指落下时，若单指平移正在进行必须立刻掐掉：
    -- 否则平移会继续吃掉 InputChanged 改写 pan，画面一边缩一边跑。
    local function codingAbortPanForPinch()
        pcall(function() if codingPanDrag then codingPanDrag() end end)
        codingPanDrag = nil
        codingPanVel.x, codingPanVel.y = 0, 0
    end

    -- 每次触控点变化都调用：≥2 指则推进缩放，<2 指则立即退出捏合。
    local function codingPinchCheck()
        pcall(function()
            local dist, ax, ay, bx, by = codingPinchPair()
            if not dist or dist < 1 then
                codingResetPinchState()
                return
            end
            local cx, cy = (ax + bx) * 0.5, (ay + by) * 0.5
            -- 两根手指都必须落在预览区内：手指压在别的 UI 上滑动不该缩放画布
            if not (codingPointInCanvas(ax, ay) and codingPointInCanvas(bx, by)) then
                codingResetPinchState()
                return
            end
            if not codingCanvasUsable() then
                codingResetPinchState()
                return
            end
            -- 浮窗 / 下拉 / 设置页抢占：与滚轮同源的「真实可见 + 命中矩形」判定
            if codingPointerBlocked(cx, cy) or codingAnyDropdownOpen() then
                codingResetPinchState()
                return
            end
            codingPinchActive = true
            if not codingPinchDist then
                -- 首帧只记基准，不缩放：避免第二指落下瞬间的倍率跳变
                codingPinchDist = dist
                codingAbortPanForPinch()
                return
            end
            local ratio = dist / codingPinchDist
            codingPinchDist = dist
            if math.abs(ratio - 1) < 0.002 then return end
            -- 【修复「双指缩放过慢」】这里必须直接调 codingZoomAt 做 1:1 跟手，
            -- 不能走滚轮那条阻尼管线：阻尼是以时间常数 τ≈0.11s「追赶目标」，
            -- 手指匀速张开时倍率会恒定落后约 τ（实测落后 6%+），
            -- 且手指每帧都在改目标，阻尼永远追不上 → 手感明显迟钝、跟不上手指。
            -- 手指本身是连续输入（不像滚轮是离散步进），本就该精确跟手；
            -- 阻尼只用于滚轮那种一格一跳的输入。
            codingZoomAt(codingView.z * ratio, cx, cy)
        end)
    end

    -- 回调内异常会断开连接 → 触控永久失灵，故每个回调都整段 pcall 兜住
    local function codingTouchSet(inp)
        codingTouchMap[inp] = { x = inp.Position.X, y = inp.Position.Y, t = os.clock() }
    end
    uis.TouchStarted:Connect(function(inp)
        pcall(function()
            codingTouchSet(inp)
            -- 有新手指落下就丢弃旧基准：否则两指跨度会突变，倍率跟着跳一下
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
            -- 手指数一变就丢弃基准：抬起第三指时跨度突变会让倍率跳一下
            codingPinchDist = nil
            if n < 2 then codingPinchActive = false end
        end)
    end
    uis.TouchEnded:Connect(onTouchGone)
    uis.TouchCanceled:Connect(onTouchGone)
end)

-- 切换页面 / 进入建造空间时把视图恢复成默认，回来时不会被上次的偏移绕晕
function codingResetViewIfHidden()
    if currentPage ~= "coding" then
        -- 连同触控追踪一起清干净：残留的手指记录会让下次回到本页时
        -- 误判成「正在捏合」，从而屏蔽平移。
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


-- 生成规则：顶层卡按添加顺序排；容器卡把嵌进来的子卡代码整体缩进一级。
-- 值积木不单独成语句，只有被别的卡用 fx 引用时才把表达式内联进去 ——
-- 这样「比较」「随机数」这类卡不会凭空变成一条 print，也不会被漏掉。
-- 一张卡（含它的子卡链）-> 若干行
-- 值积木被别人用 fx 引用时，就不再单独生成一条 print（否则一份逻辑出现两次）
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
        -- 纯值积木只是参数来源；没人引用它时才打一次，免得画布上摆着却什么都没生成
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

-- 把代码用 -- 注释拼成一行，保证永远是一行合法 Lua
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

-- ---------- 复制到剪贴板 ----------
-- 剪贴板 API 在各执行器中的全局名不一致，这里做穷举探测 + 详细日志，
-- 解决「API 确实存在但提示无法复制、退回本地存档」的问题。
-- 常见情况：setclipboard 存在但第一次调用因线程上下文报错（pcall 吞掉），
-- 此时换一个别名或延迟一帧重试往往能成功。
CODING_CLIP_FNS = {
    "setclipboard", "toclipboard", "setClipboard", "SetClipboard",
    "toClipboard", "writeclipboard", "set_clipboard", "copy",
    "Clipboard", "setToClipboard", "writeToClipboard",
}

-- 诊断信息：列出各剪贴板 API 的可用情况。
-- 复制流程已不再向控制台输出任何内容，故本函数当前无人调用；
-- 保留在此供手动排查（如需查看，在控制台自行执行 print(codingClipboardDiagnose())）。
-- 关键：探测时不再只查 _G 表，而是同时查 getgenv() 与裸标识符解析；
-- 很多执行器（含 Delta）的 setclipboard 通过 _ENV 查找链暴露，_G[name] 读出来是 nil，
-- 但裸调用 setclipboard(...) 完全正常——这正是「对象树复制能用、积木复制提示不可用」的根因。
function codingClipboardDiagnose()
    local info = {}
    local env = getgenv and getgenv() or _G
    for _, name in ipairs(CODING_CLIP_FNS) do
        local v = env[name]
        info[#info + 1] = name .. " = " .. type(v)
    end
    if env.syn then info[#info + 1] = "syn.setclipboard = " .. type(env.syn.setclipboard) end
    if env.clipboard then info[#info + 1] = "clipboard.set = " .. type(env.clipboard.set) end
    -- 直接报告「裸标识符是否可解析」，这才是真正决定成败的
    local rawKind = type(setclipboard)
    info[#info + 1] = "裸标识符 setclipboard = " .. rawKind
    return table.concat(info, " | ")
end

-- 取得「写入系统剪贴板」函数，优先级：
--   1) 裸标识符 setclipboard / toclipboard（执行器内置，_G 里往往读不到，但能调用）
--   2) getgenv() / _G 里的扁平别名
--   3) syn.setclipboard、clipboard.set 命名空间
-- 与对象树复制路径 obCopyText 保持完全一致的成功策略。
local function codingResolveClipFn()
    -- 1) 裸标识符（最关键，对象树就是靠它成功的）
    local bare = setclipboard or toclipboard
    if type(bare) == "function" then return bare end
    -- 2) getgenv() / _G（含 syn、clipboard 命名空间）
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

-- 单次尝试：解析到函数就调用，不预先用「_G 里是 nil」来否决
-- 注：成功/失败一律不再写控制台（原本每次复制都会刷一屏探测信息），
-- 结果只通过 ShowNotification 反馈给用户。
function codingTryClipboard(text)
    local f = codingResolveClipFn()
    if type(f) ~= "function" then return false end
    local ok = pcall(f, text)
    return ok == true
end

function codingCopyToClipboard(text)
    -- 尝试 1：在当前上下文直接调用（对象树 obCopyText 的等效路径）
    if codingTryClipboard(text) then return true end
    -- 尝试 2：延后一帧到主循环再调（部分执行器不允许在 input 回调内写剪贴板）
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

-- ---------- 工具条：进入建造空间按钮下方 ----------
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

    -- 复制为 Lua 脚本。
    -- 与对象树「复制路径」共用同一成功策略：优先裸标识符同步调用，失败再延后重试。
    -- 注意：这里不能只依赖 codingCopyToClipboard 内部的 task.spawn 忙等——
    -- 若调用瞬间裸 setclipboard 尚不可用，先在【当前帧同步】强制试一次（对象树就是这么成的），
    -- 再走带延迟重试的完整流程兜底。
    local copyBtn = toolBtn(0, 0.7, "复制为 Lua 脚本", "copy", theme.accent)
    copyBtn.MouseButton1Click:Connect(function()
        local code, rootCount = codingCompileBlocks()
        if not code then
            ShowNotification("预览框里还没有积木", 2)
            return
        end
        -- 强制同步裸调用：与 obCopyText 完全等价的成功路径
        -- 整条复制链路不再向控制台输出任何内容（既不再 dump 生成的代码，
        -- 也不再打印剪贴板探测/成败日志），结果只通过 ShowNotification 反馈。
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
        -- 完整流程（含延后一帧重试 + getgenv 探测）
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

    -- 清空画布
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

    -- 「运行」现在先把积木翻成 Lua 再执行：先转换，运行的是转换结果
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


-- 渐隐 / 渐显：记录原始透明度，整棵子树一起补间
codingFadeBase = codingFadeBase or setmetatable({}, {__mode = "k"})
codingFadeCache = codingFadeCache or setmetatable({}, {__mode = "k"})

-- 读取某个透明度属性；控件不支持该属性时返回 nil（Frame 没有 TextTransparency 等）
local function codingProp(obj, name)
    local ok, val = pcall(function() return obj[name] end)
    if ok and type(val) == "number" then return val end
    return nil
end

-- 记录(或取回)某控件的“常态透明度”。
-- 关键修复：是否淡出文字不再用 IsA("BaseLabel")/IsA("GuiButton") 这类继承名去猜——
-- TextLabel 在部分环境下并不匹配这两个类名，导致它的 TextTransparency 从未被记录，
-- 结果就是「背景淡出了、文字还杵在那儿」。改成直接探测控件有没有 TextTransparency 属性，
-- TextLabel / TextButton / TextBox 以及任何带文字的控件都能覆盖到。
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

-- 收集 root 自身 + 全部子控件中“有透明度可言”的对象。每次淡入淡出都重新遍历一遍，
-- 这样运行期间新建的子节点(分类卡片、搜索结果等)也不会漏掉文字渐隐。
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

-- 正处于“已淡出”状态的控件：沿父链向上查，只要任一祖先组被整组淡隐，子控件也算淡出。
-- 用于让悬停高亮在淡出窗口期内失效，否则 MouseEnter 会与淡出补间抢写同一个属性，
-- 出现“背景半途停住、文字已经消失”的错位。
codingFadeOutRoots = {}

function codingIsFadedOut(obj)
    local o = obj
    while o do
        if codingFadeOutRoots[o] then return true end
        o = o.Parent
    end
    return false
end

-- ---------- 悬停高亮登记：统一复位，杜绝「按钮卡在蓝色 = 一直被按住」 ----------
-- 背景色（BackgroundColor3 / TextColor3 / ImageColor3）【不在】codingFadeGroup 的管理范围内
-- —— 它只补间各类 Transparency。而各按钮的 MouseLeave 开头都有
-- `if codingIsFadedOut(btn) then return end` 之类的守卫（为使淡出期间不被反复改写透明度），
-- 于是「悬停中淡出」时连「背景色复位」也被一并跳过；淡入时 fadeGroup 又只恢复透明度、
-- 不管颜色 → 按钮永久停在 accent(蓝色) 高亮上，看起来就是「被按住没释放」。
-- 解法：在 codingFadeGroup 淡出这一刻统一把登记的悬停颜色复位。
-- 与守卫并不冲突：这里只写颜色、不碰 Transparency，不会与淡出补间抢同一个属性。
codingHoverTint = codingHoverTint or {}   -- [按钮] = 常态属性表

-- 登记一个「悬停会改属性」的按钮；常态值直接取登记时刻的当前属性，
-- 免得与 create() 里的初值写两遍、写不一致。
function codingRegHoverTint(btn, enterProps)
    if not btn then return end
    local base = {}
    for k in pairs(enterProps or {}) do
        local ok, v = pcall(function() return btn[k] end)
        if ok then base[k] = v end
    end
    codingHoverTint[btn] = base
end

-- 只复位「颜色类」属性（供淡出时调用，绝不能碰 Transparency，否则与淡出补间打架）
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

-- 复位全部登记属性（含 Transparency）：用于「按钮被直接隐藏」等非淡出场景，
-- 此时没有淡出补间在跑，可以安全地连同透明度一起恢复。
function codingResetHoverTintFull(btn)
    local base = codingHoverTint and btn and codingHoverTint[btn]
    if not base then return end
    pcall(function()
        if not btn.Parent then return end
        svc.TweenService:Create(btn, TweenInfo.new(0.15), base):Play()
    end)
end

-- 整组淡出时：把该组（含自身与全部后代）内的悬停高亮复位为常态
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
    -- 注意：不能写 `show and nil or true`，nil 为假值会让该表达式恒为 true
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
    -- 滚动条不参与透明度渐隐，必须单独开关：否则容器淡出后仍挂着一根滚动条。
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
        -- root 自身在淡出结束后 Visible=false，但仍在树上；子节点需确保未被销毁再补间。
        if o == root or o.Parent then
            apply(o, "BackgroundTransparency", b.bg)
            apply(o, "TextTransparency", b.text)
            apply(o, "ImageTransparency", b.image)
            if b.strokeObj then apply(b.strokeObj, "Transparency", b.stroke) end
        end
    end
    if not show then
        -- 【修复「按钮卡在蓝色 / 一直像被按住」】整组淡出时把组内的悬停高亮统一复位。
        -- 各按钮的 MouseLeave 都带着 codingIsFadedOut 守卫，淡出期间会跳过复位，
        -- 而背景色又不在本函数的补间范围内 → 颜色会永久残留。此处补上这一环。
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

-- ---------- 添加模式：搜索框 + 返回按钮（与三个操作按钮互斥显示） ----------
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

-- 右侧面板宽度改变(窗口缩放 / 展开收起)时，搜索框跟随自适应
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

-- ---------- 添加模式：分类卡片（搜索栏下方，每行两张） ----------
-- 三张卡片依次为「变量类」、「Function类」、「物体类」；展开后卡片内会排开该分类可添加的积木条目。
-- 卡片本体统一用面板底色，仅靠顶部一条分类色带区分类型。
local CODING_CARD_PURPLE = Color3.fromRGB(139, 92, 246)

-- 卡片动画串行化：自动排序(UIGridLayout.LayoutOrder)与展开/收起补间共用同一布局状态，
-- 若动画尚未结束就触发下一次(切换卡片 / 快速点击 / 收起)，卡片会同时处于「网格内 + 补间中」，
-- 导致 UIGridLayout 与 Tween 抢写 Size/Position，出现两卡片动画重叠、跳变、错位。
-- 用一把锁 + 一个待执行请求队列，保证任意时刻只有一组动画在跑。
codingCardAnimLock = false
codingCardAnimQueue = {}

-- 卡片容器：位于搜索栏(12,12,高36)下方，两列网格自动换行

-- 网格排序冻结引用计数：动画(展开/收起 + 其它卡片的淡入淡出)是跨多帧的复合过程，
-- 期间网格容器里同时存在「摘出 / 放回 / 淡入 / 淡出」多种状态。
-- UIGridLayout 是「每渲染帧都按 LayoutOrder 重排」的布局器，若动画期间让它持续参与排序，
-- 就会在动画中途逐帧重排 → 表现为「队列顺序(卡片视觉排列)在动画过程中不断改变」。
-- 因此在动画的整个生命周期内把 UIGridLayout 临时禁用，动画彻底结束后再恢复，
-- 让网格只做一次最终态重排，从根本上冻结动画期间的排序顺序。
-- 用引用计数：展开/收起各 Freeze 一次、结束后各 Thaw 一次，计数归零才真正解冻，
-- 保证「展开 + 收起」嵌套 / 快速切换(队列串行多组)场景下整段动画只解冻一次，
-- 绝不会在组边界或中途过早解冻而再次触发逐帧重排。
-- 动画期间冻结 UIGridLayout 排序的实现方式：
-- UIGridLayout 没有 Enabled 属性(直接写会报"Enabled is not a valid member")，
-- 因此采用「把布局器从容器中移除，动画结束后再重建重挂」的方式彻底冻结排序。
-- 引用计数保证嵌套/快速切换期间只在整段动画的首尾各操作一次。
local codingGridSortRefCount = 0
local codingSavedGridProps = nil -- 保存被移除网格的原始属性，供重建时还原
-- 前向声明：codingThawGridSort 在其后调用 codingCardWaitLayoutStable，而后者在更后面才定义为 local；
-- 若不提前声明，codingThawGridSort 函数体内的引用会被当作全局变量 → 运行时报 attempt to call a nil value
local codingCardWaitLayoutStable

-- 网格单元格常量（与下方 UIGridLayout 的 CellSize / CellPadding 保持一致）。
-- 提前定义是因为 codingFreezeGridSort 也需要按行列把卡片位置落盘。
local CODING_CELL_H = 88              -- 单元格高
local CODING_CELL_PAD = 8             -- 单元格间距
local CODING_CELL_COLS = 2            -- 列数（CellSize.X = 0.5,-4 ⇒ 恒为 2 列）

local function codingSaveGridProps(grid)
    -- 仅保存重建所需的关键属性(CellSize/CellPadding 等)，避免持有失效实例
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
        -- 【修复】摘掉 UIGridLayout 会让 AutomaticCanvasSize 把画布缩回去，
        -- CanvasPosition 随即被钳制为 0；先存下来，解冻后滚回原位，避免列表跳回顶部。
        codingSavedCanvasY = codingCardsScrollY()
        -- 【修复】UIGridLayout 是虚拟布局，从不改写子对象的 Position 属性；
        -- 摘掉它之后所有卡片会退回 Position(0,0) 叠在一起、画布高度随之塌陷。
        -- 故冻结前先把每张卡的格位写进 Position，冻结期间布局与画布高度都保持稳定。
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
        -- 首次冻结：把 UIGridLayout 从容器中移除，使其完全不参与布局
        local grid = codingPickerCards:FindFirstChildOfClass("UIGridLayout")
        if grid then
            codingSavedGridProps = codingSaveGridProps(grid)
            grid:Destroy()
        else
            codingSavedGridProps = nil
        end
    end
end

-- 解冻引用计数。仅当计数归零时才真正重建并挂回排序布局(触发一次最终态重排)，
-- 故「展开→收起→再展开」等快速切换期间网格始终缺席，顺序完全恒定；
-- 等队列清空、整段动画彻底结束、所有补间完成后才一次性归位。
local function codingThawGridSort()
    if codingGridSortRefCount <= 0 then
        codingGridSortRefCount = 0
        return
    end
    codingGridSortRefCount = codingGridSortRefCount - 1
    if codingGridSortRefCount == 0 then
        -- 等待布局稳定后再重建，确保残余补间(淡入淡出)都已停，只做一次最终重排
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
            -- 画布高度要等布局重算完才准确，再等一次稳定帧才把滚动位置滚回去
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

-- 等待布局稳定：让 UIGridLayout 完成一次自动排序重排 + AutomaticSize 重算高度。
-- 必须在「放回网格 / 摘出网格」等关键帧之后调用，否则后续动画会与此时的重排并发 → 卡片重叠。
-- 用两帧 Heartbeat 而非单次 task.defer，确保布局帧与尺寸(AutomaticSize.Y)都已刷新。
-- 注意：此处是赋值给前向声明的 codingCardWaitLayoutStable，不能再写 local function，
-- 否则会新建一个遮蔽局部变量，前向声明处(被 codingThawGridSort 捕获)仍是 nil。
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

-- 等待一组补间全部完成后回调。动画是否"结束"应以「最长的那一条补间」为准，
-- 而非只看主展开/收起 tween(其它卡片的淡入淡出 codingFadeGroup 长达 0.2~0.22s，
-- 与主补间 0.28~0.3s 相当)，否则按主 tween 提前解冻/释放锁，残余淡入淡出仍在改写属性，
-- UIGridLayout 又会逐帧重排 → 队列顺序在动画尾部仍改变。
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
            -- 【修复】对 callback 做 nil 保护：当外部传入的回调为 nil 时（例如调用方未提供、
            -- 或已被提前清空），绝不调用，避免 "attempt to call nil value"。
            -- 这正是报错栈中 codingWaitAllTweens -> check (12579) 的崩溃点：
            -- 兜底路径（pcall 失败立即 check / task.delay 超时 check）触发 done>=pending 时，
            -- 若 callback 为 nil 就会在此处崩溃。加保护后静默忽略，行为安全且可预期。
            if callback then callback() end
        end
    end
    for _, tw in pairs(tweens) do
        local ok, conn = pcall(function()
            return tw.Completed:Connect(check)
        end)
        if not ok or not conn then
            -- 补间已结束或无效，按完成计入
            check()
        else
            -- 【修复】补间可能已经完成（Completed 事件是过去事件，Connect 后不会再次触发）。
            -- 收起等场景下 groupTweens 里所有补间在调用本函数时都已结束，
            -- 若此处不立即按完成计入，callback 将永不触发 → codingThawGridSort 不执行 →
            -- UIGridLayout 不重建 → 收起后所有卡片重叠。
            local ok2, st = pcall(function() return tw.PlaybackState end)
            if ok2 and st == Enum.PlaybackState.Completed then
                check()
            end
        end
    end
    -- 兜底：对每个补间单独设置超时，确保即使 Completed 事件已过去/丢失也必然全部计入。
    -- 多余的 check 由 fired 标志保护，callback 只调用一次，无副作用。
    for _, tw in pairs(tweens) do
        local info = tw and tw.TweenInfo
        task.delay((info and info.Time or 0) + 0.1, check)
    end
end

-- 六个分类卡片的容器改为 ScrollingFrame：内容超出面板高度时上下滑动，
-- 不再像旧版(Frame + AutomaticSize.Y)那样把容器撑高、让最后两张卡溢出面板底部。
codingPickerCards = create("ScrollingFrame", {
    Position = UDim2.new(0, 12, 0, 56),
    -- 高度锁在面板内(顶部安全区 56 + 底部留白 8)，不再随内容增长
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

-- 【关键】ScrollingFrame 子元素的 UDim Scale 是相对 CanvasSize 计算的，
-- 若 CanvasSize.X 保持 0，UIGridLayout 的 CellSize(0.5,-4) 会算成宽度 0 → 卡片全部塌缩。
-- 故把 CanvasSize.X 用「视口像素宽」写死，并随容器宽度(面板展开/收起)同步更新。
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

-- 建一张分类卡片：order 决定排列顺序，accent 只用于顶部色带与图标着色
local CARD_BG_TRANSPARENCY = 0.25
-- 卡片展开动画状态：refs 存每张卡片的标题/描述引用，expandedCard 记录当前展开中的卡片
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

    -- 顶部分类色带：卡片唯一的颜色标识。
    -- 收起态保持全宽；仅在「展开时」由 codingExpandCard 临时缩短右端以避让收起按钮，
    -- 收起动画中再由 codingCollapseCard 恢复全宽。这样常态线条完整、展开态不重叠。
    local colorBar = create("Frame", {
        Position = UDim2.new(0, 12, 0, 10),
        Size = UDim2.new(1, -24, 0, 3),  -- 收起态：全宽（左右各留 12 边距）
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
    -- 分类英文小字：贴在卡片左下角。展开时随其他描述一起渐隐、收起时渐显。
    -- 收起态它是卡片的副标题，展开态卡片变成全屏面板、只留标题，故需要隐去。
    local engLabel
    if subtitle and subtitle ~= "" then
        engLabel = create("TextLabel", {
            -- 左下角：X 与图标/标题同一起始边距，Y 用底边定位(卡片高 88，底留 8 → 上边缘 64)
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

    -- 手动收起按钮：仅在卡片展开态显示，固定在其右上角，点击即收起。
    -- 归属 card 而非右栏，随卡片 AnchorPoint 一起移动，不会出现“按钮留在原地、卡片缩走”的错位。
    local collapseBtn = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        -- 收起按钮恢复原位(右上角 Y=8)。常态下色带是全宽的，会与按钮右上角重叠；
        -- 因此改为「展开时」由 codingExpandCard 把色带右端缩短避让，收起时恢复全宽。
        -- 这样按钮原位不动、线条常态完整，仅在展开态短暂缩短，两者永不重合。
        Position = UDim2.new(1, -8, 0, 8),
        Size = UDim2.new(0, 26, 0, 26),
        BackgroundColor3 = Color3.fromRGB(30, 36, 52),
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Visible = false,                 -- 默认隐藏，展开时由 codingExpandCard 显示
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
    -- 登记常态透明度。点击收起后按钮会被隐藏，MouseLeave 因 Visible 守卫跳过复位，
    -- 下次展开时它会以「全不透明」的悬停态出现，看起来像一直被按住。
    codingRegHoverTint(collapseBtn, { BackgroundTransparency = 0 })
    -- 卡片若被销毁，同步摘掉登记项，避免 codingHoverTint 持有失效实例并无限增长
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
        -- 仅作“收起”用途：卡片未展开时忽略，避免与卡片本体的展开点击互相冲突。
        if codingExpandedCard == card then
            codingCollapseCard(card)
        end
    end)
    -- 收起按钮引用统一存放在 codingCardRefs[card].collapseBtn（不通过 SetAttribute 存 Instance，
    -- 因为 Instance 不是 Attributes 支持的属性类型，会导致“Instance is not a supported attribute type”报错）。

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
    -- 点击卡片：展开动画（其他卡片渐隐、本卡向右下展开、标题保留、描述渐隐）；再点一次收起
    card.MouseButton1Click:Connect(function()
        if codingPickerBusy or codingSettingsMode then return end
        codingExpandCard(card)
    end)

    card.Parent = codingPickerCards
    codingCardRefs[card] = { title = titleLabel, collapseBtn = collapseBtn, colorBar = colorBar,
        eng = engLabel,
        -- title0/accent 供「展开后的条目列表」查表与配色（见 codingCardEntryList）
        title0 = title, accent = accent }
    return card
end

-- 第一张：变量类（紫色色带）
makeCodingCard(1, "变量类", "Variable", "variable", CODING_CARD_PURPLE)
-- 第二张：Function类
makeCodingCard(2, "Function类", "Function", "braces", theme.accent)
-- 第三张：物体类（排第二行第一列）
makeCodingCard(3, "物体类", "Object", "box", theme.green)
-- 新增三张分类卡：条目取自 CODING_CARD_ENTRIES，色带颜色就是分类色
makeCodingCard(4, "流程控制", "Flow", "repeat", CODING_CAT_ACCENTS["流程控制"])
makeCodingCard(5, "逻辑运算", "Logic", "sigma", CODING_CAT_ACCENTS["逻辑运算"])
makeCodingCard(6, "事件输入", "Event", "zap", CODING_CAT_ACCENTS["事件输入"])

-- 卡片随 picker 一起渐隐渐显：duration 为 0 时表示立刻显示/隐藏
-- 条目排在展开卡的标题下面，往下堆叠；右侧 circle-plus，点一条就往左侧预览框放一张积木卡。
-- 整个条目层挂在 codingRightPanel 上（不进 codingPickerCards，否则会被网格排序/裁剪搞乱），
-- 用 ScrollingFrame 裁住卡片矩形：条目多、窗口矮时能上下滑动，也不会溢出到卡片外。
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
    -- 卡片是右栏的子节点，条目层做成「卡片内」的裁剪视口才滑得动
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

-- 条目层贴进展开卡的矩形内；卡片被钉在面板角落，所以左上角要按锚点反算
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
    -- 提示行已移除：条目区直接从标题下方起排，不再为它预留 20px
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

    -- 条目列表顶部的提示文字（可添加的积木 · …）已移除

    for _, kind in ipairs(kinds) do
        local row = codingMakeEntryRow(kind, accent)
        row.Parent = veil
        table.insert(codingEntriesRows, row)
    end

    -- 条目列表底部的「＋ 添加积木」按钮已移除

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
    -- 条目层自己也能拖动滑动（触屏 / 不想用滚轮时）
    -- 条目多到一屏放不下时，按住列表拖动也能滑
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

-- ---------- 卡片展开动画：点击后其他卡片渐隐、本卡向右下展开、标题保留/描述渐隐 ----------
-- 展开时把卡片从网格摘出挂到右侧面板上自由补间；收起时放回网格，由 UIGridLayout 自动复位。

-- ---------- 展开 / 收起共用的两个目标矩形 ----------
-- 标题栏（codingAddBlockBtn）位于面板顶部 Y=12~48，卡片网格 codingPickerCards 从 Y=56 起。
-- 约定：展开矩形一律不得侵入 Y < CODING_CARD_TOP_SAFE 的顶部安全区，从根源避免覆盖标题栏。
local CODING_CARD_TOP_SAFE = 56        -- 顶部安全边距（与 codingPickerCards.Position.Y 一致）
local CODING_CARD_MARGIN = 8          -- 展开矩形到面板四边的留白

-- 【修复】展开/收起一律改用「矩形到矩形」的补间：统一锚点 (0,0) + 纯像素 Size，
-- 同时补间 Position 与 Size。旧实现把卡片钉在某个角落、只补间 Size，收起时又要
-- 按锚点反算 Position，符号与尺寸都算错 → 卡片收起时飞到第一格甚至飞出面板。
-- 展开矩形（host = codingRightPanel 的本地坐标，单位像素）
local function codingCardExpandedRect(host)
    local hSize = (host and host.AbsoluteSize) or Vector2.new(0, 0)
    local w = math.max(0, hSize.X - CODING_CARD_MARGIN * 2)
    local h = math.max(0, (hSize.Y - CODING_CARD_MARGIN) - CODING_CARD_TOP_SAFE)
    return CODING_CARD_MARGIN, CODING_CARD_TOP_SAFE, w, h
end

-- 卡片在自己网格中的「画布局部坐标」(不含滚动偏移)。
-- 展开时若已快照过就用快照(面板宽度变化后行列位置仍准确)；缺失时按 LayoutOrder 反推行列。
local function codingCardCellLocal(card)
    local cont = codingPickerCards
    if not (card and cont) then return 0, 0 end
    local cellW = math.max(0, cont.AbsoluteSize.X * 0.5 - 4)
    -- 【优先按 LayoutOrder 现算】UIGridLayout 的 SortOrder=LayoutOrder，卡片归位后的
    -- 真实位置就由它决定；用当前容器宽度现算，面板宽度变化后也一致，
    -- 避免"补间终点按旧宽度算、UIGridLayout 恢复后又微调"造成的收起末段抖动。
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

-- 容器当前滚动偏移 Y（非 ScrollingFrame 时为 0）。
-- 【注意】必须是全局函数：codingFreezeGridSort 定义在其之前，若声明为 local，
-- 那里会解析成全局变量而取到 nil。
function codingCardsScrollY()
    if not codingPickerCards then return 0 end
    local ok, y = pcall(function() return codingPickerCards.CanvasPosition.Y end)
    return (ok and type(y) == "number") and y or 0
end

-- 容器可视高度 / 画布高度（供滚动到可见用）
function codingCardsMetrics()
    if not codingPickerCards then return 0, 0 end
    local ok, viewH, canvasH = pcall(function()
        return codingPickerCards.AbsoluteSize.Y, codingPickerCards.CanvasSize.Y.Offset
    end)
    if not ok then return 0, 0 end
    return viewH or 0, canvasH or 0
end

-- 格子矩形的「屏幕绝对坐标」：画布局部坐标要减掉当前滚动偏移，才是真实屏幕位置。
local function codingCardCellRect(card)
    local cont = codingPickerCards
    if not (card and cont) then return nil end
    local lx, ly = codingCardCellLocal(card)
    local cAbs = cont.AbsolutePosition
    local cellW = math.max(0, cont.AbsoluteSize.X * 0.5 - 4)
    return cAbs.X + lx, cAbs.Y + ly - codingCardsScrollY(), cellW, CODING_CELL_H
end

-- 把卡片一次性放回「自己那一格」并交回网格容器。
-- Position 用画布局部坐标(不含滚动)，否则容器滚动后卡片会整体偏移一个滚动量。
local function codingCardReturnToCell(card)
    if not (card and codingPickerCards) then return end
    local lx, ly = codingCardCellLocal(card)
    card.AnchorPoint = Vector2.new(0, 0)
    card.Size = UDim2.new(0.5, -4, 0, CODING_CELL_H)
    card.Position = UDim2.fromOffset(lx, ly)
    if card.Parent ~= codingPickerCards then card.Parent = codingPickerCards end
    card.ZIndex = 6
end

-- 收起完成后若卡片落在可视区之外，把容器滚到刚好露出它，避免「收起后卡片不见了」。
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
    -- 【修复】先撤掉可能开着的整屏下拉遮罩：它 ZIndex=998 会吞掉后续所有点击，
    -- 若带着遮罩切卡，动画期间与动画结束后界面都会失去响应。
    pcall(codingCloseAllDropdowns)
    if codingExpandedCard == card then
        codingCollapseCard(card)
        return
    end
    -- 动画锁：上一组展开/收起尚未结束时，把本次请求入队，等当前动画完成后再串行执行。
    -- 这从根本上杜绝「切换卡片 / 快速点击」导致的多组动画并发、自动排序抢布局。
    if codingCardAnimLock then
        table.insert(codingCardAnimQueue, {"expand", card})
        return
    end
    codingCardAnimLock = true
    -- 【修复】上一张收回 + 新卡摘出 + 主补间 + 其它卡片淡出 整段必须处于冻结态，
    -- 故在「处理上一张」之前就冻结排序。否则上一张 prev.Parent = codingPickerCards 放回网格时，
    -- 网格仍处于启用态、会立即重排其它卡片 → 「切换卡片时队列顺序先跳一下」。
    -- 引用计数保证：若网格已被外层(收起组等)冻结，本 Freeze 只累加计数、不重复禁用。
    codingFreezeGridSort()
    -- 若上一张卡片仍在展开，先静默收回（不恢复其他卡片，避免闪烁）
    if codingExpandedCard then
        local prev = codingExpandedCard
        codingExpandedCard = nil
        local prevRef = codingCardRefs[prev]
        if prevRef and prevRef.sub then
            svc.TweenService:Create(prevRef.sub, TweenInfo.new(0.12), {TextTransparency = 0}):Play()
        end
        -- 切换卡片：上一张的英文小字要立刻渐显回来（它随卡片一起缩回网格）
        if prevRef and prevRef.eng and prevRef.eng.Parent then
            svc.TweenService:Create(prevRef.eng, TweenInfo.new(0.12), {TextTransparency = 0}):Play()
        end
        if prev and prev.Parent then
            -- 【修复】交回网格前必须把尺寸 / 锚点 / 位置全部复位到「自己那一格」：
            -- 旧实现只改了父级与锚点，prev 仍带着展开态的满屏尺寸和角落坐标，
            -- 会把网格容器撑高、卡片本体溢出面板 → 「上一张卡片飞出窗口」。
            local pBtn = prevRef and prevRef.collapseBtn
            if pBtn and pBtn.Parent then
                pBtn.Visible = false
                -- 隐藏前复位悬停态：它此刻可能正停在「全不透明」的悬停态上
                codingResetHoverTintFull(pBtn)
            end
            codingCardReturnToCell(prev)
        end
        -- 切到新卡片前，先把上一张的色带恢复为全宽，避免残留缩短态
        local prevColorBar = prevRef and prevRef.colorBar
        if prevColorBar and prevColorBar.Parent then
            prevColorBar.Size = UDim2.new(1, -24, 0, 3)
        end
    end
    codingExpandedCard = card
    local ref = codingCardRefs[card]
    -- 换卡时先清掉上一张卡叠的条目，新卡的条目在展开动画结束后再铺
    codingClearCardEntries()

    -- 注：Freeze 已在上方「处理上一张收回」之前调用一次；整个展开组(收回 + 摘出 + 主补间 + 淡出)
    -- 都运行在冻结态。此处不再重复 Freeze，避免引用计数 >  thaw 次数导致网格永冻。
    -- 与之配对的 Thaw 位于本组所有补间完成后的 codingWaitAllTweens 回调中。

    -- 收集本组所有补间，用于判断「整组动画何时真正结束」(见下方 expandTween 处)
    local groupTweens = {}

    -- 其他卡片渐隐
    for _, other in ipairs(codingPickerCards:GetChildren()) do
        if other ~= card and other:IsA("TextButton") then
            codingFadeGroup(other, false, 0.22)
        end
    end
    -- 描述渐隐（标题保留）
    if ref and ref.sub then
        local subTween = svc.TweenService:Create(ref.sub, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1})
        groupTweens.sub = subTween
        subTween:Play()
    end
    -- 分类英文小字同步渐隐（与描述同一节奏）：展开成全屏面板后只留标题
    if ref and ref.eng and ref.eng.Parent then
        local engTween = svc.TweenService:Create(ref.eng, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1})
        groupTweens.eng = engTween
        engTween:Play()
    end

    -- 摘出网格，挂到右侧面板自由布局：先按当前屏幕矩形对齐(尺寸=原尺寸)，
    -- 再把 Position/Size 一起补间到展开矩形。
    local absSize = card.AbsoluteSize
    local absPos = card.AbsolutePosition
    local host = codingRightPanel
    -- 快照「原位」：此时卡片仍在网格中，AbsolutePosition 即网格分配给它的单元格左上角。
    -- 局部坐标要存「画布坐标」(屏幕坐标 - 容器位置 + 滚动偏移)，
    -- 这样收起时无论容器滚到哪、面板宽高怎么变，都能精确回到自己那一格。
    if ref then
        ref.origAbsPos = Vector2.new(absPos.X, absPos.Y)
        ref.origSize = Vector2.new(absSize.X, absSize.Y)
        if codingPickerCards then
            local gp = codingPickerCards.AbsolutePosition
            ref.origLocalPos = Vector2.new(absPos.X - gp.X, absPos.Y - gp.Y + codingCardsScrollY())
        end
    end
    -- 【修复】摘出网格前，先把展开卡抬到最高层级，并压低其它卡片层级，
    -- 从根源避免「自动排序重排」过程中绘制层级交叉导致的视觉重叠。
    for _, sib in ipairs(codingPickerCards:GetChildren()) do
        if sib:IsA("GuiObject") and sib ~= card then
            sib.ZIndex = 5  -- 其它卡片统一压到中层
        end
    end
    card.ZIndex = 60  -- 展开卡最高层，覆盖所有兄弟卡片

    -- 排序已冻结(UIGridLayout 已从容器移除)，网格在动画期间不再重排，
    -- 故「上一张复位 + 新卡摘出」不会抢布局，直接摘出即可，无需再延帧等待。
    if card and card.Parent then
        card.Parent = host
    end
    -- 【修复】换父级后必须把「屏幕矩形」换算成 host 本地坐标再写回，
    -- 否则卡片会因坐标系变化瞬间跳一段(旧实现即如此，展开开头有明显瞬移)。
    card.AnchorPoint = Vector2.new(0, 0)
    card.Size = UDim2.fromOffset(absSize.X, absSize.Y)
    card.Position = UDim2.fromOffset(absPos.X - host.AbsolutePosition.X, absPos.Y - host.AbsolutePosition.Y)

    -- 显示手动收起按钮：归属 card 会随 AnchorPoint/Position 一起移动，始终贴在卡片右上角
    local cBtn = codingCardRefs[card] and codingCardRefs[card].collapseBtn
    if cBtn and cBtn.Parent then
        cBtn.Visible = true
        cBtn.ZIndex = 40
        if cBtn:IsA("GuiObject") then cBtn.Parent = card end
    end

    -- 展开态：收起按钮回到原位(右上角)会与全宽色带右端重叠，故将色带右端缩短避让。
    -- 色带左端仍固定在 x=12，仅右端从 宽-12 缩至 宽-44（留白约 32px 给 26px 按钮及间隙）。
    -- 收起时由 codingCollapseCard 恢复全宽，保证「线条常态完整、展开态不重叠」。
    local colorBar = ref and ref.colorBar
    if colorBar and colorBar.Parent then
        svc.TweenService:Create(colorBar, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, -56, 0, 3),
        }):Play()
    end

    -- 展开 = 从「自己那一格」补间到展开矩形：位置与尺寸一起补间，路径连续、无瞬移；
    -- 收起 = 同一条路径反向补间，两者严格对称。
    local exX, exY, fullW, fullH = codingCardExpandedRect(host)
    local tw = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local expandTween = svc.TweenService:Create(card, tw, {
        Size = UDim2.fromOffset(fullW, fullH),
        Position = UDim2.fromOffset(exX, exY),
    })
    groupTweens.main = expandTween
    expandTween:Play()
    -- 展开补间完成后才释放动画锁并消费队列。若不等展开结束就响应下一次点击，
    -- 上一张卡片还未稳定、网格又立即重排，就会出现「展开与收起动画重叠」。
    -- 【修复】以「主补间 + 其它卡片淡出」这组补间全部完成作为整组动画结束的判据，
    -- 并在结束后解冻网格排序(触发一次最终态重排)。仅按主 tween 提前解冻会让残余淡出
    -- 期间 UIGridLayout 再次逐帧重排 → 「队列顺序在动画尾部仍改变」。
    codingWaitAllTweens(groupTweens, function()
        codingThawGridSort()
        codingCardAnimLock = false
        -- 展开到位后再铺条目：卡片尺寸是补间出来的，提前铺会按中间态定位而错位
        codingShowCardEntries(card)
        codingCardProcessQueue()
    end)
end

-- 消费排队的展开/收起请求：保证自动排序重排布局与卡片动画严格串行，
-- 彻底消除「快速切换 / 连点」导致的多组动画并发、卡片位置重叠。
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
    -- 动画锁：收起是「补间 + 放回网格」的复合过程，放回瞬间 UIGridLayout 会按 LayoutOrder
    -- 立即重排其余卡片；若此时又触发展开，新卡片摘出 + 旧卡片复位会同时抢布局 → 动画重叠。
    -- 因此收起期间锁住，新请求入队串行执行。
    if codingCardAnimLock then
        table.insert(codingCardAnimQueue, {"collapse", card})
        return
    end
    codingCardAnimLock = true
    codingExpandedCard = nil
    -- 【修复】收起前先撤掉整屏下拉遮罩，避免遮罩残留导致收起后界面无响应
    pcall(codingCloseAllDropdowns)
    local ref = codingCardRefs[card]
    -- 条目列表叠在面板上、不属于卡片，收起时必须显式清掉
    codingClearCardEntries()
    -- 收集本组所有补间，作为「整组收起动画结束」的判据(见缩回补间 Completed 处)
    local groupTweens = {}
    -- 描述渐显（与收起缩回并行，节奏一致）
    if ref and ref.sub then
        local subTween = svc.TweenService:Create(ref.sub, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0})
        groupTweens.sub = subTween
        subTween:Play()
    end
    -- 分类英文小字同步渐显（与缩回并行）：卡片回到网格态，副标题重新出现
    if ref and ref.eng and ref.eng.Parent then
        local engTween = svc.TweenService:Create(ref.eng, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0})
        groupTweens.eng = engTween
        engTween:Play()
    end
    -- 其他卡片渐显
    for _, other in ipairs(codingPickerCards:GetChildren()) do
        if other ~= card and other:IsA("TextButton") then
            codingFadeGroup(other, true, 0.2)
        end
    end
    -- 【修复】收起动画(缩回 + 色带恢复 + 其它卡片淡入)开始前冻结网格排序。
    -- 冻结时卡片已摘出在面板 host 上、不在网格中，网格只剩其它(正在淡入的)卡片；
    -- 冻结保证这些淡入卡片在动画期间不被 UIGridLayout 逐帧重排 → 顺序恒定。
    codingFreezeGridSort()
    -- 整组收起的统一收尾：解冻网格排序(触发一次最终态重排)、释放锁、消费队列。
    -- 【修复】旧实现把收尾只写在补间 Completed 里，一旦卡片不在预期父级(异常路径)
    -- 就永远走不到收尾 → codingCardAnimLock 永久为 true，之后所有展开/收起全部卡死。
    local finishCollapse
    finishCollapse = function()
        codingWaitAllTweens(groupTweens, function()
            codingThawGridSort()
            codingCardAnimLock = false
            codingCardProcessQueue()
        end)
    end
    -- 立即隐藏手动收起按钮：卡片即将缩回并交回网格，不再需要该按钮
    local cBtn = codingCardRefs[card] and codingCardRefs[card].collapseBtn
    if cBtn and cBtn.Parent then
        cBtn.Visible = false
        -- 隐藏前复位悬停态：刚点过它，此刻正停在「全不透明」的悬停态上
        codingResetHoverTintFull(cBtn)
    end
    -- 收起态恢复色带全宽（与卡片缩回并行），线条重新加长回到完整状态
    local colorBar = codingCardRefs[card] and codingCardRefs[card].colorBar
    if colorBar and colorBar.Parent then
        local colorTween = svc.TweenService:Create(colorBar, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {
            Size = UDim2.new(1, -24, 0, 3),
        })
        groupTweens.colorBar = colorTween
        colorTween:Play()
    end
    if not (card and card.Parent) or card.Parent == codingPickerCards or not codingRightPanel then
        -- 卡片已不在面板上（已交回网格 / 已被销毁）：静态复位几何后收尾，跳过补间，避免锁死
        pcall(function()
            if card and card.Parent == codingPickerCards then
                codingCardReturnToCell(card)
            end
        end)
        finishCollapse()
        return
    end
    do
        -- 收起 = 展开的严格反向：统一锚点 (0,0)、纯像素 Size，把「当前矩形」补间成
        -- 「自己那一格」的矩形。位置与尺寸一起补间 → 路径连续、终点精确、不会飞出面板。
        local host = codingRightPanel
        local curAbs, curSize = card.AbsolutePosition, card.AbsoluteSize
        local hostAbs = host.AbsolutePosition
        card.ZIndex = 6
        card.AnchorPoint = Vector2.new(0, 0)
        card.Size = UDim2.fromOffset(curSize.X, curSize.Y)
        card.Position = UDim2.fromOffset(curAbs.X - hostAbs.X, curAbs.Y - hostAbs.Y)
        -- 终点：单元格矩形的屏幕坐标 → host 本地坐标（每张卡各回各格，不是第一格）
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
            -- 动画结束后放回网格并复位锚点，由 UIGridLayout 接管布局(精确归位)。
            -- Position 用画布局部坐标交回，容器正滚动在某处也不会整体偏移。
            if card and card.Parent then
                codingCardReturnToCell(card)
                -- 容器滚动过、卡片刚好落在可视区外时，滚回去露出它
                codingEnsureCardVisible(card)
            end
            -- 【修复】以「缩回 + 色带恢复 + 其它卡片淡入」这组补间全部完成作为整组收起结束的判据。
            -- 原实现分两处各等 2 帧布局稳定，但 2 帧远短于补间周期(0.28~0.3s)，
            -- 提前解冻后残余淡入补间仍会触发 UIGridLayout 逐帧重排 → 「队列顺序在动画尾部仍改变」。
            finishCollapse()
        end)
    end
end

-- 收起当前展开的卡片（若有）：供关闭 picker / 进入建造空间等场景兜底调用
function codingResetExpandedCard()
    if codingExpandedCard then
        codingCollapseCard(codingExpandedCard)
    end
end

-- 手动收起按钮显隐控制：展开态显示、收起态隐藏，供外部（如面板缩放、切换 tab）统一调用
function codingSetCollapseBtnVisible(card, visible)
    if not card then return end
    local cBtn = codingCardRefs[card] and codingCardRefs[card].collapseBtn
    if cBtn and cBtn.Parent then cBtn.Visible = not not visible end
end

codingPickerBusy = false
-- 预先记录各组元素的初始透明度（此时不会有悬停补间干扰）
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
        -- ① 先把整块 picker 条显示出来(仍用当前窄宽)，避免与面板展开动画互相裁剪
        codingPickerBar.Visible = true
        codingFadeGroup(codingPickerBar, true, 0)  -- 立即显示(宽=窄)，避免与面板展开动画重叠产生闪烁
        codingShowCards(true, 0)
        -- ② 右侧操作栏向左展开(变宽)，左侧预览区同步缩小，形成“挤出”过渡
        codingApplyRightWidth(CODING_RIGHT_W_EXPANDED, dur)
        if codingGridArea and codingGridArea.Parent then
            svc.TweenService:Create(codingGridArea, TweenInfo.new(dur, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                {Size = UDim2.new(1, -CODING_RIGHT_W_EXPANDED - 6, 1, 0)}):Play()
        end
        -- ③ 面板宽度补间到位后，再让搜索框自适应到展开后的新宽度，避免过渡期文字被挤压换行
        task.delay(dur + 0.02, function()
            if codingPickerOpen then codingApplySearchWidth() end
        end)
        -- ④ 三个按钮与 picker 内容淡入(与面板展开并行，节奏一致)
        codingFadeGroup(codingAddBlockBtn, false, dur)
        codingFadeGroup(codingActionSmall, false, dur)
        codingFadeGroup(codingPickerBar, true, dur)
        codingShowCards(true, dur)
        -- ⑤ 底部「附加设置」按钮同步淡出，避免添加模式下底部残留
        if codingSettingsBtn then codingFadeGroup(codingSettingsBtn, false, dur) end
        task.delay(dur + 0.06, function()
            codingPickerBusy = false
        end)
    else
        -- 关闭添加模式前先收起展开中的卡片，避免它仍挂在右侧面板上未回网格
        codingResetExpandedCard()
        codingFadeGroup(codingPickerBar, false, dur)
        codingShowCards(false, dur)
        pcall(function() codingPickerInput:ReleaseFocus() end)
        task.delay(dur + 0.06, function()
            if not codingPickerOpen then
                codingFadeGroup(codingAddBlockBtn, true, dur)
                codingFadeGroup(codingActionSmall, true, dur)
                -- 退出添加模式时补回底部设置入口
                if codingSettingsBtn then codingFadeGroup(codingSettingsBtn, true, dur) end
            end
            codingPickerBusy = false
        end)
        -- 关闭时先把搜索框缩回(此时面板仍在宽态，不会被裁剪)，再收面板 + 左侧还原
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

-- 工具条要等卡片都建好再挂（它排在「进入建造空间 / 运行」那一行的下面）
pcall(codingBuildBlockToolbar)

-- hook 必须在 codingBuildBlockToolbar() 之后，此时 codingToolRow 才被赋值，
-- 否则条件 codingToolRow 为 nil，hook 永远不注册，按钮不会随「添加积木」渐隐。
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
    -- 兜底：确保点击前右栏处于收起窄态，避免上次未正确收起导致展开起点异常
    if not codingPickerOpen then
        codingRightPanel.Size = UDim2.new(0, CODING_RIGHT_W_COLLAPSED, 1, 0)
        codingGridArea.Size = UDim2.new(1, -CODING_RIGHT_W_COLLAPSED - 6, 1, 0)
    end
    codingSetPickerOpen(true)
end)
codingBackBtn.MouseButton1Click:Connect(function()
    codingSetPickerOpen(false)
end)
-- 登记常态底色：点击「返回」会立刻让整条 picker 淡出，此时 MouseLeave 被
-- codingIsFadedOut 守卫挡下、不会复位背景色；下次打开 picker 时按钮就仍是蓝色
-- （即"被按住没释放"）。由 codingFadeGroup 淡出时的统一复位兜底。
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
    -- 点击后立刻复位到常态颜色，避免按钮卡在 MouseEnter 的 accent(蓝色) 高亮上。
    -- 同时把 btnFading 置 true，屏蔽淡出过程中 MouseEnter/MouseLeave
    -- 反复改写 BackgroundColor3 / BackgroundTransparency，导致"持续被按住(蓝色)"的观感。
    local function resetToBase()
        codingEnterBtnFading = false
        svc.TweenService:Create(codingEnterBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = baseTint,
            BackgroundTransparency = baseTransparency,
        }):Play()
    end
    codingEnterBtn.MouseButton1Click:Connect(function()
        -- 先取消鼠标高亮，再执行进入（进入后该按钮会随面板一起渐隐）
        resetToBase()
        enterBuildSpace()
    end)
    -- 登记常态底色：进入建造空间时整组淡出，MouseLeave 被 codingEnterBtnFading /
    -- codingIsFadedOut 挡下 → 蓝色残留。淡出时的统一复位再兜一道底。
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

-- ---------- 附加设置：右侧底部入口 + 设置面板 ----------
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

-- 设置面板：覆盖整个 coding 页面，风格对齐设置页
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

-- 顶栏：标题 + 退出设置按钮
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

-- 滚动设置区（类似设置页）
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

-- 分区卡片：通用
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

-- 属性窗口 开关（暂不绑定业务事件）
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
    -- 打开且当前就在建造空间里 → 立刻显示；关掉 → 立刻收起。
    -- 配置键 propWindow 由 makeToggle 落盘，下次进入建造空间时复用。
    propWindowSetVisible(state and buildSpaceActive == true)
end, "propWindow")
csPropRow.Parent = csCard

-- 预览类型 下拉（默认「面板」）。
-- 复用设置页的通用 makeDropdown：它自带整屏遮罩，会被 codingAnyDropdownOpen 识别，
-- 因此展开时不会误触发预览框的缩放/平移。
-- 【暂不绑定业务事件】只记录选择（配置键 codingPreviewType 落盘），
-- 需要按类型切换呈现时，在下面的回调里接上即可；当前值可通过 codingPreviewTypeGet() 读取。
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
-- makeDropdown 内部把 ZIndex 写死为 5/6（设置页那边的层级），这里是设置面板(13~15)，
-- 不与左侧文字重叠，但补齐层级更稳妥；展开的列表挂在 ScreenGui 上(ZIndex 999)，不受影响。
local csPreviewBtn, csPreviewGet = makeDropdown(csPreviewRow, CODING_PREVIEW_TYPES, 1, function() end, "codingPreviewType")
pcall(function()
    csPreviewBtn.ZIndex = 15
    for _, c in ipairs(csPreviewBtn:GetChildren()) do
        if c:IsA("TextLabel") or c:IsA("ImageLabel") then c.ZIndex = 16 end
    end
end)
csPreviewRow.Parent = csCard

-- 读取当前预览类型（供后续按类型切换呈现时使用）
function codingPreviewTypeGet()
    if csPreviewGet then
        local ok, v = pcall(csPreviewGet)
        if ok and type(v) == "string" and v ~= "" then return v end
    end
    return CODING_PREVIEW_TYPES[1]
end

-- 预先缓存透明度，便于整组渐隐渐显
codingFadeEntries(codingSettingsPanel)
codingFadeEntries(codingGridArea)
codingFadeEntries(codingRightPanel)
-- 单独缓存底部设置按钮：进入/退出添加模式时它要独立于右侧面板整组淡出
codingFadeEntries(codingSettingsBtn)

codingSettingsMode = false
codingSettingsBusy = false

function codingOpenSettings()
    if codingSettingsBusy or codingSettingsMode then return end
    codingSettingsMode = true
    codingSettingsBusy = true
    if codingPickerOpen then codingSetPickerOpen(false) end
    -- 进入设置前把底部按钮的悬停高亮立刻复位为常态色，避免进入设置页后
    -- 按钮仍停留在 accent 高亮(看起来像"被按压")，返回时残留未释放。
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
    -- 关闭前先撤掉可能展开的下拉遮罩（预览类型等）：遮罩 ZIndex 998 盖在设置面板(12)之上，
    -- 残留会吞掉返回后的第一次点击，表现为「点了没反应」。
    pcall(codingCloseAllDropdowns)
    -- 退出设置：先把底部按钮的悬停高亮复位为常态色，防止淡入过程中
    -- 仍显示 accent 高亮(看起来像"被按压未释放")，并让 MouseLeave 兜底逻辑更干净。
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
    -- 添加积木模式下按钮已淡隐，忽略点击避免与 picker 动画互相打断
    if codingPickerOpen or codingPickerBusy then return end
    codingOpenSettings()
end)
-- 同 codingBackBtn：进入「添加积木」模式时该按钮会整组淡出，
-- MouseLeave 被守卫挡下 → 蓝色高亮残留到下次淡入，故登记常态底色统一复位。
codingRegHoverTint(codingSettingsBtn, { BackgroundColor3 = theme.accent })
codingSettingsBtn.MouseEnter:Connect(function()
    -- 添加积木模式下该按钮已整组淡隐，悬停不能再把它点亮(否则淡出中途会残留高亮)
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

-- 兼容层
local function ensureDependencies()
    warn("[CodingBlocks] [1/5] 初始化依赖...")
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
        warn("[CodingBlocks] svc 已创建（兼容模式）")
    else
        warn("[CodingBlocks] svc 已存在")
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
        warn("[CodingBlocks] theme 已创建（兼容模式）")
    else
        warn("[CodingBlocks] theme 已存在")
    end
    if not obStoredObjects then obStoredObjects = {} end
    if not obStoredObjTexts then obStoredObjTexts = function() return {} end end
    if not buildSpaceActive then buildSpaceActive = false end
    if not AddLog then AddLog = function(msg, lvl) print("[Coding]", msg) end end
    if not currentPage then currentPage = "" end
    warn("[CodingBlocks] [1/5] 依赖初始化完成")
end

local pageDef = {
    name = "coding_blocks",
    title = "积木编程",
    icon = "blocks",
}

function pageDef.build(frame, helpers)
    warn("[CodingBlocks] [2/5] build 函数开始执行，frame = ", tostring(frame))
    warn("[CodingBlocks] frame.Parent = ", tostring(frame and frame.Parent))
    warn("[CodingBlocks] helpers = ", tostring(helpers))

    ensureDependencies()
    codingPage = frame
    frame.Name = "coding_blocks"
    warn("[CodingBlocks] [3/5] codingPage 已赋值，开始 loadstring 编译...")
    warn("[CodingBlocks] CODING_PAGE_SOURCE 长度 = ", #CODING_PAGE_SOURCE)

    local fn, err = loadstring(CODING_PAGE_SOURCE, "@coding_blocks")
    if not fn then
        warn("[CodingBlocks] [ERROR] loadstring 编译失败: " .. tostring(err))
        return
    end
    warn("[CodingBlocks] [4/5] loadstring 编译成功，开始执行...")

    local ok, runErr = pcall(fn)
    if not ok then
        warn("[CodingBlocks] [ERROR] 代码执行失败: " .. tostring(runErr))
        if debug and debug.traceback then
            warn("[CodingBlocks] [ERROR] 调用栈: " .. debug.traceback())
        end
        return
    end

    warn("[CodingBlocks] [5/5] 初始化成功！codingPage = ", tostring(codingPage))
    warn("[CodingBlocks] codingPage 子元素数量: ", tostring(#frame:GetChildren()))
end

local function register()
    warn("[CodingBlocks] 开始注册页面...")
    warn("[CodingBlocks] DeltaRegisterPage = ", tostring(DeltaRegisterPage))
    warn("[CodingBlocks] _G.DeltaRegisterPage = ", tostring(_G and _G.DeltaRegisterPage))
    if DeltaRegisterPage then
        DeltaRegisterPage(pageDef)
        warn("[CodingBlocks] 通过 DeltaRegisterPage 注册成功")
        return true
    end
    if _G and _G.DeltaRegisterPage then
        _G.DeltaRegisterPage(pageDef)
        warn("[CodingBlocks] 通过 _G.DeltaRegisterPage 注册成功")
        return true
    end
    warn("[CodingBlocks] [ERROR] 未找到 DeltaRegisterPage，注册失败")
    return false
end

local regOk = register()
warn("[CodingBlocks] 注册结果: ", tostring(regOk))
return pageDef
