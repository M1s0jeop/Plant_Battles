-- KiwiTossHandler: lob a kiwi in an arc toward the aimed point. The kiwi GROWS
-- the longer it flies and the further it travels.
--   * Hits an ENEMY  -> their screen gets smeared with kiwi slices (blinds them).
--                       Blind strength/duration scales with kiwi size.
--   * Hits an ALLY or YOURSELF -> grants an absorb shield. Shield amount scales
--                       with distance travelled and kiwi size.
-- "Ally" = a player on the same (non-neutral) Team. With no teams, everyone else
-- is an enemy, so the shield only applies to yourself (throw it up and catch it!).
--
-- How the shield works: like CoconutShield, the humanoid gets a health buffer
-- (MaxHealth and Health raised by the shield amount). Incoming damage eats the
-- buffer first; once it's depleted or expires the bonus MaxHealth is removed.
-- Current shield HP is exposed as the "KiwiShield" attribute on the Humanoid.

local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Abilities = RS:WaitForChild("Abilities")
local KiwiToss = Abilities:FindFirstChild("KiwiToss")
if not KiwiToss then
	KiwiToss = Instance.new("RemoteEvent")
	KiwiToss.Name = "KiwiToss"
	KiwiToss.Parent = Abilities
end
local KiwiSplat = Abilities:FindFirstChild("KiwiSplat")
if not KiwiSplat then
	KiwiSplat = Instance.new("RemoteEvent")
	KiwiSplat.Name = "KiwiSplat"
	KiwiSplat.Parent = Abilities
end

-- Config
local COOLDOWN = 7
local LOB_SPEED = 42            -- average flight speed (lower = longer flight = bigger kiwi)
local GRAVITY = 50
local MAX_FLIGHT_TIME = 5
local MAX_TARGET_DIST = 220
local SELF_HIT_GRACE = 0.35     -- caster can't be hit by their own kiwi for this long

local MIN_SIZE = 1.0            -- kiwi diameter at launch (studs)
local MAX_SIZE = 6.0            -- kiwi diameter cap
local GROW_PER_STUD = 0.045     -- size gained per stud travelled
local GROW_PER_SEC = 0.8        -- size gained per second airborne

local SHIELD_BASE = 10
local SHIELD_PER_STUD = 0.45
local SHIELD_PER_SIZE = 9       -- per stud of size gained above MIN_SIZE
local SHIELD_MAX = 90
local SHIELD_DURATION = 8

local KIWI_GREEN = Color3.fromRGB(120, 190, 50)
local KIWI_SKIN = Color3.fromRGB(125, 90, 50)

local lastUsed = {}
local shields = {} -- [humanoid] = session

local function isAlly(a, b)
	if not a or not b or a == b then return false end
	if a.Neutral or b.Neutral then return false end
	return a.Team ~= nil and a.Team == b.Team
end

-- =====================
-- SHIELD
-- =====================
local function endShield(hum)
	local sess = shields[hum]
	if not sess then return end
	shields[hum] = nil
	for _, c in ipairs(sess.conns) do c:Disconnect() end
	if hum.Parent then
		hum.MaxHealth = math.max(1, hum.MaxHealth - sess.added)
		if hum.Health > hum.MaxHealth then hum.Health = hum.MaxHealth end
		hum:SetAttribute("KiwiShield", nil)
	end
	if sess.bubble and sess.bubble.Parent then
		local b = sess.bubble
		TweenService:Create(b, TweenInfo.new(0.3), {Transparency = 1, Size = b.Size * 1.3}):Play()
		Debris:AddItem(b, 0.35)
	end
end

local function giveShield(hum, root, amount)
	amount = math.floor(math.clamp(amount, 1, SHIELD_MAX))
	-- refreshing: keep whichever is bigger, the leftover or the new one
	local old = shields[hum]
	if old then
		amount = math.max(amount, math.floor(old.remaining))
		endShield(hum)
	end

	local bubble = Instance.new("Part")
	bubble.Name = "KiwiShieldBubble"
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = Vector3.new(7, 7, 7)
	bubble.Color = KIWI_GREEN
	bubble.Material = Enum.Material.ForceField
	bubble.Transparency = 0
	bubble.CanCollide = false
	bubble.CanQuery = false
	bubble.CanTouch = false
	bubble.Massless = true
	bubble.CFrame = root.CFrame
	bubble.Parent = hum.Parent
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = bubble
	weld.Parent = bubble

	local sess = { added = amount, remaining = amount, bubble = bubble, conns = {} }
	shields[hum] = sess
	hum.MaxHealth = hum.MaxHealth + amount
	hum.Health = hum.Health + amount
	hum:SetAttribute("KiwiShield", amount)

	local lastH = hum.Health
	table.insert(sess.conns, hum.HealthChanged:Connect(function(h)
		if h < lastH then
			sess.remaining = sess.remaining - (lastH - h)
			hum:SetAttribute("KiwiShield", math.max(0, math.floor(sess.remaining)))
			if sess.remaining <= 0 then
				lastH = h
				endShield(hum)
				return
			end
		end
		lastH = h
	end))
	table.insert(sess.conns, hum.Died:Connect(function()
		endShield(hum)
	end))

	task.delay(SHIELD_DURATION, function()
		if shields[hum] == sess then endShield(hum) end
	end)
end

