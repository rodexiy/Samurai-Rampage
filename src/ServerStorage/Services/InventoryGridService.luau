local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local InventoryConfig = require(ReplicatedStorage.Shared.InventoryConfig)
local InventoryGrid = require(ReplicatedStorage.Shared.Utils.InventoryGrid)
local DeepCopy = require(ReplicatedStorage.Shared.Utils.DeepCopy)
local InventoryEquipmentSlots = require(ReplicatedStorage.Shared.Utils.InventoryEquipmentSlots)

type ItemData = InventoryConfig.ItemData
type Positions = { [string]: InventoryGrid.Placement }

local InventoryGridService = Knit.CreateService({Name = "InventoryGridService", Client = {}})
local DataService
local ItemService

local function GetItems(Data: ItemData): ({ ItemData }, { [string]: ItemData })
	local Items, ByName = {}, {}
	for _, Raw in Data.Inventory do
		local Item = ItemService:ImplementData(Raw)
		ByName[Item.Name] = Item
		if InventoryEquipmentSlots.UsesGrid(Item, Data.Equipped, Data.Hotbar or {}) then
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
		Backpack = {Version = 0, Tier = InventoryConfig.DefaultBackpackTier, Columns = InventoryConfig.Columns, Rows = InventoryConfig.Rows, Revision = 0, Positions = {}}
		Data.Backpack = Backpack
	end

	local Changed = Backpack.Columns == 8
	if Changed then
		Backpack.Columns = InventoryConfig.Columns
	end

	Backpack.Tier = Backpack.Tier or InventoryConfig.DefaultBackpackTier
	if Backpack.Tier == InventoryConfig.DefaultBackpackTier and Backpack.Rows == 6 then
		Backpack.Rows = InventoryConfig.Rows
		Changed = true
	end

	if Backpack.Version == 0 then
		-- Preserve existing inventories during the one-time migration, without deleting excess items.
		local Legacy = InventoryGrid.Arrange(Items, Backpack.Columns, Backpack.Rows)
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
	return {Tier = Backpack.Tier, Columns = Backpack.Columns, Rows = Backpack.Rows, Revision = Backpack.Revision, Positions = DeepCopy(Positions), Overflow = Overflow}
end

function InventoryGridService:SetBackpackTier(Player: Player, Tier: any): (boolean, string?)
	if not InventoryGrid.IsInteger(Tier) or not InventoryConfig.Backpacks[Tier] then
		return false, "Invalid backpack tier. Choose 1, 2, 3 or 4 (admin)."
	end

	local Data = DataService:GetData(Player)
	if not Data then
		return false, "Player data is not ready."
	end

	self:GetLayout(Player)
	local Backpack = Data.Backpack
	local Definition = InventoryConfig.Backpacks[Tier]
	if Backpack.Tier == Tier and Backpack.Columns == InventoryConfig.Columns and Backpack.Rows == Definition.Rows then
		return true
	end

	Backpack.Tier = Tier
	Backpack.Columns = InventoryConfig.Columns
	Backpack.Rows = Definition.Rows
	Backpack.Revision += 1
	self:GetLayout(Player)

	return true
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
	if not Item or not InventoryEquipmentSlots.UsesGrid(Item, Data.Equipped, Data.Hotbar or {}) then
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

function InventoryGridService:SetEquippedItems(Player: Player, NextEquipped: { [string]: string }, PreferredName: string?): (boolean, string?)
	local Data = DataService:GetData(Player)
	local Changed = false
	for Slot, Name in NextEquipped do
		Changed = Changed or Data.Equipped[Slot] ~= Name
	end
	for Slot, Name in Data.Equipped do
		Changed = Changed or NextEquipped[Slot] ~= Name
	end
	if not Changed then
		return true
	end

	local Layout = self:GetLayout(Player)
	local Entries = {}
	for _, Raw in Data.Inventory do
		table.insert(Entries, ItemService:ImplementData(Raw))
	end

	local Positions, Reason = InventoryEquipmentSlots.PlanLayout(Entries, Data.Equipped, NextEquipped, Data.Hotbar or {}, Layout, PreferredName)
	if not Positions then
		return false, Reason
	end

	Data.Backpack.Positions = Positions
	Data.Backpack.Revision += 1
	table.clear(Data.Equipped)
	for Slot, Name in NextEquipped do
		Data.Equipped[Slot] = Name
	end

	return true
end

function InventoryGridService:SetEquipment(Player: Player, Slot: any, NewName: any, ExpectedName: string?): (boolean, string?)
	local Data = DataService:GetData(Player)
	if not Data or typeof(Slot) ~= "string" or (NewName ~= nil and typeof(NewName) ~= "string") then
		return false, "Invalid equipment."
	end

	local _, Items = GetItems(Data)
	local NewItem = NewName and Items[NewName]
	local OldName = Data.Equipped[Slot]
	if ExpectedName and OldName ~= ExpectedName then
		return false, "Equipment changed. Try again."
	end

	if NewName and (not NewItem or NewItem.Stack <= 0 or NewItem.Class ~= "Equipable" or NewItem.Type ~= Slot) then
		return false, "This item does not belong in that slot."
	end
	local OldItem = OldName and Items[OldName]
	if not NewName and OldName and (not OldItem or OldItem.Class ~= "Equipable" or OldItem.Type ~= Slot) then
		return false, "This item does not belong in that slot."
	end

	if NewName == OldName then
		return false, "This item is already equipped."
	end

	return self:SetEquippedItems(Player, InventoryEquipmentSlots.WithSlot(Data.Equipped, Slot, NewName), NewName)
end

function InventoryGridService:CanAdd(Player: Player, Raw: ItemData): boolean
	local Data = DataService:GetData(Player)
	local Layout = self:GetLayout(Player)
	local Item = ItemService:ImplementData(Raw)
	if not InventoryEquipmentSlots.UsesGrid(Item, Data.Equipped, Data.Hotbar or {}) then
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
