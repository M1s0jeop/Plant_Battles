-- KiwiOrbitHandler: summon 3 simple kiwis that rotate around the player.
-- Each kiwi acts as a projectile shield:
-- If an incoming enemy projectile hits or comes near an orbiting kiwi:
--   1) The kiwi pops with juicy green slice particles and sound.
--   2) The projectile is destroyed / disappears instantly.
--   3) The caster is healed for +20 HP (with a green floating heal indicator).
-- Orbit lasts up to 18s or until all 3 kiwis have popped.

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Abilities = RS:WaitForChild("Abilities")
local SummonKiwiOrbit = Abilities:FindFirstChild("SummonKiwiOrbit")
if not SummonKiwiOrbit then
	SummonKiwiOrbit = Instance.new("RemoteEvent")
	SummonKiwiOrbit.Name = "SummonKiwiOrbit"
	SummonKiwiOrbit.Parent = Abilities
end

local KiwiPopHeal = Abilities:FindFirstChild("KiwiPopHeal")
if not KiwiPopHeal then
	KiwiPopHeal = Instance.new("RemoteEvent")
	KiwiPopHeal.Name = "KiwiPopHeal"
	KiwiPopHeal.Parent = Abilities
end

-- Config
local COOLDOWN = 10
local DURATION = 18
local ORBIT_RADIUS = 4.8
local ORBIT_SPEED = 2.4 -- radians per second
local HEAL_AMOUNT = 20
local HIT_DISTANCE = 3.6 -- studs for projectile interception

local KIWI_SKIN = Color3.fromRGB(120, 85, 45)
local KIWI_GREEN = Color3.fromRGB(130, 205, 50)
local KIWI_CORE = Color3.fromRGB(240, 245, 210)

local lastUsed = {}
local activeOrbits = {} -- [player] = orbitSession

local function isAlly(a, b)
	if not a or not b or a == b then return false end
	if a.Neutral or b.Neutral then return false end
	return a.Team ~= nil and a.Team == b.Team
end

-- Floating +20 HP popup
local function showHealPopup(root)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 140, 0, 36)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.AlwaysOnTop = true
	bb.Parent = root

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = "+20 HP 💚"
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextColor3 = Color3.fromRGB(110, 255, 120)
	lbl.TextStrokeTransparency = 0.25
	lbl.Parent = bb

	TweenService:Create(bb, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, 5.5, 0)
	}):Play()
	TweenService:Create(lbl, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1
	}):Play()
	Debris:AddItem(bb, 0.95)
end

-- Burst of kiwi slice particles & sound when popped
local function popKiwiVfx(pos)
	-- Sound
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://9114223170" -- juicy squish pop sound
	sound.Volume = 1.2
	sound.Pitch = 1.25
	local soundAnchor = Instance.new("Part")
	soundAnchor.Position = pos
	soundAnchor.Transparency = 1
	soundAnchor.Anchored = true
	soundAnchor.CanCollide = false
	soundAnchor.Parent = workspace
	sound.Parent = soundAnchor
	sound:Play()
	Debris:AddItem(soundAnchor, 1.5)

	-- Green & brown burst chunks
	for i = 1, 10 do
		local chunk = Instance.new("Part")
		local s = math.random(20, 45) * 0.01
		chunk.Size = Vector3.new(s, s, s)
		chunk.Shape = Enum.PartType.Ball
		chunk.Color = (i % 2 == 0) and KIWI_GREEN or KIWI_SKIN
		chunk.Material = Enum.Material.SmoothPlastic
		chunk.CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * math.pi, math.random() * math.pi, math.random() * math.pi)
		chunk.AssemblyLinearVelocity = Vector3.new(math.random(-18, 18), math.random(8, 22), math.random(-18, 18))
		chunk.CanCollide = false
		chunk.CanQuery = false
		chunk.CanTouch = false
		chunk.Parent = workspace
		Debris:AddItem(chunk, 0.8)
		TweenService:Create(chunk, TweenInfo.new(0.8), {Transparency = 1, Size = Vector3.new(0.05, 0.05, 0.05)}):Play()
	end

	-- Green flash sphere
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(1.5, 1.5, 1.5)
	flash.Color = KIWI_GREEN
	flash.Material = Enum.Material.Neon
	flash.Transparency = 0.2
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CFrame = CFrame.new(pos)
	flash.Parent = workspace
	TweenService:Create(flash, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(4, 4, 4),
		Transparency = 1
	}):Play()
	Debris:AddItem(flash, 0.35)
