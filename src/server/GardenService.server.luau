-- GardenService v3:
-- - Players buy Seed Packs of different rarities (Common, Rare, Legendary) at the Gardener's Shop.
-- - Seeds go into their inventory and can be freely planted anywhere in their garden with size-based spacing.
-- - Each plant grows through 3 Stages over playtime, with combat points shaving time off the next stage.
-- - Stage 1, 2, and 3 unlock the 1st, 2nd, and 3rd abilities of that plant tree.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local DSS = game:GetService("DataStoreService")

local Prog = require(RS:WaitForChild("PlantProgression"))
local Remotes = RS:WaitForChild("GardenRemotes")
local PlantSeed = Remotes:WaitForChild("PlantSeed")
local WaterPlant = Remotes:WaitForChild("WaterPlant")
local GardenSync = Remotes:WaitForChild("GardenSync")
local RequestGarden = Remotes:WaitForChild("RequestGarden")
local ClaimGarden = Remotes:WaitForChild("ClaimGarden")
local ToggleDevMode = Remotes:FindFirstChild("ToggleDevMode")
if not ToggleDevMode then
	ToggleDevMode = Instance.new("RemoteEvent")
	ToggleDevMode.Name = "ToggleDevMode"
	ToggleDevMode.Parent = Remotes
end

local store = DSS:GetDataStore("PlantBattles_Garden_v3")
local NUM_GARDENS = 10

local DATA = {}
local DEV_SNAPSHOTS = {} -- [userId] = { nectar = number, seeds = table, plants = table, savedAt = number }
local CLAIMED = {}   -- gardenIndex -> userId
local plantIdCounter = 0

local function deepCopy(orig)
	if type(orig) ~= "table" then return orig end
	local copy = {}
	for k, v in pairs(orig) do
		copy[deepCopy(k)] = deepCopy(v)
	end
	return copy
end

-- garden soil beds + bounds
local GARDEN_BEDS = {}
local function indexBeds()
	local gardens = workspace.Map:FindFirstChild("Gardens")
	if not gardens then return end
	for i = 1, NUM_GARDENS do
		local plot = gardens:FindFirstChild("Garden_" .. i)
		if plot then
			GARDEN_BEDS[i] = plot:FindFirstChild("SoilBed") or plot:FindFirstChild("DirtRim1") or plot:FindFirstChildWhichIsA("BasePart")
		end
	end
end
indexBeds()

local function bedBounds(idx)
	local bed = GARDEN_BEDS[idx]
	if not bed then return nil end
	local margin = 1.8
	return {
		cframe = bed.CFrame,
		halfX = bed.Size.X / 2 - margin,
		halfZ = bed.Size.Z / 2 - margin,
		topY = bed.Position.Y + bed.Size.Y / 2,
		minX = bed.Position.X - bed.Size.X / 2 + margin, maxX = bed.Position.X + bed.Size.X / 2 - margin,
		minZ = bed.Position.Z - bed.Size.Z / 2 + margin, maxZ = bed.Position.Z + bed.Size.Z / 2 - margin,
	}
end

-- Check if a world XZ is anywhere inside the claimed garden bed
local function insideBed(idx, x, z)
	local b = bedBounds(idx)
	if not b then return false end
	local lp = b.cframe:PointToObjectSpace(Vector3.new(x, b.cframe.Position.Y, z))
	if math.abs(lp.X) > b.halfX or math.abs(lp.Z) > b.halfZ then return false end
	return true
end

local function worldToFrac(idx, x, z)
	local b = bedBounds(idx)
	if not b then return 0.5, 0.5 end
	local lp = b.cframe:PointToObjectSpace(Vector3.new(x, b.cframe.Position.Y, z))
	local fx = (lp.X + b.halfX) / math.max(1, (b.halfX * 2))
	local fz = (lp.Z + b.halfZ) / math.max(1, (b.halfZ * 2))
	return math.clamp(fx, 0, 1), math.clamp(fz, 0, 1)
end

local function fracToWorld(idx, fx, fz)
	local b = bedBounds(idx)
	if not b then return 0, 0, 1.5 end
	local localX = (fx or 0.5) * (b.halfX * 2) - b.halfX
	local localZ = (fz or 0.5) * (b.halfZ * 2) - b.halfZ
	local wp = b.cframe:PointToWorldSpace(Vector3.new(localX, 0, localZ))
	return wp.X, wp.Z, b.topY
end

local function defaultData()
	return { seeds = {}, plants = {} }
