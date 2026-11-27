local Players = game:GetService("Players")
local GamepadService = game:GetService("GamepadService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local InventoryGrid = require(ReplicatedStorage.Shared.Utils.InventoryGrid)
local InventoryEquipmentSlots = require(ReplicatedStorage.Shared.Utils.InventoryEquipmentSlots)
local InventoryStacks = require(ReplicatedStorage.Shared.Utils.InventoryStacks)
local ItemDefinitions = require(ReplicatedStorage.Shared.Index.Items)

type ItemData = { [string]: any }
type StrokeHighlight = { Stroke: UIStroke, Color: Color3, Enabled: boolean }
type DragState = {
	Button: ImageButton,
	Item: ItemData,
	Input: InputObject,
	Gamepad: Enum.UserInputType?,
	Latched: boolean?,
	Start: Vector2,
	Pointer: Vector2,
	Fraction: Vector2,
	Rotated: boolean,
	Started: boolean,
	Ghost: ImageButton?,
	Candidate: InventoryGrid.Placement?,
	Slot: string?,
	HotbarSlot: number?,
	HotbarButton: ImageButton?,
	SourceHotbarSlot: number?,
	SourceSize: Vector2,
	DeleteTarget: boolean?,
	DropTarget: boolean?,
	MergeTarget: string?,
	Valid: boolean,
}

local InventoryDragController = Knit.CreateController({ Name = "InventoryDragController" })
local InventoryController
local InventoryService
local HotbarController
local InventoryDeleteController
local InventoryDropController
local InventoryModalController
local Context: ItemData?
local Layout: ItemData?
local Items: { [string]: ItemData } = {}
local InventoryEntries: { ItemData } = {}
local Equipped: { [string]: ItemData } = {}
local Buttons: { [string]: ImageButton } = {}
local State: DragState?
type GamepadSelection = {
	Button: ImageButton,
	Item: ItemData,
	Input: InputObject,
	SourceHotbarSlot: number?,
	Drag: DragState?,
	Details: boolean?,
}
local Selection: GamepadSelection?
local RotationButton: ImageButton?
local Suppressed: { [ImageButton]: number } = setmetatable({}, { __mode = "k" })
local RequestId = 0
local PendingId: number?
local Overlays: { Instance } = {}
local DropHighlights: { [GuiObject]: StrokeHighlight } = {}
local CompatibleButtons: { [GuiObject]: boolean } = {}
local HoveredButton: GuiObject?
local White = Color3.new(1, 1, 1)
local Green = Color3.fromRGB(65, 220, 100)
local Red = Color3.fromRGB(240, 65, 65)

local function RotationHint(): string
	return if UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then "X  /  ROTATE" else "R  /  ROTATE"
end

local function CursorPosition(): Vector3
	local Point = UserInputService:GetMouseLocation()
	return Vector3.new(Point.X, Point.Y, 0)
end

local function Contains(Object: GuiObject, Point: Vector2): boolean
	local Position, Size = Object.AbsolutePosition, Object.AbsoluteSize
	return Point.X >= Position.X
		and Point.Y >= Position.Y
		and Point.X < Position.X + Size.X
		and Point.Y < Position.Y + Size.Y
end

local function Pointer(Position: Vector3): Vector2
	local Inset = if Context and not Context.Main.IgnoreGuiInset then GuiService:GetGuiInset() else Vector2.zero
	return Vector2.new(Position.X, Position.Y) - Inset
end

local function IsVisible(Object: GuiObject): boolean
	local Ancestor: Instance? = Object
	while Ancestor do
		if Ancestor:IsA("GuiObject") and not Ancestor.Visible then
			return false
		end
		if Ancestor:IsA("ScreenGui") then
			return Ancestor.Enabled
		end
		Ancestor = Ancestor.Parent
	end

	return false
end

local function RestoreHighlight(Button: GuiObject)
	local Highlight = DropHighlights[Button]
	if Highlight then
		if Highlight.Stroke.Parent then
			Highlight.Stroke.Color = Highlight.Color
			Highlight.Stroke.Enabled = Highlight.Enabled
		end
		DropHighlights[Button] = nil
	end
end

local function HighlightSlot(Button: GuiObject, Color: Color3)
	local Highlight = DropHighlights[Button]
	if not Highlight then
		local Stroke = Button:FindFirstChildWhichIsA("UIStroke")
		if not Stroke then
			return
		end
		Highlight = { Stroke = Stroke, Color = Stroke.Color, Enabled = Stroke.Enabled }
		DropHighlights[Button] = Highlight
	end

	Highlight.Stroke.Color = Color
	Highlight.Stroke.Enabled = true
end

local function ClearHoveredHighlight()
	if HoveredButton then
		if CompatibleButtons[HoveredButton] then
			HighlightSlot(HoveredButton, Green)
		else
			RestoreHighlight(HoveredButton)
		end
		HoveredButton = nil
	end
end

local function HoverHighlight(Button: GuiObject, Valid: boolean)
	HoveredButton = Button
	HighlightSlot(Button, if Valid then Green else Red)
end

local function ClearDropHighlights()
	HoveredButton = nil
	table.clear(CompatibleButtons)
	for Button in DropHighlights do
		RestoreHighlight(Button)
	end
end

local function ClearOverlays()
	for _, Overlay in Overlays do
		Overlay:Destroy()
	end
	table.clear(Overlays)

	if Context then
		Context.Preview.Visible = false
	end
end

local function Overlay(Parent: GuiObject, Position: UDim2, Size: UDim2, Color: Color3): Frame
	local Frame = Instance.new("Frame")
	Frame.Name = "DropFeedback"
	Frame.Position = Position
	Frame.Size = Size
	Frame.BackgroundColor3 = Color
	Frame.BackgroundTransparency = 0.75
	Frame.BorderSizePixel = 0
	Frame.ZIndex = 28
	Frame.Parent = Parent
	local Stroke = Instance.new("UIStroke")
	Stroke.Color = Color
	Stroke.Thickness = 2
	Stroke.Parent = Frame
	table.insert(Overlays, Frame)

	return Frame
end

function InventoryDragController:Configure(Configuration: ItemData)
	Context = Configuration
	Context.Preview = Configuration.Canvas:WaitForChild("PlacementPreview") :: Frame
	Context.DragLayer = Configuration.Main:WaitForChild("DragLayer") :: Frame
	Context.RotateButton = Configuration.Panel:WaitForChild("RotateButton") :: TextButton
	Context.RotateHint = Configuration.Panel:WaitForChild("RotateHint") :: TextLabel
	Context.DeleteTarget = Configuration.Panel:WaitForChild("Delete") :: ImageLabel
	Context.DropTarget = Configuration.Panel:WaitForChild("Drop") :: ImageLabel
	Context.Preview.ZIndex = 25
	Context.RotateHint.Visible = false
	Context.RotateButton.Activated:Connect(function()
		self:Rotate()
	end)
	Configuration.Scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		self:UpdatePreview()
	end)
