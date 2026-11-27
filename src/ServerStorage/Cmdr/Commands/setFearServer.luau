local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

return function(Context: any, Level: number, TargetPlayers: { Player }?): string
	if Level ~= Level or Level < 0 or Level > 100 then
		return "Fear must be between 0 and 100."
	end

	local FearService = Knit.GetService("FearService")
	local Targets = TargetPlayers or { Context.Executor }
	local Updated: { string } = {}

	for _, Player in Targets do
		FearService:SetFear(Player, Level)
		table.insert(Updated, Player.Name)
	end

	return string.format("Fear set to %g%% for %s.", Level, table.concat(Updated, ", "))
end
