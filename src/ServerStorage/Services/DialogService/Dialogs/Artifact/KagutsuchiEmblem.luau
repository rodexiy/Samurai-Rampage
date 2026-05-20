local Knit = require(game.ReplicatedStorage.Packages.Knit)

local InventoryService = Knit.GetService("InventoryService")
local RaceService = Knit.GetService("RaceService")
local AlertService = Knit.GetService("AlertService")
local ArtifactService = Knit.GetService("ArtifactService")
local DataService = Knit.GetService("DataService")

local KagutsuchiEmblem = {
	Normal = {
		[1] = {
			npcName = "Kagutsuchi Emblem",
			npcText = "Are you sure you want to use a Kagutsuchi Emblem? The artifact will dissapear, but you will get its powers.",
			answers = {
				[1] = {
					text = "Yes.",
					visual = "GreenOutline",

					callback = function(player)
						ArtifactService:UseArtifact(player, "KagutsuchiEmblem")
					end,
				},
				[2] = { text = "Cancel.", visual = "DeathStroke" },
			},
		},

		priority = 0,
	},
}

return KagutsuchiEmblem
