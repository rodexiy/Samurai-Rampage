return {
	Name = "set-fear",
	Aliases = { "setfear", "fear" },
	Description = "Sets fear from 0 to 100 percent. Fear decays by 2 each second.",
	Group = "Admin",
	Args = {
		{
			Type = "number",
			Name = "level",
			Description = "Fear percentage (0-100).",
		},
		{
			Type = "players",
			Name = "players",
			Description = "Players to update. Defaults to you.",
			Optional = true,
		},
	},
}
