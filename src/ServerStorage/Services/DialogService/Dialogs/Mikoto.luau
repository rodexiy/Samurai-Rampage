local Knit = require(game.ReplicatedStorage.Packages.Knit)

local QuestService = Knit.GetService("QuestService")
local TutorialService = Knit.GetService("TutorialService")

return {
	StartBasicTraining = {
		[1] = {
			npcName = "Mikoto",
			npcText = "Godot sent you from the village? A blade is only useful when its owner understands the basics.",
			answers = {
				[1] = {
					text = "Teach me, sword master.",
					nextDialog = 2,
					callback = function(Player)
						if TutorialService:CanStartMission(Player, "LearnTheBasics") then
							TutorialService:StartMission(Player, "LearnTheBasics")
						end
					end,
				},
			},
		},

		[2] = {
			npcName = "Mikoto",
			npcText = "We will train in the dojo. Strike when I guard, hold your ground when I strike, and move when the blade demands it.",
			answers = {
				[1] = {
					text = "I am ready.",
					callback = function(Player)
						QuestService:CallQuestFunction(Player, "StartTraining")
					end,
				},
			},
		},

		priority = 100,
		validation = function(Player)
			return TutorialService:CanStartMission(Player, "LearnTheBasics")
				or TutorialService:IsMissionStep(Player, "LearnTheBasics", "TalkWithMikoto")
		end,
	},

	PracticeBasicTraining = {
		[1] = {
			npcName = "Mikoto",
			npcText = "Follow the objective. I will change my rhythm as you learn each lesson.",
			answers = {
				[1] = { text = "I will keep practicing." },
			},
		},

		priority = 100,
		validation = function(Player)
			return TutorialService:IsMissionStep(Player, "LearnTheBasics", "PracticeBasics")
		end,
	},

	FinishBasicTraining = {
		[1] = {
			npcName = "Mikoto",
			npcText = "Good. Your movements are still rough, but the foundation is there. Practice until the blade feels like part of you.",
			answers = {
				[1] = {
					text = "Thank you, sword master.",
					callback = function(Player)
						QuestService:CallQuestFunction(Player, "CompleteQuest")
					end,
				},
			},
		},

		priority = 110,
		validation = function(Player)
			return TutorialService:IsMissionStep(Player, "LearnTheBasics", "ReturnToMikoto")
		end,
	},

	Normal = {
		[1] = {
			npcName = "Mikoto",
			npcText = "A disciplined sword is guided by a disciplined mind.",
			answers = {
				[1] = { text = "..." },
			},
		},

		priority = 0,
	},
}
