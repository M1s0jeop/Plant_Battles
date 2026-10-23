-- KiwiOrbitClient: summons 3 simple orbiting kiwis that rotate around you
-- and block incoming projectiles, popping and healing you for +20 HP each.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local char = script.Parent

local Abilities = RS:WaitForChild("Abilities")
local SummonKiwiOrbit = Abilities:WaitForChild("SummonKiwiOrbit")
local KiwiPopHeal = Abilities:WaitForChild("KiwiPopHeal")

local ABILITY_ID = "kiwi_orbit"
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
			if id == ABILITY_ID then return SLOT_KEYCODES[s], s end
		end
	end
	return nil, nil
end

RunService.Heartbeat:Connect(function()
	_G.AbilityCooldowns = _G.AbilityCooldowns or {}
	_G.AbilityCooldowns[ABILITY_ID] = { lastUsed = lastUsed, cd = COOLDOWN }
end)

-- Activation input
UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	local myKey = getMyKey()
	if not myKey or input.KeyCode ~= myKey then return end
	if tick() - lastUsed < COOLDOWN then return end

	lastUsed = tick()

	-- Cast swirl animation & sound
	local root = char:FindFirstChild("HumanoidRootPart")
	if root then
		local castRing = Instance.new("Part")
		castRing.Shape = Enum.PartType.Cylinder
		castRing.Size = Vector3.new(0.1, 1, 1)
		castRing.Color = Color3.fromRGB(130, 215, 60)
		castRing.Material = Enum.Material.Neon
		castRing.Transparency = 0.2
		castRing.Anchored = true
		castRing.CanCollide = false
		castRing.CanQuery = false
		castRing.CFrame = root.CFrame * CFrame.Angles(0, 0, math.rad(90))
		castRing.Parent = workspace

		TweenService:Create(castRing, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.1, 10, 10),
			Transparency = 1,
		}):Play()
		Debris:AddItem(castRing, 0.45)
	end

	SummonKiwiOrbit:FireServer()
end)

-- Healing edge vignette flash when an orbiting kiwi pops & blocks a projectile
KiwiPopHeal.OnClientEvent:Connect(function(amount)
	local gui = player:FindFirstChild("PlayerGui")
	if not gui then return end

	local healGui = Instance.new("ScreenGui")
	healGui.Name = "KiwiHealFlash"
	healGui.IgnoreGuiInset = true
	healGui.ResetOnSpawn = false
	healGui.DisplayOrder = 95
	healGui.Parent = gui

	local flash = Instance.new("Frame")
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = Color3.fromRGB(110, 255, 120)
	flash.BackgroundTransparency = 0.8
	flash.BorderSizePixel = 0
	flash.Parent = healGui

	local stroke = Instance.new("UIStroke", flash)
	stroke.Color = Color3.fromRGB(120, 255, 130)
	stroke.Thickness = 6
	stroke.Transparency = 0.3

	TweenService:Create(flash, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(stroke, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
	}):Play()

	task.delay(0.55, function()
		healGui:Destroy()
	end)
end)

print("KiwiOrbitClient loaded!")
