local Knit = require(game.ReplicatedStorage.Packages.Knit)

local TetsuService = Knit.GetService("TetsuService")
local ItemService = Knit.GetService("ItemService")
local InventoryService = Knit.GetService("InventoryService")
local QuestService = Knit.GetService("QuestService")
local TutorialService = Knit.GetService("TutorialService")

local ores = {
	["Coal"] = 5,
	["IronOre"] = 10,
	["GoldOre"] = 25,
}

local function GetOres(Player: Player)
	local Character = Player.Character
	if not Character then
		return
	end

	local Item = Character:FindFirstChildWhichIsA("Tool")
	if not Item then
		return
	end
	if ores[Item.Name] == nil then
		return
	end

	return ores[Item.Name] * Item:GetAttribute("Stack"), Item
end

local Godot = {
	TalkWithBlacksmith = {
		[1] = {
			npcName = "Godot",
			npcText = "Its a miracle you are alive! That storm was massive. I see you lost almost everything you had, at least you still have clothes haha.",
			answers = {
				[1] = {
					text = "I do not know what to do now.",
					actionType = "quest",
					nextDialog = 2,
					callback = function(Player)
						if TutorialService:CanStartMission(Player, "TalkWithBlacksmith") then
							TutorialService:StartMission(Player, "TalkWithBlacksmith")
						end
					end,
				},
			},
		},

		[2] = {
			npcName = "Godot",
			npcText = "Well, I can help you forge a sword, but you will need to get the resources.",
			answers = {
				[1] = {
					text = "What i need to get?",
					nextDialog = 3,
				},
			},
		},

		[3] = {
			npcName = "Godot",
			npcText = "Here, take this pickaxe. follow the path behind the blacksmith and get 10 iron and 10 coal, also talk with the lumberjack after getting the items, you will need to get 5 wood logs too.",
			answers = {
				[1] = {
					text = "All right.",
					actionType = "quest",
					callback = function(Player)
						QuestService:CallQuestFunction(Player, "StartMining")
					end,
				},
			},
		},

		priority = 100,
		validation = function(Player)
			return TutorialService:IsMissionStep(Player, "TalkWithBlacksmith", "TalkWithBlacksmith")
				or TutorialService:CanStartMission(Player, "TalkWithBlacksmith")
		end,
	},

	TalkWithBlacksmithReturn = {
		[1] = {
			npcName = "Godot",
			npcText = "Now that we have the resources, go to the forge and craft your Katana!",
			answers = {
				[1] = {
					text = "...",
					actionType = "quest",
					callback = function(Player)
						QuestService:CallQuestFunction(Player, "StartCraftKatana")
					end,
				},
			},
		},

		priority = 100,
		validation = function(Player)
			return TutorialService:IsMissionStep(Player, "TalkWithBlacksmith", "ReturnToGodot")
		end,
	},

	TalkWithBlacksmithKatanaCrafted = {
		[1] = {
			npcName = "Godot",
			npcText = "Good. Now you have a blade of your own. Take it to the old dojo and find Mikoto. The sword master will teach you the basics.",
			answers = {
				[1] = {
					text = "...",
					actionType = "quest",
					callback = function(Player)
						QuestService:CallQuestFunction(Player, "CompleteQuest")
					end,
				},
			},
		},

		priority = 100,
		validation = function(Player)
			return TutorialService:IsMissionStep(Player, "TalkWithBlacksmith", "TalkWithGodotAfterKatana")
		end,
	},

	Normal = {
		[1] = {
			npcName = "Godot",
			npcText = "Hello, how can i help you?",
			answers = {
				[1] = {
					text = "I want to sell some ores..",
					nextDialog = 2,
					validateAnswer = function(Player)
						return GetOres(Player) ~= nil
					end,
				},
				[2] = { text = "..." },
			},
		},

		[2] = {
			npcName = "Godot",
			npcText = "",
			customText = function(Player: Player)
				local Total = GetOres(Player)
				return "I can buy what you have for " .. (Total or 0) .. " Tetsu"
			end,
			answers = {
				[1] = {
					text = "ok",
					callback = function(player)
						local Total, Item = GetOres(player)
						if not Total or not Item then
							return
						end

						InventoryService:RemoveItemFromPlayer(player, Item.Name, Item:GetAttribute("Stack"))
						TetsuService:AddTetsu(player, Total)
					end,
				},
				[2] = { text = "..." },
			},
		},

		priority = 0,
	},
}

return Godot
