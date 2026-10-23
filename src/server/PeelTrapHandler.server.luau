-- PeelTrapHandler: throw a giant banana peel that lands and waits as a trap.
-- When an enemy steps on it, they ragdoll, slide forward in the direction they
-- were moving, and take minor damage. The peel is consumed on trigger.

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Abilities = RS:WaitForChild("Abilities")
local PeelThrow = Abilities:WaitForChild("PeelThrow")
local PeelSlip = Abilities:WaitForChild("PeelSlip")

-- Config
local COOLDOWN = 7
local THROW_SPEED = 60
local THROW_GRAVITY = 80
local MAX_FLIGHT = 1.5
local PEEL_LIFETIME = 18        -- how long the trap sits armed
local TRIGGER_RADIUS = 5.5      -- step-on detection (peel is bigger now)
local DAMAGE = 12               -- minor
local SLIDE_SPEED = 55          -- how fast they skid forward
local SLIDE_TIME = 0.9          -- ragdoll/slide duration
local FLIGHT_TIME = 0.85        -- fixed arc time -> we solve velocity to land on target
local MAX_RANGE = 90            -- clamp how far the peel can be thrown
local PEEL_YELLOW = Color3.fromRGB(245, 220, 70)
local PEEL_YELLOW_D = Color3.fromRGB(225, 196, 56)
local PEEL_FLESH = Color3.fromRGB(250, 244, 214)
local PEEL_TIP = Color3.fromRGB(120, 92, 38)

local lastUsed = {}
local slipping = {} -- [humanoid] = true (debounce)

local function buildPeel(pos)
	local peel = Instance.new("Model")
	peel.Name = "BananaPeel"
	peel.Parent = workspace

	-- center hub (bigger, rounded)
	local hub = Instance.new("Part")
	hub.Name = "Hub"
	hub.Shape = Enum.PartType.Ball
	hub.Size = Vector3.new(3, 1.1, 3)
	hub.Color = PEEL_YELLOW_D
	hub.Material = Enum.Material.SmoothPlastic
	hub.Anchored = true
	hub.CanCollide = false
	hub.CanQuery = false
	hub.CFrame = CFrame.new(pos)
	hub.Parent = peel
	peel.PrimaryPart = hub

	-- inner flesh disc (pale center, the eaten part)
	local flesh = Instance.new("Part")
	flesh.Name = "Flesh"
	flesh.Shape = Enum.PartType.Cylinder
	flesh.Size = Vector3.new(0.4, 3.4, 3.4)
	flesh.Color = PEEL_FLESH
	flesh.Material = Enum.Material.SmoothPlastic
	flesh.Anchored = true
	flesh.CanCollide = false
	flesh.CanQuery = false
	flesh.CFrame = CFrame.new(pos + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, 0, math.rad(90))
	flesh.Parent = peel

	-- 5 splayed, curling peel strips (each = base + curled tip) - bigger and detailed
	for i = 1, 5 do
		local a = (i / 5) * math.pi * 2 + 0.2
		local baseCF = CFrame.new(pos + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, a, 0)
		-- the long strip lying on the ground
		local strip = Instance.new("Part")
		strip.Name = "PeelStrip"
		strip.Size = Vector3.new(1.7, 0.5, 5.5)
		strip.Color = (i % 2 == 0) and PEEL_YELLOW or PEEL_YELLOW_D
		strip.Material = Enum.Material.SmoothPlastic
		strip.Anchored = true
		strip.CanCollide = false
		strip.CanQuery = false
		strip.CFrame = baseCF * CFrame.new(0, 0, 2.3) * CFrame.Angles(math.rad(6), 0, 0)
		strip.Parent = peel
		-- pale underside accent
		local under = Instance.new("Part")
		under.Name = "StripUnder"
		under.Size = Vector3.new(1.0, 0.2, 5.2)
		under.Color = PEEL_FLESH
		under.Material = Enum.Material.SmoothPlastic
		under.Anchored = true
		under.CanCollide = false
		under.CanQuery = false
		under.CFrame = strip.CFrame * CFrame.new(0, 0.28, 0)
		under.Parent = peel
		-- curled-up tip at the end of each strip
		local tip = Instance.new("Part")
		tip.Name = "PeelTip"
		tip.Size = Vector3.new(1.5, 0.5, 1.8)
		tip.Color = strip.Color
		tip.Material = Enum.Material.SmoothPlastic
		tip.Anchored = true
		tip.CanCollide = false
		tip.CanQuery = false
		tip.CFrame = baseCF * CFrame.new(0, 0.55, 4.9) * CFrame.Angles(math.rad(50), 0, 0)
		tip.Parent = peel
	end

	-- little brown stem nub on top of the hub
	local stem = Instance.new("Part")
	stem.Name = "Stem"
	stem.Size = Vector3.new(0.7, 1.4, 0.7)
	stem.Color = PEEL_TIP
	stem.Material = Enum.Material.SmoothPlastic
	stem.Anchored = true
	stem.CanCollide = false
	stem.CanQuery = false
	stem.CFrame = CFrame.new(pos + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, 0, math.rad(12))
	stem.Parent = peel

	return peel
end

