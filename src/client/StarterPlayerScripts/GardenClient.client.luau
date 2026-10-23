-- GardenClient v3: Seeds button integrated into the HUD Sidebar (above Store),
-- Store-style panel, grid rebuilds on open, plus garden selection on spawn.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera
local Prog = require(RS:WaitForChild("PlantProgression"))
local Remotes = RS:WaitForChild("GardenRemotes")
local PlantSeed = Remotes:WaitForChild("PlantSeed")
local GardenSync = Remotes:WaitForChild("GardenSync")
local RequestGarden = Remotes:WaitForChild("RequestGarden")

local state = { seeds = {}, plants = {}, garden = nil, bounds = nil, unlocked = {} }
local pg = player:WaitForChild("PlayerGui")

-- ============ Add a Seeds button into the existing HUD Sidebar (above Store) ============
local hud = pg:WaitForChild("NatureHUD")
local sidebar
do
	local t0 = tick()
	repeat
		for _, d in ipairs(hud:GetDescendants()) do if d.Name == "Sidebar" then sidebar = d break end end
		if not sidebar then task.wait(0.2) end
	until sidebar or tick()-t0 > 8
end

local function cloneButtonStyle(into)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,12); c.Parent = into
	local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(30,30,30); st.Thickness = 3; st.Parent = into
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromRGB(100,200,100), Color3.fromRGB(60,150,60))
	g.Rotation = 90; g.Parent = into
end

local seedsBtn
if sidebar then
	-- grow the sidebar to fit 4 visible buttons (4*70 + 3*10 = 310)
	sidebar.Size = UDim2.new(0, 70, 0, 310)
	sidebar.Position = UDim2.new(0, 10, 0.5, -155)
	seedsBtn = Instance.new("ImageButton")
	seedsBtn.Name = "SeedsBtn"
	seedsBtn.Size = UDim2.new(0, 70, 0, 70)
	seedsBtn.BackgroundColor3 = Color3.fromRGB(255,255,255)
	seedsBtn.LayoutOrder = -1   -- sorts ABOVE Store (which is 0)
	seedsBtn.AutoButtonColor = true
	seedsBtn.Image = ""
	seedsBtn.Parent = sidebar
	cloneButtonStyle(seedsBtn)
	local emoji = Instance.new("TextLabel")
	emoji.Size = UDim2.new(1,0,0.62,0); emoji.Position = UDim2.new(0,0,0,2)
	emoji.BackgroundTransparency = 1; emoji.Text = "🌱"; emoji.TextScaled = true
	emoji.Parent = seedsBtn
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1,0,0.3,0); lbl.Position = UDim2.new(0,0,0.7,0)
	lbl.BackgroundTransparency = 1; lbl.Text = "Seeds"; lbl.TextSize = 8
	lbl.Font = Enum.Font.GothamBlack; lbl.TextColor3 = Color3.fromRGB(255,255,255)
	lbl.Parent = seedsBtn
end

-- ============ Seeds panel (Store-style, centered) ============
local gui = Instance.new("ScreenGui")
gui.Name = "SeedsInventoryGui"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true
gui.DisplayOrder = 60; gui.Parent = pg

local dim = Instance.new("Frame")
dim.Size = UDim2.new(1,0,1,0); dim.BackgroundColor3 = Color3.fromRGB(0,0,0)
dim.BackgroundTransparency = 0.4; dim.Visible = false; dim.Parent = gui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5,0.5); panel.Position = UDim2.new(0.5,0,0.5,0)
panel.Size = UDim2.new(0, 520, 0, 440)
panel.BackgroundColor3 = Color3.fromRGB(22,30,22); panel.BackgroundTransparency = 0.02
panel.BorderSizePixel = 0; panel.Parent = dim
Instance.new("UICorner", panel).CornerRadius = UDim.new(0,16)
local ps = Instance.new("UIStroke"); ps.Color = Color3.fromRGB(80,170,70); ps.Thickness = 3; ps.Parent = panel

local header = Instance.new("Frame")
header.Size = UDim2.new(1,0,0,60); header.BackgroundColor3 = Color3.fromRGB(40,90,40)
header.BackgroundTransparency = 0.1; header.BorderSizePixel = 0; header.Parent = panel
local hc = Instance.new("UICorner"); hc.CornerRadius = UDim.new(0,16); hc.Parent = header
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,-60,1,0); title.Position = UDim2.new(0,16,0,0)
title.BackgroundTransparency = 1; title.Text = "🌱 SEEDS"
title.TextXAlignment = Enum.TextXAlignment.Left; title.TextScaled = true
title.Font = Enum.Font.GothamBlack; title.TextColor3 = Color3.fromRGB(220,255,220); title.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0,40,0,40); closeBtn.Position = UDim2.new(1,-50,0.5,-20)
closeBtn.BackgroundColor3 = Color3.fromRGB(200,60,60); closeBtn.Text = "✕"
closeBtn.TextScaled = true; closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextColor3 = Color3.fromRGB(255,255,255); closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,8)

