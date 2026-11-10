local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
Knit.OnStart():await()

local MenuController = Knit.GetController("MenuController")
local UserInputService = game:GetService("UserInputService")
local PlaceController = Knit.GetController("PlaceController")

local openInventory = function(inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin then
		return
	end

	MenuController:OpenMenu("MainMenu")
end

UserInputService.InputBegan:Connect(function(inputObject: InputObject, processing: boolean)
	if processing and PlaceController:IsSHURA() then
		return
	end
	if inputObject.KeyCode == Enum.KeyCode.Tab then
		openInventory(Enum.UserInputState.Begin)
	end
end)

MenuController:SetHudDefaultEnabled()
