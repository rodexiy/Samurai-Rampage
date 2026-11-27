local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local MobileControlLayout = require(ReplicatedStorage.Shared.MobileControlLayout)

type Layout = MobileControlLayout.Layout
type ButtonState = { Button: ImageButton, Default: UDim2, Outline: UIStroke }
type DragState = { State: ButtonState, Input: InputObject, Start: Vector2, Position: Vector2 }

local MobileControlsController = Knit.CreateController({ Name = "MobileControlsController" })
local Changed = Instance.new("BindableEvent")
MobileControlsController.Changed = Changed.Event

local Player = Players.LocalPlayer
local DeviceController
local MenuController
local ActionWheelController
local AlertController
local MobileControlsService
local Actions: ScreenGui
local Content: GuiObject
local ResetMenu: ScreenGui
local Buttons: { [string]: ButtonState } = {}
local SavedPositions: Layout = {}
local ConfirmedPositions: Layout = {}
local Drag: DragState? = nil
local Editing = false
local Ready = false
local RequestId = 0

local function ClampPosition(Button: ImageButton, Position: Vector2): Vector2
	return MobileControlLayout.ClampPosition(Position, Button.AbsoluteSize, Content.AbsoluteSize, Button.AnchorPoint)
end

local function ApplyPosition(State: ButtonState)
	local Position = SavedPositions[State.Button.Name]
	if Position then
		local Clamped = ClampPosition(State.Button, Vector2.new(Position.X, Position.Y))
		State.Button.Position = UDim2.fromScale(Clamped.X, Clamped.Y)
	else
		State.Button.Position = State.Default
	end
end

local function ApplyLayout()
	for _, State in Buttons do
		ApplyPosition(State)
	end
end

local function SaveLayout()
	RequestId += 1
	MobileControlsService.SaveLayout:Fire(RequestId, SavedPositions)
end

local function FinishDrag()
	local Current = Drag
	Drag = nil
	if not Current or Current.State.Button.Parent ~= Content then
		return
	end

	local Button = Current.State.Button
	SavedPositions[Button.Name] = { X = Button.Position.X.Scale, Y = Button.Position.Y.Scale }
	SaveLayout()
end

local function MoveDrag(Input: InputObject)
	local Current = Drag
	if not Current or (Input ~= Current.Input and not (
		Current.Input.UserInputType == Enum.UserInputType.MouseButton1
		and Input.UserInputType == Enum.UserInputType.MouseMovement
	)) then
		return
	end

	local Size = Content.AbsoluteSize
	if Size.X <= 0 or Size.Y <= 0 then
		return
	end

	local Delta = Vector2.new(Input.Position.X, Input.Position.Y) - Current.Start
	local Position = ClampPosition(Current.State.Button, Current.Position + Delta / Size)
	Current.State.Button.Position = UDim2.fromScale(Position.X, Position.Y)
end

local function BeginDrag(State: ButtonState, Input: InputObject)
	if not Editing or Drag or (Input.UserInputType ~= Enum.UserInputType.Touch
		and Input.UserInputType ~= Enum.UserInputType.MouseButton1) then
		return
	end

	local Size = Content.AbsoluteSize
	if Size.X <= 0 or Size.Y <= 0 then
		return
	end

	local Button = State.Button
	local Position = Button.AbsolutePosition + Button.AbsoluteSize * Button.AnchorPoint - Content.AbsolutePosition
	Drag = {
		State = State, Input = Input,
		Start = Vector2.new(Input.Position.X, Input.Position.Y), Position = Position / Size,
	}
end

local function BindButton(Child: Instance)
	if not Child:IsA("ImageButton") or Buttons[Child.Name] and Buttons[Child.Name].Button == Child then
		return
	end

	local Default = Child:GetAttribute("DefaultControlPosition")
	if typeof(Default) ~= "UDim2" then
		return
	end

	local Outline = Instance.new("UIStroke")
	Outline.Name = "ControlEditOutline"
	Outline.Color = Color3.fromRGB(235, 192, 107)
	Outline.Thickness = 2
	Outline.Enabled = Editing
	Outline.Parent = Child

	local State: ButtonState = { Button = Child, Default = Default, Outline = Outline }
	Buttons[Child.Name] = State
	ApplyPosition(State)
	Child.InputBegan:Connect(function(Input: InputObject)
		BeginDrag(State, Input)
	end)
end

function MobileControlsController:IsEditing(): boolean
	return Editing
end

