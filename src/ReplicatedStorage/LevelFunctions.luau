local LevelFunctions = {}

function LevelFunctions:GetPlayerLevelExpNeeded(level)
	return 100 * level ^ 1.3
end

return LevelFunctions
