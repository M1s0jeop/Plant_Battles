local Players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local Prog = require(rs:WaitForChild("PlantProgression"))
local remotes = rs:WaitForChild("PackRemotes")
local BuyPack = remotes:WaitForChild("BuyPack")
local OpenPack = remotes:WaitForChild("OpenPack")
local ClaimReward = remotes:WaitForChild("ClaimReward")

local PendingRewards = {}

local function makePlantReward(plantName, rarity)
	local pinfo = Prog.PLANTS[plantName] or {}
	local packInfo = Prog.PACKS[rarity or pinfo.rarity or "Common"] or {}
	return {
		id = "plant_" .. plantName,
		name = plantName .. " Seed",
		type = "Plant",
		plant = plantName,
		rarity = rarity or pinfo.rarity or "Common",
		amount = 1,
		color = pinfo.color or packInfo.color or Color3.fromRGB(100, 210, 100),
		icon = pinfo.icon or "🌱",
	}
end

local function rollFromPack(rarity)
	local pack = Prog.PACKS[rarity] or Prog.PACKS["Common"]
	local pool = pack.plants
	local totalWeight = 0
	for _, entry in ipairs(pool) do
		totalWeight += (entry.weight or 10)
	end
	local rand = math.random(1, math.max(1, totalWeight))
	local cur = 0
	for _, entry in ipairs(pool) do
		cur += (entry.weight or 10)
		if rand <= cur then
			return makePlantReward(entry.plant, pack.id)
		end
	end
	return makePlantReward(pool[1].plant, pack.id)
end

local function grantPending(player)
	local reward = PendingRewards[player.UserId]
	if not reward then return end
	PendingRewards[player.UserId] = nil
	if reward.type == "Plant" and reward.plant and _G.GrantPlantSeed then
		_G.GrantPlantSeed(player, reward.plant)
	end
end

-- OpenPack(rarity): deducts Nectar for the chosen pack rarity and returns the spinner sequence immediately!
OpenPack.OnServerInvoke = function(player, rarity)
	rarity = (type(rarity) == "string" and Prog.PACKS[rarity]) and rarity or "Common"
	local pack = Prog.PACKS[rarity]
	if not pack then return false, "Invalid pack" end

	-- If player still had an unclaimed reward from a previous spin, grant it first
	if PendingRewards[player.UserId] then
		grantPending(player)
	end

	local ls = player:FindFirstChild("leaderstats")
	local nectar = ls and ls:FindFirstChild("Nectar")
	if not nectar then return false, "No leaderstats" end

	if nectar.Value < pack.price then
		return false, "Need $" .. pack.price .. " (" .. pack.name .. ")"
	end

	-- Deduct pack cost
	nectar.Value = nectar.Value - pack.price

	-- Roll winning seed from this pack's rarity pool
	local reward = rollFromPack(rarity)
	PendingRewards[player.UserId] = reward

	-- Build spinner sequence from this pack's pool
	local sequence = {}
	for i = 1, 40 do
		table.insert(sequence, rollFromPack(rarity))
	end
	table.insert(sequence, reward) -- index 41 is the winner
	for i = 1, 5 do
		table.insert(sequence, rollFromPack(rarity))
	end

	return true, sequence, 41, pack.name
end

BuyPack.OnServerEvent:Connect(function(player, rarity)
	-- Legacy remote fallback if triggered
end)

ClaimReward.OnServerEvent:Connect(function(player)
	grantPending(player)
end)

Players.PlayerRemoving:Connect(function(player)
	grantPending(player)
end)

