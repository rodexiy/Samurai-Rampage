local Knit = require(game.ReplicatedStorage.Packages.Knit)

return function(Context, TargetPlayers: { Player }?)
	local PlayerService = Knit.GetService("PlayerService")
	local PlayersToReset = TargetPlayers

	if not PlayersToReset or #PlayersToReset == 0 then
		PlayersToReset = { Context.Executor }
	end

	local ResetNames = {}
	local Failures = {}

	for _, Player in PlayersToReset do
		local Success, Message = PlayerService:ResetDataAndRestartTutorial(Player)
		if Success then
			table.insert(ResetNames, Player.Name)
		else
			table.insert(Failures, string.format("%s (%s)", Player.Name, Message or "unknown error"))
		end
	end

	local Response = {}
	if #ResetNames > 0 then
		table.insert(Response, "Reset data and restarted tutorial for " .. table.concat(ResetNames, ", ") .. ".")
	end
	if #Failures > 0 then
		table.insert(Response, "Failed: " .. table.concat(Failures, ", ") .. ".")
	end

	return table.concat(Response, " ")
end
