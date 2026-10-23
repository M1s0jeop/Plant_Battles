-- CannonHandler: become a coconut mortar cannon. You're rooted in place with
-- a beefy 500 HP pool, you steer a big target reticle around the map, and you
-- fire up to 3 quick mortar coconuts that arc steeply onto the reticle with a
-- big-radius 40 dmg blast. Exits after 3 shots (or timeout / early stop).

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Abilities = RS:WaitForChild("Abilities")
local CannonStart = Abilities:WaitForChild("CannonStart")
local CannonAim = Abilities:WaitForChild("CannonAim")
local CannonFire = Abilities:WaitForChild("CannonFire")
local CannonStop = Abilities:WaitForChild("CannonStop")

-- Config
local COOLDOWN = 18           -- starts when cannon mode ends
local MODE_TIME = 20          -- max time in cannon mode
local SHOTS = 3
local SHOT_GAP = 0.4          -- min time between shots (quick release)
local CANNON_HEALTH = 500
local AOE_RADIUS = 12         -- blast radius
local DAMAGE = 40
local MAX_RANGE = 120         -- how far the reticle can travel
local SHELL_TIME = 0.9        -- mortar flight time: lands quick
local SHELL_GRAVITY = 140     -- steep up-and-down arc

local BROWN = Color3.fromRGB(110, 75, 45)
local DARK = Color3.fromRGB(60, 45, 30)

local sessions = {} -- [player] = session

local function groundPoint(pos)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = {}
	local res = workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -120, 0), rp)
	return res and res.Position or pos
end

local function blast(pos, caster)
	-- shockwave ring
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 2, 2)
	ring.Color = Color3.fromRGB(230, 170, 80)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.2
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.3, AOE_RADIUS * 2, AOE_RADIUS * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.4)

	-- coconut shrapnel + dust
	for i = 1, 10 do
		local chunk = Instance.new("Part")
		local s = math.random(25, 55) * 0.01
		chunk.Size = Vector3.new(s, s, s)
		chunk.Color = i % 3 == 0 and Color3.fromRGB(235, 230, 215) or BROWN
		chunk.Material = Enum.Material.Wood
		chunk.CFrame = CFrame.new(pos + Vector3.new(0, 1, 0))
		chunk.AssemblyLinearVelocity = Vector3.new(math.random(-30, 30), math.random(15, 40), math.random(-30, 30))
		chunk.CanCollide = false
		chunk.CanQuery = false
		chunk.Parent = workspace
		Debris:AddItem(chunk, 1)
		TweenService:Create(chunk, TweenInfo.new(1), {Transparency = 1}):Play()
	end

	-- damage
	local casterChar = caster.Character
	for _, model in ipairs(workspace:GetChildren()) do
		if model:IsA("Model") and model ~= casterChar then
			local mRoot = model:FindFirstChild("HumanoidRootPart")
			local mHum = model:FindFirstChildOfClass("Humanoid")
			if mRoot and mHum and mHum.Health > 0
				and (mRoot.Position - pos).Magnitude <= AOE_RADIUS then
				mHum:TakeDamage(DAMAGE)
			end
		end
	end
end

local function fireMortar(caster, origin, target)
	local shell = Instance.new("Part")
	shell.Name = "MortarCoconut"
	shell.Shape = Enum.PartType.Ball
	shell.Size = Vector3.new(2, 2, 2)
	shell.Color = BROWN
	shell.Material = Enum.Material.Wood
	shell.Anchored = true
	shell.CanCollide = false
	shell.CanQuery = false
	shell.Position = origin
	shell.Parent = workspace

	-- ballistic solve for a fixed quick flight time -> steep mortar arc
	local g = Vector3.new(0, -SHELL_GRAVITY, 0)
	local delta = target - origin
	local vel = (delta - 0.5 * g * SHELL_TIME * SHELL_TIME) / SHELL_TIME

	task.spawn(function()
		local pos = origin
		local v = vel
		local elapsed = 0
		local spin = 0
		while elapsed < SHELL_TIME + 0.5 do
			local dt = RunService.Heartbeat:Wait()
			elapsed = elapsed + dt
			spin = spin + dt * 10
			local newVel = v + g * dt
			local newPos = pos + v * dt
			if newPos.Y <= target.Y + 0.5 and elapsed > SHELL_TIME * 0.5 then
				break
			end
			pos = newPos
			v = newVel
			shell.CFrame = CFrame.new(pos) * CFrame.Angles(spin, spin * 0.5, 0)
		end
		shell:Destroy()
		blast(target, caster)
	end)
end

