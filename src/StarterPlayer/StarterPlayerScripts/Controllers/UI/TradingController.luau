local Knit = require(game.ReplicatedStorage.Packages.Knit)

local TradingController = Knit.CreateController({
	Name = "TradingController",
})

if game.PlaceId ~= 140116923448246 then
	return TradingController
end

local Player = game.Players.LocalPlayer
local PlayerGui
local Menu
local TradingMenu

function TradingController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui")
	Menu = PlayerGui:WaitForChild("Menu")
	TradingMenu = Menu:WaitForChild("Trading")
end

return TradingController
