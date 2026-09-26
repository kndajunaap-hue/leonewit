-- language: Lua, file: LeoHUB_Exploit.lua
-- *LeoHUB Exploit Edition — Author: LeoXD*
-- *Fitur: Noclip, Fly, Speed, Teleport, ESP, Copy Avatar, Copy Map,
--         Spawn Item, Remote Flood, Silent Aim, Aimbot, Auto SkillCheck*
-- *Catatan: DDoS tidak mungkin dari client Lua. Remote Flood efeknya lokal.*

-- ================== SERVICES ==================
local Players              = game:GetService("Players")
local RunService           = game:GetService("RunService")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")
local UserInputService     = game:GetService("UserInputService")
local Lighting             = game:GetService("Lighting")
local TweenService         = game:GetService("TweenService")
local Workspace            = game:GetService("Workspace")
local VirtualInputManager  = game:GetService("VirtualInputManager")
local HttpService          = game:GetService("HttpService")
local Camera               = Workspace.CurrentCamera
local LocalPlayer          = Players.LocalPlayer

-- ================== CONFIG ==================
local CONFIG = {
    -- Movement
    walk_speed        = 45,
    jump_power        = 60,
    fly_enabled       = false,
    fly_speed         = 80,
    noclip_enabled    = false,
    infinite_jump     = false,
    
    -- ESP
    esp_enabled       = true,
    esp_refresh       = 0.4,
    esp_survivor      = Color3.fromRGB(0, 255, 100),
    esp_killer        = Color3.fromRGB(255, 60, 60),
    esp_generator     = Color3.fromRGB(0, 200, 255),
    esp_item          = Color3.fromRGB(255, 200, 0),
    
    -- Combat
    aimbot_enabled    = false,
    aimbot_fov        = 200,
    aimbot_smooth     = 0.25,
    silent_aim        = false,
    auto_dagger       = false,
    auto_dagger_range = 12,
    auto_dagger_cd    = 0.5,
    
    -- SkillCheck
    auto_skillcheck   = false,
    skillcheck_perfect= true,
    
    -- Flood
    flood_enabled     = false,
    flood_rate        = 30,
    
    -- Visual
    full_bright       = true,
    no_fog            = true,
}

-- ================== STATE ==================
local State = {
    fly_conn     = nil,
    fly_bv       = nil,
    noclip_conn  = nil,
    silent_target= nil,
    silent_hooked= false,
    last_dagger  = 0,
    flood_count  = 0,
    teleport_list= {},
}

-- ================== REMOTE SCAN ==================
local RemoteCache = {}
local function scanRemotes()
    RemoteCache = {}
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            table.insert(RemoteCache, obj)
        end
    end
    print(("[LeoHUB] Cached %d remotes"):format(#RemoteCache))
end
scanRemotes()

-- ================== HELPER ==================
local function notify(title, msg)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title or "LeoHUB",
            Text = msg or "",
            Duration = 3,
        })
    end)
end

