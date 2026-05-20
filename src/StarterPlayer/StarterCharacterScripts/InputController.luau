local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local InputController = {}
local Actions = {}
local MappedActions = {}

local Player = game.Players.LocalPlayer
local Mouse = Player:GetMouse()

local Knit = require(game.ReplicatedStorage.Packages.Knit)
local DeviceController = Knit.GetController("DeviceController")

function InputController.Caller(actionName, inputState, inputObject)
	if Actions[actionName] then
		Actions[actionName].callback(inputState, inputObject)
	end
end

function InputController:FireAction(input, state, gameProcessedEvent)
	local value = input.Name

	if value == "InputObject" then
		value = input.KeyCode.Name
	end
	if not value then
		return
	end

	local actions = MappedActions[value]
	if not actions then
		return
	end

	for index, action in pairs(actions) do
		if action.CASBinded then
			continue
		end

		if gameProcessedEvent then
			if not action.ExecuteOnProcess then
				continue
			end
		end

		InputController.Caller(index, state, input)
	end
end

function BindKeys()
	for name, action in Actions do
		for _, key in action.keys do
			if not MappedActions[key.Name] then
				MappedActions[key.Name] = {}
			end

			MappedActions[key.Name][name] = action
		end
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
		InputController:FireAction(input, Enum.UserInputState.Begin, gameProcessedEvent)
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessedEvent)
		InputController:FireAction(input, Enum.UserInputState.End, gameProcessedEvent)
	end)

	Mouse.Button2Down:Connect(function()
		InputController:FireAction(Enum.UserInputType.MouseButton2, Enum.UserInputState.Begin)
	end)

	Mouse.Button2Up:Connect(function()
		InputController:FireAction(Enum.UserInputType.MouseButton2, Enum.UserInputState.End)
	end)

	Mouse.Button1Down:Connect(function()
		InputController:FireAction(Enum.UserInputType.MouseButton1, Enum.UserInputState.Begin)
	end)

	Mouse.Button1Up:Connect(function()
		InputController:FireAction(Enum.UserInputType.MouseButton1, Enum.UserInputState.End)
	end)
end

function InputController.Start()
	for i, module in ipairs(script.Parent.Actions:GetChildren()) do
		if module:IsA("ModuleScript") then
			Actions[module.Name] = require(module)
		end
	end

	BindKeys()
end

return InputController
