-- DeltaUI 危险功能包 (Dangerous Features Pack)
-- 由主 UI 设置页"危险功能"分区的"安装危险功能"按钮从远程下载到本地并执行。
-- 重新加入等核心危险功能已在主 UI 内联实现；本文件用于扩展更多危险功能。
-- 在此添加需要远程分发的危险功能，并注册到 _G.DeltaDangerFeatures。

_G.DeltaDangerFeatures = _G.DeltaDangerFeatures or {}

-- 示例：可在此添加如自动重连、批量传送等高风险功能。
-- 当前暂无额外功能，仅作为远程下载 / 卸载机制的载体。

return _G.DeltaDangerFeatures