local function getChar()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- ================== NOCLIP ==================
local function toggleNoclip(state)
    CONFIG.noclip_enabled = state
    if state then
        State.noclip_conn = RunService.Stepped:Connect(function()
            if not CONFIG.noclip_enabled then return end
            local c = getChar()
            if not c then return end
            for _, part in ipairs(c:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end)
    else
        if State.noclip_conn then State.noclip_conn:Disconnect() end
        local c = getChar()
        if c then
            for _, part in ipairs(c:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
    end
end

-- ================== FLY ==================
local function toggleFly(state)
    CONFIG.fly_enabled = state
    local char = getChar()
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    if state then
        local bv = Instance.new("BodyVelocity")
        bv.Name = "LeoHUB_Fly"
        bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bv.Velocity = Vector3.zero
        bv.Parent = hrp
        State.fly_bv = bv
        
        State.fly_conn = RunService.RenderStepped:Connect(function()
            if not CONFIG.fly_enabled then return end
            local cam = Camera.CFrame
            local move = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += cam.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= cam.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= cam.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += cam.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0,1,0) end
            if move.Magnitude > 0 then
                move = move.Unit * CONFIG.fly_speed
            end
            if State.fly_bv then
                State.fly_bv.Velocity = move
            end
        end)
    else
        if State.fly_conn then State.fly_conn:Disconnect() end
        if State.fly_bv then State.fly_bv:Destroy() end
        State.fly_conn = nil
        State.fly_bv = nil
    end
end

-- ================== INFINITE JUMP ==================
local function toggleInfJump(state)
    CONFIG.infinite_jump = state
end

UserInputService.JumpRequest:Connect(function()
    if not CONFIG.infinite_jump then return end
    local hum = getHum()
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

-- ================== TELEPORT ==================
local function teleportTo(pos)
    local hrp = getChar() and getChar():FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = CFrame.new(pos)
    end
end

local function teleportToPlayer(targetName)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == targetName:lower() and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                teleportTo(hrp.Position + Vector3.new(0, 3, 0))
                return true
            end
        end
    end
    return false
end

-- ================== COPY AVATAR VISUAL ==================
local function copyAvatar(target)
    if not target or not target.Character then return end
    local myChar = getChar()
    if not myChar then return end
    for _, v in ipairs(myChar:GetChildren()) do
        if v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants")
           or v:IsA("BodyColors") or v:IsA("CharacterMesh") then
            pcall(function() v:Destroy() end)
        end
    end
    for _, v in ipairs(target.Character:GetChildren()) do
        if v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants")
           or v:IsA("BodyColors") or v:IsA("CharacterMesh") then
            pcall(function() v:Clone().Parent = myChar end)
        end
    end
    local myHum = myChar:FindFirstChildOfClass("Humanoid")
    local tgtHum = target.Character:FindFirstChildOfClass("Humanoid")
    if myHum and tgtHum then
        for _, desc in ipairs(tgtHum:GetDescendants()) do
            if desc:IsA("NumberValue") then
                local mine = myHum:FindFirstChild(desc.Name)
                if mine then mine.Value = desc.Value end
            end
        end
    end
    notify("LeoHUB", "Avatar copied from " .. target.Name)
end

-- ================== COPY MAP (DUMP STRUCTURE) ==================
local function copyMap()
    -- Dump struktur Workspace ke JSON, simpan sebagai string
    -- Tidak bisa "copy" ke server lain — hanya untuk analisis
    local function dump(inst, depth)
        if depth > 6 then return nil end  -- Limit depth
        local data = {
            name = inst.Name,
            class = inst.ClassName,
            children = {},
        }
        for _, child in ipairs(inst:GetChildren()) do
            local sub = dump(child, depth + 1)
            if sub then table.insert(data.children, sub) end
        end
        return data
    end
    
    local ok, json = pcall(function()
        return HttpService:JSONEncode(dump(Workspace, 0))
    end)
    
    if ok then
        -- Simpan ke file
        local filename = "LeoHUB_MapDump_" .. os.time() .. ".json"
        pcall(function()
            writefile(filename, json)
        end)
        notify("LeoHUB", "Map dumped: " .. filename .. " (" .. #json .. " bytes)")
        print("[LeoHUB] Map dump saved:", filename)
    else
        notify("LeoHUB", "Map dump failed")
    end
end

-- ================== SPAWN ITEM ==================
local function spawnItem(itemName)
    -- Cari item di ReplicatedStorage/ServerStorage, clone ke Backpack
    local searchRoots = { ReplicatedStorage, game:GetService("ServerStorage") }
    for _, root in ipairs(searchRoots) do
        local found = root:FindFirstChild(itemName, true)
        if found and (found:IsA("Tool") or found:IsA("Accessory")) then
            local backpack = LocalPlayer:FindFirstChild("Backpack")
            if backpack then
                pcall(function()
                    found:Clone().Parent = backpack
                    notify("LeoHUB", "Spawned: " .. itemName)
                end)
                return true
            end
        end
    end
    notify("LeoHUB", "Item not found: " .. itemName)
    return false
end

-- ================== ESP ==================
local function createESPTag(part, text, color)
    local existing = part:FindFirstChild("LeoHUB_ESP")
    if existing then existing:Destroy() end
    local gui = Instance.new("BillboardGui")
    gui.Name = "LeoHUB_ESP"
    gui.Size = UDim2.new(0, 180, 0, 40)
    gui.StudsOffset = Vector3.new(0, 3, 0)
    gui.Adornee = part
    gui.AlwaysOnTop = true
    gui.Parent = part
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color
    lbl.TextStrokeTransparency = 0
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold
    lbl.Parent = gui
end

local function getRole(player)
    if player == LocalPlayer then return "self" end
    if player.Team then
        local t = player.Team.Name:lower()
        if t:find("killer") or t:find("murder") then return "killer" end
        if t:find("survivor") or t:find("surv") then return "survivor" end
    end
    local ls = player:FindFirstChild("leaderstats")
    if ls then
        for _, v in ipairs(ls:GetChildren()) do
            local n = v.Name:lower()
            if n:find("role") or n:find("team") then
                local val = tostring(v.Value):lower()
                if val:find("killer") then return "killer" end
                if val:find("survivor") then return "survivor" end
            end
        end
    end
    return "unknown"
end

local function updateESP()
    if not CONFIG.esp_enabled then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        local c = p.Character
        if not c then continue end
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local head = c:FindFirstChild("Head")
        if not head then continue end
        local role = getRole(p)
        local color = (role == "killer") and CONFIG.esp_killer or CONFIG.esp_survivor
        createESPTag(head, role:upper() .. " | " .. p.Name .. " [" .. math.floor(hum.Health) .. "]", color)
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local n = obj.Name:lower()
        if (n:find("generator") or n:find("gen")) and obj:IsA("Model") then
            local pp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if pp then createESPTag(pp, "[GEN]", CONFIG.esp_generator) end
        elseif (n:find("gun") or n:find("weapon") or n:find("dagger") or n:find("item")) 
               and obj:IsA("Tool") then
            local handle = obj:FindFirstChild("Handle")
            if handle then createESPTag(handle, "[ITEM]", CONFIG.esp_item) end
        end
    end
end

-- ================== COMBAT ==================
local function getClosest(maxDist, partName, onlyEnemy)
    local closest, cd = nil, maxDist
    local myPos = Camera.CFrame.Position
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if onlyEnemy and getRole(p) == "survivor" then continue end
        local c = p.Character
        if not c then continue end
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local part = c:FindFirstChild(partName) or c:FindFirstChild("HumanoidRootPart")
        if not part then continue end
        local d = (part.Position - myPos).Magnitude
        if d < cd then closest = part; cd = d end
    end
    return closest
end

local function aimbotLoop()
    if not CONFIG.aimbot_enabled then return end
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
    local target = getClosest(CONFIG.aimbot_fov, "Head", true)
    if not target then return end
    Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, target.Position), CONFIG.aimbot_smooth)
end

local function hookSilentAim()
    if not CONFIG.silent_aim then return end
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then return end
    local target = getClosest(500, "HumanoidRootPart", true)
    if not target then return end
    State.silent_target = target
    if State.silent_hooked then return end
    State.silent_hooked = true
    local mt = getrawmetatable(game)
    local oldNC = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "FireServer" and typeof(self) == "Instance" and self:IsA("RemoteEvent") then
            local args = {...}
            local t = State.silent_target
            if t then
                for i, arg in ipairs(args) do
                    if typeof(arg) == "Instance" and arg:IsA("BasePart") then
                        args[i] = t
                    elseif typeof(arg) == "Vector3" then
                        args[i] = t.Position
                    end
                end
                return oldNC(self, unpack(args))
            end
        end
        return oldNC(self, ...)
    end)
    setreadonly(mt, true)
