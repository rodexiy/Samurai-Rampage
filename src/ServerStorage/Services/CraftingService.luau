local Knit = require(game.ReplicatedStorage.Packages.Knit)

local CraftingService = Knit.CreateService({
	Name = "CraftingService",
	Client = {},
})

local DataService
local AlertService
local ItemService
local InventoryService

local function IsRecipeUnlocked(PlayerData, ItemData)
	return not ItemData.BlueprintRequired or table.find(PlayerData.UnlockedBlueprints, ItemData.Name) ~= nil
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

function CraftingService:GetMaxCraftable(Player: Player, ItemToCraft: string): number
	local ItemData = ItemService:GetItemData(ItemToCraft)
	local PlayerData = DataService:GetData(Player)
	if not ItemData or not ItemData.CraftingRequirements or not IsRecipeUnlocked(PlayerData, ItemData) then
		return 0
	end

	local MaxCraftable = math.huge
	for Requirement, Amount in ItemData.CraftingRequirements do
		local ItemInInventory = InventoryService:GetPlayerItemByName(Player, Requirement)
		local Stack = if ItemInInventory then ItemInInventory.Stack else 0
		MaxCraftable = math.min(MaxCraftable, math.floor(Stack / Amount))
	end

	local AmountPerCraft = ItemData.AmountPerCraft or 1
	local CraftedItem = InventoryService:GetPlayerItemByName(Player, ItemToCraft)
	local CurrentStack = if CraftedItem then CraftedItem.Stack else 0
	local RemainingCapacity = (ItemData.MaxStack or 1) - CurrentStack
	MaxCraftable = math.min(MaxCraftable, math.floor(RemainingCapacity / AmountPerCraft))

	return math.max(0, MaxCraftable)
end

function CraftingService:Craft(Player: Player, ItemToCraft: string, RequestedAmount: number | string?): number
	local MaxCraftable = self:GetMaxCraftable(Player, ItemToCraft)
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

	local ItemData = ItemService:GetItemData(ItemToCraft)
	for Requirement, RequirementAmount in ItemData.CraftingRequirements do
		InventoryService:RemoveItemFromPlayer(Player, Requirement, RequirementAmount * Amount)
	end

	local AmountPerCraft = ItemData.AmountPerCraft or 1
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

function CraftingService:GetAvailableRecipes(Player: Player)
	local PlayerData = DataService:GetData(Player)
	local Recipes = {}

	for _, ItemData in ItemService:GetAllItems() do
		if not ItemData.CraftingRequirements or not IsRecipeUnlocked(PlayerData, ItemData) then
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
			Type = ItemData.Type,
		})
	end

	table.sort(Recipes, function(A, B)
		return A.DisplayName < B.DisplayName
	end)

	return Recipes
end

function CraftingService.Client:GetAvailableRecipes(Player: Player)
	return self.Server:GetAvailableRecipes(Player)
end

function CraftingService.Client:Craft(Player: Player, ItemToCraft: string, RequestedAmount: number | string?)
	return self.Server:Craft(Player, ItemToCraft, RequestedAmount)
end

function CraftingService.KnitInit()
	ItemService = Knit.GetService("ItemService")
	AlertService = Knit.GetService("AlertService")
	DataService = Knit.GetService("DataService")
	InventoryService = Knit.GetService("InventoryService")
end

function CraftingService.KnitStart() end

return CraftingService