end

function InventoryDragController:SetLayout(Entries: { ItemData }, Snapshot: ItemData?)
	Layout = Snapshot
	InventoryEntries = Entries
	table.clear(Items)
	table.clear(Equipped)

	for _, Item in Entries do
		Items[InventoryStacks.Key(Item)] = Item
		if Item.Class == "Equipable" and Item.Equipped then
			Equipped[Item.Type] = Item
		end
	end

	local WeaponEquipment = Snapshot and Snapshot.WeaponEquipment
	for _, Definition in InventoryEquipmentSlots.Weapons do
		local Name = WeaponEquipment and WeaponEquipment[Definition.Name]
		if Name then
			Equipped[Definition.Name] = Items[Name]
		end
	end
	for Name, Button in Buttons do
		if not Items[Name] or not Button.Parent then
			Buttons[Name] = nil
		end
	end
	if State and State.SourceHotbarSlot == nil then
		local Item = Items[InventoryStacks.Key(State.Item)]
		if not Item then
			self:Cancel()
			return
		end
		State.Item = Item
	end
	if State and State.Started then
		self:RefreshDropHighlights()
		self:UpdatePreview()
	end
end

function InventoryDragController:RemoveItem(Name: string)
	if State and State.SourceHotbarSlot == nil and InventoryStacks.Key(State.Item) == Name then
		self:Cancel()
	end
	Buttons[Name] = nil
	Items[Name] = nil
end

function InventoryDragController:ConsumesClick(Button: ImageButton): boolean
	return (Suppressed[Button] or 0) > os.clock()
end

function InventoryDragController:IsDragging(): boolean
	return State ~= nil and State.Started
end

function InventoryDragController:HasGamepadDrag(): boolean
	return State ~= nil and State.Gamepad ~= nil
end

function InventoryDragController:SetSlotStrokeColor(Button: ImageButton, Color: Color3)
	local Highlight = DropHighlights[Button]
	if Highlight then
		Highlight.Color = Color
		return
	end

	local Stroke = Button:FindFirstChildWhichIsA("UIStroke")
	if Stroke and Stroke.Color ~= Color then
		Stroke.Color = Color
	end
end

