local TweenService = game:GetService("TweenService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local InventoryController = Knit.CreateController({
	Name = "InventoryController",
})

local StanceService
local InventoryService
local HotbarController

local Player = game.Players.LocalPlayer
local PlayerGui
local Menu
local InventoryGUI
local Inventory

local background
local Content
local ItemInfo

local NotSelectedColor = Color3.fromRGB(140, 140, 140)
local SelectedColor = Color3.fromRGB(255, 255, 255)

local CurrentTab = "Items"

local Items = require(game.ReplicatedStorage.Shared.Index.Items)

local SelectedItem = nil
local SelectedItemData = nil

local EquippedVisuals = {}

function InventoryController:ClearContent()
	for _, Visual in EquippedVisuals do
		Visual:Destroy()
		Visual[_] = nil
	end

	for _, Button in Content:GetChildren() do
		if Button:IsA("ImageButton") then
			Button:Destroy()
		end
	end
end

local EasyVisuals = require(game.ReplicatedStorage.Assets.Libraries.EasyVisuals)

local SelectedVisuals = {}

local Rigs = game.ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Rigs")

function InventoryController:ConfigureViewport(Template)
	local Viewport: ViewportFrame = Template:FindFirstChildWhichIsA("ViewportFrame")
	if not Viewport then
		return
	end

	local Camera = Viewport:FindFirstChildWhichIsA("Camera")
	if not Camera then
		Camera = Instance.new("Camera")
		Camera.Parent = Viewport
		Viewport.CurrentCamera = Camera
	end

	Camera.CFrame = CFrame.new(0, 0, 0)
	Camera.CameraType = Enum.CameraType.Scriptable

	return Viewport
end

function InventoryController:LoadStanceViewport(Viewport, Stance)
	local Rig = Rigs[Stance.WeaponType .. "Visualizer"]:Clone()
	Rig:PivotTo(workspace.CurrentCamera.CFrame * CFrame.new(0, 0, 64))
	local Humanoid = Rig:WaitForChild("Humanoid")
	local Animator = Humanoid:WaitForChild("Animator")
	Rig.PrimaryPart.Anchored = true

	local WorldModel = Instance.new("WorldModel")
	WorldModel.Parent = Viewport

	Rig.Parent = workspace

	local Track: AnimationTrack =
		Animator:LoadAnimation(game.ReplicatedStorage.Assets.Animations.Stances[Stance.Name].Idle)
	Track:Play(0, 10)

	Rig.Parent = WorldModel
	Rig:PivotTo(CFrame.new(0, 0, -5) * CFrame.Angles(0, math.rad(205), 0))
end
function InventoryController:LoadStances()
	local Stances = StanceService:GetPlayerStances()
	self:ClearContent()

	for _, Stance in Stances do
		task.spawn(function()
			local Template = Inventory.StanceTemplate:Clone()
			Template.Name = Stance.Name
			Template.StanceName.Text = Stance.DisplayName or Stance.Name

			local Viewport = self:ConfigureViewport(Template)
			InventoryController:LoadStanceViewport(Viewport, Stance)
			if Stance.Equipped then
				local Rarity = Stance.Rarity or "Common"
				table.insert(EquippedVisuals, EasyVisuals.new(Template.StanceName, Rarity, 0.35, 1))
				table.insert(EquippedVisuals, EasyVisuals.new(Template, Rarity .. "Outline", 50, 1))
			end

			Template.Activated:Connect(function()
				SelectedItemData = Stance
				self:Select(Template)
				StanceService:EquipStance(Stance.Name)
			end)

			Template.Visible = true
			Template.Parent = Content
		end)
	end
end

function ClearSelectedVisuals()
	for _, Visual in SelectedVisuals do
		local found = false
		for _, EquippedVisual in EquippedVisuals do
			if Visual.UIInstance == EquippedVisual.UIInstance then
				found = true
				break
			end
		end

		if found then
			continue
		end
		Visual:Destroy()
		Visual[_] = nil
	end
end

function InventoryController:Unselect()
	ClearSelectedVisuals()

	for _, Attribute in ItemInfo.ItemStats:GetChildren() do
		if Attribute:IsA("TextLabel") then
			Attribute:Destroy()
		end
	end

	SelectedItem = nil
	SelectedItemData = nil
	ItemInfo.Visible = false
	HotbarController:LoadHotbar(true)
end

