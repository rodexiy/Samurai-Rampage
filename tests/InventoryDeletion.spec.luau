-- Run production services with an isolated profile and tool container.
return function(Service: any, Context: any, Player: any): string
	local Checks = 0
	local function Check(Value: boolean, Message: string)
		assert(Value, Message)
		Checks += 1
	end
	Context.Data = {
		Inventory = {
			{ Name = "Apple", Stack = 3 },
			{ Name = "WoodLog", Stack = 2 },
			{ Name = "StrawHat", Stack = 1 },
			{ Name = "BasicKatana", Stack = 1 },
			{ Name = "Fists", Stack = 1 },
			{ Name = "Grapple", Stack = 1 },
		},
		Hotbar = { ["0"] = "Apple" },
		Equipped = { Head = "StrawHat", Weapon = "BasicKatana" },
		Backpack = { Version = 1, Columns = 6, Rows = 8, Revision = 0, Positions = {} },
	}
	local Tool = Instance.new("Tool")
	Tool.Name = "Apple"
	Tool:SetAttribute("HotbarIndex", 0)
	Tool.Parent = Player.Backpack
	local Layout = Service:GetInventoryLayout(Player)
	Check(not Service:DeleteItem(Player, "Unknown", 1), "Unowned items must be rejected")
	Check(not Service:DeleteItem(Player, "Apple", 2), "A partial or stale stack must be rejected")
	Check(not Service:DeleteItem(Player, "Apple", -1), "Invalid amounts must not add inventory")
	Check(not Service:DeleteItem(Player, "Apple", 0 / 0), "Non-finite requests must be rejected")
	Check(not Service:DeleteItem(Player, "Fists", 1), "Hidden intrinsic items must be protected")
	Check(not Service:DeleteItem(Player, "Grapple", 1), "Learned abilities must not be removed as physical inventory")
	Check(not Service:DeleteItem(Player, "StrawHat", 1), "Equipped armor must be protected by authoritative state")
	Check(not Service:DeleteItem(Player, "BasicKatana", 1), "Equipped weapons must be protected by authoritative state")
	Check(Service:GetRawPlayerItemByName(Player, "Apple").Stack == 3, "Rejected requests must preserve the full stack")

	Service:HandleInventoryAction(
		Player,
		{ Id = 1, Kind = "Delete", Name = "Apple", Stack = 3, Revision = Layout.Revision - 1 }
	)
	Check(Service:GetRawPlayerItemByName(Player, "Apple") ~= nil, "A stale layout request must not delete an item")
	Context.Data.Inventory[1].Stack = 4
	Check(
		not Service:DeleteItem(Player, "Apple", 3),
		"Items acquired during confirmation must not be deleted unexpectedly"
	)
	Context.Data.Inventory[1].Stack = 3
	Layout = Service:GetInventoryLayout(Player)
	Service:HandleInventoryAction(
		Player,
		{ Id = 2, Kind = "Delete", Name = "Apple", Stack = 3, Revision = Layout.Revision }
	)
	Check(Service:GetRawPlayerItemByName(Player, "Apple") == nil, "Confirmation must delete the entire matching stack")
	Check(
		Context.Data.Hotbar["0"] == nil and Tool.Parent == nil,
		"Deletion must remove matching hotbar assignments and tools"
	)
	Check(Context.Data.Backpack.Positions.Apple == nil, "Deletion must free its backpack footprint")
	Check(Service:GetRawPlayerItemByName(Player, "WoodLog").Stack == 2, "Deletion must preserve unrelated inventory")
	Check(
		Context.Data.Equipped.Head == "StrawHat" and Context.Data.Equipped.Weapon == "BasicKatana",
		"Deletion must preserve equipped items"
	)
	Check(not Service:DeleteItem(Player, "Apple", 3), "Repeated confirmation must not delete anything else")
	return tostring(Checks) .. " authoritative item deletion checks passed"
end