function InventoryDragController:UpdateLayout(Snapshot: ItemData)
	Layout = Snapshot
	for Name, Item in Items do
		Item.InventoryPosition = Snapshot.Positions[Name]
		Item.Rotated = Item.InventoryPosition and Item.InventoryPosition.Rotated or false
	end

	if State and State.Started then
		self:RefreshDropHighlights()
		self:UpdatePreview()
	end
end

function InventoryDragController:BindItem(Button: ImageButton, Item: ItemData)
	Buttons[InventoryStacks.Key(Item)] = Button
	Button.InputBegan:Connect(function(Input: InputObject)
		self:BeginDrag(Button, Items[InventoryStacks.Key(Item)] or Item, Input)
	end)
end

function InventoryDragController:BeginDrag(
	Button: ImageButton,
	Item: ItemData,
	Input: InputObject,
	SourceHotbarSlot: number?
)
	local GamepadInput = (Input.KeyCode == Enum.KeyCode.ButtonR2 or Input.KeyCode == Enum.KeyCode.ButtonA)
		and Input.UserInputType.Name:match("^Gamepad") ~= nil
	if Input.UserInputType == Enum.UserInputType.MouseButton1 and GamepadService.GamepadCursorEnabled
		and UserInputService.PreferredInput == Enum.PreferredInput.Gamepad then
		return
	end

	if
		not Context
		or State
		or PendingId
		or InventoryModalController:IsOpen()
		or not InventoryController:IsOpen()
		or (SourceHotbarSlot == nil and (not Layout or not InventoryController:CanDragItems()))
		or (not GamepadInput and Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch)
	then
		return
	end

	local Point = Pointer(if GamepadInput then CursorPosition() else Input.Position)
	local Size = Button.AbsoluteSize
	State = {
		Button = Button,
		Item = Item,
		Input = Input,
		Gamepad = if GamepadInput then Input.UserInputType else nil,
		Start = Point,
		Pointer = Point,
		Fraction = Vector2.new(
			math.clamp((Point.X - Button.AbsolutePosition.X) / Size.X, 0, 1),
			math.clamp((Point.Y - Button.AbsolutePosition.Y) / Size.Y, 0, 1)
		),
		Rotated = Button:GetAttribute("Rotated") == true,
		Started = false,
		Valid = false,
		SourceHotbarSlot = SourceHotbarSlot,
		SourceSize = Size,
	}
	if GamepadInput then
		Suppressed[Button] = math.huge
	end
end

local function GetGamepadTarget(): (ImageButton?, ItemData?, number?)
	if not Context or not InventoryController:IsOpen() then
		return nil, nil, nil
	end

	local Point = Pointer(CursorPosition())
	local Target: ImageButton? = nil
	local Item: ItemData? = nil
	if Contains(Context.Scroll, Point) then
		for Id, Button in Buttons do
			if Items[Id] and IsVisible(Button) and Contains(Button, Point) and (not Target or Button.ZIndex > Target.ZIndex) then
				Target, Item = Button, Items[Id]
			end
		end
	end

	if Target and Item then
		return Target, Item, nil
	end

	local Index, Button = HotbarController:GetSlotAtPoint(Point)
	local Tool = if Index then HotbarController:GetToolInHotbarIndex(Index) else nil
	if Index and Button and Tool then
		local Data = Tool:GetAttributes()
		Data.Name = Tool.Name
		return Button, Data, Index
	end
	return nil, nil, nil
end

function InventoryDragController:BeginGamepadDrag(Input: InputObject): boolean
	if State or Selection then
		return false
	end

	local Button, Item, Index = GetGamepadTarget()
	if Button and Item then
		self:BeginDrag(Button, Item, Input, Index)
	end
	return State ~= nil and State.Input == Input
end

function InventoryDragController:CancelGamepadSelection()
	if Selection then
		Suppressed[Selection.Button] = os.clock() + 0.25
		Selection = nil
	end
end

function InventoryDragController:BeginGamepadSelection(Input: InputObject): boolean
	if Selection or InventoryModalController:IsOpen() then
		return false
	end
	if State then
		if State.Gamepad ~= Input.UserInputType then
			return false
		end
		Selection = { Button = State.Button, Item = State.Item, Input = Input, Drag = State,
			SourceHotbarSlot = State.SourceHotbarSlot }
	else
		local Button, Item, Index = GetGamepadTarget()
		if not Button or not Item then
			return false
		end
		Selection = { Button = Button, Item = Item, Input = Input, SourceHotbarSlot = Index }
	end
	Suppressed[Selection.Button] = math.huge
	return true
end

