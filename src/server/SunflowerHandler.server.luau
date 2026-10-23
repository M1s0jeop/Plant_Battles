-- SunflowerHandler: turn into a sunflower and channel a ramping damage beam.
-- Caster is heavily slowed. Damage ramps the longer the beam stays on the same
-- target (inferno tower style). Victims hit by the beam are slowed too.

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Abilities = RS:WaitForChild("Abilities")
local SunflowerStart = Abilities:WaitForChild("SunflowerStart")
local SunflowerAim = Abilities:WaitForChild("SunflowerAim")
local SunflowerStop = Abilities:WaitForChild("SunflowerStop")

-- Config
local DURATION = 6
local COOLDOWN = 5            -- starts when the beam ends
local CASTER_WALKSPEED = 4    -- heavy slow while channeling
local VICTIM_WALKSPEED = 8    -- slow applied to anyone the beam is hitting
local VICTIM_SLOW_LINGER = 0.4
local BEAM_RANGE = 150
local BASE_DPS = 10
local MAX_DPS = 50
local RAMP_TIME = 3           -- seconds on the same target to reach MAX_DPS

local sessions = {} -- [player] = session

local function makeSunflowerVisual(char)
	local head = char:FindFirstChild("Head")
	local parts = {}
	if head then
		-- brown flower center behind/above the head
		local center = Instance.new("Part")
		center.Name = "SunflowerCenter"
		center.Shape = Enum.PartType.Ball
		center.Size = Vector3.new(1.6, 1.6, 0.8)
		center.Color = Color3.fromRGB(90, 60, 20)
		center.Material = Enum.Material.SmoothPlastic
		center.CanCollide = false
		center.CanQuery = false
		center.Massless = true
		center.CFrame = head.CFrame * CFrame.new(0, 0.4, 0.7)
		center.Parent = char
		local w = Instance.new("WeldConstraint")
		w.Part0 = head; w.Part1 = center; w.Parent = center
		table.insert(parts, center)

		-- yellow petals in a ring
		for i = 1, 10 do
			local angle = (i / 10) * math.pi * 2
			local petal = Instance.new("Part")
			petal.Name = "SunflowerPetal"
			petal.Size = Vector3.new(0.5, 1.3, 0.15)
			petal.Color = Color3.fromRGB(255, 210, 40)
			petal.Material = Enum.Material.SmoothPlastic
			petal.CanCollide = false
			petal.CanQuery = false
			petal.Massless = true
			petal.CFrame = head.CFrame * CFrame.new(0, 0.4, 0.75)
				* CFrame.Angles(0, 0, angle)
				* CFrame.new(0, 1.2, 0)
			petal.Parent = char
			local pw = Instance.new("WeldConstraint")
			pw.Part0 = head; pw.Part1 = petal; pw.Parent = petal
			table.insert(parts, petal)
		end
	end

	-- green glow so the transformation reads from any angle
	local hl = Instance.new("Highlight")
	hl.FillColor = Color3.fromRGB(60, 180, 60)
	hl.FillTransparency = 0.65
	hl.OutlineColor = Color3.fromRGB(255, 210, 40)
	hl.OutlineTransparency = 0.3
	hl.Parent = char
	table.insert(parts, hl)

	return parts
end

local function restoreVictim(victimData)
	if victimData.human and victimData.human.Parent then
		victimData.human.WalkSpeed = victimData.origWS
	end
end

local function endBeam(player)
	local sess = sessions[player]
	if not sess or not sess.active then return end
	sess.active = false
	sess.cooldownUntil = tick() + COOLDOWN

	if sess.conn then sess.conn:Disconnect() end
	if sess.beamPart then sess.beamPart:Destroy() end
	if sess.impactPart then sess.impactPart:Destroy() end
	for _, p in ipairs(sess.visualParts or {}) do
		if p and p.Parent then p:Destroy() end
	end
	for _, vd in pairs(sess.victims or {}) do
		restoreVictim(vd)
	end

	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = 16
			hum.JumpPower = 50
		end
	end
end

