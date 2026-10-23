local CoconutSlam = game.ReplicatedStorage.Abilities:WaitForChild("CoconutSlam")
local SLAM_RANGE = 12
local SLAM_DAMAGE = 30
local KNOCKBACK_FORCE = 25

local function doSlam(casterRoot, targetRoot, targetHuman)
    targetHuman:TakeDamage(SLAM_DAMAGE)
    local toTarget = (targetRoot.Position - casterRoot.Position).Unit
    -- Malý knockback, viac do strany ako hore
    local bv = Instance.new("BodyVelocity")
    bv.Velocity = (toTarget + Vector3.new(0, 0.2, 0)).Unit * KNOCKBACK_FORCE
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Parent = targetRoot
    game:GetService("Debris"):AddItem(bv, 0.18)
    print("CoconutSlam trafil:", targetRoot.Parent and targetRoot.Parent.Name or "?")
end

CoconutSlam.OnServerEvent:Connect(function(caster, targetModel)
    local casterChar = caster.Character
    if not casterChar then return end
    local casterRoot = casterChar:FindFirstChild("HumanoidRootPart")
    if not casterRoot then return end

    if targetModel then
        local targetRoot = targetModel:FindFirstChild("HumanoidRootPart")
        local targetHuman = targetModel:FindFirstChildOfClass("Humanoid")
        if not targetRoot or not targetHuman then return end
        local waited = 0
        while waited < 0.6 do
            if (targetRoot.Position - casterRoot.Position).Magnitude <= 12 then break end
            task.wait(0.05); waited = waited + 0.05
        end
        doSlam(casterRoot, targetRoot, targetHuman)
    else
        for _, model in ipairs(workspace:GetChildren()) do
            if model == casterChar then continue end
            local tr = model:FindFirstChild("HumanoidRootPart")
            local th = model:FindFirstChildOfClass("Humanoid")
            if not tr or not th then continue end
            local dist = (tr.Position - casterRoot.Position).Magnitude
            if dist > SLAM_RANGE then continue end
            local dot = casterRoot.CFrame.LookVector:Dot((tr.Position - casterRoot.Position).Unit)
            if dot < 0.1 then continue end
            doSlam(casterRoot, tr, th)
        end
    end
end)
print("CoconutHandler loaded!")
