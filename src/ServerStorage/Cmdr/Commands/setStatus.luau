return {
	Name = "set-status",
	Aliases = { "setstatus", "set-stats", "setstats" },
	Description = "Sets every stat to the specified level and resets partial XP.",
	Group = "Admin",
	Args = {
		{
			Type = "number",
			Name = "level",
			Description = "Whole-number level from 0 to the configured maximum.",
		},
		{
			Type = "players",
			Name = "players",
			Description = "Players to update. Defaults to you.",
			Optional = true,
		},
	},
}
