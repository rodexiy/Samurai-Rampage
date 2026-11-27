local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Items = require(ReplicatedStorage.Shared.Index.Items)
local RangedWeaponConfig = require(ReplicatedStorage.Shared.RangedWeaponConfig)
local InventoryConfig = require(ReplicatedStorage.Shared.InventoryConfig)
local InventoryGrid = require(ReplicatedStorage.Shared.Utils.InventoryGrid)
local InventoryEquipmentSlots = require(ReplicatedStorage.Shared.Utils.InventoryEquipmentSlots)
local InventoryHotbarSlots = require(ReplicatedStorage.Shared.Utils.InventoryHotbarSlots)
local InventoryStacks = require(ReplicatedStorage.Shared.Utils.InventoryStacks)

type ItemData = { [string]: any }
type RenderedItem = { Button: ImageButton, Item: ItemData, Outline: UIStroke? }
type SlotColors = { Background: Color3, Border: Color3?, Texture: Color3? }

local InventoryController = Knit.CreateController({
	Name = "InventoryController",
})

local Player = Players.LocalPlayer
local InventoryService
local StanceService
local HotbarController
local MenuController
local ViewportRotationController
local StatsController
local InventoryDragController
local InventoryDeleteController
local InventoryDropController
local InventoryModalController
local InventoryLayout: ItemData?
local RenderedItems: { [string]: RenderedItem } = {}
local VisibleEntries: { ItemData } = {}
local CachedEntries: { ItemData }?
local CachedLayout: ItemData?
local CachedStances: { ItemData }?
local InventoryVersion = 0
local StanceVersion = 0
local RenderedTab: string?
local UpdateQueued = false
local Fetching = false

local DISPLAY_DISTANCE_SCALE = 0.8

local MainMenu: ScreenGui
local Inventory: Frame
local Equipments: Frame
local BackpackPanel: Frame
local BackpackTemplates: Folder
local GridCanvas: Frame
local ContentScroll: ScrollingFrame
local Tabs: GuiObject
local Content: Frame
local ItemInfo: Frame
local Description: TextLabel
local ItemName: TextLabel
local BasicStats: Frame
local Display: Frame
local EquipButton: ImageButton
local EquipLeftButton: ImageButton

local CurrentTab = "Items"
local SelectedItem: ImageButton? = nil
local SelectedItemZIndex: number? = nil
local SelectedItemData: ItemData? = nil
local SelectedVisuals = {}
local EquipmentButtons: { [string]: ImageButton } = {}
local EquipmentColors: { [ImageButton]: SlotColors } = {}
local EquippedItems: { [string]: ItemData } = {}
local PendingEquipmentSlots: { [string]: boolean } = {}
local GridColumns = InventoryConfig.Columns
local GridRows = InventoryConfig.Rows

local RarityColors = {
	Common = Color3.fromRGB(230, 230, 230),
	Uncommon = Color3.fromRGB(110, 220, 120),
	Rare = Color3.fromRGB(90, 160, 255),
	Epic = Color3.fromRGB(190, 110, 255),
	Legendary = Color3.fromRGB(255, 200, 70),
	Mythic = Color3.fromRGB(255, 100, 100),
}

local TabNames = { Items = true, Skills = true, Stances = true, Stats = true }

local function ApplyItemRarity(Button: ImageButton, Item: ItemData?)
	local Defaults = EquipmentColors[Button]
	local Color = Item and (RarityColors[Item.Rarity or "Common"] or RarityColors.Common)
	Button.BackgroundColor3 = if Color
		then Color:Lerp(Color3.new(0, 0, 0), 0.8)
		elseif Defaults then Defaults.Background
		else Button.BackgroundColor3

	local BorderColor = if Color then Color else Defaults and Defaults.Border
	if BorderColor then
		InventoryDragController:SetSlotStrokeColor(Button, BorderColor)
	end

	local Texture = Button:FindFirstChild("Texture") :: ImageLabel?
	local TextureColor = if Color then Color else Defaults and Defaults.Texture
	if Texture and TextureColor then
		Texture.ImageColor3 = TextureColor
	end
end

local function SameData(Left: any, Right: any): boolean
	if Left == Right then
		return true
	end
	if typeof(Left) ~= "table" or typeof(Right) ~= "table" then
		return false
	end
	for Key, Value in Left do
		if not SameData(Value, Right[Key]) then
			return false
		end
	end
	for Key in Right do
		if Left[Key] == nil then
			return false
		end
	end
	return true
end

local function ClearVisuals(Visuals: { any })
	for _, Visual in Visuals do
		Visual:Destroy()
	end

	table.clear(Visuals)
end

local function CreateOutline(Button: GuiObject, Color: Color3, Thickness: number): UIStroke
	local Outline = Instance.new("UIStroke")
	Outline.Name = "InventoryOutline"
	Outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Outline.Color = Color
	Outline.Thickness = Thickness
	Outline.Parent = Button

	return Outline
end

local function ClearViewport(Viewport: ViewportFrame)
	for _, Child in Viewport:GetChildren() do
		if Child:IsA("WorldModel") or Child:IsA("Model") or Child:IsA("BasePart") then
			Child:Destroy()
		end
	end
end

local function FitViewportCamera(
	Viewport: ViewportFrame,
	Model: Model,
	Distance: number?,
	DistanceScale: number?,
	FitRectangle: boolean?
)
	local Camera = Viewport.CurrentCamera
	if not Camera then
		return
	end

	local Bounds, Size = Model:GetBoundingBox()
	local AspectRatio = if Viewport.AbsoluteSize.Y > 0 then Viewport.AbsoluteSize.X / Viewport.AbsoluteSize.Y else 1
	local VerticalAngle = math.rad(Camera.FieldOfView) / 2
	local HorizontalAngle = math.atan(math.tan(VerticalAngle) * AspectRatio)
	local Radius = Size.Magnitude / 2
	local CameraDistance = Distance or math.max(1.1, Radius / math.sin(math.min(VerticalAngle, HorizontalAngle)) * 1.1)
	if FitRectangle then
		local HalfRight = Bounds.RightVector * Size.X / 2
		local HalfUp = Bounds.UpVector * Size.Y / 2
		local HalfLook = Bounds.LookVector * Size.Z / 2
		local HalfWidth = math.abs(HalfRight.X) + math.abs(HalfUp.X) + math.abs(HalfLook.X)
		local HalfHeight = math.abs(HalfRight.Y) + math.abs(HalfUp.Y) + math.abs(HalfLook.Y)
		local HalfDepth = math.abs(HalfRight.Z) + math.abs(HalfUp.Z) + math.abs(HalfLook.Z)
		CameraDistance = (
			math.max(HalfWidth / math.tan(HorizontalAngle), HalfHeight / math.tan(VerticalAngle)) + HalfDepth
		) * 1.1
	end

	CameraDistance *= DistanceScale or 1

	Camera.CFrame = CFrame.new(Bounds.Position + Vector3.new(0, 0, CameraDistance))
