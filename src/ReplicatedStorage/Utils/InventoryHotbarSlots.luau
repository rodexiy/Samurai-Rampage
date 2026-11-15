local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryHotbarSlots = {}

function InventoryHotbarSlots.IsValidIndex(Index: any): boolean
	return typeof(Index) == "number" and Index >= 0 and Index <= 9 and Index % 1 == 0
end

function InventoryHotbarSlots.Accepts(Item: { [string]: any }?): boolean
	if not Item or typeof(Item.Name) ~= "string" or Item.Class == "Weapon" or Item.Class == "Equipable"
		or Item.Class == "Stance" or Item.Type == "Ammunition" or Item.Type == "Bow" then
		return false
	end

	local Tool = ReplicatedStorage.Assets.Tools:FindFirstChild(Item.Name)
	return Item.Class == "Skill" or (Tool ~= nil and Tool:IsA("Tool"))
end

return InventoryHotbarSlots
