return {
	Name = "Resistance",
	Color = Color3.fromRGB(123, 143, 71),
	Description = "Increase health and posture.",

	Branches = {
		{
			Name = "Resistance I",
			PointsRequired = 1,
			Description = "Increase health and posture.",
			Position = "Forward",
			Passive = true,

			Branches = {
				{
					Name = "Resistance II",
					PointsRequired = 2,
					Description = "Increase health and posture.",
					Position = "Forward",
					Passive = true,

					Branches = {
						{
							Name = "Resistance III",
							PointsRequired = 3,
							Description = "Increase health and posture.",
							Position = "Forward",
							Passive = true,

							Branches = {
								{
									Name = "Resistance IV",
									PointsRequired = 4,
									Description = "Increase health and posture.",
									Position = "Forward",
									Passive = true,

									Branches = {
										{
											Name = "Debuff Resistance",
											PointsRequired = 5,
											Description = "Health debuffs don't hurt you.",
											Position = "Left",
											Passive = true,
										},

										{
											Name = "Resistance V",
											PointsRequired = 5,
											Description = "Increase health and posture.",
											Position = "Forward",
											Passive = true,
										},
									},
								},
							},
						},

						{
							Name = "No Fall Damage",
							PointsRequired = 2,
							Description = "You no longer take fall damage.",
							Position = "Right",
							Passive = true,
						},
					},
				},

				{
					Name = "Health Recovery",
					PointsRequired = 2,
					Description = "Small health recovery when executing an entity.",
					Position = "Right",
					Passive = true,
				},
			},
		},

		{
			Name = "Regeneration I",
			PointsRequired = 1,
			Description = "Increase health and posture regeneration.",
			Position = "Left",
			Passive = true,

			Branches = {
				{
					Name = "Regeneration II",
					PointsRequired = 2,
					Description = "Increase health and posture regeneration.",
					Position = "Forward",
					Passive = true,
				},
			},
		},
	},
}
