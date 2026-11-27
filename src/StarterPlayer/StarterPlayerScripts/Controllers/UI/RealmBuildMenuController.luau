local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Building = require(ReplicatedStorage.Shared.RealmBuilding)
local Catalog = require(ReplicatedStorage.Shared.RealmCatalog)
local Resources = require(ReplicatedStorage.Shared.RealmResources)
local Items = require(ReplicatedStorage.Shared.Index.Items)

local RealmBuildMenuController = Knit.CreateController({ Name = "RealmBuildMenuController" })
local Player = Players.LocalPlayer
local Editor, Placement, Deletion, Transform, History, Pointer, Mobile, ResourceController, InventoryService, AlertController
local MenuController
local Gui: ScreenGui
local List: Frame
local Scroll: ScrollingFrame
local Search: TextBox
local Details: Frame
local Templates: Folder
local SelectedTab: string? = nil
local SelectedCategory: string? = nil
local Placing = false
local DeleteStroke: UIStroke? = nil
local DeleteStrokeColor: Color3? = nil
local TransformStroke: UIStroke? = nil
local TransformStrokeColor: Color3? = nil
local Tools: Frame? = nil
local ToolsContent: Frame? = nil
local DeleteIcon: ImageLabel? = nil
local DeleteTitle: TextLabel? = nil
local TransformIcon: ImageLabel? = nil
local TransformTitle: TextLabel? = nil
local HistoryButtons: { [string]: ImageButton } = {}
local BuildOptionImages: { [ImageButton]: string } = {}
local ListButtonWidths: { [ImageButton]: UDim } = {}
local OwnedResources: { [string]: number } = {}
local ResourceLabels: { [string]: TextLabel } = {}
local DetailsCost: Resources.Cost = {}
local InventoryVersion = 0
type ObjectButtonState = { Cost: Resources.Cost?, Background: Color3 }
local ObjectButtons: { [ImageButton]: ObjectButtonState } = {}
local UNAVAILABLE_COLOR = Color3.fromRGB(160, 43, 43)
local SELECTED_BUILD_OPTION_IMAGE = "rbxassetid://76901907637872"

local function CanAfford(Cost: Resources.Cost?): boolean
	if not Cost then
		return false
	end
	if not ResourceController:AreResourcesRequired() then
		return true
	end

	for Name, Amount in Cost do
		if (OwnedResources[Name] or 0) < Amount then
			return false
		end
	end

	return true
end

local function RefreshObjectButtons()
	for Button, State in ObjectButtons do
		Button.BackgroundColor3 = if CanAfford(State.Cost) then State.Background else UNAVAILABLE_COLOR
	end
end

local function RenderTools()
	if not Tools or not ToolsContent then
		return
	end
	local Deleting = Deletion:IsActive()
	local Transforming = Transform:IsActive()
	Tools.Visible = UserInputService.MouseEnabled and not Pointer:IsTouch()
	for _, Tool in ToolsContent:GetChildren() do
		if Tool:IsA("GuiButton") then
			Tool.Visible = (Tool.Name == "Delete" and not Transforming) or (Tool.Name == "Transform" and not Deleting)
				or (not Deleting and not Transforming and (Tool.Name == "Back" or Tool.Name == "Forward"))
		end
	end
	if TransformStroke and TransformStrokeColor then
		TransformStroke.Color = if Transforming then Color3.fromRGB(65, 145, 255) else TransformStrokeColor
	end
	if DeleteIcon then
		DeleteIcon.Visible = not Deleting
	end
	if DeleteTitle then
		DeleteTitle.Visible = Deleting
	end
	if TransformIcon then
		TransformIcon.Visible = not Transforming
	end
	if TransformTitle then
		TransformTitle.Visible = Transforming
	end
end

local function RenderHistoryButtons()
	for Direction, Button in HistoryButtons do
		local Available = if Direction == "Undo" then History:CanUndo() else History:CanRedo()
		Button.AutoButtonColor = Available
		Button.Selectable = Available
		local Icon = Button:FindFirstChild("Icon") :: ImageLabel?
		if Icon then
			Icon.ImageTransparency = if Available then 0 else 0.65
		end
	end
