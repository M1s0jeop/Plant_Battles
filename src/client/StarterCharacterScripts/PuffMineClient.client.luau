-- PuffMineClient: place a mushroom mine at your crosshair.
-- Stacks up to 3 charges, regenerating 1 charge every 10 seconds.
-- Also listens for PuffMineDistort: when YOU get hit by a puff mine explosion or mist,
-- triggers a playable trippy/dizzy psychedelic screen distortion and camera sway.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local char = script.Parent
local camera = workspace.CurrentCamera

local Abilities = RS:WaitForChild("Abilities")
local PlacePuffMine = Abilities:WaitForChild("PlacePuffMine")
local PuffMineDistort = Abilities:WaitForChild("PuffMineDistort")

local ABILITY_ID = "puff_mine"
local MAX_CHARGES = 3
local RECHARGE_TIME = 10
local MAX_AIM_DIST = 120

local charges = MAX_CHARGES
local lastRegen = tick()
local lastCastTime = 0

local SLOT_KEYCODES = {
	[1] = Enum.KeyCode.Q,
	[2] = Enum.KeyCode.E,
	[3] = Enum.KeyCode.R,
	[4] = Enum.KeyCode.F,
}

local function getMyKey()
	if _G.EquippedAbilities then
		for s, id in pairs(_G.EquippedAbilities) do
			if id == ABILITY_ID then return SLOT_KEYCODES[s], s end
		end
	end
	return nil, nil
end

-- =====================
-- CHARGE RECHARGE LOOP
-- =====================
RunService.Heartbeat:Connect(function()
	local now = tick()
	while charges < MAX_CHARGES and now - lastRegen >= RECHARGE_TIME do
		charges = charges + 1
		lastRegen = lastRegen + RECHARGE_TIME
	end
	if charges == MAX_CHARGES then
		lastRegen = now
	end

	_G.AbilityCooldowns = _G.AbilityCooldowns or {}
	if charges > 0 then
		-- Available to cast
		_G.AbilityCooldowns[ABILITY_ID] = { lastUsed = -RECHARGE_TIME, cd = RECHARGE_TIME, charges = charges }
	else
		-- On cooldown until next charge
		_G.AbilityCooldowns[ABILITY_ID] = { lastUsed = lastRegen, cd = RECHARGE_TIME, charges = 0 }
	end
end)

-- =====================
-- CASTING INPUT
-- =====================
UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	local myKey = getMyKey()
	if not myKey or input.KeyCode ~= myKey then return end

	-- Recharge check
	local now = tick()
	while charges < MAX_CHARGES and now - lastRegen >= RECHARGE_TIME do
		charges = charges + 1
		lastRegen = lastRegen + RECHARGE_TIME
	end

	if charges <= 0 then return end
	if now - lastCastTime < 0.4 then return end -- small spam buffer
	lastCastTime = now

	-- Aim at world position under crosshair
	local vp = camera.ViewportSize
	local ray = camera:ViewportPointToRay(vp.X / 2, vp.Y / 2)
	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = {char}
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local result = workspace:Raycast(ray.Origin, ray.Direction * MAX_AIM_DIST, rp)
	local targetPoint = result and result.Position or (ray.Origin + ray.Direction * MAX_AIM_DIST)

	if charges == MAX_CHARGES then
		lastRegen = now
	end
	charges = charges - 1

	PlacePuffMine:FireServer(targetPoint)
end)

-- ==========================================
-- DIZZY / TRIPPY SCREEN DISTORTION EFFECT
-- ==========================================
local activeDizzyCount = 0

PuffMineDistort.OnClientEvent:Connect(function(duration)
	duration = tonumber(duration) or 4.5
	activeDizzyCount = activeDizzyCount + 1

	-- Visual GUI: psychedelic color tint & pulsating wavy vignette
	local gui = Instance.new("ScreenGui")
	gui.Name = "PuffDizzyScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 105
	gui.Parent = player:WaitForChild("PlayerGui")

	local tint = Instance.new("Frame")
	tint.Size = UDim2.new(1, 0, 1, 0)
	tint.BackgroundColor3 = Color3.fromRGB(175, 75, 230)
	tint.BackgroundTransparency = 0.75
	tint.BorderSizePixel = 0
	tint.Parent = gui

	-- Vignette border ring
	local vig = Instance.new("Frame")
	vig.Size = UDim2.new(1, 0, 1, 0)
	vig.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	vig.BackgroundTransparency = 0.8
	vig.BorderSizePixel = 0
	vig.Parent = gui

	-- Floating psychedelic spore rings
	local rings = {}
	local vp = camera.ViewportSize
	for i = 1, 7 do
		local r = Instance.new("Frame")
		local s = math.random(110, 240)
		r.Size = UDim2.new(0, s, 0, s)
		r.Position = UDim2.new(0, math.random(50, math.max(vp.X - s, 60)), 0, math.random(50, math.max(vp.Y - s, 60)))
		r.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(130, 255, 120) or Color3.fromRGB(225, 90, 255)
		r.BackgroundTransparency = 0.82
		r.BorderSizePixel = 0
		r.Parent = gui
		Instance.new("UICorner", r).CornerRadius = UDim.new(1, 0)
		local st = Instance.new("UIStroke", r)
		st.Color = (i % 2 == 0) and Color3.fromRGB(150, 255, 140) or Color3.fromRGB(255, 120, 255)
		st.Thickness = 2.5
		st.Transparency = 0.5
		table.insert(rings, r)
	end

	-- Color correction & gentle blur
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "PuffMineCC"
	cc.Saturation = 0.75
	cc.Contrast = 0.2
	cc.TintColor = Color3.fromRGB(240, 195, 255)
	cc.Parent = Lighting

	local blur = Instance.new("BlurEffect")
	blur.Name = "PuffMineBlur"
	blur.Size = 4
	blur.Parent = Lighting

	local startTime = tick()
	local baseFov = camera.FieldOfView
	local renderConn

	renderConn = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - startTime
		if elapsed >= duration or not gui.Parent then
			if renderConn then renderConn:Disconnect() end
			return
		end

		-- Psychedelic color cycling on tint
		local hue = (elapsed * 0.4) % 1
		tint.BackgroundColor3 = Color3.fromHSV(hue, 0.7, 0.9)

		-- Trippy dizzy camera sway and FOV breathing
		local swayAngle = math.sin(elapsed * 3.2) * 2.8
		local swayX = math.sin(elapsed * 2.5) * 0.35
		local swayY = math.cos(elapsed * 2.8) * 0.25
		camera.CFrame = camera.CFrame * CFrame.Angles(0, 0, math.rad(swayAngle)) * CFrame.new(swayX, swayY, 0)
		camera.FieldOfView = math.clamp(baseFov + math.sin(elapsed * 3.6) * 5.5, 60, 95)
	end)

	-- Fade out near the end
	task.delay(duration - 1.0, function()
		TweenService:Create(tint, TweenInfo.new(1.0), {BackgroundTransparency = 1}):Play()
		TweenService:Create(cc, TweenInfo.new(1.0), {Saturation = 0, Contrast = 0, TintColor = Color3.fromRGB(255, 255, 255)}):Play()
		TweenService:Create(blur, TweenInfo.new(1.0), {Size = 0}):Play()
	end)

	task.delay(duration, function()
		if renderConn then renderConn:Disconnect() end
		camera.FieldOfView = baseFov
		gui:Destroy()
		cc:Destroy()
		blur:Destroy()
	end)
end)

print("PuffMineClient loaded!")
