-- SunflareHandler: throw a sunflare flash grenade on an arc. It bounces off
-- surfaces and detonates on a fixed fuse (CS-style). On detonation the server
-- broadcasts the blast position to EVERY client, and each client decides how
-- badly IT got flashed based on its own camera view (line of sight + how
-- directly it was looking at the blast). See SunflareClient for that half.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Abilities = RS:WaitForChild("Abilities")
local FlashThrow = Abilities:WaitForChild("FlashThrow")
local FlashDetonate = Abilities:WaitForChild("FlashDetonate")

-- ===== Config =====
local COOLDOWN = 12
local FUSE = 1.6            -- time from throw to detonation (fixed, like CS)
local LOB_SPEED = 65
local GRAVITY = 80
local BOUNCE_DAMP = 0.5     -- velocity kept after bouncing off a surface
local MAX_TARGET_DIST = 260
local BODY_COLOR = Color3.fromRGB(240, 205, 60)

local lastUsed = {}

local function detonateVFX(pos)
	-- blinding white/gold core
	local core = Instance.new("Part")
	core.Shape = Enum.PartType.Ball
	core.Anchored = true
	core.CanCollide = false
	core.CanQuery = false
	core.Material = Enum.Material.Neon
	core.Color = Color3.fromRGB(255, 255, 245)
	core.Transparency = 0
	core.Size = Vector3.new(2, 2, 2)
	core.CFrame = CFrame.new(pos)
	core.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 255, 240)
	light.Brightness = 12
	light.Range = 60
	light.Parent = core

	TweenService:Create(core, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(16, 16, 16),
		Transparency = 1,
	}):Play()
	TweenService:Create(light, TweenInfo.new(0.45), { Brightness = 0 }):Play()
	Debris:AddItem(core, 0.5)

	-- gold sparks
	for i = 1, 14 do
		local spark = Instance.new("Part")
		local s = math.random(12, 28) * 0.01
		spark.Size = Vector3.new(s, s, s)
		spark.Shape = Enum.PartType.Ball
		spark.Color = BODY_COLOR
		spark.Material = Enum.Material.Neon
		spark.CFrame = CFrame.new(pos)
		spark.CanCollide = false
		spark.CanQuery = false
		spark.AssemblyLinearVelocity = Vector3.new(math.random(-40, 40), math.random(15, 45), math.random(-40, 40))
		spark.Parent = workspace
		Debris:AddItem(spark, 0.7)
		TweenService:Create(spark, TweenInfo.new(0.7), { Transparency = 1 }):Play()
	end
end

FlashThrow.OnServerEvent:Connect(function(caster, targetPoint)
	local now = tick()
	if lastUsed[caster] and now - lastUsed[caster] < COOLDOWN - 0.1 then return end
	if typeof(targetPoint) ~= "Vector3" then return end

	local char = caster.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return end
	if (targetPoint - root.Position).Magnitude > MAX_TARGET_DIST then return end

	lastUsed[caster] = now

	local origin = root.Position + root.CFrame.LookVector * 1.5 + Vector3.new(0, 2, 0)
	local delta = targetPoint - origin
	local flightTime = math.clamp(delta.Magnitude / LOB_SPEED, 0.35, 1.4)
	local g = Vector3.new(0, -GRAVITY, 0)
	local vel = (delta - 0.5 * g * flightTime * flightTime) / flightTime

	-- the grenade: yellow canister with a dark band
	local nade = Instance.new("Part")
	nade.Name = "Sunflare_" .. caster.Name
	nade.Shape = Enum.PartType.Cylinder
	nade.Size = Vector3.new(1.3, 0.8, 0.8)
	nade.Color = BODY_COLOR
	nade.Material = Enum.Material.Metal
	nade.Anchored = true
	nade.CanCollide = false
	nade.CanQuery = false
	nade.CFrame = CFrame.new(origin)
	nade.Parent = workspace

	local band = Instance.new("Part")
	band.Shape = Enum.PartType.Cylinder
	band.Size = Vector3.new(0.5, 0.86, 0.86)
	band.Color = Color3.fromRGB(40, 35, 25)
	band.Material = Enum.Material.Metal
	band.Anchored = true
	band.CanCollide = false
	band.CanQuery = false
	band.Parent = nade

	local glow = Instance.new("PointLight")
	glow.Color = BODY_COLOR
	glow.Brightness = 2
	glow.Range = 8
	glow.Parent = nade

	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = {char, nade}
	rp.FilterType = Enum.RaycastFilterType.Exclude

	task.spawn(function()
		local pos = origin
		local v = vel
		local elapsed = 0
		local spin = 0
		while elapsed < FUSE do
			local dt = RunService.Heartbeat:Wait()
			elapsed = elapsed + dt
			spin = spin + dt * 12

			local newVel = v + g * dt
			local newPos = pos + v * dt
			local result = workspace:Raycast(pos, newPos - pos, rp)
			if result then
				-- bounce: reflect velocity across the surface normal and damp it
				pos = result.Position + result.Normal * 0.3
				v = (v - 2 * v:Dot(result.Normal) * result.Normal) * BOUNCE_DAMP
			else
				pos = newPos
				v = newVel
			end
			nade.CFrame = CFrame.new(pos) * CFrame.Angles(spin, spin * 0.7, 0) * CFrame.Angles(0, 0, math.rad(90))
			band.CFrame = CFrame.new(pos) * CFrame.Angles(spin, spin * 0.7, 0) * CFrame.Angles(0, 0, math.rad(90))
		end

		nade:Destroy()
		detonateVFX(pos)
		-- tell everyone where it went off; each client flashes itself.
		FlashDetonate:FireAllClients(pos)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	lastUsed[player] = nil
end)

print("SunflareHandler loaded!")
