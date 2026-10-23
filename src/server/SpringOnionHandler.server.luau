local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Abilities = RS:WaitForChild("Abilities")
local SpringOnionBounce = Abilities:WaitForChild("SpringOnionBounce")

local COOLDOWN = 8
local lastUsed = {}

SpringOnionBounce.OnServerEvent:Connect(function(player)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local now = os.time()
    if lastUsed[player] and now - lastUsed[player] < COOLDOWN - 0.5 then
        return
    end
    lastUsed[player] = now
    
    -- Play a boing/spring sound effect for everyone to hear
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://4487445203" -- a boing sound
    sound.Volume = 1
    sound.Parent = root
    sound:Play()
    Debris:AddItem(sound, 2)
end)

print("SpringOnionHandler loaded!")
