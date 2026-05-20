return {
	Name = "Kendo",
	Color = Color3.fromRGB(231, 231, 231),
	Description = "Unlock skills and improve your damage.",

	Branches = {
		{
			Name = "Kendo Proficiency I",
			PointsRequired = 1,
			Description = "Increase your weapon damage.",
			Position = "Forward",
			Passive = true,

			Branches = {
				{
					Name = "Up Slash",
					PointsRequired = 1,
					Description = "An diagonal slash.",
					Position = "Left",

					Branches = {
						{
							Name = "Up Slash Block Break",
							PointsRequired = 2,
							Description = "Up Slash now breaks blocks.",
							Position = "Forward",
							Passive = true,
						},
					},
				},

				{
					Name = "Kendo Proficiency II",
					PointsRequired = 2,
					Description = "Increase your weapon damage.",
					Position = "Forward",
					Passive = true,

					Branches = {
						{
							Name = "Barrage",
							PointsRequired = 2,
							Description = "A barrage of slashes.",
							Position = "Right",

							Branches = {
								{
									Name = "Longer Barrage",
									PointsRequired = 3,
									Description = "Increase the number of slashes.",
									Position = "Right",
									Passive = true,
								},
							},
						},

						{
							Name = "Energy Conservation",
							PointsRequired = 3,
							Description = "Kendo now consumes 30% less stamina.",
							Position = "DiagonalLeft",
							Passive = true,
						},

						{
							Name = "Kendo Proficiency III",
							PointsRequired = 3,
							Description = "Increase your weapon damage.",
							Position = "Forward",
							Passive = true,

							Branches = {

								{
									Name = "Heavy Deflect",
									PointsRequired = 2,
									Description = "Some attacks cause a heavy deflect.",
									Position = "Right",
									Passive = true,
								},

								{
									Name = "Kendo Proficiency IV",
									PointsRequired = 4,
									Description = "Increase your weapon damage.",
									Position = "Forward",
									Passive = true,

									Branches = {
										{
											Name = "Kendo Proficiency V",
											PointsRequired = 5,
											Description = "Increase your weapon damage.",
											Position = "Forward",
											Passive = true,

											Branches = {
												{
													Name = "Floating Passage",
													PointsRequired = 4,
													Description = "The pinnacle of Kendo techniques.",
													Position = "Forward",
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
		},
	},
}
