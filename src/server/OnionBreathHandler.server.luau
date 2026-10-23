-- OnionBreathHandler: eat an onion and reek for a few seconds, leaving a trail
-- of stink clouds behind you as you move. Enemies standing in the stink take
-- damage over time, are slowed, and have their camera/vision disrupted
-- (handled client-side via OnionStink). Each cloud lingers 5s after it drops,
-- so the trail outlives the breath by ~5 seconds.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Abilities = RS:WaitForChild("Abilities")
local OnionBreath = Abilities:WaitForChild("OnionBreath")
local OnionStink = Abilities:WaitForChild("OnionStink")

-- ===== Config =====
local COOLDOWN        = 12
local BREATH_DURATION = 6      -- how long you keep breathing out stink
local PUFF_LIFETIME   = 5      -- each cloud lingers this long after dropping
local DROP_INTERVAL   = 0.4    -- how often we consider dropping a cloud
local MIN_SPACING     = 4      -- min gap between clouds while moving
local MAX_DROP_GAP    = 1.4    -- refresh the cloud even if standing still
local PUFF_RADIUS     = 6.5    -- horizontal reach of a cloud
local PUFF_VERT       = 8      -- vertical tolerance
local TICK_INTERVAL   = 0.5    -- damage/effect cadence
local DAMAGE_PER_TICK = 3      -- => 6 dps
local STINK_WALKSPEED = 9      -- slow applied while in the stink
local SLOW_LINGER     = 0.7    -- slow hangs on briefly after leaving
local STINK_TTL       = TICK_INTERVAL + 0.5   -- how long the client keeps the camera effect per ping
local STINK_COLOR     = Color3.fromRGB(150, 205, 90)

local lastUsed = {}
local puffs = {}     -- { {center, spawnTime, casterChar, folder}, ... }
local slowed = {}    -- [humanoid] = { orig, expire }
local tickAcc = 0

local function horizontalDist(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- ===== Slow manager =====
local function refreshSlow(hum)
	local rec = slowed[hum]
	if not rec then
		rec = { orig = (hum.WalkSpeed > STINK_WALKSPEED) and hum.WalkSpeed or 16 }
		slowed[hum] = rec
	end
	rec.expire = tick() + SLOW_LINGER
	if hum.WalkSpeed > STINK_WALKSPEED then hum.WalkSpeed = STINK_WALKSPEED end
end

-- ===== One stink cloud =====
local function dropPuff(centerPos, casterChar)
	local folder = Instance.new("Folder")
	folder.Name = "StinkPuff"
	folder.Parent = workspace

	-- translucent green cloud body
	local cloud = Instance.new("Part")
	cloud.Shape = Enum.PartType.Ball
	cloud.Anchored = true
	cloud.CanCollide = false
	cloud.CanQuery = false
	cloud.Material = Enum.Material.Neon
	cloud.Color = STINK_COLOR
	cloud.Transparency = 0.7
	cloud.Size = Vector3.new(2, 2, 2)
	cloud.CFrame = CFrame.new(centerPos + Vector3.new(0, 1.5, 0))
	cloud.Parent = folder
	TweenService:Create(cloud, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(PUFF_RADIUS * 2, 5, PUFF_RADIUS * 2), Transparency = 0.82 }):Play()

	-- stink smoke
	local emitterPart = Instance.new("Part")
	emitterPart.Size = Vector3.new(0.3, 0.3, 0.3)
	emitterPart.Transparency = 1
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CFrame = CFrame.new(centerPos + Vector3.new(0, 1, 0))
	emitterPart.Parent = folder

	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(160, 210, 95), Color3.fromRGB(110, 160, 60))
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, PUFF_RADIUS * 0.7),
		NumberSequenceKeypoint.new(1, PUFF_RADIUS * 1.1),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.6, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Lifetime = NumberRange.new(1.2, 2.2)
	smoke.Rate = 10
	smoke.Speed = NumberRange.new(0.5, 2)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Parent = emitterPart

	local rec = {
		center = centerPos,
		spawnTime = tick(),
		casterChar = casterChar,
		folder = folder,
		cloud = cloud,
		smoke = smoke,
	}
	table.insert(puffs, rec)
end