local sub = Instance.new("TextLabel")
sub.Size = UDim2.new(1,-32,0,24); sub.Position = UDim2.new(0,16,0,66)
sub.BackgroundTransparency = 1; sub.Text = "Click a seed, then place it in your garden"
sub.TextXAlignment = Enum.TextXAlignment.Left; sub.TextScaled = true
sub.Font = Enum.Font.Gotham; sub.TextColor3 = Color3.fromRGB(170,200,170); sub.Parent = panel

local grid = Instance.new("ScrollingFrame")
grid.Size = UDim2.new(1,-24,1,-104); grid.Position = UDim2.new(0,12,0,96)
grid.BackgroundTransparency = 1; grid.BorderSizePixel = 0
grid.ScrollBarThickness = 6; grid.ScrollBarImageColor3 = Color3.fromRGB(80,200,80)
grid.CanvasSize = UDim2.new(0,0,0,0); grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
grid.Parent = panel
local gl = Instance.new("UIGridLayout")
gl.CellSize = UDim2.new(0, 144, 0, 160); gl.CellPadding = UDim2.new(0, 12, 0, 12)
gl.HorizontalAlignment = Enum.HorizontalAlignment.Center
gl.SortOrder = Enum.SortOrder.LayoutOrder; gl.Parent = grid

-- ============ confirm dialog ============
local function confirmDialog(text, onYes)
	local cd = Instance.new("Frame")
	cd.Size = UDim2.new(1,0,1,0); cd.BackgroundColor3 = Color3.fromRGB(0,0,0)
	cd.BackgroundTransparency = 0.5; cd.ZIndex = 90; cd.Parent = gui
	local d = Instance.new("Frame")
	d.AnchorPoint = Vector2.new(0.5,0.5); d.Position = UDim2.new(0.5,0,0.5,0)
	d.Size = UDim2.new(0,360,0,180); d.BackgroundColor3 = Color3.fromRGB(24,32,24)
	d.BorderSizePixel = 0; d.ZIndex = 91; d.Parent = cd
	Instance.new("UICorner", d).CornerRadius = UDim.new(0,14)
	local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(90,180,80); st.Thickness=3; st.Parent=d
	local q = Instance.new("TextLabel")
	q.Size = UDim2.new(1,-24,0,96); q.Position = UDim2.new(0,12,0,14)
	q.BackgroundTransparency = 1; q.Text = text; q.TextWrapped = true; q.TextScaled = true
	q.Font = Enum.Font.GothamBold; q.TextColor3 = Color3.fromRGB(230,245,230); q.ZIndex=92; q.Parent = d
	local yes = Instance.new("TextButton")
	yes.Size = UDim2.new(0.45,0,0,44); yes.Position = UDim2.new(0.03,0,1,-54)
	yes.BackgroundColor3 = Color3.fromRGB(70,170,70); yes.Text="✓ Yes"; yes.TextScaled=true
	yes.Font=Enum.Font.GothamBold; yes.TextColor3=Color3.fromRGB(255,255,255); yes.ZIndex=92; yes.Parent=d
	Instance.new("UICorner", yes).CornerRadius = UDim.new(0,8)
	local no = Instance.new("TextButton")
	no.Size = UDim2.new(0.45,0,0,44); no.Position = UDim2.new(0.52,0,1,-54)
	no.BackgroundColor3 = Color3.fromRGB(170,60,60); no.Text="✕ No"; no.TextScaled=true
	no.Font=Enum.Font.GothamBold; no.TextColor3=Color3.fromRGB(255,255,255); no.ZIndex=92; no.Parent=d
	Instance.new("UICorner", no).CornerRadius = UDim.new(0,8)
	yes.MouseButton1Click:Connect(function() cd:Destroy(); if onYes then onYes() end end)
	no.MouseButton1Click:Connect(function() cd:Destroy() end)
end

-- ============ placement mode (with size-based radius rings) ============
local placing, ghost, ghostRing, hint = nil, nil, nil, nil
local existingRings = {}

local function clearExistingRings()
	for _, r in ipairs(existingRings) do
		if r and r.Parent then r:Destroy() end
	end
	existingRings = {}
