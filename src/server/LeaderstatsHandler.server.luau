local Players = game:GetService("Players")

local function onPlayerAdded(player)
    local leaderstats = Instance.new("Folder")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = player
    
    local nectar = Instance.new("IntValue")
    nectar.Name = "Nectar"
    nectar.Value = 150 -- Enough starting money to buy your first Common Seed Pack!
    nectar.Parent = leaderstats
    
    local seeds = Instance.new("IntValue")
    seeds.Name = "Seeds"
    seeds.Value = 0
    seeds.Parent = leaderstats
    
    local inv = Instance.new("Folder")
    inv.Name = "Inventory"
    inv.Parent = player
    
    local packs = Instance.new("IntValue")
    packs.Name = "PlantPacks"
    packs.Value = 0
    packs.Parent = inv
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
    onPlayerAdded(p)
end
