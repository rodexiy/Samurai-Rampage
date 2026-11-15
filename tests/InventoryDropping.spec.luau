-- Production inventory/grid/floor-drop services with an isolated profile and render collector.
return function(Service: any, Floor: any, Context: any, Player: any): string
	local Checks = 0
	local function Check(Value: boolean, Message: string)
		assert(Value, Message)
		Checks += 1
	end
	Context.Data = {
		Inventory = {
			{ Name = "Apple", Stack = 9, CustomValue = 42 },
			{ Name = "StrawHat", Stack = 1 },
			{ Name = "Fists", Stack = 1 },
			{ Name = "Grapple", Stack = 1 },
		},
		Hotbar = { ["0"] = "Apple" },
		Equipped = { Head = "StrawHat" },
		Backpack = { Version = 1, Columns = 6, Rows = 8, Revision = 0, Positions = {} },
	}
	local Root = Instance.new("Part")
	Root.Parent = Player.Character
	Player.Character.PrimaryPart = Root
	local Humanoid = Instance.new("Humanoid")
	Humanoid.Parent = Player.Character
	local Layout = Service:GetInventoryLayout(Player)
	for _, Amount in { 0, -1, 10, 1.5, math.huge, 0 / 0, "3" } do
		Check(not Service:DropItem(Player, "Apple", Amount, 9), "Invalid amounts must not remove inventory")
	end
	Check(not Service:DropItem(Player, "Missing", 1, 1), "Unowned items must not drop")
	Check(not Service:DropItem(Player, "Apple", 1, 8), "Stale stacks must not drop")
	Check(not Service:DropItem(Player, "StrawHat", 1, 1), "Equipped items must not drop")
	Check(not Service:DropItem(Player, "Fists", 1, 1), "Hidden intrinsic items must not drop")
	Check(not Service:DropItem(Player, "Grapple", 1, 1), "Skills must not drop")
	Player.Character.PrimaryPart = nil
	Check(not Service:DropItem(Player, "Apple", 1, 9), "Missing characters must not lose items")
	Player.Character.PrimaryPart = Root
	Service:HandleInventoryAction(
		Player,
		{ Id = 1, Kind = "Drop", Name = "Apple", Stack = 9, Amount = 3, Revision = Layout.Revision - 1 }
	)
	Check(
		#Context.Drops == 0 and Service:GetRawPlayerItemByName(Player, "Apple").Stack == 9,
		"Stale layouts must not drop"
	)
	Service:HandleInventoryAction(
		Player,
		{ Id = 2, Kind = "Drop", Name = "Apple", Stack = 9, Amount = 3, Revision = Layout.Revision }
	)
	Check(#Context.Drops == 1, "A valid drop must create one world pickup")
	local Drop = Context.Drops[1]
	Check(
		Drop.Name == "Apple" and Drop.Amount == 3 and Drop.UseDroppedItem,
		"Pickup must carry the selected quantity and generic model flag"
	)
	Check(
		Service:GetRawPlayerItemByName(Player, "Apple").Stack == 6,
		"Partial drop must remove only the requested quantity"
	)
	Check(Context.Data.Hotbar["0"] == "Apple", "Partial drop must keep the hotbar assignment")
	Check(Context.Data.Backpack.Positions.Apple ~= nil, "Partial drop must preserve the inventory slot")
	Floor:ClaimItem(Player, Drop.Id)
	Check(Service:GetRawPlayerItemByName(Player, "Apple").Stack == 9, "Pickup must return exactly the dropped quantity")
	Floor:ClaimItem(Player, Drop.Id)
	Check(Service:GetRawPlayerItemByName(Player, "Apple").Stack == 9, "Repeated claims must not duplicate items")
	Check(Service:DropItem(Player, "Apple", 9, 9), "The whole stack must be droppable")
	Drop = Context.Drops[#Context.Drops]
	Check(
		Service:GetRawPlayerItemByName(Player, "Apple") == nil and Context.Data.Hotbar["0"] == nil,
		"Whole-stack drops must remove item and hotbar assignment"
	)
	Check(Context.Data.Backpack.Positions.Apple == nil, "Whole-stack drops must free the inventory footprint")
	Root.Position = Vector3.new(1000, 0, 0)
	Floor:ClaimItem(Player, Drop.Id)
	Check(Service:GetRawPlayerItemByName(Player, "Apple") == nil, "Remote claims must be rejected")
	Root.Position = Vector3.zero
	local Give = Service.GiveItemToPlayer
	Service.GiveItemToPlayer = function()
		return 0
	end
	Floor:ClaimItem(Player, Drop.Id)
	Check(Context.Removes[Drop.Id] == nil, "A full inventory must not destroy the pickup")
	Service.GiveItemToPlayer = Give
	Floor:ClaimItem(Player, Drop.Id)
	local Item = Service:GetRawPlayerItemByName(Player, "Apple")
	Check(Item.Stack == 9 and Item.CustomValue == 42, "Reclaiming must preserve item metadata")
	Check(Context.Removes[Drop.Id], "Successful pickup must remove the world model")
	Check(Context.Data.Equipped.Head == "StrawHat", "Dropping must preserve unrelated equipment")
	return tostring(Checks) .. " authoritative item drop checks passed"
end
