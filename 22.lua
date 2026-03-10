local Notice = {
    {date = "2026-2-1", desc = "开始制作TF塔菲"},
}
local LoadServer = {
    "力量传奇",

}
local LoadingSteps = {
    {text = "正在初始化系统...", progress = 0},
    {text = "检测运行环境...", progress = 8},
    {text = "加载核心模块...", progress = 18},
    {text = "初始化用户界面...", progress = 30},
    {text = "连接远程服务器...", progress = 45},
    {text = "验证用户权限...", progress = 60},
    {text = "下载游戏数据...", progress = 75},
    {text = "解析配置文件...", progress = 85},
    {text = "准备游戏列表...", progress = 95},
    {text = "中国最佳免费！", progress = 100}
}
local Developers = {
    {name = "伊散", role = "主作者", desc = "项目负责人 · 核心架构", color = Color3.fromRGB(255, 100, 100)},
    {name = "苏达", role = "副作者", desc = "功能开发 · 代码优化", color = Color3.fromRGB(100, 255, 100)},
}

return LoadingSteps, Notice, LoadServer, Developers