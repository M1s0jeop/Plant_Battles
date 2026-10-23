-- FlytrapSentryHandler: summon two Venus-flytrap sentries that auto-bite enemies
-- coming near them. Each bite: damages the enemy, HEALS the caster, and EXTENDS
-- that sentry's lifespan (so a sentry that keeps eating can live indefinitely).
-- Sentries have 200 HP and can be killed. Re-casting replaces your old pair.

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Abilities = RS:WaitForChild("Abilities")
local FlytrapSummon = Abilities:WaitForChild("FlytrapSummon")
local FlytrapHeal = Abilities:WaitForChild("FlytrapHeal")

-- Config
local COOLDOWN = 14
local SENTRY_HP = 200
local BITE_RANGE = 9
local BITE_DAMAGE = 14
local BITE_INTERVAL = 1.2        -- seconds between a sentry's bites
local HEAL_PER_BITE = 8          -- caster heals this much per bite
local BASE_LIFESPAN = 12         -- seconds a sentry lives if it never bites
local LIFE_PER_BITE = 4          -- each bite adds this to its remaining life
local MAX_LIFESPAN = 60          -- cap so it can't be literally infinite
local SUMMON_OFFSET = 7          -- how far to each side of the caster

local STEM_GREEN = Color3.fromRGB(70, 150, 60)
local TRAP_GREEN = Color3.fromRGB(96, 188, 76)
local TRAP_RED = Color3.fromRGB(200, 70, 70)
local TOOTH = Color3.fromRGB(240, 235, 215)

local casterSentries = {} -- [player] = {sentryModel, ...}

