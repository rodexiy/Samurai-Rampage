local Knit = require(game.ReplicatedStorage.Packages.Knit)

local TradingSignService = Knit.CreateService({
	Name = "TradingSignService",
	Client = {},
})
local ToolService

local TextService = game:GetService("TextService")
function TradingSignService:ApplyText(Player: Player, Text: string)
	local filterResult = TextService:FilterStringAsync(Text, Player.UserId, Enum.TextFilterContext.PublicChat)
	local Moderatedtext = filterResult:GetNonChatStringForBroadcastAsync()

	local Character = Player.Character

	if Character then
		local Tool: Tool = ToolService:GetToolFromPlayer(Player, "TradingSign")
		if Tool then
			local Surface: SurfaceGui = Tool:FindFirstChildWhichIsA("SurfaceGui", true)
			if Surface then
				Surface.TextLabel.Text = Moderatedtext
			end
		end
	end

	return Moderatedtext
end
function TradingSignService.Client:ApplyText(Player: Player, Text: string)
	return self.Server:ApplyText(Player, Text)
end

function TradingSignService.KnitInit()
	ToolService = Knit.GetService("ToolService")
end

function TradingSignService.KnitStart() end

return TradingSignService
