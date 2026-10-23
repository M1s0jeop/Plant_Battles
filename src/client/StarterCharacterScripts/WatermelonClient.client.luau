local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local char = script.Parent
local humanoidRoot = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")
local Abilities = RS:WaitForChild("Abilities")
local WatermelonStart = Abilities:WaitForChild("WatermelonStart")
local WatermelonHit = Abilities:WaitForChild("WatermelonHit")

local COOLDOWN = 4
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
            if id == "watermelon_slam" then return SLOT_KEYCODES[s], s end
        end
    end
    return nil, nil
end

RunService.Heartbeat:Connect(function()
    _G.AbilityCooldowns = _G.AbilityCooldowns or {}
    _G.AbilityCooldowns["watermelon_slam"] = { lastUsed = lastUsed, cd = COOLDOWN }
end)

local rightArm = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
if not rightArm then
    for _, v in ipairs(char:GetChildren()) do
        if v.Name:lower():find("right") and v:IsA("BasePart") then rightArm = v break end
    end
end

local melon = Instance.new("Part")
melon.Name = "Watermelon"
melon.Size = Vector3.new(2.5, 2.5, 3)
melon.BrickColor = BrickColor.new("Earth green")
melon.Material = Enum.Material.Grass
melon.Shape = Enum.PartType.Ball
melon.CanCollide = false
melon.Transparency = 1
melon.Parent = char

local mWeld = Instance.new("Motor6D")
mWeld.Name = "MelonWeld"
mWeld.Part0 = rightArm
mWeld.Part1 = melon
mWeld.C0 = CFrame.new(0, -1, 0)
mWeld.Parent = rightArm

local function doSlam()
    isAnimating = true
    WatermelonStart:FireServer()
    
    local startY = humanoidRoot.Position.Y
    
    melon.Transparency = 0
    -- Pull animation
    mWeld.C0 = CFrame.new(0.5, 3, -1) * CFrame.Angles(math.rad(45), 0, 0)
    TweenService:Create(mWeld, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {C0 = CFrame.new(0, -2, -1.5) * CFrame.Angles(math.rad(-60), 0, 0)}
    ):Play()
    task.wait(0.15)
    
    -- Clear other forces
    for _, child in ipairs(humanoidRoot:GetChildren()) do
        if child:IsA("BodyVelocity") or child:IsA("BodyForce") or child:IsA("BodyPosition") then
            child:Destroy()
        end
    end
    
    -- Plunge downwards
    local bv = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.new(0, -400, 0)
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Parent = humanoidRoot
    
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    
    -- Wait for impact
    local hitGround = false
    local fallTime = 0
    local impactPosition = humanoidRoot.Position
    
    while fallTime < 4 do
        local dt = task.wait()
        fallTime = fallTime + dt
        
        local hit = workspace:Raycast(humanoidRoot.Position, Vector3.new(0, -15, 0), params)
        if hit and hit.Instance and hit.Instance.CanCollide then
            hitGround = true
            impactPosition = hit.Position
            humanoidRoot.CFrame = CFrame.new(humanoidRoot.Position.X, hit.Position.Y + 3, humanoidRoot.Position.Z)
            break
        end
    end
    
    if bv and bv.Parent then bv:Destroy() end
    melon.Transparency = 1
    mWeld.C0 = CFrame.new(0, -1, 0)
    
    if hitGround then
        humanoidRoot.AssemblyLinearVelocity = Vector3.new(0,0,0)
        
        local dropHeight = math.max(0, startY - humanoidRoot.Position.Y)
        
        -- Tiered logic
        local tier = 1
        if dropHeight >= 400 then tier = 4
        elseif dropHeight >= 150 then tier = 3
        elseif dropHeight >= 50 then tier = 2
        end
        
        local radius = 15
        local chunkCount = 8
        if tier == 2 then radius = 25; chunkCount = 12
        elseif tier == 3 then radius = 45; chunkCount = 20
        elseif tier == 4 then radius = 80; chunkCount = 35
        end
        
        local diameter = radius * 2
        print("WATERMELON SLAM! Drop Height:", dropHeight, "Tier:", tier)
        
        -- Visual effects
        local ring = Instance.new("Part")
        ring.Size = Vector3.new(0.2, 1, 1)
        ring.Shape = Enum.PartType.Cylinder
        ring.CFrame = CFrame.new(impactPosition) * CFrame.Angles(0, 0, math.pi/2)
        ring.Anchored = true
        ring.CanCollide = false
        ring.BrickColor = tier >= 4 and BrickColor.new("Bright red") or BrickColor.new("Earth green")
        ring.Material = Enum.Material.Neon
        ring.Transparency = 0.2
        ring.Parent = workspace
        TweenService:Create(ring, TweenInfo.new(0.4), {Size = Vector3.new(0.2, diameter, diameter), Transparency = 1}):Play()
        Debris:AddItem(ring, 0.45)
        
        -- Splatter chunks
        for i=1, chunkCount do
            local chunk = Instance.new("Part")
            chunk.Size = Vector3.new(1,1,1)
            chunk.BrickColor = math.random() > 0.6 and BrickColor.new("Earth green") or BrickColor.new("Bright red")
            chunk.CFrame = CFrame.new(impactPosition) * CFrame.new(0,1,0)
            chunk.Velocity = Vector3.new(math.random(-50,50), math.random(10,80), math.random(-50,50))
            chunk.Parent = workspace
            Debris:AddItem(chunk, 1)
        end
        
        WatermelonHit:FireServer(dropHeight, impactPosition)
    end
    
    isAnimating = false
end

UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    local myKey = getMyKey()
    if not myKey or input.KeyCode ~= myKey then return end
    if tick() - lastUsed < COOLDOWN then return end
    if isAnimating then return end

    if humanoid.FloorMaterial ~= Enum.Material.Air and humanoid:GetState() ~= Enum.HumanoidStateType.Freefall and humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
        return
    end

    lastUsed = tick()
    task.spawn(doSlam)
end)
