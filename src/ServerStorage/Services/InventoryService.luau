local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local InventoryService = Knit.CreateService({
	Name = "InventoryService",
	Client = {
		InventoryUpdated = Knit.CreateSignal(),
		HotbarUpdated = Knit.CreateSignal(),
		ItemAdded = Knit.CreateSignal(),
	},
})

local DataService
local ToolService
local WeaponService
local EquipmentService
local ValuesService
local ItemService
local AlertService
local GamepassService
local StanceService

local DeepCopy = require(game.ReplicatedStorage.Shared.Utils.DeepCopy)

local function CanChangeEquippedItems(Character: Model?)
	if not Character then
		return true
	end

	return not (
		Character:GetAttribute("Attacking")
		or Character:GetAttribute("BeenHitted")
		or Character:GetAttribute("Blocking")
		or Character:GetAttribute("BeenDeflected")
		or Character:GetAttribute("Ragdoll")
	)
end

function InventoryService:GetInventoryData(Player: Player)
	local PlayerData = DataService:GetData(Player)
	local InventoryData = {}
	for _, Item in PlayerData.Inventory do
		table.insert(InventoryData, ItemService:ImplementData(Item))
	end

	return InventoryData
end

function InventoryService:UpdateUI(Player: Player, HotbarToo: boolean)
	if HotbarToo then
		InventoryService.Client.HotbarUpdated:Fire(Player)
	end
	InventoryService.Client.InventoryUpdated:Fire(Player, InventoryService:GetInventoryData(Player))
end

function InventoryService:GetPlayerItemByName(Player: Player, ItemName: string): { any }
	local Item = self:GetRawPlayerItemByName(Player, ItemName)
	if Item then
		return ItemService:ImplementData(Item)
	end
end

function InventoryService:GetRawPlayerItemByName(Player: Player, ItemName: string): { any }
	local PlayerData = DataService:GetData(Player)
	for _, Item in PlayerData.Inventory do
		if Item.Name == ItemName then
			return Item
		end
	end
end

function InventoryService:GiveItemToPlayer(Player: Player, Item: { any })
	local PlayerData = DataService:GetData(Player)

	local ItemData = ItemService:GetItemData(Item.Name)
	local AmountToAdd = Item.Stack
	local ItemInInventory = self:GetRawPlayerItemByName(Player, Item.Name)
	if ItemInInventory then
		local OldStack = ItemInInventory.Stack

		ItemInInventory.Stack += Item.Stack or 1
		ItemInInventory.Stack = math.min(ItemData.MaxStack or 1, ItemInInventory.Stack)

		AmountToAdd = ItemInInventory.Stack - OldStack
	else
		table.insert(PlayerData.Inventory, Item)
	end

	local ToolInPlayer = ToolService:GetToolFromPlayer(Player, Item.Name)
	if ToolInPlayer and ItemInInventory then
		ToolService:CopyAttributesToTool(ToolInPlayer, ItemService:ImplementData(ItemInInventory))
	end

	if AmountToAdd <= 0 then
		return 0
	end

	InventoryService.Client.ItemAdded:Fire(Player, Item.DisplayName or Item.Name, AmountToAdd)
	InventoryService:UpdateUI(Player, ToolInPlayer ~= nil)

	return AmountToAdd
end

function InventoryService:RemoveItemFromHotbarByName(Player: Player, ItemName: string)
	local PlayerData = DataService:GetData(Player)

	ToolService:RemoveToolFromPlayer(Player, ItemName)

	for index, Name in PlayerData.Hotbar do
		if Name == ItemName then
			PlayerData.Hotbar[index] = nil
			return true
		end
	end
	return false
end

function InventoryService:GetItemHotbarIndex(Player: Player, ItemName: string)
	local PlayerData = DataService:GetData(Player)
	for index, Name in PlayerData.Hotbar do
		if Name == ItemName then
			return index
		end
	end
end