SunflowerStart.OnServerEvent:Connect(function(player)
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
		aimDir = root.CFrame.LookVector,
		victims = {},      -- [model] = {human, origWS, lastHit}
		target = nil,      -- current ramp target
		lockTime = 0,
		dmgAcc = 0,
		startTime = tick(),
	}
	sessions[player] = sess

	hum.WalkSpeed = CASTER_WALKSPEED
	hum.JumpPower = 0
	sess.visualParts = makeSunflowerVisual(char)

	-- beam visual (slightly transparent, replicated to everyone)
	local beam = Instance.new("Part")
	beam.Name = "SunflowerBeam_" .. player.Name
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 220, 60)
	beam.Transparency = 0.35
	beam.Size = Vector3.new(0.9, 0.9, 1)
	beam.Parent = workspace
	sess.beamPart = beam

	local impact = Instance.new("Part")
	impact.Name = "SunflowerImpact"
	impact.Shape = Enum.PartType.Ball
	impact.Anchored = true
	impact.CanCollide = false
	impact.CanQuery = false
	impact.Material = Enum.Material.Neon
	impact.Color = Color3.fromRGB(255, 240, 120)
	impact.Transparency = 0.25
	impact.Size = Vector3.new(1.6, 1.6, 1.6)
	impact.Parent = workspace
	sess.impactPart = impact

	sess.conn = RunService.Heartbeat:Connect(function(dt)
		local c = player.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if not r or not h or h.Health <= 0 or tick() - sess.startTime > DURATION then
			endBeam(player)
			return
		end

		local origin = r.Position + Vector3.new(0, 1, 0)
		local dir = sess.aimDir
		if dir.Magnitude < 0.01 then dir = r.CFrame.LookVector end
		dir = dir.Unit

		local rp = RaycastParams.new()
		rp.FilterDescendantsInstances = {c, beam, impact}
		rp.FilterType = Enum.RaycastFilterType.Exclude
		local result = workspace:Raycast(origin, dir * BEAM_RANGE, rp)

		local hitPos = result and result.Position or (origin + dir * BEAM_RANGE)
		local length = (hitPos - origin).Magnitude

		beam.Size = Vector3.new(0.9, 0.9, length)
		beam.CFrame = CFrame.lookAt(origin, hitPos) * CFrame.new(0, 0, -length / 2)
		impact.Position = hitPos

		-- who did we hit?
		local hitModel, hitHuman = nil, nil
		if result then
			local model = result.Instance:FindFirstAncestorOfClass("Model")
			if model and model ~= c then
				local mh = model:FindFirstChildOfClass("Humanoid")
				if mh and mh.Health > 0 and model:FindFirstChild("HumanoidRootPart") then
					hitModel, hitHuman = model, mh
				end
			end
		end

		if hitModel then
			-- inferno ramp: damage grows while locked onto the same target
			if sess.target == hitModel then
				sess.lockTime = sess.lockTime + dt
			else
				sess.target = hitModel
				sess.lockTime = 0
				sess.dmgAcc = 0
			end
			local ramp = math.min(sess.lockTime, RAMP_TIME) / RAMP_TIME
			local dps = BASE_DPS + (MAX_DPS - BASE_DPS) * ramp
			sess.dmgAcc = sess.dmgAcc + dps * dt
			if sess.dmgAcc >= 1 then
				local whole = math.floor(sess.dmgAcc)
				sess.dmgAcc = sess.dmgAcc - whole
				hitHuman:TakeDamage(whole)
			end

			-- beam heats up visually with the ramp
			beam.Color = Color3.fromRGB(255, 220 - math.floor(ramp * 120), 60)
			beam.Size = Vector3.new(0.9 + ramp * 0.8, 0.9 + ramp * 0.8, length)

			-- slow the victim while they're being hit
			local vd = sess.victims[hitModel]
			if not vd then
				vd = {human = hitHuman, origWS = hitHuman.WalkSpeed, lastHit = tick()}
				sess.victims[hitModel] = vd
			end
			vd.lastHit = tick()
			if hitHuman.WalkSpeed > VICTIM_WALKSPEED then
				hitHuman.WalkSpeed = VICTIM_WALKSPEED
			end
		else
			sess.target = nil
			sess.lockTime = 0
			beam.Color = Color3.fromRGB(255, 220, 60)
		end

		-- release the slow shortly after a victim escapes the beam
		for model, vd in pairs(sess.victims) do
			if tick() - vd.lastHit > VICTIM_SLOW_LINGER then
				restoreVictim(vd)
				sess.victims[model] = nil
			end
		end
	end)
end)

SunflowerAim.OnServerEvent:Connect(function(player, dir)
	local sess = sessions[player]
	if not sess or not sess.active then return end
	if typeof(dir) ~= "Vector3" or dir.Magnitude < 0.01 then return end
	sess.aimDir = dir.Unit
end)

SunflowerStop.OnServerEvent:Connect(function(player)
	endBeam(player)
end)

game.Players.PlayerRemoving:Connect(function(player)
	endBeam(player)
	sessions[player] = nil
end)

print("SunflowerHandler loaded!")
