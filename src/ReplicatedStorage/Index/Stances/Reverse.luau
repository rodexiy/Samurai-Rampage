return {
	Class = "Stance",

	Name = "Reverse",
	WeaponType = "Katana",
	BaseDamage = 15,
	BaseStaminaCost = 7,

	M1 = {
		[1] = {
			HitboxType = "Raycast", 
			HitboxDelay = 0.37,
		},

		[2] = {
			HitboxType = "Raycast", 
			HitboxDelay = 0.45,
		},

		[3] = {
			HitboxType = "Raycast", 
			HitboxDelay = 0.48,
		},

		[4] = {
			HitboxType = "Raycast", 
			HitboxDelay = 0.45,
		},
		[5] = {
			HitboxType = "Raycast", 
			HitboxDelay = 0.47,
		},
	},

	M2 = {
		Hits = {
			{	
				HitboxType = "Raycast", 
				HitboxDelay = 0.56, 
			},
		},
	},
}
