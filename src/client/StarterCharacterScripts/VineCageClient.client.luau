-- VineCageClient: fires the Vine Cage ability when its equipped slot key is pressed.

local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local Abilities = RS:WaitForChild("Abilities")
local VineCage = Abilities:WaitForChild("VineCage")

local COOLDOWN = 8
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
			if id == "vine_cage" then return SLOT_KEYCODES[s], s end
		end
	end
	return nil, nil
end

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	local myKey = getMyKey()
	if not myKey or input.KeyCode ~= myKey then return end
	if tick() - lastUsed < COOLDOWN then return end

	lastUsed = tick()
	_G.AbilityCooldowns = _G.AbilityCooldowns or {}
	_G.AbilityCooldowns["vine_cage"] = { lastUsed = lastUsed, cd = COOLDOWN }
	VineCage:FireServer()
end)
