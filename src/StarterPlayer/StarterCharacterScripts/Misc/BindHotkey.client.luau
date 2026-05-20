local Knit = require(game.ReplicatedStorage.Packages.Knit)
Knit.OnStart():await()

local MenuController = Knit.GetController("MenuController")
local DeviceController = Knit.GetController("DeviceController")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local PlaceController = Knit.GetController("PlaceController")

local openInventory = function(inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return
	end

	MenuController:OpenMenu("Inventory")
end

UserInputService.InputBegan:Connect(function(inputObject, processing)
	if processing and PlaceController:IsSHURA() then
		return
	end
	if inputObject.KeyCode == Enum.KeyCode.Tab then
		openInventory(Enum.UserInputState.Begin)
	end
end)

MenuController:SetHudDefaultEnabled()
DeviceController:BindAction("Inventory", openInventory, "Inventory", UDim2.fromScale(0.1, 0.35))
