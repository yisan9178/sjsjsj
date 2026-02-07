--[[
    Fixed Script: TaffyCat (塔菲喵) - UI Fix Version
    更新内容:
    1. 全局 Slider 格式修正为: Value = {Min, Max, Default}, Step
    2. 修复数值调整逻辑
    3. 将部分 Input 输入框优化为 Slider
]]

local Workspace, RunService, Players, CoreGui, Lighting = cloneref(game:GetService("Workspace")), cloneref(game:GetService("RunService")), cloneref(game:GetService("Players")), game:GetService("CoreGui"), cloneref(game:GetService("Lighting"))
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local Mouse = LocalPlayer:GetMouse()
local Cam = Workspace.CurrentCamera

-- =============================================================================
-- CONFIGURATION STORES (配置表)
-- =============================================================================

local CombatConfig = {
    Hitbox = {
        Enabled = false,
        Size = 10,
        Transparency = 0.5,
        Material = Enum.Material.ForceField,
        Color = Color3.fromRGB(255, 0, 0),
        TeamCheck = true,
        Rainbow = false
    },
    Aura = {
        Enabled = false,
        HitChance = 50,
        AttackDistance = 10,
        Follow = false,
        Spin = false,
        WallCheck = true,
        Unstoppable = false
    }
}

local ESP = {
    Enabled = false, -- 总开关初始状态
    TeamCheck = true,
    MaxDistance = 1000,
    FontSize = 11,
    FadeOut = { OnDistance = true, OnDeath = false, OnLeave = false },
    Drawing = {
        Chams = { Enabled = true, Thermal = true, FillRGB = Color3.fromRGB(119, 120, 255), Fill_Transparency = 100, OutlineRGB = Color3.fromRGB(119, 120, 255), Outline_Transparency = 100, VisibleCheck = true },
        Names = { Enabled = true, RGB = Color3.fromRGB(255, 255, 255) },
        Distances = { Enabled = true, Position = "Text", RGB = Color3.fromRGB(255, 255, 255) },
        Healthbar = { Enabled = true, HealthText = true, Lerp = false, HealthTextRGB = Color3.fromRGB(119, 120, 255), Width = 2.5, Gradient = true, GradientRGB1 = Color3.fromRGB(200, 0, 0), GradientRGB2 = Color3.fromRGB(60, 60, 125), GradientRGB3 = Color3.fromRGB(119, 120, 255) },
        Boxes = { Animate = true, RotationSpeed = 300, Gradient = false, GradientRGB1 = Color3.fromRGB(119, 120, 255), GradientRGB2 = Color3.fromRGB(0, 0, 0), GradientFill = true, GradientFillRGB1 = Color3.fromRGB(119, 120, 255), GradientFillRGB2 = Color3.fromRGB(0, 0, 0), Filled = { Enabled = true, Transparency = 0.75, RGB = Color3.fromRGB(0, 0, 0) }, Full = { Enabled = true, RGB = Color3.fromRGB(255, 255, 255) }, Corner = { Enabled = true, RGB = Color3.fromRGB(255, 255, 255) } }
    }
}

local RotationAngle, Tick = -45, tick()

-- =============================================================================
-- UTILITY FUNCTIONS (工具函数)
-- =============================================================================
local Functions = {}
function Functions:Create(Class, Properties)
    local _Instance = typeof(Class) == 'string' and Instance.new(Class) or Class
    for Property, Value in pairs(Properties) do
        _Instance[Property] = Value
    end
    if _Instance:IsA("GuiObject") then
        _Instance.Active = false
        _Instance.Selectable = false
        pcall(function() _Instance.Interactable = false end)
    end
    return _Instance
end

