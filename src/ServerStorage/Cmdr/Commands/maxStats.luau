return {
	Name = "max-stats",
	Aliases = { "maxstats" },
	Description = "Raises every attribute to its maximum level and updates skill points.",
	Group = "Admin",

	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "Players to update. Defaults to you.",
			Optional = true,
		},
	},
}
