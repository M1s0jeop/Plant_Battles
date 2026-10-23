-- BoomerangHandler: a banana boomerang. Hold to charge -> flies farther, but a
-- farther throw takes longer to come back. It PIERCES enemies (damaging each),
-- and BOUNCES back early if it hits terrain/walls. Returns to the caster's hand.
-- The only cooldown is waiting for it to return (one out at a time per player).

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Abilities = RS:WaitForChild("Abilities")
local BoomerangThrow = Abilities:WaitForChild("BoomerangThrow")
local BoomerangReturn = Abilities:WaitForChild("BoomerangReturn")

-- Config
local MIN_RANGE = 30
local MAX_RANGE = 110
local SPEED = 95             -- travel speed (studs/s), constant out & back
local DAMAGE = 18            -- per enemy hit
local HIT_COOLDOWN = 0.4     -- same enemy can't be re-hit faster than this (per pass)
local SPIN = 25              -- visual spin rate
local BANANA = Color3.fromRGB(245, 220, 70)
local BANANA_TIP = Color3.fromRGB(120, 92, 38)

local active = {} -- [player] = true while a boomerang is out

local function buildBoomerang()
	local model = Instance.new("Model")
	model.Name = "BananaBoomerang"
	model.Parent = workspace
	-- two curved banana arms meeting at an elbow (boomerang shape)
	local hub = Instance.new("Part")
	hub.Name = "Hub"
	hub.Size = Vector3.new(1.6, 0.8, 1.6)
	hub.Color = BANANA
	hub.Material = Enum.Material.SmoothPlastic
	hub.Anchored = true
	hub.CanCollide = false
	hub.CanQuery = false
	hub.Parent = model
	model.PrimaryPart = hub
	for _, ang in ipairs({35, -35}) do
		local arm = Instance.new("Part")
		arm.Name = "Arm"
		arm.Size = Vector3.new(1.4, 0.7, 5)
		arm.Color = BANANA
		arm.Material = Enum.Material.SmoothPlastic
		arm.Anchored = true
		arm.CanCollide = false
		arm.CanQuery = false
		arm.CFrame = hub.CFrame * CFrame.Angles(0, math.rad(ang), 0) * CFrame.new(0, 0, -2.2)
		arm.Parent = model
		-- brown tip
		local tip = Instance.new("Part")
		tip.Size = Vector3.new(1.3, 0.7, 1.2)
		tip.Color = BANANA_TIP
		tip.Material = Enum.Material.SmoothPlastic
		tip.Anchored = true
		tip.CanCollide = false
		tip.CanQuery = false
		tip.CFrame = hub.CFrame * CFrame.Angles(0, math.rad(ang), 0) * CFrame.new(0, 0, -4.4)
		tip.Parent = model
	end
	return model
end

BoomerangThrow.OnServerEvent:Connect(function(caster, dir, chargeFrac)
	if active[caster] then return end -- one out at a time = the "cooldown"
	if typeof(dir) ~= "Vector3" then return end
	chargeFrac = math.clamp(tonumber(chargeFrac) or 0, 0, 1)

	local char = caster.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	active[caster] = true

	-- use the FULL 3D aim direction (including up/down pitch), not flattened
	local aimDir = dir
	if aimDir.Magnitude < 0.01 then aimDir = root.CFrame.LookVector end
	aimDir = aimDir.Unit

	local range = MIN_RANGE + (MAX_RANGE - MIN_RANGE) * chargeFrac
	local model = buildBoomerang()
	local startPos = root.Position + Vector3.new(0, 2.5, 0) + aimDir * 2
	model:PivotTo(CFrame.new(startPos))

	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = {char, model}
	rp.FilterType = Enum.RaycastFilterType.Exclude

	local hitTimes = {} -- [humanoid] = last hit tick (re-damage on the return pass)

	task.spawn(function()
		local pos = startPos
		local phase = "out"        -- out -> back
		local traveled = 0
		local spin = 0
		local apex = startPos + aimDir * range

		while model.Parent do
			local dt = RunService.Heartbeat:Wait()
			spin = spin + dt * SPIN

			local target, moveDir
			if phase == "out" then
				moveDir = aimDir
			else
				-- home back to the (possibly moved) caster
				local c = caster.Character
				local cr = c and c:FindFirstChild("HumanoidRootPart")
				if not cr then model:Destroy(); active[caster] = nil; return end
				local toCaster = (cr.Position + Vector3.new(0, 2.5, 0)) - pos
				if toCaster.Magnitude < 4 then
					-- caught!
					model:Destroy()
					active[caster] = nil
					BoomerangReturn:FireClient(caster)
					return
				end
				moveDir = toCaster.Unit
			end

			local step = SPEED * dt
			local newPos = pos + moveDir * step

			-- terrain/wall bounce: if the path hits a non-character solid, flip to return
			if phase == "out" then
				local hit = workspace:Raycast(pos, newPos - pos, rp)
				if hit then
					local m = hit.Instance:FindFirstAncestorOfClass("Model")
					local isChar = m and m:FindFirstChildOfClass("Humanoid")
					if not isChar then
						phase = "back"   -- bounced off terrain
						pos = hit.Position - moveDir * 1
						model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, spin, 0))
						continue
					end
				end
				traveled = traveled + step
				if traveled >= range then phase = "back" end  -- reached apex, come back
			end

			pos = newPos
			model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, spin, 0))

			-- PIERCE: damage every enemy in contact, no stopping
			for _, em in ipairs(workspace:GetChildren()) do
				if em:IsA("Model") and em ~= char and em ~= model then
					local eHum = em:FindFirstChildOfClass("Humanoid")
					local eRoot = em:FindFirstChild("HumanoidRootPart")
					if eHum and eRoot and eHum.Health > 0 then
						if (eRoot.Position - pos).Magnitude <= 4.5 then
							local last = hitTimes[eHum]
							if not last or tick() - last > HIT_COOLDOWN then
								hitTimes[eHum] = tick()
								eHum:TakeDamage(DAMAGE)
							end
						end
					end
				end
			end
		end
		active[caster] = nil
	end)
end)

game.Players.PlayerRemoving:Connect(function(p) active[p] = nil end)

print("BoomerangHandler loaded!")