function Functions:FadeOutOnDist(element, distance, healthbar)
    if not ESP.FadeOut.OnDistance then return end
    local transparency = math.max(1, 100 - (distance / ESP.MaxDistance))
    if element:IsA("TextLabel") then element.TextTransparency = 1 - transparency
    elseif element:IsA("ImageLabel") then element.ImageTransparency = 1 - transparency
    elseif element:IsA("UIStroke") then element.Transparency = 1 - transparency
    elseif element:IsA("Frame") then element.BackgroundTransparency = 1 - transparency
    elseif element:IsA("Highlight") then element.FillTransparency = 1 - transparency; element.OutlineTransparency = 1 - transparency end
end

function gradient(text, startColor, endColor)
    local result = ""
    local chars = {}
    for uchar in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do table.insert(chars, uchar) end
    for i = 1, #chars do
        local t = (i - 1) / math.max(#chars - 1, 1)
        local r = startColor.R + (endColor.R - startColor.R) * t
        local g = startColor.G + (endColor.G - startColor.G) * t
        local b = startColor.B + (endColor.B - startColor.B) * t
        result = result .. string.format('<font color="rgb(%d,%d,%d)">%s</font>', math.floor(r*255), math.floor(g*255), math.floor(b*255), chars[i])
    end
    return result
end

-- =============================================================================
-- COMBAT FUNCTIONS (战斗功能)
-- =============================================================================

local function isTeammate(player)
    if not CombatConfig.Hitbox.TeamCheck then return false end
    return player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team
end

local function isAlive(player)
    return player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0
end

local function isVisible(targetChar)
    if not CombatConfig.Aura.WallCheck then return true end
    if not LocalPlayer.Character then return false end
    local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not myRoot or not targetRoot then return false end
    
    local origin = myRoot.Position
    local direction = targetRoot.Position - origin
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, targetChar}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local result = Workspace:Raycast(origin, direction, raycastParams)
    return result == nil
end

local function getClosestTarget()
    local closestDist = math.huge
    local closestTarget = nil
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isAlive(player) and not isTeammate(player) then
            local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot then
                local dist = (myRoot.Position - targetRoot.Position).Magnitude
                if dist < closestDist then
                    if isVisible(player.Character) then
                        closestDist = dist
                        closestTarget = player.Character
                    end
                end
            end
        end
    end
    return closestTarget
end

-- HITBOX LOGIC
local function resetHitbox(player)
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local rootPart = player.Character.HumanoidRootPart
        if rootPart.Size.X > 3 or rootPart.Transparency ~= 1 then
            rootPart.Size = Vector3.new(2, 2, 1)
            rootPart.Transparency = 1
            rootPart.CanCollide = true
            rootPart.Material = Enum.Material.Plastic
            rootPart.Color = Color3.new(0.64, 0.635, 0.647) 
            local glow = rootPart:FindFirstChild("GlowEffect")
            if glow then glow:Destroy() end
        end
    end
end

local function updateHitboxes()
    if not CombatConfig.Hitbox.Enabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then resetHitbox(player) end
        end
        return
    end

    local currentSize = Vector3.new(CombatConfig.Hitbox.Size, CombatConfig.Hitbox.Size, CombatConfig.Hitbox.Size)
    
    local currentColor = CombatConfig.Hitbox.Color
    if CombatConfig.Hitbox.Rainbow then
        local hue = tick() % 5 / 5
        currentColor = Color3.fromHSV(hue, 1, 1)
    end

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local rootPart = player.Character.HumanoidRootPart
            if isAlive(player) and not isTeammate(player) then
                rootPart.Size = currentSize
                rootPart.Transparency = CombatConfig.Hitbox.Transparency
                rootPart.Material = CombatConfig.Hitbox.Material
                rootPart.CanCollide = false
                rootPart.Color = currentColor

                local glow = rootPart:FindFirstChild("GlowEffect")
                if not glow then
                    glow = Instance.new("SelectionBox", rootPart)
                    glow.Name = "GlowEffect"
                    glow.Adornee = rootPart
                    glow.LineThickness = 0.05
                    glow.Transparency = 0.5
                end
                if glow then glow.Color3 = currentColor end
            else
                resetHitbox(player)
            end
        end
    end
