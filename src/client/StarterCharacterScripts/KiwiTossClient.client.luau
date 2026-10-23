-- KiwiTossClient: lob a kiwi at the point under your crosshair. The server grows
-- it as it flies. Also listens for KiwiSplat - when YOU get hit by an enemy
-- kiwi, your screen gets covered in kiwi slices (bigger kiwi = worse vision,
-- longer duration).

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local char = script.Parent
local camera = workspace.CurrentCamera

local Abilities = RS:WaitForChild("Abilities")
local KiwiToss = Abilities:WaitForChild("KiwiToss")
local KiwiSplat = Abilities:WaitForChild("KiwiSplat")

local ABILITY_ID = "kiwi_toss"
local COOLDOWN = 7
local MAX_AIM_DIST = 200
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
			if id == ABILITY_ID then return SLOT_KEYCODES[s], s end
		end
	end
	return nil, nil
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

	local vp = camera.ViewportSize
	local ray = camera:ViewportPointToRay(vp.X / 2, vp.Y / 2)
	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = {char}
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local result = workspace:Raycast(ray.Origin, ray.Direction * MAX_AIM_DIST, rp)
	local targetPoint = result and result.Position or (ray.Origin + ray.Direction * MAX_AIM_DIST)

	lastUsed = tick()
	KiwiToss:FireServer(targetPoint)
end)

-- =====================
-- SCREEN SPLAT (when an enemy kiwi hits me)
-- =====================
local function makeSlice(parent, size, pos)
	-- outer brown skin ring
	local skin = Instance.new("Frame")
	skin.AnchorPoint = Vector2.new(0.5, 0.5)
	skin.Size = UDim2.new(0, size, 0, size)
	skin.Position = pos
	skin.BackgroundColor3 = Color3.fromRGB(120, 85, 45)
	skin.BorderSizePixel = 0
	skin.Rotation = math.random(0, 360)
	skin.Parent = parent
	Instance.new("UICorner", skin).CornerRadius = UDim.new(1, 0)

	-- green flesh
	local flesh = Instance.new("Frame")
	flesh.AnchorPoint = Vector2.new(0.5, 0.5)
	flesh.Position = UDim2.new(0.5, 0, 0.5, 0)
	flesh.Size = UDim2.new(0.92, 0, 0.92, 0)
	flesh.BackgroundColor3 = Color3.fromRGB(125, 195, 45)
	flesh.BorderSizePixel = 0
	flesh.Parent = skin
	Instance.new("UICorner", flesh).CornerRadius = UDim.new(1, 0)

	-- ring of black seeds
	local seeds = {}
	for i = 1, 12 do
		local a = (i / 12) * math.pi * 2
		local seed = Instance.new("Frame")
		seed.AnchorPoint = Vector2.new(0.5, 0.5)
		seed.Size = UDim2.new(0.05, 0, 0.09, 0)
		seed.Position = UDim2.new(0.5 + math.cos(a) * 0.24, 0, 0.5 + math.sin(a) * 0.24, 0)
		seed.Rotation = math.deg(a) + 90
		seed.BackgroundColor3 = Color3.fromRGB(25, 20, 15)
		seed.BorderSizePixel = 0
		seed.Parent = flesh
		Instance.new("UICorner", seed).CornerRadius = UDim.new(1, 0)
		table.insert(seeds, seed)
	end

	-- pale core
	local core = Instance.new("Frame")
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.new(0.5, 0, 0.5, 0)
	core.Size = UDim2.new(0.3, 0, 0.3, 0)
	core.BackgroundColor3 = Color3.fromRGB(235, 240, 200)
	core.BorderSizePixel = 0
	core.Parent = flesh
	Instance.new("UICorner", core).CornerRadius = UDim.new(1, 0)

	local all = {skin, flesh, core}
	for _, s in ipairs(seeds) do table.insert(all, s) end
	return skin, all
end

KiwiSplat.OnClientEvent:Connect(function(strength)
	strength = math.clamp(tonumber(strength) or 0, 0, 1)
	local duration = 2 + strength * 3            -- 2s .. 5s
	local count = math.floor(4 + strength * 10)  -- 4 .. 14 slices
	local minSize = 120 + strength * 120
	local maxSize = 200 + strength * 220

	local gui = Instance.new("ScreenGui")
	gui.Name = "KiwiSplatGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.Parent = player:WaitForChild("PlayerGui")

	local tint = Instance.new("Frame")
	tint.Size = UDim2.new(1, 0, 1, 0)
	tint.BackgroundColor3 = Color3.fromRGB(110, 170, 40)
	tint.BackgroundTransparency = 0.6 - strength * 0.3
	tint.BorderSizePixel = 0
	tint.Parent = gui

	local vp = camera.ViewportSize
	local slices = {}
	for i = 1, count do
		local size = math.random(math.floor(minSize), math.floor(maxSize))
		-- bias the first few slices toward the middle of the screen
		local spread = (i <= 2) and 0.2 or 0.5
		local pos = UDim2.new(0, vp.X * (0.5 + (math.random() * 2 - 1) * spread), 0, vp.Y * (0.5 + (math.random() * 2 - 1) * spread))
		local slice, parts = makeSlice(gui, size, pos)
		slice.Size = UDim2.new(0, 0, 0, 0)
		TweenService:Create(slice, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{Size = UDim2.new(0, size, 0, size)}):Play()
		table.insert(slices, {frame = slice, parts = parts})
	end

	-- hold, then slide down & fade
	task.delay(duration * 0.55, function()
		local fadeTime = duration * 0.45
		TweenService:Create(tint, TweenInfo.new(fadeTime), {BackgroundTransparency = 1}):Play()
		for _, s in ipairs(slices) do
			TweenService:Create(s.frame, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{Position = s.frame.Position + UDim2.new(0, 0, 0, math.random(40, 120))}):Play()
			for _, p in ipairs(s.parts) do
				TweenService:Create(p, TweenInfo.new(fadeTime), {BackgroundTransparency = 1}):Play()
			end
		end
	end)

	task.delay(duration + 0.1, function()
		gui:Destroy()
	end)
end)
