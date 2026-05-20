return {
	Name = "take-damage",
	Aliases = { "takedamage", "damage" },
	Description = "Deals damage to your character.",
	Group = "Admin",

	Args = {
		{
			Type = "number",
			Name = "amount",
			Description = "The amount of damage to take.",
		},
	},
}