end

-- AURA/BOT LOGIC
local AuraTarget = nil

local function attackTarget()
    if AuraTarget and AuraTarget:FindFirstChild("Humanoid") and AuraTarget.Humanoid.Health > 0 then
        local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local targetRoot = AuraTarget:FindFirstChild("HumanoidRootPart")
        if myRoot and targetRoot then
            local distance = (myRoot.Position - targetRoot.Position).Magnitude
            if distance <= CombatConfig.Aura.AttackDistance then
                local chanceRoll = math.random(1, 100)
                if chanceRoll <= CombatConfig.Aura.HitChance then
                    for _, tool in ipairs(LocalPlayer.Character:GetChildren()) do
                        if tool:IsA("Tool") then tool:Activate() end
                    end
                end
            end
        end
    end
end

local function followTarget()
    if not CombatConfig.Aura.Follow then return end
    if AuraTarget and AuraTarget:FindFirstChild("HumanoidRootPart") then
        local myHumanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
        if myHumanoid then
            myHumanoid:MoveTo(AuraTarget.HumanoidRootPart.Position)
        end
    end
end

local function spinCharacter()
    if not CombatConfig.Aura.Spin then return end
    local rootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if rootPart then
        rootPart.CFrame = rootPart.CFrame * CFrame.Angles(0, math.rad(90), 0)
    end
end

local function makeUnstoppable()
    if not CombatConfig.Aura.Unstoppable then return end
    local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.PlatformStand = false
        humanoid.Sit = false
        local rootPart = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if rootPart then rootPart.Anchored = false end
    end
end

local function onCombatStep()
    updateHitboxes()

    if CombatConfig.Aura.Enabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        makeUnstoppable()
        AuraTarget = getClosestTarget()
        if AuraTarget then
            followTarget()
            spinCharacter()
            attackTarget()
        end
    end
end

-- =============================================================================
-- ESP LOGIC ENGINE
-- =============================================================================
local ScreenGui = Functions:Create("ScreenGui", { Parent = CoreGui, Name = "ESPHolder", ResetOnSpawn = false, DisplayOrder = -1 })

