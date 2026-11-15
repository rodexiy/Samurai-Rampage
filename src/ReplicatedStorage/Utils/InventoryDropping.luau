local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InventoryDeletion = require(ReplicatedStorage.Shared.Utils.InventoryDeletion)
local InventoryDropping = {}

function InventoryDropping.CanDrop(Item: { [string]: any }?): boolean
	return InventoryDeletion.CanDelete(Item)
end

function InventoryDropping.ClampAmount(Amount: number, Stack: number): number
	if Amount ~= Amount then
		return 1
	end

	return math.clamp(math.floor(Amount), 1, Stack)
end

function InventoryDropping.IsValidAmount(Amount: any, Stack: number): boolean
	return typeof(Amount) == "number" and Amount >= 1 and Amount <= Stack and Amount % 1 == 0
end

return InventoryDropping
