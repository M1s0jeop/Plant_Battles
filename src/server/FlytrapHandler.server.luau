local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local Abilities = ReplicatedStorage:WaitForChild("Abilities")

local FlytrapDig = Abilities:WaitForChild("FlytrapDig")
local FlytrapEmerge = Abilities:WaitForChild("FlytrapEmerge")
local FlytrapSpit = Abilities:WaitForChild("FlytrapSpit")

local state = {}

-- Setup Collision Groups correctly
pcall(function()
    PhysicsService:RegisterCollisionGroup("Characters")
    PhysicsService:RegisterCollisionGroup("Digging")
    
    -- Digging can hit Default (Map) but NOT Characters
    PhysicsService:CollisionGroupSetCollidable("Digging", "Default", true)
    PhysicsService:CollisionGroupSetCollidable("Digging", "Characters", false)
    PhysicsService:CollisionGroupSetCollidable("Digging", "Digging", false)
    
    -- Characters can hit Default and Characters
    PhysicsService:CollisionGroupSetCollidable("Characters", "Default", true)
    PhysicsService:CollisionGroupSetCollidable("Characters", "Characters", true)
end)

-- Function to ensure all normal players/dummies are in "Characters" group
local function updateCharactersGroup()
    for _, model in ipairs(workspace:GetChildren()) do
        if model:FindFirstChildOfClass("Humanoid") then
            -- Skip if they are digging
            local isDigging = false
            local plyr = game.Players:GetPlayerFromCharacter(model)
            if plyr and state[plyr] and state[plyr].active == "digging" then
                isDigging = true
            end
            
            if not isDigging then
                for _, part in ipairs(model:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CollisionGroup = "Characters"
                    end
                end
            end
        end
    end
end

-- Update every second to catch new dummies
task.spawn(function()
    while task.wait(1) do
        updateCharactersGroup()
    end
end)

local function setVisibilityAndCollision(character, isVisible)
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            if part.Name ~= "HumanoidRootPart" then
                part.Transparency = isVisible and 0 or 1
            end
            
            if not isVisible then
                part.CollisionGroup = "Digging"
            else
                part.CollisionGroup = "Characters"
            end
        elseif part:IsA("Decal") then
            part.Transparency = isVisible and 0 or 1
        end
    end
end

FlytrapDig.OnServerEvent:Connect(function(player)
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end
    
    if state[player] and state[player].active then return end
    if state[player] and state[player].cooldown and os.time() < state[player].cooldown then return end

    state[player] = {
        cooldown = os.time() + 6, -- must match COOLDOWN in FlytrapClient and the AbilityMenu registry
        active = "digging",
        startTime = os.time(),
        target = nil,
    }

    setVisibilityAndCollision(char, false)
    hum.WalkSpeed = 35 -- Boosted more
end)

local function finishAbility(player)
    if not state[player] then return end
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = 16
        end
        setVisibilityAndCollision(char, true)
    end
    
    local target = state[player].target
    if target and target.Parent then
        local tHum = target:FindFirstChildOfClass("Humanoid")
        if tHum then tHum.WalkSpeed = 16 tHum.JumpPower = 50 end
        local tRoot = target:FindFirstChild("HumanoidRootPart")
        if tRoot then
            local weld = tRoot:FindFirstChild("SwallowWeld")
            if weld then weld:Destroy() end
        end
    end
    
    state[player].active = nil
    state[player].target = nil
    -- cooldown moved to dig start
end

local function spitTarget(player, target)
    if not target or not target.Parent then return end
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    
    local tHum = target:FindFirstChildOfClass("Humanoid")
    local tRoot = target:FindFirstChild("HumanoidRootPart")
    if tHum and tRoot then
        local weld = tRoot:FindFirstChild("SwallowWeld")
        if weld then weld:Destroy() end
        
        tHum.WalkSpeed = 16
        tHum.JumpPower = 50
        
        if root then
            tRoot.CFrame = root.CFrame + root.CFrame.LookVector * 5 + Vector3.new(0,2,0)
            local bv = Instance.new("BodyVelocity")
            bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            bv.Velocity = root.CFrame.LookVector * 50 + Vector3.new(0,20,0)
            bv.Parent = tRoot
            game.Debris:AddItem(bv, 0.2)
        end
        
        tHum:TakeDamage(20)
    end
    finishAbility(player)
end

FlytrapEmerge.OnServerEvent:Connect(function(player)
    if not state[player] or state[player].active ~= "digging" then return end
    
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    
    -- Find enemy
    local hitEnemy = nil
    local closestDist = math.huge
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and obj ~= char and obj:FindFirstChild("Humanoid") and obj:FindFirstChild("HumanoidRootPart") then
            local eHum = obj:FindFirstChild("Humanoid")
            if eHum.Health > 0 then
                local dist = (obj.HumanoidRootPart.Position - root.Position).Magnitude
                if dist <= 6 then -- Increased from 12 to 24 for much bigger range
                    if dist < closestDist then
                        closestDist = dist
                        hitEnemy = obj
                    end
                end
            end
        end
    end
    
    if hitEnemy then
        local eHum = hitEnemy:FindFirstChild("Humanoid")
        local hpPercent = eHum.Health / eHum.MaxHealth
        if hpPercent <= 0.3 then
            -- Execute
            eHum.Health = 0
            finishAbility(player)
        else
            -- Swallow
            local eRoot = hitEnemy:FindFirstChild("HumanoidRootPart")
            if eRoot then
                eHum.WalkSpeed = 0
                eHum.JumpPower = 0
                eRoot.CFrame = root.CFrame
                local weld = Instance.new("WeldConstraint")
                weld.Name = "SwallowWeld"
                weld.Part0 = root
                weld.Part1 = eRoot
                weld.Parent = eRoot
                
                state[player].active = "holding"
                state[player].target = hitEnemy
                
                hum.WalkSpeed = 8
                
                task.delay(8, function()
                    if state[player] and state[player].active == "holding" and state[player].target == hitEnemy then
                        spitTarget(player, hitEnemy)
                    end
                end)
            else
                finishAbility(player)
            end
        end
    else
        finishAbility(player)
    end
end)

FlytrapSpit.OnServerEvent:Connect(function(player)
    if state[player] and state[player].active == "holding" then
        spitTarget(player, state[player].target)
    end
end)
print("FlytrapHandler fully updated!")
