local TextService = game:GetService("TextService")
local TradingSign = {}

local Player = game.Players.LocalPlayer

function TradingSign.Activated(Character: Model, Tool: Tool)
	local PlayerGui = Player.PlayerGui
	local Temporary = PlayerGui:WaitForChild("Temporary")
	local TradingSign = Temporary:WaitForChild("TradingSign")
	TradingSign.Enabled = not TradingSign.Enabled
end
function TradingSign.Unequipped(Character: Model, Tool: Tool)
	local PlayerGui = Player.PlayerGui
	local Temporary = PlayerGui:WaitForChild("Temporary")
	local TradingSign = Temporary:WaitForChild("TradingSign")
	TradingSign.Enabled = false
end

return TradingSign
