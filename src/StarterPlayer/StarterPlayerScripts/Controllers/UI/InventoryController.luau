local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Items = require(ReplicatedStorage.Shared.Index.Items)
local RangedWeaponConfig = require(ReplicatedStorage.Shared.RangedWeaponConfig)

type ItemData = { [string]: any }

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

local DISPLAY_DISTANCE_SCALE = 0.8

local MainMenu: ScreenGui
local Inventory: Frame
local Templates: Frame
local Tabs: GuiObject
local Content: ScrollingFrame
local ContentLayout: UIListLayout
local ItemInfo: Frame
local Description: TextLabel
local ItemName: TextLabel
local BasicStats: Frame
local Display: Frame
local EquipButton: ImageButton
local EquipLeftButton: ImageButton

local CurrentTab = "Items"
local SelectedItem: ImageButton? = nil
local SelectedItemData: ItemData? = nil
local RenderRevision = 0
local EquippedVisuals = {}
local SelectedVisuals = {}

local RarityColors = {
	Common = Color3.fromRGB(230, 230, 230),
	Uncommon = Color3.fromRGB(110, 220, 120),
	Rare = Color3.fromRGB(90, 160, 255),
	Epic = Color3.fromRGB(190, 110, 255),
	Legendary = Color3.fromRGB(255, 200, 70),
	Mythic = Color3.fromRGB(255, 100, 100),
}

local TabNames = { Items = true, Skills = true, Stances = true, Stats = true }

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

local function FitViewportCamera(Viewport: ViewportFrame, Model: Model, Distance: number?, DistanceScale: number?)
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
	CameraDistance *= DistanceScale or 1

	Camera.CFrame = CFrame.new(Bounds.Position + Vector3.new(0, 0, CameraDistance))
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

function InventoryController:IsOpen(): boolean
	return MainMenu ~= nil and MainMenu.Enabled
end

function InventoryController:CanAssignToHotbar(): boolean
	return self:IsOpen()
		and SelectedItemData ~= nil
		and SelectedItemData.Class ~= "Weapon"
		and SelectedItemData.Class ~= "Equipable"
		and SelectedItemData.Class ~= "Stance"
		and SelectedItemData.Type ~= "Ammunition"
end

function InventoryController:RefreshHotbar()
	if HotbarController then
		HotbarController:LoadHotbar(HotbarController:HotbarEnabledBooleans())
	end
end

function InventoryController:Unselect()
	ClearVisuals(SelectedVisuals)
	SelectedItem = nil
	SelectedItemData = nil

	if ItemInfo then
		ItemInfo.Visible = false
		Description.Visible = false

		local Viewport = Display:FindFirstChildWhichIsA("ViewportFrame")
		if Viewport then
			ViewportRotationController:StopRotation(Viewport)
			ClearViewport(Viewport)
		end
	end

	self:RefreshHotbar()
end

function InventoryController:ClearContent()
	RenderRevision += 1
	self:Unselect()
	ClearVisuals(EquippedVisuals)

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
	local Viewport = Template:FindFirstChildWhichIsA("ViewportFrame")
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

function InventoryController:AddModelToViewport(Viewport: ViewportFrame, Item: ItemData, DistanceScale: number?)
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

	FitViewportCamera(Viewport, Model, Source:GetAttribute("InventoryDistance"), DistanceScale)
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
	SelectedItemData = Item

	ItemName.Text = Item.DisplayName or Item.Name
	BasicStats.Amount.Text = tostring(Item.Stack or 1) .. "x"
	BasicStats.Amount.Visible = Item.Class ~= "Stance"
	BasicStats.ItemType.Text = Item.Type or Item.WeaponType or Item.Class or ""
	BasicStats.Rarity.Text = Item.Rarity or "Common"
	Description.Text = Item.Description or ""
	Description.Visible = Description.Text ~= ""

	local Rarity = Item.Rarity or "Common"
	local RarityColor = RarityColors[Rarity] or RarityColors.Common
	table.insert(SelectedVisuals, CreateOutline(Button, Color3.fromRGB(255, 238, 0), 2))
	BasicStats.Rarity.TextColor3 = RarityColor

	local Viewport = self:ConfigureViewport(Display)
	if Viewport then
		local Placeholder = Display:FindFirstChildWhichIsA("ImageLabel")
		if Placeholder then
			Placeholder.Visible = false
		end

		if Item.Class == "Stance" then
			self:LoadStanceViewport(Viewport, Item)
		else
			self:AddModelToViewport(Viewport, Item, DISPLAY_DISTANCE_SCALE)
		end
	end

	EquipButton.Visible = Item.Class == "Equipable"
		or Item.Class == "Weapon"
		or Item.Class == "Stance"
		or self:CanAssignToHotbar()
	EquipLeftButton.Visible = Item.Class == "Weapon" and (Item.CanEquipLeft == true or Item.EquippedLeft == true)
	SetButtonText(EquipButton, if Item.Equipped then "UNEQUIP" else "EQUIP")
	if Item.Class == "Stance" and Item.Equipped then
		SetButtonText(EquipButton, "EQUIPPED")
	end
	SetButtonText(EquipLeftButton, if Item.EquippedLeft then "UNEQUIP LEFT" else "EQUIP LEFT")

	ItemInfo.Visible = true
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
			self:UpdateContent()
		end
	elseif Item.Class == "Weapon" or Item.Class == "Equipable" then
		InventoryService:EquipUnequipItem(Item.Name)
	elseif self:CanAssignToHotbar() then
		HotbarController:BeginSlotSelection(Item.Name)
	end
