local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local char = script.Parent

-- =====================
-- ABILITY REGISTRY
-- =====================
local ABILITY_DICT = {}
local ALL_ABILITIES = {
    {
        id = "vine_grapple",
        name = "Vine Grapple",
        icon = "🌿",
        description = "Hook onto surfaces or root enemies. LMB to dash, RMB to pull.",
        color = Color3.fromRGB(50, 220, 50),
        cooldown = 3,
        plant = "Vine Plant",
    },
    {
        id = "coconut_slam",
        name = "Coconut Slam",
        icon = "🥥",
        description = "Smash a coconut on nearby enemies. Close range melee attack.",
        color = Color3.fromRGB(220, 150, 40),
        cooldown = 3,
        plant = "Coconut Palm",
    },
    {
        id = "flytrap",
        name = "Venus Flytrap",
        icon = "🌷",
        description = "Dig underground & emerge to ambush. Spit acid projectiles at range.",
        color = Color3.fromRGB(40, 200, 120),
        cooldown = 6,
        plant = "Venus Flytrap",
    },
    {
        id = "banana_surf",
        name = "Banana Surf",
        icon = "🍌",
        description = "Hop on a rapidly accelerating banana. Rams enemies out of the way.",
        color = Color3.fromRGB(255, 220, 50),
        cooldown = 6,
        plant = "Banana Tree",
    },
    {
        id = "vine_cage",
        name = "Vine Cage",
        icon = "🎍",
        description = "Grow a circular vine cage in front of you. Trapped enemies take damage and get knocked back when they try to escape.",
        color = Color3.fromRGB(35, 160, 70),
        cooldown = 8,
        plant = "Vine Plant",
    },
    {
        id = "sunflower_beam",
        name = "Sunflower Beam",
        icon = "🌻",
        description = "Turn into a sunflower and channel a beam at your cursor. Damage ramps up the longer you stay on a target. Slows you and anyone you hit. Press again to cancel.",
        color = Color3.fromRGB(255, 200, 40),
        cooldown = 5,
        plant = "Sunflower",
    },
    {
        id = "sunflower_orbs",
        name = "Sunny Bloom",
        icon = "☀️",
        description = "Burst into bloom and scatter 3 glowing sun orbs in a ring around you. Walk over one to restore HP and gain a short movement speed boost. Orbs are contested - grab them before enemies do.",
        color = Color3.fromRGB(255, 225, 80),
        cooldown = 10,
        plant = "Sunflower",
    },
    {
        id = "sunflower_flash",
        name = "Sunflare Flash",
        icon = "🌟",
        description = "Prime a sunflare grenade, then LMB to lob it (press again to cancel). It bounces and detonates on a fuse, blinding anyone with line of sight who's looking toward it - the more directly they stare at it, the longer they're blinded. CS-style.",
        color = Color3.fromRGB(255, 245, 150),
        cooldown = 12,
        plant = "Sunflower",
    },
    {
        id = "kiwi_disengage",
        name = "Kiwi Disengage",
        icon = "🥝",
        description = "Eat a kiwi to forcefully push all nearby enemies away from you.",
        color = Color3.fromRGB(150, 255, 50),
        cooldown = 4,
        plant = "Kiwi Vine",
    },
    {
        id = "kiwi_toss",
        name = "Kiwi Toss",
        icon = "🥝",
        description = "Lob a kiwi at your cursor that grows bigger the longer and further it flies. Enemies hit get their screen smeared with kiwi slices. Allies (or yourself) hit gain a shield that scales with distance travelled and kiwi size.",
        color = Color3.fromRGB(125, 195, 45),
        cooldown = 7,
        plant = "Kiwi Vine",
    },
    {
        id = "spring_onion",
        name = "Spring Onion Bounce",
        icon = "🧅",
        description = "Slam a spring onion into the ground to vault high into the air. Grants horizontal air control.",
        color = Color3.fromRGB(200, 255, 180),
        cooldown = 8,
        plant = "Spring Onion",
    },
    {
        id = "onion_breath",
        name = "Onion Breath",
        icon = "💨",
        description = "Chomp a raw onion and reek for 6 seconds, trailing stink clouds behind you as you move. Enemies caught in the fumes take damage over time, are slowed, and have their vision hazed and camera shaken. Each cloud lingers 5s after it drops.",
        color = Color3.fromRGB(150, 205, 90),
        cooldown = 12,
        plant = "Spring Onion",
    },
    {
        id = "watermelon_slam",
        name = "Watermelon Slam",
        icon = "🍉",
        description = "Plummet from the sky with a giant watermelon! Damage, radius, and knockback scale exponentially with drop height.",
        color = Color3.fromRGB(255, 100, 100),
        cooldown = 10,
        plant = "Watermelon",
    },
    {
        id = "tomato",
        name = "Tomato",
        icon = "🍅",
        description = "Lob a tomato in a slow arc at your cursor. Direct hits deal damage, slow the target and splatter their screen red. Splashes on the ground.",
        color = Color3.fromRGB(210, 40, 35),
        cooldown = 3,
        plant = "Tomato Plant",
    },
    {
        id = "mushroom_cloud",
        name = "Mushroom Cloud",
        icon = "🍄",
        description = "Drop a spore shroud at your feet. Inside it you're invisible and faster (but can still take damage), while enemies inside get poisoned.",
        color = Color3.fromRGB(160, 90, 210),
        cooldown = 12,
        plant = "Mushroom",
    },
    {
        id = "walnut_wall",
        name = "Walnut Wall",
        icon = "🌰",
        description = "Place a wall of 4 walnuts in front of you - 2 big ones for full cover, 2 small ones you can shoot over. Each nut has its own 300 HP and cracks as it takes damage.",
        color = Color3.fromRGB(155, 110, 62),
        cooldown = 15,
        plant = "Walnut",
    },
    {
        id = "pomegranate",
        name = "Pomegranate",
        icon = "💣",
        description = "Throw a pomegranate grenade in an arc. On impact it splits into seed splinters that scatter and pop one by one in juicy explosions with area damage.",
        color = Color3.fromRGB(175, 20, 45),
        cooldown = 6,
        plant = "Pomegranate Tree",
    },
    {
        id = "ketchup_slick",
        name = "Ketchup Slick",
        icon = "🥫",
        description = "Spray a long line of slippery sauce on the ground. You sprint along it with a big speed boost - enemies on it slip, flop and skid helplessly.",
        color = Color3.fromRGB(185, 28, 22),
        cooldown = 10,
        plant = "Tomato Plant",
    },
    {
        id = "cherry_barrage",
        name = "Cherry Tomato Barrage",
        icon = "🍒",
        description = "Fire a rapid stream of 6 small fast cherry tomatoes. Low damage each, but hits stagger enemies and they shred Walnut Wall shields with bonus damage.",
        color = Color3.fromRGB(220, 45, 40),
        cooldown = 5,
        plant = "Tomato Plant",
    },
    {
        id = "vine_thicket",
        name = "Wild Thicket",
        icon = "🍃",
        description = "Slam the ground and erupt a massive circle of wild vines around you. Enemies caught inside are weighed down - jump nearly removed and movement speed cut in half.",
        color = Color3.fromRGB(40, 125, 40),
        cooldown = 12,
        plant = "Vine Plant",
    },
    {
        id = "coconut_shield",
        name = "Coconut Shield",
        icon = "🛡️",
        description = "Wrap yourself in a coconut shell that blocks ONE instance of damage of any size. It shatters 0.5s after the first blocked hit, absorbing anything else that lands in that window.",
        color = Color3.fromRGB(125, 85, 50),
        cooldown = 10,
        plant = "Coconut Palm",
    },
    {
        id = "coconut_cannon",
        name = "Coconut Cannon",
        icon = "💥",
        description = "Become an immobile mortar with 500 HP. Aim a big reticle anywhere in range with your cursor and fire 3 quick mortar coconuts - each lands fast with a huge 40 dmg blast. LMB or ability key fires.",
        color = Color3.fromRGB(110, 75, 45),
        cooldown = 18,
        plant = "Coconut Palm",
    },
    {
        id = "rose_thorn",
        name = "Rose Thorn",
        icon = "🌹",
        description = "Strike with a hardened rose thorn dagger. Hit an enemy from directly behind for a massive armor-piercing critical that makes them bleed for 3 seconds.",
        color = Color3.fromRGB(170, 30, 60),
        cooldown = 4,
        plant = "Rose Bush",
    },
    {
        id = "spore_guillotine",
        name = "Spore Guillotine",
        icon = "⚔️",
        description = "A heavy melee slash that bursts toxic spores in the target's face. Deals DOUBLE damage as a finisher if they're already trapped or stunned (caged, rooted, staggered, flopped, swallowed).",
        color = Color3.fromRGB(150, 80, 200),
        cooldown = 6,
        plant = "Mushroom",
    },
    {
        id = "peel_trap",
        name = "Peel Trap",
        icon = "💥",
        description = "Throw a giant banana peel that lands where you aim. If an enemy steps on it they ragdoll, slide forward in the direction they were moving, and take minor damage.",
        color = Color3.fromRGB(245, 220, 70),
        cooldown = 7,
        plant = "Banana Tree",
    },
    {
        id = "banana_boomerang",
        name = "Banana Boomerang",
        icon = "🪃",
        description = "HOLD to charge, release to throw a spinning banana boomerang. Charging sends it farther (but it takes longer to return). It pierces through enemies and bounces back off terrain. Returns to your hand - no cooldown but the wait for it to come back.",
        color = Color3.fromRGB(235, 205, 60),
        cooldown = 0,
        plant = "Banana Tree",
    },
    {
        id = "flytrap_sentry",
        name = "Flytrap Sentries",
        icon = "🪴",
        description = "Summon two Venus flytrap sentries that bite nearby enemies. Each bite damages the enemy, heals you, and extends that sentry's lifespan - keep them fed and they live on. 200 HP each and can be destroyed.",
        color = Color3.fromRGB(96, 188, 76),
        cooldown = 14,
        plant = "Venus Flytrap",
    },
    {
        id = "acid_puddle",
        name = "Digestive Dissolve",
        icon = "🧪",
        description = "Spit a pool of corrosive digestive acid where you aim. Enemies standing in it take rapid damage over time, are slowed to half speed, and have their armor broken (shreds shields and pierces through defenses).",
        color = Color3.fromRGB(120, 220, 60),
        cooldown = 9,
        plant = "Venus Flytrap",
    },
}

