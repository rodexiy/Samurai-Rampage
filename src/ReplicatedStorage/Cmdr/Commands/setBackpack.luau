return {
	Name = "set-backpack",
	Aliases = { "setbackpack" },
	Description = "Sets the saved backpack: 1 (6x8), 2 (6x12), 3 (6x16), or 4 (admin, 6x100).",
	Group = "Admin",

	Args = {
		{
			Type = "integer",
			Name = "tier",
			Description = "Backpack tier: 1, 2, 3, or 4 for the admin backpack.",
		},
		{
			Type = "players",
			Name = "players",
			Description = "Players to update. Defaults to you.",
			Optional = true,
		},
	},
}
