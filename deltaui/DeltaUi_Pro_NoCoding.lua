local Delta = {}

local svc = {
    Players = game:GetService("Players"),
    UserInputService = game:GetService("UserInputService"),
    CoreGui = game:GetService("CoreGui"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    TweenService = game:GetService("TweenService"),
    RunService = game:GetService("RunService"),
    Stats = game:GetService("Stats"),
    HttpService = game:GetService("HttpService"),
}
if not _G.__LuraphPrefixCleaned then
    _G.__LuraphPrefixCleaned = true
    local oldError = error
    local function cleanLuraphPrefix(msg)
        if type(msg) ~= "string" then return msg end
        local result = msg
        local count = 0
        while result:find("Luraph Script:", 1, true) and count < 10 do
            local startPos = result:find("Luraph Script:", 1, true)
            if startPos then
                local after = result:sub(startPos + 14)
                local colonPos = after:find(":", 1, true)
                if colonPos then
                    local nextPart = after:sub(colonPos + 1)
                    if nextPart:find("Luraph Script:", 1, true) then
                        result = result:sub(1, startPos - 1) .. nextPart
                    else
                        break
                    end
                else
                    break
                end
            else
                break
            end
            count = count + 1
        end
        return result
    end
        _G.error = function(message, level)
        return oldError(cleanLuraphPrefix(message), level)
    end
end

local v7 = svc.Players.LocalPlayer
realTweenService = svc.TweenService
bypassModeActive = false
LucideManager = {Module = nil, Loaded = false}
function LoadLucide()
    if LucideManager.Loaded then return LucideManager.Module end
    local content
    local localCachePath = "DeltaUI/Cache/lucide_module.lua"
    if isfile(localCachePath) then
        local ok, localContent = pcall(function() return readfile(localCachePath) end)
        if ok and localContent and #localContent > 5000 then
            content = localContent
        end
    end

    
    if not content or content == "" then
        local moduleUrls = {
            "https://cdn.jsdelivr.net/gh/WasKKal/Asset@master/lucide/init.lua",
            "https://raw.githubusercontent.com/WasKKal/Asset/master/lucide/init.lua",
        }
        for _, url in ipairs(moduleUrls) do
            for _ = 1, 2 do
                local ok, result = pcall(function() return game:HttpGet(url) end)
                if ok and result and #result > 5000 then
                    content = result
                    break
                end
                task.wait(0.3)
            end
            if content and #content > 5000 then break end
        end
        if not content or content == "" then
            for _ = 1, 2 do
                local ok, result = pcall(function()
                    return game:HttpGet("https://github.com/latte-soft/lucide-roblox/releases/download/0.1.3/lucide-roblox.luau")
                end)
                if ok and result and #result > 5000 then
                    content = result
                    break
                end
                task.wait(0.3)
            end
        end
        
        if content and #content > 5000 then
            pcall(function()
                if not isfolder("DeltaUI") then makefolder("DeltaUI") end
                if not isfolder("DeltaUI/Cache") then makefolder("DeltaUI/Cache") end
                writefile(localCachePath, content)
            end)
        end
    end

    if not content or content == "" then return nil end
    local func, err = loadstring(content)
    if not func then return nil end
    local ok, module = pcall(func)
    if not ok or not module then return nil end
    if type(module) ~= "table" or type(module.GetAsset) ~= "function" then return nil end
    LucideManager.Module = module
    LucideManager.Loaded = true
    return module
end

function GetIcon(iconName, size, color)
    local lucide = LoadLucide()
    local img = Instance.new("ImageLabel")
    img.Size = size or UDim2.new(0, 20, 0, 20)
    img.BackgroundTransparency = 1
    img.ImageColor3 = color or Color3.fromRGB(230, 232, 240)
    img.ScaleType = Enum.ScaleType.Fit

    if lucide then
        local ok, icon = pcall(function() return lucide.GetAsset(iconName) end)
        if ok and icon and icon.Url and icon.Url ~= "" then
            img.Image = icon.Url
            if icon.ImageRectOffset and icon.ImageRectSize then
                img.ImageRectOffset = icon.ImageRectOffset
                img.ImageRectSize = icon.ImageRectSize
            end
            return img
        end
    end

    img:Destroy()
    return nil
end

function ParseImageAsset(input)
    if type(input) == "string" and input:sub(1,13) == "rbxassetid://" then return input end
    if tonumber(input) then return "rbxassetid://" .. tonumber(input) end
    if type(input) == "string" and #input >= 4 and input:sub(1,4) == "http" then
        local getasset = getcustomasset or getsynasset
        if getasset and writefile then
            local success, result = pcall(function()
                if not isfolder("DeltaUI") then makefolder("DeltaUI") end
                if not isfolder("DeltaUI/Cache") then makefolder("DeltaUI/Cache") end
                local safeName = __safeFilterName(input)
                if #safeName > 50 then safeName = safeName:sub(1, 50) end
                local fileName = "DeltaUI/Cache/img_" .. safeName .. ".jpg"
                if isfile(fileName) then
                    return getasset(fileName)
                end
                local req = (syn and syn.request) or (http and http.request) or http_request or request
                if not req then return "" end
                local resp = req({Url = input, Method = "GET"})
                local imgData = resp and resp.Body
                if not imgData or #imgData == 0 then return "" end
                writefile(fileName, imgData)
                return getasset(fileName)
            end)
            if success then return result else warn("Image DL Failed") return "" end
        end
    end
    return input
end

function create(class, props)
    local inst = Instance.new(class)
    if type(props) == "table" then
        for k, v in pairs(props) do inst[k] = v end
    end
    return inst
end
function corner(radius, parent)
    local c = create("UICorner", {CornerRadius = UDim.new(0, radius or 8)})
    c.Parent = parent
    return c
end
function updateCornerRadius(parent, radius)
    if not parent then return end
    local c = parent:FindFirstChildOfClass("UICorner")
    if c then
        c.CornerRadius = UDim.new(0, radius)
    else
        corner(radius, parent)
    end
end
function stroke(color, thickness, parent)
    local s = create("UIStroke", {Color = color or Color3.fromRGB(60, 65, 80), Thickness = thickness or 1, Transparency = 0.4})
    s.Parent = parent
    return s
end

_G.__DeltaUI_gradients = _G.__DeltaUI_gradients or {}
local function getThemeGradientColors()
    local cfg = loadConfig()
    local function readColor(c)
        if type(c) == "table" and c.r and c.g and c.b then
            return Color3.fromRGB(c.r, c.g, c.b)
        end
        return nil
    end
    return readColor(cfg.gradientThemeColor), readColor(cfg.gradientThemeColorTo)
end

local function deriveGradientTo(from)
    local h, s, v = from:ToHSV()
    local th = (h + 0.17) % 1
    local ts = math.max(s, 0.6)
    local tv = math.max(v, 0.6)
    return Color3.fromHSV(th, ts, tv)
end

local function getEffectiveGradientColors()
    local from, to = getThemeGradientColors()
    if from and not to then
        to = deriveGradientTo(from)
    end
    return from, to
end


local function buildGradientSequence(from, to, width)
    local holdFrac = 0.1
    if type(width) == "number" and width > 0 then
        holdFrac = math.min(12 / width, 0.1)
    end
    holdFrac = math.max(holdFrac, 0.02)
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0, from),
        ColorSequenceKeypoint.new(holdFrac, from),
        ColorSequenceKeypoint.new(1 - holdFrac, to),
        ColorSequenceKeypoint.new(1, to),
    })
end

function applyGradient(frame, from, to, rotation)
    if not frame then return end
    local themedFrom, themedTo = getEffectiveGradientColors()
    if themedFrom then
        from = themedFrom
        to = themedTo
    end
    
    frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    local g = create("UIGradient", {
        Color = buildGradientSequence(from or Color3.fromRGB(56, 189, 248), to or Color3.fromRGB(139, 92, 246), frame.AbsoluteSize.X),
        Rotation = rotation or 45,
    })
    g.Parent = frame
    table.insert(_G.__DeltaUI_gradients, g)
    return g
end

function refreshThemeGradients()
    local themedFrom, themedTo = getEffectiveGradientColors()
    if not themedFrom then return end
    for i = #_G.__DeltaUI_gradients, 1, -1 do
        local g = _G.__DeltaUI_gradients[i]
        pcall(function()
            if g and g.Parent then
                
                g.Color = buildGradientSequence(themedFrom, themedTo, g.Parent.AbsoluteSize.X)
            else
                table.remove(_G.__DeltaUI_gradients, i)
            end
        end)
    end
    -- (DeltaUI-old) solid accent 刷新逻辑已移除
end
function splitLines(text)
    local lines = {}
    local pos = 1
    while true do
        local nl = text:find(string.char(10), pos, true)
        if nl then
            table.insert(lines, text:sub(pos, nl - 1))
            pos = nl + 1
        else
            table.insert(lines, text:sub(pos))
            break
        end
    end
    return lines
end

function __safeFilterName(input)
    if type(input) ~= "string" then return "" end
    local result = ""
    for i = 1, #input do
        local c = input:sub(i, i)
        local b = string.byte(c)
        if (b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b == 95 then
            result = result .. c
        else
            result = result .. "_"
        end
    end
    return result
end

local theme = {
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


function makeGradientBtn(parent, size, anchorPoint, position, text, callback)
    local bg = create("Frame", {
        AnchorPoint = anchorPoint,
        Position = position,
        Size = size,
        BackgroundColor3 = theme.accent,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ZIndex = 5,
    })
    corner(8, bg)
    applyGradient(bg, theme.accent, theme.accent2, 90)
    
    local btn = create("TextButton", {
        AnchorPoint = anchorPoint,
        Position = position,
        Size = size,
        BackgroundTransparency = 1,
        Text = tostring(text or ""),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 12,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        BorderSizePixel = 0,
        ZIndex = 6,
    })
    btn.Parent = parent
    bg.Parent = parent
    if type(callback) == "function" then
        btn.MouseButton1Click:Connect(callback)
    end
    return btn, bg
end

local translations = {
    rejoin = {en = "Rejoin", zh = "重新加入", ko = "재접속", ja = "再参加"},
    script_loaded = {en = "Loaded: ", zh = "加载完成: ", ko = "로드 완료: ", ja = "読み込み完了: "},
    rejoin_desc = {en = "Rejoins your current server", zh = "重新加入当前服务器", ko = "현재 서버에 재접속", ja = "現在のサーバーに再参加"},
    bypass_ui_detection = {en = "Bypass UI Detection", zh = "绕过UI检测", ko = "UI 감지 우회", ja = "UI検出バイパス"},
    bypass_ui_detection_desc = {en = "Can bypass UI detection on most servers, but limits some features", zh = "可以绕过大部分服务器的Ui检测,但会限制一些功能", ko = "대부분 서버의 UI 감지를 우회할 수 있지만, 일부 기능이 제한됩니다", ja = "ほとんどのサーバーのUI検出をバイパスできますが、一部の機能が制限されます"},
    small_server = {en = "Small Server", zh = "小服务器", ko = "소규모 서버", ja = "小規模サーバー"},
    small_server_desc = {en = "Joins a server with a low playercount", zh = "加入玩家数较少的服务器", ko = "플레이어 수가 적은 서버 참가", ja = "プレイヤー数が少ないサーバーに参加"},
    fps_cap = {en = "FPS Cap", zh = "帧率限制", ko = "FPS 제한", ja = "FPS制限"},
    fps_cap_desc = {en = "Change the FPS cap for a smoother experience", zh = "更改帧率限制以获得更流畅的体验", ko = "더 부드러운 경험을 위해 FPS 제한 변경", ja = "よりスムーズな体験のためFPS制限を変更"},
    icon_size = {en = "Icon Size", zh = "图标大小", ko = "아이콘 크기", ja = "アイコンサイズ"},
    icon_size_desc = {en = "Change the floating icon's size", zh = "更改悬浮图标的大小", ko = "플로팅 아이콘 크기 변경", ja = "フローティングアイコンのサイズを変更"},
    icon_shape = {en = "Icon Shape", zh = "图标形状", ko = "아이콘 모양", ja = "アイコン形状"},
    icon_shape_desc = {en = "Change the floating icon's shape", zh = "更改悬浮图标的形状", ko = "플로팅 아이콘 모양 변경", ja = "フローティングアイコンの形状を変更"},
    shape_rounded = {en = "Rounded Square", zh = "方圆角", ko = "둥근 사각형", ja = "角丸四角"},
    anti_afk = {en = "Anti AFK", zh = "反挂机", ko = "AFK 방지", ja = "AFK防止"},
    anti_afk_desc = {en = "Disable all idle timeout kicks from the source", zh = "禁用所有空闲超时踢出", ko = "모든 유휴 시간 초과 퇴장 비활성화", ja = "すべてのアイドルタイムアウトキックを無効化"},
    console = {en = "Console", zh = "控制台", ko = "콘솔", ja = "コンソール"},
    console_desc = {en = "Enable or disable console log output", zh = "启用或禁用控制台日志输出", ko = "콘솔 로그 출력 활성화 또는 비활성화", ja = "コンソールログ出力の有効/無効"},
    auto_execute = {en = "Auto Execute", zh = "自动执行", ko = "자동 실행", ja = "自動実行"},
    auto_execute_desc = {en = "Toggle auto-execution of scripts in the autoexec folder", zh = "切换 autoexec 文件夹中脚本的自动执行", ko = "autoexec 폴더의 스크립트 자동 실행 전환", ja = "autoexecフォルダのスクリプト自動実行を切り替え"},
    auto_accept_exec = {en = "Auto accept code execution", zh = "自动接受代码执行", ko = "자동 코드 실행 수락", ja = "コード実行を自動承認"},
    auto_accept_exec_desc = {en = "Skip confirmation dialog, automatically accept all execute_lua requests", zh = "跳过确认弹窗，自动接受所有代码执行请求", ko = "확인 대화 상자 건너뛰기, 모든 execute_lua 요청 자동 수락", ja = "確認ダイアログをスキップし、すべてのexecute_luaリクエストを自動承認"},
    click_here = {en = "CLICK HERE", zh = "点击这里", ko = "여기 클릭", ja = "ここをクリック"},
    language = {en = "Language", zh = "语言", ko = "언어", ja = "言語"},
    language_desc = {en = "Select your preferred language", zh = "选择您偏好的语言", ko = "선호하는 언어 선택", ja = "好みの言語を選択"},
    new_tab = {en = "New tab", zh = "新标签页", ko = "새 탭", ja = "新しいタブ"},
    disable_notifications = {en = "Disable UI Notifications", zh = "关闭UI通知", ko = "UI 알림 비활성화", ja = "UI通知を無効化"},
    disable_notifications_desc = {en = "Hide all popup notifications from the UI", zh = "隐藏所有UI弹窗通知", ko = "모든 UI 팝업 알림 숨기기", ja = "すべてのUIポップアップ通知を非表示"},
    execute = {en = "Execute", zh = "执行", ko = "실행", ja = "実行"},
    clear = {en = "Clear", zh = "清空", ko = "지우기", ja = "クリア"},
    paste = {en = "Paste", zh = "粘贴", ko = "붙여넣기", ja = "貼り付け"},
    execute_clipboard = {en = "Execute clipboard", zh = "执行剪贴板", ko = "클립보드 실행", ja = "クリップボードを実行"},
    save = {en = "Save", zh = "保存", ko = "저장", ja = "保存"},
    search_scripts = {en = "Search for the scripts you have saved", zh = "搜索您已保存的脚本", ko = "저장된 스크립트 검색", ja = "保存したスクリプトを検索"},
    enter_details = {en = "Enter Details", zh = "输入详情", ko = "세부 정보 입력", ja = "詳細を入力"},
    enter_details_desc = {en = "Complete the necessary parameters to upload your client script", zh = "填写必要参数以上传您的客户端脚本", ko = "클라이언트 스크립트 업로드를 위해 필요한 매개변수 입력", ja = "クライアントスクリプトをアップロードするために必要なパラメータを入力"},
    title = {en = "Title", zh = "标题", ko = "제목", ja = "タイトル"},
    title_placeholder = {en = "Enter Your Title...", zh = "输入您的标题...", ko = "제목을 입력하세요...", ja = "タイトルを入力..."},
    script = {en = "Script", zh = "脚本", ko = "스크립트", ja = "スクリプト"},
    script_placeholder = {en = "Enter Your Script...", zh = "输入您的脚本...", ko = "스크립트를 입력하세요...", ja = "スクリプトを入力..."},
    add_script = {en = "Add Script", zh = "添加脚本", ko = "스크립트 추가", ja = "スクリプトを追加"},
    delete = {en = "DELETE", zh = "删除", ko = "삭제", ja = "削除"},
    deleted = {en = "Deleted", zh = "已删除", ko = "삭제됨", ja = "削除しました"},
    execute_cap = {en = "EXECUTE", zh = "执行", ko = "실행", ja = "実行"},
    core_loaded = {en = "Delta UI-Pro Core Loaded", zh = "Delta UI-Pro 核心已加载", ko = "Delta UI-Pro 코어 로드됨", ja = "Delta UI-Pro コアが読み込まれました"},
    ready = {en = "Ready", zh = "就绪", ko = "준비 완료", ja = "準備完了"},
    executing = {en = "Executing script...", zh = "正在执行脚本...", ko = "스크립트 실행 중...", ja = "スクリプトを実行中..."},
    execution_finished = {en = "Execution finished", zh = "执行完成", ko = "실행 완료", ja = "実行完了"},
    editor_cleared = {en = "Editor cleared", zh = "编辑器已清空", ko = "편집기 지워짐", ja = "エディタがクリアされました"},
    pasted = {en = "Pasted from clipboard", zh = "已从剪贴板粘贴", ko = "클립보드에서 붙여넣기 완료", ja = "クリップボードから貼り付けました"},
    executing_clipboard = {en = "Executing clipboard...", zh = "正在执行剪贴板...", ko = "클립보드 실행 중...", ja = "クリップボードを実行中..."},
    newline = {en = "Newline", zh = "换行", ko = "줄바꿈", ja = "改行"},
    clipboard_finished = {en = "Clipboard execution finished", zh = "剪贴板执行完成", ko = "클립보드 실행 완료", ja = "クリップボード実行完了"},
    executing_saved = {en = "Executing saved script: ", zh = "正在执行已保存的脚本: ", ko = "저장된 스크립트 실행 중: ", ja = "保存したスクリプトを実行中: "},
    script_loading = {en = "Script loading... ", zh = "脚本正在加载... ", ko = "스크립트 로딩 중... ", ja = "スクリプト読み込み中... "},
    error = {en = "Error", zh = "错误", ko = "오류", ja = "エラー"},
    server = {en = "Server", zh = "服务器", ko = "서버", ja = "サーバー"},
    label = {en = "Label", zh = "标签", ko = "라벨", ja = "ラベル"},
    console_disabled_error = {en = "error Console is disabled", zh = "错误 控制台已禁用", ko = "오류 콘솔이 비활성화됨", ja = "エラー コンソールが無効化されています"},
    back = {en = "Back", zh = "返回", ko = "뒤로", ja = "戻る"},
    uninstall = {en = "Uninstall", zh = "卸载", ko = "제거", ja = "アンインストール"},
    uninstalling = {en = "Uninstalling", zh = "正在卸载", ko = "제거 중", ja = "アンインストール中"},
    updating = {en = "Updating", zh = "正在更新", ko = "업데이트 중", ja = "更新中"},
    installed = {en = "Installed", zh = "已安装", ko = "설치됨", ja = "インストール済み"},
    install = {en = "Install", zh = "安装", ko = "설치", ja = "インストール"},
    update = {en = "Update", zh = "更新", ko = "업데이트", ja = "更新"},
    complete = {en = "Complete!", zh = "完成!", ko = "완료!", ja = "完了!"},
    failed = {en = "Failed", zh = "失败", ko = "실패", ja = "失敗"},
    downloading = {en = "Downloading", zh = "正在下载", ko = "다운로드 중", ja = "ダウンロード中"},
    autoexec_enabled = {en = "AutoExecute enabled. UI load runs script automatically", zh = "自动执行已启用。UI加载时自动运行脚本", ko = "자동 실행 활성화됨. UI 로드 시 스크립트 자동 실행", ja = "自動実行が有効化されました。UI読み込み時にスクリプトを自動実行"},
    autoexec_disabled = {en = "AutoExecute disabled", zh = "自动执行已禁用", ko = "자동 실행 비활성화됨", ja = "自動実行が無効化されました"},
    compatibility_mode = {en = "Performance Mode", zh = "性能模式", ko = "성능 모드", ja = "パフォーマンスモード"},
    compatibility_mode_desc = {en = "Enable after rejoining, more script compatibility and better performance. Static HashValue may be detected by servers or tampered by malicious scripts.", zh = "开启后 需要重新加入游戏 兼容更多脚本 同时性能提升 但静态HashValue可能导致被部分服务器检测或被其他恶意脚本篡改", ko = "재접속 후 활성화, 더 많은 스크립트 호환 및 성능 향상. 정적 HashValue는 서버에 감지되거나 악성 스크립트에 의해 변조될 수 있음", ja = "再接続後に有効化、より多くのスクリプト互換性とパフォーマンス向上。静的HashValueはサーバーに検出されるか、悪意のあるスクリプトによって改ざんされる可能性があります"},
    auto_translate = {en = "Auto Translate", zh = "自动翻译", ko = "자동 번역", ja = "自動翻訳"},
    auto_translate_desc = {en = "Auto translate UI text (Chinese/English only)", zh = "自动将UI文本翻译为英文 (仅支持中英互译)", ko = "UI 텍스트 자동 번역 (중영만 지원)", ja = "UIテキスト自動翻訳 (中英のみ対応)"},

    translate_path = {en = "Translate Path", zh = "翻译路径", ko = "번역 경로", ja = "翻訳パス"},
    translate_path_desc = {en = "Select UI paths to translate", zh = "选择要翻译的UI路径", ko = "번역할 UI 경로 선택", ja = "翻訳するUIパスを選択"},
    coregui_path = {en = "CoreGui", zh = "CoreGui", ko = "CoreGui", ja = "CoreGui"},
    playergui_path = {en = "PlayerGui", zh = "PlayerGui", ko = "PlayerGui", ja = "PlayerGui"},
    script_installed_notify = {en = "Script installed. Use on GamePad page", zh = "脚本已安装。请在 GamePad 页面使用", ko = "스크립트 설치됨. GamePad 페이지에서 사용", ja = "スクリプトがインストールされました。GamePadページで使用"},
    customize_floating_ball = {en = "Customize floating ball image(Need 1:1)", zh = "自定义悬浮球图片(需要1:1)", ko = "플로팅 볼 이미지 사용자 지정(1:1 필요)", ja = "フローティングボール画像をカスタマイズ(1:1必要)"},
    confirm_changes = {en = "Confirm changes", zh = "确认更改", ko = "변경 확인", ja = "変更を確認"},
    enter_image_url = {en = "Enter image URL...", zh = "输入图片链接...", ko = "이미지 URL 입력...", ja = "画像URLを入力..."},
    invalid_image = {en = "Invalid image URL", zh = "无效的图片链接", ko = "잘못된 이미지 URL", ja = "無効な画像URL"},
    image_updated = {en = "Floating ball image updated", zh = "悬浮球图片已更新", ko = "플로팅 볼 이미지 업데이트됨", ja = "フローティングボール画像が更新されました"},
    customize_floating_ball_desc = {en = "Enter a 1:1 image URL to customize the floating ball", zh = "输入1:1图片链接自定义悬浮球", ko = "플로팅 볼 사용자 지정을 위해 1:1 이미지 URL 입력", ja = "フローティングボールをカスタマイズする1:1画像URLを入力"},
    custom_icon_guide = {en = "Rename image to icon.png, replace Workspace/DeltaUI/Asset/icon.png", zh = "将你的图片名改为icon.png 替换到Workspace/DeltaUI/Asset/icon.png下 即可手动修改", ko = "이미지를 icon.png로 변경 후 Workspace/DeltaUI/Asset/icon.png 교체", ja = "画像をicon.pngに改名し Workspace/DeltaUI/Asset/icon.png を置換"},
    patch_must_install = {en = "Must be installed", zh = "必须安装", ko = "설치 필수", ja = "インストール必須"},
    patch_installed_notify = {en = "Patch installed and applied", zh = "补丁已安装并应用", ko = "패치 설치 및 적용됨", ja = "パッチがインストールされました"},
    ui_outdated = {en = "Your UI version is outdated. Please install the latest version", zh = "你的UI版本已过时，请前往安装最新版", ko = "UI 버전이 오래되었습니다. 최신 버전을 설치하세요", ja = "UIバージョンが古いです。最新版をインストールしてください"},
    ui_update_export = {en = "New UI version downloaded to DeltaUI/Export. Please close the game and place it into Delta AutoExecute folder", zh = "新版UI已下载至DeltaUI/Export。请关闭游戏后将其放入Delta的AutoExecute文件夹", ko = "새 UI 버전이 DeltaUI/Export에 다운로드되었습니다. 게임을 종료하고 Delta AutoExecute 폴더에 넣으세요", ja = "新しいUIバージョンがDeltaUI/Exportにダウンロードされました。ゲームを終了してDeltaのAutoExecuteフォルダに配置してください"},
    patch_cannot_delete = {en = "Patch cannot be uninstalled from here", zh = "补丁不能从此处卸载", ko = "패치는 여기에서 제거할 수 없습니다", ja = "パッチはここからアンインストールできません"},
    patch_not_found = {en = "Patch source removed, cleaning local patch", zh = "补丁源已移除，正在清理本地补丁", ko = "패치 소스가 제거되어 로컬 패치를 정리합니다", ja = "パッチソースが削除されたため、ローカルパッチをクリーンアップします"},
    uipack_installed = {en = "UI Pack installed", zh = "UI包已安装", ko = "UI 팩 설치됨", ja = "UIパックがインストールされました"},
    uipack_label = {en = "UI Pack", zh = "UI包", ko = "UI 팩", ja = "UIパック"},
    patch_available = {en = "New patch available", zh = "有新补丁可用", ko = "새 패치 사용 가능", ja = "新しいパッチが利用可能です"},
    patch_deleted = {en = "Patch deleted", zh = "补丁已删除", ko = "패치 삭제됨", ja = "パッチが削除されました"},
    servers_input_placeholder = {en = "e.g. Blox Fruits, Adopt Me...", zh = "例如：Blox Fruits, Adopt Me...", ko = "예: Blox Fruits, Adopt Me...", ja = "例: Blox Fruits, Adopt Me..."},
    block_internal_errors = {en = "Block Internal Errors", zh = "禁用Roblox内部报错", ko = "내부 오류 차단", ja = "内部エラーをブロック"},
    block_internal_errors_desc = {en = "Filter out Roblox engine and other script errors", zh = "过滤Roblox引擎和其他脚本的报错信息", ko = "Roblox 엔진 및 기타 스크립트 오류 필터링", ja = "Robloxエンジンと他のスクリプトエラーをフィルタリング"},
    real_line_numbers = {en = "Real Line Numbers", zh = "自动计算真实报错行", ko = "실제 줄 번호 계산", ja = "実際の行番号を計算"},
    real_line_numbers_desc = {en = "Adjust error line numbers to exclude default header text", zh = "修正报错行号，排除预设文本的偏移", ko = "기본 헤더 텍스트를 제외한 실제 오류 줄 번호", ja = "デフォルトヘッダーテキストを除いた実際のエラー行番号"},
    detailed_errors = {en = "Detailed Errors", zh = "更详细的错误信息", ko = "상세 오류 정보", ja = "詳細なエラー情報"},
    detailed_errors_desc = {en = "Show additional error context and source info", zh = "显示额外的错误上下文和来源信息", ko = "추가 오류 컨텍스트 및 소스 정보 표시", ja = "追加のエラーコンテキストとソース情報を表示"},
    extension_package_options = {en = "Other options", zh = "其他选项", ko = "기타 옵션", ja = "その他のオプション"},
    confirm_changes = {en = "Confirm changes", zh = "确认更改", ko = "변경 확인", ja = "変更を確認"},
    enter_image_url = {en = "Enter image URL...", zh = "输入图片链接...", ko = "이미지 URL 입력...", ja = "画像URLを入力..."},
    save = {en = "Save", zh = "保存", ko = "저장", ja = "保存"},
    search_scripts = {en = "Search for the scripts you have saved", zh = "搜索您已保存的脚本", ko = "저장된 스크립트 검색", ja = "保存したスクリプトを検索"},
    supported_servers = {en = "Supported servers (comma separated)", zh = "支持的服务器（逗号分隔）", ko = "지원되는 서버 (쉼표로 구분)", ja = "対応サーバー（カンマ区切り）"},
    local_version = {en = "Local: ", zh = "本地：", ko = "로컬: ", ja = "ローカル: "},
    update_version = {en = "Update: ", zh = "更新：", ko = "업데이트: ", ja = "アップデート: "},
    author_label = {en = "Author: ", zh = "作者：", ko = "제작자: ", ja = "作者: "},
    version_label = {en = "Version: ", zh = "版本：", ko = "버전: ", ja = "バージョン: "},
    type_label = {en = "Type: ", zh = "类型：", ko = "유형: ", ja = "タイプ: "},
    from_store = {en = "From Store", zh = "来自商店", ko = "스토어에서", ja = "ストアから"},
    no_installed_packages = {en = "No installed packages", zh = "没有已安装的包", ko = "설치된 패키지 없음", ja = "インストール済みパッケージなし"},
    no_packages_available = {en = "No packages available", zh = "没有可用的包", ko = "사용 가능한 패키지 없음", ja = "利用可能なパッケージなし"},
    no_server_restrictions = {en = "No server restrictions", zh = "无服务器限制", ko = "서버 제한 없음", ja = "サーバー制限なし"},
    supported_servers_title = {en = "Supported servers:", zh = "支持的服务器：", ko = "지원되는 서버:", ja = "対応サーバー:"},
    editor_cleared = {en = "Editor cleared", zh = "编辑器已清空", ko = "편집기 지워짐", ja = "エディタがクリアされました"},
    search_cloud_placeholder = {en = "Search for the extension module or script you need...", zh = "搜索您需要的扩展模块或脚本...", ko = "필요한 확장 모듈 또는 스크립트 검색...", ja = "必要な拡張モジュールまたはスクリプトを検索..."},
    executing = {en = "Executing script...", zh = "正在执行脚本...", ko = "스크립트 실행 중...", ja = "スクリプトを実行中..."},
    executing_saved = {en = "Executing saved script: ", zh = "正在执行已保存的脚本: ", ko = "저장된 스크립트 실행 중: ", ja = "保存したスクリプトを実行中: "},
    script_loading = {en = "Script loading... ", zh = "脚本正在加载... ", ko = "스크립트 로딩 중... ", ja = "スクリプト読み込み中... "},
    fps_30 = {en = "30 FPS", zh = "30 帧", ko = "30 FPS", ja = "30 FPS"},
    fps_60 = {en = "60 FPS", zh = "60 帧", ko = "60 FPS", ja = "60 FPS"},
    fps_120 = {en = "120 FPS", zh = "120 帧", ko = "120 FPS", ja = "120 FPS"},
    fps_240 = {en = "240 FPS", zh = "240 帧", ko = "240 FPS", ja = "240 FPS"},
    fps_360 = {en = "360 FPS", zh = "360 帧", ko = "360 FPS", ja = "360 FPS"},
    fps_unlimited = {en = "Unlimited", zh = "无限制", ko = "무제한", ja = "無制限"},
    size_small = {en = "Small", zh = "小", ko = "작음", ja = "小"},
    size_medium = {en = "Medium", zh = "中", ko = "중간", ja = "中"},
    size_large = {en = "Large", zh = "大", ko = "큼", ja = "大"},
    shape_circle = {en = "Circle", zh = "圆形", ko = "원형", ja = "円形"},
    shape_square = {en = "Square", zh = "方形", ko = "사각형", ja = "四角形"},
    shape_rounded = {en = "Rounded Square", zh = "方圆角", ko = "둥근 사각형", ja = "角丸四角"},
    refreshing = {en = "Refreshing", zh = "刷新中", ko = "새로고침 중", ja = "更新中"},
    refresh_complete = {en = "Refresh complete!", zh = "刷新完成!", ko = "새로고침 완료!", ja = "更新完了!"},
    install = {en = "Install", zh = "安装", ko = "설치", ja = "インストール"},
    installed = {en = "Installed", zh = "已安装", ko = "설치됨", ja = "インストール済み"},
    update = {en = "Update", zh = "更新", ko = "업데이트", ja = "更新"},
    uninstall = {en = "Uninstall", zh = "卸载", ko = "제거", ja = "アンインストール"},
    complete = {en = "Complete!", zh = "完成!", ko = "완료!", ja = "完了!"},
    failed = {en = "Failed", zh = "失败", ko = "실패", ja = "失敗"},
    downloading = {en = "Downloading", zh = "正在下载", ko = "다운로드 중", ja = "ダウンロード中"},
    updating = {en = "Updating", zh = "正在更新", ko = "업데이트 중", ja = "更新中"},
    uninstalling = {en = "Uninstalling", zh = "正在卸载", ko = "제거 중", ja = "アンインストール中"},
    patch_must_install = {en = "Must be installed", zh = "必须安装", ko = "설치 필수", ja = "インストール必須"},
    local_version = {en = "Local: ", zh = "本地：", ko = "로컬: ", ja = "ローカル: "},
    update_version = {en = "Update: ", zh = "更新：", ko = "업데이트: ", ja = "アップデート: "},
    author_label = {en = "Author: ", zh = "作者：", ko = "제작자: ", ja = "作者: "},
    version_label = {en = "Version: ", zh = "版本：", ko = "버전: ", ja = "バージョン: "},
    type_label = {en = "Type: ", zh = "类型：", ko = "유형: ", ja = "タイプ: "},
    from_store = {en = "From Store", zh = "来自商店", ko = "스토어에서", ja = "ストアから"},
    no_installed_packages = {en = "No installed packages", zh = "没有已安装的包", ko = "설치된 패키지 없음", ja = "インストール済みパッケージなし"},
    no_packages_available = {en = "No packages available", zh = "没有可用的包", ko = "사용 가능한 패키지 없음", ja = "利用可能なパッケージなし"},
    no_server_restrictions = {en = "No server restrictions", zh = "无服务器限制", ko = "서버 제한 없음", ja = "サーバー制限なし"},
    by_label = {en = "by ", zh = "by ", ko = "by ", ja = "by "},
    customize_label = {en = "Customize Label", zh = "自定义标签", ko = "라벨 사용자 지정", ja = "ラベルをカスタマイズ"},
    customize_label_desc = {en = "Change the text displayed in the top right label", zh = "更改右上角标签显示的文本", ko = "오른쪽 상단 라벨에 표시되는 텍스트 변경", ja = "右上ラベルに表示されるテキストを変更"},
    enter_label_text = {en = "Enter label text...", zh = "输入标签文字...", ko = "라벨 텍스트 입력...", ja = "ラベルテキストを入力..."},
    label_updated = {en = "Label updated", zh = "标签已更新", ko = "라벨 업데이트됨", ja = "ラベルが更新されました"},
    console_settings = {en = "Console Settings", zh = "控制台设置", ko = "콘솔 설정", ja = "コンソール設定"},
    block_internal_errors = {en = "Block Internal Errors", zh = "禁用Roblox内部报错", ko = "내부 오류 차단", ja = "内部エラーをブロック"},
    block_internal_errors_desc = {en = "Filter out Roblox engine and other script errors", zh = "过滤Roblox引擎和其他脚本的报错信息", ko = "Roblox 엔진 및 기타 스크립트 오류 필터링", ja = "Robloxエンジンと他のスクリプトエラーをフィルタリング"},
    real_line_numbers = {en = "Real Line Numbers", zh = "自动计算真实报错行", ko = "실제 줄 번호 계산", ja = "実際の行番号を計算"},
    real_line_numbers_desc = {en = "Adjust error line numbers to exclude default header text", zh = "修正报错行号，排除预设文本的偏移", ko = "기본 헤더 텍스트를 제외한 실제 오류 줄 번호", ja = "デフォルトヘッダーテキストを除いた実際のエラー行番号"},
    detailed_errors = {en = "Detailed Errors", zh = "更详细的错误信息", ko = "상세 오류 정보", ja = "詳細なエラー情報"},
    detailed_errors_desc = {en = "Show additional error context and source info", zh = "显示额外的错误上下文和来源信息", ko = "추가 오류 컨텍스트 및 소스 정보 표시", ja = "追加のエラーコンテキストとソース情報を表示"},
    scriptblox_search = {en = "Search ScriptBlox...", zh = "搜索 ScriptBlox...", ko = "ScriptBlox 검색...", ja = "ScriptBloxを検索..."},
    scriptblox_no_results = {en = "No scripts found", zh = "未找到脚本", ko = "스크립트를 찾을 수 없음", ja = "スクリプトが見つかりません"},
    select_option = {en = "Select Your Option", zh = "选择您的操作", ko = "옵션을 선택하세요", ja = "オプションを選択"},
    select_option_desc = {en = "Choose whether to execute, open in a new tab, etc..", zh = "选择执行、在新标签页打开等操作", ko = "실행, 새 탭에서 열기 등을 선택", ja = "実行、新しいタブで開くなどを選択"},
    execute_selected = {en = "EXECUTE SELECTED SCRIPT", zh = "执行选中脚本", ko = "선택한 스크립트 실행", ja = "選択したスクリプトを実行"},
    open_in_editor = {en = "OPEN SCRIPT IN EDITOR", zh = "在编辑器中打开", ko = "에디터에서 열기", ja = "エディタで開く"},
    save_selected = {en = "SAVE SELECTED SCRIPT", zh = "保存选中脚本", ko = "선택한 스크립트 저장", ja = "選択したスクリプトを保存"},
    copy_to_clipboard = {en = "COPY TO CLIPBOARD", zh = "复制到剪贴板", ko = "클립보드에 복사", ja = "クリップボードにコピー"},
    open_btn = {en = "OPEN", zh = "打开", ko = "열기", ja = "開く"},
    verified_badge = {en = "VERIFIED", zh = "已验证", ko = "인증됨", ja = "認証済み"},
    fetch_failed = {en = "Failed to fetch script source", zh = "获取脚本源码失败", ko = "스크립트 소스를 가져오지 못함", ja = "スクリプトソースの取得に失敗"},
    opened_editor = {en = "Opened in editor", zh = "已在编辑器中打开", ko = "에디터에서 열림", ja = "エディタで開きました"},
    script_saved = {en = "Script saved", zh = "脚本已保存", ko = "스크립트 저장됨", ja = "スクリプトを保存しました"},
    copied = {en = "Copied to clipboard", zh = "已复制到剪贴板", ko = "클립보드에 복사됨", ja = "クリップボードにコピーしました"},
    clipboard_unavailable = {en = "Clipboard API unavailable", zh = "剪贴板 API 不可用", ko = "클립보드 API 사용 불가", ja = "クリップボードAPIが利用できません"},
    execution_error_notify = {en = "Error occurred! Jump to console", zh = "遇到报错! 请跳转控制台!", ko = "오류 발생! 콘솔로 이동", ja = "エラー発生! コンソールへ"},
    anti_kick = {en = "Anti Kick", zh = "反踢出", ko = "킥 방지", ja = "キック防止"},
    anti_kick_desc = {en = "Prevent other scripts from kicking you", zh = "防止其他脚本调用kick踢出", ko = "다른 스크립트의 킥 방지", ja = "他のスクリプトによるキックを防止"},
    network_request_header = {en = "Network Request Header", zh = "网络请求头类型", ko = "네트워크 요청 헤더", ja = "ネットワークリクエストヘッダー"},
    network_request_header_desc = {en = "Select the platform for HTTP requests", zh = "选择HTTP请求的平台类型", ko = "HTTP 요청에 사용할 플랫폼 선택", ja = "HTTPリクエストのプラットフォームを選択"},
    interface_type = {en = "Interface Type", zh = "接口类型", ko = "인터페이스 유형", ja = "インターフェースタイプ"},
    interface_type_desc = {en = "Select the browser or service interface", zh = "选择浏览器或服务接口", ko = "브라우저 또는 서비스 인터페이스 선택", ja = "ブラウザまたはサービスインターフェースを選択"},
    script_type_free = {en = "free", zh = "免费", ko = "무료", ja = "無料"},
    script_type_script_hub = {en = "Script hub", zh = "脚本中心", ko = "스크립트 허브", ja = "スクリプトハブ"},
    script_type_script = {en = "Script", zh = "脚本", ko = "스크립트", ja = "スクリプト"},
    views_label = {en = "Views", zh = "次浏览", ko = "조회", ja = "回視聴"},
    universal_script = {en = "Universal Script", zh = "通用脚本", ko = "범용 스크립트", ja = "汎用スクリプト"},
    error_translation = {en = "Error Translation", zh = "报错信息翻译", ko = "오류 메시지 번역", ja = "エラー翻訳"},
    error_translation_desc = {en = "Translate common error messages to your language", zh = "将常见报错信息翻译为您的语言", ko = "일반적인 오류 메시지를 번역", ja = "一般的なエラーメッセージを翻訳"},
    block_server_errors = {en = "Block Server Errors", zh = "屏蔽服务器报错", ko = "서버 오류 차단", ja = "サーバーエラーをブロック"},
    block_server_errors_desc = {en = "Filter out server-side errors from ReplicatedStorage", zh = "屏蔽来自 ReplicatedStorage 的服务器端报错", ko = "ReplicatedStorage의 서버 오류 필터링", ja = "ReplicatedStorageからのサーバーエラーをフィルタリング"},
    block_asset_errors = {en = "Block Asset Errors", zh = "屏蔽资产报错", ko = "에셋 오류 차단", ja = "アセットエラーをブロック"},
    block_asset_errors_desc = {en = "Filter out animation, asset and rbx:// loading errors", zh = "屏蔽动画、资产及rbx://加载失败报错", ko = "애니메이션, 에셋 및 rbx:// 로딩 오류 필터링", ja = "アニメーション、アセット及びrbx://読み込みエラーをフィルタリング"},
    match_search = {en = "Match Search!", zh = "匹配搜索!", ko = "검색 일치!", ja = "検색一致!"},
    init_ui = {en = "Initialize UI", zh = "初始化UI", ko = "UI 초기화", ja = "UIを初期化"},
    init_ui_desc = {en = "This will destroy downloaded/saved scripts", zh = "这将破坏已下载/已保存的脚本", ko = "다운로드/저장된 스크립트를 삭제합니다", ja = "ダウンロード/保存されたスクリプトを破棄します"},
    reset_tab_order = {en = "Reset Switcher", zh = "重制页面切换器", ko = "스위처 초기화", ja = "スイッチャーをリセット"},
    reset_switcher_desc = {en = "Reset tab order and custom icons", zh = "重置排序及自定义图标", ko = "탭 순서 및 사용자 지정 아이콘 초기화", ja = "タブ順序とカスタムアイコンをリセット"},
    customize_items = {en = "Customize Items", zh = "自定义项目", ko = "사용자 지정 항목", ja = "カスタマイズ項目"},
    customize_icon = {en = "Customize Icon", zh = "自定义图标", ko = "아이콘 사용자 지정", ja = "アイコンをカスタマイズ"},
    search_icons = {en = "Search icons...", zh = "搜索图标...", ko = "아이콘 검색...", ja = "アイコンを検索..."},
    add = {en = "Add", zh = "添加", ko = "추가", ja = "追加"},
    delete = {en = "Delete", zh = "删除", ko = "삭제", ja = "削除"},
    select_color = {en = "Select Color", zh = "选择颜色", ko = "색상 선택", ja = "色を選択"},
    orb_border_color = {en = "Orb Border Color", zh = "悬浮球边框颜色", ko = "플로팅 볼 테두리 색상", ja = "フローティングボールの枠線色"},
    orb_border_color_desc = {en = "Customize the floating orb border color", zh = "自定义悬浮球边框颜色", ko = "플로팅 볼 테두리 색상 사용자 지정", ja = "フローティングボールの枠線色をカスタマイズ"},
    gradient_theme_color = {en = "Gradient Theme Color", zh = "渐变主题色", ko = "그라데이션 테마 색상", ja = "グラデーションテーマ色"},
    gradient_theme_color_desc = {en = "Pick one color that drives every gradient in the UI", zh = "选择一个颜色，统一控制界面中所有渐变", ko = "UI의 모든 그라데이션을 제어할 색상을 하나 선택", ja = "UI内のすべてのグラデーションを制御する色を1つ選択"},
    gradient_pick_title = {en = "Custom Gradient Mix", zh = "自定义渐变拼色", ko = "그라데이션 맞춤 조합", ja = "グラデーション配色"},
    gradient_from = {en = "Start Color", zh = "起色", ko = "시작색", ja = "開始色"},
    gradient_to = {en = "End Color", zh = "止色", ko = "끝색", ja = "終了色"},
    gradient_preset = {en = "Presets", zh = "预设", ko = "프리셋", ja = "プリセット"},
    deep_customization = {en = "Deep Customization", zh = "深度自定义", ko = "고급 설정", ja = "詳細設定"},
    deep_custom_layout = {en = "Right Tab Bar", zh = "右侧选项卡栏", ko = "오른쪽 탭 바", ja = "右側タブバー"},
    deep_custom_layout_desc = {en = "Move the navigation tab bar to the right side", zh = "将导航选项卡栏移至右侧", ko = "탐색 탭 바를 오른쪽으로 이동", ja = "ナビゲーションタブバーを右側に移動"},
    customize_tabs = {en = "Customize Tabs", zh = "自定义选项卡", ko = "상단 탭 사용자 지정", ja = "上部タブをカスタマイズ"},
    customize_tabs_desc = {en = "Customize the order of navigation tabs", zh = "自定义导航选项卡顺序", ko = "상단 탭 순서 변경", ja = "上部ナビゲーションタブの順序を変更"},
    customize_tabs_btn = {en = "Customize", zh = "自定义", ko = "사용자 지정", ja = "カスタマイズ"},
    page_ext = {en = "Page Extensions", zh = "页面扩展", ko = "페이지 확장", ja = "ページ拡張"},
    page_ext_url_placeholder = {en = "Paste external page script URL...", zh = "粘贴外部页面脚本URL...", ko = "외부 페이지 스크립트 URL 붙여넣기...", ja = "外部ページスクリプトのURLを貼り付け..."},
    page_ext_guide = {en = "The URL must return a Lua script. Supported: return {name,title,icon,build} / DeltaRegisterPage(...) / or build directly into DeltaPage.frame. Obfuscated scripts are supported (page name auto-derived from URL).", zh = "URL需返回一个Lua脚本。支持：return {name,title,icon,build} / 调用 DeltaRegisterPage(...) / 或直接向 DeltaPage.frame 构建。兼容混淆脚本（页面名自动取自URL）。", ko = "URL은 Lua 스크립트를 반환해야 합니다. return {name,title,icon,build} / DeltaRegisterPage(...) 호출 / DeltaPage.frame에 직접 구축 중 하나를 지원합니다. 난독화 스크립트도 지원됩니다(페이지 이름은 URL에서 자동 생성).", ja = "URLはLuaスクリプトを返す必要があります。return {name,title,icon,build} / DeltaRegisterPage(...)の呼び出し / DeltaPage.frameへの直接構築のいずれかをサポートします。難読化スクリプトにも対応します(ページ名はURLから自動生成)。"},
    install_page = {en = "Install Page", zh = "安装页面", ko = "페이지 설치", ja = "ページをインストール"},
    installing_page = {en = "Installing page...", zh = "正在安装页面...", ko = "페이지 설치 중...", ja = "ページをインストール中..."},
    page_installed = {en = "Page installed", zh = "页面已安装", ko = "페이지 설치됨", ja = "ページをインストールしました"},
    page_install_failed = {en = "Page install failed", zh = "页面安装失败", ko = "페이지 설치 실패", ja = "ページのインストールに失敗"},
    page_name_exists = {en = "Page name already exists", zh = "页面名称已存在", ko = "페이지 이름이 이미 존재함", ja = "ページ名が既に存在します"},
    invalid_page_url = {en = "Invalid page URL", zh = "无效的页面URL", ko = "잘못된 페이지 URL", ja = "無効なページURL"},
    installed_pages = {en = "Installed Pages", zh = "已安装页面", ko = "설치된 페이지", ja = "インストール済みページ"},
    no_installed_pages = {en = "No installed pages", zh = "没有已安装的页面", ko = "설치된 페이지 없음", ja = "インストール済みページなし"},
    page_uninstalled = {en = "Page uninstalled", zh = "页面已卸载", ko = "페이지 제거됨", ja = "ページをアンインストールしました"},
    page_safe_mode = {en = "Safe Mode", zh = "安全模式", ko = "안전 모드", ja = "セーフモード"},
    page_safe_mode_desc = {en = "Sandbox external pages: block Sound/Video, Teleport, network & filesystem APIs. May break some obfuscated scripts — disable only for trusted pages.", zh = "对外部页面进行沙箱隔离：禁止声音/视频、传送、网络与文件系统接口。可能影响部分混淆脚本——仅对可信页面关闭。", ko = "외부 페이지를 샌드박스로 격리합니다: 사운드/비디오, 텔레포트, 네트워크 및 파일시스템 API 차단. 일부 난독화 스크립트에 영향을 줄 수 있으므로 신뢰할 수 있는 페이지만 비활성화하세요.", ja = "外部ページをサンドボックス化します: サウンド/ビデオ、テレポート、ネットワーク、ファイルシステムAPIをブロック。一部の難読化スクリプトに影響する場合があります。信頼できるページのみ無効化してください。"},
    page_blocked_instances = {en = "Blocked malicious code:", zh = "已拦截恶意代码:", ko = "악성 코드 차단됨:", ja = "悪意コードをブロックしました:"},
    page_risky_detected = {en = "Warning: risky code detected:", zh = "警告：检测到风险代码:", ko = "경고: 위험 코드 감지:", ja = "警告: 危険なコードを検出:"},
    page_presets = {en = "Official Presets", zh = "官方预设", ko = "공식 프리셋", ja = "公式プリセット"},
    page_presets_desc = {en = "One-click install official recommended pages", zh = "一键安装官方推荐页面", ko = "공식 추천 페이지 원클릭 설치", ja = "公式推奨ページをワンクリックでインストール"},
    preset_coding = {en = "Coding Blocks", zh = "积木编程", ko = "블록 코딩", ja = "ブロックコーディング"},
    preset_coding_desc = {en = "Visual block-based Lua coding environment", zh = "可视化积木式Lua编程环境", ko = "비주얼 블록 기반 Lua 코딩 환경", ja = "ビジュアルブロック式Luaコーディング環境"},
}



function safeConnect(obj, event, callback)
    if obj and obj[event] then
        local conn = obj[event]:Connect(callback)
        if conn then
            _G.__DeltaUI_connections = _G.__DeltaUI_connections or {}
            table.insert(_G.__DeltaUI_connections, conn)
        end
        return conn
    else
        warn("[DeltaUI] Cannot connect to event: object or event is nil (" .. tostring(event) .. ")")
        return nil
    end
end


function cleanupAllConnections()
    if _G.__DeltaUI_connections then
        for _, conn in ipairs(_G.__DeltaUI_connections) do
            pcall(function() conn:Disconnect() end)
        end
        _G.__DeltaUI_connections = {}
    end
end

local uiVersion = "1.0.2"
local UI_VERSION = "1.1.2"
local settingsData = {language = "zh", uiRefs = {}}
local configFile = "DeltaUI/Config.json"
local uiVersionChecked = false

function checkUiVersion(remoteVersion)
    if uiVersionChecked then return end
    uiVersionChecked = true
    if not remoteVersion or remoteVersion == "" then return end
    if tostring(remoteVersion) ~= tostring(UI_VERSION) then
        ShowNotification(t("ui_outdated"), 2, function()
            switchPage("package")
        end)
    end
end

function loadConfig()
    local function ensureDefaults(c)
        if type(c) == "table" and c.compatibilityMode == nil then
            c.compatibilityMode = true
        end
        return c
    end
    if _G.__DeltaUI_cachedConfig then
        return _G.__DeltaUI_cachedConfig
    end
    if not isfile(configFile) then
        _G.__DeltaUI_cachedConfig = {}
        ensureDefaults(_G.__DeltaUI_cachedConfig)
        return _G.__DeltaUI_cachedConfig
    end
    local content = readfile(configFile)
    if not content then
        _G.__DeltaUI_cachedConfig = {}
        ensureDefaults(_G.__DeltaUI_cachedConfig)
        return _G.__DeltaUI_cachedConfig
    end
    local ok, data = pcall(svc.HttpService.JSONDecode, svc.HttpService, content)
    if ok and type(data) == "table" then
        _G.__DeltaUI_cachedConfig = data
        ensureDefaults(_G.__DeltaUI_cachedConfig)
        return data
    end
    _G.__DeltaUI_cachedConfig = {}
    ensureDefaults(_G.__DeltaUI_cachedConfig)
    return _G.__DeltaUI_cachedConfig
end

do
local translateMap = nil
local translateMapLoaded = false
local translateConn = nil
local originalTexts = {}
local MAX_ORIGINAL_TEXTS = 5000  

function loadTranslateMap()
    if translateMapLoaded then return translateMap end
    local localCachePath = "DeltaUI/Cache/Translate.json"
    local raw = nil

    
    if isfile(localCachePath) then
        local ok, localContent = pcall(function() return readfile(localCachePath) end)
        if ok and localContent and localContent ~= "" and #localContent > 1000 then
            raw = localContent
        end
    end

    
    if not raw or raw == "" then
        local url = "https://github.com/WasKKal/-/raw/refs/heads/main/Translate.json"
        for _ = 1, 3 do
            local ok, result = pcall(function()
                return game:HttpGet(url)
            end)
            if ok and result and result ~= "" and #result > 1000 then
                raw = result
                
                pcall(function()
                    if not isfolder("DeltaUI") then makefolder("DeltaUI") end
                    if not isfolder("DeltaUI/Cache") then makefolder("DeltaUI/Cache") end
                    writefile(localCachePath, raw)
                end)
                break
            end
            task.wait(0.5)
        end
    end

    if not raw or raw == "" then
        warn("[DeltaUI] Failed to load translate map")
        return nil
    end
    local ok, map = pcall(function()
        return svc.HttpService:JSONDecode(raw)
    end)
    if ok and map and type(map) == "table" then

        local filtered = {}
        for lang, subMap in pairs(map) do
            if lang == "en" or lang == "zh" then
                filtered[lang] = subMap
            end
        end
        translateMap = filtered
        translateMapLoaded = true
        return filtered
    end
    warn("[DeltaUI] Translate map parse failed")
    return nil
end

function translateText(text)
    if not text or text == "" then return text end
    if not translateMap then
        translateMap = loadTranslateMap()
    end
    if not translateMap then return text end
    local lang = settingsData.language or "en"

    if lang ~= "en" and lang ~= "zh" then
        return text
    end
    local map = translateMap[lang]
    if not map then return text end
    local result = text
    local protected = {}
    local idx = 1

        local function protectPattern(str, prefix)
        local out = {}
        local oi = 1
        local i = 1
        while i <= #str do
            local c = str:sub(i, i)
            if c == "-" or c == "." or (c >= "0" and c <= "9") then
                local num = c
                i = i + 1
                while i <= #str do
                    local nc = str:sub(i, i)
                    if nc == "-" or nc == "." or (nc >= "0" and nc <= "9") then
                        num = num .. nc
                        i = i + 1
                    else
                        break
                    end
                end
                local key = prefix .. idx .. "__"
                protected[key] = num
                idx = idx + 1
                out[oi] = key
                oi = oi + 1
            else
                out[oi] = c
                oi = oi + 1
                i = i + 1
            end
        end
        return table.concat(out)
    end

    result = protectPattern(result, "__PROT_EQ_")

    local sortedKeys = {}
    for src, dst in pairs(map) do
        if type(src) == "string" and type(dst) == "string" and src ~= "" then
            table.insert(sortedKeys, {src = src, dst = dst, len = #src})
        end
    end
    table.sort(sortedKeys, function(a, b) return a.len > b.len end)
    for _, entry in ipairs(sortedKeys) do
        local ok, newResult = pcall(function()
            return result:gsub(entry.src, entry.dst)
        end)
        if ok then
            result = newResult
        end
    end
    for key, val in pairs(protected) do
        result = result:gsub(key, val)
    end
    return result
end

function scanAndTranslate(container)
    if not container then return end
    local screenGuiRef = screenGui
    local function isInMainUI(obj)
        if not obj or not screenGuiRef then return false end
        local ancestor = obj:FindFirstAncestorOfClass("ScreenGui")
        return ancestor == screenGuiRef
    end
    
    local queue = {container}
    local qHead = 1
    while qHead <= #queue do
        local obj = queue[qHead]
        queue[qHead] = nil
        qHead = qHead + 1
        if obj and obj:IsA("GuiObject") and not isInMainUI(obj) then
            if obj.ClassName:find("Text") then
                local currentText = obj.Text
                if currentText and currentText ~= "" then
                    if not originalTexts[obj] then
                        originalTexts[obj] = currentText
                        originalTexts.__count = (originalTexts.__count or 0) + 1
                        if originalTexts.__count > MAX_ORIGINAL_TEXTS then
                            local k = next(originalTexts)
                            local removed = 0
                            while k and removed < 1000 do
                                if k ~= "__count" then
                                    originalTexts[k] = nil
                                    removed = removed + 1
                                end
                                k = next(originalTexts, k)
                            end
                            originalTexts.__count = originalTexts.__count - removed
                        end
                    end
                    local translated = translateText(currentText)
                    if translated ~= currentText then
                        pcall(function() obj.Text = translated end)
                    end
                end
            end
            local children = obj:GetChildren()
            if children then
                for _, child in ipairs(children) do
                    queue[#queue + 1] = child
                end
            end
        end
    end
end

function startAutoTranslate()
    if translateConn then
        for _, conn in ipairs(translateConn) do
            conn:Disconnect()
        end
        translateConn = nil
    end
    local cfg = loadConfig()
    local paths = cfg.translatePaths or {t("coregui_path")}
    translateConn = {}
    for _, path in ipairs(paths) do
        local target
        if path == t("playergui_path") then
            target = svc.Players.LocalPlayer:WaitForChild("PlayerGui")
        else
            target = svc.CoreGui
        end
        if target then
            scanAndTranslate(target)
            local conn = target.ChildAdded:Connect(function(child)
                task.wait(0.1)
                scanAndTranslate(child)
            end)
            table.insert(translateConn, conn)
            local textConn = target.DescendantAdded:Connect(function(desc)
                task.wait(0.05)
                if desc and desc:IsA("GuiObject") and desc.ClassName:find("Text") then
                    local ok, hasText = pcall(function() return desc.Text ~= nil end)
                    if ok and hasText then
                        local ok2, txt = pcall(function() return desc.Text end)
                        if ok2 and txt and txt ~= "" then
                            if not originalTexts[desc] then
                                originalTexts[desc] = txt
                                originalTexts.__count = (originalTexts.__count or 0) + 1
                                if originalTexts.__count > MAX_ORIGINAL_TEXTS then
                                    local k = next(originalTexts)
                                    local removed = 0
                                    while k and removed < 1000 do
                                        if k ~= "__count" then
                                            originalTexts[k] = nil
                                            removed = removed + 1
                                        end
                                        k = next(originalTexts, k)
                                    end
                                    originalTexts.__count = originalTexts.__count - removed
                                end
                            end
                            local translated = translateText(txt)
                            if translated ~= txt then
                                pcall(function() desc.Text = translated end)
                            end
                        end
                    end
                end
            end)
            table.insert(translateConn, textConn)
        end
    end
end

function stopAutoTranslate()
    if translateConn then
        for _, conn in ipairs(translateConn) do
            conn:Disconnect()
        end
        translateConn = nil
    end
    for obj, text in pairs(originalTexts) do
        if obj and obj.Parent then
            pcall(function()
                obj.Text = text
            end)
        end
    end
    originalTexts = {}
end
end

function getUserAgent()
    local platform = settingsData.networkHeader or "MacOS"
    local interface = settingsData.interfaceType or "Safari"
    local uaMap = {
        ["MacOS_Safari"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        ["MacOS_Chrome"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        ["MacOS_Edge"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        ["Windows_Safari"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        ["Windows_Chrome"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        ["Windows_Edge"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        ["Linux_Safari"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        ["Linux_Chrome"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        ["Linux_Edge"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        ["Android_Safari"] = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        ["Android_Chrome"] = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        ["Android_Edge"] = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        ["iOS_Safari"] = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        ["iOS_Chrome"] = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        ["iOS_Edge"] = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
        ["RobloxClient_RobloxHttpService"] = "Roblox-Client/1.0",
    }
    return uaMap[platform .. "_" .. interface] or uaMap["MacOS_Safari"]
end

function requestWithUA(url)
    local HttpService = svc.HttpService
    local ua = getUserAgent()
    local success, response = pcall(HttpService.RequestAsync, HttpService, {
        Url = url,
        Method = "GET",
        Timeout = 12,
        Headers = {
            ["User-Agent"] = ua,
            ["Accept"] = "text/plain, */*",
            ["Accept-Encoding"] = "identity",
            ["Cache-Control"] = "no-cache"
        }
    })
    if success and response and response.Success then
        return response.Body
    end
    return nil
end

function saveConfig(data)
    if not isfolder("DeltaUI") then makefolder("DeltaUI") end
    local ok, json = pcall(svc.HttpService.JSONEncode, svc.HttpService, data)
    if ok and json then
        writefile(configFile, json)
        _G.__DeltaUI_cachedConfig = data
    end
end

function t(key)
    local cache = _G.__DeltaUI_tCache
    if not cache then
        cache = {}
        _G.__DeltaUI_tCache = cache
    end
    local lang = settingsData.language or "en"
    local cacheKey = lang .. "_" .. key
    if cache[cacheKey] then
        return cache[cacheKey]
    end
    local entry = translations[key]
    local result
    if entry then
        result = entry[lang] or entry.en or key
    else
        result = key
    end
    cache[cacheKey] = result
    return result
end

function registerTranslation(key, entry)
    if type(key) ~= "string" or type(entry) ~= "table" then
        return
    end
    if translations[key] then
        return
    end
    translations[key] = entry
end

cloudPage = create("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 2})
cloudSearchBox = create("Frame", {Position = UDim2.new(0, 12, 0, 8), Size = UDim2.new(1, -52, 0, 32), BackgroundColor3 = theme.surface, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 5})
corner(8, cloudSearchBox)
stroke(theme.border, 1, cloudSearchBox)
cloudSearchBox.Parent = cloudPage
cloudSearchIcon = GetIcon("search", UDim2.new(0, 14, 0, 14), theme.textDim)
if cloudSearchIcon then
    cloudSearchIcon.Position = UDim2.new(0, 10, 0.5, -7)
    cloudSearchIcon.Parent = cloudSearchBox
end
cloudSearchInput = create("TextBox", {Position = UDim2.new(0, 30, 0, 0), Size = UDim2.new(1, -40, 1, 0), BackgroundTransparency = 1, Text = "", PlaceholderText = t("search_cloud_placeholder"), PlaceholderColor3 = theme.textDim, TextColor3 = theme.text, TextSize = 12, Font = Enum.Font.SourceSans, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, ClearTextOnFocus = false, ZIndex = 4})
cloudSearchInput.Parent = cloudSearchBox
create("UIPadding", {PaddingLeft = UDim.new(0, 5)}).Parent = cloudSearchInput
table.insert(settingsData.uiRefs, {element = cloudSearchInput, key = "search_cloud_placeholder"})
cloudRefreshBtn = create("TextButton", {Position = UDim2.new(1, -38, 0, 8), Size = UDim2.new(0, 32, 0, 32), BackgroundColor3 = theme.surface, BackgroundTransparency = 0.25, BorderSizePixel = 0, Text = "", ZIndex = 3})
corner(8, cloudRefreshBtn)
stroke(theme.border, 1, cloudRefreshBtn)
cloudRefreshBtn.Parent = cloudPage
cloudRefreshIcon = GetIcon("rotate-ccw", UDim2.new(0, 16, 0, 16), theme.text)
if cloudRefreshIcon then
    cloudRefreshIcon.Position = UDim2.new(0.5, -8, 0.5, -8)
    cloudRefreshIcon.Parent = cloudRefreshBtn
end
cloudRefreshBtn.MouseButton1Click:Connect(function()
    if cloudRefreshIcon then
        local rotation = 0
        local conn = svc.RunService.RenderStepped:Connect(function(dt)
            rotation = rotation - 720 * dt
            cloudRefreshIcon.Rotation = rotation
        end)
        task.delay(0.5, function()
            conn:Disconnect()
            cloudRefreshIcon.Rotation = 0
        end)
    end
    refreshScriptBloxList(cloudSearchInput.Text)
    ShowNotification(t("refresh_complete"), 1)
end)

cloudScroll = create("ScrollingFrame", {Position = UDim2.new(0, 12, 0, 52), Size = UDim2.new(1, -24, 1, -64), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = theme.textDim, CanvasSize = UDim2.new(0, 0, 0, 0), ClipsDescendants = true, ZIndex = 3})
cloudScroll.Parent = cloudPage
cloudScroll.Visible = false
cloudGrid = create("UIGridLayout", {CellSize = UDim2.new(0, 180, 0, 140), CellPadding = UDim2.new(0, 8, 0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Top, FillDirection = Enum.FillDirection.Horizontal})
cloudGrid.Parent = cloudScroll
cloudGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    if cloudScroll and cloudGrid and cloudScroll.Parent then
        local absSize = cloudGrid.AbsoluteContentSize
        if absSize then
            cloudScroll.CanvasSize = UDim2.new(0, 0, 0, absSize.Y + 16)
        end
    end
end)

cacheFolder = "DeltaUI/Cache"
function ensureCacheFolder()
    if not isfolder("DeltaUI") then makefolder("DeltaUI") end
    if not isfolder(cacheFolder) then makefolder(cacheFolder) end
end

function getCachedIcon(url, name)
    if not url or url == "" then return nil end
    if url:sub(1,13) == "rbxassetid://" then
        return url
    end
    ensureCacheFolder()
    local nameSafe = name and __safeFilterName(name) or ""
    local urlSafe = __safeFilterName(url)

    local cacheKey = nameSafe .. "_" .. urlSafe
    if #cacheKey > 120 then cacheKey = cacheKey:sub(1, 120) end
    local fp = cacheFolder .. "/img_" .. cacheKey .. ".png"
    local getasset = getcustomasset or getsynasset
    if isfile(fp) then
        if getasset then
            return getasset(fp)
        end
        return url
    end
    local ok, data = pcall(function()
        return game:HttpGet(url)
    end)
    if ok and data and data ~= "" then
        writefile(fp, data)
        if getasset then
            return getasset(fp)
        end
        return url
    end
    return nil
end
_G.__DeltaUI_getCachedIcon = getCachedIcon

modelFolder = "DeltaUI/Model"
patchFolder = "Delta/Patch"
exportFolder = "DeltaUI/Export"
function ensureExportFolder()
    if not isfolder("DeltaUI") then makefolder("DeltaUI") end
    if not isfolder(exportFolder) then makefolder(exportFolder) end
end
function ensureModelFolder()
    if not isfolder("DeltaUI") then makefolder("DeltaUI") end
    if not isfolder(modelFolder) then makefolder(modelFolder) end
end
function ensurePatchFolder()
    if not isfolder("Delta") then makefolder("Delta") end
    if not isfolder(patchFolder) then makefolder(patchFolder) end
end
assetFolder = "DeltaUI/Asset"
function ensureAssetFolder()
    if not isfolder("DeltaUI") then makefolder("DeltaUI") end
    if not isfolder(assetFolder) then makefolder(assetFolder) end
end
function initFloatingBallIcon()
    ensureAssetFolder()
    local iconPath = assetFolder .. "/icon.png"
    if not isfile(iconPath) then
        local ok, imgData = pcall(function()
            return game:HttpGet("https://github.com/WasKKal/-/raw/refs/heads/main/IMG_2929.jpeg")
        end)
        if ok and imgData and imgData ~= "" then
            writefile(iconPath, imgData)
        end
    end
    if isfile(iconPath) then
        local getasset = getcustomasset or getsynasset
        if getasset then
            local assetUrl = getasset(iconPath)
            if assetUrl and assetUrl ~= "" then
                orbFrame.BackgroundColor3 = Color3.fromRGB(255,255,255)
                for _, child in pairs(orbFrame:GetChildren()) do
                    if child:IsA("ImageLabel") then
                        child:Destroy()
                    end
                end
                orbImg = create("ImageLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Image = assetUrl, ZIndex = 102})
                local orbCorner = orbFrame:FindFirstChildOfClass("UICorner")
                if orbCorner then
                    corner(orbCorner.CornerRadius.Offset, orbImg)
                else
                    corner(8, orbImg)
                end
                orbImg.Parent = orbFrame
            end
        end
    end
    local cfg = loadConfig()
    if cfg.orbBorderColor and type(cfg.orbBorderColor) == "table" then
        local c = cfg.orbBorderColor
        if c.r and c.g and c.b and orbStroke then
            orbStroke.Color = Color3.fromRGB(c.r, c.g, c.b)
        end
    end
end
installedModules = {}

_G.__DeltaUI_installedModules = installedModules

storeScriptFolder = "DeltaUI/StoreScripts"

function ensureStoreFolder()
    if not isfolder("DeltaUI") then makefolder("DeltaUI") end
    if not isfolder(storeScriptFolder) then makefolder(storeScriptFolder) end
end

function loadInstalledModules()

function runAutoExecScripts()
    local cfg = loadConfig()
    if not cfg.autoExec then return end
    ensureFolder()
    ensureStoreFolder()
    local allScripts = {}
    local files = listfiles(saveFolder) or {}
    if files then
        for _, fp in ipairs(files) do
            if fp:sub(-4) == ".lua" then
local name = fp:gsub(".*[/]", ""):gsub("%.lua$", ""):gsub("%.json$", "")
                if name then
                    table.insert(allScripts, {name = name, path = fp, fromStore = false})
                end
            end
        end
    end
    local storeFiles = listfiles(storeScriptFolder) or {}
    if storeFiles then
        for _, fp in ipairs(storeFiles) do
            if fp:sub(-5) == ".json" then
                local txt = readfile(fp)
                if txt then
                    local meta = svc.HttpService:JSONDecode(txt)
                    if meta and meta.name then
                        table.insert(allScripts, {name = meta.name, path = fp, fromStore = true, meta = meta})
                    end
                end
            end
        end
    end
    for _, script in ipairs(allScripts) do
        if getAutoExecFileState(script.name) then
            local code
            if script.fromStore and script.meta and script.meta.Url then
                local src = game:HttpGet(script.meta.Url)
                if src then
                    code = src
                end
            else
                code = readfile(script.path)
            end
            if code and code ~= "" then
                local fn, err = loadstring(code)
                if fn then
                    local ok, execErr = xpcall(fn, function(err)
                        return debug.traceback(tostring(err), 2)
                    end)
                    if not ok then
                        warn("[DeltaUI] Autoexec error: " .. tostring(execErr))
                    end
                else
                    warn("[DeltaUI] Autoexec compile error: " .. tostring(err))
                end
            end
        end
    end
end

HookManager = {active = {}, originals = {}, hooks = {}}

function HookManager.getAvailableApi()
    local apis = {"hookfunction", "replaceclosure", "hookmetamethod", "hookfunc"}
    for _, name in ipairs(apis) do
        local ok, ref = pcall(function() return _G[name] or getfenv()[name] end)
        if ok and type(ref) == "function" then
            return ref, name
        end
    end
    return nil, nil
end

function HookManager.isRobloxFunc(fn)
    if type(fn) ~= "function" then return false end
    local ok, info = pcall(debug.getinfo, fn)
    if not ok or not info then return false end
    return info.what == "C" or info.source == "=[C]"
end

function HookManager.hook(target, replacement)
    if type(target) ~= "function" then
        warn("[HookManager] Target is not a function")
        return false
    end
    if type(replacement) ~= "function" then
        warn("[HookManager] Replacement is not a function")
        return false
    end
    local id = __safeFilterName(tostring(target))
    if HookManager.active[id] then
        HookManager.unhook(target)
    end
    local api, apiName = HookManager.getAvailableApi()
    local original = target
    local success = false
    if api and apiName == "hookfunction" then
        local ok, result = pcall(api, target, replacement)
        if ok and type(result) == "function" then
            original = result
            success = true
        end
    elseif api and apiName == "replaceclosure" then
        local ok, old = pcall(api, target, replacement)
        if ok then
            original = old or target
            success = true
        end
    end
    if not success then
        original = target
        local env = getfenv(target)
        if env and env.script then
            local ok, mt = pcall(getrawmetatable, env)
            if ok and mt and mt.__index and type(mt.__index) == "table" then
                for k, v in pairs(mt.__index) do
                    if v == target then
                        mt.__index[k] = replacement
                        success = true
                        break
                    end
                end
            end
        end
    end
    if not success then
        original = target
        success = true
    end
    HookManager.originals[id] = original
    HookManager.hooks[id] = replacement
    HookManager.active[id] = {
        target = target,
        replacement = replacement,
        original = original,
        api = apiName or "direct",
        direct = not api
    }
    if success and not api then
        local parent = getfenv(target)
        if parent then
            for k, v in pairs(parent) do
                if v == target then
                    parent[k] = replacement
                    HookManager.active[id].parent = parent
                    HookManager.active[id].key = k
                    break
                end
            end
        end
    end
    return success
end

function HookManager.unhook(target)
    local id = __safeFilterName(tostring(target))
    local record = HookManager.active[id]
    if not record then return false end
    local restored = false
    if record.api == "hookfunction" and HookManager.getAvailableApi() then
        local api = HookManager.getAvailableApi()
        if api and record.original then
            local ok = pcall(api, target, record.original)
            restored = ok
        end
    end
    if not restored and record.direct and record.parent and record.key then
        record.parent[record.key] = record.original
        restored = true
    end
    if not restored then
        local env = getfenv(target)
        if env then
            for k, v in pairs(env) do
                if v == record.replacement then
                    env[k] = record.original
                    restored = true
                    break
                end
            end
        end
    end
    if not restored and record.original then
        local gc = getgc and getgc()
        if gc then
            for _, obj in ipairs(gc) do
                if obj == record.replacement then
                    local ok = pcall(function()
                        local info = debug.getinfo(obj)
                        return info and info.func
                    end)
                    if not ok then
                        for i = 1, 10 do
                            local ok2, up = pcall(debug.getupvalue, obj, i)
                            if ok2 and up == record.replacement then
                                pcall(debug.setupvalue, obj, i, record.original)
                            end
                        end
                    end
                end
            end
        end
    end
    HookManager.active[id] = nil
    HookManager.originals[id] = nil
    HookManager.hooks[id] = nil
    return restored
end

function HookManager.callOriginal(id, ...)
    local orig = HookManager.originals[id]
    if type(orig) == "function" then
        return orig(...)
    end
    return nil
end

function HookManager.wrapAntiKick(targetPlayer)
    if not targetPlayer or typeof(targetPlayer) ~= "Instance" or not targetPlayer:IsA("Player") then
        warn("[HookManager] Invalid player instance")
        return nil, nil
    end
    local kickMethod = targetPlayer.Kick
    if not kickMethod then
        warn("[HookManager] Kick method not found")
        return nil, nil
    end
    local id = "Kick_" .. tostring(targetPlayer.UserId)
    local wrapper = function(self, ...)
        if self ~= targetPlayer then
            local ok, result = pcall(HookManager.callOriginal, id, self, ...)
            if ok then return result end
            return nil
        end
        warn("[DeltaUI] Kick blocked for " .. tostring(targetPlayer.Name))
        return nil
    end
    local ok = HookManager.hook(kickMethod, wrapper)
    if ok then
        return wrapper, function()
            HookManager.unhook(kickMethod)
        end
    end
    return nil, nil
end

function HookManager.wrapTeleport(targetService)
    local tp = targetService or game:GetService("TeleportService")
    local methods = {"Teleport", "TeleportToPlaceInstance", "TeleportAsync"}
    local unhookers = {}
    for _, name in ipairs(methods) do
        local fn = tp[name]
        if type(fn) == "function" then
            local wrapper = function(...)
                warn("[DeltaUI] Teleport blocked: " .. name)
                return nil
            end
            if HookManager.hook(fn, wrapper) then
                table.insert(unhookers, function()
                    HookManager.unhook(fn)
                end)
            end
        end
    end
    return function()
        for _, fn in ipairs(unhookers) do
            pcall(fn)
        end
    end
end

function HookManager.status()
    local count = 0
    for _ in pairs(HookManager.active) do count = count + 1 end
    return count, HookManager.getAvailableApi()
end

    installedModules = {}
    ensureModelFolder()
    local files = listfiles(modelFolder) or {}
    if files then
        for _, fp in ipairs(files) do
            if fp:sub(-5) == ".json" then
                local txt = readfile(fp)
                if txt then
                    local data = svc.HttpService:JSONDecode(txt)
                    if type(data) == "table" and data.name then
                        installedModules[data.name] = data
                    end
                end
            end
        end
    end
    ensurePatchFolder()
    local pfiles = listfiles(patchFolder) or {}
    if pfiles then
        for _, fp in ipairs(pfiles) do
            if fp:sub(-5) == ".json" then
                local txt = readfile(fp)
                if txt then
                    local data = svc.HttpService:JSONDecode(txt)
                    if type(data) == "table" and data.name then
                        installedModules[data.name] = data
                    end
                end
            end
        end
    end
    ensureStoreFolder()
    local sfiles = listfiles(storeScriptFolder) or {}
    if sfiles then
        for _, fp in ipairs(sfiles) do
            if fp:sub(-5) == ".json" then
                local txt = readfile(fp)
                if txt then
                    local data = svc.HttpService:JSONDecode(txt)
                    if type(data) == "table" and data.name then
                        installedModules[data.name] = data
                    end
                end
            end
        end
    end
end
loadInstalledModules()

function makeSettingRow(titleKey, descKey, layoutOrder)
    local row = create("Frame", {Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = theme.surface, BackgroundTransparency = 0.3, BorderSizePixel = 0, LayoutOrder = layoutOrder, ZIndex = 4})
    corner(12, row)
    local tLabel = create("TextLabel", {Position = UDim2.new(0, 16, 0, 8), Size = UDim2.new(0.5, -10, 0, 20), BackgroundTransparency = 1, Text = t(titleKey), TextColor3 = theme.text, TextSize = 13, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5})
    tLabel.Parent = row
    local dLabel = create("TextLabel", {Position = UDim2.new(0, 16, 0, 28), Size = UDim2.new(0.5, -10, 0, 18), BackgroundTransparency = 1, Text = t(descKey), TextColor3 = theme.textDim, TextSize = 10, Font = Enum.Font.SourceSans, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5})
    dLabel.Parent = row
    table.insert(settingsData.uiRefs, {element = tLabel, key = titleKey})
    table.insert(settingsData.uiRefs, {element = dLabel, key = descKey})
    
    row.MouseEnter:Connect(function()
        svc.TweenService:Create(row, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.12}):Play()
    end)
    row.MouseLeave:Connect(function()
        svc.TweenService:Create(row, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.3}):Play()
    end)
    return row
end

function makeActionButton(key, parent, callback)
    local btn = create("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 110, 0, 32), BackgroundColor3 = theme.accent, BackgroundTransparency = 0.25, Text = "", BorderSizePixel = 0, ZIndex = 5})
    applyGradient(btn, theme.accent, theme.accent2, 120)
    corner(8, btn)
    local txt = create("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = t(key), TextColor3 = Color3.fromRGB(255,255,255), TextSize = 12, Font = Enum.Font.SourceSansBold, ZIndex = 6})
    txt.Parent = btn
    btn.Parent = parent
    btn.MouseButton1Click:Connect(function()
        callback()
    end)
    table.insert(settingsData.uiRefs, {element = txt, key = key})
    return btn
end

function makeToggle(parent, initialState, callback, configKey)
    local cfg = loadConfig()
    local savedState = configKey and cfg[configKey]
    if savedState ~= nil then
        initialState = savedState
    end
    local toggleBg = create("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 48, 0, 26), BackgroundColor3 = initialState and theme.accent or theme.surfaceLight, BackgroundTransparency = 0.3, BorderSizePixel = 0, Text = "", ZIndex = 5})
    corner(13, toggleBg)

    local knob = create("Frame", {AnchorPoint = Vector2.new(0, 0.5), Position = initialState and UDim2.new(1, -22, 0.5, 0) or UDim2.new(0, 4, 0.5, 0), Size = UDim2.new(0, 18, 0, 18), BackgroundColor3 = Color3.fromRGB(255,255,255), BorderSizePixel = 0, ZIndex = 6})
    corner(9, knob)
    knob.Parent = toggleBg
    toggleBg.Parent = parent
    local state = initialState
    toggleBg.MouseButton1Click:Connect(function()
        state = not state
        svc.TweenService:Create(toggleBg, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = state and theme.accent or theme.surfaceLight}):Play()
        svc.TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = state and UDim2.new(1, -22, 0.5, 0) or UDim2.new(0, 4, 0.5, 0)}):Play()
        callback(state)

        if configKey then
            local cfg2 = loadConfig()
            cfg2[configKey] = state
            saveConfig(cfg2)
        end
    end)
    local function setState(newState)
        if state == newState then return end
        state = newState
        svc.TweenService:Create(toggleBg, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = state and theme.accent or theme.surfaceLight}):Play()
        svc.TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = state and UDim2.new(1, -22, 0.5, 0) or UDim2.new(0, 4, 0.5, 0)}):Play()
        callback(state)
        if configKey then
            local cfg2 = loadConfig()
            cfg2[configKey] = state
            saveConfig(cfg2)
        end
    end
    return toggleBg, function() return state end, setState
end


local deepCustomLayoutEnabled = false

function applyDeepCustomLayout(state)
    deepCustomLayoutEnabled = state
    if state then
        navBg.AnchorPoint = Vector2.new(1, 0.5)
        navBg.Position = UDim2.new(1, -10, 0.5, 0)
        logoutBtn.AnchorPoint = Vector2.new(1, 0.5)
        logoutBtn.Position = UDim2.new(1, -10, 0.5, 152)
        wrapperFrame.Position = UDim2.new(1, -64, 0, 86)
        statsRow.Position = UDim2.new(1, -64, 0, 60)
    else
        navBg.AnchorPoint = Vector2.new(0, 0.5)
        navBg.Position = UDim2.new(0, 10, 0.5, 0)
        logoutBtn.AnchorPoint = Vector2.new(0, 0.5)
        logoutBtn.Position = UDim2.new(0, 10, 0.5, 152)
        wrapperFrame.Position = UDim2.new(1, -10, 0, 86)
        statsRow.Position = UDim2.new(1, -10, 0, 60)
    end
end

function makeDropdown(parent, options, defaultIndex, callback, configKey)
    local cfg = loadConfig()
    local savedValue = configKey and cfg[configKey]
    local current = options[defaultIndex] or options[1]
    if savedValue then
        for i, opt in ipairs(options) do
            if opt == savedValue then
                current = opt
                break
            end
        end
    end

    if configKey == "language" and savedValue then
        local reverseLangMap = {en = "English", zh = "中文", ko = "한국어", ja = "日本語"}
        local mapped = reverseLangMap[savedValue]
        if mapped then
            current = mapped
        end
    end
    local btn = create("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 120, 0, 32), BackgroundColor3 = theme.surfaceLight, BackgroundTransparency = 0.3, Text = "", BorderSizePixel = 0, ZIndex = 5})
    corner(8, btn)
    local txt = create("TextLabel", {Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -30, 1, 0), BackgroundTransparency = 1, Text = current, TextColor3 = theme.text, TextSize = 12, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6})
    txt.Parent = btn
    local arrow = GetIcon("chevron-down", UDim2.new(0, 14, 0, 14), theme.textDim)
    if arrow then
        arrow.Position = UDim2.new(1, -20, 0.5, -7)
        arrow.Parent = btn
    end
    btn.Parent = parent
    local dropdownOpen = false
    local listFrame = nil

    if not _G.__DeltaUI_dropdowns then _G.__DeltaUI_dropdowns = {} end
    table.insert(_G.__DeltaUI_dropdowns, {btn = btn, close = function()
        if dropdownOpen and listFrame then
            listFrame:Destroy()
            listFrame = nil
            dropdownOpen = false
        end
        if _G.__DeltaUI_dropdownOverlay then
            _G.__DeltaUI_dropdownOverlay:Destroy()
            _G.__DeltaUI_dropdownOverlay = nil
        end
    end})

    btn.MouseButton1Click:Connect(function()
        if dropdownOpen and listFrame then
            listFrame:Destroy()
            listFrame = nil
            dropdownOpen = false
            if _G.__DeltaUI_dropdownOverlay then
                _G.__DeltaUI_dropdownOverlay:Destroy()
                _G.__DeltaUI_dropdownOverlay = nil
            end
            return
        end

        for _, dd in ipairs(_G.__DeltaUI_dropdowns or {}) do
            if dd.btn ~= btn and dd.close then
                dd.close()
            end
        end

        dropdownOpen = true

        local screenGuiAncestor = btn:FindFirstAncestorOfClass("ScreenGui")
        local overlay = create("TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 998,
            BorderSizePixel = 0
        })
        overlay.Parent = screenGuiAncestor
        _G.__DeltaUI_dropdownOverlay = overlay

        overlay.MouseButton1Click:Connect(function()
            for _, dd in ipairs(_G.__DeltaUI_dropdowns or {}) do
                if dd.close then dd.close() end
            end
        end)

        listFrame = create("Frame", {
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(0, 120, 0, #options * 30),
            BackgroundColor3 = theme.surfaceLight,
            BackgroundTransparency = 0.15,
            BorderSizePixel = 0,
            ZIndex = 999,
            ClipsDescendants = false
        })
        corner(8, listFrame)
        stroke(theme.border, 1, listFrame)
        listFrame.Parent = screenGuiAncestor
        task.defer(function()
            if listFrame and listFrame.Parent then
                listFrame.Position = UDim2.new(0, btn.AbsolutePosition.X, 0, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y + 4)
                listFrame.Size = UDim2.new(0, btn.AbsoluteSize.X, 0, #options * 30)
            end
        end)
        local scrollConn = nil
        scrollConn = svc.RunService.RenderStepped:Connect(function()
            if not listFrame or not listFrame.Parent then
                if scrollConn then scrollConn:Disconnect() end
                return
            end
            if btn and btn.Parent then
                listFrame.Position = UDim2.new(0, btn.AbsolutePosition.X, 0, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y + 4)
            end
        end)
        for i, opt in ipairs(options) do
            local optBtn = create("TextButton", {Position = UDim2.new(0, 0, 0, (i-1)*30), Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "", ZIndex = 1000})
            local optTxt = create("TextLabel", {Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -20, 1, 0), BackgroundTransparency = 1, Text = opt, TextColor3 = theme.text, TextSize = 12, Font = Enum.Font.SourceSans, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 1001})
            optTxt.Parent = optBtn
            optBtn.Parent = listFrame
            optBtn.MouseButton1Click:Connect(function()
                current = opt
                txt.Text = current
                if scrollConn then scrollConn:Disconnect() end
                if listFrame then
                    listFrame:Destroy()
                    listFrame = nil
                end
                dropdownOpen = false
                if _G.__DeltaUI_dropdownOverlay then
                    _G.__DeltaUI_dropdownOverlay:Destroy()
                    _G.__DeltaUI_dropdownOverlay = nil
                end
                local saveValue = callback(current)
                if configKey then
                    local cfg2 = loadConfig()
                    cfg2[configKey] = saveValue or current
                    saveConfig(cfg2)
                end
            end)
        end
    end)
    local function setValue(val)
        for _, opt in ipairs(options) do
            if opt == val then
                current = val
                txt.Text = current
                break
            end
        end
    end
    local function updateOptions(newOptions)
        options = newOptions

        local found = false
        for _, opt in ipairs(options) do
            if opt == current then
                found = true
                break
            end
        end
        if not found and #options > 0 then
            current = options[1]
            txt.Text = current
        end
    end
    return btn, function() return current end, setValue, updateOptions
end

function makeMultiDropdown(parent, options, defaultSelected, callback, configKey)
    local cfg = loadConfig()
    local savedValue = configKey and cfg[configKey]
    local selected = {}
    if savedValue and type(savedValue) == "table" then
        for _, v in ipairs(savedValue) do
            selected[v] = true
        end
    elseif defaultSelected and type(defaultSelected) == "table" then
        for _, v in ipairs(defaultSelected) do
            selected[v] = true
        end
    end

    local btn = create("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 120, 0, 32), BackgroundColor3 = theme.surfaceLight, BackgroundTransparency = 0.3, Text = "", BorderSizePixel = 0, ZIndex = 5})
    corner(8, btn)
    local txt = create("TextLabel", {Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -30, 1, 0), BackgroundTransparency = 1, Text = "Select", TextColor3 = theme.text, TextSize = 12, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6})
    txt.Parent = btn
    local arrow = GetIcon("chevron-down", UDim2.new(0, 14, 0, 14), theme.textDim)
    if arrow then
        arrow.Position = UDim2.new(1, -20, 0.5, -7)
        arrow.Parent = btn
    end
    btn.Parent = parent

    local function updateDisplay()
        local count = 0
        local display = ""
        for opt, isSel in pairs(selected) do
            if isSel then
                count = count + 1
                display = opt
            end
        end
        if count == 0 then
            txt.Text = "Select"
        elseif count == 1 then
            txt.Text = display
        else
            txt.Text = count .. " selected"
        end
    end
    updateDisplay()

    local dropdownOpen = false
    local listFrame = nil

    if not _G.__DeltaUI_dropdowns then _G.__DeltaUI_dropdowns = {} end
    table.insert(_G.__DeltaUI_dropdowns, {btn = btn, close = function()
        if dropdownOpen and listFrame then
            listFrame:Destroy()
            listFrame = nil
            dropdownOpen = false
        end
        if _G.__DeltaUI_dropdownOverlay then
            _G.__DeltaUI_dropdownOverlay:Destroy()
            _G.__DeltaUI_dropdownOverlay = nil
        end
    end})

    btn.MouseButton1Click:Connect(function()
        if dropdownOpen and listFrame then
            listFrame:Destroy()
            listFrame = nil
            dropdownOpen = false
            return
        end

        for _, dd in ipairs(_G.__DeltaUI_dropdowns or {}) do
            if dd.btn ~= btn and dd.close then
                dd.close()
            end
        end

        dropdownOpen = true

        local screenGuiAncestor = btn:FindFirstAncestorOfClass("ScreenGui")
        local overlay = create("TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 998,
            BorderSizePixel = 0
        })
        overlay.Parent = screenGuiAncestor
        _G.__DeltaUI_dropdownOverlay = overlay

        overlay.MouseButton1Click:Connect(function()
            for _, dd in ipairs(_G.__DeltaUI_dropdowns or {}) do
                if dd.close then dd.close() end
            end
        end)

        listFrame = create("Frame", {
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(0, 120, 0, #options * 34),
            BackgroundColor3 = theme.surfaceLight,
            BackgroundTransparency = 0.15,
            BorderSizePixel = 0,
            ZIndex = 999,
            ClipsDescendants = false
        })
        corner(8, listFrame)
        stroke(theme.border, 1, listFrame)
        listFrame.Parent = screenGuiAncestor
        task.defer(function()
            if listFrame and listFrame.Parent then
                listFrame.Position = UDim2.new(0, btn.AbsolutePosition.X, 0, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y + 4)
                listFrame.Size = UDim2.new(0, btn.AbsoluteSize.X, 0, #options * 34)
            end
        end)
        local scrollConn = nil
        scrollConn = svc.RunService.RenderStepped:Connect(function()
            if not listFrame or not listFrame.Parent then
                if scrollConn then scrollConn:Disconnect() end
                return
            end
            if btn and btn.Parent then
                listFrame.Position = UDim2.new(0, btn.AbsolutePosition.X, 0, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y + 4)
            end
        end)
        for i, opt in ipairs(options) do
            local optBtn = create("TextButton", {Position = UDim2.new(0, 0, 0, (i-1)*34), Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Text = "", ZIndex = 1000})

            local checkBox = create("Frame", {Position = UDim2.new(0, 10, 0.5, -7), Size = UDim2.new(0, 14, 0, 14), BackgroundColor3 = selected[opt] and theme.accent or theme.surfaceLight, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 1001})
            corner(3, checkBox)
            checkBox.Parent = optBtn
        
            local optTxt = create("TextLabel", {Position = UDim2.new(0, 30, 0, 0), Size = UDim2.new(1, -40, 1, 0), BackgroundTransparency = 1, Text = opt, TextColor3 = theme.text, TextSize = 12, Font = Enum.Font.SourceSans, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 1001})
            optTxt.Parent = optBtn
            optBtn.Parent = listFrame
            optBtn.MouseButton1Click:Connect(function()
                selected[opt] = not selected[opt]
                svc.TweenService:Create(checkBox, TweenInfo.new(0.15), {BackgroundColor3 = selected[opt] and theme.accent or theme.surfaceLight}):Play()
                updateDisplay()
                local result = {}
                for k, v in pairs(selected) do
                    if v then table.insert(result, k) end
                end
                callback(result)
                if configKey then
                    local cfg2 = loadConfig()
                    cfg2[configKey] = result
                    saveConfig(cfg2)
                end
            end)
        end
    end)

    local function getSelected()
        local result = {}
        for k, v in pairs(selected) do
            if v then table.insert(result, k) end
        end
        return result
    end

    local function setSelected(vals)
        selected = {}
        for _, v in ipairs(vals) do
            selected[v] = true
        end
        updateDisplay()
    end

    return btn, getSelected, setSelected
end
_G.__DeltaUI_t = t

tpService = game:GetService("TeleportService")
vUser = game:GetService("VirtualUser")

pages = {}

settingsPage = create("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 2})
pages["settings"] = settingsPage


settingsHeaderBar = create("Frame", {
    Size = UDim2.new(1, 0, 0, 32),
    BackgroundColor3 = theme.surfaceLight,
    BackgroundTransparency = 0.5,
    BorderSizePixel = 0,
    ZIndex = 4,
})
corner(theme.radius, settingsHeaderBar)
stroke(theme.border, 1, settingsHeaderBar)
settingsHeaderBar.Parent = settingsPage
settingsHeaderIcon = GetIcon("settings", UDim2.new(0, 15, 0, 15))
if settingsHeaderIcon then
    settingsHeaderIcon.Position = UDim2.new(0, 12, 0.5, -7)
    settingsHeaderIcon.ImageColor3 = theme.accent
    settingsHeaderIcon.Parent = settingsHeaderBar
end
settingsHeaderTitle = create("TextLabel", {
    Position = UDim2.new(0, settingsHeaderIcon and 34 or 12, 0, 0),
    Size = UDim2.new(1, -60, 1, 0),
    BackgroundTransparency = 1,
    Text = "设置 / Settings",
    TextColor3 = theme.textDim,
    TextSize = 12,
    Font = Enum.Font.SourceSansBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 5,
})
settingsHeaderTitle.Parent = settingsHeaderBar

settingsScroll = create("ScrollingFrame", {Position = UDim2.new(0, 14, 0, 50), Size = UDim2.new(1, -28, 1, -62), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = theme.textDim, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 3})
settingsScroll.Parent = settingsPage

settingsList = create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10)})
settingsList.Parent = settingsScroll

create("UIPadding", {
    PaddingLeft = UDim.new(0, 4),
    PaddingRight = UDim.new(0, 12),
    PaddingTop = UDim.new(0, 0),
    PaddingBottom = UDim.new(0, 0),
}).Parent = settingsScroll
settingsList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    if settingsScroll and settingsScroll.Parent then
        local absSize = settingsList.AbsoluteContentSize
        if absSize then
            settingsScroll.CanvasSize = UDim2.new(0, 0, 0, absSize.Y + 20)
        end
    end
end)



function makeSectionCard(titleText, titleKey, iconName, layoutOrder)
    local card = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = theme.surfaceLight,
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        LayoutOrder = layoutOrder,
        ZIndex = 3,
        Parent = settingsScroll,
    })
    corner(theme.radiusLg, card)
    stroke(theme.border, 1, card)
    local cardList = create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
    })
    cardList.Parent = card
    create("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        PaddingTop = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 10),
    }).Parent = card

    
    local headerBar = create("Frame", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        LayoutOrder = -1,
        ZIndex = 4,
    })
    headerBar.Parent = card
    local accentBar = create("Frame", {
        Size = UDim2.new(0, 3, 0, 14),
        Position = UDim2.new(0, 2, 0.5, -7),
        BackgroundColor3 = theme.accent,
        BorderSizePixel = 0,
        ZIndex = 5,
    })
    applyGradient(accentBar, theme.accent, theme.accent2, 90)
    corner(2, accentBar)
    accentBar.Parent = headerBar
    local sectionIcon = nil
    if iconName and GetIcon then
        sectionIcon = GetIcon(iconName, UDim2.new(0, 15, 0, 15))
        if sectionIcon then
            sectionIcon.Position = UDim2.new(0, 13, 0.5, -7)
            sectionIcon.ImageColor3 = theme.accent
            sectionIcon.Parent = headerBar
        end
    end
    local headerLabel = create("TextLabel", {
        Position = UDim2.new(0, sectionIcon and 34 or 12, 0, 0),
        Size = UDim2.new(1, -(sectionIcon and 40 or 20), 1, 0),
        BackgroundTransparency = 1,
        Text = titleText,
        TextColor3 = theme.text,
        TextSize = 13,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 5,
    })
    headerLabel.Parent = headerBar
    if titleKey then
        table.insert(settingsData.uiRefs, {element = headerLabel, key = titleKey})
    end

    
    local content = create("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex = 4,
    })
    content.Parent = card
    local contentList = create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
    })
    contentList.Parent = content
    return content
end



__secGeneral = makeSectionCard("常规设置", nil, "settings", -3)


rowBypass = makeSettingRow("bypass_ui_detection", "bypass_ui_detection_desc", 5)
makeToggle(rowBypass, false, function(state)
    local cfgBypass = loadConfig()
    cfgBypass.bypassUiDetection = state
    saveConfig(cfgBypass)
    task.wait(0.3)
    pcall(function()
        tpService:TeleportToPlaceInstance(game.PlaceId, game.JobId, v7)
    end)
end, "bypassUiDetection")
rowBypass.Parent = settingsScroll

rowAutoAcceptExec = makeSettingRow("auto_accept_exec", "auto_accept_exec_desc", -7)
makeToggle(rowAutoAcceptExec, false, function(state)
    local cfg = loadConfig()
    cfg.autoAcceptExec = state
    saveConfig(cfg)
end, "autoAcceptExec")
rowAutoAcceptExec.Parent = settingsScroll
rowInit = makeSettingRow("init_ui", "init_ui_desc", -1)
local function onInitUI()
    local function deleteFolder(path)
        local files = listfiles(path) or {}
        for _, fp in ipairs(files) do
            if isfile(fp) then
                pcall(delfile, fp)
            elseif isfolder(fp) then
                pcall(deleteFolder, fp)
                pcall(delfolder, fp)
            end
        end
    end
    if isfolder("DeltaUI") then
        deleteFolder("DeltaUI")
    end
    if isfolder("DeltaUI") then
        deleteFolder("DeltaUI")
    end
    ShowNotification(t("complete"), 2)
end
makeActionButton("click_here", rowInit, onInitUI)
rowInit.Parent = settingsScroll

row0 = makeSettingRow("language", "language_desc", 3.5)
local function onLanguageChange(val)
    local langMap = {["English"] = "en", ["中文"] = "zh", ["한국어"] = "ko", ["日本語"] = "ja"}
    settingsData.language = langMap[val] or "en"
    for _, ref in ipairs(settingsData.uiRefs) do
        if ref.element and ref.element.Parent then
            ref.element.Text = t(ref.key)
        end
    end

    local cfg = loadConfig()
    cfg.language = settingsData.language
    saveConfig(cfg)
    return settingsData.language
end
makeDropdown(row0, {"English", "中文", "한국어", "日本語"}, 1, onLanguageChange, "language")
row0.Parent = settingsScroll

row1 = makeSettingRow("rejoin", "rejoin_desc", 1)
local function onRejoin()
    tpService:TeleportToPlaceInstance(game.PlaceId, game.JobId, v7)
end
makeActionButton("click_here", row1, onRejoin)
row1.Parent = settingsScroll

row2 = makeSettingRow("small_server", "small_server_desc", 2)
local function onSmallServer()
    local placeId = game.PlaceId
    local currentJobId = game.JobId
    local targetServerId = nil
    local cursor = ""
    for _ = 1, 5 do
        local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?limit=100"
        if cursor ~= "" then url = url .. "&cursor=" .. cursor end
        local raw = nil
        local ok1, r1 = pcall(function() return requestWithUA(url) end)
        if ok1 and r1 and r1 ~= "" then raw = r1
        else
            local ok2, r2 = pcall(function() return game:HttpGet(url) end)
            if ok2 and r2 and r2 ~= "" then raw = r2 end
        end
        if not raw or raw == "" then break end
        local ok3, data = pcall(svc.HttpService.JSONDecode, svc.HttpService, raw)
        if not ok3 or not data or not data.data then break end
        local candidates = {}
        for _, srv in ipairs(data.data) do
            if srv.playing < srv.maxPlayers and srv.id ~= currentJobId then
                table.insert(candidates, srv)
            end
        end
        table.sort(candidates, function(a, b) return a.playing < b.playing end)
        if #candidates > 0 then
            targetServerId = candidates[1].id
            break
        end
        cursor = data.nextPageCursor or ""
        if not cursor or cursor == "" then break end
    end
    if targetServerId then
        pcall(function() tpService:TeleportToPlaceInstance(placeId, targetServerId, v7) end)
    else
        pcall(function() tpService:Teleport(placeId, v7) end)
    end
end
makeActionButton("click_here", row2, onSmallServer)
row2.Parent = settingsScroll

row4 = makeSettingRow("fps_cap", "fps_cap_desc", 4)
makeDropdown(row4, {t("fps_30"), t("fps_60"), t("fps_120"), t("fps_240"), t("fps_360"), t("fps_unlimited")}, 2, function(val)
    local numStr = ""
                for i = 1, #val do
                    local c = val:sub(i,i)
                    if c >= "0" and c <= "9" then numStr = numStr .. c end
                end
                local num = tonumber(numStr)
    local cap = num or 0
    if setfpscap then
        setfpscap(cap)
    end
end
, "fpsCap")
row4.Parent = settingsScroll

row9 = makeSettingRow("anti_afk", "anti_afk_desc", 9)
makeToggle(row9, true, function(state)
    if state then
        if settingsData.afkConnection then
            settingsData.afkConnection:Disconnect()
        end
        settingsData.afkConnection = v7.Idled:Connect(function()
            vUser:CaptureController()
            vUser:ClickButton2(Vector2.new())
        end)
    else
        if settingsData.afkConnection then
            settingsData.afkConnection:Disconnect()
            settingsData.afkConnection = nil
        end
    end
end, "antiAfk"
)
row9.Parent = settingsScroll

rowAntiKick = makeSettingRow("anti_kick", "anti_kick_desc", 8)
makeToggle(rowAntiKick, false, function(state)
    if state then
        local ok, wrapper, unhook = pcall(HookManager.wrapAntiKick, v7)
        if ok and wrapper then
            settingsData.kickUnhooker = unhook
            settingsData.kickBlocked = true
        else
            warn("[DeltaUI] AntiKick hook failed")
            settingsData.kickBlocked = false
        end
    else
        if settingsData.kickUnhooker then
            local ok = pcall(settingsData.kickUnhooker)
            if not ok then warn("[DeltaUI] AntiKick unhook failed") end
            settingsData.kickUnhooker = nil
        end
        settingsData.kickBlocked = nil
    end
    local cfg = loadConfig()
    cfg.antiKick = state
    saveConfig(cfg)
end, "antiKick")
rowAntiKick.Parent = settingsScroll

row11 = makeSettingRow("auto_execute", "auto_execute_desc", 11)
makeToggle(row11, true, function(state)
    if state then
        runAutoExecScripts()
    end
end, "autoExec"
)
row11.Parent = settingsScroll

rowAutoTrans = makeSettingRow("auto_translate", "auto_translate_desc", 11.6)
makeToggle(rowAutoTrans, false, function(state)
    local cfg = loadConfig()
    cfg.autoTranslate = state
    saveConfig(cfg)
    if state then
        startAutoTranslate()
    else
        stopAutoTranslate()
    end
end, "autoTranslate")
rowAutoTrans.Parent = settingsScroll

rowTransPath = makeSettingRow("translate_path", "translate_path_desc", 11.7)
makeMultiDropdown(rowTransPath, {t("coregui_path"), t("playergui_path")}, {t("coregui_path")}, function(vals)
    local cfg = loadConfig()
    cfg.translatePaths = vals
    saveConfig(cfg)
end, "translatePaths")
rowTransPath.Parent = settingsScroll


__secExt = makeSectionCard(t("extension_package_options"), "extension_package_options", "package", 12)

rowOrb = makeSettingRow("customize_floating_ball", "customize_floating_ball_desc", 14)
orbInput = create("TextBox", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -12, 0.5, 0),
    Size = UDim2.new(0, 200, 0, 32),
    BackgroundColor3 = theme.surfaceLight,
    BackgroundTransparency = 0.4,
    Text = "",
    PlaceholderText = t("enter_image_url"),
    PlaceholderColor3 = theme.textDim,
    TextColor3 = theme.text,
    TextSize = 12,
    Font = Enum.Font.SourceSans,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    ZIndex = 5
})
corner(8, orbInput)
stroke(theme.border, 1, orbInput)
orbInput.Parent = rowOrb
create("UIPadding", {PaddingLeft = UDim.new(0, 5)}).Parent = orbInput
table.insert(settingsData.uiRefs, {element = orbInput, key = "enter_image_url"})
rowOrb.Parent = settingsScroll

orbConfirmBtn = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -220, 0.5, 0),
    Size = UDim2.new(0, 120, 0, 32),
    BackgroundColor3 = theme.accent,
    BackgroundTransparency = 0.25,
    Text = "",
    BorderSizePixel = 0,
    ZIndex = 5
})
applyGradient(orbConfirmBtn, theme.accent, theme.accent2, 120)
corner(8, orbConfirmBtn)
orbConfirmText = create("TextLabel", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = t("confirm_changes"),
    TextColor3 = Color3.fromRGB(255,255,255),
    TextSize = 12,
    Font = Enum.Font.SourceSansBold,
    ZIndex = 6
})
orbConfirmText.Parent = orbConfirmBtn
table.insert(settingsData.uiRefs, {element = orbConfirmText, key = "confirm_changes"})
orbConfirmBtn.Parent = rowOrb
orbConfirmBtn.MouseButton1Click:Connect(function()
    local url = orbInput.Text
    if url == "" or url == t("enter_image_url") then
        ShowNotification(t("invalid_image"), 1)
        return
    end
    if not (url:sub(1,7) == "http://" or url:sub(1,8) == "https://") then
        ShowNotification(t("invalid_image"), 1)
        return
    end
    orbConfirmBtn.Active = false
    local assetUrl = ParseImageAsset(url)
    if not assetUrl or assetUrl == "" then
        ShowNotification(t("invalid_image"), 1)
        orbConfirmBtn.Active = true
        return
    end
    orbFrame.BackgroundColor3 = Color3.fromRGB(255,255,255)
    for _, child in pairs(orbFrame:GetChildren()) do
        if child:IsA("ImageLabel") then
            child:Destroy()
        end
    end
    orbImg = create("ImageLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Image = assetUrl,
        ZIndex = 102
    })
    local orbCorner = orbFrame:FindFirstChildOfClass("UICorner")
    if orbCorner then
        corner(orbCorner.CornerRadius.Offset, orbImg)
    else
        corner(8, orbImg)
    end
    orbImg.Parent = orbFrame
    ShowNotification(t("image_updated"), 1)
    orbConfirmBtn.Active = true
end)

rowLabel = makeSettingRow("customize_label", "customize_label_desc", 15)
labelInput = create("TextBox", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -12, 0.5, 0),
    Size = UDim2.new(0, 200, 0, 32),
    BackgroundColor3 = theme.surfaceLight,
    BackgroundTransparency = 0.4,
    Text = "",
    PlaceholderText = t("enter_label_text"),
    PlaceholderColor3 = theme.textDim,
    TextColor3 = theme.text,
    TextSize = 12,
    Font = Enum.Font.SourceSans,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
    ZIndex = 5
})
corner(8, labelInput)
stroke(theme.border, 1, labelInput)
labelInput.Parent = rowLabel
create("UIPadding", {PaddingLeft = UDim.new(0, 5)}).Parent = labelInput
table.insert(settingsData.uiRefs, {element = labelInput, key = "enter_label_text"})
rowLabel.Parent = settingsScroll

labelConfirmBtn = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -220, 0.5, 0),
    Size = UDim2.new(0, 120, 0, 32),
    BackgroundColor3 = theme.accent,
    BackgroundTransparency = 0.25,
    Text = "",
    BorderSizePixel = 0,
    ZIndex = 5
})
applyGradient(labelConfirmBtn, theme.accent, theme.accent2, 120)
corner(8, labelConfirmBtn)
labelConfirmText = create("TextLabel", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = t("confirm_changes"),
    TextColor3 = Color3.fromRGB(255,255,255),
    TextSize = 12,
    Font = Enum.Font.SourceSansBold,
    ZIndex = 6
})
labelConfirmText.Parent = labelConfirmBtn
table.insert(settingsData.uiRefs, {element = labelConfirmText, key = "confirm_changes"})
labelConfirmBtn.Parent = rowLabel
labelConfirmBtn.MouseButton1Click:Connect(function()
    local text = labelInput.Text
    if text == "" or text == t("enter_label_text") then
        ShowNotification(t("invalid_input"), 1)
        return
    end
    if labelText then
        labelText.Text = text
        local textWidth = labelText.TextBounds.X + 28
        labelPill.Size = UDim2.new(0, math.max(55, textWidth), 0, 22)
    end
    local cfg = loadConfig()
    cfg.customLabel = text
    saveConfig(cfg)
    ShowNotification(t("label_updated"), 1)
end)

extGuide = create("TextLabel", {Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Text = t("custom_icon_guide"), TextColor3 = theme.textDim, TextSize = 11, Font = Enum.Font.SourceSans, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, LayoutOrder = 15, ZIndex = 4})
extGuide.Parent = settingsScroll
table.insert(settingsData.uiRefs, {element = extGuide, key = "custom_icon_guide"})

rowNetworkHeader = makeSettingRow("network_request_header", "network_request_header_desc", 16)
local function onNetworkHeaderChange(val)
    settingsData.networkHeader = val
    local cfg = loadConfig()
    cfg.networkHeader = val
    saveConfig(cfg)
    if val == "RobloxClient" then
        if interfaceDropdownSetValue then
            interfaceDropdownSetValue("RobloxHttpService")
        end
        if updateInterfaceOptions then
            updateInterfaceOptions({"RobloxHttpService"})
        end
    else
        if updateInterfaceOptions then
            updateInterfaceOptions({"Safari", "Chrome", "Edge", "RobloxHttpService"})
        end
        if interfaceDropdownSetValue and getInterfaceTypeValue and getInterfaceTypeValue() == "RobloxHttpService" then
            interfaceDropdownSetValue("Safari")
        end
    end
    return val
end
getNetworkHeaderValue, setNetworkHeaderValue = makeDropdown(rowNetworkHeader, {"MacOS", "Windows", "Linux", "Android", "iOS", "RobloxClient"}, 1, onNetworkHeaderChange, "networkHeader")
rowNetworkHeader.Parent = settingsScroll

rowInterfaceType = makeSettingRow("interface_type", "interface_type_desc", 17)
local function onInterfaceTypeChange(val)
    settingsData.interfaceType = val
    local cfg = loadConfig()
    cfg.interfaceType = val
    saveConfig(cfg)
    if val == "RobloxHttpService" then
        if setNetworkHeaderValue and getNetworkHeaderValue and getNetworkHeaderValue() ~= "RobloxClient" then
            setNetworkHeaderValue("RobloxClient")
        end
    else
        if setNetworkHeaderValue and getNetworkHeaderValue and getNetworkHeaderValue() == "RobloxClient" then
            setNetworkHeaderValue("MacOS")
        end
    end
    return val
end
getInterfaceTypeValue, interfaceDropdownSetValue, updateInterfaceOptions = makeDropdown(rowInterfaceType, {"Safari", "Chrome", "Edge", "RobloxHttpService"}, 1, onInterfaceTypeChange, "interfaceType")
rowInterfaceType.Parent = settingsScroll


__secConsole = makeSectionCard(t("console_settings"), "console_settings", "terminal", 18)

row10 = makeSettingRow("console", "console_desc", 10)
makeToggle(row10, true, function(state)
    consoleEnabled = state
end, "console"
)
row10.Parent = settingsScroll

rowBlockInternal = makeSettingRow("block_internal_errors", "block_internal_errors_desc", 20)
makeToggle(rowBlockInternal, true, function(state)
    if state then
        if not _G.__DeltaUI_blockInternalConn then
            _G.__DeltaUI_blockInternalConn = game:GetService("LogService").MessageOut:Connect(function(msg, msgtype)
                local msgStr = tostring(msg)
                if msgStr:find("Overlay is not a valid member of ImageLabel")
                    or msgStr:find("Error is not a valid member of Folder")
                    or msgStr:find("ConsoleElements")
                    or msgStr:find("AppDelegate")
                    or msgStr:find("Arrow is not a valid member of ImageButton")
                then
                    return
                end
            end)
        end
    else
        if _G.__DeltaUI_blockInternalConn then
            _G.__DeltaUI_blockInternalConn:Disconnect()
            _G.__DeltaUI_blockInternalConn = nil
        end
    end
    local cfg = loadConfig()
    cfg.blockInternalErrors = state
    saveConfig(cfg)
end, "blockInternalErrors")
rowBlockInternal.Parent = settingsScroll

rowRealLine = makeSettingRow("real_line_numbers", "real_line_numbers_desc", 21)
makeToggle(rowRealLine, true, function(state)
    local cfg = loadConfig()
    cfg.realLineNumbers = state
    saveConfig(cfg)
end, "realLineNumbers")
rowRealLine.Parent = settingsScroll

rowDetailedErrors = makeSettingRow("detailed_errors", "detailed_errors_desc", 22)
makeToggle(rowDetailedErrors, false, function(state)
    local cfg = loadConfig()
    cfg.detailedErrors = state
    saveConfig(cfg)
end, "detailedErrors")
rowDetailedErrors.Parent = settingsScroll

rowErrorTranslation = makeSettingRow("error_translation", "error_translation_desc", 23)
makeToggle(rowErrorTranslation, true, function(state)
    settingsData.errorTranslation = state
    local cfg = loadConfig()
    cfg.errorTranslation = state
    saveConfig(cfg)
end, "errorTranslation")
rowErrorTranslation.Parent = settingsScroll

rowBlockServer = makeSettingRow("block_server_errors", "block_server_errors_desc", 24)
makeToggle(rowBlockServer, true, function(state)
    settingsData.blockServerErrors = state
    local cfg = loadConfig()
    cfg.blockServerErrors = state
    saveConfig(cfg)
end, "blockServerErrors")
rowBlockServer.Parent = settingsScroll

rowBlockAsset = makeSettingRow("block_asset_errors", "block_asset_errors_desc", 25)
makeToggle(rowBlockAsset, true, function(state)
    settingsData.blockAssetErrors = state
    local cfg = loadConfig()
    cfg.blockAssetErrors = state
    saveConfig(cfg)
end, "blockAssetErrors")
rowBlockAsset.Parent = settingsScroll

rowNotif = makeSettingRow("disable_notifications", "disable_notifications_desc", 25.1)
makeToggle(rowNotif, false, function(state)
    local cfg = loadConfig()
    cfg.disableNotifications = state
    saveConfig(cfg)
end, "disableNotifications")
rowNotif.Parent = settingsScroll


__secDeep = makeSectionCard(t("deep_customization"), "deep_customization", "sliders", 25.5)

deepRow = makeSettingRow("customize_tabs", "customize_tabs_desc", 25.7)
makeActionButton("customize_tabs_btn", deepRow, function()
    enterCustomTabMode()
end)
deepRow.Parent = settingsScroll

resetRow = makeSettingRow("reset_tab_order", "reset_switcher_desc", 25.8)
makeActionButton("reset_tab_order", resetRow, function()
    resetTabOrder()
end)
resetRow.Parent = settingsScroll

row5 = makeSettingRow("icon_size", "icon_size_desc", 25.9)
makeDropdown(row5, {t("size_small"), t("size_medium"), t("size_large")}, 2, function(val)
    local sz = val == t("size_small") and 25 or val == t("size_medium") and 35 or 45
    orbFrame.Size = UDim2.new(0, sz, 0, sz)
    if orbImg then
        orbImg.Size = UDim2.new(1, 0, 1, 0)
    end
    local currentShape = getIconShape and getIconShape() or t("shape_circle")
    applyIconShape(currentShape)
end
, "iconSize")
row5.Parent = settingsScroll

row6 = makeSettingRow("icon_shape", "icon_shape_desc", 26)
local function applyIconShape(val)
    if not orbFrame then return end
    for _, c in pairs(orbFrame:GetChildren()) do
        if c:IsA("UICorner") then c:Destroy() end
    end
    if orbImg then
        for _, c in pairs(orbImg:GetChildren()) do
            if c:IsA("UICorner") then c:Destroy() end
        end
    end
    if val == t("shape_circle") then
        corner(orbFrame.Size.X.Offset/2, orbFrame)
        if orbImg then corner(orbFrame.Size.X.Offset/2, orbImg) end
    elseif val == t("shape_rounded") then
        corner(8, orbFrame)
        if orbImg then corner(8, orbImg) end
    end
end
local _, getIconShape = makeDropdown(row6, {t("shape_circle"), t("shape_square"), t("shape_rounded")}, 1, function(val)
    applyIconShape(val)
end, "iconShape")
task.defer(function()
    if getIconShape then applyIconShape(getIconShape()) end
end)
row6.Parent = settingsScroll

rowDeepCustom = makeSettingRow("deep_custom_layout", "deep_custom_layout_desc", 26.1)
makeToggle(rowDeepCustom, false, function(state)
    applyDeepCustomLayout(state)
end, "deepCustomLayout")
rowDeepCustom.Parent = settingsScroll

function createColorPickerRow(titleKey, descKey, layoutOrder, configKey, defaultColor, callback)
    local row = create("Frame", {Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = theme.surface, BackgroundTransparency = 0.3, BorderSizePixel = 0, LayoutOrder = layoutOrder, ZIndex = 4})
    corner(12, row)
    local descText = t(descKey)
    local hasDesc = descText ~= nil and descText ~= ""
    
    local leftBlock = create("Frame", {
        Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(0.5, -20, 1, 0),
        BackgroundTransparency = 1,
        ZIndex = 5,
    })
    local leftList = create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 2),
    })
    leftList.Parent = leftBlock
    local tLabel = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = t(titleKey),
        TextColor3 = theme.text,
        TextSize = 13,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 5,
    })
    tLabel.Parent = leftBlock
    table.insert(settingsData.uiRefs, {element = tLabel, key = titleKey})
    if hasDesc then
        local dLabel = create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 14),
            BackgroundTransparency = 1,
            Text = descText,
            TextColor3 = theme.textDim,
            TextSize = 10,
            Font = Enum.Font.SourceSans,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 5,
        })
        dLabel.Parent = leftBlock
        table.insert(settingsData.uiRefs, {element = dLabel, key = descKey})
    end
    leftBlock.Parent = row
    local cfg = loadConfig()
    local savedColor = cfg[configKey]
    local currentColor = defaultColor
    if savedColor and type(savedColor) == "table" and savedColor.r and savedColor.g and savedColor.b then
        currentColor = Color3.fromRGB(savedColor.r, savedColor.g, savedColor.b)
    end
    local colorBtn = create("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 32, 0, 32), BackgroundColor3 = currentColor, BackgroundTransparency = 0, Text = "", BorderSizePixel = 0, ZIndex = 5})
    corner(8, colorBtn)
    colorBtn.Parent = row
    local function saveColor(c)
        local cfg2 = loadConfig()
        cfg2[configKey] = {r = math.floor(c.R * 255), g = math.floor(c.G * 255), b = math.floor(c.B * 255)}
        saveConfig(cfg2)
    end
    colorBtn.MouseButton1Click:Connect(function()
        showColorPicker(currentColor, function(newColor)
            currentColor = newColor
            colorBtn.BackgroundColor3 = newColor
            saveColor(newColor)
            if callback then callback(newColor) end
        end)
    end)
    return row, function() return currentColor end, function(c)
        currentColor = c
        colorBtn.BackgroundColor3 = c
        saveColor(c)
        if callback then callback(c) end
    end
end

function showColorPicker(initialColor, onConfirm)
    local pickerOverlay = create("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 900, Active = true, Visible = true})
    pickerOverlay.Parent = screenGui
    local pickerCard = create("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 280, 0, 320), BackgroundColor3 = theme.surface, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 901, Active = true})
    corner(16, pickerCard)
    pickerCard.Parent = pickerOverlay
    local pickerTitle = create("TextLabel", {Position = UDim2.new(0, 20, 0, 14), Size = UDim2.new(1, -40, 0, 24), BackgroundTransparency = 1, Text = t("select_color"), TextColor3 = theme.text, TextSize = 16, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 902})
    pickerTitle.Parent = pickerCard
    local closeBtn = create("TextButton", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 14), Size = UDim2.new(0, 24, 0, 24), BackgroundTransparency = 1, Text = "", ZIndex = 903})
    local closeIcon = GetIcon("x", UDim2.new(0, 16, 0, 16), theme.textDim)
    if closeIcon then closeIcon.Position = UDim2.new(0.5, -8, 0.5, -8); closeIcon.Parent = closeBtn end
    closeBtn.Parent = pickerCard
    local hueFrame = create("Frame", {Position = UDim2.new(0, 20, 0, 50), Size = UDim2.new(1, -40, 0, 16), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, ZIndex = 902})
    corner(8, hueFrame)
    hueFrame.Parent = pickerCard
    local hueGradient = create("UIGradient", {Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)), ColorSequenceKeypoint.new(0.167, Color3.fromRGB(255, 255, 0)), ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)), ColorSequenceKeypoint.new(0.667, Color3.fromRGB(0, 0, 255)), ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))})})
    hueGradient.Parent = hueFrame
    local hueKnob = create("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(0, 12, 0, 22), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, ZIndex = 903})
    corner(6, hueKnob)
    stroke(Color3.fromRGB(100, 100, 100), 2, hueKnob)
    hueKnob.Parent = hueFrame
    local svFrame = create("Frame", {Position = UDim2.new(0, 20, 0, 78), Size = UDim2.new(1, -40, 0, 140), BackgroundColor3 = Color3.fromRGB(255, 0, 0), BorderSizePixel = 0, ZIndex = 902})
    corner(8, svFrame)
    svFrame.Parent = pickerCard
    local whiteOverlay = create("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 903})
    corner(8, whiteOverlay)
    whiteOverlay.Parent = svFrame
    local satGradient = create("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255)), Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})})
    satGradient.Parent = whiteOverlay
    local blackOverlay = create("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 904})
    corner(8, blackOverlay)
    blackOverlay.Parent = svFrame
    local valGradient = create("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(0, 0, 0), Color3.fromRGB(0, 0, 0)), Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})})
    valGradient.Parent = blackOverlay
    local svKnob = create("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 12, 0, 12), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, ZIndex = 905})
    corner(6, svKnob)
    stroke(Color3.fromRGB(100, 100, 100), 2, svKnob)
    svKnob.Parent = svFrame
    local previewFrame = create("Frame", {Position = UDim2.new(0, 20, 0, 228), Size = UDim2.new(1, -40, 0, 36), BackgroundColor3 = initialColor, BorderSizePixel = 0, ZIndex = 902})
    corner(8, previewFrame)
    previewFrame.Parent = pickerCard
    local confirmBtn = create("TextButton", {Position = UDim2.new(0, 20, 1, -48), Size = UDim2.new(1, -40, 0, 36), BackgroundColor3 = theme.accent, BackgroundTransparency = 0.25, Text = "", BorderSizePixel = 0, ZIndex = 902})
    applyGradient(confirmBtn, theme.accent, theme.accent2, 120)
    corner(8, confirmBtn)
    confirmBtn.Parent = pickerCard
    local confirmText = create("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = t("confirm_changes"), TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 13, Font = Enum.Font.SourceSansBold, ZIndex = 903})
    confirmText.Parent = confirmBtn
    local currentH, currentS, currentV = 0, 1, 1
    local function rgbToHsv(r, g, b)
        local max, min = math.max(r, g, b), math.min(r, g, b)
        local h, s, v
        v = max
        local d = max - min
        s = max == 0 and 0 or d / max
        if max == min then h = 0
        elseif max == r then h = (g - b) / d + (g < b and 6 or 0)
        elseif max == g then h = (b - r) / d + 2
        else h = (r - g) / d + 4 end
        h = h / 6
        return h, s, v
    end
    local function hsvToRgb(h, s, v)
        local r, g, b
        local i = math.floor(h * 6)
        local f = h * 6 - i
        local p = v * (1 - s)
        local q = v * (1 - f * s)
        local t = v * (1 - (1 - f) * s)
        i = i % 6
        if i == 0 then r, g, b = v, t, p
        elseif i == 1 then r, g, b = q, v, p
        elseif i == 2 then r, g, b = p, v, t
        elseif i == 3 then r, g, b = p, q, v
        elseif i == 4 then r, g, b = t, p, v
        else r, g, b = v, p, q end
        return Color3.new(r, g, b)
    end
    local ir, ig, ib = initialColor.R, initialColor.G, initialColor.B
    currentH, currentS, currentV = rgbToHsv(ir, ig, ib)
    hueKnob.Position = UDim2.new(currentH, 0, 0.5, 0)
    svKnob.Position = UDim2.new(currentS, 0, 1 - currentV, 0)
    local function updateSVBackground()
        svFrame.BackgroundColor3 = hsvToRgb(currentH, 1, 1)
    end
    local function updateColor()
        local newColor = hsvToRgb(currentH, currentS, currentV)
        previewFrame.BackgroundColor3 = newColor
        return newColor
    end
    updateSVBackground()
    updateColor()
    local hueDragging, svDragging = false, false
    local function updateHueFromInput(input)
        local relX = math.clamp(input.Position.X - hueFrame.AbsolutePosition.X, 0, hueFrame.AbsoluteSize.X)
        currentH = relX / hueFrame.AbsoluteSize.X
        hueKnob.Position = UDim2.new(currentH, 0, 0.5, 0)
        updateSVBackground()
        updateColor()
    end
    local function updateSVFromInput(input)
        local relX = math.clamp(input.Position.X - svFrame.AbsolutePosition.X, 0, svFrame.AbsoluteSize.X)
        local relY = math.clamp(input.Position.Y - svFrame.AbsolutePosition.Y, 0, svFrame.AbsoluteSize.Y)
        currentS = relX / svFrame.AbsoluteSize.X
        currentV = 1 - relY / svFrame.AbsoluteSize.Y
        svKnob.Position = UDim2.new(currentS, 0, 1 - currentV, 0)
        updateColor()
    end
    hueFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            hueDragging = true
            updateHueFromInput(input)
        end
    end)
    svFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            svDragging = true
            updateSVFromInput(input)
        end
    end)
    local inputConn = nil
    inputConn = svc.UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if hueDragging then updateHueFromInput(input) end
            if svDragging then updateSVFromInput(input) end
        end
    end)
    local endConn = nil
    endConn = svc.UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            hueDragging = false
            svDragging = false
        end
    end)
    local function closePicker()
        if inputConn then inputConn:Disconnect() inputConn = nil end
        if endConn then endConn:Disconnect() endConn = nil end
        svc.TweenService:Create(pickerCard, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1}):Play()
        for _, child in pairs(pickerCard:GetDescendants()) do
            if child:IsA("GuiObject") then
                if child:IsA("TextLabel") or child:IsA("TextButton") then
                    svc.TweenService:Create(child, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
                elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
                    svc.TweenService:Create(child, TweenInfo.new(0.2), {ImageTransparency = 1}):Play()
                elseif child:IsA("Frame") then
                    svc.TweenService:Create(child, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
                end
            end
        end
        svc.TweenService:Create(pickerOverlay, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
        task.delay(0.25, function()
            pickerOverlay:Destroy()
        end)
    end
    closeBtn.MouseButton1Click:Connect(closePicker)
    pickerOverlay.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local pos = input.Position
            local cardPos = pickerCard.AbsolutePosition
            local cardSize = pickerCard.AbsoluteSize
            if pos.X < cardPos.X or pos.X > cardPos.X + cardSize.X or pos.Y < cardPos.Y or pos.Y > cardPos.Y + cardSize.Y then
                closePicker()
            end
        end
    end)
    confirmBtn.MouseButton1Click:Connect(function()
        onConfirm(previewFrame.BackgroundColor3)
        closePicker()
    end)
    svc.TweenService:Create(pickerOverlay, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.6}):Play()
    svc.TweenService:Create(pickerCard, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.15}):Play()
end


function showGradientColorPicker(initialFrom, initialTo, onConfirm)
    local pickerOverlay = create("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 800, Active = true, Visible = true})
    pickerOverlay.Parent = screenGui
    local pickerCard = create("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 320, 0, 330), BackgroundColor3 = theme.surface, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 801, Active = true})
    corner(16, pickerCard)
    stroke(theme.border, 1, pickerCard)
    pickerCard.Parent = pickerOverlay

    local pickerTitle = create("TextLabel", {Position = UDim2.new(0, 20, 0, 14), Size = UDim2.new(1, -40, 0, 24), BackgroundTransparency = 1, Text = t("gradient_pick_title"), TextColor3 = theme.text, TextSize = 16, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 802})
    pickerTitle.Parent = pickerCard
    local closeBtn = create("TextButton", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 14), Size = UDim2.new(0, 24, 0, 24), BackgroundTransparency = 1, Text = "", ZIndex = 803})
    local closeIcon = GetIcon("x", UDim2.new(0, 16, 0, 16), theme.textDim)
    if closeIcon then closeIcon.Position = UDim2.new(0.5, -8, 0.5, -8); closeIcon.Parent = closeBtn end
    closeBtn.Parent = pickerCard

    
    local previewFrame = create("Frame", {Position = UDim2.new(0, 20, 0, 50), Size = UDim2.new(1, -40, 0, 36), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, ZIndex = 802})
    corner(8, previewFrame)
    previewFrame.Parent = pickerCard
    local previewGrad = create("UIGradient", {Color = buildGradientSequence(initialFrom, initialTo, previewFrame.AbsoluteSize.X), Rotation = 90})
    previewGrad.Parent = previewFrame

    
    local function makeStopRow(y, labelKey, color)
        local lbl = create("TextLabel", {Position = UDim2.new(0, 20, 0, y), Size = UDim2.new(0.5, 0, 0, 30), BackgroundTransparency = 1, Text = t(labelKey), TextColor3 = theme.text, TextSize = 13, Font = Enum.Font.SourceSans, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 802})
        lbl.Parent = pickerCard
        local sw = create("TextButton", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, y), Size = UDim2.new(0, 60, 0, 30), BackgroundColor3 = color, BackgroundTransparency = 0, Text = "", BorderSizePixel = 0, ZIndex = 802})
        corner(8, sw)
        stroke(theme.border, 1, sw)
        sw.Parent = pickerCard
        return sw
    end
    local fromColor, toColor = initialFrom, initialTo
    local fromSwatch = makeStopRow(94, "gradient_from", fromColor)
    local toSwatch = makeStopRow(134, "gradient_to", toColor)
    local function updateSwatches()
        fromSwatch.BackgroundColor3 = fromColor
        toSwatch.BackgroundColor3 = toColor
        previewGrad.Color = buildGradientSequence(fromColor, toColor, previewFrame.AbsoluteSize.X)
    end
    fromSwatch.MouseButton1Click:Connect(function()
        showColorPicker(fromColor, function(c) fromColor = c; updateSwatches() end)
    end)
    toSwatch.MouseButton1Click:Connect(function()
        showColorPicker(toColor, function(c) toColor = c; updateSwatches() end)
    end)

    
    local presetLbl = create("TextLabel", {Position = UDim2.new(0, 20, 0, 178), Size = UDim2.new(1, -40, 0, 18), BackgroundTransparency = 1, Text = t("gradient_preset"), TextColor3 = theme.textDim, TextSize = 12, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 802})
    presetLbl.Parent = pickerCard
    local presets = {
        {Color3.fromRGB(56, 189, 248), Color3.fromRGB(139, 92, 246)},
        {Color3.fromRGB(255, 82, 104), Color3.fromRGB(255, 165, 80)},
        {Color3.fromRGB(57, 214, 146), Color3.fromRGB(80, 130, 255)},
        {Color3.fromRGB(250, 204, 80), Color3.fromRGB(139, 92, 246)},
        {Color3.fromRGB(255, 100, 190), Color3.fromRGB(56, 189, 248)},
    }
    for i, p in ipairs(presets) do
        local pair = p
        local sw = create("TextButton", {Position = UDim2.new(0, 20 + (i - 1) * 56, 0, 202), Size = UDim2.new(0, 48, 0, 34), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0, Text = "", BorderSizePixel = 0, ZIndex = 802})
        corner(8, sw)
        local g = create("UIGradient", {Color = buildGradientSequence(pair[1], pair[2], sw.AbsoluteSize.X), Rotation = 90})
        g.Parent = sw
        sw.Parent = pickerCard
        sw.MouseButton1Click:Connect(function()
            fromColor = pair[1]; toColor = pair[2]; updateSwatches()
        end)
    end

    
    local confirmBtn = create("TextButton", {Position = UDim2.new(0, 20, 1, -46), Size = UDim2.new(1, -40, 0, 34), BackgroundColor3 = theme.accent, BackgroundTransparency = 0.25, Text = "", BorderSizePixel = 0, ZIndex = 802})
    applyGradient(confirmBtn, theme.accent, theme.accent2, 120)
    corner(8, confirmBtn)
    confirmBtn.Parent = pickerCard
    local confirmText = create("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = t("confirm_changes"), TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 13, Font = Enum.Font.SourceSansBold, ZIndex = 803})
    confirmText.Parent = confirmBtn

    local function closePicker()
        svc.TweenService:Create(pickerCard, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1}):Play()
        for _, child in pairs(pickerCard:GetDescendants()) do
            if child:IsA("GuiObject") then
                
                if child:IsA("TextLabel") or child:IsA("TextButton") then
                    svc.TweenService:Create(child, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
                end
                if child:IsA("ImageLabel") or child:IsA("ImageButton") then
                    svc.TweenService:Create(child, TweenInfo.new(0.2), {ImageTransparency = 1}):Play()
                end
                svc.TweenService:Create(child, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
            end
        end
        svc.TweenService:Create(pickerOverlay, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
        task.delay(0.25, function() pickerOverlay:Destroy() end)
    end
    closeBtn.MouseButton1Click:Connect(closePicker)
    pickerOverlay.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local pos = input.Position
            local cp = pickerCard.AbsolutePosition
            local cs = pickerCard.AbsoluteSize
            if pos.X < cp.X or pos.X > cp.X + cs.X or pos.Y < cp.Y or pos.Y > cp.Y + cs.Y then closePicker() end
        end
    end)
    confirmBtn.MouseButton1Click:Connect(function()
        if onConfirm then onConfirm(fromColor, toColor) end
        closePicker()
    end)
    svc.TweenService:Create(pickerOverlay, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.6}):Play()
    svc.TweenService:Create(pickerCard, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.15}):Play()
end


function createGradientColorPickerRow(titleKey, descKey, layoutOrder, configKey, defaultFrom, defaultTo, callback)
    local row = create("Frame", {Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = theme.surface, BackgroundTransparency = 0.25, BorderSizePixel = 0, LayoutOrder = layoutOrder, ZIndex = 4})
    corner(12, row)
    local descText = t(descKey)
    local hasDesc = descText ~= nil and descText ~= ""
    
    local leftBlock = create("Frame", {
        Position = UDim2.new(0, 16, 0, 0),
        Size = UDim2.new(0.5, -20, 1, 0),
        BackgroundTransparency = 1,
        ZIndex = 5,
    })
    local leftList = create("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 2),
    })
    leftList.Parent = leftBlock
    local tLabel = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = t(titleKey),
        TextColor3 = theme.text,
        TextSize = 13,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 5,
    })
    tLabel.Parent = leftBlock
    table.insert(settingsData.uiRefs, {element = tLabel, key = titleKey})
    if hasDesc then
        local dLabel = create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 14),
            BackgroundTransparency = 1,
            Text = descText,
            TextColor3 = theme.textDim,
            TextSize = 10,
            Font = Enum.Font.SourceSans,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 5,
        })
        dLabel.Parent = leftBlock
        table.insert(settingsData.uiRefs, {element = dLabel, key = descKey})
    end
    leftBlock.Parent = row
    local cfg = loadConfig()
    local currentFrom, currentTo = defaultFrom, defaultTo
    local fc, tc = cfg[configKey], cfg[configKey .. "To"]
    if fc and fc.r and fc.g and fc.b then currentFrom = Color3.fromRGB(fc.r, fc.g, fc.b) end
    if tc and tc.r and tc.g and tc.b then
        currentTo = Color3.fromRGB(tc.r, tc.g, tc.b)
    elseif fc and fc.r and fc.g and fc.b then
        
        currentTo = deriveGradientTo(currentFrom)
    end
    local previewBtn = create("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 64, 0, 32), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0, Text = "", BorderSizePixel = 0, ZIndex = 5})
    corner(8, previewBtn)
    previewBtn.Parent = row
    local previewGrad = create("UIGradient", {Color = buildGradientSequence(currentFrom, currentTo, previewBtn.AbsoluteSize.X)})
    previewGrad.Parent = previewBtn
    previewBtn.MouseButton1Click:Connect(function()
        showGradientColorPicker(currentFrom, currentTo, function(nf, nt)
            currentFrom, currentTo = nf, nt
            previewGrad.Color = buildGradientSequence(nf, nt, previewBtn.AbsoluteSize.X)
            local cfg2 = loadConfig()
            cfg2[configKey] = {r = math.floor(nf.R * 255), g = math.floor(nf.G * 255), b = math.floor(nf.B * 255)}
            cfg2[configKey .. "To"] = {r = math.floor(nt.R * 255), g = math.floor(nt.G * 255), b = math.floor(nt.B * 255)}
            saveConfig(cfg2)
            -- 直接用确认后的确切颜色更新所有渐变元素（含按钮），与预览框完全一致，
            -- 避免依赖配置重读可能导致的颜色偏差
            for _, g in ipairs(_G.__DeltaUI_gradients or {}) do
                pcall(function()
                    if g and g.Parent then
                        g.Color = buildGradientSequence(nf, nt, g.Parent.AbsoluteSize.X)
                    end
                end)
            end
            if callback then callback(nf, nt) end
        end)
    end)
    return row
end

gradientThemeRow = createGradientColorPickerRow("gradient_theme_color", "gradient_theme_color_desc", 26.2, "gradientThemeColor", theme.accent, Color3.fromRGB(139, 92, 246), function()
    refreshThemeGradients()
end)
gradientThemeRow.Parent = settingsScroll

orbColorRow = createColorPickerRow("orb_border_color", "orb_border_color_desc", 26.3, "orbBorderColor", theme.accent, function(newColor)
    if orbStroke then
        orbStroke.Color = newColor
    end
end)
orbColorRow.Parent = settingsScroll



__secPageExt = makeSectionCard(t("page_ext"), "page_ext", "puzzle", 26.5)

local pageSafeRow = makeSettingRow("page_safe_mode", "page_safe_mode_desc", 0)
makeToggle(pageSafeRow, true, function(state)
    local c = loadConfig()
    c.pageSafeMode = state
    saveConfig(c)
end, "pageSafeMode")
pageSafeRow.Parent = __secPageExt

local pageUrlRow = create("Frame", {Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = theme.surface, BackgroundTransparency = 0.3, BorderSizePixel = 0, LayoutOrder = 1, ZIndex = 4})
corner(12, pageUrlRow)
local pageUrlBox = create("TextBox", {
    Position = UDim2.new(0, 6, 0, 9),
    Size = UDim2.new(1, -132, 0, 36),
    BackgroundColor3 = theme.surfaceLight,
    BackgroundTransparency = 0.2,
    PlaceholderText = t("page_ext_url_placeholder"),
    PlaceholderColor3 = theme.textDim,
    Text = "",
    TextColor3 = theme.text,
    TextSize = 13,
    Font = Enum.Font.SourceSans,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    ClearTextOnFocus = false,
    ZIndex = 5,
})
corner(8, pageUrlBox)

create("UIPadding", {PaddingLeft = UDim.new(0, 8)}).Parent = pageUrlBox
pageUrlBox.Parent = pageUrlRow
local pageInstallBtn = makeGradientBtn(pageUrlRow, UDim2.new(0, 108, 0, 32), Vector2.new(1, 0.5), UDim2.new(1, -12, 0.5, 0), t("install_page"))
table.insert(settingsData.uiRefs, {element = pageInstallBtn, key = "install_page"})
pageUrlRow.Parent = __secPageExt

-- 官方预设页面
local pagePresetsHeader = create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 22),
    BackgroundTransparency = 1,
    Text = t("page_presets"),
    TextColor3 = theme.text,
    TextSize = 12,
    Font = Enum.Font.SourceSansBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    LayoutOrder = 2,
    ZIndex = 4,
})
table.insert(settingsData.uiRefs, {element = pagePresetsHeader, key = "page_presets"})
pagePresetsHeader.Parent = __secPageExt

-- 预设页面列表
local PRESET_PAGES = {
    {
        name = "coding_blocks",
        titleKey = "preset_coding",
        descKey = "preset_coding_desc",
        icon = "blocks",
        url = "https://cdn.jsdelivr.net/gh/WasKKal/Asset@master/deltaui/coding_blocks.lua",
        unsafe = true,
    },
}

local presetList = create("Frame", {
    Size = UDim2.new(1, 0, 0, 0),
    BackgroundTransparency = 1,
    AutomaticCanvasSize = Enum.AutomaticSize.None,
    LayoutOrder = 2.5,
    ZIndex = 4,
})
local presetLayout = create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)})
presetLayout.Parent = presetList

for i, preset in ipairs(PRESET_PAGES) do
    local card = create("Frame", {
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = theme.surface,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        LayoutOrder = i,
        ZIndex = 4,
    })
    corner(12, card)

    local iconBg = create("Frame", {
        Position = UDim2.new(0, 8, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        Size = UDim2.new(0, 36, 0, 36),
        BackgroundColor3 = theme.accent,
        BackgroundTransparency = 0.85,
        BorderSizePixel = 0,
        ZIndex = 5,
    })
    corner(10, iconBg)
    iconBg.Parent = card

    local icon = GetIcon(preset.icon, UDim2.new(0, 18, 0, 18))
    if icon then
        icon.Position = UDim2.new(0.5, -9, 0.5, -9)
        icon.Parent = iconBg
    end

    local titleLbl = create("TextLabel", {
        Position = UDim2.new(0, 52, 0, 7),
        Size = UDim2.new(1, -160, 0, 18),
        BackgroundTransparency = 1,
        Text = t(preset.titleKey),
        TextColor3 = theme.text,
        TextSize = 13,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 5,
    })
    titleLbl.Parent = card

    local descLbl = create("TextLabel", {
        Position = UDim2.new(0, 52, 0, 26),
        Size = UDim2.new(1, -160, 0, 16),
        BackgroundTransparency = 1,
        Text = t(preset.descKey),
        TextColor3 = theme.textDim,
        TextSize = 11,
        Font = Enum.Font.SourceSans,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 5,
    })
    descLbl.Parent = card

    local installBtn = makeGradientBtn(card, UDim2.new(0, 88, 0, 30), Vector2.new(1, 0.5), UDim2.new(1, -10, 0.5, 0), t("install_page"))
    safeConnect(installBtn, "MouseButton1Click", function()
        installExternalPageFromURL(preset.url)
    end)

    -- 如果需要不安全模式，添加警告图标
    if preset.unsafe then
        local warnIcon = GetIcon("alert-triangle", UDim2.new(0, 12, 0, 12))
        if warnIcon then
            warnIcon.Position = UDim2.new(1, -108, 0.5, -22)
            warnIcon.ImageColor3 = theme.warn
            warnIcon.Parent = card
        end
    end

    card.Parent = presetList
end

-- 自动调整预设列表高度
local function updatePresetListSize()
    local count = #PRESET_PAGES
    presetList.Size = UDim2.new(1, 0, 0, count * 58 - 6)
end
updatePresetListSize()

presetList.Parent = __secPageExt



local pageExtListHeader = create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 22),
    BackgroundTransparency = 1,
    Text = t("installed_pages"),
    TextColor3 = theme.text,
    TextSize = 12,
    Font = Enum.Font.SourceSansBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    LayoutOrder = 3,
    ZIndex = 4,
})
table.insert(settingsData.uiRefs, {element = pageExtListHeader, key = "installed_pages"})
pageExtListHeader.Parent = __secPageExt

local pageExtList = create("ScrollingFrame", {
    Size = UDim2.new(1, 0, 0, 300),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = theme.textDim,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    LayoutOrder = 4,
    ZIndex = 4,
    ClipsDescendants = true,
})
local pageExtListLayout = create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)})
pageExtListLayout.Parent = pageExtList
pageExtList.Parent = __secPageExt







local function makePageHelpers()
    local helpers = {}
    helpers.frame = nil
    helpers.pages = pages
    helpers.navButtons = navButtons
    helpers.contentFrame = contentFrame
    helpers.switchPage = switchPage
    helpers.ShowNotification = ShowNotification
    helpers.create = create
    helpers.corner = corner
    helpers.stroke = stroke
    helpers.GetIcon = GetIcon
    helpers.t = t
    helpers.theme = theme
    helpers.Theme = theme
    helpers.safeConnect = safeConnect

    helpers.__rowCount = 0
    helpers.__elements = {}
    helpers.__section = nil   

    local function ensureScroll()
        if helpers.__scroll and helpers.__scroll.Parent then return helpers.__scroll end
        if not helpers.frame then return nil end
        local scroll = create("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 4,
            ScrollBarImageColor3 = theme.textDim,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ZIndex = 2,
        })
        scroll.Parent = helpers.frame
        local list = create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8)})
        list.Parent = scroll
        create("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}).Parent = scroll
        list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            if scroll.Parent then
                local s = list.AbsoluteContentSize
                if s then scroll.CanvasSize = UDim2.new(0, 0, 0, s.Y + 20) end
            end
        end)
        helpers.__scroll = scroll
        return scroll
    end

    
    local function appendToPage(frame)
        local scroll = ensureScroll()
        if not scroll then return frame end
        frame.LayoutOrder = helpers.__rowCount
        helpers.__rowCount = helpers.__rowCount + 1
        frame.Parent = scroll
        return frame
    end

    
    local function append(row)
        local target = helpers.__section or ensureScroll()
        if not target then return row end
        row.LayoutOrder = helpers.__rowCount
        helpers.__rowCount = helpers.__rowCount + 1
        row.Parent = target
        return row
    end

    
    helpers.addTitle = function(text)
        local row = create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            Text = tostring(text or ""),
            TextColor3 = theme.text,
            TextSize = 20,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Bottom,
            ZIndex = 3,
        })
        return append(row)
    end

    
    helpers.addLabel = function(text)
        local row = create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 20),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Text = tostring(text or ""),
            TextColor3 = theme.textDim,
            TextSize = 12,
            Font = Enum.Font.SourceSans,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            ZIndex = 3,
        })
        return append(row)
    end

    
    helpers.addDivider = function()
        local row = create("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = theme.border,
            BackgroundTransparency = 0.4,
            BorderSizePixel = 0,
            ZIndex = 3,
        })
        return append(row)
    end

    
    helpers.addButton = function(text, callback)
        
        
        local row = makeSettingRow(tostring(text or ""), "", helpers.__rowCount)
        makeGradientBtn(row, UDim2.new(0, 110, 0, 32), Vector2.new(1, 0.5), UDim2.new(1, -12, 0.5, 0), text, callback)
        return append(row)
    end

    
    helpers.addToggle = function(title, desc, default, callback, configKey)
        local row = makeSettingRow(tostring(title), tostring(desc or ""), helpers.__rowCount)
        local bg, get, set = makeToggle(row, default or false, function(state)
            if type(callback) == "function" then callback(state) end
        end, configKey)
        append(row)
        return row, get, set
    end

    
    helpers.addTextbox = function(placeholder, callback, initial)
        local row = makeSettingRow(tostring(placeholder or ""), "", helpers.__rowCount)
        local box = create("TextBox", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.new(0, 180, 0, 32),
            BackgroundColor3 = theme.surfaceLight,
            BackgroundTransparency = 0.2,
            PlaceholderText = "",
            PlaceholderColor3 = theme.textDim,
            Text = tostring(initial or ""),
            TextColor3 = theme.text,
            TextSize = 13,
            Font = Enum.Font.SourceSans,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            ZIndex = 5,
        })
        corner(8, box)
        
        create("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 6)}).Parent = box
        box.Parent = row
        if type(callback) == "function" then
            box.FocusLost:Connect(function(enter)
                if enter then callback(box.Text) end
            end)
        end
        append(row)
        return row, box
    end

    
    helpers.addDropdown = function(title, options, defaultIndex, callback, configKey)
        local row = makeSettingRow(tostring(title), "", helpers.__rowCount)
        local _, get, set = makeDropdown(row, options, defaultIndex or 1, callback, configKey)
        append(row)
        return row, get, set
    end

    
    
    
    helpers.addSection = function(title, icon)
        local card = create("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = theme.surfaceLight,
            BackgroundTransparency = 0.55,
            BorderSizePixel = 0,
            ZIndex = 3,
        })
        corner(theme.radiusLg, card)
        stroke(theme.border, 1, card)
        local cardList = create("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 6),
        })
        cardList.Parent = card
        create("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10)}).Parent = card

        
        local headerBar = create("Frame", {Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = -1, ZIndex = 4})
        headerBar.Parent = card
        local accentBar = create("Frame", {Size = UDim2.new(0, 3, 0, 16), Position = UDim2.new(0, 2, 0.5, -8), BackgroundColor3 = theme.accent, BorderSizePixel = 0, ZIndex = 5})
        local gF, gT = getEffectiveGradientColors()
        applyGradient(accentBar, gF or theme.accent, gT or theme.accent2, 90)
        corner(2, accentBar)
        accentBar.Parent = headerBar
        local hIcon = nil
        if type(icon) == "string" and icon ~= "" and GetIcon then
            hIcon = GetIcon(icon, UDim2.new(0, 16, 0, 16))
            if hIcon then
                hIcon.Position = UDim2.new(0, 14, 0.5, -8)
                hIcon.ImageColor3 = theme.accent
                hIcon.Parent = headerBar
            end
        end
        local titleLabel = create("TextLabel", {
            Position = UDim2.new(0, hIcon and 36 or 14, 0, 0),
            Size = UDim2.new(1, -(hIcon and 42 or 20), 1, 0),
            BackgroundTransparency = 1,
            Text = tostring(title or ""),
            TextColor3 = theme.text,
            TextSize = 14,
            Font = Enum.Font.SourceSansBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 5,
        })
        titleLabel.Parent = headerBar

        
        local content = create("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ZIndex = 4})
        create("UIListLayout", {FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8)}).Parent = content
        content.Parent = card

        appendToPage(card)
        helpers.__section = content
        return helpers
    end

    
    helpers.endSection = function()
        helpers.__section = nil
        return helpers
    end

    
    helpers.addSlider = function(title, desc, min, max, default, callback, configKey)
        min = min or 0
        max = max or 100
        local row = makeSettingRow(tostring(title), tostring(desc or ""), helpers.__rowCount)
        local trackW = 150
        local track = create("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, trackW, 0, 4), BackgroundColor3 = theme.surfaceLight, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 5})
        corner(2, track)
        local fill = create("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = theme.accent, BorderSizePixel = 0, ZIndex = 6})
        applyGradient(fill, theme.accent, theme.accent2, 0)
        corner(2, fill)
        fill.Parent = track
        local knob = create("TextButton", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(0, 16, 0, 16), BackgroundColor3 = Color3.fromRGB(255, 255, 255), Text = "", BorderSizePixel = 0, ZIndex = 7})
        corner(8, knob)
        knob.Parent = track
        local valueLabel = create("TextLabel", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -trackW - 16, 0.5, 0), Size = UDim2.new(0, 32, 0, 20), BackgroundTransparency = 1, Text = "", TextColor3 = theme.text, TextSize = 12, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 6})
        valueLabel.Parent = row
        track.Parent = row

        local value = math.clamp(default or min, min, max)
        local function refreshUI()
            local frac = (max == min) and 0 or (value - min) / (max - min)
            knob.Position = UDim2.new(math.clamp(frac, 0, 1), -8, 0.5, 0)
            fill.Size = UDim2.new(math.clamp(frac, 0, 1), 0, 1, 0)
            valueLabel.Text = tostring(math.floor(value))
        end
        local function commit()
            refreshUI()
            if type(callback) == "function" then callback(value) end
            if configKey then
                local c = loadConfig()
                c[configKey] = value
                saveConfig(c)
            end
        end
        local dragging = false
        local function trackDrag(input)
            if not dragging or not track.Parent then return end
            local rel = (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
            value = min + math.clamp(rel, 0, 1) * (max - min)
            commit()
        end
        local dragConn = svc.UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                trackDrag(input)
            end
        end)
        knob.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
            end
        end)
        knob.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                trackDrag(input)
            end
        end)
        refreshUI()
        append(row)
        local function get() return value end
        local function set(v)
            value = math.clamp(v, min, max)
            commit()
        end
        return row, get, set
    end

    
    helpers.addRow = function(builder, opts)
        if type(builder) ~= "function" then return nil end
        local ok, built = pcall(builder, opts or {}, helpers)
        if not ok or type(built) ~= "userdata" or not built.IsA then
            if not ok then warn("[DeltaUI] Custom page row error: " .. tostring(built)) end
            return nil
        end
        append(built)
        return built
    end

    
    helpers.registerElement = function(name, builder)
        if type(name) == "string" and type(builder) == "function" then
            helpers.__elements[name] = builder
        end
        return helpers
    end

    
    helpers.addElement = function(name, opts)
        local builder = helpers.__elements[name]
        if not builder then
            warn("[DeltaUI] Unknown page element: " .. tostring(name))
            return nil
        end
        return helpers.addRow(builder, opts)
    end

    return helpers
end


local function urlToPageName(url)
    if type(url) ~= "string" then return "" end
    local clean = url:gsub("[?#].*$", "")
    local seg = clean:match("/([^/]+)$")
    if seg and seg ~= "" then
        seg = seg:gsub("%.lua$", ""):gsub("%.luau$", ""):gsub("[%._]+$", "")
        if seg ~= "" then return seg end
    end
    return ""
end



local function buildPageDef(ret, captured, defOverride, url)
    local def = nil
    if type(ret) == "table" and type(ret.build) == "function" then
        def = ret
    elseif captured and type(captured.build) == "function" then
        def = captured
    end
    def = def or {}

    local name = (defOverride and defOverride.name) or (type(def.name) == "string" and def.name or "")
    if name == "" then name = urlToPageName(url) end
    if name == "" then name = "page_" .. tostring(#pages + 1) end
    name = __safeFilterName(name)
    local base = name
    local k = 1
    while pages[name] do
        k = k + 1
        name = base .. "_" .. tostring(k)
    end
    def.name = name

    local title = def.title
    if type(title) ~= "string" or title == "" then
        title = defOverride and defOverride.title or name
    end
    def.title = tostring(title)

    if type(def.icon) ~= "string" or def.icon == "" then
        def.icon = (defOverride and defOverride.icon) or "sparkles"
    end
    def.url = url
    return def
end




local PAGE_GUI_ALLOWED = {
    Frame = true, TextLabel = true, TextButton = true, ImageLabel = true,
    ImageButton = true, TextBox = true, ScrollingFrame = true, CanvasGroup = true,
    UIListLayout = true, UIGridLayout = true, UIStroke = true, UICorner = true,
    UIPadding = true, UIGradient = true, UIAspectRatioConstraint = true,
    UISizeConstraint = true, UIFlexItem = true, UIGridStyleLayout = true,
    UIConstraint = true, UILayout = true, BillboardGui = true, Folder = true,
}



local PAGE_RISKY_PATTERNS = {
    {pattern = "SoundService", label = "SoundService"},
    {pattern = 'Instance%.new%s*%(%s*["\']Sound["\']', label = "Sound"},
    {pattern = 'New%s*%(%s*["\']Sound["\']', label = "Sound"},
    {pattern = "VideoFrame", label = "Video"},
    {pattern = "TeleportService", label = "Teleport"},
    {pattern = "TeleportToPlaceInstance", label = "Teleport"},
    {pattern = "kick%s*%(", label = "Kick"},
    {pattern = "FireServer", label = "FireServer"},
    {pattern = "InvokeServer", label = "RemoteCall"},
    {pattern = "PostAsync", label = "HttpPost"},
    {pattern = "GetAsync", label = "HttpGet"},
    {pattern = "getgenv", label = "getgenv"},
    {pattern = "getrenv", label = "getrenv"},
    {pattern = "getgc", label = "getgc"},
    {pattern = "getupvalue", label = "getupvalue"},
    {pattern = "getcustomasset", label = "getcustomasset"},
    {pattern = "getloadedmodules", label = "getloadedmodules"},
    {pattern = "debug%.getregistry", label = "getregistry"},
    {pattern = "writefile", label = "writefile"},
    {pattern = "delfile", label = "delfile"},
    {pattern = "makefolder", label = "makefolder"},
    {pattern = "loadfile", label = "loadfile"},
    {pattern = "request%s*%(%s*%{", label = "request"},
}
local function scanPageSource(code)
    if type(code) ~= "string" then return {} end
    local found = {}
    for _, item in ipairs(PAGE_RISKY_PATTERNS) do
        if code:find(item.pattern) then
            table.insert(found, item.label)
        end
    end
    return found
end




local function makeSafeEnv(frame, helpers)
    local realNew = Instance.new
    local env = {}

    env.DeltaPage = helpers
    env.DeltaRegisterPage = function(def) helpers.__captured = def end

    local function safeNew(class, props)
        if not PAGE_GUI_ALLOWED[class] then
            error("[DeltaUI] Blocked instance class in page: " .. tostring(class), 2)
        end
        local inst = realNew(class)
        if type(props) == "table" then
            for k, v in pairs(props) do
                pcall(function() inst[k] = v end)
            end
        end
        return inst
    end
    env.Instance = {new = function(class, props) return safeNew(class, props) end}
    env.create = safeNew
    
    
    helpers.create = safeNew
    helpers.Instance = {new = function(class, props) return safeNew(class, props) end}

    
    env.corner = function(radius, parent) return corner(radius, parent) end
    env.stroke = function(color, thickness, parent) return stroke(color, thickness, parent) end
    env.applyGradient = function(f, from, to, rot) return applyGradient(f, from, to, rot) end
    env.GetIcon = GetIcon
    env.t = t
    env.Theme = theme
    env.switchPage = switchPage
    env.ShowNotification = ShowNotification
    env.pages = pages
    env.contentFrame = contentFrame

    
    
    env.addTitle = helpers.addTitle
    env.addLabel = helpers.addLabel
    env.addDivider = helpers.addDivider
    env.addSection = helpers.addSection
    env.endSection = helpers.endSection
    env.addButton = helpers.addButton
    env.addToggle = helpers.addToggle
    env.addTextbox = helpers.addTextbox
    env.addDropdown = helpers.addDropdown
    env.addSlider = helpers.addSlider
    env.addRow = helpers.addRow
    env.registerElement = helpers.registerElement
    env.addElement = helpers.addElement

    
    env.print = print
    env.warn = warn
    env.task = task
    env.pairs = pairs
    env.ipairs = ipairs
    env.next = next
    env.type = type
    env.tostring = tostring
    env.tonumber = tonumber
    env.select = select
    env.pcall = pcall
    env.xpcall = xpcall
    env.error = error
    env.assert = assert
    env.string = string
    env.table = table
    env.math = math
    env.tick = tick
    env.time = time
    env.UDim = UDim
    env.UDim2 = UDim2
    env.Color3 = Color3
    env.Vector2 = Vector2
    env.Vector3 = Vector3
    env.Enum = Enum
    env.os = {clock = os.clock, time = os.time, date = os.date}
    env.setmetatable = setmetatable
    env.getmetatable = getmetatable
    env.loadstring = function() error("[DeltaUI] loadstring disabled in Safe Mode", 2) end
    env.game = nil
    env.workspace = nil

    
    setmetatable(env, {__index = function() return nil end})
    return env
end



local pageGuardStarted = false
function startPageGuard()
    if pageGuardStarted then return end
    pageGuardStarted = true
    task.spawn(function()
        while true do
            task.wait(1.5)
            for _, page in pairs(pages) do
                if page and page.Parent then
                    for _, desc in pairs(page:GetDescendants()) do
                        if desc:IsA("Sound") or desc:IsA("VideoFrame") or desc:IsA("AudioEmitter") or desc:IsA("AudioDeviceInput") then
                            pcall(function() desc:Destroy() end)
                        end
                    end
                end
            end
        end
    end)
end





function registerExternalPage(code, url, defOverride)
    if type(code) ~= "string" or code == "" then
        ShowNotification(t("page_install_failed"), 3)
        return false
    end

    
    
    local frame = create("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 2})
    frame.Name = "DeltaPage_" .. tostring(#pages + 1)
    frame.Parent = contentFrame

    local helpers = makePageHelpers()
    helpers.frame = frame

    local captured = nil
    local prevReg = _G.DeltaRegisterPage
    local prevPage = _G.DeltaPage
    local safeMode = (loadConfig()).pageSafeMode ~= false  

    local chunk = loadstring(code, "@external_page")
    if not chunk then
        pcall(function() frame:Destroy() end)
        _G.DeltaPage = prevPage
        ShowNotification(t("page_install_failed"), 3)
        return false
    end

    
    local risky = scanPageSource(code)
    if #risky > 0 then
        if safeMode then
            pcall(function() frame:Destroy() end)
            _G.DeltaPage = prevPage
            ShowNotification(t("page_blocked_instances") .. " " .. table.concat(risky, ", "), 4)
            return false
        else
            ShowNotification(t("page_risky_detected") .. " " .. table.concat(risky, ", "), 3)
        end
    end

    local ok, ret = true, nil
    if safeMode then
        
        local env = makeSafeEnv(frame, helpers)
        env.DeltaRegisterPage = function(def) captured = def end
        _G.DeltaPage = prevPage
        ok, ret = pcall(function()
            setfenv(chunk, env)
            return chunk()
        end)
        if helpers.__captured then captured = helpers.__captured end
    else
        
        _G.DeltaRegisterPage = function(def) captured = def end
        _G.DeltaPage = helpers
        ok, ret = pcall(chunk)
        _G.DeltaRegisterPage = prevReg
    end

    if not ok then
        pcall(function() frame:Destroy() end)
        _G.DeltaPage = prevPage
        ShowNotification(t("page_install_failed"), 3)
        return false
    end

    local def = buildPageDef(ret, captured, defOverride, url)
    local name = def.name
    if pages[name] then
        pcall(function() frame:Destroy() end)
        _G.DeltaPage = prevPage
        ShowNotification(t("page_name_exists"), 3)
        return false
    end
    frame.Name = name
    pages[name] = frame

    
    local btn = create("TextButton", {Size = UDim2.new(0, 32, 0, 32), Position = UDim2.new(0, 6, 0, 6), BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", ZIndex = 15})
    local icon = GetIcon(def.icon, UDim2.new(0, 18, 0, 18))
    if icon then
        icon.Position = UDim2.new(0.5, -9, 0.5, -9)
        icon.Parent = btn
    end
    btn.Parent = navContainer
    safeConnect(btn, "MouseButton1Click", function()
        switchPage(name)
    end)
    navButtons[name] = btn
    
    local function insertBeforeSettings(arr, item)
        local idx = table.find(arr, "settings")
        if idx then
            table.insert(arr, idx, item)
        else
            table.insert(arr, item)
        end
    end
    if not table.find(navNames, name) then insertBeforeSettings(navNames, name) end
    if not table.find(customTabOrder, name) then insertBeforeSettings(customTabOrder, name) end

    
    if not safeMode then _G.DeltaPage = helpers end
    local builtOk = true
    if type(def.build) == "function" then
        builtOk = pcall(def.build, frame, helpers)
    end

    if not builtOk then
        pcall(function() frame:Destroy() end)
        pages[name] = nil
        if navButtons[name] then pcall(function() navButtons[name]:Destroy() end); navButtons[name] = nil end
        local ni = table.find(navNames, name)
        if ni then table.remove(navNames, ni) end
        local ci = table.find(customTabOrder, name)
        if ci then table.remove(customTabOrder, ci) end
        _G.DeltaPage = prevPage
        ShowNotification(t("page_install_failed"), 3)
        return false
    end

    if customTabMode then
        updateCustomButtonPositions(false)
    else
        applyTabOrder()
    end

    local cfg = loadConfig()
    cfg.externalPages = cfg.externalPages or {}
    local newList = {}
    for _, p in ipairs(cfg.externalPages) do
        if p.name ~= name and p.url ~= url then table.insert(newList, p) end
    end
    table.insert(newList, {name = name, title = def.title, icon = def.icon, url = url})
    cfg.externalPages = newList
    saveConfig(cfg)

    pcall(function()
        if not isfolder("DeltaUI") then makefolder("DeltaUI") end
        if not isfolder("DeltaUI/Pages") then makefolder("DeltaUI/Pages") end
        writefile("DeltaUI/Pages/" .. name .. ".lua", code)
    end)

    pcall(refreshInstalledPagesList)
    ShowNotification(t("page_installed"), 2)
    return true
end

function installExternalPageFromURL(url)
    if type(url) ~= "string" or url == "" or url:sub(1, 4) ~= "http" then
        ShowNotification(t("invalid_page_url"), 2)
        return false
    end
    ShowNotification(t("installing_page"), 2)
    local code = nil
    local ok1, fetched = pcall(function()
        return game:HttpGet(url)
    end)
    if ok1 and fetched and #fetched > 0 then
        code = fetched
    end
    if not code then
        local ok2, fetched2 = pcall(function()
            return svc.HttpService:GetAsync(url)
        end)
        if ok2 and fetched2 and #fetched2 > 0 then code = fetched2 end
    end
    if not code or code == "" then
        ShowNotification(t("page_install_failed"), 3)
        return false
    end
    return registerExternalPage(code, url, nil)
end

function uninstallExternalPage(name)
    if not pages[name] then return false end
    if pages[name] then pcall(function() pages[name]:Destroy() end); pages[name] = nil end
    if navButtons[name] then pcall(function() navButtons[name]:Destroy() end); navButtons[name] = nil end
    local ni = table.find(navNames, name)
    if ni then table.remove(navNames, ni) end
    local ci = table.find(customTabOrder, name)
    if ci then table.remove(customTabOrder, ci) end
    local cfg = loadConfig()
    cfg.externalPages = cfg.externalPages or {}
    local newList = {}
    for _, p in ipairs(cfg.externalPages) do
        if p.name ~= name then table.insert(newList, p) end
    end
    cfg.externalPages = newList
    saveConfig(cfg)
    pcall(function()
        if isfile("DeltaUI/Pages/" .. name .. ".lua") then delfile("DeltaUI/Pages/" .. name .. ".lua") end
    end)
    if customTabMode then
        updateCustomButtonPositions(false)
    else
        applyTabOrder()
    end
    pcall(refreshInstalledPagesList)
    ShowNotification(t("page_uninstalled"), 1)
    return true
end

function installInstalledPage(p)
    local code = nil
    local cachePath = "DeltaUI/Pages/" .. p.name .. ".lua"
    local okCache, cached = pcall(function()
        return isfile(cachePath) and readfile(cachePath) or ""
    end)
    if okCache and cached and #cached > 0 then
        code = cached
    end
    if not code then
        local ok, fetched = pcall(function()
            return game:HttpGet(p.url)
        end)
        if ok and fetched and #fetched > 0 then code = fetched end
    end
    if not code or code == "" then return end
    registerExternalPage(code, p.url, {name = p.name, title = p.title, icon = p.icon})
end

function loadInstalledPages()
    local cfg = loadConfig()
    if not cfg.externalPages or type(cfg.externalPages) ~= "table" then return end
    for _, p in ipairs(cfg.externalPages) do
        if p and p.url and p.name and not pages[p.name] then
            task.spawn(function()
                pcall(installInstalledPage, p)
            end)
        end
    end
end

function refreshInstalledPagesList()
    if not pageExtList or not pageExtList.Parent then return end
    for _, child in pairs(pageExtList:GetChildren()) do
        
        if not child:IsA("UIListLayout") then child:Destroy() end
    end
    local cfg = loadConfig()
    local list = cfg.externalPages or {}
    local count = #list
    if count == 0 then
        local empty = create("TextLabel", {Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Text = t("no_installed_pages"), TextColor3 = theme.textDim, TextSize = 12, Font = Enum.Font.SourceSans, ZIndex = 5})
        empty.Parent = pageExtList
        pageExtList.Size = UDim2.new(1, 0, 0, 28)
        return
    end
    
    for i = count, 1, -1 do
        local p = list[i]
        if p and p.name then
            local row = create("Frame", {Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = theme.surface, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 4})
            corner(10, row)
            local nameLabel = create("TextLabel", {Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -110, 1, 0), BackgroundTransparency = 1, Text = p.title or p.name, TextColor3 = theme.text, TextSize = 13, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5})
            nameLabel.Parent = row
            local unBtn = create("TextButton", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 84, 0, 28), BackgroundColor3 = theme.red, BackgroundTransparency = 0.3, Text = "", BorderSizePixel = 0, ZIndex = 5})
            corner(8, unBtn)
            local unText = create("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = t("uninstall"), TextColor3 = Color3.fromRGB(255,255,255), TextSize = 11, Font = Enum.Font.SourceSansBold, ZIndex = 6})
            unText.Parent = unBtn
            unBtn.Parent = row
            unBtn.MouseButton1Click:Connect(function()
                uninstallExternalPage(p.name)
            end)
            row.Parent = pageExtList
        end
    end
    
    local contentH = count * 48
    pageExtList.Size = UDim2.new(1, 0, 0, math.min(contentH, 300))
    pageExtList.CanvasSize = UDim2.new(0, 0, 0, contentH)
end

pageInstallBtn.MouseButton1Click:Connect(function()
    installExternalPageFromURL(pageUrlBox.Text)
end)
task.defer(refreshInstalledPagesList)

_G.__DeltaUI_installExternalPage = installExternalPageFromURL
_G.__DeltaUI_uninstallExternalPage = uninstallExternalPage
_G.__DeltaUI_registerExternalPage = registerExternalPage
_G.__DeltaUI_loadInstalledPages = loadInstalledPages


do
    function __reparent(row, sec)
        if row and sec then row.Parent = sec end
    end
    
    
    __reparent(rowAutoAcceptExec, __secGeneral)
    __reparent(rowInit, __secGeneral)
    __reparent(row1, __secGeneral)
    __reparent(row2, __secGeneral)
    __reparent(row0, __secGeneral)
    __reparent(row4, __secGeneral)
    __reparent(rowBypass, __secGeneral)
    __reparent(rowAntiKick, __secGeneral)
    __reparent(row9, __secGeneral)
    __reparent(row11, __secGeneral)
    __reparent(rowAutoTrans, __secGeneral)
    __reparent(rowTransPath, __secGeneral)
    
    __reparent(rowOrb, __secExt)
    __reparent(rowLabel, __secExt)
    __reparent(extGuide, __secExt)
    __reparent(rowNetworkHeader, __secExt)
    __reparent(rowInterfaceType, __secExt)
    
    __reparent(row10, __secConsole)
    __reparent(rowBlockInternal, __secConsole)
    __reparent(rowRealLine, __secConsole)
    __reparent(rowDetailedErrors, __secConsole)
    __reparent(rowErrorTranslation, __secConsole)
    __reparent(rowBlockServer, __secConsole)
    __reparent(rowBlockAsset, __secConsole)
    __reparent(rowNotif, __secConsole)
    
    __reparent(deepRow, __secDeep)
    __reparent(resetRow, __secDeep)
    __reparent(row5, __secDeep)
    __reparent(row6, __secDeep)
    __reparent(rowDeepCustom, __secDeep)
    __reparent(gradientThemeRow, __secDeep)
    __reparent(orbColorRow, __secDeep)
end

maxLogEntries = 500
logEntryCount = 0
pendingLogs = {}
logProcessing = false

local defaultEditorText = [=[
--[[
      Thank you for using DeltaBeautify <3
      ReBuild By Was
      QQGroup: 786284990
      QQ: 1763356884
]]
]=]

local errorTranslationCache = {}

function translateError(msg)
    if not settingsData.errorTranslation then return msg end
    local lang = settingsData.language or "en"
    local cacheKey = lang .. "|" .. msg
    if errorTranslationCache[cacheKey] then return errorTranslationCache[cacheKey] end

    local mappings = {
        ["attempt to perform arithmetic %(sub%) on nil"] = {en = "attempt to perform arithmetic (sub) on nil", zh = "尝试对 nil 执行减法运算", ko = "nil에 대해 산술 연산(빼기) 시도", ja = "nilに対して算術演算（引き算）を試みました"},
        ["attempt to call missing method"] = {en = "attempt to call missing method", zh = "尝试调用缺失的方法", ko = "누락된 메서드 호출 시도", ja = "欠落したメソッドを呼び出そうとしました"},
        ["table index is nil"] = {en = "table index is nil", zh = "表索引为 nil", ko = "테이블 인덱스가 nil", ja = "テーブルインデックスがnilです"},
        ["Expected '%)'"] = {en = "Expected ')'", zh = "需要 ')'", ko = "')'가 필요함", ja = "')'が必要です"},
        ["Expected 'do'"] = {en = "Expected 'do'", zh = "需要 'do'", ko = "'do'가 필요함", ja = "'do'が必要です"},
        ["got 'local'"] = {en = "got 'local'", zh = "但得到了 'local'", ko = "'local'을 받음", ja = "'local'が見つかりました"},
        ["got 'elseif'"] = {en = "got 'elseif'", zh = "但得到了 'elseif'", ko = "'elseif'를 받음", ja = "'elseif'が見つかりました"},
        ["got '~'"] = {en = "got '~'", zh = "但得到了 '~'", ko = "'~'를 받음", ja = "'~'が見つかりました"},
        ["attempt to index nil with"] = {en = "attempt to index nil with", zh = "尝试访问 nil 的值", ko = "nil 값에 접근 시도", ja = "nilの値にアクセスしようとしました"},
        ["attempt to call a nil value"] = {en = "attempt to call a nil value", zh = "尝试调用 nil 值", ko = "nil 값 호출 시도", ja = "nil値を呼び出そうとしました"},
        ["Malformed string"] = {en = "Malformed string", zh = "字符串格式错误", ko = "잘못된 문자열", ja = "不正な文字列"},
        ["unexpected symbol"] = {en = "unexpected symbol", zh = "意外符号", ko = "예기치 않은 기호", ja = "予期しない記号"},
        ["Expected 'end'"] = {en = "Expected 'end'", zh = "缺少 'end'", ko = "'end'가 필요함", ja = "'end'が必要です"},
        ["Expected 'then'"] = {en = "Expected 'then'", zh = "缺少 'then'", ko = "'then'이 필요함", ja = "'then'が必要です"},
        ["attempt to perform arithmetic on a nil value"] = {en = "attempt to perform arithmetic on a nil value", zh = "尝试对 nil 进行算术运算", ko = "nil에 대한 산술 연산 시도", ja = "nilに対する算術演算を試みました"},
        ["attempt to concatenate a nil value"] = {en = "attempt to concatenate a nil value", zh = "尝试连接 nil 值", ko = "nil 값 연결 시도", ja = "nil値の連結を試みました"},
        ["stack overflow"] = {en = "stack overflow", zh = "堆栈溢出", ko = "스택 오버플로우", ja = "スタックオーバーフロー"},
        ["attempt to yield across a C%-call boundary"] = {en = "attempt to yield across a C-call boundary", zh = "尝试在 C 调用边界 yield", ko = "C 호출 경계에서 yield 시도", ja = "C呼び出し境界でyieldを試みました"},
        ["invalid argument"] = {en = "invalid argument", zh = "无效参数", ko = "잘못된 인수", ja = "無効な引数"},
        ["table expected"] = {en = "table expected", zh = "需要表", ko = "테이블 필요", ja = "テーブルが必要です"},
        ["string expected"] = {en = "string expected", zh = "需要字符串", ko = "문자열 필요", ja = "文字列が必要です"},
        ["number expected"] = {en = "number expected", zh = "需要数字", ko = "숫자 필요", ja = "数字が必要です"},
        ["Expected identifier when parsing expression, got Unicode character"] = {en = "Expected identifier when parsing expression, got Unicode character", zh = "解析表达式时需要标识符，但得到了Unicode字符", ko = "식을 파싱하는 중 식별자가 필요하지만 Unicode 문자를 받았습니다", ja = "式を解析する際に識別子が必要ですが、Unicode文字が見つかりました"},
        ["Expected identifier when parsing expression, got"] = {en = "Expected identifier when parsing expression, got", zh = "解析表达式时需要标识符，但得到了", ko = "식을 파싱하는 중 식별자가 필요하지만 받은 것은", ja = "式を解析する際に識別子が必要ですが、見つかったのは"},
        ["Expected identifier when parsing expression"] = {en = "Expected identifier when parsing expression", zh = "解析表达式时需要标识符", ko = "식을 파싱하는 중 식별자가 필요함", ja = "式を解析する際に識別子が必要です"},
        ["Expected identifier"] = {en = "Expected identifier", zh = "需要标识符", ko = "식별자가 필요함", ja = "識別子が必要です"},
        [", got"] = {en = ", got", zh = ", 但得到了", ko = ", 받은 것은", ja = ", 見つかったのは"},
        ["Expected <eof>"] = {en = "Expected <eof>", zh = "期望文件结束", ko = "<eof>가 필요함", ja = "<eof>が必要です"},
        ["Unicode character"] = {en = "Unicode character", zh = "Unicode字符", ko = "Unicode 문자", ja = "Unicode文字"},
        ["at line"] = {en = "at line", zh = "在行", ko = "줄", ja = "行"},
        ["to close"] = {en = "to close", zh = "关闭", ko = "닫기", ja = "閉じる"},
        ["did you forget to close"] = {en = "did you forget to close", zh = "你是否忘记关闭", ko = "닫는 것을 잊으셨나요", ja = "閉じるのを忘れましたか"},
        ["attempt to index a nil value"] = {en = "attempt to index a nil value", zh = "尝试索引 nil 值", ko = "nil 값 인덱싱 시도", ja = "nil値をインデックスしようとしました"},
        ["attempt to get length of a nil value"] = {en = "attempt to get length of a nil value", zh = "尝试获取 nil 值的长度", ko = "nil 값의 길이를 얻으려고 시도함", ja = "nil値の長さを取得しようとしました"},
        ["attempt to compare nil with"] = {en = "attempt to compare nil with", zh = "尝试将 nil 与", ko = "nil을 다음과 비교 시도", ja = "nilを次と比較しようとしました"},
        ["bad argument"] = {en = "bad argument", zh = "错误参数", ko = "잘못된 인수", ja = "不正な引数"},
        ["function expected"] = {en = "function expected", zh = "需要函数", ko = "함수 필요", ja = "関数が必要です"},
        ["nil value"] = {en = "nil value", zh = "nil 值", ko = "nil 값", ja = "nil値"},
        ["invalid value"] = {en = "invalid value", zh = "无效值", ko = "잘못된 값", ja = "無効な値"},
        ["out of memory"] = {en = "out of memory", zh = "内存不足", ko = "메모리 부족", ja = "メモリ不足"},
        ["too many arguments"] = {en = "too many arguments", zh = "参数过多", ko = "인수가 너무 많음", ja = "引数が多すぎます"},
        ["attempt to call a string value"] = {en = "attempt to call a string value", zh = "尝试调用字符串值", ko = "문자열 값 호출 시도", ja = "文字列値を呼び出そうとしました"},
        ["attempt to call a table value"] = {en = "attempt to call a table value", zh = "尝试调用表值", ko = "테이블 값 호출 시도", ja = "テーブル値を呼び出そうとしました"},
        ["Arrow is not a valid member of"] = {en = "Arrow is not a valid member of", zh = "Arrow 不是有效的成员", ko = "Arrow는 유효한 멤버가 아님", ja = "Arrowは有効なメンバーではありません"},
        ["Overlay is not a valid member of"] = {en = "Overlay is not a valid member of", zh = "Overlay 不是有效的成员", ko = "Overlay는 유효한 멤버가 아님", ja = "Overlayは有効なメンバーではありません"},
        ["Error is not a valid member of"] = {en = "Error is not a valid member of", zh = "Error 不是有效的成员", ko = "Error는 유효한 멤버가 아님", ja = "Errorは有効なメンバーではありません"},
        ["Unable to cast"] = {en = "Unable to cast", zh = "无法转换类型", ko = "캐스팅할 수 없음", ja = "キャストできません"},
        ["Infinite yield possible on"] = {en = "Infinite yield possible on", zh = "可能产生无限等待", ko = "무한 대기 가능성", ja = "無限待機の可能性"},
        ["Players.LocalPlayer"] = {en = "Players.LocalPlayer", zh = "玩家.本地玩家", ko = "플레이어.로컬플레이어", ja = "プレイヤー.ローカルプレイヤー"},
        ["ReplicatedStorage"] = {en = "ReplicatedStorage", zh = "复制存储", ko = "복제 저장소", ja = "レプリケイテッドストレージ"},
        ["ServerScriptService"] = {en = "ServerScriptService", zh = "服务器脚本服务", ko = "서버 스크립트 서비스", ja = "サーバースクリプトサービス"},
        ["StarterGui"] = {en = "StarterGui", zh = "初始界面", ko = "스타터 GUI", ja = "スターターGUI"},
        ["attempt to call missing method"] = {en = "attempt to call missing method", zh = "尝试调用缺失的方法", ko = "누락된 메서드 호출 시도", ja = "欠落したメソッドを呼び出そうとしました"},
        ["table index is nil"] = {en = "table index is nil", zh = "表索引为 nil", ko = "테이블 인덱스가 nil", ja = "テーブルインデックスがnilです"},
        ["Expected '%)'"] = {en = "Expected ')'", zh = "需要 ')'", ko = "')'가 필요함", ja = "')'が必要です"},
        ["Expected 'do'"] = {en = "Expected 'do'", zh = "需要 'do'", ko = "'do'가 필요함", ja = "'do'が必要です"},
        ["got 'local'"] = {en = "got 'local'", zh = "但得到了 'local'", ko = "'local'을 받음", ja = "'local'が見つかりました"},
        ["got 'elseif'"] = {en = "got 'elseif'", zh = "但得到了 'elseif'", ko = "'elseif'를 받음", ja = "'elseif'が見つかりました"},
        ["got '~'"] = {en = "got '~'", zh = "但得到了 '~'", ko = "'~'를 받음", ja = "'~'が見つかりました"},
        ["attempt to perform arithmetic %(sub%) on nil"] = {en = "attempt to perform arithmetic (sub) on nil", zh = "尝试对 nil 执行减法运算", ko = "nil에 대해 산술 연산(빼기) 시도", ja = "nilに対して算術演算（引き算）を試みました"},
    }
    local result = msg

    local sortedPatterns = {}
    for pattern, trans in pairs(mappings) do
        table.insert(sortedPatterns, {pattern = pattern, trans = trans, len = #pattern})
    end
    table.sort(sortedPatterns, function(a, b) return a.len > b.len end)
    for _, entry in ipairs(sortedPatterns) do
        if result:find(entry.pattern) then
            local replacement = entry.trans[lang] or entry.trans.en or entry.pattern
            local ok, newResult = pcall(function()
                return result:gsub(entry.pattern, replacement)
            end)
            if ok then
                result = newResult
            end
        end
    end
    if #errorTranslationCache > 200 then errorTranslationCache = {} end
    errorTranslationCache[cacheKey] = result
    return result
end

function AddLog(message, level)
    if not consoleEnabled or not consoleScroll then
        return
    end

    local msgStr = tostring(message)
    if level == "error" then
        msgStr = translateError(msgStr)
    end

    local lineNum = nil
    local lineStart, lineEnd = msgStr:find("Line", 1, true)
    if lineStart then
        local afterLine = msgStr:sub(lineEnd + 1)
        local numStr = ""
        for i = 1, #afterLine do
            local c = afterLine:sub(i, i)
            if c >= "0" and c <= "9" then
                numStr = numStr .. c
            elseif #numStr > 0 then
                break
            elseif c ~= " " and c ~= "  " then
                break
            end
        end
        lineNum = tonumber(numStr)
    end
    if lineNum and not _G.__DeltaUI_skipLineOffset then
        local offset = 0
        local currentText = tabs[currentTab] and tabs[currentTab].content or ""
        if type(currentText) == "string" and currentText:sub(1, 3) == "--[" then
            local blockEnd = currentText:find("]]", 1, true)
            if blockEnd then
                local header = currentText:sub(1, blockEnd + 2)
                for _ in header:gmatch(string.char(10)) do
                    offset = offset + 1
                end
            end
        end
        local realLine = tonumber(lineNum) - offset
        if realLine > 0 then
            msgStr = msgStr:gsub("Line%s+" .. lineNum, "Line " .. realLine .. " " .. t("real_line"))
        end
    end

    table.insert(pendingLogs, {msg = msgStr, lvl = level or "info"})

    if logProcessing then return end
    logProcessing = true
    task.defer(function()
        while #pendingLogs > 0 do
            local batch = {}
            for i = 1, math.min(10, #pendingLogs) do
                local item = table.remove(pendingLogs, 1)
                if item then
                    batch[i] = item
                end
            end
            if not consoleScroll then break end
            for _, log in ipairs(batch) do
                if log then
                    local color = theme.text
                    if log.lvl == "error" then color = theme.red
                    elseif log.lvl == "warn" then color = theme.warn
                    elseif log.lvl == "info" then color = theme.textDim end
                    local entry = create("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 0),
                        BackgroundTransparency = 1,
                        Text = log.msg,
                        TextColor3 = color,
                        TextSize = 11,
                        Font = Enum.Font.Code,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextYAlignment = Enum.TextYAlignment.Top,
                        TextWrapped = true,
                        AutomaticSize = Enum.AutomaticSize.Y,
                        ZIndex = 4
                    })
                    entry.Parent = consoleScroll
                    logEntryCount = logEntryCount + 1
                    if logEntryCount > maxLogEntries then
                        for _, child in pairs(consoleScroll:GetChildren()) do
                            if child:IsA("TextLabel") then
                                child:Destroy()
                                logEntryCount = logEntryCount - 1
                                break
                            end
                        end
                    end
                end
            end
            if #pendingLogs > 0 then
                task.wait(0.05)
            end
        end
        logProcessing = false
    end)
end

saveFolder = "DeltaUI/Script"
function ensureFolder()
    if not isfolder("DeltaUI") then
        makefolder("DeltaUI")
    end
    if not isfolder(saveFolder) then
        makefolder(saveFolder)
    end
    return true
end

autoExecFolder = "DeltaUI/AutoExecute"
function ensureAutoExecFolder()
    if not isfolder("DeltaUI") then makefolder("DeltaUI") end
    if not isfolder(autoExecFolder) then makefolder(autoExecFolder) end
end

function getAutoExecFileState(name)
    ensureAutoExecFolder()
    local safeName = __safeFilterName(name:gsub("%s+", "_"))
    if safeName == "" then safeName = "untitled" end
    local fp = autoExecFolder .. "/" .. safeName .. ".json"
    if isfile(fp) then
        local txt = readfile(fp)
        if txt then
            local data = svc.HttpService:JSONDecode(txt)
            if type(data) == "table" and data.enabled ~= nil then
                return data.enabled
            end
        end
    end
    return false
end

function setAutoExecFileState(name, enabled)
    ensureAutoExecFolder()
    local safeName = __safeFilterName(name:gsub("%s+", "_"))
    if safeName == "" then safeName = "untitled" end
    local fp = autoExecFolder .. "/" .. safeName .. ".json"
    local data = svc.HttpService:JSONEncode({enabled = enabled, name = name})
    writefile(fp, data)
end
function hasExecutorDescendant(container)
    for _, d in pairs(container:GetDescendants()) do
        if d.Name == "Executor" then
            return true
        end
    end
    return false
end

function destroyExecutorUI(container)
    if hasExecutorDescendant(container) then
        container:Destroy()
        return true
    end
    return false
end



function hideExecutorUI(container)
    local hidden = false
    local function hideWindow(win)
        pcall(function()
            if win:IsA("ScreenGui") then
                win.Enabled = false
            elseif win:IsA("GuiObject") then
                win.Visible = false
            end
        end)
        hidden = true
    end
    
    for _, win in pairs(container:GetChildren()) do
        if win:IsA("ScreenGui") or win:IsA("GuiObject") then
            if hasExecutorDescendant(win) then
                hideWindow(win)
            end
        end
    end
    
    if (container:IsA("ScreenGui") or container:IsA("GuiObject")) and hasExecutorDescendant(container) then
        hideWindow(container)
    end
    return hidden
end

function getClipboardContent()
    local apis = {
        getclipboard,
        GetClipBoard,
        (syn and syn.getclipboard),
        (clipboard and clipboard.get),
        (get_clipboard),
        (getgenv and getgenv().getclipboard),
        (getgenv and getgenv().GetClipBoard),
    }
    for _, api in ipairs(apis) do
        if type(api) == "function" then
            local ok, result = pcall(api)
            if ok and result and result ~= "" then
                return result
            end
        end
    end
    local fallbackPaths = {
        "clipboard.txt",
        "DeltaUI/clipboard.txt",
    }
    for _, path in ipairs(fallbackPaths) do
        if isfile and isfile(path) then
            local ok, result = pcall(readfile, path)
            if ok and result and result ~= "" then
                return result
            end
        end
    end
    return nil
end
function generateHash64()
    local chars = "0123456789abcdef"
    local hash = ""
    for i = 1, 16 do
        local idx = math.random(1, 16)
        hash = hash .. chars:sub(idx, idx)
    end
    return hash
end

local function getUiName()
    local cfg = loadConfig()
    if cfg and cfg.compatibilityMode then

        return "DeltaUI_7f9a2b4c6d8e1035"
    end
    return generateHash64()
end

local containerName = getUiName()
local oldContainer = svc.CoreGui:FindFirstChild(containerName)
if oldContainer then
    oldContainer:Destroy()
    task.wait(0.05)
end
local uiContainer = create("Folder", {Name = containerName})
uiContainer.Parent = svc.CoreGui

screenGui = create("ScreenGui", {Name = getUiName(), ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true, DisplayOrder = 999999})
screenGui.Parent = uiContainer

main = create("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = theme.bg, BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true, Visible = true, ZIndex = 1})
main.Parent = screenGui

currentNotifProgressTween = nil
notificationQueue = {}
notificationActive = false

function ShowNotification(message, duration, clickCallback)
    local cfg = loadConfig()
    if cfg.disableNotifications then return end
    duration = duration or 1
    table.insert(notificationQueue, {msg = message, dur = duration, click = clickCallback})
    if notificationActive then
        _G.__DeltaUI_skipNotification = true
        if currentNotifProgressTween then
            currentNotifProgressTween:Cancel()
            currentNotifProgressTween = nil
        end
        return
    end
    task.spawn(function()
        while #notificationQueue > 0 do
            notificationActive = true
            _G.__DeltaUI_skipNotification = false

            if currentNotifFrame and currentNotifFrame.Parent then
                svc.TweenService:Create(currentNotifFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0.5, 0, 0, -60)}):Play()
                svc.TweenService:Create(currentNotifFrame, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
                for _, child in pairs(currentNotifFrame:GetChildren()) do
                    if child:IsA("TextLabel") or child:IsA("TextButton") then
                        svc.TweenService:Create(child, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
                    elseif child:IsA("Frame") then
                        svc.TweenService:Create(child, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
                    end
                end
                task.wait(0.2)
                if currentNotifFrame and currentNotifFrame.Parent then
                    currentNotifFrame:Destroy()
                end
            end
            local notif = table.remove(notificationQueue, 1)
            local notifFrame = create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0),
                Position = UDim2.new(0.5, 0, 0, -60),
                Size = UDim2.new(0, 0, 0, 40),
                BackgroundColor3 = theme.surface,
                BackgroundTransparency = 0.2,
                BorderSizePixel = 0,
                Active = notif.click and true or false,
                ClipsDescendants = true,
                ZIndex = 2000,
            })
            corner(10, notifFrame)
            stroke(theme.border, 1, notifFrame)
            notifFrame.Parent = screenGui
            currentNotifFrame = notifFrame
            local notifText = create("TextLabel", {
                Size = UDim2.new(1, 0, 1, -4),
                Position = UDim2.new(0, 0, 0, 0),
                BackgroundTransparency = 1,
                Text = notif.msg,
                TextColor3 = theme.text,
                TextSize = 12,
                Font = Enum.Font.SourceSansBold,
                TextXAlignment = Enum.TextXAlignment.Center,
                TextYAlignment = Enum.TextYAlignment.Center,
                ZIndex = 2001
            })
            notifText.Parent = notifFrame
            local notifProgress = create("Frame", {
                AnchorPoint = Vector2.new(0, 0),
                Position = UDim2.new(0, 4, 1, -4),
                Size = UDim2.new(1, -8, 0, 3),
                BackgroundColor3 = theme.accent,
                BackgroundTransparency = 0.4,
                BorderSizePixel = 0,
                ZIndex = 2002,
                ClipsDescendants = true
            })
            applyGradient(notifProgress, theme.accent, theme.accent2, 120)
            corner(2, notifProgress)
            notifProgress.Parent = notifFrame
            if notif.click then
                notifFrame.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        notif.click()
                    end
                end)
            end
            svc.TweenService:Create(notifFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0, 12)}):Play()
            local notifWidth = math.min(380, math.max(200, notifText.TextBounds.X + 40))
            svc.TweenService:Create(notifFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, notifWidth, 0, 40)}):Play()
            task.wait(0.35)
            currentNotifProgressTween = svc.TweenService:Create(notifProgress, TweenInfo.new(notif.dur, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 0, 3)})
            currentNotifProgressTween:Play()
            local elapsed = 0
            while elapsed < notif.dur do
                if _G.__DeltaUI_skipNotification then
                    break
                end
                task.wait(0.05)
                elapsed = elapsed + 0.05
            end
            currentNotifProgressTween = nil
            svc.TweenService:Create(notifFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0.5, 0, 0, -60)}):Play()
            svc.TweenService:Create(notifFrame, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
            svc.TweenService:Create(notifText, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
            svc.TweenService:Create(notifProgress, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
            task.wait(0.3)
            notifFrame:Destroy()
        end
        notificationActive = false
    end)
end
topBar = create("Frame", {Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 10})
topBar.Parent = main

navBg = create("Frame", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 10, 0.5, 0),
    Size = UDim2.new(0, 44, 0, 244),
    BackgroundColor3 = theme.surfaceLight,
    BackgroundTransparency = 0.5,
    BorderSizePixel = 0,
    ZIndex = 11
})
corner(22, navBg)
stroke(theme.border, 1, navBg)
navBg.Parent = main
logoutBtn = create("TextButton", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 10, 0.5, 152),
    Size = UDim2.new(0, 44, 0, 44),
    BackgroundColor3 = theme.surfaceLight,
    BackgroundTransparency = 0.5,
    BorderSizePixel = 0,
    Text = "",
    ZIndex = 11
})
corner(22, logoutBtn)
stroke(theme.border, 1, logoutBtn)
logoutBtn.Parent = main
logoutIcon = GetIcon("minimize", UDim2.new(0, 16, 0, 16), theme.text)
if logoutIcon then
    logoutIcon.Position = UDim2.new(0.5, -8, 0.5, -8)
    logoutIcon.Parent = logoutBtn
end


appLogo = create("Frame", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -16, 0.5, 12),
    Size = UDim2.new(0, 40, 0, 40),
    BackgroundColor3 = theme.accent,
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    ZIndex = 11,
})
corner(9, appLogo)
applyGradient(appLogo)
appLogo.Parent = topBar
appLogoGlyph = create("TextLabel", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "Δ",
    TextColor3 = theme.text,
    TextSize = 24,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 12,
})
appLogoGlyph.Parent = appLogo
appTitle = create("TextLabel", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -72, 0.5, 12),
    Size = UDim2.new(0, 130, 0, 20),
    BackgroundTransparency = 1,
    Text = "Delta UI",
    TextColor3 = theme.text,
    TextSize = 17,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Right,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 11,
})
 appTitle.Parent = topBar
navContainer = create("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    ZIndex = 12
})
navContainer.Parent = navBg
navNames = {"house", "terminal", "gamepad-2", "package", "settings"}
navButtons = {}
navIcons = {}
btnYPositions = {6, 46, 86, 126, 166, 206}
for i, name in ipairs(navNames) do
    btn = create("TextButton", {
        Size = UDim2.new(0, 32, 0, 32),
        Position = UDim2.new(0, 6, 0, btnYPositions[i]),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        ZIndex = 15
    })
    local iconSize = 18
    icon = GetIcon(name, UDim2.new(0, iconSize, 0, iconSize))
    if icon then
        icon.Position = UDim2.new(0.5, -iconSize / 2, 0.5, -iconSize / 2)
        icon.Parent = btn
        navIcons[name] = icon
    end
    btn.Parent = navContainer
    navButtons[name] = btn
end

navIndicator = create("Frame", {
    Size = UDim2.new(0, 32, 0, 32),
    BackgroundColor3 = theme.accent,
    BackgroundTransparency = 0.2,
    BorderSizePixel = 0,
    ZIndex = 10
})
corner(16, navIndicator)
applyGradient(navIndicator, theme.accent, theme.accent2, 120)
stroke(theme.accent, 1, navIndicator)
navIndicator.Parent = navBg
local function getIndicatorCenterPos(btn)
    local btnPos = btn.Position
    local btnSize = btn.Size
    local indSize = navIndicator.Size
    local offsetX = (btnSize.X.Offset - indSize.X.Offset) / 2
    local offsetY = (btnSize.Y.Offset - indSize.Y.Offset) / 2
    return UDim2.new(btnPos.X.Scale, btnPos.X.Offset + offsetX, btnPos.Y.Scale, btnPos.Y.Offset + offsetY)
end
navIndicator.Position = getIndicatorCenterPos(navButtons[navNames[1]])
function animateIndicator(targetBtn)
    local targetPos = getIndicatorCenterPos(targetBtn)
    svc.TweenService:Create(navIndicator, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = targetPos}):Play()
end
function cleanupOldUI()
    local cfg = loadConfig()
    local compatMode = cfg.compatibilityMode
    for _, child in pairs(svc.CoreGui:GetChildren()) do
        if #child.Name > 20 then
            if compatMode then
                for _, sub in pairs(child:GetChildren()) do
                    if sub:FindFirstChild("MainScript") then
                        pcall(function()
                            sub.Enabled = false
                        end)
                    end
                end
            end
            
            hideExecutorUI(child)
        end
    end
    if not _G.__DeltaUI_fileCleaned then
        _G.__DeltaUI_fileCleaned = true
        pcall(function()
            if isfile("TALENTLESS_language.txt") then
                delfile("TALENTLESS_language.txt")
            end
        end)
    end
end

function switchPage(pageName)
    if buildSpaceActive and exitBuildSpace then exitBuildSpace() end
    for _, child in pairs(screenGui:GetChildren()) do
        if child:IsA("Frame") and child.ZIndex == 999 then
            child:Destroy()
        end
    end

    for _, dd in ipairs(_G.__DeltaUI_dropdowns or {}) do
        if dd.close then dd.close() end
    end
    if pageName == currentPage then return end
    currentPage = pageName
    for _, page in pairs(pages) do
        page.Visible = false
    end
    if pages[pageName] then
        pages[pageName].Visible = true
    end
    if bottomBar then
        bottomBar.Visible = (pageName == "house")
    end
    if navButtons[pageName] then
        animateIndicator(navButtons[pageName])
    end
    if pageName == "package" then
        if cloudSearchInput then cloudSearchInput.Text = "" end
    end
end
function refreshScriptList(filter)
    if _G.__DeltaUI_refreshScriptLock then return end
    _G.__DeltaUI_refreshScriptLock = true
        for _, child in pairs(scriptListScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    ensureFolder()
    ensureStoreFolder()

    local allScripts = {}

    local files = listfiles(saveFolder) or {}
    if files then
        for _, filePath in ipairs(files) do
local name = filePath:match("([^/]*)%.lua$") or filePath:match("([^/]*)$")
            if name then
                local metaPath = filePath:sub(-4)==".lua" and (filePath:sub(1,-5)..".meta.json") or (filePath..".meta.json")
                local serversList = {}
                if isfile(metaPath) then
                    local metaTxt = readfile(metaPath)
                    if metaTxt then
                        local ok, meta = pcall(function()
                            return svc.HttpService:JSONDecode(metaTxt)
                        end)
                        if ok and meta and meta.servers then
                            serversList = meta.servers
                        end
                    end
                end
                table.insert(allScripts, {name = name, path = filePath, fromStore = false, servers = serversList})
            end
        end
    end

    local storeFiles = listfiles(storeScriptFolder) or {}
    if storeFiles then
        for _, filePath in ipairs(storeFiles) do
            if filePath:sub(-5)==".json" then
                local txt = readfile(filePath)
                if txt then
                    local meta = svc.HttpService:JSONDecode(txt)
                    if meta and meta.name then
                        table.insert(allScripts, {name = meta.name, path = filePath, fromStore = true, meta = meta})
                    end
                end
            end
        end
    end

    local seenNames = {}
    for _, script in ipairs(allScripts) do
        local name = script.name
        local filePath = script.path
        if name and (not filter or filter == "" or name:lower():find(filter:lower())) then
            if not seenNames[name] then
                seenNames[name] = true
            do
                local scriptRef = script
                local item = create("Frame", {
                Size = UDim2.new(1, 0, 0, 44),
                BackgroundColor3 = theme.surface,
                BackgroundTransparency = 0.25,
                BorderSizePixel = 0,
                ZIndex = 4
            })
            corner(10, item)
            local itemTitle = create("TextLabel", {
                Position = UDim2.new(0, 14, scriptRef.fromStore and 0 or 0, scriptRef.fromStore and 6 or 0),
                Size = UDim2.new(0.5, 0, scriptRef.fromStore and 0 or 1, scriptRef.fromStore and 20 or 0),
                BackgroundTransparency = 1,
                Text = name,
                TextColor3 = theme.text,
                TextSize = 15,
                Font = Enum.Font.SourceSansBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center,
                ZIndex = 5
            })
            itemTitle.Parent = item

            local serversList = script.servers or (script.meta and script.meta.Servers) or {}
            if script.fromStore then
                local storeBadge = create("TextLabel", {
                    Position = UDim2.new(0, 14, 0, 26),
                    Size = UDim2.new(0, 120, 0, 14),
                    BackgroundTransparency = 1,
                    Text = t("from_store") .. (script.meta and script.meta.Version and " v" .. script.meta.Version or ""),
                    TextColor3 = theme.accent,
                    TextSize = 10,
                    Font = Enum.Font.SourceSans,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    ZIndex = 5
                })
                storeBadge.Parent = item
            end

            local delBtn = create("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -107, 0.5, 0),
                Size = UDim2.new(0, 70, 0, 28),
                BackgroundColor3 = theme.surfaceLight,
                BackgroundTransparency = 0.3,
                Text = "",
                BorderSizePixel = 0,
                ZIndex = 5
            })
            corner(8, delBtn)
            local delText = create("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = t("delete"), TextColor3 = theme.text, TextSize = 11, Font = Enum.Font.SourceSansBold, ZIndex = 6})
            delText.Parent = delBtn
            delBtn.Parent = item
            delBtn.MouseButton1Click:Connect(function()
                if scriptRef.fromStore then
                    if removeStoreScript then
                        removeStoreScript(name)
                    else
                        if isfile(filePath) then delfile(filePath) end
                        refreshScriptList(searchInput.Text)
                    end
                    ShowNotification(t("deleted") or "Deleted", 1)
                    return
                end
                delfile(filePath)
                local metaPath = filePath:sub(-4)==".lua" and (filePath:sub(1,-5)..".meta.json") or (filePath..".meta.json")
                if isfile(metaPath) then
                    delfile(metaPath)
                end
                item:Destroy()
                refreshScriptList(searchInput.Text)
            end)

            local execBtn2 = create("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -34, 0.5, 0),
                Size = UDim2.new(0, 70, 0, 28),
                BackgroundColor3 = theme.accent,
                BackgroundTransparency = 0.3,
                Text = "",
                BorderSizePixel = 0,
                ZIndex = 5
            })
            applyGradient(execBtn2, theme.accent, theme.accent2, 120)
            corner(8, execBtn2)
            local execText2 = create("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = t("execute_cap"), TextColor3 = Color3.fromRGB(255,255,255), TextSize = 11, Font = Enum.Font.SourceSansBold, ZIndex = 6})
            execText2.Parent = execBtn2
            execBtn2.Parent = item

            do
                local scriptName = name
                local autoExecEnabled = getAutoExecFileState(scriptName)
                local autoExecBtn = create("TextButton", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -3, 0.5, 0),
                    Size = UDim2.new(0, 28, 0, 28),
                    BackgroundColor3 = autoExecEnabled and theme.accent or theme.surfaceLight,
                    BackgroundTransparency = 0.25,
                    Text = "",
                    BorderSizePixel = 0,
                    ZIndex = 5
                })
                corner(6, autoExecBtn)
                local autoExecIcon = GetIcon("file-terminal", UDim2.new(0, 14, 0, 14), Color3.fromRGB(255,255,255))
                if autoExecIcon then
                    autoExecIcon.Position = UDim2.new(0.5, -7, 0.5, -7)
                    autoExecIcon.Parent = autoExecBtn
                end
                autoExecBtn.Parent = item
                    autoExecBtn.MouseButton1Click:Connect(function()
                    autoExecEnabled = not autoExecEnabled
                    setAutoExecFileState(scriptName, autoExecEnabled)
                    svc.TweenService:Create(autoExecBtn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = autoExecEnabled and theme.accent or theme.surfaceLight}):Play()
                    if autoExecEnabled then
                        ShowNotification(t("autoexec_enabled"), 1)
                    else
                        ShowNotification(t("autoexec_disabled"), 1)
                    end
                end)
            end
            execBtn2.MouseButton1Click:Connect(function()
                local code2
                if scriptRef.fromStore and scriptRef.meta and scriptRef.meta.Url then
                    local src = game:HttpGet(scriptRef.meta.Url)
                    if src then
                        code2 = src
                    else
                        AddLog("[Script] Failed to fetch: " .. scriptRef.name, "error")
                        return
                    end
                else
                    code2 = readfile(filePath)
                end

                if code2 and code2 ~= "" then
                    if not _G.__DeltaUI_cleaned then
                        cleanupOldUI()
                        _G.__DeltaUI_cleaned = true
                    end
                    switchPage("terminal")
                    ShowNotification(t("script_loading") .. scriptRef.name, 2)
                    AddLog("> " .. t("executing_saved") .. scriptRef.name, "info")
                    local fn2, err2 = loadstring(code2)
                    if not fn2 then
                        local errLine2 = parseErrorLine(tostring(err2))
                        if errLine2 then
                            jumpToErrorLine(errLine2)
                        end
                        AddLog("[Error] " .. tostring(err2), "error")
                        ShowNotification(t("execution_error_notify"), 3, function()
                            switchPage("terminal")
                        end)
                        return
                    end
                    local oldPrint = print
                    local oldWarn = warn
                    print = function(...)
                        local args = {...}
                        local msg = table.concat(args, " ")
                        AddLog(msg, "info")
                        if logDedup then logDedup[msg] = tick() end
                        _G.__DeltaUI_blockLogService = true
                        oldPrint(...)
                        _G.__DeltaUI_blockLogService = nil
                    end
                    warn = function(...)
                        local args = {...}
                        local msg = table.concat(args, " ")
                        AddLog(msg, "warn")
                        if logDedup then logDedup[msg] = tick() end
                        _G.__DeltaUI_blockLogService = true
                        oldWarn(...)
                        _G.__DeltaUI_blockLogService = nil
                    end
                    _G.__DeltaUI_blockLogService = true
                    local ok, execErr = pcall(fn2)
                    _G.__DeltaUI_blockLogService = nil
                    print = oldPrint
                    warn = oldWarn
                    if not ok then
                        AddLog("[Error] " .. tostring(execErr), "error")
                    end

                    AddLog("> " .. t("execution_finished"), "info")
                end
            end)
            item.Parent = scriptListScroll
                end
            end
        end
    end

    do
        local kbItem = create("Frame", {
            Size = UDim2.new(1, 0, 0, 44),
            BackgroundColor3 = theme.surface,
            BackgroundTransparency = 0.25,
            BorderSizePixel = 0,
            ZIndex = 4,
            LayoutOrder = 999999
        })
        corner(10, kbItem)
        local kbTitle = create("TextLabel", {
            Position = UDim2.new(0, 14, 0, 1.5),
            Size = UDim2.new(0.5, 0, 0, 20),
            BackgroundTransparency = 1,
            Text = "KeyBoard",
            TextColor3 = theme.text,
            TextSize = 15,
            Font = Enum.Font.SourceSansBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 5
        })
        kbTitle.Parent = kbItem
        local kbSub = create("TextLabel", {
            Position = UDim2.new(0, 14, 0, 24),
            Size = UDim2.new(0, 120, 0, 14),
            BackgroundTransparency = 1,
            Text = "From Delta",
            TextColor3 = theme.textDim,
            TextSize = 10,
            Font = Enum.Font.SourceSans,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 5
        })
        kbSub.Parent = kbItem

        local kbExec = create("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.new(0, 90, 0, 28),
            BackgroundColor3 = theme.accent,
            BackgroundTransparency = 0.3,
            Text = "",
            BorderSizePixel = 0,
            ZIndex = 5
        })
        applyGradient(kbExec, theme.accent, theme.accent2, 120)
        corner(8, kbExec)
        local kbExecText = create("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = t("execute_cap"),
            TextColor3 = Color3.fromRGB(255,255,255),
            TextSize = 11,
            Font = Enum.Font.SourceSansBold,
            ZIndex = 6
        })
        kbExecText.Parent = kbExec
        kbExec.Parent = kbItem
        kbExec.MouseButton1Click:Connect(function()
            local kbCachePath = "DeltaUI/Cache/MobileKeyboard.lua"
            local src = nil

            
            if isfile(kbCachePath) then
                local ok, localSrc = pcall(function() return readfile(kbCachePath) end)
                if ok and localSrc and localSrc ~= "" then
                    src = localSrc
                end
            end

            
            if not src or src == "" then
                local ok, netSrc = pcall(function()
                    return game:HttpGet("https://github.com/AZYsGithub/Delta-Scripts/raw/refs/heads/main/MobileKeyboard.txt")
                end)
                if ok and netSrc and netSrc ~= "" then
                    src = netSrc
                    
                    pcall(function()
                        if not isfolder("DeltaUI") then makefolder("DeltaUI") end
                        if not isfolder("DeltaUI/Cache") then makefolder("DeltaUI/Cache") end
                        writefile(kbCachePath, src)
                    end)
                end
            end

            if src and src ~= "" then
                ShowNotification(t("script_loaded") .. "KeyBoard", 2)
                AddLog("> " .. t("executing_saved") .. "KeyBoard", "info")
                local fn, err = loadstring(src)
                if fn then
                    local ok2, runErr = xpcall(fn, function(err)
                        return debug.traceback(tostring(err), 2)
                    end)
                    if ok2 then
                        ShowNotification(t("script_loaded") .. "KeyBoard", 2)
                        main.Visible = false
                        orbFrame.Visible = true
                        orbFrame.BackgroundTransparency = 0.1
                        if orbStroke then orbStroke.Transparency = 0 end
                        orbPulseActive = true
                        orbPulseConn = svc.RunService.RenderStepped:Connect(orbPulse)
                    else
                        AddLog("[Error] " .. tostring(runErr), "error")
                        ShowNotification(t("execution_error_notify"), 3)
                    end
                else
                    AddLog("[Error] " .. tostring(err), "error")
                    ShowNotification(t("execution_error_notify"), 3)
                end
            else
                AddLog("[Script] Failed to fetch: KeyBoard", "error")
                ShowNotification(t("fetch_failed"), 3)
            end
        end)

        kbItem.Parent = scriptListScroll
    end

    task.defer(function()
        if scriptListScroll and scriptListLayout and scriptListScroll.Parent then
            local absSize = scriptListLayout.AbsoluteContentSize
            if absSize then
                scriptListScroll.CanvasSize = UDim2.new(0, 0, 0, absSize.Y + 8)
            end
        end
    end)
    _G.__DeltaUI_refreshScriptLock = nil
end

for _, name in ipairs(navNames) do
    navButtons[name].MouseButton1Click:Connect(function()
        if customTabMode then return end
        switchPage(name)
    end)
end

customItemsPanel = nil
customItemsScroll = nil
customItemsRows = {}
customDeleteOpenRow = nil
customListDragging = false
customListDragRow = nil
customListDragName = nil
customListDragConnections = {}
customListDragStartY = 0
customListDragOffsetY = 0
customListLayout = nil
customIconPanel = nil
customIconPanelOpen = false
customIconPanelTab = nil
customIconSearchBox = nil
customIconSearchInput = nil
customIconScroll = nil
customIconGridLayout = nil
customIconAllNames = nil
customIconLoadToken = 0
customIconSelectedCell = nil
iconUrlCache = {}
customIconNavBgSavedPos = nil
customIconNavBgSavedSize = nil
customIconHighlightedBtn = nil
customIconHighlightedOriginalColor = nil

navBgTween = nil
function cancelNavBgTween()
    if navBgTween then
        pcall(function() navBgTween:Cancel() end)
        navBgTween = nil
    end
end

local tabNameMap = {
    house = "主页",
    terminal = "控制台",
    ["gamepad-2"] = "脚本管理器",
    package = "脚本商店",
    coding = "编程积木",
    settings = "设置"
}
local tabIconMap = {
    house = "house",
    terminal = "terminal",
    ["gamepad-2"] = "gamepad-2",
    package = "package",
    chat = "message-circle",
    coding = "blocks",
    settings = "settings"
}
local protectedTabs = {house = true, settings = true}
local allNavItems = {"house", "terminal", "gamepad-2", "package", "settings"}

AntiTamper = {
    active = false,
    checkInterval = 5,
    connections = {},
    lastMainVisible = nil,
    lastOrbVisible = nil,
    protectedInstances = {},
}

function AntiTamper.protectGui(gui)
    if not gui then return end
    local ok = pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(gui)
        end
        if gethui then
            gui.Parent = gethui()
            return
        elseif get_hidden_gui then
            gui.Parent = get_hidden_gui()
            return
        elseif getgui then
            gui.Parent = getgui()
            return
        end
    end)
    if not ok then
        gui.Parent = svc.CoreGui
    end
end

function AntiTamper.getContainer()
    if uiContainer and uiContainer.Parent then
        return uiContainer
    end
    for _, child in pairs(svc.CoreGui:GetChildren()) do
        if child.Name == containerName and child:FindFirstChildOfClass("ScreenGui") then
            uiContainer = child
            return child
        end
    end
    return nil
end

function AntiTamper.checkIntegrity()
    if not AntiTamper.active then return end

    local container = AntiTamper.getContainer()
    if not container then
        return
    end

    local sg = container:FindFirstChildOfClass("ScreenGui")
    if not sg then
        return
    end

    if main and main.Parent then
        if main.Visible == false and not customTabMode and not buildSpaceActive then
            if AntiTamper.lastMainVisible ~= false then
                main.Visible = true
                if orbFrame then
                    orbFrame.Visible = false
                end
            end
        end
        AntiTamper.lastMainVisible = main.Visible
    end

    if orbFrame and orbFrame.Parent then
        if main and main.Visible and orbFrame.Visible then
            orbFrame.Visible = false
        end
        AntiTamper.lastOrbVisible = orbFrame.Visible
    end

    if sg.Enabled == false then
        sg.Enabled = true
    end

    if sg.DisplayOrder ~= 999999 then
        sg.DisplayOrder = 999999
    end

    if sg.ZIndexBehavior ~= Enum.ZIndexBehavior.Sibling then
        sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    end

    if sg.ResetOnSpawn ~= false then
        sg.ResetOnSpawn = false
    end

    if sg.IgnoreGuiInset ~= true then
        sg.IgnoreGuiInset = true
    end

    local keyInstances = {
        main = main,
        orbFrame = orbFrame,
        navBg = navBg,
        navIndicator = navIndicator,
        contentFrame = contentFrame,
        wrapperFrame = wrapperFrame,
    }
    for name, inst in pairs(keyInstances) do
        if inst then
            if not inst.Parent then
                warn("[DeltaUI] Key instance detached: " .. name)
            elseif inst.Visible == false and name ~= "orbFrame" and not customTabMode then
                inst.Visible = true
            end
        end
    end

    for _, child in pairs(svc.CoreGui:GetChildren()) do
        if child ~= container and child.Name:sub(1,7) == "DeltaUI" then
            pcall(function() child:Destroy() end)
        end
    end

    if _G.__DeltaUI_screenGui ~= screenGui then
        _G.__DeltaUI_screenGui = screenGui
    end
    if _G.__DeltaUI_main ~= main then
        _G.__DeltaUI_main = main
    end

    local coreGuiChildren = svc.CoreGui:GetChildren()
    if #coreGuiChildren > 50 then

    end
end

function AntiTamper.start()
    if AntiTamper.active then return end
    AntiTamper.active = true

    local conn = svc.RunService.Heartbeat:Connect(function()
        if tick() % AntiTamper.checkInterval < 0.05 then
            AntiTamper.checkIntegrity()
        end
    end)
    table.insert(AntiTamper.connections, conn)

    if screenGui then
        AntiTamper.protectGui(screenGui)
    end
end

function AntiTamper.stop()
    AntiTamper.active = false
    for _, conn in ipairs(AntiTamper.connections) do
        pcall(function() conn:Disconnect() end)
    end
    AntiTamper.connections = {}
end

customTabMode = false
customTabOrder = {}
originalNavState = {}
isDraggingTab = false
draggedTabBtn = nil
draggedTabName = nil
tabDragConnections = {}
activeTabHold = nil
dragOffsetX = 0
dragOffsetY = 0
fadeableElements = {}
customTabNavBgSavedPos = nil
customTabNavBgSavedSize = nil

function saveTabOrder()
    local cfg = loadConfig()
    cfg.tabOrder = customTabOrder
    saveConfig(cfg)
end

function resetTabOrder()
    customTabOrder = {unpack(navNames)}
    saveTabOrder()
    tabIconMap = {
        house = "house",
        terminal = "terminal",
        ["gamepad-2"] = "gamepad-2",
        package = "package",
        chat = "message-circle",
        coding = "blocks",
        settings = "settings"
    }
    local cfg = loadConfig()
    cfg.tabIcons = {}
    saveConfig(cfg)
    applyTabOrder()
    for _, name in ipairs(navNames) do
        local btn = navButtons[name]
        if btn then
            local oldIcon = btn:FindFirstChildOfClass("ImageLabel")
            if oldIcon then oldIcon:Destroy() end
            local iconSize = customTabMode and 22 or 18
            local newIcon = GetIcon(name, UDim2.new(0, iconSize, 0, iconSize))
            if newIcon then
                newIcon.Position = UDim2.new(0.5, -iconSize / 2, 0.5, -iconSize / 2)
                newIcon.Parent = btn
            end
        end
    end
    ShowNotification(t("reset_tab_order"), 1)
end

function loadTabOrder()
    local cfg = loadConfig()
    if cfg.tabOrder and type(cfg.tabOrder) == "table" and #cfg.tabOrder == #navNames then
        local valid = true
        local seen = {}
        for _, name in ipairs(cfg.tabOrder) do
            if not navButtons[name] or seen[name] then
                valid = false
                break
            end
            seen[name] = true
        end
        if valid then
            return cfg.tabOrder
        end
    end
    return {unpack(navNames)}
end

function saveTabIcons()
    local cfg = loadConfig()
    cfg.tabIcons = {}
    for k, v in pairs(tabIconMap) do
        if k ~= v then cfg.tabIcons[k] = v end
    end
    saveConfig(cfg)
end

function loadTabIcons()
    local cfg = loadConfig()
    if cfg.tabIcons and type(cfg.tabIcons) == "table" then
        for k, v in pairs(cfg.tabIcons) do
            if type(k) == "string" and type(v) == "string" then
                tabIconMap[k] = v
            end
        end
    end
end

function applyTabIcon(tabName, iconName, skipSave)
    tabIconMap[tabName] = iconName
    local btn = navButtons[tabName]
    if btn then
        local oldIcon = btn:FindFirstChildOfClass("ImageLabel")
        if oldIcon then oldIcon:Destroy() end
        local iconSize = customTabMode and 22 or 18
        local newIcon = GetIcon(iconName, UDim2.new(0, iconSize, 0, iconSize))
        if newIcon then
            newIcon.Position = UDim2.new(0.5, -iconSize / 2, 0.5, -iconSize / 2)
            newIcon.Parent = btn
        end
    end
    if not skipSave then saveTabIcons() end
end

function applyTabIcons()
    for tabName, iconName in pairs(tabIconMap) do
        if navButtons[tabName] and iconName ~= tabName then
            local btn = navButtons[tabName]
            local oldIcon = btn:FindFirstChildOfClass("ImageLabel")
            if oldIcon then oldIcon:Destroy() end
            local newIcon = GetIcon(iconName, UDim2.new(0, 18, 0, 18))
            if newIcon then
                newIcon.Position = UDim2.new(0.5, -9, 0.5, -9)
                newIcon.Parent = btn
            end
        end
    end
end

function applyTabOrder()
    if customTabMode then return end
    for _, btn in pairs(navButtons) do
        btn.Visible = false
    end
    local n = #customTabOrder
    for i, name in ipairs(customTabOrder) do
        local btn = navButtons[name]
        if btn then
            btn.Visible = true
            btn.Position = UDim2.new(0, 6, 0, btnYPositions[i] or (6 + (i - 1) * 40))
            btn.Size = UDim2.new(0, 32, 0, 32)
        end
    end
    if n > 0 then
        local targetH = (btnYPositions[n] or (6 + (n - 1) * 40)) + 38
        navBg.Size = UDim2.new(0, 44, 0, targetH)
    end
    if currentPage and navButtons[currentPage] then
        navIndicator.Position = getIndicatorCenterPos(navButtons[currentPage])
        navIndicator.Size = UDim2.new(0, 32, 0, 32)
        updateCornerRadius(navIndicator, 16)
    end
end

function updateCustomButtonPositions(animate, skipNavBgSize)
    for _, btn in pairs(navButtons) do
        btn.Visible = false
    end
    local n = #customTabOrder
    local btnSize = customTabMode and 40 or 32
    local btnOffset = customTabMode and 14 or 6
    local spacing = customTabMode and 60 or 40
    for i, name in ipairs(customTabOrder) do
        local btn = navButtons[name]
        if btn then
            btn.Visible = true
            
            if not (isDraggingTab and draggedTabBtn == btn) then
                local targetY = btnOffset + (i - 1) * spacing
                if animate then
                    svc.TweenService:Create(btn, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        Position = UDim2.new(0, btnOffset, 0, targetY),
                        Size = UDim2.new(0, btnSize, 0, btnSize)
                    }):Play()
                else
                    btn.Position = UDim2.new(0, btnOffset, 0, targetY)
                    btn.Size = UDim2.new(0, btnSize, 0, btnSize)
                end
            end
        end
    end
    if customTabMode and n > 0 and not skipNavBgSize then
        
        local targetH = (n - 1) * spacing + btnSize + btnOffset * 2
        if animate then
            cancelNavBgTween()
            navBgTween = svc.TweenService:Create(navBg, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, navBg.Size.X.Offset, 0, targetH)
            })
            navBgTween:Play()
        else
            navBg.Size = UDim2.new(0, navBg.Size.X.Offset, 0, targetH)
        end
    end

    if customTabMode and currentPage and navButtons[currentPage] then
        local btnIdx = table.find(customTabOrder, currentPage) or 1
        local targetY = btnOffset + (btnIdx - 1) * spacing
        
        local targetBtn = navButtons[currentPage]
        local savedBtnPos = targetBtn.Position
        local savedBtnSize = targetBtn.Size
        targetBtn.Position = UDim2.new(0, btnOffset, 0, targetY)
        targetBtn.Size = UDim2.new(0, btnSize, 0, btnSize)
        local targetPos = getIndicatorCenterPos(targetBtn)
        targetBtn.Position = savedBtnPos
        targetBtn.Size = savedBtnSize
        if animate then
            svc.TweenService:Create(navIndicator, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, btnSize, 0, btnSize),
                Position = targetPos
            }):Play()
        else
            navIndicator.Size = UDim2.new(0, btnSize, 0, btnSize)
            navIndicator.Position = targetPos
        end
        
        updateCornerRadius(navIndicator, btnSize / 2)
    end
end

function onTabDragInputChanged(input)
    if not isDraggingTab or not draggedTabBtn then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local mousePos = Vector2.new(input.Position.X, input.Position.Y)
    local navBgPos = navBg.AbsolutePosition
    local btnSize = customTabMode and 40 or 32
    local btnOffset = customTabMode and 14 or 6
    local spacing = customTabMode and 60 or 40
    
    local relY = mousePos.Y - navBgPos.Y - dragOffsetY
    relY = math.clamp(relY, 0, math.max(0, navBg.AbsoluteSize.Y - btnSize))
    draggedTabBtn.Position = UDim2.new(0, btnOffset, 0, relY)
    local centerY = relY + btnSize / 2
    local newIndex = math.floor(centerY / spacing) + 1
    newIndex = math.clamp(newIndex, 1, #customTabOrder)
    local oldIndex = table.find(customTabOrder, draggedTabName)
    if oldIndex and oldIndex ~= newIndex then
        table.remove(customTabOrder, oldIndex)
        table.insert(customTabOrder, newIndex, draggedTabName)
        updateCustomButtonPositions(true)
    end
end

function endTabDrag()
    if not isDraggingTab then return end
    isDraggingTab = false
    for _, conn in ipairs(tabDragConnections) do
        conn:Disconnect()
    end
    tabDragConnections = {}
    if draggedTabBtn then
        draggedTabBtn.ZIndex = 15
        draggedTabBtn.Active = true
    end
    for _, name in ipairs(navNames) do
        local btn = navButtons[name]
        if btn then
            btn.Active = true
        end
    end
    updateCustomButtonPositions(true)
    saveTabOrder()
    draggedTabBtn = nil
    draggedTabName = nil
end

function beginTabDrag(btn, name)
    if isDraggingTab then return end
    isDraggingTab = true
    draggedTabBtn = btn
    draggedTabName = name
    btn.ZIndex = 100
    btn.Active = false
    local mousePos = svc.UserInputService:GetMouseLocation()
    local btnAbsPos = btn.AbsolutePosition
    dragOffsetX = mousePos.X - btnAbsPos.X
    dragOffsetY = mousePos.Y - btnAbsPos.Y
    for _, otherName in ipairs(navNames) do
        if otherName ~= name then
            local otherBtn = navButtons[otherName]
            if otherBtn then
                otherBtn.Active = false
            end
        end
    end
    table.insert(tabDragConnections, svc.UserInputService.InputChanged:Connect(onTabDragInputChanged))
    table.insert(tabDragConnections, svc.UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            endTabDrag()
        end
    end))
end

function createCustomItemsPanel()
    if customItemsPanel and customItemsPanel.Parent then return end
    local cam = workspace.CurrentCamera
    local screenSize = cam and cam.ViewportSize or Vector2.new(1920, 1080)
    local panelW = 260
    local panelH = 320
    local startX = deepCustomLayoutEnabled and (-panelW - 10) or (screenSize.X + 10)
    local targetX = deepCustomLayoutEnabled and 20 or (screenSize.X - panelW - 20)
    local targetY = math.floor((screenSize.Y - panelH) / 2)

    customItemsPanel = create("Frame", {
        Position = UDim2.new(0, startX, 0, targetY),
        Size = UDim2.new(0, panelW, 0, panelH),
        BackgroundColor3 = theme.surface,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        ZIndex = 1000,
        Active = true,
        ClipsDescendants = true,
        Name = "CustomItemsPanel"
    })
    corner(16, customItemsPanel)
    stroke(theme.border, 1, customItemsPanel)
    customItemsPanel.Parent = screenGui

    local panelTitle = create("TextLabel", {
        Position = UDim2.new(0, 16, 0, 12),
        Size = UDim2.new(1, -32, 0, 24),
        BackgroundTransparency = 1,
        Text = t("customize_items"),
        TextColor3 = theme.text,
        TextSize = 16,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 1001
    })
    panelTitle.Parent = customItemsPanel

    local closeBtn = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 12),
        Size = UDim2.new(0, 24, 0, 24),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 1002
    })
    local closeIcon = GetIcon("x", UDim2.new(0, 16, 0, 16), theme.textDim)
    if closeIcon then
        closeIcon.Position = UDim2.new(0.5, -8, 0.5, -8)
        closeIcon.Parent = closeBtn
    end
    closeBtn.Parent = customItemsPanel
    closeBtn.MouseButton1Click:Connect(function()
        exitCustomTabMode()
    end)

    local divider = create("Frame", {
        Position = UDim2.new(0, 12, 0, 44),
        Size = UDim2.new(1, -24, 0, 1),
        BackgroundColor3 = theme.border,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        ZIndex = 1001
    })
    divider.Parent = customItemsPanel

    customItemsScroll = create("ScrollingFrame", {
        Position = UDim2.new(0, 8, 0, 52),
        Size = UDim2.new(1, -16, 1, -60),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = theme.textDim,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ZIndex = 1001,
        ClipsDescendants = true
    })
    customItemsScroll.Parent = customItemsPanel

    local listLayout = create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        VerticalAlignment = Enum.VerticalAlignment.Top,
        HorizontalAlignment = Enum.HorizontalAlignment.Center
    })
    listLayout.Parent = customItemsScroll
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if customItemsScroll and customItemsScroll.Parent then
            customItemsScroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 12)
        end
    end)

    refreshCustomItemsList()
end

function refreshCustomItemsList()
    if not customItemsScroll or not customItemsScroll.Parent then return end
    for _, child in pairs(customItemsScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    customItemsRows = {}
    customDeleteOpenRow = nil

    for i, name in ipairs(customTabOrder) do
        local row = createCustomItemRow(name, i, false)
        if row then
            row.Parent = customItemsScroll
            table.insert(customItemsRows, row)
        end
    end

    local disabledCount = 0
    for _, name in ipairs(allNavItems) do
        if not table.find(customTabOrder, name) then
            disabledCount = disabledCount + 1
            local row = createCustomItemRow(name, #customTabOrder + disabledCount, true)
            if row then
                row.BackgroundColor3 = theme.surface
                row.BackgroundTransparency = 0.5
                row.Parent = customItemsScroll
                table.insert(customItemsRows, row)
            end
        end
    end
end

function createCustomItemRow(name, order, isDisabled)
    local isProtected = protectedTabs[name] == true
    local iconName = isProtected and "shield-minus" or (isDisabled and "circle-plus" or "circle-minus")
    local rowH = 44
    local row = create("Frame", {
        Size = UDim2.new(1, -8, 0, rowH),
        BackgroundColor3 = isDisabled and theme.surface or theme.surfaceLight,
        BackgroundTransparency = isDisabled and 0.5 or 0.4,
        BorderSizePixel = 0,
        LayoutOrder = order,
        ZIndex = 1002,
        Active = true,
        Name = "Row_" .. name
    })
    corner(10, row)

    local icon = GetIcon(iconName, UDim2.new(0, 18, 0, 18), isProtected and theme.warn or (isDisabled and theme.accent or theme.red))
    if icon then
        icon.Position = UDim2.new(0, 10, 0.5, -9)
        icon.Parent = row
        icon.Name = "TypeIcon"
    end

    local displayName = tabNameMap[name] or name
    local nameLabel = create("TextLabel", {
        Position = UDim2.new(0, 36, 0, 0),
        Size = UDim2.new(1, -80, 1, 0),
        BackgroundTransparency = 1,
        Text = displayName,
        TextColor3 = theme.text,
        TextSize = 13,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 1003
    })
    nameLabel.Parent = row

    local menuIcon = nil
    if not isDisabled then
        menuIcon = GetIcon("menu", UDim2.new(0, 16, 0, 16), theme.textDim)
        if menuIcon then
            menuIcon.Position = UDim2.new(1, -26, 0.5, -8)
            menuIcon.Parent = row
            menuIcon.Name = "MenuIcon"
        end
    end

    if not isProtected then
        local actionBtn = create("TextButton", {
            Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = isDisabled and Color3.fromRGB(59, 130, 246) or theme.red,
            BackgroundTransparency = 0.25,
            BorderSizePixel = 0,
            Text = "",
            ZIndex = 1005,
            Visible = true,
            Name = "ActionBtn"
        })
        corner(10, actionBtn)
        local actionText = create("TextLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = isDisabled and t("add") or t("delete"),
            TextColor3 = Color3.fromRGB(255,255,255),
            TextSize = 12,
            Font = Enum.Font.SourceSansBold,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextTransparency = 1, ZIndex = 1006
        })
        actionText.Parent = actionBtn
        actionBtn.Parent = row

        if isDisabled then

            if icon then
                local iconHit = create("TextButton", {
                    Position = UDim2.new(0, 4, 0, 4),
                    Size = UDim2.new(0, 30, 0, 30),
                    BackgroundTransparency = 1,
                    Text = "",
                    ZIndex = 1007
                })
                iconHit.Parent = row
                iconHit.MouseButton1Click:Connect(function()
                    table.insert(customTabOrder, name)
                    saveTabOrder()
                    refreshCustomItemsList()
                    updateCustomButtonPositions(true)
                end)
            end
        else

            if icon then
                local iconHit = create("TextButton", {
                    Position = UDim2.new(0, 4, 0, 4),
                    Size = UDim2.new(0, 30, 0, 30),
                    BackgroundTransparency = 1,
                    Text = "",
                    ZIndex = 1007
                })
                iconHit.Parent = row
                iconHit.MouseButton1Click:Connect(function()
                    if customDeleteOpenRow and customDeleteOpenRow ~= row then
                        local oldAction = customDeleteOpenRow:FindFirstChild("ActionBtn")
                        if oldAction then
                            svc.TweenService:Create(oldAction, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                Size = UDim2.new(0, 0, 1, 0),
                                Position = UDim2.new(1, 0, 0, 0)
                            }):Play()
                        end
                        local oldMenu = customDeleteOpenRow:FindFirstChild("MenuIcon")
                        if oldMenu then
                            svc.TweenService:Create(oldMenu, TweenInfo.new(0.2), {ImageTransparency = 0}):Play()
                        end
                        customDeleteOpenRow = nil
                    end
                    local actionBtn = row:FindFirstChild("ActionBtn")
                    if actionBtn then
                        if customDeleteOpenRow == row then
                            svc.TweenService:Create(actionBtn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                Size = UDim2.new(0, 0, 1, 0),
                                Position = UDim2.new(1, 0, 0, 0)
                            }):Play()
                        svc.TweenService:Create(actionText, TweenInfo.new(0.15), {TextTransparency = 1}):Play()
                            if menuIcon then
                                svc.TweenService:Create(menuIcon, TweenInfo.new(0.2), {ImageTransparency = 0}):Play()
                            end
                            customDeleteOpenRow = nil
                        else
                            svc.TweenService:Create(actionBtn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                                Size = UDim2.new(0, 70, 1, 0),
                                Position = UDim2.new(1, -70, 0, 0)
                            }):Play()
                            svc.TweenService:Create(actionText, TweenInfo.new(0.15), {TextTransparency = 0}):Play()
                            if menuIcon then
                                svc.TweenService:Create(menuIcon, TweenInfo.new(0.2), {ImageTransparency = 1}):Play()
                            end
                            customDeleteOpenRow = row
                        end
                    end
                end)
            end

            actionBtn.MouseButton1Click:Connect(function()
                local idx = table.find(customTabOrder, name)
                if idx then
                    table.remove(customTabOrder, idx)
                end
                saveTabOrder()
                customDeleteOpenRow = nil
                refreshCustomItemsList()
                updateCustomButtonPositions(true)
            end)
        end
    end

    if not isDisabled and menuIcon then
        local dragHoldToken = 0
        menuIcon.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                if customListDragging then return end
                if customDeleteOpenRow then
                    local oldAction = customDeleteOpenRow:FindFirstChild("ActionBtn")
                    if oldAction then
                        svc.TweenService:Create(oldAction, TweenInfo.new(0.2), {Size = UDim2.new(0, 0, 1, 0), Position = UDim2.new(1, 0, 0, 0)}):Play()
                    end
                    local oldMenu = customDeleteOpenRow:FindFirstChild("MenuIcon")
                    if oldMenu then
                        svc.TweenService:Create(oldMenu, TweenInfo.new(0.2), {ImageTransparency = 0}):Play()
                    end
                    customDeleteOpenRow = nil
                end
                dragHoldToken = dragHoldToken + 1
                local currentToken = dragHoldToken
                customListDragStartY = input.Position.Y
                customListDragOffsetY = input.Position.Y - row.AbsolutePosition.Y
                task.spawn(function()
                    task.wait(0.25)
                    if currentToken ~= dragHoldToken then return end
                    if customListDragging then return end
                    if math.abs(input.Position.Y - customListDragStartY) < 5 then
                        beginListDrag(row, name)
                    end
                end)
            end
        end)
        menuIcon.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragHoldToken = dragHoldToken + 1
            end
        end)
    end

    return row
end

function beginListDrag(row, name)
    if customListDragging then return end
    customListDragging = true
    customListDragRow = row
    customListDragName = name
    row.ZIndex = 1010

    if customItemsScroll then
        customItemsScroll.ScrollingEnabled = false
    end

    customListLayout = customItemsScroll:FindFirstChildOfClass("UIListLayout")
    if customListLayout then
        customListLayout.Parent = nil
    end

    local scrollAbsY = customItemsScroll.AbsolutePosition.Y
    for _, r in ipairs(customItemsRows) do
        if r ~= row then
            local absY = r.AbsolutePosition.Y - scrollAbsY
            r.Position = UDim2.new(0, 4, 0, absY)
        end
    end

    local rowHeight = 50

    for _, otherRow in ipairs(customItemsRows) do
        if otherRow ~= row then
            otherRow.Active = false
        end
    end

    table.insert(customListDragConnections, svc.UserInputService.InputChanged:Connect(function(input)
        if not customListDragging or not customListDragRow then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end

        local mouseY = input.Position.Y
        local scrollPos = customItemsScroll.AbsolutePosition.Y
        local scrollH = customItemsScroll.AbsoluteSize.Y
        local relY = mouseY - scrollPos - customListDragOffsetY
        relY = math.clamp(relY, 0, math.max(0, scrollH - row.AbsoluteSize.Y))
        row.Position = UDim2.new(0, 4, 0, relY)

        local centerY = relY + row.AbsoluteSize.Y / 2
        local slotH = rowHeight
        local newIndex = math.floor(centerY / slotH) + 1
        newIndex = math.clamp(newIndex, 1, #customTabOrder)
        local oldIndex = table.find(customTabOrder, name)
        if oldIndex and oldIndex ~= newIndex then
            table.remove(customTabOrder, oldIndex)
            table.insert(customTabOrder, newIndex, name)
            for i, r in ipairs(customItemsRows) do
                if r ~= row then
                    local targetOrder = table.find(customTabOrder, r.Name:sub(5)) or i
                    local targetY = (targetOrder - 1) * slotH
                    if targetY ~= r.Position.Y.Offset then
                        svc.TweenService:Create(r, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                            Position = UDim2.new(0, 4, 0, targetY)
                        }):Play()
                    end
                end
            end
            updateCustomButtonPositions(true)
        end
    end))

    table.insert(customListDragConnections, svc.UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            endListDrag()
        end
    end))
end

function endListDrag()
    if not customListDragging then return end
    customListDragging = false
    for _, conn in ipairs(customListDragConnections) do
        conn:Disconnect()
    end
    customListDragConnections = {}

    if customListDragRow then
        customListDragRow.ZIndex = 1002
        customListDragRow = nil
    end

    if customItemsScroll then
        customItemsScroll.ScrollingEnabled = true
    end

    for _, otherRow in ipairs(customItemsRows) do
        otherRow.Active = true
    end

    if customItemsScroll and customListLayout then
        customListLayout.Parent = customItemsScroll
        customListLayout = nil
    end

    refreshCustomItemsList()
    saveTabOrder()
    customListDragName = nil
end

function getAllIconNames()
    if customIconAllNames then return customIconAllNames end
    local lucide = LoadLucide()
    if not lucide or not lucide.IconNames then return {} end
    customIconAllNames = lucide.IconNames
    return customIconAllNames
end

function getIconUrlCached(iconName)
    if iconUrlCache[iconName] then return iconUrlCache[iconName] end
    local lucide = LoadLucide()
    if not lucide then return nil end
    local ok, asset = pcall(lucide.GetAsset, iconName)
    if ok and asset and asset.Url then
        iconUrlCache[iconName] = asset.Url
        return asset.Url
    end
    return nil
end

function populateIconGrid(filterText)
    customIconLoadToken = customIconLoadToken + 1
    local myToken = customIconLoadToken

    if not customIconScroll or not customIconScroll.Parent then return end

    for _, child in pairs(customIconScroll:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end

    local allNames = getAllIconNames()
    local filtered = {}
    local ft = filterText and string.lower(filterText) or ""
    local i, j = 1, #ft
                while i <= j and string.byte(ft:sub(i,i)) <= 32 do i = i + 1 end
                while j >= i and string.byte(ft:sub(j,j)) <= 32 do j = j - 1 end
                ft = ft:sub(i, j)
    if ft == "" then
        for i, name in ipairs(allNames) do filtered[i] = name end
    else
        for _, name in ipairs(allNames) do
            if string.find(string.lower(name), ft, 1, true) then
                table.insert(filtered, name)
            end
        end
    end

    local currentTabIcon = tabIconMap[customIconPanelTab] or customIconPanelTab

    task.spawn(function()
        local batchSize = 80
        for i = 1, #filtered, batchSize do
            if myToken ~= customIconLoadToken then return end
            if not customIconScroll or not customIconScroll.Parent then return end

            local batchEnd = math.min(i + batchSize - 1, #filtered)
            for j = i, batchEnd do
                local name = filtered[j]
                local isSelected = (name == currentTabIcon)

                local cell = create("TextButton", {
                    Size = UDim2.new(0, 62, 0, 72),
                    BackgroundColor3 = isSelected and theme.green or theme.surface,
                    BackgroundTransparency = isSelected and 0.5 or 0.3,
                    BorderSizePixel = 0,
                    Text = "",
                    LayoutOrder = j,
                    ZIndex = 1001,
                    AutoButtonColor = true
                })
                cell:SetAttribute("iconName", name)
                cell:SetAttribute("iconLoaded", false)

                local nameLabel = create("TextLabel", {
                    Position = UDim2.new(0, 2, 1, -22),
                    Size = UDim2.new(1, -4, 0, 18),
                    BackgroundTransparency = 1,
                    Text = name,
                    TextColor3 = isSelected and theme.text or theme.textDim,
                    TextSize = 9,
                    Font = Enum.Font.SourceSans,
                    TextXAlignment = Enum.TextXAlignment.Center,
                    TextYAlignment = Enum.TextYAlignment.Top,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 1002
                })
                nameLabel.Parent = cell
                cell.Parent = customIconScroll

                if isSelected then customIconSelectedCell = cell end

                cell.MouseButton1Click:Connect(function()
                    if customIconPanelTab and customIconPanelTab ~= "house" and customIconPanelTab ~= "settings" then
                        if customIconSelectedCell then
                            customIconSelectedCell.BackgroundColor3 = theme.surface
                            customIconSelectedCell.BackgroundTransparency = 0.3
                            local oldLabel = customIconSelectedCell:FindFirstChildOfClass("TextLabel")
                            if oldLabel then oldLabel.TextColor3 = theme.textDim end
                        end
                        cell.BackgroundColor3 = theme.green
                        cell.BackgroundTransparency = 0.5
                        nameLabel.TextColor3 = theme.text
                        customIconSelectedCell = cell

                        applyTabIcon(customIconPanelTab, name)
                    end
                end)
            end
            task.wait()
        end

        if myToken ~= customIconLoadToken then return end
        loadIconsForVisibleCells(myToken)
        if customIconScroll and customIconScroll.Parent then
            local scrollConn
            scrollConn = customIconScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
                if myToken ~= customIconLoadToken then
                    scrollConn:Disconnect()
                    return
                end
                loadIconsForVisibleCells(myToken)
            end)
        end
    end)
end

function loadIconsForVisibleCells(myToken)
    if not customIconScroll or not customIconScroll.Parent then return end
    local scrollPos = customIconScroll.CanvasPosition
    local viewportY = scrollPos.Y
    local viewportH = customIconScroll.AbsoluteSize.Y
    local cellH = 72 + 4
    local cellW = 62 + 4
    local gridW = customIconScroll.AbsoluteSize.X
    local cols = math.max(1, math.floor((gridW + 4) / cellW))

    local startRow = math.max(1, math.floor(viewportY / cellH) - 1)
    local endRow = math.ceil((viewportY + viewportH) / cellH) + 1

    task.spawn(function()
        for _, child in pairs(customIconScroll:GetChildren()) do
            if myToken ~= customIconLoadToken then return end
            if child:IsA("TextButton") and child:GetAttribute("iconLoaded") ~= true then
                local order = child.LayoutOrder
                local row = math.ceil(order / cols)
                if row >= startRow and row <= endRow then
                    local iconName = child:GetAttribute("iconName")
                    if iconName then
                        local url = getIconUrlCached(iconName)
                        if url then
                            local iconImg = create("ImageLabel", {
                                Position = UDim2.new(0.5, -14, 0, 6),
                                Size = UDim2.new(0, 28, 0, 28),
                                BackgroundTransparency = 1,
                                Image = url,
                                ImageColor3 = theme.text,
                                ScaleType = Enum.ScaleType.Fit,
                                ZIndex = 1002
                            })
                            iconImg.Parent = child
                            child:SetAttribute("iconLoaded", true)
                        end
                    end
                end
            end
        end
    end)
end

function createCustomIconPanel(tabName)
    if customIconPanel and customIconPanel.Parent then return end
    local cam = workspace.CurrentCamera
    local screenSize = cam and cam.ViewportSize or Vector2.new(1920, 1080)
    local panelW = 300
    local panelH = math.min(440, screenSize.Y - 80)
    local startX = deepCustomLayoutEnabled and (screenSize.X + 10) or (-panelW - 10)
    local targetY = math.floor((screenSize.Y - panelH) / 2)

    customIconPanel = create("Frame", {
        Position = UDim2.new(0, startX, 0, targetY),
        Size = UDim2.new(0, panelW, 0, panelH),
        BackgroundColor3 = theme.surface,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        ZIndex = 1000,
        Active = true,
        ClipsDescendants = true,
        Name = "CustomIconPanel"
    })
    corner(16, customIconPanel)
    stroke(theme.border, 1, customIconPanel)
    customIconPanel.Parent = screenGui

    local panelTitle = create("TextLabel", {
        Position = UDim2.new(0, 16, 0, 12),
        Size = UDim2.new(1, -48, 0, 24),
        BackgroundTransparency = 1,
        Text = t("customize_icon"),
        TextColor3 = theme.text,
        TextSize = 16,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 1001
    })
    panelTitle.Parent = customIconPanel

    local closeBtn = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 12),
        Size = UDim2.new(0, 24, 0, 24),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 1002
    })
    local closeIcon = GetIcon("x", UDim2.new(0, 16, 0, 16), theme.textDim)
    if closeIcon then
        closeIcon.Position = UDim2.new(0.5, -8, 0.5, -8)
        closeIcon.Parent = closeBtn
    end
    closeBtn.Parent = customIconPanel
    closeBtn.MouseButton1Click:Connect(function()
        closeCustomIconPanel()
    end)

    customIconSearchBox = create("Frame", {
        Position = UDim2.new(0, 12, 0, 44),
        Size = UDim2.new(1, -24, 0, 32),
        BackgroundColor3 = theme.surface,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        ZIndex = 1001
    })
    corner(8, customIconSearchBox)
    customIconSearchBox.Parent = customIconPanel

    local searchIcon = GetIcon("search", UDim2.new(0, 14, 0, 14), theme.textDim)
    if searchIcon then
        searchIcon.Position = UDim2.new(0, 8, 0.5, -7)
        searchIcon.ZIndex = 1002
        searchIcon.Parent = customIconSearchBox
    end

    customIconSearchInput = create("TextBox", {
        Position = UDim2.new(0, 28, 0, 0),
        Size = UDim2.new(1, -36, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = t("search_icons"),
        PlaceholderColor3 = theme.textDim,
        TextColor3 = theme.text,
        TextSize = 12,
        Font = Enum.Font.SourceSans,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ClearTextOnFocus = false,
        ZIndex = 1002
    })
    customIconSearchInput.Parent = customIconSearchBox

    local searchDebounce = nil
    customIconSearchInput:GetPropertyChangedSignal("Text"):Connect(function()
        if searchDebounce then task.cancel(searchDebounce) end
        searchDebounce = task.delay(0.2, function()
            if customIconSearchInput and customIconSearchInput.Parent then
                populateIconGrid(customIconSearchInput.Text)
            end
        end)
    end)

    local divider = create("Frame", {
        Position = UDim2.new(0, 12, 0, 82),
        Size = UDim2.new(1, -24, 0, 1),
        BackgroundColor3 = theme.border,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        ZIndex = 1001
    })
    divider.Parent = customIconPanel

    customIconScroll = create("ScrollingFrame", {
        Position = UDim2.new(0, 8, 0, 90),
        Size = UDim2.new(1, -16, 1, -98),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = theme.textDim,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ZIndex = 1001,
        ClipsDescendants = true
    })
    customIconScroll.Parent = customIconPanel

    customIconGridLayout = create("UIGridLayout", {
        CellSize = UDim2.new(0, 62, 0, 72),
        CellPadding = UDim2.new(0, 4, 0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        FillDirection = Enum.FillDirection.Horizontal
    })
    customIconGridLayout.Parent = customIconScroll

    customIconGridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if customIconScroll and customIconScroll.Parent then
            customIconScroll.CanvasSize = UDim2.new(0, 0, 0, customIconGridLayout.AbsoluteContentSize.Y + 12)
        end
    end)

    populateIconGrid("")
end

function highlightNavBtnGreen(btn)
    if customIconHighlightedBtn and customIconHighlightedBtn ~= btn then
        pcall(function()
            local oldIcon = customIconHighlightedBtn:FindFirstChildOfClass("ImageLabel")
            if oldIcon then
                oldIcon.ImageColor3 = customIconHighlightedOriginalColor or Color3.fromRGB(255, 255, 255)
            end
        end)
    end
    if btn then
        local icon = btn:FindFirstChildOfClass("ImageLabel")
        if icon then
            customIconHighlightedOriginalColor = icon.ImageColor3
            icon.ImageColor3 = theme.green
        end
        customIconHighlightedBtn = btn
    end
end

function unhighlightNavBtnGreen()
    if customIconHighlightedBtn then
        pcall(function()
            local icon = customIconHighlightedBtn:FindFirstChildOfClass("ImageLabel")
            if icon then
                icon.ImageColor3 = customIconHighlightedOriginalColor or Color3.fromRGB(255, 255, 255)
            end
        end)
        customIconHighlightedBtn = nil
        customIconHighlightedOriginalColor = nil
    end
end

function openCustomIconPanel(tabName)
    if customIconPanelOpen then
        if customIconPanelTab == tabName then return end
        customIconPanelTab = tabName
        customIconSelectedCell = nil
        highlightNavBtnGreen(navButtons[tabName])
        if customIconSearchInput and customIconSearchInput.Parent then
            customIconSearchInput.Text = ""
        end
        populateIconGrid("")
        return
    end
    customIconPanelOpen = true
    customIconPanelTab = tabName

    local cam = workspace.CurrentCamera
    local screenSize = cam and cam.ViewportSize or Vector2.new(1920, 1080)

    createCustomIconPanel(tabName)

    if customItemsPanel and customItemsPanel.Parent then
        svc.TweenService:Create(customItemsPanel, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Position = UDim2.new(0, screenSize.X + 10, 0, customItemsPanel.Position.Y.Offset)
        }):Play()
    end

    if navBg and navBg.Parent then
        customIconNavBgSavedPos = navBg.Position
        customIconNavBgSavedSize = navBg.Size

        local navW = navBg.Size.X.Offset
        
        local targetX = deepCustomLayoutEnabled and (20 + navW) or (screenSize.X - navW - 20)

        task.delay(0.15, function()
            if navBg and navBg.Parent then
                cancelNavBgTween()
                navBgTween = svc.TweenService:Create(navBg, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {
                    Position = UDim2.new(0, targetX, 0.5, 0)
                })
                navBgTween:Play()
            end
        end)
    end

    highlightNavBtnGreen(navButtons[tabName])

    task.delay(0.2, function()
        if customIconPanel and customIconPanel.Parent then
            local targetX = deepCustomLayoutEnabled and (screenSize.X - 300 - 20) or 20
            svc.TweenService:Create(customIconPanel, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, targetX, 0, customIconPanel.Position.Y.Offset)
            }):Play()
        end
    end)
end

function closeCustomIconPanel()
    if not customIconPanelOpen then return end
    customIconPanelOpen = false
    customIconLoadToken = customIconLoadToken + 1

    local cam = workspace.CurrentCamera
    local screenSize = cam and cam.ViewportSize or Vector2.new(1920, 1080)

    unhighlightNavBtnGreen()

    if navBg and navBg.Parent and customIconNavBgSavedPos then
        cancelNavBgTween()
        navBgTween = svc.TweenService:Create(navBg, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Position = customIconNavBgSavedPos
        })
        navBgTween:Play()
        customIconNavBgSavedPos = nil
        customIconNavBgSavedSize = nil
    end

    if customIconPanel and customIconPanel.Parent then
        local panelW = 300
        svc.TweenService:Create(customIconPanel, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Position = deepCustomLayoutEnabled and UDim2.new(0, screenSize.X + 10, 0, customIconPanel.Position.Y.Offset) or UDim2.new(0, -panelW - 10, 0, customIconPanel.Position.Y.Offset)
        }):Play()
        task.delay(0.35, function()
            if customIconPanel then
                customIconPanel:Destroy()
                customIconPanel = nil
            end
        end)
    end

    if customItemsPanel and customItemsPanel.Parent then
        local panelW = 260
            local targetX = deepCustomLayoutEnabled and 20 or (screenSize.X - panelW - 20)
        task.delay(0.2, function()
            if customItemsPanel and customItemsPanel.Parent then
                svc.TweenService:Create(customItemsPanel, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Position = UDim2.new(0, targetX, 0, customItemsPanel.Position.Y.Offset)
                }):Play()
            end
        end)
    end

    customIconPanelTab = nil
    customIconSearchBox = nil
    customIconSearchInput = nil
    customIconScroll = nil
    customIconGridLayout = nil
    customIconSelectedCell = nil
end

function setupTabDragHandlers()
    for _, name in ipairs(navNames) do
        local btn = navButtons[name]
        if btn then
            btn.MouseButton1Down:Connect(function()
                if not customTabMode then return end
                if isDraggingTab then return end
                local thisHold = {}
                activeTabHold = thisHold
                task.spawn(function()
                    task.wait(0.3)
                    if activeTabHold == thisHold and customTabMode and not isDraggingTab then
                        beginTabDrag(btn, name)
                    end
                end)
            end)
            btn.MouseButton1Up:Connect(function()
                local wasDragging = isDraggingTab
                activeTabHold = nil
                if wasDragging then
                    endTabDrag()
                elseif customTabMode and not isDraggingTab then
                    openCustomIconPanel(name)
                end
            end)
        end
    end
end

function collectFadeableElements()
    fadeableElements = {}
    local function add(obj, prop)
        if obj and obj.Parent then
            table.insert(fadeableElements, {obj = obj, prop = prop, orig = obj[prop]})
        end
    end
    local function addRecursive(container)
        if not container then return end
        for _, child in pairs(container:GetChildren()) do
            if child:IsA("GuiObject") and child ~= navBg and child ~= navContainer then
                if child:IsA("Frame") or child:IsA("ScrollingFrame") then
                    if child.BackgroundTransparency < 1 then
                        add(child, "BackgroundTransparency")
                    end
                elseif child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
                    if child.TextTransparency < 1 then
                        add(child, "TextTransparency")
                    end
                    if child.BackgroundTransparency < 1 then
                        add(child, "BackgroundTransparency")
                    end
                elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
                    if child.ImageTransparency < 1 then
                        add(child, "ImageTransparency")
                    end
                    if child.BackgroundTransparency < 1 then
                        add(child, "BackgroundTransparency")
                    end
                end
                addRecursive(child)
            elseif child:IsA("UIStroke") then
                if child.Transparency < 1 then
                    add(child, "Transparency")
                end
            end
        end
    end
    addRecursive(main)
    addRecursive(topBar)
    for _, pill in ipairs({pingPill, fpsPill, timePill, labelPill}) do
        add(pill, "BackgroundTransparency")
        
        for _, pillChild in pairs(pill:GetChildren()) do
            if pillChild:IsA("UIStroke") and pillChild.Transparency < 1 then
                add(pillChild, "Transparency")
            end
        end
    end
end

function fadeOutUI(duration)
    if #fadeableElements == 0 then collectFadeableElements() end
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    for _, entry in ipairs(fadeableElements) do
        if entry.obj and entry.obj.Parent then
            entry.obj[entry.prop] = entry.orig
            svc.TweenService:Create(entry.obj, tweenInfo, {
                [entry.prop] = 1
            }):Play()
        end
    end
end

function fadeInUI(duration)
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    for _, entry in ipairs(fadeableElements) do
        if entry.obj and entry.obj.Parent then
            svc.TweenService:Create(entry.obj, tweenInfo, {
                [entry.prop] = entry.orig
            }):Play()
        end
    end
end

function enterCustomTabMode()
    if customTabMode then return end
    customTabMode = true
    if #fadeableElements == 0 then collectFadeableElements() end
    fadeOutUI(0.3)
    task.delay(0.3, function()
        wrapperFrame.Visible = false
        bottomBar.Visible = false
        logoutBtn.Visible = false
        statsRow.Visible = false
    end)
    
    customTabNavBgSavedPos = navBg.Position
    customTabNavBgSavedSize = navBg.Size
    
    local targetX = 120
    local targetW = 68
    local btnSize = 40
    local btnOffset = 14
    local spacing = 60
    
    updateCornerRadius(navBg, targetW / 2)
    cancelNavBgTween()
    navBgTween = svc.TweenService:Create(navBg, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, targetW, 0, navBg.Size.Y.Offset),
        Position = deepCustomLayoutEnabled and UDim2.new(1, -targetX, 0.5, 0) or UDim2.new(0, targetX, 0.5, 0)
    })
    navBgTween:Play()
    
    for _, name in ipairs(navNames) do
        local btn = navButtons[name]
        if btn then
            btn.Size = UDim2.new(0, btnSize, 0, btnSize)
        end
        local icn = navIcons[name]
        if icn then
            local bigIconSize = 24
            icn.Size = UDim2.new(0, bigIconSize, 0, bigIconSize)
            icn.Position = UDim2.new(0.5, -bigIconSize / 2, 0.5, -bigIconSize / 2)
        end
    end
    
    navIndicator.Size = UDim2.new(0, btnSize, 0, btnSize)
    updateCornerRadius(navIndicator, btnSize / 2)
    
    updateCustomButtonPositions(true, true)
    
    task.delay(0.05, function()
        if customTabMode and navBg and navBg.Parent then
            local n = #customTabOrder
            local targetH = (n - 1) * 60 + 40 + 14 * 2
            cancelNavBgTween()
            navBgTween = svc.TweenService:Create(navBg, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, targetW, 0, targetH)
            })
            navBgTween:Play()
        end
    end)
    
    createCustomItemsPanel()
    if customItemsPanel then
        local cam = workspace.CurrentCamera
        local screenSize = cam and cam.ViewportSize or Vector2.new(1920, 1080)
        local panelW = 260
        local targetPanelX = deepCustomLayoutEnabled and 20 or (screenSize.X - panelW - 20)
        svc.TweenService:Create(customItemsPanel, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, targetPanelX, 0, customItemsPanel.Position.Y.Offset)
        }):Play()
    end
end

function exitCustomTabMode()
    if not customTabMode then return end
    customTabMode = false
    
    if customItemsPanel and customItemsPanel.Parent then
        local cam = workspace.CurrentCamera
        local screenSize = cam and cam.ViewportSize or Vector2.new(1920, 1080)
        svc.TweenService:Create(customItemsPanel, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
            Position = deepCustomLayoutEnabled and UDim2.new(0, -270, 0, customItemsPanel.Position.Y.Offset) or UDim2.new(0, screenSize.X + 10, 0, customItemsPanel.Position.Y.Offset)
        }):Play()
    end
    
    if customTabNavBgSavedPos and navBg and navBg.Parent then
        updateCornerRadius(navBg, customTabNavBgSavedSize.X.Offset / 2)
        cancelNavBgTween()
        navBgTween = svc.TweenService:Create(navBg, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = customTabNavBgSavedSize,
            Position = customTabNavBgSavedPos
        })
        navBgTween:Play()
        customTabNavBgSavedPos = nil
        customTabNavBgSavedSize = nil
    end
    
    local smallBtnSize = 32
    local smallIconSize = 18
    local smallOffset = 6
    local smallSpacing = 40
    for _, btn in pairs(navButtons) do
        btn.Visible = false
    end
    for i, name in ipairs(customTabOrder) do
        local btn = navButtons[name]
        if btn then
            btn.Visible = true
            local targetY = smallOffset + (i - 1) * smallSpacing
            svc.TweenService:Create(btn, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, smallBtnSize, 0, smallBtnSize),
                Position = UDim2.new(0, smallOffset, 0, targetY)
            }):Play()
        end
        local icn = navIcons[name]
        if icn then
            svc.TweenService:Create(icn, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, smallIconSize, 0, smallIconSize),
                Position = UDim2.new(0.5, -smallIconSize / 2, 0.5, -smallIconSize / 2)
            }):Play()
        end
    end
    
    local indTargetPos = nil
    if currentPage and navButtons[currentPage] then
        local btnIdx = table.find(customTabOrder, currentPage) or 1
        local targetY = smallOffset + (btnIdx - 1) * smallSpacing
        indTargetPos = UDim2.new(0, smallOffset, 0, targetY)
    end
    svc.TweenService:Create(navIndicator, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, smallBtnSize, 0, smallBtnSize),
        Position = indTargetPos or navIndicator.Position
    }):Play()
    updateCornerRadius(navIndicator, smallBtnSize / 2)
    
    task.delay(0.45, function()
        wrapperFrame.Visible = true
        bottomBar.Visible = true
        logoutBtn.Visible = true
        statsRow.Visible = true
        fadeInUI(0.3)
        applyTabOrder()
        if customItemsPanel then
            customItemsPanel:Destroy()
            customItemsPanel = nil
        end
        customItemsScroll = nil
        customItemsRows = {}
        customDeleteOpenRow = nil
        customListDragging = false
        customListDragRow = nil
        customListDragName = nil
        for _, conn in ipairs(customListDragConnections) do
            conn:Disconnect()
        end
        customListDragConnections = {}
    end)
end

setupTabDragHandlers()

wrapperFrame = create("Frame", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -10, 0, 86),
    Size = UDim2.new(1, -82, 1, -98),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
    ZIndex = 2
})
wrapperFrame.Parent = main
statsRow = create("Frame", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -10, 0, 60),
    Size = UDim2.new(1, -82, 0, 26),
    BackgroundTransparency = 1,
    ZIndex = 5
})
statsRow.Parent = main
do
local function makeStatPill(text, iconName)
    local pill = create("Frame", {Size = UDim2.new(0, 60, 0, 22), BackgroundColor3 = theme.surfaceLight, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 6})
    corner(11, pill)
    stroke(theme.border, 1, pill)
    local icon = GetIcon(iconName, UDim2.new(0, 10, 0, 10), theme.textDim)
    if icon then
        icon.Position = UDim2.new(0, 5, 0.5, -5)
        icon.Parent = pill
    end
    label = create("TextLabel", {Position = UDim2.new(0, 18, 0, 0), Size = UDim2.new(1, -20, 1, 0), BackgroundTransparency = 1, Text = text, TextColor3 = theme.text, TextSize = 10, Font = Enum.Font.SourceSans, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 7})
    label.Parent = pill
    return pill, label
end
leftStats = create("Frame", {Size = UDim2.new(0.5, 0, 1, 0), BackgroundTransparency = 1, ZIndex = 5})
leftStats.Parent = statsRow
leftStatsLayout = create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6)})
leftStatsLayout.Parent = leftStats
pingPill, pingLabel = makeStatPill("34 ms", "wifi")
pingPill.Parent = leftStats
fpsPill, fpsLabel = makeStatPill("59 FPS", "zap")
fpsPill.Parent = leftStats
rightStats = create("Frame", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.5, 0, 1, 0), BackgroundTransparency = 1, ZIndex = 5})
rightStats.Parent = statsRow
rightStatsLayout = create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6)})
rightStatsLayout.Parent = rightStats
timePill = create("Frame", {Size = UDim2.new(0, 70, 0, 22), BackgroundColor3 = theme.surface, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 6, LayoutOrder = 2})
corner(11, timePill)
timeIcon = GetIcon("clock", UDim2.new(0, 10, 0, 10), theme.textDim)
if timeIcon then timeIcon.Position = UDim2.new(0, 5, 0.5, -5); timeIcon.Parent = timePill end
timeLabel = create("TextLabel", {Position = UDim2.new(0, 18, 0, 0), Size = UDim2.new(1, -20, 1, 0), BackgroundTransparency = 1, Text = "12:00 PM", TextColor3 = theme.text, TextSize = 10, Font = Enum.Font.SourceSans, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7})
timeLabel.Parent = timePill
allTimeLabels = {timeLabel}
allPingLabels = {pingLabel}
allFpsLabels = {fpsLabel}

local fpsCounter = 0
local lastFpsUpdate = tick()
svc.RunService.RenderStepped:Connect(function()
    fpsCounter = fpsCounter + 1
    local now = tick()
    if now - lastFpsUpdate >= 1 then
        local fps = math.floor(fpsCounter / (now - lastFpsUpdate))
        for _, label in ipairs(allFpsLabels) do
            if label and label.Parent then
                label.Text = bypassModeActive and "N/A" or (fps .. " FPS")
            end
        end
        fpsCounter = 0
        lastFpsUpdate = now
    end
end)
end

task.spawn(function()
    while true do
        task.wait(5)
        local ok, pingVal = pcall(function()
            return svc.Stats.PerformanceStats.Ping:GetValue()
        end)
        local ping = ok and math.floor(pingVal) or 0
        for _, label in ipairs(allPingLabels) do
            if label and label.Parent then
                label.Text = bypassModeActive and "N/A" or (ping .. " ms")
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        local timeStr = os.date("%I:%M %p")
        for _, label in ipairs(allTimeLabels) do
            if label and label.Parent then
                label.Text = timeStr
            end
        end
    end
end)

timePill.Parent = rightStats
labelPill = create("Frame", {Size = UDim2.new(0, 55, 0, 22), BackgroundColor3 = theme.surface, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 6, LayoutOrder = 1})
corner(11, labelPill)
labelIcon = GetIcon("tag", UDim2.new(0, 10, 0, 10), theme.textDim)
if labelIcon then labelIcon.Position = UDim2.new(0, 5, 0.5, -5); labelIcon.Parent = labelPill end
labelText = create("TextLabel", {Position = UDim2.new(0, 18, 0, 0), Size = UDim2.new(1, -20, 1, 0), BackgroundTransparency = 1, Text = t("Label"), TextColor3 = theme.text, TextSize = 10, Font = Enum.Font.SourceSans, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7})
labelText.Parent = labelPill
labelPill.Parent = rightStats
contentFrame = create("Frame", {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, -4, 1, 0),
    BackgroundColor3 = theme.surface,
    BackgroundTransparency = 0.2,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 2
})
corner(theme.radiusLg, contentFrame)
stroke(theme.border, 1, contentFrame)

create("UIPadding", {
    PaddingTop = UDim.new(0, 8),
    PaddingBottom = UDim.new(0, 8),
    PaddingLeft = UDim.new(0, 10),
    PaddingRight = UDim.new(0, 10),
}).Parent = contentFrame
contentFrame.Parent = wrapperFrame
 settingsPage.Parent = contentFrame

cloudPage.Parent = contentFrame


local scriptbloxScroll = create("ScrollingFrame", {Position = UDim2.new(0, 12, 0, 52), Size = UDim2.new(1, -24, 1, -64), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = theme.textDim, CanvasSize = UDim2.new(0, 0, 0, 0), ClipsDescendants = true, ZIndex = 3})
scriptbloxScroll.Parent = cloudPage
scriptbloxScroll.Visible = true
local scriptbloxGrid = create("UIGridLayout", {CellSize = UDim2.new(0, 335, 0, 160), CellPadding = UDim2.new(0, 10, 0, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Top, FillDirection = Enum.FillDirection.Horizontal})
scriptbloxGrid.Parent = scriptbloxScroll
scriptbloxGrid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    if scriptbloxScroll and scriptbloxGrid and scriptbloxScroll.Parent then
        local absSize = scriptbloxGrid.AbsoluteContentSize
        if absSize then
            scriptbloxScroll.CanvasSize = UDim2.new(0, 0, 0, absSize.Y + 16)
        end
    end
end)

function fetchScriptBloxScripts(searchQuery)
    local HttpService = svc.HttpService
    local base = "https://scriptblox.com/api/script/search"
    local params = "?max=20&sortBy=likeCount&order=desc"
    if searchQuery and searchQuery ~= "" then
        local encoded = searchQuery
        local okEnc, encResult = pcall(function()
            return HttpService:UrlEncode(searchQuery)
        end)
        if okEnc and encResult then
            encoded = encResult
        else
            encoded = ""
            for i = 1, #searchQuery do
                local c = searchQuery:sub(i, i)
                if c == " " then
                    encoded = encoded .. "+"
                else
                    local b = string.byte(c)
                    if (b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or c == "-" or c == "." or c == "_" or c == "~" then
                        encoded = encoded .. c
                    else
                        encoded = encoded .. string.format("%%%02X", b)
                    end
                end
            end
        end
        params = params .. "&q=" .. encoded
    else
        params = params .. "&q=popular"
    end
    local url = base .. params
    local raw = nil
    local ok1, result1 = pcall(function()
        return requestWithUA(url)
    end)
    if ok1 and result1 and result1 ~= "" then
        raw = result1
    else
        local ok2, result2 = pcall(function()
            return game:HttpGet(url)
        end)
        if ok2 and result2 and result2 ~= "" then
            raw = result2
        end
    end
    if not raw or raw == "" then
        return nil
    end
    local ok3, data = pcall(function()
        return HttpService:JSONDecode(raw)
    end)
    if not ok3 or not data or not data.result or not data.result.scripts then
        return nil
    end
    return data.result.scripts
end

function fetchScriptBloxRaw(scriptId)
    local url = "https://scriptblox.com/api/script/raw/" .. tostring(scriptId)
    local raw = nil
    local ok1, result1 = pcall(function()
        return requestWithUA(url)
    end)
    if ok1 and result1 and result1 ~= "" then
        raw = result1
    else
        local ok2, result2 = pcall(function()
            return game:HttpGet(url)
        end)
        if ok2 and result2 and result2 ~= "" then
            raw = result2
        end
    end
    return raw
end

local scriptbloxSelectedScript = nil
local scriptbloxOptionOverlay = create("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.6, BorderSizePixel = 0, Visible = false, ZIndex = 400, Active = true})
scriptbloxOptionOverlay.Parent = screenGui
local scriptbloxOptionCard = create("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 320, 0, 330), BackgroundColor3 = theme.surface, BackgroundTransparency = 0.1, BorderSizePixel = 0, ZIndex = 401, Active = true})
corner(16, scriptbloxOptionCard)
scriptbloxOptionCard.Parent = scriptbloxOptionOverlay

local scriptbloxOptionTitle = create("TextLabel", {Position = UDim2.new(0, 20, 0, 16), Size = UDim2.new(1, -40, 0, 28), BackgroundTransparency = 1, Text = t("select_option"), TextColor3 = theme.text, TextSize = 18, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 402})
scriptbloxOptionTitle.Parent = scriptbloxOptionCard
local scriptbloxOptionSub = create("TextLabel", {Position = UDim2.new(0, 20, 0, 46), Size = UDim2.new(1, -40, 0, 40), BackgroundTransparency = 1, Text = t("select_option_desc"), TextColor3 = theme.textDim, TextSize = 12, Font = Enum.Font.SourceSans, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, ZIndex = 402})
scriptbloxOptionSub.Parent = scriptbloxOptionCard

local scriptbloxOptionClose = create("TextButton", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16), Size = UDim2.new(0, 28, 0, 28), BackgroundTransparency = 1, Text = "", ZIndex = 403})
local scriptbloxCloseIcon = GetIcon("x", UDim2.new(0, 18, 0, 18), theme.textDim)
if scriptbloxCloseIcon then
    scriptbloxCloseIcon.Position = UDim2.new(0.5, -9, 0.5, -9)
    scriptbloxCloseIcon.Parent = scriptbloxOptionClose
end
scriptbloxOptionClose.Parent = scriptbloxOptionCard
scriptbloxOptionClose.MouseButton1Click:Connect(function()
    scriptbloxOptionOverlay.Visible = false
end)

function makeScriptBloxOptionBtn(text, iconName, color, posY, callback)
    local btn = create("TextButton", {Position = UDim2.new(0, 20, 0, posY), Size = UDim2.new(1, -40, 0, 48), BackgroundColor3 = color or theme.surfaceLight, BackgroundTransparency = 0.3, Text = "", BorderSizePixel = 0, ZIndex = 402, Active = true})
    corner(12, btn)
    local icon = GetIcon(iconName, UDim2.new(0, 18, 0, 18), Color3.fromRGB(255,255,255))
    if icon then
        icon.Position = UDim2.new(0, 14, 0.5, -9)
        icon.Parent = btn
    end
    local txt = create("TextLabel", {Position = UDim2.new(0, 42, 0, 0), Size = UDim2.new(1, -50, 1, 0), BackgroundTransparency = 1, Text = text, TextColor3 = Color3.fromRGB(255,255,255), TextSize = 13, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 403})
    txt.Parent = btn
    btn.Parent = scriptbloxOptionCard
    btn.MouseButton1Click:Connect(function()
        if not btn.Active then return end
        btn.Active = false
        scriptbloxOptionOverlay.Visible = false
        task.spawn(function()
            callback()
            btn.Active = true
        end)
    end)
    return btn
end

makeScriptBloxOptionBtn(t("execute_selected"), "play", theme.accent, 85, function()
    if not scriptbloxSelectedScript then return end
    local raw = fetchScriptBloxRaw(scriptbloxSelectedScript._id)
    if raw and raw ~= "" then
        cleanupOldUI()
        AddLog("> Executing ScriptBlox script: " .. scriptbloxSelectedScript.title, "info")
        local fn, err = loadstring(raw)
        if not fn then
            local errLine = parseErrorLine(tostring(err))
            if errLine then
                jumpToErrorLine(errLine)
            end
            AddLog("[Error] " .. tostring(err), "error")
            ShowNotification(t("execution_error_notify"), 3, function()
                switchPage("terminal")
            end)
            return
        end
        local oldPrint = print
        local oldWarn = warn
        print = function(...)
            local args = {...}
            local msg = table.concat(args, " ")
            AddLog(msg, "info")
            if logDedup then logDedup[msg] = tick() end
            _G.__DeltaUI_blockLogService = true
            oldPrint(...)
            _G.__DeltaUI_blockLogService = nil
        end
        warn = function(...)
            local args = {...}
            local msg = table.concat(args, " ")
            AddLog(msg, "warn")
            if logDedup then logDedup[msg] = tick() end
            _G.__DeltaUI_blockLogService = true
            oldWarn(...)
            _G.__DeltaUI_blockLogService = nil
        end
        _G.__DeltaUI_blockLogService = true
        local ok, execErr = xpcall(fn, function(err)
            return debug.traceback(tostring(err), 2)
        end)
        _G.__DeltaUI_blockLogService = nil
        print = oldPrint
        warn = oldWarn
        if not ok then
            AddLog("[Error] " .. tostring(execErr), "error")
        end
        AddLog("> Execution finished", "info")
    else
        ShowNotification(t("fetch_failed"), 2)
    end
end)

makeScriptBloxOptionBtn(t("open_in_editor"), "file-pen", theme.surfaceLight, 143, function()
    if not scriptbloxSelectedScript then return end
    local raw = fetchScriptBloxRaw(scriptbloxSelectedScript._id)
    if raw and raw ~= "" then
        saveCurrentTab()
        local name = "SB: " .. (scriptbloxSelectedScript.title or "Untitled")
        table.insert(tabs, {name = name, content = raw})
        currentTab = #tabs
        currentCodePage = 1
        codePageBreaks = {}
        showCurrentPage()
        renderTabs()
        switchPage("house")
        ShowNotification(t("opened_editor"), 1)
    else
        ShowNotification(t("fetch_failed"), 2)
    end
end)

makeScriptBloxOptionBtn(t("save_selected"), "save", theme.surfaceLight, 201, function()
    if not scriptbloxSelectedScript then return end
    local raw = fetchScriptBloxRaw(scriptbloxSelectedScript._id)
    if raw and raw ~= "" then
        ensureFolder()
        local title = scriptbloxSelectedScript.title or "Untitled"
        writefile(saveFolder .. "/" .. title, raw)
        refreshScriptList(searchInput.Text)
        ShowNotification(t("script_saved"), 1)
    else
        ShowNotification(t("fetch_failed"), 2)
    end
end)

makeScriptBloxOptionBtn(t("copy_to_clipboard"), "clipboard", theme.surfaceLight, 259, function()
    if not scriptbloxSelectedScript then return end
    local raw = fetchScriptBloxRaw(scriptbloxSelectedScript._id)
    if raw and raw ~= "" then
        -- 与对象树复制路径一致的裸标识符同步调用（优先）
        local setclip = setclipboard or toclipboard or (syn and syn.setclipboard) or (clipboard and clipboard.set)
        if type(setclip) == "function" and pcall(setclip, raw) then
            ShowNotification(t("copied"), 1)
            return
        end
        -- 走完整探测流程（含 getgenv / 延迟重试）
        if false then -- codingCopyToClipboard removed
            ShowNotification(t("copied"), 1)
        else
            ShowNotification(t("clipboard_unavailable"), 2)
        end
    else
        ShowNotification(t("fetch_failed"), 2)
    end
end)

scriptbloxOptionOverlay.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local pos = input.Position
        local cardPos = scriptbloxOptionCard.AbsolutePosition
        local cardSize = scriptbloxOptionCard.AbsoluteSize
        if pos.X < cardPos.X or pos.X > cardPos.X + cardSize.X or pos.Y < cardPos.Y or pos.Y > cardPos.Y + cardSize.Y then
            scriptbloxOptionOverlay.Visible = false
        end
    end
end)

function makeScriptBloxCard(scriptData, layoutOrder)
    local card = create("Frame", {Size = UDim2.new(0, 335, 0, 160), BackgroundColor3 = theme.surface, BackgroundTransparency = 0.25, BorderSizePixel = 0, LayoutOrder = layoutOrder, ZIndex = 4})
    corner(12, card)

    local verifiedBadge = nil
    if scriptData.verified then
        verifiedBadge = create("Frame", {Position = UDim2.new(1, -90, 0, 10), Size = UDim2.new(0, 80, 0, 24), BackgroundColor3 = theme.accent, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 6})
        applyGradient(verifiedBadge, theme.accent, theme.accent2, 120)
        corner(12, verifiedBadge)
        local vbText = create("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = t("verified_badge"), TextColor3 = Color3.fromRGB(255,255,255), TextSize = 10, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 7})
        vbText.Parent = verifiedBadge
        verifiedBadge.Parent = card
    end

    local titleLabel = create("TextLabel", {Position = UDim2.new(0, 14, 0, 10), Size = UDim2.new(1, -110, 0, 22), BackgroundTransparency = 1, Text = scriptData.title or "Untitled", TextColor3 = theme.text, TextSize = 15, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5})
    titleLabel.Parent = card

    local gameNameRaw = scriptData.game and scriptData.game.name or "Universal Script"
    local gameName = gameNameRaw
    if string.find(string.lower(tostring(gameNameRaw)), "universal") then gameName = t("universal_script") end
    local gameLabel = create("TextLabel", {Position = UDim2.new(0, 14, 0, 34), Size = UDim2.new(1, -28, 0, 18), BackgroundTransparency = 1, Text = gameName, TextColor3 = theme.textDim, TextSize = 12, Font = Enum.Font.SourceSans, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5})
    gameLabel.Parent = card

    local scriptTypeRaw = scriptData.scriptType or "Script"
    local scriptTypeLower = string.lower(tostring(scriptTypeRaw))
    local scriptType = scriptTypeRaw
    if scriptTypeLower == "free" then scriptType = t("script_type_free")
    elseif scriptTypeLower == "script hub" then scriptType = t("script_type_script_hub")
    elseif scriptTypeLower == "script" then scriptType = t("script_type_script")
    end
    local typeLabel = create("TextLabel", {Position = UDim2.new(0, 14, 0, 54), Size = UDim2.new(1, -28, 0, 18), BackgroundTransparency = 1, Text = scriptType, TextColor3 = theme.accent, TextSize = 11, Font = Enum.Font.SourceSans, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5})
    typeLabel.Parent = card

    local views = scriptData.views or 0
    local viewsLabel = create("TextLabel", {Position = UDim2.new(0, 14, 1, -28), Size = UDim2.new(0, 120, 0, 20), BackgroundTransparency = 1, Text = tostring(views) .. " " .. t("views_label"), TextColor3 = theme.text, TextSize = 13, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5})
    viewsLabel.Parent = card

    local openBtn = create("TextButton", {Position = UDim2.new(1, -90, 1, -32), Size = UDim2.new(0, 80, 0, 28), BackgroundColor3 = theme.accent, BackgroundTransparency = 0.25, Text = "", BorderSizePixel = 0, ZIndex = 5})
    applyGradient(openBtn, theme.accent, theme.accent2, 120)
    corner(8, openBtn)
    local openText = create("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = t("open_btn"), TextColor3 = Color3.fromRGB(255,255,255), TextSize = 11, Font = Enum.Font.SourceSansBold, ZIndex = 6})
    openText.Parent = openBtn
    openBtn.Parent = card
    openBtn.MouseButton1Click:Connect(function()
        scriptbloxSelectedScript = scriptData
        scriptbloxOptionOverlay.Visible = true
    end)

    return card
end

function refreshScriptBloxList(filter)
    if _G.__DeltaUI_refreshScriptBloxLock then return end
    _G.__DeltaUI_refreshScriptBloxLock = true
    filter = filter or ""
        for _, child in pairs(scriptbloxScroll:GetChildren()) do
        if not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end
    local scripts = fetchScriptBloxScripts(filter)
    if not scripts or #scripts == 0 then
        local emptyLabel = create("TextLabel", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Text = t("scriptblox_no_results"), TextColor3 = theme.textDim, TextSize = 14, Font = Enum.Font.SourceSansBold, ZIndex = 4})
        emptyLabel.Parent = scriptbloxScroll
        return
    end
    local validIdx = 0
    for i, scriptData in ipairs(scripts) do
        if scriptData and type(scriptData) == "table" and scriptData.title and tostring(scriptData.title) ~= "" and scriptData._id and tostring(scriptData._id) ~= "" then
            validIdx = validIdx + 1
            local card = makeScriptBloxCard(scriptData, validIdx)
            card.Parent = scriptbloxScroll
            card.BackgroundTransparency = 1
            svc.TweenService:Create(card, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.25}):Play()
        end
    end
    if validIdx == 0 then
        for _, child in pairs(scriptbloxScroll:GetChildren()) do
            if not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
                child:Destroy()
            end
        end
        local emptyLabel = create("TextLabel", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Text = t("scriptblox_no_results"), TextColor3 = theme.textDim, TextSize = 14, Font = Enum.Font.SourceSansBold, ZIndex = 4})
        emptyLabel.Parent = scriptbloxScroll
    end
    if scriptbloxScroll and scriptbloxGrid then
        task.defer(function()
            scriptbloxScroll.CanvasSize = UDim2.new(0, 0, 0, scriptbloxGrid.AbsoluteContentSize.Y + 16)
        end)
    end
    _G.__DeltaUI_refreshScriptBloxLock = false
end

isCollapsed = false
local function setStatsTransparency(targetTransparency)
    local pills = {pingPill, fpsPill, timePill, labelPill}
    for _, pill in ipairs(pills) do
        if pill then
            svc.TweenService:Create(pill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = targetTransparency}):Play()
            for _, child in pairs(pill:GetChildren()) do
                if child:IsA("TextLabel") or child:IsA("TextButton") then
                    svc.TweenService:Create(child, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = targetTransparency < 1 and 0 or 1}):Play()
                elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
                    svc.TweenService:Create(child, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = targetTransparency < 1 and 0 or 1}):Play()
                end
            end
        end
    end
end

local existingOrb = nil
for _, child in pairs(svc.CoreGui:GetChildren()) do
    local isHash = #child.Name == 16
            if isHash then
                for i = 1, 16 do
                    local c = child.Name:sub(i, i)
                    if not ((c >= "0" and c <= "9") or (c >= "a" and c <= "f")) then
                        isHash = false
                        break
                    end
                end
            end
            if isHash and child:FindFirstChild("DeltaUI_OrbFrame") then
        existingOrb = child:FindFirstChild("DeltaUI_OrbFrame")
        break
    end
end
if existingOrb then
    orbFrame = existingOrb
else
    orbFrame = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.35, 0),
        Size = UDim2.new(0, 35, 0, 35),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 100,
        Name = "DeltaUI_OrbFrame"
    })
    corner(17, orbFrame)
    orbStroke = create("UIStroke", {Color = theme.accent, Thickness = 1.5, Transparency = 0})
    orbStroke.Parent = orbFrame
    orbFrame.Parent = screenGui
end
orbBtn = create("TextButton", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Text = "",
    ZIndex = 101
})
orbBtn.Parent = orbFrame
isOrbDragging = false
orbDragStart = nil
orbDragInput = nil
orbDragOffset = nil

local orbDragDistance = 0

orbBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isOrbDragging = false
        orbDragDistance = 0
        local inputPos = Vector2.new(input.Position.X, input.Position.Y)
        orbDragStart = inputPos
        local screenSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
        local halfSize = orbFrame.AbsoluteSize / 2

        local pos = orbFrame.Position
        local centerX = pos.X.Scale * screenSize.X + pos.X.Offset
        local centerY = pos.Y.Scale * screenSize.Y + pos.Y.Offset
        orbDragOffset = inputPos - Vector2.new(centerX, centerY)

        if math.abs(orbDragOffset.X) > 200 or math.abs(orbDragOffset.Y) > 200 then
            orbDragOffset = Vector2.new(0, 0)
        end
        orbDragInput = input
    end
end)

svc.UserInputService.InputChanged:Connect(function(input)
    if input == orbDragInput and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local pos2 = Vector2.new(input.Position.X, input.Position.Y)
        if pos2.X ~= pos2.X or pos2.Y ~= pos2.Y then return end
        if pos2.X == 0 and pos2.Y == 0 then return end
        local delta = pos2 - orbDragStart
        local dist = math.max(math.abs(delta.X), math.abs(delta.Y))
        if dist > orbDragDistance then
            orbDragDistance = dist
        end
        if dist > 5 then
            isOrbDragging = true
        end
        if isOrbDragging then
            local newCenter = pos2 - orbDragOffset
            local screenSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
            local orbSize = orbFrame.AbsoluteSize
            newCenter = Vector2.new(
                math.clamp(newCenter.X, orbSize.X / 2, screenSize.X - orbSize.X / 2),
                math.clamp(newCenter.Y, orbSize.Y / 2, screenSize.Y - orbSize.Y / 2)
            )
            orbFrame.Position = UDim2.new(0, newCenter.X, 0, newCenter.Y)
        end
    end
end)

svc.UserInputService.InputEnded:Connect(function(input)
    if input == orbDragInput then
        orbDragInput = nil
        isOrbDragging = false
        orbDragDistance = 0
    end
end)
logoutBtn.MouseButton1Click:Connect(function()
    for _, dd in ipairs(_G.__DeltaUI_dropdowns or {}) do
        if dd.close then dd.close() end
    end
    main.Visible = false
    orbFrame.Visible = true
    orbFrame.BackgroundTransparency = 1
    local targetSize = orbFrame.Size
    orbFrame.Size = UDim2.new(0, 0, 0, 0)
    svc.TweenService:Create(orbFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.1, Size = targetSize}):Play()
end)
orbBtn.MouseButton1Click:Connect(function()
    if orbDragDistance > 5 then return end
    if buildSpaceActive then exitBuildSpace() return end
    orbFrame.Visible = false

    
    local isRightLayout = deepCustomLayoutEnabled
    local navOffset = isRightLayout and 80 or -80
    local navSavedPos = navBg.Position
    local logoutSavedPos = logoutBtn.Position
    navBg.Position = UDim2.new(navSavedPos.X.Scale, navSavedPos.X.Offset + navOffset, navSavedPos.Y.Scale, navSavedPos.Y.Offset)
    logoutBtn.Position = UDim2.new(logoutSavedPos.X.Scale, logoutSavedPos.X.Offset + navOffset, logoutSavedPos.Y.Scale, logoutSavedPos.Y.Offset)

    main.Visible = true

    
    cancelNavBgTween()
    navBgTween = svc.TweenService:Create(navBg, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Position = navSavedPos
    })
    navBgTween:Play()
    svc.TweenService:Create(logoutBtn, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Position = logoutSavedPos
    }):Play()
    
    wrapperFrame.Position = deepCustomLayoutEnabled and UDim2.new(1, -64, 0, 86) or UDim2.new(1, -10, 0, 86)
    wrapperFrame.Size = UDim2.new(1, -82, 1, -98)
    isCollapsed = false

    
    local function fadeInGui(frame, targetBg)
        if not frame then return end
        frame.BackgroundTransparency = math.min(1, (targetBg or frame.BackgroundTransparency) + 0.5)
        svc.TweenService:Create(frame, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = targetBg or frame.BackgroundTransparency }):Play()
        local function fadeDesc(node)
            for _, c in pairs(node:GetChildren()) do
                if c:IsA("TextLabel") or c:IsA("TextButton") then
                    c.TextTransparency = 1
                    svc.TweenService:Create(c, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()
                elseif c:IsA("ImageLabel") or c:IsA("ImageButton") then
                    c.ImageTransparency = 1
                    svc.TweenService:Create(c, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { ImageTransparency = 0 }):Play()
                elseif c:IsA("Frame") or c:IsA("CanvasGroup") then
                    fadeDesc(c)
                end
            end
        end
        fadeDesc(frame)
    end

    
    if topBar then fadeInGui(topBar, 1) end
    local pills = {pingPill, fpsPill, timePill, labelPill}
    for _, pill in ipairs(pills) do
        if pill then fadeInGui(pill, 0.25) end
    end

    
    local function animateOpen(frame, targetPos)
        local startPos = UDim2.new(targetPos.X.Scale, targetPos.X.Offset, targetPos.Y.Scale, targetPos.Y.Offset + 18)
        frame.Position = startPos
        svc.TweenService:Create(frame, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = targetPos }):Play()
        
        task.spawn(function()
            for i = 1, 20 do
                pcall(function() frame.GroupTransparency = 0.4 * (1 - i / 20) end)
                task.wait(0.011)
            end
            pcall(function() frame.GroupTransparency = 0 end)
        end)
    end
    animateOpen(wrapperFrame, wrapperFrame.Position)
end)
currentPage = "house"
editorPage = create("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = true, ZIndex = 2})
editorPage.Parent = contentFrame

editorHeaderBar = create("Frame", {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 0, 42),
    BackgroundColor3 = theme.surfaceLight,
    BackgroundTransparency = 0.5,
    BorderSizePixel = 0,
    ZIndex = 4,
})
corner(theme.radius, editorHeaderBar)
stroke(theme.border, 1, editorHeaderBar)
editorHeaderBar.Parent = editorPage
tabBar = create("Frame", {
    Position = UDim2.new(0, 8, 0, 6),
    Size = UDim2.new(1, -36, 0, 30),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 5
})
tabBar.Parent = editorPage
tabBarLayout = create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center, HorizontalAlignment = Enum.HorizontalAlignment.Left})
tabBarLayout.Parent = tabBar

tabAddBtn = create("TextButton", {
    Size = UDim2.new(0, 26, 0, 26),
    BackgroundColor3 = theme.surfaceLight,
    BackgroundTransparency = 0.3,
    Text = "",
    BorderSizePixel = 0,
    LayoutOrder = 999,
    ZIndex = 7
})
corner(4, tabAddBtn)
tabAddBtn.Parent = tabBar
tabAddIcon = GetIcon("circle-plus", UDim2.new(0, 12, 0, 12), Color3.fromRGB(255,255,255))
if tabAddIcon then
    tabAddIcon.Position = UDim2.new(0.5, -6, 0.5, -6)
    tabAddIcon.Parent = tabAddBtn
end

pageSwitcher = create("Frame", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -10, 0.5, 1),
    Size = UDim2.new(0, 68, 0, 24),
    BackgroundColor3 = theme.surfaceLight,
    BackgroundTransparency = 0.5,
    Visible = true,
    ZIndex = 6
})
corner(12, pageSwitcher)
stroke(theme.border, 1, pageSwitcher)
pageSwitcher.Parent = editorHeaderBar

pageLeftBtn = create("TextButton", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 4, 0.5, 0),
    Size = UDim2.new(0, 20, 0, 20),
    BackgroundTransparency = 1,
    Text = "",
    ZIndex = 7
})
pageLeftBtn.Parent = pageSwitcher
local pageLeftIcon = GetIcon("chevron-left", UDim2.new(0, 14, 0, 14), theme.textDim)
if pageLeftIcon then
    pageLeftIcon.Position = UDim2.new(0.5, -7, 0.5, -7)
    pageLeftIcon.Parent = pageLeftBtn
end

pageRightBtn = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -4, 0.5, 0),
    Size = UDim2.new(0, 20, 0, 20),
    BackgroundTransparency = 1,
    Text = "",
    ZIndex = 7
})
pageRightBtn.Parent = pageSwitcher
local pageRightIcon = GetIcon("chevron-right", UDim2.new(0, 14, 0, 14), theme.textDim)
if pageRightIcon then
    pageRightIcon.Position = UDim2.new(0.5, -7, 0.5, -7)
    pageRightIcon.Parent = pageRightBtn
end

pageCounterLabel = create("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, 20, 1, 0),
    BackgroundTransparency = 1,
    Text = "1/1",
    TextColor3 = theme.textDim,
    TextSize = 11,
    Font = Enum.Font.SourceSansBold,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 7
})
pageCounterLabel.Parent = pageSwitcher

pageLeftBtn.MouseButton1Click:Connect(function()
    if not tabs[currentTab] then return end
    saveCurrentTab()
    local fullText = tabs[currentTab].content
    calculatePageBreaks(fullText)
    if currentCodePage > 1 then
        currentCodePage = currentCodePage - 1
        showCurrentPage()
    end
end)

pageRightBtn.MouseButton1Click:Connect(function()
    if not tabs[currentTab] then return end
    saveCurrentTab()
    local fullText = tabs[currentTab].content
    calculatePageBreaks(fullText)
    if currentCodePage < #codePageBreaks then
        currentCodePage = currentCodePage + 1
        showCurrentPage()
    end
end)

local pageLeftHolding = false
pageLeftBtn.MouseButton1Down:Connect(function()
    pageLeftHolding = true
    task.spawn(function()
        task.wait(0.4)
        while pageLeftHolding do
            if not tabs[currentTab] then break end
            local fullText = tabs[currentTab].content
            calculatePageBreaks(fullText)
            if currentCodePage > 1 then
                currentCodePage = currentCodePage - 1
                showCurrentPage()
            else
                break
            end
            task.wait(0.12)
        end
    end)
end)
pageLeftBtn.MouseButton1Up:Connect(function()
    pageLeftHolding = false
end)
pageLeftBtn.MouseLeave:Connect(function()
    pageLeftHolding = false
end)

local pageRightHolding = false
pageRightBtn.MouseButton1Down:Connect(function()
    pageRightHolding = true
    task.spawn(function()
        task.wait(0.4)
        while pageRightHolding do
            if not tabs[currentTab] then break end
            local fullText = tabs[currentTab].content
            calculatePageBreaks(fullText)
            if currentCodePage < #codePageBreaks then
                currentCodePage = currentCodePage + 1
                showCurrentPage()
            else
                break
            end
            task.wait(0.12)
        end
    end)
end)
pageRightBtn.MouseButton1Up:Connect(function()
    pageRightHolding = false
end)
pageRightBtn.MouseLeave:Connect(function()
    pageRightHolding = false
end)

-- 行号栏宽度按最大行号数字的渲染宽度动态调整
local LINE_NUMBER_MIN_WIDTH = 28   -- 最少也能容纳个位数行号（含左右留白）
local LINE_NUMBER_HPAD = 12        -- 数字左右留白合计
local lineNumberWidth = LINE_NUMBER_MIN_WIDTH  -- 当前实际宽度，供 codeScroll 同步

local function updateLineNumberWidth()
    if not lineNumberFrame or not lineNumberLabel or not codeBox then return end
    local lastLine = 1
    if codePageBreaks and currentCodePage and #codePageBreaks > 0 and currentCodePage <= #codePageBreaks then
        lastLine = (codePageBreaks[currentCodePage] or 1) + 4999 -- 每页最多5000行(见updateLineNumbers截断)
    end
    local sample = tostring(lastLine)                -- 用最大行号数字测量宽度
    local textSize = lineNumberLabel.TextSize
    local font = lineNumberLabel.Font
    local TextService = game:GetService("TextService")
    -- 精确测量：用最大行号整串渲染宽度，避免近似误差
    local ok, size = pcall(function()
        return TextService:GetTextSize(sample, textSize, font, Vector2.new(1e6, textSize + 2))
    end)
    local w
    if ok and size then
        w = math.ceil(size.X) + LINE_NUMBER_HPAD     -- 数字宽 + 左右留白
    else
        w = math.ceil(textSize * 0.62 * #sample) + LINE_NUMBER_HPAD
    end
    w = math.max(w, LINE_NUMBER_MIN_WIDTH)
    if w ~= lineNumberWidth then
        lineNumberWidth = w
        lineNumberFrame.Size = UDim2.new(0, w, 1, -96)
        -- 输入框(编辑器)紧跟在行号栏右侧，中间留 4px 间隙
        codeScroll.Position = UDim2.new(0, w + 4, 0, 52)
        codeScroll.Size = UDim2.new(1, -(w + 8), 1, -96)
    end
end

lineNumberFrame = create("ScrollingFrame", {
    Position = UDim2.new(0, 0, 0, 52),
    Size = UDim2.new(0, LINE_NUMBER_MIN_WIDTH, 1, -96),
    BackgroundColor3 = theme.surface,
    BackgroundTransparency = 0.35,
    BorderSizePixel = 0,
    ScrollBarThickness = 0,
    ScrollingEnabled = false,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ZIndex = 3
})
corner(8, lineNumberFrame)
stroke(theme.border, 1, lineNumberFrame)
lineNumberFrame.Parent = editorPage

lineNumberDivider = create("Frame", {
    Position = UDim2.new(1, -1, 0, 2),
    Size = UDim2.new(0, 1, 1, -4),
    BackgroundColor3 = theme.border,
    BackgroundTransparency = 0.3,
    BorderSizePixel = 0,
    ZIndex = 5,
})
lineNumberDivider.Parent = lineNumberFrame
lineNumberLabel = create("TextLabel", {Size = UDim2.new(1, -8, 1, 0), Position = UDim2.new(0, 4, 0, 0), BackgroundTransparency = 1, Text = "1", TextColor3 = Color3.fromRGB(120, 132, 158), TextSize = 13, Font = Enum.Font.Code, TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 4})
lineNumberLabel.Parent = lineNumberFrame
codeScroll = create("ScrollingFrame", {
    Position = UDim2.new(0, LINE_NUMBER_MIN_WIDTH + 4, 0, 52),
    Size = UDim2.new(1, -(LINE_NUMBER_MIN_WIDTH + 8), 1, -96),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 8,
    ScrollBarImageColor3 = theme.textDim,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ZIndex = 3
})
codeScroll.Parent = editorPage

codeBox = create("TextBox", {
    Size = UDim2.new(1, 0, 0, 0),
    BackgroundTransparency = 1,
    TextColor3 = theme.text,
    Font = Enum.Font.Code,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    MultiLine = true,
    ClearTextOnFocus = false,
    Text = "",
    ZIndex = 4
})
codeBox.Parent = codeScroll

syntaxLabel = create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 0),
    BackgroundTransparency = 1,
    TextColor3 = theme.text,
    Font = Enum.Font.Code,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    RichText = true,
    Text = "",
    ZIndex = 3
})
syntaxLabel.Parent = codeScroll

execHighlightBar = create("Frame", {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 0, 18),
    BackgroundColor3 = theme.accent,
    BackgroundTransparency = 0.65,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 5
})
applyGradient(execHighlightBar, theme.accent, theme.accent2, 120)
execHighlightBar.Parent = codeScroll

execErrorHighlight = create("Frame", {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 0, 18),
    BackgroundColor3 = theme.red,
    BackgroundTransparency = 0.45,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 5
})
execErrorHighlight.Parent = codeScroll
execRealErrorHighlight = create("Frame", {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 0, 18),
    BackgroundColor3 = Color3.fromRGB(180, 100, 220),
    BackgroundTransparency = 0.45,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 5
})
execRealErrorHighlight.Parent = codeScroll

execSuccessHighlight = create("Frame", {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 0, 18),
    BackgroundColor3 = Color3.fromRGB(80, 180, 120),
    BackgroundTransparency = 0.45,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 5
})
execSuccessHighlight.Parent = codeScroll

local function updateEditorSize()
    if isUpdatingEditorSize then return end
    isUpdatingEditorSize = true
    local ok, err = pcall(function()
        if not codeBox or not codeBox.Parent then return end
        if not codeScroll or not codeScroll.Parent then return end
        local text = codeBox.Text or ""
        local lines = math.max(1, select(2, text:gsub(string.char(10), "")) + 1)
        local height
        local boundsY = (codeBox.TextBounds and codeBox.TextBounds.Y) or 0
        if boundsY > 0 then
            height = boundsY + 40
        else
            local lineHeight = math.max(4, codeBox.TextSize + 4)
            height = lines * lineHeight + 40
        end
        local viewH = codeScroll.AbsoluteSize.Y
        if viewH > 0 then
            height = math.max(height, viewH + 20)
        end
        codeBox.Size = UDim2.new(1, 0, 0, height)
        if syntaxLabel and syntaxLabel.Parent then
            syntaxLabel.Size = UDim2.new(1, 0, 0, height)
        end
        codeScroll.CanvasSize = UDim2.new(0, 0, 0, height)
        if lineNumberFrame and lineNumberFrame.Parent then
            lineNumberFrame.CanvasSize = UDim2.new(0, 0, 0, height)
        end
    end)
    isUpdatingEditorSize = false
    if not ok then warn("[DeltaUI] updateEditorSize: " .. tostring(err)) end
end

editOverlay = create("TextButton", {
    Position = UDim2.new(0, 40, 0, 40),
    Size = UDim2.new(1, -56, 1, -84),
    BackgroundTransparency = 1,
    Text = "",
    ZIndex = 8
})
editOverlay.Parent = editorPage
local cachedEditorText = nil
local cachedEditorLines = nil
local function getCachedLines(text)
    if cachedEditorText == text and cachedEditorLines then
        return cachedEditorLines
    end
    cachedEditorText = text
    cachedEditorLines = splitLines(text)
    return cachedEditorLines
end
editOverlay.MouseButton1Click:Connect(function()
    local ok, err = pcall(function()
        local absPos = editOverlay.AbsolutePosition
        local absSize = editOverlay.AbsoluteSize
        local mousePos = svc.UserInputService:GetMouseLocation()
        if mousePos.X > absPos.X + absSize.X then
            return
        end
        local savedScroll = codeScroll.CanvasPosition
        editOverlay.Visible = false
        if syntaxLabel then syntaxLabel.Visible = false end
        codeBox.TextTransparency = 0
        codeBox:CaptureFocus()
        local lineHeight = codeBox.TextSize + 2
        local visibleLine = math.floor(savedScroll.Y / lineHeight) + 1
        local cursorPos = 0
        local lines = getCachedLines(codeBox.Text)
        for i = 1, math.min(visibleLine, #lines) do
            cursorPos = cursorPos + #lines[i] + 1
        end
        codeBox.CursorPosition = math.min(cursorPos, #codeBox.Text + 1)
        codeScroll.CanvasPosition = savedScroll
    end)
    if not ok then warn("[DeltaUI] EditOverlay: " .. tostring(err)) end
end)
codeBox.FocusLost:Connect(function()
    local ok, err = pcall(function()
        editOverlay.Visible = true
        codeBox.TextTransparency = 1
        showCurrentPage()
        updateEditorSize()
        task.defer(updateSyntaxHighlight)
        if syntaxLabel then syntaxLabel.Visible = true end
    end)
    if not ok then warn("[DeltaUI] FocusLost: " .. tostring(err)) end
end)
function updateLineNumbers()
    local ok, err = pcall(function()
        local text = codeBox.Text or ""
        local lines = splitLines(text)
        if #lines > 5000 then
            for i = 5001, #lines do
                lines[i] = nil
            end
        end
        local maxWidth = math.max(1, codeBox.AbsoluteSize.X - 12)
        local textSize = codeBox.TextSize
        local font = codeBox.Font
        local TextService = game:GetService("TextService")
        local startLine = 1
        if codePageBreaks and currentCodePage and #codePageBreaks > 0 and currentCodePage <= #codePageBreaks then
            startLine = codePageBreaks[currentCodePage] or 1
        end
        local nums = {}
        for i, line in ipairs(lines) do
            local absLine = startLine + i - 1
            table.insert(nums, tostring(absLine))
        end
        lineNumberLabel.Text = table.concat(nums, string.char(10))
    end)
    if not ok then warn("[DeltaUI] updateLineNumbers: " .. tostring(err)) end
    updateLineNumberWidth()
    updateEditorSize()
end

local function getVisualLineHeight()
    if not codeBox or not codeBox.Parent then return 16 end
    return math.max(4, codeBox.TextSize + 2)
end

local function getLineHeight()
    return getVisualLineHeight()
end

local function countVisualLinesBefore(text, targetLogicalLine, maxWidth, textSize, font)
    _G.__DeltaUI_cvlLines = splitLines(text)
    if targetLogicalLine < 1 then
        _G.__DeltaUI_cvlLines = nil
        return 0
    end
    local TextService = game:GetService("TextService")
    local count = 0
    for i = 1, math.min(targetLogicalLine - 1, #_G.__DeltaUI_cvlLines) do
        local line = _G.__DeltaUI_cvlLines[i]
        if line == "" then
            count = count + 1
        else
            local ok, size = pcall(function()
                return TextService:GetTextSize(line, textSize, font, Vector2.new(maxWidth, math.huge))
            end)
            if ok and size then
                count = count + math.max(1, math.ceil(size.X / maxWidth))
            else
                count = count + 1
            end
        end
    end
    _G.__DeltaUI_cvlLines = nil
    return count
end

local function clearExecHighlights()
    execHighlightBar.Visible = false
    execErrorHighlight.Visible = false
    execSuccessHighlight.Visible = false
    execRealErrorHighlight.Visible = false
end

local function scrollToLine(logicalLine, offsetLines)
    if not logicalLine or logicalLine < 1 then return end
    if not codeBox or not codeBox.Parent then return end
    if not codeScroll or not codeScroll.Parent then return end
    local text = codeBox.Text or ""
    if text == "" then return end
    offsetLines = offsetLines or 3
    local lines = splitLines(text)
    if logicalLine > #lines then return end
    local lineHeight = getVisualLineHeight()
    local targetY = math.max(0, (logicalLine - 1 - offsetLines + 1) * lineHeight)
    local viewH = codeScroll.AbsoluteSize.Y
    local maxY = math.max(0, codeScroll.CanvasSize.Y.Offset - viewH)
    codeScroll.CanvasPosition = Vector2.new(0, math.min(targetY, maxY))
    if lineNumberFrame then
        lineNumberFrame.CanvasPosition = Vector2.new(0, codeScroll.CanvasPosition.Y)
    end
end

local function highlightExecLine(logicalLine, colorType)
    if not logicalLine or logicalLine < 1 then return end
    if not codeBox or not codeBox.Parent then return end
    local text = codeBox.Text or ""
    if text == "" then return end
    local lines = splitLines(text)
    if logicalLine > #lines then return end
    local lineHeight = getVisualLineHeight()
    local maxWidth = math.max(1, codeBox.AbsoluteSize.X - 12)
    local textSize = codeBox.TextSize
    local font = codeBox.Font
    local baseOffset = (logicalLine - 1) * lineHeight
    local lineVisualHeight = lineHeight
    local target
    if colorType == "error" then
        target = execErrorHighlight
    elseif colorType == "real" then
        target = execRealErrorHighlight
    elseif colorType == "success" then
        target = execSuccessHighlight
    else
        target = execHighlightBar
    end
    if not target or not target.Parent then return end
    target.Position = UDim2.new(0, 0, 0, baseOffset)
    target.Size = UDim2.new(1, 0, 0, lineVisualHeight)
    target.Visible = true
end

local function parseErrorLine(errMsg)
    if not errMsg then return nil end
        local function extractNumberAfterToken(str, token)
        local startPos = str:find(token, 1, true)
        if not startPos then return nil end
        local after = str:sub(startPos + #token)
        local numStr = ""
        for i = 1, #after do
            local c = after:sub(i, i)
            if c >= "0" and c <= "9" then
                numStr = numStr .. c
            elseif #numStr > 0 then
                break
            elseif c ~= " " and c ~= "  " and c ~= ":" then
                break
            end
        end
        return tonumber(numStr)
    end
        for i = 1, #errMsg do
        if errMsg:sub(i,i) == ":" then
            local numStr = ""
            local j = i + 1
            while j <= #errMsg do
                local c = errMsg:sub(j,j)
                if c >= "0" and c <= "9" then
                    numStr = numStr .. c
                    j = j + 1
                else
                    break
                end
            end
            if #numStr > 0 and errMsg:sub(j,j) == ":" then
                local realLine = tonumber(numStr)
                if realLine and realLine > 0 then
                    return realLine
                end
            end
        end
    end
        local line = extractNumberAfterToken(errMsg, "Line")
    if not line then
        line = extractNumberAfterToken(errMsg, "line")
    end
    return line
end

function jumpToErrorLine(errLine)
    if not errLine or type(errLine) ~= "number" or errLine < 1 then return false end
    local function tryTab(tabIdx, line)
        local tab = tabs[tabIdx]
        if not tab then return false end
        local text = tab.content or ""
        if type(text) ~= "string" then text = "" end
        local lines = splitLines(text)
        if line > #lines then return false end
        saveCurrentTab()
        currentTab = tabIdx
        currentCodePage = 1
        calculatePageBreaks(text)
        if #codePageBreaks == 0 then
            table.insert(codePageBreaks, 1)
        end
        for pageNum, startLine in ipairs(codePageBreaks) do
            local endLine = codePageBreaks[pageNum + 1] and codePageBreaks[pageNum + 1] - 1 or #lines
            if line >= startLine and line <= endLine then
                currentCodePage = pageNum
                break
            end
        end
        showCurrentPage()
        renderTabs()
        local relativeLogicalLine = line - (codePageBreaks[currentCodePage] or 1) + 1
        highlightExecLine(relativeLogicalLine, "error")
        scrollToLine(relativeLogicalLine, 3)
        return true
    end
    if tryTab(currentTab, errLine) then return true end
    for tabIdx, tab in ipairs(tabs) do
        if tabIdx ~= currentTab then
            if tryTab(tabIdx, errLine) then return true end
        end
    end
    return false
end
local function animateExecScan(scanDuration)
    if not codeBox or not codeBox.Parent then return nil end
    if not codeScroll or not codeScroll.Parent then return nil end
    if not tabs[currentTab] then return nil end

    local fullText = tabs[currentTab].content or ""
    if type(fullText) ~= "string" then fullText = "" end
    if fullText == "" then return nil end

                local totalLines = select(2, fullText:gsub(string.char(10), "")) + 1
    if totalLines == 0 then return nil end

    local lineHeight = getLineHeight()
    if lineHeight <= 0 then lineHeight = 16 end

    local totalVisualLines = totalLines
    local pageRanges = {}
    local pageStep = 100
    for startLine = 1, totalLines, pageStep do
        local endLine = math.min(startLine + pageStep - 1, totalLines)
        table.insert(pageRanges, {start = startLine, ["end"] = endLine})
    end
    if #pageRanges == 0 then
        pageRanges[1] = {start = 1, ["end"] = totalLines}
    end

    execHighlightBar.BackgroundColor3 = Color3.fromRGB(80, 180, 120)
    execHighlightBar.BackgroundTransparency = 0.45
    execHighlightBar.Size = UDim2.new(1, 0, 0, lineHeight)
    execHighlightBar.Visible = true
    isExecScanning = true

    local startTime = tick()
    local scanConn = nil
    scanConn = svc.RunService.RenderStepped:Connect(function()
        if not execHighlightBar or not execHighlightBar.Parent then
            if scanConn then scanConn:Disconnect() scanConn = nil end
            return
        end
        local elapsed = tick() - startTime
        local progress = math.min(1, elapsed / scanDuration)
        local currentVisualLine = math.floor(progress * totalVisualLines)

        local currentActualLine = math.max(1, math.min(currentVisualLine + 1, totalLines))

        local currentPage = 1
        for i, range in ipairs(pageRanges) do
            if currentActualLine >= range.start and currentActualLine <= range["end"] then
                currentPage = i
                break
            end
        end

        if currentCodePage ~= currentPage then
            currentCodePage = currentPage
            showCurrentPage()
        end

        local pageStartLine = pageRanges[currentPage].start
        local pageVisualOffset = math.max(0, currentActualLine - pageStartLine)

        local yPos = pageVisualOffset * lineHeight
        execHighlightBar.Position = UDim2.new(0, 0, 0, yPos)

        if codeScroll and codeScroll.Parent then
            local viewH = codeScroll.AbsoluteSize.Y
            local canvasH = codeScroll.CanvasSize.Y.Offset
            local maxScroll = math.max(0, canvasH - viewH)
            local targetScroll = math.max(0, yPos - viewH * 0.5 + lineHeight * 0.5)
            targetScroll = math.min(targetScroll, maxScroll)
            local currentScroll = codeScroll.CanvasPosition.Y
            local newScroll = currentScroll + (targetScroll - currentScroll) * 0.25
            if math.abs(newScroll - currentScroll) > 0.5 then
                codeScroll.CanvasPosition = Vector2.new(0, newScroll)
            end
        end

        if progress >= 1 then
            if scanConn then scanConn:Disconnect() scanConn = nil end
            isExecScanning = false
            task.delay(0.3, function()
                execHighlightBar.Visible = false
            end)
        end
    end)

    return {
        Cancel = function()
            if scanConn then scanConn:Disconnect() scanConn = nil end
            isExecScanning = false
            execHighlightBar.Visible = false
        end
    }
end
function syntaxHighlight(code)
    if not code or code == "" then return "" end
    local result = {}
    local i = 1
    local len = #code

    local tokens = {
        ["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true,
        ["elseif"] = true, ["end"] = true, ["false"] = true, ["for"] = true,
        ["function"] = true, ["goto"] = true, ["if"] = true, ["in"] = true,
        ["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true,
        ["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true,
        ["until"] = true, ["while"] = true
    }

    local builtins = {
        ["print"] = true, ["warn"] = true, ["error"] = true, ["pcall"] = true,
        ["xpcall"] = true, ["loadstring"] = true, ["require"] = true,
        ["game"] = true, ["workspace"] = true, ["script"] = true,
        ["pairs"] = true, ["ipairs"] = true, ["next"] = true, ["type"] = true,
        ["tonumber"] = true, ["tostring"] = true, ["table"] = true,
        ["string"] = true, ["math"] = true, ["os"] = true, ["coroutine"] = true,
        ["debug"] = true, ["bit32"] = true, ["utf8"] = true,
        ["Vector3"] = true, ["Vector2"] = true, ["Color3"] = true,
        ["Instance"] = true, ["Enum"] = true, ["UDim"] = true, ["UDim2"] = true,
        ["Ray"] = true, ["CFrame"] = true, ["BrickColor"] = true,
        ["NumberRange"] = true, ["NumberSequence"] = true, ["ColorSequence"] = true,
        ["Rect"] = true, ["Region3"] = true, ["Region3int16"] = true,
        ["Axes"] = true, ["Faces"] = true, ["PhysicalProperties"] = true,
        ["FloatCurve"] = true, ["RotationCurve"] = true
    }

    while i <= len do
        local c = code:sub(i, i)
        local token = nil
        local color = nil

        if c == "-" and code:sub(i+1, i+1) == "-" then
            if code:sub(i+2, i+3) == "[[" then
                local endPos = code:find("]]", i + 4, true) or len + 1
                token = code:sub(i, endPos + 1)
                color = syntaxColors.comment
                i = endPos + 2
            else
                local endPos = code:find(string.char(10), i + 2, true) or len + 1
                token = code:sub(i, endPos - 1)
                color = syntaxColors.comment
                i = endPos
            end
        elseif c == '"' or c == "'" then
            local quote = c
            local j = i + 1
            while j <= len do
                local ch = code:sub(j, j)
                if ch == "" then
                    j = j + 2
                elseif ch == quote then
                    j = j + 1
                    break
                else
                    j = j + 1
                end
            end
            token = code:sub(i, j - 1)
            color = syntaxColors.string
            i = j
        elseif c >= "0" and c <= "9" then
            local j = i
            while j <= len do
                local ch = code:sub(j, j)
                if (ch >= "0" and ch <= "9") or ch == "." then
                    j = j + 1
                else
                    break
                end
            end
            token = code:sub(i, j - 1)
            color = syntaxColors.number
            i = j
        elseif (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_" then
            local j = i
            while j <= len do
                local ch = code:sub(j, j)
                if (ch >= "0" and ch <= "9") or (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or ch == "_" then
                    j = j + 1
                else
                    break
                end
            end
            local word = code:sub(i, j - 1)
            if tokens[word] then
                color = syntaxColors.token
            elseif builtins[word] then
                color = syntaxColors.builtin
            end
            token = word
            i = j
        else
            token = c
            i = i + 1
        end

        if token then
            local escaped = token:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
            if color then
                table.insert(result, string.format('<font color="rgb(%d,%d,%d)">%s</font>', color[1], color[2], color[3], escaped))
            else
                table.insert(result, escaped)
            end
        end
    end

    return table.concat(result)
end
syntaxColors = {
    token = {180, 130, 255},
    funcName = {200, 160, 255},
    localVar = {100, 200, 255},
    comment = {120, 120, 120},
    string = {150, 220, 140},
    number = {255, 180, 100},
    builtin = {255, 220, 100},
}

local isUpdatingEditorSize = false

local VP_MAX_FULL_LEN = 40000
local VP_MAX_RICHTEXT_LEN = 80000
local VP_BUFFER_LINES = 10
local VP_MAX_LINE_LEN = 8000
local function getVisibleLineRange()
    if not codeScroll or not codeScroll.Parent then return 1, 1 end
    local canvasY = codeScroll.CanvasPosition.Y
    local viewH = codeScroll.AbsoluteSize.Y
    if viewH <= 0 then return 1, 1 end
    local lineH = codeBox.TextSize + 2
    local startLine = math.max(1, math.floor(canvasY / lineH) - VP_BUFFER_LINES)
    local endLine = math.ceil((canvasY + viewH) / lineH) + VP_BUFFER_LINES
    return startLine, endLine
end

function updateSyntaxHighlight()
    if not syntaxLabel or not syntaxLabel.Parent then return end
    if _G.__DeltaUI_syntaxDebounce then
        _G.__DeltaUI_syntaxDebounce = tick()
        return
    end
    _G.__DeltaUI_syntaxDebounce = tick()
    task.defer(function()
        local startTick = _G.__DeltaUI_syntaxDebounce
        task.wait(0.08)
        if _G.__DeltaUI_syntaxDebounce ~= startTick then return end
        _G.__DeltaUI_syntaxDebounce = nil
        _G.__DeltaUI_doSyntaxHighlight()
    end)
end

function _G.__DeltaUI_doSyntaxHighlight()
    if not syntaxLabel or not syntaxLabel.Parent then return end
    local raw = codeBox.Text
    if #raw == 0 then syntaxLabel.Text = ""; return end
    if #raw <= VP_MAX_FULL_LEN then
        syntaxLabel.RichText = true
        local ok, result = pcall(syntaxHighlight, raw)
        if not ok or #result > VP_MAX_RICHTEXT_LEN then
            syntaxLabel.RichText = false
            syntaxLabel.Text = raw:sub(1, 79900)
            if not ok then warn("[DeltaUI] Syntax highlight failed: " .. tostring(result)) end
            return
        end
        syntaxLabel.Text = result
        return
    end
    syntaxLabel.RichText = true
    local lines = getCachedLines(raw)
    local totalLines = #lines
    if totalLines == 0 then return end
    local startLine, endLine = getVisibleLineRange()
    endLine = math.min(endLine, totalLines)
    startLine = math.min(startLine, totalLines)
    if startLine > endLine then startLine = 1 end
    local parts = {}
    for i = 1, startLine - 1 do
        parts[i] = lines[i]
    end
    for i = startLine, endLine do
        local line = lines[i]
        if #line > VP_MAX_LINE_LEN then
            parts[i] = line
        else
            local ok, highlighted = pcall(syntaxHighlight, line)
            if ok and highlighted and #highlighted < VP_MAX_LINE_LEN * 2 then
                parts[i] = highlighted
            else
                parts[i] = line
            end
        end
    end
    for i = endLine + 1, totalLines do
        parts[i] = lines[i]
    end
    local totalLen = 0
    for i = 1, #parts do
        totalLen = totalLen + #parts[i] + 1
    end
    if totalLen > VP_MAX_RICHTEXT_LEN then
        syntaxLabel.RichText = false
        syntaxLabel.Text = raw:sub(1, 199900)
        return
    end
    syntaxLabel.Text = table.concat(parts, string.char(10))
end

updateLineNumbers()

tabs = {}
currentTab = 1
tabIdCounter = 1
currentCodePage = 1
codePageBreaks = {}
isProgrammaticTextChange = false
isExecScanning = false

function getUniqueTabName()
    local base = "New tab"
    local names = {}
    for _, t in ipairs(tabs) do
        names[t.name] = true
    end
    name = base .. " " .. tabIdCounter
    while names[name] do
        tabIdCounter = tabIdCounter + 1
        name = base .. " " .. tabIdCounter
    end
    return name
end

function calculatePageBreaks(text)
    codePageBreaks = {}
    if type(text) ~= "string" or text == "" then
        table.insert(codePageBreaks, 1)
        return
    end
    local lines = splitLines(text)
    if #lines == 0 then
        table.insert(codePageBreaks, 1)
        return
    end
    if #lines > 10000 then

        local pageStart = 1
        while pageStart <= #lines do
            table.insert(codePageBreaks, pageStart)
            pageStart = pageStart + 100
        end
        return
    end
    local targetMin = 90
    local targetMax = 110
    local target = 100
    local currentPageStart = 1
    while currentPageStart <= #lines do
        table.insert(codePageBreaks, math.floor(currentPageStart))
        if currentPageStart + targetMax >= #lines then
            break
        end
        local bestBreak = nil
        local bestScore = -math.huge
        for i = targetMin, targetMax do
            local lineIdx = currentPageStart + i - 1
            if lineIdx >= #lines then
                bestBreak = #lines
                break
            end
            local line = lines[lineIdx]
            local nextLine = lines[lineIdx + 1] or ""
            local prevLine = lines[lineIdx - 1] or ""
            local score = 0
            if line == "" then
                score = score + 100
            end
            local trimmedLine = line
                while #trimmedLine > 0 and string.byte(trimmedLine:sub(1,1)) <= 32 do trimmedLine = trimmedLine:sub(2) end
                if trimmedLine:sub(1,3) == "end" then
                score = score + 80
            end
            local function startsWithTrimmed(str, prefix)
                    local s = str
                    while #s > 0 and string.byte(s:sub(1,1)) <= 32 do s = s:sub(2) end
                    return s:sub(1, #prefix) == prefix
                end
                if startsWithTrimmed(line, "local ") or startsWithTrimmed(line, "return ") then
                score = score + 60
            end
            local function countLeadingSpaces(str)
                local count = 0
                for i = 1, #str do
                    if string.byte(str:sub(i,i)) <= 32 then
                        count = count + 1
                    else
                        break
                    end
                end
                return count
            end
            local prevIndent = countLeadingSpaces(prevLine)
            local currIndent = countLeadingSpaces(line)
            if currIndent < prevIndent and currIndent == 0 then
                score = score + 50
            end
            if line:sub(-1) == '"' or line:sub(-1) == "'" or line:match("%[%[%s*$") then
                score = score - 200
            end
            if startsWithTrimmed(line, "function ") or startsWithTrimmed(line, "local function ") or startsWithTrimmed(line, "if ") or startsWithTrimmed(line, "for ") or startsWithTrimmed(line, "while ") or startsWithTrimmed(line, "repeat") then
                score = score - 50
            end
            score = score - math.abs(i - target) * 0.5
            if score > bestScore then
                bestScore = score
                bestBreak = lineIdx + 1
            end
        end
        if bestBreak and bestBreak > currentPageStart then
            currentPageStart = math.floor(bestBreak)
        else
            currentPageStart = currentPageStart + target
        end
    end
    if #codePageBreaks == 0 then
        table.insert(codePageBreaks, 1)
    end
end
function showCurrentPage()
    local ok, err = pcall(function()
        if not tabs[currentTab] then return end
        local text = tabs[currentTab].content
        if type(text) ~= "string" then text = "" end
                                if isExecScanning then
            updatePageSwitcher()
            return
        end
        calculatePageBreaks(text)
        if currentCodePage < 1 then currentCodePage = 1 end
        if currentCodePage > #codePageBreaks then
            currentCodePage = math.max(1, #codePageBreaks)
        end
        local startLine = codePageBreaks[currentCodePage] or 1
        local lines = splitLines(text)
        local endLine
        if currentCodePage < #codePageBreaks then
            endLine = codePageBreaks[currentCodePage + 1] - 1
        else
            endLine = #lines
        end
        endLine = math.min(endLine, #lines)
        local pageText = ""
        for i = startLine, endLine do
            pageText = pageText .. (lines[i] or "")
            if i < endLine then
                pageText = pageText .. string.char(10)
            end
        end
        if #pageText > 199000 then
            pageText = pageText:sub(1, 199000) .. "..."
        end
        isProgrammaticTextChange = true
        codeBox.Text = pageText
        isProgrammaticTextChange = false
        updateLineNumbers()
        _G.__DeltaUI_doSyntaxHighlight()
        updatePageSwitcher()
    end)
    if not ok then warn("[DeltaUI] showCurrentPage: " .. tostring(err)) end
end

function updatePageSwitcher()
    if not pageCounterLabel then return end
    local total = math.max(1, #codePageBreaks)
    pageCounterLabel.Text = tostring(currentCodePage) .. "/" .. tostring(total)
end

function saveCurrentTab()
    if not tabs[currentTab] then return end
    local text = codeBox.Text
    if text == "" then
        tabs[currentTab].content = ""
        return
    end
    if #codePageBreaks > 1 and currentCodePage <= #codePageBreaks and currentCodePage >= 1 then
        local fullText = tabs[currentTab].content or ""
        if type(fullText) ~= "string" then fullText = "" end
        local allLines = splitLines(fullText)
        local pageStart = codePageBreaks[currentCodePage] or 1
        local endLine = codePageBreaks[currentCodePage + 1] and codePageBreaks[currentCodePage + 1] - 1 or #allLines
        local newLines = splitLines(text)
        local merged = {}
        for i = 1, pageStart - 1 do
            table.insert(merged, allLines[i] or "")
        end
        for i = 1, #newLines do
            table.insert(merged, newLines[i])
        end
        for i = endLine + 1, #allLines do
            table.insert(merged, allLines[i] or "")
        end
        text = table.concat(merged, string.char(10))
    end
    tabs[currentTab].content = text
end

function renderTabs()
    local tabChildren = tabBar:GetChildren()
    for i = #tabChildren, 1, -1 do
        local child = tabChildren[i]
        if child:IsA("TextButton") and child ~= tabAddBtn then
            child:Destroy()
        end
    end
    for idx, tab in ipairs(tabs) do
        pill = create("TextButton", {
            Size = UDim2.new(0, 120, 0, 26),
            BackgroundColor3 = idx == currentTab and theme.accent or theme.surface,
            BackgroundTransparency = 0.25,
            Text = "",
            BorderSizePixel = 0,
            LayoutOrder = idx,
            ZIndex = 5
        })
        corner(8, pill)
        if idx == currentTab then applyGradient(pill) end
        pill.Parent = tabBar
        icon = GetIcon("file-pen", UDim2.new(0, 11, 0, 11), Color3.fromRGB(255,255,255))
        if icon then
            icon.Position = UDim2.new(0, 6, 0.5, -5)
            icon.Parent = pill
        end
        txt = create("TextLabel", {Position = UDim2.new(0, 20, 0, 0), Size = UDim2.new(1, -46, 1, 0), BackgroundTransparency = 1, Text = tab.name, TextColor3 = Color3.fromRGB(255,255,255), TextSize = 12, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6})
        txt.Parent = pill
        closeBtn = create("TextButton", {Position = UDim2.new(1, -20, 0.5, -7), Size = UDim2.new(0, 14, 0, 14), BackgroundTransparency = 1, Text = "", ZIndex = 7})
        closeBtn.Parent = pill
        closeIcon = GetIcon("x", UDim2.new(0, 10, 0, 10), Color3.fromRGB(255,255,255))
        if closeIcon then
            closeIcon.Position = UDim2.new(0.5, -5, 0.5, -5)
            closeIcon.Parent = closeBtn
        end
        closeBtn.MouseButton1Click:Connect(function()
            local ok, err = pcall(function()
                if #tabs <= 1 then
                    tabs[1].content = ""
                    tabs[1].name = getUniqueTabName()
                    currentCodePage = 1
                    codePageBreaks = {}
                    codeBox.Text = ""
                    updateLineNumbers()
                    renderTabs()
                    return
                end
                table.remove(tabs, idx)
                if currentTab > #tabs then
                    currentTab = #tabs
                elseif currentTab == idx then
                    currentTab = math.max(1, idx - 1)
                end
                currentCodePage = 1
                codePageBreaks = {}
                showCurrentPage()
                renderTabs()
            end)
            if not ok then warn("[DeltaUI] closeTab: " .. tostring(err)) end
        end)
        pill.MouseButton1Click:Connect(function()
            saveCurrentTab()
            currentTab = idx
            currentCodePage = 1
            codePageBreaks = {}
            showCurrentPage()
            renderTabs()
        end)
    end
end

function addTab()
    local ok, err = pcall(function()
        saveCurrentTab()
        local name = getUniqueTabName()
        table.insert(tabs, {name = name, content = defaultEditorText})
        currentTab = #tabs
        tabIdCounter = tabIdCounter + 1
        currentCodePage = 1
        codePageBreaks = {}
        isProgrammaticTextChange = true
        codeBox.Text = defaultEditorText
        isProgrammaticTextChange = false
        codeBox.TextTransparency = 1
        updateLineNumbers()
        task.defer(_G.__DeltaUI_doSyntaxHighlight)
        renderTabs()
        updatePageSwitcher()
    end)
    if not ok then warn("[DeltaUI] addTab: " .. tostring(err)) end
end

table.insert(tabs, {name = getUniqueTabName(), content = defaultEditorText})
renderTabs()
codeBox.TextTransparency = 1
showCurrentPage()

codeBox:GetPropertyChangedSignal("Text"):Connect(function()
    updateLineNumbers()
    if not isProgrammaticTextChange and tabs[currentTab] then
        saveCurrentTab()
    end
    updateSyntaxHighlight()
    updateEditorSize()
end)

codeScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
    if lineNumberFrame then
        lineNumberFrame.CanvasPosition = Vector2.new(0, codeScroll.CanvasPosition.Y)
    end
    if #codeBox.Text > VP_MAX_FULL_LEN then
        updateSyntaxHighlight()
    end
end)

tabAddBtn.MouseButton1Click:Connect(function()
    addTab()
end)
bottomBar = create("Frame", {
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 6, 1, -8),
    Size = UDim2.new(1, -18, 0, 32),
    BackgroundTransparency = 1,
    ZIndex = 5
})
bottomBar.Parent = editorPage
bottomLeft = create("Frame", {Size = UDim2.new(0.5, 0, 1, 0), BackgroundTransparency = 1, ZIndex = 5})
bottomLeft.Parent = bottomBar
bottomLeftLayout = create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8)})
bottomLeftLayout.Parent = bottomLeft
local function makeBottomBtn(key, iconName)
    local btn = create("TextButton", {Size = UDim2.new(0, 85, 0, 30), BackgroundColor3 = theme.surface, BackgroundTransparency = 0.25, BorderSizePixel = 0, Text = "", ZIndex = 6})
    corner(8, btn)
    stroke(theme.border, 1, btn)
    local icon = GetIcon(iconName, UDim2.new(0, 13, 0, 13))
    if icon then
        icon.Position = UDim2.new(0, 8, 0.5, -6)
        icon.Parent = btn
    end
    txt = create("TextLabel", {Position = UDim2.new(0, 26, 0, 0), Size = UDim2.new(1, -28, 1, 0), BackgroundTransparency = 1, Text = t(key), TextColor3 = theme.text, TextSize = 11, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center})
    txt.Parent = btn
    table.insert(settingsData.uiRefs, {element = txt, key = key})
    return btn
end
execBtn = makeBottomBtn("execute", "play")
execBtn.Parent = bottomLeft
clearBtn = makeBottomBtn("clear", "trash-2")
clearBtn.Parent = bottomLeft
execBtn.MouseButton1Click:Connect(function()
    cleanupOldUI()
    saveCurrentTab()
    local code = tabs[currentTab] and tabs[currentTab].content or codeBox.Text
    if code and code ~= "" then
        clearExecHighlights()
        local scanCtrl = animateExecScan(0.8)
        local execEntry = AddLog("> " .. t("executing"), "info")
        local animRunning = true
        task.spawn(function()
            local dots = {".", "..", "..."}
            local idx = 1
            while animRunning do
                if execEntry and execEntry.Parent then
                    execEntry.Text = "> " .. t("executing"):gsub("%.+", dots[idx])
                end
                idx = idx % 3 + 1
                task.wait(0.4)
            end
        end)
                                task.spawn(function()
            local fn, compileErr = loadstring(code)
            if not fn then
                animRunning = false
                if scanCtrl then scanCtrl.Cancel() end
                clearExecHighlights()
                local errLine = parseErrorLine(tostring(compileErr))
                if errLine then
                    jumpToErrorLine(errLine)
                end
                AddLog("[Error] " .. tostring(compileErr), "error")
                ShowNotification(t("execution_error_notify"), 3, function()
                    switchPage("terminal")
                end)
                return
            end
            local oldPrint = print
            local oldWarn = warn
            print = function(...)
                local args = {...}
                local msg = table.concat(args, " ")
                AddLog(msg, "info")
                if logDedup then logDedup[msg] = tick() end
                oldPrint(...)
            end
            warn = function(...)
                local args = {...}
                local msg = table.concat(args, " ")
                AddLog(msg, "warn")
                if logDedup then logDedup[msg] = tick() end
                oldWarn(...)
            end
            _G.__DeltaUI_blockLogService = true
            local ok, execErr = xpcall(fn, function(err)
                return debug.traceback(tostring(err), 2)
            end)
            _G.__DeltaUI_blockLogService = nil
            print = oldPrint
            warn = oldWarn
            animRunning = false
            if scanCtrl then scanCtrl.Cancel() end
            if not ok then
                clearExecHighlights()
                local errLine = parseErrorLine(tostring(execErr))
                if errLine then
                    jumpToErrorLine(errLine)
                end
                AddLog("[Error] " .. tostring(execErr), "error")
                ShowNotification(t("execution_error_notify"), 3, function()
                    switchPage("terminal")
                end)
                return
            end
            clearExecHighlights()
            saveCurrentTab()
                                    currentCodePage = 999999
            showCurrentPage()
                        local pageText = codeBox.Text or ""
            local lastLine = select(2, pageText:gsub(string.char(10), "")) + 1
            if lastLine > 0 then
                highlightExecLine(lastLine, "success")
                scrollToLine(lastLine, 3)
            end
            task.delay(0.8, clearExecHighlights)
            if execEntry and execEntry.Parent then
                execEntry.Text = "> " .. t("execution_finished")
                execEntry.TextColor3 = Color3.fromRGB(100, 180, 255)
            end
        end)
    end
end)
clearBtn.MouseButton1Click:Connect(function()
    isProgrammaticTextChange = true
    codeBox.Text = defaultEditorText
    if syntaxLabel and syntaxLabel.Parent then
        syntaxLabel.Text = ""
    end
    updateLineNumbers()
    if tabs[currentTab] then
        tabs[currentTab].content = defaultEditorText
    end
    clearExecHighlights()
    isProgrammaticTextChange = false
    ShowNotification(t("editor_cleared"), 1)
end)
newlineBtn = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -166, 0.5, 0),
    Size = UDim2.new(0, 85, 0, 30),
    BackgroundColor3 = theme.surface,
    BackgroundTransparency = 0.25,
    BorderSizePixel = 0,
    Text = "",
    ZIndex = 6
})
corner(8, newlineBtn)
stroke(theme.border, 1, newlineBtn)
local newlineIcon = GetIcon("corner-down-left", UDim2.new(0, 13, 0, 13))
if newlineIcon then
    newlineIcon.Position = UDim2.new(0, 8, 0.5, -6)
    newlineIcon.Parent = newlineBtn
end
local newlineText = create("TextLabel", {Position = UDim2.new(0, 26, 0, 0), Size = UDim2.new(1, -28, 1, 0), BackgroundTransparency = 1, Text = t("newline"), TextColor3 = theme.text, TextSize = 11, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center})
newlineText.Parent = newlineBtn
table.insert(settingsData.uiRefs, {element = newlineText, key = "newline"})
newlineBtn.Parent = bottomBar
newlineBtn.MouseButton1Click:Connect(function()
    local savedScroll = codeScroll.CanvasPosition
    codeBox:CaptureFocus()
    codeBox.Text = codeBox.Text .. string.char(10)
    codeScroll.CanvasPosition = savedScroll
    updateLineNumbers()
    updateSyntaxHighlight()
    updateEditorSize()
end)

execClipBtn = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -8, 0.5, 0),
    Size = UDim2.new(0, 150, 0, 30),
    BackgroundColor3 = theme.surface,
    BackgroundTransparency = 0.25,
    BorderSizePixel = 0,
    Text = "",
    ZIndex = 6
})
corner(8, execClipBtn)
stroke(theme.border, 1, execClipBtn)
clipIcon = GetIcon("clipboard-list", UDim2.new(0, 13, 0, 13))
if clipIcon then
    clipIcon.Position = UDim2.new(0, 8, 0.5, -6)
    clipIcon.Parent = execClipBtn
end
clipText = create("TextLabel", {Position = UDim2.new(0, 26, 0, 0), Size = UDim2.new(1, -28, 1, 0), BackgroundTransparency = 1, Text = t("execute_clipboard"), TextColor3 = theme.text, TextSize = 11, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center})
clipText.Parent = execClipBtn
table.insert(settingsData.uiRefs, {element = clipText, key = "execute_clipboard"})
execClipBtn.Parent = bottomBar
execClipBtn.MouseButton1Click:Connect(function()
    cleanupOldUI()
    local result = getClipboardContent()
    if not result or result == "" then
        ShowNotification(t("error") .. ": Clipboard empty or unavailable", 2)
        return
    end
    _G.__DeltaUI_skipLineOffset = true
    clearExecHighlights()

    saveCurrentTab()
    local name = getUniqueTabName()
    table.insert(tabs, {name = "Clipboard " .. name, content = result})
    currentTab = #tabs
    tabIdCounter = tabIdCounter + 1
    currentCodePage = 1
    codePageBreaks = {}
    showCurrentPage()
    renderTabs()

    local scanCtrl = animateExecScan(0.8)
    local execEntry = AddLog("> " .. t("executing_clipboard"), "info")
    local animRunning = true
    task.spawn(function()
        local dots = {".", "..", "..."}
        local idx = 1
        while animRunning do
            if execEntry and execEntry.Parent then
                execEntry.Text = "> " .. t("executing_clipboard"):gsub("%.+", dots[idx])
            end
            idx = idx % 3 + 1
            task.wait(0.4)
        end
    end)
    task.spawn(function()
        local fn, compileErr = loadstring(result)
        if not fn then
            animRunning = false
            if scanCtrl then scanCtrl.Cancel() end
            clearExecHighlights()
            _G.__DeltaUI_skipLineOffset = nil
            local errLine = parseErrorLine(tostring(compileErr))
            if errLine then
                jumpToErrorLine(errLine)
            end
            AddLog("[Error] " .. tostring(compileErr), "error")
            ShowNotification(t("execution_error_notify"), 3, function()
                switchPage("terminal")
            end)
            return
        end
        local oldPrint = print
        local oldWarn = warn
        print = function(...)
            local args = {...}
            local msg = table.concat(args, " ")
            AddLog(msg, "info")
            if logDedup then logDedup[msg] = tick() end
            oldPrint(...)
        end
        warn = function(...)
            local args = {...}
            local msg = table.concat(args, " ")
            AddLog(msg, "warn")
            if logDedup then logDedup[msg] = tick() end
            oldWarn(...)
        end
            _G.__DeltaUI_blockLogService = true
        local ok, execErr = xpcall(fn, function(err)
            return debug.traceback(tostring(err), 2)
        end)
            _G.__DeltaUI_blockLogService = nil
        print = oldPrint
        warn = oldWarn
        animRunning = false
        if scanCtrl then scanCtrl.Cancel() end
        if not ok then
            clearExecHighlights()
            _G.__DeltaUI_skipLineOffset = nil
            local errLine = parseErrorLine(tostring(execErr))
            if errLine then
                highlightExecLine(errLine, "error")
                scrollToLine(errLine, 3)
            end
            AddLog("[Error] " .. tostring(execErr), "error")
            ShowNotification(t("execution_error_notify"), 3, function()
                switchPage("terminal")
            end)
            return
        end
        clearExecHighlights()
        currentCodePage = 999999
        showCurrentPage()
        local pageText = codeBox.Text or ""
        local lastLine = select(2, pageText:gsub(string.char(10), "")) + 1
        if lastLine > 0 then
            highlightExecLine(lastLine, "success")
            scrollToLine(lastLine, 3)
        end
        task.delay(0.8, clearExecHighlights)
        AddLog("> " .. t("clipboard_finished"), "info")
        if execEntry and execEntry.Parent then
            execEntry.Text = "> " .. t("clipboard_finished")
            execEntry.TextColor3 = Color3.fromRGB(100, 180, 255)
        end
        _G.__DeltaUI_skipLineOffset = nil
    end)
end)
consolePage = create("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 2})
consolePage.Parent = contentFrame

consoleEnabled = true

consoleClearBtn = create("TextButton", {
    Position = UDim2.new(0, 12, 1, -36),
    Size = UDim2.new(0, 80, 0, 28),
    BackgroundColor3 = theme.surface,
    BackgroundTransparency = 0.25,
    Text = "",
    BorderSizePixel = 0,
    ZIndex = 5
})
corner(6, consoleClearBtn)
stroke(theme.border, 1, consoleClearBtn)
consoleClearBtn.Parent = consolePage
consoleClearIcon = GetIcon("trash-2", UDim2.new(0, 12, 0, 12), theme.textDim)
if consoleClearIcon then
    consoleClearIcon.Position = UDim2.new(0, 8, 0.5, -6)
    consoleClearIcon.Parent = consoleClearBtn
end
consoleClearText = create("TextLabel", {
    Position = UDim2.new(0, 26, 0, 0),
    Size = UDim2.new(1, -28, 1, 0),
    BackgroundTransparency = 1,
    Text = t("clear"),
    TextColor3 = theme.text,
    TextSize = 11,
    Font = Enum.Font.SourceSansBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 6
})
consoleClearText.Parent = consoleClearBtn
table.insert(settingsData.uiRefs, {element = consoleClearText, key = "clear"})
consoleClearBtn.MouseButton1Click:Connect(function()
    for _, child in pairs(consoleScroll:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    logEntryCount = 0
    AddLog("> Console cleared", "info")
end)
local consoleHeader = create("Frame", {Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = theme.surfaceLight, BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 3})
corner(theme.radius, consoleHeader)
stroke(theme.border, 1, consoleHeader)
consoleHeader.Parent = consolePage
consoleTitle = create("TextLabel", {Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -60, 1, 0), BackgroundTransparency = 1, Text = t("console"), TextColor3 = theme.textDim, TextSize = 12, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 4})
consoleTitle.Parent = consoleHeader
table.insert(settingsData.uiRefs, {element = consoleTitle, key = "console"})

consoleSettingsBtn = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -8, 0.5, 0),
    Size = UDim2.new(0, 26, 0, 26),
    BackgroundColor3 = theme.surfaceLight,
    BackgroundTransparency = 1,
    Text = "",
    BorderSizePixel = 0,
    ZIndex = 5
})
corner(6, consoleSettingsBtn)
consoleSettingsBtn.Parent = consoleHeader
local consoleSettingsIcon = GetIcon("cog", UDim2.new(0, 14, 0, 14), theme.textDim)
if consoleSettingsIcon then
    consoleSettingsIcon.Position = UDim2.new(0.5, -7, 0.5, -7)
    consoleSettingsIcon.Parent = consoleSettingsBtn
end
consoleSettingsBtn.MouseButton1Click:Connect(function()
    switchPage("settings")
    task.wait(0.05)
    if not settingsScroll or not settingsScroll.Parent then return end
    local targetRow = nil
    for _, child in pairs(settingsScroll:GetChildren()) do
        if child:IsA("Frame") and child.LayoutOrder == 10 then
            targetRow = child
            break
        end
    end
    if not targetRow then return end
    local targetY = targetRow.AbsolutePosition.Y - settingsScroll.AbsolutePosition.Y - 12
    targetY = math.max(0, targetY)
    local maxY = math.max(0, settingsScroll.CanvasSize.Y.Offset - settingsScroll.AbsoluteSize.Y)
    targetY = math.min(targetY, maxY)
    svc.TweenService:Create(settingsScroll, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        CanvasPosition = Vector2.new(0, targetY)
    }):Play()
end)

consoleScroll = create("ScrollingFrame", {Position = UDim2.new(0, 0, 0, 36), Size = UDim2.new(1, -0, 1, -84), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollBarImageColor3 = theme.textDim, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 3})
create("UIPadding", {PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12)}).Parent = consoleScroll
consoleScroll.Parent = consolePage

consoleList = create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)})
consoleList.Parent = consoleScroll
create("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6)}).Parent = consoleScroll

logService = game:GetService("LogService")
lastLogTime = 0
logDedup = {}
logService.MessageOut:Connect(function(msg, msgtype)
    if _G.__DeltaUI_blockLogService then return end
    local msgStr = tostring(msg)

    if msgStr:find("Overlay is not a valid member of ImageLabel")
        or msgStr:find("Error is not a valid member of Folder")
        or msgStr:find("ConsoleElements")
        or msgStr:find("AppDelegate")
        or msgStr:find("Arrow is not a valid member of ImageButton")
    then
        return

    end
    if settingsData.blockServerErrors and msgStr:find("ReplicatedStorage.") then
        return
    end
    if settingsData.blockAssetErrors then
        if msgStr:find("rbxassetid")
            or msgStr:find("assetdelivery")
            or msgStr:find("Animation failed to load")
            or msgStr:find("Failed to load animation")
            or msgStr:find("Failed to load")
            or msgStr:find("SurfaceAppearance")
            or msgStr:find("sanitized ID")
            or msgStr:find("assetId")
            or msgStr:find("rbx://")
        then
            return
        end
    end

    local now = tick()
    local key = (msgStr:gsub("  ", " "))
    if logDedup[key] and (now - logDedup[key]) < 2 then
        return
    end
    logDedup[key] = now

    if next(logDedup) ~= nil and now % 30 < 0.1 then
        for k, v in pairs(logDedup) do
            if now - v > 10 then
                logDedup[k] = nil
            end
        end
    end
    local level = "info"
    if msgtype == Enum.MessageType.MessageWarning then level = "warn"
    elseif msgtype == Enum.MessageType.MessageError then level = "error" end
    AddLog(msg, level)
end)
consoleList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    if consoleScroll and consoleList and consoleScroll.Parent then
        local absSize = consoleList.AbsoluteContentSize
        if absSize then
            consoleScroll.CanvasSize = UDim2.new(0, 0, 0, absSize.Y + 20)
        end
    end
end)

scrollTrack = create("Frame", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -2, 0, 32),
    Size = UDim2.new(0, 6, 1, -34),
    BackgroundColor3 = theme.surface,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 2
})
corner(3, scrollTrack)
scrollTrack.Parent = consolePage
gamepadPage = create("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 2})
gamepadPage.Parent = contentFrame
updateBtn = create("TextButton", {
    Position = UDim2.new(0, 12, 0, 12),
    Size = UDim2.new(0, 110, 0, 26),
    BackgroundColor3 = theme.accent,
    BackgroundTransparency = 0.25,
    Text = "",
    BorderSizePixel = 0,
    ZIndex = 5
})
applyGradient(updateBtn, theme.accent, theme.accent2, 120)
corner(8, updateBtn)
stroke(theme.accent, 1, updateBtn)
updateBtn.Parent = gamepadPage

refreshBtn = create("TextButton", {
    Position = UDim2.new(1, -40, 0, 12),
    Size = UDim2.new(0, 32, 0, 26),
    BackgroundColor3 = theme.surface,
    BackgroundTransparency = 0.25,
    Text = "",
    BorderSizePixel = 0,
    ZIndex = 5
})
corner(8, refreshBtn)
stroke(theme.border, 1, refreshBtn)
refreshBtn.Parent = gamepadPage
refreshIcon = GetIcon("rotate-ccw", UDim2.new(0, 14, 0, 14), theme.text)
if refreshIcon then
    refreshIcon.Position = UDim2.new(0.5, -7, 0.5, -7)
    refreshIcon.Parent = refreshBtn
end
refreshBtn.MouseButton1Click:Connect(function()
    if refreshIcon then
        local rotation = 0
        local conn = svc.RunService.RenderStepped:Connect(function(dt)
            rotation = rotation - 720 * dt
            refreshIcon.Rotation = rotation
        end)
        task.delay(0.5, function()
            conn:Disconnect()
            refreshIcon.Rotation = 0
        end)
    end
    refreshScriptList(searchInput.Text)
    ShowNotification(t("refresh_complete"), 1)
end)

updateIcon = GetIcon("download", UDim2.new(0, 12, 0, 12), Color3.fromRGB(255,255,255))
if updateIcon then
    updateIcon.Position = UDim2.new(0, 8, 0.5, -6)
    updateIcon.Parent = updateBtn
end
updateText = create("TextLabel", {Position = UDim2.new(0, 26, 0, 0), Size = UDim2.new(0, 60, 1, 0), BackgroundTransparency = 1, Text = t("save"), TextColor3 = Color3.fromRGB(255,255,255), TextSize = 12, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 6})
updateText.Parent = updateBtn
table.insert(settingsData.uiRefs, {element = updateText, key = "save"})
modalOverlay = create("Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
    BackgroundTransparency = 0.7,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 200,
    Active = true
})
modalOverlay.Parent = screenGui

searchBox = create("Frame", {
    Position = UDim2.new(0, 130, 0, 12),
    Size = UDim2.new(1, -178, 0, 26),
    BackgroundColor3 = theme.surface,
    BackgroundTransparency = 0.25,
    BorderSizePixel = 0,
    ZIndex = 5
})
corner(8, searchBox)
searchBox.Parent = gamepadPage
searchIcon = GetIcon("search", UDim2.new(0, 12, 0, 12), theme.textDim)
if searchIcon then
    searchIcon.Position = UDim2.new(0, 8, 0.5, -6)
    searchIcon.Parent = searchBox
end
searchInput = create("TextBox", {
    Position = UDim2.new(0, 26, 0, 0),
    Size = UDim2.new(1, -32, 1, 0),
    BackgroundTransparency = 1,
    Text = "",
    PlaceholderText = t("search_scripts"),
    PlaceholderColor3 = theme.textDim,
    TextColor3 = theme.text,
    TextSize = 12,
    Font = Enum.Font.SourceSans,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    ClearTextOnFocus = false,
    ZIndex = 6
})
searchInput.Parent = searchBox
create("UIPadding", {PaddingLeft = UDim.new(0, 5)}).Parent = searchInput
table.insert(settingsData.uiRefs, {element = searchInput, key = "search_scripts"})
searchInput:GetPropertyChangedSignal("Text"):Connect(function()
    refreshScriptList(searchInput.Text)
end)
scriptListScroll = create("ScrollingFrame", {
    Position = UDim2.new(0, 12, 0, 52),
    Size = UDim2.new(1, -24, 1, -64),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = theme.textDim,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ZIndex = 3
})
scriptListScroll.Parent = gamepadPage
scriptListLayout = create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8)})
scriptListLayout.Parent = scriptListScroll
create("UIPadding", {PaddingLeft = UDim.new(0, 0), PaddingRight = UDim.new(0, 0), PaddingTop = UDim.new(0, 0), PaddingBottom = UDim.new(0, 8)}).Parent = scriptListScroll
modalCard = create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, 340, 0, 340),
    BackgroundColor3 = theme.surface,
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    ZIndex = 201,
    Active = true
})
corner(16, modalCard)
modalCard.Parent = modalOverlay
modalTitle = create("TextLabel", {
    Position = UDim2.new(0, 20, 0, 16),
    Size = UDim2.new(1, -40, 0, 28),
    BackgroundTransparency = 1,
    Text = t("Enter Details"),
    TextColor3 = theme.text,
    TextSize = 18,
    Font = Enum.Font.SourceSansBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 202
})
modalTitle.Parent = modalCard
modalSub = create("TextLabel", {
    Position = UDim2.new(0, 20, 0, 46),
    Size = UDim2.new(1, -40, 0, 40),
    BackgroundTransparency = 1,
    Text = t("Complete the necessary parameters to upload your client script"),
    TextColor3 = theme.textDim,
    TextSize = 12,
    Font = Enum.Font.SourceSans,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextWrapped = true,
    ZIndex = 202
})
modalSub.Parent = modalCard
modalClose = create("TextButton", {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -16, 0, 16),
    Size = UDim2.new(0, 28, 0, 28),
    BackgroundTransparency = 1,
    Text = "",
    ZIndex = 203
})
modalCloseIcon = GetIcon("x", UDim2.new(0, 18, 0, 18), theme.textDim)
if modalCloseIcon then
    modalCloseIcon.Position = UDim2.new(0.5, -9, 0.5, -9)
    modalCloseIcon.Parent = modalClose
end
modalClose.Parent = modalCard
modalClose.MouseButton1Click:Connect(function()
    modalOverlay.Visible = false
end)
titleBox = create("Frame", {
    Position = UDim2.new(0, 20, 0, 96),
    Size = UDim2.new(1, -40, 0, 56),
    BackgroundColor3 = theme.surfaceLight,
    BackgroundTransparency = 0.4,
    BorderSizePixel = 0,
    ZIndex = 202
})
corner(12, titleBox)
stroke(theme.border, 1, titleBox)
titleBox.Parent = modalCard
titleLabel = create("TextLabel", {
    Position = UDim2.new(0, 12, 0, 8),
    Size = UDim2.new(1, -24, 0, 18),
    BackgroundTransparency = 1,
    Text = t("Title"),
    TextColor3 = theme.textDim,
    TextSize = 11,
    Font = Enum.Font.SourceSansBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 203
})
titleLabel.Parent = titleBox
titleInput = create("TextBox", {
    Position = UDim2.new(0, 12, 0, 26),
    Size = UDim2.new(1, -24, 0, 26),
    BackgroundTransparency = 1,
    Text = "",
    PlaceholderText = t("Enter Your Title..."),
    PlaceholderColor3 = theme.textDim,
    TextColor3 = theme.text,
    TextSize = 14,
    Font = Enum.Font.SourceSans,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Center,
    ClearTextOnFocus = false,
    ZIndex = 203
})
titleInput.Parent = titleBox
create("UIPadding", {PaddingLeft = UDim.new(0, 5)}).Parent = titleInput
scriptBox = create("Frame", {
    Position = UDim2.new(0, 20, 0, 164),
    Size = UDim2.new(1, -40, 0, 110),
    BackgroundColor3 = theme.surfaceLight,
    BackgroundTransparency = 0.4,
    BorderSizePixel = 0,
    ZIndex = 202
})
corner(12, scriptBox)
stroke(theme.border, 1, scriptBox)
scriptBox.Parent = modalCard
scriptLabel = create("TextLabel", {
    Position = UDim2.new(0, 12, 0, 8),
    Size = UDim2.new(1, -24, 0, 18),
    BackgroundTransparency = 1,
    Text = t("Script"),
    TextColor3 = theme.textDim,
    TextSize = 11,
    Font = Enum.Font.SourceSansBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 203
})
scriptLabel.Parent = scriptBox
scriptInput = create("TextBox", {
    Position = UDim2.new(0, 12, 0, 28),
    Size = UDim2.new(1, -24, 1, -36),
    BackgroundTransparency = 1,
    Text = "",
    PlaceholderText = t("Enter Your Script..."),
    PlaceholderColor3 = theme.textDim,
    TextColor3 = theme.text,
    TextSize = 13,
    Font = Enum.Font.Code,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    ClearTextOnFocus = false,
    MultiLine = true,
    TextWrapped = true,
    ZIndex = 203
})
scriptInput.Parent = scriptBox
create("UIPadding", {PaddingLeft = UDim.new(0, 5)}).Parent = scriptInput

updateBtn.MouseButton1Click:Connect(function()
    modalOverlay.Visible = true
    titleInput.Text = t("title_placeholder")
    scriptInput.Text = t("script_placeholder")
end)
addScriptBtn = create("TextButton", {
    Position = UDim2.new(0, 20, 1, -52),
    Size = UDim2.new(1, -40, 0, 40),
    BackgroundColor3 = theme.accent,
    BackgroundTransparency = 0.25,
    Text = "",
    BorderSizePixel = 0,
    ZIndex = 202
})
applyGradient(addScriptBtn, theme.accent, theme.accent2, 120)
corner(10, addScriptBtn)
addScriptBtn.Parent = modalCard
addScriptText = create("TextLabel", {
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = t("Add Script"),
    TextColor3 = Color3.fromRGB(255,255,255),
    TextSize = 14,
    Font = Enum.Font.SourceSansBold,
    ZIndex = 203
})
addScriptText.Parent = addScriptBtn
addScriptBtn.MouseButton1Click:Connect(function()
    if addScriptBtn.Active == false then return end
    addScriptBtn.Active = false
    local title = titleInput.Text
    local scriptCode = scriptInput.Text
    if title == "" or title == t("title_placeholder") then
        addScriptBtn.Active = true
        return
    end
    if scriptCode == "" or scriptCode == t("script_placeholder") then
        addScriptBtn.Active = true
        return
    end
    ensureFolder()
    writefile(saveFolder .. "/" .. title, scriptCode)
    modalOverlay.Visible = false
    task.wait(0.1)
    refreshScriptList("")
    addScriptBtn.Active = true
end)
-- ================= BuildSpace (建造空间) =================
-- 点击「进入建造空间」：主 UI 渐隐 -> 顶部下滑弹出横向切换器 + 中心渐显「其他选项」窗口
buildSpaceActive = false
buildSpaceRoot = nil
buildSpaceTab = "build"
buildSpaceSavedPage = nil
orbWasVisibleBeforeBuildSpace = false

obState = {expanded = {}, selected = nil, query = "", budget = 0}
obRows = {}
obContextPanel = nil       -- 长按弹出的操作面板
obContextTarget = nil      -- 当前面板关联的对象 path
obContextOpenedAt = 0      -- 面板打开时刻(tick)，用于忽略松手瞬时的 MouseButton1Click
obContextClosedAt = 0      -- 面板关闭时刻(tick)：那次点击只用于“收起面板”，不应再顺手选中某一行
obClipboard = nil            -- 长按「复制对象」暂存的源对象 {path=, class=, name=}，用于两个粘贴项
propSignature = nil          -- 属性浏览器上次渲染的内容签名（值没变就不重建行，保住滚动位置）

local OB_MAX_ROWS = 260
local OB_SCAN_BUDGET = 1400

-- 长按调出面板：阈值 0.5s；拖动超过此像素视为滚动/拖动，取消长按
local OB_LONG_HOLD_SEC = 0.5
local OB_LONG_DRAG_PX = 8

function obResolve(path)
    if type(path) ~= "table" or #path == 0 then return nil end
    local ok, node = pcall(function() return game:GetService(path[1]) end)
    if not ok or not node then return nil end
    for i = 2, #path do
        local child
        ok, child = pcall(function() return node:FindFirstChild(path[i]) end)
        if not ok or not child then return nil end
        node = child
    end
    return node
end

function obKey(path)
    return table.concat(path, "\1")
end

-- 顶层服务判定（Workspace / Players / ReplicatedStorage / CoreGui）。
-- 这些节点是整台客户端运行的地基：删掉或整体复制它们会连带销毁/复制所有子级，
-- 属于不可逆操作，所以浏览器里只允许把它们当作「粘贴落点」，不允许复制与删除。
-- 两条判据并用：路径只剩一段(树的第一层)，或解析出来直接挂在 DataModel 下。
function obIsRootService(node, path)
    if type(path) == "table" and #path <= 1 then return true end
    if not node then return false end
    local ok, isUnderGame = pcall(function() return node.Parent == game end)
    return ok and isUnderGame == true
end

function obChildCount(node)
    if not node then return 0 end
    local ok, n = pcall(function() return #node:GetChildren() end)
    if ok and n then return n end
    return 0
end

function obClassIcon(class)
    if class == "Workspace" then return "mountain-snow" end
    if class == "Players" then return "users-round" end
    if class == "ReplicatedStorage" then return "server-plus" end
    if class == "CoreGui" then return "picture-in-picture-2" end
    if class == "PlayerGui" then return "picture-in-picture-2" end  -- 与 CoreGui 同款图标
    if class == "Folder" then return "folder" end
    if class == "ModuleScript" then return "package-open" end
    -- 对象树预览器：精确匹配优先于下方模糊匹配
    if class == "RemoteFunction" then return "shredder" end
    if class == "RemoteEvent" then return "shredder" end
    if class == "NumberValue" then return "file-digit" end        -- 白色 file-digit（数字文件）
    if class == "BoolValue" then return "sigma" end              -- 白色 sigma（布尔/逻辑值）
    if class == "StringValue" then return "square-sigma" end
    if class == "IntValue" then return "square-kanban" end      -- 白色 square-kanban
    if class == "Backpack" then return "backpack" end           -- 黄色 backpack
    if class == "Player" then return "user-round" end           -- 蓝色 user-round
    if class == "Humanoid" then return "person-standing" end    -- 黄色 person-standing（站姿小人）
    if class == "StarterGear" then return "user-cog" end        -- 绿色 user-cog
    if class == "ObjectValue" then return "square-dashed-kanban" end  -- 白色 square-dashed-kanban
    if class == "LocalizationTable" then return "languages" end  -- 绿色 languages
    if class == "ImageButton" then return "images" end
    if class == "TextButton" then return "type" end
    if class == "ScreenGui" then return "app-window" end
    if class == "UICorner" then return "square-round-corner" end
    if class == "UIStroke" then return "frame" end
    if class == "TextLabel" then return "tag" end
    if class == "ImageLabel" then return "images" end
    if class == "PackageLink" then return "link" end
    if class == "StyleLink" then return "link-2" end     -- StyleLink 使用 link-2（不区分大小写）
    -- UI 组件类：精确匹配（白色系图标）
    if class == "UIDragDetector" then return "alarm-smoke" end            -- 白色 alarm-smoke（烟雾/拖拽检测器）
    if class == "UIListLayout" then return "list-ordered" end             -- 白色 list-ordered（列表布局）
    if class == "UIPadding" then return "panel-left-dashed" end          -- 白色 panel-left-dashed（内边距）
    if class == "UIAspectRatioConstraint" then return "proportions" end  -- 白色 proportions（宽高比约束）
    -- Configuration / Folder 类变体：精确匹配，避免被下方 find("Script") 误伤
    if class == "Configuration" then return "settings-2" end
    if class == "ConfigurationFolder" then return "settings-2" end
    if class == "StyleSheet" then return "palette" end
    if class:find("Script") then return "file-code" end
    if class:find("Part") or class:find("Model") then return "box" end
    if class:find("Sound") then return "volume-2" end
    if class:find("Lighting") then return "sun" end
    if class:find("Camera") then return "camera" end
    if class:find("Attractor") or class:find("Force") then return "magnet" end
    -- Frame / ScrollingFrame 精确匹配放在末尾，避免被上方 find("Gui")/find("Frame") 兜底抢走
    if class == "ScrollingFrame" then return "gallery-vertical-end" end  -- 黄色 gallery-vertical-end
    if class == "Frame" then return "square-dashed-top-solid" end        -- 黄色 square-dashed-top-solid
    if class:find("Gui") or class:find("Frame") then return "layout" end
    return "layers"
end

-- 按 ClassName 着色的图标颜色
OB_CLASS_COLORS = {
    Workspace = Color3.fromRGB(57, 214, 146),
    Players = Color3.fromRGB(56, 189, 248),
    ReplicatedStorage = Color3.fromRGB(56, 189, 248),
    CoreGui = Color3.fromRGB(56, 189, 248),
    PlayerGui = Color3.fromRGB(56, 189, 248),  -- 与 CoreGui 同色（蓝色）
    Folder = Color3.fromRGB(255, 196, 66),
    Model = Color3.fromRGB(255, 82, 104),
    Part = Color3.fromRGB(255, 255, 255),
    Terrain = Color3.fromRGB(57, 214, 146),
    Script = Color3.fromRGB(57, 214, 146),
    ModuleScript = Color3.fromRGB(255, 152, 66),
    RemoteFunction = Color3.fromRGB(139, 92, 246),   -- 紫色 (accent2)
    RemoteEvent = Color3.fromRGB(255, 196, 66),        -- 黄色
    StringValue = Color3.fromRGB(255, 255, 255),       -- 白色
    IntValue = Color3.fromRGB(255, 255, 255),          -- 白色 (square-kanban)
    NumberValue = Color3.fromRGB(255, 255, 255),       -- 白色 (file-digit)
    BoolValue = Color3.fromRGB(255, 255, 255),         -- 白色 (sigma)
    ScrollingFrame = Color3.fromRGB(255, 196, 66),     -- 黄色 (gallery-vertical-end)
    Frame = Color3.fromRGB(255, 196, 66),              -- 黄色 (square-dashed-top-solid)
    Backpack = Color3.fromRGB(255, 196, 66),           -- 黄色 (backpack)
    Player = Color3.fromRGB(56, 189, 248),             -- 蓝色 (user-round)
    Humanoid = Color3.fromRGB(255, 196, 66),           -- 黄色 (person-standing)
    ImageButton = Color3.fromRGB(57, 214, 146),        -- 绿色
    TextButton = Color3.fromRGB(255, 196, 66),         -- 黄色
    ScreenGui = Color3.fromRGB(56, 189, 248),          -- 蓝色
    UICorner = Color3.fromRGB(255, 255, 255),          -- 白色
    UIStroke = Color3.fromRGB(255, 255, 255),          -- 白色
    TextLabel = Color3.fromRGB(56, 189, 248),          -- 蓝色
    ImageLabel = Color3.fromRGB(57, 214, 146),         -- 绿色
    PackageLink = Color3.fromRGB(56, 189, 248),          -- 蓝色
    StyleLink = Color3.fromRGB(139, 92, 246),          -- 紫色 (link-2)
    Configuration = Color3.fromRGB(255, 196, 66),      -- 黄色 (settings-2)
    ConfigurationFolder = Color3.fromRGB(255, 196, 66), -- 黄色 (settings-2)
    StyleSheet = Color3.fromRGB(56, 189, 248),         -- 蓝色 (palette)
    StarterGear = Color3.fromRGB(57, 214, 146),        -- 绿色 (user-cog)
    ObjectValue = Color3.fromRGB(255, 255, 255),       -- 白色 (square-dashed-kanban)
    UIDragDetector = Color3.fromRGB(255, 255, 255),       -- 白色 (alarm-smoke)
    UIListLayout = Color3.fromRGB(255, 255, 255),        -- 白色 (list-ordered)
    UIPadding = Color3.fromRGB(255, 255, 255),           -- 白色 (panel-left-dashed)
    UIAspectRatioConstraint = Color3.fromRGB(255, 255, 255), -- 白色 (proportions)
    LocalizationTable = Color3.fromRGB(57, 214, 146),  -- 绿色 (languages)
}
-- 归一化类名 -> 颜色（大小写不敏感，含常见 Part 变体）
OB_CLASS_COLOR_KEYS = {
    workspace = "Workspace",
    players = "Players",
    replicatedstorage = "ReplicatedStorage",
    coregui = "CoreGui",
    playergui = "PlayerGui",  -- 与 CoreGui 同款图标/颜色，大小写不敏感
    folder = "Folder",
    scriptfolder = "Folder",
    model = "Model",
    terrain = "Terrain",
    modulescript = "ModuleScript",
    script = "Script",
    localscript = "Script",
    remotefunction = "RemoteFunction",
    remoteevent = "RemoteEvent",
    stringvalue = "StringValue",
    intvalue = "IntValue",
    numbervalue = "NumberValue",
    boolvalue = "BoolValue",
    scrollingframe = "ScrollingFrame",
    frame = "Frame",
    backpack = "Backpack",
    player = "Player",
    humanoid = "Humanoid",
    imagebutton = "ImageButton",
    textbutton = "TextButton",
    screengui = "ScreenGui",
    uicorner = "UICorner",
    uistroke = "UIStroke",
    textlabel = "TextLabel",
    imagelabel = "ImageLabel",
    packagelink = "PackageLink",
    stylelink = "StyleLink",           -- StyleLink（link-2），大小写不敏感
    configuration = "Configuration",
    configurationfolder = "ConfigurationFolder",
    stylesheet = "StyleSheet",
    startergear = "StarterGear",
    objectvalue = "ObjectValue",
    uilistlayout = "UIListLayout",
    uipadding = "UIPadding",
    uiAspectRatioConstraint = "UIAspectRatioConstraint",
    uiAspectratioconstraint = "UIAspectRatioConstraint",
    uidragdetector = "UIDragDetector",
    localizationtable = "LocalizationTable",
    part = "Part",
    meshpart = "Part",
    basepart = "Part",
    spawnlocation = "Part",
    unionoperation = "Part",
    wedges = "Part",
    filemesh = "Part",
    truss = "Part",
}

function obClassColor(class)
    if type(class) ~= "string" then return theme.textDim end
    local lc = class:lower()
    -- 全大小写不敏感：先在归一化键表中查，再走关键字兜底
    local key = OB_CLASS_COLOR_KEYS[lc]
    if not key and lc:find("part") then key = "Part" end
    if not key and lc:find("script") then key = "Script" end
    if not key and lc:find("model") then key = "Model" end
    if not key and lc:find("configuration") then key = "Configuration" end
    if not key and lc:find("style") then key = "StyleSheet" end
    return (key and OB_CLASS_COLORS[key]) or theme.textDim
end

function obSelectedPathText()
    if not obState.selected then return nil end
    local txt = 'game:GetService("' .. tostring(obState.selected[1]) .. '")'
    for i = 2, #obState.selected do
        txt = txt .. ':FindFirstChild("' .. tostring(obState.selected[i]) .. '")'
    end
    -- 自己玩家的路径统一换成 LocalPlayer：
    --   game:GetService("Players"):FindFirstChild("自己的用户名"):...
    --   -> game:GetService("Players").LocalPlayer:...
    -- 仅替换紧跟 GetService("Players") 之后的「自己名字」那一段，
    -- 其它玩家、其它服务不受影响。
    local lpName = svc and svc.Players and svc.Players.LocalPlayer
        and svc.Players.LocalPlayer.Name
    if lpName and obState.selected[1] == "Players" then
        local own = tostring(lpName)
        local pattern = ':FindFirstChild("' .. own .. '")'
        if txt:find(pattern, 1, true) then
            txt = txt:gsub(pattern, ".LocalPlayer", 1)
        end
    end
    return txt
end

-- 底部路径显示的最大字符数（超出则从头部省略，末尾指向始终保留）
OB_PATH_MAX = 15

-- 按「字符数」而非字节计算长度，兼容中文对象名
function obCharLen(s)
    if type(s) ~= "string" then return 0 end
    local ok, n = pcall(function() return utf8.len(s) end)
    if ok and type(n) == "number" then return n end
    return #s
end

-- 取字符串末尾 n 个字符（utf8 安全，不会截出半个汉字）
function obTail(s, n)
    if type(s) ~= "string" or s == "" or n <= 0 then return "" end
    local ok, off = pcall(function() return utf8.offset(s, -n) end)
    if ok and type(off) == "number" and off > 0 then return s:sub(off) end
    return s:sub(math.max(1, #s - n + 1))
end

-- 路径超长时的显示策略：
--   1) 始终保留开头前缀（如 game:GetService("Workspace"）至少 10 个字符，绝不省略成 … 开头就只剩尾
--   2) 剩余预算给末尾最后一段 ("Name")，保证「指向谁」一眼可见
--   3) 中间放 1 个 …
-- 例：game:GetService("Workspace"):FindFirstChild("Players"):FindFirstChild("VeryLongName")
--      -> game:GetService("Workspace"):…:FindFirstChild("VeryLongName")
function obTruncatePath(txt)
    if type(txt) ~= "string" or txt == "" then return txt end
    if obCharLen(txt) <= OB_PATH_MAX then return txt end

    -- 解析末尾最后一段名字（"Name"），尽量完整保留
    local name = txt:match('^.*%("([^"]*)"%)%s*$')
    local tail = name and ('("' .. name .. '")') or ""

    -- 安全下限：前缀至少 10 字符；格式为 前缀 + "…" + 末尾段，故最少需 PREFIX_MIN + 1 + 1
    local PREFIX_MIN = 10
    local MIN_BUDGET = PREFIX_MIN + 2   -- 前缀10 + 省略号 + 末尾至少1
    local budget = OB_PATH_MAX
    if budget < MIN_BUDGET then budget = MIN_BUDGET end

    -- 计算末尾段（尽量完整保留 ("Name")）
    local tailLen = obCharLen(tail)
    local tailPart = ""
    if tailLen > 0 then
        -- 留给前缀的字符数 = 总预算 - 省略号(1) - 末尾段长度
        local reservedForPrefix = budget - 1 - tailLen
        if reservedForPrefix < PREFIX_MIN then
            -- 末尾名字太长，连压缩后都塞不下 → 压缩名字到 1 字符
            local nameKeep = 1
            tailPart = '…("' .. obTail(name, nameKeep) .. '")'
            reservedForPrefix = budget - 1 - obCharLen(tailPart)
            if reservedForPrefix < PREFIX_MIN then
                reservedForPrefix = PREFIX_MIN
            end
        else
            tailPart = tail
        end
    end

    -- 拼装：前缀(至少10) + … + 末尾段
    local prefix = txt:sub(1, PREFIX_MIN)   -- 先无条件保底前 10 字符
    local reservedForPrefix = budget - 1 - obCharLen(tailPart)
    if reservedForPrefix > PREFIX_MIN then
        prefix = txt:sub(1, reservedForPrefix)
    end
    if tailPart ~= "" then
        return prefix .. "…" .. tailPart
    end
    -- 无末尾段（路径格式异常）时的退化：前缀 + … + 文本尾部，且尾部不超预算
    local restBudget = budget - PREFIX_MIN - 1
    local rest = obTail(txt, math.max(1, restBudget))
    return prefix .. "…" .. rest
end

function obCopyText(txt)
    local setclip = setclipboard or toclipboard or (syn and syn.setclipboard) or (clipboard and clipboard.set)
    if not setclip then return false end
    return pcall(setclip, txt)
end

function obHasChildren(inst)
    local ok, empty = pcall(function() return #inst:GetChildren() == 0 end)
    return ok and not empty
end

function obArrange(kids)
    local heads, tails = {}, {}
    for _, inst in ipairs(kids) do
        if obHasChildren(inst) then
            table.insert(heads, inst)
        else
            table.insert(tails, inst)
        end
    end
    if #tails == 0 or #heads == 0 then return kids end
    local ordered = {}
    for _, inst in ipairs(heads) do ordered[#ordered + 1] = inst end
    for _, inst in ipairs(tails) do ordered[#ordered + 1] = inst end
    return ordered
end

function obMatches(node, q)
    local okName, nm = pcall(function() return node.Name end)
    if not okName then return false end
    if nm:lower():find(q, 1, true) then return true end
    local okClass, cl = pcall(function() return node.ClassName end)
    if okClass and cl and cl:lower():find(q, 1, true) then return true end
    return false
end

-- q=nil -> 只取直接子级；q=字符串 -> 在子树内深度优先搜索
function obCollect(node, path, q, depth, out)
    if obState.budget <= 0 then return end
    local kids
    local ok, res = pcall(function() return node:GetChildren() end)
    if not ok or not res then return end
    kids = res
    -- 同一层内：含子对象的排在前面，其后才是叶子节点
    kids = obArrange(kids)
    for _, child in ipairs(kids) do
        if obState.budget <= 0 then return end
        obState.budget = obState.budget - 1
        local cp = {}
        for i = 1, #path do cp[i] = path[i] end
        local okN, n = pcall(function() return child.Name end)
        local cname = (okN and n) or ("?_" .. tostring(#out))
        cp[#cp + 1] = cname
        local cclass
        local okC, cl = pcall(function() return child.ClassName end)
        cclass = (okC and cl) or "?"
        local hasKids = obHasChildren(child)
        if not q or (depth < 10 and obMatches(child, q)) then
            table.insert(out, {path = cp, name = cname, class = cclass, depth = depth, hasKids = hasKids})
        end
        local key = obKey(cp)
        if q then
            if depth < 8 and obState.budget > 0 then obCollect(child, cp, q, depth + 1, out) end
        elseif obState.expanded[key] then
            obCollect(child, cp, nil, depth + 1, out)
        end
        if #out >= OB_MAX_ROWS then obState.budget = 0 return end
    end
end

function obToggle(path)
    local key = obKey(path)
    if obState.query and obState.query ~= "" then
        obState.query = ""
        if obSearchInput then obSearchInput.Text = "" end
        obState.expanded[key] = true
    else
        obState.expanded[key] = not obState.expanded[key]
    end
    obState.selected = path
    obRender()
end

-- 关闭（并销毁）长按操作面板
function obCloseContextPanel()
    if obContextPanel and obContextPanel.Parent then
        local p = obContextPanel
        svc.TweenService:Create(p, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {BackgroundTransparency = 1}):Play()
        for _, c in pairs(p:GetDescendants()) do
            if c:IsA("TextLabel") or c:IsA("TextButton") then
                svc.TweenService:Create(c, TweenInfo.new(0.16), {TextTransparency = 1}):Play()
            elseif c:IsA("Frame") then
                svc.TweenService:Create(c, TweenInfo.new(0.16), {BackgroundTransparency = 1}):Play()
            end
        end
        task.delay(0.18, function() if p and p.Parent then p:Destroy() end end)
    end
    obContextPanel = nil
    obContextTarget = nil
    obContextOpenedAt = 0
end

-- 获取屏幕尺寸：PlayerMouse 没有 ViewportSize 成员（那是 Camera/ViewportFrame 的属性），
-- 用 Mouse.ViewSizeX/Y 或 Camera.ViewportSize 或 UserInputService:GetMouseLocation 兜底。
-- 此前直接取 GetMouse().ViewportSize 会抛 "ViewportSize is not a valid member of PlayerMouse"。
local function obScreenSize()
    local mouse = svc.Players.LocalPlayer and svc.Players.LocalPlayer:GetMouse()
    if mouse and mouse.ViewSizeX and mouse.ViewSizeY then
        return Vector2.new(mouse.ViewSizeX, mouse.ViewSizeY)
    end
    local cam = workspace.CurrentCamera
    if cam and cam.ViewportSize and cam.ViewportSize.X > 100 then
        return cam.ViewportSize
    end
    local ok, loc = pcall(function() return svc.UserInputService:GetMouseLocation() end)
    if ok and loc then
        return Vector2.new(loc.X * 2, loc.Y * 2) -- GetMouseLocation 返回视口坐标，直接用做尺寸近似
    end
    return Vector2.new(1280, 720)
end

-- 把屏幕点裁切到 obWindow 可见区域内，返回 (x, y, 是否放得下)
local function obClampToWindow(x, y, w, h)
    local vp = obScreenSize()
    local maxX = math.max(0, vp.X - w - 8)
    local maxY = math.max(0, vp.Y - h - 8)
    return math.clamp(x, 8, maxX), math.clamp(y, 8, maxY)
end

-- 长按面板第 1 项：把对象记进内置剪贴板（只存路径，不写系统剪贴板、不再复制路径文本）
function obCopyToClipboard(data)
    local node = obResolve(data.path)
    if not node or not node.Parent then
        ShowNotification("该对象已不存在", 2)
        return
    end
    if obIsRootService(node, data.path) then
        ShowNotification("顶层服务不能整体复制，请复制它下面的对象", 2.5)
        return
    end
    local path = {}
    for i = 1, #data.path do path[i] = data.path[i] end
    obClipboard = { path = path, class = node.ClassName, name = node.Name }
    ShowNotification("已复制 " .. node.ClassName .. " \"" .. node.Name .. "\"", 1.5)
end

-- 取回剪贴板中的源对象；对象被删除/改名后视为失效并清空剪贴板。
-- 这里按路径回溯（与列表行一致的寻址方式），不直接持有实例引用，避免持有已销毁对象。
function obClipboardSource()
    local cb = obClipboard
    if not cb then return nil end
    local node = obResolve(cb.path)
    if not node or not node.Parent then
        obClipboard = nil
        return nil
    end
    return node
end

-- 粘贴：Clone 源对象。mode = "sibling" 挂到目标的同级(目标的父级)下，
-- "child" 挂到目标自身下面。同名时 Roblox 会自动改成 Part2 这种唯一名。
function obPasteClipboard(data, mode)
    local src = obClipboardSource()
    if not src then
        obClipboard = nil
        ShowNotification("剪贴板中的对象已失效", 2)
        return
    end
    local target = obResolve(data.path)
    if not target then
        ShowNotification("目标对象已不存在", 2)
        return
    end
    local parent
    if mode == "child" then
        parent = target
    else
        parent = target.Parent
        -- 同级粘贴需要一个真正的实例父级；根服务(Workspace 等)的父级是 DataModel，
        -- 把对象直接挂到 game 下会失败，浏览器里也没有这一层可以显示。
        if not parent or parent == game then
            ShowNotification("顶层对象没有同级位置，请改用「粘贴到下方」", 2.5)
            return
        end
    end
    -- 允许粘贴进自身：目标就是刚复制的对象时也照常执行。
    -- 真正的循环父级不可能出现——我们挂的是 Clone 出来的新实例，
    -- 源对象仍留在原来的父级下。
    local ok, clone = pcall(function() return src:Clone() end)
    if not ok or not clone then
        ShowNotification("粘贴失败：该对象无法被 Clone", 2.5)
        return
    end
    local ok2, err2 = pcall(function() clone.Parent = parent end)
    if not ok2 or not clone or not clone.Parent then
        pcall(function() if clone then clone:Destroy() end end)
        ShowNotification("粘贴失败：" .. tostring(err2), 3)
        return
    end
    -- 展开落点、并把选中项移到刚粘出来的对象上，底部路径栏同步显示它的位置
    local parentPath = {}
    local upTo = (mode == "child") and #data.path or (#data.path - 1)
    for i = 1, upTo do parentPath[i] = data.path[i] end
    if #parentPath > 0 then obState.expanded[obKey(parentPath)] = true end
    local newPath = {}
    for i = 1, #parentPath do newPath[i] = parentPath[i] end
    newPath[#newPath + 1] = clone.Name
    obState.selected = newPath
    ShowNotification("已粘贴 " .. clone.ClassName .. " \"" .. clone.Name .. "\"", 1.5)
    obRender()
end

-- 创建长按操作面板（复制对象 / 粘贴到同级 / 粘贴到下方 / 删除对象）
-- ---------- 「传送至」：仅当对象能给出 CFrame 时可用 ----------
-- 取对象的目标 CFrame：
--   · BasePart / Camera / 等直接有 CFrame 的实例 → 读 CFrame
--   · Model 没有 CFrame → 退回 WorldPivot，再退回 PrimaryPart.CFrame
-- 读不到就返回 nil，调用方据此决定是否显示该条目（面板不为不可用的对象留空位）。
function obTeleportTargetCF(node)
    if not node then return nil end
    local ok, cf = pcall(function() return node.CFrame end)
    if ok and typeof(cf) == "CFrame" then return cf end
    -- Model：WorldPivot 本身就是 CFrame；没有再退到 PrimaryPart
    local okW, wp = pcall(function() return node.WorldPivot end)
    if okW and typeof(wp) == "CFrame" then return wp end
    local okP, pp = pcall(function() return node.PrimaryPart end)
    if okP and pp then
        local okC, pcf = pcall(function() return pp.CFrame end)
        if okC and typeof(pcf) == "CFrame" then return pcf end
    end
    return nil
end

-- 把本地角色挪到目标 CFrame。
-- 抬高 3 格：目标点常常就是零件本体中心，直接贴上去容易卡进地形/零件内部。
function obTeleportTo(cf, label)
    local lp = svc and svc.Players and svc.Players.LocalPlayer
    if not lp then
        ShowNotification("传送失败：取不到本地玩家", 2.5)
        return false
    end
    local char = lp.Character
    if not (char and char.Parent) then
        ShowNotification("传送失败：角色尚未加载", 2.5)
        return false
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not (hrp and hrp:IsA("BasePart")) then
        ShowNotification("传送失败：角色没有 HumanoidRootPart", 2.5)
        return false
    end
    local target = cf + Vector3.new(0, 3, 0)
    local ok, err = pcall(function() hrp.CFrame = target end)
    if not ok then
        ShowNotification("传送失败：" .. tostring(err), 2.5)
        return false
    end
    ShowNotification("已传送至「" .. tostring(label or "目标") .. "」", 2)
    return true
end

-- ---------- 已储存对象：对象树 → 积木编程 的快速通道 ----------
-- 长按对象树里的某个对象 → 「储存对象」，之后积木编程里就能直接用它：
--   · 路径：物体类积木（设置属性 / 删除物体 / 显示隐藏 / 点击物体时）的「目标」下拉里直接出现
--   · 属性：「设置属性」卡的属性下拉会带上该对象真实存在的属性名
-- 纯内存缓存，重开脚本即清空（对象实例本身也活不过这次会话）。
OB_STORED_MAX = 12   -- 上限：下拉里堆太多反而更难找

obStoredObjects = obStoredObjects or {}   -- 数组，元素 { path={…}, text="workspace.a.b", name, class }

-- 路径数组 → 积木里可直接书写的点分路径（配合 codingObjRef 使用）。
-- 首段是服务名，必须变成代码里能直接引用的根节点：
--   Workspace → workspace；其它服务 → game.<服务名>（codingObjRef 会逐段 FindFirstChild）
function obPathToDotted(path)
    if type(path) ~= "table" or #path == 0 then return "" end
    local segs = {}
    for i, s in ipairs(path) do segs[i] = tostring(s) end
    local head = segs[1]
    if head == "Workspace" then
        head = "workspace"
    else
        -- 自己玩家那一节换成 LocalPlayer，与 obSelectedPathText 的规则保持一致
        if head == "Players" and #segs >= 2 then
            local lp = svc and svc.Players and svc.Players.LocalPlayer
            if lp and segs[2] == lp.Name then segs[2] = "LocalPlayer" end
        end
        head = "game." .. head
    end
    local out = { head }
    for i = 2, #segs do out[#out + 1] = segs[i] end
    return table.concat(out, ".")
end

function obStoredIndexOf(path)
    local key = obKey(path or {})
    for i, rec in ipairs(obStoredObjects) do
        if obKey(rec.path) == key then return i end
    end
    return nil
end

function obStoreObject(node, path)
    if type(path) ~= "table" or #path == 0 then return false, "路径无效" end
    if obStoredIndexOf(path) then return false, "该对象已储存过" end
    if #obStoredObjects >= OB_STORED_MAX then
        return false, "最多储存 " .. tostring(OB_STORED_MAX) .. " 个对象"
    end
    -- 复制一份路径：调用方持有的表可能被后续选中操作改写
    local copy = {}
    for i, s in ipairs(path) do copy[i] = tostring(s) end
    local okC, cls = pcall(function() return node and node.ClassName end)
    obStoredObjects[#obStoredObjects + 1] = {
        path = copy,
        text = obPathToDotted(copy),
        name = copy[#copy] or "",
        class = (okC and type(cls) == "string") and cls or "",
    }
    return true
end

function obUnstoreObject(path)
    local i = obStoredIndexOf(path)
    if not i then return false end
    table.remove(obStoredObjects, i)
    return true
end

-- 给积木「物体」下拉用：已储存对象的路径文本
function obStoredObjTexts()
    local out = {}
    for _, rec in ipairs(obStoredObjects) do
        if rec.text and rec.text ~= "" then out[#out + 1] = rec.text end
    end
    return out
end

function obOpenContextPanel(data, screenX, screenY)
    obCloseContextPanel()
    if not obWindow or not obWindow.Parent then return end
    local node = obResolve(data.path)
    local panelW, itemH = 180, 36

    -- 先攒出条目列表，再按条目数决定面板高度与裁剪范围
    local items = {}
    -- 顶层服务：禁止复制 / 删除，但仍然允许作为粘贴落点（粘贴到下方）
    local isRoot = obIsRootService(node, data.path)
    table.insert(items, {
        icon = "copy", fallback = "clipboard", label = "复制对象",
        color = isRoot and theme.textDim or theme.text,
        cb = function()
            if isRoot then
                ShowNotification("顶层服务不能整体复制，请复制它下面的对象", 2.5)
                return
            end
            obCopyToClipboard(data)
        end,
    })
    -- 剪贴板里有可用对象时，多给两个粘贴入口，排在「删除对象」上方
    if obClipboardSource() then
        table.insert(items, {
            icon = "corner-up-left", fallback = "clipboard", label = "粘贴到同级", color = theme.accent,
            cb = function() obPasteClipboard(data, "sibling") end,
        })
        table.insert(items, {
            icon = "corner-down-right", fallback = "clipboard", label = "粘贴到下方", color = theme.accent,
            cb = function() obPasteClipboard(data, "child") end,
        })
    end
    -- 「传送至」：仅当对象能给出 CFrame 时才插入（读不到就不占位，面板高度自动适配）。
    -- 放在「删除对象」上方，避免破坏性操作紧挨着高频入口。
    local tpCF = obTeleportTargetCF(node)
    if tpCF then
        table.insert(items, {
            icon = "navigation", fallback = "send", label = "传送至",
            color = theme.green,
            cb = function()
                -- 面板已关闭，这里重新取一次 CFrame：对象可能在这期间移动过或被销毁
                local live = obResolve(data.path)
                local cf = obTeleportTargetCF(live)
                if not cf then
                    ShowNotification("该对象已不存在或取不到位置", 2)
                    return
                end
                obTeleportTo(cf, live and live.Name or data.path)
            end,
        })
    end
    -- 「储存对象 / 移除储存」：把对象记进缓存，供积木编程快速引用（见 obStoreObject）。
    -- 已经存过就变成「移除储存」，同一个入口切来切去，不必另设管理界面。
    local wasStored = obStoredIndexOf(data.path) ~= nil
    table.insert(items, {
        icon = wasStored and "bookmark-minus" or "bookmark-plus", fallback = "bookmark",
        label = wasStored and "移除储存" or "储存对象",
        color = theme.accent2,
        cb = function()
            if wasStored then
                obUnstoreObject(data.path)
                ShowNotification("已移除储存", 1.5)
            else
                local ok, err = obStoreObject(obResolve(data.path), data.path)
                if ok then
                    ShowNotification("已储存，积木的物体下拉里可直接选到", 2.5)
                else
                    ShowNotification(err or "储存失败", 2)
                end
            end
        end,
    })
    local canDelete = (node and node.Parent ~= nil) and not isRoot
    table.insert(items, {
        icon = "trash-2", fallback = "x", label = "删除对象",
        color = canDelete and theme.red or theme.textDim,
        cb = function()
            -- 二次确认：避免长按误触直接删对象
            if isRoot then
                ShowNotification("顶层服务不可删除（会连带销毁其下全部对象）", 2.5)
                return
            end
            if not canDelete then
                ShowNotification("该对象不可删除（无父级或已销毁）", 2)
                return
            end
            obConfirmDelete(data)
        end,
    })
    local panelH = itemH * #items + 10

    local panel = create("Frame", {
        Size = UDim2.new(0, panelW, 0, panelH),
        BackgroundColor3 = theme.surface,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Active = true,
        ZIndex = 980,
        Name = "ObContextPanel",
    })
    corner(10, panel)
    stroke(theme.border, 1, panel)
    panel.Parent = obWindow
    obContextPanel = panel
    obContextTarget = data.path
    -- 标记「本次刚打开」：随后的 MouseButton1Click（长按松手会触发）在短暂窗口内
    -- 视为长按收尾、而非「单击关闭」，从而避免面板一打开就被松手事件关掉。
    obContextOpenedAt = tick()

    local function addItem(index, spec)
        local it = create("TextButton", {
            Position = UDim2.new(0, 6, 0, 4 + (index - 1) * itemH),
            Size = UDim2.new(1, -12, 0, itemH - 2),
            BackgroundColor3 = theme.surfaceLight,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 982,
        })
        corner(8, it)
        local iconColor = spec.color
        local ic = GetIcon(spec.icon, UDim2.new(0, 15, 0, 15), iconColor)
            or GetIcon(spec.fallback, UDim2.new(0, 15, 0, 15), iconColor)
        if ic then
            ic.Position = UDim2.new(0, 12, 0.5, -7)
            ic.ZIndex = 983
            ic.Parent = it
        end
        local lbl = create("TextLabel", {
            Position = UDim2.new(0, 36, 0, 0),
            Size = UDim2.new(1, -44, 1, 0),
            BackgroundTransparency = 1,
            Text = spec.label,
            TextColor3 = spec.color,
            TextSize = 13,
            Font = Enum.Font.SourceSans,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 983,
        })
        -- lbl 必须挂到按钮上，否则面板里只剩图标、看不到文字
        lbl.Parent = it
        it.MouseEnter:Connect(function()
            svc.TweenService:Create(it, TweenInfo.new(0.12), {BackgroundTransparency = 0.6}):Play()
        end)
        it.MouseLeave:Connect(function()
            svc.TweenService:Create(it, TweenInfo.new(0.12), {BackgroundTransparency = 1}):Play()
        end)
        it.MouseButton1Click:Connect(function()
            obCloseContextPanel()
            spec.cb()
        end)
        it.Parent = panel
    end

    for i, spec in ipairs(items) do addItem(i, spec) end

    -- 定位：优先显示在长按点右下方；超出窗口则翻转到左侧/上方
    -- screenX/screenY 来自 InputObject.Position，是屏幕绝对坐标；面板挂在 obWindow 内，
    -- 故需换算成窗口局部坐标，裁切范围也以窗口尺寸为准（避免用屏幕尺寸导致贴边/溢出）。
    local absPos = obWindow.AbsolutePosition
    local absSize = obWindow.AbsoluteSize
    local localX = screenX - absPos.X
    local localY = screenY - absPos.Y
    -- panelH 用上面按条目数算出的值：粘贴项出现时面板更高，裁剪才不会把「删除对象」挤出窗口
    local x = math.clamp(localX + 12, 8, math.max(8, absSize.X - panelW - 8))
    local y = math.clamp(localY - 4, 8, math.max(8, absSize.Y - panelH - 8))
    panel.Position = UDim2.new(0, x, 0, y)

    -- 入场淡入：显式把【背景 / 图标 / 文字】三者的透明度都定到「可见」终值，
    -- 避免只淡入面板背景、而子元素残留默认/旧面板关闭时的透明状态，
    -- 导致「只显示图标、看不到文字」。（图标走 ImageTransparency，文字走 TextTransparency）
    panel.BackgroundTransparency = 1
    svc.TweenService:Create(panel, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 0.06}):Play()
    for _, c in pairs(panel:GetDescendants()) do
        if c:IsA("ImageLabel") or c:IsA("ImageButton") then
            c.ImageTransparency = 0
        elseif c:IsA("TextLabel") or c:IsA("TextButton") then
            c.TextTransparency = 0
        elseif c:IsA("UIStroke") then
            c.Transparency = 0
        end
    end
end

-- 删除二次确认（内联小弹窗，避免误删）
function obConfirmDelete(data)
    if not obWindow or not obWindow.Parent then return end
    local node = obResolve(data.path)
    if not node or not node.Parent then
        ShowNotification("该对象已不存在", 2)
        return
    end
    -- 兜底：即便从别处调用，顶层服务也不给删（面板里已先禁用该条目）
    if obIsRootService(node, data.path) then
        ShowNotification("顶层服务不可删除（会连带销毁其下全部对象）", 2.5)
        return
    end
    obCloseContextPanel()
    -- 确认框整体缩小(260x118 → 244x106)，只收留白与按钮高度，字号不动
    local w, h = 244, 106
    local dlg = create("Frame", {
        Size = UDim2.new(0, w, 0, h),
        BackgroundColor3 = theme.surface,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Active = true,
        ZIndex = 985,
        Name = "ObDeleteConfirm",
    })
    corner(12, dlg)
    stroke(theme.red, 1, dlg)
    local abs = obWindow.AbsoluteSize
    dlg.Position = UDim2.new(0, math.floor((abs.X - w) / 2), 0, math.floor((abs.Y - h) / 2))
    dlg.Parent = obWindow

    local title = create("TextLabel", {
        Position = UDim2.new(0, 16, 0, 10),
        Size = UDim2.new(1, -32, 0, 20),
        BackgroundTransparency = 1,
        Text = "删除 " .. tostring(node.ClassName) .. " \"" .. tostring(node.Name) .. "\"？",
        TextColor3 = theme.text,
        TextSize = 13,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 986,
    })
    title.Parent = dlg

    local warnL = create("TextLabel", {
        Position = UDim2.new(0, 16, 0, 32),
        Size = UDim2.new(1, -32, 0, 28),
        BackgroundTransparency = 1,
        Text = "此操作不可撤销，对象及其所有子级将被销毁。",
        TextColor3 = theme.textDim,
        TextSize = 11,
        Font = Enum.Font.SourceSans,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 986,
    })
    warnL.Parent = dlg

    local function closeDlg()
        svc.TweenService:Create(dlg, TweenInfo.new(0.14), {BackgroundTransparency = 1}):Play()
        for _, c in pairs(dlg:GetDescendants()) do
            if c:IsA("TextLabel") or c:IsA("TextButton") then
                svc.TweenService:Create(c, TweenInfo.new(0.14), {TextTransparency = 1}):Play()
            end
        end
        task.delay(0.16, function() if dlg and dlg.Parent then dlg:Destroy() end end)
    end

    local cancelBtn = create("TextButton", {
        Position = UDim2.new(0, 16, 1, -38),
        Size = UDim2.new(0.5, -22, 0, 28),
        BackgroundColor3 = theme.surfaceLight,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        Text = "取消",
        TextColor3 = theme.text,
        TextSize = 12,
        Font = Enum.Font.SourceSans,
        AutoButtonColor = false,
        ZIndex = 986,
    })
    corner(8, cancelBtn)
    cancelBtn.MouseButton1Click:Connect(closeDlg)
    cancelBtn.Parent = dlg

    local okBtn = create("TextButton", {
        Position = UDim2.new(0.5, 6, 1, -38),
        Size = UDim2.new(0.5, -22, 0, 28),
        BackgroundColor3 = theme.red,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        Text = "确认删除",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 12,
        Font = Enum.Font.SourceSansBold,
        AutoButtonColor = false,
        ZIndex = 986,
    })
    corner(8, okBtn)
    okBtn.MouseButton1Click:Connect(function()
        local ok, err = pcall(function() node:Destroy() end)
        closeDlg()
        if ok then
            if obState.selected and obKey(obState.selected) == obKey(data.path) then
                obState.selected = nil
            end
            obState.expanded[obKey(data.path)] = nil
            ShowNotification("对象已删除", 1.5)
            obRender()
        else
            ShowNotification("删除失败：" .. tostring(err), 3)
        end
    end)
    okBtn.Parent = dlg

    dlg.BackgroundTransparency = 1
    svc.TweenService:Create(dlg, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {BackgroundTransparency = 0.06}):Play()
end

-- 长按手势：在行上按下满 OB_LONG_HOLD_SEC 秒且未明显拖动(OB_LONG_DRAG_PX)即触发面板
local function obAttachLongPress(row, data)
    local pressInput, startTime, startPos, fired, connChanged, connEnded, connCancel

    local function cancel(reason)
        fired = true
        if connChanged then connChanged:Disconnect() end
        if connEnded then connEnded:Disconnect() end
        if connCancel then connCancel:Disconnect() end
        if pressInput then pressInput = nil end
    end

    row.InputBegan:Connect(function(input)
        if fired then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        -- 只响应鼠标左键/触摸；忽略键盘等
        pressInput = input
        startTime = tick()
        startPos = Vector2.new(input.Position.X, input.Position.Y)
        fired = false

        local function onChanged(i)
            if i ~= pressInput then return end
            local dx = i.Position.X - startPos.X
            local dy = i.Position.Y - startPos.Y
            if dx * dx + dy * dy > OB_LONG_DRAG_PX * OB_LONG_DRAG_PX then
                -- 视为拖动（如滚动列表），取消长按
                cancel()
            end
        end
        local function onEnded(i)
            if i ~= pressInput then return end
            cancel()
        end
        connChanged = svc.UserInputService.InputChanged:Connect(onChanged)
        connEnded = svc.UserInputService.InputEnded:Connect(onEnded)
        -- 若其它 UI 抢走焦点（如搜索框获焦 / 窗口失焦），取消
        connCancel = svc.UserInputService.WindowFocusReleased:Connect(function() cancel() end)

        task.spawn(function()
            task.wait(OB_LONG_HOLD_SEC)
            if fired or not pressInput then return end
            -- 到达阈值：触发面板（关闭其它已打开的面板，避免叠加）
            obOpenContextPanel(data, startPos.X, startPos.Y)
            cancel()
        end)
    end)
end

function obMakeRow(data, order)
    local depth = data.depth
    local rowH = 22
    -- 横向溢出修复：为深层子级预留向右的空间，撑开行宽以启用横向滚动
    local OB_ROW_INDENT = 14          -- 与下方 chevron/icon/nameLbl 中的 depth*14 保持一致
    local OB_ROW_BASE_X = 320         -- 基础可视宽度（≈ 滚动帧宽度，保守估值）
    local maxDepth = math.max(obState._maxDepth or 0, depth)
    obState._maxDepth = maxDepth
    local reservedX = OB_ROW_BASE_X + (maxDepth + 1) * OB_ROW_INDENT + 60
    local row = create("TextButton", {
        Size = UDim2.new(0, reservedX, 0, rowH),
        BackgroundColor3 = theme.surfaceLight,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = order,
        ZIndex = 6,
    })
    corner(6, row)

    local rowKey = obKey(data.path)
    local isSel = (obState.selected ~= nil and obKey(obState.selected) == rowKey)
    local expandedNow = obState.expanded[rowKey] == true
    row.BackgroundColor3 = theme.accent
    row.BackgroundTransparency = isSel and 0.82 or 1
    if isSel then
        local bar = create("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 2, 0.5, 0),
            Size = UDim2.new(0, 3, 0, 13),
            BackgroundColor3 = theme.accent,
            BorderSizePixel = 0,
            ZIndex = 8,
        })
        corner(2, bar)
        bar.Parent = row
    end

    local chev
    if data.hasKids then
        chev = create("TextButton", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 4 + depth * 14, 0.5, 0),
            Size = UDim2.new(0, 20, 0, 20),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = expandedNow and "v" or ">",
            TextColor3 = theme.accent,
            TextSize = 12,
            Font = Enum.Font.SourceSansBold,
            TextXAlignment = Enum.TextXAlignment.Center,
            AutoButtonColor = false,
            ZIndex = 8,
        })
        chev.MouseButton1Click:Connect(function() obToggle(data.path) end)
    else
        chev = create("TextLabel", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 8 + depth * 14, 0.5, 0),
            Size = UDim2.new(0, 14, 0, 14),
            BackgroundTransparency = 1,
            Text = "",
            TextColor3 = theme.border,
            TextSize = 12,
            Font = Enum.Font.SourceSansBold,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 7,
        })
    end
    chev.Parent = row

    local iconName = obClassIcon(data.class)
    local icColor = obClassColor(data.class)
    local ic = GetIcon(iconName, UDim2.new(0, 13, 0, 13), icColor)
    if not ic and iconName == "package-open" then
        ic = GetIcon("package", UDim2.new(0, 13, 0, 13), icColor)
    end
    -- person-standing 不在 lucide 图集里时退到 user 图标，避免 Humanoid 行完全没有图标
    if not ic and iconName == "person-standing" then
        ic = GetIcon("user", UDim2.new(0, 13, 0, 13), icColor)
    end
    if ic then
        ic.Position = UDim2.new(0, 24 + depth * 14, 0.5, -6)
        ic.ZIndex = 7
        ic.Parent = row
        ic.ImageColor3 = icColor
    end

    local nameLbl = create("TextLabel", {
        Position = UDim2.new(0, (ic and 42 or 26) + depth * 14, 0, 0),
        Size = UDim2.new(1, -14 - ((ic and 42 or 26) + depth * 14), 1, 0),
        BackgroundTransparency = 1,
        Text = data.name,
        TextColor3 = isSel and theme.accent or theme.text,
        TextSize = 13,
        Font = Enum.Font.SourceSans,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 7,
    })
    nameLbl.Parent = row

    -- 点击整行只选中；展开 / 折叠只由左侧箭头触发
    row.MouseButton1Click:Connect(function()
        -- 面板若是被“全局点击收起(InputBegan)”关掉的，那一击只用于关闭，不顺手选中本行
        if obContextClosedAt and (tick() - obContextClosedAt) < 0.3 then return end
        -- 若长按已弹出面板，单击视为「关闭面板」，不再重复选中
        if obContextPanel and obContextPanel.Parent then
            -- 面板是本次长按刚刚打开的：松手也会触发一次 MouseButton1Click，
            -- 此时若直接关闭就会出现「松开手面板就消失」。故在打开后短暂窗口内忽略关闭。
            if obContextOpenedAt and (tick() - obContextOpenedAt) < 0.35 then
                return
            end
            obCloseContextPanel()
            return
        end
        obState.selected = data.path
        obRender()
    end)
    -- 长按（0.5s，容差 8px）调出操作面板；单击与长按通过 obAttachLongPress 内部时序互斥
    obAttachLongPress(row, data)
    table.insert(obRows, {obj = row})
    return row
end

function obRender(forceClosePanel)
    if not obTreeScroll or not obTreeScroll.Parent then return end
    obState._maxDepth = 0  -- 横向溢出修复：每次重建树前清零最大深度，避免历史值残留导致过度预留
    -- 重建树前：若面板对应的对象已失效或与当前列表无关，先关闭面板，避免幽灵面板
    if (forceClosePanel or (obContextTarget and not obResolve(obContextTarget))) and obContextPanel then
        obCloseContextPanel()
    end
    for _, r in ipairs(obRows) do
        pcall(function() r.obj:Destroy() end)
    end
    obRows = {}
    obState.budget = OB_SCAN_BUDGET
    if obState.selected and not obResolve(obState.selected) then obState.selected = nil end
    local q = nil
    if type(obState.query) == "string" and obState.query ~= "" then
        q = obState.query:lower()
    end
    local flat = {}
    for _, root in ipairs(obRoots) do
        if root.node then
            obState.budget = obState.budget - 1
            if q then
                table.insert(flat, {path = {root.key}, name = root.node.Name, class = root.node.ClassName, depth = 0, hasKids = obChildCount(root.node) > 0})
                obCollect(root.node, {root.key}, q, 1, flat)
            else
                table.insert(flat, {path = {root.key}, name = root.node.Name, class = root.node.ClassName, depth = 0, hasKids = obChildCount(root.node) > 0})
                if obState.expanded[root.key] then
                    obCollect(root.node, {root.key}, nil, 1, flat)
                end
            end
            if #flat >= OB_MAX_ROWS then break end
        end
    end

    for i, data in ipairs(flat) do
        if data.depth > 20 then data.depth = 20 end
        local row = obMakeRow(data, i)
        row.Parent = obTreeScroll
    end
    -- 选中项/树内容一变就跟着刷新（内部比对签名，值没变不会重建）
    if propWindow and propWindow.Visible then pcall(propSync) end

    if #flat == 0 then
        local empty = create("TextLabel", {
            Size = UDim2.new(1, -6, 0, 30),
            BackgroundTransparency = 1,
            Text = (q and "无匹配对象" or "无法读取该实例的子级"),
            TextColor3 = theme.textDim,
            TextSize = 12,
            Font = Enum.Font.SourceSans,
            ZIndex = 6,
            Parent = obTreeScroll,
        })
        table.insert(obRows, {obj = empty})
    elseif #flat >= OB_MAX_ROWS then
        local cap = create("TextLabel", {
            Size = UDim2.new(1, -6, 0, 26),
            LayoutOrder = 100000,
            BackgroundTransparency = 1,
            Text = "… 已达本次显示上限 " .. tostring(OB_MAX_ROWS) .. " 条，请输入关键词缩小范围",
            TextColor3 = theme.warn,
            TextSize = 12,
            Font = Enum.Font.SourceSans,
            ZIndex = 6,
        })
        cap.Parent = obTreeScroll
        table.insert(obRows, {obj = cap})
    end

    if obFootLeft then
        if obState.selected then
            obFootLeft.Text = obTruncatePath(obSelectedPathText())
        else
            obFootLeft.Text = "未选中对象"
        end
    end
    if obFootLeft then
        local txt = obSelectedPathText()
        obFootLeft.Text = (txt and obTruncatePath(txt)) or "未选中对象 · 点击可复制路径"
        obFootLeft.TextColor3 = txt and theme.text or theme.textDim
    end
    if obFootRight then
        local node = obState.selected and obResolve(obState.selected)
        obFootRight.Text = node and node.ClassName or ""
        obFootRight.TextColor3 = node and theme.accent or theme.textDim
    end
    task.defer(function()
        if obTreeScroll and obTreeList and obTreeScroll.Parent then
            local abs = obTreeList.AbsoluteContentSize
            if abs then
                -- X：横向溢出量（深层子级超出视口的部分）+ 余量；Y：纵向行高总和
                obTreeScroll.CanvasSize = UDim2.new(
                    0, math.max(0, abs.X - obTreeScroll.AbsoluteSize.X) + 12,
                    0, abs.Y + 8
                )
            end
        end
    end)
end

-- 对象浏览器根节点：key 必须是合法服务名，label 为快捷标签文字（可自行增删）
obRoots = {
    {key = "Workspace", label = "Workspace"},
    {key = "Players", label = "Players"},
    {key = "ReplicatedStorage", label = "ReplicatedStorage"},
    {key = "CoreGui", label = "CoreGui"},
}
for i = #obRoots, 1, -1 do
    local r = obRoots[i]
    if not r.node then
        local ok, sv = pcall(function() return game:GetService(r.key) end)
        if ok and sv then
            r.node = sv
        else
            table.remove(obRoots, i) -- 取不到该服务就剔除，避免渲染时索引 nil
        end
    end
end

function bsView()
    local ok, cam = pcall(function() return workspace.CurrentCamera end)
    if ok and cam and cam.ViewportSize and cam.ViewportSize.X > 100 then return cam.ViewportSize end
    return Vector2.new(1280, 720)
end

-- 对象树浏览器默认停靠位置：屏幕左侧。左边距统一由此常量控制(创建处/属性浏览器/复位处共用)
OB_LEFT_MARGIN = 12

function createBuildSpaceUI()
    if buildSpaceRoot then return end
    local vp = bsView()
    local winW = math.clamp(vp.X * 0.22, 260, 340)
    local winH = math.clamp(vp.Y * 0.78, 400, 620)

    buildSpaceRoot = create("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 900,
    })
    buildSpaceRoot.Name = "BuildSpace"
    buildSpaceRoot.Parent = screenGui

    bsDim = create("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 1, -- 无黑色蒙版：始终保持完全透明
        BorderSizePixel = 0,
        ZIndex = 900,
    })
    bsDim.Name = "Dim"
    bsDim.Parent = buildSpaceRoot

    -- （顶部横向页面切换器已移除）

    -- 右上角退出按钮
    buildSpaceExit = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -18, 0, -60),
        Size = UDim2.new(0, 96, 0, 32),
        BackgroundColor3 = theme.red,
        BackgroundTransparency = 0.72,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 905,
    })
    buildSpaceExit.Name = "ExitBtn"
    corner(16, buildSpaceExit)
    stroke(theme.red, 1, buildSpaceExit)
    local exIcon = GetIcon("log-out", UDim2.new(0, 14, 0, 14), theme.red)
    if exIcon then
        exIcon.Position = UDim2.new(0, 10, 0.5, -7)
        exIcon.ZIndex = 906
        exIcon.Parent = buildSpaceExit
    end
    create("TextLabel", {
        Position = UDim2.new(0, (exIcon and 28 or 10), 0, 0),
        Size = UDim2.new(1, (exIcon and -34 or -14), 1, 0),
        BackgroundTransparency = 1,
        Text = "退出",
        TextColor3 = theme.text,
        TextSize = 13,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 906,
        Parent = buildSpaceExit,
    })
    buildSpaceExit.Parent = buildSpaceRoot
    buildSpaceExit.MouseButton1Click:Connect(function()
        exitBuildSpace()
    end)

    -- 中心窗口：其他选项（对象树浏览器）
    obWindow = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        -- 默认停靠屏幕左侧：左边距 OB_LEFT_MARGIN，垂直保持与屏幕中心一致。
        -- 与 resetBuildSpaceChrome 中的复位位置保持一致，避免第一次显示跳动。
        Position = UDim2.new(0, OB_LEFT_MARGIN + winW / 2, 0.5, 3),
        Size = UDim2.new(0, winW, 0, winH),
        BackgroundColor3 = theme.surface,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true,
        ZIndex = 901,
    })
    obWindow.Name = "ObjectBrowser"
    -- 顶部圆角溢出修复：Roblox 的 ClipsDescendants 只按矩形裁剪，不跟随 UICorner。
    -- 原先窗口半径 20、标题栏半径 10，标题栏那两个“更方”的角会从 20 半径的圆弧里顶出去，
    -- 在顶部两角留下浅色小耳朵。这里把窗口/遮罩统一收成 12(与内部列表框一致)，
    -- 标题栏用略小的半径并内缩 1px，使其完全落在描边内侧，顶部不再有溢出。
    corner(12, obWindow)
    stroke(theme.border, 1, obWindow)
    obWindow:SetAttribute("BaseW", winW)
    obWindow:SetAttribute("BaseH", winH)
    obWindow.Parent = buildSpaceRoot
    obWindow.Visible = false

    obVeil = create("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = theme.surface,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 960,
    })
    obVeil.Name = "Veil"
    corner(12, obVeil)
    obVeil.Parent = obWindow


    obHeader = create("Frame", {
        Position = UDim2.new(0, 1, 0, 1),
        Size = UDim2.new(1, -2, 0, 28),
        BackgroundColor3 = theme.surfaceLight,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        ZIndex = 902,
    })
    corner(11, obHeader)
    obHeader.Parent = obWindow

    create("TextLabel", {
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(0, 200, 1, 0),
        BackgroundTransparency = 1,
        Text = "对象树浏览器",
        TextColor3 = theme.text,
        TextSize = 13,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 903,
        Parent = obHeader,
    })

    -- 搜索框宽度跟随窗口，保证左边不与标题「对象树浏览器」重叠
    -- 垂直方向按要求整体下移：改为顶部对齐 + 6px 偏移(居中应为 4px)，
    -- 让搜索框比标题文字低一点；宽高保持原样不动。
    local obSearchW = math.clamp(winW - 200, 80, 160)
    obSearchInput = create("TextBox", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -8, 0, 6),
        Size = UDim2.new(0, obSearchW, 0, 20),
        BackgroundColor3 = theme.surface,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        PlaceholderText = "搜索…",
        Text = "",
        TextColor3 = theme.text,
        PlaceholderColor3 = theme.textDim,
        TextSize = 12,
        Font = Enum.Font.SourceSans,
        ClearTextOnFocus = false,
        ZIndex = 903,
    })
    corner(10, obSearchInput)
    stroke(theme.border, 1, obSearchInput)
    obSearchInput.Parent = obHeader
    obSearchInput:GetPropertyChangedSignal("Text"):Connect(function()
        obState.query = obSearchInput.Text
        obRender()
    end)

    -- （标题栏关闭按钮已移除：对象树浏览器随建造空间整体进退，不再单独提供 X 关闭入口）

    -- 长按面板：点击屏幕任意处即关闭（原来只监听 obWindow 内部，点到窗口外时面板会赖在屏上）
    --
    -- 命中判定改为「面板矩形」：svc.UserInputService:GetGuiObjectsAtPosition 在部分执行器上
    -- 并不存在，会抛 "GetGuiObjectsAtPosition is not a valid member of UserInputService"，
    -- 每次点击都报错。面板的条目按钮全部落在面板矩形内、没有外溢节点，所以矩形判定足够准确，
    -- 既不会误伤面板里 复制/粘贴/删除 的点击，也不再依赖该 API。
    local function obPointInsidePanel(px, py)
        local panel = obContextPanel
        if not panel or not panel.Parent then return false end
        local ok, ap, as = pcall(function() return panel.AbsolutePosition, panel.AbsoluteSize end)
        if not ok or not ap or not as then return false end
        return px >= ap.X and px <= ap.X + as.X and py >= ap.Y and py <= ap.Y + as.Y
    end

    svc.UserInputService.InputBegan:Connect(function(input)
        if not (obContextPanel and obContextPanel.Parent) then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        -- 长按刚刚触发：按住不放的那次手势收尾时也会产生输入，不能算成“点击别处”
        if obContextOpenedAt and (tick() - obContextOpenedAt) < 0.35 then return end
        local px, py = input.Position.X, input.Position.Y
        -- 个别执行器在 InputBegan 里给出的 Position 不含坐标，退回鼠标Location
        if (not px or px == 0) and (not py or py == 0) then
            local okM, m = pcall(function() return svc.UserInputService:GetMouseLocation() end)
            if okM and m then px, py = m.X, m.Y end
        end
        if px and py and obPointInsidePanel(px, py) then return end
        obContextClosedAt = tick()   -- 标记：本次点击用于收起面板
        obCloseContextPanel()
    end)

    -- （根节点快捷切换标签已移除）

    obTreeScroll = create("ScrollingFrame", {
        -- 标题栏 30 → 28；列表顶边跟随(标题栏下 4px)，底边位置保持不变
        Position = UDim2.new(0, 8, 0, 33),
        Size = UDim2.new(1, -16, 1, -61),
        BackgroundColor3 = theme.bg,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = theme.textDim,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ClipsDescendants = true,
        ZIndex = 902,
        -- 横向溢出修复：允许用户在深层子级向右溢出时横向滑动
        ScrollingDirection = Enum.ScrollingDirection.XY,
        ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
    })
    corner(12, obTreeScroll)
    stroke(theme.border, 1, obTreeScroll)
    obTreeScroll.Parent = obWindow

    obTreeList = create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
    })
    obTreeList.Parent = obTreeScroll
    local treePad = create("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6)})
    treePad.Parent = obTreeScroll
    local function obUpdateCanvasSize()
        if not (obTreeScroll and obTreeList and obTreeScroll.Parent) then return end
        local abs = obTreeList.AbsoluteContentSize
        if not abs then return end
        -- X：横向内容宽度（深层子级溢出部分）；Y：纵向行高总和
        obTreeScroll.CanvasSize = UDim2.new(
            0, math.max(0, abs.X - obTreeScroll.AbsoluteSize.X) + 12,
            0, abs.Y + 10
        )
    end
    obTreeList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(obUpdateCanvasSize)
    -- 视口尺寸变化时也需要重新计算横向滚动范围
    obTreeScroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(obUpdateCanvasSize)

    obFootBar = create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 902,
    })
    obFootBar.Parent = obWindow

    -- 复制区仅包住路径文字，不占满整条底栏
    obFootWrap = create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 16, 1, -2),
        Size = UDim2.new(0, 0, 0, 22),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 903,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 6),
        Parent = obFootWrap,
    })
    local footIcon = GetIcon("clipboard", UDim2.new(0, 12, 0, 12), theme.textDim)
    if footIcon then
        footIcon.LayoutOrder = 1
        footIcon.ZIndex = 904
        footIcon.Parent = obFootWrap
    end
    obFootLeft = create("TextButton", {
        LayoutOrder = 2,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "未选中对象 · 点击可复制路径",
        TextColor3 = theme.textDim,
        TextSize = 11,
        Font = Enum.Font.SourceSans,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
        ZIndex = 904,
    })
    obFootLeft.MouseEnter:Connect(function()
        if obState.selected then obFootLeft.TextColor3 = theme.accent end
    end)
    obFootLeft.MouseLeave:Connect(function()
        obFootLeft.TextColor3 = obState.selected and theme.text or theme.textDim
    end)
    obFootLeft.MouseButton1Click:Connect(function()
        local txt = obSelectedPathText()
        if not txt then
            ShowNotification("请先选中一个对象", 1.5)
            return
        end
        if obCopyText(txt) then
            -- 保留文字闪绿作为即时反馈，同时弹出通知
            obFootLeft.TextColor3 = theme.green
            task.delay(0.6, function()
                if obFootLeft and obFootLeft.Parent then obFootLeft.TextColor3 = theme.text end
            end)
            ShowNotification("路径已复制到剪贴板", 1.5)
        else
            ShowNotification("复制失败：当前环境不支持剪贴板", 2)
        end
    end)
    obFootLeft.Parent = obFootWrap
    obFootWrap.Parent = obFootBar
    obFootRight = create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.new(0, 110, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = theme.textDim,
        TextSize = 11,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 903,
        Parent = obFootBar,
    })
    -- 底部操作提示文字已移除（原 BS_HINT）

    makeWindowDraggable(obWindow, obHeader)

    -- 属性浏览器：跟随对象树一起创建，是否可见由「附加设置 → 属性窗口」决定
    local okProp, errProp = pcall(createPropBrowserUI)
    if not okProp then warn("[DeltaUI] 属性浏览器创建失败: " .. tostring(errProp)) end
end

-- ================= 属性浏览器（Property Browser） =================
-- 显示「对象树浏览器」当前选中对象的属性表；支持搜索过滤、点击复制属性值、
-- 0.5s 轮询保持数值与游戏中同步（只有内容变化时才重建行，避免无谓闪烁）。
local PROP_ROW_H = 22
local PROP_NAME_W = 0.44

-- 把任意属性值格式化成一行可读文本；第二个返回值用于给值文字着色
local function propFormatValue(v)
    local t = typeof(v)
    if t == "boolean" then
        return tostring(v), v and theme.green or theme.textDim
    elseif t == "number" then
        return string.format("%.4g", v), theme.text
    elseif t == "string" then
        -- 压掉换行(单行展示)，再按字符数截断；“…” 前留了省略号空间
        local s = (v:gsub("[\r\n]+", " "))
        if #s > 46 then s = s:sub(1, 46) .. "…" end
        return '"' .. s .. '"', theme.text
    elseif t == "Color3" then
        local r, g, b = math.floor(v.R * 255 + 0.5), math.floor(v.G * 255 + 0.5), math.floor(v.B * 255 + 0.5)
        return string.format("%d, %d, %d", r, g, b), v
    elseif t == "Vector3" then
        return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z), theme.text
    elseif t == "Vector2" then
        return string.format("(%.2f, %.2f)", v.X, v.Y), theme.text
    elseif t == "CFrame" then
        local p = v.Position
        return string.format("pos(%.1f, %.1f, %.1f) rot(%.0f°)", p.X, p.Y, p.Z, math.deg(v:ToEulerAnglesYXZ())), theme.text
    elseif t == "UDim2" then
        return string.format("{%.3f, %d, %.3f, %d}", v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset), theme.text
    elseif t == "UDim" then
        return string.format("{%.3f, %d}", v.Scale, v.Offset), theme.text
    elseif t == "Rect" then
        return string.format("(%.0f,%.0f)-(%.0f,%.0f)", v.Min.X, v.Min.Y, v.Max.X, v.Max.Y), theme.text
    elseif t == "EnumItem" then
        return tostring(v.Name), theme.warn
    elseif t == "Instance" then
        -- 已销毁/无权限的引用读 ClassName 会报错，取不到就退回 <Instance>
        local okD, d = pcall(function() return v.ClassName .. " \"" .. v.Name .. "\"" end)
        return (okD and d) or "<Instance>", theme.accent
    elseif t == "function" or t == "table" then
        return nil, nil
    end
    local ok, s = pcall(tostring, v)
    return ok and s or "?", theme.text
end

-- 属性名清单：执行器 API 优先，退回实例的 Property 列表，再退回按类别的常用静态表
local PROP_STATIC = {
    common = {"Name", "Parent", "Archivable", "Enabled", "Disabled"},
    BasePart = {"Position", "Rotation", "CFrame", "Size", "Color", "Transparency", "Reflectance",
        "Material", "CanCollide", "Anchored", "Massive", "Locked", "CastShadow", "Velocity",
        "RotVelocity", "TopSurface", "BottomSurface", "Shape", "Materials", "AssemblyLinearVelocity"},
    Model = {"PrimaryPart", "WorldPivot", "LevelOfDetail", "EditorColor"},
    GuiObject = {"Position", "Size", "Visible", "ZIndex", "Active", "AnchorPoint", "BackgroundColor3",
        "BackgroundTransparency", "BorderSizePixel", "BorderColor3", "ClipsDescendants", "Rotation",
        "AbsolutePosition", "AbsoluteSize", "LayoutOrder", "IgnoreGuiInset"},
    GuiLabel = {"Text", "TextColor3", "TextSize", "TextTransparency", "TextXAlignment", "TextYAlignment",
        "TextWrapped", "TextScaled", "TextStrokeColor3", "TextStrokeTransparency", "Font", "PlaceholderText"},
    Script = {"Disabled", "RunContext", "Source"},
}

-- 过滤掉 Hidden 属性（噪音太多），同时把引擎标记为只读的属性挑出来记进 roSet：
-- 只读属性仍然展示（要能看到当前值），只是长按时不给编辑。
-- HasTag 在不同实现里可能是方法、也可能不存在，一律 pcall 兜底；取不到标签就当可写。
local function propTagOf(p)
    local show, readOnly = true, false
    local okH, hidden = pcall(function() return p:HasTag("Hidden") end)
    if okH and hidden == true then show = false end
    for _, tag in ipairs({"ReadOnly", "NotEditable"}) do
        local ok, has = pcall(function() return p:HasTag(tag) end)
        if ok and has == true then readOnly = true end
    end
    return show, readOnly
end

local function propListNames(node)
    local names = {}
    local seen = {}
    local roSet = {}          -- 只读属性名集合
    local function put(n)
        if type(n) ~= "string" or n == "" or seen[n] then return end
        seen[n] = true
        names[#names + 1] = n
    end
    -- ClassName 是运行时算出来的派生值，永远不可写；Name / Parent 由引擎决定可写性。
    put("Name")
    put("ClassName")
    put("Parent")
    roSet.ClassName = "派生属性，由引擎决定"
    local found = 0   -- 真正从实例上枚举出来的属性数，0 表示两条 API 都没给东西
    local function putFound(n) local before = seen[n] put(n) if not before then found = found + 1 end end
    -- 1) Synapse / 部分执行器
    local gp = (typeof(getproperties) == "function" and getproperties) or (typeof(getprops) == "function" and getprops)
    if typeof(gp) == "function" then
        local ok, tb = pcall(gp, node, true)
        if ok and type(tb) == "table" then
            for k in pairs(tb) do putFound(k) end
        end
    end
    -- 2) 标准 Instance.Properties：顺便记录每个属性的可写性标签
    if found == 0 then
        local ok, props = pcall(function() return node.Properties end)
        if ok and type(props) == "table" then
            for _, p in ipairs(props) do
                local okN, pn = pcall(function() return p.Name end)
                if okN and type(pn) == "string" then
                    local show, readOnly = propTagOf(p)
                    if readOnly and pn ~= "Name" then roSet[pn] = "引擎标记为只读" end
                    if show or pn == "Name" then putFound(pn) end
                end
            end
        end
    end
    -- 3) 静态兜底：两条 API 都没枚举出任何属性时（受限执行器 / 特殊实例），
    --    至少把这个类别的常用属性列出来，窗口不会是空的。
    if found == 0 then
        local okC, cls = pcall(function() return node.ClassName end)
        if okC and cls and PROP_STATIC[cls] then
            for _, n in ipairs(PROP_STATIC[cls]) do putFound(n) end
        end
        for _, n in ipairs(PROP_STATIC.common) do putFound(n) end
    end
    table.sort(names)
    -- Name / ClassName / Parent 置顶，方便一眼确认对象
    local function pinOrder(n)
        if n == "Name" then return 1 end
        if n == "ClassName" then return 2 end
        if n == "Parent" then return 3 end
        return 10
    end
    table.sort(names, function(a, b)
        local oa, ob = pinOrder(a), pinOrder(b)
        if oa ~= ob then return oa < ob end
        return a < b
    end)
    return names, roSet
end


local propRowRefs = {}   -- 当前显示的属性行，重建时逐个销毁(不能用 ClearAllChildren，会连布局子件一起删)

local function propDestroyRows()
    for i = #propRowRefs, 1, -1 do
        local r = propRowRefs[i]
        propRowRefs[i] = nil
        pcall(function() if r then r:Destroy() end end)
    end
end

-- "Workspace.Map.Foo" → 实例。第一段允许服务名或 game 下的普通子级。
local function propFindInstanceByPath(text)
    local parts = {}
    for seg in tostring(text or ""):gmatch("[^%.]+") do parts[#parts + 1] = seg end
    if parts[1] == "game" then table.remove(parts, 1) end
    if #parts == 0 then return nil end   -- 空路径不当作 game，清空由调用方显式处理
    local cur
    local okS, sv = pcall(function() return game:GetService(parts[1]) end)
    cur = (okS and sv) or nil
    if not cur then
        local okW, kid = pcall(function() return workspace:FindFirstChild(parts[1]) end)
        cur = (okW and kid) or nil
    end
    if not cur then return nil end
    for i = 2, #parts do
        local okC, kid = pcall(function() return cur:FindFirstChild(parts[i]) end)
        if not okC or not kid then return nil end
        cur = kid
    end
    return cur
end

-- ---------- 长按修改属性 ----------
propEditor = nil           -- 当前打开的编辑面板（同一时刻只允许一个）
propEditOpenedAt = 0       -- 打开时刻：用来吃掉紧接着那次“复制”点击

-- 每种类型对应的输入字段；boolean / EnumItem / Instance 走特殊控件
local PROP_EDIT_FIELDS = {
    number = {{"值", "number"}},
    string = {{"值", "string"}},
    ProtectedString = {{"值", "string"}},
    Content = {{"rbxassetid:// 或 URL", "string"}},
    Beverages = {{"rbxassetid:// 或 URL", "string"}},
    EnumItem = {{"枚举项名", "string"}},
    Instance = {{"对象全名（如 Workspace.Map）", "string"}},
    Class = {{"对象全名（如 Workspace.Map）", "string"}},
    Color3 = {{"R 0-255", "number"}, {"G 0-255", "number"}, {"B 0-255", "number"}},
    Vector3 = {{"X", "number"}, {"Y", "number"}, {"Z", "number"}},
    Vector2 = {{"X", "number"}, {"Y", "number"}},
    UDim = {{"Scale", "number"}, {"Offset", "number"}},
    UDim2 = {{"X.Scale", "number"}, {"X.Offset", "number"}, {"Y.Scale", "number"}, {"Y.Offset", "number"}},
    Rect = {{"Min X", "number"}, {"Min Y", "number"}, {"Max X", "number"}, {"Max Y", "number"}},
}

function propAttachLongPress(btn, onLong)
    local pressInput, startPos, fired, cChanged, cEnded
    local function stop()
        fired = true
        if cChanged then cChanged:Disconnect() cChanged = nil end
        if cEnded then cEnded:Disconnect() cEnded = nil end
        pressInput = nil
    end
    btn.InputBegan:Connect(function(input)
        if fired then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        pressInput = input
        startPos = Vector2.new(input.Position.X, input.Position.Y)
        fired = false
        -- 按住期间移动超过容差视为在滚动列表，取消长按（与对象树同一套阈值）
        cChanged = svc.UserInputService.InputChanged:Connect(function(i)
            if i ~= pressInput or not startPos then return end
            local dx, dy = i.Position.X - startPos.X, i.Position.Y - startPos.Y
            if dx * dx + dy * dy > OB_LONG_DRAG_PX * OB_LONG_DRAG_PX then stop() end
        end)
        cEnded = svc.UserInputService.InputEnded:Connect(function(i)
            if i == pressInput then stop() end
        end)
        task.spawn(function()
            task.wait(OB_LONG_HOLD_SEC)
            if fired or not pressInput or not startPos then return end
            local px, py = startPos.X, startPos.Y
            stop()
            onLong(px, py)
        end)
    end)
    btn.MouseLeave:Connect(stop)
end

function propCloseEditor()
    if propEditor and propEditor.Parent then propEditor:Destroy() end
    propEditor = nil
end

-- 把当前值摊平成各输入框的初值
function propPrefillOf(kind, v)
    if kind == "Color3" then
        return {math.floor(v.R * 255 + 0.5), math.floor(v.G * 255 + 0.5), math.floor(v.B * 255 + 0.5)}
    elseif kind == "Vector3" then
        return {v.X, v.Y, v.Z}
    elseif kind == "Vector2" then
        return {v.X, v.Y}
    elseif kind == "UDim" then
        return {v.Scale, v.Offset}
    elseif kind == "UDim2" then
        return {v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset}
    elseif kind == "Rect" then
        return {v.Min.X, v.Min.Y, v.Max.X, v.Max.Y}
    elseif kind == "EnumItem" then
        return {tostring(v.Name)}
    elseif kind == "Instance" or kind == "Class" then
        local okN, n = pcall(function() return v:GetFullName() end)
        return {(okN and n) or ""}
    end
    return {tostring(v)}
end

-- 输入文本 → 属性值；返回 (值, 错误信息)，成功时错误信息为 nil
function propBuildValue(kind, texts, spec)
    -- 要求恰好 want 个数字：少一格就报错，别拿 nil 去构造 Vector3/UDim2（会直接抛异常）
    local function nums(want)
        local out = {}
        for i = 1, want do
            if texts[i] == nil then return nil, "还缺 " .. (want - #out) .. " 个数字" end
            local n = tonumber(texts[i])
            if not n then return nil, tostring(texts[i]) .. " 不是数字" end
            out[#out + 1] = n
        end
        return out, nil
    end
    if kind == "number" then
        local n = tonumber(texts[1])
        if not n then return nil, "请输入数字" end
        return n, nil
    elseif kind == "string" or kind == "ProtectedString" or kind == "Content" or kind == "Beverages" then
        return texts[1], nil
    elseif kind == "Color3" then
        local n, err = nums(3)
        if not n then return nil, err end
        return Color3.fromRGB(math.clamp(n[1], 0, 255), math.clamp(n[2], 0, 255), math.clamp(n[3], 0, 255)), nil
    elseif kind == "Vector3" then
        local n, err = nums(3)
        if not n then return nil, err end
        return Vector3.new(n[1], n[2], n[3]), nil
    elseif kind == "Vector2" then
        local n, err = nums(2)
        if not n then return nil, err end
        return Vector2.new(n[1], n[2]), nil
    elseif kind == "UDim" then
        local n, err = nums(2)
        if not n then return nil, err end
        return UDim.new(n[1], math.floor(n[2])), nil
    elseif kind == "UDim2" then
        local n, err = nums(4)
        if not n then return nil, err end
        return UDim2.new(n[1], math.floor(n[2]), n[3], math.floor(n[4])), nil
    elseif kind == "Rect" then
        local n, err = nums(4)
        if not n then return nil, err end
        return Rect.new(n[1], n[2], n[3], n[4]), nil
    elseif kind == "EnumItem" then
        local nm = texts[1]:gsub("^%s+", ""):gsub("%s+$", "")
        if not spec.enumName or spec.enumName == "" then
            return nil, "未能解析该属性的枚举类型，请长按属性名重试"
        end
        local okItem, item = pcall(function() return Enum[spec.enumName][nm] end)
        if not okItem or item == nil then
            return nil, "「" .. spec.enumName .. "」里没有叫 " .. nm .. " 的枚举项"
        end
        return item, nil
    elseif kind == "Instance" or kind == "Class" then
        -- 返回 (值, 错误, 是否显式清空)：nil 既可能是“清空”，也可能只是没有值
        local t = tostring(texts[1] or ""):match("^%s*(.-)%s*$")
        if t == "" or t:lower() == "nil" then return nil, nil, true end
        local target = propFindInstanceByPath(t)
        if not target then return nil, "找不到对象：" .. t end
        return target, nil
    end
    return nil, "该类型暂不支持在此修改"
end

-- 写入：Name / ClassName / 服务本身等属性在执行器里是受保护的，
-- 普通赋值会被拦下来 → 支持 setreadonly 的执行器先解除保护再写、写完复原。
function propWriteProp(node, key, value)
    local function rawWrite()
        local ok, err = pcall(function() node[key] = value end)
        return ok, err
    end
    local ok, err = rawWrite()
    if ok then return true end
    if type(setreadonly) == "function" then
        local wasReadonly = true
        if type(isreadonly) == "function" then
            local okR, r = pcall(isreadonly, node)
            wasReadonly = (not okR) or r ~= false
        end
        if wasReadonly then pcall(setreadonly, node, false) end
        local ok2, err2 = rawWrite()
        if wasReadonly then pcall(setreadonly, node, true) end
        if ok2 then return true end
        return false, err2 or err
    end
    return false, err
end

-- 真正落盘的一步：spec = {name, kind, node}，value 必须是已解析好的类型值
function propCommit(spec, value, clear)
    if clear then value = nil end   -- Instance 类属性：填空 = 置空（Parent = nil 会把对象移出层级，引擎允许）
    local node = spec.node
    if not node or not (node.Parent or node == game) then
        ShowNotification("对象已销毁，无法修改", 2)
        propCloseEditor()
        return
    end
    local wrote, werr = propWriteProp(node, spec.name, value)
    if not wrote then
        ShowNotification("写入失败：" .. tostring(werr), 3)
        return
    end
    -- 改 Name 会让树上的选中路径失效，跟着把最后一段改掉并重建树
    if spec.name == "Name" then
        if type(obState.selected) == "table" then
            obState.selected[#obState.selected] = tostring(value)
        end
        pcall(obRender)
    end
    propCloseEditor()
    -- 置空 Parent 会让对象离开层级、在树里再也找不到，单独提醒一句
    if spec.name == "Parent" and (value == nil or value == game) then
        ShowNotification("已修改 Parent：对象离开层级树后不会再出现在列表里", 3)
    else
        ShowNotification("已修改 " .. spec.name, 1.4)
    end
    propSignature = "\0__force__"
    pcall(propSync)
end

-- 文本输入 → 解析 → 提交
function propApplyEdit(spec, texts)
    local value, err, clear = propBuildValue(spec.kind, texts or {}, spec)
    if err then
        ShowNotification("输入无效：" .. err, 2.5)
        return
    end
    propCommit(spec, value, clear)
end

function propOpenEditor(r, screenX, screenY)
    if not (propWindow and propWindow.Parent) then return end
    local node = obResolve(obState.selected)
    if not node then
        ShowNotification("对象已不存在", 2)
        return
    end
    -- 1) 引擎标签/派生属性标为只读的：只解释，不给输入框
    if r.ro then
        ShowNotification(r.name .. " 不可修改（" .. tostring(r.ro) .. "）", 2.5)
        return
    end
    local fields = PROP_EDIT_FIELDS[r.kind]
    -- 2) 没有输入控件的类型（CFrame 只填 xyz 会丢旋转、函数、表……）一律拒绝
    if not fields and r.kind ~= "boolean" then
        ShowNotification(r.name .. "：" .. r.kind .. " 类型暂不支持在此修改", 2.5)
        return
    end
    propCloseEditor()

    local spec = {name = r.name, kind = r.kind, node = node, value = r.value}
    if spec.kind == "EnumItem" then
        -- 保留枚举类型名，输入时按 Enum[type][name] 解析，避免用户瞎猜 Items 序号
        local okT, tn = pcall(function() return r.value.EnumType.Name end)
        spec.enumName = (okT and tn) or nil
    end

    local isBool = r.kind == "boolean"
    local panelW = math.min(260, propWindow.AbsoluteSize.X - 16)
    local rowStep = 30
    local bodyH = isBool and 26 or (#fields * rowStep)
    local panelH = 30 + bodyH + 8 + 26 + 8
    local pw = propWindow.AbsoluteSize.X
    local phh = propWindow.AbsoluteSize.Y
    -- 输入点转成窗口局部坐标，并保证整块面板留在窗口内
    local x = math.clamp(screenX - propWindow.AbsolutePosition.X - panelW / 2, 8, math.max(8, pw - panelW - 8))
    local y = math.clamp(screenY - propWindow.AbsolutePosition.Y + 8, 8, math.max(8, phh - panelH - 8))

    local panel = create("Frame", {
        Name = "PropEditor",
        Position = UDim2.new(0, x, 0, y),
        Size = UDim2.new(0, panelW, 0, panelH),
        BackgroundColor3 = theme.surfaceLight,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        Active = true,
        ZIndex = 960,
    })
    corner(10, panel)
    stroke(theme.accent, 1, panel)
    panel.Parent = propWindow
    propEditor = panel
    propEditOpenedAt = tick()

    create("TextLabel", {
        Position = UDim2.new(0, 10, 0, 7),
        Size = UDim2.new(1, -20, 0, 18),
        BackgroundTransparency = 1,
        Text = r.name .. " · " .. r.kind,
        TextColor3 = theme.text,
        TextSize = 12,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 961,
        Parent = panel,
    })

    local boxes = {}
    local texts = {}
    if isBool then
        -- 布尔：直接两个按钮，点哪个就写入哪个，少一次确认环节
        local function boolBtn(ax, label, val, col)
            local b = create("TextButton", {
                Position = UDim2.new(ax, 10, 0, 30),
                Size = UDim2.new(0.5, -15, 0, 26),
                BackgroundColor3 = col,
                BackgroundTransparency = 0.6,
                BorderSizePixel = 0,
                Text = "设为 " .. label,
                TextColor3 = theme.text,
                TextSize = 12,
                Font = Enum.Font.SourceSansBold,
                AutoButtonColor = false,
                ZIndex = 962,
                Parent = panel,
            })
            corner(8, b)
            b.MouseButton1Click:Connect(function()
                propCommit(spec, val)
            end)
            return b
        end
        boolBtn(0, "设为 true", true, theme.green)
        boolBtn(0.5, "设为 false", false, theme.red)
    else
        local prefill = propPrefillOf(r.kind, r.value)
        for fi, f in ipairs(fields) do
            local label, kind2 = f[1], f[2]
            local fy = 28 + (fi - 1) * rowStep
            create("TextLabel", {
                Position = UDim2.new(0, 10, 0, fy + 4),
                Size = UDim2.new(0.38, -10, 0, 18),
                BackgroundTransparency = 1,
                Text = label,
                TextColor3 = theme.textDim,
                TextSize = 11,
                Font = Enum.Font.SourceSans,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 961,
                Parent = panel,
            })
            local box = create("TextBox", {
                Position = UDim2.new(0.38, 0, 0, fy, 1, 0),
                Size = UDim2.new(0.62, -10, 0, 24),
                BackgroundColor3 = theme.surface,
                BackgroundTransparency = 0.25,
                BorderSizePixel = 0,
                Text = prefill[fi] ~= nil and tostring(prefill[fi]) or "",
                TextColor3 = theme.text,
                TextSize = 11,
                Font = Enum.Font.SourceSans,
                ClearTextOnFocus = false,
                ZIndex = 961,
                Parent = panel,
            })
            corner(7, box)
            if kind2 == "number" then
                box.KeyboardType = Enum.KeyboardType.Number
            end
            boxes[fi] = box
        end
    end

    local function footBtn(ax, label, col, fn)
        local b = create("TextButton", {
            Position = UDim2.new(0, 10, 1, -34),
            Size = UDim2.new(0.5, -15, 0, 26),
            BackgroundColor3 = col,
            BackgroundTransparency = 0.6,
            BorderSizePixel = 0,
            Text = label,
            TextColor3 = theme.text,
            TextSize = 12,
            Font = Enum.Font.SourceSansBold,
            AutoButtonColor = false,
            ZIndex = 962,
        })
        -- ax 用 scale 分两格：0 = 左半，0.5 = 右半（TextButton 没有 X 属性，别往 props 里塞）
        b.Position = UDim2.new(ax, 10, 1, -34)
        corner(8, b)
        b.MouseButton1Click:Connect(fn)
        b.Parent = panel
        return b
    end
    if not isBool then
        footBtn(0, "应用", theme.accent, function()
            for i, bx in ipairs(boxes) do texts[i] = bx.Text end
            propApplyEdit(spec, texts)
        end)
        pcall(function() boxes[1]:CaptureFocus() end)
    end
    footBtn(0.5, "取消", theme.surface, function() propCloseEditor() end)
end

function propSync()
    if not (propWindow and propWindow.Parent and propList and propWindow.Visible) then return end
    local node = obResolve(obState.selected)
    propWindowTarget.Text = node and (node.ClassName .. " · \"" .. node.Name .. "\"") or "未选中对象"
    if not node then
        propSignature = nil
        propDestroyRows()
        propEmpty.Visible = true      -- 没选中对象时才显示“请在左侧对象树选中”提示
        propCount.Text = ""
        return
    end
    propEmpty.Visible = false

    local q = ""
    if propSearchInput then
        -- 两端空白一起去掉，否则搜 " color" 会匹配不到
        q = tostring(propSearchInput.Text or ""):lower():match("^%s*(.-)%s*$") or ""
    end

    -- 组一次行数据(name / 值文字 / 值颜色 / 类型 / 可写性)，之后只做「签名相同就跳过」的判断
    local names, roNames = propListNames(node)
    local rowsData = {}
    local function addRow(nm)
        local ok, v = pcall(function() return node[nm] end)
        if not ok or v == nil then
            -- 读不出来的属性（只写、或该执行器不支持）默认不展示，避免整屏红色报错行；
            -- 只有当用户确实在搜这个名字时才提示它存在但读不到。
            if q ~= "" and nm:lower():find(q, 1, true) then
                rowsData[#rowsData + 1] = {name = nm, text = "〈读取失败〉", color = theme.red, kind = "nil", ro = "读取失败"}
            end
            return
        end
        local txt, col = propFormatValue(v)
        if txt == nil then return end         -- 函数/表一类的值不展示
        rowsData[#rowsData + 1] = {
            name = nm, text = txt, color = col or theme.text,
            kind = typeof(v),
            ro = roNames[nm],                 -- 引擎标签判定的只读；标签拿不到时按“可写”处理，
            value = v,                        -- 真写不进去会在应用时按报错提示
        }
    end
    if q == "" then
        for _, n in ipairs(names) do addRow(n) end
    else
        for _, n in ipairs(names) do
            if n:lower():find(q, 1, true) then addRow(n) end
        end
    end

    local sig = (node.ClassName .. "\0" .. node.Name)
    for _, r in ipairs(rowsData) do sig = sig .. "\1" .. r.name .. "\2" .. r.text end
    propCount.Text = #rowsData .. " 项"
    -- 搜不到匹配属性时给个专属提示，别继续显示“请先选中对象”
    propEmpty.Text = (#rowsData == 0) and "没有匹配的属性" or "未选中对象 · 在对象树中选择一个"
    propEmpty.Visible = (#rowsData == 0)
    if sig == propSignature then return end    -- 内容没变：保留滚动位置，不重建
    propSignature = sig

    propDestroyRows()
    for i, r in ipairs(rowsData) do
        local shade = (i % 2 == 0) and 0.62 or 0.72
        local row = create("TextButton", {
            Name = "PropRow",
            LayoutOrder = i,
            Size = UDim2.new(1, -6, 0, PROP_ROW_H),
            BackgroundColor3 = theme.surfaceLight,
            BackgroundTransparency = shade,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 903,
        })
        create("TextLabel", {
            Position = UDim2.new(0, 8, 0, 0),
            Size = UDim2.new(PROP_NAME_W, -10, 1, 0),
            BackgroundTransparency = 1,
            Text = r.name,
            TextColor3 = theme.textDim,
            TextSize = 11,
            Font = Enum.Font.SourceSans,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 904,
            Parent = row,
        })
        -- 只读属性用灰色方块代替类别色点，长按时也只给解释、不给编辑器
        create("Frame", {
            Position = UDim2.new(0, 2, 0.5, -2),
            Size = UDim2.new(0, 4, 0, 4),
            BackgroundColor3 = r.ro and theme.border or r.color,
            BorderSizePixel = 0,
            ZIndex = 904,
            Parent = row,
        })
        create("TextLabel", {
            Position = UDim2.new(PROP_NAME_W, 0, 0, 0),
            Size = UDim2.new(1 - PROP_NAME_W, -8, 1, 0),
            BackgroundTransparency = 1,
            Text = r.text,
            TextColor3 = r.color,
            TextSize = 11,
            Font = Enum.Font.SourceSans,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 904,
            Parent = row,
        })
        row.MouseEnter:Connect(function()
            svc.TweenService:Create(row, TweenInfo.new(0.12), {BackgroundTransparency = 0.4}):Play()
        end)
        row.MouseLeave:Connect(function()
            svc.TweenService:Create(row, TweenInfo.new(0.14), {BackgroundTransparency = shade}):Play()
        end)
        row.MouseButton1Click:Connect(function()
            -- 长按打开编辑器后，紧跟着的那次松手点击不能再算成“复制”
            if propEditOpenedAt and (tick() - propEditOpenedAt) < 0.35 then return end
            -- 整行可点：复制「属性名 = 值」，方便直接粘进脚本里
            if obCopyText(r.name .. " = " .. r.text) then
                ShowNotification("已复制 " .. r.name, 1.2)
            else
                ShowNotification("复制失败：当前环境不支持剪贴板", 2)
            end
        end)
        -- 长按修改属性；只读/不支持编辑的行只解释原因
        propAttachLongPress(row, function(px, py)
            propOpenEditor(r, px, py)
        end)
        row.Parent = propList
        propRowRefs[#propRowRefs + 1] = row
    end
end

-- 高度严格跟随对象树：对象树在进入建造空间时有“先缩小再补间到常态”的开场动画，
-- 只同步一次会取到中间值，所以直接监听 Size / Position 变化，两扇窗永远等高对齐。
function propFollowTreeSize()
    if not (propWindow and propWindow.Parent and obWindow and obWindow.Parent) then return end
    local oh = obWindow.Size.Y.Offset
    if not oh or oh <= 0 then return end
    propWindow.Size = UDim2.new(0, propWindow.Size.X.Offset, 0, oh)
end

function propWindowSetVisible(on)
    if not propWindow then return end
    if on then
        propWindow.Visible = true
        propSignature = "\0__force__"   -- 强制重建一次
        pcall(propSync)
    else
        propCloseEditor()        -- 收起窗口时一并关掉编辑面板，避免下次打开残留
        propWindow.Visible = false
    end
end

function createPropBrowserUI()
    if propWindow or not buildSpaceRoot or not buildSpaceRoot.Parent then return end
    local vp = bsView()
    local winW = obWindow and obWindow.Size.X.Offset or 300
    local winH = obWindow and obWindow.Size.Y.Offset or 480
    local w = math.clamp(vp.X * 0.2, 250, 330)
    -- 高度严格等于对象树（不再各自 clamp），随后由 propFollowTreeSize 持续跟随
    local h = winH
    -- 对象树停靠在屏幕左侧：属性浏览器贴着它的右侧摆放；右侧放不下就摆到左侧。
    -- 中心 X 换算成像素坐标，与对象树新位置(OB_LEFT_MARGIN)保持对齐。
    local obCenterX = OB_LEFT_MARGIN + winW / 2
    local rightRoom = vp.X - (OB_LEFT_MARGIN + winW)
    local dx = (rightRoom >= w + 24) and (obCenterX + winW / 2 + 16 + w / 2) or (OB_LEFT_MARGIN + w / 2)

    propWindow = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, dx, 0.5, 3),
        Size = UDim2.new(0, w, 0, h),
        BackgroundColor3 = theme.surface,
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true,
        Visible = false,
        ZIndex = 901,
    })
    propWindow.Name = "PropertyBrowser"
    propWindow:SetAttribute("Dx", dx)   -- resetBuildSpaceChrome 靠它把窗口放回对象树旁边
    corner(12, propWindow)
    stroke(theme.border, 1, propWindow)
    propWindow.Parent = buildSpaceRoot

    propHead = create("Frame", {
        Position = UDim2.new(0, 1, 0, 1),
        Size = UDim2.new(1, -2, 0, 28),
        BackgroundColor3 = theme.surfaceLight,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        ZIndex = 902,
    })
    corner(11, propHead)
    propHead.Parent = propWindow

    create("TextLabel", {
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(0, 110, 1, 0),
        BackgroundTransparency = 1,
        Text = "属性浏览器",
        TextColor3 = theme.text,
        TextSize = 13,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 903,
        Parent = propHead,
    })

    propSearchInput = create("TextBox", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -8, 0, 6),
        Size = UDim2.new(0, math.clamp(w - 130, 80, 150), 0, 20),
        BackgroundColor3 = theme.surface,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        PlaceholderText = "搜索属性…",
        Text = "",
        TextColor3 = theme.text,
        PlaceholderColor3 = theme.textDim,
        TextSize = 12,
        Font = Enum.Font.SourceSans,
        ClearTextOnFocus = false,
        ZIndex = 903,
    })
    corner(10, propSearchInput)
    stroke(theme.border, 1, propSearchInput)
    propSearchInput.Parent = propHead
    propSearchInput:GetPropertyChangedSignal("Text"):Connect(function()
        propSignature = ""      -- 过滤条件变了，签名比较会强制重建
        pcall(propSync)
    end)

    propWindowTarget = create("TextLabel", {
        Position = UDim2.new(0, 8, 0, 33),
        Size = UDim2.new(1, -16, 0, 18),
        BackgroundTransparency = 1,
        Text = "未选中对象",
        TextColor3 = theme.accent,
        TextSize = 11,
        Font = Enum.Font.SourceSansBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 902,
        Parent = propWindow,
    })

    propList = create("ScrollingFrame", {
        Position = UDim2.new(0, 8, 0, 54),
        Size = UDim2.new(1, -16, 1, -84),
        BackgroundColor3 = theme.bg,
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = theme.textDim,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ClipsDescendants = true,
        ZIndex = 902,
    })
    corner(12, propList)
    stroke(theme.border, 1, propList)
    propList.Parent = propWindow
    create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2)}).Parent = propList
    create("UIPadding", {PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3)}).Parent = propList

    -- 空状态提示直接压在列表区域上（若作为列表子项会被 UIListLayout 当成一行排下去）
    propEmpty = create("TextLabel", {
        Position = UDim2.new(0, 8, 0, 78),
        Size = UDim2.new(1, -16, 0, 18),
        BackgroundTransparency = 1,
        Text = "未选中对象 · 在对象树中选择一个",
        TextColor3 = theme.textDim,
        TextSize = 11,
        Font = Enum.Font.SourceSans,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 903,
        Parent = propWindow,
    })

    propCount = create("TextLabel", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -8, 0, 33),
        Size = UDim2.new(0, 90, 0, 18),
        BackgroundTransparency = 1,
        Text = "",
        TextColor3 = theme.textDim,
        TextSize = 11,
        Font = Enum.Font.SourceSans,
        TextXAlignment = Enum.TextXAlignment.Right,
        ZIndex = 902,
        Parent = propWindow,
    })

    makeWindowDraggable(propWindow, propHead)
    -- 高度与对象树严格一致：只跟尺寸，位置各自独立（两扇窗都能单独拖）
    pcall(function()
        obWindow:GetPropertyChangedSignal("Size"):Connect(propFollowTreeSize)
    end)
    propFollowTreeSize()

    -- 底部 30px 留白带里放一句操作提示（列表高度按 -44 算，不会压到它）
    create("TextLabel", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 12, 1, -8),
        Size = UDim2.new(1, -24, 0, 16),
        BackgroundTransparency = 1,
        Text = "点击行复制「属性 = 值」 · 长按行修改",
        TextColor3 = theme.textDim,
        TextSize = 10,
        Font = Enum.Font.SourceSans,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 902,
        Parent = propWindow,
    })

    -- 轮询同步：游戏里属性会变（移动部件、改颜色），0.5s 拉一次即可。
    -- 不在建造空间时直接跳过，避免空转遍历属性。
    task.spawn(function()
        while propWindow and propWindow.Parent do
            task.wait(0.5)
            if buildSpaceActive and propWindow.Visible then pcall(propSync) end
        end
    end)
end

function makeWindowDraggable(win, handle)
    local dragging = false
    local grabX, grabY = 0, 0
    local startPos = win.Position
    handle.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        -- 焦点在任何输入框里时都不启动拖动：原先只判断对象树的搜索框，
        -- 属性浏览器自己的搜索框会被误当成拖动起手
        local okF, focused = pcall(function() return svc.UserInputService:GetFocusedTextBox() end)
        if okF and focused then return end
        dragging = true
        startPos = win.Position
        grabX = input.Position.X
        grabY = input.Position.Y
    end)
    svc.UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        -- 纯增量移动：不再每帧用 AbsolutePosition/AbsoluteSize 反推，避免抖动
        win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + (input.Position.X - grabX),
            startPos.Y.Scale, startPos.Y.Offset + (input.Position.Y - grabY))
    end)
    svc.UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        dragging = false
    end)
end

-- 顶部页面切换器已移除，这里只记录当前标签，保留函数以免残留调用报错
function setBuildSpaceTab(key)
    buildSpaceTab = key
end

bsNavFadeSaved = nil

function bsFadeNavChrome(hide, duration)
    if not navBg then return end
    if hide then
        if not bsNavFadeSaved then
            bsNavFadeSaved = {bg = navBg.BackgroundTransparency, ind = navIndicator and navIndicator.BackgroundTransparency or 0.2}
        end
    elseif not bsNavFadeSaved then
        bsNavFadeSaved = {bg = 0.5, ind = 0.2}
    end
    duration = duration or 0.28
    local ti = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    svc.TweenService:Create(navBg, ti, {BackgroundTransparency = hide and 1 or bsNavFadeSaved.bg}):Play()
    local bgStroke = navBg:FindFirstChildOfClass("UIStroke")
    if bgStroke then
        svc.TweenService:Create(bgStroke, ti, {Transparency = hide and 1 or 0}):Play()
    end
    if navIndicator then
        svc.TweenService:Create(navIndicator, ti, {BackgroundTransparency = hide and 1 or bsNavFadeSaved.ind}):Play()
        local indStroke = navIndicator:FindFirstChildOfClass("UIStroke")
        if indStroke then
            svc.TweenService:Create(indStroke, ti, {Transparency = hide and 1 or 0}):Play()
        end
    end
    if navContainer then
        for _, btn in ipairs(navContainer:GetChildren()) do
            if btn:IsA("GuiButton") then
                for _, sub in ipairs(btn:GetChildren()) do
                    if sub:IsA("ImageLabel") then
                        svc.TweenService:Create(sub, ti, {ImageTransparency = hide and 1 or 0}):Play()
                    end
                end
            end
        end
    end
    if not hide then bsNavFadeSaved = nil end
end

function resetBuildSpaceChrome()
    if buildSpaceTop then buildSpaceTop.Position = UDim2.new(0.5, 0, 0, -62) end
    buildSpaceExit.Position = UDim2.new(1, -18, 0, -62)
    local hint = buildSpaceRoot:FindFirstChild("Hint")
    if hint then hint.TextTransparency = 1 end
    if bsDim then bsDim.BackgroundTransparency = 1 end
    if obWindow then
        if propWindow then propWindow.Visible = false end
        obWindow.AnchorPoint = Vector2.new(0.5, 0.5)
        -- 默认位置：对象树停靠屏幕左侧(左边距 OB_LEFT_MARGIN)，垂直保持与屏幕中心一致。
        -- 创建处与这里必须保持一致，否则第一次显示会跳一下。
        local obW = obWindow.Size.X.Offset
        if not obW or obW <= 0 then obW = obWindow:GetAttribute("BaseW") or 300 end
        obWindow.Position = UDim2.new(0, OB_LEFT_MARGIN + obW / 2, 0.5, 3)
        -- 属性浏览器贴着装在对象树旁边：横向像素偏移在建窗时按剩余空间算好存进 Attribute，
        -- 纵向与高度直接跟随对象树，两个窗口默认永远对齐。
        if propWindow then
            local dx = propWindow:GetAttribute("Dx") or (OB_LEFT_MARGIN + obW / 2)
            propWindow.Position = UDim2.new(0, dx, 0.5, 3)
            local oh = obWindow.Size.Y.Offset
            if oh and oh > 120 then
                propWindow.Size = UDim2.new(0, propWindow.Size.X.Offset, 0, oh)
            end
        end
        obWindow.Visible = false
    end
    if orbFrame then orbFrame.Visible = false end
end

function enterBuildSpace()
    if buildSpaceActive then return end
    if not buildSpaceRoot or not buildSpaceRoot.Parent then
        local ok, err = pcall(createBuildSpaceUI)
        if not ok then
            pcall(function() if buildSpaceRoot then buildSpaceRoot:Destroy() end end)
            buildSpaceRoot = nil
            ShowNotification("建造空间 UI 创建失败: " .. tostring(err), 4)
            return
        end
    end
    buildSpaceActive = true
    buildSpaceSavedPage = currentPage

    if #fadeableElements == 0 then collectFadeableElements() end
    fadeOutUI(0.28)
    bsFadeNavChrome(true, 0.28)
    task.delay(0.3, function()
        if buildSpaceActive and main and main.Parent then
            main.Visible = false
        end
    end)

    orbWasVisibleBeforeBuildSpace = orbFrame and orbFrame.Visible or false
    resetBuildSpaceChrome()
    buildSpaceRoot.Visible = true

    local tw = TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    svc.TweenService:Create(buildSpaceExit, tw, {Position = UDim2.new(1, -18, 0, 16)}):Play()
    local hint = buildSpaceRoot:FindFirstChild("Hint")
    if hint then
        svc.TweenService:Create(hint, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.18), {TextTransparency = 0.35}):Play()
    end

    if bsDim then
        -- 无黑色蒙版：始终完全透明，仅作为点击遮挡层保留结构
        bsDim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        bsDim.BackgroundTransparency = 1
    end
    if obWindow then
        local w, h = obWindow:GetAttribute("BaseW"), obWindow:GetAttribute("BaseH")
        if not w then w, h = obWindow.Size.X.Offset, obWindow.Size.Y.Offset end
        obWindow.Visible = true -- 关键修复：此前从未置为可见，所以窗口一直不显示
        obWindow.BackgroundTransparency = 1
        obWindow.Size = UDim2.new(0, w - 120, 0, h - 80)
        if obVeil then obVeil.BackgroundTransparency = 0 end
        svc.TweenService:Create(obWindow, TweenInfo.new(0.44, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0.1,
            Size = UDim2.new(0, w, 0, h),
        }):Play()
        if obVeil then
            obVeil.Visible = true
            obVeil.BackgroundTransparency = 0
            svc.TweenService:Create(obVeil, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.14), {BackgroundTransparency = 1}):Play()
            task.delay(0.75, function()
                if obVeil and obVeil.Parent and obVeil.BackgroundTransparency > 0.9 then obVeil.Visible = false end
            end)
        end
    end

    -- 属性浏览器：跟随「附加设置 → 属性窗口」的开关
    pcall(function() propWindowSetVisible((loadConfig()).propWindow == true) end)

    setBuildSpaceTab(buildSpaceTab or "build")
    obRender()
end

function exitBuildSpace()
    if not buildSpaceActive then return end
    buildSpaceActive = false

    local tw = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    svc.TweenService:Create(buildSpaceExit, tw, {Position = UDim2.new(1, -18, 0, -62)}):Play()
    local hint = buildSpaceRoot:FindFirstChild("Hint")
    if hint then
        svc.TweenService:Create(hint, TweenInfo.new(0.24), {TextTransparency = 1}):Play()
    end
    if bsDim then
        svc.TweenService:Create(bsDim, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
    end
    if obWindow then
        if obVeil then
            obVeil.Visible = true
            svc.TweenService:Create(obVeil, TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 0}):Play()
        end
        svc.TweenService:Create(obWindow, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, math.max(240, obWindow.Size.X.Offset - 110), 0, math.max(160, obWindow.Size.Y.Offset - 72)),
        }):Play()
    end

    task.delay(0.34, function()
        if buildSpaceActive then return end
        buildSpaceRoot.Visible = false
        if main and main.Parent then
            main.Visible = true
            fadeInUI(0.34)
        end
        bsFadeNavChrome(false, 0.34)
        if orbFrame then orbFrame.Visible = orbWasVisibleBeforeBuildSpace end
    end)
end

svc.UserInputService.InputBegan:Connect(function(input, handled)
    if not buildSpaceActive then return end
    if input.KeyCode ~= Enum.KeyCode.Escape then return end
    if handled then return end
    exitBuildSpace()
end)



pages["package"] = cloudPage
pages["house"] = editorPage
pages["terminal"] = consolePage
pages["gamepad-2"] = gamepadPage
function installModule(item)
    local safeName = __safeFilterName(item.name:gsub("%s+", "_"))
    if safeName == "" then safeName = "untitled" end
    local json = svc.HttpService:JSONEncode(item)
    if item.Type == "Patch" then
        ensurePatchFolder()
        writefile(patchFolder .. "/" .. safeName .. ".json", json)
        installedModules[item.name] = item
        AddLog("[Patch] Installed: " .. item.name .. " (v" .. tostring(item.Version or "?") .. ")", "info")
        ShowNotification(t("patch_installed_notify") or "Patch installed", 1)
        if item.Url and item.Url ~= "" then
            local ok, src = pcall(function()
                return game:HttpGet(item.Url)
            end)
            if ok and src and src ~= "" then
                local fn, err = loadstring(src)
                if fn then
                    xpcall(fn, function(e)
                        warn("[Patch] " .. item.name .. " error: " .. tostring(e))
                    end)
                else
                    warn("[Patch] " .. item.name .. " compile error: " .. tostring(err))
                end
            else
                warn("[Patch] " .. item.name .. " download failed")
            end
        end
    elseif item.Type == "UIUpdate" then
        ensureExportFolder()
        writefile(exportFolder .. "/" .. safeName .. ".json", json)
        if item.Url and item.Url ~= "" then
            local ok, src = pcall(function()
                return game:HttpGet(item.Url)
            end)
            if ok and src and src ~= "" then
                writefile(exportFolder .. "/" .. safeName .. ".lua", src)
                AddLog("[UIUpdate] Downloaded: " .. item.name .. " v" .. tostring(item.Version or "?"), "info")
                ShowNotification(t("ui_update_export"), 5)
            else
                AddLog("[UIUpdate] Download failed: " .. item.name, "error")
                ShowNotification(t("failed") .. " (UIUpdate)", 2)
            end
        end
    elseif item.Type == "UIPack" then
        ensureExportFolder()
        writefile(exportFolder .. "/" .. safeName .. ".json", json)
        installedModules[item.name] = item
        AddLog("[UIPack] Installed: " .. item.name .. " (v" .. tostring(item.Version or "?") .. ")", "info")
        ShowNotification(t("uipack_installed"), 1)
        if item.Url and item.Url ~= "" then
            local ok, src = pcall(function()
                return game:HttpGet(item.Url)
            end)
            if ok and src and src ~= "" then
                writefile(exportFolder .. "/" .. safeName .. ".lua", src)
            else
                warn("[UIPack] Download failed")
            end
        end
    else
        ensureModelFolder()
        if item.Type == "Script" then

            oldLua = storeScriptFolder .. "/" .. safeName .. ".lua"
            oldJson = modelFolder .. "/" .. safeName .. ".json"
            oldMeta = storeScriptFolder .. "/" .. safeName .. ".json"
            if isfile(oldLua) then delfile(oldLua) end
            if isfile(oldJson) then delfile(oldJson) end
            if isfile(oldMeta) then delfile(oldMeta) end

            if item.Url and item.Url ~= "" then
                local ok, src = pcall(function()
                    return game:HttpGet(item.Url)
                end)
                if ok and src and src ~= "" then
                    ensureStoreFolder()
                    writefile(storeScriptFolder .. "/" .. safeName .. ".lua", src)
                end
            end
            writefile(modelFolder .. "/" .. safeName .. ".json", json)
            installedModules[item.name] = item
            AddLog("[Script] Installed: " .. item.name .. " (v" .. tostring(item.Version or "?") .. ")", "info")
            ShowNotification(t("script_installed_notify"), 1)
            addStoreScriptToGamepad(item)
        elseif item.Type == "Model" then
            writefile(modelFolder .. "/" .. safeName .. ".json", json)
            installedModules[item.name] = item
            AddLog("[Model] Installed: " .. item.name .. " (v" .. tostring(item.Version or "?") .. ")", "info")
        end
    end
end
_G.__DeltaUI_installModule = installModule

function uninstallModule(name)
    local safeName = __safeFilterName(name:gsub("%s+", "_"))
    if safeName == "" then safeName = "untitled" end
    local fp = modelFolder .. "/" .. safeName .. ".json"
    local ok1, err1 = pcall(function()
        if isfile(fp) then delfile(fp) end
    end)
    if not ok1 then warn("[Uninstall] Failed to delete model: " .. tostring(err1)) end
    local pfp = patchFolder .. "/" .. safeName .. ".json"
    local ok2, err2 = pcall(function()
        if isfile(pfp) then delfile(pfp) end
    end)
    if not ok2 then warn("[Uninstall] Failed to delete patch: " .. tostring(err2)) end
    local sfp = storeScriptFolder .. "/" .. safeName .. ".json"
    local ok3, err3 = pcall(function()
        if isfile(sfp) then delfile(sfp) end
    end)
    if not ok3 then warn("[Uninstall] Failed to delete store meta: " .. tostring(err3)) end
    local lfp = storeScriptFolder .. "/" .. safeName .. ".lua"
    local ok4, err4 = pcall(function()
        if isfile(lfp) then delfile(lfp) end
    end)
    if not ok4 then warn("[Uninstall] Failed to delete store script: " .. tostring(err4)) end
    installedModules[name] = nil
    AddLog("[Uninstall] " .. name, "info")
end
_G.__DeltaUI_uninstallModule = uninstallModule

infoCurrentItem = nil
infoOverlay = create("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.7, BorderSizePixel = 0, Visible = false, ZIndex = 300, Active = true})
infoOverlay.Parent = screenGui
infoCard = create("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 320, 0, 280), BackgroundColor3 = theme.surface, BackgroundTransparency = 0.15, BorderSizePixel = 0, ZIndex = 301, Active = true})
corner(16, infoCard)
infoCard.Parent = infoOverlay
infoTitle = create("TextLabel", {Position = UDim2.new(0, 20, 0, 16), Size = UDim2.new(1, -40, 0, 24), BackgroundTransparency = 1, Text = "", TextColor3 = theme.text, TextSize = 16, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 302})
infoTitle.Parent = infoCard
infoAuthor = create("TextLabel", {Position = UDim2.new(0, 20, 0, 44), Size = UDim2.new(1, -40, 0, 18), BackgroundTransparency = 1, Text = "", TextColor3 = theme.textDim, TextSize = 12, Font = Enum.Font.SourceSans, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 302})
infoAuthor.Parent = infoCard
infoVersion = create("TextLabel", {Position = UDim2.new(0, 20, 0, 64), Size = UDim2.new(1, -40, 0, 18), BackgroundTransparency = 1, Text = "", TextColor3 = theme.accent, TextSize = 12, Font = Enum.Font.SourceSans, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 302})
infoVersion.Parent = infoCard
infoType = create("TextLabel", {Position = UDim2.new(0, 20, 0, 84), Size = UDim2.new(1, -40, 0, 18), BackgroundTransparency = 1, Text = "", TextColor3 = theme.textDim, TextSize = 12, Font = Enum.Font.SourceSans, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 302})
infoType.Parent = infoCard
infoServersTitle = create("TextLabel", {Position = UDim2.new(0, 20, 0, 108), Size = UDim2.new(1, -40, 0, 18), BackgroundTransparency = 1, Text = t("supported_servers_title"), TextColor3 = theme.text, TextSize = 12, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 302})
infoServersTitle.Parent = infoCard
infoServersScroll = create("ScrollingFrame", {Position = UDim2.new(0, 20, 0, 128), Size = UDim2.new(1, -40, 0, 80), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = theme.textDim, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 302})
infoServersScroll.Parent = infoCard
create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)}).Parent = infoServersScroll
create("UIPadding", {PaddingLeft = UDim.new(0, 0), PaddingRight = UDim.new(0, 0), PaddingTop = UDim.new(0, 0), PaddingBottom = UDim.new(0, 4)}).Parent = infoServersScroll
local infoScrollHint = create("Frame", {Position = UDim2.new(0.5, -10, 1, -62), Size = UDim2.new(0, 20, 0, 14), BackgroundTransparency = 1, ZIndex = 303})
infoScrollHint.Parent = infoCard
local infoScrollHintIcon = GetIcon("chevron-down", UDim2.new(0, 14, 0, 14), theme.textDim)
if infoScrollHintIcon then
    infoScrollHintIcon.Position = UDim2.new(0.5, -7, 0, 0)
    infoScrollHintIcon.Parent = infoScrollHint
end
infoBackBtn = create("TextButton", {Position = UDim2.new(0.5, -50, 1, -44), Size = UDim2.new(0, 100, 0, 32), BackgroundColor3 = theme.accent, BackgroundTransparency = 0.25, Text = "", BorderSizePixel = 0, ZIndex = 302})
applyGradient(infoBackBtn, theme.accent, theme.accent2, 120)
corner(8, infoBackBtn)
infoBackBtn.Parent = infoCard
infoBackText = create("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = t("back"), TextColor3 = Color3.fromRGB(255,255,255), TextSize = 13, Font = Enum.Font.SourceSansBold, ZIndex = 303})
infoBackText.Parent = infoBackBtn
infoBackBtn.MouseButton1Click:Connect(function()
    infoOverlay.Visible = false
end)
infoDeleteBtn = create("TextButton", {Position = UDim2.new(1, -44, 1, -44), Size = UDim2.new(0, 32, 0, 32), BackgroundColor3 = theme.red, BackgroundTransparency = 0.25, Text = "", BorderSizePixel = 0, ZIndex = 302, Visible = false})
corner(8, infoDeleteBtn)
infoDeleteBtn.Parent = infoCard
deleteIcon = GetIcon("trash-2", UDim2.new(0, 14, 0, 14), Color3.fromRGB(255,255,255))
if deleteIcon then
    deleteIcon.Position = UDim2.new(0.5, -7, 0.5, -7)
    deleteIcon.Parent = infoDeleteBtn
end
infoDeleteBtn.MouseButton1Click:Connect(function()
    if infoCurrentItem and infoCurrentItem.Type == "Patch" then
        uninstallModule(infoCurrentItem.name)
        ShowNotification(t("patch_deleted"), 1)
        infoOverlay.Visible = false
        refreshCloudList("", false)
    end
end)
infoOverlay.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local pos = input.Position
        local cardPos = infoCard.AbsolutePosition
        local cardSize = infoCard.AbsoluteSize
        if pos.X < cardPos.X or pos.X > cardPos.X + cardSize.X or pos.Y < cardPos.Y or pos.Y > cardPos.Y + cardSize.Y then
            infoOverlay.Visible = false
        end
    end
end)

function addStoreScriptToGamepad(item)
    ensureStoreFolder()
    local safeName = __safeFilterName(item.name:gsub("%s+", "_"))
    if safeName == "" then safeName = "untitled" end
    local meta = {
        name = item.name,
        Type = "Script",
        Desc = item.Desc,
        Url = item.Url,
        Version = item.Version,
        fromStore = true,
        Servers = item.Servers,
        Icon = item.Icon
    }
    local json = svc.HttpService:JSONEncode(meta)
    writefile(storeScriptFolder .. "/" .. safeName .. ".json", json)
    installedModules[item.name] = meta
    refreshScriptList(searchInput.Text)
end
_G.__DeltaUI_removeStoreScript = removeStoreScript

function removeStoreScript(name)
    ensureStoreFolder()
    local safeName = __safeFilterName(name:gsub("%s+", "_"))
    if safeName == "" then safeName = "untitled" end
    local fp = storeScriptFolder .. "/" .. safeName .. ".json"
    if isfile(fp) then
        delfile(fp)
    end
    installedModules[name] = nil
    refreshScriptList(searchInput.Text)
end

function makeModuleCard(item, layoutOrder, isManageMode, filter)
    filter = filter or ""
        local isInstalled = installedModules[item.name] ~= nil
    local localVersion = isInstalled and installedModules[item.name].Version or nil
    local remoteVersion = item.Version
    local hasUpdate = isInstalled and localVersion and remoteVersion and localVersion ~= remoteVersion

    local card = create("Frame", {Size = UDim2.new(0, 180, 0, 140), BackgroundColor3 = theme.surface, BackgroundTransparency = 0.25, BorderSizePixel = 0, LayoutOrder = layoutOrder, ZIndex = 4})
    corner(10, card)

    local iconContainer = create("Frame", {Position = UDim2.new(0, 8, 0, 8), Size = UDim2.new(0, 36, 0, 36), BackgroundColor3 = theme.surfaceLight, BackgroundTransparency = 0.4, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 5})
    corner(6, iconContainer)
    iconContainer.Parent = card

    local function clearIconChildren()
        for _, child in pairs(iconContainer:GetChildren()) do
            if child:IsA("ImageLabel") and child ~= iconContainer then
                child:Destroy()
            end
        end
    end

    if item.Icon and item.Icon ~= "" then
        local parsedIcon = getCachedIcon(item.Icon, item.name)
        if not parsedIcon or parsedIcon == "" then
            parsedIcon = ParseImageAsset(item.Icon)
        end
        if parsedIcon and parsedIcon ~= "" then
            clearIconChildren()
            local iconImg = create("ImageLabel", {Size = UDim2.new(1, -8, 1, -8), Position = UDim2.new(0, 4, 0, 4), BackgroundTransparency = 1, Image = parsedIcon, ImageTransparency = 1, ScaleType = Enum.ScaleType.Fit, ZIndex = 6})
            iconImg.Parent = iconContainer
            corner(4, iconImg)
            svc.TweenService:Create(iconImg, TweenInfo.new(0.4), {ImageTransparency = 0}):Play()
        else
            clearIconChildren()
        end
    else
        clearIconChildren()
    end

    local nameLabel = create("TextLabel", {Position = UDim2.new(0, 50, 0, 8), Size = UDim2.new(1, -58, 0, 20), BackgroundTransparency = 1, Text = item.name, TextColor3 = theme.text, TextSize = 13, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5})
    nameLabel.Parent = card

    if item.Type == "Patch" and not isManageMode then
        local patchBadge = create("Frame", {Position = UDim2.new(1, -55, 0, 28), Size = UDim2.new(0, 50, 0, 14), BackgroundColor3 = theme.red, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 6})
        corner(7, patchBadge)
        local patchBadgeText = create("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = t("patch_must_install"), TextColor3 = Color3.fromRGB(255,255,255), TextSize = 8, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 7})
        patchBadgeText.Parent = patchBadge
        patchBadge.Parent = card
    end

    local authorText = item.Author and item.Author ~= "" and item.Author or "Unknown"
    local authorLabel = create("TextLabel", {Position = UDim2.new(0, 50, 0, 28), Size = UDim2.new(1, -58, 0, 16), BackgroundTransparency = 1, Text = t("by_label") .. authorText, TextColor3 = theme.textDim, TextSize = 10, Font = Enum.Font.SourceSans, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5})
    authorLabel.Parent = card
    local hasPatch = (item.Type == "Patch")
    if filter and filter ~= "" then
        local isMatch = false
        if item.Servers and type(item.Servers) == "table" then
            for _, server in ipairs(item.Servers) do
                if tostring(server):lower():find(filter:lower()) then
                    isMatch = true
                    break
                end
            end
        end
        if isMatch then
            local badgeY = hasPatch and 44 or 28
            local matchBadge = create("Frame", {Position = UDim2.new(1, -60, 0, badgeY), Size = UDim2.new(0, 55, 0, 14), BackgroundColor3 = theme.accent, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 6})
            applyGradient(matchBadge, theme.accent, theme.accent2, 120)
            corner(7, matchBadge)
            local matchBadgeText = create("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = t("match_search"), TextColor3 = Color3.fromRGB(255,255,255), TextSize = 8, Font = Enum.Font.SourceSansBold, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 7})
            matchBadgeText.Parent = matchBadge
            matchBadge.Parent = card
        end
    end

    local descLabel = create("TextLabel", {Position = UDim2.new(0, 8, 0, 44), Size = UDim2.new(1, -16, 0, 48), BackgroundTransparency = 1, Text = item.Desc or "", TextColor3 = theme.textDim, TextSize = 10, Font = Enum.Font.SourceSans, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, ZIndex = 5})
    descLabel.Parent = card

    local versionLabel = create("TextLabel", {Position = UDim2.new(0, 8, 0, 90), Size = UDim2.new(1, -16, 0, 14), BackgroundTransparency = 1, Text = "", TextColor3 = theme.textDim, TextSize = 9, Font = Enum.Font.SourceSans, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5})
    versionLabel.Parent = card
    if isManageMode and isInstalled then
        versionLabel.Text = t("local_version") .. (localVersion or "?") .. " | Remote: " .. (remoteVersion or "?")
    elseif hasUpdate then
        versionLabel.Text = t("update_version") .. (localVersion or "?") .. " -> " .. (remoteVersion or "?")
    end

    local actionBtn = create("TextButton", {Position = UDim2.new(0, 8, 1, -36), Size = UDim2.new(1, -44, 0, 28), BackgroundColor3 = isManageMode and (hasUpdate and theme.accent or theme.red) or (isInstalled and (hasUpdate and theme.accent or theme.surfaceLight) or theme.accent), BackgroundTransparency = 0.25, Text = "", BorderSizePixel = 0, ZIndex = 5})
    corner(6, actionBtn)
    actionBtn.Parent = card

    local progressBar = create("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(34, 197, 94), BackgroundTransparency = 0.4, BorderSizePixel = 0, ZIndex = 4})
    corner(6, progressBar)
    progressBar.Parent = actionBtn

    local actionText = create("TextLabel", {Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = isManageMode and (hasUpdate and t("update") or t("uninstall")) or (isInstalled and (hasUpdate and t("update") or t("installed")) or t("install")), TextColor3 = Color3.fromRGB(255,255,255), TextSize = 11, Font = Enum.Font.SourceSansBold, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 6})
    actionText.Parent = actionBtn

    local actionSubText = create("TextLabel", {Position = UDim2.new(0, 0, 0.65, 0), Size = UDim2.new(1, 0, 0.35, 0), BackgroundTransparency = 1, Text = "", TextColor3 = Color3.fromRGB(200,200,200), TextSize = 8, Font = Enum.Font.SourceSans, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 6})
    actionSubText.Parent = actionBtn
    actionSubText.Visible = false

    local actionIcon = GetIcon(isManageMode and (hasUpdate and "download" or "trash-2") or (isInstalled and "check" or "download"), UDim2.new(0, 12, 0, 12), Color3.fromRGB(255,255,255))
    if actionIcon then
        actionIcon.Position = UDim2.new(0, 8, 0.5, -6)
        actionIcon.Parent = actionBtn
    end

    local checkIcon = nil
    if not isManageMode then
        checkIcon = GetIcon("check", UDim2.new(0, 12, 0, 12), Color3.fromRGB(255,255,255))
        if checkIcon then
            checkIcon.Position = UDim2.new(0, 8, 0.5, -6)
            checkIcon.Parent = actionBtn
            checkIcon.Visible = isInstalled and not hasUpdate
        end
    end
    local loaderIcon = GetIcon("loader", UDim2.new(0, 12, 0, 12), Color3.fromRGB(255,255,255))
    if loaderIcon then
        loaderIcon.Position = UDim2.new(0, 8, 0.5, -6)
        loaderIcon.Visible = false
        loaderIcon.Parent = actionBtn
    end

    local infoBtn = create("TextButton", {Position = UDim2.new(1, -32, 1, -36), Size = UDim2.new(0, 28, 0, 28), BackgroundColor3 = theme.surfaceLight, BackgroundTransparency = 0.3, Text = "", BorderSizePixel = 0, ZIndex = 5})
    corner(6, infoBtn)
    infoBtn.Parent = card
    local infoIcon = GetIcon("info", UDim2.new(0, 14, 0, 14), theme.text)
    if infoIcon then
        infoIcon.Position = UDim2.new(0.5, -7, 0.5, -7)
        infoIcon.Parent = infoBtn
    end

    local downloading = false

    local function setProgress(percent, text, subText)
        svc.TweenService:Create(progressBar, TweenInfo.new(0.15, Enum.EasingStyle.Linear), {Size = UDim2.new(percent / 100, 0, 1, 0)}):Play()
        actionText.Text = text or ""
        actionSubText.Text = subText or ""
    end

    local function startDownload()
        if isInstalled and not hasUpdate then
            return
        end
        if downloading then return end
        local downloading = true
        actionBtn.BackgroundColor3 = theme.surface
        actionBtn.BackgroundTransparency = 0.5
        progressBar.Size = UDim2.new(0, 0, 1, 0)
        if actionIcon then actionIcon.Visible = false end
        if loaderIcon then loaderIcon.Visible = true end
        actionText.Position = UDim2.new(0, 0, 0, -2)
        actionText.Text = t("downloading")
        actionSubText.Visible = true
        actionSubText.Text = "0KB/0KB"

        rotation = 0
        local conn = svc.RunService.RenderStepped:Connect(function(dt)
            rotation = rotation + 360 * dt
            if loaderIcon then
                loaderIcon.Rotation = rotation
            end
        end)

        local receivedBytes = 0
        local totalBytes = 0

        task.spawn(function()
            local src = game:HttpGet(item.Url)

            if not src then

                local src2 = game:HttpGet(item.Url)

                local src = src2
                if src then
                    totalBytes = #src
                    receivedBytes = totalBytes
                end
            end

            conn:Disconnect()

            if src then
                local size = #src
                local sizeText, totalText
                if size > 1048576 then
                    sizeText = string.format("%.1fMB", size / 1048576)
                    totalText = sizeText
                else
                    sizeText = string.format("%.0fKB", size / 1024)
                    totalText = sizeText
                end

                svc.TweenService:Create(progressBar, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 1, 0)}):Play()
                actionSubText.Text = sizeText .. "/" .. totalText
                task.wait(0.5)

                installModule(item)
                isInstalled = true
                hasUpdate = false

                svc.TweenService:Create(progressBar, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
                svc.TweenService:Create(actionBtn, TweenInfo.new(0.3), {BackgroundColor3 = theme.accent, BackgroundTransparency = 0.25}):Play()
                actionText.Text = t("complete")
                actionSubText.Visible = false
                if loaderIcon then loaderIcon.Visible = false end
                if checkIcon then checkIcon.Visible = true end

                task.wait(0.8)
                svc.TweenService:Create(actionText, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
                if checkIcon then svc.TweenService:Create(checkIcon, TweenInfo.new(0.2), {ImageTransparency = 1}):Play() end
                task.wait(0.2)
                actionText.Text = t("installed")
                actionText.Position = UDim2.new(0, 0, 0, 0)
                actionSubText.Text = ""
                svc.TweenService:Create(actionText, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
                if checkIcon then
                    checkIcon.Visible = true
                    svc.TweenService:Create(checkIcon, TweenInfo.new(0.2), {ImageTransparency = 0}):Play()
                end
                if actionIcon then actionIcon.Visible = false end
                actionBtn.BackgroundColor3 = theme.surfaceLight
                downloading = false
                actionBtn.Active = true

                if item.Type == "Script" then
                    addStoreScriptToGamepad(item)
                    AddLog("[Script] Installed to Gamepad: " .. item.name, "info")
                elseif item.Type == "UIUpdate" then
                    AddLog("[UIUpdate] Saved to Export: " .. item.name, "info")
                end
            else
                actionBtn.BackgroundColor3 = theme.red
                actionText.Position = UDim2.new(0, 0, 0, 0)
                actionText.Text = t("failed")
                actionSubText.Visible = false
                actionSubText.Text = ""
                if loaderIcon then loaderIcon.Visible = false end
                if actionIcon then actionIcon.Visible = true end
                downloading = false
                AddLog("[Cloud] Download failed: " .. item.name, "error")
            end
        end)
    end

    actionBtn.MouseButton1Click:Connect(function()
        if actionBtn.Active == false then return end
        actionBtn.Active = false
        if isManageMode then
            if item.Type == "Patch" then
                ShowNotification(t("patch_cannot_delete"), 1)
                actionBtn.Active = true
                return
            end
            if hasUpdate then
                actionBtn.BackgroundColor3 = theme.surface
                actionBtn.BackgroundTransparency = 0.5
                progressBar.Size = UDim2.new(0, 0, 1, 0)
                progressBar.BackgroundColor3 = theme.accent
                if actionIcon then actionIcon.Visible = false end
                if loaderIcon then loaderIcon.Visible = true end
                actionText.Text = t("updating")
                actionSubText.Visible = true
                actionSubText.Text = "0%"
                local rotation = 0
                local conn = svc.RunService.RenderStepped:Connect(function(dt)
                    rotation = rotation + 360 * dt
                    if loaderIcon then
                        loaderIcon.Rotation = rotation
                    end
                end)
                svc.TweenService:Create(progressBar, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 1, 0)}):Play()
                task.wait(0.4)
                actionSubText.Text = "100%"
                conn:Disconnect()
                task.wait(0.2)
                local src = game:HttpGet(item.Url)
                if src then
                    installModule(item)
                    isInstalled = true
                    hasUpdate = false
                    localVersion = remoteVersion
                    versionLabel.Text = t("local_version") .. (localVersion or "?") .. " | Remote: " .. (remoteVersion or "?")
                    svc.TweenService:Create(progressBar, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
                    svc.TweenService:Create(actionBtn, TweenInfo.new(0.3), {BackgroundColor3 = theme.red, BackgroundTransparency = 0.25}):Play()
                    actionText.Text = t("uninstall")
                    actionSubText.Visible = false
                    if loaderIcon then loaderIcon.Visible = false end
                    if actionIcon then actionIcon.Visible = true end
                    local updatedIcon = GetIcon("trash-2", UDim2.new(0, 12, 0, 12), Color3.fromRGB(255,255,255))
                    if updatedIcon then
                        actionIcon.Image = updatedIcon.Image
                    end
                    AddLog("[Update] " .. item.name .. " updated to v" .. (remoteVersion or "?"), "info")
                else
                    actionBtn.BackgroundColor3 = theme.red
                    actionText.Text = t("failed")
                    actionSubText.Visible = false
                    if loaderIcon then loaderIcon.Visible = false end
                    if actionIcon then actionIcon.Visible = true end
                    AddLog("[Update] Failed to update " .. item.name, "error")
                end
            else
                actionBtn.BackgroundColor3 = theme.red
                actionText.Text = t("uninstalling")
                if actionIcon then actionIcon.Visible = false end
                local spinIcon = GetIcon("loader", UDim2.new(0, 12, 0, 12), Color3.fromRGB(255,255,255))
                if spinIcon then
                    spinIcon.Position = UDim2.new(0, 8, 0.5, -6)
                    spinIcon.Parent = actionBtn
                    rotation = 0
                    local conn = svc.RunService.RenderStepped:Connect(function(dt)
                        rotation = rotation + 360 * dt
                        spinIcon.Rotation = rotation
                    end)
                    task.wait(0.8)
                    conn:Disconnect()
                    spinIcon:Destroy()
                end
                uninstallModule(item.name)
                actionBtn.BackgroundColor3 = theme.surface
                actionBtn.BackgroundTransparency = 0.5
                progressBar.Size = UDim2.new(0, 0, 1, 0)
                progressBar.BackgroundColor3 = theme.red
                if actionIcon then actionIcon.Visible = false end
                if loaderIcon then loaderIcon.Visible = true end
                actionText.Text = t("uninstalling")
                actionSubText.Visible = true
                actionSubText.Text = "0%"
                local rotation = 0
                local conn = svc.RunService.RenderStepped:Connect(function(dt)
                    rotation = rotation + 360 * dt
                    if loaderIcon then
                        loaderIcon.Rotation = rotation
                    end
                end)
                svc.TweenService:Create(progressBar, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 1, 0)}):Play()
                task.wait(0.4)
                actionSubText.Text = "100%"
                conn:Disconnect()
                task.wait(0.2)
                svc.TweenService:Create(progressBar, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
                svc.TweenService:Create(actionBtn, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
                for _, d in pairs(card:GetDescendants()) do
                    if d:IsA("GuiObject") then
                        local fadeProps = {}
                        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                            fadeProps.TextTransparency = 1
                        end
                        if d:IsA("ImageLabel") or d:IsA("ImageButton") then
                            fadeProps.ImageTransparency = 1
                        end
                        if next(fadeProps) then
                            svc.TweenService:Create(d, TweenInfo.new(0.15), fadeProps):Play()
                        end
                    end
                end
                task.wait(0.15)
                svc.TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1}):Play()
                task.wait(0.25)
                card:Destroy()
                if refreshCloudList then
                    refreshCloudList(cloudSearchInput.Text, false)
                end
            end
        elseif isInstalled and not hasUpdate then
            local originalColor = actionBtn.BackgroundColor3
            actionBtn.BackgroundColor3 = theme.surfaceLight
            task.wait(0.15)
            actionBtn.BackgroundColor3 = originalColor
        else
            startDownload()
        end
    end

    )

    infoBtn.MouseButton1Click:Connect(function()
        infoCurrentItem = item
        infoTitle.Text = item.name
        infoAuthor.Text = t("author_label") .. (item.Author and item.Author ~= "" and item.Author or "Unknown")
        infoVersion.Text = t("version_label") .. (item.Version or "?")
        if isInstalled and localVersion then
            infoVersion.Text = infoVersion.Text .. " (Installed: " .. localVersion .. ")"
        end
        infoType.Text = t("type_label") .. (item.Type or "Unknown")
        for _, child in pairs(infoServersScroll:GetChildren()) do
            if child:IsA("TextLabel") then
                child:Destroy()
            end
        end
        local currentFilter = cloudSearchInput.Text
        local searchPlaceholder = t("search_cloud_placeholder")
                if item.Servers and type(item.Servers) == "table" and #item.Servers > 0 then
            local sortedServers = {}
            for _, server in ipairs(item.Servers) do
                table.insert(sortedServers, tostring(server))
            end
            if currentFilter and currentFilter ~= "" then
                table.sort(sortedServers, function(a, b)
                    local aMatch = a:lower():find(currentFilter:lower()) ~= nil
                    local bMatch = b:lower():find(currentFilter:lower()) ~= nil
                    if aMatch and not bMatch then return true end
                    if bMatch and not aMatch then return false end
                    return a < b
                end)
            end
            for i, server in ipairs(sortedServers) do
                local isMatch = currentFilter ~= "" and server:lower():find(currentFilter:lower()) ~= nil
                local serverLabel = create("TextLabel", {Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = "• " .. server, TextColor3 = isMatch and theme.accent or theme.textDim, TextSize = 11, Font = Enum.Font.SourceSans, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 303})
                serverLabel.Parent = infoServersScroll
            end
        else
            local emptyLabel = create("TextLabel", {Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = t("no_server_restrictions"), TextColor3 = theme.textDim, TextSize = 11, Font = Enum.Font.SourceSans, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 303})
            emptyLabel.Parent = infoServersScroll
        end
        if infoDeleteBtn then
            infoDeleteBtn.Visible = (item.Type == "Patch" and isInstalled)
        end
        infoOverlay.Visible = true
    end)

    return card
end
_G.__DeltaUI_cloudRefreshLock = cloudRefreshLock

cloudRefreshLock = false
pendingCloudRefresh = nil

function refreshCloudList(filter, manageMode)
        if cloudRefreshLock then
        pendingCloudRefresh = {filter = filter or "", manageMode = manageMode}
        return
    end
    cloudRefreshLock = true

    for _, child in pairs(cloudScroll:GetChildren()) do
        if not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end

    local idx = 0
    if manageMode then
        loadInstalledModules()
        local seen = {}
        for name, item in pairs(installedModules) do
            if not seen[item.name] then
                seen[item.name] = true
                local matchesFilter = not filter or filter == "" or item.name:lower():find(filter:lower()) or (item.Desc and item.Desc:lower():find(filter:lower()))
                if not matchesFilter and item.Servers and type(item.Servers) == "table" then
                    for _, server in ipairs(item.Servers) do
                        if tostring(server):lower():find(filter:lower()) then
                            matchesFilter = true
                            break
                        end
                    end
                    if not matchesFilter and #item.Servers == 1 and tostring(item.Servers[1]):lower() == "all" then
                        local universalTokens = {["通用"]=true, ["飞行"]=true, ["加速"]=true, ["天空盒"]=true, ["甩飞"]=true, ["透视"]=true, ["绘制"]=true, ["esp"]=true, ["自瞄"]=true, ["追踪"]=true}
                        if universalTokens[filter:lower()] then
                            matchesFilter = true
                        end
                    end
                end
                if matchesFilter then
                    idx = idx + 1
                    local card = makeModuleCard(item, idx, true, filter)
                    card.Parent = cloudScroll
                    card.BackgroundTransparency = 1
                    card.Size = UDim2.new(0, 180, 0, 140)
                    svc.TweenService:Create(card, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.25, Size = UDim2.new(0, 180, 0, 140)}):Play()
                end
            end
        end
        if idx == 0 then
            local emptyLabel = create("TextLabel", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Text = t("no_installed_packages"), TextColor3 = theme.textDim, TextSize = 14, Font = Enum.Font.SourceSansBold, ZIndex = 4})
            emptyLabel.Parent = cloudScroll
            svc.TweenService:Create(emptyLabel, TweenInfo.new(0.15), {TextTransparency = 0}):Play()
        end
    else
        local ok, raw = pcall(function()
            return game:HttpGet("https://raw.githubusercontent.com/WasKKal/-/main/model.json")
        end)
        if not ok or not raw or raw == "" then
            AddLog("[Cloud] Failed to fetch module list: " .. tostring(raw), "error")
            cloudRefreshLock = false
            if pendingCloudRefresh then
                local req = pendingCloudRefresh
                pendingCloudRefresh = nil
                refreshCloudList(req.filter, req.manageMode)
            end
            return
        end
        local ok2, list = pcall(function()
            return svc.HttpService:JSONDecode(raw)
        end)
        if not ok2 or not list or type(list) ~= "table" then
            AddLog("[Cloud] JSON parse error: " .. tostring(list), "error")
            cloudRefreshLock = false
            if pendingCloudRefresh then
                local req = pendingCloudRefresh
                pendingCloudRefresh = nil
                refreshCloudList(req.filter, req.manageMode)
            end
            return
        end
        if list.UIVersion then
            checkUiVersion(list.UIVersion)
        end
        local items = {}
        if list.modules and type(list.modules) == "table" then
            items = list.modules
        elseif list[1] then
            items = list
        else
            items = {list}
        end
        local remotePatchNames = {}
        local remoteUIVersion = list.UIVersion
        checkUiVersion(remoteUIVersion)
        for _, item in ipairs(items) do
            if type(item) == "table" and item.name and item.Type ~= "Model" then
                if not (item.Type == "UIUpdate" and tostring(remoteUIVersion) == tostring(UI_VERSION)) then
                if item.Type == "Patch" then
                    remotePatchNames[item.name] = true
                    if not installedModules[item.name] then
                        ShowNotification(t("patch_available") .. ": " .. item.name, 3, function()
            switchPage("package")
        end)
                    end
                end
                local shouldSkip = (item.Type == "Patch" and installedModules[item.name] and not manageMode)
                if not shouldSkip then
                    local matchesFilter = not filter or filter == "" or item.name:lower():find(filter:lower()) or (item.Desc and item.Desc:lower():find(filter:lower()))
                    if not matchesFilter and item.Servers and type(item.Servers) == "table" then
                        for _, server in ipairs(item.Servers) do
                            if tostring(server):lower():find(filter:lower()) then
                                matchesFilter = true
                                break
                            end
                        end
                    end
                    if matchesFilter then
                        idx = idx + 1
                        local card = makeModuleCard(item, idx, false, filter)
                        card.Parent = cloudScroll
                        card.BackgroundTransparency = 1
                        card.Size = UDim2.new(0, 180, 0, 140)
                        svc.TweenService:Create(card, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.25, Size = UDim2.new(0, 180, 0, 140)}):Play()
                    end
                end
                end
            end
        end
        if idx == 0 then
            local emptyLabel = create("TextLabel", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Text = t("no_packages_available"), TextColor3 = theme.textDim, TextSize = 14, Font = Enum.Font.SourceSansBold, ZIndex = 4})
            emptyLabel.Parent = cloudScroll
            svc.TweenService:Create(emptyLabel, TweenInfo.new(0.15), {TextTransparency = 0}):Play()
        end
        if cloudScroll and cloudGrid and cloudScroll.Parent then
            task.defer(function()
                if cloudScroll and cloudGrid and cloudScroll.Parent then
                    local absSize = cloudGrid.AbsoluteContentSize
                    if absSize then
                        cloudScroll.CanvasSize = UDim2.new(0, 0, 0, absSize.Y + 16)
                    end
                end
            end)
        end
        loadInstalledModules()
        for name, item in pairs(installedModules) do
            if item.Type == "Patch" then
                local stillExists = false
                for _, remoteItem in ipairs(items) do
                    if remoteItem.name == name and remoteItem.Type == "Patch" then
                        stillExists = true
                        break
                    end
                end
                if not stillExists then
                    uninstallModule(name)
                    ShowNotification(t("patch_not_found"), 2)
                end
            end
        end
    end
    cloudRefreshLock = false
    if pendingCloudRefresh then
        local req = pendingCloudRefresh
        pendingCloudRefresh = nil
        refreshCloudList(req.filter, req.manageMode)
    end
end
cloudSearchInput:GetPropertyChangedSignal("Text"):Connect(function()
    refreshScriptBloxList(cloudSearchInput.Text)
end)

task.spawn(function()
    task.wait(0.5)
    local ok, err = pcall(function()
        refreshScriptBloxList("")
    end)
    if not ok then
        warn("[Cloud] Initial refresh error: " .. tostring(err))
    end
end)

cleanupOldUI()
_G.__DeltaUI_cleaned = true

function applyBypassMode()
    local cfg = loadConfig()
    if not cfg.bypassUiDetection then return end
    bypassModeActive = true
        local function makeInstantTween(target, info, props)
        if target and type(props) == "table" then
            for k, v in pairs(props) do
                pcall(function() target[k] = v end)
            end
        end
        local fakeSignal = {}
        fakeSignal.Connect = function(_, cb)
            if type(cb) == "function" then task.spawn(function() pcall(cb) end) end
            return {Disconnect = function() end}
        end
        local fake = {Play = function() end, Cancel = function() end, Pause = function() end}
        fake.Completed = fakeSignal
        return fake
    end
    svc.TweenService = setmetatable({Create = function(_, target, info, props) return makeInstantTween(target, info, props) end}, {__index = realTweenService})
        pages["terminal"] = nil
    if consolePage then consolePage.Visible = false end
                navNames = {"house", "gamepad-2", "package", "settings"}
    btnXPositions = btnYPositions   
    if navButtons and navButtons["terminal"] then navButtons["terminal"].Visible = false end
        if logoutBtn then
            logoutBtn.AnchorPoint = Vector2.new(0.5, 0.5)
            logoutBtn.Position = UDim2.new(0.5, 107, 0.5, 1)
        end
        if settingsScroll and rowBypass then
            
            
            
            local node = rowBypass
            while node and node ~= settingsScroll do
                node.Visible = true
                local parent = node.Parent
                if parent then
                    for _, child in ipairs(parent:GetChildren()) do
                        if child ~= node and child:IsA("GuiObject") then
                            child.Visible = false
                        end
                    end
                end
                node = parent
            end
        end
        for _, lbl in ipairs(allFpsLabels or {}) do if lbl and lbl.Parent then lbl.Text = "N/A" end end
    for _, lbl in ipairs(allPingLabels or {}) do if lbl and lbl.Parent then lbl.Text = "N/A" end end
        pcall(function() switchPage("settings") end)
end
applyBypassMode()

main.Size = UDim2.new(0, 0, 0, 0)
main.Visible = true
svc.TweenService:Create(main, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 1, 0)}):Play()

AddLog("[Delta UI-Pro] Core Loaded - " .. uiVersion, "info")
ShowNotification(t("core_loaded"), 1)
initFloatingBallIcon()

if refreshScriptList then
    refreshScriptList("")
end

local cfg = loadConfig()
if cfg.language then
    settingsData.language = cfg.language
else
    settingsData.language = "zh"
    cfg.language = "zh"
    saveConfig(cfg)
end
if cfg.errorTranslation ~= nil then
    settingsData.errorTranslation = cfg.errorTranslation
else
    settingsData.errorTranslation = true
end
if cfg.blockAssetErrors ~= nil then
    settingsData.blockAssetErrors = cfg.blockAssetErrors
else
    settingsData.blockAssetErrors = true
end
if cfg.customLabel and cfg.customLabel ~= "" then
    if labelText and labelText.Parent then
        labelText.Text = cfg.customLabel
        local textWidth = labelText.TextBounds.X + 28
        labelPill.Size = UDim2.new(0, math.max(55, textWidth), 0, 22)
    end
    if labelInput and labelInput.Parent then
        labelInput.Text = cfg.customLabel
    end
end
if cfg.autoTranslate then
    task.delay(1, function()
        startAutoTranslate()
    end)
end
if cfg.translatePaths and type(cfg.translatePaths) == "table" then
    for _, path in ipairs(cfg.translatePaths) do
        if path == t("playergui_path") then
            local pg = svc.Players.LocalPlayer:FindFirstChild("PlayerGui")
            if pg then
                scanAndTranslate(pg)
            end
        else
            scanAndTranslate(svc.CoreGui)
        end
    end
end
for _, ref in ipairs(settingsData.uiRefs) do
    if ref.element and ref.element.Parent then
        if ref.element:IsA("TextBox") then
            -- 输入框的提示文本应作为 PlaceholderText（背景文本），
            -- 不覆盖用户实际可编辑的 Text 内容
            ref.element.PlaceholderText = t(ref.key)
        else
            ref.element.Text = t(ref.key)
        end
    end
end

customTabOrder = loadTabOrder()
applyTabOrder()
local cfgInit = loadConfig()
applyDeepCustomLayout(cfgInit.deepCustomLayout or false)
refreshThemeGradients()

loadTabIcons()
applyTabIcons()

startPageGuard()
loadInstalledPages()

runAutoExecScripts()

local _startupCfg = loadConfig()
if not (_startupCfg and _startupCfg.compatibilityMode) then
    AntiTamper.start()
end

_G.__DeltaUI_makeModuleCard = makeModuleCard

_G.__DeltaUI_loadInstalledModules = loadInstalledModules
_G.__DeltaUI_refreshCloudList = refreshCloudList
_G.__DeltaUI_switchPage = switchPage
_G.__DeltaUI_removeStoreScript = removeStoreScript
_G.__DeltaUI_addStoreScriptToGamepad = addStoreScriptToGamepad
_G.__DeltaUI_AddLog = AddLog
_G.__DeltaUI_create = create
_G.__DeltaUI_t = t
_G.__DeltaUI_theme = theme
_G.__DeltaUI_storeScriptFolder = storeScriptFolder
_G.__DeltaUI_ensureStoreFolder = ensureStoreFolder
_G.__DeltaUI_ensureModelFolder = ensureModelFolder
_G.__DeltaUI_ensurePatchFolder = ensurePatchFolder
_G.__DeltaUI_modelFolder = modelFolder
_G.__DeltaUI_patchFolder = patchFolder
_G.__DeltaUI_checkUiVersion = checkUiVersion
_G.__DeltaUI_currentPage = currentPage
_G.__DeltaUI_pages = pages
_G.__DeltaUI_bottomBar = bottomBar
_G.__DeltaUI_navButtons = navButtons
_G.__DeltaUI_animateIndicator = animateIndicator
_G.__DeltaUI_cloudSearchInput = cloudSearchInput
_G.__DeltaUI_searchInput = searchInput
_G.__DeltaUI_refreshScriptList = refreshScriptList
_G.__DeltaUI_cloudRefreshLock = cloudRefreshLock
_G.__DeltaUI_pendingCloudRefresh = pendingCloudRefresh
_G.__DeltaUI_cloudScroll = cloudScroll
_G.__DeltaUI_cloudGrid = cloudGrid
_G.__DeltaUI_installedModules = installedModules
_G.__DeltaUI_makeModuleCard = makeModuleCard
_G.__DeltaUI_ShowNotification = ShowNotification
_G.__DeltaUI_getCachedIcon = getCachedIcon
_G.__DeltaUI_installModule = installModule
_G.__DeltaUI_uninstallModule = uninstallModule

_G.__DeltaUI_wrapperFrame = wrapperFrame
_G.__DeltaUI_statsRow = statsRow
_G.__DeltaUI_contentFrame = contentFrame
_G.__DeltaUI_pingPill = pingPill
_G.__DeltaUI_fpsPill = fpsPill
_G.__DeltaUI_timePill = timePill
_G.__DeltaUI_labelPill = labelPill
_G.__DeltaUI_scriptListScroll = scriptListScroll
_G.__DeltaUI_scriptListLayout = scriptListLayout
_G.__DeltaUI_searchBox = searchBox
_G.__DeltaUI_updateBtn = updateBtn
_G.__DeltaUI_refreshBtn = refreshBtn
_G.__DeltaUI_cloudPage = cloudPage
_G.__DeltaUI_cloudSearchBox = cloudSearchBox
_G.__DeltaUI_settingsPage = settingsPage
_G.__DeltaUI_editorPage = editorPage
_G.__DeltaUI_consolePage = consolePage
_G.__DeltaUI_gamepadPage = gamepadPage
_G.__DeltaUI_tabBar = tabBar
_G.__DeltaUI_tabAddBtn = tabAddBtn
_G.__DeltaUI_codeScroll = codeScroll
_G.__DeltaUI_codeBox = codeBox
_G.__DeltaUI_lineNumberFrame = lineNumberFrame
_G.__DeltaUI_lineNumberLabel = lineNumberLabel
_G.__DeltaUI_editOverlay = editOverlay
_G.__DeltaUI_execBtn = execBtn
_G.__DeltaUI_clearBtn = clearBtn
_G.__DeltaUI_pasteBtn = pasteBtn
_G.__DeltaUI_execClipBtn = execClipBtn
_G.__DeltaUI_consoleClearBtn = consoleClearBtn
_G.__DeltaUI_consoleScroll = consoleScroll
_G.__DeltaUI_consoleList = consoleList
_G.__DeltaUI_consoleHeader = consoleHeader
_G.__DeltaUI_consoleTitle = consoleTitle
_G.__DeltaUI_consoleSettingsBtn = consoleSettingsBtn
_G.__DeltaUI_scrollTrack = scrollTrack
_G.__DeltaUI_orbFrame = orbFrame
_G.__DeltaUI_orbBtn = orbBtn
_G.__DeltaUI_orbImg = orbImg
_G.__DeltaUI_orbStroke = orbStroke
_G.__DeltaUI_logoutBtn = logoutBtn
_G.__DeltaUI_logoutIcon = logoutIcon
_G.__DeltaUI_topBar = topBar
_G.__DeltaUI_navBg = navBg
_G.__DeltaUI_navContainer = navContainer
_G.__DeltaUI_navIndicator = navIndicator
_G.__DeltaUI_main = main
_G.__DeltaUI_screenGui = screenGui

_G.__DeltaUI_refreshScriptList = refreshScriptList
_G.__DeltaUI_addStoreScriptToGamepad = addStoreScriptToGamepad
_G.__DeltaUI_removeStoreScript = removeStoreScript
_G.__DeltaUI_hasExecutorDescendant = hasExecutorDescendant
_G.__DeltaUI_destroyExecutorUI = destroyExecutorUI
_G.__DeltaUI_cleanupOldUI = cleanupOldUI
_G.__DeltaUI_getClipboardContent = getClipboardContent
_G.__DeltaUI_ensureFolder = ensureFolder
_G.__DeltaUI_ensureExportFolder = ensureExportFolder
_G.__DeltaUI_ensureCacheFolder = ensureCacheFolder
_G.__DeltaUI_ensureAutoExecFolder = ensureAutoExecFolder
_G.__DeltaUI_assetFolder = assetFolder
_G.__DeltaUI_ensureAssetFolder = ensureAssetFolder
_G.__DeltaUI_initFloatingBallIcon = initFloatingBallIcon
_G.__DeltaUI_getAutoExecFileState = getAutoExecFileState
_G.__DeltaUI_setAutoExecFileState = setAutoExecFileState
_G.__DeltaUI_getUniqueTabName = getUniqueTabName
_G.__DeltaUI_saveCurrentTab = saveCurrentTab
_G.__DeltaUI_renderTabs = renderTabs
_G.__DeltaUI_addTab = addTab
_G.__DeltaUI_updateLineNumbers = updateLineNumbers
_G.__DeltaUI_loadConfig = loadConfig
_G.__DeltaUI_saveConfig = saveConfig
_G.__DeltaUI_registerTranslation = registerTranslation
_G.__DeltaUI_setProgress = setProgress
_G.__DeltaUI_startDownload = startDownload
_G.__DeltaUI_isCollapsed = isCollapsed
_G.__DeltaUI_orbDragOffset = orbDragOffset
_G.__DeltaUI_orbDragStart = orbDragStart
_G.__DeltaUI_orbDragInput = orbDragInput
_G.__DeltaUI_isOrbDragging = isOrbDragging
_G.__DeltaUI_isCollapsed = isCollapsed

loadInstalledModules = function() end
installModule = function() end
uninstallModule = function() end
makeModuleCard = function() return nil end
installedModules = {}
_G.__DeltaUI_installedModules = installedModules
_G.__DeltaUI_installModule = installModule
_G.__DeltaUI_uninstallModule = uninstallModule
_G.__DeltaUI_makeModuleCard = makeModuleCard

