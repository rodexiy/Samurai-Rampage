local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local DayNightCycleController = Knit.CreateController({
	Name = "DayNightCycleController",
})

local Player = Players.LocalPlayer

local START_MINUTES_ATTRIBUTE = "DayNightCycleStartMinutes"
local START_SERVER_TIME_ATTRIBUTE = "DayNightCycleStartServerTime"
local MINUTES_PER_SECOND_ATTRIBUTE = "DayNightCycleMinutesPerSecond"
local WAIT_TIME_ATTRIBUTE = "DayNightCycleWaitTime"


local WISDOM_WORLD_CLOCK_TIME = 14
local DEFAULT_WAIT_TIME = 0.25
local DAY_MINUTES = 24 * 60
local STREET_LIGHT_ON_COLOR = Color3.fromRGB(248, 248, 248)
local STREET_LIGHT_OFF_COLOR = Color3.fromRGB(0, 0, 0)

local DefaultStreetLightColors = {}
local DefaultLightPartColors = {}
local LightsOn

local function GetCycleWaitTime()
	return Workspace:GetAttribute(WAIT_TIME_ATTRIBUTE) or DEFAULT_WAIT_TIME
end

local function GetSyncedMinutesAfterMidnight()
	local StartMinutes = Workspace:GetAttribute(START_MINUTES_ATTRIBUTE)
	local StartServerTime = Workspace:GetAttribute(START_SERVER_TIME_ATTRIBUTE)
	local MinutesPerSecond = Workspace:GetAttribute(MINUTES_PER_SECOND_ATTRIBUTE)

	if typeof(StartMinutes) ~= "number" or typeof(StartServerTime) ~= "number" or typeof(MinutesPerSecond) ~= "number" then
		return Lighting:GetMinutesAfterMidnight()
	end

	local Elapsed = math.max(0, Workspace:GetServerTimeNow() - StartServerTime)
	return (StartMinutes + Elapsed * MinutesPerSecond) % DAY_MINUTES
end

local function ApplyStreetLight(Neon: Instance, IsLightsOn: boolean)
	if not Neon:IsA("BasePart") then
		return
	end

	if not DefaultStreetLightColors[Neon] then
		DefaultStreetLightColors[Neon] = Neon.Color
	end

	Neon.Color = if IsLightsOn then DefaultStreetLightColors[Neon] else STREET_LIGHT_OFF_COLOR

	local Parent = Neon.Parent
	if Parent then
		for _, Part in Parent:GetChildren() do
			if not Part:IsA("BasePart") then
				continue
			end

			local IsLightPart = DefaultLightPartColors[Part] ~= nil
				or Part:GetAttribute("HasForceFieldMaterial")
				or Part.Color == STREET_LIGHT_ON_COLOR

			if not IsLightPart then
				continue
			end

			if not DefaultLightPartColors[Part] then
				DefaultLightPartColors[Part] = Part.Color
			end

			Part.Color = if IsLightsOn then DefaultLightPartColors[Part] else STREET_LIGHT_OFF_COLOR
		end
	end

	local PointLight = Neon:FindFirstChildWhichIsA("PointLight")
	if PointLight then
		PointLight.Enabled = IsLightsOn
	end
end

local function ToggleLights(IsLightsOn: boolean)
	if IsLightsOn == LightsOn then
		return
	end

	LightsOn = IsLightsOn

	for _, Neon in CollectionService:GetTagged("StreetLight") do
		ApplyStreetLight(Neon, IsLightsOn)
	end
end

local function UpdateClock()
	if Player:GetAttribute("InWisdomWorld") then
		Lighting.ClockTime = WISDOM_WORLD_CLOCK_TIME
	else
		Lighting:SetMinutesAfterMidnight(GetSyncedMinutesAfterMidnight())
	end

	local ClockTime = Lighting.ClockTime
	ToggleLights(ClockTime <= 6.5 or ClockTime >= 17.5)
end

function DayNightCycleController.KnitStart()
	CollectionService:GetInstanceAddedSignal("StreetLight"):Connect(function(Neon)
		if LightsOn ~= nil then
			ApplyStreetLight(Neon, LightsOn)
		end
	end)

	Player:GetAttributeChangedSignal("InWisdomWorld"):Connect(UpdateClock)

	task.spawn(function()
		while true do
			UpdateClock()
			task.wait(GetCycleWaitTime())
		end
	end)
end

return DayNightCycleController
