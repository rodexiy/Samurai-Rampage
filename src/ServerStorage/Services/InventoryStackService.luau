local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local InventoryStacks = require(ReplicatedStorage.Shared.Utils.InventoryStacks)
local InventoryGrid = require(ReplicatedStorage.Shared.Utils.InventoryGrid)
local InventoryEquipmentSlots = require(ReplicatedStorage.Shared.Utils.InventoryEquipmentSlots)
local DeepCopy = require(ReplicatedStorage.Shared.Utils.DeepCopy)

type ItemData = { [string]: any }
local InventoryStackService = Knit.CreateService({ Name = "InventoryStackService", Client = {} })
local ItemService
local DataService

local function NewId(Name: string, Used: { [string]: boolean }): string
	local Id = if not Used[Name] then Name else Name .. ":" .. HttpService:GenerateGUID(false)
	Used[Id] = true
	return Id
end

local function NormalizeAssignments(Data: ItemData, Kind: string)
	local Ids = Data[Kind .. "StackIds"] or {}
	Data[Kind .. "StackIds"] = Ids
	for Slot in Ids do
		if not (Data[Kind] or {})[Slot] then
			Ids[Slot] = nil
		end
	end
	for Slot, Name in Data[Kind] or {} do
		local Item = Ids[Slot] and InventoryStacks.Find(Data.Inventory, Ids[Slot])
		if not Item or Item.Name ~= Name then
			Ids[Slot] = nil
			for _, Owned in Data.Inventory do
				if Owned.Name == Name then
					Ids[Slot] = InventoryStacks.Key(Owned)
					break
				end
			end
		end
	end
end

function InventoryStackService:Normalize(Data: ItemData)
	local Used = {}
	for _, Item in Data.Inventory do
		if typeof(Item.Id) == "string" and Item.Id ~= "" and not Used[Item.Id] then
			Used[Item.Id] = true
		else
			Item.Id = NewId(Item.Name, Used)
		end
	end

	local Extra = {}
	for _, Item in Data.Inventory do
		local Definition = ItemService:GetItemData(Item.Name)
		local Limit = Definition and (Definition.MaxStack or 1)
		if Limit and Item.Stack > Limit then
			local Remaining = Item.Stack - Limit
			Item.Stack = Limit
			repeat
				local Split = DeepCopy(Item)
				Split.Id = NewId(Item.Name, Used)
				Split.Stack = math.min(Limit, Remaining)
				table.insert(Extra, Split)
				Remaining -= Split.Stack
			until Remaining == 0
		end
	end
	for _, Item in Extra do
		table.insert(Data.Inventory, Item)
	end
	NormalizeAssignments(Data, "Hotbar")
	NormalizeAssignments(Data, "Equipped")
end

function InventoryStackService:GetData(Player: Player): ItemData
	local Data = DataService:GetData(Player)
	if Data then
		self:Normalize(Data)
	end

	return Data
end

-- Plan against a snapshot so crafting and capacity checks never mutate the profile.
function InventoryStackService:PlanAdd(
	Data: ItemData,
	Raw: ItemData,
	Layout: ItemData
): (number, ItemData, { ItemData }, ItemData)
	local Definition = ItemService:GetItemData(Raw.Name)
	if not Definition or not InventoryGrid.IsInteger(Raw.Stack) or Raw.Stack <= 0 then
		return 0, {}, {}, Layout.Positions
	end
	local Remaining = Raw.Stack
	local Limit = Definition.MaxStack or 1
	local Unique = Definition.Hidden or Definition.Class == "Skill" or Definition.Class == "Stance"
	local Updates, NewItems, Used = {}, {}, {}
	local Positions = table.clone(Layout.Positions)
	for _, Owned in Data.Inventory do
		Used[InventoryStacks.Key(Owned)] = true
		if Owned.Name == Raw.Name and Unique then
			return 0, {}, {}, Positions
		end
		if InventoryStacks.Compatible(Owned, Raw) then
			local Added = math.min(Remaining, math.max(0, Limit - Owned.Stack))
			if Added > 0 then
				Updates[InventoryStacks.Key(Owned)] = Owned.Stack + Added
				Remaining -= Added
			end
		end
	end

	while Remaining > 0 do
		local Item = DeepCopy(Raw)
		Item.Id = NewId(Raw.Name, Used)
		Item.Stack = math.min(Limit, Remaining)
		local FullItem = ItemService:ImplementData(Item)
		if
			InventoryEquipmentSlots.UsesGrid(
				FullItem,
				InventoryStacks.Assignments(Data, "Equipped"),
				InventoryStacks.Assignments(Data, "Hotbar")
			)
		then
			local Placement = InventoryGrid.FindPlacement(FullItem, Positions, Layout.Columns, Layout.Rows)
			if not Placement then
				break
			end
			Positions[Item.Id] = Placement
		end
		table.insert(NewItems, Item)
		Remaining -= Item.Stack
		if Unique then
			break
		end
	end

	return Raw.Stack - Remaining, Updates, NewItems, Positions
end

function InventoryStackService.KnitInit()
	ItemService = Knit.GetService("ItemService")
	DataService = Knit.GetService("DataService")
end

return InventoryStackService