end

local function SetText(Parent: Instance, Name: string, Text: string)
	local Label = Parent:FindFirstChild(Name)
	if Label and Label:IsA("TextLabel") then
		Label.Text = Text
	end
end

local function DisplayObject(Container: GuiObject, Asset: PVInstance)
	local Icon = Container:FindFirstChild("Icon") :: ImageLabel?
	local Viewport = Container:FindFirstChildWhichIsA("ViewportFrame")
	local Image = Asset:GetAttribute("Icon")
	if Icon then
		Icon.ImageColor3 = Color3.new(1, 1, 1)
		Icon.Visible = typeof(Image) == "string" and Image ~= ""
		Icon.Image = if typeof(Image) == "string" then Image else ""
	end
	if not Viewport then
		return
	end
	Viewport.ImageColor3 = Color3.new(1, 1, 1)

	for _, Child in Viewport:GetChildren() do
		if Child:IsA("Camera") or Child:IsA("WorldModel") then
			Child:Destroy()
		end
	end
	Viewport.Visible = not Icon or not Icon.Visible
	if not Viewport.Visible then
		return
	end

	local World = Instance.new("WorldModel")
	World.Parent = Viewport
	local Model = Building.Clone(Asset)
	Building.Prepare(Model, false)
	Model:PivotTo(CFrame.identity)
	Model.Parent = World
	local Bounds = Building.GetBounds(Model)
	local Camera = Instance.new("Camera")
	Camera.FieldOfView = 35
	local Distance = Bounds.Size.Magnitude / (2 * math.tan(math.rad(Camera.FieldOfView / 2))) * 1.15
	local Center = Bounds.Offset.Position
	Camera.CFrame = CFrame.lookAt(Center + Vector3.new(1, 0.65, 1).Unit * Distance, Center)
	Camera.Parent = Viewport
	Viewport.CurrentCamera = Camera
end

local function RefreshResourceAmounts()
	RefreshObjectButtons()
	local ResourcesRequired = ResourceController:AreResourcesRequired()
	for Name, Label in ResourceLabels do
		local Owned, Required = OwnedResources[Name] or 0, DetailsCost[Name]
		Label.Text = if ResourcesRequired then tostring(Owned) .. "/" .. tostring(Required) .. " " .. (Items[Name].DisplayName or Name) else "Free"
		Label.TextColor3 = if not ResourcesRequired or Owned >= Required then Color3.fromRGB(180, 230, 180) else Color3.fromRGB(255, 140, 140)
	end
end