local ShowAttributes = {
	["MaxHealthIncrease"] = {
		DisplayName = "Health",
		Color = Color3.fromRGB(82, 255, 0),
	},
	["MaxStaminaIncrease"] = {
		DisplayName = "Stamina",
		Color = Color3.fromRGB(0, 148, 255),
	},
	["RunspeedIncrease"] = {
		DisplayName = "Run Speed",
		Color = Color3.fromRGB(255, 242, 0),
	},

	["BaseDamage"] = {
		DisplayName = "Damage",
		Color = Color3.fromRGB(237, 70, 70),
	},
	["BaseStaminaCost"] = {
		DisplayName = "Stamina Cost",
		Color = Color3.fromRGB(0, 148, 255),
	},

	["AdditionalDamage"] = {
		DisplayName = "Damage",
		Color = Color3.fromRGB(237, 70, 70),
	},
	["AdditionalStaminaCost"] = {
		DisplayName = "Stamina Cost",
		Color = Color3.fromRGB(0, 148, 255),
	},
}
function InventoryController:ShowSelectedItemInfo(SelectedItem)
	local ItemData = Items[SelectedItem.Name] or SelectedItem
	for _, Attribute in ItemInfo.ItemStats:GetChildren() do
		if Attribute:IsA("TextLabel") then
			Attribute:Destroy()
		end
	end

	local amountOfAttributes = 0

	for Attribute, DisplayData in ShowAttributes do
		local value = ItemData[Attribute]

		if value then
			local Template = ItemInfo.StatusTemplate:Clone()
			local Sign = if value > 0 then "+" else ""
			Template.Text = DisplayData.DisplayName .. ": " .. Sign .. tostring(value)

			if value > 0 then
				Template.TextColor3 = DisplayData.Color
			else
				Template.TextColor3 = Color3.fromRGB(237, 70, 70)
			end
			Template.Visible = true
			Template.Parent = ItemInfo.ItemStats
			amountOfAttributes += 1
		end
	end

	if amountOfAttributes == 0 then
		ItemInfo.ItemStats.Visible = false
		ItemInfo.ItemStatsTitle.Visible = false
	else
		ItemInfo.ItemStats.Visible = true
		ItemInfo.ItemStatsTitle.Visible = true

		ItemInfo.ItemStats.Size = UDim2.fromScale(0.864, amountOfAttributes * 0.1)
	end
end

local ItemTools = game.ReplicatedStorage.Assets.Tools
local Equipables = game.ReplicatedStorage.Assets.Equipables
local Weapons = game.ReplicatedStorage.Assets.Weapons
function InventoryController:Select(Item)
	SelectedItem = Item

	ClearSelectedVisuals()

	InventoryController:ShowSelectedItemInfo(SelectedItemData)

	ItemInfo.ItemName.Text = SelectedItemData.DisplayName or SelectedItemData.Name
	ItemInfo.ItemDescription.Text = SelectedItemData.Description or ""
	ItemInfo.ItemType.Text = SelectedItemData.Type or ""
	ItemInfo.ItemRarity.Text = SelectedItemData.Rarity or "Common"

	local Rarity = SelectedItemData.Rarity or "Common"
	table.insert(SelectedVisuals, EasyVisuals.new(SelectedItem, Rarity .. "Outline", 50, 1))
	table.insert(SelectedVisuals, EasyVisuals.new(ItemInfo, Rarity .. "Outline", 50, 2))
	table.insert(SelectedVisuals, EasyVisuals.new(ItemInfo.ItemRarity, Rarity, 0.35, 1))

	for _, Model in ItemInfo.ViewportFrame:GetChildren() do
		if not Model:IsA("Camera") then
			Model:Destroy()
		end
	end

	if SelectedItemData.Class == "Stance" then
		local Viewport = self:ConfigureViewport(ItemInfo)
		self:LoadStanceViewport(Viewport, SelectedItemData)

		for _, EquippedVisual in EquippedVisuals do
			EquippedVisual:Destroy()
		end
		table.clear(EquippedVisuals)
	else
		self:AddModelToViewport(ItemInfo.ViewportFrame, SelectedItemData)
	end

	if SelectedItemData.Equipped then
		ItemInfo.EquipButton.Text = "Unequip"
	else
		ItemInfo.EquipButton.Text = "Equip"
	end

	ItemInfo.EquipButton.Visible = SelectedItemData.Class == "Equipable" or SelectedItemData.Class == "Weapon"
	ItemInfo.Vanity.Visible = SelectedItemData.Class == "Equipable"

	ItemInfo.Visible = true

	if
		SelectedItemData.Class ~= "Stance"
		and SelectedItemData.Class ~= "Equipable"
		and SelectedItemData.Class ~= "Weapon"
	then
		HotbarController:LoadHotbar(HotbarController:HotbarEnabledBooleans())
	end
end

function InventoryController:GetSelected()
	return SelectedItem
end

