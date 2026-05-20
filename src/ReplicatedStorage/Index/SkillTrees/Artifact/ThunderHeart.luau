return {
	Name = "Thunder Heart",
	Color = Color3.fromRGB(255, 208, 0),
	Description = "The emblem of the Kagutsuchi.",

	Branches = {
		{
			Name = "Thunder Heart I",
			PointsRequired = 1,
			Description = "Increase damage.",
			Position = "DiagonalLeft",

			Passive = true,

			Branches = {
				{
					Name = "Thunder Heart II",
					PointsRequired = 2,
					Description = "Increase damage.",
					Position = "DiagonalRight",

					Passive = true,

					Branches = {
						{
							Name = "Thunder Heart III",
							PointsRequired = 3,
							Description = "Increase damage.",
							Position = "DiagonalLeft",

							Passive = true,

							Branches = {
								{
									Name = "Lightning Strike",
									PointsRequired = 3,
									Description = "Skill.",
									Position = "Left",
								},
								{
									Name = "Thunder Heart IV",
									PointsRequired = 2,
									Description = "Increase damage.",
									Position = "DiagonalRight",

									Passive = true,

									Branches = {
										{
											Name = "Thunder Heart V",
											PointsRequired = 2,
											Description = "Increase damage.",
											Position = "Forward",

											Passive = true,

											Branches = {},
										},
									},
								},
							},
						},

						{
							Name = "Thunder Wrath",
							PointsRequired = 2,
							Description = "Skill.",
							Position = "Right",
						},
					},
				},
			},
		},
	},
}
