-- TomatoHandler: lob a tomato in a slow ballistic arc toward the aimed point.
-- Direct hit: damage + slow + red tomato splat on the victim's screen.
-- Ground/wall hit: juicy splash.

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Abilities = RS:WaitForChild("Abilities")
local TomatoThrow = Abilities:WaitForChild("TomatoThrow")
local TomatoSplat = Abilities:WaitForChild("TomatoSplat")

-- Config
local COOLDOWN = 3
local DAMAGE = 20
local SLOW_WALKSPEED = 8
local SLOW_DURATION = 2
local LOB_SPEED = 55          -- average flight speed (lower = slower, floatier arc)
local GRAVITY = 60            -- custom gravity: lower than Roblox's = higher curve
local MAX_FLIGHT_TIME = 4
local MAX_TARGET_DIST = 250

local lastUsed = {}
local slowedVictims = {} -- [humanoid] = original WalkSpeed

local function spawnSplash(pos)
	-- red chunks flying out
	for i = 1, 8 do
		local chunk = Instance.new("Part")
		local s = math.random(20, 45) * 0.01
		chunk.Size = Vector3.new(s, s, s)
		chunk.Color = Color3.fromRGB(200, 30, 25)
		chunk.Material = Enum.Material.SmoothPlastic
		chunk.CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * math.pi, math.random() * math.pi, math.random() * math.pi)
		chunk.AssemblyLinearVelocity = Vector3.new(math.random(-18, 18), math.random(8, 22), math.random(-18, 18))
		chunk.CanCollide = false
		chunk.CanQuery = false
		chunk.Parent = workspace
		Debris:AddItem(chunk, 1)
		TweenService:Create(chunk, TweenInfo.new(1), {Transparency = 1, Size = Vector3.new(0.05, 0.05, 0.05)}):Play()
	end

	-- flat red splat that spreads on the ground below the impact
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = {}
	local res = workspace:Raycast(pos + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), rp)
	if res then
		local splat = Instance.new("Part")
		splat.Name = "TomatoGroundSplat"
		splat.Shape = Enum.PartType.Cylinder
		splat.Size = Vector3.new(0.1, 1, 1)
		splat.Color = Color3.fromRGB(190, 25, 20)
		splat.Material = Enum.Material.SmoothPlastic
		splat.Transparency = 0.15
		splat.Anchored = true
		splat.CanCollide = false
		splat.CanQuery = false
		splat.CFrame = CFrame.new(res.Position + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90))
		splat.Parent = workspace
		TweenService:Create(splat, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Size = Vector3.new(0.1, 6, 6)}):Play()
		task.delay(1.4, function()
			TweenService:Create(splat, TweenInfo.new(0.6), {Transparency = 1}):Play()
		end)
		Debris:AddItem(splat, 2.2)
	end
end

local function applySlow(victimHuman)
	if slowedVictims[victimHuman] == nil then
		slowedVictims[victimHuman] = victimHuman.WalkSpeed
	end
	victimHuman.WalkSpeed = math.min(victimHuman.WalkSpeed, SLOW_WALKSPEED)
	task.delay(SLOW_DURATION, function()
		local orig = slowedVictims[victimHuman]
		if orig ~= nil and victimHuman.Parent then
			-- only restore if nothing else changed their speed meanwhile
			if victimHuman.WalkSpeed <= SLOW_WALKSPEED then
				victimHuman.WalkSpeed = orig
			end
		end
		slowedVictims[victimHuman] = nil
	end)
end

TomatoThrow.OnServerEvent:Connect(function(caster, targetPoint)
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
	-- pick a flight time from distance, then solve the launch velocity so the
	-- tomato lands exactly on the target point under our custom gravity = the curve
	local flightTime = math.clamp(delta.Magnitude / LOB_SPEED, 0.45, 2.2)
	local g = Vector3.new(0, -GRAVITY, 0)
	local vel = (delta - 0.5 * g * flightTime * flightTime) / flightTime

	-- the tomato itself
	local tomato = Instance.new("Part")
	tomato.Name = "Tomato_" .. caster.Name
	tomato.Shape = Enum.PartType.Ball
	tomato.Size = Vector3.new(1.3, 1.3, 1.3)
	tomato.Color = Color3.fromRGB(210, 35, 30)
	tomato.Material = Enum.Material.SmoothPlastic
	tomato.Anchored = true
	tomato.CanCollide = false
	tomato.CanQuery = false
	tomato.CFrame = CFrame.new(origin)
	tomato.Parent = workspace

	local stem = Instance.new("Part")
	stem.Name = "Stem"
	stem.Size = Vector3.new(0.3, 0.25, 0.3)
	stem.Color = Color3.fromRGB(60, 140, 50)
	stem.Material = Enum.Material.SmoothPlastic
	stem.Anchored = true
	stem.CanCollide = false
	stem.CanQuery = false
	stem.Parent = tomato

	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = {char, tomato}
	rp.FilterType = Enum.RaycastFilterType.Exclude

	-- manual ballistic simulation with swept raycasts so it can't tunnel through anyone
	task.spawn(function()
		local pos = origin
		local v = vel
		local elapsed = 0
		local spin = 0
		while elapsed < MAX_FLIGHT_TIME do
			local dt = RunService.Heartbeat:Wait()
			elapsed = elapsed + dt
			spin = spin + dt * 9

			local newVel = v + g * dt
			local newPos = pos + v * dt

			local result = workspace:Raycast(pos, newPos - pos, rp)
			if result then
				local model = result.Instance:FindFirstAncestorOfClass("Model")
				if model and model ~= char then
					local vHum = model:FindFirstChildOfClass("Humanoid")
					if vHum and vHum.Health > 0 then
						vHum:TakeDamage(DAMAGE)
						applySlow(vHum)
						local vPlayer = Players:GetPlayerFromCharacter(model)
						if vPlayer then
							TomatoSplat:FireClient(vPlayer)
						end
					end
				end
				spawnSplash(result.Position)
				break
			end

			pos = newPos
			v = newVel
			tomato.CFrame = CFrame.new(pos) * CFrame.Angles(spin, spin * 0.7, 0)
			stem.CFrame = tomato.CFrame * CFrame.new(0, 0.7, 0)
		end
		tomato:Destroy()
	end)
end)

print("TomatoHandler loaded!")