local MAX_SLOTS = 4
local SLOT_KEYS = {"Q", "E", "R", "F"}
local equipped = {}
equipped[1] = "vine_grapple"

_G.EquippedAbilities = equipped
_G.AbilityRegistry = ALL_ABILITIES
for _, ab in ipairs(ALL_ABILITIES) do
    ABILITY_DICT[ab.id] = ab
end

_G.MenuOpen = false

-- =====================
-- MENU GUI
-- =====================
local menuOpen = false

local gui = Instance.new("ScreenGui")
gui.Name = "AbilityMenuGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player.PlayerGui

-- =====================
-- MAIN MENU OVERLAY
-- =====================
local overlay = Instance.new("Frame")
overlay.Size = UDim2.new(1,0,1,0)
overlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
overlay.BackgroundTransparency = 0.5
overlay.BorderSizePixel = 0
overlay.Visible = false
overlay.ZIndex = 50
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 800, 0, 580)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, -45)
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 18)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.ZIndex = 51
panel.Parent = overlay
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)
-- scale the whole panel down on small screens so it never clips off-edge,
-- and stays centered + consistent at any resolution
local panelScale = Instance.new("UIScale")
panelScale.Parent = panel
local function fitPanel()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local sx = (vp.X - 40) / 800
    local sy = (vp.Y - 40) / 640
    panelScale.Scale = math.clamp(math.min(sx, sy, 1), 0.45, 1)
