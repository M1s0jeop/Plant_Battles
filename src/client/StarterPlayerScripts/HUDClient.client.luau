local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local hud = gui:WaitForChild("NatureHUD")
local Prog = require(RS:WaitForChild("PlantProgression"))

-- Update Currencies (Nectar & Seeds; hide removed Polievacky & PacksBtn)
local currencies = hud:WaitForChild("Currencies")
local nectarLbl = currencies:WaitForChild("Nectar"):WaitForChild("Val")
local seedsLbl = currencies:WaitForChild("Seeds"):WaitForChild("Val")
local polievackyFrame = currencies:FindFirstChild("Polievacky")
if polievackyFrame then
	polievackyFrame.Visible = false
end

local sidebar = hud:WaitForChild("Sidebar")
local packsBtn = sidebar:FindFirstChild("PacksBtn")
if packsBtn then
	packsBtn.Visible = false
end

local function updateStats()
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local n = ls:FindFirstChild("Nectar")
		if n then nectarLbl.Text = "$ " .. n.Value end

		local s = ls:FindFirstChild("Seeds")
		if s then seedsLbl.Text = "🌱 " .. tostring(s.Value) end
	end
end

player.ChildAdded:Connect(function(c)
	if c.Name == "leaderstats" then
		c.ChildAdded:Connect(function(val)
			val.Changed:Connect(updateStats)
			updateStats()
		end)
		for _, val in ipairs(c:GetChildren()) do
			val.Changed:Connect(updateStats)
		end
		updateStats()
	end
end)

if player:FindFirstChild("leaderstats") then
	for _, val in ipairs(player.leaderstats:GetChildren()) do
		val.Changed:Connect(updateStats)
	end
end
updateStats()

-- Remotes
local remotes = RS:WaitForChild("PackRemotes")
local OpenPack = remotes:WaitForChild("OpenPack")
local ClaimReward = remotes:WaitForChild("ClaimReward")

-- Spinner Logic
local spinState = "idle" -- "idle", "spinning", "waiting_claim"
local spinnerLayer = hud:WaitForChild("SpinnerLayer")
local spinFrame = spinnerLayer:WaitForChild("Frame")
local spinContainer = spinFrame:WaitForChild("SpinContainer")

local claimTxt = spinnerLayer:FindFirstChild("ClaimText")
if not claimTxt then
	claimTxt = Instance.new("TextLabel")
	claimTxt.Name = "ClaimText"
	claimTxt.Size = UDim2.new(1, 0, 0, 50)
	claimTxt.Position = UDim2.new(0, 0, 0.5, 120)
	claimTxt.BackgroundTransparency = 1
	claimTxt.Text = "CLICK ANYWHERE TO CLAIM SEED!"
	claimTxt.Font = Enum.Font.GothamBlack
	claimTxt.TextColor3 = Color3.fromRGB(255, 255, 50)
	claimTxt.TextScaled = true
	claimTxt.Visible = false
	claimTxt.ZIndex = 110
	local str = Instance.new("UIStroke", claimTxt)
	str.Thickness = 4; str.Color = Color3.fromRGB(0, 0, 0)
	claimTxt.Parent = spinnerLayer
end

-- Build the 3-Rarity Gardener Seed Pack Shop UI inside ShopWindow
local shopWin = hud:WaitForChild("WindowsLayer"):WaitForChild("ShopWindow")
local shopContent = shopWin:WaitForChild("Content")
local headerTitle = shopWin:FindFirstChild("Header") and shopWin.Header:FindFirstChildWhichIsA("TextLabel")
if headerTitle then
	headerTitle.Text = "👨‍🌾 GARDENER'S SEED PACKS"
end

-- Widen ShopWindow slightly via WindowManager / direct sizing so 3 rarity cards look great
shopContent:ClearAllChildren()
local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Horizontal
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
listLayout.Padding = UDim.new(0, 12)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = shopContent

