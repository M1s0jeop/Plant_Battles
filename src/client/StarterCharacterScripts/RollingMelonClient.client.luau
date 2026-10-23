-- RollingMelonClient: transforms into a giant rolling watermelon, accelerating
-- over time and becoming harder to steer the faster you go.
-- Upon impacting an enemy or obstacle, splashes juicy red chunks, launches the enemy
-- into the air based on impact speed, and gives the caster a constant rebound jump up & back.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local char = script.Parent
local humanoidRoot = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")
local camera = workspace.CurrentCamera

local Abilities = RS:WaitForChild("Abilities")
local RollingMelonStart = Abilities:WaitForChild("RollingMelonStart")
local RollingMelonHit = Abilities:WaitForChild("RollingMelonHit")
local RollingMelonStop = Abilities:WaitForChild("RollingMelonStop")

local ABILITY_ID = "rolling_melon"
local COOLDOWN = 9
local lastUsed = -COOLDOWN

local START_SPEED = 25
local MAX_SPEED = 80
local ACCEL_RATE = 15.5 -- speed gained per second
local MAX_ROLL_TIME = 8.0
local HIT_CHECK_RADIUS = 3.6

local isRolling = false

local SLOT_KEYCODES = {
	[1] = Enum.KeyCode.Q,
	[2] = Enum.KeyCode.E,
	[3] = Enum.KeyCode.R,
	[4] = Enum.KeyCode.F,
}

local function getMyKey()
	if _G.EquippedAbilities then
		for s, id in pairs(_G.EquippedAbilities) do
			if id == ABILITY_ID then return SLOT_KEYCODES[s], s end
		end
	end
	return nil, nil
end

RunService.Heartbeat:Connect(function()
	_G.AbilityCooldowns = _G.AbilityCooldowns or {}
	_G.AbilityCooldowns[ABILITY_ID] = { lastUsed = lastUsed, cd = COOLDOWN }
end)

