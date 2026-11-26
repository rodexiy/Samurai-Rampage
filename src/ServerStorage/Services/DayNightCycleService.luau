local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local DayNightCycleConfig = require(ReplicatedStorage.Shared.DayNightCycleConfig)

local DayNightCycleService = Knit.CreateService({
	Name = "DayNightCycleService",
	Client = {},
})

local START_MINUTES_ATTRIBUTE = "DayNightCycleStartMinutes"
local START_SERVER_TIME_ATTRIBUTE = "DayNightCycleStartServerTime"
local WAIT_TIME_ATTRIBUTE = "DayNightCycleWaitTime"

function DayNightCycleService:SyncCycle(StartMinutes: number?)
	workspace:SetAttribute(START_MINUTES_ATTRIBUTE, StartMinutes or math.random(4 * 60, 18 * 60))
	workspace:SetAttribute(START_SERVER_TIME_ATTRIBUTE, workspace:GetServerTimeNow())
	workspace:SetAttribute(WAIT_TIME_ATTRIBUTE, DayNightCycleConfig.UpdateInterval)
end

function DayNightCycleService:SetTime(ClockTime: number)
	local StartMinutes = (ClockTime % 24) * 60
	Lighting:SetMinutesAfterMidnight(StartMinutes)
	self:SyncCycle(StartMinutes)
end

function DayNightCycleService.KnitInit() end

function DayNightCycleService.KnitStart()
	DayNightCycleService:SyncCycle()

	Lighting:GetPropertyChangedSignal("ClockTime"):Connect(function()
		DayNightCycleService:SyncCycle(Lighting:GetMinutesAfterMidnight())
	end)
end

return DayNightCycleService
