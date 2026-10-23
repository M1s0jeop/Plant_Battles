-- ThicketHandler: slam the ground and erupt a massive circular thicket of
-- wild vines around you. Enemies caught in the zone are weighed down -
-- jump nearly removed and movement speed cut in half. The caster is immune.

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Abilities = RS:WaitForChild("Abilities")
local VineThicket = Abilities:WaitForChild("VineThicket")

-- Config
local COOLDOWN = 12
local DURATION = 7
local RADIUS = 16
local VINE_COUNT = 30
local WEIGHED_JUMPPOWER = 5    -- from default 50: barely a hop
local WEIGHED_JUMPHEIGHT = 1   -- R15 JumpHeight equivalent
local VINE_GREEN = Color3.fromRGB(40, 125, 40)
local VINE_DARK = Color3.fromRGB(30, 95, 35)

local lastUsed = {}

local function horizontalDist(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function groundY(pos, ignore)
	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = ignore
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local res = workspace:Raycast(pos + Vector3.new(0, 8, 0), Vector3.new(0, -50, 0), rp)
	return res and res.Position.Y or pos.Y
end

local function dirtBurst(pos)
	for i = 1, 12 do
		local chunk = Instance.new("Part")
		local s = math.random(15, 35) * 0.01
		chunk.Size = Vector3.new(s, s, s)
		chunk.Color = Color3.fromRGB(95, 70, 45)
		chunk.Material = Enum.Material.SmoothPlastic
		chunk.CFrame = CFrame.new(pos + Vector3.new(math.random(-6, 6), 0.5, math.random(-6, 6)))
		chunk.AssemblyLinearVelocity = Vector3.new(math.random(-15, 15), math.random(15, 30), math.random(-15, 15))
		chunk.CanCollide = false
		chunk.CanQuery = false
		chunk.Parent = workspace
		Debris:AddItem(chunk, 1)
		TweenService:Create(chunk, TweenInfo.new(1), {Transparency = 1}):Play()
	end
end

VineThicket.OnServerEvent:Connect(function(caster)
	local now = tick()
	if lastUsed[caster] and now - lastUsed[caster] < COOLDOWN - 0.1 then return end

	local char = caster.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	lastUsed[caster] = now

	local center = root.Position
	local baseY = groundY(center, {char})

	local folder = Instance.new("Folder")
	folder.Name = "VineThicket_" .. caster.Name
	folder.Parent = workspace

	dirtBurst(Vector3.new(center.X, baseY, center.Z))

	-- erupting tangled vines scattered across the whole zone
	for i = 1, VINE_COUNT do
		local a = math.random() * math.pi * 2
		local r = math.sqrt(math.random()) * (RADIUS - 1)  -- sqrt for even area spread
		local pos = Vector3.new(center.X + math.cos(a) * r, 0, center.Z + math.sin(a) * r)
		local gy = groundY(pos, {char, folder})
		local height = math.random(20, 55) * 0.1
		local lean = math.rad(math.random(-35, 35))
		local lean2 = math.rad(math.random(-35, 35))

		local vine = Instance.new("Part")
		vine.Name = "WildVine"
		vine.Shape = Enum.PartType.Cylinder
		vine.Material = Enum.Material.Grass
		vine.Color = math.random() > 0.5 and VINE_GREEN or VINE_DARK
		vine.Anchored = true
		vine.CanCollide = false
		vine.CanQuery = false
		vine.Size = Vector3.new(0.2, 0.45, 0.45)
		vine.CFrame = CFrame.new(pos.X, gy + 0.1, pos.Z)
			* CFrame.Angles(lean2, 0, math.rad(90) + lean)
		vine.Parent = folder

		-- erupt upward with slight random delay for a rolling wave feel
		task.delay(math.random() * 0.35, function()
			if not vine.Parent then return end
			TweenService:Create(vine, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = Vector3.new(height, 0.45, 0.45),
				CFrame = CFrame.new(pos.X, gy + height / 2, pos.Z)
					* CFrame.Angles(lean2, 0, math.rad(90) + lean),
			}):Play()
		end)
	end

	-- zone effect: weigh down every enemy inside
	local affected = {} -- [model] = {hum, origWS, origJP, origJH, origUseJP}
	local startTime = tick()

	local function release(model)
		local d = affected[model]
		if not d then return end
		if d.hum and d.hum.Parent then
			d.hum.WalkSpeed = d.origWS
			d.hum.JumpPower = d.origJP
			d.hum.JumpHeight = d.origJH
		end
		affected[model] = nil
	end

	local conn
	conn = RunService.Heartbeat:Connect(function()
		if tick() - startTime > DURATION then
			conn:Disconnect()
			for model in pairs(affected) do release(model) end
			-- vines sink back into the ground
			for _, vine in ipairs(folder:GetChildren()) do
				TweenService:Create(vine, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					CFrame = vine.CFrame - Vector3.new(0, vine.Size.X, 0),
					Transparency = 1,
				}):Play()
			end
			Debris:AddItem(folder, 0.7)
			return
		end

		for _, model in ipairs(workspace:GetChildren()) do
			if not model:IsA("Model") or model == caster.Character then continue end
			local mRoot = model:FindFirstChild("HumanoidRootPart")
			local mHum = model:FindFirstChildOfClass("Humanoid")
			if not mRoot or not mHum or mHum.Health <= 0 then continue end

			local inside = horizontalDist(mRoot.Position, center) <= RADIUS
				and math.abs(mRoot.Position.Y - baseY) <= 10
			local data = affected[model]

			if inside and not data then
				affected[model] = {
					hum = mHum,
					origWS = mHum.WalkSpeed,
					origJP = mHum.JumpPower,
					origJH = mHum.JumpHeight,
				}
				mHum.WalkSpeed = mHum.WalkSpeed / 2  -- cut in half
				mHum.JumpPower = WEIGHED_JUMPPOWER
				mHum.JumpHeight = WEIGHED_JUMPHEIGHT
			elseif not inside and data then
				release(model)
			end
		end
	end)
end)

print("ThicketHandler loaded!")
