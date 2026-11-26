local Players = game:GetService("Players")

local OceanWaveController = require(Players.LocalPlayer.PlayerScripts.Client.Controllers.OceanWaveController)
local Character = script.Parent.Parent.Parent :: Model
local Cleanup = OceanWaveController.Start(Character)

script.Destroying:Connect(Cleanup)
