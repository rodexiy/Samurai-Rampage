local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)

type Slot = {
	Index: number,
	Slice: ImageLabel,
	Rotation: number,
	Color: Color3,
	NameLabel: TextLabel,
	IndexLabel: TextLabel,
	AmountLabel: TextLabel,
	TextColor: Color3,
	Images: { ImageLabel },
	Tool: Tool?,
}

local ConsoleHotbarController = Knit.CreateController({ Name = "ConsoleHotbarController" })
local Player = Players.LocalPlayer
local PRIORITY = Enum.ContextActionPriority.High.Value + 20
local DEADZONE = 0.25
local CLOSED_ROTATION = -135
local FAN_TWEEN = TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local Highlight = Color3.fromRGB(223, 190, 119)
local EquippedColor = Color3.fromRGB(255, 183, 0)
local BlockedAttributes = { "Died", "Downed", "Ragdoll", "RealmEditing", "RealmTeleporting", "CameraCutscene" }

local HotbarController
local InventoryController
local ActionWheelController
local Wheel: ScreenGui
local Background: Frame
local Slots: { [number]: Slot } = {}
local Tweens: { [Instance]: Tween } = {}
local Selected: Slot? = nil
local Direction = Vector2.zero
local Gamepad: Enum.UserInputType? = nil
local PreviousSelection: GuiObject? = nil
local Opened = false
local Ready = false
local Revision = 0

local function Animate(Object: Instance, Properties: { [string]: any })
	if Tweens[Object] then
		Tweens[Object]:Cancel()
	end

	local Tween = TweenService:Create(Object, FAN_TWEEN, Properties)
	Tweens[Object] = Tween
	Tween.Completed:Once(function()
		if Tweens[Object] == Tween then
			Tweens[Object] = nil
		end
	end)
	Tween:Play()
end

local function SetSelected(Slot: Slot?)
	Selected = Slot
	for _, Entry in Slots do
		Entry.Slice.ImageColor3 = if Entry == Slot then Highlight else Entry.Color
	end
end

local function SelectDirection(Value: Vector2)
	Direction = Value
	if Value.Magnitude <= DEADZONE then
		SetSelected(nil)
		return
	end

	local Angle = math.deg(math.atan2(Value.X, -Value.Y))
	local Nearest: Slot? = nil
	local Distance = math.huge
	for _, Entry in Slots do
		local Difference = math.abs((Angle - Entry.Rotation + 180) % 360 - 180)
		if Difference < Distance then
			Distance, Nearest = Difference, Entry
		end
	end
	SetSelected(if Nearest and Nearest.Tool then Nearest else nil)
end

local function CanOpen(): boolean
	local Character = Player.Character
	if not Ready or not Wheel.Enabled or not Character or workspace:GetAttribute("InMainMenu")
		or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() or InventoryController:IsOpen()
		or Player:GetAttribute("EditingMobileControls") or Player:GetAttribute("InIntroCutscene")
		or Player:GetAttribute("InDialog") or HotbarController:IsSelectingSlot() then
		return false
	end

	for _, Attribute in BlockedAttributes do
		if Character:GetAttribute(Attribute) then
			return false
		end
	end
	return true
end

local function AnimateSlot(Entry: Slot, Showing: boolean)
	local Visible = Showing and Entry.Tool ~= nil
	Animate(Entry.Slice, {
		Rotation = if Showing then Entry.Rotation else CLOSED_ROTATION,
		ImageTransparency = if Showing then (if Entry.Tool then 0 else 0.65) else 1,
	})
	for _, Label in { Entry.NameLabel, Entry.IndexLabel, Entry.AmountLabel } do
		Animate(Label, {
			Rotation = if Showing then -Entry.Rotation else -CLOSED_ROTATION,
			TextTransparency = if Visible or (Showing and Label == Entry.IndexLabel) then 0 else 1,
		})
	end
	for _, Image in Entry.Images do
		Animate(Image, { ImageTransparency = if Visible then 0 else 1 })
	end
end