end

local function autoDagger()
    if not CONFIG.auto_dagger then return end
    local now = tick()
    if now - State.last_dagger < CONFIG.auto_dagger_cd then return end
    local target = getClosest(CONFIG.auto_dagger_range, "HumanoidRootPart", true)
    if not target then return end
    local c = getChar()
    local tool = c and c:FindFirstChildOfClass("Tool") or LocalPlayer.Backpack:FindFirstChildOfClass("Tool")
    if not tool then return end
    pcall(function() tool:Activate() end)
    for _, r in ipairs(RemoteCache) do
        if r:IsA("RemoteEvent") then
            local n = r.Name:lower()
            if n:find("attack") or n:find("hit") or n:find("dagger") then
                pcall(function() r:FireServer(target) end)
            end
        end
    end
    State.last_dagger = now
end

-- ================== AUTO SKILLCHECK ==================
local function findSkillGui()
    for _, root in ipairs({ LocalPlayer:FindFirstChild("PlayerGui"), game:GetService("CoreGui") }) do
        if not root then continue end
        for _, g in ipairs(root:GetDescendants()) do
            if g:IsA("GuiObject") and g.Visible then
                local n = g.Name:lower()
                if n:find("skill") or n:find("check") or n:find("qte") then
                    return g
                end
            end
        end
    end