local function startRolling()
	if isRolling then return end
	if tick() - lastUsed < COOLDOWN then return end
	if humanoid.Health <= 0 then return end

	isRolling = true
	lastUsed = tick()

	RollingMelonStart:FireServer()

	-- Initial roll direction from camera / root look vector
	local look = camera.CFrame.LookVector
	local currentHeading = Vector3.new(look.X, 0, look.Z).Unit
	if currentHeading.Magnitude < 0.1 then
		currentHeading = humanoidRoot.CFrame.LookVector
	end

	-- Movement velocity control
	for _, c in ipairs(humanoidRoot:GetChildren()) do
		if c.Name == "MelonVelocity" or c.Name == "MelonReboundJump" then
			c:Destroy()
		end
	end

	local bv = Instance.new("BodyVelocity")
	bv.Name = "MelonVelocity"
	bv.MaxForce = Vector3.new(1e5, 0, 1e5) -- Let gravity keep character grounded on slopes
	bv.Velocity = currentHeading * START_SPEED
	bv.Parent = humanoidRoot

	-- Visual roll mesh / sphere locally
	local localBall = Instance.new("Part")
	localBall.Name = "LocalMelonBall"
	localBall.Shape = Enum.PartType.Ball
	localBall.Size = Vector3.new(6.0, 6.0, 6.0)
	localBall.Color = Color3.fromRGB(45, 130, 45)
	localBall.Material = Enum.Material.SmoothPlastic
	localBall.CanCollide = false
	localBall.CanQuery = false
	localBall.CanTouch = false
	localBall.Massless = true
	localBall.CFrame = humanoidRoot.CFrame
	localBall.Parent = workspace

	-- Local stripe details
	for i = 1, 6 do
		local a = (i / 6) * math.pi
		local stripe = Instance.new("Part")
		stripe.Name = "LocalStripe_" .. i
		stripe.Shape = Enum.PartType.Cylinder
		stripe.Size = Vector3.new(6.05, 0.45, 0.45)
		stripe.Color = Color3.fromRGB(115, 215, 85)
		stripe.Material = Enum.Material.SmoothPlastic
		stripe.CanCollide = false
		stripe.CanQuery = false
		stripe.CanTouch = false
		stripe.Massless = true
		stripe.CFrame = localBall.CFrame * CFrame.Angles(0, a, math.rad(90))
		stripe.Parent = localBall
		local sw = Instance.new("WeldConstraint")
		sw.Part0 = localBall
		sw.Part1 = stripe
		sw.Parent = stripe
	end

	local startTime = tick()
	local rollAngle = 0
	local rollConn

	local function stopRoll(hitPos, hitModel, speed, heading)
		if not isRolling then return end
		isRolling = false
		if rollConn then rollConn:Disconnect() end
		if bv and bv.Parent then bv:Destroy() end
		if localBall and localBall.Parent then localBall:Destroy() end

		if hitPos then
			RollingMelonHit:FireServer(hitPos, hitModel, speed, heading)
		else
			RollingMelonStop:FireServer(heading)
		end

		-- Constant client rebound jump up & back
		local flatBack = -Vector3.new(heading.X, 0, heading.Z).Unit
		local rebound = Instance.new("BodyVelocity")
		rebound.Name = "MelonReboundJump"
		rebound.Velocity = flatBack * 22 + Vector3.new(0, 32, 0)
		rebound.MaxForce = Vector3.new(1e5, 1e5, 1e5)
		rebound.Parent = humanoidRoot
		Debris:AddItem(rebound, 0.22)
	end

	rollConn = RunService.Heartbeat:Connect(function(dt)
		if not isRolling or humanoid.Health <= 0 or not char.Parent then
			stopRoll(nil, nil, 0, currentHeading)
			return
		end

		local elapsed = tick() - startTime
		if elapsed >= MAX_ROLL_TIME then
			stopRoll(humanoidRoot.Position, nil, MAX_SPEED, currentHeading)
			return
		end

		-- Speed increases over time
		local currentSpeed = math.clamp(START_SPEED + elapsed * ACCEL_RATE, START_SPEED, MAX_SPEED)
		local speedRatio = (currentSpeed - START_SPEED) / (MAX_SPEED - START_SPEED)

		-- Steering becomes harder / heavier as speed increases:
		-- Sharp steering (4.2 rad/s) at low speed down to heavy drift (0.75 rad/s) at max speed
		local maxTurnSpeed = math.clamp(4.2 - speedRatio * 3.45, 0.75, 4.2)

		-- Desired direction from camera look vector
		local camLook = camera.CFrame.LookVector
		local targetHeading = Vector3.new(camLook.X, 0, camLook.Z).Unit
		if targetHeading.Magnitude > 0.1 then
			-- Smoothly slerp/steer towards target
			local currentCFrame = CFrame.lookAt(Vector3.zero, currentHeading)
			local targetCFrame = CFrame.lookAt(Vector3.zero, targetHeading)
			local angleDiff = math.acos(math.clamp(currentHeading:Dot(targetHeading), -1, 1))
			local maxStep = maxTurnSpeed * dt
			local stepRatio = (angleDiff > 0.001) and math.min(1, maxStep / angleDiff) or 1
			local newCFrame = currentCFrame:Lerp(targetCFrame, stepRatio)
			currentHeading = newCFrame.LookVector.Unit
		end

		-- Apply velocity & orient character
		bv.Velocity = currentHeading * currentSpeed
		humanoidRoot.CFrame = CFrame.lookAt(humanoidRoot.Position, humanoidRoot.Position + currentHeading)

		-- Roll the watermelon ball forward matching speed
		rollAngle = rollAngle + (currentSpeed / 3.0) * dt
		localBall.CFrame = CFrame.new(humanoidRoot.Position)
			* CFrame.lookAt(Vector3.zero, currentHeading)
			* CFrame.Angles(-rollAngle, 0, 0)

		-- Collision detection: raycast in front for walls & enemies
		local rayOrigin = humanoidRoot.Position + Vector3.new(0, 0.5, 0)
		local checkDist = HIT_CHECK_RADIUS + currentSpeed * dt * 1.5
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.FilterDescendantsInstances = {char, localBall}

		local rayHit = workspace:Raycast(rayOrigin, currentHeading * checkDist, rp)
		if rayHit then
			local hitModel = rayHit.Instance:FindFirstAncestorOfClass("Model")
			local isEnemy = false
			if hitModel and hitModel ~= char then
				local h = hitModel:FindFirstChildOfClass("Humanoid")
				if h and h.Health > 0 then
					isEnemy = true
				end
			end

			-- If hit an enemy OR hit a solid wall facing against us
			local isSolidWall = rayHit.Normal:Dot(currentHeading) < -0.3
			if isEnemy or isSolidWall then
				stopRoll(rayHit.Position, isEnemy and hitModel or nil, currentSpeed, currentHeading)
				return
			end
		end

		-- Also check proximity to any enemy model within sphere
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		overlap.FilterDescendantsInstances = {char, localBall}
		for _, part in ipairs(workspace:GetPartBoundsInRadius(humanoidRoot.Position + currentHeading * 2.2, 3.2, overlap)) do
			local model = part:FindFirstAncestorOfClass("Model")
			if model and model ~= char then
				local h = model:FindFirstChildOfClass("Humanoid")
				if h and h.Health > 0 then
					stopRoll(part.Position, model, currentSpeed, currentHeading)
					return
				end
			end
		end
	end)
end

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	local myKey = getMyKey()
	if not myKey or input.KeyCode ~= myKey then return end

	if isRolling then
		-- Pressing again cancels roll with the slight rebound jump
		isRolling = false
	else
		startRolling()
	end
end)

print("RollingMelonClient loaded!")
