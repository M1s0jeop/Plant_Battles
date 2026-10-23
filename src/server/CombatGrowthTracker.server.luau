-- CombatGrowthTracker: awards money (Nectar) and speeds up garden plant growth timers
-- when players deal damage to or defeat other players or NPCs (Dummies, Sentries, etc.).

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Prog = require(RS:WaitForChild("PlantProgression"))

local ATTRIBUTION_RANGE = 120   -- studs; a player within this of the victim can be credited
local moneyRemainder = {}       -- [userId] = fractional Nectar accumulator

local function awardCombatReward(plr, damage, isKill)
	if not plr then return end
	-- 1. Grant Nectar (money) for buying Seed Packs
	local ls = plr:FindFirstChild("leaderstats")
	local nectar = ls and ls:FindFirstChild("Nectar")
	if nectar then
		local earned = (damage or 0) * (Prog.MONEY_PER_DAMAGE or 0.5) + (isKill and (Prog.MONEY_PER_KILL or 35) or 0)
		local total = (moneyRemainder[plr.UserId] or 0) + earned
		local whole = math.floor(total)
		moneyRemainder[plr.UserId] = total - whole
		if whole > 0 then
			nectar.Value = nectar.Value + whole
		end
	end

	-- 2. Reduce plant stage timers in the player's garden
	if _G.AddCombatGrowth then
		_G.AddCombatGrowth(plr, damage, isKill)
	end
end

-- find the player most likely responsible for damage to `victimRoot`:
-- nearest player (excluding the victim themselves) within range.
local function creditPlayer(victimModel, victimRoot)
	local best, bestDist
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and char ~= victimModel then
			local d = (root.Position - victimRoot.Position).Magnitude
			if d <= ATTRIBUTION_RANGE and (not bestDist or d < bestDist) then
				best, bestDist = plr, d
			end
		end
	end
	return best
end

local tracked = setmetatable({}, {__mode = "k"})

local function watch(model)
	if tracked[model] then return end
	if model.Name == "Gardener" then return end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not hum or not root then return end
	tracked[model] = true

	local lastHealth = hum.Health
	hum.HealthChanged:Connect(function(newHealth)
		local delta = lastHealth - newHealth
		lastHealth = newHealth
		if delta > 0.5 then  -- took damage
			local plr = creditPlayer(model, root)
			if plr then
				awardCombatReward(plr, delta, false)
			end
		end
	end)
	hum.Died:Connect(function()
		local plr = creditPlayer(model, root)
		if plr then
			awardCombatReward(plr, 0, true)  -- kill bonus
		end
	end)
end

-- watch existing + future workspace models with humanoids (dummies, sentries' victims, etc.)
for _, m in ipairs(workspace:GetDescendants()) do
	if m:IsA("Model") then watch(m) end
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Model") then
		task.wait(0.1)
		watch(d)
	elseif d:IsA("Humanoid") then
		local m = d.Parent
		if m and m:IsA("Model") then task.wait(0.1); watch(m) end
	end
end)

print("CombatGrowthTracker loaded!")