function InventoryService:RemoveItemFromHotbar(Player: Player, Index: number, update: boolean)
	local PlayerData = DataService:GetData(Player)

	local ArtifactName
	local ToolInIndex = self:GetToolInHotbarIndex(Player, Index)
	if ToolInIndex and ToolInIndex:GetAttribute("Class") == "Artifact" then
		if GamepassService:HasGamepass(Player, "ArtifactBag") then
			if InventoryService:GetPlayerItemByName(Player, ToolInIndex.Name) then
				AlertService:AlertPlayer(Player, "You can only have one artifact of this type!", "Error")
				return
			end

			ArtifactName = ToolInIndex.Name

			ToolService:RemoveToolFromPlayer(Player, ArtifactName)

			local ArtifactItem = ItemService:CreateItem(ArtifactName, 1)
			self:GiveItemToPlayer(Player, ArtifactItem)
			update = false
		end
	else
		local ItemName = PlayerData.Hotbar[tostring(Index)]
		if ItemName then
			self:RemoveItemFromHotbarByName(Player, ItemName)
		end
	end

	if update then
		InventoryService:UpdateUI(Player, true)
	end
end
function InventoryService.Client:RemoveItemFromHotbar(Player: Player, Index: number)
	self.Server:RemoveItemFromHotbar(Player, Index, true)
end

function InventoryService:EquipToHotbar(Player: Player, ItemName: string, Index: number)
	local PlayerData = DataService:GetData(Player)

	if not self:GetPlayerItemByName(Player, ItemName) then
		return
	end

	local ToolInIndex = self:GetToolInHotbarIndex(Player, Index)
	if ToolInIndex and ToolInIndex:GetAttribute("Class") == "Artifact" then
		AlertService:AlertPlayer(Player, "You have a artifact in this slot!", "Warn")
		return
	end
	self:RemoveItemFromHotbar(Player, Index)
	PlayerData.Hotbar[tostring(Index)] = nil

	local ItemData = ItemService:GetItemData(ItemName)
	local updateUI = true
	if ItemData.Class == "Artifact" then
		updateUI = false
		InventoryService:RemoveItemFromPlayer(Player, ItemName, 1, true)
	else
		self:RemoveItemFromHotbarByName(Player, ItemName)
		PlayerData.Hotbar[tostring(Index)] = ItemName
	end

	ToolService:GiveToolToPlayer(Player, ItemName, Index, true)

	if updateUI then
		InventoryService:UpdateUI(Player, true)
	end
end
function InventoryService.Client:EquipToHotbar(Player: Player, ItemName: string, Index: number)
	self.Server:EquipToHotbar(Player, ItemName, Index)
end

function InventoryService:GetAvailableHotbarIndex(Player: Player)
	local Indexes = {}

	local Tools = Player.Backpack:GetChildren()

	local Character = Player.Character
	if Character then
		table.insert(Tools, Character:FindFirstChildWhichIsA("Tool"))
	end

	for _, Tool in Player.Backpack:GetChildren() do
		local Index = Tool:GetAttribute("HotbarIndex")
		if Index == 0 then
			Index = 10
		end
		Indexes[tonumber(Index)] = true
	end

	for i = 1, 10 do
		if not Indexes[i] then
			if i == 10 then
				return 0
			end
			return i
		end
	end
end

function InventoryService:GetToolInHotbarIndex(Player: Player, Index: number)
	local Character = Player.Character
	for _, Tool: Tool in Player.Backpack:GetChildren() do
		if Tool:GetAttribute("HotbarIndex") == tonumber(Index) then
			return Tool
		end
	end
	if not Character then
		return
	end

	local Tool: Tool = Character:FindFirstChildWhichIsA("Tool")
	if Tool and Tool:GetAttribute("HotbarIndex") == tonumber(Index) then
		return Tool
	end
end

function InventoryService:RemoveItemFromPlayer(
	Player: Player,
	ItemName: string,
	_Amount: number,
	dontRemoveFromHotbar: boolean
)
	local Amount = _Amount or 1

	local Item = self:GetRawPlayerItemByName(Player, ItemName)

	if not Item then
		return
	end

	if Amount == "all" then
		Amount = Item.Stack
	end

	Item.Stack -= Amount

	local PlayerData = DataService:GetData(Player)
	if Item.Stack <= 0 then
		if not dontRemoveFromHotbar then
			self:RemoveItemFromHotbarByName(Player, ItemName)
		end
		for index, Item in PlayerData.Inventory do
			if Item.Name == ItemName then
				table.remove(PlayerData.Inventory, index)
				break
			end
		end
	end

	if Item.Stack > 0 then
		local Tool = ToolService:GetToolFromPlayer(Player, ItemName)
		if Tool then
			ToolService:CopyAttributesToTool(Tool, ItemService:ImplementData(Item))
		end
	end

	self:UpdateUI(Player, true)