function InventoryController:EquipItem()
	ItemInfo.Visible = false
	InventoryService:EquipUnequipItem(SelectedItem:GetAttribute("Name"))
end

function InventoryController:AddModelToViewport(Viewport: ViewportFrame, Item: { any })
	local Model = ItemTools:FindFirstChild(Item.Name) or Equipables:FindFirstChild(Item.Name, true)
	if not Model then
		Model = Weapons:FindFirstChild(Item.Name)
		if Model then
			Model = Model.Weapon
		end
	end

	if not Model then
		return
	end
	Model = Model:Clone()

	for _, Part in Model:GetDescendants() do
		Part:RemoveTag("SmartBone")
	end

	local InventoryOffset = Model:GetAttribute("InventoryOffset") or CFrame.new()
	local _, BoundingSize = Model:GetBoundingBox()
	local LargestDimension = math.max(BoundingSize.X, BoundingSize.Y, BoundingSize.Z)
	if Item.Class == "Equipable" then
		Model:PivotTo(CFrame.new(0, 0, -5) * InventoryOffset)
	else
		local InventoryDistance = Model:GetAttribute("InventoryDistance")
			or math.clamp(LargestDimension * 1.8, 1.1, 2.5)
		Model:PivotTo(
			CFrame.new(0, 0, -InventoryDistance) * CFrame.Angles(0, 0, math.rad(45)) * InventoryOffset
		)
	end

	for _, Part in Model:GetDescendants() do
		if Part:IsA("BasePart") then
			Part.Anchored = true
		end
	end
	Model.Parent = Viewport
end
function InventoryController:LoadItems()
	local Items = InventoryService:GetInventory(Player)
	self:ClearContent()

	for _, Item in Items do
		if Item.Class == "Skill" then
			continue
		end
		if Item.Hidden then
			continue
		end

		local Template = Inventory.ItemTemplate:Clone()
		Template.Name = Item.Name
		Template:SetAttribute("Name", Item.Name)
		Template:SetAttribute("ItemClass", Item.Class)
		Template:SetAttribute("ItemType", Item.Type)
		Template:SetAttribute("Rarity", Item.Rarity)
		Template.ItemName.Text = Item.DisplayName

		Template.Amount.Visible = Item.Stack > 1
		Template.Amount.Text = tostring(Item.Stack) .. "x"

		local _Tool = HotbarController:GetToolByNameFromPlayer(Template:GetAttribute("Name"))
		if _Tool then
			if _Tool:GetAttribute("HotbarIndex") and _Tool:GetAttribute("Class") ~= "Artifact" then
				Template.EquipIndex.Text = "[" .. tostring(_Tool:GetAttribute("HotbarIndex")) .. "]"
				Template.Name = tostring(_Tool:GetAttribute("HotbarIndex")) .. _Tool.Name
			end
		end

		if Item.Class == "Equipable" or Item.Class == "Weapon" then
			if Item.Equipped then
				Template.EquipIndex.Text = "[E]"
				Template.Name = "1" .. Item.Name

				local Rarity = Item.Rarity or "Common"
				if Rarity ~= "Common" then
					table.insert(EquippedVisuals, EasyVisuals.new(Template.ItemName, Rarity, 0.35, 1))
					table.insert(EquippedVisuals, EasyVisuals.new(Template, Rarity .. "Outline", 50, 1))
				end
			end
		end

		local Viewport = self:ConfigureViewport(Template)
		if Viewport then
			self:AddModelToViewport(Viewport, Item)
		end

		Template.Activated:Connect(function()
			if SelectedItem ~= Template then
				self:Unselect()
				SelectedItemData = Item
				self:Select(Template)
			else
				self:Unselect()
			end
		end)

		Template.Visible = true
		Template.Parent = Content
	end
end

function InventoryController:LoadSkills()
	local Skills = InventoryService:GetInventory(Player)
	self:ClearContent()

	for _, Skill in Skills do
		if Skill.Class ~= "Skill" then
			continue
		end

		local Template = Inventory.SkillTemplate:Clone()
		Template.Name = Skill.Name
		Template.ItemName.Text = Skill.DisplayName

		local _Tool = HotbarController:GetToolByNameFromPlayer(Skill.Name)
		if _Tool then
			if _Tool:GetAttribute("HotbarIndex") then
				Template.EquipIndex.Text = "[" .. tostring(_Tool:GetAttribute("HotbarIndex")) .. "]"

				local Rarity = Skill.Rarity or "Common"
				table.insert(EquippedVisuals, EasyVisuals.new(Template.ItemName, Rarity, 0.35, 1))
				table.insert(EquippedVisuals, EasyVisuals.new(Template, Rarity .. "Outline", 50, 1))
			end
		end

		Template.Activated:Connect(function()
			if SelectedItem ~= Template then
				self:Unselect()
				SelectedItemData = Skill
				self:Select(Template)
			else
				self:Unselect()
			end
		end)

		Template.Visible = true
		Template.Parent = Content
	end
