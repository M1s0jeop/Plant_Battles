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
local SpringOnionBounce = Abilities:WaitForChild("SpringOnionBounce")

local COOLDOWN = 8
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
            if id == "spring_onion" then return SLOT_KEYCODES[s], s end
        end
    end
    return nil, nil
end

RunService.Heartbeat:Connect(function()
    _G.AbilityCooldowns = _G.AbilityCooldowns or {}
    _G.AbilityCooldowns["spring_onion"] = { lastUsed = lastUsed, cd = COOLDOWN }
end)

local rightArm = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
if not rightArm then
    for _, v in ipairs(char:GetChildren()) do
        if v.Name:lower():find("right") and v:IsA("BasePart") then rightArm = v break end
    end
end

-- Create a visual Spring Onion
local onion = Instance.new("Part")
onion.Name = "SpringOnion"
onion.Size = Vector3.new(0.4, 2.5, 0.4)
onion.BrickColor = BrickColor.new("Lime green")
onion.Material = Enum.Material.SmoothPlastic
onion.CanCollide = false
onion.Transparency = 1
onion.Parent = char

local bulb = Instance.new("Part")
bulb.Size = Vector3.new(0.8, 0.8, 0.8)
bulb.BrickColor = BrickColor.new("Institutional white")
bulb.Shape = Enum.PartType.Ball
bulb.CanCollide = false
bulb.Transparency = 1
bulb.Parent = onion
local bWeld = Instance.new("WeldConstraint")
bWeld.Part0 = onion
bWeld.Part1 = bulb
bWeld.Parent = onion
bulb.CFrame = onion.CFrame * CFrame.new(0, -1, 0)

local onionWeld = Instance.new("Motor6D")
onionWeld.Name = "OnionWeld"
onionWeld.Part0 = rightArm
onionWeld.Part1 = onion
onionWeld.C0 = CFrame.new(0, -1, 0)
onionWeld.Parent = rightArm

local function doBounce()
    isAnimating = true
    onion.Transparency = 0
    bulb.Transparency = 0
    
    -- Raise onion
    TweenService:Create(onionWeld, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {C0 = CFrame.new(0.5, 1.5, -0.5) * CFrame.Angles(math.rad(120), 0, math.rad(-45))}
    ):Play()
    task.wait(0.2)
    
    -- Slam down
    TweenService:Create(onionWeld, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {C0 = CFrame.new(0, -1.5, -1) * CFrame.Angles(math.rad(-30), 0, 0)}
    ):Play()
    task.wait(0.15)
    
    -- Impact visuals
    local ring = Instance.new("Part")
    ring.Size = Vector3.new(0.2, 1, 1)
    ring.Shape = Enum.PartType.Cylinder
    ring.CFrame = humanoidRoot.CFrame * CFrame.new(0, -2.5, 0) * CFrame.Angles(0, 0, math.pi/2)
    ring.Anchored = true
    ring.CanCollide = false
    ring.BrickColor = BrickColor.new("Lime green")
    ring.Material = Enum.Material.Neon
    ring.Transparency = 0.2
    ring.Parent = workspace
    
    TweenService:Create(ring, TweenInfo.new(0.3), {Size = Vector3.new(0.2, 15, 15), Transparency = 1}):Play()
    Debris:AddItem(ring, 0.35)
    
    -- Launch player
        -- Launch player using direct velocity for true high jump
    humanoidRoot.AssemblyLinearVelocity = Vector3.new(0, 350, 0)
    
    -- Add horizontal air control
    local airControl = Instance.new("BodyVelocity")
    airControl.MaxForce = Vector3.new(2e4, 0, 2e4)
    airControl.Velocity = Vector3.new(0,0,0)
    airControl.Parent = humanoidRoot
    
    -- Hide onion
    onion.Transparency = 1
    bulb.Transparency = 1
    onionWeld.C0 = CFrame.new(0, -1, 0)
    isAnimating = false
    
    -- Manage air control
    task.spawn(function()
        task.wait(0.2)
        while humanoid:GetState() == Enum.HumanoidStateType.Freefall or humanoid:GetState() == Enum.HumanoidStateType.Jumping do
            local moveDir = humanoid.MoveDirection
            airControl.Velocity = moveDir * 60 -- Speedy horizontal movement
            task.wait()
        end
        airControl:Destroy()
    end)
end

UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    local myKey = getMyKey()
    if not myKey or input.KeyCode ~= myKey then return end
    if tick() - lastUsed < COOLDOWN then return end
    if isAnimating then return end

    lastUsed = tick()
    
    task.spawn(doBounce)
    SpringOnionBounce:FireServer()
end)