end

local function stopPlacing()
	placing = nil
	if ghost then ghost:Destroy(); ghost = nil end
	if ghostRing then ghostRing:Destroy(); ghostRing = nil end
	if hint then hint:Destroy(); hint = nil end
	clearExistingRings()
end

local function inBounds(pos)
	local b = state.bounds
	if not b then return false end
	if b.cframe and b.halfX then
		local lp = b.cframe:PointToObjectSpace(Vector3.new(pos.X, b.cframe.Position.Y, pos.Z))
		if math.abs(lp.X) > b.halfX or math.abs(lp.Z) > b.halfZ then return false end
		return true
	end
	return pos.X >= b.minX and pos.X <= b.maxX and pos.Z >= b.minZ and pos.Z <= b.maxZ
end

-- world XZ of an existing plant (from its stored fraction within the current garden)
local function plantWorldXZ(pl)
	local b = state.bounds
	if not b then return nil end
	if b.cframe and b.halfX then
		local localX = (pl.fx or 0.5) * (b.halfX * 2) - b.halfX
		local localZ = (pl.fz or 0.5) * (b.halfZ * 2) - b.halfZ
		local wp = b.cframe:PointToWorldSpace(Vector3.new(localX, 0, localZ))
		return wp.X, wp.Z
	end
	local x = b.minX + (pl.fx or 0.5) * (b.maxX - b.minX)
	local z = b.minZ + (pl.fz or 0.5) * (b.maxZ - b.minZ)
	return x, z
end

-- true if pos is within (newRadius + existingRadius) of any existing plant
local function tooClose(pos, plantName)
	local newR = Prog.getRadius(plantName or placing)
	for _, pl in ipairs(state.plants or {}) do
		local ex, ez = plantWorldXZ(pl)
		if ex then
			local existingR = Prog.getRadius(pl.plant)
			local minDist = newR + existingR
			local dx, dz = pos.X - ex, pos.Z - ez
			if (dx * dx + dz * dz) < (minDist * minDist) then return true end
		end
	end
	return false
end

local function validSpot(pos)
	return inBounds(pos) and not tooClose(pos, placing)
end

local function startPlacing(plantName)
	stopPlacing()
	placing = plantName
	local info = Prog.PLANTS[plantName] or {}
	local r = Prog.getRadius(plantName)
	local topY = (state.bounds and state.bounds.topY) or 1.5

	ghost = Instance.new("Part")
	ghost.Name = "PlantGhost"; ghost.Anchored = true; ghost.CanCollide = false; ghost.CanQuery = false
	ghost.Shape = Enum.PartType.Ball; ghost.Size = Vector3.new(2.2, 2.2, 2.2)
	ghost.Color = info.color or Color3.fromRGB(120, 200, 120); ghost.Material = Enum.Material.ForceField
	ghost.Transparency = 0.25; ghost.Parent = workspace

	ghostRing = Instance.new("Part")
	ghostRing.Name = "PlantRadiusRing"; ghostRing.Anchored = true; ghostRing.CanCollide = false; ghostRing.CanQuery = false
	ghostRing.Shape = Enum.PartType.Cylinder
	ghostRing.Size = Vector3.new(0.15, r * 2, r * 2)
	ghostRing.Color = info.color or Color3.fromRGB(120, 200, 120)
	ghostRing.Material = Enum.Material.Neon
	ghostRing.Transparency = 0.55
	ghostRing.Parent = workspace

	-- Show subtle spacing circles around already-planted plants
	for _, pl in ipairs(state.plants or {}) do
		local ex, ez = plantWorldXZ(pl)
		if ex then
			local er = Prog.getRadius(pl.plant)
			local ring = Instance.new("Part")
			ring.Name = "ExistingPlantRing"
			ring.Anchored = true; ring.CanCollide = false; ring.CanQuery = false
			ring.Shape = Enum.PartType.Cylinder
			ring.Size = Vector3.new(0.12, er * 2, er * 2)
			ring.Color = Color3.fromRGB(255, 190, 80)
			ring.Material = Enum.Material.Neon
			ring.Transparency = 0.65
			ring.CFrame = CFrame.new(ex, topY + 0.08, ez) * CFrame.Angles(0, 0, math.rad(90))
			ring.Parent = workspace
			table.insert(existingRings, ring)
		end
	end

	hint = Instance.new("ScreenGui"); hint.Name = "PlaceHint"; hint.IgnoreGuiInset = true; hint.Parent = pg
	local h = Instance.new("TextLabel")
	h.AnchorPoint = Vector2.new(0.5, 0); h.Position = UDim2.new(0.5, 0, 0, 90); h.Size = UDim2.new(0, 560, 0, 42)
	h.BackgroundColor3 = Color3.fromRGB(20, 28, 20); h.BackgroundTransparency = 0.12
	h.Text = "Click anywhere in YOUR garden to plant " .. plantName .. " • Right-click / Esc to cancel"
	h.TextScaled = true; h.Font = Enum.Font.GothamBold; h.TextColor3 = Color3.fromRGB(190, 235, 190); h.Parent = hint
	Instance.new("UICorner", h).CornerRadius = UDim.new(0, 8)
	dim.Visible = false