end

function InventoryController:EquipLeftItem()
	local Item = SelectedItemData
	if Item and Item.Class == "Weapon" and (Item.CanEquipLeft or Item.EquippedLeft) then
		InventoryService:EquipUnequipLeftItem(Item.Name)
	end
end

function InventoryController:CreateEntry(Item: ItemData, TemplateName: string, Index: number): ImageButton
	local Template = Templates:FindFirstChild(TemplateName .. "Wrapper") :: Frame
	local Wrapper = Template:Clone()
	local Button = Wrapper:FindFirstChild(TemplateName) :: ImageButton
	Wrapper.Name = Item.Name
	Wrapper.LayoutOrder = Index + (if Item.Equipped or Item.EquippedLeft then 0 else 1000)

	Button.Name = Item.Name
	Button:SetAttribute("Name", Item.Name)
	Button:SetAttribute("ItemClass", Item.Class)
	Button:SetAttribute("ItemType", Item.Type)
	Button:SetAttribute("Rarity", Item.Rarity or "Common")

	local Label = Button:FindFirstChild("ItemName") or Button:FindFirstChild("StanceName")
	if Label and Label:IsA("TextLabel") then
		Label.Text = Item.DisplayName or Item.Name
	end

	local Amount = Button:FindFirstChild("Amount") :: TextLabel?
	if Amount then
		Amount.Visible = (Item.Stack or 1) > 1
		Amount.Text = tostring(Item.Stack or 1) .. "x"
	end

	local EquipIndex = Button:FindFirstChild("EquipIndex") :: TextLabel?
	if EquipIndex then
		EquipIndex.Text = ""
		if Item.Class == "Weapon" then
			if Item.Equipped and Item.EquippedLeft then
				EquipIndex.Text = "[R/L]"
			elseif Item.Equipped then
				EquipIndex.Text = "[R]"
			elseif Item.EquippedLeft then
				EquipIndex.Text = "[L]"
			end
		elseif Item.Equipped then
			EquipIndex.Text = "[E]"
		else
			local Tool = HotbarController:GetToolByNameFromPlayer(Item.Name)
			local HotbarIndex = Tool and Tool:GetAttribute("HotbarIndex")
			if HotbarIndex ~= nil and Tool:GetAttribute("Class") ~= "Artifact" then
				EquipIndex.Text = "[" .. tostring(HotbarIndex) .. "]"
			end
		end
	end

	if Item.Equipped or Item.EquippedLeft then
		local Rarity = Item.Rarity or "Common"
		table.insert(EquippedVisuals, CreateOutline(Button, RarityColors[Rarity] or RarityColors.Common, 1))
	end

	local Viewport = self:ConfigureViewport(Button)
	if Viewport then
		if Item.Class == "Stance" then
			self:LoadStanceViewport(Viewport, Item)
		else
			self:AddModelToViewport(Viewport, Item)
		end
	end

	Button.Activated:Connect(function()
		if SelectedItem == Button then
			self:Unselect()
		else
			self:Select(Button, Item)
		end
	end)

	Button.Visible = true
	Wrapper.Visible = true
	Wrapper.Parent = Content

	return Button
end

function InventoryController:UpdateStatus()
	if StatsController then
		StatsController:RefreshOtherStats()
	end
end

