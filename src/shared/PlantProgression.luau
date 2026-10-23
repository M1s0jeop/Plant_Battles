-- PlantProgression: single source of truth for the plant -> abilities -> time/combat growth system.
local M = {}

-- Starter abilities unlocked by default so every player can fight immediately to earn money.
M.STARTER_ABILITIES = { "vine_grapple" }

-- 3 Seed Pack Rarities sold by Barnaby the Gardener
M.PACK_ORDER = { "Common", "Rare", "Legendary" }

M.PACKS = {
	["Common"] = {
		id = "Common",
		name = "Common Seed Pack",
		icon = "🌱",
		price = 100,
		color = Color3.fromRGB(90, 210, 90),
		description = "Fast-growing starter plants. Unlocks stages in just a few minutes!",
		plants = {
			{ plant = "Vine Plant",   weight = 30 },
			{ plant = "Tomato Plant", weight = 28 },
			{ plant = "Spring Onion", weight = 22 },
			{ plant = "Kiwi Vine",    weight = 20 },
		},
	},
	["Rare"] = {
		id = "Rare",
		name = "Rare Seed Pack",
		icon = "🌿",
		price = 350,
		color = Color3.fromRGB(70, 165, 255),
		description = "Mid-game tactical plants. Stages take 10–45m of playtime (faster with combat!).",
		plants = {
			{ plant = "Banana Tree",  weight = 25 },
			{ plant = "Coconut Palm", weight = 25 },
			{ plant = "Mushroom",     weight = 20 },
			{ plant = "Walnut",       weight = 15 },
			{ plant = "Rose Bush",    weight = 15 },
		},
	},
	["Legendary"] = {
		id = "Legendary",
		name = "Legendary Seed Pack",
		icon = "🌟",
		price = 1000,
		color = Color3.fromRGB(255, 190, 45),
		description = "Endgame powerhouse plants! Stages take hours up to a full day of playtime & combat.",
		plants = {
			{ plant = "Venus Flytrap",    weight = 30 },
			{ plant = "Sunflower",        weight = 25 },
			{ plant = "Pomegranate Tree", weight = 25 },
			{ plant = "Watermelon",       weight = 20 },
		},
	},
}

-- Each plant family, its rarity, placement radius (studs), stage thresholds (seconds of growth), and 3 abilities.
-- Stage 1 unlocks immediately on planting (0s). Stage 2 unlocks at stageTimes[2], Stage 3 at stageTimes[3].
M.PLANTS = {
	-- COMMON PLANTS (1 - 4 minutes)
	["Vine Plant"] = {
		icon = "🌿", rarity = "Common", radius = 2.8,
		color = Color3.fromRGB(90, 200, 90),
		stageTimes = { 0, 45, 120 }, -- 45s for Stage 2, 2m for Stage 3
		abilities = { "vine_grapple", "vine_cage", "vine_thicket" },
	},
	["Tomato Plant"] = {
		icon = "🍅", rarity = "Common", radius = 2.6,
		color = Color3.fromRGB(225, 70, 60),
		stageTimes = { 0, 60, 180 }, -- 1m for Stage 2, 3m for Stage 3
		abilities = { "tomato", "ketchup_slick", "cherry_barrage" },
	},
	["Spring Onion"] = {
		icon = "🧅", rarity = "Common", radius = 2.4,
		color = Color3.fromRGB(180, 210, 120),
		stageTimes = { 0, 75, 210 }, -- 1m 15s for Stage 2, 3m 30s for Stage 3
		abilities = { "spring_onion", "onion_breath" },
	},
	["Kiwi Vine"] = {
		icon = "🥝", rarity = "Common", radius = 2.5,
		color = Color3.fromRGB(140, 180, 70),
		stageTimes = { 0, 60, 150 },
		abilities = { "kiwi_disengage", "kiwi_toss" },
	},

	-- RARE PLANTS (10 - 45 minutes)
	["Banana Tree"] = {
		icon = "🍌", rarity = "Rare", radius = 3.4,
		color = Color3.fromRGB(245, 210, 70),
		stageTimes = { 0, 600, 1800 }, -- 10m for Stage 2, 30m for Stage 3
		abilities = { "banana_surf", "peel_trap", "banana_boomerang" },
	},
	["Coconut Palm"] = {
		icon = "🥥", rarity = "Rare", radius = 3.6,
		color = Color3.fromRGB(170, 120, 70),
		stageTimes = { 0, 900, 2700 }, -- 15m for Stage 2, 45m for Stage 3
		abilities = { "coconut_slam", "coconut_shield", "coconut_cannon" },
	},
	["Mushroom"] = {
		icon = "🍄", rarity = "Rare", radius = 2.7,
		color = Color3.fromRGB(180, 80, 90),
		stageTimes = { 0, 720, 2100 }, -- 12m for Stage 2, 35m for Stage 3
		abilities = { "mushroom_cloud", "spore_guillotine", "puff_mine" },
	},
	["Walnut"] = {
		icon = "🌰", rarity = "Rare", radius = 3.0,
		color = Color3.fromRGB(150, 110, 60),
		stageTimes = { 0, 600, 1800 },
		abilities = { "walnut_wall" },
	},
	["Rose Bush"] = {
		icon = "🌹", rarity = "Rare", radius = 2.7,
		color = Color3.fromRGB(225, 60, 90),
		stageTimes = { 0, 900, 2400 },
		abilities = { "rose_thorn" },
	},

	-- LEGENDARY PLANTS (2 hours up to 24 hours of playtime)
	["Venus Flytrap"] = {
		icon = "🪴", rarity = "Legendary", radius = 3.4,
		color = Color3.fromRGB(200, 70, 150),
		stageTimes = { 0, 7200, 28800 }, -- 2h for Stage 2, 8h for Stage 3
		abilities = { "flytrap", "flytrap_sentry", "acid_puddle" },
	},
	["Pomegranate Tree"] = {
		icon = "💣", rarity = "Legendary", radius = 3.4,
		color = Color3.fromRGB(200, 40, 70),
		stageTimes = { 0, 10800, 43200 }, -- 3h for Stage 2, 12h for Stage 3
		abilities = { "pomegranate" },
	},
	["Watermelon"] = {
		icon = "🍉", rarity = "Legendary", radius = 3.6,
		color = Color3.fromRGB(90, 190, 90),
		stageTimes = { 0, 10800, 36000 }, -- 3h for Stage 2, 10h for Stage 3
		abilities = { "watermelon_slam" },
	},
	["Sunflower"] = {
		icon = "🌻", rarity = "Legendary", radius = 3.2,
		color = Color3.fromRGB(245, 200, 40),
		stageTimes = { 0, 14400, 86400 }, -- 4h for Stage 2, 24h (1 full day) for Stage 3
		abilities = { "sunflower_beam", "sunflower_orbs", "sunflower_flash" },
	},
}

