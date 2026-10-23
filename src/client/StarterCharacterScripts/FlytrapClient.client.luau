local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Abilities = ReplicatedStorage:WaitForChild("Abilities")
local FlytrapDig = Abilities:WaitForChild("FlytrapDig")
local FlytrapEmerge = Abilities:WaitForChild("FlytrapEmerge")
local FlytrapSpit = Abilities:WaitForChild("FlytrapSpit")

local player = Players.LocalPlayer
local character = script.Parent
local root = character:WaitForChild("HumanoidRootPart")
local hum = character:WaitForChild("Humanoid")

local COOLDOWN = 6
local lastUsed = -COOLDOWN

local state = "none" -- none, digging, holding
local trailConnection = nil
local activeGyro = nil
local activeRing = nil
local RADIUS = 6
local MS_BOOST = 40 -- speed boost while digging

local SLOT_KEYCODES = {
    [1] = Enum.KeyCode.Q,
    [2] = Enum.KeyCode.E,
    [3] = Enum.KeyCode.R,
    [4] = Enum.KeyCode.F
}
local function getMyKey()
    if _G.EquippedAbilities then
        for s, id in pairs(_G.EquippedAbilities) do
            if id == "flytrap" then return SLOT_KEYCODES[s], s end
        end
    end
    return nil, nil
end

RunService.Heartbeat:Connect(function()
    _G.AbilityCooldowns = _G.AbilityCooldowns or {}
    _G.AbilityCooldowns["flytrap"] = { lastUsed = lastUsed, cd = COOLDOWN }
end)

-- Spawns physical brown cubes
local function spawnDirtCube(pos, velocity)
    local chunk = Instance.new("Part")
    local size = math.random(10, 20) * 0.1
    chunk.Size = Vector3.new(size, size, size)
    chunk.BrickColor = BrickColor.new("Brown")
    chunk.Material = Enum.Material.SmoothPlastic
    chunk.CFrame = CFrame.new(pos) * CFrame.Angles(math.random()*math.pi, math.random()*math.pi, math.random()*math.pi)
    chunk.Velocity = velocity or Vector3.new(math.random(-15,15), math.random(10,25), math.random(-15,15))
    chunk.CanCollide = false
    chunk.CanQuery = false
    chunk.Parent = workspace
    Debris:AddItem(chunk, 1.2)
    
    TweenService:Create(chunk, TweenInfo.new(1.2), {Transparency=1, Size=Vector3.new(0,0,0)}):Play()
end

-- Stores each part's transparency before digging, so we restore EXACTLY what
-- was there before - hidden ability props (coconut, watermelon, kiwi, onion)
-- parented to the character must stay hidden after we emerge.
local digTransparencyStore = {}

local function cleanupDig()
    if trailConnection then trailConnection:Disconnect(); trailConnection = nil end
    if activeGyro then activeGyro:Destroy(); activeGyro = nil end
    if activeRing then activeRing:Destroy(); activeRing = nil end
    state = "none"
    if hum and hum.Parent then
        hum.WalkSpeed = 16
        hum.JumpPower = 50
    end
    for v, orig in pairs(digTransparencyStore) do
        if v and v.Parent then v.Transparency = orig end
    end
    table.clear(digTransparencyStore)
end

