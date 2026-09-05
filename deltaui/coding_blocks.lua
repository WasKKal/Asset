-- ============================================================
-- DeltaUI 外部页面：积木编程 (Coding Blocks)
-- 来源：DeltaUI Pro 提取版
-- 安装方式：在 DeltaUI 设置 → 外部页面 中粘贴此文件的原始 URL
--
-- 重要说明：
--   1. 必须关闭「页面安全模式」才能运行 (设置 → 外部页面 → 页面安全模式)
--   2. 积木运行需要执行器支持 loadstring
--   3. 部分功能（建造空间、对象树联动）需要完整 DeltaUI 环境
-- ============================================================

local pageDef = {}
pageDef.name = "coding_blocks"
pageDef.title = "积木编程"
pageDef.icon = "blocks"

function pageDef.build(frame, helpers)
    -- ============================================================
    -- 兼容层：补全 DeltaUI 内部变量（外部页面环境中不可直接访问）
    -- ============================================================

    -- 服务表（与 DeltaUI 内部 svc 一致）
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

    -- 主题表（DeltaUI 默认深色主题）
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

    -- 对象储存兜底（完整对象树功能需 DeltaUI 环境）
    if not obStoredObjects then obStoredObjects = {} end
    if not obStoredObjTexts then obStoredObjTexts = function() return {} end end
    if not buildSpaceActive then buildSpaceActive = false end
    if not AddLog then AddLog = function(msg, lvl) print("[Coding]", msg) end end

    -- 属性候选函数（来自属性浏览器模块，带兼容处理）
    function codingObjPropOptions()
        local out, seen = {}, {}
        local function put(n)
            if type(n) ~= "string" or n == "" or seen[n] then return end
            seen[n] = true
            out[#out + 1] = n
        end
        for _, n in ipairs(CODING_OBJ_PROPS or {}) do put(n) end
        pcall(function()
            if not propListNames then return end
            for _, rec in ipairs(obStoredObjects or {}) do
                local node = obResolve and obResolve(rec.path) or nil
                if node then
                    local ok, names = pcall(propListNames, node)
                    if ok and type(names) == "table" then
                        for _, n in ipairs(CODING_OBJ_PROP_EXTRA or {}) do
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

    -- ================ 积木页面主代码 ================

    -- 初始化根容器
    codingPage = frame
    frame.Name = "coding_blocks"