M.MAX_TIER = 3
M.TIER_THRESHOLDS = { 0, 120, 300 } -- fallback default

-- Combat speed-up & Money rewards
M.TIME_REDUCTION_PER_DAMAGE = 0.5   -- seconds shaved off growth per 1 damage dealt
M.TIME_REDUCTION_PER_KILL = 20      -- seconds shaved off growth per kill
M.MONEY_PER_DAMAGE = 0.5            -- Nectar earned per 1 damage dealt
M.MONEY_PER_KILL = 35               -- Nectar bonus per kill

function M.getThresholds(plantName)
	local data = plantName and M.PLANTS[plantName]
	return (data and data.stageTimes) or M.TIER_THRESHOLDS
end

function M.getRadius(plantName)
	local data = plantName and M.PLANTS[plantName]
	return (data and data.radius) or 2.8
end

-- Supports both M.tierForGrowth(plantName, growthSec) and M.tierForGrowth(growthSec)
function M.tierForGrowth(a, b)
	local plantName, growth
	if type(a) == "string" then
		plantName, growth = a, b or 0
	else
		plantName, growth = nil, a or 0
	end
	local thresholds = M.getThresholds(plantName)
	local tier = 1
	for t = 2, M.MAX_TIER do
		if growth >= (thresholds[t] or math.huge) then
			tier = t
		end
	end
	return tier
end

-- Which ability IDs are unlocked for a plant at a given growth time (seconds)
function M.unlockedAbilities(plantName, growth)
	local data = M.PLANTS[plantName]
	if not data then return {} end
	local tier = M.tierForGrowth(plantName, growth or 0)
	local unlocked = {}
	for i = 1, math.min(tier, #data.abilities) do
		unlocked[#unlocked + 1] = data.abilities[i]
	end
	return unlocked
end

-- Total growth seconds needed to reach the next stage (or nil if Stage 3 reached)
function M.nextTierAt(plantName, growth)
	local data = M.PLANTS[plantName]
	if not data then return nil end
	local tier = M.tierForGrowth(plantName, growth or 0)
	if tier >= M.MAX_TIER then return nil end
	local thresholds = M.getThresholds(plantName)
	return thresholds[tier + 1]
end

-- Remaining seconds until the next stage (or 0 if Stage 3 reached)
function M.timeRemaining(plantName, growth)
	local nextAt = M.nextTierAt(plantName, growth or 0)
	if not nextAt then return 0 end
	return math.max(0, math.ceil(nextAt - (growth or 0)))
end

function M.formatDuration(sec)
	sec = math.max(0, math.floor(sec or 0))
	if sec >= 3600 then
		local h = math.floor(sec / 3600)
		local m = math.floor((sec % 3600) / 60)
		return string.format("%dh %02dm", h, m)
	elseif sec >= 60 then
		local m = math.floor(sec / 60)
		local s = sec % 60
		return string.format("%dm %02ds", m, s)
	else
		return string.format("%ds", sec)
	end
end

return M

