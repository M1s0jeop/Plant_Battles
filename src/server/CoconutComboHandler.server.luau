local comboEvent = game.ReplicatedStorage.Abilities:WaitForChild("CoconutSlamCombo")
local SLAM_DAMAGE = 30
local KNOCKBACK_FORCE = 80

comboEvent.OnServerEvent:Connect(function(caster, comboTarget)
    local casterChar = caster.Character
    if not casterChar then return end
    local casterRoot = casterChar:FindFirstChild("HumanoidRootPart")
    if not casterRoot then return end

    if comboTarget and typeof(comboTarget) == "Instance" and comboTarget:IsA("Model") then
        local targetRoot = comboTarget:FindFirstChild("HumanoidRootPart")
        local targetHuman = comboTarget:FindFirstChildOfClass("Humanoid")
        
        if targetRoot and targetHuman then
            local dist = (targetRoot.Position - casterRoot.Position).Magnitude
    if dist < 150 then -- Zvacseny range kvoli latencii na serveri
                targetHuman:TakeDamage(SLAM_DAMAGE)
                
                -- Knock UP
                local bv = Instance.new("BodyVelocity")
                bv.Velocity = Vector3.new(0, 110, 0)
                bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
                bv.Parent = targetRoot
                game:GetService("Debris"):AddItem(bv, 0.25)
                
                print("CoconutSlam COMBO trafil a nadhodil:", comboTarget.Name)
            else
                print("Combo target was too far:", dist)
            end
        end
    end
end)
print("CoconutComboHandler loaded!")
