return {
	Name = "play-intro",
	Aliases = { "playintro", "intro", "cutscene-inicial" },
	Description = "Replays the initial tutorial cutscene without resetting player data.",
	Group = "Admin",
	Args = {
		{
			Type = "players",
			Name = "players",
			Description = "Players to run the intro for. Defaults to you.",
			Optional = true,
		},
	},
}
