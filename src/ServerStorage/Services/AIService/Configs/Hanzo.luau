return {
	Lifes = {
		["2"] = {
			Health = 150,
			AttackDistance = 6,
			TargetOffset = 3,

			RunDistance = 10,

			MaintainDistance = 95, -- distance where the boss drops the target
			DetectionDistanceFromSpawn = 70, -- spawn detection radius; hit aggro can chase up to MaxDistanceFromSpawn
			MaxDistanceFromSpawn = 140, -- starts returning after this distance from spawn

			ActionDistance = 11,
			ActionChance = 70,
			DeflectChance = 65,
			RollChance = 20,

			RunSpeed = 18,

			SkillChance = 100,

			Skills = {
				"FloatingPassage",
			},
			Actions = {
				"Roll",
				"Run",
			},
		},

		["1"] = {
			Health = 150,
			AttackDistance = 6,
			TargetOffset = 3,
			RunDistance = 10,

			ActionDistance = 11,
			ActionChance = 85,
			DeflectChance = 70,
			RollChance = 20,

			MaintainDistance = 95, -- distance where the boss drops the target
			DetectionDistanceFromSpawn = 70, -- spawn detection radius; hit aggro can chase up to MaxDistanceFromSpawn
			MaxDistanceFromSpawn = 140, -- starts returning after this distance from spawn

			RunSpeed = 18,

			SkillChance = 70,

			Actions = {
				"Roll",
				"Run",
			},

			Skills = {
				"FloatingPassage",
				"UpSlash",
				"Barrage",
				"Barrage",
			},
		},
	},

	Equipment = {
		Weapon = { "Blossom" },
	},
}
