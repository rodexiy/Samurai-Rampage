-- Run with production hotbar rules/services and an isolated inventory profile.
return function(Slots: any, Service: any, Context: any, Player: any): string
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	for Index = 0, 9 do
		Check(Slots.IsValidIndex(Index), "Every displayed hotbar slot must be accepted")
	end
	for _, Index in {-1, 10, 0.5, math.huge, 0 / 0, "1"} do
		Check(not Slots.IsValidIndex(Index), "Invalid hotbar indexes must be rejected")
	end
	Check(not Slots.Accepts(nil), "Missing items must be rejected")
	Check(not Slots.Accepts({Name = "MissingTool", Class = "Resource"}), "Items without a tool must be rejected")
	Check(Slots.Accepts({Name = "Apple", Class = "Consumable"}), "Existing item tools must be accepted")
	Check(Slots.Accepts({Name = "Grapple", Class = "Skill"}), "Skills must not require a tool template")
	for _, Class in {"Weapon", "Equipable", "Stance"} do
		Check(not Slots.Accepts({Name = "Apple", Class = Class}), "Equipment classes must remain blocked even with a tool template")
	end
	Check(not Slots.Accepts({Name = "Apple", Class = "Resource", Type = "Ammunition"}), "Ammunition must be blocked")

	Context.Data = {
		Inventory = {{Name = "Apple", Stack = 3}, {Name = "WoodLog", Stack = 2}, {Name = "BasicKatana", Stack = 1}, {Name = "Arrow", Stack = 10}},
		Equipped = {}, Hotbar = {},
	}
	Check(Service:EquipToHotbar(Player, "Apple", 0), "Drop into slot zero must succeed")
	Check(Context.Data.Hotbar["0"] == "Apple", "Drop must persist its exact destination")
	Check(Context.Data.Inventory[1].Stack == 3, "Hotbar assignment must preserve item stacks")
	Check(Service:GetToolInHotbarIndex(Player, 0).Name == "Apple", "Hotbar assignment must create the usable tool")
	Check(Service:EquipToHotbar(Player, "Apple", 9), "An assigned item can move to another slot")
	Check(Context.Data.Hotbar["0"] == nil and Context.Data.Hotbar["9"] == "Apple", "Moving must not duplicate hotbar assignments")
	Check(Service:EquipToHotbar(Player, "WoodLog", 9), "Dropping onto a normal occupied slot must replace it")
	Check(Context.Data.Hotbar["9"] == "WoodLog", "Replacement must update the destination")
	Check(Service:GetToolInHotbarIndex(Player, 9).Name == "WoodLog", "Replacement must update its tool")
	Check(not Service:EquipToHotbar(Player, "BasicKatana", 9), "Server must reject weapons")
	Check(not Service:EquipToHotbar(Player, "Arrow", 9), "Server must reject ammunition")
	Check(not Service:EquipToHotbar(Player, "Bandage", 9), "Server must reject unowned items")
	Check(not Service:EquipToHotbar(Player, "Apple", 0.5), "Server must reject invalid slots")
	Check(Context.Data.Hotbar["9"] == "WoodLog", "Rejected drops must preserve the existing assignment")

	Service:HandleInventoryAction(Player, {Id = 1, Kind = "Hotbar", Name = "Apple", Index = 0, Revision = 7})
	Check(Context.Data.Hotbar["0"] == "Apple", "Drag request must route through the authoritative hotbar service")
	Service:HandleInventoryAction(Player, {Id = 2, Kind = "Hotbar", Name = "Apple", Index = 8, Revision = 6})
	Check(Context.Data.Hotbar["8"] == nil, "Stale drag requests must not mutate the hotbar")

	Service:RemoveItemFromHotbar(Player, 0, true)
	Check(Context.Data.Hotbar["0"] == nil and not Service:GetToolInHotbarIndex(Player, 0), "Click removal must clear assignment and tool")
	Check(Context.Data.Inventory[1].Stack == 3, "Click removal must preserve the inventory item")
	Service:RemoveItemFromHotbar(Player, 0, true)
	Check(Context.Data.Hotbar["9"] == "WoodLog", "Clicking an empty slot must preserve other slots")

	Check(Service:EquipToHotbar(Player, "Apple", 0), "Prepare a hotbar item for dragging")
	local Apple = Service:GetToolInHotbarIndex(Player, 0)
	local Wood = Service:GetToolInHotbarIndex(Player, 9)
	Check(Service:MoveHotbarSlot(Player, 0, 1, "Apple"), "Dragging into an empty hotbar slot must succeed")
	Check(Context.Data.Hotbar["0"] == nil and Context.Data.Hotbar["1"] == "Apple", "Moving must clear the source assignment")
	Check(Service:GetToolInHotbarIndex(Player, 1) == Apple, "Moving must preserve the existing tool")
	Check(Service:MoveHotbarSlot(Player, 1, 9, "Apple"), "Dragging into an occupied hotbar slot must swap items")
	Check(Context.Data.Hotbar["1"] == "WoodLog" and Context.Data.Hotbar["9"] == "Apple", "Swapping must preserve both saved assignments")
	Check(Service:GetToolInHotbarIndex(Player, 1) == Wood and Service:GetToolInHotbarIndex(Player, 9) == Apple, "Swapping must preserve both tool instances")
	Check(Context.Data.Inventory[1].Stack == 3 and Context.Data.Inventory[2].Stack == 2, "Reordering must not consume inventory stacks")
	Check(not Service:MoveHotbarSlot(Player, 9, 0, "WoodLog"), "A stale source item must not move a replacement")
	Check(not Service:MoveHotbarSlot(Player, 7, 0, "Apple"), "An empty source must be rejected")
	Check(not Service:MoveHotbarSlot(Player, 9, 0.5, "Apple"), "Reordering must reject invalid destination indexes")
	Check(Service:MoveHotbarSlot(Player, 9, 9, "Apple"), "Dropping onto the source slot must be harmless")
	Check(Service:GetToolInHotbarIndex(Player, 9) == Apple, "Dropping onto the source must preserve its tool")
	Service:HandleInventoryAction(Player, {Id = 3, Kind = "MoveHotbar", Name = "Apple", SourceIndex = 9, Index = 0})
	Check(Context.Data.Hotbar["0"] == "Apple" and Context.Data.Hotbar["9"] == nil, "Hotbar moves must work without a backpack revision on other inventory tabs")

	local Artifact = Instance.new("Tool")
	Artifact.Name = "WindStone"
	Artifact:SetAttribute("Class", "Artifact")
	Artifact:SetAttribute("HotbarIndex", 2)
	Artifact.Parent = Player.Backpack
	Check(Service:MoveHotbarSlot(Player, 2, 0, "WindStone"), "Artifacts can be reordered without unequipping them")
	Check(Service:GetToolInHotbarIndex(Player, 0) == Artifact and Service:GetToolInHotbarIndex(Player, 2) == Apple, "Artifact swaps must preserve both tools")
	Check(Context.Data.Hotbar["0"] == nil and Context.Data.Hotbar["2"] == "Apple", "Artifact swaps must preserve the separate artifact persistence rules")
	Artifact:Destroy()

	return tostring(Checks) .. " inventory hotbar checks passed"
end