local function ESP_Func(plr)
    if ScreenGui:FindFirstChild(plr.Name) then ScreenGui[plr.Name]:Destroy() end
    local PlrFolder = Functions:Create("Folder", {Parent = ScreenGui, Name = plr.Name})

    local Name = Functions:Create("TextLabel", {Parent = PlrFolder, Position = UDim2.new(0.5, 0, 0, -11), Size = UDim2.new(0, 100, 0, 20), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBold, TextSize = ESP.FontSize, TextStrokeTransparency = 0, TextStrokeColor3 = Color3.fromRGB(0, 0, 0), RichText = true})
    local Distance = Functions:Create("TextLabel", {Parent = PlrFolder, Position = UDim2.new(0.5, 0, 0, 11), Size = UDim2.new(0, 100, 0, 20), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBold, TextSize = ESP.FontSize, TextStrokeTransparency = 0, TextStrokeColor3 = Color3.fromRGB(0, 0, 0), RichText = true})
    local Box = Functions:Create("Frame", {Parent = PlrFolder, BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.75, BorderSizePixel = 0})
    local Gradient1 = Functions:Create("UIGradient", {Parent = Box, Enabled = ESP.Drawing.Boxes.GradientFill, Color = ColorSequence.new{ColorSequenceKeypoint.new(0, ESP.Drawing.Boxes.GradientFillRGB1), ColorSequenceKeypoint.new(1, ESP.Drawing.Boxes.GradientFillRGB2)}})
    local Outline = Functions:Create("UIStroke", {Parent = Box, Enabled = ESP.Drawing.Boxes.Gradient, Transparency = 0, Color = Color3.fromRGB(255, 255, 255), LineJoinMode = Enum.LineJoinMode.Miter})
    local Gradient2 = Functions:Create("UIGradient", {Parent = Outline, Enabled = ESP.Drawing.Boxes.Gradient, Color = ColorSequence.new{ColorSequenceKeypoint.new(0, ESP.Drawing.Boxes.GradientRGB1), ColorSequenceKeypoint.new(1, ESP.Drawing.Boxes.GradientRGB2)}})
    local Healthbar = Functions:Create("Frame", {Parent = PlrFolder, BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0})
    local BehindHealthbar = Functions:Create("Frame", {Parent = PlrFolder, ZIndex = -1, BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0})
    local HealthText = Functions:Create("TextLabel", {Parent = PlrFolder, Position = UDim2.new(0.5, 0, 0, 31), Size = UDim2.new(0, 100, 0, 20), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBold, TextSize = ESP.FontSize - 3, TextStrokeTransparency = 0, TextStrokeColor3 = Color3.fromRGB(0, 0, 0)})
    local Chams = Functions:Create("Highlight", {Parent = PlrFolder, FillTransparency = 1, OutlineTransparency = 0, OutlineColor = Color3.fromRGB(119, 120, 255), DepthMode = "AlwaysOnTop"})
    
    local CornerParts = {}
    for i=1, 8 do table.insert(CornerParts, Functions:Create("Frame", {Parent = PlrFolder, BackgroundColor3 = ESP.Drawing.Boxes.Corner.RGB})) end

    local Connection
    local function HideESP()
        for _, v in pairs(PlrFolder:GetChildren()) do if v:IsA("GuiObject") then v.Visible = false end end
        Chams.Enabled = false
        if not plr or not plr.Parent then
            PlrFolder:Destroy()
            if Connection then Connection:Disconnect() end
        end
    end

    Connection = RunService.RenderStepped:Connect(function()
        if not ESP.Enabled then HideESP() return end
        
        local char = plr.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")

        if hrp and hum and hum.Health > 0 then
            local Pos, OnScreen = Cam:WorldToScreenPoint(hrp.Position)
            local Dist = (Cam.CFrame.Position - hrp.Position).Magnitude / 3.57

            if OnScreen and Dist <= ESP.MaxDistance then
                local isEnemy = (ESP.TeamCheck and plr ~= LocalPlayer and ((LocalPlayer.Team ~= plr.Team) or (not LocalPlayer.Team and not plr.Team))) or (not ESP.TeamCheck)
                
                if isEnemy then
                    local scaleFactor = (hrp.Size.Y * Cam.ViewportSize.Y) / (Pos.Z * 2)
                    local w, h = 3 * scaleFactor, 4.5 * scaleFactor
                    
                    Functions:FadeOutOnDist(Box, Dist)
                    Functions:FadeOutOnDist(Outline, Dist)
                    Functions:FadeOutOnDist(Name, Dist)
                    Functions:FadeOutOnDist(Distance, Dist)
                    Functions:FadeOutOnDist(Healthbar, Dist)
                    Functions:FadeOutOnDist(BehindHealthbar, Dist)
                    Functions:FadeOutOnDist(HealthText, Dist)
                    Functions:FadeOutOnDist(Chams, Dist)
                    for _,v in pairs(CornerParts) do Functions:FadeOutOnDist(v, Dist) end

                    Chams.Adornee = char
                    Chams.Enabled = ESP.Drawing.Chams.Enabled
                    Chams.FillColor = ESP.Drawing.Chams.FillRGB
                    if ESP.Drawing.Chams.Thermal then
                        local breathe = math.atan(math.sin(tick() * 2)) * 2 / math.pi
                        Chams.FillTransparency = ESP.Drawing.Chams.Fill_Transparency * breathe * 0.01
                    end
                    Chams.DepthMode = ESP.Drawing.Chams.VisibleCheck and "Occluded" or "AlwaysOnTop"

                    local cp = CornerParts
                    cp[1].Visible, cp[1].Position, cp[1].Size = ESP.Drawing.Boxes.Corner.Enabled, UDim2.new(0, Pos.X - w/2, 0, Pos.Y - h/2), UDim2.new(0, w/5, 0, 1)
                    cp[2].Visible, cp[2].Position, cp[2].Size = ESP.Drawing.Boxes.Corner.Enabled, UDim2.new(0, Pos.X - w/2, 0, Pos.Y - h/2), UDim2.new(0, 1, 0, h/5)
                    cp[3].Visible, cp[3].Position, cp[3].Size, cp[3].AnchorPoint = ESP.Drawing.Boxes.Corner.Enabled, UDim2.new(0, Pos.X - w/2, 0, Pos.Y + h/2), UDim2.new(0, 1, 0, h/5), Vector2.new(0, 5)
                    cp[4].Visible, cp[4].Position, cp[4].Size, cp[4].AnchorPoint = ESP.Drawing.Boxes.Corner.Enabled, UDim2.new(0, Pos.X - w/2, 0, Pos.Y + h/2), UDim2.new(0, w/5, 0, 1), Vector2.new(0, 1)
                    cp[5].Visible, cp[5].Position, cp[5].Size, cp[5].AnchorPoint = ESP.Drawing.Boxes.Corner.Enabled, UDim2.new(0, Pos.X + w/2, 0, Pos.Y - h/2), UDim2.new(0, w/5, 0, 1), Vector2.new(1, 0)
                    cp[6].Visible, cp[6].Position, cp[6].Size, cp[6].AnchorPoint = ESP.Drawing.Boxes.Corner.Enabled, UDim2.new(0, Pos.X + w/2 - 1, 0, Pos.Y - h/2), UDim2.new(0, 1, 0, h/5), Vector2.new(0, 0)
                    cp[7].Visible, cp[7].Position, cp[7].Size, cp[7].AnchorPoint = ESP.Drawing.Boxes.Corner.Enabled, UDim2.new(0, Pos.X + w/2, 0, Pos.Y + h/2), UDim2.new(0, 1, 0, h/5), Vector2.new(1, 1)
                    cp[8].Visible, cp[8].Position, cp[8].Size, cp[8].AnchorPoint = ESP.Drawing.Boxes.Corner.Enabled, UDim2.new(0, Pos.X + w/2, 0, Pos.Y + h/2), UDim2.new(0, w/5, 0, 1), Vector2.new(1, 1)

                    Box.Visible = ESP.Drawing.Boxes.Full.Enabled
                    Box.Position = UDim2.new(0, Pos.X - w/2, 0, Pos.Y - h/2)
                    Box.Size = UDim2.new(0, w, 0, h)
                    Box.BackgroundTransparency = ESP.Drawing.Boxes.Filled.Enabled and ESP.Drawing.Boxes.Filled.Transparency or 1
                    
                    RotationAngle = RotationAngle + (tick() - Tick) * ESP.Drawing.Boxes.RotationSpeed * math.cos(math.pi / 4 * tick() - math.pi / 2)
                    Gradient1.Rotation = ESP.Drawing.Boxes.Animate and RotationAngle or -45
                    Gradient2.Rotation = ESP.Drawing.Boxes.Animate and RotationAngle or -45
                    Tick = tick()

                    local hp_ratio = hum.Health / hum.MaxHealth
                    Healthbar.Visible = ESP.Drawing.Healthbar.Enabled
                    Healthbar.Position = UDim2.new(0, Pos.X - w/2 - 6, 0, Pos.Y - h/2 + h*(1-hp_ratio))
                    Healthbar.Size = UDim2.new(0, ESP.Drawing.Healthbar.Width, 0, h*hp_ratio)
                    BehindHealthbar.Visible = ESP.Drawing.Healthbar.Enabled
                    BehindHealthbar.Position = UDim2.new(0, Pos.X - w/2 - 6, 0, Pos.Y - h/2)
                    BehindHealthbar.Size = UDim2.new(0, ESP.Drawing.Healthbar.Width, 0, h)
                    
                    if ESP.Drawing.Healthbar.HealthText then
                        HealthText.Visible = hum.Health < hum.MaxHealth
                        HealthText.Text = math.floor(hp_ratio * 100)
                        HealthText.Position = UDim2.new(0, Pos.X - w/2 - 6, 0, Pos.Y - h/2 + h*(1-hp_ratio) + 3)
                        HealthText.TextColor3 = ESP.Drawing.Healthbar.Lerp and Color3.fromHSV(hp_ratio * 0.3, 1, 1) or ESP.Drawing.Healthbar.HealthTextRGB
                    end

                    Name.Visible = ESP.Drawing.Names.Enabled
                    local friendTag = LocalPlayer:IsFriendsWith(plr.UserId) and '<font color="rgb(0,255,0)">[友]</font> ' or '<font color="rgb(255,0,0)">[敌]</font> '
                    local distTag = ESP.Drawing.Distances.Enabled and string.format(" [%d]", math.floor(Dist)) or ""
                    Name.Text = friendTag .. plr.Name .. distTag
                    Name.Position = UDim2.new(0, Pos.X, 0, Pos.Y - h/2 - 9)
                else
                    HideESP()
                end
            else
                HideESP()
            end
        else
            HideESP()
        end
    end)
