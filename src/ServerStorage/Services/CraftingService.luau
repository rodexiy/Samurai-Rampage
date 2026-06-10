local Knit = require(game.ReplicatedStorage.Packages.Knit)

local CraftingService = Knit.CreateService({
	Name = "CraftingService",
	Client = {},
})

local DataService
local AlertService
local ItemService
local InventoryService

local DEFAULT_RECIPE_TYPE = "Crafting"

local function IsRecipeUnlocked(PlayerData, ItemData)
	if not PlayerData then
		return false
	end

	return not ItemData.BlueprintRequired or table.find(PlayerData.UnlockedBlueprints, ItemData.Name) ~= nil
end

local function GetRecipeType(ItemData)
	return ItemData.RecipeType or DEFAULT_RECIPE_TYPE
end

local function MatchesRecipeType(ItemData, RecipeType: string?)
	return not RecipeType or GetRecipeType(ItemData) == RecipeType
end

local function GetRequirementGroups(ItemData)
	local Requirements = ItemData.CraftingRequirements
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

local function GetMaxCraftableForRequirements(Player: Player, Requirements): number
	local MaxCraftable = math.huge
	for Requirement, Amount in Requirements do
		local ItemInInventory = InventoryService:GetPlayerItemByName(Player, Requirement)
		local Stack = if ItemInInventory then ItemInInventory.Stack else 0
		MaxCraftable = math.min(MaxCraftable, math.floor(Stack / Amount))
	end

	return MaxCraftable
end

local function ResolveRequirements(Player: Player, ItemData, SelectedOptions, RequireSelections: boolean?)
	local CombinedRequirements = {}

	for GroupIndex, Options in GetRequirementGroups(ItemData) do
		local OptionIndex
		if #Options == 1 then
			OptionIndex = 1
		elseif typeof(SelectedOptions) == "table" then
			OptionIndex = math.floor(tonumber(SelectedOptions[GroupIndex]) or 0)
		end

		if not OptionIndex or not Options[OptionIndex] then
			if RequireSelections then
				return nil, 0
			end

			local BestMaxCraftable = -1
			for Index, Requirements in Options do
				local MaxCraftable = GetMaxCraftableForRequirements(Player, Requirements)
				if MaxCraftable > BestMaxCraftable then
					OptionIndex = Index
					BestMaxCraftable = MaxCraftable
				end
			end
		end

		for Requirement, Amount in Options[OptionIndex] do
			CombinedRequirements[Requirement] = (CombinedRequirements[Requirement] or 0) + Amount
		end
	end

	return CombinedRequirements, GetMaxCraftableForRequirements(Player, CombinedRequirements)
end

function CraftingService:UnlockBlueprint(Player: Player, BlueprintName: string)
	local PlayerData = DataService:GetData(Player)
	if table.find(PlayerData.UnlockedBlueprints, BlueprintName) then
		AlertService:AlertPlayer(Player, "Blueprint already unlocked.", "Error")
		return
	end

	table.insert(PlayerData.UnlockedBlueprints, BlueprintName)
	AlertService:AlertPlayer(Player, "Blueprint unlocked.", "Success")
end

function CraftingService:UnlockAllBlueprints() end

function CraftingService:GetMaxCraftable(
	Player: Player,
	ItemToCraft: string,
	RecipeType: string?,
	SelectedOptions: { [number]: number }?
): number
	local ItemData = ItemService:GetItemData(ItemToCraft)
	local PlayerData = DataService:GetData(Player)
	if
		not ItemData
		or #GetRequirementGroups(ItemData) == 0
		or not MatchesRecipeType(ItemData, RecipeType)
		or not IsRecipeUnlocked(PlayerData, ItemData)
	then
		return 0
	end

	local _, MaxCraftable = ResolveRequirements(Player, ItemData, SelectedOptions)

	local AmountPerCraft = ItemData.AmountPerCraft or 1
	local CraftedItem = InventoryService:GetPlayerItemByName(Player, ItemToCraft)
	local CurrentStack = if CraftedItem then CraftedItem.Stack else 0
	local RemainingCapacity = (ItemData.MaxStack or 1) - CurrentStack
	MaxCraftable = math.min(MaxCraftable, math.floor(RemainingCapacity / AmountPerCraft))

	return math.max(0, MaxCraftable)
end

