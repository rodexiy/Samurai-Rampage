local Lighting = game:GetService("Lighting")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local LightingController = Knit.CreateController({
	Name = "LightingController",
})

local LightLoader = require(game.ReplicatedStorage.Shared.LightLoader)

local Player = game.Players.LocalPlayer

function LightingController:LoadLighting()
	if Player:GetAttribute("LightingRegion") then
		LightLoader:Apply(Lighting:FindFirstChild(Player:GetAttribute("LightingRegion")) or Lighting.Normal)

		return
	end

	local LightingToApply = Lighting:FindFirstChild(workspace:GetAttribute("Season")) or Lighting.Normal
	LightLoader:Apply(LightingToApply)
end

function LightingController.KnitStart()
	workspace:GetAttributeChangedSignal("Season"):Connect(function()
		LightingController:LoadLighting()
	end)

	Player:GetAttributeChangedSignal("LightingRegion"):Connect(function()
		LightingController:LoadLighting()
	end)

	LightingController:LoadLighting()
end

return LightingController