end

-- =============================================================================
-- WINDUI SETUP
-- =============================================================================
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/yisan9178/sjsjsj/refs/heads/main/Windui.lua(1).txt"))()

local Window = WindUI:CreateWindow({
    Title = gradient("塔菲喵脚本", Color3.fromHex("#00DBDE"), Color3.fromHex("#FC00FF")), 
    Author = "伊散",
    IconThemed = true,
    Folder = "TaffyCatv2Fix",
    Size = UDim2.fromOffset(580, 460),
    Theme = "Dark",
})
Window:SetToggleKey(Enum.KeyCode.F, true)

-- ez.服务器脚本
local fwTab = Window:Tab({ Title = '其他服务器', Icon = 'swords' })
fwTab:Button({
    Title = "力量传奇",
    Callback = function() 
    loadstring(game:HttpGet("https://raw.githubusercontent.com/yisan9178/sjsjsj/refs/heads/main/obfuscated_script-1770480001885.lua.txt"))()
    end
})

-- 1. INFO TAB
local InfoTab = Window:Tab({ Title = '信息', Icon = 'info' })
InfoTab:Paragraph({ Title = '修正说明', Desc = '已修复透视界面无法控制的问题。\n"启用 ESP (总开关)" 控制所有透视功能。\n滑块格式已更新。' })