end

local function OrientGridModel(Model: Model, Placement: InventoryGrid.Placement)
	if Placement.Width == Placement.Height then
		if Placement.Rotated then
			Model:PivotTo(CFrame.Angles(0, 0, math.pi / 2) * Model:GetPivot())
		end
		return
	end

	local Bounds, Size = Model:GetBoundingBox()
	local Rotation = CFrame.identity
	if Placement.Width > Placement.Height then
		if Size.Y >= Size.X and Size.Y >= Size.Z then
			Rotation = CFrame.Angles(0, 0, -math.pi / 2)
		elseif Size.Z >= Size.X then
			Rotation = CFrame.Angles(0, math.pi / 2, 0)
		end
	elseif Size.X >= Size.Y and Size.X >= Size.Z then
		Rotation = CFrame.Angles(0, 0, math.pi / 2)
	elseif Size.Z >= Size.Y then
		Rotation = CFrame.Angles(math.pi / 2, 0, 0)
	end

	Model:PivotTo(Rotation * Bounds:ToObjectSpace(Model:GetPivot()))
end

local function FitItemIcon(Icon: ImageLabel, Placement: InventoryGrid.Placement?)
	Icon.AnchorPoint = Vector2.new(0.5, 0.5)
	Icon.Position = UDim2.fromScale(0.5, 0.5)
	Icon.Rotation = if Placement and Placement.Rotated then 90 else 0

	-- Fit the image in its original bounds before rotating into the swapped grid footprint.
	Icon.Size = if Placement and Placement.Rotated
		then UDim2.fromScale(Placement.Height / Placement.Width, Placement.Width / Placement.Height)
		else UDim2.fromScale(1, 1)
end

local function GetItemData(Item: ItemData): ItemData
	local Data = table.clone(Items[Item.Name] or {})
	for Key, Value in Item do
		Data[Key] = Value
	end

	return Data
end

local function SetButtonText(Button: ImageButton, Text: string)
	local Label = Button:FindFirstChildWhichIsA("TextLabel")
	if Label then
		Label.Text = Text
	end
end

local function BindEntryFeedback(Button: ImageButton)
	local Style = Button:GetAttribute("Style")
	local StyleNames = {}
	if typeof(Style) == "string" then
		for Name in Style:gmatch("%S+") do
			if Name ~= "Button" and Name ~= "-Button" then
				table.insert(StyleNames, Name)
			end
		end
	end
	table.insert(StyleNames, "-Button")
	Button:SetAttribute("Style", table.concat(StyleNames, " "))

	for _, LegacyFeedback in Button:GetChildren() do
		if LegacyFeedback.Name == "Button" and LegacyFeedback:IsA("LocalScript") then
			LegacyFeedback:Destroy()
		end
	end

	local BaseTransparency = Button.BackgroundTransparency
	local HoverTween: Tween?
	local function Hover(Entered: boolean)
		if HoverTween then
			HoverTween:Cancel()
		end

		HoverTween = TweenService:Create(Button, TweenInfo.new(0.15, Enum.EasingStyle.Sine), {
			BackgroundTransparency = if Entered then math.clamp(BaseTransparency - 0.15, 0, 1) else BaseTransparency,
		})
		HoverTween:Play()
	end

	Button.MouseEnter:Connect(function()
		Hover(true)
	end)
	Button.MouseLeave:Connect(function()
		Hover(false)
	end)
end

local function PlayEntryClick()
	local PlayerGui = Players.LocalPlayer:FindFirstChildWhichIsA("PlayerGui")
	local Temporary = PlayerGui and PlayerGui:FindFirstChild("Temporary")
	local Circle = Temporary and Temporary:FindFirstChild("Circle")
	local Template = Circle and Circle:FindFirstChild("Template") :: GuiObject?
	if not Template or not Circle then
		return
	end

	local Effect = Template:Clone()
	local Mouse = Players.LocalPlayer:GetMouse()
	Effect.Position = UDim2.fromOffset(Mouse.X, Mouse.Y)
	Effect.Visible = true
	Effect.Parent = Circle
	local Tween = TweenService:Create(Effect, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(0.085, 0.085),
		BackgroundTransparency = 1,
	})
	Tween.Completed:Once(function()
		Effect:Destroy()
	end)
	Tween:Play()
end

function InventoryController:IsOpen(): boolean
	return MainMenu ~= nil and MainMenu.Enabled
end

function InventoryController:GetCurrentTab(): string
	return CurrentTab
end

function InventoryController:GetInventoryItem(Name: string): ItemData?
	for _, Item in CachedEntries or {} do
		if InventoryStacks.Key(Item) == Name then
			return GetItemData(Item)
		end
	end

	return nil
end

function InventoryController:GetInventoryRevision(): number?
	return if CachedLayout then CachedLayout.Revision else nil
end

function InventoryController:CanAssignToHotbar(): boolean
	return self:IsOpen() and InventoryHotbarSlots.Accepts(SelectedItemData)
end

function InventoryController:RefreshHotbar()
	if HotbarController then
		HotbarController:LoadHotbar(HotbarController:HotbarEnabledBooleans())
	end
end

function InventoryController:Unselect()
	ClearVisuals(SelectedVisuals)
	if SelectedItem and SelectedItemZIndex then
		SelectedItem.ZIndex = SelectedItemZIndex
	end

	SelectedItem = nil
	SelectedItemZIndex = nil
	SelectedItemData = nil

	if ItemInfo then
		ItemInfo.Visible = false
		Description.Visible = false
		Equipments.Visible = CurrentTab == "Items"

		local Viewport = Display:FindFirstChildWhichIsA("ViewportFrame")
		if Viewport then
			ViewportRotationController:StopRotation(Viewport)
			ClearViewport(Viewport)
		end
	end

	self:RefreshHotbar()
end

function InventoryController:ClearContent()
	if InventoryDragController then
		InventoryDragController:Cancel()
	end

	self:Unselect()
	table.clear(RenderedItems)
	table.clear(VisibleEntries)

	if not Content then
		return
	end

	for _, Child in Content:GetChildren() do
		if Child:IsA("GuiObject") then
			Child:Destroy()
		end
	end
end

function InventoryController:ConfigureViewport(Template: GuiObject): ViewportFrame?
	local Visual = Template:FindFirstChild("Visual") or Template
	local Viewport = Visual:FindFirstChildWhichIsA("ViewportFrame")
	if not Viewport then
		return nil
	end

	local Camera = Viewport:FindFirstChildWhichIsA("Camera")
	if not Camera then
		Camera = Instance.new("Camera")
		Camera.Parent = Viewport
	end

	Camera.CFrame = CFrame.new()
	Camera.CameraType = Enum.CameraType.Scriptable
	Viewport.CurrentCamera = Camera

	return Viewport
