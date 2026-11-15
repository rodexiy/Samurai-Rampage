return {
	Name = "GunAmmo",
	Class = "Resource",
	Type = "Ammunition",
	DisplayName = "Gun Ammo",
	Description = "Prepared ammunition for the Tanegashima. Each shot consumes one round.",
	AmountPerCraft = 3,
	RecipeType = "Crafting",
	CraftingRequirements = {
		{ { BlackPowderSack = 1 } },
		{ { IronIngot = 1 } },
	},
	MaxStack = 999,
}
