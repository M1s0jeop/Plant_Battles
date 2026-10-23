local TweenService = game:GetService("TweenService")
local hud = script.Parent
local sidebar = hud:WaitForChild("Sidebar")
local layer = hud:WaitForChild("WindowsLayer")
local shopWin = layer:WaitForChild("ShopWindow")
local invWin = layer:WaitForChild("InvWindow")

local shopBtn = sidebar:WaitForChild("ShopBtn")
local invBtn = sidebar:WaitForChild("InvBtn")

local currentWindow = nil

local tweenInfoPop = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local tweenInfoClose = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local function closeWindow(win)
    if not win then return end
    local tw = TweenService:Create(win, tweenInfoClose, {Size = UDim2.new(0, 0, 0, 0)})
    tw:Play()
    tw.Completed:Connect(function()
        if currentWindow ~= win then win.Visible = false end
    end)
    if currentWindow == win then currentWindow = nil end
end

local function openWindow(win)
    if currentWindow == win then
        closeWindow(win)
        return
    end
    if currentWindow then
        closeWindow(currentWindow)
    end
    
    win.Size = UDim2.new(0, 0, 0, 0)
    win.Visible = true
    TweenService:Create(win, tweenInfoPop, {Size = UDim2.new(0, 520, 0, 360)}):Play()
    currentWindow = win
end

_G.OpenShopWindow = function()
    if currentWindow ~= shopWin then
        openWindow(shopWin)
    end
end
_G.CloseShopWindow = function()
    if currentWindow == shopWin then
        closeWindow(shopWin)
    end
end

shopBtn.MouseButton1Click:Connect(function() openWindow(shopWin) end)
invBtn.MouseButton1Click:Connect(function() 
    if _G.ToggleAbilityMenu then 
        _G.ToggleAbilityMenu() 
    end 
end)
        

shopWin.Header.CloseBtn.MouseButton1Click:Connect(function() closeWindow(shopWin) end)
invWin.Header.CloseBtn.MouseButton1Click:Connect(function() closeWindow(invWin) end)

for _, btn in ipairs(sidebar:GetChildren()) do
    if btn:IsA("ImageButton") then
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {Size = UDim2.new(0, 75, 0, 75)}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {Size = UDim2.new(0, 70, 0, 70)}):Play()
        end)
    end
end
