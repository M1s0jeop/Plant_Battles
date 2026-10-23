-- SunflowerClient: channel a sunflower beam toward the cursor.
-- The aim direction deliberately lags behind the cursor (limited turn speed),
-- so you can't flick the beam around. Press the ability key again to cancel.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local char = script.Parent
local camera = workspace.CurrentCamera

local Abilities = RS:WaitForChild("Abilities")
local SunflowerStart = Abilities:WaitForChild("SunflowerStart")
local SunflowerAim = Abilities:WaitForChild("SunflowerAim")
local SunflowerStop = Abilities:WaitForChild("SunflowerStop")

local DURATION = 6
local COOLDOWN = 5                 -- starts when the beam ends
local MAX_TURN_SPEED = math.rad(55) -- how fast the beam may track the cursor (per second)
local AIM_SEND_RATE = 1 / 20        -- stream aim to server at 20 Hz

local active = false
local lastUsed = -COOLDOWN          -- here this marks when the beam ENDED
local currentDir = nil
local aimConn = nil
local sendAcc = 0
local stopTimer = nil

local SLOT_KEYCODES = {
	[1] = Enum.KeyCode.Q,
	[2] = Enum.KeyCode.E,
	[3] = Enum.KeyCode.R,
	[4] = Enum.KeyCode.F
}
local function getMyKey()
	if _G.EquippedAbilities then
		for s, id in pairs(_G.EquippedAbilities) do
			if id == "sunflower_beam" then return SLOT_KEYCODES[s], s end
		end
	end
	return nil, nil
end

RunService.Heartbeat:Connect(function()
	_G.AbilityCooldowns = _G.AbilityCooldowns or {}
	_G.AbilityCooldowns["sunflower_beam"] = { lastUsed = lastUsed, cd = COOLDOWN }
end)

local function desiredDir()
	local vp = camera.ViewportSize
	local ray = camera:ViewportPointToRay(vp.X / 2, vp.Y / 2)
	return ray.Direction.Unit
end

-- rotate `current` toward `target` by at most `maxAngle` radians
local function rotateTowards(current, target, maxAngle)
	local dot = math.clamp(current:Dot(target), -1, 1)
	local angle = math.acos(dot)
	if angle <= maxAngle or angle < 1e-3 then return target end
	local axis = current:Cross(target)
	if axis.Magnitude < 1e-4 then
		axis = Vector3.new(0, 1, 0)
	else
		axis = axis.Unit
	end
	return (CFrame.fromAxisAngle(axis, maxAngle) * current).Unit
end

local function deactivate(fireStop)
	if not active then return end
	active = false
	lastUsed = tick() -- cooldown starts now
	if aimConn then aimConn:Disconnect(); aimConn = nil end
	if stopTimer then task.cancel(stopTimer); stopTimer = nil end
	if fireStop then SunflowerStop:FireServer() end
end

local function activate()
	active = true
	currentDir = desiredDir()
	sendAcc = 0
	SunflowerStart:FireServer()
	SunflowerAim:FireServer(currentDir)

	aimConn = RunService.RenderStepped:Connect(function(dt)
		if not active then return end
		currentDir = rotateTowards(currentDir, desiredDir(), MAX_TURN_SPEED * dt)
		sendAcc = sendAcc + dt
		if sendAcc >= AIM_SEND_RATE then
			sendAcc = 0
			SunflowerAim:FireServer(currentDir)
		end

		-- Hide the beam body on MY screen while in first person (it blocks the view).
		-- LocalTransparencyModifier is client-only: everyone else still sees the beam,
		-- and the impact glow stays visible as the aim marker.
		local beamPart = workspace:FindFirstChild("SunflowerBeam_" .. player.Name)
		if beamPart then
			local head = char:FindFirstChild("Head")
			local isFirstPerson = head and (camera.CFrame.Position - head.Position).Magnitude < 1.2
			beamPart.LocalTransparencyModifier = isFirstPerson and 1 or 0
		end
	end)

	stopTimer = task.delay(DURATION, function()
		stopTimer = nil
		deactivate(true)
	end)
end

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	local myKey = getMyKey()
	if not myKey or input.KeyCode ~= myKey then return end

	if active then
		-- press again to cancel
		deactivate(true)
		return
	end

	if tick() - lastUsed < COOLDOWN then return end
	activate()
end)
