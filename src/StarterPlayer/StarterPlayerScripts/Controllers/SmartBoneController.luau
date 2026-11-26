local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local SmartBone = require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Libraries"):WaitForChild("SmartBone"))

local SmartBoneController = Knit.CreateController({ Name = "SmartBoneController" })
local Player = Players.LocalPlayer

function SmartBoneController.KnitStart()
	local Runtime = SmartBone.Start(Player:GetAttribute("SmartBone") ~= false)
	Player:GetAttributeChangedSignal("SmartBone"):Connect(function()
		Runtime.SetEnabled(Player:GetAttribute("SmartBone") ~= false)
	end)

	-- Startup can yield while the player's saved settings are loading.
	Runtime.SetEnabled(Player:GetAttribute("SmartBone") ~= false)
end

return SmartBoneController
