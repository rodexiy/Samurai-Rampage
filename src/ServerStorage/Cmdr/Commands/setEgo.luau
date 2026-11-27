return {
	Name = "set-ego",
	Aliases = { "setego" },
	Description = "Changes and saves a player's Ego ID.",
	Group = "Admin",
	Args = {
		{
			Type = "string",
			Name = "ego",
			Description = "Ego ID from EgoConfig (for example, 1 or 2).",
		},
		{
			Type = "players",
			Name = "players",
			Description = "Players to update. Defaults to you.",
			Optional = true,
		},
	},
}
