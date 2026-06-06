local Knit = require(game.ReplicatedStorage.Packages.Knit)

return function(_context, ClockTime: number)
	local DayNightCycleService = Knit.GetService("DayNightCycleService")
	DayNightCycleService:SetTime(ClockTime)

	return string.format("Set game time to %.2f.", ClockTime % 24)
end