end
fitPanel()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitPanel)

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(50, 180, 50)
panelStroke.Thickness = 2
panelStroke.Transparency = 0.3
panelStroke.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 50)
title.Position = UDim2.new(0, 0, 0, 10)
title.BackgroundTransparency = 1
title.Text = "🌱  ABILITY LOADOUT  🌱"
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(80, 255, 80)
title.ZIndex = 52
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, 0, 0, 20)
subtitle.Position = UDim2.new(0, 0, 0, 55)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Click ability to equip. Click equipped slot to unequip."
subtitle.TextScaled = true
subtitle.Font = Enum.Font.Gotham
subtitle.TextColor3 = Color3.fromRGB(150, 180, 150)
subtitle.ZIndex = 52
subtitle.Parent = panel

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -50, 0, 10)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "✕"
closeBtn.TextScaled = true
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.ZIndex = 53
closeBtn.Parent = panel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

-- =====================
-- EQUIPPED SLOTS
-- =====================
local slotsLabel = Instance.new("TextLabel")
slotsLabel.Size = UDim2.new(0, 200, 0, 25)
slotsLabel.Position = UDim2.new(0.5, -100, 0, 85)
slotsLabel.BackgroundTransparency = 1
slotsLabel.Text = "⚔️  EQUIPPED SLOTS"
slotsLabel.TextScaled = true
slotsLabel.Font = Enum.Font.GothamBold
slotsLabel.TextColor3 = Color3.fromRGB(200, 220, 200)
slotsLabel.ZIndex = 52
slotsLabel.Parent = panel

local slotsContainer = Instance.new("Frame")
slotsContainer.Size = UDim2.new(0, 500, 0, 90)
slotsContainer.Position = UDim2.new(0.5, -250, 0, 115)
slotsContainer.BackgroundTransparency = 1
slotsContainer.ZIndex = 52
slotsContainer.Parent = panel

