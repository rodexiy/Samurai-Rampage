local Knit = require(game.ReplicatedStorage.Packages.Knit)
local QuestService = Knit.GetService("QuestService")
local DataService = Knit.GetService("DataService")

local Jimbe = {
	Normal = {
		[1] = {
			npcName = "Jimbe",
			npcText = "Hey, I have to bring this crate to the market. Can you help me? I will pay you a fair amount.",
			answers = {
				[1] = {
					text = "Yeah, I can do that.",
					actionType = "accept",

					callback = function(player)
						QuestService:GiveQuest(player, "DeliverBox")
					end,
				},

				[2] = { text = "..." },
			},
		},

		priority = 0,
	},

	CompletedQuest = {
		[1] = {
			npcName = "Jimbe",
			npcText = "Thank you for your help.",
			answers = {
				[1] = { text = "..." },
			},
		},

		validation = function(Player)
			local PlayerData = DataService:GetData(Player)
			if PlayerData.NPCs.DeliveredBoxToSakamoto then
				return true
			end
		end,
		priority = 1,
	},

	WithQuest = {
		[1] = {
			npcName = "Jimbe",
			npcText = "Please, go fast.",
			answers = {
				[1] = {
					text = "...",
				},
			},
		},

		validation = function(Player)
			local PlayerData = DataService:GetData(Player)
			if PlayerData.Quest.Name == "DeliverBox" then
				return true
			end
		end,

		priority = 1,
	},

	Delivered = {
		[1] = {
			npcName = "Jimbe",
			npcText = "Thank you for your help, here is your reward.",
			answers = {
				[1] = {
					text = "...",
					callback = function(player)
						QuestService:CallQuestFunction(player, "Completed")
					end,
				},
			},
		},

		validation = function(Player)
			local PlayerData = DataService:GetData(Player)
			if PlayerData.Quest.Name == "DeliverBox" and PlayerData.Quest.TalkedWithSakamoto then
				return true
			end
		end,
		priority = 2,
	},
}

return Jimbe
