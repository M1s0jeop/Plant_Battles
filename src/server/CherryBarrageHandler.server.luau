-- CherryBarrageHandler: machine-gun stream of 6 small fast cherry tomatoes.
-- Low damage per hit, but: bonus "shred" damage vs Walnut Wall nuts (shields),
-- and each hit briefly staggers the victim - sustained fire keeps them
-- staggered, opening them up for a heavy follow-up ability.

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Abilities = RS:WaitForChild("Abilities")
local CherryBarrage = Abilities:WaitForChild("CherryBarrage")

-- Config
local COOLDOWN = 5
local SHOT_COUNT = 6
local SHOT_INTERVAL = 0.12    -- machine-gun cadence
local SHOT_SPEED = 90         -- fast little tomatoes
local SHOT_GRAVITY = 25       -- nearly flat trajectory
local SHOT_RANGE_TIME = 1.2   -- max flight time (~range cap)
local DAMAGE = 6              -- per cherry
local SHIELD_SHRED = 18       -- per cherry vs Walnut nuts
local STAGGER_SPEED = 4
local STAGGER_TIME = 0.35     -- refreshed by every consecutive hit
local SPREAD = math.rad(2.5)
local MAX_TARGET_DIST = 250

local CHERRY = Color3.fromRGB(220, 45, 40)

local lastUsed = {}
local staggered = {} -- [humanoid] = {orig = ws, untilT = tick}

local function hitPoof(pos)
	for i = 1, 4 do
		local d = Instance.new("Part")
		local s = math.random(10, 22) * 0.01
		d.Size = Vector3.new(s, s, s)
		d.Shape = Enum.PartType.Ball
		d.Color = CHERRY
		d.Material = Enum.Material.Glass
		d.Transparency = 0.15
		d.CFrame = CFrame.new(pos)
		d.AssemblyLinearVelocity = Vector3.new(math.random(-14, 14), math.random(6, 16), math.random(-14, 14))
		d.CanCollide = false
		d.CanQuery = false
		d.Parent = workspace
		Debris:AddItem(d, 0.5)
		TweenService:Create(d, TweenInfo.new(0.5), {Transparency = 1}):Play()
	end
end

local function applyStagger(hum)
	local entry = staggered[hum]
	if entry then
		entry.untilT = tick() + STAGGER_TIME -- refresh: sustained fire = sustained stagger
		return
	end
	staggered[hum] = {orig = hum.WalkSpeed, untilT = tick() + STAGGER_TIME}
	hum.WalkSpeed = math.min(hum.WalkSpeed, STAGGER_SPEED)
	task.spawn(function()
		while true do
			local e = staggered[hum]
			if not e then return end
			local remaining = e.untilT - tick()
			if remaining <= 0 then break end
			task.wait(remaining)
		end
		local e = staggered[hum]
		if e and hum.Parent then
			if hum.WalkSpeed <= STAGGER_SPEED then
				hum.WalkSpeed = e.orig
			end
		end
		staggered[hum] = nil
	end)
end

local function fireCherry(caster, char, origin, targetPoint)
	local baseDir = (targetPoint - origin)
	if baseDir.Magnitude < 0.5 then return end
	baseDir = baseDir.Unit

	-- random spread for the machine-gun feel
	local yaw = (math.random() - 0.5) * 2 * SPREAD
	local pitch = (math.random() - 0.5) * 2 * SPREAD
	local dir = (CFrame.lookAt(Vector3.zero, baseDir) * CFrame.Angles(pitch, yaw, 0)).LookVector

	local cherry = Instance.new("Part")
	cherry.Name = "CherryTomato"
	cherry.Shape = Enum.PartType.Ball
	cherry.Size = Vector3.new(0.6, 0.6, 0.6)
	cherry.Color = CHERRY
	cherry.Material = Enum.Material.SmoothPlastic
	cherry.Anchored = true
	cherry.CanCollide = false
	cherry.CanQuery = false
	cherry.Position = origin
	cherry.Parent = workspace

	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = {char, cherry}
	rp.FilterType = Enum.RaycastFilterType.Exclude

	task.spawn(function()
		local pos = origin
		local v = dir * SHOT_SPEED
		local g = Vector3.new(0, -SHOT_GRAVITY, 0)
		local elapsed = 0
		while elapsed < SHOT_RANGE_TIME do
			local dt = RunService.Heartbeat:Wait()
			elapsed = elapsed + dt
			local newVel = v + g * dt
			local newPos = pos + v * dt

			local result = workspace:Raycast(pos, newPos - pos, rp)
			if result then
				local model = result.Instance:FindFirstAncestorOfClass("Model")
				if model and model ~= char then
					local vHum = model:FindFirstChildOfClass("Humanoid")
					if vHum and vHum.Health > 0 then
						local isShield = model.Name:find("Walnut") ~= nil
						vHum:TakeDamage(isShield and SHIELD_SHRED or DAMAGE)
						if not isShield then
							applyStagger(vHum)
						end
					end
				end
				hitPoof(result.Position)
				break
			end

			pos = newPos
			v = newVel
			cherry.Position = pos
		end
		cherry:Destroy()
	end)
end

CherryBarrage.OnServerEvent:Connect(function(caster, targetPoint)
	local now = tick()
	if lastUsed[caster] and now - lastUsed[caster] < COOLDOWN - 0.1 then return end
	if typeof(targetPoint) ~= "Vector3" then return end

	local char = caster.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if (targetPoint - root.Position).Magnitude > MAX_TARGET_DIST then return end

	lastUsed[caster] = now

	task.spawn(function()
		for i = 1, SHOT_COUNT do
			local c = caster.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			if not r then return end
			local origin = r.Position + r.CFrame.LookVector * 1.5 + Vector3.new(0, 1.5, 0)
			fireCherry(caster, c, origin, targetPoint)
			task.wait(SHOT_INTERVAL)
		end
	end)
end)

print("CherryBarrageHandler loaded!")
