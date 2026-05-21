return {
	Class = "Stance",

	Name = "OneArm",
	DisplayName = "One Arm",
	WeaponType = "Katana",
	BaseDamage = 20,
	BaseStaminaCost = 13,
	LeftArmRagdoll = true,

	M1 = {
		[5] = {
			HitboxType = "Box",
			HitboxSize = Vector3.new(5, 5, 7),
			PlaySwingSound = false,
			EnableSwordTrail = false,
		},
	},

	M2 = {
		Hits = {
			{ Delay = 0.3, Duration = 0.25 },
			{ Delay = 0.7, Duration = 0.25 },
		},
	},
}
