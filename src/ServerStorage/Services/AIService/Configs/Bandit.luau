return {
	Lifes = {
		["1"] = {
			Health = 100,
			AttackDistance = 6,
			TargetOffset = 3,
			RunDistance = 10,

			MaintainDistance = 65,
			DetectionDistanceFromSpawn = 45,
			MaxDistanceFromSpawn = 100,

			ActionDistance = 11,
			ActionChance = 55,
			DeflectChance = 70,
			RollChance = 30,

			RunSpeed = 15,

			Actions = {
				"Roll",
				"Run",
			},
		},
	},

	Equipment = {
		Weapon = { "BasicKatana", "Origin" },
		Head = { "None", "None", "RoninKasa" },
		Torso = { "SamuraiChestplate", "BeigeKimono", "DarkKimono", "VillagerShirt" },
		Legs = { "SamuraiLegplate", "VillagerPants", "NoblePants" },
	},

	Stance = "Drunk",
}
