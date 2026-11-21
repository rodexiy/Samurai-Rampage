local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local LightingController = Knit.CreateController({
	Name = "LightingController",
})

local LightLoader = require(ReplicatedStorage.Shared.LightLoader)
local IntroCutsceneConfig = require(ReplicatedStorage.Shared.IntroCutsceneConfig)

local Player = Players.LocalPlayer

local WISDOM_WORLD_LIGHTING_NAMES = {
	"WisdomWorld",
	"WisdomWorldLightingPreset",
	"WisdomWorld LightingPreset",
}

local function GetWisdomWorldLighting(): Instance
	for _, LightingName in WISDOM_WORLD_LIGHTING_NAMES do
		local LightingPreset = Lighting:FindFirstChild(LightingName)
		if LightingPreset then
			return LightingPreset
		end
	end

	return Lighting.Normal
end

function LightingController:LoadLighting()
	local LightingToApply

	if Player:GetAttribute("InIntroCutscene") then
		LightingToApply = Lighting:FindFirstChild(IntroCutsceneConfig.StormLightingName) or Lighting.Normal
	elseif Player:GetAttribute("InWisdomWorld") then
		LightingToApply = GetWisdomWorldLighting()
	elseif Player:GetAttribute("LightingRegion") then
		LightingToApply = Lighting:FindFirstChild(Player:GetAttribute("LightingRegion")) or Lighting.Normal
	else
		LightingToApply = Lighting:FindFirstChild(workspace:GetAttribute("Season")) or Lighting.Normal
	end

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

	Player:GetAttributeChangedSignal("InIntroCutscene"):Connect(function()
		LightingController:LoadLighting()
	end)

	LightingController:LoadLighting()
end

return LightingController
