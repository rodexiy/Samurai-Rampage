local Knit = require(game.ReplicatedStorage.Packages.Knit)

local CraftingController = Knit.CreateController({
	Name = "CraftingController",
})

local Player = game.Players.LocalPlayer
local Items = require(game.ReplicatedStorage.Shared.Index.Items)

local CraftingService
local InventoryService
local InventoryController
local MenuController

local HotbarGui
local InventoryAmounts = {}

local NotoSerifJPFont = nil

local Stations = {
	Crafting = {
		MenuName = "Crafting",
		RecipeType = "Crafting",
		EmptyText = "Choose a recipe from the list to inspect its materials.",
		SelectedColor = Color3.fromRGB(130, 82, 46),
		UnselectedColor = Color3.fromRGB(48, 38, 32),
		DisabledColor = Color3.fromRGB(61, 55, 51),
	},
	Forge = {
		MenuName = "Forge",
		RecipeType = "Forge",
		EmptyText = "Choose a forge recipe from the list to inspect its materials.",
		SelectedColor = Color3.fromRGB(151, 99, 45),
		UnselectedColor = Color3.fromRGB(28, 28, 28),
		DisabledColor = Color3.fromRGB(62, 62, 62),
	},
}

local QuantityOptions = {
	["x1"] = 1,
	["x5"] = 5,
	["x25"] = 25,
	All = "All",
}

local RecipeCategories = {
	Resource = {
		Name = "CRAFTING MATERIALS",
		Order = 1,
	},
	Usable = {
		Name = "USABLES",
		Order = 2,
	},
	Weapon = {
		Name = "WEAPONS",
		Order = 3,
	},
	Equipable = {
		Name = "EQUIPMENT",
		Order = 4,
	},
}

local function ClearGenerated(Container: Instance, Template: Instance?)
	for _, Child in Container:GetChildren() do
		if Child ~= Template and not Child:IsA("UIListLayout") and not Child:IsA("UIPadding") then
			Child:Destroy()
		end
	end
end

local function GetRecipeCategory(Recipe)
	return RecipeCategories[Recipe.Class] or {
		Name = "OTHER",
		Order = 5,
	}
end

local function CreateCategoryHeader(Container: Instance, Template: GuiObject, CategoryName: string, LayoutOrder: number)
	local Header = Instance.new("TextLabel")
	Header.Name = "Category_" .. CategoryName
	Header.LayoutOrder = LayoutOrder
	Header.Size = UDim2.new(Template.Size.X.Scale, Template.Size.X.Offset, 0, 28)
	Header.BackgroundTransparency = 1
	Header.Text = CategoryName
	Header.TextColor3 = Color3.fromRGB(184, 184, 184)
	Header.TextSize = 13
	Header.TextXAlignment = Enum.TextXAlignment.Left
	Header.Visible = true
	Header.Parent = Container
end

local function ConfigureScrollingList(Container: Instance)
	if not Container:IsA("ScrollingFrame") then
		return
	end

	for _, Child in Container:GetChildren() do
		if Child:IsA("UIPadding") then
			Child:Destroy()
		end
	end

	local OriginalParent = Container.Parent
	local ClippingFrame = Instance.new("Frame")
	ClippingFrame.Name = Container.Name .. "Clip"
	ClippingFrame.AnchorPoint = Container.AnchorPoint
	ClippingFrame.Position = Container.Position
	ClippingFrame.Size = Container.Size
	ClippingFrame.LayoutOrder = Container.LayoutOrder
	ClippingFrame.Rotation = Container.Rotation
	ClippingFrame.Visible = Container.Visible
	ClippingFrame.ZIndex = Container.ZIndex
	ClippingFrame.BackgroundTransparency = 1
	ClippingFrame.BorderSizePixel = 0
	ClippingFrame.ClipsDescendants = true
	ClippingFrame.Parent = OriginalParent

	Container.AnchorPoint = Vector2.zero
	Container.Position = UDim2.fromScale(0, 0)
	Container.Size = UDim2.new(1, 0, 1, 0)
	Container.LayoutOrder = 0
	Container.Rotation = 0
	Container.ClipsDescendants = false
	Container.Parent = ClippingFrame
end

local function GetOwnedAmount(ItemName: string): number
	return InventoryAmounts[ItemName] or 0
end

