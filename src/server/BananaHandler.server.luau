local rs = game:GetService("ReplicatedStorage")
local ds = game:GetService("Debris")
local abilities = rs:WaitForChild("Abilities")
local BananaSpawn = abilities:WaitForChild("BananaSpawn")

local BANANA_DAMAGE = 45
local BANANA_LIFETIME = 10
local START_SPEED = 10
local MAX_SPEED = 120
local ACCEL_TIME = 3.5

BananaSpawn.OnServerEvent:Connect(function(player)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then return end
    
    -- Create the Banana Model
    local banana = Instance.new("Model")
    banana.Name = "BananaSurf_" .. player.Name
    
    local mainPart = Instance.new("Part")
    mainPart.Name = "MainPart"
    mainPart.Size = Vector3.new(3, 2, 8)
    mainPart.BrickColor = BrickColor.new("Bright yellow")
    mainPart.Material = Enum.Material.SmoothPlastic
    mainPart.CFrame = root.CFrame * CFrame.new(0, -0.5, -4)
    mainPart.CustomPhysicalProperties = PhysicalProperties.new(5, 0.3, 0.5, 1, 1)
    
    -- Make it look like a banana
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Sphere
    mesh.Parent = mainPart
    
    -- Seat for the player
    local seat = Instance.new("Seat")
    seat.Name = "BananaSeat"
    seat.Size = Vector3.new(2, 0.5, 2)
    seat.Transparency = 1
    seat.CFrame = mainPart.CFrame * CFrame.new(0, 1.5, 0)
    
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = mainPart
    weld.Part1 = seat
    weld.Parent = mainPart
    
    mainPart.Parent = banana
    seat.Parent = banana
        banana.PrimaryPart = mainPart
    banana.Parent = workspace
    
    mainPart:SetNetworkOwner(nil)

    
    -- Player can jump on it manually
    
    -- Prevent falling over using BodyGyro
    local gyro = Instance.new("BodyGyro")
    gyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    gyro.CFrame = CFrame.new(mainPart.Position, mainPart.Position + root.CFrame.LookVector)
    gyro.Parent = mainPart
    
    -- Movement using BodyVelocity
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5, 0, 1e5) -- Let gravity work, but control X/Z
    bv.Velocity = root.CFrame.LookVector * START_SPEED
    bv.Parent = mainPart
    
    local direction = root.CFrame.LookVector
    
    local startTime = tick()
    
    -- Acceleration Loop
    local connection
    connection = game:GetService("RunService").Heartbeat:Connect(function()
        if not mainPart or not mainPart.Parent then 
            connection:Disconnect() 
            return 
        end
        
        local elapsed = tick() - startTime
        local progress = math.clamp(elapsed / ACCEL_TIME, 0, 1)
        local currentSpeed = START_SPEED + (MAX_SPEED - START_SPEED) * progress
        
        bv.Velocity = direction * currentSpeed
        gyro.CFrame = CFrame.new(mainPart.Position, mainPart.Position + direction)
    end)
    
    -- Hit Detection
    local hitDebounce = {}
    mainPart.Touched:Connect(function(hit)
        local model = hit:FindFirstAncestorOfClass("Model")
        if model and model ~= char and not hitDebounce[model] then
            local th = model:FindFirstChildOfClass("Humanoid")
            local tr = model:FindFirstChild("HumanoidRootPart")
            if th and tr and th.Health > 0 then
                hitDebounce[model] = true
                
                -- Damage
                th:TakeDamage(BANANA_DAMAGE)
                
                -- Knockback (Sideways and slightly Up)
                local toTarget = (tr.Position - mainPart.Position).Unit
                -- Force it mostly sideways relative to banana path
                local rightVec = mainPart.CFrame.RightVector
                local dot = toTarget:Dot(rightVec)
                local sideDir = rightVec
                if dot < 0 then sideDir = -rightVec end
                
                local kbDir = (sideDir * 1.5 + Vector3.new(0, 1.2, 0)).Unit
                
                local kb = Instance.new("BodyVelocity")
                kb.Velocity = kbDir * 80
                kb.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                kb.Parent = tr
                ds:AddItem(kb, 0.2)
                
                task.delay(1, function() hitDebounce[model] = nil end)
            end
        end
    end)
    
    -- Despawn Logic
    task.delay(BANANA_LIFETIME, function()
        if banana and banana.Parent then
            -- Explosion effect
            local exp = Instance.new("Explosion")
            exp.Position = mainPart.Position
            exp.BlastRadius = 0
            exp.BlastPressure = 0
            exp.Parent = workspace
            
            banana:Destroy()
        end
    end)
end)

print("BananaHandler loaded!")
