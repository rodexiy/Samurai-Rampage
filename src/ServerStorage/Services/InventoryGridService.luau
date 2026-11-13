local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local InventoryConfig = require(ReplicatedStorage.Shared.InventoryConfig)
local InventoryGrid = require(ReplicatedStorage.Shared.Utils.InventoryGrid)
local DeepCopy = require(ReplicatedStorage.Shared.Utils.DeepCopy)

type ItemData = InventoryConfig.ItemData
type Positions = { [string]: InventoryGrid.Placement }

local InventoryGridService = Knit.CreateService({Name = "InventoryGridService", Client = {}})
local DataService
local ItemService

local function UsesGrid(Item: ItemData, Equipped: { [string]: string }): boolean
	return not Item.Hidden and Item.Class ~= "Skill" and Item.Class ~= "Stance"
		and not (Item.Class == "Equipable" and Equipped[Item.Type] == Item.Name)
end

local function GetItems(Data: ItemData): ({ ItemData }, { [string]: ItemData })
	local Items, ByName = {}, {}
	for _, Raw in Data.Inventory do
		local Item = ItemService:ImplementData(Raw)
		ByName[Item.Name] = Item
		if UsesGrid(Item, Data.Equipped) then
			table.insert(Items, Item)
		end
	end

	return Items, ByName
end

local function IsSavedPosition(Position: any): boolean
	return typeof(Position) == "table" and InventoryGrid.IsInteger(Position.Column)
		and InventoryGrid.IsInteger(Position.Row) and typeof(Position.Rotated) == "boolean"
end

function InventoryGridService:GetLayout(Player: Player): ItemData
	local Data = DataService:GetData(Player)
	local Items = GetItems(Data)
	local Backpack = Data.Backpack
	if not Backpack then
		Backpack = {Version = 0, Columns = InventoryConfig.Columns, Rows = InventoryConfig.Rows, Revision = 0, Positions = {}}
		Data.Backpack = Backpack
	end

	if Backpack.Version == 0 then
		-- Preserve existing inventories during the one-time migration, without deleting excess items.
		local Legacy = InventoryGrid.Arrange(Items, Backpack.Columns, Backpack.Rows)
		Backpack.Rows = Legacy.Rows
		for Index, Item in Items do
			Backpack.Positions[Item.Name] = Legacy.Placements[Index]
		end
		Backpack.Version = 1
	end

	local Positions: Positions = {}
	local Overflow = {}
	for _, Item in Items do
		local Saved = Backpack.Positions[Item.Name]
		if IsSavedPosition(Saved) then
			local Candidate = InventoryGrid.Placement(Item, Saved.Column, Saved.Row, Saved.Rotated)
			if InventoryGrid.Fits(Positions, Candidate, Backpack.Columns, Backpack.Rows) then
				Positions[Item.Name] = Candidate
			end
		end
	end

	for _, Item in Items do
		if not Positions[Item.Name] then
			local Candidate = InventoryGrid.FindPlacement(Item, Positions, Backpack.Columns, Backpack.Rows)
			if Candidate then
				Positions[Item.Name] = Candidate
			else
				table.insert(Overflow, Item.Name)
			end
		end
	end

	local Changed = false
	for Name, Position in Positions do
		local Previous = Backpack.Positions[Name]
		if not Previous or Previous.Column ~= Position.Column or Previous.Row ~= Position.Row or Previous.Rotated ~= Position.Rotated then
			Changed = true
		end
	end
	for Name in Backpack.Positions do
		if not Positions[Name] then
			Changed = true
		end
	end
	if Changed then
		Backpack.Revision += 1
	end

	Backpack.Positions = Positions
	return {Columns = Backpack.Columns, Rows = Backpack.Rows, Revision = Backpack.Revision, Positions = DeepCopy(Positions), Overflow = Overflow}
end

function InventoryGridService:Move(Player: Player, Name: any, Column: any, Row: any, Rotated: any, Revision: any): (boolean, string?)
	if typeof(Name) ~= "string" or not InventoryGrid.IsInteger(Column) or not InventoryGrid.IsInteger(Row)
		or typeof(Rotated) ~= "boolean" then
		return false, "Invalid inventory position."
	end

	local Data = DataService:GetData(Player)
	if not Data then
		return false, "Inventory is not ready."
	end

	local Layout = self:GetLayout(Player)
	if Revision ~= Layout.Revision then
		return false, "Inventory changed. Try again."
	end

	local _, Items = GetItems(Data)
	local Item = Items[Name]
	if not Item or not UsesGrid(Item, Data.Equipped) then
		return false, "This item cannot be moved."
	end

	local Candidate = InventoryGrid.Placement(Item, Column, Row, Rotated)
	if not InventoryGrid.Fits(Layout.Positions, Candidate, Layout.Columns, Layout.Rows, Name) then
		return false, "That space is blocked."
	end

	Data.Backpack.Positions[Name] = Candidate
	Data.Backpack.Revision += 1
	return true
end

function InventoryGridService:SetEquipment(Player: Player, Slot: any, NewName: any, ExpectedName: string?): (boolean, string?)
	local Data = DataService:GetData(Player)
	if not Data or typeof(Slot) ~= "string" or (NewName ~= nil and typeof(NewName) ~= "string") then
		return false, "Invalid equipment."
	end

	local Layout = self:GetLayout(Player)
	local _, Items = GetItems(Data)
	local NewItem = NewName and Items[NewName]
	local OldName = Data.Equipped[Slot]
	if ExpectedName and OldName ~= ExpectedName then
		return false, "Equipment changed. Try again."
	end

	if NewName and (not NewItem or NewItem.Class ~= "Equipable" or NewItem.Type ~= Slot) then
		return false, "This item does not belong in that slot."
	end

	if NewName == OldName then
		return false, "This item is already equipped."
	end

	local Positions = Layout.Positions
	local Preferred = NewName and Positions[NewName]
	if NewName then
		Positions[NewName] = nil
	end

	if OldName then
		local OldItem = Items[OldName]
		local Placement = OldItem and InventoryGrid.FindPlacement(OldItem, Positions, Layout.Columns, Layout.Rows, Preferred)
		if not Placement then
			return false, "Not enough backpack space for the equipped item."
		end
		Positions[OldName] = Placement
	end

	Data.Backpack.Positions = Positions
	Data.Backpack.Revision += 1
	Data.Equipped[Slot] = NewName
	return true
end

function InventoryGridService:CanAdd(Player: Player, Raw: ItemData): boolean
	local Data = DataService:GetData(Player)
	local Layout = self:GetLayout(Player)
	local Item = ItemService:ImplementData(Raw)
	if not UsesGrid(Item, Data.Equipped) then
		return true
	end

	for _, Owned in Data.Inventory do
		if Owned.Name == Item.Name then
			return true
		end
	end

	return InventoryGrid.FindPlacement(Item, Layout.Positions, Layout.Columns, Layout.Rows) ~= nil
end

function InventoryGridService.KnitInit()
	DataService = Knit.GetService("DataService")
	ItemService = Knit.GetService("ItemService")
end

return InventoryGridService
