local Knit = require(game.ReplicatedStorage.Packages.Knit)

local CraftingService = Knit.CreateService({
	Name = "CraftingService",
	Client = {},
})

local DataService
local AlertService
local ItemService
local InventoryService

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

function CraftingService:Craft(Player: Player, ItemToCraft: string)
	if not self:HaveCraftingItems(Player, ItemToCraft) then
		AlertService:AlertPlayer(Player, "You do not have the required items to craft this item.", "Error")
		return
	end

	local ItemData = ItemService:GetItemData(ItemToCraft)
	for Requirement, Amount in ItemData.CraftingRequirements do
		InventoryService:RemoveItemByName(Player, Requirement, Amount)
	end

	local AmountPerCraft = ItemData.AmountPerCraft or 1
	InventoryService:GiveItemToPlayer(Player, ItemService:CreateItem(ItemToCraft, AmountPerCraft))
end

function CraftingService:HaveCraftingItems(Player: Player, ItemToCraft: string): boolean
	local ItemData = ItemService:GetItemData(ItemToCraft)
	if not ItemData or not ItemData.CraftingRequirements then
		return false
	end

	for Requirement, Amount in ItemData.CraftingRequirements do
		local ItemInInventory = InventoryService:GetPlayerItemByName(Player, Requirement)
		if not ItemInInventory then
			return false
		end

		if ItemInInventory.Amount < Amount then
			return false
		end
	end

	return true
end

function CraftingService:GetAvailableRecipes(Player: Player) end

function CraftingService.KnitInit()
	ItemService = Knit.GetService("ItemService")
	AlertService = Knit.GetService("AlertService")
	DataService = Knit.GetService("DataService")
	InventoryService = Knit.GetService("InventoryService")
end

function CraftingService.KnitStart() end

return CraftingService
