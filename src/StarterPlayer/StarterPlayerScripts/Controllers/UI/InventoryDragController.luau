local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local InventoryGrid = require(ReplicatedStorage.Shared.Utils.InventoryGrid)
local InventoryEquipmentSlots = require(ReplicatedStorage.Shared.Utils.InventoryEquipmentSlots)

type ItemData = { [string]: any }
type DragState = {
	Button: ImageButton,
	Item: ItemData,
	Input: InputObject,
	Start: Vector2,
	Pointer: Vector2,
	Fraction: Vector2,
	Rotated: boolean,
	Started: boolean,
	Ghost: ImageButton?,
	Candidate: InventoryGrid.Placement?,
	Slot: string?,
	Valid: boolean,
}

local InventoryDragController = Knit.CreateController({Name = "InventoryDragController"})
local InventoryController
local InventoryService
local Context: ItemData?
local Layout: ItemData?
local Items: { [string]: ItemData } = {}
local InventoryEntries: { ItemData } = {}
local Equipped: { [string]: ItemData } = {}
local Buttons: { [string]: ImageButton } = {}
local State: DragState?
local Suppressed: { [ImageButton]: number } = setmetatable({}, {__mode = "k"})
local RequestId = 0
local PendingId: number?
local Overlays: { Instance } = {}
local White = Color3.new(1, 1, 1)
local Red = Color3.fromRGB(240, 65, 65)

local function Contains(Object: GuiObject, Point: Vector2): boolean
	local Position, Size = Object.AbsolutePosition, Object.AbsoluteSize
	return Point.X >= Position.X and Point.Y >= Position.Y and Point.X < Position.X + Size.X and Point.Y < Position.Y + Size.Y
end

local function Pointer(Position: Vector3): Vector2
	local Inset = if Context and not Context.Main.IgnoreGuiInset then GuiService:GetGuiInset() else Vector2.zero
	return Vector2.new(Position.X, Position.Y) - Inset
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
	table.clear(Buttons)

	for _, Item in Entries do
		Items[Item.Name] = Item
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
end

function InventoryDragController:ConsumesClick(Button: ImageButton): boolean
	return (Suppressed[Button] or 0) > os.clock()
end

function InventoryDragController:UpdateLayout(Snapshot: ItemData)
	Layout = Snapshot
	for Name, Item in Items do
		Item.InventoryPosition = Snapshot.Positions[Name]
		Item.Rotated = Item.InventoryPosition and Item.InventoryPosition.Rotated or false
	end

	if State and State.Started then
		self:UpdatePreview()
	end
end

function InventoryDragController:BindItem(Button: ImageButton, Item: ItemData)
	Buttons[Item.Name] = Button
	Button.InputBegan:Connect(function(Input: InputObject)
		if not Context or not Layout or State or PendingId or not InventoryController:CanDragItems()
			or (Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch) then
			return
		end

		local Point = Pointer(Input.Position)
		local Size = Button.AbsoluteSize
		State = {
			Button = Button, Item = Item, Input = Input, Start = Point, Pointer = Point,
			Fraction = Vector2.new(math.clamp((Point.X - Button.AbsolutePosition.X) / Size.X, 0, 1), math.clamp((Point.Y - Button.AbsolutePosition.Y) / Size.Y, 0, 1)),
			Rotated = Button:GetAttribute("Rotated") == true, Started = false, Valid = false,
		}
	end)
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
	Drag.Button.Visible = false
	Context.Scroll.ScrollingEnabled = Drag.Input.UserInputType ~= Enum.UserInputType.Touch
	Context.RotateButton.Visible = true
	Context.RotateHint.Text = "R  /  ROTATE"
	Context.RotateHint.Visible = true
	self:RenderGhost()
end

function InventoryDragController:RenderGhost()
	local Drag = State
	if not Drag or not Drag.Ghost then
		return
	end

	local Placement = InventoryGrid.Placement(Drag.Item, 1, 1, Drag.Rotated)
	local Viewport = InventoryController:ConfigureViewport(Drag.Ghost)
	if Viewport then
		InventoryController:AddModelToViewport(Viewport, Drag.Item, nil, Placement)
	end
	self:UpdatePreview()
end

function InventoryDragController:Rotate()
	if not State or not State.Started then
		return
	end

	State.Rotated = not State.Rotated
	State.Fraction = Vector2.new(1 - State.Fraction.Y, State.Fraction.X)
	self:RenderGhost()
end