end

local function trySkillCheck()
    local gui = findSkillGui()
    if not gui then return false end
    local zone, marker
    for _, c in ipairs(gui:GetDescendants()) do
        if c:IsA("Frame") or c:IsA("ImageLabel") then
            local n = c.Name:lower()
            if n:find("zone") or n:find("perfect") then zone = c
            elseif n:find("marker") or n:find("pointer") then marker = c end
        end
    end
    local click = function()
        local cx = gui.AbsolutePosition.X + gui.AbsoluteSize.X / 2
        local cy = gui.AbsolutePosition.Y + gui.AbsoluteSize.Y / 2
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
            VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
        end)
    end
    if zone and marker and CONFIG.skillcheck_perfect then
        local zp = zone.AbsolutePosition.X
        local zs = zone.AbsoluteSize.X
        local mp = marker.AbsolutePosition.X
        if mp >= zp and mp <= (zp + zs) then
            click()
            return true
        end
    else
        click()
        return true
    end
    return false
end

-- ================== REMOTE FLOOD ==================
-- *Efek lokal: bikin server lag sementara. Kamu mungkin di-kick duluan.*
local function floodLoop()
    if not CONFIG.flood_enabled then return end
    local interval = 1 / CONFIG.flood_rate
    for _, r in ipairs(RemoteCache) do
        if r:IsA("RemoteEvent") then
            pcall(function()
                r:FireServer(math.random(), math.random(), "x" .. math.random(1e6))
            end)
        end
    end
    State.flood_count = State.flood_count + 1
    task.wait(interval)
end

-- ================== VISUAL ==================
local function applyVisual()
    if CONFIG.full_bright then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(128,128,128)
        Lighting.Ambient = Color3.fromRGB(178,178,178)
    end
    if CONFIG.no_fog then
        Lighting.FogEnd = 100000
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("Atmosphere") or v:IsA("Clouds") then
                pcall(function() v.Parent = nil end)
            end
        end
    end
end

-- ================== MOVEMENT ==================
local function applyMovement()
    local hum = getHum()
    if hum then
        hum.WalkSpeed = CONFIG.walk_speed
        hum.JumpPower = CONFIG.jump_power
        hum.UseJumpPower = true
    end
end

-- ================== LOOPS ==================
spawn(function() while task.wait(CONFIG.esp_refresh) do pcall(updateESP) end end)
spawn(function()
    RunService.RenderStepped:Connect(function()
        pcall(aimbotLoop); pcall(hookSilentAim)
    end)
end)
spawn(function()
    while task.wait(0.1) do
        pcall(autoDagger); pcall(applyMovement)
    end
end)
spawn(function()
    while task.wait(0.02) do
        if CONFIG.auto_skillcheck then pcall(trySkillCheck) end
    end
end)
spawn(function() while task.wait(1) do pcall(applyVisual) end end)
spawn(function() while task.wait(0.03) do pcall(floodLoop) end end)
spawn(function() while task.wait(30) do pcall(scanRemotes) end end)

-- ================== LeoHUB UI ==================
local LeoHUB = Instance.new("ScreenGui")
LeoHUB.Name = "LeoHUB"
LeoHUB.ResetOnSpawn = false
LeoHUB.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
LeoHUB.Parent = LocalPlayer:WaitForChild("PlayerGui")

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 560, 0, 440)
Main.Position = UDim2.new(0.5, -280, 0.5, -220)
Main.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
Main.BackgroundTransparency = 0.05
Main.BorderSizePixel = 0
Main.Parent = LeoHUB

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 16)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(70, 60, 120)
MainStroke.Thickness = 1.5
MainStroke.Transparency = 0.3
MainStroke.Parent = Main

