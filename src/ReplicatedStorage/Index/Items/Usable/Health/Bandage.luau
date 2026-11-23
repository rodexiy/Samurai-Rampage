return {
	Name = "Bandage",
	Class = "Usable",
	Type = "Health",

	DisplayName = "Bandage",
	Description = "Apply for 2 seconds to restore <font color='rgb(82,255,0)'>15 Health</font>. Taking a hit interrupts application. Ten second cooldown.",

	MaxStack = 5,
	AmountPerCraft = 1,
	RecipeType = "Crafting",

	CraftingRequirements = {
		{ { HealingHerbs = 2 } },
	},
}