local function endCannon(player)
	local sess = sessions[player]
	if not sess or not sess.active then return end
	sess.active = false
	sess.cooldownUntil = tick() + COOLDOWN

	if sess.reticle then sess.reticle:Destroy() end
	for _, p in ipairs(sess.visuals or {}) do
		if p and p.Parent then p:Destroy() end
	end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then root.Anchored = false end
	if hum then
		-- carry damage taken over proportionally: full pool = full original health
		local frac = math.clamp(hum.Health / CANNON_HEALTH, 0, 1)
		hum.MaxHealth = sess.origMax
		hum.Health = math.max(1, math.floor(sess.origHealth * frac))
		hum.WalkSpeed = 16
		hum.JumpPower = 50
	end
end

CannonStart.OnServerEvent:Connect(function(player)
	local old = sessions[player]
	if old and old.active then return end
	if old and old.cooldownUntil and tick() < old.cooldownUntil - 0.1 then return end

	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return end

	local sess = {
		active = true,
		shots = 0,
		lastShot = 0,
		origHealth = hum.Health,
		origMax = hum.MaxHealth,
		aimPos = groundPoint(root.Position + root.CFrame.LookVector * 25),
		visuals = {},
		startTime = tick(),
	}
	sessions[player] = sess

	-- root in place + beefy health pool
	root.Anchored = true
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	hum.MaxHealth = CANNON_HEALTH
	hum.Health = CANNON_HEALTH

	-- cannon visuals: angled barrel + base
	local barrel = Instance.new("Part")
	barrel.Name = "CannonBarrel"
	barrel.Shape = Enum.PartType.Cylinder
	barrel.Size = Vector3.new(5, 1.8, 1.8)
	barrel.Color = DARK
	barrel.Material = Enum.Material.Metal
	barrel.Anchored = true
	barrel.CanCollide = false
	barrel.CanQuery = false
	barrel.CFrame = root.CFrame * CFrame.new(0, 2, -1) * CFrame.Angles(0, math.rad(90), math.rad(50))
	barrel.Parent = char
	table.insert(sess.visuals, barrel)

	local base = Instance.new("Part")
	base.Name = "CannonBase"
	base.Shape = Enum.PartType.Cylinder
	base.Size = Vector3.new(0.6, 5, 5)
	base.Color = BROWN
	base.Material = Enum.Material.Wood
	base.Anchored = true
	base.CanCollide = false
	base.CanQuery = false
	base.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.7, 0)) * CFrame.Angles(0, 0, math.rad(90))
	base.Parent = char
	table.insert(sess.visuals, base)

	-- targeting reticle showing the blast area
	local reticle = Instance.new("Part")
	reticle.Name = "CannonReticle_" .. player.Name
	reticle.Shape = Enum.PartType.Cylinder
	reticle.Size = Vector3.new(0.15, AOE_RADIUS * 2, AOE_RADIUS * 2)
	reticle.Color = Color3.fromRGB(255, 150, 50)
	reticle.Material = Enum.Material.Neon
	reticle.Transparency = 0.65
	reticle.Anchored = true
	reticle.CanCollide = false
	reticle.CanQuery = false
	reticle.CFrame = CFrame.new(sess.aimPos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	reticle.Parent = workspace
	sess.reticle = reticle

	-- timeout / death watchdog
	task.spawn(function()
		while sess.active do
			if tick() - sess.startTime > MODE_TIME then break end
			local c = player.Character
			local h = c and c:FindFirstChildOfClass("Humanoid")
			if not h or h.Health <= 0 then break end
			task.wait(0.25)
		end
		endCannon(player)
	end)
end)

CannonAim.OnServerEvent:Connect(function(player, pos)
	local sess = sessions[player]
	if not sess or not sess.active then return end
	if typeof(pos) ~= "Vector3" then return end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- clamp reticle within range of the cannon
	local flat = Vector3.new(pos.X, root.Position.Y, pos.Z)
	local offset = flat - root.Position
	if offset.Magnitude > MAX_RANGE then
		flat = root.Position + offset.Unit * MAX_RANGE
	end
	sess.aimPos = groundPoint(flat)
	if sess.reticle then
		sess.reticle.CFrame = CFrame.new(sess.aimPos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	end
end)

CannonFire.OnServerEvent:Connect(function(player)
	local sess = sessions[player]
	if not sess or not sess.active then return end
	if sess.shots >= SHOTS then return end
	local t = tick()
	if t - sess.lastShot < SHOT_GAP then return end
	sess.lastShot = t
	sess.shots = sess.shots + 1

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	fireMortar(player, root.Position + Vector3.new(0, 4, 0), sess.aimPos)

	if sess.shots >= SHOTS then
		-- let the last shell leave the barrel, then pack up
		task.delay(0.3, function() endCannon(player) end)
	end
end)

CannonStop.OnServerEvent:Connect(function(player)
	endCannon(player)
end)

game.Players.PlayerRemoving:Connect(function(player)
	endCannon(player)
	sessions[player] = nil
end)

print("CannonHandler loaded!")
