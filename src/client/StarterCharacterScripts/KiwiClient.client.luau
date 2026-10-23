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
local KiwiDisengage = Abilities:WaitForChild("KiwiDisengage")

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
            if id == "kiwi_disengage" then return SLOT_KEYCODES[s], s end
        end
    end
    return nil, nil
end

RunService.Heartbeat:Connect(function()
    _G.AbilityCooldowns = _G.AbilityCooldowns or {}
    _G.AbilityCooldowns["kiwi_disengage"] = { lastUsed = lastUsed, cd = COOLDOWN }
end)

local rightArm = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
if not rightArm then
    for _, v in ipairs(char:GetChildren()) do
        if v.Name:lower():find("right") and v:IsA("BasePart") then rightArm = v break end
    end
end

local kiwiModel = Instance.new("Part")
kiwiModel.Name = "Kiwi"
kiwiModel.Size = Vector3.new(0.6, 0.4, 0.4)
kiwiModel.BrickColor = BrickColor.new("Bright green")
kiwiModel.Material = Enum.Material.SmoothPlastic
kiwiModel.CanCollide = false
kiwiModel.Transparency = 1
kiwiModel.Parent = char

local kiwiWeld = Instance.new("Motor6D")
kiwiWeld.Name = "KiwiWeld"
kiwiWeld.Part0 = rightArm
kiwiWeld.Part1 = kiwiModel
kiwiWeld.C0 = CFrame.new(0, -1, 0)
kiwiWeld.Parent = rightArm

local function doEatKiwi()
    isAnimating = true
    kiwiModel.Transparency = 0
    
    -- Animate hand up to mouth
    TweenService:Create(kiwiWeld, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {C0 = CFrame.new(0.2, 0.8, -0.4) * CFrame.Angles(math.rad(-60), 0, math.rad(-20))}
    ):Play()
    task.wait(0.2)
    
    -- Munch effect
    local crunch = Instance.new("Part")
    crunch.Size = Vector3.new(0.1,0.1,0.1)
    crunch.BrickColor = BrickColor.new("Lime green")
    crunch.Anchored = true
    crunch.CanCollide = false
    crunch.CFrame = kiwiModel.CFrame
    crunch.Parent = workspace
    Debris:AddItem(crunch, 0.5)
    
    for i=1, 5 do
        local p = Instance.new("Part")
        p.Size = Vector3.new(0.1,0.1,0.1)
        p.BrickColor = BrickColor.new("Lime green")
        p.CFrame = kiwiModel.CFrame
        p.Velocity = Vector3.new(math.random(-10,10), math.random(5,15), math.random(-10,10))
        p.Parent = workspace
        Debris:AddItem(p, 0.5)
    end
    
    local ring = Instance.new("Part")
    ring.Size = Vector3.new(0.1, 1, 1)
    ring.Shape = Enum.PartType.Cylinder
    ring.CFrame = humanoidRoot.CFrame * CFrame.new(0, -2.5, 0) * CFrame.Angles(0, 0, math.pi/2)
    ring.Anchored = true
    ring.CanCollide = false
    ring.BrickColor = BrickColor.new("Lime green")
    ring.Material = Enum.Material.Neon
    ring.Transparency = 0.2
    ring.Parent = workspace
    
    TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.1, 36, 36),
        Transparency = 1
    }):Play()
    Debris:AddItem(ring, 0.45)
    
    kiwiModel.Transparency = 1
    task.wait(0.1)
    
    -- Hand back down
    TweenService:Create(kiwiWeld, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {C0 = CFrame.new(0, -1, 0)}
    ):Play()
    task.wait(0.2)
    
    isAnimating = false
end

UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    local myKey = getMyKey()
    if not myKey or input.KeyCode ~= myKey then return end
    if tick() - lastUsed < COOLDOWN then return end
    if isAnimating then return end

    lastUsed = tick()
    
    task.spawn(doEatKiwi)
    KiwiDisengage:FireServer()
end)
