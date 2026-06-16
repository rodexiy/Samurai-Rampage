return {
	Class = "Stance",
	Name = "TwoHeavens",
    DisplayName = "Two Heavens",
	WeaponType = "Katana",
	DualWield = true,
	BaseDamage = 15,
	BaseStaminaCost = 8,

	M1 = {
		[1] = {
			HitboxType = "Raycast", 
            HandHitbox = "Right", 
            HitboxDelay = 0.28,
		},

		[2] = {
			HitboxType = "Raycast", 
            HandHitbox = "Right", 
            HitboxDelay = 0.27,
            
            
		},

		[3] = {
			HitboxType = "Raycast", 
            HandHitbox = "Left", 
            HitboxDelay = 0.24,
            
		},

		[4] = {
			HitboxType = "Raycast", 
            HandHitbox = "Left", 
            HitboxDelay = 0.26,
            
		},
		[5] = {
			HitboxType = "Raycast", 
            HandHitbox = "Right", 
            HitboxDelay = 0.3,
            
		},
	},

	M2 = {
		Hits = {
			{	
				HitboxType = "Raycast", 
				WeaponSide = "Both",
				HitboxDelay = 0.5, 
			},
		},
	},
}
