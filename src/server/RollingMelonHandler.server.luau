-- RollingMelonHandler: player turns into a giant rolling watermelon.
-- Gaining speed over time, steering gets harder the faster it goes.
-- On hitting someone:
--   * Splashes red melon chunks & seeds everywhere.
--   * Bounces the victim high into the air based on impact speed.
--   * Deals heavy speed-scaling damage.
--   * Caster is bounced up and back with a CONSTANT jump (fixed height/recoil, not changing with speed).

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Abilities = RS:WaitForChild("Abilities")
local RollingMelonStart = Abilities:FindFirstChild("RollingMelonStart")
if not RollingMelonStart then
	RollingMelonStart = Instance.new("RemoteEvent")
	RollingMelonStart.Name = "RollingMelonStart"
	RollingMelonStart.Parent = Abilities
end

local RollingMelonHit = Abilities:FindFirstChild("RollingMelonHit")
if not RollingMelonHit then
	RollingMelonHit = Instance.new("RemoteEvent")
	RollingMelonHit.Name = "RollingMelonHit"
	RollingMelonHit.Parent = Abilities
end

local RollingMelonStop = Abilities:FindFirstChild("RollingMelonStop")
if not RollingMelonStop then
	RollingMelonStop = Instance.new("RemoteEvent")
	RollingMelonStop.Name = "RollingMelonStop"
	RollingMelonStop.Parent = Abilities
end

-- Configuration
local COOLDOWN = 9
local MIN_DAMAGE = 20
local MAX_DAMAGE = 65
local MIN_SPEED = 25
local MAX_SPEED = 80
local CONSTANT_BOUNCE_HEIGHT = 32
local CONSTANT_BOUNCE_BACK = 22

local MELON_DARK_GREEN = Color3.fromRGB(45, 125, 45)
local MELON_STRIPE_GREEN = Color3.fromRGB(115, 210, 85)
local FLESH_RED = Color3.fromRGB(225, 35, 40)
local SEED_BLACK = Color3.fromRGB(25, 20, 20)

local lastUsed = {}
local activeRolls = {} -- [player] = { melonModel = Model, origTrans = {} }

local function isAlly(a, b)
	if not a or not b or a == b then return false end
	if a.Neutral or b.Neutral then return false end
	return a.Team ~= nil and a.Team == b.Team
end

-- =====================
-- WATERMELON BALL MODEL
-- =====================
local function createWatermelonModel(player, root)
	local melon = Instance.new("Model")
	melon.Name = "RollingMelon_" .. player.Name

	-- Main sphere
	local core = Instance.new("Part")
	core.Name = "MelonBall"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(5.8, 5.8, 5.8)
	core.Color = MELON_DARK_GREEN
	core.Material = Enum.Material.SmoothPlastic
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.Massless = true
	core.CFrame = root.CFrame
	core.Parent = melon
	melon.PrimaryPart = core

	-- Vertical lighter green stripes
	for i = 1, 6 do
		local a = (i / 6) * math.pi
		local stripe = Instance.new("Part")
		stripe.Name = "Stripe_" .. i
		stripe.Shape = Enum.PartType.Cylinder
		stripe.Size = Vector3.new(5.85, 0.45, 0.45)
		stripe.Color = MELON_STRIPE_GREEN
		stripe.Material = Enum.Material.SmoothPlastic
		stripe.CanCollide = false
		stripe.CanQuery = false
		stripe.CanTouch = false
		stripe.Massless = true
		stripe.CFrame = core.CFrame * CFrame.Angles(0, a, math.rad(90))
		stripe.Parent = melon

		local sw = Instance.new("WeldConstraint")
		sw.Part0 = core
		sw.Part1 = stripe
		sw.Parent = stripe
	end

	-- Rolling rumble sound
	local rumble = Instance.new("Sound")
	rumble.Name = "RollingSound"
	rumble.SoundId = "rbxassetid://9114223170" -- rolling rumble
	rumble.Looped = true
	rumble.Volume = 0.8
	rumble.Pitch = 0.75
	rumble.Parent = core
	rumble:Play()

	melon.Parent = workspace
	return melon, core
end

