return {
	Class = "Stance",

	Name = "Undead",
	WeaponType = "Fists",
	BaseDamage = 10,
	BaseStaminaCost = 5,

	M1 = {
		[1] = {
			HitboxType = "Raycast",
			HandHitbox = "Left", 
			HitboxDelay = 0.1,
		},

		[2] = {
			HitboxType = "Raycast", 
			HandHitbox = "Right", 
			HitboxDelay = 0.1,
		},

		[3] = {
			HitboxType = "Raycast", 
			HandHitbox = "Right", 
			HitboxDelay = 0.1,
		},
	},

	M2 = {
		Hits = {
			{	
				HitboxType = "Raycast", 
				HitboxDelay = 0.15, 
			},
		},
	},
}