function CraftingService:Craft(
	Player: Player,
	ItemToCraft: string,
	RequestedAmount: number | string?,
	RecipeType: string?,
	SelectedOptions: { [number]: number }?
): number
	local ItemData = ItemService:GetItemData(ItemToCraft)
	local PlayerData = DataService:GetData(Player)
	if
		not ItemData
		or #GetRequirementGroups(ItemData) == 0
		or not MatchesRecipeType(ItemData, RecipeType)
		or not IsRecipeUnlocked(PlayerData, ItemData)
	then
		return 0
	end

	local Requirements, MaxCraftable = ResolveRequirements(Player, ItemData, SelectedOptions, true)
	if not Requirements then
		AlertService:AlertPlayer(Player, "Select an option for every material group.", "Error")
		return 0
	end

	local AmountPerCraft = ItemData.AmountPerCraft or 1
	local CraftedItem = InventoryService:GetPlayerItemByName(Player, ItemToCraft)
	local CurrentStack = if CraftedItem then CraftedItem.Stack else 0
	local RemainingCapacity = (ItemData.MaxStack or 1) - CurrentStack
	MaxCraftable = math.min(MaxCraftable, math.floor(RemainingCapacity / AmountPerCraft))

	if MaxCraftable <= 0 then
		AlertService:AlertPlayer(Player, "You do not have the required items to craft this item.", "Error")
		return 0
	end

	local Amount = if RequestedAmount == "All"
		then MaxCraftable
		else math.clamp(math.floor(tonumber(RequestedAmount) or 1), 1, MaxCraftable)

	if Amount <= 0 then
		AlertService:AlertPlayer(Player, "You do not have the required items to craft this item.", "Error")
		return 0
	end

	for Requirement, RequirementAmount in Requirements do
		InventoryService:RemoveItemFromPlayer(Player, Requirement, RequirementAmount * Amount)
	end

	local CraftedAmount = AmountPerCraft * Amount
	InventoryService:GiveItemToPlayer(Player, ItemService:CreateItem(ItemToCraft, CraftedAmount))
	-- AlertService:AlertPlayer(
	-- 	Player,
	-- 	"Crafted " .. tostring(CraftedAmount) .. "x " .. (ItemData.DisplayName or ItemData.Name) .. ".",
	-- 	"Success"
	-- )

	return Amount
end

function CraftingService:HaveCraftingItems(Player: Player, ItemToCraft: string, Amount: number?): boolean
	return self:GetMaxCraftable(Player, ItemToCraft) >= (Amount or 1)
end

function CraftingService:GetAvailableRecipes(Player: Player, RecipeType: string?)
	local PlayerData = DataService:GetData(Player)
	local Recipes = {}

	for _, ItemData in ItemService:GetAllItems() do
		if
			#GetRequirementGroups(ItemData) == 0
			or not MatchesRecipeType(ItemData, RecipeType)
			or not IsRecipeUnlocked(PlayerData, ItemData)
		then
			continue
		end

		table.insert(Recipes, {
			AmountPerCraft = ItemData.AmountPerCraft or 1,
			Class = ItemData.Class,
			CraftingRequirements = ItemData.CraftingRequirements,
			Description = ItemData.Description,
			DisplayName = ItemData.DisplayName or ItemData.Name,
			MaxStack = ItemData.MaxStack or 1,
			Name = ItemData.Name,
			Rarity = ItemData.Rarity,
			RecipeType = GetRecipeType(ItemData),
			Type = ItemData.Type,
		})
	end

	table.sort(Recipes, function(A, B)
		return A.DisplayName < B.DisplayName
	end)

	return Recipes
end

function CraftingService.Client:GetAvailableRecipes(Player: Player, RecipeType: string?)
	return self.Server:GetAvailableRecipes(Player, RecipeType)
end

function CraftingService.Client:Craft(
	Player: Player,
	ItemToCraft: string,
	RequestedAmount: number | string?,
	RecipeType: string?,
	SelectedOptions: { [number]: number }?
)
	return self.Server:Craft(Player, ItemToCraft, RequestedAmount, RecipeType, SelectedOptions)
end

function CraftingService.KnitInit()
	ItemService = Knit.GetService("ItemService")
	AlertService = Knit.GetService("AlertService")
	DataService = Knit.GetService("DataService")
	InventoryService = Knit.GetService("InventoryService")
end

function CraftingService.KnitStart() end

return CraftingService
