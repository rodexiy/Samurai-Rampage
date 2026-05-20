return {
	Lifes = {
		["2"] = {
			Health = 150,
			AttackDistance = 6,
			TargetOffset = 3,

			RunDistance = 10,

			MaintainDistance = 50, -- distancia entre o jogador que passa a ignoralo e para
			DetectionDistanceFromSpawn = 35, -- raio de detecção do spawn, se entrar ele vai atras, fora disso só detecta com hit e vai até o MaxDistanceFromSpawn
			MaxDistanceFromSpawn = 100, -- volta andando (*2 da top)

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

			MaintainDistance = 50, -- distancia entre o jogador que passa a ignoralo e para
			DetectionDistanceFromSpawn = 35, -- raio de detecção do spawn, se entrar ele vai atras, fora disso só detecta com hit e vai até o MaxDistanceFromSpawn
			MaxDistanceFromSpawn = 100, -- volta andando (*2 da top)

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
