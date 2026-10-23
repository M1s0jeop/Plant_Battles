-- TomatoClient: throw a tomato at the point under your crosshair (server lobs
-- it on a slow arc). Also listens for TomatoSplat - when YOU get hit, your
-- screen turns red with tomato splatter.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local char = script.Parent
local camera = workspace.CurrentCamera

local Abilities = RS:WaitForChild("Abilities")
local TomatoThrow = Abilities:WaitForChild("TomatoThrow")
local TomatoSplat = Abilities:WaitForChild("TomatoSplat")

local COOLDOWN = 3
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
			if id == "tomato" then return SLOT_KEYCODES[s], s end
		end
	end
	return nil, nil
end

RunService.Heartbeat:Connect(function()
	_G.AbilityCooldowns = _G.AbilityCooldowns or {}
	_G.AbilityCooldowns["tomato"] = { lastUsed = lastUsed, cd = COOLDOWN }
end)

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	local myKey = getMyKey()
	if not myKey or input.KeyCode ~= myKey then return end
	if tick() - lastUsed < COOLDOWN then return end

	-- aim: world point under the crosshair
	local vp = camera.ViewportSize
	local ray = camera:ViewportPointToRay(vp.X / 2, vp.Y / 2)
	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = {char}
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local result = workspace:Raycast(ray.Origin, ray.Direction * MAX_AIM_DIST, rp)
	local targetPoint = result and result.Position or (ray.Origin + ray.Direction * MAX_AIM_DIST)

	lastUsed = tick()
	TomatoThrow:FireServer(targetPoint)
end)

-- =====================
-- SCREEN SPLAT (when I get hit)
-- =====================
TomatoSplat.OnClientEvent:Connect(function()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TomatoSplatGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.Parent = player:WaitForChild("PlayerGui")

	-- red tint over the whole screen, fades out
	local tint = Instance.new("Frame")
	tint.Size = UDim2.new(1, 0, 1, 0)
	tint.BackgroundColor3 = Color3.fromRGB(190, 20, 15)
	tint.BackgroundTransparency = 0.55
	tint.BorderSizePixel = 0
	tint.Parent = gui
	TweenService:Create(tint, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{BackgroundTransparency = 1}):Play()

	-- tomato blobs that slowly drip down the screen and fade
	local vp = camera.ViewportSize
	for i = 1, 6 do
		local size = math.random(90, 220)
		local blob = Instance.new("Frame")
		blob.Size = UDim2.new(0, size, 0, size)
		blob.Position = UDim2.new(0, math.random(0, math.max(vp.X - size, 1)), 0, math.random(0, math.max(vp.Y - size, 1)))
		blob.BackgroundColor3 = Color3.fromRGB(170, 18, 14)
		blob.BackgroundTransparency = 0.15
		blob.BorderSizePixel = 0
		blob.Parent = gui
		Instance.new("UICorner", blob).CornerRadius = UDim.new(1, 0)

		local drip = math.random(30, 90)
		TweenService:Create(blob, TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = blob.Position + UDim2.new(0, 0, 0, drip),
			BackgroundTransparency = 1,
		}):Play()
	end

	task.delay(2.6, function()
		gui:Destroy()
	end)
end)
