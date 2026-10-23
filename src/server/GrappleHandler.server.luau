local RS = game.ReplicatedStorage.Abilities
local FireGrapple = RS:WaitForChild("FireGrapple")
local GrappleDecision = RS:WaitForChild("GrappleDecision")
local GrappleHit = RS:WaitForChild("GrappleHit")

local rootedTargets = {}
local activePulls = {} -- [victimRoot] = {bv, conn}

-- Cancel any pull already running on this victim and clear stray velocity
-- movers, so repeated pulls can never stack their forces.
local function cancelPull(victimRoot)
	local p = activePulls[victimRoot]
	if p then
		if p.conn then p.conn:Disconnect() end
		if p.bv and p.bv.Parent then p.bv:Destroy() end
		activePulls[victimRoot] = nil
	end
	for _, c in ipairs(victimRoot:GetChildren()) do
		if c:IsA("BodyVelocity") then c:Destroy() end
	end
end

FireGrapple.OnServerEvent:Connect(function(caster, targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    local victimChar = targetPlayer.Character
    local victimRoot = victimChar:FindFirstChild("HumanoidRootPart")
    local victimHuman = victimChar:FindFirstChildOfClass("Humanoid")
    if not victimRoot or not victimHuman then return end

    victimHuman.WalkSpeed = 0
    victimHuman.JumpPower = 0
    rootedTargets[caster] = {player = targetPlayer, root = victimRoot, human = victimHuman}

    GrappleHit:FireClient(caster, targetPlayer)

    task.delay(3, function()
        if rootedTargets[caster] then
            local data = rootedTargets[caster]
            if data.human and data.human.Parent then
                data.human.WalkSpeed = 16
                data.human.JumpPower = 50
            end
            rootedTargets[caster] = nil
        end
    end)
end)

GrappleDecision.OnServerEvent:Connect(function(caster, decision)
    local data = rootedTargets[caster]
    if not data then return end

    local casterChar = caster.Character
    if not casterChar then return end
    local casterRoot = casterChar:FindFirstChild("HumanoidRootPart")
    local victimRoot = data.root
    local victimHuman = data.human

    -- Unroot
    if victimHuman and victimHuman.Parent then
        victimHuman.WalkSpeed = 16
        victimHuman.JumpPower = 50
    end
    rootedTargets[caster] = nil

    if not casterRoot or not victimRoot or not victimRoot.Parent then return end

    if decision == "RIGHT" then
        -- Pull the victim to a spot directly in front of the caster (LookVector),
        -- never behind. Only one pull per victim at a time.
        cancelPull(victimRoot)
        victimRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        bv.P = 1e5
        bv.Velocity = Vector3.new(0, 0, 0)
        bv.Parent = victimRoot

        local conn
        conn = game:GetService("RunService").Heartbeat:Connect(function()
            if not victimRoot or not victimRoot.Parent or not casterRoot.Parent then
                conn:Disconnect()
                if bv and bv.Parent then bv:Destroy() end
                activePulls[victimRoot] = nil
                return
            end
            -- dest tracks the caster's facing: always right in front of them
            local dest = casterRoot.Position + casterRoot.CFrame.LookVector * 4 + Vector3.new(0, 2, 0)
            local remaining = dest - victimRoot.Position
            local remDist = remaining.Magnitude
            if remDist < 1.5 then
                conn:Disconnect()
                if bv and bv.Parent then bv:Destroy() end
                activePulls[victimRoot] = nil
                -- Gravity kick - padne normálne, ale bez horizontálnej sily aby neprelietol
                victimRoot.AssemblyLinearVelocity = Vector3.new(0, -5, 0)
                return
            end
            bv.Velocity = remaining.Unit * math.min(remDist * 12, 140)
        end)

        activePulls[victimRoot] = {bv = bv, conn = conn}

        -- Safety timeout in case the victim never reaches the destination
        task.delay(1.5, function()
            if bv and bv.Parent then
                bv:Destroy()
                conn:Disconnect()
                activePulls[victimRoot] = nil
                if victimRoot and victimRoot.Parent then
                    victimRoot.AssemblyLinearVelocity = Vector3.new(0, -5, 0)
                end
            end
        end)
    end
end)

print("GrappleHandler loaded!")
