local Knit = require(game.ReplicatedStorage.Packages.Knit)

local InventoryService = Knit.GetService("InventoryService")
local RaceService = Knit.GetService("RaceService")
local AlertService = Knit.GetService("AlertService")
local ArtifactService = Knit.GetService("ArtifactService")
local DataService = Knit.GetService("DataService")

local ArtifactRemover = {
	Normal = {
		[1] = {
			npcName = "Artifact Remover",
			npcText = "Are you sure you want to use an Artifact Remover? This will remove your artifact, you don't receive it back.",
			answers = {
				[1] = {
					text = "Yes.",
					visual = "GreenOutline",

					callback = function(player)
						if InventoryService:GetPlayerItemByName(player, "ArtifactRemover") then
							local PlayerData = DataService:GetData(player)
							if PlayerData.Artifact == nil then
								AlertService:AlertPlayer(player, "You don't have an artifact.", "Error")
								return
							end
							InventoryService:RemoveItemFromPlayer(player, "ArtifactRemover", 1)
							ArtifactService:ResetArtifact(player)
							AlertService:AlertPlayer(player, "Your artifact has been removed.", "Success")
						end
					end,
					validateAnswer = function(Player)
						return InventoryService:GetPlayerItemByName(Player, "ArtifactRemover")
					end,
				},
				[2] = { text = "Cancel.", visual = "DeathStroke" },
			},
		},

		priority = 0,
	},
}

return ArtifactRemover
