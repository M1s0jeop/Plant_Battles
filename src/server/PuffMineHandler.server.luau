-- PuffMineHandler: place a mushroom mine that slowly swells over time,
-- expanding its trigger and effective blast radius.
-- Pops when:
--   1) An enemy steps near it / touches it.
--   2) ANY damage is dealt to it (by caster, allies, projectiles, or enemies).
-- On pop:
--   * Blasts enemies in its wide effective radius (dealing damage, marking them
--     with a red outline visible through invisibility for 3s, and distorting their screen).
--   * Creates a spore mist cloud that drifts in a random wind direction over 4 seconds,
--     affecting any players who walk through it.

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Abilities = RS:WaitForChild("Abilities")
local PlacePuffMine = Abilities:FindFirstChild("PlacePuffMine")
if not PlacePuffMine then
	PlacePuffMine = Instance.new("RemoteEvent")
	PlacePuffMine.Name = "PlacePuffMine"
	PlacePuffMine.Parent = Abilities
end

local PuffMineDistort = Abilities:FindFirstChild("PuffMineDistort")
if not PuffMineDistort then
	PuffMineDistort = Instance.new("RemoteEvent")
	PuffMineDistort.Name = "PuffMineDistort"
	PuffMineDistort.Parent = Abilities
end

-- Configuration
local MAX_CHARGES = 3
local RECHARGE_TIME = 10
local MAX_AIM_DIST = 120
local MAX_MINES_PER_PLAYER = 6

local BASE_TRIGGER_RADIUS = 4.5
local MAX_TRIGGER_RADIUS = 8.5
local BASE_BLAST_RADIUS = 16
local MAX_BLAST_RADIUS = 28
local GROW_DURATION = 12       -- seconds to reach full swelling / max radius

local POP_DAMAGE = 18
local MIST_TICK_DAMAGE = 3
local MARK_DURATION = 3        -- red outline duration
local DISTORT_DURATION = 4.5   -- screen distortion duration
local MIST_TRAVEL_TIME = 4     -- seconds the mist drifts in the wind

local CAP_PURPLE = Color3.fromRGB(155, 60, 215)
local CAP_SPOTS = Color3.fromRGB(110, 255, 120)
local STALK_COLOR = Color3.fromRGB(235, 230, 215)

local playerCharges = {} -- [player] = { charges = 3, lastUsed = tick() }
local playerMines = {}   -- [player] = { [mineModel] = true }

local function isAlly(a, b)
	if not a or not b or a == b then return false end
	if a.Neutral or b.Neutral then return false end
	return a.Team ~= nil and a.Team == b.Team
end

-- =====================
-- RED OUTLINE MARKER
-- =====================
local function applyRedOutline(character)
	if not character then return end
	local old = character:FindFirstChild("PuffMineMark")
	if old then old:Destroy() end

	local highlight = Instance.new("Highlight")
	highlight.Name = "PuffMineMark"
	highlight.FillColor = Color3.fromRGB(255, 30, 30)
	highlight.FillTransparency = 0.55
	highlight.OutlineColor = Color3.fromRGB(255, 20, 20)
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- Always visible even through walls & invisibility!
	highlight.Adornee = character
	highlight.Parent = character
	Debris:AddItem(highlight, MARK_DURATION)
end

-- =====================
-- POP & DRIFTING MIST
-- =====================
local function applyEffectToVictim(caster, victimModel)
	local hum = victimModel:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end

	hum:TakeDamage(POP_DAMAGE)
	applyRedOutline(victimModel)

	local victimPlayer = Players:GetPlayerFromCharacter(victimModel)
	if victimPlayer and victimPlayer ~= caster then
		PuffMineDistort:FireClient(victimPlayer, DISTORT_DURATION)
	end
end

