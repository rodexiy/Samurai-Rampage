local ContextActionService = game:GetService("ContextActionService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local HotkeyController = Knit.CreateController({
	Name = "HotkeyController",
})

local MenuController
local DeviceController

function HotkeyController:BindHotkeys() end

function HotkeyController.KnitInit()
	DeviceController = Knit.GetController("DeviceController")
	MenuController = Knit.GetController("MenuController")
end

function HotkeyController.KnitStart()
	HotkeyController:BindHotkeys()
end

return HotkeyController