local function setCharacterVisible(char, isVisible, store)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			if not isVisible then
				if store[d] == nil then store[d] = d.Transparency end
				d.Transparency = 1
			elseif store[d] ~= nil then
				d.Transparency = store[d]
			end
		elseif d:IsA("Decal") then
			if not isVisible then
				if store[d] == nil then store[d] = d.Transparency end
				d.Transparency = 1
			elseif store[d] ~= nil then
				d.Transparency = store[d]
			end
		end
	end
	if isVisible then
		table.clear(store)
	end
end

-- =====================
-- SPLASH VFX & SOUND
-- =====================
local function spawnMelonSplash(pos, speedRatio)
	-- Splash sound
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://138084128" -- heavy splash/splat
	sound.Volume = 1.3
	sound.Pitch = 1.05 - speedRatio * 0.2
	local soundPart = Instance.new("Part")
	soundPart.Position = pos
	soundPart.Transparency = 1
	soundPart.Anchored = true
	soundPart.CanCollide = false
	soundPart.Parent = workspace
	sound.Parent = soundPart
	sound:Play()
	Debris:AddItem(soundPart, 2)

	-- Red watermelon chunks flying out
	local chunkCount = math.floor(12 + speedRatio * 14)
	for i = 1, chunkCount do
		local chunk = Instance.new("Part")
		local s = math.random(25, 60) * 0.01 * (0.8 + speedRatio * 0.6)
		chunk.Size = Vector3.new(s, s, s)
		chunk.Shape = Enum.PartType.Ball
		if i % 3 == 0 then
			chunk.Color = MELON_DARK_GREEN
		elseif i % 4 == 0 then
			chunk.Color = SEED_BLACK
			chunk.Size = Vector3.new(s * 0.5, s * 0.5, s * 0.5)
		else
			chunk.Color = FLESH_RED
		end
		chunk.Material = Enum.Material.SmoothPlastic
		chunk.CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * math.pi, math.random() * math.pi, math.random() * math.pi)
		local spread = 20 + speedRatio * 35
		chunk.AssemblyLinearVelocity = Vector3.new(math.random(-spread, spread), math.random(12, 38), math.random(-spread, spread))
		chunk.CanCollide = false
		chunk.CanQuery = false
		chunk.Parent = workspace
		Debris:AddItem(chunk, 1.2)
		TweenService:Create(chunk, TweenInfo.new(1.2), {Transparency = 1, Size = Vector3.new(0.05, 0.05, 0.05)}):Play()
	end

	-- Red ground splat
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = {}
	local ground = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -15, 0), rp)
	if ground then
		local splat = Instance.new("Part")
		splat.Shape = Enum.PartType.Cylinder
		splat.Size = Vector3.new(0.1, 2, 2)
		splat.Color = FLESH_RED
		splat.Material = Enum.Material.SmoothPlastic
		splat.Transparency = 0.2
		splat.Anchored = true
		splat.CanCollide = false
		splat.CFrame = CFrame.new(ground.Position + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90))
		splat.Parent = workspace
		local splatSize = 6 + speedRatio * 8
		TweenService:Create(splat, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.1, splatSize, splatSize)
		}):Play()
		task.delay(1.5, function()
			TweenService:Create(splat, TweenInfo.new(0.8), {Transparency = 1}):Play()
		end)
		Debris:AddItem(splat, 2.5)
	end
end

-- Constant rebound jump for caster (fixed height & back, independent of speed)
local function applyCasterReboundJump(casterRoot, rollDir)
	local flatDir = Vector3.new(rollDir.X, 0, rollDir.Z)
	if flatDir.Magnitude < 0.1 then
		flatDir = Vector3.new(0, 0, 1)
	else
		flatDir = flatDir.Unit
	end

	-- Clear old forces
	for _, child in ipairs(casterRoot:GetChildren()) do
		if child:IsA("BodyVelocity") or child:IsA("BodyForce") then
			child:Destroy()
		end
	end

	local bv = Instance.new("BodyVelocity")
	bv.Name = "MelonReboundJump"
	-- Constant jump up & back
	bv.Velocity = (-flatDir * CONSTANT_BOUNCE_BACK) + Vector3.new(0, CONSTANT_BOUNCE_HEIGHT, 0)
	bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bv.Parent = casterRoot
	Debris:AddItem(bv, 0.22)
end