local slotFrames = {}
for i = 1, MAX_SLOTS do
    local sf = Instance.new("TextButton")
    sf.Size = UDim2.new(0, 110, 0, 85)
    sf.Position = UDim2.new(0, (i-1) * 125, 0, 0)
    sf.BackgroundColor3 = Color3.fromRGB(30, 35, 30)
    sf.BackgroundTransparency = 0.2
    sf.BorderSizePixel = 0; sf.Text = ""; sf.ZIndex = 53
    sf.AutoButtonColor = false; sf.Parent = slotsContainer
    Instance.new("UICorner", sf).CornerRadius = UDim.new(0, 10)

    local ss = Instance.new("UIStroke")
    ss.Color = Color3.fromRGB(60, 80, 60); ss.Thickness = 2; ss.Parent = sf

    local sk = Instance.new("TextLabel")
    sk.Name = "KeyLabel"; sk.Size = UDim2.new(0,28,0,22)
    sk.Position = UDim2.new(0,5,0,5)
    sk.BackgroundColor3 = Color3.fromRGB(20,20,20); sk.BackgroundTransparency = 0.3
    sk.BorderSizePixel = 0; sk.Text = SLOT_KEYS[i]; sk.TextScaled = true
    sk.Font = Enum.Font.GothamBold; sk.TextColor3 = Color3.fromRGB(200,200,200)
    sk.ZIndex = 54; sk.Parent = sf
    Instance.new("UICorner", sk).CornerRadius = UDim.new(0, 4)

    local si = Instance.new("TextLabel")
    si.Name = "Icon"; si.Size = UDim2.new(1,0,0.5,0)
    si.Position = UDim2.new(0,0,0.05,0); si.BackgroundTransparency = 1
    si.Text = "—"; si.TextScaled = true; si.TextColor3 = Color3.fromRGB(80,80,80)
    si.ZIndex = 54; si.Parent = sf

    local sn = Instance.new("TextLabel")
    sn.Name = "NameLabel"; sn.Size = UDim2.new(1,0,0.25,0)
    sn.Position = UDim2.new(0,0,0.65,0); sn.BackgroundTransparency = 1
    sn.Text = "Empty"; sn.TextScaled = true; sn.Font = Enum.Font.GothamBold
    sn.TextColor3 = Color3.fromRGB(80,80,80); sn.ZIndex = 54; sn.Parent = sf

    sf.MouseButton1Click:Connect(function()
        if equipped[i] then
            equipped[i] = nil
            _G.EquippedAbilities = equipped
        end
    end)

    slotFrames[i] = {frame=sf, stroke=ss, icon=si, name=sn}
end

-- =====================
-- ABILITY CARDS
-- =====================
local abLabel = Instance.new("TextLabel")
abLabel.Size = UDim2.new(0, 250, 0, 25)
abLabel.Position = UDim2.new(0.5, -125, 0, 220)
abLabel.BackgroundTransparency = 1
abLabel.Text = "🌿  AVAILABLE ABILITIES"
abLabel.TextScaled = true; abLabel.Font = Enum.Font.GothamBold
abLabel.TextColor3 = Color3.fromRGB(200, 220, 200)
abLabel.ZIndex = 52; abLabel.Parent = panel

local abContainer = Instance.new("ScrollingFrame")
abContainer.Size = UDim2.new(1, -16, 1, -22)
abContainer.Position = UDim2.new(0, 8, 0, 14)
-- inner background box framing the whole scroll/ability area.
-- It is a STATIC viewport frame: cards scroll within it, and it clips them so
-- nothing renders outside the box. The background is always behind the cards
-- no matter how far you scroll.
local abBg = Instance.new("Frame")
abBg.Name = "AbilityAreaBG"
abBg.Size = UDim2.new(0, 760, 0, 320)
abBg.Position = UDim2.new(0, 20, 0, 256)
abBg.BackgroundColor3 = Color3.fromRGB(12, 16, 12)
abBg.BackgroundTransparency = 0.15
abBg.BorderSizePixel = 0
abBg.ClipsDescendants = true
abBg.ZIndex = 52
abBg.Parent = panel
Instance.new("UICorner", abBg).CornerRadius = UDim.new(0, 14)
local abBgStroke = Instance.new("UIStroke")
abBgStroke.Color = Color3.fromRGB(60, 90, 55)
abBgStroke.Thickness = 2
abBgStroke.Transparency = 0.4
abBgStroke.Parent = abBg
abContainer.BackgroundTransparency = 1
abContainer.BorderSizePixel = 0
abContainer.ZIndex = 52
abContainer.ScrollBarThickness = 6
abContainer.ScrollBarImageColor3 = Color3.fromRGB(80, 200, 80)
abContainer.ScrollingDirection = Enum.ScrollingDirection.Y
abContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
abContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
abContainer.Parent = abBg

