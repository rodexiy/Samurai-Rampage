return {
	Name = "Raijin",
	Color = Color3.fromRGB(206, 172, 0),
	Description = "Sons of the lightning and the heavens.",

	Branches = {
		{
			Name = "Heavens Recall",
			PointsRequired = 1,
			Description = "Teleport to the heavens.",
			Position = "DiagonalLeft",
		},

		{
			Name = "Lightning Dash",
			PointsRequired = 1,
			Description = "Replaces your normal dash with a lightning.",
			Position = "DiagonalRight",
			Passive = true,
		},
	},
}
