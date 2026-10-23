-- CannonClient: become a coconut mortar. WASD pans the targeting reticle
-- across the map and YOUR CAMERA FOLLOWS THE RETICLE from above (artillery
-- view) - you watch the landing zone, not your own character. LMB or the
-- ability key fires (3 shots). Mode ends after the 3rd shot.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local char = script.Parent
local camera = workspace.CurrentCamera

local Abilities = RS:WaitForChild("Abilities")
local CannonStart = Abilities:WaitForChild("CannonStart")
local CannonAim = Abilities:WaitForChild("CannonAim")
local CannonFire = Abilities:WaitForChild("CannonFire")
local CannonStop = Abilities:WaitForChild("CannonStop")

local COOLDOWN = 18
local SHOTS = 3
local MODE_TIME = 20
local AIM_SEND_RATE = 1 / 20
local SHOT_GAP = 0.4          -- must match the server's per-shot gap
local PAN_SPEED = 45          -- studs/s the reticle travels with WASD
local MAX_RANGE = 120         -- must match the server clamp
local CAM_HEIGHT = 55         -- artillery view height above the landing zone
local CAM_BACK = 22           -- camera pulled back toward the cannon

local active = false
local shots = 0
local lastUsed = -COOLDOWN -- set when cannon mode ENDS
local aimConn = nil
local sendAcc = 0
local modeTimer = nil
local aimPos = nil
local lastShotT = 0

local SLOT_KEYCODES = {
	[1] = Enum.KeyCode.Q,
	[2] = Enum.KeyCode.E,
	[3] = Enum.KeyCode.R,
	[4] = Enum.KeyCode.F
}
local function getMyKey()
	if _G.EquippedAbilities then
		for s, id in pairs(_G.EquippedAbilities) do
			if id == "coconut_cannon" then return SLOT_KEYCODES[s], s end
		end
	end
	return nil, nil
end

RunService.Heartbeat:Connect(function()
	_G.AbilityCooldowns = _G.AbilityCooldowns or {}
	_G.AbilityCooldowns["coconut_cannon"] = { lastUsed = lastUsed, cd = COOLDOWN }
end)

local function groundAt(pos)
	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = {char}
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local res = workspace:Raycast(pos + Vector3.new(0, 40, 0), Vector3.new(0, -160, 0), rp)
	return res and res.Position or pos
end

local function restoreCamera()
	camera.CameraType = Enum.CameraType.Custom
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then camera.CameraSubject = hum end
end

local function deactivate(fireStop)
	if not active then return end
	active = false
	lastUsed = tick()
	if aimConn then aimConn:Disconnect(); aimConn = nil end
	if modeTimer then task.cancel(modeTimer); modeTimer = nil end
	restoreCamera()
	if fireStop then CannonStop:FireServer() end
end

local function activate()
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	active = true
	shots = 0
	sendAcc = 0
	lastShotT = 0

	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
	aimPos = groundAt(root.Position + flat.Unit * 30)

	CannonStart:FireServer()
	CannonAim:FireServer(aimPos)

	-- artillery camera
	camera.CameraType = Enum.CameraType.Scriptable

	aimConn = RunService.RenderStepped:Connect(function(dt)
		if not active then return end
		local r = char:FindFirstChild("HumanoidRootPart")
		if not r then deactivate(true) return end

		-- WASD pans the reticle, relative to the current camera view
		local camLook = camera.CFrame.LookVector
		local fwd = Vector3.new(camLook.X, 0, camLook.Z)
		if fwd.Magnitude < 0.01 then fwd = Vector3.new(0, 0, -1) end
		fwd = fwd.Unit
		local rgt = Vector3.new(-fwd.Z, 0, fwd.X)

		local move = Vector3.zero
		if UIS:IsKeyDown(Enum.KeyCode.W) then move += fwd end
		if UIS:IsKeyDown(Enum.KeyCode.S) then move -= fwd end
		if UIS:IsKeyDown(Enum.KeyCode.D) then move += rgt end
		if UIS:IsKeyDown(Enum.KeyCode.A) then move -= rgt end
		if move.Magnitude > 0 then
			aimPos = aimPos + move.Unit * PAN_SPEED * dt
			-- keep within cannon range
			local offset = Vector3.new(aimPos.X - r.Position.X, 0, aimPos.Z - r.Position.Z)
			if offset.Magnitude > MAX_RANGE then
				local clamped = r.Position + offset.Unit * MAX_RANGE
				aimPos = Vector3.new(clamped.X, aimPos.Y, clamped.Z)
			end
			aimPos = groundAt(aimPos)
		end

		-- camera hovers above the landing zone, pulled back toward the cannon,
		-- looking down at the blast area
		local toCannon = Vector3.new(r.Position.X - aimPos.X, 0, r.Position.Z - aimPos.Z)
		local backDir
		if toCannon.Magnitude > 1 then
			backDir = toCannon.Unit
		else
			backDir = -fwd
		end
		local targetCamPos = aimPos + backDir * CAM_BACK + Vector3.new(0, CAM_HEIGHT, 0)
		local targetCF = CFrame.lookAt(targetCamPos, aimPos)
		camera.CFrame = camera.CFrame:Lerp(targetCF, math.clamp(14 * dt, 0, 1))

		-- stream the aim point to the server
		sendAcc = sendAcc + dt
		if sendAcc >= AIM_SEND_RATE then
			sendAcc = 0
			CannonAim:FireServer(aimPos)
		end
	end)

	modeTimer = task.delay(MODE_TIME, function()
		modeTimer = nil
		deactivate(true)
	end)
end

local function fire()
	-- mirror the server's shot gap so client and server shot counts NEVER
	-- desync (the old version counted spam-clicks the server rejected,
	-- leaving you stuck in cannon mode after the "3rd" shot)
	local t = tick()
	if t - lastShotT < SHOT_GAP then return end
	lastShotT = t

	shots = shots + 1
	CannonFire:FireServer()
	if shots >= SHOTS then
		-- fireStop=true: even if anything desyncs, this forces the server to
		-- pack up the cannon too (harmless if it already has)
		task.delay(0.35, function() deactivate(true) end)
	end
end

-- safety: if the character dies mid-mode, give the camera back
local hum = char:WaitForChild("Humanoid")
hum.Died:Connect(function()
	if active then deactivate(false) end
end)

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	local myKey = getMyKey()
	if not myKey then return end

	if active then
		-- in cannon mode: key or LMB fires
		if input.KeyCode == myKey or input.UserInputType == Enum.UserInputType.MouseButton1 then
			fire()
		end
		return
	end

	if input.KeyCode ~= myKey then return end
	if tick() - lastUsed < COOLDOWN then return end
	activate()
end)
