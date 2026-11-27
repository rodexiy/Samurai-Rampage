local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local SmartBoneController = Knit.CreateController({ Name = "SmartBoneController" })
local Player = Players.LocalPlayer
local SMART_BONE_ENABLED = false

function SmartBoneController.KnitStart()
	-- Temporarily disabled until bone loading is resolved.
	if not SMART_BONE_ENABLED then
		return
	end

	local SmartBone = require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Libraries"):WaitForChild("SmartBone") :: ModuleScript)
	local Runtime = SmartBone.Start(Player:GetAttribute("SmartBone") ~= false)
	if not Runtime then
		return
	end

	local function Update()
		Runtime.SetEnabled(Player:GetAttribute("SmartBone") ~= false)
	end

	Player:GetAttributeChangedSignal("SmartBone"):Connect(Update)

	-- Saved settings may change while SmartBone.Start yields.
	Update()
end

return SmartBoneController
