local Knit = require(game.ReplicatedStorage.Packages.Knit)

local TetsuService = Knit.GetService("TetsuService")
local ItemService = Knit.GetService("ItemService")
local InventoryService = Knit.GetService("InventoryService")

local Price = 700
local SamuraiLegplate = {
	Normal = {
		[1] = {
			npcName = "Samurai Legplate",
			npcText = 'You want to purshase Samurai Legplate for <font color="rgb(82,255,0)">700</font> Tetsu?',
			answers = {
				[1] = {
					text = "Yes",
					callback = function(player)
						TetsuService:RemoveTetsu(player, Price)
						local Item = ItemService:CreateItem("SamuraiLegplate", 1)
						InventoryService:GiveItemToPlayer(player, Item)
					end,
					validateAnswer = function(Player)
						return TetsuService:HaveTetsu(Player, Price)
					end,
				},
				[2] = { text = "..." },
			},
		},

		priority = 0,
	},

	AlreadyHave = {
		[1] = {
			npcName = "Samurai Legplate",
			npcText = "You already have this item.",
			answers = {
				[1] = { text = "..." },
			},
		},

		priority = 1,

		validation = function(player)
			return InventoryService:GetPlayerItemByName(player, "SamuraiLegplate")
		end,
	},
}

return SamuraiLegplate
