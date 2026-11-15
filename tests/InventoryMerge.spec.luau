-- Production inventory, grid, stack and tool services with an isolated profile.
return function(Inventory: any, Grid: any, Context: any, Player: any): string
	local Checks = 0
	local function Check(Value: boolean, Message: string)
		assert(Value, Message)
		Checks += 1
	end
	local function Reset(SourceAmount: number, TargetAmount: number, Columns: number?)
		Player.Backpack:ClearAllChildren()
		Player.Character:ClearAllChildren()
		Context.Data = {
			Inventory = {
				{ Id = "Source", Name = "Apple", Stack = SourceAmount },
				{ Id = "Target", Name = "Apple", Stack = TargetAmount },
			},
			Equipped = {},
			Hotbar = {},
			Backpack = { Version = 1, Columns = Columns or 6, Rows = 1, Revision = 0, Positions = {} },
		}
		Grid:GetLayout(Player)
		return Context.Data.Inventory[1], Context.Data.Inventory[2]
	end
	local Source, Target = Reset(2, 97)
	local Layout = Inventory:GetInventoryLayout(Player)
	local Position = Layout.Positions.Target
	Inventory:HandleInventoryAction(
		Player,
		{
			Id = 1,
			Kind = "Merge",
			Name = "Source",
			Target = "Target",
			Stack = 2,
			TargetStack = 97,
			Revision = Layout.Revision,
		}
	)
	Check(
		Inventory:GetRawPlayerStack(Player, "Source") == nil and Target.Stack == 99,
		"2 onto 97 must make 99 and remove the empty source"
	)
	Layout = Grid:GetLayout(Player)
	Check(
		Layout.Positions.Source == nil and Layout.Positions.Target.Column == Position.Column,
		"A complete merge must free only the source slot"
	)
	Check(Inventory:GetPlayerItemByName(Player, "Apple").Stack == 99, "Merging must conserve the total quantity")
	Check(not Inventory:MergeStacks(Player, "Source", "Target", 2, 97), "Repeated requests must not duplicate items")

	Source, Target = Reset(97, 5)
	Check(Inventory:MergeStacks(Player, "Source", "Target", 97, 5), "A partial merge must succeed")
	Check(
		Source.Stack == 3 and Target.Stack == 99,
		"Only available capacity may transfer; the remainder stays in its source"
	)
	Layout = Grid:GetLayout(Player)
	Check(
		Layout.Positions.Source ~= nil and Layout.Positions.Target ~= nil,
		"A partial merge must retain both grid slots"
	)
	Check(Inventory:GetPlayerItemByName(Player, "Apple").Stack == 102, "A partial merge must conserve all items")
	Check(not Inventory:MergeStacks(Player, "Source", "Target", 3, 99), "Full destination stacks must reject merging")
	Check(not Inventory:MergeStacks(Player, "Source", "Source", 3, 3), "A stack must not merge with itself")
	Check(not Inventory:MergeStacks(Player, "Missing", "Target", 3, 99), "Unowned source stacks must be rejected")
	Check(not Inventory:MergeStacks(Player, "Source", "Missing", 3, 99), "Unowned destination stacks must be rejected")
	Check(not Inventory:MergeStacks(Player, "Source", {}, 3, 99), "Malformed target identities must be rejected")

	Source, Target = Reset(2, 97)
	Check(not Inventory:MergeStacks(Player, "Source", "Target", 1, 97), "A stale source quantity must be rejected")
	Check(not Inventory:MergeStacks(Player, "Source", "Target", 2, 96), "A stale destination quantity must be rejected")
	Check(
		not Inventory:MergeStacks(Player, "Source", "Target", 0 / 0, 97),
		"Non-finite quantity requests must be rejected"
	)
	Layout = Grid:GetLayout(Player)
	Inventory:HandleInventoryAction(
		Player,
		{
			Id = 2,
			Kind = "Merge",
			Name = "Source",
			Target = "Target",
			Stack = 2,
			TargetStack = 97,
			Revision = Layout.Revision - 1,
		}
	)
	Check(Source.Stack == 2 and Target.Stack == 97, "A stale layout must preserve both stacks")
	Target.Name = "WoodLog"
	Check(not Inventory:MergeStacks(Player, "Source", "Target", 2, 97), "Different item definitions must not merge")
	Target.Name = "Apple"
	Source.Quality, Target.Quality = "A", "B"
	Check(
		not Inventory:MergeStacks(Player, "Source", "Target", 2, 97),
		"Different persistent item metadata must not merge"
	)
	Target.Quality = "A"
	Check(
		Inventory:MergeStacks(Player, "Source", "Target", 2, 97) and Target.Quality == "A",
		"Matching metadata must survive merging"
	)

	Source, Target = Reset(5, 97)
	Check(
		Inventory:EquipToHotbar(Player, "Source", 1) and Inventory:EquipToHotbar(Player, "Target", 2),
		"Both stacks must equip for the quantity update test"
	)
	local SourceTool = Inventory:GetToolInHotbarIndex(Player, 1)
	local TargetTool = Inventory:GetToolInHotbarIndex(Player, 2)
	Check(Inventory:MergeStacks(Player, "Source", "Target", 5, 97), "Hotbar-assigned stacks must support merging")
	Check(
		SourceTool:GetAttribute("Stack") == 3 and TargetTool:GetAttribute("Stack") == 99,
		"A partial merge must update each existing tool's quantity"
	)
	Check(
		Context.Data.HotbarStackIds["1"] == "Source" and Context.Data.HotbarStackIds["2"] == "Target",
		"A partial merge must preserve both hotbar assignments"
	)
	Source, Target = Reset(2, 97)
	Inventory:EquipToHotbar(Player, "Source", 1)
	Inventory:EquipToHotbar(Player, "Target", 2)
	SourceTool, TargetTool = Inventory:GetToolInHotbarIndex(Player, 1), Inventory:GetToolInHotbarIndex(Player, 2)
	Check(Inventory:MergeStacks(Player, "Source", "Target", 2, 97), "A complete hotbar stack merge must succeed")
	Check(
		SourceTool.Parent == nil and Context.Data.Hotbar["1"] == nil,
		"An emptied source must remove only its tool and assignment"
	)
	Check(
		TargetTool.Parent ~= nil
			and TargetTool:GetAttribute("Stack") == 99
			and Context.Data.HotbarStackIds["2"] == "Target",
		"The destination tool and assignment must remain intact"
	)

	Source, Target = Reset(2, 97, 1)
	Check(#Grid:GetLayout(Player).Overflow == 1, "The overflow fixture must have one unplaced stack")
	Check(
		Inventory:MergeStacks(Player, "Source", "Target", 2, 97),
		"Overflow stacks must be combinable to free inventory space"
	)
	Check(#Grid:GetLayout(Player).Overflow == 0, "A complete merge must resolve the overflow")
	return tostring(Checks) .. " inventory stack merge checks passed"
end
