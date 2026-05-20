local Knit = require(game.ReplicatedStorage.Packages.Knit)

local TetsuService = Knit.GetService("TetsuService")
local ItemService = Knit.GetService("ItemService")
local InventoryService = Knit.GetService("InventoryService")
local SkillTreeService = Knit.GetService("SkillTreeService")
local AlertService = Knit.GetService("AlertService")

local ResetSkillTree = {
	Normal = {
		[1] = {
			npcName = "Reset Skill Tree",
			npcText = "Are you sure you want to use a Reset Skill Tree?",
			answers = {
				[1] = {
					text = "Yes.",
					visual = "GreenOutline",

					callback = function(player)
						if InventoryService:GetPlayerItemByName(player, "ResetSkillTree") then
							InventoryService:RemoveItemFromPlayer(player, "ResetSkillTree", 1)
							SkillTreeService:ResetSkillTree(player)
							AlertService:AlertPlayer(player, "Successfully reseted your skill tree.", "Success")
						end
					end,
					validateAnswer = function(Player)
						return InventoryService:GetPlayerItemByName(Player, "ResetSkillTree")
					end,
				},
				[2] = { text = "Cancel.", visual = "DeathStroke" },
			},
		},

		priority = 0,
	},
}

return ResetSkillTree
