local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local char = script.Parent
local humanoidRoot = char:WaitForChild("HumanoidRootPart")
local camera = workspace.CurrentCamera

local Abilities = RS:WaitForChild("Abilities")
local FireGrapple = Abilities:WaitForChild("FireGrapple")
local GrappleDecision = Abilities:WaitForChild("GrappleDecision")
local GrappleHit = Abilities:WaitForChild("GrappleHit")
local PullDummy = Abilities:WaitForChild("PullDummy")

local COOLDOWN = 3
local MAX_RANGE = 120
local DASH_SPEED = 80
local PULL_SPEED = 140
local DECISION_TIME = 3
local lastUsed = -COOLDOWN

local grappleState = {
    active = false,
    cleanupFn = nil,
    targetModel = nil,
    dashing = false,
    pulling = false
}
_G.GrappleState = grappleState

local SLOT_KEYCODES = {
    [1] = Enum.KeyCode.Q,
    [2] = Enum.KeyCode.E,
    [3] = Enum.KeyCode.R,
    [4] = Enum.KeyCode.F
}
local function getMyKey()
    if _G.EquippedAbilities then
        for s, id in pairs(_G.EquippedAbilities) do
            if id == "vine_grapple" then return SLOT_KEYCODES[s], s end
        end
    end
    return nil, nil
end

-- =====================
-- CROSSHAIR & BEAM
-- =====================

local crossGui = player.PlayerGui:FindFirstChild("CrosshairGui")
if not crossGui then
    crossGui = Instance.new("ScreenGui")
    crossGui.Name = "CrosshairGui"; crossGui.ResetOnSpawn = false
    crossGui.IgnoreGuiInset = true; crossGui.Parent = player.PlayerGui
end
crossGui:ClearAllChildren()
local crossFrame = Instance.new("Frame")
crossFrame.Size = UDim2.new(0,24,0,24); crossFrame.AnchorPoint = Vector2.new(0.5,0.5)
crossFrame.Position = UDim2.new(0.5,0,0.5,0); crossFrame.BackgroundTransparency = 1
crossFrame.Parent = crossGui

local hBar = Instance.new("Frame"); hBar.Size = UDim2.new(1,0,0,2)
hBar.Position = UDim2.new(0,0,0.5,-1); hBar.BackgroundColor3 = Color3.fromRGB(80,255,80)
hBar.BorderSizePixel = 0; hBar.Parent = crossFrame

local vBar = Instance.new("Frame"); vBar.Size = UDim2.new(0,2,1,0)
vBar.Position = UDim2.new(0.5,-1,0,0); vBar.BackgroundColor3 = Color3.fromRGB(80,255,80)
vBar.BorderSizePixel = 0; vBar.Parent = crossFrame

local dot = Instance.new("Frame"); dot.Size = UDim2.new(0,4,0,4)
dot.Position = UDim2.new(0.5,-2,0.5,-2); dot.BackgroundColor3 = Color3.fromRGB(255,255,255)
dot.BorderSizePixel = 0; dot.Parent = crossFrame
Instance.new("UICorner", dot).CornerRadius = UDim.new(1,0)

local outerRing = Instance.new("Frame"); outerRing.Size = UDim2.new(0,38,0,38)
outerRing.AnchorPoint = Vector2.new(0.5,0.5); outerRing.Position = UDim2.new(0.5,0,0.5,0)
outerRing.BackgroundTransparency = 1; outerRing.BorderSizePixel = 0; outerRing.Parent = crossGui
Instance.new("UICorner", outerRing).CornerRadius = UDim.new(1,0)
local ringStroke = Instance.new("UIStroke"); ringStroke.Thickness = 2
ringStroke.Transparency = 1; ringStroke.Parent = outerRing

local function getCenterRay()
    local vp = camera.ViewportSize
    return camera:ViewportPointToRay(vp.X/2, vp.Y/2)
end

