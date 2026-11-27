local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local ActionWheelController = Knit.CreateController({ Name = "ActionWheelController" })
local Player = Players.LocalPlayer
local DEADZONE = 0.25
local PRIORITY = Enum.ContextActionPriority.High.Value + 20
local FAN_TWEEN = TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local CLOSED_ROTATION = -135
local CLOSED_BUTTON_SCALE = 0.05

type Action = {
	Name: string,
	Enabled: boolean,
	Rotation: number,
	Slice: ImageLabel,
	Icon: ImageLabel,
	Color: Color3,
	IconColor: Color3,
}

local ActionNames = {
	Inventory = true,
	Meditate = true,
	Horse = true,
	Crafting = true,
	DeathStare = true,
	Shop = true,
	Settings = true,
	Emote = true,
}
local MenuNames = { Inventory = "MainMenu", Crafting = "Crafting", Shop = "Store", Settings = "Settings" }
local Actions: { Action } = {}
local Tweens: { [Instance]: Tween } = {}
local MenuController
local HotbarController
local PlaceController
local HorseService
local DeviceController
local Wheel: ScreenGui
local Background: Frame
local CloseScale: UIScale
local Selected: Action? = nil
local Gamepad: Enum.UserInputType? = nil
local PreviousGuiSelection: GuiObject? = nil
local Opened = false
local Revision = 0
local Ready = false

local function Animate(Object: Instance, Properties: { [string]: any }, Info: TweenInfo?)
	if Tweens[Object] then
		Tweens[Object]:Cancel()
	end

	local Tween = TweenService:Create(Object, Info or FAN_TWEEN, Properties)
	Tweens[Object] = Tween
	Tween.Completed:Once(function()
		if Tweens[Object] == Tween then
			Tweens[Object] = nil
		end
	end)
	Tween:Play()
end

local function SetSelected(Action: Action?)
	if Selected == Action then
		return
	end

	Selected = Action
	for _, Entry in Actions do
		local Highlighted = Entry == Action
		Entry.Slice.ImageColor3 = if Highlighted then Color3.fromRGB(223, 190, 119) else Entry.Color
	end
end

local function SelectDirection(Direction: Vector2)
	if Direction.Magnitude <= DEADZONE then
		SetSelected(nil)
		return
	end

	-- Authored slices point up at Rotation = 0 and rotate clockwise.
	local Angle = math.deg(math.atan2(Direction.X, -Direction.Y))
	local Nearest: Action? = nil
	local Distance = math.huge
	for _, Action in Actions do
		local Difference = math.abs((Angle - Action.Rotation + 180) % 360 - 180)
		if Difference < Distance then
			Distance, Nearest = Difference, Action
		end
	end
	SetSelected(Nearest)
end

local function SelectMouse()
	local Inset = if Wheel.IgnoreGuiInset then Vector2.zero else GuiService:GetGuiInset()
	local Offset = UserInputService:GetMouseLocation() - Inset - Background.AbsolutePosition - Background.AbsoluteSize / 2
	local Radius = math.min(Background.AbsoluteSize.X, Background.AbsoluteSize.Y) / 2
	if Radius <= 0 or Offset.Magnitude > Radius then
		SetSelected(nil)
		return
	end

	SelectDirection(Offset / Radius)
end

function ActionWheelController:IsOpen(): boolean
	return Opened
end

local function CanOpen(): boolean
	local Character = Player.Character
	if not Ready or not Wheel.Enabled or not Character or workspace:GetAttribute("InMainMenu")
		or Player:GetAttribute("EditingMobileControls")
		or UserInputService:GetFocusedTextBox() or GuiService.MenuIsOpen
		or Player:GetAttribute("InIntroCutscene") or Player:GetAttribute("InDialog") then
		return false
	end

	for _, Attribute in { "Died", "Downed", "Ragdoll", "RealmEditing", "RealmTeleporting", "CameraCutscene" } do
		if Character:GetAttribute(Attribute) then
			return false
		end
	end

	local Menus = Wheel.Parent.Parent:FindFirstChild("Menu")
	local Dialog = Menus and Menus:FindFirstChild("Dialog") :: ScreenGui?
	return not Dialog or not Dialog.Enabled
end

