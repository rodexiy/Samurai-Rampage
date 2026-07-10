return {
	Name = "PortableRug",
	Class = "Usable",
	Type = "Misc",

	DisplayName = "Portable Rug",
	Description = "A portable resting rug with five uses. Only one can be carried at a time.",

	MaxUses = 5,
	MaxStack = 1,
	AmountPerCraft = 1,
	RecipeType = "Crafting",

	CraftingRequirements = {
		{ { Cloth = 4 } },
		{ { StrongRope = 2 } }
	},
}