local function ragdollSlide(model, hum, root, dir)
	slipping[hum] = true
	local origAutoRotate = hum.AutoRotate
	local origPlatform = hum.PlatformStand

	hum.PlatformStand = true     -- limp ragdoll
	hum.AutoRotate = false

	-- spin the character as they skid (funny tumble)
	local tumble = Instance.new("BodyAngularVelocity")
	tumble.AngularVelocity = Vector3.new(math.random(-6, 6), math.random(-3, 3), math.random(8, 14))
	tumble.MaxTorque = Vector3.new(1, 1, 1) * 4e4
	tumble.P = 3000
	tumble.Parent = root

	-- slide forward in their movement direction
	local slide = Instance.new("BodyVelocity")
	slide.Velocity = dir * SLIDE_SPEED + Vector3.new(0, 8, 0)
	slide.MaxForce = Vector3.new(1, 1, 1) * 5e4
	slide.P = 2500
	slide.Parent = root
	Debris:AddItem(slide, SLIDE_TIME * 0.55)
	Debris:AddItem(tumble, SLIDE_TIME)

	task.delay(SLIDE_TIME, function()
		if hum and hum.Parent then
			hum.PlatformStand = origPlatform
			hum.AutoRotate = origAutoRotate
		end
		slipping[hum] = nil
	end)
end

PeelThrow.OnServerEvent:Connect(function(caster, targetPos)
	local now = tick()
	if lastUsed[caster] and now - lastUsed[caster] < COOLDOWN - 0.1 then return end
	if typeof(targetPos) ~= "Vector3" then return end

	local char = caster.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	lastUsed[caster] = now

	-- clamp the landing target to MAX_RANGE from the thrower
	local flatOff = Vector3.new(targetPos.X - root.Position.X, 0, targetPos.Z - root.Position.Z)
	if flatOff.Magnitude > MAX_RANGE then
		local clamped = root.Position + flatOff.Unit * MAX_RANGE
		targetPos = Vector3.new(clamped.X, targetPos.Y, clamped.Z)
	end
	local flatDir = flatOff.Magnitude > 0.01 and flatOff.Unit or root.CFrame.LookVector

	local origin = root.Position + flatDir * 3 + Vector3.new(0, 3, 0)
	local g = Vector3.new(0, -THROW_GRAVITY, 0)

	-- solve initial velocity so the peel reaches targetPos in exactly FLIGHT_TIME
	-- pos(t) = origin + v*t + 0.5*g*t^2  =>  v = (target - origin - 0.5*g*t^2) / t
	local delta = targetPos - origin
	local vel = (delta - 0.5 * g * FLIGHT_TIME * FLIGHT_TIME) / FLIGHT_TIME

	local tossPeel = buildPeel(origin)
	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = {char, tossPeel}
	rp.FilterType = Enum.RaycastFilterType.Exclude

	task.spawn(function()
		local pos = origin
		local v = vel
		local elapsed = 0
		local spin = 0
		while elapsed < FLIGHT_TIME do
			local dt = RunService.Heartbeat:Wait()
			elapsed += dt
			spin += dt * 12
			local newPos = pos + v * dt
			v = v + g * dt
			-- stop early if we hit something solid on the way
			local hit = workspace:Raycast(pos, newPos - pos, rp)
			if hit then pos = hit.Position; break end
			pos = newPos
			tossPeel:PivotTo(CFrame.new(pos) * CFrame.Angles(spin, spin * 0.6, 0))
		end
		-- settle flat on the ground at the landing point
		local groundHit = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -14, 0), rp)
		local gy = groundHit and groundHit.Position.Y or pos.Y
		tossPeel:Destroy()
		local armed = buildPeel(Vector3.new(pos.X, gy + 0.2, pos.Z))
		local center = Vector3.new(pos.X, gy, pos.Z)

		-- arm the trap: watch for any non-caster stepping on it
		local startT = tick()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			if not armed.Parent then conn:Disconnect() return end
			if tick() - startT > PEEL_LIFETIME then
				conn:Disconnect()
				for _, p in ipairs(armed:GetChildren()) do
					if p:IsA("BasePart") then TweenService:Create(p, TweenInfo.new(0.5), {Transparency = 1}):Play() end
				end
				Debris:AddItem(armed, 0.6)
				return
			end
			for _, model in ipairs(workspace:GetChildren()) do
				if model:IsA("Model") and model ~= char and model ~= armed then
					local mHum = model:FindFirstChildOfClass("Humanoid")
					local mRoot = model:FindFirstChild("HumanoidRootPart")
					if mHum and mRoot and mHum.Health > 0 and not slipping[mHum] then
						local d = mRoot.Position - center
						if math.abs(d.Y) < 5 and Vector3.new(d.X, 0, d.Z).Magnitude <= TRIGGER_RADIUS then
							conn:Disconnect()
							-- direction they were moving (fallback to facing)
							local hv = mRoot.AssemblyLinearVelocity
							local slideDir = Vector3.new(hv.X, 0, hv.Z)
							if slideDir.Magnitude < 3 then
								slideDir = Vector3.new(mRoot.CFrame.LookVector.X, 0, mRoot.CFrame.LookVector.Z)
							end
							if slideDir.Magnitude < 0.01 then slideDir = flatDir end
							slideDir = slideDir.Unit
							mHum:TakeDamage(DAMAGE)
							ragdollSlide(model, mHum, mRoot, slideDir)
							-- tell clients to play the slip whoosh on the victim
							PeelSlip:FireAllClients(mRoot.Position)
							-- peel flies off comically
							for _, p in ipairs(armed:GetChildren()) do
								if p:IsA("BasePart") then
									p.Anchored = false
									p.CanCollide = false
									p.AssemblyLinearVelocity = Vector3.new(math.random(-12,12), 14, math.random(-12,12))
								end
							end
							Debris:AddItem(armed, 1.2)
							break
						end
					end
				end
			end
		end)
	end)
end)

print("PeelTrapHandler loaded!")
