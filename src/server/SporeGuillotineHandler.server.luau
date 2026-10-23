-- SporeGuillotineHandler: high-damage melee slash with a toxic spore burst
-- to the face. If the victim is already trapped or stunned (vine cage,
-- grapple root, flytrap, ketchup flop, cherry stagger...), it deals DOUBLE
-- damage as a finisher.

local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Abilities = RS:WaitForChild("Abilities")
local SporeGuillotine = Abilities:WaitForChild("SporeGuillotine")

-- Config
local COOLDOWN = 6
local RANGE = 8
local CONE_DOT = 0.55
local BASE_DAMAGE = 35
local FINISHER_MULT = 2       -- double damage vs trapped/stunned targets
local STUN_WALKSPEED = 4.5    -- at or below this counts as "stunned"
local CAGE_TRAP_RADIUS = 9    -- inside a VineCage inner ring counts as trapped

local SPORE_PURPLE = Color3.fromRGB(150, 80, 200)
local SPORE_GREEN = Color3.fromRGB(120, 230, 110)

local lastUsed = {}

local function horizontalDist(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- is this model currently trapped or stunned by ANY of the game's CC?
local function isTrappedOrStunned(model, root, hum)
	if hum.PlatformStand then return true, "flopped" end
	if hum.WalkSpeed <= STUN_WALKSPEED then return true, "rooted/staggered" end
	if root:FindFirstChild("SwallowWeld") then return true, "swallowed" end
	-- standing inside an active vine cage?
	for _, f in ipairs(workspace:GetChildren()) do
		if f:IsA("Folder") and f.Name:match("^VineCage_") then
			local sum, n = Vector3.zero, 0
			for _, bar in ipairs(f:GetChildren()) do
				if bar:IsA("BasePart") then sum += bar.Position n += 1 end
			end
			if n > 0 then
				local center = sum / n
				if horizontalDist(root.Position, center) <= CAGE_TRAP_RADIUS then
					return true, "caged"
				end
			end
		end
	end
	return false, nil
end

local function sporeBurst(pos, big)
	local count = big and 14 or 8
	for i = 1, count do
		local spore = Instance.new("Part")
		local s = math.random(12, 28) * 0.01 * (big and 1.4 or 1)
		spore.Size = Vector3.new(s, s, s)
		spore.Shape = Enum.PartType.Ball
		spore.Color = i % 3 == 0 and SPORE_GREEN or SPORE_PURPLE
		spore.Material = Enum.Material.Neon
		spore.Transparency = 0.2
		spore.CFrame = CFrame.new(pos)
		spore.AssemblyLinearVelocity = Vector3.new(math.random(-14, 14), math.random(4, 14), math.random(-14, 14))
		spore.CanCollide = false
		spore.CanQuery = false
		spore.Parent = workspace
		Debris:AddItem(spore, 0.7)
		TweenService:Create(spore, TweenInfo.new(0.7), {Transparency = 1}):Play()
	end
end

local function finisherPopup(victimRoot)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 150, 0, 38)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.AlwaysOnTop = true
	bb.Parent = victimRoot
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "FINISHER!"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = SPORE_PURPLE
	label.TextStrokeTransparency = 0.3
	label.Parent = bb
	TweenService:Create(bb, TweenInfo.new(0.9), {StudsOffset = Vector3.new(0, 5.5, 0)}):Play()
	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	Debris:AddItem(bb, 1)
end

local function slashEffect(fromRoot, toPos)
	local slash = Instance.new("Part")
	slash.Size = Vector3.new(0.3, 1.6, 4)
	slash.Color = SPORE_PURPLE
	slash.Material = Enum.Material.Neon
	slash.Transparency = 0.2
	slash.Anchored = true
	slash.CanCollide = false
	slash.CanQuery = false
	slash.CFrame = CFrame.lookAt(fromRoot.Position + Vector3.new(0, 1.5, 0), toPos)
		* CFrame.new(0, 1.2, -2) * CFrame.Angles(0, 0, math.rad(90))
	slash.Parent = workspace
	TweenService:Create(slash, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = slash.CFrame * CFrame.new(0, -2.6, 0),
		Transparency = 1,
	}):Play()
	Debris:AddItem(slash, 0.25)
end

SporeGuillotine.OnServerEvent:Connect(function(caster)
	local now = tick()
	if lastUsed[caster] and now - lastUsed[caster] < COOLDOWN - 0.1 then return end

	local char = caster.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	lastUsed[caster] = now

	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z).Unit

	local target, targetRoot, targetHum
	local bestDist = RANGE + 1
	for _, model in ipairs(workspace:GetChildren()) do
		if model:IsA("Model") and model ~= char then
			local mRoot = model:FindFirstChild("HumanoidRootPart")
			local mHum = model:FindFirstChildOfClass("Humanoid")
			if mRoot and mHum and mHum.Health > 0 then
				local offset = mRoot.Position - root.Position
				local flat = Vector3.new(offset.X, 0, offset.Z)
				local dist = flat.Magnitude
				if dist <= RANGE and dist < bestDist and math.abs(offset.Y) < 8 then
					if dist < 1.5 or flat.Unit:Dot(flatLook) >= CONE_DOT then
						target, targetRoot, targetHum = model, mRoot, mHum
						bestDist = dist
					end
				end
			end
		end
	end

	if not target then
		slashEffect(root, root.Position + flatLook * 5)
		return
	end

	slashEffect(root, targetRoot.Position)

	local trapped = isTrappedOrStunned(target, targetRoot, targetHum)
	local headPos = targetRoot.Position + Vector3.new(0, 1.8, 0)

	if trapped then
		targetHum:TakeDamage(BASE_DAMAGE * FINISHER_MULT)
		sporeBurst(headPos, true)
		finisherPopup(targetRoot)
	else
		targetHum:TakeDamage(BASE_DAMAGE)
		sporeBurst(headPos, false)
	end
end)

print("SporeGuillotineHandler loaded!")