end

function InventoryController:RenderItemVisual(
	Template: GuiObject,
	Item: ItemData?,
	DistanceScale: number?,
	Placement: InventoryGrid.Placement?
)
	local Visual = (Template:FindFirstChild("Visual") or Template) :: GuiObject
	local Viewport = Visual:FindFirstChildWhichIsA("ViewportFrame")
	local Icon = Visual:FindFirstChild("Icon") :: ImageLabel?
	local Image = Item and (Item.Icon or (Items[Item.Name] and Items[Item.Name].Icon))

	if Icon then
		Icon.Visible = Image ~= nil
	end

	if not Item or Image then
		if Viewport then
			ViewportRotationController:StopRotation(Viewport)
			ClearViewport(Viewport)
			Viewport.Visible = false
		end

		if Image then
			if not Icon then
				Icon = Instance.new("ImageLabel")
				Icon.Name = "Icon"
				Icon.BackgroundTransparency = 1
				Icon.ZIndex = if Viewport then Viewport.ZIndex else Visual.ZIndex
				Icon.Parent = Visual
			end

			Icon.Image = Image
			Icon.ScaleType = Enum.ScaleType.Fit
			FitItemIcon(Icon, Placement)

			local SlotName = Template:GetAttribute("EquipmentSlot")
			if not Placement and Item.Type == "Katana" and (SlotName == "Katana" or SlotName == "SecondKatana") then
				Icon.Rotation = 35
			end

			Icon.Visible = true
		end

		return
	end

	Viewport = self:ConfigureViewport(Template)
	if Viewport then
		Viewport.Visible = true
		if Item.Class == "Stance" then
			self:LoadStanceViewport(Viewport, Item)
		else
			self:AddModelToViewport(Viewport, Item, DistanceScale, Placement)
		end
	end
end

function InventoryController:AddModelToViewport(
	Viewport: ViewportFrame,
	Item: ItemData,
	DistanceScale: number?,
	Placement: InventoryGrid.Placement?
)
	ClearViewport(Viewport)

	local Source = ReplicatedStorage.Assets.Tools:FindFirstChild(Item.Name)
		or ReplicatedStorage.Assets.Equipables:FindFirstChild(Item.Name, true)
	local Weapon = ReplicatedStorage.Assets.Weapons:FindFirstChild(Item.Name)
	if not Source and Weapon then
		Source = Weapon:FindFirstChild("Weapon")
	end
	if Item.Type == "Bow" then
		Source = RangedWeaponConfig.GetModel(Item.Name)
	elseif Item.Type == "Ammunition" and Item.Name == "Arrow" then
		Source = ReplicatedStorage.Assets.Models.Bow.Arrow
	end

	if not Source then
		return
	end

	local Clone = Source:Clone()
	local Model: Model
	if Clone:IsA("Model") then
		Model = Clone
	else
		Model = Instance.new("Model")
		Clone.Parent = Model
	end

	for _, Script in Model:QueryDescendants("LuaSourceContainer") do
		Script:Destroy()
	end

	Model:RemoveTag("SmartBone")
	for _, Part in Model:QueryDescendants("BasePart") do
		Part:RemoveTag("SmartBone")
		Part.Anchored = true
		Part.CanCollide = false
	end

	local _, BoundingSize = Model:GetBoundingBox()
	local LargestDimension = math.max(BoundingSize.X, BoundingSize.Y, BoundingSize.Z)
	local Offset = Source:GetAttribute("InventoryOffset") or CFrame.new()
	local Distance = Source:GetAttribute("InventoryDistance") or math.clamp(LargestDimension * 1.8, 1.1, 2.5)
	local Rotation = CFrame.Angles(0, 0, math.rad(45))
	if Item.Class == "Equipable" then
		Distance = Source:GetAttribute("InventoryDistance") or 5
		Rotation = CFrame.new()
	end

	Model:PivotTo(CFrame.new(0, 0, -Distance) * Rotation * Offset)
	Model.Parent = Viewport

	if Placement then
		OrientGridModel(Model, Placement)

		local function FitGridModel()
			FitViewportCamera(Viewport, Model, nil, nil, true)
		end

		FitGridModel()
		local ResizeConnection = Viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(FitGridModel)
		Model.Destroying:Once(function()
			ResizeConnection:Disconnect()
		end)
	else
		FitViewportCamera(Viewport, Model, Source:GetAttribute("InventoryDistance"), DistanceScale)
	end
end

function InventoryController:CreateWeaponSlots(Scroll: ScrollingFrame)
	local Template = Scroll:WaitForChild("HeadSlot") :: Frame
	for _, Definition in InventoryEquipmentSlots.Weapons do
		local Slot = Scroll:FindFirstChild(Definition.Name .. "Slot") :: Frame?
		if not Slot then
			Slot = Template:Clone()
			Slot.Name = Definition.Name .. "Slot"
			Slot.Parent = Scroll
		end

		Slot.LayoutOrder = Definition.Order
		Slot:SetAttribute("EquipmentSlot", Definition.Name)
		local Title = Slot:WaitForChild("Title") :: TextLabel
		Title.Text = Definition.Title
		local Button = Slot:WaitForChild("Button") :: ImageButton
		Button:SetAttribute("EquipmentSlot", Definition.Name)
		Slot.Visible = Definition.Name ~= "SecondKatana"
	end
end

function InventoryController:RefreshEquipmentSlots(Entries: { ItemData }, Snapshot: ItemData?)
	table.clear(EquippedItems)
	local ByName: { [string]: ItemData } = {}

	for _, Entry in Entries do
		ByName[InventoryStacks.Key(Entry)] = Entry
		if Entry.Class == "Equipable" and Entry.Equipped then
			EquippedItems[Entry.Type] = GetItemData(Entry)
		end
	end

	local WeaponEquipment = Snapshot and Snapshot.WeaponEquipment
	for _, Definition in InventoryEquipmentSlots.Weapons do
		local Name = WeaponEquipment and WeaponEquipment[Definition.Name]
		if Name and ByName[Name] then
			EquippedItems[Definition.Name] = GetItemData(ByName[Name])
		end
	end
	local SecondKatana = EquipmentButtons.SecondKatana
	if SecondKatana then
		local Slot = SecondKatana.Parent :: Frame
		Slot.Visible = WeaponEquipment ~= nil and WeaponEquipment.DualWield == true
	end

	for SlotName, Button in EquipmentButtons do
		local Item = EquippedItems[SlotName]
		local Name = Item and InventoryStacks.Key(Item)
		local Changed = Button:GetAttribute("ItemName") ~= Name
		if Changed or not Item then
			self:RenderItemVisual(Button, Item)
		end

		local EmptyIcon = Button:FindFirstChild("EmptyIcon") :: ImageLabel?
		if EmptyIcon then
			EmptyIcon.Visible = false
		end

		ApplyItemRarity(Button, Item)

		Button:SetAttribute("ItemName", Name)
		Button.Interactable = Item ~= nil
	end
