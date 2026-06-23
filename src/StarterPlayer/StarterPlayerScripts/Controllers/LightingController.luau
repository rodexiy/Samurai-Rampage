local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local LightingController = Knit.CreateController({
	Name = "LightingController",
})

local LightLoader = require(game.ReplicatedStorage.Shared.LightLoader)

local Player = game.Players.LocalPlayer

local NIGHT_START_TIME = 18
local NIGHT_END_TIME = 5.4
local NIGHT_AMBIENT = Color3.fromRGB(94, 102, 150)
local NIGHT_ATMOSPHERE_VALUE = 0.38
local ATMOSPHERE_TWEEN_INFO = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local WISDOM_WORLD_LIGHTING_NAMES = {
	"WisdomWorld",
	"WisdomWorldLightingPreset",
	"WisdomWorld LightingPreset",
}

local CurrentAtmosphere
local DefaultAtmosphereColor
local DefaultAmbient
local IsNight
local AtmosphereTween

local function IsNightTime(ClockTime: number)
	return ClockTime >= NIGHT_START_TIME or ClockTime < NIGHT_END_TIME
end

local function UpdateAtmosphere()
	local Atmosphere = Lighting:FindFirstChildWhichIsA("Atmosphere")
	local Night = IsNightTime(Lighting.ClockTime)
	local AtmosphereChanged = Atmosphere ~= CurrentAtmosphere

	if not AtmosphereChanged and Night == IsNight then
		return
	end

	if AtmosphereChanged then
		CurrentAtmosphere = Atmosphere
		DefaultAtmosphereColor = if Atmosphere then Atmosphere.Color else nil
	end

	IsNight = Night
	Lighting.Ambient = if Night then NIGHT_AMBIENT else DefaultAmbient

	if not Atmosphere or not DefaultAtmosphereColor then
		return
	end

	local TargetColor = DefaultAtmosphereColor
	if Night then
		local Hue, Saturation, Value = DefaultAtmosphereColor:ToHSV()
		TargetColor = Color3.fromHSV(Hue, Saturation, math.min(Value, NIGHT_ATMOSPHERE_VALUE))
	end

	if AtmosphereTween then
		AtmosphereTween:Cancel()
	end

	print(TargetColor)

	AtmosphereTween = TweenService:Create(Atmosphere, ATMOSPHERE_TWEEN_INFO, {
		Color = TargetColor,
	})
	AtmosphereTween:Play()
end

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
	local LightingToApply

	if Player:GetAttribute("InWisdomWorld") then
		LightingToApply = GetWisdomWorldLighting()
	elseif Player:GetAttribute("LightingRegion") then
		LightingToApply = Lighting:FindFirstChild(Player:GetAttribute("LightingRegion")) or Lighting.Normal
	else
		LightingToApply = Lighting:FindFirstChild(workspace:GetAttribute("Season")) or Lighting.Normal
	end

	LightLoader:Apply(LightingToApply)
	local PresetAmbient = LightingToApply:GetAttribute("Ambient")
	DefaultAmbient = if typeof(PresetAmbient) == "Color3" then PresetAmbient else Lighting.Ambient
	UpdateAtmosphere()
end

function LightingController.KnitStart()
	Lighting:GetPropertyChangedSignal("ClockTime"):Connect(UpdateAtmosphere)

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