function InventoryController:UpdateContent()
	if not self:IsOpen() or not Content then
		return
	end

	local SelectedName = SelectedItemData and SelectedItemData.Name
	self:ClearContent()
	local Revision = RenderRevision
	local Tab = CurrentTab
	Inventory.Visible = Tab ~= "Stats"
	StatsController:SetVisible(Tab == "Stats")

	Content.CanvasPosition = Vector2.zero
	ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	ContentLayout.FillDirection = Enum.FillDirection.Horizontal
	ContentLayout.Wraps = true

	for _, Button in Tabs:GetChildren() do
		if Button:IsA("TextButton") then
			TweenService:Create(Button, TweenInfo.new(0.2), {
				TextColor3 = if Button.Name == Tab then Color3.fromRGB(255, 238, 0) else Color3.new(1, 1, 1),
			}):Play()
		end
	end

	if Tab == "Stats" then
		return
	end

	local Entries = if Tab == "Stances" then StanceService:GetPlayerStances() else InventoryService:GetInventory()
	if Revision ~= RenderRevision or Tab ~= CurrentTab or not self:IsOpen() then
		return
	end

	if Tab == "Stances" and not SelectedName then
		for _, Entry in Entries do
			if Entry.Equipped then
				SelectedName = Entry.Name
				break
			end
		end
	end

	for Index, Entry in Entries do
		local Item = GetItemData(Entry)
		if Item.Hidden or (Tab == "Skills" and Item.Class ~= "Skill") or (Tab == "Items" and Item.Class == "Skill") then
			continue
		end

		local TemplateName = if Tab == "Stances" then "StanceTemplate" elseif Tab == "Skills" then "SkillTemplate" else "ItemTemplate"
		local Button = self:CreateEntry(Item, TemplateName, Index)
		if Item.Name == SelectedName then
			self:Select(Button, Item)
		end
	end
end

function InventoryController:ChangeTab(TabName: string)
	if not TabNames[TabName] or CurrentTab == TabName then
		return
	end

	self:Unselect()
	CurrentTab = TabName
	self:UpdateContent()
end

function InventoryController.KnitInit()
	InventoryService = Knit.GetService("InventoryService")
	StanceService = Knit.GetService("StanceService")
	HotbarController = Knit.GetController("HotbarController")
	MenuController = Knit.GetController("MenuController")
	ViewportRotationController = Knit.GetController("ViewportRotationController")
	StatsController = Knit.GetController("StatsController")
end

function InventoryController.KnitStart()
	local PlayerGui = Player:WaitForChild("PlayerGui") :: PlayerGui
	local Menus = PlayerGui:WaitForChild("Menu") :: ScreenGui
	MainMenu = (PlayerGui:FindFirstChild("MainMenu") or Menus:WaitForChild("MainMenu")) :: ScreenGui
	local CloseButton = MainMenu:WaitForChild("Close") :: ImageButton
	CloseButton.Modal = true
	Inventory = MainMenu:WaitForChild("Inventory") :: Frame
	Templates = Inventory:WaitForChild("Templates") :: Frame
	Tabs = MainMenu:WaitForChild("Tabs") :: GuiObject
	local Background = Inventory:WaitForChild("Background") :: Frame
	Content = Background:WaitForChild("Content") :: ScrollingFrame
	ContentLayout = Content:FindFirstChildWhichIsA("UIListLayout") :: UIListLayout
	ItemInfo = Inventory:WaitForChild("ItemInfo") :: Frame
	Description = Inventory:WaitForChild("Description") :: TextLabel
	ItemName = ItemInfo:WaitForChild("TextLabel") :: TextLabel
	BasicStats = ItemInfo:WaitForChild("BasicStats") :: Frame
	Display = ItemInfo:WaitForChild("Display") :: Frame
	local Viewport = Display:FindFirstChildWhichIsA("ViewportFrame")
	if Viewport then
		ViewportRotationController:BindViewport(Viewport)
	end

	local Buttons = ItemInfo:WaitForChild("Buttons") :: Frame
	EquipButton = Buttons:WaitForChild("Equip") :: ImageButton
	EquipLeftButton = Buttons:WaitForChild("EquipLeft") :: ImageButton

	Templates.Visible = false
	MainMenu.Enabled = false
	Inventory.Visible = true
	StatsController:SetVisible(false)
	Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	InventoryController:ClearContent()

	for _, Button in Tabs:GetChildren() do
		if Button:IsA("TextButton") then
			Button:SetAttribute("callback", nil)
			Button.Activated:Connect(function()
				InventoryController:ChangeTab(Button.Name)
			end)
		end
	end

	CloseButton:SetAttribute("callback", nil)
	CloseButton.Activated:Connect(function()
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
		if MainMenu.Enabled then
			HotbarController:CancelSlotSelection()
			MenuController:SetHudFocus(true)
			HotbarController:UpdateVisibility()
			InventoryController:UpdateContent()
		else
			InventoryController:ClearContent()

			if not HotbarController:IsSelectingSlot() then
				MenuController:SetHudFocus(false)
			end

			HotbarController:UpdateVisibility()
		end
	end)

	InventoryService.InventoryUpdated:Connect(function()
		if CurrentTab ~= "Stances" and CurrentTab ~= "Stats" then
			InventoryController:UpdateContent()
		end
	end)
	InventoryService.HotbarUpdated:Connect(function()
		InventoryController:UpdateContent()
	end)
	StanceService.UpdateUI:Connect(function()
		if CurrentTab == "Stances" then
			InventoryController:UpdateContent()
		end
	end)
end

return InventoryController
