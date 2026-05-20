local Knit = require(game.ReplicatedStorage.Packages.Knit)
local DataService = Knit.GetService("DataService")
local InventoryService = Knit.GetService("InventoryService")
local ItemService = Knit.GetService("ItemService")
local TetsuService = Knit.GetService("TetsuService")
local AlertService = Knit.GetService("AlertService")

local PoliceChief = {

	NoCuffs = {
		[1] = {
			npcName = "Police Chief",
			text = "...",
			answers = {
				[1] = {
					text = "I want to bounty hunt!",

					callback = function(player)
						if not InventoryService:GetPlayerItemByName(player, "Handcuffs") then
							InventoryService:GiveItemToPlayer(player, ItemService:CreateItem("Handcuffs", 1))
						end
					end,
					nextDialog = 2,
				},

				[2] = { text = "..." },
			},
		},

		[2] = {
			npcName = "Police Chief",
			npcText = "Defeat players with bounty and handcuffs them. For every player you hunt, you will earn reputation. Remember that you still get bounty for killing players.",
			answers = {
				[1] = { text = "What do I do with Reputation?", nextDialog = 3 },
				[2] = { text = "..." },
			},
		},

		[3] = {
			npcName = "Police Chief",
			npcText = "You can trade reputation for items like the Police Armor and Katana.",
			answers = {
				[1] = { text = "..." },
			},
		},

		priority = 0,

		validation = function(Player)
			return not InventoryService:GetPlayerItemByName(Player, "Handcuffs")
		end,
	},

	Cuffs = {
		[1] = {
			npcName = "Police Chief",
			npcText = "...",
			answers = {
				[1] = { text = "I want to trade my reputation!", nextDialog = 2 },
				[2] = { text = "..." },
			},
		},

		[2] = {
			npcName = "Police Chief",
			customText = function(Player: Player)
				local PlayerData = DataService:GetData(Player)
				local Reputation = PlayerData.Reputation
				return "You have " .. Reputation .. " reputation."
			end,

			answers = {
				[1] = {
					text = "[25 REP.] POLICE HAT",
					callback = function(player)
						local PlayerData = DataService:GetData(player)

						if PlayerData.Reputation < 25 then
							return AlertService:AlertPlayer(
								player,
								"You don't have enough reputation to buy this!",
								"Error"
							)
						end

						PlayerData.Reputation -= 25
						InventoryService:GiveItemToPlayer(player, ItemService:CreateItem("PoliceHat", 1))
					end,
					validateAnswer = function(Player)
						return not InventoryService:GetPlayerItemByName(Player, "PoliceHat")
					end,
				},
				[2] = {
					text = "[50 REP.] POLICE PANTS",
					callback = function(Player)
						local PlayerData = DataService:GetData(Player)

						if PlayerData.Reputation < 50 then
							return AlertService:AlertPlayer(
								Player,
								"You don't have enough reputation to buy this!",
								"Error"
							)
						end

						PlayerData.Reputation -= 50
						InventoryService:GiveItemToPlayer(Player, ItemService:CreateItem("PolicePants", 1))
					end,
					validateAnswer = function(Player)
						return not InventoryService:GetPlayerItemByName(Player, "PolicePants")
					end,
				},

				[3] = {
					text = "[75 REP.] POLICE SHIRT",
					callback = function(Player)
						local PlayerData = DataService:GetData(Player)

						if PlayerData.Reputation < 75 then
							return AlertService:AlertPlayer(
								Player,
								"You don't have enough reputation to buy this!",
								"Error"
							)
						end

						PlayerData.Reputation -= 75
						InventoryService:GiveItemToPlayer(Player, ItemService:CreateItem("PoliceShirt", 1))
					end,
					validateAnswer = function(Player)
						return not InventoryService:GetPlayerItemByName(Player, "PoliceShirt")
					end,
				},
				[4] = {
					text = "[100 REP.] POLICE KATANA",
					callback = function(Player)
						local PlayerData = DataService:GetData(Player)

						if PlayerData.Reputation < 100 then
							return AlertService:AlertPlayer(
								Player,
								"You don't have enough reputation to buy this!",
								"Error"
							)
						end

						PlayerData.Reputation -= 100
						InventoryService:GiveItemToPlayer(Player, ItemService:CreateItem("MizuKatana", 1))
					end,
					validateAnswer = function(Player)
						return not InventoryService:GetPlayerItemByName(Player, "MizuKatana")
					end,
				},
				[5] = { text = "..." },
			},
		},

		validation = function(Player)
			return InventoryService:GetPlayerItemByName(Player, "Handcuffs")
		end,

		priority = 1,
	},
}

return PoliceChief
