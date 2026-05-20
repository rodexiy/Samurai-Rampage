return {
	Name = "Kagutsuchi Emblem",
	Color = Color3.fromRGB(255, 0, 0),
	Description = "The emblem of the Kagutsuchi.",

	Branches = {

		{
			Name = "Kagutsuchi Emblem I",
			PointsRequired = 1,
			Description = "Ignite your blade with the fire of Kagutsuchi.",
			Position = "Forward",

			Branches = {
				{
					Name = "Blade Ignition",
					PointsRequired = 1,
					Description = "Ignite your blade with the fire of Kagutsuchi.",
					Position = "DiagonalRight",

					Branches = {
						{
							Name = "Blade Ignition II",
							PointsRequired = 2,
							Description = "Increase the duration of the fire.",
							Position = "DiagonalRight",
							Passive = true,
						},
					},
				},

				{
					Name = "Kagutsuchi Emblem II",
					PointsRequired = 2,
					Description = "Ignite your blade with the fire of Kagutsuchi.",
					Position = "DiagonalLeft",

					Branches = {
						{
							Name = "Fire Slash",
							PointsRequired = 2,
							Description = "Release a forward slash of fire.",
							Position = "DiagonalLeft",
						},

						{
							Name = "Kagutsuchi Emblem III",
							PointsRequired = 3,
							Description = "Ignite your blade with the fire of Kagutsuchi.",
							Position = "DiagonalRight",

							Branches = {
								{
									Name = "Molten Smash",
									PointsRequired = 3,
									Description = "3 large explosions of fire.",
									Position = "DiagonalRight",
								},

								{
									Name = "Kagutsuchi Emblem IV",
									PointsRequired = 4,
									Description = "Ignite your blade with the fire of Kagutsuchi.",
									Position = "DiagonalLeft",

									Branches = {
										{
											Name = "Fireball",
											PointsRequired = 4,
											Description = "Explode everyone in your way.",
											Position = "DiagonalLeft",
										},
										{
											Name = "Kagutsuchi Emblem V",
											PointsRequired = 5,
											Description = "Ignite your blade with the fire of Kagutsuchi.",
											Position = "DiagonalRight",

											Branches = {},
										},
									},
								},
							},
						},
					},
				},
			},
		},
	},
}