end

function InventoryController:ChangeEquipment(Item: ItemData, Unequip: boolean?, EquipmentSlot: string?)
	local SlotName = EquipmentSlot or Item.Type
	if PendingEquipmentSlots[SlotName] then
		return
	end

	PendingEquipmentSlots[SlotName] = true
	local Success, Error = pcall(function()
		if Unequip then
			InventoryService:UnequipEquipmentSlot(SlotName, InventoryStacks.Key(Item))
		else
			InventoryService:EquipUnequipItem(InventoryStacks.Key(Item))
		end
	end)
	PendingEquipmentSlots[SlotName] = nil

	if not Success then
		warn("Could not change equipment: " .. tostring(Error))
	end
end

function InventoryController:UnequipEquipmentSlot(SlotName: string)
	local Item = EquippedItems[SlotName]
	if not self:IsOpen() or CurrentTab ~= "Items" or not Item then
		return
	end

	self:ChangeEquipment(Item, true, SlotName)
end

function InventoryController:ResizeBackpackCanvas()
	local Width = ContentScroll.AbsoluteWindowSize.X
	if Width <= 0 then
		return
	end

	local Height = Width * GridRows / GridColumns
	GridCanvas.Size = UDim2.fromOffset(Width, Height)
	ContentScroll.CanvasSize = UDim2.fromOffset(0, Height)
end

function InventoryController:UpdateBackpackGrid(VisibleItems: { ItemData }): { InventoryGrid.Placement }
	local Snapshot = if CurrentTab == "Items" then InventoryLayout else nil
	GridColumns = if Snapshot
		then Snapshot.Columns
		else math.max(1, BackpackPanel:GetAttribute("Columns") or InventoryConfig.Columns)
	local BaseRows = if Snapshot
		then Snapshot.Rows
		else math.max(1, BackpackPanel:GetAttribute("Rows") or InventoryConfig.Rows)
	local LayoutResult = { Placements = {}, Rows = BaseRows }
	if Snapshot then
		local Overflow, Indices = {}, {}
		for Index, Item in VisibleItems do
			if Snapshot.Positions[InventoryStacks.Key(Item)] then
				LayoutResult.Placements[Index] = Snapshot.Positions[InventoryStacks.Key(Item)]
			else
				table.insert(Overflow, Item)
				table.insert(Indices, Index)
			end
		end

		if #Overflow > 0 then
			local Extra = InventoryGrid.Arrange(Overflow, GridColumns, 1)
			LayoutResult.Rows = BaseRows + 1 + Extra.Rows
			for Index, Placement in Extra.Placements do
				Placement.Row += BaseRows + 1
				LayoutResult.Placements[Indices[Index]] = Placement
			end
		end
	else
		LayoutResult = InventoryGrid.Arrange(VisibleItems, GridColumns, BaseRows, true)
	end
	GridRows = LayoutResult.Rows
	self:ResizeBackpackCanvas()

	local Cells = GridCanvas:FindFirstChild("CellsLayer") :: Frame
	local CellRows = if Snapshot then BaseRows else GridRows
	Cells.Size = UDim2.fromScale(1, CellRows / GridRows)
	local Layout = Cells:FindFirstChildWhichIsA("UIGridLayout") :: UIGridLayout
	local CellSize = UDim2.fromScale(1 / GridColumns, 1 / CellRows)
	local Rebuild = Layout.FillDirectionMaxCells ~= GridColumns or #Cells:GetChildren() - 1 ~= GridColumns * CellRows
	Layout.CellSize = CellSize
	Layout.CellPadding = UDim2.fromOffset(0, 0)
	Layout.FillDirectionMaxCells = GridColumns

	local Preview = GridCanvas:FindFirstChild("PlacementPreview") :: Frame
	Preview.Size = CellSize
	local Dimensions = BackpackPanel:FindFirstChild("Dimensions") :: TextLabel
	Dimensions.Text = tostring(GridColumns) .. " × " .. tostring(CellRows)
	local OverflowNotice = GridCanvas:FindFirstChild("OverflowNotice") :: TextLabel?
	if not OverflowNotice then
		OverflowNotice = BackpackPanel.RotateHint:Clone()
		OverflowNotice.Name = "OverflowNotice"
		OverflowNotice.Text = "EXTRA ITEMS — FREE UP BACKPACK SPACE"
		OverflowNotice.TextColor3 = Color3.fromRGB(240, 90, 90)
		OverflowNotice.ZIndex = 8
		OverflowNotice.Parent = GridCanvas
	end
	OverflowNotice.Visible = Snapshot ~= nil and GridRows > BaseRows
	OverflowNotice.Position = UDim2.fromScale(0, BaseRows / GridRows)
	OverflowNotice.Size = UDim2.fromScale(1, 1 / GridRows)

	if not Rebuild then
		return LayoutResult.Placements
	end

	for _, Cell in Cells:GetChildren() do
		if Cell:IsA("GuiObject") then
			local Row, Column = Cell:GetAttribute("Row"), Cell:GetAttribute("Column")
			if typeof(Row) ~= "number" or typeof(Column) ~= "number" or Row > CellRows or Column > GridColumns then
				Cell:Destroy()
			else
				Cell.LayoutOrder = (Row - 1) * GridColumns + Column
			end
		end
	end

	local CellTemplate = BackpackTemplates:FindFirstChild("CellTemplate") :: Frame
	for Row = 1, CellRows do
		for Column = 1, GridColumns do
			local Name = string.format("Cell_%02d_%02d", Row, Column)
			if not Cells:FindFirstChild(Name) then
				local Cell = CellTemplate:Clone()
				Cell.Name = Name
				Cell.LayoutOrder = (Row - 1) * GridColumns + Column
				Cell:SetAttribute("Column", Column)
				Cell:SetAttribute("Row", Row)
				Cell.Visible = true
				Cell.Parent = Cells
			end
		end
	end

	return LayoutResult.Placements
end