end

function InventoryService:IsEquipped(Player: Player, ItemName: string)
	local PlayerData = DataService:GetData(Player)

	for _, Equipped in PlayerData.Equipped do
		if Equipped == ItemName then
			return true
		end
	end

	return false
end

function InventoryService:EquipUnequipItem(Player: Player, ItemName: string)
	local PlayerData = DataService:GetData(Player)
	local ItemData = ItemService:GetItemData(ItemName)

	if not ItemData then
		return
	end

	local Character = Player.Character

	if not CanChangeEquippedItems(Character) then
		return
	end

	if ItemData.Class == "Weapon" then
		if PlayerData.Equipped.Weapon ~= ItemName then
			local StanceData = StanceService:GetStance(PlayerData.SelectedStance)

			if not StanceData or StanceData.WeaponType ~= ItemData.Type then
				AlertService:AlertPlayer(Player, "You cannot equip this weapon in this stance!", "Warn")
				return
			end

			if PlayerData.Equipped.LeftWeapon == ItemName then
				self:UnequipLeftWeapon(Player, false, false)
			end

			PlayerData.Equipped.Weapon = ItemName

			if Character then
				if Character:GetAttribute("WeaponEquipped") then
					WeaponService:Equip(Character, false, 1.5)
				end
				Character:SetAttribute("Weapon", ItemName)
				Character:SetAttribute("WeaponType", ItemData.Type)
				WeaponService:LoadWeapon(
					Character,
					PlayerData.Equipped.Weapon,
					PlayerData.Equipped.LeftWeapon,
					PlayerData.SelectedStance
				)

				Character:SetAttribute("WeaponEquipped", false)
				ValuesService:UpdateDamage(Character)
			end
		else
			PlayerData.Equipped.Weapon = nil
			PlayerData.Equipped.LeftWeapon = nil
			if Character then
				if Character:GetAttribute("WeaponEquipped") then
					WeaponService:Equip(Character, false, 1.5)
				end
				WeaponService:UnloadWeapon(Character)
				Character:SetAttribute("Weapon", nil)
				Character:SetAttribute("WeaponType", nil)
				Character:SetAttribute("LeftWeapon", nil)
				Character:SetAttribute("LeftWeaponType", nil)
				Character:SetAttribute("WeaponEquipped", false)
				ValuesService:UpdateDamage(Character)
			end
		end
	elseif not self:IsEquipped(Player, ItemName) then
		if ItemData.Class == "Equipable" then
			if Character then
				PlayerData.Equipped[ItemData.Type] = ItemName
				if Character then
					EquipmentService:LoadEquipment(Character, ItemData.Type, ItemName)
					ValuesService:UpdateEquipableValues(Character)
				end
			end
		end
	else
		if ItemData.Class == "Equipable" then
			PlayerData.Equipped[ItemData.Type] = nil

			if Character then
				if Character then
					EquipmentService:UnloadEquipment(Character, ItemData.Type)
					ValuesService:UpdateEquipableValues(Character)
				end
			end
		end
	end

	self:UpdateUI(Player)
end
function InventoryService.Client:EquipUnequipItem(Player: Player, ItemName: string)
	self.Server:EquipUnequipItem(Player, ItemName)
end

function InventoryService:UnequipLeftWeapon(Player: Player, UpdateUI: boolean?, LoadFallback: boolean?)
	local PlayerData = DataService:GetData(Player)
	PlayerData.Equipped.LeftWeapon = nil

	local Character = Player.Character
	if Character then
		local StanceData = StanceService:GetStance(PlayerData.SelectedStance)
		if LoadFallback ~= false and StanceData and StanceData.DualWield and PlayerData.Equipped.Weapon then
			WeaponService:LoadLeftWeapon(
				Character,
				PlayerData.Equipped.LeftWeapon,
				PlayerData.Equipped.Weapon,
				PlayerData.SelectedStance
			)
		else
			WeaponService:UnloadLeftWeapon(Character)
		end

		ValuesService:UpdateDamage(Character)
	end

	if UpdateUI ~= false then
		self:UpdateUI(Player)
	end