function ActionWheelController:Close(Confirm: boolean?)
	if not Opened then
		return
	end

	local Action = if Confirm then Selected else nil
	Opened = false
	Gamepad = nil
	Revision += 1
	local CloseRevision = Revision
	Player:SetAttribute("ActionWheelOpen", false)
	ContextActionService:UnbindAction("ActionWheelStick")
	ContextActionService:UnbindAction("ActionWheelCancel")
	if PreviousGuiSelection and PreviousGuiSelection.Parent then
		GuiService.SelectedObject = PreviousGuiSelection
	end
	PreviousGuiSelection = nil
	SetSelected(nil)

	Animate(CloseScale, { Scale = CLOSED_BUTTON_SCALE })
	for _, Entry in Actions do
		Animate(Entry.Slice, { Rotation = CLOSED_ROTATION, ImageTransparency = 1 })
		Animate(Entry.Icon, { Rotation = -CLOSED_ROTATION, ImageTransparency = 1 })
	end
	task.delay(FAN_TWEEN.Time, function()
		if Revision == CloseRevision then
			Background.Visible = false
		end
	end)

	if Action and Action.Enabled and CanOpen() then
		local MenuName = MenuNames[Action.Name]
		if MenuName then
			MenuController:OpenMenu(MenuName)
		elseif Action.Name == "Horse" then
			HorseService.Request:Fire("Spawn")
		elseif Action.Name == "DeathStare" then
			Knit.GetController("EgoController"):Toggle()
		elseif Action.Name == "Meditate" then
			local Character = Player.Character
			local Client = Character and Character:FindFirstChild("Client")
			if Client and Client:FindFirstChild("InputController") then
				local InputController = require(Players.LocalPlayer.Character.Client.InputController)
				InputController.Caller("Meditate", Enum.UserInputState.Begin)
			end
		end
	end
end

local function StickAction(_Name: string, State: Enum.UserInputState, Input: InputObject): Enum.ContextActionResult
	if Input.UserInputType == Gamepad then
		local Direction = if State == Enum.UserInputState.Cancel or State == Enum.UserInputState.End
			then Vector2.zero else Vector2.new(Input.Position.X, -Input.Position.Y)
		SelectDirection(Direction)
	end

	return Enum.ContextActionResult.Sink
end

local function CancelAction(_Name: string, State: Enum.UserInputState, _Input: InputObject): Enum.ContextActionResult
	if State == Enum.UserInputState.Begin then
		ActionWheelController:Close()
	end

	return Enum.ContextActionResult.Sink
end

function ActionWheelController:Open(InputGamepad: Enum.UserInputType?)
	if Opened or not CanOpen() then
		return
	end

	HotbarController:CancelSlotSelection()
	Knit.GetController("ConsoleHotbarController"):Close()
	Opened = true
	Gamepad = InputGamepad
	Revision += 1
	Player:SetAttribute("ActionWheelOpen", true)
	PreviousGuiSelection = GuiService.SelectedObject
	GuiService.SelectedObject = nil
	Background.Visible = true
	Selected = nil

	Animate(CloseScale, { Scale = 1 })
	for _, Entry in Actions do
		Entry.Enabled = Entry.Name ~= "Emote"
			and (Entry.Name ~= "DeathStare" or Knit.GetController("EgoController"):CanUse())
			and (Entry.Name ~= "Shop" or not PlaceController:IsArena())
		Entry.Slice.Rotation = CLOSED_ROTATION
		Entry.Icon.Rotation = -CLOSED_ROTATION
		Animate(Entry.Slice, { Rotation = Entry.Rotation, ImageTransparency = if Entry.Enabled then 0 else 0.45 })
		Animate(Entry.Icon, { Rotation = -Entry.Rotation, ImageTransparency = if Entry.Enabled then 0 else 0.65 })
	end

	ContextActionService:BindActionAtPriority("ActionWheelCancel", CancelAction, false, PRIORITY, Enum.KeyCode.ButtonB)
	if Gamepad then
		ContextActionService:BindActionAtPriority("ActionWheelStick", StickAction, false, PRIORITY, Enum.KeyCode.Thumbstick2)
		for _, Input in UserInputService:GetGamepadState(Gamepad) do
			if Input.KeyCode == Enum.KeyCode.Thumbstick2 then
				StickAction("ActionWheelStick", Enum.UserInputState.Change, Input)
			end
		end
	end
end

local function ToggleAction(_Name: string, State: Enum.UserInputState, Input: InputObject): Enum.ContextActionResult
	if State == Enum.UserInputState.Begin then
		if Input.KeyCode == Enum.KeyCode.Tab and not UserInputService:GetFocusedTextBox() then
			for _, MenuName in { "Inventory", "Meditate" } do
				local Menu = MenuController:GetMenu(MenuName)
				if Menu and Menu.Enabled then
					ActionWheelController:Close()
					MenuController:CloseMenu(MenuName)
					return Enum.ContextActionResult.Sink
				end
			end
		end

		if Opened then
			ActionWheelController:Close()
		else
			ActionWheelController:Open(if Input.KeyCode == Enum.KeyCode.ButtonL1 then Input.UserInputType else nil)
		end
	elseif Input.KeyCode == Enum.KeyCode.ButtonL1 and Gamepad == Input.UserInputType then
		if State == Enum.UserInputState.End or State == Enum.UserInputState.Cancel then
			ActionWheelController:Close(State == Enum.UserInputState.End)
		end
	end

	return Enum.ContextActionResult.Sink