function InventoryController:LoadStanceViewport(Viewport: ViewportFrame, Stance: ItemData)
	ClearViewport(Viewport)

	local Source = ReplicatedStorage.Assets.Rigs:FindFirstChild((Stance.WeaponType or "Katana") .. "Visualizer")
	local Animations = ReplicatedStorage.Assets.Animations.Stances:FindFirstChild(Stance.Name)
	local Idle = Animations and Animations:FindFirstChild("Idle") :: Animation?
	if not Source or not Source:IsA("Model") then
		return
	end

	local Rig = Source:Clone()
	local Humanoid = Rig:FindFirstChildWhichIsA("Humanoid")
	local Animator = Humanoid and Humanoid:FindFirstChildWhichIsA("Animator")
	if Rig.PrimaryPart then
		Rig.PrimaryPart.Anchored = true
	end

	for _, Script in Rig:QueryDescendants("LuaSourceContainer") do
		Script:Destroy()
	end

	local WorldModel = Instance.new("WorldModel")
	WorldModel.Parent = Viewport
	Rig.Parent = WorldModel
	Rig:PivotTo(CFrame.new(0, 0, -5) * CFrame.Angles(0, math.rad(205), 0))

	if Animator and Idle then
		Animator:LoadAnimation(Idle):Play(0, 10)
	end
end

function InventoryController:Select(Button: ImageButton, Data: ItemData?)
	local Item = Data or SelectedItemData
	if not Item then
		return
	end

	self:Unselect()
	SelectedItem = Button
	SelectedItemZIndex = Button.ZIndex
	SelectedItemData = Item
	Button.ZIndex += 1
	table.insert(SelectedVisuals, CreateOutline(Button, Color3.fromRGB(255, 238, 0), 2))
	self:UpdateSelection(true)
end

function InventoryController:UpdateSelection(ReloadModel: boolean?)
	local Item = SelectedItemData
	if not Item then
		return
	end

	ItemName.Text = Item.DisplayName or Item.Name
	BasicStats.Amount.Text = tostring(Item.Stack or 1) .. "x"
	BasicStats.Amount.Visible = Item.Class ~= "Stance"
	BasicStats.ItemType.Text = Item.Type or Item.WeaponType or Item.Class or ""
	BasicStats.Rarity.Text = Item.Rarity or "Common"
	Description.Text = Item.Description or ""
	Description.Visible = Description.Text ~= ""

	local Rarity = Item.Rarity or "Common"
	local RarityColor = RarityColors[Rarity] or RarityColors.Common
	BasicStats.Rarity.TextColor3 = RarityColor

	if ReloadModel then
		local Placeholder = Display:FindFirstChildWhichIsA("ImageLabel")
		if Placeholder then
			Placeholder.Visible = false
		end

		self:RenderItemVisual(Display, Item, DISPLAY_DISTANCE_SCALE)
	end

	EquipButton.Visible = Item.Class == "Equipable"
		or Item.Class == "Weapon"
		or Item.Class == "Stance"
		or self:CanAssignToHotbar()
	EquipLeftButton.Visible = Item.Class == "Weapon"
		and not Item.DefaultLeft
		and (Item.CanEquipLeft == true or Item.EquippedLeft == true)
	SetButtonText(EquipButton, if Item.Equipped then "UNEQUIP" else "EQUIP")
	if Item.Class == "Stance" and Item.Equipped then
		SetButtonText(EquipButton, "EQUIPPED")
	end
	SetButtonText(EquipLeftButton, if Item.EquippedLeft then "UNEQUIP LEFT" else "EQUIP LEFT")

	ItemInfo.Visible = true
	Equipments.Visible = false
	self:RefreshHotbar()
end

function InventoryController:GetSelected(): ImageButton?
	return SelectedItem
end

function InventoryController:EquipItem()
	local Item = SelectedItemData
	if not Item then
		return
	end

	if Item.Class == "Stance" then
		if not Item.Equipped then
			StanceService:EquipStance(Item.Name)
		end
	elseif Item.Class == "Equipable" then
		self:ChangeEquipment(Item)
	elseif Item.Class == "Weapon" then
		InventoryService:EquipUnequipItem(InventoryStacks.Key(Item))
	elseif self:CanAssignToHotbar() then
		HotbarController:BeginSlotSelection(InventoryStacks.Key(Item))
	end
end

function InventoryController:EquipLeftItem()
	local Item = SelectedItemData
	if Item and Item.Class == "Weapon" and (Item.CanEquipLeft or Item.EquippedLeft) then
		if Item.EquippedLeft then
			self:ChangeEquipment(Item, true, "SecondKatana")
		else
			InventoryService:EquipUnequipLeftItem(InventoryStacks.Key(Item))
		end
	end
end

function InventoryController:ApplyEntryPlacement(Button: ImageButton, Placement: InventoryGrid.Placement)
	local PreviousRotation = Button:GetAttribute("Rotated")
	local Size = UDim2.fromScale(Placement.Width / GridColumns, Placement.Height / GridRows)
	local Resized = Button.Size ~= Size
	Button.Position = UDim2.fromScale((Placement.Column - 1) / GridColumns, (Placement.Row - 1) / GridRows)
	Button.Size = Size
	Button:SetAttribute("Column", Placement.Column)
	Button:SetAttribute("Row", Placement.Row)
	Button:SetAttribute("Width", Placement.Width)
	Button:SetAttribute("Height", Placement.Height)
	Button:SetAttribute("Rotated", Placement.Rotated)

	if PreviousRotation == nil or (PreviousRotation == Placement.Rotated and not Resized) then
		return
	end

	local Visual = Button:FindFirstChild("Visual")
	local Icon = Visual and Visual:FindFirstChild("Icon") :: ImageLabel?
	if Icon then
		FitItemIcon(Icon, Placement)
	end

	local Viewport = Visual and Visual:FindFirstChildWhichIsA("ViewportFrame")
	local Model = Viewport and Viewport:FindFirstChildWhichIsA("Model")
	if Viewport and Model then
		if PreviousRotation ~= Placement.Rotated then
			local Bounds = Model:GetBoundingBox()
			local Angle = if Placement.Rotated then math.pi / 2 else -math.pi / 2
			Model:PivotTo(
				CFrame.new(Bounds.Position)
					* CFrame.Angles(0, 0, Angle)
					* CFrame.new(-Bounds.Position)
					* Model:GetPivot()
			)
		end

		FitViewportCamera(Viewport, Model, nil, nil, true)
	end
end

