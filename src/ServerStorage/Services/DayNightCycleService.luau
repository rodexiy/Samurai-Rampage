local Workspace = game:GetService("Workspace")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local DayNightCycleService = Knit.CreateService({
	Name = "DayNightCycleService",
	Client = {},
})

local TIME_SHIFT = 0.155 -- how many minutes shift every tick
local WAIT_TIME = 0.25 -- length of the tick in seconds
local MINUTES_PER_SECOND = TIME_SHIFT / WAIT_TIME

local START_MINUTES_ATTRIBUTE = "DayNightCycleStartMinutes"
local START_SERVER_TIME_ATTRIBUTE = "DayNightCycleStartServerTime"
local MINUTES_PER_SECOND_ATTRIBUTE = "DayNightCycleMinutesPerSecond"
local WAIT_TIME_ATTRIBUTE = "DayNightCycleWaitTime"

function DayNightCycleService:SyncCycle()
	Workspace:SetAttribute(START_MINUTES_ATTRIBUTE, math.random(4 * 60, 18 * 60))
	Workspace:SetAttribute(START_SERVER_TIME_ATTRIBUTE, Workspace:GetServerTimeNow())
	Workspace:SetAttribute(MINUTES_PER_SECOND_ATTRIBUTE, MINUTES_PER_SECOND)
	Workspace:SetAttribute(WAIT_TIME_ATTRIBUTE, WAIT_TIME)
end

function DayNightCycleService.KnitInit() end

function DayNightCycleService.KnitStart()
	DayNightCycleService:SyncCycle()
end

return DayNightCycleService