RunService.RenderStepped:Connect(function()
    if crossGui then crossGui.Enabled = true end

    local ray = getCenterRay()
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {char}; rp.FilterType = Enum.RaycastFilterType.Exclude
    local res = workspace:Raycast(ray.Origin, ray.Direction * MAX_RANGE, rp)
    if not res then
        hBar.BackgroundColor3 = Color3.fromRGB(255,60,60); vBar.BackgroundColor3 = Color3.fromRGB(255,60,60)
        dot.BackgroundColor3 = Color3.fromRGB(255,60,60); ringStroke.Transparency = 1; return
    end
    local hitModel = res.Instance:FindFirstAncestorOfClass("Model")
    local isEnemy = hitModel and hitModel ~= char and hitModel:FindFirstChildOfClass("Humanoid")
    if isEnemy then
        hBar.BackgroundColor3 = Color3.fromRGB(255,220,0); vBar.BackgroundColor3 = Color3.fromRGB(255,220,0)
        dot.BackgroundColor3 = Color3.fromRGB(255,220,0)
        ringStroke.Color = Color3.fromRGB(255,220,0); ringStroke.Transparency = 0
    else
        hBar.BackgroundColor3 = Color3.fromRGB(80,255,80); vBar.BackgroundColor3 = Color3.fromRGB(80,255,80)
        dot.BackgroundColor3 = Color3.fromRGB(255,255,255); ringStroke.Transparency = 1
    end
end)


local vineBeam, va0, va1 = nil, nil, nil
local function showVineBeam(fromRoot, toParent, toWorldPos)
    if va0 then va0:Destroy() end; if va1 then va1:Destroy() end
    if vineBeam then vineBeam:Destroy() end
    va0 = Instance.new("Attachment"); va0.Parent = fromRoot
    va1 = Instance.new("Attachment")
    if toParent then va1.Parent = toParent
    else va1.WorldPosition = toWorldPos; va1.Parent = workspace.Terrain end
    vineBeam = Instance.new("Beam")
    vineBeam.Attachment0 = va0; vineBeam.Attachment1 = va1
    vineBeam.Color = ColorSequence.new(Color3.fromRGB(34,200,34))
    vineBeam.Width0 = 0.2; vineBeam.Width1 = 0.05; vineBeam.Segments = 25
    vineBeam.CurveSize0 = 1.5; vineBeam.CurveSize1 = 1.5
    vineBeam.FaceCamera = true; vineBeam.LightEmission = 0.9; vineBeam.Parent = workspace
end
local function clearVineBeam()
    if vineBeam then vineBeam:Destroy(); vineBeam = nil end
    if va0 then va0:Destroy(); va0 = nil end
    if va1 then va1:Destroy(); va1 = nil end
end

local function createRootVisual(targetRoot)
    local parts = {}
    local ring = Instance.new("Part"); ring.Size = Vector3.new(4,0.2,4)
    ring.Shape = Enum.PartType.Cylinder
    ring.CFrame = targetRoot.CFrame * CFrame.new(0,-2.5,0) * CFrame.Angles(0,0,math.pi/2)
    ring.Anchored = true; ring.CanCollide = false
    ring.BrickColor = BrickColor.new("Bright green"); ring.Material = Enum.Material.Neon
    ring.Transparency = 0.3; ring.Parent = workspace; table.insert(parts, ring)
    for _, off in ipairs({Vector3.new(1.5,0,0),Vector3.new(-1.5,0,0),Vector3.new(0,0,1.5),Vector3.new(0,0,-1.5)}) do
        local v = Instance.new("Part"); v.Size = Vector3.new(0.2,3,0.2)
        v.CFrame = targetRoot.CFrame * CFrame.new(off); v.Anchored = true; v.CanCollide = false
        v.BrickColor = BrickColor.new("Bright green"); v.Material = Enum.Material.Neon
        v.Transparency = 0.2; v.Parent = workspace; table.insert(parts, v)
    end
    return parts
end
local function removeRootVisual(parts)
    for _, p in ipairs(parts) do if p and p.Parent then p:Destroy() end end
end

local function safeDash(startPos, endPos, speed, onDone)
    local totalDist = (endPos - startPos).Magnitude
    if totalDist < 0.5 then if onDone then onDone() end return end

    local dir = (endPos - startPos).Unit
    local duration = math.clamp(totalDist / speed, 0.08, 0.5)
    local elapsed = 0

    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {char}
    rp.FilterType = Enum.RaycastFilterType.Exclude

    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        elapsed = elapsed + dt
        local alpha = math.min(elapsed / duration, 1)
        local eased = 1 - (1 - alpha)^2
        local targetPos = startPos:Lerp(endPos, eased)

        local stepDir = (targetPos - humanoidRoot.Position)
        local stepDist = stepDir.Magnitude
        if stepDist > 0.1 then
            local wallCheck = workspace:Raycast(humanoidRoot.Position, stepDir.Unit * (stepDist + 0.5), rp)
            if wallCheck then
                humanoidRoot.CFrame = CFrame.new(wallCheck.Position + wallCheck.Normal * 2.5) * humanoidRoot.CFrame.Rotation
                conn:Disconnect()
                if onDone then onDone() end
                return
            end
        end

        humanoidRoot.CFrame = CFrame.new(targetPos) * humanoidRoot.CFrame.Rotation
        if alpha >= 1 then conn:Disconnect(); if onDone then onDone() end end
    end)