local Glow = Instance.new("ImageLabel")
Glow.Size = UDim2.new(1, 40, 1, 40)
Glow.Position = UDim2.new(0, -20, 0, -20)
Glow.BackgroundTransparency = 1
Glow.Image = "rbxassetid://5028857084"
Glow.ImageColor3 = Color3.fromRGB(120, 80, 255)
Glow.ImageTransparency = 0.75
Glow.ZIndex = 0
Glow.Parent = Main

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 54)
Header.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
Header.BorderSizePixel = 0
Header.Parent = Main

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 16)
HeaderCorner.Parent = Header

local HeaderCover = Instance.new("Frame")
HeaderCover.Size = UDim2.new(1, 0, 0, 16)
HeaderCover.Position = UDim2.new(0, 0, 1, -16)
HeaderCover.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
HeaderCover.BorderSizePixel = 0
HeaderCover.Parent = Header

local Logo = Instance.new("TextLabel")
Logo.Size = UDim2.new(0, 250, 0, 30)
Logo.Position = UDim2.new(0, 20, 0, 6)
Logo.BackgroundTransparency = 1
Logo.Text = "LeoHUB"
Logo.TextColor3 = Color3.fromRGB(255, 255, 255)
Logo.TextXAlignment = Enum.TextXAlignment.Left
Logo.Font = Enum.Font.GothamBlack
Logo.TextSize = 26
Logo.Parent = Header

local LogoGradient = Instance.new("UIGradient")
LogoGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 100, 200)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 100, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 200, 255)),
})
LogoGradient.Parent = Logo

local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(0, 300, 0, 14)
Subtitle.Position = UDim2.new(0, 22, 0, 34)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "Exploit Edition • LeoXD"
Subtitle.TextColor3 = Color3.fromRGB(120, 120, 140)
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Font = Enum.Font.GothamMedium
Subtitle.TextSize = 11
Subtitle.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -42, 0, 12)
CloseBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = Header

local CloseC = Instance.new("UICorner")
CloseC.CornerRadius = UDim.new(0, 8)
CloseC.Parent = CloseBtn

CloseBtn.MouseButton1Click:Connect(function() LeoHUB:Destroy() end)

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -78, 0, 12)
MinBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
MinBtn.BorderSizePixel = 0
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(220, 220, 230)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 14
MinBtn.Parent = Header

local MinC = Instance.new("UICorner")
MinC.CornerRadius = UDim.new(0, 8)
MinC.Parent = MinBtn

-- Sidebar
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 150, 1, -70)
Sidebar.Position = UDim2.new(0, 0, 0, 54)
Sidebar.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
Sidebar.BackgroundTransparency = 0.4
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Main

local SbCorner = Instance.new("UICorner")
SbCorner.CornerRadius = UDim.new(0, 16)
SbCorner.Parent = Sidebar

local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(1, -20, 1, -20)
TabContainer.Position = UDim2.new(0, 10, 0, 10)
TabContainer.BackgroundTransparency = 1
TabContainer.Parent = Sidebar

local TabLayout = Instance.new("UIListLayout")
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.Padding = UDim.new(0, 6)
TabLayout.Parent = TabContainer

-- Content
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -170, 1, -74)
Content.Position = UDim2.new(0, 160, 0, 64)
Content.BackgroundTransparency = 1
Content.Parent = Main

local Pages = {}
local CurrentTab = nil

local function createPage(name)
    local p = Instance.new("ScrollingFrame")
    p.Size = UDim2.new(1, 0, 1, 0)
    p.BackgroundTransparency = 1
    p.BorderSizePixel = 0
    p.ScrollBarThickness = 4
    p.ScrollBarImageColor3 = Color3.fromRGB(90, 80, 150)
    p.CanvasSize = UDim2.new(0, 0, 0, 0)
    p.Visible = false
    p.Parent = Content
    local l = Instance.new("UIListLayout")
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Padding = UDim.new(0, 8)
    l.Parent = p
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 4)
    pad.PaddingLeft = UDim.new(0, 4)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = p
    l:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        p.CanvasSize = UDim2.new(0, 0, 0, l.AbsoluteContentSize.Y + 12)
    end)
    Pages[name] = p
end

