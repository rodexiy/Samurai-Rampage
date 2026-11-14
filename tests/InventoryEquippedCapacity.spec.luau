-- Run with production services and isolated player data/rendering dependencies.
return function(Grid: any, Inventory: any, Stances: any, Context: any, Player: any): string
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local function Reset(Names: { string }, Columns: number, Rows: number, Stance: string?)
		Context.Data = {
			Inventory = {}, Equipped = {}, Hotbar = {}, SelectedStance = Stance or "Beginner",
			Stances = {"Beginner", "TwoHeavens", "Undead"},
			Backpack = {Version = 1, Columns = Columns, Rows = Rows, Revision = 0, Positions = {}},
		}
		for _, Name in Names do
			table.insert(Context.Data.Inventory, {Name = Name, Stack = 1})
		end
	end

	Reset({"BasicKatana", "NightSkyKatana", "Bow", "Pickaxe", "OniMask"}, 8, 6, "TwoHeavens")
	Context.Data.Hotbar["1"] = "Pickaxe"
	Check(Inventory:EquipEquipmentSlot(Player, "Katana", "BasicKatana"), "Equip primary katana")
	Check(Inventory:EquipEquipmentSlot(Player, "SecondKatana", "NightSkyKatana"), "Equip secondary katana")
	Check(Inventory:EquipEquipmentSlot(Player, "Ranged", "Bow"), "Equip ranged weapon")
	Check(Inventory:EquipEquipmentSlot(Player, "Face", "OniMask"), "Equip armor")
	local Layout = Grid:GetLayout(Player)
	Check(not Layout.Positions.BasicKatana and not Layout.Positions.NightSkyKatana, "Both equipped swords must free their grid footprints")
	Check(not Layout.Positions.Bow and not Layout.Positions.OniMask, "Equipped ranged weapons and armor must free their footprints")
	Check(Layout.Positions.Pickaxe ~= nil, "Hotbar tools must retain their footprint")
	Check(#Layout.Overflow == 0, "Equipped items must not be treated as overflow")
	Check(not Grid:Move(Player, "BasicKatana", 1, 1, false, Layout.Revision), "Equipped weapons cannot be moved as backpack items")
	local Entries = Inventory:GetInventory(Player)
	for _, Item in Entries do
		Check(Item.UsesInventoryGrid == (Item.Name == "Pickaxe"), "Client visibility must match authoritative grid usage for " .. Item.Name)
	end
	Context.Data.Hotbar["2"] = "BasicKatana"
	Layout = Grid:GetLayout(Player)
	Check(Layout.Positions.BasicKatana ~= nil, "The hotbar exception must take precedence over equipment")
	Entries = Inventory:GetInventory(Player)
	Check(Entries[1].InHotbar and Entries[1].UsesInventoryGrid, "Client must preserve the hotbar exception")

	Reset({"BasicKatana"}, 6, 1, "TwoHeavens")
	Inventory:EquipEquipmentSlot(Player, "Katana", "BasicKatana")
	Check(Inventory:UnequipEquipmentSlot(Player, "Katana", "BasicKatana"), "Default second sword must not require a duplicate footprint when unequipping")
	Check(#Grid:GetLayout(Player).Overflow == 0 and #Context.Data.Inventory == 1, "Default second sword must not duplicate the owned item")

	Reset({"BasicKatana", "NightSkyKatana"}, 6, 1)
	Inventory:EquipEquipmentSlot(Player, "Katana", "BasicKatana")
	Layout = Grid:GetLayout(Player)
	local Revision = Layout.Revision
	Check(not Inventory:UnequipEquipmentSlot(Player, "Katana", "BasicKatana"), "A full backpack must reject unequipping")
	Check(Context.Data.Equipped.Weapon == "BasicKatana" and Grid:GetLayout(Player).Revision == Revision, "Rejected unequip must preserve equipment and revision")
	Check(Inventory:EquipEquipmentSlot(Player, "Katana", "NightSkyKatana"), "Full backpack must allow a swap into the incoming footprint")
	Layout = Grid:GetLayout(Player)
	Check(Layout.Positions.BasicKatana ~= nil and not Layout.Positions.NightSkyKatana, "Swap must return only the outgoing katana")
	Check(#Layout.Overflow == 0 and #Context.Data.Inventory == 2, "Swap must not overflow, duplicate or delete items")
	Check(not Inventory:UnequipEquipmentSlot(Player, "Weapon", "NightSkyKatana"), "Raw weapon keys must not bypass weapon slot validation")

	Reset({"BasicKatana", "NightSkyKatana", "Origin"}, 6, 1, "TwoHeavens")
	Inventory:EquipEquipmentSlot(Player, "Katana", "BasicKatana")
	Inventory:EquipEquipmentSlot(Player, "SecondKatana", "NightSkyKatana")
	Check(not Inventory:UnequipEquipmentSlot(Player, "Katana", "BasicKatana"), "Removing primary must reserve room for both returning swords")
	Check(Context.Data.Equipped.Weapon == "BasicKatana" and Context.Data.Equipped.LeftWeapon == "NightSkyKatana", "Failed two-item return must preserve both weapons")
	Check(not Stances:EquipStance(Player, "Beginner"), "Changing stance must reject a second sword that cannot return")
	Check(Context.Data.SelectedStance == "TwoHeavens" and Context.Data.Equipped.LeftWeapon == "NightSkyKatana", "Failed stance change must preserve stance and equipment")
	Check(Inventory:EquipEquipmentSlot(Player, "SecondKatana", "Origin"), "Full backpack must allow swapping the second sword")
	Check(Grid:GetLayout(Player).Positions.NightSkyKatana ~= nil, "Secondary swap must return the old sword")
	Context.Data.Backpack.Rows = 2
	Check(Stances:EquipStance(Player, "Beginner"), "Changing stance must succeed when the second sword fits")
	Check(Context.Data.Equipped.LeftWeapon == nil and Grid:GetLayout(Player).Positions.Origin ~= nil, "Leaving dual wield must return the explicit second sword")

	Reset({"BasicKatana", "NightSkyKatana", "Fists"}, 6, 1)
	Inventory:EquipEquipmentSlot(Player, "Katana", "BasicKatana")
	Check(not Stances:EquipStance(Player, "Undead"), "Switching weapon types must check capacity for the old primary")
	Check(Context.Data.SelectedStance == "Beginner" and Context.Data.Equipped.Weapon == "BasicKatana", "Rejected weapon type change must be atomic")
	Context.Data.Backpack.Rows = 2
	Check(Stances:EquipStance(Player, "Undead"), "Weapon type change must succeed with room")
	Layout = Grid:GetLayout(Player)
	Check(Context.Data.Equipped.Weapon == "Fists" and Layout.Positions.BasicKatana ~= nil, "Stance change must equip its matching weapon and return the katana")
	Check(not Layout.Positions.Fists and #Layout.Overflow == 0, "Hidden stance weapons must not consume backpack space")

	Reset({"Tanegashima", "BasicKatana", "NightSkyKatana"}, 6, 2)
	Inventory:EquipEquipmentSlot(Player, "Ranged", "Tanegashima")
	Check(not Inventory:UnequipEquipmentSlot(Player, "Ranged", "Tanegashima"), "Ranged unequip must reject a full backpack")
	Check(Context.Data.Equipped.Bow == "Tanegashima", "Rejected ranged unequip must preserve the ranged slot")
	Context.Data.Backpack.Rows = 4
	Check(Inventory:UnequipEquipmentSlot(Player, "Ranged", "Tanegashima"), "Ranged unequip must succeed when the footprint fits")
	Check(Grid:GetLayout(Player).Positions.Tanegashima ~= nil, "Unequipped ranged weapon must return to the grid")
	return tostring(Checks) .. " equipped inventory capacity checks passed"
end