end

-- ===== unlocked abilities (starter abilities + union across all planted plants' stages) =====
local DEBUG_UNLOCK_ALL = false

local function computeUnlocked(pdata)
	local set = {}
	for _, id in ipairs(Prog.STARTER_ABILITIES or {}) do
		set[id] = true
	end
	if DEBUG_UNLOCK_ALL or pdata.devMode then
		for _, data in pairs(Prog.PLANTS) do
			for _, id in ipairs(data.abilities) do set[id] = true end
		end
		return set
	end
	for _, pl in ipairs(pdata.plants) do
		for _, id in ipairs(Prog.unlockedAbilities(pl.plant, pl.growth or 0)) do
			set[id] = true
		end
	end
	return set
end

local function updateSeedLeaderstat(player, pdata)
	local ls = player:FindFirstChild("leaderstats")
	local seedsVal = ls and ls:FindFirstChild("Seeds")
	if seedsVal and pdata and pdata.seeds then
		local total = 0
		for _, c in pairs(pdata.seeds) do
			total += (c or 0)
		end
		seedsVal.Value = total
	end
end

-- ===== 3-Stage World Plant Visuals =====
local plantModels = {} -- [plantId] = { model = Model, tier = number, timerLbl = TextLabel, titleLbl = TextLabel }

local function formatPlantTimerText(plantName, growth)
	local tier = Prog.tierForGrowth(plantName, growth)
	if tier >= Prog.MAX_TIER then
		return "✨ STAGE 3 (MAX)"
	end
	local rem = Prog.timeRemaining(plantName, growth)
	return "⏳ Next Stage: " .. Prog.formatDuration(rem)
end

local function buildPlantVisual(plant, growth, pos)
	local info = Prog.PLANTS[plant] or {}
	local tier = Prog.tierForGrowth(plant, growth or 0)
	local plantColor = info.color or Color3.fromRGB(120, 200, 120)
	local radius = Prog.getRadius(plant)

	local model = Instance.new("Model")
	model.Name = "GardenPlant_" .. plant

	-- Subtle soil mound base sized to the stage
	local moundDiam = math.min(radius * 1.4, 1.4 + tier * 0.7)
	local mound = Instance.new("Part")
	mound.Name = "Mound"
	mound.Shape = Enum.PartType.Cylinder
	mound.Anchored = true; mound.CanCollide = false; mound.CanQuery = false
	mound.Size = Vector3.new(0.45, moundDiam, moundDiam)
	mound.Color = Color3.fromRGB(92, 62, 38)
	mound.Material = Enum.Material.Ground
	mound.CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	mound.Parent = model

	-- Stem / Trunk (grows taller and thicker each stage)
	local stemH = (tier == 1 and 1.6) or (tier == 2 and 3.1) or 4.8
	local stemW = (tier == 1 and 0.45) or (tier == 2 and 0.75) or 1.15
	local stem = Instance.new("Part")
	stem.Name = "Stem"
	stem.Anchored = true; stem.CanCollide = false; stem.CanQuery = false
	stem.Size = Vector3.new(stemW, stemH, stemW)
	stem.Color = (tier == 3 and Color3.fromRGB(85, 130, 55)) or Color3.fromRGB(70, 155, 60)
	stem.Material = Enum.Material.SmoothPlastic
	stem.CFrame = CFrame.new(pos + Vector3.new(0, stemH / 2, 0))
	stem.Parent = model
	model.PrimaryPart = stem

	if tier == 1 then
		-- STAGE 1: Cute Sprout (2 angled leaves + small bud)
		for side = -1, 1, 2 do
			local leaf = Instance.new("Part")
			leaf.Name = "SproutLeaf"
			leaf.Anchored = true; leaf.CanCollide = false; leaf.CanQuery = false
			leaf.Size = Vector3.new(0.9, 0.25, 0.5)
			leaf.Color = Color3.fromRGB(95, 200, 85)
			leaf.Material = Enum.Material.SmoothPlastic
			leaf.CFrame = CFrame.new(pos + Vector3.new(side * 0.45, stemH * 0.75, 0)) * CFrame.Angles(0, 0, math.rad(side * 25))
			leaf.Parent = model
		end
		local bud = Instance.new("Part")
		bud.Name = "Canopy"
		bud.Shape = Enum.PartType.Ball
		bud.Anchored = true; bud.CanCollide = false; bud.CanQuery = false
		bud.Size = Vector3.new(1.1, 1.1, 1.1)
		bud.Color = plantColor
		bud.Material = Enum.Material.SmoothPlastic
		bud.CFrame = CFrame.new(pos + Vector3.new(0, stemH + 0.35, 0))
		bud.Parent = model
	elseif tier == 2 then
		-- STAGE 2: Medium Bush / Growing Sapling with side leaves & budding fruits
		local canopy = Instance.new("Part")
		canopy.Name = "Canopy"
		canopy.Shape = Enum.PartType.Ball
		canopy.Anchored = true; canopy.CanCollide = false; canopy.CanQuery = false
		canopy.Size = Vector3.new(2.7, 2.4, 2.7)
		canopy.Color = Color3.fromRGB(65, 165, 65)
		canopy.Material = Enum.Material.SmoothPlastic
		canopy.CFrame = CFrame.new(pos + Vector3.new(0, stemH + 0.5, 0))
		canopy.Parent = model

		for i = 1, 2 do
			local ang = math.rad(i * 180 + 35)
			local fruit = Instance.new("Part")
			fruit.Name = "BudFruit"
			fruit.Shape = Enum.PartType.Ball
			fruit.Anchored = true; fruit.CanCollide = false; fruit.CanQuery = false
			fruit.Size = Vector3.new(1.0, 1.0, 1.0)
			fruit.Color = plantColor
			fruit.Material = Enum.Material.SmoothPlastic
			fruit.CFrame = CFrame.new(pos + Vector3.new(math.cos(ang) * 1.1, stemH + 0.7, math.sin(ang) * 1.1))
			fruit.Parent = model
		end
	else
		-- STAGE 3: Full-Grown Lush Plant with layered canopy & glowing fruits/bloom
		local mainCanopy = Instance.new("Part")
		mainCanopy.Name = "Canopy"
		mainCanopy.Shape = Enum.PartType.Ball
		mainCanopy.Anchored = true; mainCanopy.CanCollide = false; mainCanopy.CanQuery = false
		mainCanopy.Size = Vector3.new(4.0, 3.5, 4.0)
		mainCanopy.Color = Color3.fromRGB(55, 155, 55)
		mainCanopy.Material = Enum.Material.SmoothPlastic
		mainCanopy.CFrame = CFrame.new(pos + Vector3.new(0, stemH + 0.8, 0))
		mainCanopy.Parent = model

		for i = 1, 4 do
			local ang = math.rad(i * 90)
			local fruit = Instance.new("Part")
			fruit.Name = "RipeFruit"
			fruit.Shape = Enum.PartType.Ball
			fruit.Anchored = true; fruit.CanCollide = false; fruit.CanQuery = false
			fruit.Size = Vector3.new(1.3, 1.3, 1.3)
			fruit.Color = plantColor
			fruit.Material = Enum.Material.Neon
			fruit.CFrame = CFrame.new(pos + Vector3.new(math.cos(ang) * 1.65, stemH + 0.9, math.sin(ang) * 1.65))
			fruit.Parent = model
		end

		local crown = Instance.new("Part")
		crown.Name = "CrownBloom"
		crown.Shape = Enum.PartType.Ball
		crown.Anchored = true; crown.CanCollide = false; crown.CanQuery = false
		crown.Size = Vector3.new(1.6, 1.6, 1.6)
		crown.Color = plantColor
		crown.Material = Enum.Material.SmoothPlastic
		crown.CFrame = CFrame.new(pos + Vector3.new(0, stemH + 2.5, 0))
		crown.Parent = model
	end

	-- Overhead BillboardGui showing Plant Name, Stage (1..3), and Live Timer
	local topOffset = stemH + (tier == 1 and 1.8 or (tier == 2 and 2.6 or 3.8))
	local bb = Instance.new("BillboardGui")
	bb.Name = "PlantBillboard"
	bb.Size = UDim2.new(0, 150, 0, 44)
	bb.StudsOffset = Vector3.new(0, topOffset, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 55
	bb.Adornee = stem
	bb.Parent = stem

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Name = "TitleLabel"
	titleLbl.Size = UDim2.new(1, 0, 0.55, 0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = (info.icon or "🌱") .. " " .. plant .. " [S" .. tier .. "/3]"
	titleLbl.TextScaled = true
	titleLbl.Font = Enum.Font.GothamBlack
	titleLbl.TextColor3 = plantColor
	titleLbl.TextStrokeTransparency = 0.25
	titleLbl.Parent = bb

	local timerLbl = Instance.new("TextLabel")
	timerLbl.Name = "TimerLabel"
	timerLbl.Size = UDim2.new(1, 0, 0.45, 0)
	timerLbl.Position = UDim2.new(0, 0, 0.55, 0)
	timerLbl.BackgroundTransparency = 1
	timerLbl.Text = formatPlantTimerText(plant, growth or 0)
	timerLbl.TextScaled = true
	timerLbl.Font = Enum.Font.GothamBold
	timerLbl.TextColor3 = (tier >= 3) and Color3.fromRGB(255, 230, 90) or Color3.fromRGB(220, 245, 220)
	timerLbl.TextStrokeTransparency = 0.3
	timerLbl.Parent = bb

	return model, tier, timerLbl, titleLbl
end

local function refreshPlantVisuals(player)
	local pdata = DATA[player.UserId]
	if not pdata or not pdata.garden then return end

	local activeIds = {}
	for _, pl in ipairs(pdata.plants) do
		activeIds[pl.id] = true
		local fx, fz = pl.fx, pl.fz
		if fx == nil and pl.x ~= nil then fx, fz = worldToFrac(pdata.garden, pl.x, pl.z) end
		local wx, wz, topY = fracToWorld(pdata.garden, fx, fz)
		local pos = Vector3.new(wx, topY, wz)
		local newTier = Prog.tierForGrowth(pl.plant, pl.growth or 0)

		local existing = plantModels[pl.id]
		if existing and existing.model and existing.model.Parent and existing.tier == newTier then
			-- Same stage: just update the timer text without destroying/rebuilding the 3D parts
			if existing.timerLbl then
				existing.timerLbl.Text = formatPlantTimerText(pl.plant, pl.growth or 0)
			end
		else
			if existing and existing.model then
				existing.model:Destroy()
			end
			local model, tier, timerLbl, titleLbl = buildPlantVisual(pl.plant, pl.growth or 0, pos)
			model:SetAttribute("Owner", player.UserId)
			model:SetAttribute("PlantId", pl.id)
			model.Parent = workspace
			plantModels[pl.id] = {
				model = model,
				tier = tier,
				timerLbl = timerLbl,
				titleLbl = titleLbl,
				owner = player.UserId,
			}
		end
	end

	-- Clean up any removed plants for this player
	for id, entry in pairs(plantModels) do
		if entry.owner == player.UserId and not activeIds[id] then
			if entry.model then entry.model:Destroy() end
			plantModels[id] = nil
		end
	end
end

local function syncToClient(player)
	local pdata = DATA[player.UserId]
	if not pdata then return end
	updateSeedLeaderstat(player, pdata)
	local claimedStatus = {}
	for i = 1, NUM_GARDENS do claimedStatus[i] = CLAIMED[i] ~= nil end
	GardenSync:FireClient(player, {
		seeds = pdata.seeds,
		plants = pdata.plants,
		garden = pdata.garden,
		bounds = pdata.garden and bedBounds(pdata.garden) or nil,
		unlocked = computeUnlocked(pdata),
		claimedGardens = claimedStatus,
		devMode = pdata.devMode == true,
	})
	refreshPlantVisuals(player)
end

local function broadcastClaims()
	for _, p in ipairs(Players:GetPlayers()) do
		if DATA[p.UserId] then syncToClient(p) end
	end
end

-- ===== DataStore =====
local function loadData(player)
	local key = "u_" .. player.UserId
	local ok, result = pcall(function() return store:GetAsync(key) end)
	local d
	if ok and type(result) == "table" then
		result.seeds = result.seeds or {}
		result.plants = result.plants or {}
		d = result
	else
		d = defaultData()
	end
	DATA[player.UserId] = d
end

local function saveData(player)
	local pdata = DATA[player.UserId]
	if not pdata then return end
	-- If the player is in Dev Mode, persist their real pre-dev snapshot instead of temporary testing items
	local snap = DEV_SNAPSHOTS[player.UserId]
	local toSave = snap and { seeds = snap.seeds, plants = snap.plants } or { seeds = pdata.seeds, plants = pdata.plants }
	pcall(function() store:SetAsync("u_" .. player.UserId, toSave) end)
end

-- ===== Claim a garden =====
local function claimGarden(player, index)
	index = tonumber(index)
	if not index or index < 1 or index > NUM_GARDENS or not GARDEN_BEDS[index] then return false end
	if CLAIMED[index] and CLAIMED[index] ~= player.UserId then return false end
	local pdata = DATA[player.UserId]
	if not pdata then return false end
	if pdata.garden and CLAIMED[pdata.garden] == player.UserId then CLAIMED[pdata.garden] = nil end
	CLAIMED[index] = player.UserId
	pdata.garden = index
	for _, pl in ipairs(pdata.plants) do
		if pl.fx == nil and pl.x ~= nil then
			pl.fx, pl.fz = worldToFrac(index, pl.x, pl.z)
			pl.x, pl.z = nil, nil
		end
	end
	return true
end

-- ===== Grant rolled seed (PackHandler calls this) =====
_G.GrantPlantSeed = function(player, plantName)
	local pdata = DATA[player.UserId]
	if not pdata or not Prog.PLANTS[plantName] then return end
	pdata.seeds[plantName] = (pdata.seeds[plantName] or 0) + 1
	syncToClient(player)
end

-- ===== Plant a seed anywhere in the player's garden with size-based spacing =====
PlantSeed.OnServerEvent:Connect(function(player, plantName, x, z)
	local pdata = DATA[player.UserId]
	if not pdata or not pdata.garden then return end
	if not Prog.PLANTS[plantName] then return end
	if (pdata.seeds[plantName] or 0) <= 0 then return end
	x, z = tonumber(x), tonumber(z)
	if not x or not z then return end
	if not insideBed(pdata.garden, x, z) then return end

	local newRadius = Prog.getRadius(plantName)

	-- Reject if overlapping another plant's size radius
	for _, pl in ipairs(pdata.plants) do
		local ex, ez = fracToWorld(pdata.garden, pl.fx, pl.fz)
		local existingRadius = Prog.getRadius(pl.plant)
		local minDist = newRadius + existingRadius
		local dx, dz = x - ex, z - ez
		if (dx * dx + dz * dz) < (minDist * minDist) then
			return
		end
	end

	if not pdata.devMode then
		pdata.seeds[plantName] = pdata.seeds[plantName] - 1
		if pdata.seeds[plantName] <= 0 then pdata.seeds[plantName] = nil end
	end
	plantIdCounter += 1
	local fx, fz = worldToFrac(pdata.garden, x, z)
	local thresholds = Prog.getThresholds(plantName)
	local initialGrowth = pdata.devMode and ((thresholds and thresholds[Prog.MAX_TIER]) or 999999) or 0
	table.insert(pdata.plants, {
		id = "p" .. plantIdCounter .. "_" .. player.UserId,
		plant = plantName,
		growth = initialGrowth,
		fx = fx,
		fz = fz,
	})
	syncToClient(player)
end)

-- ===== Helper to advance growth on a player's plants and sync if any stage unlocks =====
local function advancePlayerPlants(player, secondsToAdd)
	local pdata = DATA[player.UserId]
	if not pdata or #pdata.plants == 0 then return end

	local stageChanged = false
	for _, pl in ipairs(pdata.plants) do
		local oldTier = Prog.tierForGrowth(pl.plant, pl.growth or 0)
		if oldTier < Prog.MAX_TIER then
			pl.growth = (pl.growth or 0) + secondsToAdd
			local newTier = Prog.tierForGrowth(pl.plant, pl.growth)
			if newTier > oldTier then
				stageChanged = true
			end
		end
	end

	if stageChanged then
		syncToClient(player)
	else
		refreshPlantVisuals(player)
	end
end

-- ===== Combat time-reduction (each damage/kill shaves seconds off growing plants) =====
_G.AddCombatGrowth = function(player, damage, isKill)
	local pdata = DATA[player.UserId]
	if not pdata or #pdata.plants == 0 then return end
	local shavedSeconds = (damage or 0) * (Prog.TIME_REDUCTION_PER_DAMAGE or 0.5)
		+ (isKill and (Prog.TIME_REDUCTION_PER_KILL or 20) or 0)
	if shavedSeconds > 0 then
		advancePlayerPlants(player, shavedSeconds)
	end
end

-- ===== 1-Second Playtime Growth Loop =====
task.spawn(function()
	while true do
		task.wait(1)
		for _, p in ipairs(Players:GetPlayers()) do
			if DATA[p.UserId] then
				advancePlayerPlants(p, 1)
			end
		end
	end
end)

RequestGarden.OnServerEvent:Connect(function(player)
	syncToClient(player)
end)

ClaimGarden.OnServerEvent:Connect(function(player, index)
	if claimGarden(player, index) then
		broadcastClaims()
	end
end)

-- ===== Developer Testing Mode Toggle =====
-- Switches between full Dev Mode (all abilities unlocked, $999,999 Nectar, 10x of every seed, max-stage plants)
-- and Regular Mode (restores exact normal player money, seeds, plants, and stage locks).
ToggleDevMode.OnServerEvent:Connect(function(player)
	local pdata = DATA[player.UserId]
	if not pdata then return end

	local ls = player:FindFirstChild("leaderstats")
	local nectar = ls and ls:FindFirstChild("Nectar")

	if not pdata.devMode then
		-- Snapshot normal player state before entering Dev Mode
		DEV_SNAPSHOTS[player.UserId] = {
			nectar = nectar and nectar.Value or 150,
			seeds = deepCopy(pdata.seeds or {}),
			plants = deepCopy(pdata.plants or {}),
			savedAt = tick(),
		}
		pdata.devMode = true
		player:SetAttribute("DevMode", true)

		if nectar then
			nectar.Value = 999999
		end

		-- Grant 10 of every plant seed in the game
		pdata.seeds = {}
		for plantName, _ in pairs(Prog.PLANTS) do
			pdata.seeds[plantName] = 10
		end

		-- Max out growth on any currently planted plants to Stage 3
		for _, pl in ipairs(pdata.plants) do
			local thresholds = Prog.getThresholds(pl.plant)
			pl.growth = (thresholds and thresholds[Prog.MAX_TIER]) or 999999
		end
	else
		-- Restore normal player state
		local snap = DEV_SNAPSHOTS[player.UserId]
		DEV_SNAPSHOTS[player.UserId] = nil
		pdata.devMode = false
		player:SetAttribute("DevMode", false)

		if snap then
			if nectar then
				nectar.Value = snap.nectar
			end
			pdata.seeds = snap.seeds or {}
			local elapsed = math.max(0, math.floor(tick() - (snap.savedAt or tick())))
			pdata.plants = snap.plants or {}
			for _, pl in ipairs(pdata.plants) do
				pl.growth = (pl.growth or 0) + elapsed
			end
		end
	end

	syncToClient(player)
end)

-- Claim ProximityPrompts on each garden bed
local claimPrompts = {}
do
	for i = 1, NUM_GARDENS do
		local bed = GARDEN_BEDS[i]
		if bed then
			local oldCp = bed:FindFirstChild("ClaimPrompt")
			if oldCp then oldCp:Destroy() end
			local cp = Instance.new("ProximityPrompt")
			cp.Name = "ClaimPrompt"
			cp.ActionText = "Claim this garden"
			cp.ObjectText = "Garden " .. i
			cp.KeyboardKeyCode = Enum.KeyCode.E
			cp.HoldDuration = 0.3
			cp.MaxActivationDistance = 16
			cp.RequiresLineOfSight = false
			cp:SetAttribute("GardenIndex", i)
			cp.Parent = bed
			claimPrompts[i] = cp
		end
	end
end

-- ===== Lifecycle =====
local function setup(player)
	loadData(player)
	task.wait(0.4)
	-- Automatically claim the first available garden on join so the player can plant immediately
	local pdata = DATA[player.UserId]
	if pdata and not pdata.garden then
		for i = 1, NUM_GARDENS do
			if GARDEN_BEDS[i] and not CLAIMED[i] then
				claimGarden(player, i)
				break
			end
		end
	end
	broadcastClaims()
end
Players.PlayerAdded:Connect(setup)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(setup, p) end

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	local pdata = DATA[player.UserId]
	if pdata and pdata.garden and CLAIMED[pdata.garden] == player.UserId then
		CLAIMED[pdata.garden] = nil
	end
	for id, entry in pairs(plantModels) do
		if entry.owner == player.UserId then
			if entry.model then entry.model:Destroy() end
			plantModels[id] = nil
		end
	end
	DATA[player.UserId] = nil
	DEV_SNAPSHOTS[player.UserId] = nil
end)
game:BindToClose(function() for _, p in ipairs(Players:GetPlayers()) do saveData(p) end end)
task.spawn(function() while true do task.wait(120); for _, p in ipairs(Players:GetPlayers()) do saveData(p) end end end)

local ProximityPromptService = game:GetService("ProximityPromptService")
ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if prompt.Name == "ClaimPrompt" then
		local idx = prompt:GetAttribute("GardenIndex")
		if idx and claimGarden(player, idx) then broadcastClaims() end
	end
end)

print("GardenService v3 loaded!")
