local Knit = require(game.ReplicatedStorage.Packages.Knit)

local InventoryService = Knit.GetService("InventoryService")
local RaceService = Knit.GetService("RaceService")
local AlertService = Knit.GetService("AlertService")

local RaceReroll = {
	Normal = {
		[1] = {
			npcName = "Race Reroll",
			npcText = "Are you sure you want to use a Race Reroll? This will reroll your race, you have the chance to get the same race.",
			answers = {
				[1] = {
					text = "Yes.",
					visual = "GreenOutline",

					callback = function(player)
						if InventoryService:GetPlayerItemByName(player, "RaceReroll") then
							InventoryService:RemoveItemFromPlayer(player, "RaceReroll", 1)

							local Race = RaceService:RollRandomRace(player)
							AlertService:AlertPlayer(player, "Your race has been changed to " .. Race .. ".", "Success")
						end
					end,
					validateAnswer = function(Player)
						return InventoryService:GetPlayerItemByName(Player, "RaceReroll")
					end,
				},
				[2] = { text = "Cancel.", visual = "DeathStroke" },
			},
		},

		priority = 0,
	},
}

return RaceReroll
