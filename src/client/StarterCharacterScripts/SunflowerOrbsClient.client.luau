-- SunflowerOrbsClient: press the ability key to drop 3 sun orbs around you.
-- One-shot cast; the server owns all orb/heal/speed logic. This just fires it
-- and drives the HUD cooldown for the slot.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local Abilities = RS:WaitForChild("Abilities")
local SunflowerOrbs = Abilities:WaitForChild("SunflowerOrbs")

local ABILITY_ID = "sunflower_orbs"
local COOLDOWN = 10
local lastUsed = -COOLDOWN

local SLOT_KEYCODES = {
	[1] = Enum.KeyCode.Q,
	[2] = Enum.KeyCode.E,
	[3] = Enum.KeyCode.R,
	[4] = Enum.KeyCode.F,
}

local function getMyKey()
	if _G.EquippedAbilities then
		for s, id in pairs(_G.EquippedAbilities) do
			if id == ABILITY_ID then return SLOT_KEYCODES[s] end
		end
	end
	return nil
end

RunService.Heartbeat:Connect(function()
	_G.AbilityCooldowns = _G.AbilityCooldowns or {}
	_G.AbilityCooldowns[ABILITY_ID] = { lastUsed = lastUsed, cd = COOLDOWN }
end)

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	local myKey = getMyKey()
	if not myKey or input.KeyCode ~= myKey then return end
	if tick() - lastUsed < COOLDOWN then return end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end

	lastUsed = tick()
	SunflowerOrbs:FireServer()
end)
