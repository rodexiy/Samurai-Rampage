local Knit = require(game.ReplicatedStorage.Packages.Knit)

local Player = game.Players.LocalPlayer
local Character = Player.Character

local ArtifactService
local DeviceController = Knit.GetController("DeviceController")
local Validate = require(game.ReplicatedStorage.Shared.Validate)

local Camera = workspace.CurrentCamera

local DropArtifact = {
	callback = function(inputState, inputObject)
		if inputState ~= Enum.UserInputState.Begin then
			return
		end

		local Tool = Character:FindFirstChildWhichIsA("Tool")
		if Tool then
			ArtifactService:DropArtifact()
		end
	end,

	keys = { Enum.KeyCode.Backspace },
}

function DropArtifact.Start()
	ArtifactService = Knit.GetService("ArtifactService")
end

return DropArtifact
