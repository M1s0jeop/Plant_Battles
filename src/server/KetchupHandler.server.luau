-- KetchupHandler: spray a line of ketchup on the ground in front of you.
-- Running along it gives YOU a big speed boost; enemies on it slip and
-- slide helplessly (flopping + uncontrolled skidding).

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Abilities = RS:WaitForChild("Abilities")
local KetchupSlick = Abilities:WaitForChild("KetchupSlick")

-- Config
local COOLDOWN = 10
local DURATION = 8
local SLICK_LENGTH = 45
local SLICK_WIDTH = 7
local CASTER_SPEED = 30       -- your speed while running on your own sauce
local SLIP_PUSH = 26          -- how hard enemies skid
local SLIP_FLOP_TIME = 0.45   -- how long each helpless flop lasts
local SLIP_FLOP_EVERY = 1.0   -- seconds between flops while on the slick
local KETCHUP = Color3.fromRGB(185, 28, 22)

local lastUsed = {}

KetchupSlick.OnServerEvent:Connect(function(caster)
	local now = tick()
	if lastUsed[caster] and now - lastUsed[caster] < COOLDOWN - 0.1 then return end

	local char = caster.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	lastUsed[caster] = now

	local look = root.CFrame.LookVector
	local dir = Vector3.new(look.X, 0, look.Z)
	if dir.Magnitude < 0.01 then dir = Vector3.new(0, 0, -1) end
	dir = dir.Unit
	local right = Vector3.new(-dir.Z, 0, dir.X)

	-- ground the line start just in front of the caster
	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = {char}
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local startProbe = root.Position + dir * 2
	local groundHit = workspace:Raycast(startProbe + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), rp)
	local groundY = groundHit and groundHit.Position.Y or (root.Position.Y - 3)
	local lineStart = Vector3.new(startProbe.X, groundY, startProbe.Z)

	local folder = Instance.new("Folder")
	folder.Name = "KetchupSlick_" .. caster.Name
	folder.Parent = workspace

	-- the sauce strip
	local strip = Instance.new("Part")
	strip.Name = "SauceStrip"
	strip.Size = Vector3.new(SLICK_WIDTH, 0.15, SLICK_LENGTH)
	strip.Color = KETCHUP
	strip.Material = Enum.Material.Glass
	strip.Transparency = 0.12
	strip.Reflectance = 0.08
	strip.Anchored = true
	strip.CanCollide = false
	strip.CanQuery = false
	strip.CFrame = CFrame.lookAt(lineStart + dir * (SLICK_LENGTH / 2) + Vector3.new(0, 0.08, 0),
		lineStart + dir * SLICK_LENGTH)
	strip.Parent = folder

	-- messy blobs along the edges so it looks sprayed, not painted
	for i = 1, 10 do
		local blob = Instance.new("Part")
		blob.Shape = Enum.PartType.Cylinder
		local bs = math.random(8, 20) * 0.1
		blob.Size = Vector3.new(0.12, bs, bs)
		blob.Color = KETCHUP
		blob.Material = Enum.Material.Glass
		blob.Transparency = 0.12
		blob.Anchored = true
		blob.CanCollide = false
		blob.CanQuery = false
		local along = math.random() * SLICK_LENGTH
		local side = (math.random() - 0.5) * (SLICK_WIDTH + 2)
		blob.CFrame = CFrame.new(lineStart + dir * along + right * side + Vector3.new(0, 0.1, 0))
			* CFrame.Angles(0, 0, math.rad(90))
		blob.Parent = folder
	end

	-- zone logic
	local affected = {} -- [model] = {hum, origWS, lastFlop, isCaster}
	local startTime = tick()

	local function release(model)
		local data = affected[model]
		if not data then return end
		if data.hum and data.hum.Parent then
			data.hum.WalkSpeed = data.origWS
			data.hum.PlatformStand = false
		end
		affected[model] = nil
	end

	local function onSlick(pos)
		local rel = pos - lineStart
		local along = rel:Dot(dir)
		local lateral = rel:Dot(right)
		return along >= 0 and along <= SLICK_LENGTH
			and math.abs(lateral) <= SLICK_WIDTH / 2 + 0.5
			and math.abs(pos.Y - groundY) <= 7
	end

	local conn
	conn = RunService.Heartbeat:Connect(function()
		if tick() - startTime > DURATION then
			conn:Disconnect()
			for model in pairs(affected) do release(model) end
			for _, p in ipairs(folder:GetChildren()) do
				TweenService:Create(p, TweenInfo.new(0.8), {Transparency = 1}):Play()
			end
			Debris:AddItem(folder, 1)
			return
		end

		for _, model in ipairs(workspace:GetChildren()) do
			if not model:IsA("Model") then continue end
			local mRoot = model:FindFirstChild("HumanoidRootPart")
			local mHum = model:FindFirstChildOfClass("Humanoid")
			if not mRoot or not mHum or mHum.Health <= 0 then continue end

			local isOn = onSlick(mRoot.Position)
			local data = affected[model]

			if isOn and not data then
				affected[model] = {
					hum = mHum,
					origWS = mHum.WalkSpeed,
					lastFlop = 0,
					isCaster = (model == caster.Character),
				}
				data = affected[model]
			elseif not isOn and data then
				release(model)
				data = nil
			end

			if data then
				if data.isCaster then
					mHum.WalkSpeed = CASTER_SPEED
				else
					-- helpless slipping: periodic flop + uncontrolled skid
					local t = tick()
					if t - data.lastFlop > SLIP_FLOP_EVERY then
						data.lastFlop = t
						mHum.PlatformStand = true
						task.delay(SLIP_FLOP_TIME, function()
							if affected[model] == data and mHum.Parent then
								mHum.PlatformStand = false
							end
						end)

						-- skid in their current motion direction (or a random one if standing)
						local hv = mRoot.AssemblyLinearVelocity
						local skidDir = Vector3.new(hv.X, 0, hv.Z)
						if skidDir.Magnitude < 2 then
							local a = math.random() * math.pi * 2
							skidDir = Vector3.new(math.cos(a), 0, math.sin(a))
						else
							skidDir = skidDir.Unit
						end
						local bv = Instance.new("BodyVelocity")
						bv.Velocity = skidDir * SLIP_PUSH
						bv.MaxForce = Vector3.new(1e5, 0, 1e5)
						bv.Parent = mRoot
						Debris:AddItem(bv, SLIP_FLOP_TIME)
					end
				end
			end
		end
	end)
end)

print("KetchupHandler loaded!")
