return {
	Name = "Flag",
	Class = "Equipable",
	Type = "Back",

	DisplayName = "Flag",
	Description = `Use /flag [Image Id] in the chat to change the flag image, and /flagColor [#Hex code] to change the flag color.`,

	MaxStack = 1,

	AmountPerCraft = 1,
	RecipeType = "Crafting",
	CraftingRequirements = {
		Cloth = 4,
		WoodLog  = 1,
		StrongRope = 2
	},
}
