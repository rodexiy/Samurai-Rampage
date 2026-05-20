local Knit = require(game.ReplicatedStorage.Packages.Knit)

local InventoryService = Knit.GetService("InventoryService")
local AlertService = Knit.GetService("AlertService")
local DataService = Knit.GetService("DataService")
local TetsuService = Knit.GetService("TetsuService")
local StanceService = Knit.GetService("StanceService")

local Ashina = {
	Normal = {
		[1] = {
			npcName = "Ashina",
			npcText = "If you defeat him, maybe you can learn his stance...",
			answers = {
		
				[1] = { text = "..." },
			},
		},

		priority = 0,
	},
	

}

return Ashina