-- =====================
-- REMOTE HANDLERS
-- =====================
RollingMelonStart.OnServerEvent:Connect(function(player)
	local now = tick()
	if lastUsed[player] and now - lastUsed[player] < COOLDOWN - 0.2 then return end

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return end

	lastUsed[player] = now

	-- Clean up old roll if any
	if activeRolls[player] then
		if activeRolls[player].melonModel then activeRolls[player].melonModel:Destroy() end
		setCharacterVisible(char, true, activeRolls[player].origTrans)
		activeRolls[player] = nil
	end

	local store = {}
	setCharacterVisible(char, false, store)
	local melonModel, melonCore = createWatermelonModel(player, root)

	activeRolls[player] = {
		melonModel = melonModel,
		melonCore = melonCore,
		origTrans = store,
		startTime = now,
	}

	-- Keep melon centered on root part
	local alignConn
	alignConn = RunService.Heartbeat:Connect(function()
		local cur = activeRolls[player]
		if not cur or not char or not root or not root.Parent or not melonModel.Parent then
			if alignConn then alignConn:Disconnect() end
			return
		end
		melonCore.CFrame = root.CFrame
	end)
end)

RollingMelonHit.OnServerEvent:Connect(function(player, impactPos, hitModel, currentSpeed, rollDir)
	local session = activeRolls[player]
	if not session then return end
	activeRolls[player] = nil

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")

	-- Clean up melon visual & restore character
	if session.melonModel and session.melonModel.Parent then
		session.melonModel:Destroy()
	end
	if char then
		setCharacterVisible(char, true, session.origTrans)
	end

	currentSpeed = math.clamp(tonumber(currentSpeed) or MIN_SPEED, MIN_SPEED, MAX_SPEED)
	local speedRatio = math.clamp((currentSpeed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED), 0, 1)

	if typeof(rollDir) ~= "Vector3" or rollDir.Magnitude < 0.1 then
		rollDir = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
	end
	if typeof(impactPos) ~= "Vector3" then
		impactPos = root and root.Position or Vector3.zero
	end

	-- Spawn juicy red splash
	spawnMelonSplash(impactPos, speedRatio)

	-- If an enemy was hit, damage them & launch them into the air scaling with speed
	if hitModel and hitModel:IsA("Model") and hitModel ~= char then
		local enemyHum = hitModel:FindFirstChildOfClass("Humanoid")
		local enemyRoot = hitModel:FindFirstChild("HumanoidRootPart")
		if enemyHum and enemyRoot and enemyHum.Health > 0 then
			local enemyPlayer = Players:GetPlayerFromCharacter(hitModel)
			if not (enemyPlayer and isAlly(player, enemyPlayer)) then
				-- Damage scales with speed
				local damage = math.floor(MIN_DAMAGE + speedRatio * (MAX_DAMAGE - MIN_DAMAGE))
				enemyHum:TakeDamage(damage)

				-- Launch victim high into the air based on speed
				local launchForce = 50 + speedRatio * 85
				local flatToVictim = (enemyRoot.Position - impactPos)
				local flatDir = Vector3.new(flatToVictim.X, 0, flatToVictim.Z)
				if flatDir.Magnitude < 0.1 then
					flatDir = Vector3.new(rollDir.X, 0, rollDir.Z)
				end
				flatDir = flatDir.Unit

				local kbDir = (flatDir * 0.6 + Vector3.new(0, 1.25, 0)).Unit
				local bv = Instance.new("BodyVelocity")
				bv.Velocity = kbDir * launchForce
				bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
				bv.Parent = enemyRoot
				Debris:AddItem(bv, 0.25)
			end
		end
	end

	-- Caster constant rebound jump up and back (fixed height & back)
	if root and hum and hum.Health > 0 then
		applyCasterReboundJump(root, rollDir)
	end
end)

RollingMelonStop.OnServerEvent:Connect(function(player, rollDir)
	local session = activeRolls[player]
	if not session then return end
	activeRolls[player] = nil

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if session.melonModel and session.melonModel.Parent then
		session.melonModel:Destroy()
	end
	if char then
		setCharacterVisible(char, true, session.origTrans)
	end

	if root and typeof(rollDir) == "Vector3" then
		applyCasterReboundJump(root, rollDir)
	end
end)

Players.PlayerRemoving:Connect(function(p)
	if activeRolls[p] then
		if activeRolls[p].melonModel then activeRolls[p].melonModel:Destroy() end
		activeRolls[p] = nil
	end
	lastUsed[p] = nil
end)

print("RollingMelonHandler loaded!")