function InventoryController:ApplyLayout(Snapshot: ItemData): boolean
	if CachedLayout and Snapshot.Revision < CachedLayout.Revision then
		return true
	end
	CachedLayout = Snapshot
	InventoryVersion += 1
	if CachedEntries then
		for _, Item in CachedEntries do
			Item.InventoryPosition = Snapshot.Positions[InventoryStacks.Key(Item)]
			Item.Rotated = Item.InventoryPosition and Item.InventoryPosition.Rotated or false
		end
	end

	if not self:CanDragItems() then
		return true
	end
	if CurrentTab == "Skills" then
		InventoryLayout = Snapshot
		InventoryDragController:UpdateLayout(Snapshot)
		return true
	end

	if not InventoryLayout then
		return false
	end
	if Snapshot.Revision < InventoryLayout.Revision then
		return true
	end

	for Name in Snapshot.Positions do
		if not RenderedItems[Name] then
			return false
		end
	end
	for Name in RenderedItems do
		if not Snapshot.Positions[Name] and not table.find(Snapshot.Overflow, Name) then
			return false
		end
	end

	local ResizeGrid = Snapshot.Columns ~= InventoryLayout.Columns
		or Snapshot.Rows ~= InventoryLayout.Rows
		or #Snapshot.Overflow ~= #InventoryLayout.Overflow
	InventoryLayout = Snapshot
	local Placements = if ResizeGrid then self:UpdateBackpackGrid(VisibleEntries) else nil
	for Index, Item in VisibleEntries do
		local Placement = if Placements then Placements[Index] else Snapshot.Positions[InventoryStacks.Key(Item)]
		local Entry = RenderedItems[InventoryStacks.Key(Item)]
		if Entry and Placement then
			Item.InventoryPosition = Snapshot.Positions[InventoryStacks.Key(Item)]
			Item.Rotated = Placement.Rotated
			local Button = Entry.Button
			if
				ResizeGrid
				or Button:GetAttribute("Column") ~= Placement.Column
				or Button:GetAttribute("Row") ~= Placement.Row
				or Button:GetAttribute("Rotated") ~= Placement.Rotated
			then
				self:ApplyEntryPlacement(Button, Placement)
			end
		end
	end

	InventoryDragController:UpdateLayout(Snapshot)
	return true
end

function InventoryController:UpdateEntry(Entry: RenderedItem, Data: ItemData, Placement: InventoryGrid.Placement?)
	local Button, Item = Entry.Button, Entry.Item
	local Changed = not SameData(Item, Data)
	local ModelChanged = Item.Name ~= Data.Name
		or Item.Icon ~= Data.Icon
		or Item.Class ~= Data.Class
		or Item.Type ~= Data.Type
		or Item.WeaponType ~= Data.WeaponType
	local DetailsChanged = false
	for _, Key in
		{
			"Stack",
			"Icon",
			"DisplayName",
			"Description",
			"Type",
			"Class",
			"WeaponType",
			"Rarity",
			"Equipped",
			"EquippedLeft",
			"DefaultLeft",
			"CanEquipLeft",
		}
	do
		if Item[Key] ~= Data[Key] then
			DetailsChanged = true
			break
		end
	end
	if Changed then
		table.clear(Item)
		for Key, Value in Data do
			Item[Key] = Value
		end
	end

	if
		Placement
		and (
			Button.Position ~= UDim2.fromScale((Placement.Column - 1) / GridColumns, (Placement.Row - 1) / GridRows)
			or Button.Size ~= UDim2.fromScale(Placement.Width / GridColumns, Placement.Height / GridRows)
			or Button:GetAttribute("Rotated") ~= Placement.Rotated
		)
	then
		self:ApplyEntryPlacement(Button, Placement)
	end
	if not Changed then
		return
	end

	Button:SetAttribute("Name", Item.Name)
	Button:SetAttribute("Id", InventoryStacks.Key(Item))
	Button:SetAttribute("ItemClass", Item.Class)
	Button:SetAttribute("ItemType", Item.Type)
	Button:SetAttribute("Rarity", Item.Rarity or "Common")
	ApplyItemRarity(Button, Item)

	local Label = Button:FindFirstChild("ItemName") :: TextLabel?
	if Label and Label:IsA("TextLabel") then
		Label.Visible = false
	end

	local Amount = Button:FindFirstChild("Quantity") :: TextLabel?
	if Amount then
		Amount.Visible = (Item.Stack or 1) > 1
		Amount.Text = tostring(Item.Stack or 1) .. "x"
	end

	local EquipIndex = Button:FindFirstChild("EquipIndex") :: TextLabel?
	if EquipIndex then
		local Text = ""
		if Item.Class == "Weapon" then
			if Item.Equipped and Item.EquippedLeft then
				Text = "[R/L]"
			elseif Item.Equipped then
				Text = "[R]"
			elseif Item.EquippedLeft then
				Text = "[L]"
			end
		elseif Item.Equipped then
			Text = "[E]"
		elseif Item.HotbarIndex ~= nil then
			Text = "[" .. tostring(Item.HotbarIndex) .. "]"
		end
		if EquipIndex.Text ~= Text then
			EquipIndex.Text = Text
		end
	end

	if Item.Equipped or Item.EquippedLeft then
		local Rarity = Item.Rarity or "Common"
		local Color = RarityColors[Rarity] or RarityColors.Common
		if not Entry.Outline then
			Entry.Outline = CreateOutline(Button, Color, 1)
		else
			Entry.Outline.Color = Color
		end
	elseif Entry.Outline then
		Entry.Outline:Destroy()
		Entry.Outline = nil
	end

	if ModelChanged then
		self:RenderItemVisual(Button, Item, nil, Placement)
	end
	if SelectedItem == Button and DetailsChanged then
		self:UpdateSelection(ModelChanged)
	end
end

function InventoryController:CreateEntry(Item: ItemData, Placement: InventoryGrid.Placement): ImageButton
	local Template = BackpackTemplates:FindFirstChild("ItemTemplate") :: ImageButton
	local Button = Template:Clone()
	Button.Name = InventoryStacks.Key(Item)
	BindEntryFeedback(Button)
	local Entry: RenderedItem = { Button = Button, Item = {} }
	RenderedItems[InventoryStacks.Key(Item)] = Entry
	self:UpdateEntry(Entry, Item, Placement)
	Button.Visible = true
	Button.Parent = Content

	Button.Activated:Connect(function()
		if InventoryDragController:ConsumesClick(Button) then
			return
		end

		PlayEntryClick()
		if SelectedItem == Button then
			self:Unselect()
		else
			self:Select(Button, Entry.Item)
		end
	end)
	InventoryDragController:BindItem(Button, Entry.Item)

	return Button
end

function InventoryController:UpdateStatus()
	if StatsController then
		StatsController:RefreshOtherStats()
	end
end

function InventoryController:CanDragItems(): boolean
	return self:IsOpen() and (CurrentTab == "Items" or CurrentTab == "Skills")
end

function InventoryController:ReceiveInventory(Entries: { ItemData }, Snapshot: ItemData)
	InventoryVersion += 1
	CachedEntries, CachedLayout = Entries, Snapshot
	InventoryDeleteController:ValidatePending()
	InventoryDropController:ValidatePending()
	if CurrentTab == "Items" or CurrentTab == "Skills" then
		self:UpdateContent()
	end
end

function InventoryController:UpdateContent(ForceFetch: boolean?)
	if ForceFetch then
		if CurrentTab == "Stances" then
			CachedStances = nil
			StanceVersion += 1
		else
			CachedEntries = nil
			InventoryVersion += 1
		end
	end
	if UpdateQueued or not self:IsOpen() or not Content then
		return
	end

	UpdateQueued = true
	task.defer(function()
		UpdateQueued = false
		self:ReconcileContent()
	end)
