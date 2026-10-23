-- SunflareClient: prime a sunflare flash, then LMB to throw it (key again to
-- cancel). Also owns the CS-style blind: when the server says a flash went off,
-- THIS client checks its own camera - line of sight to the blast and how
-- directly it was looking at it - and whites out its screen accordingly.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Abilities = RS:WaitForChild("Abilities")
local FlashThrow = Abilities:WaitForChild("FlashThrow")
local FlashDetonate = Abilities:WaitForChild("FlashDetonate")

local ABILITY_ID = "sunflower_flash"
local COOLDOWN = 12
local MAX_AIM_DIST = 240
local lastUsed = -COOLDOWN
local primed = false
local hintGui = nil

-- ===== Flash tuning =====
local MAX_DUR   = 4.5    -- full-in-the-face blind duration (seconds)
local MIN_DUR   = 0.3    -- below this we don't bother flashing
local FULL_DIST = 22     -- within this distance, no distance falloff
local FAR_DIST  = 140    -- beyond this, minimum distance factor

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
	return nil
end

RunService.Heartbeat:Connect(function()
	_G.AbilityCooldowns = _G.AbilityCooldowns or {}
	_G.AbilityCooldowns[ABILITY_ID] = { lastUsed = lastUsed, cd = COOLDOWN }
end)

-- ===== Primed hint UI =====
local function showHint(key)
	if hintGui then hintGui:Destroy() end
	hintGui = Instance.new("ScreenGui")
	hintGui.Name = "SunflarePrimeHint"
	hintGui.ResetOnSpawn = false
	hintGui.IgnoreGuiInset = true
	hintGui.DisplayOrder = 60
	hintGui.Parent = player:WaitForChild("PlayerGui")

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0, 460, 0, 40)
	lbl.AnchorPoint = Vector2.new(0.5, 1)
	lbl.Position = UDim2.new(0.5, 0, 1, -160)
	lbl.BackgroundColor3 = Color3.fromRGB(20, 18, 8)
	lbl.BackgroundTransparency = 0.25
	lbl.BorderSizePixel = 0
	lbl.Text = "\u{1F31F} Sunflare primed  \u{2022}  LMB to throw  \u{2022}  " .. key .. " to cancel"
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.TextColor3 = Color3.fromRGB(255, 225, 90)
	lbl.Parent = hintGui
	Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 8)
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(255, 210, 60); st.Thickness = 2; st.Transparency = 0.3
	st.Parent = lbl
end
local function clearHint()
	if hintGui then hintGui:Destroy(); hintGui = nil end
end

local function unprime()
	primed = false
	clearHint()
end

local function throwAt()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then unprime() return end

	local vp = camera.ViewportSize
	local ray = camera:ViewportPointToRay(vp.X / 2, vp.Y / 2)
	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = {char}
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local result = workspace:Raycast(ray.Origin, ray.Direction * MAX_AIM_DIST, rp)
	local targetPoint = result and result.Position or (ray.Origin + ray.Direction * MAX_AIM_DIST)

	unprime()
	lastUsed = tick()
	FlashThrow:FireServer(targetPoint)
end

UIS.InputBegan:Connect(function(input, processed)
	if processed then
		-- still allow the ability key (keyboard) even if game-processed is flagged by UI
	end
	local myKey = getMyKey()

	-- ability key: prime / cancel
	if myKey and input.KeyCode == myKey and not processed then
		if primed then
			unprime()
			return
		end
		if tick() - lastUsed < COOLDOWN then return end
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then return end
		primed = true
		showHint(tostring(myKey.Name))
		return
	end

	-- LMB while primed: throw
	if primed and input.UserInputType == Enum.UserInputType.MouseButton1 then
		throwAt()
	end
end)

-- if we die while holding it, put it away
local function hookChar(char)
	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
	if hum then hum.Died:Connect(unprime) end
end
if player.Character then hookChar(player.Character) end
player.CharacterAdded:Connect(hookChar)

-- ===== The blind (server tells us a flash went off at flashPos) =====
local activeToken = 0

local function characterFilterList()
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then table.insert(list, plr.Character) end
	end
	return list
end

local function showFlash(intensity)
	-- intensity 0..1 -> how white and how long
	local dur = MAX_DUR * intensity
	if dur < MIN_DUR then return end

	activeToken += 1
	local myToken = activeToken

	local pg = player:WaitForChild("PlayerGui")
	local existing = pg:FindFirstChild("SunflareBlindGui")
	if existing then existing:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "SunflareBlindGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 500
	gui.Parent = pg

	local white = Instance.new("Frame")
	white.Size = UDim2.new(1, 0, 1, 0)
	white.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	white.BorderSizePixel = 0
	-- strong flash = fully opaque white; weak flash = lighter veil
	local peak = 1 - intensity        -- 0 = solid white, higher = more see-through
	white.BackgroundTransparency = peak
	white.Parent = gui

	-- hold at peak, then fade out over the remainder (CS-style tail)
	local hold = dur * 0.35
	task.delay(hold, function()
		if myToken ~= activeToken then return end
		TweenService:Create(white, TweenInfo.new(dur - hold, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 1 }):Play()
	end)
	task.delay(dur + 0.1, function()
		if myToken == activeToken and gui then gui:Destroy() end
	end)
end

FlashDetonate.OnClientEvent:Connect(function(flashPos)
	if typeof(flashPos) ~= "Vector3" then return end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end

	local camPos = camera.CFrame.Position
	local look = camera.CFrame.LookVector
	local toFlash = flashPos - camPos
	local dist = toFlash.Magnitude
	if dist < 0.5 then dist = 0.5 end
	local dir = toFlash / dist

	-- 1) are we even looking toward it? (dot: 1 = dead center, <=0 = facing away)
	local dot = look:Dot(dir)
	if dot <= 0.1 then return end   -- it's beside/behind us: no flash

	-- 2) line of sight: a wall between us and the blast blocks it
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = characterFilterList()
	local hit = workspace:Raycast(camPos, toFlash, rp)
	if hit and (hit.Position - flashPos).Magnitude > 3 then
		return   -- something solid is in the way
	end

	-- 3) angle factor: strongest when centered, ramps off toward the edge of view
	local angleFactor = math.clamp((dot - 0.1) / 0.9, 0, 1)
	angleFactor = angleFactor ^ 0.7

	-- 4) distance factor: full up close, weaker far away
	local distFactor
	if dist <= FULL_DIST then
		distFactor = 1
	else
		distFactor = math.clamp(1 - (dist - FULL_DIST) / (FAR_DIST - FULL_DIST), 0.25, 1)
	end

	showFlash(angleFactor * distFactor)
end)
