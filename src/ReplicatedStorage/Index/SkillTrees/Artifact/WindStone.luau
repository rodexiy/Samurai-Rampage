return {
	Name = "Wind Stone",
	Color = Color3.fromRGB(112, 204, 103),
	Description = "The emblem of the Kagutsuchi.",

	Branches = {
		{
			Name = "Wind Vault",
			PointsRequired = 1,
			Description = "Quickly vault 4 studs forward in any direction, bypassing terrain and light obstacles. Deals light posture damage if passing through an enemy.",
			Position = "Forward",

			Branches = {
				{
					Name = "Gale Kick",
					PointsRequired = 2,
					Description = "If you collide with an enemy during Wind Vault, they are briefly staggered (0.5s) and pushed back.",
					Position = "Forward",
					Passive = true,
				},
			},
		},
	},
}
