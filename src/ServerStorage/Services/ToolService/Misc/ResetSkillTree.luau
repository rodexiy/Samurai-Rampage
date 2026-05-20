local ResetSkillTree = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)

local DialogService = Knit.GetService("DialogService")

local Players = game:GetService("Players")

function ResetSkillTree.Activated(Character: Model, Data: { any })
	local Player = Players:GetPlayerFromCharacter(Character)

	if not Player then
		return
	end

	DialogService:StartDialog(Player, "ResetSkillTree")
end

return ResetSkillTree
