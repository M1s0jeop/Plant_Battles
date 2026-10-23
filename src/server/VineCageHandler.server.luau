-- VineCageHandler: grows a circular vine cage in front of the caster.
-- Anyone inside is trapped; trying to escape damages them and knocks them back in.

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local VineCage = RS.Abilities:WaitForChild("VineCage")

-- Config
local CAGE_RADIUS = 11
local NUM_BARS = 18
local BAR_HEIGHT = 16
local BAR_THICKNESS = 1.4
local GROW_INTERVAL = 0.07      -- delay between each bar spawning (slow generation)
local BAR_GROW_TIME = 0.5       -- how long each bar takes to rise
local CAGE_LIFETIME = 8         -- seconds the cage stays after fully formed
local ESCAPE_DAMAGE = 10
local DAMAGE_COOLDOWN = 0.6     -- per-victim damage tick limit
local PUSHBACK_FORCE = 45
local CAGE_DISTANCE = 14        -- how far in front of caster the cage center is
local COOLDOWN = 8

local lastUsed = {}

local function getGroundY(pos, ignore)
	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = ignore
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local result = workspace:Raycast(pos + Vector3.new(0, 10, 0), Vector3.new(0, -60, 0), rp)
	if result then return result.Position.Y end
	return pos.Y
end

local function makeBar(center, angle, groundY, folder)
	local x = center.X + math.cos(angle) * CAGE_RADIUS
	local z = center.Z + math.sin(angle) * CAGE_RADIUS

	local bar = Instance.new("Part")
	bar.Name = "VineBar"
	bar.Shape = Enum.PartType.Cylinder
	bar.Material = Enum.Material.Grass
	bar.Color = Color3.fromRGB(45, 140, 45)
	bar.Anchored = true
	bar.CanCollide = true
	bar.CanQuery = false
	-- Cylinder's length is along X, so rotate it to stand upright
	bar.Size = Vector3.new(0.2, BAR_THICKNESS, BAR_THICKNESS)
	bar.CFrame = CFrame.new(x, groundY + 0.1, z) * CFrame.Angles(0, 0, math.rad(90))
	bar.Parent = folder

	-- Grow upward
	local goalSize = Vector3.new(BAR_HEIGHT, BAR_THICKNESS, BAR_THICKNESS)
	local goalCFrame = CFrame.new(x, groundY + BAR_HEIGHT / 2, z) * CFrame.Angles(0, 0, math.rad(90))
	local tween = TweenService:Create(bar, TweenInfo.new(BAR_GROW_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = goalSize,
		CFrame = goalCFrame,
	})
	tween:Play()
	return bar
end

local function horizontalDist(a, b)
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

VineCage.OnServerEvent:Connect(function(caster)
	local now = tick()
	if lastUsed[caster] and now - lastUsed[caster] < COOLDOWN - 0.1 then return end
	lastUsed[caster] = now

	local casterChar = caster.Character
	if not casterChar then return end
	local casterRoot = casterChar:FindFirstChild("HumanoidRootPart")
	if not casterRoot then return end

	local look = casterRoot.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.01 then flatLook = Vector3.new(0, 0, -1) end
	flatLook = flatLook.Unit

	local center = casterRoot.Position + flatLook * CAGE_DISTANCE
	local groundY = getGroundY(center, {casterChar})
	center = Vector3.new(center.X, groundY, center.Z)

	local folder = Instance.new("Folder")
	folder.Name = "VineCage_" .. caster.Name
	folder.Parent = workspace

	local cageAlive = true

	-- Slowly generate bars around the circle
	task.spawn(function()
		for i = 1, NUM_BARS do
			if not cageAlive then return end
			local angle = (i / NUM_BARS) * math.pi * 2
			local barGroundY = getGroundY(Vector3.new(
				center.X + math.cos(angle) * CAGE_RADIUS,
				center.Y,
				center.Z + math.sin(angle) * CAGE_RADIUS
			), {casterChar, folder})
			makeBar(center, angle, barGroundY, folder)
			task.wait(GROW_INTERVAL)
		end
	end)

	-- Containment loop
	local trapped = {}        -- [model] = true
	local lastDamage = {}     -- [model] = tick
	local innerRadius = CAGE_RADIUS - 2

	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not cageAlive then conn:Disconnect() return end
		for _, model in ipairs(workspace:GetChildren()) do
			if model == casterChar or not model:IsA("Model") then continue end
			local root = model:FindFirstChild("HumanoidRootPart")
			local human = model:FindFirstChildOfClass("Humanoid")
			if not root or not human or human.Health <= 0 then continue end

			local dist = horizontalDist(root.Position, center)

			-- Anyone who steps inside becomes trapped
			if not trapped[model] and dist < innerRadius - 0.5 and root.Position.Y < center.Y + BAR_HEIGHT then
				trapped[model] = true
			end

			if trapped[model] then
				local escapingSide = dist > innerRadius
				local escapingTop = root.Position.Y > center.Y + BAR_HEIGHT - 3

				if escapingSide or escapingTop then
					-- Damage (rate limited)
					local t = tick()
					if not lastDamage[model] or t - lastDamage[model] > DAMAGE_COOLDOWN then
						lastDamage[model] = t
						human:TakeDamage(ESCAPE_DAMAGE)
					end

					-- Push back toward center
					local toCenter = (Vector3.new(center.X, root.Position.Y, center.Z) - root.Position)
					local pushDir
					if toCenter.Magnitude > 0.01 then
						pushDir = toCenter.Unit
					else
						pushDir = Vector3.new(0, 0, 0)
					end
					if escapingTop then
						pushDir = (pushDir + Vector3.new(0, -1.2, 0))
						if pushDir.Magnitude > 0.01 then pushDir = pushDir.Unit end
					end

					local bv = Instance.new("BodyVelocity")
					bv.Velocity = pushDir * PUSHBACK_FORCE
					bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
					bv.Parent = root
					Debris:AddItem(bv, 0.2)
				end
			end
		end
	end)

	-- Cage lifetime: forming time + lifetime, then sink and clean up
	local formingTime = NUM_BARS * GROW_INTERVAL + BAR_GROW_TIME
	task.delay(formingTime + CAGE_LIFETIME, function()
		cageAlive = false
		for _, bar in ipairs(folder:GetChildren()) do
			if bar:IsA("BasePart") then
				bar.CanCollide = false
				local sink = TweenService:Create(bar, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					CFrame = bar.CFrame - Vector3.new(0, BAR_HEIGHT, 0),
					Transparency = 1,
				})
				sink:Play()
			end
		end
		Debris:AddItem(folder, 0.8)
	end)
end)
