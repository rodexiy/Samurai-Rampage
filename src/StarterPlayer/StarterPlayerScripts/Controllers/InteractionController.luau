local Knit = require(game.ReplicatedStorage.Packages.Knit)

--[[
    Recebe inputs de proximity prompts e executa seus callbacks
]]

local InteractionController = Knit.CreateController({
	Name = "InteractionController",
	Client = {},
})

local MissionBoardController
local InteractionService


local ProximityPromptService = game:GetService("ProximityPromptService")

local callbacks = {
	OpenCityBoard = function(Player: Player, Prompt: ProximityPrompt)
		MissionBoardController:OpenBoard(Player)
	end,

	Cuff = function(Player: Player, Prompt: ProximityPrompt)
	end,
}

function InteractionController.ButtonTriggered(ProximityPrompt: ProximityPrompt, Player: Player)
	local Character = Player.Character

	local callback = ProximityPrompt:GetAttribute("callback")
	if callback and callbacks[callback] then
		callbacks[callback](Player, ProximityPrompt)
	end
end

function InteractionController:EnablePrompt(ProximityPrompt: ProximityPrompt, state: boolean)
	local state = state or false
	if ProximityPrompt then
		ProximityPrompt.Enabled = state
	end
end

function InteractionController.KnitInit()
	MissionBoardController = Knit.GetController("MissionBoardController")
	InteractionService = Knit.GetService("InteractionService")

end

function InteractionController.KnitStart()
	ProximityPromptService.PromptTriggered:Connect(InteractionController.ButtonTriggered)
	InteractionService.EnablePrompt:Connect(function(...)
		InteractionController:EnablePrompt(...)
	end)
end

return InteractionController
