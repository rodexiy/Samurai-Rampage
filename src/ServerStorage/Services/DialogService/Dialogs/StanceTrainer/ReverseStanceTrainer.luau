local Knit = require(game.ReplicatedStorage.Packages.Knit)

local InventoryService = Knit.GetService("InventoryService")
local AlertService = Knit.GetService("AlertService")
local DataService = Knit.GetService("DataService")
local TetsuService = Knit.GetService("TetsuService")
local StanceService = Knit.GetService("StanceService")

local ReverseStanceTrainer = {
	Normal = {
		[1] = {
			npcName = "Reverse Stance Trainer",
			npcText = "If you want to learn the Reverse Stance, give me 10k Tetsu.",
			answers = {
				[1] = {
					text = "Learn [10k Tetsu].",
					visual = "GreenOutline",

					callback = function(player)
						if TetsuService:RemoveTetsu(player, 10000) then
							StanceService:GiveStance(player, "Reverse")
						end
					end,
					validateAnswer = function(Player)
						return TetsuService:HaveTetsu(Player, 10000)
					end,
				},
				[2] = { text = "Cancel.", visual = "DeathStroke" },
			},
		},

		priority = 0,
	},
	
	Learned = {
		[1] = {
			npcName = "Reverse Stance Trainer",
			npcText = "You already learned the Reverse Stance.",
			answers = {
				[1] = { text = "..." },
			},
		},

		priority = 1,
		
		validation = function(Player)
			return StanceService:HaveStance(Player, "Reverse")
		end,
	},
}

return ReverseStanceTrainer