local function GetSelection(Input: InputObject): GamepadSelection?
	if not Selection or Selection.Input.UserInputType ~= Input.UserInputType
		or not Selection.Button.Parent or not InventoryController:IsOpen() or InventoryModalController:IsOpen() then
		return nil
	end
	if Selection.SourceHotbarSlot == nil and not Items[Selection.Button.Name] then
		return nil
	end
	return Selection
end

function InventoryDragController:ShowGamepadDetails(Input: InputObject): boolean
	local Current = GetSelection(Input)
	if not Current or Current.Details then
		return false
	end

	self:Cancel()
	InventoryController:Select(Current.Button, Items[Current.Button.Name] or Current.Item)
	Current.Details = true
	Selection = Current
	Suppressed[Current.Button] = math.huge
	return true
end

function InventoryDragController:ConfirmGamepadSelection(Input: InputObject)
	local Current = GetSelection(Input)
	self:CancelGamepadSelection()
	if not Current or Current.Details then
		return
	end

	if Current.Drag then
		if State == Current.Drag then
			self:UpdateGamepadPointer()
			self:Drop()
		end
		return
	end
	self:BeginDrag(Current.Button, Items[Current.Button.Name] or Current.Item, Input, Current.SourceHotbarSlot)
	if State then
		State.Latched = true
		self:StartDrag()
		self:UpdateGamepadPointer()
	elseif Current.SourceHotbarSlot == nil and not InventoryController:CanDragItems() then
		InventoryController:Select(Current.Button, Current.Item)
	end
end

function InventoryDragController:UpdateGamepadPointer()
	local Drag = State
	if not Drag or not Drag.Gamepad then
		return
	end

	Drag.Pointer = Pointer(CursorPosition())
	if not Drag.Started and not Selection and (Drag.Pointer - Drag.Start).Magnitude >= 6 then
		self:StartDrag()
	end
	self:UpdatePreview()
end

function InventoryDragController:EndGamepadDrag(Input: InputObject, InputState: Enum.UserInputState): boolean
	local Drag = State
	if not Drag or Drag.Latched or Drag.Gamepad ~= Input.UserInputType or Input.KeyCode ~= Enum.KeyCode.ButtonR2
		or Drag.Input.KeyCode ~= Enum.KeyCode.ButtonR2 then
		return false
	end
	if InputState == Enum.UserInputState.Cancel then
		self:Cancel()
	elseif InputState == Enum.UserInputState.End then
		self:UpdateGamepadPointer()
		if Drag.Started then
			self:Drop()
		else
			self:Cancel()
			if Drag.SourceHotbarSlot == nil then
				if InventoryController:GetSelected() == Drag.Button then
					InventoryController:Unselect()
				else
					InventoryController:Select(Drag.Button, Drag.Item)
				end
			end
		end
	end
	return true
end

function InventoryDragController:BeginHotbarDrag(Button: ImageButton, Index: number, Tool: Tool, Input: InputObject)
	local Item = Tool:GetAttributes()
	Item.Name = Tool.Name
	self:BeginDrag(Button, Item, Input, Index)
end

function InventoryDragController:StartDrag()
	local Drag = State
	if not Context or not Drag then
		return
	end

	Drag.Started = true
	Suppressed[Drag.Button] = math.huge
	InventoryController:Unselect()
	local Ghost = Drag.Button:Clone()
	Ghost.Name = "DraggedItem"
	Ghost.Interactable = false
	Ghost.AnchorPoint = Vector2.zero
	Ghost.ZIndex = 32
	for _, Object in Ghost:QueryDescendants("GuiObject") do
		Object.ZIndex += 32
		Object.Active = false
	end
	Ghost.Parent = Context.DragLayer
	Drag.Ghost = Ghost
	if Drag.SourceHotbarSlot == nil then
		Drag.Button.Visible = false
	end
	Context.Scroll.ScrollingEnabled = Drag.Input.UserInputType ~= Enum.UserInputType.Touch
	Context.RotateButton.Visible = Drag.SourceHotbarSlot == nil
	Context.RotateHint.Text = RotationHint()
	Context.RotateHint.Visible = Drag.SourceHotbarSlot == nil
	self:RenderGhost()
	self:RefreshDropHighlights()
end

function InventoryDragController:RenderGhost()
	local Drag = State
	if not Drag or not Drag.Ghost then
		return
	end
	if Drag.SourceHotbarSlot ~= nil then
		self:UpdatePreview()
		return
	end

	local Placement = InventoryGrid.Placement(Drag.Item, 1, 1, Drag.Rotated)
	InventoryController:RenderItemVisual(Drag.Ghost, Drag.Item, nil, Placement)

	self:UpdatePreview()
