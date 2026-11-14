return {
	Name = "set-horse-level",
	Aliases = { "sethorselevel", "set-horse-tier" },
	Description = "Sets the player's saved horse level. Summon the horse again to use it.",
	Group = "Admin",

	Args = {
		{
			Type = "integer",
			Name = "level",
			Description = "Horse level, from 1 to 5.",
		},
		{
			Type = "players",
			Name = "players",
			Description = "Players to update. Defaults to you.",
			Optional = true,
		},
	},
}