local statusBanner = shopWin:FindFirstChild("StatusBanner")
if not statusBanner then
	statusBanner = Instance.new("TextLabel")
	statusBanner.Name = "StatusBanner"
	statusBanner.Size = UDim2.new(1, -24, 0, 22)
	statusBanner.Position = UDim2.new(0, 12, 1, -26)
	statusBanner.BackgroundTransparency = 1
	statusBanner.Text = "Fight players & dummies to earn $ and speed up plant stages!"
	statusBanner.Font = Enum.Font.GothamBold
	statusBanner.TextScaled = true
	statusBanner.TextColor3 = Color3.fromRGB(185, 235, 185)
	statusBanner.Parent = shopWin
end

local function buyAndSpinPack(rarity)
	if spinState ~= "idle" then return end
	local pack = Prog.PACKS[rarity]
	if not pack then return end

	local ls = player:FindFirstChild("leaderstats")
	local nectar = ls and ls:FindFirstChild("Nectar")
	if not nectar or nectar.Value < pack.price then
		statusBanner.Text = "Not enough money! Need $" .. pack.price .. " for " .. pack.name .. "."
		statusBanner.TextColor3 = Color3.fromRGB(255, 110, 110)
		return
	end

	spinState = "spinning"
	local success, sequence, targetIndex = OpenPack:InvokeServer(rarity)
	if success and type(sequence) == "table" then
		if _G.CloseShopWindow then
			_G.CloseShopWindow()
		else
			shopWin.Visible = false
		end
		spinnerLayer.Visible = true
		claimTxt.Visible = false
		spinContainer:ClearAllChildren()

		local ITEM_WIDTH = 150
		for i, item in ipairs(sequence) do
			local card = Instance.new("Frame")
			card.Size = UDim2.new(0, ITEM_WIDTH - 10, 1, -20)
			card.Position = UDim2.new(0, (i - 1) * ITEM_WIDTH + 5, 0, 10)
			card.BackgroundColor3 = Color3.fromRGB(28, 38, 28)
			card.BorderSizePixel = 0
			Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

			local str = Instance.new("UIStroke", card)
			str.Thickness = 4; str.Color = item.color

			local ico = Instance.new("TextLabel")
			ico.Size = UDim2.new(1, 0, 0.55, 0); ico.Position = UDim2.new(0, 0, 0.05, 0)
			ico.BackgroundTransparency = 1; ico.Text = item.icon
			ico.TextScaled = true; ico.Parent = card

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -8, 0.32, 0); lbl.Position = UDim2.new(0, 4, 0.62, 0)
			lbl.BackgroundTransparency = 1; lbl.Text = item.name
			lbl.Font = Enum.Font.GothamBlack; lbl.TextColor3 = item.color
			lbl.TextScaled = true; lbl.Parent = card

			card.Parent = spinContainer
		end

		spinContainer.Position = UDim2.new(0, 0, 0, 0)
		local targetX = -((targetIndex - 1) * ITEM_WIDTH + (ITEM_WIDTH / 2)) + 400
		targetX = targetX + math.random(-35, 35)

		local tw = TweenService:Create(spinContainer, TweenInfo.new(3.8, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, targetX, 0, 0)
		})
		tw:Play()

		tw.Completed:Connect(function()
			task.wait(0.35)
			spinState = "waiting_claim"
			local won = sequence[targetIndex]
			claimTxt.Text = "🌱 YOU GOT: " .. string.upper(won and won.name or "SEED") .. "! CLICK TO CLAIM!"
			claimTxt.Visible = true
		end)
	else
		spinState = "idle"
		statusBanner.Text = tostring(sequence or "Could not open pack!")
		statusBanner.TextColor3 = Color3.fromRGB(255, 110, 110)
	end
end

