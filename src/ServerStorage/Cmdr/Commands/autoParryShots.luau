return {
	Name = "auto-parry-shots",
	Aliases = { "autoparryshots", "auto-parry-tiros" },
	Description = "Automatically parries incoming firearm shots when the player can defend. Applies to this session.",
	Group = "Admin",
	Args = {
		{
			Type = "player",
			Name = "player",
			Description = "Player whose automatic shot parry will change.",
		},
		{
			Type = "boolean",
			Name = "enabled",
			Description = "Use false to disable it. Defaults to true.",
			Optional = true,
		},
	},
}