local function buildSentry(pos)
	local model = Instance.new("Model")
	model.Name = "FlytrapSentry"
	model.Parent = workspace

	-- base bulb / pot
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(3, 2, 3)
	base.Color = Color3.fromRGB(120, 90, 60)
	base.Material = Enum.Material.SmoothPlastic
	base.Anchored = true
	base.CanCollide = false
	base.CFrame = CFrame.new(pos + Vector3.new(0, 1, 0))
	base.Parent = model

	-- stem
	local stem = Instance.new("Part")
	stem.Name = "Stem"
	stem.Size = Vector3.new(1, 4, 1)
	stem.Color = STEM_GREEN
	stem.Material = Enum.Material.SmoothPlastic
	stem.Anchored = true
	stem.CanCollide = false
	stem.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
	stem.Parent = model

	-- head root (the part that everything bites around)
	local head = Instance.new("Part")
	head.Name = "HumanoidRootPart"
	head.Size = Vector3.new(3.4, 3.4, 2)
	head.Transparency = 1
	head.Anchored = true
	head.CanCollide = false
	head.CFrame = CFrame.new(pos + Vector3.new(0, 6.5, 0))
	head.Parent = model

	-- two jaw halves (upper/lower) made of a green pad + white teeth
	local function jaw(name, flip)
		local pad = Instance.new("Part")
		pad.Name = name
		pad.Size = Vector3.new(3.2, 0.5, 2.6)
		pad.Color = TRAP_GREEN
		pad.Material = Enum.Material.SmoothPlastic
		pad.Anchored = true
		pad.CanCollide = false
		pad.Parent = model
		-- inner red
		local inner = Instance.new("Part")
		inner.Name = name .. "Inner"
		inner.Size = Vector3.new(2.6, 0.2, 2)
		inner.Color = TRAP_RED
		inner.Material = Enum.Material.SmoothPlastic
		inner.Anchored = true
		inner.CanCollide = false
		inner.Parent = model
		return pad, inner
	end
	local upper, upperIn = jaw("UpperJaw", 1)
	local lower, lowerIn = jaw("LowerJaw", -1)

	-- teeth along the front edge of each jaw
	local teeth = {}
	for i = -2, 2 do
		for _, j in ipairs({"U", "L"}) do
			local t = Instance.new("Part")
			t.Name = "Tooth" .. j .. i
			t.Size = Vector3.new(0.35, 1, 0.35)
			t.Color = TOOTH
			t.Material = Enum.Material.SmoothPlastic
			t.Anchored = true
			t.CanCollide = false
			t.Parent = model
			teeth[#teeth + 1] = {part = t, idx = i, jaw = j}
		end
	end

	-- Humanoid so it has health and can be killed/damaged by abilities
	local hum = Instance.new("Humanoid")
	hum.MaxHealth = SENTRY_HP
	hum.Health = SENTRY_HP
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	hum.NameDisplayDistance = 0
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	hum.RequiresNeck = false
	hum.BreakJointsOnDeath = false
	hum.Parent = model

	-- lifespan bar floating above the trap (drains over time, refills on bite)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "LifeBar"
	billboard.Size = UDim2.new(0, 70, 0, 16)
	billboard.StudsOffset = Vector3.new(0, 4.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = head
	billboard.Parent = head
	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	bg.BackgroundTransparency = 0.25
	bg.BorderSizePixel = 0
	bg.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = bg
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, -4, 1, -4)
	fill.Position = UDim2.new(0, 2, 0, 2)
	fill.BackgroundColor3 = Color3.fromRGB(120, 220, 90)
	fill.BorderSizePixel = 0
	fill.Parent = bg
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill

	return model, head, hum, upper, lower, upperIn, lowerIn, teeth, fill
end

local function poseJaws(head, upper, lower, upperIn, lowerIn, teeth, openFrac)
	-- openFrac 0 = shut, 1 = wide open
	local hc = head.CFrame
	local ang = math.rad(8 + openFrac * 38)
	upper.CFrame = hc * CFrame.new(0, 0.4, -1) * CFrame.Angles(ang, 0, 0) * CFrame.new(0, 0, -1.3)
	lower.CFrame = hc * CFrame.new(0, -0.4, -1) * CFrame.Angles(-ang, 0, 0) * CFrame.new(0, 0, -1.3)
	upperIn.CFrame = upper.CFrame * CFrame.new(0, -0.3, 0)
	lowerIn.CFrame = lower.CFrame * CFrame.new(0, 0.3, 0)
	for _, td in ipairs(teeth) do
		local jawPart = (td.jaw == "U") and upper or lower
		local dirY = (td.jaw == "U") and -1 or 1
		td.part.CFrame = jawPart.CFrame * CFrame.new(td.idx * 0.6, dirY * 0.5, -1) * CFrame.Angles(math.rad(dirY * 20), 0, 0)
	end
end

local function clearSentries(player)
	local list = casterSentries[player]
	if not list then return end
	for _, data in ipairs(list) do
		if data.conn then data.conn:Disconnect() end
		if data.model and data.model.Parent then
			local m = data.model
			for _, p in ipairs(m:GetChildren()) do
				if p:IsA("BasePart") then TweenService:Create(p, TweenInfo.new(0.4), {Transparency = 1}):Play() end
			end
			Debris:AddItem(m, 0.5)
		end
	end
	casterSentries[player] = nil
end

local lastUsed = {}

FlytrapSummon.OnServerEvent:Connect(function(caster)
	local now = tick()
	if lastUsed[caster] and now - lastUsed[caster] < COOLDOWN - 0.1 then return end

	local char = caster.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	lastUsed[caster] = now
	clearSentries(caster) -- replace any existing pair
	casterSentries[caster] = {}

	local right = root.CFrame.RightVector
	local fwd = root.CFrame.LookVector
	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = {char}
	rp.FilterType = Enum.RaycastFilterType.Exclude

	for side = -1, 1, 2 do
		local spot = root.Position + fwd * 5 + right * (side * SUMMON_OFFSET)
		local gh = workspace:Raycast(spot + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), rp)
		local gy = gh and gh.Position.Y or (root.Position.Y - 3)
		local basePos = Vector3.new(spot.X, gy, spot.Z)

		local model, head, hum, upper, lower, upperIn, lowerIn, teeth, lifeFill = buildSentry(basePos)
		local data = {
			model = model, head = head, hum = hum, lifeFill = lifeFill,
			lifeLeft = BASE_LIFESPAN, lastBite = 0, biteAnim = 0,
		}
		table.insert(casterSentries[caster], data)

		hum.Died:Connect(function()
			if data.conn then data.conn:Disconnect() end
			for _, p in ipairs(model:GetChildren()) do
				if p:IsA("BasePart") then
					p.Anchored = false; p.CanCollide = false
					p.AssemblyLinearVelocity = Vector3.new(math.random(-10,10), 8, math.random(-10,10))
				end
			end
			Debris:AddItem(model, 1.5)
		end)

		-- spawn-grow pop
		poseJaws(head, upper, lower, upperIn, lowerIn, teeth, 0.5)

		data.conn = RunService.Heartbeat:Connect(function(dt)
			if not model.Parent or hum.Health <= 0 then
				if data.conn then data.conn:Disconnect() end
				return
			end
			-- lifespan countdown
			data.lifeLeft = data.lifeLeft - dt
			-- update the lifespan bar (fraction of the max possible life, color shifts as it runs low)
			if data.lifeFill then
				-- scale against base lifespan so a fresh trap reads full; fed traps stay full
				local frac = math.clamp(data.lifeLeft / BASE_LIFESPAN, 0, 1)
				data.lifeFill.Size = UDim2.new(frac, -4, 1, -4)
				if data.lifeLeft <= 3 then
					data.lifeFill.BackgroundColor3 = Color3.fromRGB(230, 70, 60)   -- about to expire
				elseif data.lifeLeft <= 6 then
					data.lifeFill.BackgroundColor3 = Color3.fromRGB(240, 200, 70)  -- getting low
				else
					data.lifeFill.BackgroundColor3 = Color3.fromRGB(120, 220, 90)  -- healthy
				end
			end
			if data.lifeLeft <= 0 then
				data.conn:Disconnect()
				for _, p in ipairs(model:GetChildren()) do
					if p:IsA("BasePart") then TweenService:Create(p, TweenInfo.new(0.4), {Transparency = 1}):Play() end
				end
				Debris:AddItem(model, 0.5)
				-- remove from list
				local list = casterSentries[caster]
				if list then for i, d in ipairs(list) do if d == data then table.remove(list, i) break end end end
				return
			end

			-- bite animation easing toward open, snaps shut on bite
			data.biteAnim = math.max(0, data.biteAnim - dt * 4)
			local openFrac = 0.5 + 0.4 * math.sin(tick() * 2) - data.biteAnim
			poseJaws(head, upper, lower, upperIn, lowerIn, teeth, math.clamp(openFrac, 0, 1))

			-- find an enemy in range to bite
			if tick() - data.lastBite >= BITE_INTERVAL then
				for _, em in ipairs(workspace:GetChildren()) do
					if em:IsA("Model") and em ~= char and em ~= model and em.Name ~= "FlytrapSentry" then
						local eHum = em:FindFirstChildOfClass("Humanoid")
						local eRoot = em:FindFirstChild("HumanoidRootPart")
						if eHum and eRoot and eHum.Health > 0 then
							if (eRoot.Position - head.Position).Magnitude <= BITE_RANGE then
								data.lastBite = tick()
								data.biteAnim = 1   -- snap shut
								eHum:TakeDamage(BITE_DAMAGE)
								-- extend life (capped)
								data.lifeLeft = math.min(MAX_LIFESPAN, data.lifeLeft + LIFE_PER_BITE)
								-- heal the caster
								local cc = caster.Character
								local ch = cc and cc:FindFirstChildOfClass("Humanoid")
								if ch and ch.Health > 0 then
									ch.Health = math.min(ch.MaxHealth, ch.Health + HEAL_PER_BITE)
									FlytrapHeal:FireClient(caster, head.Position)
								end
								break
							end
						end
					end
				end
			end
		end)
	end
end)

game.Players.PlayerRemoving:Connect(function(p)
	clearSentries(p)
	lastUsed[p] = nil
end)

print("FlytrapSentryHandler loaded!")