function ConsoleHotbarController:RefreshSlot(Index: number, SkipAnimation: boolean?)
	local Entry = Slots[Index]
	if not Entry then
		return
	end

	local Tool = HotbarController:GetToolInHotbarIndex(Index)
	Entry.Tool = Tool
	Entry.NameLabel.Text = if Tool then Tool:GetAttribute("DisplayName") or Tool.Name else ""
	Entry.IndexLabel.Text = tostring(Index)
	local Amount = Tool and Tool:GetAttribute("Stack")
	Entry.AmountLabel.Text = if typeof(Amount) == "number" and Amount > 1 then "x" .. tostring(Amount) else ""
	Entry.AmountLabel.Visible = Entry.AmountLabel.Text ~= ""
	Entry.NameLabel.TextColor3 = if Tool and Tool.Parent == Player.Character then EquippedColor else Entry.TextColor
	if Opened and not SkipAnimation then
		AnimateSlot(Entry, true)
		SelectDirection(Direction)
	end
end

function ConsoleHotbarController:IsOpen(): boolean
	return Opened
end

function ConsoleHotbarController:Close(Confirm: boolean?)
	if not Opened then
		return
	end

	local Index = Selected and Selected.Index
	local CanConfirm = Confirm and CanOpen()
	Opened = false
	Gamepad = nil
	Direction = Vector2.zero
	Revision += 1
	local CloseRevision = Revision
	Player:SetAttribute("ConsoleHotbarOpen", false)
	ContextActionService:UnbindAction("ConsoleHotbarStick")
	ContextActionService:UnbindAction("ConsoleHotbarCancel")
	if PreviousSelection and PreviousSelection.Parent then
		GuiService.SelectedObject = PreviousSelection
	end
	PreviousSelection = nil
	SetSelected(nil)
	for _, Entry in Slots do
		AnimateSlot(Entry, false)
	end
	task.delay(FAN_TWEEN.Time, function()
		if Revision == CloseRevision then
			Background.Visible = false
		end
	end)

	if CanConfirm then
		HotbarController:SelectConsoleSlot(Index)
	end
end

local function StickInput(_Name: string, State: Enum.UserInputState, Input: InputObject): Enum.ContextActionResult
	if Input.UserInputType == Gamepad then
		SelectDirection(if State == Enum.UserInputState.End or State == Enum.UserInputState.Cancel
			then Vector2.zero else Vector2.new(Input.Position.X, -Input.Position.Y))
	end
	return Enum.ContextActionResult.Sink
end

local function CancelInput(_Name: string, State: Enum.UserInputState, _Input: InputObject): Enum.ContextActionResult
	if State == Enum.UserInputState.Begin then
		ConsoleHotbarController:Close()
	end
	return Enum.ContextActionResult.Sink
end

function ConsoleHotbarController:Open(InputGamepad: Enum.UserInputType)
	if Opened or not CanOpen() then
		return
	end

	ActionWheelController:Close()
	Opened = true
	Gamepad = InputGamepad
	Revision += 1
	Direction = Vector2.zero
	Player:SetAttribute("ConsoleHotbarOpen", true)
	PreviousSelection = GuiService.SelectedObject
	GuiService.SelectedObject = nil
	Background.Visible = true
	SetSelected(nil)
	for Index, Entry in Slots do
		self:RefreshSlot(Index, true)
		Entry.Slice.Rotation = CLOSED_ROTATION
		Entry.Slice.ImageTransparency = 1
		for _, Label in { Entry.NameLabel, Entry.IndexLabel, Entry.AmountLabel } do
			Label.Rotation = -CLOSED_ROTATION
			Label.TextTransparency = 1
		end
		for _, Image in Entry.Images do
			Image.ImageTransparency = 1
		end
		AnimateSlot(Entry, true)
	end

	ContextActionService:BindActionAtPriority("ConsoleHotbarStick", StickInput, false, PRIORITY, Enum.KeyCode.Thumbstick2)
	ContextActionService:BindActionAtPriority("ConsoleHotbarCancel", CancelInput, false, PRIORITY, Enum.KeyCode.ButtonB)
	for _, Input in UserInputService:GetGamepadState(InputGamepad) do
		if Input.KeyCode == Enum.KeyCode.Thumbstick2 then
			StickInput("ConsoleHotbarStick", Enum.UserInputState.Change, Input)
		end
	end
