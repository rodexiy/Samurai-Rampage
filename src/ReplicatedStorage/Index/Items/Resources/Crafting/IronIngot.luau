return {
	Name = "IronIngot",
	DisplayName = "Iron Ingot",
	Class = "Resource",
	Type = "Crafting",

	Description = "Can be used in weapons and armors.",

	AmountPerCraft = 1,
	RecipeType = "Forge",

	CraftingRequirements = {
		{ { Coal = 1 } },
		{ { IronOre = 1 } },
	},
	
	MaxStack = 99,
}
