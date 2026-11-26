local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local DayNightCycleConfig = require(ReplicatedStorage.Shared.DayNightCycleConfig)
local IntroCutsceneConfig = require(ReplicatedStorage.Shared.IntroCutsceneConfig)

local DayNightCycleController = Knit.CreateController({
	Name = "DayNightCycleController",
})

local Player = Players.LocalPlayer

local START_MINUTES_ATTRIBUTE = "DayNightCycleStartMinutes"
local START_SERVER_TIME_ATTRIBUTE = "DayNightCycleStartServerTime"
local WAIT_TIME_ATTRIBUTE = "DayNightCycleWaitTime"


local WISDOM_WORLD_CLOCK_TIME = 14
local STREET_LIGHT_ON_COLOR = Color3.fromRGB(248, 248, 248)
local STREET_LIGHT_OFF_COLOR = Color3.fromRGB(0, 0, 0)

local DefaultStreetLightColors = {}
local DefaultLightPartColors = {}
local LightsOn

local function GetCycleWaitTime(): number
	return workspace:GetAttribute(WAIT_TIME_ATTRIBUTE) or DayNightCycleConfig.UpdateInterval
end

local function GetSyncedMinutesAfterMidnight(): number
	local StartMinutes = workspace:GetAttribute(START_MINUTES_ATTRIBUTE)
	local StartServerTime = workspace:GetAttribute(START_SERVER_TIME_ATTRIBUTE)

	if typeof(StartMinutes) ~= "number" or typeof(StartServerTime) ~= "number" then
		return Lighting:GetMinutesAfterMidnight()
	end

	local Elapsed = math.max(0, workspace:GetServerTimeNow() - StartServerTime)
	return DayNightCycleConfig.GetMinutesAfterMidnight(StartMinutes, Elapsed)
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
	if Player:GetAttribute("InIntroStorm") then
		Lighting.ClockTime = IntroCutsceneConfig.Environment.ClockTime
	elseif Player:GetAttribute("InWisdomWorld") then
		Lighting.ClockTime = WISDOM_WORLD_CLOCK_TIME
	else
		Lighting:SetMinutesAfterMidnight(GetSyncedMinutesAfterMidnight())
	end

	local ClockTime = Lighting.ClockTime
	ToggleLights(ClockTime <= 6.5 or ClockTime >= 17.5)
end

function DayNightCycleController.KnitStart()
	CollectionService:GetInstanceAddedSignal("StreetLight"):Connect(function(Neon: Instance)
		if LightsOn ~= nil then
			ApplyStreetLight(Neon, LightsOn)
		end
	end)

	Player:GetAttributeChangedSignal("InWisdomWorld"):Connect(UpdateClock)
	Player:GetAttributeChangedSignal("InIntroStorm"):Connect(UpdateClock)

	local Elapsed = 0
	RunService.Heartbeat:Connect(function(DeltaTime: number)
		Elapsed += DeltaTime
		local Interval = GetCycleWaitTime()
		if Elapsed < Interval then
			return
		end

		Elapsed %= Interval
		UpdateClock()
	end)

	UpdateClock()
end

return DayNightCycleController
