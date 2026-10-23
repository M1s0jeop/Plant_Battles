-- BoomerangClient: HOLD the ability key to charge (throws farther), release to throw.
-- While a boomerang is out, the key is locked until it returns.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local char = script.Parent
local camera = workspace.CurrentCamera

local Abilities = RS:WaitForChild("Abilities")
local BoomerangThrow = Abilities:WaitForChild("BoomerangThrow")
local BoomerangReturn = Abilities:WaitForChild("BoomerangReturn")

local MAX_CHARGE_TIME = 1.2   -- seconds to reach full charge/range
local charging = false
local chargeStart = 0
local outThere = false        -- true while a boomerang is flying (key locked)

local SLOT_KEYCODES = {
	[1] = Enum.KeyCode.Q,
	[2] = Enum.KeyCode.E,
	[3] = Enum.KeyCode.R,
	[4] = Enum.KeyCode.F
}
local function getMyKey()
	if _G.EquippedAbilities then
		for s, id in pairs(_G.EquippedAbilities) do
			if id == "banana_boomerang" then return SLOT_KEYCODES[s], s end
		end
	end
	return nil, nil
end

-- HUD cooldown ring shows "charging" fill while held, and "out" while flying
RunService.Heartbeat:Connect(function()
	_G.AbilityCooldowns = _G.AbilityCooldowns or {}
	if outThere then
		-- show as on cooldown (full) until it returns
		_G.AbilityCooldowns["banana_boomerang"] = { lastUsed = tick(), cd = 999 }
	elseif charging then
		local frac = math.clamp((tick() - chargeStart) / MAX_CHARGE_TIME, 0, 1)
		-- repurpose the ring to show charge building up
		_G.AbilityCooldowns["banana_boomerang"] = { lastUsed = tick() - (1 - frac) * 2, cd = 2 }
	else
		_G.AbilityCooldowns["banana_boomerang"] = { lastUsed = 0, cd = 0 }
	end
end)

BoomerangReturn.OnClientEvent:Connect(function()
	outThere = false
end)

local function aimDir()
	local mouse = UIS:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local root = char:FindFirstChild("HumanoidRootPart")
	-- FULL 3D aim: keep the camera ray's vertical pitch so you can throw up/down
	local dir = ray.Direction
	if dir.Magnitude < 0.01 and root then dir = root.CFrame.LookVector end
	return dir.Unit
end

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	local myKey = getMyKey()
	if not myKey or input.KeyCode ~= myKey then return end
	if outThere then return end       -- locked until it comes back
	charging = true
	chargeStart = tick()
end)

UIS.InputEnded:Connect(function(input)
	local myKey = getMyKey()
	if not myKey or input.KeyCode ~= myKey then return end
	if not charging then return end
	charging = false
	if outThere then return end
	local frac = math.clamp((tick() - chargeStart) / MAX_CHARGE_TIME, 0, 1)
	outThere = true
	BoomerangThrow:FireServer(aimDir(), frac)
end)
