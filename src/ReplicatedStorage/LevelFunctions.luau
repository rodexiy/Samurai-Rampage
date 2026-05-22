local LevelFunctions = {}

LevelFunctions.POINTS_PER_LEVEL = 1

function LevelFunctions:GetPlayerLevelExpNeeded(level)
	return 100 * level ^ 1.3
end

function LevelFunctions:GetPlayerFreePointsFromLevel(level)
	return math.max(0, (level - 1) * self.POINTS_PER_LEVEL)
end

return LevelFunctions