local function spawnDriftingMist(caster, startPos, radius)
	local angle = math.random() * math.pi * 2
	local driftDist = math.random(22, 34)
	local endPos = startPos + Vector3.new(math.cos(angle) * driftDist, 1.5, math.sin(angle) * driftDist)

	local mistPart = Instance.new("Part")
	mistPart.Name = "PuffMineDriftingMist"
	mistPart.Size = Vector3.new(radius * 0.7, 4, radius * 0.7)
	mistPart.Position = startPos + Vector3.new(0, 2, 0)
	mistPart.Transparency = 1
	mistPart.Anchored = true
	mistPart.CanCollide = false
	mistPart.CanQuery = false
	mistPart.Parent = workspace

	-- Purple smoke
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(CAP_PURPLE, Color3.fromRGB(110, 45, 160))
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 5),
		NumberSequenceKeypoint.new(0.6, 12),
		NumberSequenceKeypoint.new(1, 16),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(0.7, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Lifetime = NumberRange.new(1.8, 2.6)
	smoke.Rate = 18
	smoke.Speed = NumberRange.new(1, 3)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Parent = mistPart

	-- Glowing neon green spores
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(CAP_SPOTS)
	sparkles.Size = NumberSequence.new(0.5, 1.2)
	sparkles.Transparency = NumberSequence.new(0.1, 1)
	sparkles.Lifetime = NumberRange.new(1.2, 2.0)
	sparkles.Rate = 14
	sparkles.Speed = NumberRange.new(2, 5)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Parent = mistPart

	-- Move mist across wind direction over MIST_TRAVEL_TIME
	local tw = TweenService:Create(mistPart, TweenInfo.new(MIST_TRAVEL_TIME, Enum.EasingStyle.Linear), {
		Position = endPos,
	})
	tw:Play()

	local affectedRecently = {} -- [humanoid] = lastHitTime
	local mistConn
	mistConn = RunService.Heartbeat:Connect(function()
		if not mistPart.Parent then
			if mistConn then mistConn:Disconnect() end
			return
		end
		local now = tick()
		local pRadius = mistPart.Size.X / 2 + 3
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		overlap.FilterDescendantsInstances = {caster.Character, mistPart}

		for _, part in ipairs(workspace:GetPartBoundsInRadius(mistPart.Position, pRadius, overlap)) do
			local model = part:FindFirstAncestorOfClass("Model")
			local hum = model and model:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and (now - (affectedRecently[hum] or 0)) >= 1.0 then
				local p = Players:GetPlayerFromCharacter(model)
				if p and (p == caster or isAlly(caster, p)) then
					-- friendly
				else
					affectedRecently[hum] = now
					hum:TakeDamage(MIST_TICK_DAMAGE)
					applyRedOutline(model)
					if p then PuffMineDistort:FireClient(p, DISTORT_DURATION) end
				end
			end
		end
	end)

	task.delay(MIST_TRAVEL_TIME, function()
		smoke.Enabled = false
		sparkles.Enabled = false
		if mistConn then mistConn:Disconnect() end
		Debris:AddItem(mistPart, 2.5)
	end)
end

local function popMine(caster, mineModel, growthProgress)
	if not mineModel.Parent then return end

	local primary = mineModel.PrimaryPart or mineModel:FindFirstChildWhichIsA("BasePart")
	if not primary then
		mineModel:Destroy()
		return
	end

	local popPos = primary.Position
	local blastRadius = BASE_BLAST_RADIUS + (MAX_BLAST_RADIUS - BASE_BLAST_RADIUS) * growthProgress

	-- Sound
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://9114223170" -- squishy heavy pop sound
	sound.Volume = 1.4
	sound.Parent = primary
	sound:Play()

	-- Shockwave ring
	local blast = Instance.new("Part")
	blast.Shape = Enum.PartType.Ball
	blast.Size = Vector3.new(2, 2, 2)
	blast.Color = CAP_PURPLE
	blast.Material = Enum.Material.Neon
	blast.Transparency = 0.3
	blast.Anchored = true
	blast.CanCollide = false
	blast.CanQuery = false
	blast.CFrame = CFrame.new(popPos)
	blast.Parent = workspace
	TweenService:Create(blast, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(blastRadius * 2, blastRadius * 2, blastRadius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(blast, 0.45)

	-- Spore chunks flying
	for i = 1, 14 do
		local chunk = Instance.new("Part")
		local s = math.random(25, 60) * 0.01
		chunk.Size = Vector3.new(s, s, s)
		chunk.Shape = Enum.PartType.Ball
		chunk.Color = (i % 2 == 0) and CAP_PURPLE or CAP_SPOTS
		chunk.Material = Enum.Material.Neon
		chunk.CFrame = CFrame.new(popPos) * CFrame.Angles(math.random() * math.pi, math.random() * math.pi, math.random() * math.pi)
		chunk.AssemblyLinearVelocity = Vector3.new(math.random(-30, 30), math.random(12, 35), math.random(-30, 30))
		chunk.CanCollide = false
		chunk.CanQuery = false
		chunk.Parent = workspace
		Debris:AddItem(chunk, 1.2)
		TweenService:Create(chunk, TweenInfo.new(1.2), {Transparency = 1}):Play()
	end

	-- Affect enemies in blast radius
	local hitVictims = {}
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = {caster.Character, mineModel}

	for _, part in ipairs(workspace:GetPartBoundsInRadius(popPos, blastRadius, overlap)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local hum = model and model:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and not hitVictims[model] then
			hitVictims[model] = true
			local p = Players:GetPlayerFromCharacter(model)
			if p and (p == caster or isAlly(caster, p)) then
				-- ally or caster
			else
				applyEffectToVictim(caster, model)
			end
		end
	end

	-- Spawn traveling wind mist
	spawnDriftingMist(caster, popPos, blastRadius)

	mineModel:Destroy()
end

-- =====================
-- BUILD MINE INSTANCE
-- =====================
local function createMine(caster, spawnPos)
	local mine = Instance.new("Model")
	mine.Name = "PuffMine_" .. caster.Name

	-- Stalk
	local stalk = Instance.new("Part")
	stalk.Name = "Stalk"
	stalk.Shape = Enum.PartType.Cylinder
	stalk.Size = Vector3.new(1.4, 0.8, 0.8)
	stalk.Color = STALK_COLOR
	stalk.Material = Enum.Material.SmoothPlastic
	stalk.Anchored = true
	stalk.CanCollide = false
	stalk.CFrame = CFrame.new(spawnPos + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.rad(90))
	stalk.Parent = mine
	mine.PrimaryPart = stalk

	-- Cap
	local cap = Instance.new("Part")
	cap.Name = "Cap"
	cap.Shape = Enum.PartType.Ball
	cap.Size = Vector3.new(2.2, 1.6, 2.2)
	cap.Color = CAP_PURPLE
	cap.Material = Enum.Material.SmoothPlastic
	cap.Anchored = true
	cap.CanCollide = false
	cap.CFrame = CFrame.new(spawnPos + Vector3.new(0, 1.6, 0))
	cap.Parent = mine

	-- Neon spots
	for i = 1, 4 do
		local a = (i / 4) * math.pi * 2
		local spot = Instance.new("Part")
		spot.Name = "Spot"
		spot.Shape = Enum.PartType.Ball
		spot.Size = Vector3.new(0.45, 0.45, 0.45)
		spot.Color = CAP_SPOTS
		spot.Material = Enum.Material.Neon
		spot.Anchored = true
		spot.CanCollide = false
		spot.CFrame = cap.CFrame * CFrame.new(math.cos(a) * 0.8, 0.4, math.sin(a) * 0.8)
		spot.Parent = mine
	end

	-- Subtle pulsing aura
	local aura = Instance.new("ParticleEmitter")
	aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	aura.Color = ColorSequence.new(CAP_SPOTS)
	aura.Size = NumberSequence.new(0.3, 0.6)
	aura.Transparency = NumberSequence.new(0.2, 1)
	aura.Lifetime = NumberRange.new(0.8, 1.4)
	aura.Rate = 5
	aura.Speed = NumberRange.new(0.5, 1.5)
	aura.Parent = cap

	-- Humanoid so ANY damage dealt to it (by weapons, projectiles, abilities) registers!
	local mineHum = Instance.new("Humanoid")
	mineHum.MaxHealth = 20
	mineHum.Health = 20
	mineHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	mineHum.BreakJointsOnDeath = false
	mineHum.Parent = mine

	mine.Parent = workspace

	-- Growth & Proximity Loop
	task.spawn(function()
		local spawnTime = tick()
		local popped = false

		-- If damaged by ANY weapon or attack, pop immediately
		local healthConn
		healthConn = mineHum.HealthChanged:Connect(function(newHealth)
			if newHealth < 20 and not popped then
				popped = true
				if healthConn then healthConn:Disconnect() end
				local growthProgress = math.clamp((tick() - spawnTime) / GROW_DURATION, 0, 1)
				popMine(caster, mine, growthProgress)
			end
		end)

		while mine.Parent and not popped do
			local dt = RunService.Heartbeat:Wait()
			local elapsed = tick() - spawnTime
			local growthProgress = math.clamp(elapsed / GROW_DURATION, 0, 1)

			-- Visual swelling growth
			local currentScale = 1.0 + growthProgress * 1.5
			local breathe = 1.0 + math.sin(elapsed * 4) * 0.05
			cap.Size = Vector3.new(2.2 * currentScale * breathe, 1.6 * currentScale, 2.2 * currentScale * breathe)
			stalk.Size = Vector3.new(1.4 * currentScale, 0.8 * currentScale, 0.8 * currentScale)
			stalk.CFrame = CFrame.new(spawnPos + Vector3.new(0, 0.7 * currentScale, 0)) * CFrame.Angles(0, 0, math.rad(90))
			cap.CFrame = CFrame.new(spawnPos + Vector3.new(0, 1.6 * currentScale, 0))

			-- Check trigger radius for enemies stepping on or near it
			local currentTriggerRadius = BASE_TRIGGER_RADIUS + (MAX_TRIGGER_RADIUS - BASE_TRIGGER_RADIUS) * growthProgress
			local overlap = OverlapParams.new()
			overlap.FilterType = Enum.RaycastFilterType.Exclude
			overlap.FilterDescendantsInstances = {caster.Character, mine}

			for _, part in ipairs(workspace:GetPartBoundsInRadius(spawnPos, currentTriggerRadius, overlap)) do
				local model = part:FindFirstAncestorOfClass("Model")
				local hum = model and model:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					local p = Players:GetPlayerFromCharacter(model)
					if not (p and (p == caster or isAlly(caster, p))) then
						popped = true
						if healthConn then healthConn:Disconnect() end
						popMine(caster, mine, growthProgress)
						break
					end
				end
			end
		end

		if healthConn then healthConn:Disconnect() end
	end)

	return mine
end

-- =====================
-- CHARGE & CAST LOGIC
-- =====================
local function getPlayerData(player)
	local pdata = playerCharges[player]
	if not pdata then
		pdata = { charges = MAX_CHARGES, lastRegen = tick() }
		playerCharges[player] = pdata
	end

	-- Passive charge regeneration: 1 charge every 10 seconds up to 3
	local now = tick()
	while pdata.charges < MAX_CHARGES and now - pdata.lastRegen >= RECHARGE_TIME do
		pdata.charges = pdata.charges + 1
		pdata.lastRegen = pdata.lastRegen + RECHARGE_TIME
	end
	if pdata.charges == MAX_CHARGES then
		pdata.lastRegen = now
	end

	return pdata
end

PlacePuffMine.OnServerEvent:Connect(function(player, targetPoint)
	if typeof(targetPoint) ~= "Vector3" then return end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if (targetPoint - root.Position).Magnitude > MAX_AIM_DIST then return end

	local pdata = getPlayerData(player)
	if pdata.charges <= 0 then return end

	-- Raycast down to find ground
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = {char}
	local hit = workspace:Raycast(targetPoint + Vector3.new(0, 5, 0), Vector3.new(0, -30, 0), rp)
	local groundPos = hit and hit.Position or targetPoint

	-- Consume 1 charge
	if pdata.charges == MAX_CHARGES then
		pdata.lastRegen = tick()
	end
	pdata.charges = pdata.charges - 1

	-- Maintain active mine limit
	playerMines[player] = playerMines[player] or {}
	local activeCount = 0
	for m, _ in pairs(playerMines[player]) do
		if m and m.Parent then
			activeCount = activeCount + 1
		else
			playerMines[player][m] = nil
		end
	end
	if activeCount >= MAX_MINES_PER_PLAYER then
		-- Pop oldest
		for m, _ in pairs(playerMines[player]) do
			if m and m.Parent then
				popMine(player, m, 1.0)
				playerMines[player][m] = nil
				break
			end
		end
	end

	local mine = createMine(player, groundPos)
	playerMines[player][mine] = true
end)

Players.PlayerRemoving:Connect(function(p)
	playerCharges[p] = nil
	if playerMines[p] then
		for m, _ in pairs(playerMines[p]) do
			if m and m.Parent then m:Destroy() end
		end
		playerMines[p] = nil
	end
end)

print("PuffMineHandler loaded!")