end

function InventoryController:EnsureContentData(Tab: string): boolean
	local Stances = Tab == "Stances"
	if Tab ~= "Stats" and (if Stances then CachedStances == nil else CachedEntries == nil) then
		if Fetching then
			return false
		end

		Fetching = true
		local Version = if Stances then StanceVersion else InventoryVersion
		local Success, Entries, Snapshot = pcall(function(): ({ ItemData }, ItemData?)
			if Stances then
				return StanceService:GetPlayerStances(), nil
			end
			return InventoryService:GetInventory()
		end)
		Fetching = false
		if not Success then
			warn("Could not update inventory: " .. tostring(Entries))
			return false
		end
		if Stances and Version == StanceVersion then
			CachedStances = Entries
		end
		if not Stances and Version == InventoryVersion then
			CachedEntries, CachedLayout = Entries, Snapshot
		end
		if Tab ~= CurrentTab then
			self:UpdateContent()
			return false
		end
	end

	return true
end

function InventoryController:ReconcileContent()
	if not self:IsOpen() or not Content or InventoryModalController:IsOpen() then
		return
	end
	local Tab = CurrentTab
	if not self:EnsureContentData(Tab) or not self:IsOpen() then
		return
	end

	local TabChanged = RenderedTab ~= Tab
	if TabChanged then
		self:ClearContent()
		RenderedTab = Tab
		ContentScroll.CanvasPosition = Vector2.zero
		for _, Button in Tabs:GetChildren() do
			if Button:IsA("TextButton") then
				TweenService:Create(Button, TweenInfo.new(0.2), {
					TextColor3 = if Button.Name == Tab then Color3.fromRGB(255, 238, 0) else Color3.new(1, 1, 1),
				}):Play()
			end
		end
	end
	Inventory.Visible = Tab ~= "Stats"
	StatsController:SetVisible(Tab == "Stats")
	if Tab == "Stats" then
		InventoryDragController:SetLayout({}, nil)
		return
	end

	local Entries = if Tab == "Stances" then CachedStances else CachedEntries
	local Snapshot = if Tab == "Stances" then nil else CachedLayout
	if not Entries then
		self:UpdateContent()
		return
	end
	self:ReconcileEntries(Entries, Snapshot, TabChanged)
end

