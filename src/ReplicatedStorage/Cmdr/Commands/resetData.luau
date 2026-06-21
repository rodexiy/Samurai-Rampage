return {
	Name = "reset-data",
	Aliases = { "resetdata", "restart-tutorial", "restarttutorial" },
	Description = "Completely resets player data and restarts the tutorial.",
	Group = "Admin",

	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "Players to reset. Defaults to you.",
			Optional = true,
		},
	},
}
