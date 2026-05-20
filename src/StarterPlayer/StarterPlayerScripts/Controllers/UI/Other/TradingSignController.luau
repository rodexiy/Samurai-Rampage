local TextService = game:GetService("TextService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local TradingSignController = Knit.CreateController({
	Name = "TradingSignController",
})

local Player = game.Players.LocalPlayer
local PlayerGui
local Temporary
local TradingSign
local content
local SignText

local AlertController
local TradingSignService

local text

local function ApplyText()
	local filteredText = TradingSignService:ApplyText(text)

	if filteredText ~= text then
		SignText.Text = filteredText
		AlertController:Alert("The message has been moderated", "Error")
	else
		TradingSign.Enabled = false
	end
end

function TradingSignController:BindSignText()
	SignText:GetPropertyChangedSignal("Text"):Connect(function()
		text = SignText.Text
	end)

	SignText.FocusLost:Connect(function(enterPressed)
		if not enterPressed then
			return
		end
		ApplyText()
	end)
end

function TradingSignController.KnitInit()
	TradingSignService = Knit.GetService("TradingSignService")
	AlertController = Knit.GetController("AlertController")
end

function TradingSignController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui")
	Temporary = PlayerGui:WaitForChild("Temporary", math.huge)
	TradingSign = Temporary:WaitForChild("TradingSign")
	content = TradingSign:WaitForChild("content")
	SignText = content:WaitForChild("SignText")

	TradingSignController:BindSignText()
end

return TradingSignController