function MobileControlsController:SetEditing(Active: boolean): boolean
	if Active == Editing then
		return true
	end
	if Active then
		local Character = Player.Character
		if not DeviceController:IsMobile() or not Ready or not Character
			or Character:GetAttribute("Died") or Character:GetAttribute("Downed")
			or Character:GetAttribute("RealmEditing") or Character:GetAttribute("Meditating")
			or Player:GetAttribute("InIntroCutscene") or Player:GetAttribute("InDialog") then
			return false
		end

		ActionWheelController:Close()
		MenuController:CloseAllMenus()
	else
		FinishDrag()
	end

	Editing = Active
	Player:SetAttribute("EditingMobileControls", Active)
	for _, State in Buttons do
		State.Outline.Enabled = Active
	end
	Changed:Fire(Active)
	return true
end

function MobileControlsController:RequestReset()
	if not DeviceController:IsMobile() or not Ready then
		return
	end

	self:SetEditing(false)
	MenuController:OpenMenu("ResetControlSettings", true)
end

local function OnLayoutSaved(Id: number, Success: boolean, Layout: Layout?)
	if Success and Layout then
		ConfirmedPositions = MobileControlLayout.Validate(Layout) or ConfirmedPositions
	end
	if Id ~= RequestId then
		return
	end
	if not Success then
		SavedPositions = MobileControlLayout.Validate(ConfirmedPositions) or {}
		Drag = nil
		ApplyLayout()
		AlertController:Alert("Couldn't save control positions. Try again.", "Error")
	end
end

local function ConfirmReset()
	if not ResetMenu.Enabled then
		return
	end

	SavedPositions = {}
	ApplyLayout()
	SaveLayout()
	MenuController:CloseMenu("ResetControlSettings")
end

function MobileControlsController.KnitInit()
	DeviceController = Knit.GetController("DeviceController")
	MenuController = Knit.GetController("MenuController")
	ActionWheelController = Knit.GetController("ActionWheelController")
	AlertController = Knit.GetController("AlertController")
	MobileControlsService = Knit.GetService("MobileControlsService")
end

function MobileControlsController.KnitStart()
	local PlayerGui = Player:WaitForChild("PlayerGui") :: PlayerGui
	Actions = PlayerGui:WaitForChild("Actions") :: ScreenGui
	Content = Actions:WaitForChild("content") :: GuiObject
	local Menus = PlayerGui:WaitForChild("Menu") :: ScreenGui
	ResetMenu = Menus:WaitForChild("ResetControlSettings") :: ScreenGui
	local Panel = ResetMenu:WaitForChild("DeleteConfirmation") :: Frame
	local ResetButtons = Panel:WaitForChild("Buttons") :: Frame
	local Confirm = ResetButtons:WaitForChild("Delete") :: ImageButton
	local Cancel = ResetButtons:WaitForChild("Cancel") :: ImageButton
	local ConfirmTitle = Confirm:WaitForChild("Title") :: TextLabel
	ConfirmTitle.Text = "RESET"
	Confirm:SetAttribute("callback", nil)
	Cancel:SetAttribute("callback", nil)
	Confirm.Activated:Connect(ConfirmReset)
	MenuController:BindCloseButton(Cancel, function()
		MenuController:CloseMenu("ResetControlSettings")
	end)

	Content.ChildAdded:Connect(BindButton)
	Content.ChildRemoved:Connect(function(Child: Instance)
		local State = Buttons[Child.Name]
		if State and State.Button == Child then
			if Drag and Drag.State == State then
				Drag = nil
			end
			Buttons[Child.Name] = nil
		end
	end)
	Content:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		FinishDrag()
		ApplyLayout()
	end)
	for _, Child in Content:GetChildren() do
		BindButton(Child)
	end

	UserInputService.InputChanged:Connect(MoveDrag)
	UserInputService.InputEnded:Connect(function(Input: InputObject)
		if Drag and Input == Drag.Input then
			MoveDrag(Input)
			FinishDrag()
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		MobileControlsController:SetEditing(false)
	end)
	Player.CharacterRemoving:Connect(function()
		MobileControlsController:SetEditing(false)
	end)
	DeviceController.DeviceChanged:Connect(function(Device: string)
		if Device ~= "Mobile" then
			MobileControlsController:SetEditing(false)
		end
	end)
	Actions:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not Actions.Enabled then
			MobileControlsController:SetEditing(false)
		end
	end)
	MobileControlsService.LayoutSaved:Connect(OnLayoutSaved)

	local Success, Layout = pcall(function(): Layout?
		return MobileControlsService:GetLayout()
	end)
	local ValidLayout = if Success then MobileControlLayout.Validate(Layout) else nil
	if not ValidLayout then
		if DeviceController:IsMobile() then
			AlertController:Alert("Couldn't load control positions. Rejoin to edit controls.", "Error")
		end
		return
	end

	SavedPositions = ValidLayout
	ConfirmedPositions = MobileControlLayout.Validate(ValidLayout) or {}
	Ready = true
	ApplyLayout()
end

return MobileControlsController