end

-- =====================
-- BUILD SIMPLE KIWI MODEL
-- =====================
local function createSimpleKiwi()
	local model = Instance.new("Model")
	model.Name = "OrbitingKiwi"

	-- Main body: simple fuzzy brown kiwi oval
	local body = Instance.new("Part")
	body.Name = "KiwiBody"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(1.3, 1.0, 1.0)
	body.Color = KIWI_SKIN
	body.Material = Enum.Material.Fabric -- simple fuzzy texture
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = true  -- Crucial: raycast projectiles will hit this!
	body.CanTouch = true  -- Crucial: physical touched events
	body.Parent = model
	model.PrimaryPart = body

	-- Sliced green face on one side for unmistakable kiwi look
	local slice = Instance.new("Part")
	slice.Name = "SliceFace"
	slice.Shape = Enum.PartType.Cylinder
	slice.Size = Vector3.new(0.1, 0.85, 0.85)
	slice.Color = KIWI_GREEN
	slice.Material = Enum.Material.SmoothPlastic
	slice.Anchored = true
	slice.CanCollide = false
	slice.CanQuery = true
	slice.CanTouch = true
	slice.CFrame = body.CFrame * CFrame.Angles(0, 0, math.rad(90)) * CFrame.new(0, 0.55, 0)
	slice.Parent = model

	-- Pale core
	local core = Instance.new("Part")
	core.Name = "Core"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(0.12, 0.28, 0.28)
	core.Color = KIWI_CORE
	core.Material = Enum.Material.SmoothPlastic
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.CanTouch = false
	core.CFrame = slice.CFrame
	core.Parent = model

	-- Subtle green glowing sparkle trail
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.3, 0)
	a0.Parent = body
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.3, 0)
	a1.Parent = body
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(KIWI_GREEN)
	trail.Transparency = NumberSequence.new(0.35, 1)
	trail.Lifetime = 0.25
	trail.LightEmission = 0.5
	trail.Parent = body

	model.Parent = workspace
	return model, body, slice, core
end

-- Check if an instance is an incoming enemy projectile
local function isEnemyProjectile(inst, casterChar)
	if not inst or not inst.Parent then return false end
	if inst:IsDescendantOf(casterChar) then return false end

	local name = inst.Name:lower()
	-- Known projectile signatures
	if name:find("tomato") or name:find("kiwi") or name:find("mortar")
		or name:find("cherry") or name:find("pomegranate") or name:find("banana")
		or name:find("projectile") or name:find("bullet") or name:find("spore")
		or name:find("peel") or name:find("seed") then
		-- Exclude our own orbiting kiwis
		if name:find("orbitingkiwi") or name:find("kiwibody") or name:find("sliceface") then
			return false
		end
		-- Check if belonging to an ally
		local creator = inst:GetAttribute("Creator") or inst:GetAttribute("Owner")
		if creator and typeof(creator) == "number" then
			local p = Players:GetPlayerByUserId(creator)
			local casterPlayer = Players:GetPlayerFromCharacter(casterChar)
			if p and isAlly(casterPlayer, p) then
				return false
			end
		end
		return true
	end
	return false
end