end

RunService.Heartbeat:Connect(function()
    _G.AbilityCooldowns = _G.AbilityCooldowns or {}
    _G.AbilityCooldowns["vine_grapple"] = { lastUsed = lastUsed, cd = COOLDOWN }
end)

UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
        local myKey = getMyKey()

    if myKey and input.KeyCode == myKey then
        if tick() - lastUsed < COOLDOWN then return end
        if grappleState.active then return end

        local ray = getCenterRay()
        local rp = RaycastParams.new()
        rp.FilterDescendantsInstances = {char}; rp.FilterType = Enum.RaycastFilterType.Exclude
        local result = workspace:Raycast(ray.Origin, ray.Direction * MAX_RANGE, rp)
        if not result then return end

        local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
        local isChar = hitModel and hitModel ~= char
            and hitModel:FindFirstChildOfClass("Humanoid")
            and hitModel:FindFirstChild("HumanoidRootPart")

        lastUsed = tick()

        if isChar then
            local targetRoot = hitModel:FindFirstChild("HumanoidRootPart")
            local targetHuman = hitModel:FindFirstChildOfClass("Humanoid")
            local hitPlayer = Players:GetPlayerFromCharacter(hitModel)

            showVineBeam(humanoidRoot, targetRoot, nil)
            targetHuman.WalkSpeed = 0; targetHuman.JumpPower = 0
            local rootParts = createRootVisual(targetRoot)
            if hitPlayer then FireGrapple:FireServer(hitPlayer) end

            grappleState.active = true
            grappleState.targetModel = hitModel

            local cleanupDone = false
            local function cleanup(decision, skipPull)
                if cleanupDone then return end
                cleanupDone = true
                grappleState.active = false
                grappleState.targetModel = nil
                clearVineBeam()
                if targetHuman and targetHuman.Parent then
                    targetHuman.WalkSpeed = 16; targetHuman.JumpPower = 50
                end
                removeRootVisual(rootParts)
                if skipPull then return end

                if decision == "LEFT" then
                    local dir = (targetRoot.Position - humanoidRoot.Position).Unit
                    grappleState.dashing = hitModel -- combo window: CoconutClient reads this mid-dash
                    safeDash(humanoidRoot.Position, targetRoot.Position - dir*4 + Vector3.new(0,2,0), DASH_SPEED, function()
                        grappleState.dashing = false
                    end)
                    if hitPlayer then GrappleDecision:FireServer("LEFT") end
                elseif decision == "RIGHT" then
                    if targetHuman and targetHuman.Health > 0 and targetRoot.Parent then
                        grappleState.pulling = hitModel -- combo window: CoconutClient reads this during the pull
                        task.delay(0.8, function()
                            if grappleState.pulling == hitModel then grappleState.pulling = false end
                        end)
                        if hitPlayer then
                            GrappleDecision:FireServer("RIGHT")
                        else
                            PullDummy:FireServer(hitModel)
                        end
                    end
                end
            end

            grappleState.cleanupFn = cleanup
            task.delay(DECISION_TIME, function() cleanup(nil) end)

        else
            local hitPos = result.Position
            showVineBeam(humanoidRoot, nil, hitPos)
            grappleState.terrainDash = true -- separate flag: dashing is reserved for enemy targets (combo)
            safeDash(humanoidRoot.Position, hitPos + Vector3.new(0,3,0), DASH_SPEED, function()
                clearVineBeam()
                grappleState.terrainDash = false
            end)
        end
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if grappleState.active and grappleState.cleanupFn then
            grappleState.cleanupFn("LEFT")
        end
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
        if grappleState.active and grappleState.cleanupFn then
            grappleState.cleanupFn("RIGHT")
        end
    end
end)
