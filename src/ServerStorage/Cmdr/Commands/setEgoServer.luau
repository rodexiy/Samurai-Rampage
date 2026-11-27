local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

return function(Context: { Executor: Player }, Id: string, TargetPlayers: { Player }?): string
	local EgoService = Knit.GetService("EgoService")
	local Targets = if TargetPlayers and #TargetPlayers > 0 then TargetPlayers else { Context.Executor }
	local Updated: { string } = {}
	local Failures: { string } = {}

	for _, Player in Targets do
		local Success, Reason = EgoService:SetEgo(Player, Id)
		if Success then
			table.insert(Updated, Player.Name)
		else
			table.insert(Failures, string.format("%s (%s)", Player.Name, Reason or "unknown error"))
		end
	end

	local Response: { string } = {}
	if #Updated > 0 then
		table.insert(Response, string.format("Ego set to %s for %s.", Id, table.concat(Updated, ", ")))
	end
	if #Failures > 0 then
		table.insert(Response, "Failed: " .. table.concat(Failures, ", ") .. ".")
	end

	return table.concat(Response, " ")
end
