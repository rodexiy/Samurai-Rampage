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
			HitboxDelay = 0.3,
		},

		[2] = {
			HitboxType = "Raycast", 
			HandHitbox = "Right", 
			HitboxDelay = 0.3,
		},

		[3] = {
			HitboxType = "Raycast", 
			HandHitbox = "Right", 
			HitboxDelay = 0.3,
		},
	},

	M2 = {
		Hits = {
			{	
				HitboxType = "Raycast", 
				HitboxDelay = 0.25, 
			},
		},
	},
}