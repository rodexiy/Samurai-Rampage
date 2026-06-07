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

local Stations = {
	Crafting = {
		MenuName = "Crafting",
		RecipeType = "Crafting",
		EmptyText = "Choose a recipe from the list to inspect its materials.",
	},
	Forge = {
		MenuName = "Forge",
		RecipeType = "Forge",
		EmptyText = "Choose a forge recipe from the list to inspect its materials.",
	},
}

local QuantityOptions = {
	["x1"] = 1,
	["x5"] = 5,
	["x25"] = 25,
	All = "All",
}

local function ClearGenerated(Container: Instance, Template: Instance?)
	for _, Child in Container:GetChildren() do
		if Child ~= Template and not Child:IsA("UIListLayout") and not Child:IsA("UIPadding") then
			Child:Destroy()
		end
	end
end

local function GetOwnedAmount(ItemName: string): number
	return InventoryAmounts[ItemName] or 0
end

local function GetMaxCraftable(Recipe): number
	local MaxCraftable = math.huge
	for Requirement, Amount in Recipe.CraftingRequirements do
		MaxCraftable = math.min(MaxCraftable, math.floor(GetOwnedAmount(Requirement) / Amount))
	end

	local CurrentStack = GetOwnedAmount(Recipe.Name)
	local RemainingCapacity = (Recipe.MaxStack or 1) - CurrentStack
	MaxCraftable = math.min(MaxCraftable, math.floor(RemainingCapacity / (Recipe.AmountPerCraft or 1)))

	return math.max(0, MaxCraftable)
end

local function GetSelectedCraftAmount(Station): number
	if not Station.SelectedRecipe then
		return 0
	end

	local MaxCraftable = GetMaxCraftable(Station.SelectedRecipe)
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
		Station.CraftButton.BackgroundColor3 = Color3.fromRGB(62, 62, 62)
		ClearGenerated(Station.Requirements, Station.IngredientTemplate)
		Station.ResultSlot.Visible = false
		return
	end

	local MaxCraftable = GetMaxCraftable(Station.SelectedRecipe)
	local CraftAmount = if Station.SelectedAmount == "All" then MaxCraftable else Station.SelectedAmount :: number
	Station.RecipeName.Text = Station.SelectedRecipe.DisplayName
	Station.RecipeDescription.Text = Station.SelectedRecipe.Description or ""

	ClearGenerated(Station.Requirements, Station.IngredientTemplate)
	for Requirement, Amount in Station.SelectedRecipe.CraftingRequirements do
		local Needed = Amount * CraftAmount
		local Owned = GetOwnedAmount(Requirement)
		local Slot = Station.IngredientTemplate:Clone()
		PopulateSlot(Slot, Requirement, tostring(Owned) .. "/" .. tostring(Needed), Owned >= Needed)
		Slot.Parent = Station.Requirements
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
				then Color3.fromRGB(151, 99, 45)
				else Color3.fromRGB(28, 28, 28)
		end
	end

	local CanCraft = MaxCraftable >= CraftAmount and CraftAmount > 0
	Station.CraftButton.Interactable = CanCraft
	Station.CraftButton.BackgroundColor3 = if CanCraft then Color3.fromRGB(151, 99, 45) else Color3.fromRGB(62, 62, 62)
	Station.Status.Text = if MaxCraftable > 0
		then "You can craft " .. tostring(MaxCraftable) .. " batch(es)."
		else "Missing materials or no inventory space."
end

function CraftingController:SelectRecipe(Station, Recipe)
	Station.SelectedRecipe = Recipe
	Station.SelectedAmount = 1
	self:RefreshRecipeDetails(Station)
end

function CraftingController:RefreshRecipes(Station)
	Station.Recipes = CraftingService:GetAvailableRecipes(Station.RecipeType)
	ClearGenerated(Station.RecipeList, Station.RecipeTemplate)

	for _, Recipe in Station.Recipes do
		local Button = Station.RecipeTemplate:Clone()
		Button.Name = Recipe.Name
		Button.RecipeName.Text = Recipe.DisplayName
		Button.RecipeType.Text = string.upper(Recipe.Type or Recipe.Class or "ITEM")
		Button.Visible = true
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

		CraftingService:Craft(Station.SelectedRecipe.Name, Station.SelectedAmount, Station.RecipeType)
	end)

	Station.Gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if Station.Gui.Enabled then
			Station.HotbarWasEnabled = HotbarGui.Enabled
			HotbarGui.Enabled = false
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
