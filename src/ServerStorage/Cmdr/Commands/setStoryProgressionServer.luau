local Knit = require(game.ReplicatedStorage.Packages.Knit)

return function(Context, MissionName: string, TargetPlayers: { Player }?)
	local TutorialService = Knit.GetService("TutorialService")
	local PlayersToUpdate = TargetPlayers
	if not PlayersToUpdate or #PlayersToUpdate == 0 then
		PlayersToUpdate = { Context.Executor }
	end

	local Updated = {}
	local Failures = {}
	local NextMissions = {}

	for _, Player in PlayersToUpdate do
		local Success, Result = TutorialService:SetStoryProgression(Player, MissionName)
		if Success then
			table.insert(Updated, Player.Name)
			NextMissions[Result or "Story complete"] = true
		else
			table.insert(Failures, string.format("%s (%s)", Player.Name, Result))
		end
	end

	local Response = {}
	if #Updated > 0 then
		local Next = {}
		for Mission in NextMissions do
			table.insert(Next, Mission)
		end
		table.sort(Next)
		table.insert(
			Response,
			string.format(
				"Marked %s complete for %s. Next: %s.",
				MissionName,
				table.concat(Updated, ", "),
				table.concat(Next, ", ")
			)
		)
	end
	if #Failures > 0 then
		table.insert(Response, "Failed: " .. table.concat(Failures, ", ") .. ".")
	end

	return table.concat(Response, " ")
end