end

function InventoryDragController:Rotate()
	if not State or State.SourceHotbarSlot ~= nil then
		return
	end
	if not State.Started then
		if not State.Gamepad then
			return
		end
		self:StartDrag()
	end

	State.Rotated = not State.Rotated
	State.Fraction = Vector2.new(1 - State.Fraction.Y, State.Fraction.X)
	self:RenderGhost()
end

function InventoryDragController:EndGamepadRotation()
	if RotationButton then
		Suppressed[RotationButton] = os.clock() + 0.25
		RotationButton = nil
	end
end

function InventoryDragController:RotateSelected(): boolean
	if not Context or State or not Layout or not InventoryController:CanDragItems() or InventoryModalController:IsOpen() then
		return false
	end

	local Button = InventoryController:GetSelected()
	local Item = Button and Items[Button.Name]
	local Position = Button and Layout.Positions[Button.Name]
	if not Button or not Item or not Position then
		return false
	end

	RotationButton = Button
	Suppressed[Button] = math.huge
	if PendingId then
		return true
	end

	local Candidate = InventoryGrid.Placement(Item, Position.Column, Position.Row, not Position.Rotated)
	if not InventoryGrid.Fits(Layout.Positions, Candidate, Layout.Columns, Layout.Rows, Button.Name) then
		Context.RotateHint.Text = "Not enough space to rotate"
		Context.RotateHint.Visible = true
		task.delay(3, function()
			if Context and not State then
				Context.RotateHint.Visible = false
				Context.RotateHint.Text = RotationHint()
			end
		end)
		return true
	end

	if self:SubmitAction({
		Kind = "Move", Name = Button.Name, Column = Candidate.Column, Row = Candidate.Row,
		Rotated = Candidate.Rotated, Revision = Layout.Revision,
	}) then
		InventoryController:ApplyEntryPlacement(Button, Candidate)
	end
	return true
end

function InventoryDragController:CanEquipSlot(Item: ItemData, Slot: string): boolean
	if not Layout or not InventoryEquipmentSlots.Accepts(Item, Slot, Layout.WeaponEquipment) then
		return false
	end
	local WeaponSlot = InventoryEquipmentSlots.IsWeaponSlot(Slot)
	if
		(WeaponSlot and Equipped[Slot] and InventoryStacks.Key(Equipped[Slot]) == InventoryStacks.Key(Item))
		or (not WeaponSlot and Item.Equipped)
	then
		return false
	end

	local CurrentEquipment = Layout.Equipped or {}
	local NextEquipment = InventoryEquipmentSlots.WithSlot(CurrentEquipment, Slot, InventoryStacks.Key(Item))
	return InventoryEquipmentSlots.PlanLayout(
		InventoryEntries,
		CurrentEquipment,
		NextEquipment,
		Layout.Hotbar or {},
		Layout,
		InventoryStacks.Key(Item)
	) ~= nil
end

function InventoryDragController:RefreshDropHighlights()
	local Drag = State
	if not Context or not Drag or not Drag.Started then
		ClearDropHighlights()
		return
	end

	local Targets: { [GuiObject]: boolean } = {}
	if Drag.SourceHotbarSlot == nil then
		for Slot, Button in Context.EquipmentButtons do
			if IsVisible(Button) and self:CanEquipSlot(Drag.Item, Slot) then
				Targets[Button] = true
			end
		end
		for Id, Button in Buttons do
			if IsVisible(Button) and self:CanMerge(Drag.Item, Id) then
				Targets[Button] = true
			end
		end
	end
	for Index, Button in HotbarController:GetSlotButtons() do
		local Allowed = if Drag.SourceHotbarSlot ~= nil
			then Index ~= Drag.SourceHotbarSlot and HotbarController:CanMoveSlot(
				Drag.SourceHotbarSlot,
				Index,
				InventoryStacks.Key(Drag.Item)
			)
			else HotbarController:CanAssignItem(Drag.Item, Index)
		if Allowed and IsVisible(Button) then
			Targets[Button] = true
		end
	end

	CompatibleButtons = Targets
	if HoveredButton and not IsVisible(HoveredButton) then
		HoveredButton = nil
	end
	for Button in DropHighlights do
		if not Targets[Button] and Button ~= HoveredButton then
			RestoreHighlight(Button)
		end
	end
	for Button in Targets do
		HighlightSlot(Button, Green)
	end
	if HoveredButton and not Targets[HoveredButton] then
		HighlightSlot(HoveredButton, Red)
	end
end

