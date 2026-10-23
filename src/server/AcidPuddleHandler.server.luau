-- AcidPuddleHandler: spit a pool of corrosive digestive acid on the ground.
-- Enemies standing in it take rapid damage-over-time, are slowed, and have their
-- armor broken: bonus shred vs Walnut Wall shields + a portion of the DoT bypasses
-- ForceFields (armor-piercing). Slow & DoT stop when they leave the puddle.

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Abilities = RS:WaitForChild("Abilities")
local AcidSpit = Abilities:WaitForChild("AcidSpit")

-- Config
local COOLDOWN = 9
local PUDDLE_RADIUS = 11
local DURATION = 7
local TICK_INTERVAL = 0.35       -- rapid DoT
local TICK_DAMAGE = 7            -- per tick (~20 dmg/sec)
local SHIELD_SHRED = 16          -- per tick vs Walnut nuts (armor break)
local PIERCE_FRAC = 0.4          -- this fraction of each tick bypasses ForceFields
local SLOW_MULT = 0.5            -- movement speed cut to half while standing in it
local MAX_RANGE = 70             -- how far you can spit it
local ACID_GREEN = Color3.fromRGB(120, 220, 60)
local ACID_DARK = Color3.fromRGB(90, 180, 40)

local lastUsed = {}

local function horizontalDist(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

AcidSpit.OnServerEvent:Connect(function(caster, targetPos)
	local now = tick()
	if lastUsed[caster] and now - lastUsed[caster] < COOLDOWN - 0.1 then return end
	if typeof(targetPos) ~= "Vector3" then return end

	local char = caster.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- clamp range
	local flatOff = Vector3.new(targetPos.X - root.Position.X, 0, targetPos.Z - root.Position.Z)
	if flatOff.Magnitude > MAX_RANGE then
		local clamped = root.Position + flatOff.Unit * MAX_RANGE
		targetPos = Vector3.new(clamped.X, targetPos.Y, clamped.Z)
	end

	lastUsed[caster] = now

	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = {char}
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local gh = workspace:Raycast(targetPos + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0), rp)
	local gy = gh and gh.Position.Y or targetPos.Y
	local center = Vector3.new(targetPos.X, gy, targetPos.Z)

	local folder = Instance.new("Folder")
	folder.Name = "AcidPuddle_" .. caster.Name
	folder.Parent = workspace

	-- main puddle disc
	local puddle = Instance.new("Part")
	puddle.Name = "Acid"
	puddle.Shape = Enum.PartType.Cylinder
	puddle.Size = Vector3.new(0.4, 1, 1)
	puddle.Color = ACID_GREEN
	puddle.Material = Enum.Material.Neon
	puddle.Transparency = 0.15
	puddle.Anchored = true
	puddle.CanCollide = false
	puddle.CanQuery = false
	puddle.CFrame = CFrame.new(center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	puddle.Parent = folder
	TweenService:Create(puddle, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Size = Vector3.new(0.4, PUDDLE_RADIUS * 2, PUDDLE_RADIUS * 2)}):Play()

	-- irregular blobs around the edge so it looks organic
	for i = 1, 9 do
		local a = (i / 9) * math.pi * 2
		local r = PUDDLE_RADIUS * (0.7 + math.random() * 0.4)
		local blob = Instance.new("Part")
		blob.Shape = Enum.PartType.Cylinder
		local bs = math.random(25, 50) * 0.1
		blob.Size = Vector3.new(0.4, bs, bs)
		blob.Color = (i % 2 == 0) and ACID_DARK or ACID_GREEN
		blob.Material = Enum.Material.Neon
		blob.Transparency = 0.2
		blob.Anchored = true
		blob.CanCollide = false
		blob.CanQuery = false
		blob.CFrame = CFrame.new(center.X + math.cos(a) * r, center.Y + 0.18, center.Z + math.sin(a) * r) * CFrame.Angles(0, 0, math.rad(90))
		blob.Parent = folder
	end

	-- rising acid bubbles
	task.spawn(function()
		while folder.Parent do
			local b = Instance.new("Part")
			b.Shape = Enum.PartType.Ball
			local s = math.random(4, 9) * 0.1
			b.Size = Vector3.new(s, s, s)
			b.Color = ACID_GREEN
			b.Material = Enum.Material.Neon
			b.Transparency = 0.2
			b.Anchored = true
			b.CanCollide = false
			b.CanQuery = false
			local a = math.random() * math.pi * 2
			local r = math.random() * PUDDLE_RADIUS * 0.9
			b.CFrame = CFrame.new(center.X + math.cos(a) * r, center.Y + 0.3, center.Z + math.sin(a) * r)
			b.Parent = folder
			TweenService:Create(b, TweenInfo.new(0.6), {
				CFrame = b.CFrame + Vector3.new(0, 2, 0), Transparency = 1, Size = Vector3.new(0.05,0.05,0.05)
			}):Play()
			Debris:AddItem(b, 0.7)
			task.wait(0.12)
		end
	end)

	-- DoT + slow zone
	local affected = {}  -- [hum] = origWS
	local tickAcc = 0
	local startT = tick()
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if tick() - startT > DURATION then
			conn:Disconnect()
			for hum, ws in pairs(affected) do
				if hum and hum.Parent then hum.WalkSpeed = ws end
			end
			for _, p in ipairs(folder:GetChildren()) do
				if p:IsA("BasePart") then TweenService:Create(p, TweenInfo.new(0.5), {Transparency = 1}):Play() end
			end
			Debris:AddItem(folder, 0.6)
			return
		end

		tickAcc = tickAcc + dt
		local doDamage = tickAcc >= TICK_INTERVAL
		if doDamage then tickAcc = tickAcc - TICK_INTERVAL end

		local inside = {}
		-- scan direct workspace models AND models nested one level in folders
		-- (e.g. Walnut nuts live inside a WalnutWall_<name> folder)
		local candidates = {}
		for _, obj in ipairs(workspace:GetChildren()) do
			if obj:IsA("Model") then
				candidates[#candidates + 1] = obj
			elseif obj:IsA("Folder") then
				for _, sub in ipairs(obj:GetChildren()) do
					if sub:IsA("Model") then candidates[#candidates + 1] = sub end
				end
			end
		end
		for _, model in ipairs(candidates) do
			if model ~= char then
				local mHum = model:FindFirstChildOfClass("Humanoid")
				local mRoot = model:FindFirstChild("HumanoidRootPart")
				if mHum and mRoot and mHum.Health > 0
					and horizontalDist(mRoot.Position, center) <= PUDDLE_RADIUS
					and math.abs(mRoot.Position.Y - center.Y) <= 6 then
					inside[mHum] = true
					-- apply slow once
					if not affected[mHum] then
						affected[mHum] = mHum.WalkSpeed
						mHum.WalkSpeed = mHum.WalkSpeed * SLOW_MULT
					end
					if doDamage then
						local isShield = model.Name:find("Walnut") ~= nil
						if isShield then
							mHum:TakeDamage(SHIELD_SHRED)   -- armor break: extra vs walls
						else
							-- split: most via TakeDamage, a pierce portion bypasses ForceFields
							local pierce = TICK_DAMAGE * PIERCE_FRAC
							mHum:TakeDamage(TICK_DAMAGE - pierce)
							mHum.Health = math.max(0, mHum.Health - pierce)
						end
					end
				end
			end
		end
		-- restore anyone who left the puddle
		for hum, ws in pairs(affected) do
			if not inside[hum] then
				if hum and hum.Parent then hum.WalkSpeed = ws end
				affected[hum] = nil
			end
		end
	end)
end)

print("AcidPuddleHandler loaded!")
