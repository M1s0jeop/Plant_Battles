local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Abilities = RS:WaitForChild("Abilities")
local KiwiDisengage = Abilities:WaitForChild("KiwiDisengage")

local COOLDOWN = 4
local KNOCKBACK_FORCE = 60
local RADIUS = 18

local lastUsed = {}

local function doKnockback(casterRoot, targetRoot)
    local toTarget = (targetRoot.Position - casterRoot.Position)
    if toTarget.Magnitude < 0.1 then
        toTarget = Vector3.new(0,0,-1)
    end
    toTarget = toTarget.Unit
    toTarget = Vector3.new(toTarget.X, 0, toTarget.Z).Unit -- Flatten
    
    local bv = Instance.new("BodyVelocity")
    bv.Velocity = (toTarget + Vector3.new(0, 0.4, 0)).Unit * KNOCKBACK_FORCE
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Parent = targetRoot
    
    Debris:AddItem(bv, 0.25)
end

KiwiDisengage.OnServerEvent:Connect(function(player)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local now = os.time()
    if lastUsed[player] and now - lastUsed[player] < COOLDOWN - 0.5 then
        return
    end
    lastUsed[player] = now
    
    -- Play a knockback sound or effect if desired
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://12222076" -- swoosh sound
    sound.Parent = root
    sound:Play()
    Debris:AddItem(sound, 1)

    -- Find enemies
    for _, model in ipairs(workspace:GetChildren()) do
        if model == char then continue end
        local tr = model:FindFirstChild("HumanoidRootPart")
        local th = model:FindFirstChildOfClass("Humanoid")
        
        if tr and th and th.Health > 0 then
            local dist = (tr.Position - root.Position).Magnitude
            if dist <= RADIUS then
                doKnockback(root, tr)
            end
        end
    end
end)

print("KiwiHandler loaded!")
