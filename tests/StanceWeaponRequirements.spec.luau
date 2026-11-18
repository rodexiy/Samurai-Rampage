-- Run production stance/inventory services with isolated profiles and weapon rendering.
return function(Stance: any, Inventory: any, Context: any, Player: any): string
	local Checks = 0
	local function Check(Value: boolean, Message: string)
		assert(Value, Message)
		Checks += 1
	end

	local function Reset(Items: { any }, Selected: string?)
		Context.Data = {
			Inventory = Items,
			Stances = { "Beginner", "TwoHeavens", "Undead" },
			SelectedStance = Selected or "Beginner",
			Equipped = {},
			Hotbar = {},
			Backpack = { Version = 1, Columns = 6, Rows = 8, Revision = 0, Positions = {} },
		}
		Player.Character:SetAttribute("Stance", Selected or "Beginner")
		Player.Character:SetAttribute("WeaponEquipped", false)
		Context.Alerts = {}
		Context.StanceUpdates = {}
	end

	Reset({})
	Check(not Stance:HasRequiredWeapons(Player, "TwoHeavens"), "Empty inventories must reject dual wield")
	Check(not Stance:EquipStance(Player, "TwoHeavens"), "The server must reject equipping dual wield without katanas")
	Check(Context.Data.SelectedStance == "Beginner", "Rejected requests must preserve the selected stance")
	Check(#Context.Alerts == 1, "Missing weapons should produce a player warning")
	Check(#Context.StanceUpdates == 0, "Rejected requests must not publish a successful stance change")
	Check(Stance:HasRequiredWeapons(Player, "Beginner"), "Single sword stances must not require two katanas")

	Reset({ { Name = "BasicKatana", Stack = 1 }, { Name = "Fists", Stack = 1 }, { Name = "Bow", Stack = 3 } })
	Context.Data.Equipped.Weapon = "BasicKatana"
	Context.Data.Equipped.LeftWeapon = "BasicKatana"
	Check(not Stance:EquipStance(Player, "TwoHeavens"), "Equipment assignments and other weapon types must not count as additional katanas")

	Reset({ { Name = "BasicKatana", Stack = 1 }, { Name = "NightSkyKatana", Stack = 0 } })
	Check(not Stance:EquipStance(Player, "TwoHeavens"), "Empty katana stacks must not satisfy the requirement")

	Reset({ { Name = "BasicKatana", Stack = 1 }, { Name = "NightSkyKatana", Stack = 1 } })
	Check(Stance:EquipStance(Player, "TwoHeavens"), "Two different owned katanas should enable dual wield")
	Check(Context.Data.SelectedStance == "TwoHeavens", "Successful requests must select the dual wield stance")
	Check(Player.Character:GetAttribute("Stance") == "TwoHeavens", "The character must receive the selected stance")
	Check(Inventory:GetWeaponEquipment(Player).DualWield, "The inventory should enable dual wield equipment slots")
	local Pair = Inventory:GetInventoryLayout(Player).Equipped
	Check(Pair.Weapon ~= nil and Pair.LeftWeapon ~= nil and Pair.Weapon ~= Pair.LeftWeapon, "Activation must assign two distinct inventory copies")
	Check(#Context.StanceUpdates == 1, "Successful stance changes must publish exactly one UI update")
	local function Equipped(Entries: { any }, Name: string): boolean
		for _, Entry in Entries do
			if Entry.Name == Name then
				return Entry.Equipped == true
			end
		end

		return false
	end
	Check(Equipped(Context.StanceUpdates[1], "TwoHeavens"), "The UI snapshot must mark the newly selected stance as equipped")
	Check(not Equipped(Context.StanceUpdates[1], "Beginner"), "The UI snapshot must clear the previous stance's equipped flag")
	Check(Stance:EquipStance(Player, "TwoHeavens"), "Repeated valid requests should still succeed")
	Check(#Context.StanceUpdates == 2, "Repeated valid requests must refresh stale client stance data")
	Check(Stance:EquipStance(Player, "Beginner"), "Prepare switching back to a single sword stance")
	Check(Equipped(Context.StanceUpdates[3], "Beginner") and not Equipped(Context.StanceUpdates[3], "TwoHeavens"), "Switching back must update both stance flags")

	Reset({ { Name = "BasicKatana", Stack = 1 }, { Name = "BasicKatana", Stack = 1 } })
	Check(Stance:EquipStance(Player, "TwoHeavens"), "Two physical copies of the same katana must count separately")
	Check(Stance:HasRequiredWeapons(Player, "TwoHeavens"), "Equipped katanas must still count as owned inventory items")
	Pair = Inventory:GetInventoryLayout(Player).Equipped
	Check(Pair.Weapon ~= Pair.LeftWeapon and Context.Data.Equipped.LeftWeapon == "BasicKatana", "Identical katana models must use separate stack IDs for each hand")

	Reset({ { Name = "BasicKatana", Stack = 2 } })
	Check(Stance:EquipStance(Player, "TwoHeavens"), "Legacy stacks containing two katanas must count by quantity")
	local Updates = #Context.StanceUpdates
	Inventory:RemoveItemFromPlayer(Player, "BasicKatana", 1)
	Check(Context.Data.SelectedStance == "Beginner", "Losing the second katana must restore a single sword stance")
	Check(Player.Character:GetAttribute("Stance") == "Beginner", "The active character must stop using dual wield")
	Check(not Inventory:GetWeaponEquipment(Player).DualWield, "The second weapon slot must disappear after losing the requirement")
	Check(Player.Character:GetAttribute("LeftWeaponType") == nil, "The left-hand weapon must be unloaded")
	Check(#Context.StanceUpdates == Updates + 1 and Equipped(Context.StanceUpdates[#Context.StanceUpdates], "Beginner"), "Automatic fallback must publish exactly one authoritative stance update")
	Check(not Stance:EquipStance(Player, "TwoHeavens"), "The player must not re-equip dual wield after losing a katana")

	Reset({ { Name = "BasicKatana", Stack = 1 }, { Name = "NightSkyKatana", Stack = 1 } })
	Context.Data.Stances = { "Beginner" }
	Check(not Stance:EquipStance(Player, "TwoHeavens"), "Having two katanas must not unlock an unowned stance")

	Reset({ { Name = "BasicKatana", Stack = 1 } }, "TwoHeavens")
	Context.Data.Stances = { "TwoHeavens" }
	Inventory:RemoveUnavailableItems(Player)
	Check(Context.Data.SelectedStance == "Beginner", "Loading an invalid saved dual wield stance must restore the default stance")
	Check(not table.find(Context.Data.Stances, "Beginner"), "Fallback must not grant additional stance unlocks")

	Reset({ { Name = "BasicKatana", Stack = 1 }, { Name = "NightSkyKatana", Stack = 1 } })
	Check(Stance:EquipStance(Player, "TwoHeavens"), "Prepare two equipped katanas")
	Check(Inventory:EquipEquipmentSlot(Player, "SecondKatana", "NightSkyKatana"), "Prepare a custom left-hand weapon")
	Context.Data.Backpack.Rows = 1
	for Index = 1, 6 do
		table.insert(Context.Data.Inventory, { Name = "Apple", Stack = 1, Id = "Apple:" .. Index })
	end
	Check(#Inventory:GetInventoryLayout(Player).Overflow == 0, "Prepare a completely full backpack")
	Inventory:RemoveItemFromPlayer(Player, "BasicKatana", "all")
	Check(Context.Data.SelectedStance == "Beginner", "Removing the primary katana must invalidate dual wield")
	Check(Context.Data.Equipped.Weapon == "NightSkyKatana", "Fallback should retain the surviving owned katana")
	Check(Context.Data.Equipped.LeftWeapon == nil, "Fallback must clear the left-hand assignment")
	Check(#Inventory:GetInventoryLayout(Player).Overflow == 0, "Fallback must not overflow a full backpack")

	Reset({ { Name = "BasicKatana", Stack = 1 }, { Name = "NightSkyKatana", Stack = 1 }, { Name = "Apple", Stack = 1 } })
	Check(Stance:EquipStance(Player, "TwoHeavens"), "Prepare an eligible dual wield stance")
	Inventory:RemoveItemFromPlayer(Player, "Apple", 1)
	Check(Context.Data.SelectedStance == "TwoHeavens", "Removing unrelated items must preserve an eligible stance")

	Reset({ { Name = "BasicKatana", Stack = 1 }, { Name = "NightSkyKatana", Stack = 1 }, { Name = "Origin", Stack = 1 } })
	Check(Stance:EquipStance(Player, "TwoHeavens"), "Prepare dual wield with a spare katana")
	Context.Data.Backpack.Rows = 1
	Check(#Inventory:GetInventoryLayout(Player).Overflow == 0, "The spare katana should fill the available backpack row")
	Check(Inventory:EquipEquipmentSlot(Player, "SecondKatana", "Origin"), "Direct left-hand replacement should succeed without extra backpack capacity")
	Check(Context.Data.SelectedStance == "TwoHeavens" and Context.Data.Equipped.LeftWeapon == "Origin", "Replacing the second sword directly must preserve dual wield")
	Check(Inventory:EquipEquipmentSlot(Player, "Katana", "NightSkyKatana"), "Direct primary replacement should succeed")
	Check(Context.Data.SelectedStance == "TwoHeavens" and Context.Data.Equipped.LeftWeapon == "Origin", "Replacing the first sword directly must preserve the other hand and stance")
	Check(#Inventory:GetInventoryLayout(Player).Overflow == 0, "Direct swaps must preserve inventory capacity")
	Check(not Inventory:UnequipEquipmentSlot(Player, "SecondKatana", "Origin"), "A full backpack must reject a removal that cannot store the sword")
	Check(Context.Data.SelectedStance == "TwoHeavens" and Context.Data.Equipped.LeftWeapon == "Origin", "Failed removals must preserve both equipment and stance atomically")
	Context.Data.Backpack.Rows = 8
	Check(Inventory:UnequipEquipmentSlot(Player, "SecondKatana", "Origin"), "Prepare removing one sword while still owning three")
	Check(Context.Data.SelectedStance == "Beginner", "Owning spare swords must not preserve dual wield after unequipping a hand")

	Reset({ { Name = "BasicKatana", Stack = 1 }, { Name = "NightSkyKatana", Stack = 1 }, { Name = "Origin", Stack = 1 } })
	Check(Stance:EquipStance(Player, "TwoHeavens"), "Prepare losing an equipped sword while owning a spare")
	Inventory:RemoveItemFromPlayer(Player, "NightSkyKatana", "all")
	Check(Stance:HasRequiredWeapons(Player, "TwoHeavens") and Context.Data.SelectedStance == "Beginner", "Losing an assigned sword must exit the stance even when two other katanas remain")

	Reset({
		{ Name = "BasicKatana", Stack = 1, Id = "BasicKatana:spare" },
		{ Name = "BasicKatana", Stack = 1, Id = "BasicKatana:main" },
		{ Name = "BasicKatana", Stack = 1, Id = "BasicKatana:left" },
	})
	Context.Data.Equipped = { Weapon = "BasicKatana", LeftWeapon = "BasicKatana" }
	Context.Data.EquippedStackIds = { Weapon = "BasicKatana:main", LeftWeapon = "BasicKatana:left" }
	Check(Stance:EquipStance(Player, "TwoHeavens"), "Prepare a pair and a spare of the same katana model")
	Pair = Inventory:GetInventoryLayout(Player).Equipped
	Check(Pair.Weapon == "BasicKatana:main" and Pair.LeftWeapon == "BasicKatana:left", "Activation should preserve an existing valid physical pair")
	Inventory:RemoveItemFromPlayer(Player, "BasicKatana", 1, false, "BasicKatana:main")
	Check(Context.Data.SelectedStance == "Beginner", "Removing a sword must not silently replace it with a same-name spare")
	Check(Inventory:GetInventoryLayout(Player).Equipped.Weapon == "BasicKatana:left", "Fallback should retain the actual surviving equipped copy")

	return tostring(Checks) .. " stance weapon requirement checks passed"
end