end

RunService.RenderStepped:Connect(function()
	if not placing or not ghost or not ghostRing then return end
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local rp = RaycastParams.new()
	local filter = { player.Character, ghost, ghostRing }
	for _, r in ipairs(existingRings) do table.insert(filter, r) end
	rp.FilterDescendantsInstances = filter
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, rp)
	if hit then
		local ok = validSpot(hit.Position)
		local col = ok and (Prog.PLANTS[placing].color or Color3.fromRGB(120, 200, 120)) or Color3.fromRGB(220, 60, 60)
		ghost.Position = hit.Position + Vector3.new(0, 1.2, 0)
		ghost.Color = col
		ghostRing.CFrame = CFrame.new(hit.Position + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ghostRing.Color = col
	end
end)

UIS.InputBegan:Connect(function(input, gpe)
	if not placing then return end
	if input.KeyCode == Enum.KeyCode.Escape or input.UserInputType == Enum.UserInputType.MouseButton2 then
		stopPlacing()
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not gpe then
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		local rp = RaycastParams.new()
		local filter = { player.Character, ghost, ghostRing }
		for _, r in ipairs(existingRings) do table.insert(filter, r) end
		rp.FilterDescendantsInstances = filter
		rp.FilterType = Enum.RaycastFilterType.Exclude
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, rp)
		if hit and inBounds(hit.Position) then
			if tooClose(hit.Position, placing) then
				if hint then
					local lbl = hint:FindFirstChildWhichIsA("TextLabel")
					if lbl then
						lbl.Text = "Too close to another plant's radius! Pick a spot slightly farther away."
						lbl.TextColor3 = Color3.fromRGB(255, 140, 140)
					end
				end
				return
			end
			local pos, pn = hit.Position, placing
			stopPlacing()
			PlantSeed:FireServer(pn, pos.X, pos.Z)
		elseif hit then
			if hint then
				local lbl = hint:FindFirstChildWhichIsA("TextLabel")
				if lbl then
					lbl.Text = "Click inside your fenced Garden soil bed to plant!"
					lbl.TextColor3 = Color3.fromRGB(255, 200, 120)
				end
			end
		end
	end
end)

-- ============ grid ============
local function buildGrid()
	for _, c in ipairs(grid:GetChildren()) do if not c:IsA("UIGridLayout") then c:Destroy() end end
	local any, order = false, 0
	for plantName, count in pairs(state.seeds) do
		if count and count > 0 then
			any = true; order += 1
			local info = Prog.PLANTS[plantName] or {}
			local card = Instance.new("TextButton")
			card.LayoutOrder = order; card.BackgroundColor3 = Color3.fromRGB(32, 42, 32)
			card.BackgroundTransparency = 0.05; card.BorderSizePixel = 0; card.Text = ""; card.Parent = grid
			Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)
			local cst = Instance.new("UIStroke"); cst.Color = info.color or Color3.fromRGB(100, 180, 100); cst.Thickness = 2; cst.Transparency = 0.2; cst.Parent = card
			local em = Instance.new("TextLabel"); em.Size = UDim2.new(1, 0, 0, 64); em.Position = UDim2.new(0, 0, 0, 6)
			em.BackgroundTransparency = 1; em.Text = info.icon or "🌱"; em.TextScaled = true; em.Parent = card
			local nm = Instance.new("TextLabel"); nm.Size = UDim2.new(1, -8, 0, 30); nm.Position = UDim2.new(0, 4, 0, 72)
			nm.BackgroundTransparency = 1; nm.Text = plantName; nm.TextScaled = true; nm.TextWrapped = true
			nm.Font = Enum.Font.GothamBold; nm.TextColor3 = info.color or Color3.fromRGB(220, 240, 220); nm.Parent = card

			local st = info.stageTimes or { 0, 60, 180 }
			local tm = Instance.new("TextLabel"); tm.Size = UDim2.new(1, -8, 0, 22); tm.Position = UDim2.new(0, 4, 0, 104)
			tm.BackgroundTransparency = 1
			tm.Text = (info.rarity or "Common") .. " • S2: " .. Prog.formatDuration(st[2])
			tm.TextScaled = true; tm.Font = Enum.Font.Gotham; tm.TextColor3 = Color3.fromRGB(165, 205, 165); tm.Parent = card

			local cnt = Instance.new("TextLabel"); cnt.Size = UDim2.new(1, -8, 0, 24); cnt.Position = UDim2.new(0, 4, 1, -26)
			cnt.BackgroundTransparency = 1; cnt.Text = "PLANT (x" .. count .. ")"; cnt.TextScaled = true; cnt.Font = Enum.Font.GothamBlack
			cnt.TextColor3 = Color3.fromRGB(140, 255, 140); cnt.Parent = card
			card.MouseButton1Click:Connect(function()
				startPlacing(plantName)
			end)
		end
	end
	if not any then
		local e = Instance.new("TextLabel"); e.Size = UDim2.new(1, 0, 0, 80); e.BackgroundTransparency = 1
		e.Text = "No seeds yet!\nVisit Barnaby the Gardener's Shop to buy Seed Packs."; e.TextScaled = true; e.Font = Enum.Font.Gotham
		e.TextColor3 = Color3.fromRGB(150, 160, 150); e.Parent = grid
	end
