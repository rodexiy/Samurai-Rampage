local InventoryDeletion = {}

function InventoryDeletion.CanDelete(Item: { [string]: any }?): boolean
	return Item ~= nil
		and typeof(Item.Name) == "string"
		and typeof(Item.Stack) == "number"
		and Item.Stack > 0
		and Item.Stack < math.huge
		and Item.Stack % 1 == 0
		and not Item.Hidden
		and Item.Class ~= "Skill"
		and Item.Class ~= "Stance"
		and not Item.Equipped
		and not Item.EquippedLeft
end

return InventoryDeletion
