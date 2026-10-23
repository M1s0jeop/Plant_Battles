-- SunflowerOrbsHandler: drop 3 glowing sun orbs in a ring around the caster.
-- Whoever walks over an orb is healed and gets a short movement-speed boost.
-- Orbs are contested by default (anyone can grab) - flip CASTER_ONLY for self-only.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Abilities = RS:WaitForChild("Abilities")
local SunflowerOrbs = Abilities:WaitForChild("SunflowerOrbs")

-- ===== Config =====
local ORB_COUNT      = 3
local SPAWN_RADIUS   = 9      -- how far out the ring sits from you
local PICKUP_RADIUS  = 4.5    -- how close you must get to grab one
local HEAL_AMOUNT    = 25     -- HP restored per orb
local SPEED_BONUS    = 8      -- +walkspeed while buffed (16 -> 24)
local SPEED_DURATION = 4      -- seconds the speed boost lasts (refreshes per orb)
local ORB_LIFETIME   = 12     -- orbs despawn if left uncollected
local COOLDOWN       = 10
local BASE_WALKSPEED = 16
local CASTER_ONLY    = false  -- true = only the caster can collect their own orbs

local ORB_COLOR = Color3.fromRGB(255, 210, 60)

local cooldowns = {}   -- [player] = tick when usable again
local orbs = {}        -- list of live orb records

-- ===== Speed buff (token-based so overlapping grabs refresh, not fight) =====
local function applySpeedBuff(hum)
	if not hum or not hum.Parent then return end
	hum.WalkSpeed = BASE_WALKSPEED + SPEED_BONUS
	local token = os.clock()
	hum:SetAttribute("SunOrbBuffToken", token)
	task.delay(SPEED_DURATION, function()
		if hum and hum.Parent and hum:GetAttribute("SunOrbBuffToken") == token then
			hum:SetAttribute("SunOrbBuffToken", nil)
			-- only reset if nothing else took control and slowed us below our buff
			if hum.WalkSpeed > BASE_WALKSPEED then
				hum.WalkSpeed = BASE_WALKSPEED
			end
		end
	end)
end

-- ===== Pickup pop effect =====
local function popEffect(pos)
	local pop = Instance.new("Part")
	pop.Shape = Enum.PartType.Ball
	pop.Anchored = true
	pop.CanCollide = false
	pop.CanQuery = false
	pop.Material = Enum.Material.Neon
	pop.Color = ORB_COLOR
	pop.Transparency = 0.2
	pop.Size = Vector3.new(1, 1, 1)
	pop.CFrame = CFrame.new(pos)
	pop.Parent = workspace
	local TweenService = game:GetService("TweenService")
	TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(7, 7, 7),
		Transparency = 1,
	}):Play()
	Debris:AddItem(pop, 0.4)
end

-- ===== Make one orb =====
local function makeOrb(centerPos, index, caster)
	local angle = (index / ORB_COUNT) * math.pi * 2
	local offset = Vector3.new(math.cos(angle) * SPAWN_RADIUS, 0, math.sin(angle) * SPAWN_RADIUS)
	local basePos = centerPos + offset + Vector3.new(0, 2.5, 0)

	local orb = Instance.new("Part")
	orb.Name = "SunOrb"
	orb.Shape = Enum.PartType.Ball
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.Material = Enum.Material.Neon
	orb.Color = ORB_COLOR
	orb.Size = Vector3.new(1.6, 1.6, 1.6)
	orb.CFrame = CFrame.new(basePos)
	orb.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = ORB_COLOR
	light.Brightness = 3
	light.Range = 10
	light.Parent = orb

	-- faint outer halo so orbs read from a distance
	local halo = Instance.new("Part")
	halo.Shape = Enum.PartType.Ball
	halo.Anchored = true
	halo.CanCollide = false
	halo.CanQuery = false
	halo.Material = Enum.Material.Neon
	halo.Color = ORB_COLOR
	halo.Transparency = 0.75
	halo.Size = Vector3.new(2.8, 2.8, 2.8)
	halo.CFrame = orb.CFrame
	halo.Parent = workspace

	table.insert(orbs, {
		part = orb,
		halo = halo,
		basePos = basePos,
		phase = angle,
		spawnTime = tick(),
		caster = caster,
	})
end

-- ===== Single loop drives bob/spin + collection + lifetime for all orbs =====
RunService.Heartbeat:Connect(function()
	local now = tick()
	for i = #orbs, 1, -1 do
		local rec = orbs[i]
		local orb = rec.part
		if not orb or not orb.Parent then
			if rec.halo then rec.halo:Destroy() end
			table.remove(orbs, i)
			continue
		end

		-- lifetime expiry
		if now - rec.spawnTime > ORB_LIFETIME then
			orb:Destroy()
			if rec.halo then rec.halo:Destroy() end
			table.remove(orbs, i)
			continue
		end

		-- bob + slow spin
		local t = now * 2 + rec.phase
		local bobPos = rec.basePos + Vector3.new(0, math.sin(t) * 0.5, 0)
		orb.CFrame = CFrame.new(bobPos) * CFrame.Angles(0, now * 1.5, 0)
		if rec.halo then rec.halo.CFrame = CFrame.new(bobPos) end

		-- collection check
		local collected = false
		for _, plr in ipairs(Players:GetPlayers()) do
			if CASTER_ONLY and plr ~= rec.caster then continue end
			local ch = plr.Character
			local root = ch and ch:FindFirstChild("HumanoidRootPart")
			local hum = ch and ch:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 then
				if (root.Position - bobPos).Magnitude <= PICKUP_RADIUS then
					hum.Health = math.min(hum.MaxHealth, hum.Health + HEAL_AMOUNT)
					applySpeedBuff(hum)
					popEffect(bobPos)
					collected = true
					break
				end
			end
		end

		if collected then
			orb:Destroy()
			if rec.halo then rec.halo:Destroy() end
			table.remove(orbs, i)
		end
	end
end)

-- ===== Cast =====
SunflowerOrbs.OnServerEvent:Connect(function(player)
	local now = tick()
	if cooldowns[player] and now < cooldowns[player] then return end

	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return end

	cooldowns[player] = now + COOLDOWN

	local center = root.Position
	for i = 1, ORB_COUNT do
		makeOrb(center, i, player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	cooldowns[player] = nil
end)

print("SunflowerOrbsHandler loaded!")