function InventoryDragController:PreviewEquipment(Drag: DragState): boolean
	if not Context or not Layout then
		return false
	end

	for Slot, Button in Context.EquipmentButtons do
		local SlotFrame = Button.Parent :: GuiObject
		if not Button.Visible or not SlotFrame.Visible or not Contains(Button, Drag.Pointer) then
			continue
		end

		Drag.Slot = Slot
		local WeaponSlot = InventoryEquipmentSlots.IsWeaponSlot(Slot)
		Drag.Valid = InventoryEquipmentSlots.Accepts(Drag.Item, Slot, Layout.WeaponEquipment)
			and (if WeaponSlot then not Equipped[Slot] or Equipped[Slot].Name ~= Drag.Item.Name else not Drag.Item.Equipped)
		if Drag.Valid then
			local CurrentEquipment = Layout.Equipped or {}
			local NextEquipment = InventoryEquipmentSlots.WithSlot(CurrentEquipment, Slot, Drag.Item.Name)
			Drag.Valid = InventoryEquipmentSlots.PlanLayout(InventoryEntries, CurrentEquipment, NextEquipment, Layout.Hotbar or {}, Layout, Drag.Item.Name) ~= nil
		end

		local Layer = Context.DragLayer
		Overlay(Layer, UDim2.fromScale((Button.AbsolutePosition.X - Layer.AbsolutePosition.X) / Layer.AbsoluteSize.X, (Button.AbsolutePosition.Y - Layer.AbsolutePosition.Y) / Layer.AbsoluteSize.Y), UDim2.fromScale(Button.AbsoluteSize.X / Layer.AbsoluteSize.X, Button.AbsoluteSize.Y / Layer.AbsoluteSize.Y), if Drag.Valid then White else Red)
		return true
	end

	return false
end

function InventoryDragController:UpdatePreview()
	local Drag = State
	if not Context or not Layout or not Drag or not Drag.Started or not Drag.Ghost then
		return
	end

	ClearOverlays()
	Drag.Valid = false
	Drag.Candidate = nil
	Drag.Slot = nil
	local Layer = Context.DragLayer
	local Cell = Context.Canvas.AbsoluteSize.X / Layout.Columns
	local Candidate = InventoryGrid.Placement(Drag.Item, 1, 1, Drag.Rotated)
	local Size = Vector2.new(Candidate.Width * Cell, Candidate.Height * Cell)
	local TopLeft = Drag.Pointer - Vector2.new(Size.X * Drag.Fraction.X, Size.Y * Drag.Fraction.Y)
	Drag.Ghost.Size = UDim2.fromScale(Size.X / Layer.AbsoluteSize.X, Size.Y / Layer.AbsoluteSize.Y)
	Drag.Ghost.Position = UDim2.fromScale((TopLeft.X - Layer.AbsolutePosition.X) / Layer.AbsoluteSize.X, (TopLeft.Y - Layer.AbsolutePosition.Y) / Layer.AbsoluteSize.Y)

	if self:PreviewEquipment(Drag) or not Contains(Context.Scroll, Drag.Pointer) then
		return
	end

	Candidate.Column = math.floor((TopLeft.X - Context.Canvas.AbsolutePosition.X) / Cell + 0.5) + 1
	Candidate.Row = math.floor((TopLeft.Y - Context.Canvas.AbsolutePosition.Y) / Cell + 0.5) + 1
	Drag.Candidate = Candidate
	local Blockers, Outside = InventoryGrid.Blockers(Layout.Positions, Candidate, Layout.Columns, Layout.Rows, Drag.Item.Name)
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
		local Boundary = Overlay(Context.Canvas, UDim2.fromScale(0, 0), UDim2.fromScale(1, Layout.Rows / DisplayRows), Red)
		Boundary.BackgroundTransparency = 1
	end
end

function InventoryDragController:Cancel()
	local Drag = State
	State = nil
	ClearOverlays()
	if Drag then
		if Drag.Started then
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
	if not Drag or not Drag.Started or not Drag.Valid or not Layout then
		self:Cancel()
		return
	end

	RequestId += 1
	PendingId = RequestId
	local Candidate = Drag.Candidate
	local Request = {
		Id = RequestId, Kind = if Drag.Slot then "Equip" else "Move", Name = Drag.Item.Name, Slot = Drag.Slot,
		Column = Candidate and Candidate.Column, Row = Candidate and Candidate.Row, Rotated = Drag.Rotated, Revision = Layout.Revision,
	}

	if Candidate and not Drag.Slot then
		InventoryController:ApplyEntryPlacement(Drag.Button, Candidate)
	end

	self:Cancel()
	InventoryService.InventoryAction:Fire(Request)
	local Id = RequestId
	task.delay(8, function()
		if PendingId == Id then
			PendingId = nil
			InventoryController:UpdateContent()
		end
	end)
end

function InventoryDragController.KnitInit()
	InventoryController = Knit.GetController("InventoryController")
	InventoryService = Knit.GetService("InventoryService")
end

function InventoryDragController.KnitStart()
	UserInputService.InputChanged:Connect(function(Input: InputObject)
		local Drag = State
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
		if State and (Input == State.Input or (State.Input.UserInputType == Enum.UserInputType.MouseButton1 and Input.UserInputType == Enum.UserInputType.MouseButton1)) then
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
	InventoryService.InventoryActionResult:Connect(function(Id: number, Success: boolean, Reason: string?, Correction: ItemData?)
		if Id ~= PendingId then
			return
		end

		PendingId = nil
		if not Success then
			if not Correction or not InventoryController:ApplyLayout(Correction) then
				InventoryController:UpdateContent()
			end
		end
		if not Success and Reason and Context and Context.Main.Enabled then
			Context.RotateHint.Text = Reason
			Context.RotateHint.Visible = true
			task.delay(3, function()
				if Context and not State then
					Context.RotateHint.Visible = false
					Context.RotateHint.Text = "R  /  ROTATE"
				end
			end)
		end
	end)
end

return InventoryDragController
