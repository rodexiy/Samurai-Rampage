-- Run with production services and isolated profile/equipment dependencies.
return function(GridService: any, InventoryService: any, Context: any, Player: any): string
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Reset(Names: { string }, Equipped: { [string]: string }, Columns: number, Rows: number)
		Context.Data = {Inventory = {}, Equipped = Equipped, Hotbar = {}, Backpack = {Version = 1, Columns = Columns, Rows = Rows, Revision = 0, Positions = {}}}
		for _, Name in Names do
			table.insert(Context.Data.Inventory, {Name = Name, Stack = 1})
		end
		GridService:GetLayout(Player)
	end

	Reset({"OniMask", "HannyaMask", "IronOre", "WoodLog", "Coal", "Stone", "Rice", "PlantFiber"}, {Face = "HannyaMask"}, 4, 2)
	local Before = GridService:GetLayout(Player)
	local Success = InventoryService:EquipEquipmentSlot(Player, "Face", "OniMask")
	Check(not Success, "Full inventory must reject a smaller incoming item when the previous item cannot return")
	Check(Context.Data.Equipped.Face == "HannyaMask", "Rejected swap must preserve equipped item")
	Check(#Context.Data.Inventory == 8, "Rejected swap must preserve all owned items")
	local After = GridService:GetLayout(Player)
	Check(After.Revision == Before.Revision, "Rejected swap must not commit a revision")
	for Name, Position in Before.Positions do
		local Other = After.Positions[Name]
		Check(Other.Column == Position.Column and Other.Row == Position.Row and Other.Rotated == Position.Rotated, "Rejected swap must preserve every placement")
	end
	Check(not InventoryService:EquipUnequipItem(Player, "OniMask"), "Equip button must obey the same capacity rule as dragging")
	Check(not InventoryService:UnequipEquipmentSlot(Player, "Face", "HannyaMask"), "Unequipping must fail when there is no space")
	Check(Context.Data.Equipped.Face == "HannyaMask", "Failed unequip must not delete equipment")
	Check(not InventoryService:EquipEquipmentSlot(Player, "Head", "OniMask"), "Wrong equipment slot must reject item")
	Check(not InventoryService:EquipEquipmentSlot(Player, "Face", "UnknownMask"), "Unowned item must be rejected")

	Reset({"SamuraiHelmet", "StrawHat", "IronOre", "WoodLog", "Coal", "Stone"}, {Head = "StrawHat"}, 4, 2)
	local Origin = GridService:GetLayout(Player).Positions.SamuraiHelmet
	Check(InventoryService:EquipEquipmentSlot(Player, "Head", "SamuraiHelmet"), "Full inventory must allow equal-size swap using the vacated footprint")
	local Swapped = GridService:GetLayout(Player)
	Check(Context.Data.Equipped.Head == "SamuraiHelmet" and not Swapped.Positions.SamuraiHelmet, "Incoming equipment must leave backpack")
	Check(Swapped.Positions.StrawHat.Column == Origin.Column and Swapped.Positions.StrawHat.Row == Origin.Row, "Previous equipment must occupy the vacated footprint")
	Check(not InventoryService:UnequipEquipmentSlot(Player, "Head", "StrawHat"), "Stale unequip must not remove replacement")

	Reset({"BasicKatana", "OniMask", "IronOre"}, {}, 8, 6)
	local Layout = GridService:GetLayout(Player)
	Check(GridService:Move(Player, "BasicKatana", 6, 1, true, Layout.Revision), "Rotated katana must fit a 1 by 6 column")
	Layout = GridService:GetLayout(Player)
	Check(Layout.Positions.BasicKatana.Width == 1 and Layout.Positions.BasicKatana.Height == 6, "Server must compute rotated footprint")
	local Revision = Layout.Revision
	Check(not GridService:Move(Player, "OniMask", 6, 1, false, Revision), "Overlapping move must be rejected")
	Check(not GridService:Move(Player, "BasicKatana", 4, 1, false, Revision), "Out-of-bounds move must be rejected")
	Check(not GridService:Move(Player, "BasicKatana", 1.5, 1, false, Revision), "Fractional coordinates must be rejected")
	Check(not GridService:Move(Player, "BasicKatana", 0 / 0, 1, false, Revision), "NaN coordinates must be rejected")
	Check(not GridService:Move(Player, "BasicKatana", math.huge, 1, false, Revision), "Infinite coordinates must be rejected")
	Check(not GridService:Move(Player, "BasicKatana", 1, 1, false, Revision - 1), "Stale move must be rejected")
	Check(not GridService:Move(Player, "UnknownKatana", 1, 1, false, Revision), "Unowned move must be rejected")
	Check(GridService:GetLayout(Player).Revision == Revision, "Rejected moves must not mutate layout")
	Check(GridService:Move(Player, "BasicKatana", 1, 6, false, Revision), "Valid arbitrary position must be accepted")
	local Saved = GridService:GetLayout(Player)
	Check(Saved.Positions.BasicKatana.Row == 6 and Saved.Positions.BasicKatana.Column == 1, "Refreshing inventory must preserve manual position")

	Check(InventoryService:EquipEquipmentSlot(Player, "Face", "OniMask"), "Equip a valid owned item")
	Layout = GridService:GetLayout(Player)
	Check(not GridService:Move(Player, "OniMask", 1, 1, false, Layout.Revision), "Equipped items cannot be moved as backpack items")
	Check(InventoryService:UnequipEquipmentSlot(Player, "Face", "OniMask"), "Unequipping must restore an item when space exists")
	Check(GridService:GetLayout(Player).Positions.OniMask ~= nil, "Unequipped item must receive an authoritative position")

	Reset({"SamuraiHelmet", "StrawHat", "IronOre", "WoodLog", "Coal", "Stone"}, {Head = "StrawHat"}, 4, 2)
	Check(not GridService:CanAdd(Player, {Name = "HannyaMask", Stack = 1}), "New items must not expand a full backpack")
	Check(GridService:CanAdd(Player, {Name = "IronOre", Stack = 1}), "Existing material stack must not require another footprint")
	Check(InventoryService:GiveItemToPlayer(Player, {Name = "HannyaMask", Stack = 1}) == 0, "Full backpack must reject new item acquisition")
	Check(#Context.Data.Inventory == 6, "Failed acquisition must not insert an unpositioned item")

	Context.Data = {Inventory = {}, Equipped = {}, Hotbar = {}}
	for Index = 1, 9 do
		table.insert(Context.Data.Inventory, {Name = "LegacyKatana" .. tostring(Index), Class = "Weapon", Type = "Katana", Stack = 1})
	end
	local Migrated = GridService:GetLayout(Player)
	Check(Migrated.Rows >= 9 and #Context.Data.Inventory == 9, "Legacy migration must preserve oversized existing inventories")
	Check(Context.Data.Backpack.Version == 1, "Legacy migration must complete only once")

	return tostring(Checks) .. " inventory transaction checks passed"
end
