local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local char = script.Parent
local humanoidRoot = char:WaitForChild("HumanoidRootPart")

local Abilities = RS:WaitForChild("Abilities")
local BananaSpawn = Abilities:WaitForChild("BananaSpawn")

local COOLDOWN = 6
local lastUsed = -COOLDOWN

local SLOT_KEYCODES = {
    [1] = Enum.KeyCode.Q,
    [2] = Enum.KeyCode.E,
    [3] = Enum.KeyCode.R,
    [4] = Enum.KeyCode.F
}
local function getMyKey()
    if _G.EquippedAbilities then
        for s, id in pairs(_G.EquippedAbilities) do
            if id == "banana_surf" then return SLOT_KEYCODES[s], s end
        end
    end
    return nil, nil
end

RunService.Heartbeat:Connect(function()
    _G.AbilityCooldowns = _G.AbilityCooldowns or {}
    _G.AbilityCooldowns["banana_surf"] = { lastUsed = lastUsed, cd = COOLDOWN }
end)

UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
        local myKey = getMyKey()
    if myKey and input.KeyCode == myKey then
        if tick() - lastUsed < COOLDOWN then return end
        lastUsed = tick()
        BananaSpawn:FireServer()
    end
end)
