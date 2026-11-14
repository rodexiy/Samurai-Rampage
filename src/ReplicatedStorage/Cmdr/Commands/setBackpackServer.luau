local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local InventoryConfig = require(ReplicatedStorage.Shared.InventoryConfig)

return function(Context: { Executor: Player }, Tier: number, TargetPlayers: { Player }?): string
	local InventoryService = Knit.GetService("InventoryService")
	local Targets = if TargetPlayers and #TargetPlayers > 0 then TargetPlayers else { Context.Executor }
	local Updated = {}
	local Failures = {}

	for _, Player in Targets do
		local Success, Reason = InventoryService:SetBackpackTier(Player, Tier)
		if Success then
			table.insert(Updated, Player.Name)
		else
			table.insert(Failures, string.format("%s (%s)", Player.Name, Reason or "unknown error"))
		end
	end

	local Response = {}
	if #Updated > 0 then
		local Definition = InventoryConfig.Backpacks[Tier]
		table.insert(Response, string.format("Set %s backpack (%dx%d) for %s.", Definition.Name, InventoryConfig.Columns, Definition.Rows, table.concat(Updated, ", ")))
	end
	if #Failures > 0 then
		table.insert(Response, "Failed: " .. table.concat(Failures, ", ") .. ".")
	end

	return table.concat(Response, " ")
end
