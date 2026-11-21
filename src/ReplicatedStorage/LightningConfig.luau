local LightningConfig = {
	Storm = {
		MinimumInterval = 14,
		MaximumInterval = 24,
		MinimumRadius = 700,
		MaximumRadius = 1100,
	},

	Bolt = {
		Color = Color3.new(1, 1, 1),
		MinimumHeight = 450,
		MaximumHeight = 650,
		CloudOffset = 65,
		Segments = 40,
		Thickness = 2.5,
		JitterRadius = 18,
		Lifetime = 0.05,
		BranchCount = 2,
		BranchSegments = 12,
		BranchLength = 110,
	},

	Flash = {
		CloudColor = Color3.new(1, 1, 1),
		Brightness = 0.22,
		HoldTime = 0.045,
		FadeTime = 0.3,
	},

	Thunder = {
		SoundIds = {
			"rbxassetid://139319051979882",
			"rbxassetid://102164464566453",
			"rbxassetid://114778516343256",
			"rbxassetid://111792757907186",
			"rbxassetid://112601622500056",
		},
		-- Standard Roblox scale and the speed of sound in air at roughly 20 degrees C.
		MetersPerStud = 0.28,
		SpeedOfSound = 343,
		MaximumVolume = 1.4,
		ReferenceDistance = 150,
		MaximumDistance = 5000,
		MaximumLifetime = 45,
	},
}

return LightningConfig