local function emerge(pos)
    cleanupDig()
    if root and root.Parent then
        root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    end
    state = "holding"
    
    -- Emerge explosion of cubes
    for i = 1, 15 do
        spawnDirtCube(pos, Vector3.new(math.random(-25,25), math.random(30,55), math.random(-25,25)))
    end
    
    FlytrapEmerge:FireServer(pos)
    
    task.delay(4.5, function()
        if state == "holding" then
            state = "none"
            FlytrapSpit:FireServer()
        end
    end)
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    local myKey = getMyKey()
    
    -- Recast with ability key or LMB
    if state == "digging" and ((myKey and input.KeyCode == myKey) or input.UserInputType == Enum.UserInputType.MouseButton1) then
        if root and root.Parent then
            emerge(root.Position)
        end
        return
    end

        if state == "holding" and ((myKey and input.KeyCode == myKey) or input.UserInputType == Enum.UserInputType.MouseButton1) then
        state = "none"
        FlytrapSpit:FireServer()
        return
    end

    if myKey and input.KeyCode == myKey then
        if state == "none" then
            if tick() - lastUsed < COOLDOWN then return end
            lastUsed = tick()

            state = "digging"
            FlytrapDig:FireServer()

            hum.WalkSpeed = MS_BOOST
            hum.JumpPower = 0
            
            table.clear(digTransparencyStore)
            for _, v in ipairs(character:GetDescendants()) do
                if (v:IsA("BasePart") and v.Name ~= "HumanoidRootPart") or v:IsA("Decal") then
                    digTransparencyStore[v] = v.Transparency
                    v.Transparency = 1
                end
            end

            activeRing = Instance.new("Part")
            activeRing.Size = Vector3.new(0.2, RADIUS*2, RADIUS*2)
            activeRing.Shape = Enum.PartType.Cylinder
            activeRing.Material = Enum.Material.Neon
            activeRing.BrickColor = BrickColor.new("Really red")
            activeRing.Transparency = 0.6
            activeRing.Anchored = true
            activeRing.CanCollide = false
            activeRing.CanQuery = false
            activeRing.Parent = workspace

            activeGyro = Instance.new("BodyGyro")
            activeGyro.MaxTorque = Vector3.new(0, 400000, 0)
            activeGyro.P = 30000
            activeGyro.Parent = root

            local t = 0
            local dirtTimer = 0
            trailConnection = RunService.RenderStepped:Connect(function(dt)
                t = t + dt
                dirtTimer = dirtTimer + dt
                
                -- Spawn trailing cubes
                                if dirtTimer > 0.08 then
                    dirtTimer = 0
                    if hum.MoveDirection.Magnitude > 0 then
                        local right = root.CFrame.RightVector
                        -- Left side chunk
                        local velLeft = (-right * math.random(15, 25)) + Vector3.new(0, math.random(10, 20), 0)
                        spawnDirtCube(root.Position - Vector3.new(0, 2.5, 0), velLeft)
                        -- Right side chunk
                        local velRight = (right * math.random(15, 25)) + Vector3.new(0, math.random(10, 20), 0)
                        spawnDirtCube(root.Position - Vector3.new(0, 2.5, 0), velRight)
                    end
                end
                
                local moveDir = hum.MoveDirection
                if moveDir.Magnitude > 0 then
                    activeGyro.CFrame = CFrame.new(Vector3.new(), moveDir)
                end
                
                -- Check for enemies in radius
                local canEat = false
                for _, model in ipairs(workspace:GetChildren()) do
                    if model ~= character then
                        local tr = model:FindFirstChild("HumanoidRootPart")
                        local th = model:FindFirstChildOfClass("Humanoid")
                        if tr and th and th.Health > 0 then
                            local dist = (tr.Position - root.Position).Magnitude
                            -- Cylinder radius check is horizontally roughly RADIUS. We use 3D dist for simplicity or ignore Y
                            local horizDist = Vector3.new(tr.Position.X - root.Position.X, 0, tr.Position.Z - root.Position.Z).Magnitude
                            if horizDist <= RADIUS and math.abs(tr.Position.Y - root.Position.Y) < 10 then
                                canEat = true
                                break
                            end
                        end
                    end
                end
                
                if canEat then
                    activeRing.BrickColor = BrickColor.new("Bright green")
                else
                    activeRing.BrickColor = BrickColor.new("Really red")
                end
                
                local rp = RaycastParams.new()
                rp.FilterDescendantsInstances = {character, activeRing}
                rp.FilterType = Enum.RaycastFilterType.Exclude
                local res = workspace:Raycast(root.Position, Vector3.new(0,-10,0), rp)
                
                if res then
                    activeRing.CFrame = CFrame.new(res.Position) * CFrame.Angles(0,0,math.pi/2)
                else
                    activeRing.CFrame = root.CFrame * CFrame.new(0,-3,0) * CFrame.Angles(0,0,math.pi/2)
                end
                
                if t > 7 then
                    emerge(root.Position)
                end
            end)
        end
    end
end)