-- 2. COMBAT TAB
local CombatTab = Window:Tab({ Title = '战斗功能', Icon = 'swords' })

local HitboxSection = CombatTab:Section({ Title = "判定范围 (Hitbox)" })
HitboxSection:Toggle({
    Title = "开启 Hitbox 扩大",
    Callback = function(state) 
        CombatConfig.Hitbox.Enabled = state 
        if not state then updateHitboxes() end 
    end
})

-- [Fixed] Hitbox Size Slider
HitboxSection:Slider({
    Title = "Hitbox 大小",
    Step = 1,
    Value = {Min = 1, Max = 50, Default = 10},
    Callback = function(v) CombatConfig.Hitbox.Size = v end
})

-- [Fixed] Transparency Slider
HitboxSection:Slider({
    Title = "透明度",
    Step = 0.1,
    Value = {Min = 0, Max = 1, Default = 0.5},
    Callback = function(v) CombatConfig.Hitbox.Transparency = v end -- 修正：滑块直接返回 0-1 的值，无需除以10
})

HitboxSection:Toggle({
    Title = "彩虹颜色",
    Default = false,
    Callback = function(state) CombatConfig.Hitbox.Rainbow = state end
})

local AuraSection = CombatTab:Section({ Title = "Bot/Aura" })
AuraSection:Toggle({
    Title = "开启自动攻击",
    Callback = function(state) CombatConfig.Aura.Enabled = state end
})

