local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local RemovedItemService = Knit.CreateService({ Name = "RemovedItemService", Client = {} })
local RemovedItems = {
	WindStone = true,
	LanternOfCinders = true,
	LightNagatama = true,
	RottenLotus = true,
	KagutsuchiEmblem = true,
	ThunderHeart = true,
}

function RemovedItemService:Migrate(Data: { [string]: any }): number
	local Count = 0
	local Positions = Data.Backpack and Data.Backpack.Positions
	for Index = #Data.Inventory, 1, -1 do
		local Item = Data.Inventory[Index]
		if RemovedItems[Item.Name] then
			if Positions then
				Positions[Item.Id or Item.Name] = nil
			end
			table.remove(Data.Inventory, Index)
			Count += 1
		end
	end

	for Slot, Name in Data.Hotbar do
		if RemovedItems[Name] then
			Data.Hotbar[Slot] = nil
			if Data.HotbarStackIds then
				Data.HotbarStackIds[Slot] = nil
			end
		end
	end
	if Count > 0 and Data.Backpack then
		Data.Backpack.Revision = (Data.Backpack.Revision or 0) + 1
	end

	return Count
end

return RemovedItemService
