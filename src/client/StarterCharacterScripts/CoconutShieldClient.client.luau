-- CoconutShieldClient: wrap yourself in a one-hit-blocking coconut shell.

local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Abilities = RS:WaitForChild("Abilities")
local CoconutShield = Abilities:WaitForChild("CoconutShield")

local COOLDOWN = 10
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
			if id == "coconut_shield" then return SLOT_KEYCODES[s], s end
		end
	end
	return nil, nil
end

RunService.Heartbeat:Connect(function()
	_G.AbilityCooldowns = _G.AbilityCooldowns or {}
	_G.AbilityCooldowns["coconut_shield"] = { lastUsed = lastUsed, cd = COOLDOWN }
end)

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	local myKey = getMyKey()
	if not myKey or input.KeyCode ~= myKey then return end
	if tick() - lastUsed < COOLDOWN then return end

	lastUsed = tick()
	CoconutShield:FireServer()
end)
