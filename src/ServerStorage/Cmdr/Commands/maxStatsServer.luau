local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

return function(Context: { Executor: Player }, TargetPlayers: { Player }?): string
	local StatService = Knit.GetService("StatService")
	local Targets = if TargetPlayers and #TargetPlayers > 0 then TargetPlayers else { Context.Executor }
	local Updated = {}
	local Failures = {}

	for _, Player in Targets do
		local Success, Reason = StatService:MaxStats(Player)
		if Success then
			table.insert(Updated, Player.Name)
		else
			table.insert(Failures, string.format("%s (%s)", Player.Name, Reason or "unknown error"))
		end
	end

	local Response = {}
	if #Updated > 0 then
		table.insert(Response, "Maxed all stats for " .. table.concat(Updated, ", ") .. ".")
	end
	if #Failures > 0 then
		table.insert(Response, "Failed: " .. table.concat(Failures, ", ") .. ".")
	end

	return table.concat(Response, " ")
end