local abGrid = Instance.new("UIGridLayout")
abGrid.CellSize = UDim2.new(0, 148, 0, 172)
abGrid.CellPadding = UDim2.new(0, 8, 0, 12)
abGrid.FillDirection = Enum.FillDirection.Horizontal
abGrid.FillDirectionMaxCells = 4   -- 1 plant-marker + 3 ability cards per row
abGrid.SortOrder = Enum.SortOrder.LayoutOrder
abGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
abGrid.Parent = abContainer
-- top/side padding inside the scroll canvas so the first row's card border
-- isn't clipped by the box edge, and cards don't hug the scrollbar
local abInnerPad = Instance.new("UIPadding")
abInnerPad.PaddingTop = UDim.new(0, 10)
abInnerPad.PaddingLeft = UDim.new(0, 6)
abInnerPad.PaddingRight = UDim.new(0, 6)
abInnerPad.Parent = abContainer

-- Build a plant-grouped ordering so abilities from the same plant sit together.
-- Plants appear in the order they first show up in ALL_ABILITIES; within a plant,
-- abilities keep their original relative order.
local plantOrder = {}      -- list of plant names in first-seen order
local plantSeen = {}
local byPlant = {}         -- plant -> { ability, ability, ... }
for _, ab in ipairs(ALL_ABILITIES) do
    local plant = ab.plant or "Other"
    if not plantSeen[plant] then
        plantSeen[plant] = true
        table.insert(plantOrder, plant)
        byPlant[plant] = {}
    end
    table.insert(byPlant[plant], ab)
end
local groupedLayout = {}   -- ability.id -> layout index (grouped by plant)
-- a representative emoji + color per plant, taken from its first ability
local plantInfo = {}       -- plant -> {emoji, color}
local PLANT_EMOJI = {
    ["Vine Plant"] = "\u{1F33F}",
    ["Coconut Palm"] = "\u{1F965}",
    ["Venus Flytrap"] = "\u{1FAB4}",
    ["Banana Tree"] = "\u{1F34C}",
    ["Tomato Plant"] = "\u{1F345}",
    ["Mushroom"] = "\u{1F344}",
    ["Sunflower"] = "\u{1F33B}",
    ["Walnut"] = "\u{1F330}",
    ["Pomegranate Tree"] = "\u{1F4A3}",
    ["Rose Bush"] = "\u{1F339}",
    ["Kiwi"] = "\u{1F95D}",
    ["Spring Onion"] = "\u{1F9C5}",
    ["Watermelon"] = "\u{1F349}",
}
-- each plant gets its own ROW: [marker][ability][ability][ability] = 4 cells.
-- LayoutOrder is assigned in blocks of 4 so families never share a row.
local rowIndex = 0
local abilityStage = {}
for _, plant in ipairs(plantOrder) do
    local base = rowIndex * 4
    plantInfo[plant] = {
        emoji = PLANT_EMOJI[plant] or "\u{1F331}",
        color = (byPlant[plant][1] and byPlant[plant][1].color) or Color3.fromRGB(120,200,120),
        layout = base + 1,   -- the marker cell sits first in the row
    }
    for i, ab in ipairs(byPlant[plant]) do
        groupedLayout[ab.id] = base + 1 + i   -- abilities fill cells 2,3,4 of the row
        abilityStage[ab.id] = i
    end
    rowIndex = rowIndex + 1
end

-- create the plant marker cells (one per family, leading each row)
for plant, info in pairs(plantInfo) do
    local marker = Instance.new("Frame")
    marker.Name = "PlantMarker_" .. plant
    marker.LayoutOrder = info.layout
    marker.BackgroundColor3 = Color3.fromRGB(20, 26, 20)
    marker.BackgroundTransparency = 0.25
    marker.BorderSizePixel = 0
    marker.ZIndex = 53
    marker.Parent = abContainer
    Instance.new("UICorner", marker).CornerRadius = UDim.new(0, 12)
    local ms = Instance.new("UIStroke")
    ms.Color = info.color; ms.Thickness = 2; ms.Transparency = 0.2; ms.Parent = marker

    local me = Instance.new("TextLabel")
    me.Size = UDim2.new(1, 0, 0, 90); me.Position = UDim2.new(0, 0, 0, 35)
    me.BackgroundTransparency = 1; me.Text = info.emoji; me.TextScaled = true
    me.ZIndex = 54; me.Parent = marker

    local mn = Instance.new("TextLabel")
    mn.Size = UDim2.new(1, -10, 0, 44); mn.Position = UDim2.new(0, 5, 0, 130)
    mn.BackgroundTransparency = 1; mn.Text = plant; mn.TextScaled = true
    mn.TextWrapped = true; mn.Font = Enum.Font.GothamBold; mn.TextColor3 = info.color
    mn.ZIndex = 54; mn.Parent = marker
end

-- ===== Garden unlock state =====
-- abilities are LOCKED until unlocked by planting+growing their plant in the garden (starter ability unlocked by default).
local unlockedSet = { ["vine_grapple"] = true }   -- [abilityId] = true once unlocked
local lockCards = {}     -- [abilityId] = { card, statusLabel, overlay, ab, stroke, stageNum }
local function isLocked(ab)
    return not unlockedSet[ab.id]
