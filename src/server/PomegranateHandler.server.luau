-- PomegranateHandler: throw a pomegranate grenade on an arc. On impact it
-- deals direct-hit damage and splits into seed splinters that scatter, then
-- each seed pops in a juicy red explosion with AoE damage.

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Abilities = RS:WaitForChild("Abilities")
local PomegranateThrow = Abilities:WaitForChild("PomegranateThrow")

-- Config
local COOLDOWN = 6
local DIRECT_DAMAGE = 15      -- bonk damage if the grenade itself hits someone
local SEED_COUNT = 6
local SEED_DAMAGE = 12        -- per seed explosion
local SEED_RADIUS = 7         -- explosion radius per seed
local SEED_FUSE = 0.55        -- base fuse, staggered per seed
local LOB_SPEED = 60
local GRAVITY = 70
local SEED_GRAVITY = 85
local MAX_TARGET_DIST = 250

local JUICE = Color3.fromRGB(175, 20, 45)
local SEED_COLOR = Color3.fromRGB(195, 35, 60)

local lastUsed = {}

local function groundSplat(pos, size)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = {}
	local res = workspace:Raycast(pos + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), rp)
	if not res then return end
	local splat = Instance.new("Part")
	splat.Name = "JuiceSplat"
	splat.Shape = Enum.PartType.Cylinder
	splat.Size = Vector3.new(0.1, 0.8, 0.8)
	splat.Color = JUICE
	splat.Material = Enum.Material.SmoothPlastic
	splat.Transparency = 0.2
	splat.Anchored = true
	splat.CanCollide = false
	splat.CanQuery = false
	splat.CFrame = CFrame.new(res.Position + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
	splat.Parent = workspace
	TweenService:Create(splat, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = Vector3.new(0.1, size, size)}):Play()
	task.delay(1.2, function()
		TweenService:Create(splat, TweenInfo.new(0.6), {Transparency = 1}):Play()
	end)
	Debris:AddItem(splat, 2)
end

local function juiceExplosion(pos, caster)
	-- expanding juice burst
	local burst = Instance.new("Part")
	burst.Shape = Enum.PartType.Ball
	burst.Size = Vector3.new(1, 1, 1)
	burst.Color = JUICE
	burst.Material = Enum.Material.Neon
	burst.Transparency = 0.25
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.Position = pos
	burst.Parent = workspace
	TweenService:Create(burst, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(SEED_RADIUS * 1.5, SEED_RADIUS * 1.5, SEED_RADIUS * 1.5),
		Transparency = 1,
	}):Play()
	Debris:AddItem(burst, 0.4)

	-- juice droplets
	for i = 1, 10 do
		local drop = Instance.new("Part")
		local s = math.random(15, 35) * 0.01
		drop.Size = Vector3.new(s, s, s)
		drop.Shape = Enum.PartType.Ball
		drop.Color = JUICE
		drop.Material = Enum.Material.Glass
		drop.Transparency = 0.15
		drop.CFrame = CFrame.new(pos)
		drop.AssemblyLinearVelocity = Vector3.new(math.random(-22, 22), math.random(8, 26), math.random(-22, 22))
		drop.CanCollide = false
		drop.CanQuery = false
		drop.Parent = workspace
		Debris:AddItem(drop, 0.8)
		TweenService:Create(drop, TweenInfo.new(0.8), {Transparency = 1}):Play()
	end

	groundSplat(pos, SEED_RADIUS * 0.9)

	-- AoE damage
	local casterChar = caster.Character
	for _, model in ipairs(workspace:GetChildren()) do
		if model:IsA("Model") and model ~= casterChar then
			local mRoot = model:FindFirstChild("HumanoidRootPart")
			local mHum = model:FindFirstChildOfClass("Humanoid")
			if mRoot and mHum and mHum.Health > 0
				and (mRoot.Position - pos).Magnitude <= SEED_RADIUS then
				mHum:TakeDamage(SEED_DAMAGE)
			end
		end
	end
end

