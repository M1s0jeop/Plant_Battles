-- PeelTrapClient: throw a banana peel trap toward where you're aiming.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local char = script.Parent
local camera = workspace.CurrentCamera

local Abilities = RS:WaitForChild("Abilities")
local PeelThrow = Abilities:WaitForChild("PeelThrow")
local PeelSlip = Abilities:WaitForChild("PeelSlip")

local COOLDOWN = 7
local lastUsed = -COOLDOWN

local SLOT_KEYCODES = {
	[1] = Enum.KeyCode.Q,
	[2] = Enum.KeyCode.E,
	[3] = Enum.KeyCode.R,
	[4] = Enum.KeyCode.F
}
local function getMyKey()
	if _G.EquippedAbilities then
		for s, id in pairs(_G.EquippedAbilities) do
			if id == "peel_trap" then return SLOT_KEYCODES[s], s end
		end
	end
	return nil, nil
end

RunService.Heartbeat:Connect(function()
	_G.AbilityCooldowns = _G.AbilityCooldowns or {}
	_G.AbilityCooldowns["peel_trap"] = { lastUsed = lastUsed, cd = COOLDOWN }
end)

-- little "WOOPS!" popup + dust when someone slips
PeelSlip.OnClientEvent:Connect(function(pos)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.new(0, 120, 0, 40)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = true
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(pos)
	anchor.Parent = workspace
	bb.Parent = anchor
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = "WOOPS!"
	lbl.TextScaled = true
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextColor3 = Color3.fromRGB(245, 220, 70)
	lbl.TextStrokeTransparency = 0.3
	lbl.Parent = bb
	game:GetService("TweenService"):Create(bb, TweenInfo.new(0.9), {StudsOffset = Vector3.new(0, 6, 0)}):Play()
	game:GetService("TweenService"):Create(lbl, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	game:GetService("Debris"):AddItem(anchor, 1)
end)

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	local myKey = getMyKey()
	if not myKey or input.KeyCode ~= myKey then return end
	if tick() - lastUsed < COOLDOWN then return end

	-- aim at the ground point under the cursor (so the peel lands where you point)
	local mouse = UIS:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = {char}
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 400, rp)
	local targetPos
	if hit then
		targetPos = hit.Position
	else
		-- no ground hit (aiming at sky): project forward at the player's height
		local dir = Vector3.new(ray.Direction.X, 0, ray.Direction.Z)
		if dir.Magnitude < 0.01 then dir = root.CFrame.LookVector end
		targetPos = root.Position + dir.Unit * 40
	end

	lastUsed = tick()
	PeelThrow:FireServer(targetPos)
end)
