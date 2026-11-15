local InventoryStacks = {}
type ItemData = { [string]: any }

function InventoryStacks.Key(Item: ItemData): string
	return Item.Id or Item.Name
end

function InventoryStacks.Find(Entries: { ItemData }, Id: string): ItemData?
	for _, Item in Entries do
		if InventoryStacks.Key(Item) == Id then
			return Item
		end
	end

	return nil
end

function InventoryStacks.Count(Entries: { ItemData }, Name: string): number
	local Amount = 0
	for _, Item in Entries do
		if Item.Name == Name then
			Amount += Item.Stack
		end
	end

	return Amount
end

local function SameData(Left: any, Right: any): boolean
	if typeof(Left) ~= "table" or typeof(Right) ~= "table" then
		return Left == Right
	end
	for Key, Value in Left do
		if not SameData(Value, Right[Key]) then
			return false
		end
	end
	for Key in Right do
		if Left[Key] == nil then
			return false
		end
	end

	return true
end

function InventoryStacks.Compatible(Left: ItemData, Right: ItemData): boolean
	for _, Pair in { { Left, Right }, { Right, Left } } do
		for Key, Value in Pair[1] do
			if Key ~= "Id" and Key ~= "Stack" and not SameData(Value, Pair[2][Key]) then
				return false
			end
		end
	end

	return true
end

function InventoryStacks.Assignments(Data: ItemData, Kind: string): { [string]: string }
	local Result = {}
	local Ids = Data[Kind .. "StackIds"] or {}
	for Slot, Name in Data[Kind] or {} do
		Result[Slot] = Ids[Slot] or Name
	end

	return Result
end

return InventoryStacks