for order, rarity in ipairs(Prog.PACK_ORDER) do
	local pack = Prog.PACKS[rarity]
	local card = Instance.new("Frame")
	card.Name = rarity .. "PackCard"
	card.LayoutOrder = order
	card.Size = UDim2.new(0, 146, 0, 235)
	card.BackgroundColor3 = Color3.fromRGB(24, 34, 24)
	card.BorderSizePixel = 0
	card.Parent = shopContent
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 12)

	local stroke = Instance.new("UIStroke", card)
	stroke.Color = pack.color
	stroke.Thickness = 2.5

	local badge = Instance.new("TextLabel")
	badge.Size = UDim2.new(1, -12, 0, 22)
	badge.Position = UDim2.new(0, 6, 0, 6)
	badge.BackgroundTransparency = 1
	badge.Text = string.upper(rarity)
	badge.Font = Enum.Font.GothamBlack
	badge.TextScaled = true
	badge.TextColor3 = pack.color
	badge.Parent = card

	local iconLbl = Instance.new("TextLabel")
	iconLbl.Size = UDim2.new(1, 0, 0, 52)
	iconLbl.Position = UDim2.new(0, 0, 0, 28)
	iconLbl.BackgroundTransparency = 1
	iconLbl.Text = pack.icon
	iconLbl.TextScaled = true
	iconLbl.Parent = card

	-- List of plant icons & names inside this pack
	local plantNames = {}
	for _, entry in ipairs(pack.plants) do
		local pinfo = Prog.PLANTS[entry.plant]
		table.insert(plantNames, (pinfo and pinfo.icon or "🌱") .. " " .. entry.plant)
	end
	local poolLbl = Instance.new("TextLabel")
	poolLbl.Size = UDim2.new(1, -12, 0, 92)
	poolLbl.Position = UDim2.new(0, 6, 0, 82)
	poolLbl.BackgroundTransparency = 1
	poolLbl.Text = table.concat(plantNames, "\n")
	poolLbl.Font = Enum.Font.GothamBold
	poolLbl.TextScaled = true
	poolLbl.TextColor3 = Color3.fromRGB(215, 235, 215)
	poolLbl.Parent = card

	local buyBtn = Instance.new("TextButton")
	buyBtn.Name = "BuyPackBtn"
	buyBtn.Size = UDim2.new(1, -16, 0, 42)
	buyBtn.Position = UDim2.new(0, 8, 1, -50)
	buyBtn.BackgroundColor3 = pack.color
	buyBtn.BorderSizePixel = 0
	buyBtn.Text = "BUY $" .. pack.price
	buyBtn.Font = Enum.Font.GothamBlack
	buyBtn.TextScaled = true
	buyBtn.TextColor3 = Color3.fromRGB(20, 25, 20)
	buyBtn.Parent = card
	Instance.new("UICorner", buyBtn).CornerRadius = UDim.new(0, 8)

	buyBtn.MouseButton1Click:Connect(function()
		buyAndSpinPack(rarity)
	end)
end

-- Claim Input after spinner finishes
UIS.InputBegan:Connect(function(input)
	if spinState == "waiting_claim" then
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode ~= Enum.KeyCode.Unknown then
			spinState = "idle"
			spinnerLayer.Visible = false
			claimTxt.Visible = false
			ClaimReward:FireServer()
		end
	end
end)

-- Gardener NPC Shop Proximity & Prompt Integration
ProximityPromptService.PromptTriggered:Connect(function(prompt, plr)
	if plr == player and prompt.Name == "ShopPrompt" then
		if _G.OpenShopWindow then
			_G.OpenShopWindow()
		else
			shopWin.Visible = true
		end
	end
end)

local wasNearGardener = false
RunService.Heartbeat:Connect(function()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local map = workspace:FindFirstChild("Map")
	local shopModel = map and map:FindFirstChild("GardenerShop")
	local counter = shopModel and shopModel:FindFirstChild("Counter")
	if not root or not counter then return end

	local dist = (root.Position - counter.Position).Magnitude
	if dist <= 13 and not wasNearGardener then
		wasNearGardener = true
		if spinState == "idle" and _G.OpenShopWindow then
			_G.OpenShopWindow()
		end
	elseif dist > 17 and wasNearGardener then
		wasNearGardener = false
		if _G.CloseShopWindow then
			_G.CloseShopWindow()
		end
	end
end)

print("HUDClient loaded with 3-Rarity Gardener Seed Pack Shop!")