end

local abilityCards = {}
for idx, ab in ipairs(ALL_ABILITIES) do
    local card = Instance.new("TextButton")
    card.LayoutOrder = groupedLayout[ab.id] or (idx + 9000)
    card.BackgroundColor3 = Color3.fromRGB(25, 30, 25)
    card.BackgroundTransparency = 0.1; card.BorderSizePixel = 0
    card.Text = ""; card.ZIndex = 53; card.AutoButtonColor = false
    card.Parent = abContainer
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

    local cs = Instance.new("UIStroke")
    cs.Color = ab.color; cs.Thickness = 2
    cs.Transparency = isLocked(ab) and 0.7 or 0; cs.Parent = card

    local ci = Instance.new("TextLabel")
    ci.Size = UDim2.new(1,0,0,50); ci.Position = UDim2.new(0,0,0,10)
    ci.BackgroundTransparency = 1; ci.Text = ab.icon; ci.TextScaled = true
    ci.ZIndex = 54; ci.Parent = card

    local cn = Instance.new("TextLabel")
    cn.Size = UDim2.new(1,-10,0,22); cn.Position = UDim2.new(0,5,0,62)
    cn.BackgroundTransparency = 1; cn.Text = ab.name; cn.TextScaled = true
    cn.Font = Enum.Font.GothamBold; cn.TextColor3 = ab.color
    cn.ZIndex = 54; cn.Parent = card

    local cp = Instance.new("TextLabel")
    cp.Size = UDim2.new(1,-10,0,16); cp.Position = UDim2.new(0,5,0,85)
    cp.BackgroundTransparency = 1; cp.Text = "🌱 " .. ab.plant; cp.TextScaled = true
    cp.Font = Enum.Font.Gotham; cp.TextColor3 = Color3.fromRGB(120,160,120)
    cp.ZIndex = 54; cp.Parent = card

    local ct = Instance.new("TextLabel")
    ct.Size = UDim2.new(1,-14,0,22); ct.Position = UDim2.new(0,7,0,108)
    ct.BackgroundTransparency = 1; ct.Text = "⏱ " .. ab.cooldown .. "s"
    ct.TextScaled = true; ct.Font = Enum.Font.GothamBold
    ct.TextColor3 = Color3.fromRGB(150,175,150); ct.ZIndex = 54; ct.Parent = card

    local stg = abilityStage[ab.id] or 1
    local sl = Instance.new("TextLabel")
    sl.Name = "StatusLabel"
    sl.Size = UDim2.new(1,-14,0,28); sl.Position = UDim2.new(0,7,1,-35)
    sl.BackgroundColor3 = isLocked(ab) and Color3.fromRGB(60,30,30) or ab.color
    sl.BackgroundTransparency = 0.5; sl.BorderSizePixel = 0
    sl.Text = isLocked(ab) and ("🔒 STAGE " .. stg) or "EQUIP"
    sl.TextScaled = true; sl.Font = Enum.Font.GothamBold
    sl.TextColor3 = isLocked(ab) and Color3.fromRGB(180,80,80) or Color3.fromRGB(255,255,255)
    sl.ZIndex = 55; sl.Parent = card
    Instance.new("UICorner", sl).CornerRadius = UDim.new(0, 6)

    local lockOverlay = Instance.new("Frame")
    lockOverlay.Name = "LockOverlay"
    lockOverlay.Size = UDim2.new(1,0,1,0); lockOverlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
    lockOverlay.BackgroundTransparency = 0.5; lockOverlay.BorderSizePixel = 0
    lockOverlay.Visible = isLocked(ab)
    lockOverlay.ZIndex = 56; lockOverlay.Parent = card
    Instance.new("UICorner", lockOverlay).CornerRadius = UDim.new(0, 12)

    -- remember the lock-related bits so refreshLocks() can update them live
    lockCards[ab.id] = { card = card, statusLabel = sl, overlay = lockOverlay, ab = ab, stroke = cs, stageNum = stg }

    card.MouseButton1Click:Connect(function()
        if isLocked(ab) then return end
        for s, id in pairs(equipped) do
            if id == ab.id then return end
        end
        for i = 1, MAX_SLOTS do
            if not equipped[i] then
                equipped[i] = ab.id
                _G.EquippedAbilities = equipped
                TweenService:Create(slotFrames[i].frame, TweenInfo.new(0.15), {BackgroundColor3 = ab.color}):Play()
                task.delay(0.15, function()
                    TweenService:Create(slotFrames[i].frame, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(30,35,30)}):Play()
                end)
                return
            end
        end
    end)

    card.MouseEnter:Connect(function()
        if isLocked(ab) then return end
        TweenService:Create(card, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
    end)
    card.MouseLeave:Connect(function()
        TweenService:Create(card, TweenInfo.new(0.15), {BackgroundTransparency = 0.1}):Play()
    end)

    abilityCards[idx] = {card=card, status=sl, stroke=cs}
end

-- =====================
-- UPDATE LOOP
-- =====================
local bottomGui = Instance.new("ScreenGui")
bottomGui.Name = "AbilitiesBottomUI"
bottomGui.ResetOnSpawn = false
bottomGui.Parent = player.PlayerGui

local bottomSlots = {}
local SLOT_KEYS = {"Q", "E", "R", "F"}
for i=1, 4 do
    local slot = Instance.new("Frame")
    slot.Size = UDim2.new(0,80,0,80)
    slot.Position = UDim2.new(0.5, -225 + (i-1)*105, 1, -110)
    slot.BackgroundColor3 = Color3.fromRGB(15,15,15)
    slot.BackgroundTransparency = 0.3
    slot.BorderSizePixel = 0
    slot.Parent = bottomGui
    Instance.new("UICorner", slot).CornerRadius = UDim.new(0,12)

    local border = Instance.new("UIStroke")
    border.Color = Color3.fromRGB(60,60,60)
    border.Thickness = 2
    border.Parent = slot

    local ico = Instance.new("TextLabel")
    ico.Size = UDim2.new(1,0,0.55,0)
    ico.Position = UDim2.new(0,0,0.04,0)
    ico.BackgroundTransparency = 1
    ico.Text = ""
    ico.TextScaled = true
    ico.Parent = slot

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,0,0.2,0)
    lbl.Position = UDim2.new(0,0,0.6,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "EMPTY"
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold
    lbl.TextColor3 = Color3.fromRGB(150,150,150)
    lbl.Parent = slot

    local kl = Instance.new("TextLabel")
    kl.Size = UDim2.new(0.35,0,0.25,0)
    kl.Position = UDim2.new(0.03,0,0.74,0)
    kl.BackgroundColor3 = Color3.fromRGB(30,30,30)
    kl.BackgroundTransparency = 0.2
    kl.BorderSizePixel = 0
    kl.Text = SLOT_KEYS[i]
    kl.TextScaled = true
    kl.Font = Enum.Font.GothamBold
    kl.TextColor3 = Color3.fromRGB(220,220,220)
    kl.Parent = slot
    Instance.new("UICorner", kl).CornerRadius = UDim.new(0,4)

    local cdo = Instance.new("Frame")
    cdo.Size = UDim2.new(1,0,0,0)
    cdo.BackgroundColor3 = Color3.fromRGB(0,0,0)
    cdo.BackgroundTransparency = 0.45
    cdo.BorderSizePixel = 0
    cdo.ZIndex = 5
    cdo.Visible = false
    cdo.Parent = slot
    Instance.new("UICorner", cdo).CornerRadius = UDim.new(0,12)

    local cdt = Instance.new("TextLabel")
    cdt.Size = UDim2.new(1,0,1,0)
    cdt.BackgroundTransparency = 1
    cdt.TextScaled = true
    cdt.Font = Enum.Font.GothamBold
    cdt.TextColor3 = Color3.fromRGB(255,255,255)
    cdt.ZIndex = 6
    cdt.Parent = cdo

    local rf = Instance.new("Frame")
    rf.Size = UDim2.new(1,0,1,0)
    rf.BackgroundColor3 = Color3.fromRGB(255,255,255)
    rf.BackgroundTransparency = 1
    rf.BorderSizePixel = 0
    rf.ZIndex = 7
    rf.Parent = slot
    Instance.new("UICorner", rf).CornerRadius = UDim.new(0,12)

    bottomSlots[i] = {
        frame = slot, iconLabel = ico, nameLabel = lbl, stroke = border,
        cdOverlay = cdo, cdText = cdt, readyFlash = rf, wasOnCD = false
    }
end

RunService.Heartbeat:Connect(function()
    for i=1, 4 do
        local abName = _G.EquippedAbilities[i]
        local s = bottomSlots[i]
        if abName and ABILITY_DICT[abName] then
            local ab = ABILITY_DICT[abName]
            s.iconLabel.Text = ab.icon
            s.nameLabel.Text = ab.name
            s.nameLabel.TextColor3 = ab.color
            
            _G.AbilityCooldowns = _G.AbilityCooldowns or {}
            local cdInfo = _G.AbilityCooldowns[abName]
            if cdInfo then
                local rem = cdInfo.cd - (tick() - cdInfo.lastUsed)
                if rem > 0 then
                    s.wasOnCD = true
                    s.cdOverlay.Visible = true
                    s.cdOverlay.Size = UDim2.new(1,0,math.clamp(rem/cdInfo.cd,0,1),0)
                    s.cdText.Text = string.format("%.1f", rem)
                    s.stroke.Color = Color3.fromRGB(100,100,100)
                    s.iconLabel.TextTransparency = 0.5
                else
                    s.cdOverlay.Visible = false
                    s.cdText.Text = ""
                    s.stroke.Color = ab.color
                    s.iconLabel.TextTransparency = 0
                    if s.wasOnCD then
                        s.wasOnCD = false
                        s.readyFlash.BackgroundTransparency = 0.4
                        TweenService:Create(s.readyFlash, TweenInfo.new(0.5), {BackgroundTransparency=1}):Play()
                    end
                end
            else
                s.cdOverlay.Visible = false
                s.stroke.Color = ab.color
                s.iconLabel.TextTransparency = 0
            end
        else
            s.iconLabel.Text = ""
            s.nameLabel.Text = "EMPTY"
            s.stroke.Color = Color3.fromRGB(60,60,60)
            s.cdOverlay.Visible = false
            s.iconLabel.TextTransparency = 0
        end
    end

    for i = 1, MAX_SLOTS do
        local sd = slotFrames[i]
        local aid = equipped[i]
        local ab = nil
        if aid then
            for _, a in ipairs(ALL_ABILITIES) do
                if a.id == aid then ab = a break end
            end
        end
        if ab then
            sd.icon.Text = ab.icon; sd.icon.TextColor3 = Color3.fromRGB(255,255,255)
            sd.name.Text = ab.name; sd.name.TextColor3 = ab.color
            sd.stroke.Color = ab.color
        else
            sd.icon.Text = "—"; sd.icon.TextColor3 = Color3.fromRGB(80,80,80)
            sd.name.Text = "Empty"; sd.name.TextColor3 = Color3.fromRGB(80,80,80)
            sd.stroke.Color = Color3.fromRGB(60,80,60)
        end

            end

    for idx, ab in ipairs(ALL_ABILITIES) do
        if isLocked(ab) then continue end
        local cd = abilityCards[idx]
        local isEq = false; local sn = 0
        for i, id in pairs(equipped) do
            if id == ab.id then isEq = true; sn = i break end
        end
        if isEq then
            cd.status.Text = "✓ SLOT " .. sn .. " [" .. SLOT_KEYS[sn] .. "]"
            cd.status.BackgroundTransparency = 0.3; cd.stroke.Thickness = 3
        else
            cd.status.Text = "EQUIP"
            cd.status.BackgroundTransparency = 0.5; cd.stroke.Thickness = 2
        end
    end
end)

-- =====================
-- TOGGLE
-- =====================
local function toggleMenu()
    _G.ToggleAbilityMenu = toggleMenu
    menuOpen = not menuOpen
    overlay.Visible = menuOpen
    _G.MenuOpen = menuOpen
    if menuOpen then
        panel.Size = UDim2.new(0, 800, 0, 0)
        TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 800, 0, 580)}):Play()
    end
