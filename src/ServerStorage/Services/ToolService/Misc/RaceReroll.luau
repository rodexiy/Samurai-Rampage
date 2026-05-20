local RaceReroll = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)

local DialogService = Knit.GetService("DialogService")

local Players = game:GetService("Players")

function RaceReroll.Activated(Character: Model, Data: { any })
	local Player = Players:GetPlayerFromCharacter(Character)

	if not Player then
		return
	end

	DialogService:StartDialog(Player, "RaceReroll")
end

return RaceReroll
