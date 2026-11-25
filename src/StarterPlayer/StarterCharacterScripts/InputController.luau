local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Validate = require(ReplicatedStorage.Shared.Validate)

local InputController = {}
local Actions = {}
local MappedActions = {}

local Player = Players.LocalPlayer
local Mouse = Player:GetMouse()

function InputController.Caller(actionName: string, inputState: Enum.UserInputState, inputObject: (InputObject | Enum.UserInputType)?)
	local Character = Player.Character
	if Character and inputState == Enum.UserInputState.Begin and not Validate:CanPerformIntroAction(Character, actionName) then
		return
	end
	if Character and Character:GetAttribute("RealmEditing") and inputState ~= Enum.UserInputState.End
		and inputState ~= Enum.UserInputState.Cancel then
		return
	end

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

	if value == Enum.KeyCode.G.Name then
		if gameProcessedEvent or state ~= Enum.UserInputState.Begin then
			return
		end

		local Character = Player.Character
		if not Character then
			return
		end

		local WasClimbing = Character:GetAttribute("Climbing")
		InputController.Caller("Climb", state, input)

		if not WasClimbing and not Character:GetAttribute("Climbing") then
			Knit.GetController("KickController"):HandleInput(state)
		end
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
	for _, module in ipairs(script.Parent.Actions:GetChildren()) do
		if module:IsA("ModuleScript") then
			Actions[module.Name] = require(module)
		end
	end

	BindKeys()
end

return InputController