-- ===== Main effect + lifetime loop =====
RunService.Heartbeat:Connect(function(dt)
	local now = tick()

	-- expire old clouds
	for i = #puffs, 1, -1 do
		local p = puffs[i]
		if now - p.spawnTime > PUFF_LIFETIME then
			if p.smoke then p.smoke.Enabled = false end
			if p.cloud then TweenService:Create(p.cloud, TweenInfo.new(0.6), { Transparency = 1 }):Play() end
			Debris:AddItem(p.folder, 2.4)
			table.remove(puffs, i)
		end
	end

	-- restore expired slows
	for hum, rec in pairs(slowed) do
		if now > rec.expire then
			if hum.Parent and hum.WalkSpeed <= STINK_WALKSPEED then
				hum.WalkSpeed = rec.orig
			end
			slowed[hum] = nil
		end
	end

	if #puffs == 0 then return end

	-- effect ticks
	tickAcc = tickAcc + dt
	if tickAcc < TICK_INTERVAL then return end
	tickAcc = tickAcc - TICK_INTERVAL

	for _, model in ipairs(workspace:GetChildren()) do
		if not model:IsA("Model") then continue end
		local mRoot = model:FindFirstChild("HumanoidRootPart")
		local mHum = model:FindFirstChildOfClass("Humanoid")
		if not mRoot or not mHum or mHum.Health <= 0 then continue end

		-- inside any enemy stink cloud? (immune to your own breath)
		local inStink = false
		for _, p in ipairs(puffs) do
			if p.casterChar ~= model
				and math.abs(mRoot.Position.Y - p.center.Y) <= PUFF_VERT
				and horizontalDist(mRoot.Position, p.center) <= PUFF_RADIUS then
				inStink = true
				break
			end
		end

		if inStink then
			mHum:TakeDamage(DAMAGE_PER_TICK)
			refreshSlow(mHum)
			local plr = Players:GetPlayerFromCharacter(model)
			if plr then
				OnionStink:FireClient(plr, STINK_TTL)
			end
		end
	end
end)

-- ===== Caster breath visual =====
local function makeBreathVisual(char, duration)
	local head = char:FindFirstChild("Head")
	if not head then return end
	local src = Instance.new("Part")
	src.Name = "OnionBreathSource"
	src.Size = Vector3.new(0.4, 0.4, 0.4)
	src.Transparency = 1
	src.CanCollide = false
	src.CanQuery = false
	src.Massless = true
	src.CFrame = head.CFrame * CFrame.new(0, -0.4, -0.8)
	src.Parent = char
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head; weld.Part1 = src; weld.Parent = src

	local breath = Instance.new("ParticleEmitter")
	breath.Texture = "rbxasset://textures/particles/smoke_main.dds"
	breath.Color = ColorSequence.new(Color3.fromRGB(170, 220, 100), Color3.fromRGB(120, 170, 70))
	breath.Size = NumberSequence.new(0.6, 2.2)
	breath.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	breath.Lifetime = NumberRange.new(0.6, 1.1)
	breath.Rate = 22
	breath.Speed = NumberRange.new(4, 7)
	breath.SpreadAngle = Vector2.new(25, 25)
	breath.Acceleration = Vector3.new(0, 2, 0)
	breath.Parent = src

	task.delay(duration, function()
		breath.Enabled = false
		Debris:AddItem(src, 1.5)
	end)
end

-- ===== Cast =====
OnionBreath.OnServerEvent:Connect(function(caster)
	local now = tick()
	if lastUsed[caster] and now - lastUsed[caster] < COOLDOWN - 0.1 then return end

	local char = caster.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return end

	lastUsed[caster] = now
	makeBreathVisual(char, BREATH_DURATION)

	task.spawn(function()
		local startTime = tick()
		local lastPuffPos = nil
		local lastDropTime = 0

		local function groundedPos()
			local c = caster.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			if not r then return nil end
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Exclude
			rp.FilterDescendantsInstances = { c }
			local hit = workspace:Raycast(r.Position + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), rp)
			local y = hit and hit.Position.Y or (r.Position.Y - 2.5)
			return Vector3.new(r.Position.X, y, r.Position.Z)
		end

		-- always drop one right away so standing still still reeks
		local p0 = groundedPos()
		if p0 then dropPuff(p0, char); lastPuffPos = p0; lastDropTime = tick() end

		while tick() - startTime < BREATH_DURATION do
			task.wait(DROP_INTERVAL)
			local c = caster.Character
			local h = c and c:FindFirstChildOfClass("Humanoid")
			if not c or not h or h.Health <= 0 then break end

			local pos = groundedPos()
			if pos then
				local movedEnough = (not lastPuffPos) or horizontalDist(pos, lastPuffPos) >= MIN_SPACING
				local staleStationary = (tick() - lastDropTime) >= MAX_DROP_GAP
				if movedEnough or staleStationary then
					dropPuff(pos, char)
					lastPuffPos = pos
					lastDropTime = tick()
				end
			end
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	lastUsed[player] = nil
end)

print("OnionBreathHandler loaded!")
