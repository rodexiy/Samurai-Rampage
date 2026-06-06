return {
	Name = "setTime",
	Aliases = {},
	Description = "Change the game time.",
	Group = "Admin",

	Args = {
		{
			Type = "number",
			Name = "clock time",
			Description = "Time to change to.",
		},
	},
}
