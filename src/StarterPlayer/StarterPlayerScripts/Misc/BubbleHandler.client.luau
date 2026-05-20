local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local Player = game.Players.LocalPlayer
local Character = Player.Character
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { Character }

ReplicatedStorage.Assets.Public.BubbleEvent.OnClientEvent:Connect(function(message, position)
	local Parts = workspace:GetPartBoundsInRadius(position, 2, params)
	for i, v in pairs(Parts) do
		if v.Parent:GetAttribute("IsAI") and not v.Parent:GetAttribute("WorkBubble") then
			TextChatService:DisplayBubble(v.Parent.Head, message)
			v.Parent:SetAttribute("WorkBubble", true)
			task.delay(1, function()
				v.Parent:SetAttribute("WorkBubble", nil)
			end)
		end
	end
end)
