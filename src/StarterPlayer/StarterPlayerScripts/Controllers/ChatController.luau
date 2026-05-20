local Knit = require(game.ReplicatedStorage.Packages.Knit)

local ChatController = Knit.CreateController({
	Name = "ChatController",
})

local TextChatService = game:GetService("TextChatService")

local FlagService
local PlaceController

function ChatController:Bind()
	if not PlaceController:IsArena() and not not PlaceController:IsHub() then
		local FlagImage: TextChatCommand = TextChatService:WaitForChild("FlagImage")
		local FlagColor: TextChatCommand = TextChatService:WaitForChild("FlagColor")

		FlagImage.Triggered:Connect(function(originTextSource, unfilteredText)
			local splitted = unfilteredText:split(" ")

			FlagService:ChangeFlagImage(splitted[2])
		end)

		FlagColor.Triggered:Connect(function(originTextSource, unfilteredText)
			local splitted = unfilteredText:split(" ")
			FlagService:ChangeFlagColor(splitted[2])
		end)
	end
end

function ChatController.KnitInit()
	FlagService = Knit.GetService("FlagService")
	PlaceController = Knit.GetController("PlaceController")
end

function ChatController.KnitStart()
	ChatController:Bind()
end

return ChatController