function InventoryDragController:PreviewEquipment(Drag: DragState): boolean
	if not Context or not Layout then
		return false
	end

	for Slot, Button in Context.EquipmentButtons do
		if not IsVisible(Button) or not Contains(Button, Drag.Pointer) then
			continue
		end

		Drag.Slot = Slot
		Drag.Valid = self:CanEquipSlot(Drag.Item, Slot)

		HoverHighlight(Button, Drag.Valid)
		return true
	end

	return false
end

function InventoryDragController:PreviewHotbar(Drag: DragState): boolean
	if not Context then
		return false
	end

	local Index, Button = HotbarController:GetSlotAtPoint(Drag.Pointer)
	if Index == nil or not Button then
		return false
	end

	Drag.HotbarSlot = Index
	Drag.HotbarButton = Button
	Drag.Valid = if Drag.SourceHotbarSlot ~= nil
		then HotbarController:CanMoveSlot(Drag.SourceHotbarSlot, Index, InventoryStacks.Key(Drag.Item))
		else HotbarController:CanAssignItem(Drag.Item, Index)
	HoverHighlight(Button, Drag.Valid)

	return true
end

function InventoryDragController:PreviewDelete(Drag: DragState): boolean
	local Target = Context and Context.DeleteTarget :: ImageLabel?
	if not Target or not IsVisible(Target) or not Contains(Target, Drag.Pointer) then
		return false
	end

	Drag.DeleteTarget = true
	Drag.Valid = InventoryDeleteController:CanDelete(InventoryStacks.Key(Drag.Item))
	HoverHighlight(Target, false)
	return true
end

function InventoryDragController:PreviewDrop(Drag: DragState): boolean
	local Target = Context and Context.DropTarget :: ImageLabel?
	if not Target or not IsVisible(Target) or not Contains(Target, Drag.Pointer) then
		return false
	end

	Drag.DropTarget = true
	Drag.Valid = InventoryDropController:CanDrop(InventoryStacks.Key(Drag.Item))
	HoverHighlight(Target, Drag.Valid)
	return true
end

function InventoryDragController:CanMerge(Item: ItemData, TargetId: string): boolean
	local Source = Items[InventoryStacks.Key(Item)]
	local Target = Items[TargetId]
	local Definition = Source and ItemDefinitions[Source.Name]
	if
		not Source
		or not Target
		or not Definition
		or Source.UsesInventoryGrid == false
		or Target.UsesInventoryGrid == false
	then
		return false
	end

	return InventoryStacks.MergeAmount(Source, Target, Definition.MaxStack or 1) > 0
end

function InventoryDragController:PreviewMerge(Drag: DragState): boolean
	if not Context or not Layout or not Contains(Context.Scroll, Drag.Pointer) then
		return false
	end
	for Id, Button in Buttons do
		local Target = Items[Id]
		if
			Id ~= InventoryStacks.Key(Drag.Item)
			and Target
			and Target.Name == Drag.Item.Name
			and IsVisible(Button)
			and Contains(Button, Drag.Pointer)
		then
			Drag.MergeTarget = Id
			Drag.Valid = self:CanMerge(Drag.Item, Id)
			HoverHighlight(Button, Drag.Valid)
			return true
		end
	end

	return false
end

