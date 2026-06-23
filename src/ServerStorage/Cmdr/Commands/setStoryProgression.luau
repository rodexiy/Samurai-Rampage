return {
	Name = "set-story-progression",
	Aliases = { "setstory", "set-story" },
	Description = "Marks a story mission and its prerequisites complete, then advances to the next mission.",
	Group = "Admin",

	Args = {
		{
			Type = "storyMission",
			Name = "mission",
			Description = "The last story mission that should count as completed.",
		},
		{
			Type = "players",
			Name = "players",
			Description = "Players to update. Defaults to you.",
			Optional = true,
		},
	},
}
