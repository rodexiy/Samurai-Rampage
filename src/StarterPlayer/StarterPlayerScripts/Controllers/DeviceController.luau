local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Validate = require(ReplicatedStorage.Shared.Validate)

local DeviceController = Knit.CreateController({
	Name = "DeviceController",
})

local DeviceChanged = Instance.new("BindableEvent")
DeviceController.DeviceChanged = DeviceChanged.Event

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Actions = PlayerGui:WaitForChild("Actions", math.huge)
local content = Actions:WaitForChild("content")
local Template = Actions:WaitForChild("Template")

type PersistentAction = {
	Callback: (Enum.UserInputState) -> (),
	Name: string,
	Position: UDim2,
}

local PersistentActions: { [string]: PersistentAction } = {}
local BoundActions: { [string]: PersistentAction } = {}
local ActionDefinitions: { [string]: { Name: string, Position: UDim2 } } = {}
local PressedActions: { [ImageButton]: (Enum.UserInputState) -> () } = {}
local JumpActions: { [string]: (Enum.UserInputState) -> () } = {}
local JumpButtons: { [GuiButton]: boolean } = setmetatable({}, { __mode = "k" })

local function BindJumpButton(Object: Instance)
	if not Object:IsA("GuiButton") or Object.Name ~= "JumpButton"
		or not Object:FindFirstAncestor("TouchGui") or JumpButtons[Object] then
		return
	end

	JumpButtons[Object] = true
	Object.InputBegan:Connect(function(Input: InputObject)
		if not DeviceController:IsMobile() then
			return
		end
		if Input.UserInputType ~= Enum.UserInputType.Touch and Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		if Player:GetAttribute("EditingMobileControls") then
			return
		end

		local Character = Player.Character
		if not Character or Character:GetAttribute("RealmEditing") then
			return
		end

		for ActionName, Callback in JumpActions do
			if Validate:CanPerformIntroAction(Character, ActionName) then
				Callback(Enum.UserInputState.Begin)
			end
		end
	end)
end

local function CreateButton(ActionName: string, Name: string, Position: UDim2): ImageButton
	local Action = Template:Clone() :: ImageButton
	Action.Name = ActionName
	local Label = Action:WaitForChild("ActionName") :: TextLabel
	Label.Text = Name
	Action.Position = Position
	Action:SetAttribute("DefaultControlPosition", Position)
	return Action
end

local function ShowPreview(ActionName: string)
	local Definition = ActionDefinitions[ActionName]
	if not Definition or content:FindFirstChild(ActionName) then
		return
	end

	local Action = CreateButton(ActionName, Definition.Name, Definition.Position)
	Action:SetAttribute("ControlPreview", true)
	Action.Parent = content
	Action.Visible = true
end

local function ReleaseActions()
	local Callbacks = table.clone(PressedActions)
	table.clear(PressedActions)

	for _, Callback in Callbacks do
		Callback(Enum.UserInputState.End)
	end
end

function DeviceController:ApplyStrokeValue()
	if DeviceController:IsDevice("Mobile") then
		task.spawn(function()
			repeat
				task.wait()
			until #PlayerGui:GetDescendants() >= #StarterGui:GetDescendants()

			for _, Stroke: UIStroke in PlayerGui:GetDescendants() do
				if Stroke:IsA("UIStroke") then
					Stroke.Thickness = Stroke.Thickness / 2
				end
			end
		end)
	end
end

function DeviceController:GetDevice()
	return if self:IsMobile() then "Mobile" else "Desktop"
end

function DeviceController:IsDevice(DeviceName: string)
	return self:GetDevice() == DeviceName
end

function DeviceController:UnbindAction(ActionName: string)
	PersistentActions[ActionName] = nil
	BoundActions[ActionName] = nil

	local Action = content:FindFirstChild(ActionName)
	if Action and not Action:GetAttribute("ControlPreview") then
		local Callback = PressedActions[Action]
		PressedActions[Action] = nil
		if Callback then
			Callback(Enum.UserInputState.End)
		end

		Action:Destroy()
	end

	if self:IsMobile() and Player:GetAttribute("EditingMobileControls") then
		ShowPreview(ActionName)
	end
