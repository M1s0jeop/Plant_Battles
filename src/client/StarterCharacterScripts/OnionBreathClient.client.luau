-- OnionBreathClient: cast the breath, and receive stink pings. While standing
-- in an enemy's stink the server keeps pinging us (OnionStink); this shakes the
-- camera, hazes the screen green, blurs vision, and wobbles the FOV. When the
-- pings stop (we left the cloud) the effect smoothly clears.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Abilities = RS:WaitForChild("Abilities")
local OnionBreath = Abilities:WaitForChild("OnionBreath")
local OnionStink = Abilities:WaitForChild("OnionStink")

local ABILITY_ID = "onion_breath"
local COOLDOWN = 12
local lastUsed = -COOLDOWN

-- disruption tuning
local MAX_BLUR  = 16
local SHAKE     = 0.45   -- studs of camera jitter at full strength
local FOV_WOBBLE = 4     -- degrees of woozy FOV sway
local TINT_MAX  = 0.5    -- peak green haze opacity

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
	OnionBreath:FireServer()
end)

-- ===== Camera / vision disruption =====
local stinkUntil = 0
OnionStink.OnClientEvent:Connect(function(ttl)
	if typeof(ttl) ~= "number" then ttl = 1 end
	stinkUntil = math.max(stinkUntil, tick() + ttl)
end)

-- green haze overlay
local gui = Instance.new("ScreenGui")
gui.Name = "OnionStinkGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 40
gui.Parent = player:WaitForChild("PlayerGui")

local haze = Instance.new("Frame")
haze.Size = UDim2.new(1, 0, 1, 0)
haze.BackgroundColor3 = Color3.fromRGB(120, 190, 70)
haze.BackgroundTransparency = 1
haze.BorderSizePixel = 0
haze.Parent = gui

local blur = Instance.new("BlurEffect")
blur.Name = "OnionStinkBlur"
blur.Size = 0
blur.Parent = Lighting

local strength = 0
local woozing = false
local baseFOV = camera.FieldOfView

RunService.RenderStepped:Connect(function(dt)
	local active = tick() < stinkUntil
	local target = active and 1 or 0
	local rate = active and 9 or 3          -- ramp up fast, ease down
	strength = strength + (target - strength) * math.clamp(dt * rate, 0, 1)
	if target == 0 and strength < 0.01 then strength = 0 end

	-- blur
	blur.Size = strength * MAX_BLUR

	-- green haze (pulses a little so it feels alive)
	local pulse = 0.85 + 0.15 * math.sin(tick() * 6)
	haze.BackgroundTransparency = 1 - (strength * TINT_MAX * pulse)

	-- camera shake via humanoid CameraOffset
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		if strength > 0.01 then
			hum.CameraOffset = Vector3.new(
				(math.random() - 0.5) * 2,
				(math.random() - 0.5) * 2,
				(math.random() - 0.5) * 2
			) * SHAKE * strength
		else
			hum.CameraOffset = Vector3.zero
		end
	end

	-- woozy FOV sway
	if strength > 0.01 then
		if not woozing then baseFOV = camera.FieldOfView; woozing = true end
		camera.FieldOfView = baseFOV + math.sin(tick() * 9) * FOV_WOBBLE * strength
	elseif woozing then
		camera.FieldOfView = baseFOV
		woozing = false
	end
end)
