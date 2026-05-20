local Artifact = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)
local ArtifactService = Knit.GetService("ArtifactService")

function Artifact.Activated(Character: Model)
	local Player = game.Players:GetPlayerFromCharacter(Character)
	local Tool = Character:FindFirstChildWhichIsA("Tool")

	if Player and Tool then
		ArtifactService:PromptArtifact(Player, Tool)
	end
end

return Artifact