function InventoryDragController:UpdatePreview()
	local Drag = State
	if not Context or not Drag or not Drag.Started or not Drag.Ghost then
		return
	end

	ClearOverlays()
	ClearHoveredHighlight()
	Drag.Valid = false
	Drag.Candidate = nil
	Drag.Slot = nil
	Drag.HotbarSlot = nil
	Drag.HotbarButton = nil
	Drag.DeleteTarget = nil
	Drag.DropTarget = nil
	Drag.MergeTarget = nil
	local Layer = Context.DragLayer
	if Drag.SourceHotbarSlot ~= nil then
		local Size = Drag.SourceSize
		local TopLeft = Drag.Pointer - Vector2.new(Size.X * Drag.Fraction.X, Size.Y * Drag.Fraction.Y)
		Drag.Ghost.Size = UDim2.fromScale(Size.X / Layer.AbsoluteSize.X, Size.Y / Layer.AbsoluteSize.Y)
		Drag.Ghost.Position = UDim2.fromScale(
			(TopLeft.X - Layer.AbsolutePosition.X) / Layer.AbsoluteSize.X,
			(TopLeft.Y - Layer.AbsolutePosition.Y) / Layer.AbsoluteSize.Y
		)
		if not self:PreviewDelete(Drag) and not self:PreviewDrop(Drag) then
			self:PreviewHotbar(Drag)
		end
		return
	end
	if not Layout then
		return
	end

	local Cell = Context.Canvas.AbsoluteSize.X / Layout.Columns
	local Candidate = InventoryGrid.Placement(Drag.Item, 1, 1, Drag.Rotated)
	local Size = Vector2.new(Candidate.Width * Cell, Candidate.Height * Cell)
	local TopLeft = Drag.Pointer - Vector2.new(Size.X * Drag.Fraction.X, Size.Y * Drag.Fraction.Y)
	Drag.Ghost.Size = UDim2.fromScale(Size.X / Layer.AbsoluteSize.X, Size.Y / Layer.AbsoluteSize.Y)
	Drag.Ghost.Position = UDim2.fromScale(
		(TopLeft.X - Layer.AbsolutePosition.X) / Layer.AbsoluteSize.X,
		(TopLeft.Y - Layer.AbsolutePosition.Y) / Layer.AbsoluteSize.Y
	)

	if
		self:PreviewDelete(Drag)
		or self:PreviewDrop(Drag)
		or self:PreviewHotbar(Drag)
		or Drag.Item.Class == "Skill"
		or self:PreviewEquipment(Drag)
		or not Contains(Context.Scroll, Drag.Pointer)
		or self:PreviewMerge(Drag)
	then
		return
	end

	Candidate.Column = math.floor((TopLeft.X - Context.Canvas.AbsolutePosition.X) / Cell + 0.5) + 1
	Candidate.Row = math.floor((TopLeft.Y - Context.Canvas.AbsolutePosition.Y) / Cell + 0.5) + 1
	Drag.Candidate = Candidate
	local Blockers, Outside =
		InventoryGrid.Blockers(Layout.Positions, Candidate, Layout.Columns, Layout.Rows, InventoryStacks.Key(Drag.Item))
	Drag.Valid = not Outside and #Blockers == 0
	local DisplayRows = Context.Canvas.AbsoluteSize.Y / Cell
	local Preview = Context.Preview
	Preview.Position = UDim2.fromScale((Candidate.Column - 1) / Layout.Columns, (Candidate.Row - 1) / DisplayRows)
	Preview.Size = UDim2.fromScale(Candidate.Width / Layout.Columns, Candidate.Height / DisplayRows)
	Preview.BackgroundColor3 = White
	Preview.BackgroundTransparency = 0.8
	local Border = Preview:FindFirstChildWhichIsA("UIStroke")
	if Border then
		Border.Color = if Drag.Valid then White else Red
	end
	Preview.Visible = true

	for _, Name in Blockers do
		local Button = Buttons[Name]
		if Button then
			Overlay(Context.Canvas, Button.Position, Button.Size, Red)
		end
	end
	if Outside then
		local Boundary =
			Overlay(Context.Canvas, UDim2.fromScale(0, 0), UDim2.fromScale(1, Layout.Rows / DisplayRows), Red)
		Boundary.BackgroundTransparency = 1
	end
end

function InventoryDragController:Cancel()
	self:CancelGamepadSelection()
	self:EndGamepadRotation()
	local Drag = State
	State = nil
	ClearOverlays()
	ClearDropHighlights()
	if Drag then
		if Drag.Started or Drag.Gamepad then
			Suppressed[Drag.Button] = os.clock() + 0.25
		end
		if Drag.Button.Parent then
			Drag.Button.Visible = true
		end
		if Drag.Ghost then
			Drag.Ghost:Destroy()
		end
	end

	if Context then
		Context.Scroll.ScrollingEnabled = true
		Context.RotateButton.Visible = false
		Context.RotateHint.Visible = false
	end
end