local function RenderCosts(Asset: PVInstance)
	local Container = Details:FindFirstChild("Resources") :: Frame?
	if not Container then
		return
	end
	local Template = Container:FindFirstChild("Template") :: Frame?
	if not Template then
		return
	end
	Template.Visible = false
	for _, Child in Container:GetChildren() do
		if Child:IsA("Frame") and Child ~= Template then
			Child:Destroy()
		end
	end
	table.clear(ResourceLabels)
	DetailsCost = Resources.GetCost(Asset) or {}
	local Names = Resources.GetNames(DetailsCost)
	Container.Visible = #Names > 0
	for Index, Name in Names do
		local Row = Template:Clone()
		Row.Name = Name
		Row.LayoutOrder = Index
		Row.Size = UDim2.fromScale(1 / #Names - 0.02, 1)
		local Label = Row:WaitForChild("Amount") :: TextLabel
		local Icon = Row:FindFirstChildWhichIsA("ImageLabel")
		if Icon then
			Icon.Visible = Items[Name].Icon ~= nil
			Icon.Image = Items[Name].Icon or ""
		end
		if not Icon or not Icon.Visible then
			Label.Size = UDim2.fromScale(1, 1)
			Label.Position = UDim2.fromScale(0.5, 0.5)
		end
		ResourceLabels[Name] = Label
		Row.Visible = true
		Row.Parent = Container
	end
	RefreshResourceAmounts()
end

local function ShowDetails(Asset: PVInstance, Button: GuiButton, CategoryName: string)
	if Placing or Deletion:IsActive() or Transform:IsActive() then
		return
	end

	SetText(Details, "Amount", Asset:GetAttribute("DisplayName") or Asset.Name)
	SetText(Details, "Category", CategoryName)
	SetText(Details, "Description", Asset:GetAttribute("Description") or "")
	RenderCosts(Asset)
	DisplayObject(Details:WaitForChild("Display") :: Frame, Asset)
	local X = math.clamp(Button.AbsolutePosition.X - List.AbsolutePosition.X, 0,
		math.max(0, List.AbsoluteSize.X - Details.AbsoluteSize.X))
	Details.Position = UDim2.fromOffset(X, -6)
	Details.Visible = true
end

local function SortedChildren(Parent: Instance): { Instance }
	local Children = Parent:GetChildren()
	table.sort(Children, function(A: Instance, B: Instance): boolean
		return A.Name < B.Name
	end)

	return Children
end

local function ClearList()
	Details.Visible = false
	table.clear(ObjectButtons)
	table.clear(ListButtonWidths)
	for _, Child in Scroll:GetChildren() do
		if Child:IsA("GuiButton") then
			Child:Destroy()
		end
	end
end

local function ResizeListButton(Button: ImageButton, Width: UDim)
	Button.Size = UDim2.new(0, Scroll.AbsoluteWindowSize.X * Width.Scale + Width.Offset,
		Button.Size.Y.Scale, Button.Size.Y.Offset)
end

local function RegisterListButton(Button: ImageButton)
	local Width = Button.Size.X
	ListButtonWidths[Button] = Width
	ResizeListButton(Button, Width)
end

local function Render()
	if not Gui then
		return
	end

	for Button, OriginalImage in BuildOptionImages do
		Button.Image = if Button.Name == SelectedTab then SELECTED_BUILD_OPTION_IMAGE else OriginalImage
	end

	RenderTools()
	ClearList()
	Scroll.CanvasPosition = Vector2.zero
	List.Visible = Editor:IsOpen() and SelectedTab ~= nil and not Placing and not Deletion:IsActive() and not Transform:IsActive()
	if not SelectedTab then
		return
	end

	local Root = Building.GetRoot()
	local Tab = Root and Root:FindFirstChild(SelectedTab)
	if not Tab then
		return
	end
	local Searching = string.find(Search.Text, "%S") ~= nil
	if SelectedCategory or Searching then
		local CategoryName = if SelectedCategory == "ALL" then nil else SelectedCategory
		for Index, Entry in Catalog.GetObjects(Tab, CategoryName, Search.Text) do
			local Child = Entry.Asset
			local Button = Templates:WaitForChild("ObjectTemplate"):Clone() :: ImageButton
			RegisterListButton(Button)
			ObjectButtons[Button] = { Cost = Resources.GetCost(Child), Background = Button.BackgroundColor3 }
			Button.Name = Child.Name
			Button.LayoutOrder = Index
			SetText(Button, "ItemName", Child:GetAttribute("DisplayName") or Child.Name)
			DisplayObject(Button, Child)
			Button.Visible = true
			Button.Parent = Scroll
			Button.MouseEnter:Connect(function()
				ShowDetails(Child, Button, Entry.CategoryName)
			end)
			Button.MouseLeave:Connect(function()
				Details.Visible = false
			end)
			Button.SelectionGained:Connect(function()
				ShowDetails(Child, Button, Entry.CategoryName)
			end)
			Button.SelectionLost:Connect(function()
				Details.Visible = false
			end)
			Button.Activated:Connect(function()
				Deletion:Stop()
				Mobile:Close()
				if Placement:Start(Entry.Key) then
					Placing = true
					List.Visible = false
					Details.Visible = false
				end
			end)
		end
	else
		local Categories = SortedChildren(Tab)
		table.insert(Categories, 1, Tab)
		for Index, Child in Categories do
			if not Child:IsA("Folder") then
				continue
			end
			local IsAll = Child == Tab
			local Button = Templates:WaitForChild("CategoryTemplate"):Clone() :: ImageButton
			RegisterListButton(Button)
			Button.Name = if IsAll then "ALL" else Child.Name
			Button.LayoutOrder = Index
			SetText(Button, "ItemName", if IsAll then "ALL" else Child:GetAttribute("DisplayName") or Child.Name)
			Button.Visible = true
			Button.Parent = Scroll
			Button.Activated:Connect(function()
				SelectedCategory = if IsAll then "ALL" else Child.Name
				Search.Text = ""
				Render()
			end)
		end
	end
	RefreshObjectButtons()
end

local function BindGui(Screen: ScreenGui)
	Gui = Screen
	Gui.ResetOnSpawn = false
	Gui.Enabled = Editor:IsOpen()
	List = Gui:WaitForChild("List") :: Frame
	Details = List:WaitForChild("ItemDetails") :: Frame
	Templates = List:WaitForChild("Templates") :: Folder
	local Wrapper = List:WaitForChild("ScrollWrapper") :: Frame
	Scroll = Wrapper:WaitForChild("Scroll") :: ScrollingFrame
	local SearchFrame = List:WaitForChild("Search") :: ImageLabel
	Search = SearchFrame:WaitForChild("Search") :: TextBox
	Scroll.Active = true
	Scroll.ScrollingEnabled = true
	Scroll.ClipsDescendants = true
	Scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
	Scroll.CanvasSize = UDim2.fromScale(0, 0)
	Scroll.ScrollingDirection = Enum.ScrollingDirection.X
	local Layout = Scroll:FindFirstChildWhichIsA("UIListLayout")
	if Layout then
		Layout.FillDirection = Enum.FillDirection.Horizontal
		Layout.Wraps = false
		Layout.SortOrder = Enum.SortOrder.LayoutOrder

		local Padding = Layout.Padding
		local function ResizeList()
			Layout.Padding = UDim.new(0, Scroll.AbsoluteWindowSize.X * Padding.Scale + Padding.Offset)
			for Button, Width in ListButtonWidths do
				ResizeListButton(Button, Width)
			end
		end

		local function UpdateCanvas()
			Scroll.CanvasSize = UDim2.fromOffset(math.ceil(Layout.AbsoluteContentSize.X), 0)
		end

		Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateCanvas)
		Scroll:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(ResizeList)
		ResizeList()
		UpdateCanvas()
	end

	local ResourcePanel = Gui:FindFirstChild("Resources") :: Frame?
	if ResourcePanel then
		ResourcePanel.Visible = false
	end
	Tools = Gui:WaitForChild("Tools") :: Frame
	ToolsContent = Tools:WaitForChild("Content") :: Frame
	local Delete = ToolsContent:WaitForChild("Delete") :: ImageButton
	DeleteIcon = Delete:FindFirstChild("Icon") :: ImageLabel?
	DeleteTitle = Delete:FindFirstChild("Title") :: TextLabel?
	DeleteStroke = Delete:FindFirstChildWhichIsA("UIStroke")
	DeleteStrokeColor = if DeleteStroke then DeleteStroke.Color else nil
	Delete.Activated:Connect(function()
		Deletion:Toggle()
	end)
	local TransformButton = ToolsContent:WaitForChild("Transform") :: ImageButton
	TransformIcon = TransformButton:FindFirstChild("Icon") :: ImageLabel?
	TransformTitle = TransformButton:FindFirstChild("Title") :: TextLabel?
	TransformStroke = TransformButton:FindFirstChildWhichIsA("UIStroke")
	TransformStrokeColor = if TransformStroke then TransformStroke.Color else nil
	TransformButton.Activated:Connect(function()
		Transform:Toggle()
	end)
	for Name, Direction in { Back = "Undo", Forward = "Redo" } do
		local Button = ToolsContent:WaitForChild(Name) :: ImageButton
		HistoryButtons[Direction] = Button
		Button.Activated:Connect(function()
			History:Request(Direction)
		end)
	end
	RenderHistoryButtons()
	local Options = Gui:WaitForChild("BuildOptions") :: Frame
	local Buttons = Options:WaitForChild("Buttons") :: Frame
	table.clear(BuildOptionImages)
	for _, TabName in { "Decorations", "Utility", "Terrain" } do
		local Button = Buttons:WaitForChild(TabName) :: ImageButton
		BuildOptionImages[Button] = Button.Image
		Button.Activated:Connect(function()
			if not Editor:IsOpen() then
				return
			end
			if TabName == "Terrain" then
				AlertController:Alert("Terrain editing is coming later.", "Warn")
				return
			end

			Deletion:Stop()
			Mobile:Close()
			Placement:Cancel()
			Transform:Cancel()
			SelectedTab = TabName
			SelectedCategory = nil
			Search.Text = ""
			Render()
		end)
	end

	local Close = List:WaitForChild("Close") :: ImageButton
	MenuController:BindCloseButton(Close, function()
		if SelectedCategory then
			SelectedCategory = nil
		else
			SelectedTab = nil
		end
		Search.Text = ""
		Render()
	end)
	Search:GetPropertyChangedSignal("Text"):Connect(Render)
	Render()
