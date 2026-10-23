-- CoconutShieldHandler: wrap yourself in a coconut shell. It blocks ONE
-- instance of damage of ANY size (2 or 300, doesn't matter). 0.5s after that
-- first blocked hit the shell shatters - so only hits landing within 0.5s of
-- the first one are also absorbed.
--
-- How blocking works: while shielded, the humanoid's health is raised by a
-- huge buffer. Any damage just dents the buffer (so nothing can kill you),
-- and the first dent is our signal that a hit was blocked, which starts the
-- 0.5s shatter timer. On shatter/expiry the exact pre-shield health and
-- MaxHealth are restored.

local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Abilities = RS:WaitForChild("Abilities")
local CoconutShield = Abilities:WaitForChild("CoconutShield")

-- Config
local COOLDOWN = 10
local MAX_UPTIME = 8          -- shield fades on its own if never hit
local BLOCK_WINDOW = 0.5      -- extra absorb time after the first blocked hit
local BUFFER = 100000
local SHELL_BROWN = Color3.fromRGB(125, 85, 50)
local SHELL_DARK = Color3.fromRGB(95, 62, 35)

local lastUsed = {}
local active = {} -- [player] = session

local function shatter(pos)
	for i = 1, 12 do
		local chunk = Instance.new("Part")
		local s = math.random(25, 60) * 0.01
		chunk.Size = Vector3.new(s, s, s * 0.4)
		chunk.Color = SHELL_BROWN
		chunk.Material = Enum.Material.Wood
		chunk.CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * math.pi, math.random() * math.pi, math.random() * math.pi)
		chunk.AssemblyLinearVelocity = Vector3.new(math.random(-22, 22), math.random(10, 26), math.random(-22, 22))
		chunk.CanCollide = false
		chunk.CanQuery = false
		chunk.Parent = workspace
		Debris:AddItem(chunk, 1)
		TweenService:Create(chunk, TweenInfo.new(1), {Transparency = 1}):Play()
	end
end

local function endShield(player, didShatter)
	local sess = active[player]
	if not sess then return end
	active[player] = nil

	if sess.healthConn then sess.healthConn:Disconnect() end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		-- restore exact pre-shield values (any damage that landed only dented the buffer)
		hum.MaxHealth = sess.origMax
		hum.Health = math.min(sess.origHealth, sess.origMax)
	end

	if sess.shell and sess.shell.Parent then
		if didShatter then
			shatter(sess.shell.Position)
			sess.shell:Destroy()
		else
			local shell = sess.shell
			TweenService:Create(shell, TweenInfo.new(0.4), {Transparency = 1}):Play()
			for _, sp in ipairs(shell:GetChildren()) do
				if sp:IsA("BasePart") then
					TweenService:Create(sp, TweenInfo.new(0.4), {Transparency = 1}):Play()
				end
			end
			Debris:AddItem(shell, 0.5)
		end
	end
end

CoconutShield.OnServerEvent:Connect(function(player)
	local now = tick()
	if lastUsed[player] and now - lastUsed[player] < COOLDOWN - 0.1 then return end
	if active[player] then return end

	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return end

	lastUsed[player] = now

	-- the shell: translucent coconut sphere around the character
	local shell = Instance.new("Part")
	shell.Name = "CoconutShell_" .. player.Name
	shell.Shape = Enum.PartType.Ball
	shell.Size = Vector3.new(7.5, 7.5, 7.5)
	shell.Color = SHELL_BROWN
	shell.Material = Enum.Material.Wood
	shell.Transparency = 0.45
	shell.CanCollide = false
	shell.CanQuery = false
	shell.Massless = true
	shell.CFrame = root.CFrame
	shell.Parent = char
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = shell
	weld.Parent = shell

	-- the three classic coconut face dots
	for _, off in ipairs({Vector3.new(0.9, 1.6, -3.3), Vector3.new(-0.9, 1.6, -3.3), Vector3.new(0, 0.4, -3.6)}) do
		local spot = Instance.new("Part")
		spot.Shape = Enum.PartType.Ball
		spot.Size = Vector3.new(0.8, 0.8, 0.4)
		spot.Color = SHELL_DARK
		spot.Material = Enum.Material.Wood
		spot.Transparency = 0.25
		spot.CanCollide = false
		spot.CanQuery = false
		spot.Massless = true
		spot.CFrame = root.CFrame * CFrame.new(off)
		spot.Parent = shell
		local sw = Instance.new("WeldConstraint")
		sw.Part0 = shell
		sw.Part1 = spot
		sw.Parent = spot
	end

	-- raise the health buffer
	local sess = {
		origHealth = hum.Health,
		origMax = hum.MaxHealth,
		shell = shell,
		blocked = false,
	}
	active[player] = sess
	hum.MaxHealth = hum.MaxHealth + BUFFER
	hum.Health = hum.Health + BUFFER
	local baseline = hum.Health

	sess.healthConn = hum.HealthChanged:Connect(function(h)
		if h < baseline and not sess.blocked then
			-- first blocked instance: crack the shell, start the shatter timer
			sess.blocked = true
			shell.Color = SHELL_DARK
			shell.Transparency = 0.3
			task.delay(BLOCK_WINDOW, function()
				if active[player] == sess then
					endShield(player, true)
				end
			end)
		end
	end)

	-- fade on its own if never hit
	task.delay(MAX_UPTIME, function()
		if active[player] == sess and not sess.blocked then
			endShield(player, false)
		end
	end)
end)

game.Players.PlayerRemoving:Connect(function(player)
	endShield(player, false)
	lastUsed[player] = nil
end)

print("CoconutShieldHandler loaded!")
