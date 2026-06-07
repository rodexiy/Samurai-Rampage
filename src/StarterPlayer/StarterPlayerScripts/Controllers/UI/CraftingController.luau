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

local CraftingGui
local HotbarGui
local HotbarWasEnabled
local Window
local RecipeList
local RecipeTemplate
local IngredientTemplate
local Requirements
local ResultSlot
local RecipeName
local RecipeDescription
local QuantityButtons
local CraftButton
local Status

local Recipes = {}
local InventoryAmounts = {}
local SelectedRecipe
local SelectedAmount: number | string = 1

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

local function GetSelectedCraftAmount(): number
	if not SelectedRecipe then
		return 0
	end

	local MaxCraftable = GetMaxCraftable(SelectedRecipe)
	if SelectedAmount == "All" then
		return MaxCraftable
	end

	return math.min(SelectedAmount :: number, MaxCraftable)
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

function CraftingController:RefreshRecipeDetails()
	if not SelectedRecipe then
		RecipeName.Text = "SELECT A RECIPE"
		RecipeDescription.Text = "Choose a recipe from the list to inspect its materials."
		Status.Text = ""
		CraftButton.Interactable = false
		CraftButton.BackgroundColor3 = Color3.fromRGB(62, 62, 62)
		ClearGenerated(Requirements, IngredientTemplate)
		ResultSlot.Visible = false
		return
	end

	local MaxCraftable = GetMaxCraftable(SelectedRecipe)
	local CraftAmount = if SelectedAmount == "All" then MaxCraftable else SelectedAmount :: number
	RecipeName.Text = SelectedRecipe.DisplayName
	RecipeDescription.Text = SelectedRecipe.Description or ""

	ClearGenerated(Requirements, IngredientTemplate)
	for Requirement, Amount in SelectedRecipe.CraftingRequirements do
		local Needed = Amount * CraftAmount
		local Owned = GetOwnedAmount(Requirement)
		local Slot = IngredientTemplate:Clone()
		PopulateSlot(Slot, Requirement, tostring(Owned) .. "/" .. tostring(Needed), Owned >= Needed)
		Slot.Parent = Requirements
	end

	local OutputAmount = (SelectedRecipe.AmountPerCraft or 1) * CraftAmount
	PopulateSlot(ResultSlot, SelectedRecipe.Name, "x" .. tostring(OutputAmount), MaxCraftable >= CraftAmount and CraftAmount > 0)

	for ButtonName, Amount in QuantityOptions do
		local Button = QuantityButtons:FindFirstChild(ButtonName)
		if Button then
			Button.BackgroundColor3 = if SelectedAmount == Amount
				then Color3.fromRGB(151, 99, 45)
				else Color3.fromRGB(28, 28, 28)
		end
	end

	local CanCraft = MaxCraftable >= CraftAmount and CraftAmount > 0
	CraftButton.Interactable = CanCraft
	CraftButton.BackgroundColor3 = if CanCraft then Color3.fromRGB(151, 99, 45) else Color3.fromRGB(62, 62, 62)
	Status.Text = if MaxCraftable > 0
		then "You can craft " .. tostring(MaxCraftable) .. " batch(es)."
		else "Missing materials or no inventory space."
end

function CraftingController:SelectRecipe(Recipe)
	SelectedRecipe = Recipe
	SelectedAmount = 1
	self:RefreshRecipeDetails()
end

function CraftingController:RefreshRecipes()
	Recipes = CraftingService:GetAvailableRecipes()
	ClearGenerated(RecipeList, RecipeTemplate)

	for _, Recipe in Recipes do
		local Button = RecipeTemplate:Clone()
		Button.Name = Recipe.Name
		Button.RecipeName.Text = Recipe.DisplayName
		Button.RecipeType.Text = string.upper(Recipe.Type or Recipe.Class or "ITEM")
		Button.Visible = true
		Button.Parent = RecipeList
		Button.Activated:Connect(function()
			self:SelectRecipe(Recipe)
		end)
	end

	if #Recipes > 0 then
		self:SelectRecipe(Recipes[1])
	else
		SelectedRecipe = nil
		self:RefreshRecipeDetails()
	end
end

function CraftingController:BindUI()
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local Menus = PlayerGui:WaitForChild("Menu")
	HotbarGui = PlayerGui:WaitForChild("Hud"):WaitForChild("NewHotbar")
	CraftingGui = Menus:WaitForChild("Crafting")
	local Shade = CraftingGui:WaitForChild("Shade")
	Window = Shade:WaitForChild("Window")

	local Header = Window:WaitForChild("Header")
	local Body = Window:WaitForChild("Body")
	local Details = Body:WaitForChild("Details")
	local Flow = Details:WaitForChild("Flow")
	local Bottom = Details:WaitForChild("Bottom")

	RecipeList = Body.Recipes.Content
	RecipeTemplate = RecipeList:WaitForChild("Template")
	IngredientTemplate = Flow.Requirements:WaitForChild("Template")
	Requirements = Flow.Requirements
	ResultSlot = Flow:WaitForChild("Result")
	RecipeName = Details:WaitForChild("RecipeName")
	RecipeDescription = Details:WaitForChild("Description")
	QuantityButtons = Bottom:WaitForChild("Quantities")
	CraftButton = Bottom:WaitForChild("Craft")
	Status = Bottom:WaitForChild("Status")

	Header.Close.Activated:Connect(function()
		MenuController:CloseAllMenus()
	end)

	for ButtonName, Amount in QuantityOptions do
		QuantityButtons[ButtonName].Activated:Connect(function()
			SelectedAmount = Amount
			self:RefreshRecipeDetails()
		end)
	end

	CraftButton.Activated:Connect(function()
		if not SelectedRecipe or GetSelectedCraftAmount() <= 0 then
			return
		end

		CraftingService:Craft(SelectedRecipe.Name, SelectedAmount)
	end)

	CraftingGui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if CraftingGui.Enabled then
			HotbarWasEnabled = HotbarGui.Enabled
			HotbarGui.Enabled = false
			self:RefreshInventory()
			self:RefreshRecipes()
		elseif HotbarWasEnabled ~= nil then
			HotbarGui.Enabled = HotbarWasEnabled
			HotbarWasEnabled = nil
		end
	end)
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
		if CraftingGui.Enabled then
			CraftingController:RefreshInventory()
			CraftingController:RefreshRecipeDetails()
		end
	end)
end

return CraftingController
