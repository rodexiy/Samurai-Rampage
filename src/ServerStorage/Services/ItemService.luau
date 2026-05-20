local HttpService = game:GetService("HttpService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local ItemService = Knit.CreateService({
	Name = "ItemService",
	Client = {},
})

local Items = require(game.ReplicatedStorage.Shared.Index.Items)
local DeepCopy = require(game.ReplicatedStorage.Shared.Utils.DeepCopy)

function ItemService:GetItemData(ItemName: string)
	return Items[ItemName]
end

function ItemService:ImplementData(Item: {})
	local ItemData = self:GetItemData(Item.Name)
	local NewItem = DeepCopy(Item)
	if ItemData then
		for Key, Value in ItemData do
			if NewItem[Key] == nil then
				NewItem[Key] = Value
			end
		end
	end
	return NewItem
end

function ItemService:CreateItem(Name: string, Amount: number)
	local ItemData = self:GetItemData(Name)

	if not ItemData then
		return
	end

	local Item = {}
	Item.Name = Name

	Item.Stack = math.min(ItemData.MaxStack or 1, Amount)
	return Item
end

function ItemService.KnitInit() end

function ItemService.KnitStart() end

return ItemService