local function createTab(name, icon)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 36)
    b.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
    b.BackgroundTransparency = 1
    b.BorderSizePixel = 0
    b.Text = "   " .. (icon or "") .. "   " .. name
    b.TextColor3 = Color3.fromRGB(160, 160, 180)
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 13
    b.AutoButtonColor = false
    b.Parent = TabContainer
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = b
    b.MouseEnter:Connect(function()
        if CurrentTab ~= name then
            TweenService:Create(b, TweenInfo.new(0.15), {
                BackgroundTransparency = 0.6,
                BackgroundColor3 = Color3.fromRGB(50, 45, 80)
            }):Play()
        end
    end)
    b.MouseLeave:Connect(function()
        if CurrentTab ~= name then
            TweenService:Create(b, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
        end
    end)
    b.MouseButton1Click:Connect(function()
        for _, p in pairs(Pages) do p.Visible = false end
        for _, t in pairs(TabContainer:GetChildren()) do
            if t:IsA("TextButton") then
                TweenService:Create(t, TweenInfo.new(0.15), {
                    BackgroundTransparency = 1,
                    TextColor3 = Color3.fromRGB(160, 160, 180)
                }):Play()
            end
        end
        Pages[name].Visible = true
        TweenService:Create(b, TweenInfo.new(0.15), {
            BackgroundTransparency = 0.2,
            BackgroundColor3 = Color3.fromRGB(80, 60, 150),
            TextColor3 = Color3.fromRGB(255, 255, 255)
        }):Play()
        CurrentTab = name
    end)
    createPage(name)
end

-- Components
local function section(parent, title)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 24)
    l.BackgroundTransparency = 1
    l.Text = title
    l.TextColor3 = Color3.fromRGB(160, 140, 255)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Font = Enum.Font.GothamBold
    l.TextSize = 12
    l.Parent = parent
end

local function toggle(parent, label, key, cb)
    local r = Instance.new("Frame")
    r.Size = UDim2.new(1, 0, 0, 38)
    r.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
    r.BackgroundTransparency = 0.3
    r.BorderSizePixel = 0
    r.Parent = parent
    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0, 8)
    rc.Parent = r
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.6, 0, 1, 0)
    l.Position = UDim2.new(0, 14, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = label
    l.TextColor3 = Color3.fromRGB(230, 230, 240)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 13
    l.Parent = r
    local tg = Instance.new("Frame")
    tg.Size = UDim2.new(0, 42, 0, 22)
    tg.Position = UDim2.new(1, -54, 0.5, -11)
    tg.BackgroundColor3 = CONFIG[key] and Color3.fromRGB(130, 90, 255) or Color3.fromRGB(50, 50, 68)
    tg.BorderSizePixel = 0
    tg.Parent = r
    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(1, 0)
    tc.Parent = tg
    local k = Instance.new("Frame")
    k.Size = UDim2.new(0, 16, 0, 16)
    k.Position = CONFIG[key] and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    k.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    k.BorderSizePixel = 0
    k.Parent = tg
    local kc = Instance.new("UICorner")
    kc.CornerRadius = UDim.new(1, 0)
    kc.Parent = k
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = r
    btn.MouseButton1Click:Connect(function()
        CONFIG[key] = not CONFIG[key]
        TweenService:Create(tg, TweenInfo.new(0.2), {
            BackgroundColor3 = CONFIG[key] and Color3.fromRGB(130, 90, 255) or Color3.fromRGB(50, 50, 68)
        }):Play()
        TweenService:Create(k, TweenInfo.new(0.2), {
            Position = CONFIG[key] and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        }):Play()
        if cb then cb(CONFIG[key]) end
    end)
end

local function slider(parent, label, key, min, max)
    local r = Instance.new("Frame")
    r.Size = UDim2.new(1, 0, 0, 56)
    r.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
    r.BackgroundTransparency = 0.3
    r.BorderSizePixel = 0
    r.Parent = parent
    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0, 8)
    rc.Parent = r
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.7, 0, 0, 20)
    l.Position = UDim2.new(0, 14, 0, 6)
    l.BackgroundTransparency = 1
    l.Text = label
    l.TextColor3 = Color3.fromRGB(230, 230, 240)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 13
    l.Parent = r
    local vl = Instance.new("TextLabel")
    vl.Size = UDim2.new(0.3, -14, 0, 20)
    vl.Position = UDim2.new(0.7, 0, 0, 6)
    vl.BackgroundTransparency = 1
    vl.Text = tostring(CONFIG[key])
    vl.TextColor3 = Color3.fromRGB(160, 140, 255)
    vl.TextXAlignment = Enum.TextXAlignment.Right
    vl.Font = Enum.Font.GothamBold
    vl.TextSize = 13
    vl.Parent = r
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, -28, 0, 6)
    bg.Position = UDim2.new(0, 14, 0, 38)
    bg.BackgroundColor3 = Color3.fromRGB(45, 45, 62)
    bg.BorderSizePixel = 0
    bg.Parent = r
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(1, 0)
    bc.Parent = bg
    local f = Instance.new("Frame")
    local pct = (CONFIG[key] - min) / (max - min)
    f.Size = UDim2.new(pct, 0, 1, 0)
    f.BackgroundColor3 = Color3.fromRGB(140, 100, 255)
    f.BorderSizePixel = 0
    f.Parent = bg
    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(1, 0)
    fc.Parent = f
    local dragging = false
    local function update(x)
        local rel = math.clamp((x - bg.AbsolutePosition.X) / bg.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + (max - min) * rel)
        CONFIG[key] = val
        vl.Text = tostring(val)
        f.Size = UDim2.new(rel, 0, 1, 0)
    end
    bg.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(i.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            update(i.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local function button(parent, label, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 38)
    b.BackgroundColor3 = Color3.fromRGB(70, 55, 130)
    b.BorderSizePixel = 0
    b.Text = label
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.AutoButtonColor = false
    b.Parent = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = b
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(95, 75, 180) }):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(70, 55, 130) }):Play()
    end)
    b.MouseButton1Click:Connect(cb)