end

function RealmBuildMenuController.KnitInit()
	MenuController = Knit.GetController("MenuController")
	Editor = Knit.GetController("RealmEditorController")
	Placement = Knit.GetController("RealmPlacementController")
	Deletion = Knit.GetController("RealmDeletionController")
	Transform = Knit.GetController("RealmTransformController")
	History = Knit.GetController("RealmHistoryController")
	Pointer = Knit.GetController("RealmPointerController")
	Mobile = Knit.GetController("RealmMobileController")
	ResourceController = Knit.GetController("RealmResourceController")
	InventoryService = Knit.GetService("InventoryService")
	AlertController = Knit.GetController("AlertController")
end

function RealmBuildMenuController.KnitStart()
	ResourceController.Changed:Connect(RefreshResourceAmounts)
	local function UpdateInventory(Entries: { any })
		InventoryVersion += 1
		table.clear(OwnedResources)
		for _, Item in Entries do
			OwnedResources[Item.Name] = (OwnedResources[Item.Name] or 0) + (Item.Stack or 0)
		end
		RefreshResourceAmounts()
	end
	InventoryService.InventoryUpdated:Connect(UpdateInventory)
	local Version = InventoryVersion
	task.spawn(function()
		local Success, Entries = pcall(function(): { any }
			return InventoryService:GetInventory()
		end)
		if Success and InventoryVersion == Version then
			UpdateInventory(Entries)
		elseif not Success then
			warn("[RealmBuildMenu] Unable to load resource counts:", Entries)
		end
	end)
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(RenderTools)
	History.Changed:Connect(RenderHistoryButtons)
	Transform.Changed:Connect(Render)
	Editor.Changed:Connect(function(Active: boolean)
		if Gui then
			Gui.Enabled = Active
			if not Active then
				SelectedTab, SelectedCategory = nil, nil
				Placing = false
			end
			Render()
		end
	end)
	Placement.Finished:Connect(function()
		Placing = false
		Render()
	end)
	Placement.Started:Connect(function()
		Placing = true
		Render()
	end)
	Deletion.Changed:Connect(function(Active: boolean)
		if DeleteStroke and DeleteStrokeColor then
			DeleteStroke.Color = if Active then Color3.fromRGB(235, 55, 55) else DeleteStrokeColor
		end
		Render()
	end)

	local PlayerGui = Player:WaitForChild("PlayerGui") :: PlayerGui
	local Screen = PlayerGui:WaitForChild("RealmEdit") :: ScreenGui
	BindGui(Screen)
end

return RealmBuildMenuController
