local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryGrid = require(ReplicatedStorage.Shared.Utils.InventoryGrid)
local InventoryStacks = require(ReplicatedStorage.Shared.Utils.InventoryStacks)

local InventoryEquipmentSlots = {}

type ItemData = { [string]: any }
export type WeaponEquipment = {
	Ranged: string?,
	Katana: string?,
	SecondKatana: string?,
	DualWield: boolean,
}

InventoryEquipmentSlots.Weapons = {
	{ Name = "Ranged", Title = "RANGED", Type = "Bow", Order = 8 },
	{ Name = "Katana", Title = "KATANA", Type = "Katana", Order = 9 },
	{ Name = "SecondKatana", Title = "SECOND KATANA", Type = "Katana", Order = 10 },
}

function InventoryEquipmentSlots.IsWeaponSlot(Slot: string): boolean
	return Slot == "Ranged" or Slot == "Katana" or Slot == "SecondKatana"
end

function InventoryEquipmentSlots.UsesGrid(
	Item: ItemData,
	Equipped: { [string]: string },
	Hotbar: { [string]: string }
): boolean
	local Id = InventoryStacks.Key(Item)
	if Item.Hidden or Item.Class == "Skill" or Item.Class == "Stance" or (Item.Stack and Item.Stack <= 0) then
		return false
	end

	for _, Name in Hotbar do
		if Name == Id then
			return true
		end
	end

	if Item.Class == "Equipable" then
		return Equipped[Item.Type] ~= Id
	end
	if Item.Class == "Weapon" then
		return Equipped.Weapon ~= Id and Equipped.LeftWeapon ~= Id and Equipped.Bow ~= Id
	end

	return true
end

function InventoryEquipmentSlots.WithSlot(
	Equipped: { [string]: string },
	Slot: string,
	Name: string?
): { [string]: string }
	local Key = if Slot == "Ranged"
		then "Bow"
		elseif Slot == "Katana" then "Weapon"
		elseif Slot == "SecondKatana" then "LeftWeapon"
		else Slot
	local NextEquipped = table.clone(Equipped)
	NextEquipped[Key] = Name
	if
		(Key == "Weapon" and (Name == nil or NextEquipped.LeftWeapon == Name))
		or (Key == "LeftWeapon" and Name == NextEquipped.Weapon)
	then
		NextEquipped.LeftWeapon = nil
	end

	return NextEquipped
end

function InventoryEquipmentSlots.PlanLayout(
	Entries: { ItemData },
	Equipped: { [string]: string },
	NextEquipped: { [string]: string },
	Hotbar: { [string]: string },
	Layout: ItemData,
	PreferredName: string?
): ({ [string]: InventoryGrid.Placement }?, string?)
	local Positions = table.clone(Layout.Positions)
	local Preferred = PreferredName and Positions[PreferredName]
	for _, Item in Entries do
		if not InventoryEquipmentSlots.UsesGrid(Item, NextEquipped, Hotbar) then
			Positions[InventoryStacks.Key(Item)] = nil
		end
	end

	for _, Item in Entries do
		if Item.Stack and Item.Stack <= 0 then
			continue
		end
		if
			InventoryEquipmentSlots.UsesGrid(Item, NextEquipped, Hotbar)
			and not InventoryEquipmentSlots.UsesGrid(Item, Equipped, Hotbar)
		then
			local Placement = InventoryGrid.FindPlacement(Item, Positions, Layout.Columns, Layout.Rows, Preferred)
			if not Placement then
				return nil, "Not enough backpack space for the equipped item."
			end

			Positions[InventoryStacks.Key(Item)] = Placement
		end
	end

	return Positions
end

function InventoryEquipmentSlots.Resolve(
	Equipped: { [string]: string },
	Stance: ItemData?,
	MainWeapon: ItemData?
): WeaponEquipment
	local Katana = if MainWeapon and MainWeapon.Type == "Katana" then Equipped.Weapon else nil
	local DualWield = Stance ~= nil and Stance.WeaponType == "Katana" and Stance.DualWield == true

	return {
		Ranged = Equipped.Bow,
		Katana = Katana,
		SecondKatana = if DualWield and Katana then Equipped.LeftWeapon or Katana else nil,
		DualWield = DualWield,
	}
end

function InventoryEquipmentSlots.Accepts(Item: ItemData, Slot: string, Equipment: WeaponEquipment?): boolean
	if not InventoryEquipmentSlots.IsWeaponSlot(Slot) then
		return Item.Class == "Equipable" and Item.Type == Slot
	end

	if Item.Class ~= "Weapon" then
		return false
	end
	if Slot == "Ranged" then
		return Item.Type == "Bow"
	end

	return Item.Type == "Katana"
		and (Slot ~= "SecondKatana" or (Equipment ~= nil and Equipment.DualWield and Equipment.Katana ~= nil))
end

return InventoryEquipmentSlots