local function GetRequirementGroups(Recipe)
	local Requirements = Recipe.CraftingRequirements
	if not Requirements then
		return {}
	end

	local FirstKey, FirstValue = next(Requirements)
	if typeof(FirstKey) == "string" then
		local Groups = {}
		for Requirement, Amount in Requirements do
			table.insert(Groups, { { [Requirement] = Amount } })
		end
		return Groups
	end

	if typeof(FirstKey) == "number" and typeof(next(FirstValue)) == "string" then
		return { Requirements }
	end

	return Requirements
end

local function GetMaxCraftableForRequirements(Requirements): number
	local MaxCraftable = math.huge
	for Requirement, Amount in Requirements do
		MaxCraftable = math.min(MaxCraftable, math.floor(GetOwnedAmount(Requirement) / Amount))
	end

	return MaxCraftable
end

local function GetCombinedSelectedRequirements(Station)
	local CombinedRequirements = {}

	for GroupIndex, Options in GetRequirementGroups(Station.SelectedRecipe) do
		local OptionIndex = if #Options == 1 then 1 else Station.SelectedRequirementOptions[GroupIndex]
		local Requirements = Options[OptionIndex]
		if not Requirements then
			return nil
		end

		for Requirement, Amount in Requirements do
			CombinedRequirements[Requirement] = (CombinedRequirements[Requirement] or 0) + Amount
		end
	end

	return CombinedRequirements
end

local function GetMaxCraftable(Station): number
	local Requirements = GetCombinedSelectedRequirements(Station)
	if not Requirements then
		return 0
	end

	local MaxCraftable = GetMaxCraftableForRequirements(Requirements)

	local CurrentStack = GetOwnedAmount(Station.SelectedRecipe.Name)
	local RemainingCapacity = (Station.SelectedRecipe.MaxStack or 1) - CurrentStack
	MaxCraftable = math.min(MaxCraftable, math.floor(RemainingCapacity / (Station.SelectedRecipe.AmountPerCraft or 1)))

	return math.max(0, MaxCraftable)
end

local function GetSelectedCraftAmount(Station): number
	if not Station.SelectedRecipe then
		return 0
	end

	local MaxCraftable = GetMaxCraftable(Station)
	if Station.SelectedAmount == "All" then
		return MaxCraftable
	end

	return math.min(Station.SelectedAmount :: number, MaxCraftable)
end

local function ClearViewport(Viewport: ViewportFrame)
	for _, Child in Viewport:GetChildren() do
		if not Child:IsA("Camera") then
			Child:Destroy()
		end
	end
end

local function PopulateSlot(Slot: ImageButton, ItemName: string, AmountText: string, Enough: boolean?)
	local ItemData = Items[ItemName]
	Slot.ItemName.Text = if ItemData then ItemData.DisplayName or ItemName else ItemName
	Slot.Amount.Text = AmountText
	Slot.Amount.Visible = true
	Slot.EquipIndex.Visible = false
	Slot.Visible = true
	Slot.BackgroundColor3 = if Enough == false then Color3.fromRGB(73, 24, 24) else Color3.fromRGB(0, 0, 0)

	local Viewport = InventoryController:ConfigureViewport(Slot)
	if Viewport then
		ClearViewport(Viewport)
		InventoryController:AddModelToViewport(Viewport, ItemData or { Name = ItemName })
	end
end

function CraftingController:RefreshInventory()
	table.clear(InventoryAmounts)
	for _, Item in InventoryService:GetInventory(Player) do
		InventoryAmounts[Item.Name] = Item.Stack
	end
end