local function launchSeed(origin, caster, fuse, ignoreList)
	local seed = Instance.new("Part")
	seed.Name = "PomegranateSeed"
	seed.Shape = Enum.PartType.Ball
	seed.Size = Vector3.new(0.5, 0.5, 0.5)
	seed.Color = SEED_COLOR
	seed.Material = Enum.Material.Glass
	seed.Transparency = 0.1
	seed.Anchored = true
	seed.CanCollide = false
	seed.CanQuery = false
	seed.Position = origin
	seed.Parent = workspace

	local vel = Vector3.new(math.random(-16, 16), math.random(16, 26), math.random(-16, 16))
	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = ignoreList
	rp.FilterType = Enum.RaycastFilterType.Exclude

	task.spawn(function()
		local pos = origin
		local v = vel
		local elapsed = 0
		local resting = false
		while elapsed < fuse do
			local dt = RunService.Heartbeat:Wait()
			elapsed = elapsed + dt
			if not resting then
				local newVel = v + Vector3.new(0, -SEED_GRAVITY, 0) * dt
				local newPos = pos + v * dt
				local result = workspace:Raycast(pos, newPos - pos, rp)
				if result then
					pos = result.Position + result.Normal * 0.25
					resting = true
				else
					pos = newPos
					v = newVel
				end
				seed.Position = pos
			end
		end
		seed:Destroy()
		juiceExplosion(pos, caster)
	end)
end

PomegranateThrow.OnServerEvent:Connect(function(caster, targetPoint)
	local now = tick()
	if lastUsed[caster] and now - lastUsed[caster] < COOLDOWN - 0.1 then return end
	if typeof(targetPoint) ~= "Vector3" then return end

	local char = caster.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if (targetPoint - root.Position).Magnitude > MAX_TARGET_DIST then return end

	lastUsed[caster] = now

	local origin = root.Position + root.CFrame.LookVector * 1.5 + Vector3.new(0, 2, 0)
	local delta = targetPoint - origin
	local flightTime = math.clamp(delta.Magnitude / LOB_SPEED, 0.4, 2)
	local g = Vector3.new(0, -GRAVITY, 0)
	local vel = (delta - 0.5 * g * flightTime * flightTime) / flightTime

	-- the pomegranate: deep crimson ball with a little crown on top
	local pom = Instance.new("Part")
	pom.Name = "Pomegranate_" .. caster.Name
	pom.Shape = Enum.PartType.Ball
	pom.Size = Vector3.new(1.5, 1.5, 1.5)
	pom.Color = Color3.fromRGB(150, 22, 40)
	pom.Material = Enum.Material.SmoothPlastic
	pom.Anchored = true
	pom.CanCollide = false
	pom.CanQuery = false
	pom.CFrame = CFrame.new(origin)
	pom.Parent = workspace

	local crown = Instance.new("Part")
	crown.Name = "Crown"
	crown.Shape = Enum.PartType.Cylinder
	crown.Size = Vector3.new(0.35, 0.55, 0.55)
	crown.Color = Color3.fromRGB(115, 60, 40)
	crown.Material = Enum.Material.SmoothPlastic
	crown.Anchored = true
	crown.CanCollide = false
	crown.CanQuery = false
	crown.Parent = pom

	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = {char, pom}
	rp.FilterType = Enum.RaycastFilterType.Exclude

	task.spawn(function()
		local pos = origin
		local v = vel
		local elapsed = 0
		local spin = 0
		while elapsed < 4 do
			local dt = RunService.Heartbeat:Wait()
			elapsed = elapsed + dt
			spin = spin + dt * 8

			local newVel = v + g * dt
			local newPos = pos + v * dt

			local result = workspace:Raycast(pos, newPos - pos, rp)
			if result then
				-- direct hit bonus damage
				local model = result.Instance:FindFirstAncestorOfClass("Model")
				if model and model ~= char then
					local vHum = model:FindFirstChildOfClass("Humanoid")
					if vHum and vHum.Health > 0 then
						vHum:TakeDamage(DIRECT_DAMAGE)
					end
				end

				-- split into seed splinters
				local splitPos = result.Position + result.Normal * 0.6
				groundSplat(splitPos, 3)
				for i = 1, SEED_COUNT do
					launchSeed(splitPos, caster, SEED_FUSE + i * 0.12, {char, pom})
				end
				break
			end

			pos = newPos
			v = newVel
			pom.CFrame = CFrame.new(pos) * CFrame.Angles(spin, spin * 0.6, 0)
			crown.CFrame = pom.CFrame * CFrame.new(0, 0.85, 0) * CFrame.Angles(0, 0, math.rad(90))
		end
		pom:Destroy()
	end)
end)

print("PomegranateHandler loaded!")