end

local function BindSlice(Slice: ImageLabel)
	local Icon = Slice:WaitForChild("Icon") :: ImageLabel
	local Button = Slice:FindFirstChildWhichIsA("GuiButton")
	local Action: Action = {
		Name = Slice.Name, Enabled = false,
		Rotation = Slice.Rotation, Slice = Slice, Icon = Icon,
		Color = Slice.ImageColor3, IconColor = Icon.ImageColor3,
	}
	table.insert(Actions, Action)
	if Button then
		Button.Selectable = false
		Button.Activated:Connect(function()
			if Opened and not Gamepad then
				SetSelected(Action)
				ActionWheelController:Close(Action.Enabled)
			end
		end)
	end
end

function ActionWheelController.KnitInit()
	MenuController = Knit.GetController("MenuController")
	HotbarController = Knit.GetController("HotbarController")
	PlaceController = Knit.GetController("PlaceController")
	HorseService = Knit.GetService("HorseService")
	DeviceController = Knit.GetController("DeviceController")
end

function ActionWheelController.KnitStart()
	local PlayerGui = Player:WaitForChild("PlayerGui") :: PlayerGui
	local Hud = PlayerGui:WaitForChild("Hud") :: ScreenGui
	Wheel = Hud:WaitForChild("ActionUI") :: ScreenGui
	Background = Wheel:WaitForChild("Background") :: Frame
	Background.Visible = false
	Wheel.DisplayOrder = 30
	Wheel.Enabled = true
	if not Wheel:FindFirstChild("Enabler") then
		local Enabler = Instance.new("BoolValue")
		Enabler.Name = "Enabler"
		Enabler.Parent = Wheel
	end

	for _, Slice in Background:GetChildren() do
		if Slice:IsA("ImageLabel") and ActionNames[Slice.Name] then
			BindSlice(Slice)
		end
	end
	local Close = Background:WaitForChild("Close") :: ImageButton
	CloseScale = Close:FindFirstChildWhichIsA("UIScale") or Instance.new("UIScale")
	CloseScale.Scale = CLOSED_BUTTON_SCALE
	CloseScale.Parent = Close

	Close.Selectable = false
	MenuController:BindCloseButton(Close, function()
		ActionWheelController:Close()
	end)

	DeviceController:BindAction("ActionWheel", function(State: Enum.UserInputState)
		if State ~= Enum.UserInputState.Begin then
			return
		end

		if Opened then
			ActionWheelController:Close()
		else
			ActionWheelController:Open()
		end
	end, "Actions", UDim2.fromScale(0.1, 0.475), true)

	UserInputService.InputChanged:Connect(function(Input: InputObject)
		if Opened and not Gamepad and Input.UserInputType == Enum.UserInputType.MouseMovement
			and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			SelectMouse()
		end
	end)
	UserInputService.InputEnded:Connect(function(Input: InputObject, Processed: boolean)
		if Opened and not Gamepad and not Processed and Input.UserInputType == Enum.UserInputType.MouseButton1 then
			SelectMouse()
			ActionWheelController:Close(true)
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		ActionWheelController:Close()
	end)
	UserInputService.GamepadDisconnected:Connect(function(InputType: Enum.UserInputType)
		if Gamepad == InputType then
			ActionWheelController:Close()
		end
	end)
	Wheel:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not Wheel.Enabled then
			ActionWheelController:Close()
		end
	end)
	Player.CharacterRemoving:Connect(function()
		ActionWheelController:Close()
	end)
	for _, Attribute in { "InDialog", "InIntroCutscene" } do
		Player:GetAttributeChangedSignal(Attribute):Connect(function()
			if Player:GetAttribute(Attribute) then
				ActionWheelController:Close()
			end
		end)
	end
	local function BindCharacter(Character: Model)
		for _, Attribute in { "Died", "Downed", "Ragdoll", "RealmEditing", "RealmTeleporting", "CameraCutscene" } do
			Character:GetAttributeChangedSignal(Attribute):Connect(function()
				if Character:GetAttribute(Attribute) then
					ActionWheelController:Close()
				end
			end)
		end
	end
	Player.CharacterAdded:Connect(BindCharacter)
	if Player.Character then
		BindCharacter(Player.Character)
	end

	Ready = true
	ContextActionService:BindActionAtPriority("ActionWheelToggle", ToggleAction, false, PRIORITY, Enum.KeyCode.Tab, Enum.KeyCode.ButtonL1)
end

return ActionWheelController