function CraftingController:RefreshRecipeDetails(Station)
	if not Station.SelectedRecipe then
		Station.RecipeName.Text = "SELECT A RECIPE"
		Station.RecipeDescription.Text = Station.EmptyText
		Station.Status.Text = ""
		Station.CraftButton.Interactable = false
		Station.CraftButton.BackgroundColor3 = Station.DisabledColor
		ClearGenerated(Station.Requirements, Station.IngredientTemplate)
		Station.ResultSlot.Visible = false
		return
	end

	local MaxCraftable = GetMaxCraftable(Station)
	local CraftAmount = if Station.SelectedAmount == "All" then MaxCraftable else Station.SelectedAmount :: number
	Station.RecipeName.Text = Station.SelectedRecipe.DisplayName

	ClearGenerated(Station.Requirements, Station.IngredientTemplate)
	local RequirementGroups = GetRequirementGroups(Station.SelectedRecipe)
	local HasAlternativeRequirements = false
	for _, Options in RequirementGroups do
		if #Options > 1 then
			HasAlternativeRequirements = true
			break
		end
	end
	Station.RecipeDescription.Text = Station.SelectedRecipe.Description or ""

	for GroupIndex, Options in RequirementGroups do
		local SelectedOptionIndex = if #Options == 1 then 1 else Station.SelectedRequirementOptions[GroupIndex]
		local IsExpanded = Station.ExpandedRequirementGroup == GroupIndex

		if #Options > 1 and not IsExpanded and not SelectedOptionIndex then
			local SelectButton = Station.IngredientTemplate:Clone()
			local PreviewRequirement = next(Options[1])
			PopulateSlot(SelectButton, PreviewRequirement, "", true)
			SelectButton.ItemName.Text = "SELECT"
			SelectButton.Amount.Visible = false
			SelectButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			local Viewport = SelectButton:FindFirstChildWhichIsA("ViewportFrame", true)
			if Viewport then
				ClearViewport(Viewport)
			end
			SelectButton.Activated:Connect(function()
				Station.ExpandedRequirementGroup = GroupIndex
				self:RefreshRecipeDetails(Station)
			end)
			SelectButton.Parent = Station.Requirements
		elseif #Options > 1 and not IsExpanded then
			for Requirement, Amount in Options[SelectedOptionIndex] do
				local Needed = Amount * CraftAmount
				local Owned = GetOwnedAmount(Requirement)
				local SelectedSlot = Station.IngredientTemplate:Clone()
				PopulateSlot(SelectedSlot, Requirement, tostring(Owned) .. "/" .. tostring(Needed), Owned >= Needed)
				SelectedSlot.BackgroundColor3 = if Owned >= Needed
					then Color3.fromRGB(31, 112, 55)
					else Color3.fromRGB(73, 24, 24)
				SelectedSlot.Activated:Connect(function()
					Station.ExpandedRequirementGroup = GroupIndex
					self:RefreshRecipeDetails(Station)
				end)
				SelectedSlot.Parent = Station.Requirements
			end
		else
			for OptionIndex, Requirements in Options do
				if #Options == 1 or IsExpanded then
					for Requirement, Amount in Requirements do
						local Needed = Amount * CraftAmount
						local Owned = GetOwnedAmount(Requirement)
						local Slot = Station.IngredientTemplate:Clone()
						PopulateSlot(Slot, Requirement, tostring(Owned) .. "/" .. tostring(Needed), Owned >= Needed)
						if #Options > 1 then
							Slot.BackgroundColor3 = if Owned >= Needed
								then Color3.fromRGB(31, 112, 55)
								else Color3.fromRGB(73, 24, 24)
							Slot.Activated:Connect(function()
								Station.SelectedRequirementOptions[GroupIndex] = OptionIndex
								Station.ExpandedRequirementGroup = nil
								self:RefreshRecipeDetails(Station)
							end)
						end
						Slot.Parent = Station.Requirements
					end
				end
			end
		end
	end

	local OutputAmount = (Station.SelectedRecipe.AmountPerCraft or 1) * CraftAmount
	PopulateSlot(
		Station.ResultSlot,
		Station.SelectedRecipe.Name,
		"x" .. tostring(OutputAmount),
		MaxCraftable >= CraftAmount and CraftAmount > 0
	)

	for ButtonName, Amount in QuantityOptions do
		local Button = Station.QuantityButtons:FindFirstChild(ButtonName)
		if Button then
			Button.BackgroundColor3 = if Station.SelectedAmount == Amount
				then Station.SelectedColor
				else Station.UnselectedColor
		end
	end

	local CanCraft = MaxCraftable >= CraftAmount and CraftAmount > 0
	Station.CraftButton.Interactable = CanCraft
	Station.CraftButton.BackgroundColor3 = if CanCraft then Station.SelectedColor else Station.DisabledColor
	Station.Status.Text = if MaxCraftable > 0
		then "You can craft " .. tostring(MaxCraftable) .. " batch(es)."
		else "Missing materials or no inventory space."
end

function CraftingController:SelectRecipe(Station, Recipe)
	Station.SelectedRecipe = Recipe
	Station.SelectedAmount = 1
	Station.SelectedRequirementOptions = {}
	Station.ExpandedRequirementGroup = nil
	self:RefreshRecipeDetails(Station)
end