-- =====================
-- SUMMON ORBIT
-- =====================
local function startKiwiOrbit(player)
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return end

	-- Clean up existing session if any
	if activeOrbits[player] then
		activeOrbits[player].cleanup()
	end

	local kiwis = {}
	for i = 1, 3 do
		local model, body, slice, core = createSimpleKiwi()
		table.insert(kiwis, {
			model = model,
			body = body,
			slice = slice,
			core = core,
			offsetAngle = (i - 1) * (math.pi * 2 / 3), -- 120 degrees apart
		})
	end

	local startTime = tick()
	local currentAngle = 0
	local isEnded = false
	local heartbeatConn

	local function cleanup()
		if isEnded then return end
		isEnded = true
		if heartbeatConn then heartbeatConn:Disconnect() end
		for _, k in ipairs(kiwis) do
			if k.model and k.model.Parent then
				k.model:Destroy()
			end
		end
		table.clear(kiwis)
		activeOrbits[player] = nil
	end

	local function popOneKiwi(index, pos)
		local k = kiwis[index]
		if not k then return end
		table.remove(kiwis, index)

		popKiwiVfx(pos)
		if k.model and k.model.Parent then
			k.model:Destroy()
		end

		-- Heal caster for +20 HP
		if hum and hum.Health > 0 and char and char.Parent then
			hum.Health = math.min(hum.MaxHealth, hum.Health + HEAL_AMOUNT)
			if root and root.Parent then
				showHealPopup(root)
			end
			KiwiPopHeal:FireClient(player, HEAL_AMOUNT)
		end

		-- If all 3 popped, end orbit
		if #kiwis == 0 then
			cleanup()
		end
	end

	-- Connect Touched on each kiwi part
	for i, k in ipairs(kiwis) do
		local touchedConn
		touchedConn = k.body.Touched:Connect(function(otherPart)
			if isEnded then
				touchedConn:Disconnect()
				return
			end
			if isEnemyProjectile(otherPart, char) then
				-- Find current index of this kiwi
				local curIdx = nil
				for idx, item in ipairs(kiwis) do
					if item == k then curIdx = idx break end
				end
				if curIdx then
					touchedConn:Disconnect()
					local popPos = k.body.Position
					-- Destroy projectile
					otherPart:Destroy()
					popOneKiwi(curIdx, popPos)
				end
			end
		end)
	end

	-- Heartbeat rotation & swept proximity interception loop
	heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		local c = player.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if not r or not h or h.Health <= 0 or tick() - startTime > DURATION then
			cleanup()
			return
		end

		currentAngle = currentAngle + dt * ORBIT_SPEED
		local centerPos = r.Position

		-- Update positions of surviving kiwis
		for idx = #kiwis, 1, -1 do
			local k = kiwis[idx]
			if not k.model.Parent then
				table.remove(kiwis, idx)
				continue
			end

			local a = currentAngle + k.offsetAngle
			local bob = math.sin(tick() * 3 + k.offsetAngle) * 0.35
			local kiwiPos = centerPos + Vector3.new(math.cos(a) * ORBIT_RADIUS, bob, math.sin(a) * ORBIT_RADIUS)
			local kiwiCFrame = CFrame.new(kiwiPos) * CFrame.Angles(0, -a + math.pi / 2, 0)

			k.body.CFrame = kiwiCFrame
			k.slice.CFrame = kiwiCFrame * CFrame.Angles(0, 0, math.rad(90)) * CFrame.new(0, 0.55, 0)
			k.core.CFrame = k.slice.CFrame

			-- Proximity sweep for any incoming projectiles nearby
			local overlap = OverlapParams.new()
			overlap.FilterType = Enum.RaycastFilterType.Exclude
			overlap.FilterDescendantsInstances = {char, k.model}

			local nearbyParts = workspace:GetPartBoundsInRadius(kiwiPos, HIT_DISTANCE, overlap)
			local intercepted = false
			for _, part in ipairs(nearbyParts) do
				if isEnemyProjectile(part, char) then
					intercepted = true
					part:Destroy()
					break
				end
			end

			if intercepted then
				popOneKiwi(idx, kiwiPos)
			end
		end

		if #kiwis == 0 then
			cleanup()
		end
	end)

	activeOrbits[player] = {
		cleanup = cleanup
	}
end

SummonKiwiOrbit.OnServerEvent:Connect(function(player)
	local now = tick()
	if lastUsed[player] and now - lastUsed[player] < COOLDOWN - 0.1 then return end

	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end

	lastUsed[player] = now
	startKiwiOrbit(player)
end)

Players.PlayerRemoving:Connect(function(p)
	if activeOrbits[p] then
		activeOrbits[p].cleanup()
	end
	lastUsed[p] = nil
end)

print("KiwiOrbitHandler loaded!")