-- [Fixed] Attack Distance Slider
AuraSection:Slider({
    Title = "攻击距离",
    Step = 1,
    Value = {Min = 1, Max = 100, Default = 10},
    Callback = function(v) CombatConfig.Aura.AttackDistance = v end
})

-- [Fixed] Hit Chance Slider
AuraSection:Slider({
    Title = "命中几率",
    Step = 1,
    Value = {Min = 0, Max = 100, Default = 50},
    Callback = function(v) CombatConfig.Aura.HitChance = v end
})

AuraSection:Toggle({
    Title = "自动跟随",
    Callback = function(state) CombatConfig.Aura.Follow = state end
})
AuraSection:Toggle({
    Title = "大风车旋转 (Spin)",
    Callback = function(state) CombatConfig.Aura.Spin = state end
})
AuraSection:Toggle({
    Title = "无敌模式 (Unstoppable)",
    Callback = function(state) CombatConfig.Aura.Unstoppable = state end
})

-- 3. PLAYER TAB
local PlayerTab = Window:Tab({ Title = '玩家设置', Icon = 'user' })
local SpeedSection = PlayerTab:Section({ Title = "加速" })
local tpSpeedValue = 16 
local tpWalkEnabled = false

-- [Fixed] Speed Slider (Changed from Input)
SpeedSection:Slider({
    Title = "移动速度",
    Step = 1,
    Value = {Min = 16, Max = 200, Default = 16},
    Callback = function(v) tpSpeedValue = tonumber(v) or 16 end
})

SpeedSection:Toggle({
    Title = "开启加速",
    Callback = function(state)
        tpWalkEnabled = state
        if state then
            task.spawn(function()
                while tpWalkEnabled do
                    local char = LocalPlayer.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hum and hrp and hum.MoveDirection.Magnitude > 0 then
                        -- 简单的 CFrame 加速逻辑
                        hrp.CFrame = hrp.CFrame + (hum.MoveDirection * (tpSpeedValue - 16) * 0.05)
                    end
                    RunService.RenderStepped:Wait()
                end
            end)
        end
    end
})

local jump_Ys = false
PlayerTab:Section({ Title = "跳跃" }):Toggle({
    Title = "开启无限跳",
    Callback = function(v)
    getgenv().Jump = v
    if jump_Ys then
        jump_Ys:Disconnect()
        jump_Ys = nil
    end
    if Jump then
        jump_Ys = game.UserInputService.JumpRequest:Connect(function()
            local character = game.Players.LocalPlayer.Character
            if character and character:FindFirstChild("Humanoid") then
                character.Humanoid:ChangeState("Jumping")
            end
        end)
    end
      end
})

-- FLY SYSTEM
local flySpeed = 50
local flying = false
local bodyVelocity, bodyGyro
local renderSteppedConnection

local function stopFlying()
    flying = false
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character.Humanoid.PlatformStand = false
    end
    if bodyVelocity then bodyVelocity:Destroy() end
    if bodyGyro then bodyGyro:Destroy() end
    if renderSteppedConnection then renderSteppedConnection:Disconnect() end
end