function InventoryController:ReconcileEntries(Entries: { ItemData }, Snapshot: ItemData?, TabChanged: boolean)
	local Tab = CurrentTab
	local Stances = Tab == "Stances"
	local PreviousLayout = InventoryLayout
	local GridChanged = TabChanged
		or not SameData(PreviousLayout and PreviousLayout.Positions, Snapshot and Snapshot.Positions)
		or (PreviousLayout and PreviousLayout.Columns) ~= (Snapshot and Snapshot.Columns)
		or (PreviousLayout and PreviousLayout.Rows) ~= (Snapshot and Snapshot.Rows)
		or not SameData(PreviousLayout and PreviousLayout.Overflow, Snapshot and Snapshot.Overflow)
	local HotbarIndices: { [string]: number } = {}
	if Snapshot and Snapshot.Hotbar then
		for Index, Name in Snapshot.Hotbar do
			HotbarIndices[Name] = tonumber(Index)
		end
	end
	local VisibleItems, ByName = {}, {}
	for _, Entry in Entries do
		local Item = GetItemData(Entry)
		if
			Item.Hidden
			or (Tab == "Skills" and Item.Class ~= "Skill")
			or (Tab == "Items" and (Item.Class == "Skill" or Item.UsesInventoryGrid == false))
		then
			continue
		end
		Item.HotbarIndex = HotbarIndices[InventoryStacks.Key(Item)]
		table.insert(VisibleItems, Item)
		ByName[InventoryStacks.Key(Item)] = Item
		local Old = VisibleEntries[#VisibleItems]
		if
			not Old
			or InventoryStacks.Key(Old) ~= InventoryStacks.Key(Item)
			or not RenderedItems[InventoryStacks.Key(Item)]
		then
			GridChanged = true
		end
	end
	if #VisibleItems ~= #VisibleEntries then
		GridChanged = true
	end

	for Name, Entry in RenderedItems do
		if not ByName[Name] then
			InventoryDragController:RemoveItem(Name)
			if SelectedItem == Entry.Button then
				self:Unselect()
			end
			Entry.Button:Destroy()
			RenderedItems[Name] = nil
		end
	end
	InventoryLayout = Snapshot
	local Placements = if GridChanged then self:UpdateBackpackGrid(VisibleItems) else nil
	table.clear(VisibleEntries)
	for Index, Item in VisibleItems do
		local Entry = RenderedItems[InventoryStacks.Key(Item)]
		if Entry then
			self:UpdateEntry(Entry, Item, Placements and Placements[Index])
		else
			self:CreateEntry(Item, Placements[Index])
			Entry = RenderedItems[InventoryStacks.Key(Item)]
		end
		table.insert(VisibleEntries, Entry.Item)
		if Stances and TabChanged and Item.Equipped then
			self:Select(Entry.Button, Entry.Item)
		end
	end
	if not Stances then
		self:RefreshEquipmentSlots(Entries, Snapshot)
	end
	InventoryDragController:SetLayout(Entries, Snapshot)
end

function InventoryController:ChangeTab(TabName: string)
	if not TabNames[TabName] then
		return
	end
	InventoryModalController:Cancel()
	InventoryDragController:Cancel()
	if CurrentTab == TabName then
		return
	end

	self:Unselect()
	CurrentTab = TabName
	HotbarController:UpdateVisibility()
	self:UpdateContent()
end

function InventoryController:CycleTab(Direction: number)
	if not self:IsOpen() or InventoryModalController:IsOpen() then
		return
	end

	local Available: { TextButton } = {}
	for _, Button in Tabs:GetChildren() do
		if Button:IsA("TextButton") and Button.Visible and TabNames[Button.Name] then
			table.insert(Available, Button)
		end
	end
	table.sort(Available, function(Left: TextButton, Right: TextButton): boolean
		return if Left.LayoutOrder == Right.LayoutOrder then Left.Name < Right.Name else Left.LayoutOrder < Right.LayoutOrder
	end)
	if #Available == 0 then
		return
	end

	local Current = 1
	for Index, Button in Available do
		if Button.Name == CurrentTab then
			Current = Index
			break
		end
	end
	self:ChangeTab(Available[(Current - 1 + Direction) % #Available + 1].Name)
end

function InventoryController.KnitInit()
	InventoryService = Knit.GetService("InventoryService")
	StanceService = Knit.GetService("StanceService")
	HotbarController = Knit.GetController("HotbarController")
	MenuController = Knit.GetController("MenuController")
	ViewportRotationController = Knit.GetController("ViewportRotationController")
	StatsController = Knit.GetController("StatsController")
	InventoryDragController = Knit.GetController("InventoryDragController")
	InventoryDeleteController = Knit.GetController("InventoryDeleteController")
	InventoryDropController = Knit.GetController("InventoryDropController")
	InventoryModalController = Knit.GetController("InventoryModalController")
end

function InventoryController.KnitStart()
	local PlayerGui = Player:WaitForChild("PlayerGui") :: PlayerGui
	local Menus = PlayerGui:WaitForChild("Menu") :: ScreenGui
	MainMenu = (
		PlayerGui:FindFirstChild("MainMenu")
		or Menus:FindFirstChild("MainMenu")
		or PlayerGui:WaitForChild("MainMenu")
	) :: ScreenGui
	HotbarController:ConfigureInventory(MainMenu)
	local CloseButton = MainMenu:WaitForChild("Close") :: ImageButton
	CloseButton.Modal = false
	Inventory = MainMenu:WaitForChild("Inventory") :: Frame
	Equipments = Inventory:WaitForChild("Equipments") :: Frame
	BackpackPanel = Inventory:WaitForChild("BackpackPanel") :: Frame
	BackpackTemplates = BackpackPanel:WaitForChild("Templates") :: Folder
	Tabs = MainMenu:WaitForChild("Tabs") :: GuiObject
	local ScrollWrapper = BackpackPanel:WaitForChild("ScrollWrapper") :: Frame
	ContentScroll = ScrollWrapper:WaitForChild("Scroll") :: ScrollingFrame
	GridCanvas = ContentScroll:WaitForChild("GridCanvas") :: Frame
	Content = GridCanvas:WaitForChild("ItemsLayer") :: Frame
	ItemInfo = Inventory:WaitForChild("ItemInfo") :: Frame
	Description = ItemInfo:WaitForChild("Description") :: TextLabel
	ItemName = ItemInfo:WaitForChild("TextLabel") :: TextLabel
	BasicStats = ItemInfo:WaitForChild("BasicStats") :: Frame
	Display = ItemInfo:WaitForChild("Display") :: Frame
	InventoryModalController:Configure(MainMenu, Inventory)
	InventoryDeleteController:Configure(MainMenu, Inventory)
	InventoryDropController:Configure(Inventory)
	InventoryDragController:Configure({
		Main = MainMenu,
		Panel = BackpackPanel,
		Canvas = GridCanvas,
		Scroll = ContentScroll,
		EquipmentButtons = EquipmentButtons,
	})
	local Viewport = Display:FindFirstChildWhichIsA("ViewportFrame")
	if Viewport then
		ViewportRotationController:BindViewport(Viewport)
	end

	local Buttons = ItemInfo:WaitForChild("Buttons") :: Frame
	EquipButton = Buttons:WaitForChild("Equip") :: ImageButton
	EquipLeftButton = Buttons:WaitForChild("EquipLeft") :: ImageButton
	EquipLeftButton.Active = true

	local LegacyTemplates = Inventory:FindFirstChild("Templates") :: Frame?
	if LegacyTemplates then
		LegacyTemplates.Visible = false
	end

	MainMenu.Enabled = false
	Inventory.Visible = true
	StatsController:SetVisible(false)
	local GridRatio = GridCanvas:FindFirstChildWhichIsA("UIAspectRatioConstraint")
	if GridRatio then
		GridRatio:Destroy()
	end

	ContentScroll.AutomaticCanvasSize = Enum.AutomaticSize.None
	ContentScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	ContentScroll.ClipsDescendants = true
	ContentScroll:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function()
		InventoryController:ResizeBackpackCanvas()
	end)
	InventoryController:ResizeBackpackCanvas()
	InventoryController:ClearContent()

	local EquipmentScrollWrapper = Equipments:WaitForChild("ScrollWrapper") :: Frame
	local EquipmentScroll = EquipmentScrollWrapper:WaitForChild("Scroll") :: ScrollingFrame
	InventoryController:CreateWeaponSlots(EquipmentScroll)
	for _, Button in EquipmentScroll:QueryDescendants("ImageButton") do
		local SlotName = Button:GetAttribute("EquipmentSlot")
		if typeof(SlotName) == "string" then
			EquipmentButtons[SlotName] = Button
			local Outline = Button:FindFirstChildWhichIsA("UIStroke")
			local Texture = Button:FindFirstChild("Texture") :: ImageLabel?
			EquipmentColors[Button] = {
				Background = Button.BackgroundColor3,
				Border = Outline and Outline.Color,
				Texture = Texture and Texture.ImageColor3,
			}

			Button.Activated:Connect(function()
				InventoryController:UnequipEquipmentSlot(SlotName)
			end)
		end
	end

	for _, Button in Tabs:GetChildren() do
		if Button:IsA("TextButton") then
			Button:SetAttribute("callback", nil)
			Button.Activated:Connect(function()
				InventoryController:ChangeTab(Button.Name)
			end)
		end
	end

	CloseButton:SetAttribute("callback", nil)
	MenuController:BindCloseButton(CloseButton, function()
		MenuController:CloseAllMenus()
	end)

	EquipButton:SetAttribute("callback", nil)
	EquipLeftButton:SetAttribute("callback", nil)
	EquipButton.Activated:Connect(function()
		InventoryController:EquipItem()
	end)
	EquipLeftButton.Activated:Connect(function()
		InventoryController:EquipLeftItem()
	end)

	MainMenu:GetPropertyChangedSignal("Enabled"):Connect(function()
		InventoryModalController:Cancel()
		CloseButton.Modal = MainMenu.Enabled

		if MainMenu.Enabled then
			CurrentTab = "Items"
			InventoryController:Unselect()
			HotbarController:CancelSlotSelection()
			MenuController:SetHudFocus(true)
			HotbarController:UpdateVisibility()
			InventoryController:UpdateContent()
		else
			InventoryDragController:Cancel()
			InventoryController:Unselect()

			if not HotbarController:IsSelectingSlot() then
				MenuController:SetHudFocus(false)
			end

			HotbarController:UpdateVisibility()
		end
	end)

	InventoryService.InventoryUpdated:Connect(function(Entries: { ItemData }, Snapshot: ItemData?)
		if Snapshot then
			InventoryController:ReceiveInventory(Entries, Snapshot)
		else
			InventoryController:UpdateContent(true)
		end
	end)
	InventoryService.InventoryLayoutUpdated:Connect(function(Snapshot: ItemData)
		if not InventoryController:ApplyLayout(Snapshot) then
			InventoryController:UpdateContent(true)
		end
	end)
	StanceService.UpdateUI:Connect(function(Entries: { ItemData })
		StanceVersion += 1
		CachedStances = Entries
		if CurrentTab == "Stances" then
			InventoryController:UpdateContent()
		end
	end)
end

return InventoryController