-- =====================
-- VFX
-- =====================
local function spawnBurst(pos, size)
	for i = 1, math.floor(6 + size * 2) do
		local chunk = Instance.new("Part")
		local s = math.random(20, 45) * 0.01 * (0.6 + size * 0.25)
		chunk.Size = Vector3.new(s, s, s)
		chunk.Color = (i % 3 == 0) and KIWI_SKIN or KIWI_GREEN
		chunk.Material = Enum.Material.SmoothPlastic
		chunk.CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * math.pi, math.random() * math.pi, math.random() * math.pi)
		chunk.AssemblyLinearVelocity = Vector3.new(math.random(-20, 20), math.random(8, 24), math.random(-20, 20))
		chunk.CanCollide = false
		chunk.CanQuery = false
		chunk.CanTouch = false
		chunk.Parent = workspace
		Debris:AddItem(chunk, 1)
		TweenService:Create(chunk, TweenInfo.new(1), {Transparency = 1}):Play()
	end
end

local function buildKiwi(origin)
	local kiwi = Instance.new("Part")
	kiwi.Name = "KiwiToss"
	kiwi.Shape = Enum.PartType.Ball
	kiwi.Size = Vector3.new(MIN_SIZE, MIN_SIZE, MIN_SIZE)
	kiwi.Color = KIWI_SKIN
	kiwi.Material = Enum.Material.Fabric -- fuzzy skin
	kiwi.Anchored = true
	kiwi.CanCollide = false
	kiwi.CanQuery = false
	kiwi.CanTouch = false
	kiwi.CFrame = CFrame.new(origin)
	kiwi.Parent = workspace

	-- green glowing trail so you can see it grow
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.3, 0)
	a0.Parent = kiwi
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.3, 0)
	a1.Parent = kiwi
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(KIWI_GREEN)
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.Lifetime = 0.3
	trail.LightEmission = 0.4
	trail.Parent = kiwi
	return kiwi, a0, a1
end

-- =====================
-- IMPACT
-- =====================
local function resolveImpact(caster, pos, size, distance, canHitSelf)
	local radius = size * 0.5 + 1.5
	local hitSomething = false
	local affected = {}

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(pos, radius, params)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local hum = model and model:FindFirstChildOfClass("Humanoid")
		local root = model and model:FindFirstChild("HumanoidRootPart")
		if hum and root and hum.Health > 0 and not affected[hum] then
			affected[hum] = true
			local vPlayer = Players:GetPlayerFromCharacter(model)
			local isSelf = vPlayer == caster
			if isSelf and not canHitSelf then
				-- still in grace period, ignore
			elseif isSelf or isAlly(caster, vPlayer) then
				hitSomething = true
				local amount = SHIELD_BASE + distance * SHIELD_PER_STUD + (size - MIN_SIZE) * SHIELD_PER_SIZE
				giveShield(hum, root, amount)
			else
				hitSomething = true
				if vPlayer then
					local t = (size - MIN_SIZE) / (MAX_SIZE - MIN_SIZE)
					KiwiSplat:FireClient(vPlayer, t)
				end
			end
		end
	end
	return hitSomething
end

-- =====================
-- THROW
-- =====================
KiwiToss.OnServerEvent:Connect(function(caster, targetPoint)
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
	local flightTime = math.clamp(delta.Magnitude / LOB_SPEED, 0.5, 2.6)
	local g = Vector3.new(0, -GRAVITY, 0)
	local vel = (delta - 0.5 * g * flightTime * flightTime) / flightTime

	local kiwi, a0, a1 = buildKiwi(origin)

	local rpNoSelf = RaycastParams.new()
	rpNoSelf.FilterType = Enum.RaycastFilterType.Exclude
	rpNoSelf.FilterDescendantsInstances = {char, kiwi}
	local rpWithSelf = RaycastParams.new()
	rpWithSelf.FilterType = Enum.RaycastFilterType.Exclude
	rpWithSelf.FilterDescendantsInstances = {kiwi}

	task.spawn(function()
		local pos = origin
		local v = vel
		local elapsed = 0
		local travelled = 0
		local spin = 0
		local size = MIN_SIZE

		while elapsed < MAX_FLIGHT_TIME do
			local dt = RunService.Heartbeat:Wait()
			elapsed = elapsed + dt
			spin = spin + dt * 8

			local newPos = pos + v * dt
			local step = newPos - pos
			local canHitSelf = elapsed >= SELF_HIT_GRACE

			-- swept sphere-ish: raycast from the center, plus proximity check for
			-- humanoids since a big kiwi should hit things its edge touches
			local result = workspace:Raycast(pos, step + step.Unit * (size * 0.5), canHitSelf and rpWithSelf or rpNoSelf)
			local hitPos = result and result.Position

			if not hitPos then
				-- edge contact with any character
				local params = OverlapParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = canHitSelf and {kiwi} or {kiwi, char}
				for _, part in ipairs(workspace:GetPartBoundsInRadius(newPos, size * 0.5, params)) do
					local m = part:FindFirstAncestorOfClass("Model")
					local h = m and m:FindFirstChildOfClass("Humanoid")
					if h and h.Health > 0 then
						hitPos = newPos
						break
					end
				end
			end

			if hitPos then
				resolveImpact(caster, hitPos, size, travelled, canHitSelf)
				spawnBurst(hitPos, size)
				break
			end

			travelled = travelled + step.Magnitude
			pos = newPos
			v = v + g * dt
			size = math.min(MAX_SIZE, MIN_SIZE + travelled * GROW_PER_STUD + elapsed * GROW_PER_SEC)
			kiwi.Size = Vector3.new(size, size * 0.85, size * 0.85)
			a0.Position = Vector3.new(0, size * 0.3, 0)
			a1.Position = Vector3.new(0, -size * 0.3, 0)
			kiwi.CFrame = CFrame.new(pos) * CFrame.Angles(spin, spin * 0.6, 0)
		end
		kiwi:Destroy()
	end)
end)

Players.PlayerRemoving:Connect(function(p)
	lastUsed[p] = nil
end)

print("KiwiTossHandler loaded!")
