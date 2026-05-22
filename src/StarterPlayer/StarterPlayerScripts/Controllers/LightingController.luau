local Lighting = game:GetService("Lighting")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local LightingController = Knit.CreateController({
	Name = "LightingController",
})

local LightLoader = require(game.ReplicatedStorage.Shared.LightLoader)

local Player = game.Players.LocalPlayer

local WISDOM_WORLD_LIGHTING_NAMES = {
	"WisdomWorld",
	"WisdomWorldLightingPreset",
	"WisdomWorld LightingPreset",
}

local function GetWisdomWorldLighting()
	for _, LightingName in WISDOM_WORLD_LIGHTING_NAMES do
		local LightingPreset = Lighting:FindFirstChild(LightingName)
		if LightingPreset then
			return LightingPreset
		end
	end

	return Lighting.Normal
end

function LightingController:LoadLighting()
	if Player:GetAttribute("InWisdomWorld") then
		LightLoader:Apply(GetWisdomWorldLighting())

		return
	end

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

	Player:GetAttributeChangedSignal("InWisdomWorld"):Connect(function()
		LightingController:LoadLighting()
	end)

	LightingController:LoadLighting()
end

return LightingController