end

local function setPanel(open)
	dim.Visible = open
	if open then buildGrid() end   -- ALWAYS rebuild on open (the fix)
end
if seedsBtn then seedsBtn.MouseButton1Click:Connect(function() setPanel(not dim.Visible) end) end
closeBtn.MouseButton1Click:Connect(function() setPanel(false) end)
dim.InputBegan:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 then
		local m=UIS:GetMouseLocation(); local bp,bs=panel.AbsolutePosition,panel.AbsoluteSize
		if m.X<bp.X or m.X>bp.X+bs.X or m.Y<bp.Y or m.Y>bp.Y+bs.Y then setPanel(false) end
	end
end)

-- ============ claim-prompt management + spawn hint ============
local Workspace = workspace
local claimHintGui
local function updateClaimPrompts()
	local gardens = Workspace:FindFirstChild("Map")
	gardens = gardens and gardens:FindFirstChild("Gardens")
	if not gardens then return end
	local haveGarden = state.garden ~= nil
	for i = 1, 6 do
		local plot = gardens:FindFirstChild("Garden_" .. i)
		local bed = plot and (plot:FindFirstChild("SoilBed") or plot:FindFirstChildWhichIsA("BasePart"))
		local cp = bed and bed:FindFirstChild("ClaimPrompt")
		if cp then
			local takenByOther = state.claimedGardens and state.claimedGardens[i] and (state.garden ~= i)
			-- show claim prompt only if I haven't claimed yet AND this garden is free
			cp.Enabled = (not haveGarden) and (not takenByOther)
		end
	end
	-- spawn hint banner until claimed
	if not haveGarden then
		if not claimHintGui then
			claimHintGui = Instance.new("ScreenGui")
			claimHintGui.Name = "ClaimHint"; claimHintGui.IgnoreGuiInset = true; claimHintGui.ResetOnSpawn = false
			claimHintGui.Parent = pg
			local h = Instance.new("TextLabel")
			h.AnchorPoint = Vector2.new(0.5,0); h.Position = UDim2.new(0.5,0,0,30); h.Size = UDim2.new(0,560,0,46)
			h.BackgroundColor3 = Color3.fromRGB(40,90,40); h.BackgroundTransparency = 0.1
			h.Text = "🌱 Walk up to a garden and press E to claim it as your base!"
			h.TextScaled = true; h.Font = Enum.Font.GothamBold; h.TextColor3 = Color3.fromRGB(220,255,220)
			h.Parent = claimHintGui
			Instance.new("UICorner", h).CornerRadius = UDim.new(0,10)
		end
		claimHintGui.Enabled = true
	elseif claimHintGui then
		claimHintGui.Enabled = false
	end
end

GardenSync.OnClientEvent:Connect(function(data)
	if not data or data.openPicker then return end
	state.seeds=data.seeds or {}; state.plants=data.plants or {}
	state.garden=data.garden; state.bounds=data.bounds; state.unlocked=data.unlocked or {}
	state.claimedGardens=data.claimedGardens or {}
	if dim.Visible then buildGrid() end
	updateClaimPrompts()
end)

task.wait(1)
RequestGarden:FireServer()
