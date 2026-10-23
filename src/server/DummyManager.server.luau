local PullDummy = game.ReplicatedStorage.Abilities:WaitForChild("PullDummy")
local RunService = game:GetService("RunService")

local activePulls = {} -- [targetRoot] = {bv, conn}

-- Cancel any pull already running on this target and clear stray velocity
-- movers, so forces can never stack across repeated pulls.
local function cancelPull(targetRoot)
	local p = activePulls[targetRoot]
	if p then
		if p.conn then p.conn:Disconnect() end
		if p.bv and p.bv.Parent then p.bv:Destroy() end
		activePulls[targetRoot] = nil
	end
	for _, c in ipairs(targetRoot:GetChildren()) do
		if c:IsA("BodyVelocity") then c:Destroy() end
	end
end

local currentDummy = nil

local function createDummy()
    local dummy = Instance.new("Model")
    dummy.Name = "Dummy"
    dummy.Parent = workspace
    currentDummy = dummy

    local spawnPos = Vector3.new(8, 4, 0)

    local function makePart(name, size, offset, color, canCollide)
        local p = Instance.new("Part")
        p.Name = name
        p.Size = size
        p.CFrame = CFrame.new(spawnPos + offset)
        p.BrickColor = BrickColor.new(color)
        p.CanCollide = canCollide or false
        p.CollisionGroup = "Characters"
        p.Anchored = false
        p.Parent = dummy
        return p
    end

    local root = makePart("HumanoidRootPart", Vector3.new(2,2,1), Vector3.new(0,0,0), "Medium stone grey", false)
    root.Transparency = 1
    local torso = makePart("Torso", Vector3.new(2,2,1), Vector3.new(0,0,0), "Bright red", true)
    local head = makePart("Head", Vector3.new(2,1,1), Vector3.new(0,1.5,0), "Bright yellow", true)
    makePart("Left Arm",  Vector3.new(1,2,1), Vector3.new(-1.5,0,0), "Bright yellow", false)
    makePart("Right Arm", Vector3.new(1,2,1), Vector3.new(1.5,0,0),  "Bright yellow", false)
    makePart("Left Leg",  Vector3.new(1,2,1), Vector3.new(-0.5,-2,0),"Dark blue",     false)
    makePart("Right Leg", Vector3.new(1,2,1), Vector3.new(0.5,-2,0), "Dark blue",     false)

    local humanoid = Instance.new("Humanoid")
    humanoid.MaxHealth = 100
    humanoid.Health = 100
    humanoid.WalkSpeed = 0
    humanoid.JumpPower = 0
    humanoid.Parent = dummy

    local function weld(a, b)
        local w = Instance.new("WeldConstraint")
        w.Part0 = a; w.Part1 = b; w.Parent = a
    end
    weld(root, torso); weld(root, head)
    for _, p in ipairs(dummy:GetChildren()) do
        if p:IsA("BasePart") and p ~= root then
            if not root:FindFirstChild("WC_"..p.Name) then
                local w = Instance.new("WeldConstraint")
                w.Name = "WC_"..p.Name
                w.Part0 = root; w.Part1 = p; w.Parent = root
            end
        end
    end
    dummy.PrimaryPart = root

    -- HP bar
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0,100,0,14)
    bb.StudsOffset = Vector3.new(0,4,0)
    bb.AlwaysOnTop = false; bb.Parent = root
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1,0,1,0)
    bg.BackgroundColor3 = Color3.fromRGB(60,0,0)
    bg.BorderSizePixel = 0; bg.Parent = bb
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0,4)
    local hpBar = Instance.new("Frame")
    hpBar.Size = UDim2.new(1,0,1,0)
    hpBar.BackgroundColor3 = Color3.fromRGB(220,50,50)
    hpBar.BorderSizePixel = 0; hpBar.Parent = bg
    Instance.new("UICorner", hpBar).CornerRadius = UDim.new(0,4)
    humanoid.HealthChanged:Connect(function(hp)
        hpBar.Size = UDim2.new(math.clamp(hp/humanoid.MaxHealth,0,1),0,1,0)
    end)

    humanoid.Died:Connect(function()
        currentDummy = nil
        task.wait(2)
        dummy:Destroy()
        task.wait(0.5)
        createDummy()
    end)

    print("Dummy created!")
    return dummy, root, humanoid
end

-- Pull event - klient pošle "RIGHT" keď chce dummy k sebe
PullDummy.OnServerEvent:Connect(function(player, targetModel)
    if not targetModel or not targetModel.Parent then return end
    local casterChar = player.Character
    if not casterChar then return end
    local casterRoot = casterChar:FindFirstChild("HumanoidRootPart")
    if not casterRoot then return end

    local targetRoot = targetModel:FindFirstChild("HumanoidRootPart")
    local targetHuman = targetModel:FindFirstChildOfClass("Humanoid")
    if not targetRoot or not targetHuman then return end

    -- Unroot HNED
    targetHuman.WalkSpeed = 0
    targetHuman.JumpPower = 0

    -- Only one pull per target at a time (prevents stacked BodyVelocity)
    cancelPull(targetRoot)
    targetRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bv.P = 1e5
    bv.Velocity = Vector3.new(0,0,0)
    bv.Parent = targetRoot

    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not targetRoot or not targetRoot.Parent or not casterRoot.Parent then
            conn:Disconnect()
            if bv and bv.Parent then bv:Destroy() end
            activePulls[targetRoot] = nil
            return
        end
        local dest = casterRoot.Position + casterRoot.CFrame.LookVector * 4 + Vector3.new(0, 1, 0)
        local remaining = dest - targetRoot.Position
        local dist = remaining.Magnitude
        if dist < 1.5 then
            conn:Disconnect()
            bv:Destroy()
            activePulls[targetRoot] = nil
            targetHuman.WalkSpeed = 16
            targetHuman.JumpPower = 50
            targetRoot.AssemblyLinearVelocity = Vector3.new(0, -20, 0)
            return
        end
        bv.Velocity = remaining.Unit * math.min(dist * 12, 140)
    end)

    activePulls[targetRoot] = {bv = bv, conn = conn}

    -- Safety timeout
    task.delay(1.5, function()
        if bv and bv.Parent then
            bv:Destroy()
            conn:Disconnect()
            activePulls[targetRoot] = nil
            if targetHuman and targetHuman.Parent then
                targetHuman.WalkSpeed = 16
                targetHuman.JumpPower = 50
            end
            if targetRoot and targetRoot.Parent then
                targetRoot.AssemblyLinearVelocity = Vector3.new(0, -20, 0)
            end
        end
    end)
end)

local old = workspace:FindFirstChild("Dummy")
if old then old:Destroy() end
createDummy()
