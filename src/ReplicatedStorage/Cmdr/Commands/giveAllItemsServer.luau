local Knit = require(game.ReplicatedStorage.Packages.Knit)

return function(Context)
	local Player = Context.Executor
	local ItemService = Knit.GetService("ItemService")
	local InventoryService = Knit.GetService("InventoryService")

	local ItemCount = 0
	local AmountAdded = 0

	for ItemName, ItemData in ItemService:GetAllItems() do
		local MaxStack = ItemData.MaxStack or 1
		local Item = ItemService:CreateItem(ItemName, MaxStack)
		if Item then
			local Added = InventoryService:GiveItemToPlayer(Player, Item)
			if Added > 0 then
				ItemCount += 1
				AmountAdded += Added
			end
		end
	end

	return string.format("Added %d item types and %d total items at their maximum stacks.", ItemCount, AmountAdded)
end
