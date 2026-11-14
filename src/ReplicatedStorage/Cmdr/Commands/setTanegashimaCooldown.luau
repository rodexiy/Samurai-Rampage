return {
	Name = "set-tanegashima-cooldown",
	Aliases = { "settanegashimacooldown", "set-tane-cooldown" },
	Description = "Sets a player's Tanegashima cooldown for this session and adjusts reload timing. Zero removes the cooldown.",
	Group = "Admin",

	Args = {
		{
			Type = "number",
			Name = "seconds",
			Description = "Cooldown in seconds, including decimals. Use 0 for no cooldown or 7 for the default.",
		},
		{
			Type = "players",
			Name = "players",
			Description = "Players to update. Defaults to you.",
			Optional = true,
		},
	},
}
