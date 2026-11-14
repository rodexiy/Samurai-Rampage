-- Run production inventory services with isolated player data and weapon rendering.
return function(Service: any, Slots: any, Context: any, Player: any): string
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local function Reset(Stance: string)
		Context.Data = {
			Inventory = {
				{Name = "BasicKatana", Stack = 1}, {Name = "NightSkyKatana", Stack = 1},
				{Name = "Bow", Stack = 1}, {Name = "Tanegashima", Stack = 1},
			},
			SelectedStance = Stance, Equipped = {}, Hotbar = {},
			Backpack = {Version = 1, Columns = 8, Rows = 12, Revision = 0, Positions = {}},
		}
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

	Reset("TwoHeavens")
	Check(not Service:EquipEquipmentSlot(Player, "SecondKatana", "NightSkyKatana"), "Second slot requires a primary katana")
	Check(Service:EquipEquipmentSlot(Player, "Katana", "BasicKatana"), "Dual stance must accept a primary katana")
	local Equipment = Service:GetWeaponEquipment(Player)
	Check(Equipment.DualWield and Equipment.SecondKatana == "BasicKatana", "Second slot must default to the first katana")
	Check(Context.Data.Equipped.LeftWeapon == nil, "Default second katana must use the existing fallback without duplicating inventory")
	local Entries, Snapshot = Service:GetInventory(Player)
	Check(Snapshot.WeaponEquipment.SecondKatana == "BasicKatana", "Client snapshot must include the fallback")
	Check(Entries[1].EquippedLeft and Entries[1].DefaultLeft, "Default katana must be marked as used by both hands")
	Check(Service:EquipEquipmentSlot(Player, "SecondKatana", "NightSkyKatana"), "Second slot must accept another owned katana")
	Check(Service:GetWeaponEquipment(Player).SecondKatana == "NightSkyKatana", "Second slot must display the custom katana")
	Check(Service:UnequipEquipmentSlot(Player, "SecondKatana", "NightSkyKatana"), "Second slot must allow removing its override")
	Check(Service:GetWeaponEquipment(Player).SecondKatana == "BasicKatana", "Removing the override must restore the first katana")
	Service:EquipEquipmentSlot(Player, "SecondKatana", "NightSkyKatana")
	Check(Service:EquipEquipmentSlot(Player, "SecondKatana", "BasicKatana"), "Dropping the primary into the second slot must reset the fallback")
	Check(Context.Data.Equipped.LeftWeapon == nil, "Resetting fallback must clear the explicit second weapon")
	Service:EquipEquipmentSlot(Player, "Katana", "NightSkyKatana")
	Check(Service:GetWeaponEquipment(Player).SecondKatana == "NightSkyKatana", "Default second katana must follow primary replacements")
	Service:UnequipEquipmentSlot(Player, "Katana", "NightSkyKatana")
	Check(Service:GetWeaponEquipment(Player).SecondKatana == nil, "Removing the primary must clear the second slot")

	Reset("Undead")
	Check(not Service:EquipEquipmentSlot(Player, "Katana", "BasicKatana"), "An incompatible stance must reject katanas")
	local Katana = {Name = "BasicKatana", Class = "Weapon", Type = "Katana"}
	Check(not Slots.Accepts(Katana, "Head", nil), "Armor slots must reject weapons")
	Check(not Slots.Accepts({Class = "Equipable", Type = "Katana"}, "Katana", nil), "Weapon slots must reject armor")
	return tostring(Checks) .. " weapon equipment slot checks passed"
end
