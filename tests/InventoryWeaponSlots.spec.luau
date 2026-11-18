-- Run production inventory services with isolated player data and weapon rendering.
return function(Service: any, Slots: any, Context: any, Player: any, Stance: any): string
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local function Reset(StanceName: string)
		Context.Data = {
			Inventory = {
				{Name = "BasicKatana", Stack = 1}, {Name = "NightSkyKatana", Stack = 1},
				{Name = "Bow", Stack = 1}, {Name = "Tanegashima", Stack = 1},
			},
			SelectedStance = StanceName, Equipped = {}, Hotbar = {},
			Stances = { "Beginner", "TwoHeavens", "Undead" },
			Backpack = {Version = 1, Columns = 8, Rows = 12, Revision = 0, Positions = {}},
		}
		Context.StanceUpdates = {}
		Player.Character:SetAttribute("Stance", StanceName)
	end

	Reset("Beginner")
	Check(Service:EquipEquipmentSlot(Player, "Katana", "BasicKatana"), "Primary slot must equip an owned katana")
	Check(Service:EquipEquipmentSlot(Player, "Katana", "BasicKatana"), "Dropping the same katana must not toggle it off")
	Check(Context.Data.Equipped.Weapon == "BasicKatana", "Primary katana must remain equipped")
	Check(not Service:GetWeaponEquipment(Player).DualWield, "Single sword stance must hide the second slot")
	Check(not Service:EquipEquipmentSlot(Player, "SecondKatana", "NightSkyKatana"), "Single sword stance must reject a second katana")
	Check(not Service:EquipEquipmentSlot(Player, "Ranged", "BasicKatana"), "Ranged slot must reject katanas")
	Check(not Service:EquipEquipmentSlot(Player, "Katana", "Bow"), "Katana slot must reject ranged weapons")
	Check(not Service:EquipEquipmentSlot(Player, "Katana", "Origin"), "Unowned weapons must be rejected")
	Check(Service:EquipEquipmentSlot(Player, "Ranged", "Bow"), "Ranged slot must accept a bow")
	Check(Service:EquipEquipmentSlot(Player, "Ranged", "Tanegashima"), "Ranged slot must accept a firearm")
	Check(Service:GetWeaponEquipment(Player).Ranged == "Tanegashima", "Ranged replacement must update the slot")
	Check(not Service:UnequipEquipmentSlot(Player, "Ranged", "Bow"), "A stale click must not unequip a replacement")
	Check(Service:UnequipEquipmentSlot(Player, "Ranged", "Tanegashima"), "Ranged slot must unequip its current weapon")
	Check(Context.Data.Equipped.Weapon == "BasicKatana", "Ranged changes must preserve the katana")

	Reset("Beginner")
	Check(not Service:EquipEquipmentSlot(Player, "SecondKatana", "NightSkyKatana"), "Second slot requires a primary katana")
	Check(Stance:EquipStance(Player, "TwoHeavens"), "Dual stance must automatically equip two owned katanas")
	local Equipment = Service:GetWeaponEquipment(Player)
	Check(Equipment.Katana == "BasicKatana" and Equipment.SecondKatana == "NightSkyKatana", "Each slot must contain a different owned katana")
	Check(Context.Data.Equipped.LeftWeapon == "NightSkyKatana", "The second katana must be assigned explicitly")
	local Entries, Snapshot = Service:GetInventory(Player)
	Check(Snapshot.WeaponEquipment.SecondKatana == "NightSkyKatana", "Client snapshots must include the actual second katana")
	Check(Entries[1].Equipped and not Entries[1].EquippedLeft and not Entries[1].DefaultLeft, "The primary copy must only occupy the right hand")
	Check(Entries[2].EquippedLeft and Entries[2].UsesInventoryGrid == false, "The actual second copy must leave the backpack grid")
	Check(not Service:EquipEquipmentSlot(Player, "SecondKatana", "BasicKatana"), "The same physical katana cannot occupy both hands")
	Check(not Service:EquipUnequipItem(Player, "NightSkyKatana"), "The direct weapon API must also reject using the left katana in both hands")
	Check(Context.Data.SelectedStance == "TwoHeavens", "Rejected replacements must preserve the stance")
	Check(Service:UnequipEquipmentSlot(Player, "SecondKatana", "NightSkyKatana"), "The second katana must be removable")
	Check(Context.Data.SelectedStance == "Beginner", "Removing the second katana must exit dual wield")
	Check(Context.Data.Equipped.Weapon == "BasicKatana" and Context.Data.Equipped.LeftWeapon == nil, "Removing the second katana must preserve only the first")
	Check(Service:GetWeaponEquipment(Player).SecondKatana == nil, "No synthetic second katana should remain")
	Check(Stance:EquipStance(Player, "TwoHeavens"), "Reactivating the stance should equip both physical katanas again")
	Check(Service:UnequipEquipmentSlot(Player, "Katana", "BasicKatana"), "The primary katana must be removable")
	Check(Context.Data.SelectedStance == "Beginner", "Removing the primary katana must exit dual wield")
	Check(Context.Data.Equipped.Weapon == "NightSkyKatana" and Context.Data.Equipped.LeftWeapon == nil, "The remaining second katana should move into the single sword slot")
	Check(Slots.Resolve({Weapon = "BasicKatana"}, {WeaponType = "Katana", DualWield = true}, {Type = "Katana"}).SecondKatana == nil, "Missing second assignments must never resolve to a copy of the first")

	Reset("Undead")
	Check(not Service:EquipEquipmentSlot(Player, "Katana", "BasicKatana"), "An incompatible stance must reject katanas")
	local Katana = {Name = "BasicKatana", Class = "Weapon", Type = "Katana"}
	Check(not Slots.Accepts(Katana, "Head", nil), "Armor slots must reject weapons")
	Check(not Slots.Accepts({Class = "Equipable", Type = "Katana"}, "Katana", nil), "Weapon slots must reject armor")
	return tostring(Checks) .. " weapon equipment slot checks passed"
end
