-- MushroomHandler: drop a spore shroud at your position (Akali W style).
-- While inside: the caster turns invisible (but can still take damage) and
-- gains movement speed. Enemies inside take small poison ticks.
-- Spore particles mark the area for everyone.

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Abilities = RS:WaitForChild("Abilities")
local MushroomCloud = Abilities:WaitForChild("MushroomCloud")

-- Config
local OUTER_RADIUS = 24       -- outer edge of the donut
local INNER_RADIUS = 9        -- the hole in the middle (no effects there, like Akali W)
local DURATION = 11
local COOLDOWN = 12
local CASTER_SPEED = 22       -- movement speed while hidden in the shroud
local POISON_DAMAGE = 3       -- per tick
local POISON_INTERVAL = 0.5   -- seconds between ticks

local lastUsed = {}
local activeShrouds = {} -- [player] = true (one shroud per caster)

local function horizontalDist(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function inDonut(pos, center)
	local d = horizontalDist(pos, center)
	return d >= INNER_RADIUS and d <= OUTER_RADIUS
end

local function makeBoundaryRing(folder, center, radius, color)
	local segments = 28
	for i = 1, segments do
		local a = (i / segments) * math.pi * 2
		local seg = Instance.new("Part")
		seg.Size = Vector3.new((2 * math.pi * radius / segments) * 1.05, 0.2, 0.6)
		seg.Color = color
		seg.Material = Enum.Material.Neon
		seg.Transparency = 0.45
		seg.Anchored = true
		seg.CanCollide = false
		seg.CanQuery = false
		seg.CFrame = CFrame.new(center + Vector3.new(math.cos(a) * radius, 0.1, math.sin(a) * radius))
			* CFrame.Angles(0, -a + math.pi / 2, 0)
		seg.Parent = folder
	end
end

local function makeShroudVisual(center)
	local folder = Instance.new("Folder")
	folder.Name = "MushroomShroud"
	folder.Parent = workspace

	-- glowing boundary rings so the donut shape reads clearly
	makeBoundaryRing(folder, center, OUTER_RADIUS, Color3.fromRGB(170, 100, 220))
	makeBoundaryRing(folder, center, INNER_RADIUS, Color3.fromRGB(120, 60, 170))

	-- spore particle emitters spread along the ring's centerline
	local midRadius = (INNER_RADIUS + OUTER_RADIUS) / 2
	local ringWidth = OUTER_RADIUS - INNER_RADIUS
	local posts = 14
	for i = 1, posts do
		local a = (i / posts) * math.pi * 2
		local pos = center + Vector3.new(math.cos(a) * midRadius, 1.5, math.sin(a) * midRadius)
		local post = Instance.new("Part")
		post.Size = Vector3.new(0.2, 0.2, 0.2)
		post.Position = pos
		post.Transparency = 1
		post.Anchored = true
		post.CanCollide = false
		post.CanQuery = false
		post.Parent = folder

		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Color = ColorSequence.new(Color3.fromRGB(160, 90, 210), Color3.fromRGB(90, 50, 140))
		smoke.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, ringWidth * 0.45),
			NumberSequenceKeypoint.new(1, ringWidth * 0.7),
		})
		smoke.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(0.7, 0.7),
			NumberSequenceKeypoint.new(1, 1),
		})
		smoke.Lifetime = NumberRange.new(1.4, 2.4)
		smoke.Rate = 7
		smoke.Speed = NumberRange.new(0.5, 1.5)
		smoke.SpreadAngle = Vector2.new(180, 180)
		smoke.Parent = post

		local spores = Instance.new("ParticleEmitter")
		spores.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		spores.Color = ColorSequence.new(Color3.fromRGB(120, 255, 120))
		spores.Size = NumberSequence.new(0.35)
		spores.Transparency = NumberSequence.new(0.2, 1)
		spores.Lifetime = NumberRange.new(1, 2)
		spores.Rate = 5
		spores.Speed = NumberRange.new(1, 3)
		spores.SpreadAngle = Vector2.new(180, 180)
		spores.Parent = post
	end

	return folder
end
local function setCharacterInvisible(char, invisible, store)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			if invisible then
				if store[d] == nil then store[d] = d.Transparency end
				d.Transparency = 1
			elseif store[d] ~= nil then
				d.Transparency = store[d]
			end
		elseif d:IsA("Decal") then -- face
			if invisible then
				if store[d] == nil then store[d] = d.Transparency end
				d.Transparency = 1
			elseif store[d] ~= nil then
				d.Transparency = store[d]
			end
		end
	end
	if not invisible then
		table.clear(store)
	end
end

MushroomCloud.OnServerEvent:Connect(function(caster)
	local now = tick()
	if lastUsed[caster] and now - lastUsed[caster] < COOLDOWN - 0.1 then return end
	if activeShrouds[caster] then return end

	local char = caster.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return end

	lastUsed[caster] = now
	activeShrouds[caster] = true

	local center = root.Position
	local folder = makeShroudVisual(center)

	local transparencyStore = {}
	local casterHidden = false
	local origNameDistance = hum.DisplayDistanceType
	local origWS = nil
	local poisonAcc = 0
	local startTime = tick()
	local victimsLastTick = {}

	local conn
	local function cleanup()
		if conn then conn:Disconnect() end
		activeShrouds[caster] = nil
		local c = caster.Character
		if c then
			setCharacterInvisible(c, false, transparencyStore)
			local h = c:FindFirstChildOfClass("Humanoid")
			if h then
				h.DisplayDistanceType = origNameDistance
				if origWS then h.WalkSpeed = origWS end
			end
		end
		-- let lingering particles fade naturally, hide ring segments, then remove
		for _, d in ipairs(folder:GetDescendants()) do
			if d:IsA("ParticleEmitter") then d.Enabled = false end
			if d:IsA("BasePart") then d.Transparency = 1 end
		end
		Debris:AddItem(folder, 2.5)
	end

	conn = RunService.Heartbeat:Connect(function(dt)
		local c = caster.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if not r or not h or h.Health <= 0 or tick() - startTime > DURATION then
			cleanup()
			return
		end

		-- caster: invisible + fast while inside the shroud
		local inside = inDonut(r.Position, center)
		if inside and not casterHidden then
			casterHidden = true
			setCharacterInvisible(c, true, transparencyStore)
			h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			origWS = origWS or h.WalkSpeed
			h.WalkSpeed = CASTER_SPEED
		elseif not inside and casterHidden then
			casterHidden = false
			setCharacterInvisible(c, false, transparencyStore)
			h.DisplayDistanceType = origNameDistance
			if origWS then h.WalkSpeed = origWS end
		end

		-- enemies: poison ticks while inside
		poisonAcc = poisonAcc + dt
		if poisonAcc >= POISON_INTERVAL then
			poisonAcc = poisonAcc - POISON_INTERVAL
			for _, model in ipairs(workspace:GetChildren()) do
				if model:IsA("Model") and model ~= c then
					local mRoot = model:FindFirstChild("HumanoidRootPart")
					local mHum = model:FindFirstChildOfClass("Humanoid")
					if mRoot and mHum and mHum.Health > 0
						and inDonut(mRoot.Position, center) then
						mHum:TakeDamage(POISON_DAMAGE)
					end
				end
			end
		end
	end)
end)

game.Players.PlayerRemoving:Connect(function(player)
	lastUsed[player] = nil
end)

print("MushroomHandler loaded!")