end

function DeviceController:RegisterAction(ActionName: string, Name: string, Position: UDim2)
	ActionDefinitions[ActionName] = { Name = Name, Position = Position }
	if self:IsMobile() and Player:GetAttribute("EditingMobileControls") then
		ShowPreview(ActionName)
	end
end

function DeviceController:BindJumpAction(ActionName: string, Callback: (Enum.UserInputState) -> ())
	JumpActions[ActionName] = Callback
end

function DeviceController:IsDown(ActionName: string)
	if Player:GetAttribute("EditingMobileControls") then
		return false
	end

	if content:FindFirstChild(ActionName) then
		return content[ActionName].GuiState == Enum.GuiState.Press
	end
end

function DeviceController:BindAction(
	ActionName: string,
	callback: (Enum.UserInputState) -> (),
	Name: string,
	Position: UDim2,
	PersistAcrossCharacters: boolean?
)
	self:RegisterAction(ActionName, Name, Position)
	local Binding: PersistentAction = { Callback = callback, Name = Name, Position = Position }
	BoundActions[ActionName] = Binding
	if PersistAcrossCharacters then
		PersistentActions[ActionName] = Binding
	end

	local Existing = content:FindFirstChild(ActionName)
	if Existing then
		if Existing:GetAttribute("ControlPreview") then
			Existing:Destroy()
		else
			return
		end
	end
	if self:IsMobile() then
		local Action = CreateButton(ActionName, Name, Position)

		Action:GetPropertyChangedSignal("GuiState"):Connect(function()
			if Player:GetAttribute("EditingMobileControls") then
				return
			end

			if Action.GuiState == Enum.GuiState.Press then
				local Character = Player.Character
				if Character and (Character:GetAttribute("RealmEditing") or not Validate:CanPerformIntroAction(Character, ActionName)) then
					return
				end

				PressedActions[Action] = callback
				callback(Enum.UserInputState.Begin)
			elseif PressedActions[Action] then
				PressedActions[Action] = nil
				callback(Enum.UserInputState.End)
			end
		end)
		Action.Destroying:Connect(function()
			PressedActions[Action] = nil
		end)

		Action.Parent = content
		Action.Visible = true
	end
end

function DeviceController:IsMobile()
	return UserInputService.TouchEnabled
end

local function ClearButtons()
	ReleaseActions()

	for _, Action in content:GetChildren() do
		if Action:IsA("ImageButton") then
			Action:Destroy()
		end
	end
end

local function RefreshDevice()
	if DeviceController:IsMobile() then
		for ActionName, Binding in table.clone(BoundActions) do
			DeviceController:BindAction(ActionName, Binding.Callback, Binding.Name, Binding.Position)
		end
	else
		ClearButtons()
	end

	DeviceChanged:Fire(DeviceController:GetDevice())
end

function DeviceController.KnitInit()
	DeviceController:ApplyStrokeValue()
end

function DeviceController.KnitStart()
	UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(RefreshDevice)
	PlayerGui.DescendantAdded:Connect(BindJumpButton)
	for _, Button in PlayerGui:QueryDescendants("GuiButton") do
		BindJumpButton(Button)
	end

	Player:GetAttributeChangedSignal("EditingMobileControls"):Connect(function()
		if Player:GetAttribute("EditingMobileControls") then
			ReleaseActions()
			for ActionName in ActionDefinitions do
				ShowPreview(ActionName)
			end
		else
			for _, Action in content:GetChildren() do
				if Action:GetAttribute("ControlPreview") then
					Action:Destroy()
				end
			end
		end
	end)

	Player.CharacterRemoving:Connect(function()
		table.clear(JumpActions)
		ClearButtons()
		BoundActions = table.clone(PersistentActions)
	end)

	Player.CharacterAdded:Connect(function()
		for ActionName, Binding in PersistentActions do
			DeviceController:BindAction(ActionName, Binding.Callback, Binding.Name, Binding.Position)
		end
	end)
end

return DeviceController
