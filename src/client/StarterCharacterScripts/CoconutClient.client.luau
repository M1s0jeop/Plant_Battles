local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local char = script.Parent
local humanoidRoot = char:WaitForChild("HumanoidRootPart")
local Abilities = RS:WaitForChild("Abilities")
local CoconutSlam = Abilities:WaitForChild("CoconutSlam")
local CoconutSlamCombo = Abilities:FindFirstChild("CoconutSlamCombo")
if not CoconutSlamCombo then
    CoconutSlamCombo = Instance.new("RemoteEvent")
    CoconutSlamCombo.Name = "CoconutSlamCombo"
    CoconutSlamCombo.Parent = Abilities
end

local COOLDOWN = 3
local SLAM_RANGE = 12
local lastUsed = -COOLDOWN
local isAnimating = false

local SLOT_KEYCODES = {
    [1] = Enum.KeyCode.Q,
    [2] = Enum.KeyCode.E,
    [3] = Enum.KeyCode.R,
    [4] = Enum.KeyCode.F
}
local function getMyKey()
    if _G.EquippedAbilities then
        for s, id in pairs(_G.EquippedAbilities) do
            if id == "coconut_slam" then return SLOT_KEYCODES[s], s end
        end
    end
    return nil, nil
end

-- KOKOS
local rightArm = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
if not rightArm then
    for _, v in ipairs(char:GetChildren()) do
        if v.Name:lower():find("right") and v:IsA("BasePart") then rightArm = v break end
    end
end

local coconut = Instance.new("Part")
coconut.Name = "Coconut"
coconut.Size = Vector3.new(0.85,0.85,0.85)
coconut.BrickColor = BrickColor.new("Brown")
coconut.Material = Enum.Material.SmoothPlastic
coconut.CanCollide = false
coconut.Transparency = 1
coconut.Parent = char
Instance.new("SpecialMesh", coconut).MeshType = Enum.MeshType.Sphere

local spots = {}
for _, off in ipairs({Vector3.new(0.25,0.25,0.3), Vector3.new(-0.2,0.15,0.35), Vector3.new(0.05,-0.25,0.32)}) do
    local sp = Instance.new("Part")
    sp.Size = Vector3.new(0.18,0.18,0.1)
    sp.BrickColor = BrickColor.new("Really black")
    sp.Material = Enum.Material.SmoothPlastic
    sp.CanCollide = false; sp.Transparency = 1
    sp.Parent = char
    Instance.new("SpecialMesh", sp).MeshType = Enum.MeshType.Sphere
    local sw = Instance.new("WeldConstraint")
    sw.Part0 = coconut; sw.Part1 = sp; sw.Parent = coconut
    sp.CFrame = coconut.CFrame * CFrame.new(off)
    table.insert(spots, sp)
end

local holdWeld = Instance.new("Motor6D")
holdWeld.Name = "CoconutWeld"
holdWeld.Part0 = rightArm; holdWeld.Part1 = coconut
holdWeld.C0 = CFrame.new(0,-1.0,0)
holdWeld.Parent = rightArm

local function setVisible(v)
    coconut.Transparency = v and 0 or 1
    for _, sp in ipairs(spots) do sp.Transparency = v and 0 or 1 end
end

local idleT = 0
RunService.RenderStepped:Connect(function(dt)
    if isAnimating then return end
    idleT = idleT + dt * 1.8
    if holdWeld then holdWeld.C0 = CFrame.new(0, -1.0 + math.sin(idleT)*0.04, 0) end
end)

-- IMPACT
local function spawnImpact(pos)
    for i = 1, 5 do
        local chunk = Instance.new("Part")
        chunk.Size = Vector3.new(0.2,0.2,0.2)
        chunk.BrickColor = BrickColor.new("Brown")
        chunk.Material = Enum.Material.SmoothPlastic
        chunk.CFrame = CFrame.new(pos) * CFrame.new(math.random(-10,10)*0.1, math.random(0,8)*0.1, math.random(-5,5)*0.1)
        chunk.Velocity = Vector3.new(math.random(-15,15), math.random(8,18), math.random(-15,15))
        chunk.Parent = workspace
        Debris:AddItem(chunk, 0.6)
        TweenService:Create(chunk, TweenInfo.new(0.5), {Transparency=1, Size=Vector3.new(0.05,0.05,0.05)}):Play()
    end
    local ring = Instance.new("Part")
    ring.Size = Vector3.new(1,0.1,1); ring.Shape = Enum.PartType.Cylinder
    ring.CFrame = CFrame.new(pos) * CFrame.Angles(0,0,math.pi/2)
    ring.Anchored = true; ring.CanCollide = false
    ring.BrickColor = BrickColor.new("Bright orange"); ring.Material = Enum.Material.Neon
    ring.Transparency = 0.2; ring.Parent = workspace
    TweenService:Create(ring, TweenInfo.new(0.3), {Size=Vector3.new(8,0.1,8), Transparency=1}):Play()
    Debris:AddItem(ring, 0.35)