end

local function textbox(parent, placeholder, cb)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, 36)
    box.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
    box.BorderSizePixel = 0
    box.Text = ""
    box.PlaceholderText = placeholder
    box.PlaceholderColor3 = Color3.fromRGB(110, 110, 130)
    box.TextColor3 = Color3.fromRGB(230, 230, 240)
    box.Font = Enum.Font.GothamMedium
    box.TextSize = 13
    box.ClearTextOnFocus = false
    box.Parent = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = box
    box.FocusLost:Connect(function(enter)
        if enter and cb then cb(box.Text) end
    end)
end

-- Build Tabs
createTab("Movement", "🏃")
createTab("Visual", "👁")
createTab("Combat", "⚔")
createTab("Exploit", "💥")
createTab("Map", "🗺")
createTab("Misc", "⚙")

-- ============ MOVEMENT TAB ============
section(Pages["Movement"], "SPEED & JUMP")
slider(Pages["Movement"], "Walk Speed", "walk_speed", 16, 300)
slider(Pages["Movement"], "Jump Power", "jump_power", 50, 500)
toggle(Pages["Movement"], "Infinite Jump", "infinite_jump")
section(Pages["Movement"], "FLY")
toggle(Pages["Movement"], "Fly (WASD + Space/LCtrl)", "fly_enabled", function(s) toggleFly(s) end)
slider(Pages["Movement"], "Fly Speed", "fly_speed", 20, 300)
section(Pages["Movement"], "NOCLIP")
toggle(Pages["Movement"], "Noclip", "noclip_enabled", function(s) toggleNoclip(s) end)

-- ============ VISUAL TAB ============
section(Pages["Visual"], "ESP")
toggle(Pages["Visual"], "ESP Enabled", "esp_enabled")
section(Pages["Visual"], "LIGHTING")
toggle(Pages["Visual"], "Full Bright", "full_bright")
toggle(Pages["Visual"], "No Fog", "no_fog")

-- ============ COMBAT TAB ============
section(Pages["Combat"], "AIMBOT")
toggle(Pages["Combat"], "Aimbot (Hold RMB)", "aimbot_enabled")
slider(Pages["Combat"], "FOV", "aimbot_fov", 50, 800)
slider(Pages["Combat"], "Smoothness x100", "aimbot_smooth", 5, 100)
section(Pages["Combat"], "SILENT AIM")
toggle(Pages["Combat"], "Silent Aim (Hold LMB)", "silent_aim")
section(Pages["Combat"], "AUTO ATTACK")
toggle(Pages["Combat"], "Auto Dagger", "auto_dagger")
slider(Pages["Combat"], "Range", "auto_dagger_range", 5, 50)
section(Pages["Combat"], "SKILLCHECK")
toggle(Pages["Combat"], "Auto SkillCheck", "auto_skillcheck")
toggle(Pages["Combat"], "Perfect Zone Only", "skillcheck_perfect")

