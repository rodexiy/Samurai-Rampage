local Knit = require(game.ReplicatedStorage.Packages.Knit)

local DataService = Knit.GetService("DataService")
local QuestService = Knit.GetService("QuestService")
local InventoryService = Knit.GetService("InventoryService")
local ItemService = Knit.GetService("ItemService")

local Sakamoto = {
	Normal = {
		[1] = {
			npcName = "Sakamoto",
			npcText = "Hello, do you need something?",
			answers = {
				[1] = {
					text = "Im here to deliver this box",
					validateAnswer = function(Player)
						local PlayerData = DataService:GetData(Player)
						if PlayerData.Quest.Name == "DeliverBox" and not PlayerData.Quest.TalkedWithSakamoto then
							return true
						end
					end,

					callback = function(Player)
						local PlayerData = DataService:GetData(Player)
						PlayerData.Quest.TalkedWithSakamoto = true
						QuestService:CallQuestFunction(Player, "TalkedWithSakamoto", true)
					end,

					nextDialog = 2,
				},

				[2] = {
					text = "Can i keep the box?",
					nextDialog = 3,
					validateAnswer = function(Player)
						local PlayerData = DataService:GetData(Player)
						if
							PlayerData.NPCs.DeliveredBoxToSakamoto
							and not InventoryService:GetPlayerItemByName(Player, "WoodenBox")
						then
							return true
						end
					end,

					callback = function(Player)
						InventoryService:GiveItemToPlayer(Player, ItemService:CreateItem("WoodenBox", 1))
					end,
				},

				[3] = { text = "..." },
			},
		},

		[2] = {
			npcName = "Sakamoto",
			npcText = "Thank you.",
			answers = {
				[1] = { text = "..." },
			},
		},

		[3] = {
			npcName = "Sakamoto",
			npcText = "Sure, i don't have any use for it anyway.",
			answers = {
				[1] = { text = "..." },
			},
		},
	},
}

return Sakamoto
