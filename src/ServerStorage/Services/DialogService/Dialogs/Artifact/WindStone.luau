local Knit = require(game.ReplicatedStorage.Packages.Knit)

local ArtifactService = Knit.GetService("ArtifactService")

local WindStone = {
	Normal = {
		[1] = {
			npcName = "Wind Stone",
			npcText = "Are you sure you want to use a Wind Stone? The artifact will dissapear, but you will get its powers.",
			answers = {
				[1] = {
					text = "Yes.",
					visual = "GreenOutline",

					callback = function(player)
						ArtifactService:UseArtifact(player, "WindStone")
					end,
				},
				[2] = { text = "Cancel.", visual = "DeathStroke" },
			},
		},

		priority = 0,
	},
}

return WindStone