end

function InventoryService:EquipUnequipLeftItem(Player: Player, ItemName: string)
	local PlayerData = DataService:GetData(Player)
	local ItemData = ItemService:GetItemData(ItemName)

	if not ItemData or ItemData.Class ~= "Weapon" then
		return
	end

	local Character = Player.Character
	if not CanChangeEquippedItems(Character) then
		return
	end

	if PlayerData.Equipped.LeftWeapon == ItemName then
		self:UnequipLeftWeapon(Player)
		return
	end

	local StanceData = StanceService:GetStance(PlayerData.SelectedStance)
	if not StanceData or not StanceData.DualWield then
		AlertService:AlertPlayer(Player, "This stance cannot dual wield.", "Warn")
		return
	end

	if StanceData.WeaponType ~= ItemData.Type then
		AlertService:AlertPlayer(Player, "You cannot equip this weapon in this stance!", "Warn")
		return
	end

	if not PlayerData.Equipped.Weapon then
		AlertService:AlertPlayer(Player, "Equip a right-hand weapon first.", "Warn")
		return
	end

	if PlayerData.Equipped.Weapon == ItemName then
		AlertService:AlertPlayer(Player, "This weapon is already in your right hand.", "Warn")
		return
	end

	PlayerData.Equipped.LeftWeapon = ItemName

	if Character then
		Character:SetAttribute("LeftWeapon", ItemName)
		Character:SetAttribute("LeftWeaponType", ItemData.Type)
		WeaponService:LoadLeftWeapon(
			Character,
			PlayerData.Equipped.LeftWeapon,
			PlayerData.Equipped.Weapon,
			PlayerData.SelectedStance
		)
		ValuesService:UpdateDamage(Character)
	end

	self:UpdateUI(Player)
end
function InventoryService.Client:EquipUnequipLeftItem(Player: Player, ItemName: string)
	self.Server:EquipUnequipLeftItem(Player, ItemName)
end

function InventoryService:GetInventory(Player: Player)
	local PlayerData = DataService:GetData(Player)
	local InventoryCopy = DeepCopy(PlayerData.Inventory)
	local StanceData = StanceService:GetStance(PlayerData.SelectedStance)

	for _, Item in InventoryCopy do
		local ItemData = ItemService:GetItemData(Item.Name)
		Item.Description = ItemData.Description
		Item.Rarity = ItemData.Rarity
		Item.DisplayName = ItemData.DisplayName
		Item.Type = ItemData.Type
		Item.Class = ItemData.Class
		Item.Hidden = ItemData.Hidden

		if Item.Class ~= "Equipable" and Item.Class ~= "Weapon" then
			continue
		end

		if Item.Class == "Weapon" then
			Item.Equipped = PlayerData.Equipped.Weapon == Item.Name
			Item.EquippedLeft = PlayerData.Equipped.LeftWeapon == Item.Name
			Item.CanEquipLeft = StanceData
				and StanceData.DualWield
				and StanceData.WeaponType == Item.Type
				and PlayerData.Equipped.Weapon ~= nil
				and PlayerData.Equipped.Weapon ~= Item.Name
		else
			Item.Equipped = self:IsEquipped(Player, Item.Name)
		end
	end

	return InventoryCopy
end
function InventoryService.Client:GetInventory(Player: Player)
	return self.Server:GetInventory(Player)
end

function InventoryService.KnitInit()
	DataService = Knit.GetService("DataService")
	ToolService = Knit.GetService("ToolService")
	WeaponService = Knit.GetService("WeaponService")
	EquipmentService = Knit.GetService("EquipmentService")
	ValuesService = Knit.GetService("ValuesService")
	ItemService = Knit.GetService("ItemService")
	AlertService = Knit.GetService("AlertService")
	GamepassService = Knit.GetService("GamepassService")
	StanceService = Knit.GetService("StanceService")
end

function InventoryService.KnitStart() end

return InventoryService