end

local function ToggleInput(_Name: string, State: Enum.UserInputState, Input: InputObject): Enum.ContextActionResult
	if State == Enum.UserInputState.Begin then
		if not CanOpen() then
			return Enum.ContextActionResult.Pass
		end
		ConsoleHotbarController:Open(Input.UserInputType)
	elseif Gamepad == Input.UserInputType and (State == Enum.UserInputState.End or State == Enum.UserInputState.Cancel) then
		ConsoleHotbarController:Close(State == Enum.UserInputState.End)
	else
		return Enum.ContextActionResult.Pass
	end
	return Enum.ContextActionResult.Sink
end

function ConsoleHotbarController.KnitInit()
	HotbarController = Knit.GetController("HotbarController")
	InventoryController = Knit.GetController("InventoryController")
	ActionWheelController = Knit.GetController("ActionWheelController")
end

function ConsoleHotbarController.KnitStart()
	local PlayerGui = Player:WaitForChild("PlayerGui") :: PlayerGui
	local Hud = PlayerGui:WaitForChild("Hud") :: ScreenGui
	Wheel = Hud:WaitForChild("ConsoleHotbar") :: ScreenGui
	Background = Wheel:WaitForChild("Background") :: Frame
	Background.Visible = false
	Wheel.Enabled = true
	Wheel.DisplayOrder = 30
	if not Wheel:FindFirstChild("Enabler") then
		local Enabler = Instance.new("BoolValue")
		Enabler.Name = "Enabler"
		Enabler.Parent = Wheel
	end

	for _, Slice in Background:GetChildren() do
		local Order = tonumber(Slice.Name)
		if Slice:IsA("ImageLabel") and Order and Order >= 1 and Order <= 10 then
			local Index = Order % 10
			local NameLabel = Slice:WaitForChild("ItemName") :: TextLabel
			Slots[Index] = {
				Index = Index, Slice = Slice, Rotation = Slice.Rotation, Color = Slice.ImageColor3,
				NameLabel = NameLabel, IndexLabel = Slice:WaitForChild("HotbarIndex") :: TextLabel,
				AmountLabel = Slice:WaitForChild("ItemAmount") :: TextLabel,
				TextColor = NameLabel.TextColor3, Images = Slice:QueryDescendants("ImageLabel") :: { ImageLabel },
			}
			ConsoleHotbarController:RefreshSlot(Index)
		end
	end

	HotbarController.Updated:Connect(function(Index: number)
		ConsoleHotbarController:RefreshSlot(Index)
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		ConsoleHotbarController:Close()
	end)
	UserInputService.GamepadDisconnected:Connect(function(InputType: Enum.UserInputType)
		if Gamepad == InputType then
			ConsoleHotbarController:Close()
		end
	end)
	GuiService:GetPropertyChangedSignal("MenuIsOpen"):Connect(function()
		if GuiService.MenuIsOpen then
			ConsoleHotbarController:Close()
		end
	end)
	Wheel:GetPropertyChangedSignal("Enabled"):Connect(function()
		if not Wheel.Enabled then
			ConsoleHotbarController:Close()
		end
	end)
	Player.CharacterRemoving:Connect(function()
		ConsoleHotbarController:Close()
	end)
	for _, Attribute in { "InDialog", "InIntroCutscene" } do
		Player:GetAttributeChangedSignal(Attribute):Connect(function()
			if Player:GetAttribute(Attribute) then
				ConsoleHotbarController:Close()
			end
		end)
	end
	local function BindCharacter(Character: Model)
		for _, Attribute in BlockedAttributes do
			Character:GetAttributeChangedSignal(Attribute):Connect(function()
				if Character:GetAttribute(Attribute) then
					ConsoleHotbarController:Close()
				end
			end)
		end
	end
	Player.CharacterAdded:Connect(BindCharacter)
	if Player.Character then
		BindCharacter(Player.Character)
	end

	Ready = true
	ContextActionService:BindActionAtPriority("ConsoleHotbarToggle", ToggleInput, false, PRIORITY, Enum.KeyCode.ButtonR1)
end

return ConsoleHotbarController
