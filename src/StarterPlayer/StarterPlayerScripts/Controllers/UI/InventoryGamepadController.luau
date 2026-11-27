local ContextActionService = game:GetService("ContextActionService")
local GamepadService = game:GetService("GamepadService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local InventoryGamepadController = Knit.CreateController({ Name = "InventoryGamepadController" })
local PRIORITY = Enum.ContextActionPriority.High.Value + 30
local DRAG_HOLD_TIME = 0.5

local InventoryController
local InventoryDragController
local InventoryModalController
local MainMenu: ScreenGui
local CursorActive = false
local OwnsCursor = false
local PreviousSelection: GuiObject? = nil
local RotateHeld = false
local BackHandled = false
type SelectionPress = { Input: InputObject, Started: number, Resolved: boolean, Placing: boolean }
local Press: SelectionPress?

local function CancelSelectionPress()
	Press = nil
	InventoryDragController:CancelGamepadSelection()
end

local function CanHandleInput(): boolean
	return InventoryController:IsOpen() and not GuiService.MenuIsOpen and not UserInputService:GetFocusedTextBox()
end

local function UpdateCursor()
	local Wanted = InventoryController:IsOpen() and not GuiService.MenuIsOpen
		and UserInputService.PreferredInput == Enum.PreferredInput.Gamepad
	if Wanted == CursorActive then
		return
	end

	CursorActive = Wanted
	if Wanted then
		PreviousSelection = GuiService.SelectedObject
		GuiService.SelectedObject = nil
		OwnsCursor = not GamepadService.GamepadCursorEnabled
		GamepadService:EnableGamepadCursor()
	else
		CancelSelectionPress()
		InventoryDragController:Cancel()
		if OwnsCursor then
			GamepadService:DisableGamepadCursor()
		end
		OwnsCursor = false
		if PreviousSelection and PreviousSelection.Parent then
			GuiService.SelectedObject = PreviousSelection
		end
		PreviousSelection = nil
	end
end

local function TabInput(_Name: string, State: Enum.UserInputState, Input: InputObject): Enum.ContextActionResult
	if not CanHandleInput() then
		return Enum.ContextActionResult.Pass
	end

	if State == Enum.UserInputState.Begin then
		CancelSelectionPress()
		InventoryController:CycleTab(if Input.KeyCode == Enum.KeyCode.ButtonL1 then -1 else 1)
	end
	return Enum.ContextActionResult.Sink
end

local function SelectInput(_Name: string, State: Enum.UserInputState, Input: InputObject): Enum.ContextActionResult
	if State == Enum.UserInputState.Begin then
		if Press then
			return Enum.ContextActionResult.Sink
		end
		if not CanHandleInput() or InventoryModalController:IsOpen()
			or not InventoryDragController:BeginGamepadSelection(Input) then
			return Enum.ContextActionResult.Pass
		end

		local Current: SelectionPress = { Input = Input, Started = os.clock(), Resolved = false,
			Placing = InventoryDragController:HasGamepadDrag() }
		Press = Current
		if Current.Placing then
			return Enum.ContextActionResult.Sink
		end

		task.delay(DRAG_HOLD_TIME, function()
			if Press == Current and not Current.Resolved and CanHandleInput() and not InventoryModalController:IsOpen() then
				Current.Resolved = true
				InventoryDragController:ConfirmGamepadSelection(Input)
			end
		end)
	elseif Press and Press.Input.UserInputType == Input.UserInputType then
		if State == Enum.UserInputState.End then
			local Current = Press
			Press = nil
			if not CanHandleInput() or InventoryModalController:IsOpen() then
				InventoryDragController:Cancel()
			elseif Current.Resolved then
				InventoryDragController:CancelGamepadSelection()
			elseif Current.Placing or os.clock() - Current.Started >= DRAG_HOLD_TIME then
				InventoryDragController:ConfirmGamepadSelection(Input)
			else
				InventoryDragController:ShowGamepadDetails(Input)
				InventoryDragController:CancelGamepadSelection()
			end
		elseif State == Enum.UserInputState.Cancel then
			CancelSelectionPress()
			InventoryDragController:Cancel()
		end
	else
		return Enum.ContextActionResult.Pass
	end
	return Enum.ContextActionResult.Sink
end

local function BackInput(_Name: string, State: Enum.UserInputState, _Input: InputObject): Enum.ContextActionResult
	if State ~= Enum.UserInputState.Begin then
		if BackHandled then
			if State == Enum.UserInputState.End or State == Enum.UserInputState.Cancel then
				BackHandled = false
			end
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end

	if not CanHandleInput() or InventoryModalController:IsOpen() then
		return Enum.ContextActionResult.Pass
	end
	if Press or InventoryDragController:IsDragging() or InventoryDragController:HasGamepadDrag()
		or InventoryController:GetSelected() then
		CancelSelectionPress()
		InventoryDragController:Cancel()
		InventoryController:Unselect()
		BackHandled = true
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

local function RotateInput(_Name: string, State: Enum.UserInputState, _Input: InputObject): Enum.ContextActionResult
	if not CanHandleInput() then
		if RotateHeld then
			RotateHeld = false
			InventoryDragController:EndGamepadRotation()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end

	if State == Enum.UserInputState.Begin then
		if Press then
			return Enum.ContextActionResult.Sink
		end
		if InventoryModalController:IsOpen() then
			return Enum.ContextActionResult.Pass
		end
		if InventoryDragController:IsDragging() or InventoryDragController:HasGamepadDrag() then
			InventoryDragController:Rotate()
			RotateHeld = true
		else
			RotateHeld = InventoryDragController:RotateSelected()
		end
	elseif State == Enum.UserInputState.End or State == Enum.UserInputState.Cancel then
		local Handled = RotateHeld
		RotateHeld = false
		InventoryDragController:EndGamepadRotation()
		return if Handled then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
	end
	return if RotateHeld then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
end

local function ClickInput(_Name: string, State: Enum.UserInputState, Input: InputObject): Enum.ContextActionResult
	if InventoryDragController:EndGamepadDrag(Input, State) then
		return Enum.ContextActionResult.Sink
	end
	if not CanHandleInput() or InventoryModalController:IsOpen() then
		return Enum.ContextActionResult.Pass
	end
	if Press or InventoryDragController:HasGamepadDrag() then
		return Enum.ContextActionResult.Sink
	end

	if State == Enum.UserInputState.Begin and InventoryDragController:BeginGamepadDrag(Input) then
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

function InventoryGamepadController.KnitInit()
	InventoryController = Knit.GetController("InventoryController")
	InventoryDragController = Knit.GetController("InventoryDragController")
	InventoryModalController = Knit.GetController("InventoryModalController")
end

function InventoryGamepadController.KnitStart()
	local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local Menus = PlayerGui:WaitForChild("Menu") :: ScreenGui
	MainMenu = (PlayerGui:FindFirstChild("MainMenu") or Menus:WaitForChild("MainMenu")) :: ScreenGui
	MainMenu:GetPropertyChangedSignal("Enabled"):Connect(UpdateCursor)
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(UpdateCursor)
	GuiService:GetPropertyChangedSignal("MenuIsOpen"):Connect(UpdateCursor)
	Players.LocalPlayer.CharacterRemoving:Connect(function()
		CancelSelectionPress()
		InventoryDragController:Cancel()
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		CancelSelectionPress()
		InventoryDragController:Cancel()
	end)
	UserInputService.TextBoxFocused:Connect(CancelSelectionPress)
	UserInputService.GamepadDisconnected:Connect(function()
		CancelSelectionPress()
		InventoryDragController:Cancel()
	end)
	ContextActionService:BindActionAtPriority(
		"InventoryTabs", TabInput, false, PRIORITY, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1
	)
	ContextActionService:BindActionAtPriority("InventorySelect", SelectInput, false, PRIORITY, Enum.KeyCode.ButtonA)
	ContextActionService:BindActionAtPriority("InventoryBack", BackInput, false, PRIORITY, Enum.KeyCode.ButtonB)
	ContextActionService:BindActionAtPriority("InventoryRotate", RotateInput, false, PRIORITY, Enum.KeyCode.ButtonX)
	ContextActionService:BindActionAtPriority("InventoryClick", ClickInput, false, PRIORITY, Enum.KeyCode.ButtonR2)
	UpdateCursor()
end

return InventoryGamepadController
