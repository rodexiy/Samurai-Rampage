return {
	Class = "Stance",

	Name = "Reverse",
	WeaponType = "Katana",
	BaseDamage = 15,
	BaseStaminaCost = 7,

	M1 = {
		[1] = {
			HitboxType = "Raycast", 
		},

		[2] = {
			HitboxType = "Raycast", 
		},

		[3] = {
			HitboxType = "Raycast", 
		},

		[4] = {
			HitboxType = "Raycast", 
		},
		[5] = {
			HitboxType = "Raycast", 
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