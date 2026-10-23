-- RoseThornHandler: strike with a hardened rose thorn dagger (short melee).
-- Hit from DIRECTLY BEHIND = critical backstab: massive damage, half of it
-- dealt as a direct health subtraction that bypasses ForceFields and any
-- TakeDamage-based shielding, plus a 3-second bleed (damage over time).

local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Abilities = RS:WaitForChild("Abilities")
local RoseThorn = Abilities:WaitForChild("RoseThorn")

-- Config
local COOLDOWN = 4
local RANGE = 8               -- melee reach
local CONE_DOT = 0.55         -- how centered the target must be in front of you
local FRONT_DAMAGE = 15
local BACKSTAB_DAMAGE = 50    -- half normal, half armor-piercing
local BACKSTAB_DOT = 0.55     -- how "directly behind" you must be
local BLEED_TICK = 4
local BLEED_INTERVAL = 0.5
local BLEED_DURATION = 3

local THORN_GREEN = Color3.fromRGB(45, 90, 40)
local BLOOD = Color3.fromRGB(150, 15, 15)

local lastUsed = {}
local bleeding = {} -- [humanoid] = endTime

local function slashEffect(fromRoot, toPos, isCrit)
	-- the thorn dagger flashes in an arc
	local slash = Instance.new("Part")
	slash.Size = Vector3.new(0.25, 1.2, 3.2)
	slash.Color = isCrit and BLOOD or THORN_GREEN
	slash.Material = Enum.Material.Neon
	slash.Transparency = 0.25
	slash.Anchored = true
	slash.CanCollide = false
	slash.CanQuery = false
	slash.CFrame = CFrame.lookAt(fromRoot.Position + Vector3.new(0, 0.5, 0), toPos)
		* CFrame.new(0.8, 0, -2) * CFrame.Angles(0, 0, math.rad(40))
	slash.Parent = workspace
	TweenService:Create(slash, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = slash.CFrame * CFrame.new(-1.6, 0, 0) * CFrame.Angles(0, 0, math.rad(-80)),
		Transparency = 1,
	}):Play()
	Debris:AddItem(slash, 0.25)
end

local function critPopup(victimRoot)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 110, 0, 36)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.AlwaysOnTop = true
	bb.Parent = victimRoot
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "CRIT!"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(255, 60, 50)
	label.TextStrokeTransparency = 0.4
	label.Parent = bb
	TweenService:Create(bb, TweenInfo.new(0.8), {StudsOffset = Vector3.new(0, 5.2, 0)}):Play()
	TweenService:Create(label, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	Debris:AddItem(bb, 0.9)
end

local function applyBleed(victimHuman, victimRoot)
	local endTime = tick() + BLEED_DURATION
	local alreadyBleeding = bleeding[victimHuman] ~= nil
	bleeding[victimHuman] = endTime -- refresh if re-stabbed
	if alreadyBleeding then return end

	-- blood drip particles while bleeding
	local drip = Instance.new("ParticleEmitter")
	drip.Name = "BleedDrip"
	drip.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	drip.Color = ColorSequence.new(BLOOD)
	drip.Size = NumberSequence.new(0.25)
	drip.Transparency = NumberSequence.new(0.2, 1)
	drip.Lifetime = NumberRange.new(0.4, 0.8)
	drip.Rate = 12
	drip.Speed = NumberRange.new(1, 3)
	drip.Acceleration = Vector3.new(0, -25, 0)
	drip.SpreadAngle = Vector2.new(60, 60)
	drip.Parent = victimRoot

	task.spawn(function()
		while bleeding[victimHuman] and tick() < bleeding[victimHuman] do
			task.wait(BLEED_INTERVAL)
			if victimHuman.Parent and victimHuman.Health > 0 then
				victimHuman:TakeDamage(BLEED_TICK)
			else
				break
			end
		end
		bleeding[victimHuman] = nil
		if drip.Parent then drip:Destroy() end
	end)
end

RoseThorn.OnServerEvent:Connect(function(caster)
	local now = tick()
	if lastUsed[caster] and now - lastUsed[caster] < COOLDOWN - 0.1 then return end

	local char = caster.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	lastUsed[caster] = now

	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z).Unit

	-- find the nearest valid target in the melee cone
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
		-- whiff: still show the swing
		slashEffect(root, root.Position + flatLook * 5, false)
		return
	end

	slashEffect(root, targetRoot.Position, false)

	-- backstab check: am I directly behind the victim?
	-- (victim's facing and the attacker->victim direction point the same way)
	local victimLook = targetRoot.CFrame.LookVector
	local victimFlatLook = Vector3.new(victimLook.X, 0, victimLook.Z)
	local toVictim = Vector3.new(targetRoot.Position.X - root.Position.X, 0, targetRoot.Position.Z - root.Position.Z)
	local isBackstab = false
	if victimFlatLook.Magnitude > 0.01 and toVictim.Magnitude > 0.01 then
		isBackstab = victimFlatLook.Unit:Dot(toVictim.Unit) >= BACKSTAB_DOT
	end

	if isBackstab then
		-- half via TakeDamage, half pierces straight through shields/armor
		local half = BACKSTAB_DAMAGE / 2
		targetHum:TakeDamage(half)
		targetHum.Health = math.max(0, targetHum.Health - half) -- the bypass
		applyBleed(targetHum, targetRoot)
		critPopup(targetRoot)
		slashEffect(root, targetRoot.Position, true)
	else
		targetHum:TakeDamage(FRONT_DAMAGE)
	end
end)

print("RoseThornHandler loaded!")