end

UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.M then toggleMenu() end
end)

closeBtn.MouseButton1Click:Connect(function()
    menuOpen = false; overlay.Visible = false
end)

_G.ToggleAbilityMenu = toggleMenu

-- ===== Garden unlock sync: lock/unlock cards based on planted+grown plants =====
local RSsvc = game:GetService("ReplicatedStorage")
local function refreshLocks()
    for id, info in pairs(lockCards) do
        local locked = not unlockedSet[id]
        info.overlay.Visible = locked
        info.statusLabel.Text = locked and ("🔒 STAGE " .. (info.stageNum or 1)) or "EQUIP"
        info.statusLabel.BackgroundColor3 = locked and Color3.fromRGB(60,30,30) or info.ab.color
        info.statusLabel.TextColor3 = locked and Color3.fromRGB(180,80,80) or Color3.fromRGB(255,255,255)
        if info.stroke then info.stroke.Transparency = locked and 0.7 or 0 end
    end
end

local gardenRemotes = RSsvc:WaitForChild("GardenRemotes", 10)
if gardenRemotes then
    local sync = gardenRemotes:WaitForChild("GardenSync", 10)
    local req = gardenRemotes:FindFirstChild("RequestGarden")
    if sync then
        sync.OnClientEvent:Connect(function(state)
            if not state or state.openPicker then return end  -- ignore picker-only messages
            unlockedSet = {}
            if state and state.unlocked then
                for id, v in pairs(state.unlocked) do unlockedSet[id] = v and true or nil end
            end
            -- if an equipped ability got locked (e.g. data reset), unequip it
            for slot, id in pairs(equipped) do
                if id and not unlockedSet[id] then equipped[slot] = nil end
            end
            _G.EquippedAbilities = equipped
            refreshLocks()
        end)
    end
    if req then req:FireServer() end
end
refreshLocks()

print("AbilityMenu loaded with " .. #ALL_ABILITIES .. " abilities!")
