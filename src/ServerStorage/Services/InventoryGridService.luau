local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local InventoryConfig = require(ReplicatedStorage.Shared.InventoryConfig)
local InventoryGrid = require(ReplicatedStorage.Shared.Utils.InventoryGrid)
local DeepCopy = require(ReplicatedStorage.Shared.Utils.DeepCopy)
local InventoryEquipmentSlots = require(ReplicatedStorage.Shared.Utils.InventoryEquipmentSlots)
local InventoryStacks = require(ReplicatedStorage.Shared.Utils.InventoryStacks)

type ItemData = InventoryConfig.ItemData
type Positions = { [string]: InventoryGrid.Placement }

local InventoryGridService = Knit.CreateService({ Name = "InventoryGridService", Client = {} })
local DataService
local ItemService
local InventoryStackService

local function GetItems(Data: ItemData): ({ ItemData }, { [string]: ItemData })
	InventoryStackService:Normalize(Data)
	local Items, ByName = {}, {}
	for _, Raw in Data.Inventory do
		local Item = ItemService:ImplementData(Raw)
		ByName[InventoryStacks.Key(Item)] = Item
		if
			InventoryEquipmentSlots.UsesGrid(
				Item,
				InventoryStacks.Assignments(Data, "Equipped"),
				InventoryStacks.Assignments(Data, "Hotbar")
			)
		then
			table.insert(Items, Item)
		end
	end

	return Items, ByName
end

local function IsSavedPosition(Position: any): boolean
	return typeof(Position) == "table"
		and InventoryGrid.IsInteger(Position.Column)
		and InventoryGrid.IsInteger(Position.Row)
		and typeof(Position.Rotated) == "boolean"
end

function InventoryGridService:GetLayout(Player: Player): ItemData
	local Data = InventoryStackService:GetData(Player)
	local Items = GetItems(Data)
	local Backpack = Data.Backpack
	if not Backpack then
		Backpack = {
			Version = 0,
			Tier = InventoryConfig.DefaultBackpackTier,
			Columns = InventoryConfig.Columns,
			Rows = InventoryConfig.Rows,
			Revision = 0,
			Positions = {},
		}
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
			Backpack.Positions[InventoryStacks.Key(Item)] = Legacy.Placements[Index]
		end
		Backpack.Version = 1
	end

	local Positions: Positions = {}
	local Overflow = {}
	for _, Item in Items do
		local Saved = Backpack.Positions[InventoryStacks.Key(Item)]
		if IsSavedPosition(Saved) then
			local Candidate = InventoryGrid.Placement(Item, Saved.Column, Saved.Row, Saved.Rotated)
			if InventoryGrid.Fits(Positions, Candidate, Backpack.Columns, Backpack.Rows) then
				Positions[InventoryStacks.Key(Item)] = Candidate
			end
		end
	end

	for _, Item in Items do
		if not Positions[InventoryStacks.Key(Item)] then
			local Candidate = InventoryGrid.FindPlacement(Item, Positions, Backpack.Columns, Backpack.Rows)
			if Candidate then
				Positions[InventoryStacks.Key(Item)] = Candidate
			else
				table.insert(Overflow, InventoryStacks.Key(Item))
			end
		end
	end

	for Name, Position in Positions do
		local Previous = Backpack.Positions[Name]
		if
			not Previous
			or Previous.Column ~= Position.Column
			or Previous.Row ~= Position.Row
			or Previous.Rotated ~= Position.Rotated
		then
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
	return {
		Tier = Backpack.Tier,
		Columns = Backpack.Columns,
		Rows = Backpack.Rows,
		Revision = Backpack.Revision,
		Positions = DeepCopy(Positions),
		Overflow = Overflow,
	}
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