-- ============ EXPLOIT TAB ============
section(Pages["Exploit"], "REMOTE FLOOD")
-- *Catatan: efek lokal, bukan DDoS. Kamu mungkin di-kick.*
toggle(Pages["Exploit"], "Enable Flood", "flood_enabled")
slider(Pages["Exploit"], "Flood Rate (pkt/s)", "flood_rate", 1, 60)
section(Pages["Exploit"], "SPAWN ITEM")
textbox(Pages["Exploit"], "Item name (misal: Gun, Sword)", function(txt)
    if txt and #txt > 0 then spawnItem(txt) end
end)
button(Pages["Exploit"], "Rescan Remotes", function() scanRemotes() end)

-- ============ MAP TAB ============
section(Pages["Map"], "MAP TOOLS")
button(Pages["Map"], "Dump Map Structure (JSON)", function() copyMap() end)
button(Pages["Map"], "Teleport to Player...", function()
    notify("LeoHUB", "Gunakan textbox di bawah")
end)
textbox(Pages["Map"], "Player name untuk teleport", function(txt)
    if txt and #txt > 0 then
        if teleportToPlayer(txt) then
            notify("LeoHUB", "Teleported to " .. txt)
        else
            notify("LeoHUB", "Player not found: " .. txt)
        end
    end
end)

-- ============ MISC TAB ============
section(Pages["Misc"], "AVATAR")
button(Pages["Misc"], "Copy Avatar (Nearest)", function()
    local closest, cd = nil, 500
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        local c = p.Character
        if c and c:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character
           and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local d = (c.HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
            if d < cd then closest = p; cd = d end
        end
    end
    if closest then copyAvatar(closest) end
end)
section(Pages["Misc"], "INFO")
button(Pages["Misc"], "Rescan Remotes", function() scanRemotes() end)
button(Pages["Misc"], "Destroy LeoHUB", function() LeoHUB:Destroy() end)

-- Default tab
for _, t in ipairs(TabContainer:GetChildren()) do
    if t:IsA("TextButton") and t.Name:find("Movement") then
        t.BackgroundTransparency = 0.2
        t.BackgroundColor3 = Color3.fromRGB(80, 60, 150)
        t.TextColor3 = Color3.fromRGB(255, 255, 255)
        Pages["Movement"].Visible = true
        CurrentTab = "Movement"
    end
end

-- Drag
local dragging, dragStart, startPos
Header.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = i.Position
        startPos = Main.Position
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- Minimize
local minimized = false
local MiniBtn = Instance.new("TextButton")
MiniBtn.Size = UDim2.new(0, 130, 0, 38)
MiniBtn.Position = UDim2.new(0, 20, 0, 20)
MiniBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
MiniBtn.BorderSizePixel = 0
MiniBtn.Text = "LeoHUB"
MiniBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MiniBtn.Font = Enum.Font.GothamBlack
MiniBtn.TextSize = 16
MiniBtn.Visible = false
MiniBtn.Parent = LeoHUB

local mc = Instance.new("UICorner")
mc.CornerRadius = UDim.new(0, 10)
mc.Parent = MiniBtn

local mg = Instance.new("UIGradient")
mg.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 100, 200)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 200, 255)),
})
mg.Parent = MiniBtn

MiniBtn.MouseButton1Click:Connect(function()
    minimized = false
    MiniBtn.Visible = false
    Main.Visible = true
end)

MinBtn.MouseButton1Click:Connect(function()
    minimized = true
    MiniBtn.Visible = true
    Main.Visible = false
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        minimized = not minimized
        Main.Visible = not minimized
        MiniBtn.Visible = minimized
    end
end)

-- ================== DONE ==================
notify("LeoHUB", "Exploit Edition loaded. RightShift to minimize.")
print("[LeoHUB] Exploit Edition loaded — LeoXD")