local function startFlying()
    if flying then stopFlying() end
    flying = true
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    hum.PlatformStand = true
    bodyVelocity = Instance.new("BodyVelocity", hrp)
    bodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bodyGyro = Instance.new("BodyGyro", hrp)
    bodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)

    renderSteppedConnection = RunService.RenderStepped:Connect(function()
        if flying and hrp and hum then
            local moveDir = hum.MoveDirection * flySpeed
            local camLook = workspace.CurrentCamera.CFrame.LookVector
            if moveDir.Magnitude > 0 then
                if camLook.Y > 0.2 or camLook.Y < -0.2 then
                    moveDir = moveDir + Vector3.new(0, camLook.Y * flySpeed, 0)
                end
            end
            bodyVelocity.Velocity = moveDir
            bodyGyro.CFrame = bodyGyro.CFrame:Lerp(CFrame.new(hrp.Position, hrp.Position + camLook), 0.2)
        end
    end)
end

local FlySection = PlayerTab:Section({ Title = "飞行" })

-- [Fixed] Fly Speed Slider (Changed from Input)
FlySection:Slider({ 
    Title = "飞行速度", 
    Step = 5,
    Value = {Min = 10, Max = 500, Default = 50},
    Callback = function(v) flySpeed = tonumber(v) or 50 end 
})

FlySection:Toggle({ Title = "开启飞行", Callback = function(state) if state then startFlying() else stopFlying() end end })

-- 4. VISUALS TAB (Classic ESP)
local VisualsTab = Window:Tab({ Title = '透视辅助', Icon = 'eye' })
local MainVisuals = VisualsTab:Section({ Title = "全局设置" })

MainVisuals:Toggle({
    Title = "启用 ESP (总开关)",
    Default = false,
    Callback = function(state) ESP.Enabled = state end
})

MainVisuals:Toggle({
    Title = "团队过滤",
    Default = true,
    Callback = function(state) ESP.TeamCheck = state end
})

-- [Fixed] Max Distance Slider
MainVisuals:Slider({
    Title = "最大距离",
    Step = 50,
    Value = {Min = 100, Max = 5000, Default = 1000},
    Callback = function(v) ESP.MaxDistance = v end
})

local DetailVisuals = VisualsTab:Section({ Title = "视觉细节" })
DetailVisuals:Toggle({ Title = "显示名字", Default = true, Callback = function(s) ESP.Drawing.Names.Enabled = s end })
DetailVisuals:Toggle({ Title = "显示距离", Default = true, Callback = function(s) ESP.Drawing.Distances.Enabled = s end })
DetailVisuals:Toggle({ Title = "方框透视", Default = true, Callback = function(s) ESP.Drawing.Boxes.Full.Enabled = s end })
DetailVisuals:Toggle({ Title = "发光 (Chams)", Default = true, Callback = function(s) ESP.Drawing.Chams.Enabled = s end })
DetailVisuals:Toggle({ Title = "血条显示", Default = true, Callback = function(s) ESP.Drawing.Healthbar.Enabled = s end })

-- 5. EXTRA TAB
local ExtraTab = Window:Tab({ Title = '其他', Icon = 'settings' })
ExtraTab:Button({ Title = "重置角色", Callback = function() LocalPlayer.Character:BreakJoints() end })
ExtraTab:Button({ Title = "清空控制台", Callback = function() print(("\n"):rep(100)) end })

-- =============================================================================
-- INITIALIZATION
-- =============================================================================

for _, v in pairs(Players:GetPlayers()) do
    if v ~= LocalPlayer then task.spawn(ESP_Func, v) end      
end
Players.PlayerAdded:Connect(function(v) task.spawn(ESP_Func, v) end)

RunService.Stepped:Connect(onCombatStep) 

pcall(function()
    if not ReplicatedStorage:FindFirstChild("DamageEvent") then
        local damageEvent = Instance.new("BindableEvent")
        damageEvent.Name = "DamageEvent"
        damageEvent.Parent = ReplicatedStorage
        damageEvent.Event:Connect(function(player, character)
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then humanoid:TakeDamage(10) end
        end)
    end
end)

Window:SelectTab(1)
WindUI:Notify({ Title = "塔菲喵整合版", Desc = "菜单已加载，请先开启ESP总开关", Image = "check" })