function InventoryGridService:Move(
	Player: Player,
	Name: any,
	Column: any,
	Row: any,
	Rotated: any,
	Revision: any
): (boolean, string?)
	if
		typeof(Name) ~= "string"
		or not InventoryGrid.IsInteger(Column)
		or not InventoryGrid.IsInteger(Row)
		or typeof(Rotated) ~= "boolean"
	then
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
	if
		not Item
		or not InventoryEquipmentSlots.UsesGrid(
			Item,
			InventoryStacks.Assignments(Data, "Equipped"),
			InventoryStacks.Assignments(Data, "Hotbar")
		)
	then
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

function InventoryGridService:SetEquippedItems(
	Player: Player,
	NextEquipped: { [string]: string },
	PreferredName: string?
): (boolean, string?)
	local Data = DataService:GetData(Player)
	InventoryStackService:Normalize(Data)
	local CurrentEquipped = InventoryStacks.Assignments(Data, "Equipped")
	local Changed = false
	for Slot, Name in NextEquipped do
		Changed = Changed or CurrentEquipped[Slot] ~= Name
	end
	for Slot, Name in CurrentEquipped do
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

	local Positions, Reason = InventoryEquipmentSlots.PlanLayout(
		Entries,
		CurrentEquipped,
		NextEquipped,
		InventoryStacks.Assignments(Data, "Hotbar"),
		Layout,
		PreferredName
	)
	if not Positions then
		return false, Reason
	end

	Data.Backpack.Positions = Positions
	Data.Backpack.Revision += 1
	table.clear(Data.Equipped)
	table.clear(Data.EquippedStackIds)
	for Slot, Name in NextEquipped do
		local Item = InventoryStacks.Find(Data.Inventory, Name)
		if Item then
			Data.Equipped[Slot] = Item.Name
			Data.EquippedStackIds[Slot] = Name
		end
	end

	return true
end

function InventoryGridService:SetEquipment(
	Player: Player,
	Slot: any,
	NewName: any,
	ExpectedName: string?
): (boolean, string?)
	local Data = DataService:GetData(Player)
	if not Data or typeof(Slot) ~= "string" or (NewName ~= nil and typeof(NewName) ~= "string") then
		return false, "Invalid equipment."
	end

	local _, Items = GetItems(Data)
	local NewItem = NewName and Items[NewName]
	local Equipped = InventoryStacks.Assignments(Data, "Equipped")
	local OldName = Equipped[Slot]
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

	return self:SetEquippedItems(Player, InventoryEquipmentSlots.WithSlot(Equipped, Slot, NewName), NewName)
end

function InventoryGridService:CanAdd(Player: Player, Raw: ItemData): boolean
	local Data = DataService:GetData(Player)
	local Layout = self:GetLayout(Player)
	local Added = InventoryStackService:PlanAdd(Data, Raw, Layout)
	return Added == Raw.Stack
end

function InventoryGridService:CanCraft(
	Player: Player,
	Requirements: { [string]: number },
	Amount: number,
	Item: ItemData
): boolean
	local Layout = self:GetLayout(Player)
	local Data = DeepCopy(DataService:GetData(Player))
	local Positions = table.clone(Layout.Positions)
	local Remaining = {}
	for Name, Count in Requirements do
		Remaining[Name] = Count * Amount
	end
	for Index = #Data.Inventory, 1, -1 do
		local Owned = Data.Inventory[Index]
		local Consumed = math.min(Owned.Stack, Remaining[Owned.Name] or 0)
		Remaining[Owned.Name] = (Remaining[Owned.Name] or 0) - Consumed
		Owned.Stack -= Consumed
		if Owned.Stack == 0 then
			Positions[InventoryStacks.Key(Owned)] = nil
			table.remove(Data.Inventory, Index)
		end
	end
	local Output = { Name = Item.Name, Stack = Amount * (Item.AmountPerCraft or 1) }
	local Simulated = table.clone(Layout)
	Simulated.Positions = Positions
	local Added = InventoryStackService:PlanAdd(Data, Output, Simulated)
	return Added == Output.Stack
end

function InventoryGridService.KnitInit()
	DataService = Knit.GetService("DataService")
	ItemService = Knit.GetService("ItemService")
	InventoryStackService = Knit.GetService("InventoryStackService")
end

return InventoryGridService
