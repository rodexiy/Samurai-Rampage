local DayNightCycleConfig = {
	DayStartMinutes = 6 * 60,
	NightStartMinutes = 18 * 60,
	DayDuration = 40 * 60,
	NightDuration = 20 * 60,
	UpdateInterval = 0.25,
}

local MINUTES_PER_DAY = 24 * 60

function DayNightCycleConfig.GetMinutesAfterMidnight(StartMinutes: number, Elapsed: number): number
	local DayMinutes = DayNightCycleConfig.NightStartMinutes - DayNightCycleConfig.DayStartMinutes
	local NightMinutes = MINUTES_PER_DAY - DayMinutes
	local MinutesFromDawn = (StartMinutes - DayNightCycleConfig.DayStartMinutes) % MINUTES_PER_DAY
	local CycleSeconds: number
	if MinutesFromDawn < DayMinutes then
		CycleSeconds = MinutesFromDawn / DayMinutes * DayNightCycleConfig.DayDuration
	else
		CycleSeconds = DayNightCycleConfig.DayDuration
			+ (MinutesFromDawn - DayMinutes) / NightMinutes * DayNightCycleConfig.NightDuration
	end

	local CycleDuration = DayNightCycleConfig.DayDuration + DayNightCycleConfig.NightDuration
	CycleSeconds = (CycleSeconds + math.max(0, Elapsed)) % CycleDuration

	if CycleSeconds < DayNightCycleConfig.DayDuration then
		return (DayNightCycleConfig.DayStartMinutes + CycleSeconds / DayNightCycleConfig.DayDuration * DayMinutes)
			% MINUTES_PER_DAY
	end

	return (DayNightCycleConfig.NightStartMinutes
		+ (CycleSeconds - DayNightCycleConfig.DayDuration) / DayNightCycleConfig.NightDuration * NightMinutes)
		% MINUTES_PER_DAY
end

return DayNightCycleConfig
