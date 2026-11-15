-- Run production services with isolated profile, tool instances and render collector.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DeepCopy = require(ReplicatedStorage.Shared.Utils.DeepCopy)
return function(Inventory: any, Grid: any, Stacks: any, Floor: any, Context: any, Player: any): string
	local Checks = 0
	local function Check(Value: boolean, Message: string)
		assert(Value, Message)
		Checks += 1
	end
	local function Reset(Items: { any }, Columns: number?, Rows: number?)
		Player.Backpack:ClearAllChildren()
		Player.Character:ClearAllChildren()
		local Root = Instance.new("Part")
		Root.Parent = Player.Character
		Player.Character.PrimaryPart = Root
		Instance.new("Humanoid").Parent = Player.Character
		Context.Data = {
			Inventory = Items,
			Equipped = {},
			Hotbar = {},
			Backpack = { Version = 1, Columns = Columns or 6, Rows = Rows or 8, Revision = 0, Positions = {} },
		}
		return Context.Data
	end

	local Data = Reset({ { Name = "Apple", Stack = 98 } })
	Check(
		Inventory:GiveItemToPlayer(Player, { Name = "Apple", Stack = 105 }) == 105,
		"Receiving must not truncate at one stack"
	)
	Check(
		#Data.Inventory == 3
			and Data.Inventory[1].Stack == 99
			and Data.Inventory[2].Stack == 99
			and Data.Inventory[3].Stack == 5,
		"Incomplete stacks must fill before new stacks are created"
	)
	local First, Second, Third = Data.Inventory[1].Id, Data.Inventory[2].Id, Data.Inventory[3].Id
	Check(First ~= Second and Second ~= Third, "Every stack must have a distinct identity")
	Check(
		Inventory:GetPlayerItemByName(Player, "Apple").Stack == 203,
		"Name-based gameplay queries must count all stacks"
	)
	local Layout = Grid:GetLayout(Player)
	Check(
		Layout.Positions[First] and Layout.Positions[Second] and Layout.Positions[Third],
		"Each stack must occupy a separate grid slot"
	)
	Check(Grid:Move(Player, Second, 4, 3, false, Layout.Revision), "A duplicate stack must move independently")
	Layout = Grid:GetLayout(Player)
	Check(
		Layout.Positions[Second].Row == 3 and Layout.Positions[First].Row == 1,
		"Moving a stack must preserve its siblings"
	)
	Check(
		Inventory:EquipToHotbar(Player, First, 1) and Inventory:EquipToHotbar(Player, Third, 2),
		"Different stacks of one item must equip independently"
	)
	local ToolA, ToolB = Inventory:GetToolInHotbarIndex(Player, 1), Inventory:GetToolInHotbarIndex(Player, 2)
	Check(
		ToolA:GetAttribute("Id") == First and ToolA:GetAttribute("Stack") == 99,
		"Hotbar quantity must belong to its assigned stack"
	)
	Check(
		ToolB:GetAttribute("Id") == Third and ToolB:GetAttribute("Stack") == 5,
		"Duplicate hotbar tools must retain distinct quantities"
	)
	Check(Inventory:MoveHotbarSlot(Player, 2, 1, Third), "Duplicate hotbar tools must swap by identity")
	Check(
		Data.HotbarStackIds["1"] == Third and Data.HotbarStackIds["2"] == First,
		"Swapping must persist both stack assignments"
	)
	Layout = Grid:GetLayout(Player)
	Check(
		Grid:Move(Player, Second, 4, 4, false, Layout.Revision),
		"Moving a sibling stack after equipping must succeed"
	)
	Check(
		Data.HotbarStackIds["1"] == Third and ToolB.Parent ~= nil,
		"Moving a sibling stack must preserve its hotbar assignment"
	)
	ToolB.Parent = Player.Character
	Inventory:ConsumeToolItem(Player, "Apple", 1)
	Check(
		Inventory:GetRawPlayerStack(Player, Third).Stack == 4 and Inventory:GetRawPlayerStack(Player, First).Stack == 99,
		"Using a tool must consume its own stack"
	)
	Check(ToolB:GetAttribute("Stack") == 4, "Using a duplicate tool must refresh the matching quantity")
	Check(Inventory:DeleteItem(Player, Second, 99), "A duplicate stack must be deletable independently")
	Check(
		Inventory:GetRawPlayerStack(Player, First)
			and Inventory:GetRawPlayerStack(Player, Third)
			and ToolA.Parent
			and ToolB.Parent,
		"Deleting one stack must preserve sibling stacks and tools"
	)
	Check(Inventory:DropItem(Player, Third, 2, 4), "Drop must target the selected duplicate stack")
	Check(
		Inventory:GetRawPlayerStack(Player, Third).Stack == 2 and Inventory:GetRawPlayerStack(Player, First).Stack == 99,
		"Partial drop must preserve sibling quantities"
	)
	local Drop = Context.Drops[#Context.Drops]
	Floor:ClaimItem(Player, Drop.Id)
	Check(Inventory:GetRawPlayerStack(Player, Third).Stack == 4, "Picking up must refill compatible incomplete stacks")

	local Copy = DeepCopy(Data)
	Context.Data = Copy
	Stacks:Normalize(Copy)
	Check(
		Copy.Inventory[1].Id == First and Copy.HotbarStackIds["1"] == Third,
		"Reloading must preserve IDs and hotbar references"
	)
	Check(Grid:GetLayout(Player).Positions[First] ~= nil, "Reloading must preserve each stack's layout")

	Data = Reset({ { Name = "Apple", Stack = 198 } }, 1, 1)
	Layout = Grid:GetLayout(Player)
	Check(
		#Data.Inventory == 2 and Data.Inventory[1].Stack == 99 and Data.Inventory[2].Stack == 99,
		"Legacy oversized stacks must migrate without losing items"
	)
	Check(#Layout.Overflow == 1, "Migration must preserve excess stacks in overflow")
	Data = Reset({ { Name = "Apple", Stack = 98 } }, 1, 1)
	Check(
		not Grid:CanAdd(Player, { Name = "Apple", Stack = 3 }),
		"Capacity checks must account for extra required stacks"
	)
	Check(
		Inventory:GiveItemToPlayer(Player, { Name = "Apple", Stack = 3 }) == 1,
		"Receiving with limited space must report only the amount accepted"
	)
	Check(Data.Inventory[1].Stack == 99 and #Data.Inventory == 1, "Full backpacks must not create overlapping stacks")

	Data = Reset({ { Name = "Apple", Stack = 3, Quality = "A" } })
	Inventory:GiveItemToPlayer(Player, { Name = "Apple", Stack = 4, Quality = "B" })
	Check(#Data.Inventory == 2 and Data.Inventory[1].Stack == 3, "Different item metadata must not merge")
	Inventory:RemoveItemFromPlayer(Player, "Apple", 5)
	Check(Inventory:GetPlayerItemByName(Player, "Apple").Stack == 2, "Gameplay consumption must span multiple stacks")

	Data = Reset({ { Name = "StrawHat", Stack = 1 }, { Name = "StrawHat", Stack = 1 } })
	Grid:GetLayout(Player)
	First, Second = Data.Inventory[1].Id, Data.Inventory[2].Id
	Check(Inventory:EquipEquipmentSlot(Player, "Head", Second), "Duplicate equipment must equip by stack identity")
	Layout = Inventory:GetInventoryLayout(Player)
	Check(
		Layout.Equipped.Head == Second and Layout.Positions[First] and not Layout.Positions[Second],
		"Only the selected equipped copy must leave the grid"
	)
	Check(Data.Equipped.Head == "StrawHat", "Gameplay equipment references must retain the item definition name")
	Check(
		not Inventory:DeleteItem(Player, Second, 1) and Inventory:DeleteItem(Player, First, 1),
		"Equipment protection must apply to the equipped copy only"
	)
	Check(Inventory:UnequipEquipmentSlot(Player, "Head", Second), "Duplicate equipment must unequip by identity")
	Check(Grid:GetLayout(Player).Positions[Second] ~= nil, "Unequipping must restore the same stack to the grid")

	local OriginalLimit = Context.Items.GunAmmo.MaxStack
	Context.Items.GunAmmo.MaxStack = 3
	Data = Reset({
		{ Name = "BlackPowderSack", Stack = 1 },
		{ Name = "BlackPowderSack", Stack = 1 },
		{ Name = "IronIngot", Stack = 1 },
		{ Name = "IronIngot", Stack = 1 },
		{ Name = "GunAmmo", Stack = 3 },
	})
	Check(
		Context.Crafting:Craft(Player, "GunAmmo", 2, "Crafting") == 2,
		"Crafting must consume materials across stacks and exceed one output stack"
	)
	Check(
		Inventory:GetPlayerItemByName(Player, "GunAmmo").Stack == 9,
		"Crafting must retain all output across multiple stacks"
	)
	Check(
		not Inventory:GetPlayerItemByName(Player, "IronIngot")
			and not Inventory:GetPlayerItemByName(Player, "BlackPowderSack"),
		"Crafting must remove precisely the consumed material stacks"
	)
	Context.Items.GunAmmo.MaxStack = OriginalLimit
	return tostring(Checks) .. " multiple-stack inventory checks passed"
end