end

-- SLAM
local function doSlam()
    isAnimating = true
    setVisible(true)

    TweenService:Create(holdWeld, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {C0 = CFrame.new(0.3,0.6,-0.3) * CFrame.Angles(math.rad(-80), math.rad(20), math.rad(-20))}
    ):Play()
    task.wait(0.18)

    TweenService:Create(holdWeld, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {C0 = CFrame.new(-0.1,-0.5,-0.9) * CFrame.Angles(math.rad(55), math.rad(-10), math.rad(15))}
    ):Play()
    task.wait(0.09)

    local didHit = false
    for _, model in ipairs(workspace:GetChildren()) do
        if model == char then continue end
        local tr = model:FindFirstChild("HumanoidRootPart")
        local th = model:FindFirstChildOfClass("Humanoid")
        if not tr or not th then continue end
        if th.Health <= 0 then continue end
        local dist = (tr.Position - humanoidRoot.Position).Magnitude
        if dist <= SLAM_RANGE then didHit = true break end
    end

    if didHit then
        spawnImpact((humanoidRoot.CFrame * CFrame.new(0,0,-2)).Position)
        coconut.BrickColor = BrickColor.new("Bright orange")
        task.wait(0.06)
        coconut.BrickColor = BrickColor.new("Brown")
    else
        local miss = Instance.new("Part")
        miss.Size = Vector3.new(0.5,0.5,0.5)
        miss.BrickColor = BrickColor.new("Medium stone grey")
        miss.Material = Enum.Material.Neon; miss.Transparency = 0.5
        miss.Anchored = true; miss.CanCollide = false
        miss.CFrame = humanoidRoot.CFrame * CFrame.new(0,0,-2.5)
        miss.Parent = workspace
        TweenService:Create(miss, TweenInfo.new(0.2), {Transparency=1, Size=Vector3.new(1.5,1.5,1.5)}):Play()
        Debris:AddItem(miss, 0.25)
    end

    task.wait(0.07)
    TweenService:Create(holdWeld, TweenInfo.new(0.28, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
        {C0 = CFrame.new(0,-1.0,0)}
    ):Play()
    task.wait(0.28)
    setVisible(false)
    isAnimating = false
end

RunService.Heartbeat:Connect(function()
    _G.AbilityCooldowns = _G.AbilityCooldowns or {}
    _G.AbilityCooldowns["coconut_slam"] = { lastUsed = lastUsed, cd = COOLDOWN }
end)

local qPending = false
local function inRange()
    for _, model in ipairs(workspace:GetChildren()) do
        if model == char then continue end
        local tr = model:FindFirstChild("HumanoidRootPart")
        local th = model:FindFirstChildOfClass("Humanoid")
        if not tr or not th then continue end
        if th.Health <= 0 then continue end
        if (tr.Position - humanoidRoot.Position).Magnitude <= SLAM_RANGE then return true end
    end
    return false
end

UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
        local myKey = getMyKey()
    if not myKey or input.KeyCode ~= myKey then return end
    if tick() - lastUsed < COOLDOWN then return end
    if qPending or isAnimating then return end

    lastUsed = tick()

    local gs = _G.GrappleState
    local comboTarget = nil
    if gs then
        if gs.active and gs.targetModel and gs.cleanupFn then
            comboTarget = gs.targetModel
            gs.cleanupFn("LEFT")
            task.wait(0.05)
        elseif gs.pulling then
            comboTarget = gs.pulling
        elseif gs.dashing then
            comboTarget = gs.dashing
        end
    end

    if comboTarget then
        qPending = true
        task.spawn(function()
            local waited = 0
            while waited < 5 do
                local targetRoot = comboTarget:FindFirstChild("HumanoidRootPart")
                if not targetRoot then break end
                if (targetRoot.Position - humanoidRoot.Position).Magnitude <= 18 then
                    qPending = false
                    isAnimating = false
                    task.spawn(doSlam)
                    CoconutSlamCombo:FireServer(comboTarget)
                    return
                end
                task.wait(0.03)
                waited = waited + 0.03
            end
            qPending = false
        end)
        return
    end

    if inRange() then
        task.spawn(doSlam)
        CoconutSlam:FireServer()
    else
        qPending = true
        task.spawn(function()
            local waited = 0
            while waited < 5 do
                task.wait(0.03)
                waited = waited + 0.03
                if inRange() then
                    qPending = false
                    isAnimating = false
                    task.spawn(doSlam)
                    CoconutSlam:FireServer()
                    return
                end
            end
            qPending = false
        end)
    end
end)