end

function InventoryController:UpdateContent()
	local UnSelectedTabColor = Color3.new(1, 1, 1)
	local SelectedTabColor = Color3.new(1, 0.933333, 0)
	local Ti = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	if CurrentTab == "Stances" then
		self:LoadStances()
	elseif CurrentTab == "Items" then
		self:LoadItems()
	elseif CurrentTab == "Skills" then
		self:LoadSkills()
	end

	for i, v in pairs(Inventory.Tabs:GetChildren()) do
		if v:IsA("TextButton") then
			if v.Name == CurrentTab or v.Text == CurrentTab then
				local Tween = TweenService:Create(v, Ti, { TextColor3 = SelectedTabColor })
				Tween:Play()
			else
				local Tween = TweenService:Create(v, Ti, { TextColor3 = UnSelectedTabColor })
				Tween:Play()
			end
		end
	end
end

function InventoryController:ChangeTab(TabName: string)
	if CurrentTab == TabName then
		return
	end
	self:Unselect()
	CurrentTab = TabName

	self:UpdateContent()
end

local AttributesToColor = {
	["Health"] = Color3.fromRGB(82, 255, 0),
	["Stamina"] = Color3.fromRGB(47, 99, 211),
	["Posture"] = Color3.fromRGB(255, 170, 0),
	["Run Speed"] = Color3.fromRGB(255, 242, 0),
	["Damage"] = Color3.fromRGB(211, 0, 0),
}

local AttributesToShow = {
	["Run Speed"] = "",
	["Health"] = "MaxHealth",
	["Stamina"] = "MaxStamina",
	["Posture"] = "MaxPosture",
	["Damage"] = "SwordDamage",
}
local bottom
function InventoryController:UpdateStatus()
	local Character = Player.Character

	for _, Template in bottom:GetChildren() do
		if Template:IsA("TextLabel") then
			Template:Destroy()
		end
	end

	if Character then
		for Display, Attribute in AttributesToShow do
			local Value = Character:GetAttribute(Attribute)

			if Display == "Run Speed" then
				Value = (Character:GetAttribute("RunningWalkSpeed") or 24)
						* (Character:GetAttribute("RunSpeedMultiplier") or 1)
					+ (Character:GetAttribute("RunSpeedIncrease") or 0)
			end

			if Value then
				local Template = Inventory.StatusTemplate:Clone()
				Template.TextColor3 = AttributesToColor[Display] or Color3.fromRGB(255, 255, 255)

				local formatted = string.format("%.1f", Value)
				local splitted = formatted:split(".")

				if splitted[2] == "0" then
					Template.Text = Display .. ": " .. splitted[1]
				else
					Template.Text = Display .. ": " .. formatted
				end

				Template.Parent = bottom
				Template.Visible = true
			end
		end
	end
end

function InventoryController:KnitInit()
	StanceService = Knit.GetService("StanceService")
	InventoryService = Knit.GetService("InventoryService")
	HotbarController = Knit.GetController("HotbarController")
end

function InventoryController.KnitStart()
	PlayerGui = Player:WaitForChild("PlayerGui")
	Menu = PlayerGui:WaitForChild("Menu")
	InventoryGUI = Menu:WaitForChild("Inventory")
	Inventory = InventoryGUI:WaitForChild("Inventory")

	background = Inventory:WaitForChild("background")
	Content = background:WaitForChild("content")
	ItemInfo = Inventory:WaitForChild("ItemInfo")
	bottom = Inventory:WaitForChild("bottom")

	InventoryGUI:GetPropertyChangedSignal("Enabled"):Connect(function()
		InventoryController:Unselect()
		if not InventoryGUI.Enabled then
			InventoryController:ClearContent()
		else
			InventoryController:UpdateContent()
		end
		HotbarController:LoadHotbar(InventoryGUI.Enabled)
	end)

	InventoryService.InventoryUpdated:Connect(function(Inventory)
		if not InventoryGUI.Enabled then
			return
		end

		InventoryController:UpdateContent()
	end)

	StanceService.UpdateUI:Connect(function(Data)
		if not InventoryGUI.Enabled then
			return
		end

		if CurrentTab == "Stances" then
			InventoryController:UpdateContent()
		end
	end)

	InventoryController:UpdateStatus()
end

return InventoryController
