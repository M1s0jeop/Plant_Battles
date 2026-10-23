local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

RunService.RenderStepped:Connect(function()
    local char = player.Character
    if char and char:FindFirstChild("Head") then
        local dist = (camera.CFrame.Position - char.Head.Position).Magnitude
        if dist < 1.5 then
            -- FIRST PERSON
            UIS.MouseIconEnabled = false
        else
            -- THIRD PERSON
            UIS.MouseIconEnabled = true
        end
    else
        UIS.MouseIconEnabled = true
    end
end)