function CraftingController:RefreshRecipes(Station)
	Station.Recipes = CraftingService:GetAvailableRecipes(Station.RecipeType)
	ClearGenerated(Station.RecipeList, Station.RecipeTemplate)

	table.sort(Station.Recipes, function(A, B)
		local CategoryA = GetRecipeCategory(A)
		local CategoryB = GetRecipeCategory(B)
		if CategoryA.Order ~= CategoryB.Order then
			return CategoryA.Order < CategoryB.Order
		end

		return A.DisplayName < B.DisplayName
	end)

	local CurrentCategory
	for RecipeIndex, Recipe in Station.Recipes do
		local Category = GetRecipeCategory(Recipe)
		if CurrentCategory ~= Category.Name then
			CurrentCategory = Category.Name
			CreateCategoryHeader(Station.RecipeList, Station.RecipeTemplate, Category.Name, Category.Order * 1000)
		end

		local Button = Station.RecipeTemplate:Clone()
		Button.Name = Recipe.Name
		Button.LayoutOrder = Category.Order * 1000 + RecipeIndex
		Button.RecipeName.Text = Recipe.DisplayName
		Button.RecipeType.Text = string.upper(Recipe.Type or Recipe.Class or "ITEM")
		Button.Visible = true
		Button.Size = UDim2.fromScale(0.95, 0.14)
		Button.Parent = Station.RecipeList
		Button.Activated:Connect(function()
			self:SelectRecipe(Station, Recipe)
		end)
	end

	if #Station.Recipes > 0 then
		self:SelectRecipe(Station, Station.Recipes[1])
	else
		Station.SelectedRecipe = nil
		self:RefreshRecipeDetails(Station)
	end
end

function CraftingController:BindStation(Menus: Instance, Station)
	Station.Gui = Menus:WaitForChild(Station.MenuName)
	local Shade = Station.Gui:WaitForChild("Shade")
	Station.Window = Shade:WaitForChild("Window")

	local Header = Station.Window:WaitForChild("Header")
	local Body = Station.Window:WaitForChild("Body")
	local Details = Body:WaitForChild("Details")
	local Flow = Details:WaitForChild("Flow")
	local Bottom = Details:WaitForChild("Bottom")

	Station.RecipeList = Body.Recipes.Content
	Station.RecipeTemplate = Station.RecipeList:WaitForChild("Template")
	ConfigureScrollingList(Station.RecipeList)
	Station.IngredientTemplate = Flow.Requirements:WaitForChild("Template")
	Station.Requirements = Flow.Requirements
	Station.ResultSlot = Flow:WaitForChild("Result")
	Station.RecipeName = Details:WaitForChild("RecipeName")
	Station.RecipeDescription = Details:WaitForChild("Description")
	Station.QuantityButtons = Bottom:WaitForChild("Quantities")
	Station.CraftButton = Bottom:WaitForChild("Craft")
	Station.Status = Bottom:WaitForChild("Status")
	Station.Recipes = {}
	Station.SelectedAmount = 1

	Header.Close.Activated:Connect(function()
		MenuController:CloseAllMenus()
	end)

	for ButtonName, Amount in QuantityOptions do
		Station.QuantityButtons[ButtonName].Activated:Connect(function()
			Station.SelectedAmount = Amount
			self:RefreshRecipeDetails(Station)
		end)
	end

	Station.CraftButton.Activated:Connect(function()
		if not Station.SelectedRecipe or GetSelectedCraftAmount(Station) <= 0 then
			return
		end

		CraftingService:Craft(
			Station.SelectedRecipe.Name,
			Station.SelectedAmount,
			Station.RecipeType,
			Station.SelectedRequirementOptions
		)
	end)

	Station.Gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if Station.Gui.Enabled then
			Station.HotbarWasEnabled = HotbarGui.Enabled
			HotbarGui.Enabled = false
			NotoSerifJPFont = Header.Title.Font
			self:RefreshInventory()
			self:RefreshRecipes(Station)
		elseif Station.HotbarWasEnabled ~= nil then
			HotbarGui.Enabled = Station.HotbarWasEnabled
			Station.HotbarWasEnabled = nil
		end
	end)
end

function CraftingController:BindUI()
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local Menus = PlayerGui:WaitForChild("Menu")
	HotbarGui = PlayerGui:WaitForChild("Hud"):WaitForChild("NewHotbar")

	for _, Station in Stations do
		self:BindStation(Menus, Station)
	end
end

function CraftingController.KnitInit()
	CraftingService = Knit.GetService("CraftingService")
	InventoryService = Knit.GetService("InventoryService")
	InventoryController = Knit.GetController("InventoryController")
	MenuController = Knit.GetController("MenuController")
end

function CraftingController.KnitStart()
	CraftingController:BindUI()

	InventoryService.InventoryUpdated:Connect(function()
		CraftingController:RefreshInventory()
		for _, Station in Stations do
			if Station.Gui.Enabled then
				CraftingController:RefreshRecipeDetails(Station)
			end
		end
	end)
end

return CraftingController
