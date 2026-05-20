return {
	Class = "Stance",

	Name = "Drunk",
	WeaponType = "Katana",
	BaseDamage = 6,
	BaseStaminaCost = 4,

	M1 = {
		[1] = {
			HitboxType = "Raycast", 
			HitboxDelay = 0.5,
		},

		[2] = {
			HitboxType = "Raycast", 
			HitboxDelay = 0.47,
		},

		[3] = {
			HitboxType = "Raycast", 
			HitboxDelay = 0.4,
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
