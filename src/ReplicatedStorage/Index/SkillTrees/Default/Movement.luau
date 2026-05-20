return {
	Name = "Movement",
	Color = Color3.fromRGB(103, 149, 255),
	Description = "Upgrade your stamina and movement techniques.",

	Branches = {
		{
			Name = "Climb",
			PointsRequired = 1,
			Description = "Climb walls pressing G.",
			Position = "DiagonalLeft",
			Passive = true,

			Branches = {
				{
					Name = "Climb Speed",
					PointsRequired = 2,
					Description = "Increase your climb speed.",
					Position = "Forward",
					Passive = true,
				},

				{
					Name = "No Climb Stamina Drain",
					PointsRequired = 2,
					Description = "You no longer lose stamina when climbing, except when in combat.",
					Position = "DiagonalLeft",
					Passive = true,
				},
			},
		},

		{
			Name = "Max Stamina I",
			PointsRequired = 1,
			Description = "Increase your max stamina.",
			Position = "Forward",
			Passive = true,

			Branches = {
				{
					Name = "Max Stamina II",
					PointsRequired = 2,
					Description = "Increase your max stamina.",
					Position = "Forward",
					Passive = true,

					Branches = {
						{
							Name = "Max Stamina III",
							PointsRequired = 3,
							Description = "Increase your max stamina.",
							Position = "Forward",
							Passive = true,

							Branches = {
								{
									Name = "Max Stamina IV",
									PointsRequired = 4,
									Description = "Increase your max stamina.",
									Position = "Forward",
									Passive = true,

									Branches = {
										{
											Name = "Max Stamina V",
											PointsRequired = 5,
											Description = "Increase your max stamina.",
											Position = "Forward",
											Passive = true,
										},
									},
								},

								{
									Name = "Deflect Stamina Recovery",
									PointsRequired = 3,
									Description = "Recover a bit more stamina by deflecting attacks.",
									Position = "DiagonalRight",
									Passive = true,

									Branches = {
										{
											Name = "Deflect Stamina Recovery II",
											PointsRequired = 4,
											Description = "Recover even more stamina by deflecting attacks.",
											Position = "Forward",
											Passive = true,
										},
									},
								},
							},
						},

						{
							Name = "No Run Stamina Drain",
							PointsRequired = 2,
							Description = "You no longer lose stamina when running, except when in combat.",
							Position = "Right",
							Passive = true,
						},
					},
				},
			},
		},
	},
}
