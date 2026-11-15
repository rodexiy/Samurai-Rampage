-- Run production crafting/inventory services with isolated profile data.
return function(Crafting: any, Grid: any, Inventory: any, Context: any, Player: any): string
	local Checks = 0
	local function Check(Value: boolean, Message: string)
		assert(Value, Message)
		Checks += 1
	end
	local function Reset(Sacks: number, Iron: number, Ammo: number, Columns: number?)
		Context.Data = {
			Inventory = {},
			Hotbar = {},
			Equipped = {},
			UnlockedBlueprints = {},
			Backpack = { Version = 1, Columns = Columns or 6, Rows = 1, Revision = 0, Positions = {} },
		}
		for Name, Stack in { BlackPowderSack = Sacks, IronIngot = Iron, GunAmmo = Ammo } do
			if Stack > 0 then
				table.insert(Context.Data.Inventory, { Name = Name, Stack = Stack })
			end
		end
	end
	local function Stack(Name: string): number
		local Item = Inventory:GetPlayerItemByName(Player, Name)
		return if Item then Item.Stack else 0
	end

	local Item = Context.Items.GunAmmo
	Check(
		Item.Type == "Ammunition" and Item.AmountPerCraft == 3,
		"GunAmmo must be ammunition yielding three rounds per craft"
	)
	Check(
		Context.Items.Crystal == nil and Context.Items.Gunpowder == nil and Context.Items.IronBullet == nil,
		"Retired items must leave the catalog"
	)
	Reset(1, 1, 0)
	local Recipe
	for _, Candidate in Crafting:GetAvailableRecipes(Player, "Crafting") do
		if Candidate.Name == "GunAmmo" then
			Recipe = Candidate
			break
		end
	end
	Check(Recipe ~= nil and Recipe.AmountPerCraft == 3, "The crafting UI must receive the three-round recipe")
	Check(
		Recipe.CraftingRequirements[1][1].BlackPowderSack == 1 and Recipe.CraftingRequirements[2][1].IronIngot == 1,
		"The crafting UI must receive the exact ingredient quantities"
	)
	Check(Crafting:GetMaxCraftable(Player, "GunAmmo", "Crafting") == 1, "One sack and one ingot must enable one craft")
	Check(Crafting:GetMaxCraftable(Player, "GunAmmo", "Forge") == 0, "GunAmmo must use the crafting recipe category")
	Check(Crafting:Craft(Player, "GunAmmo", 1, "Crafting") == 1, "Crafting the new ammunition must succeed")
	Check(
		Stack("GunAmmo") == 3 and Stack("BlackPowderSack") == 0 and Stack("IronIngot") == 0,
		"Each craft must consume exactly one of each ingredient and produce three rounds"
	)
	Reset(1, 0, 0)
	Check(
		Crafting:Craft(Player, "GunAmmo", 1, "Crafting") == 0 and Stack("BlackPowderSack") == 1,
		"Missing iron must not consume the sack"
	)
	Reset(0, 1, 0)
	Check(
		Crafting:Craft(Player, "GunAmmo", 1, "Crafting") == 0 and Stack("IronIngot") == 1,
		"Missing powder must not consume iron"
	)
	Reset(4, 2, 0)
	Check(Crafting:Craft(Player, "GunAmmo", "All", "Crafting") == 2, "Craft all must respect the limiting ingredient")
	Check(
		Stack("GunAmmo") == 6 and Stack("BlackPowderSack") == 2 and Stack("IronIngot") == 0,
		"Batch crafting must preserve the one-to-three ratio"
	)
	Reset(1, 1, 997)
	Check(
		Crafting:GetMaxCraftable(Player, "GunAmmo", "Crafting") == 1,
		"A full output batch may continue into another stack"
	)
	Check(
		Crafting:Craft(Player, "GunAmmo", 1, "Crafting") == 1 and Stack("GunAmmo") == 1000 and Stack("IronIngot") == 0,
		"Crafting across the stack limit must preserve the complete output batch"
	)
	Reset(1, 1, 996)
	Check(
		Crafting:Craft(Player, "GunAmmo", 1, "Crafting") == 1 and Stack("GunAmmo") == 999,
		"A final complete batch may reach the stack limit"
	)
	Reset(1, 1, 0, 2)
	Check(
		Crafting:Craft(Player, "GunAmmo", 1, "Crafting") == 1 and Stack("GunAmmo") == 3,
		"Crafting must use space freed by consumed ingredients"
	)
	Reset(2, 2, 0, 2)
	Check(
		not Grid:CanCraft(Player, { BlackPowderSack = 1, IronIngot = 1 }, 1, Item),
		"Full backpacks must account for ingredient stacks that remain"
	)
	Check(Crafting:Craft(Player, "GunAmmo", 1, "Crafting") == 0, "Crafting without output space must fail")
	Check(
		Stack("BlackPowderSack") == 2 and Stack("IronIngot") == 2 and Stack("GunAmmo") == 0,
		"Rejected crafting must preserve every ingredient"
	)
	Check(
		Crafting:Craft(Player, "GunAmmo", "All", "Crafting") == 2 and Stack("GunAmmo") == 6,
		"Consuming full ingredient stacks must make the freed space available"
	)

	Reset(1, 1, 0)
	table.insert(Context.Data.Inventory, 1, { Name = "Crystal", Stack = 4 })
	table.insert(Context.Data.Inventory, 2, { Name = "Gunpowder", Stack = 3 })
	table.insert(Context.Data.Inventory, 3, { Name = "IronBullet", Stack = 2 })
	Context.Data.Hotbar = { ["0"] = "Crystal", ["1"] = "Gunpowder", ["2"] = "IronBullet", ["3"] = "IronIngot" }
	Context.Data.Equipped = { Head = "Crystal" }
	Context.Data.Backpack.Positions = { Crystal = {}, Gunpowder = {}, IronBullet = {}, IronIngot = {} }
	Inventory:RemoveUnavailableItems(Player)
	Check(
		#Context.Data.Inventory == 2 and Stack("BlackPowderSack") == 1 and Stack("IronIngot") == 1,
		"Cleanup must remove all consecutive retired entries and preserve valid items"
	)
	Check(
		Context.Data.Hotbar["0"] == nil
			and Context.Data.Hotbar["1"] == nil
			and Context.Data.Hotbar["2"] == nil
			and Context.Data.Hotbar["3"] == "IronIngot",
		"Cleanup must remove retired hotbar references"
	)
	Check(
		Context.Data.Equipped.Head == nil and Context.Data.Backpack.Positions.Crystal == nil,
		"Cleanup must remove retired equipment and layout references"
	)
	local Revision = Context.Data.Backpack.Revision
	Inventory:RemoveUnavailableItems(Player)
	Check(
		#Context.Data.Inventory == 2 and Context.Data.Backpack.Revision == Revision,
		"Retired-item cleanup must be idempotent"
	)
	return tostring(Checks) .. " GunAmmo crafting and cleanup checks passed"
end
