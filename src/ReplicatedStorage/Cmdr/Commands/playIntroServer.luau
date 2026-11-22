local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

return function(Context: { Executor: Player }, TargetPlayers: { Player }?): string
	local IntroCutsceneService = Knit.GetService("IntroCutsceneService")
	local Targets = if TargetPlayers and #TargetPlayers > 0 then TargetPlayers else { Context.Executor }
	local Started = {}
	local Failures = {}

	for _, Player in Targets do
		local Success, Reason = IntroCutsceneService:Replay(Player)
		if Success then
			table.insert(Started, Player.Name)
		else
			table.insert(Failures, string.format("%s (%s)", Player.Name, Reason or "unknown error"))
		end
	end

	local Response = {}
	if #Started > 0 then
		table.insert(Response, "Started intro for " .. table.concat(Started, ", ") .. ".")
	end
	if #Failures > 0 then
		table.insert(Response, "Failed: " .. table.concat(Failures, ", ") .. ".")
	end

	return table.concat(Response, " ")
end
