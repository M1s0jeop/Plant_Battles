local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Abilities = RS:WaitForChild("Abilities")
local WatermelonStart = Abilities:WaitForChild("WatermelonStart")
local WatermelonHit = Abilities:WaitForChild("WatermelonHit")

local COOLDOWN = 4
local lastUsed = {}

local function doKnockback(impactPos, targetRoot, force)
    local toTarget = (targetRoot.Position - impactPos)
    if toTarget.Magnitude < 0.1 then
        toTarget = Vector3.new(0,0,-1)
    end
    toTarget = Vector3.new(toTarget.X, 0, toTarget.Z).Unit
    
    local bv = Instance.new("BodyVelocity")
    bv.Velocity = (toTarget + Vector3.new(0, 0.5, 0)).Unit * force
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Parent = targetRoot
    Debris:AddItem(bv, 0.25)
end

WatermelonStart.OnServerEvent:Connect(function(player)
    local now = os.time()
    lastUsed[player] = now
end)

WatermelonHit.OnServerEvent:Connect(function(player, dropHeight, impactPosition)
    if type(dropHeight) ~= "number" or typeof(impactPosition) ~= "Vector3" then return end
    local char = player.Character
    if not char then return end
    
    dropHeight = math.clamp(dropHeight, 0, 2000)
    
    -- Tiered logic
    local tier = 1
    if dropHeight >= 400 then tier = 4
    elseif dropHeight >= 150 then tier = 3
    elseif dropHeight >= 50 then tier = 2
    end
    
    local radius = 15
    local damage = 25
    local appliesKnockback = false
    local kbForce = 0
    
    if tier == 2 then
        radius = 25
        damage = 50
    elseif tier == 3 then
        radius = 45
        damage = 80
        appliesKnockback = true
        kbForce = 80
    elseif tier == 4 then
        radius = 80
        damage = 9999
        appliesKnockback = true
        kbForce = 150
    end
    
    -- Play explosion sound
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://138084128"
    sound.Volume = 1
    
    local soundPart = Instance.new("Part")
    soundPart.Transparency = 1
    soundPart.CanCollide = false
    soundPart.Anchored = true
    soundPart.Position = impactPosition
    soundPart.Parent = workspace
    sound.Parent = soundPart
    sound:Play()
    Debris:AddItem(soundPart, 2)

    -- Deal damage & knockback
    for _, model in ipairs(workspace:GetChildren()) do
        if model == char then continue end
        local tr = model:FindFirstChild("HumanoidRootPart")
        local th = model:FindFirstChildOfClass("Humanoid")
        
        if tr and th and th.Health > 0 then
            local dist = (tr.Position - impactPosition).Magnitude
            if dist <= radius then
                th:TakeDamage(damage)
                if appliesKnockback then
                    doKnockback(impactPosition, tr, kbForce)
                end
            end
        end
    end
end)

print("WatermelonHandler network lag fix loaded")
