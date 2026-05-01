--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

print("Henderson Roblox Bridge initialized")

local function onPlayerAdded(player)
	print(("Player joined: %s"):format(player.Name))
end

Players.PlayerAdded:Connect(onPlayerAdded)

if RunService:IsStudio() then
	print("Running in Roblox Studio — edit mode active")
end
