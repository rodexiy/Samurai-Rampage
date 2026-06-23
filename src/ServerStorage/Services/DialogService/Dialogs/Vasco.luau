local Knit = require(game.ReplicatedStorage.Packages.Knit)

local QuestService = Knit.GetService("QuestService")
local TutorialService = Knit.GetService("TutorialService")

return {
	TalkWithBlacksmith = {
		[1] = {
			npcName = "Vasco",
			npcText = "Who is you?, I never saw you before.",
			answers = {
				[1] = {
					text = "",
					customText = function(Player)
						return "My name is "
							.. Player.Name
							.. ", My boat sank and Godot helped me, im here to get some wood for him. He said you can give me an axe."
					end,
					nextDialog = 2,
				},
			},
		},

		[2] = {
			npcName = "Vasco",
			npcText = "He is a chill guy, here, take this axe. Also I can buy some wood of you, but dont expect too much money.",
			answers = {
				[1] = {
					text = "Thank you.",
					callback = function(Player)
						QuestService:CallQuestFunction(Player, "StartWoodcutting")
					end,
				},
			},
		},

		priority = 100,
		validation = function(Player)
			return TutorialService:IsMissionStep(Player, "TalkWithBlacksmith", "TalkWithLumberjack")
		end,
	},
}
