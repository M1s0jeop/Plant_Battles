-- WalnutHandler: place a walnut wall in front of you (PvZ Garden Warfare style).
-- 2 big nuts on the sides (full body cover) + 2 small nuts in the middle
-- (bottom-half cover you can shoot over). Each nut is its own mini-unit with
-- 300 HP, its own healthbar, and crack stages. Because each nut has a Humanoid
-- and a HumanoidRootPart, ALL existing abilities damage them automatically.

local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Abilities = RS:WaitForChild("Abilities")
local WalnutWall = Abilities:WaitForChild("WalnutWall")

-- Config
local COOLDOWN = 15
local NUT_HEALTH = 300
local WALL_LIFETIME = 30      -- seconds before the wall crumbles on its own
local WALL_DISTANCE = 5       -- studs in front of the caster
local BIG_SIZE = Vector3.new(5, 8.5, 3)
local SMALL_SIZE = Vector3.new(3.2, 4, 2.6)
local HEALTHY = Color3.fromRGB(155, 110, 62)
local CRACKED = Color3.fromRGB(122, 84, 46)
local BROKEN = Color3.fromRGB(92, 60, 32)

local lastUsed = {}
local activeWalls = {} -- [player] = folder

local function spawnChips(pos, count)
	for i = 1, count do
		local chip = Instance.new("Part")
		local s = math.random(20, 50) * 0.01
		chip.Size = Vector3.new(s, s, s)
		chip.Color = CRACKED
		chip.Material = Enum.Material.Wood
		chip.CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * math.pi, math.random() * math.pi, math.random() * math.pi)
		chip.AssemblyLinearVelocity = Vector3.new(math.random(-16, 16), math.random(8, 22), math.random(-16, 16))
		chip.CanCollide = false
		chip.CanQuery = false
		chip.Parent = workspace
		Debris:AddItem(chip, 1)
		TweenService:Create(chip, TweenInfo.new(1), {Transparency = 1}):Play()
	end
end

local function makeHealthbar(nutPart, hum)
	local bb = Instance.new("BillboardGui")
	bb.Name = "NutHealth"
	bb.Size = UDim2.new(0, 80, 0, 14)
	bb.StudsOffsetWorldSpace = Vector3.new(0, nutPart.Size.Y / 2 + 1.2, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 120
	bb.Parent = nutPart

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	bg.BackgroundTransparency = 0.25
	bg.BorderSizePixel = 0
	bg.Parent = bb
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 4)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, -4, 1, -4)
	fill.Position = UDim2.new(0, 2, 0, 2)
	fill.BackgroundColor3 = Color3.fromRGB(80, 200, 60)
	fill.BorderSizePixel = 0
	fill.Parent = bg
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)

	hum.HealthChanged:Connect(function(h)
		local frac = math.clamp(h / NUT_HEALTH, 0, 1)
		fill.Size = UDim2.new(frac, -4, 1, -4)
		fill.BackgroundColor3 = frac > 0.5 and Color3.fromRGB(80, 200, 60)
			or frac > 0.25 and Color3.fromRGB(230, 180, 40)
			or Color3.fromRGB(220, 60, 40)
	end)
end

local function makeNut(position, size, name)
	local model = Instance.new("Model")
	model.Name = name

	local nut = Instance.new("Part")
	nut.Name = "HumanoidRootPart" -- so every ability's generic target check finds it
	nut.Shape = Enum.PartType.Ball
	nut.Size = size
	nut.Color = HEALTHY
	nut.Material = Enum.Material.Wood
	nut.Anchored = true
	nut.CanCollide = true
	nut.Position = position
	nut.Parent = model

	-- vertical seam so it reads as a walnut
	local seam = Instance.new("Part")
	seam.Name = "Seam"
	seam.Size = Vector3.new(0.25, size.Y * 0.92, size.Z * 0.85)
	seam.Color = Color3.fromRGB(105, 70, 38)
	seam.Material = Enum.Material.Wood
	seam.Anchored = true
	seam.CanCollide = false
	seam.CanQuery = false
	seam.Position = position
	seam.Parent = model

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = NUT_HEALTH
	hum.Health = NUT_HEALTH
	hum.RequiresNeck = false
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- custom bar instead
	hum.EvaluateStateMachine = false
	hum.Parent = model

	model.PrimaryPart = nut
	makeHealthbar(nut, hum)

	-- crack stages + crumble
	local stage = 0
	hum.HealthChanged:Connect(function(h)
		local frac = h / NUT_HEALTH
		if h <= 0 then
			if model.Parent then
				spawnChips(nut.Position, 10)
				model:Destroy()
			end
		elseif frac <= 0.33 and stage < 2 then
			stage = 2
			nut.Color = BROKEN
			spawnChips(nut.Position, 5)
		elseif frac <= 0.66 and stage < 1 then
			stage = 1
			nut.Color = CRACKED
			spawnChips(nut.Position, 3)
		end
	end)

	return model
end

local function getGroundY(pos, ignore)
	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = ignore
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local result = workspace:Raycast(pos + Vector3.new(0, 8, 0), Vector3.new(0, -60, 0), rp)
	if result then return result.Position.Y end
	return pos.Y
end

WalnutWall.OnServerEvent:Connect(function(caster)
	local now = tick()
	if lastUsed[caster] and now - lastUsed[caster] < COOLDOWN - 0.1 then return end

	local char = caster.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	lastUsed[caster] = now

	-- replacing your previous wall if it still stands
	if activeWalls[caster] then activeWalls[caster]:Destroy() end

	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.01 then flatLook = Vector3.new(0, 0, -1) end
	flatLook = flatLook.Unit
	local right = Vector3.new(-flatLook.Z, 0, flatLook.X)

	local centerBase = root.Position + flatLook * WALL_DISTANCE

	local folder = Instance.new("Folder")
	folder.Name = "WalnutWall_" .. caster.Name
	folder.Parent = workspace
	activeWalls[caster] = folder

	-- layout: [BIG] [small] [small] [BIG]
	local layout = {
		{offset = -(SMALL_SIZE.X + BIG_SIZE.X) / 2 - 0.2, size = BIG_SIZE, name = "WalnutBig"},
		{offset = -SMALL_SIZE.X / 2 - 0.05, size = SMALL_SIZE, name = "WalnutSmall"},
		{offset = SMALL_SIZE.X / 2 + 0.05, size = SMALL_SIZE, name = "WalnutSmall"},
		{offset = (SMALL_SIZE.X + BIG_SIZE.X) / 2 + 0.2, size = BIG_SIZE, name = "WalnutBig"},
	}
	for _, entry in ipairs(layout) do
		local pos = centerBase + right * entry.offset
		local groundY = getGroundY(pos, {char, folder})
		local nutPos = Vector3.new(pos.X, groundY + entry.size.Y / 2, pos.Z)
		local nut = makeNut(nutPos, entry.size, entry.name)
		nut.Parent = folder
	end

	-- the wall crumbles on its own after a while
	task.delay(WALL_LIFETIME, function()
		if folder.Parent then
			for _, m in ipairs(folder:GetChildren()) do
				local p = m:FindFirstChild("HumanoidRootPart")
				if p then spawnChips(p.Position, 6) end
			end
			folder:Destroy()
		end
		if activeWalls[caster] == folder then activeWalls[caster] = nil end
	end)
end)

game.Players.PlayerRemoving:Connect(function(player)
	if activeWalls[player] then activeWalls[player]:Destroy() end
	activeWalls[player] = nil
	lastUsed[player] = nil
end)

print("WalnutHandler loaded!")
