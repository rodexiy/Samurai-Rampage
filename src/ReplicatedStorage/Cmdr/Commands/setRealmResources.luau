return {
	Name = "set-realm-resources",
	Aliases = { "setrealmresources", "realmresources" },
	Description = "Enables or disables resource costs for new Realm builds for this session.",
	Group = "Admin",

	Args = {
		{
			Type = "boolean",
			Name = "required",
			Description = "False allows free building. True restores resource costs.",
		},
		{
			Type = "players",
			Name = "players",
			Description = "Players to update. Defaults to you.",
			Optional = true,
		},
	},
}