function InventoryDragController:Drop()
	local Drag = State
	if Drag and Drag.Started and Drag.HotbarButton then
		Suppressed[Drag.HotbarButton] = os.clock() + 0.25
	end
	if Drag and Drag.Started and Drag.MergeTarget and Buttons[Drag.MergeTarget] then
		Suppressed[Buttons[Drag.MergeTarget]] = os.clock() + 0.25
	end

	if
		not Drag
		or not Drag.Started
		or not Drag.Valid
		or (not Layout and Drag.SourceHotbarSlot == nil)
		or (Drag.SourceHotbarSlot ~= nil and Drag.SourceHotbarSlot == Drag.HotbarSlot)
	then
		self:Cancel()
		return
	end

	if Drag.DeleteTarget then
		local Name = InventoryStacks.Key(Drag.Item)
		self:Cancel()
		InventoryDeleteController:Begin(Name)
		return
	end
	if Drag.DropTarget then
		local Name = InventoryStacks.Key(Drag.Item)
		self:Cancel()
		InventoryDropController:Begin(Name)
		return
	end
	if Drag.MergeTarget then
		local Target = Items[Drag.MergeTarget]
		local Request = {
			Kind = "Merge",
			Name = InventoryStacks.Key(Drag.Item),
			Target = Drag.MergeTarget,
			Stack = Drag.Item.Stack,
			TargetStack = Target and Target.Stack,
			Revision = Layout and Layout.Revision,
		}
		self:Cancel()
		self:SubmitAction(Request)
		return
	end

	local Candidate = Drag.Candidate
	local Request = {
		Kind = if Drag.SourceHotbarSlot ~= nil
			then "MoveHotbar"
			elseif Drag.HotbarSlot ~= nil then "Hotbar"
			elseif Drag.Slot then "Equip"
			else "Move",
		Name = InventoryStacks.Key(Drag.Item),
		Slot = Drag.Slot,
		Index = Drag.HotbarSlot,
		SourceIndex = Drag.SourceHotbarSlot,
		Column = Candidate and Candidate.Column,
		Row = Candidate and Candidate.Row,
		Rotated = Drag.Rotated,
		Revision = Layout and Layout.Revision,
	}

	if Candidate and not Drag.Slot then
		InventoryController:ApplyEntryPlacement(Drag.Button, Candidate)
	end

	self:Cancel()
	self:SubmitAction(Request)
end

function InventoryDragController:SubmitAction(Request: ItemData): boolean
	if PendingId then
		return false
	end
	RequestId += 1
	PendingId = RequestId
	Request.Id = RequestId
	InventoryService.InventoryAction:Fire(Request)
	local Id = RequestId
	task.delay(8, function()
		if PendingId == Id then
			PendingId = nil
			InventoryController:UpdateContent(true)
		end
	end)
	return true
end

function InventoryDragController.KnitInit()
	InventoryController = Knit.GetController("InventoryController")
	InventoryService = Knit.GetService("InventoryService")
	HotbarController = Knit.GetController("HotbarController")
	InventoryDeleteController = Knit.GetController("InventoryDeleteController")
	InventoryDropController = Knit.GetController("InventoryDropController")
	InventoryModalController = Knit.GetController("InventoryModalController")
end

function InventoryDragController.KnitStart()
	Players.LocalPlayer:GetMouse().Move:Connect(function()
		InventoryDragController:UpdateGamepadPointer()
	end)
	UserInputService.InputChanged:Connect(function(Input: InputObject)
		local Drag = State
		if Drag and Drag.Gamepad then
			if Input.UserInputType == Enum.UserInputType.MouseMovement then
				InventoryDragController:UpdateGamepadPointer()
			end
			return
		end
		if not Drag or (Input.UserInputType ~= Enum.UserInputType.MouseMovement and Input ~= Drag.Input) then
			return
		end

		Drag.Pointer = Pointer(Input.Position)
		if not Drag.Started and (Drag.Pointer - Drag.Start).Magnitude >= 6 then
			InventoryDragController:StartDrag()
		end
		InventoryDragController:UpdatePreview()
	end)
	UserInputService.InputEnded:Connect(function(Input: InputObject)
		if
			State
			and not State.Gamepad
			and (
				Input == State.Input
				or (
					State.Input.UserInputType == Enum.UserInputType.MouseButton1
					and Input.UserInputType == Enum.UserInputType.MouseButton1
				)
			)
		then
			InventoryDragController:Drop()
		end
	end)
	UserInputService.InputBegan:Connect(function(Input: InputObject)
		if Input.KeyCode == Enum.KeyCode.R and not UserInputService:GetFocusedTextBox() then
			InventoryDragController:Rotate()
		elseif Input.KeyCode == Enum.KeyCode.Escape then
			InventoryDragController:Cancel()
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		InventoryDragController:Cancel()
	end)
	Players.LocalPlayer.CharacterRemoving:Connect(function()
		InventoryDragController:Cancel()
	end)
	InventoryService.InventoryActionResult:Connect(
		function(Id: number, Success: boolean, Reason: string?, Correction: ItemData?)
			if Id ~= PendingId then
				return
			end

			PendingId = nil
			if not Success then
				if not Correction or not InventoryController:ApplyLayout(Correction) then
					InventoryController:UpdateContent(true)
				end
			end
			if not Success and Reason and Context and Context.Main.Enabled then
				Context.RotateHint.Text = Reason
				Context.RotateHint.Visible = true
				task.delay(3, function()
					if Context and not State then
						Context.RotateHint.Visible = false
						Context.RotateHint.Text = RotationHint()
					end
				end)
			end
		end
	)
end

return InventoryDragController
