local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

type ItemData = { [string]: any }

local InventoryService = Knit.CreateService({
	Name = "InventoryService",
	Client = {
		InventoryUpdated = Knit.CreateSignal(),
		HotbarUpdated = Knit.CreateSignal(),
		ItemAdded = Knit.CreateSignal(),
		InventoryAction = Knit.CreateSignal(),
		InventoryActionResult = Knit.CreateSignal(),
		InventoryLayoutUpdated = Knit.CreateSignal(),
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
local BowService
local InventoryGridService

local DeepCopy = require(ReplicatedStorage.Shared.Utils.DeepCopy)
local InventoryEquipmentSlots = require(ReplicatedStorage.Shared.Utils.InventoryEquipmentSlots)

local function CanChangeEquippedItems(Character: Model?): boolean
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

function InventoryService:GiveItemToPlayer(Player: Player, Item: { any }): number
	local PlayerData = DataService:GetData(Player)
	if not InventoryGridService:CanAdd(Player, Item) then
		return 0
	end

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
			if not InventoryGridService:CanAdd(Player, {Name = ArtifactName, Stack = 1}) then
				AlertService:AlertPlayer(Player, "Not enough backpack space.", "Warn")
				return
			end

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
	local ItemData = ItemService:GetItemData(ItemName)
	if not ItemData or ItemData.Type == "Bow" or ItemData.Type == "Ammunition" then
		return
	end

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
		if PlayerData.Equipped.Bow == ItemName then
			BowService:UnequipItem(Player)
		end

		if not dontRemoveFromHotbar then
			self:RemoveItemFromHotbarByName(Player, ItemName)
		end
		for index, InventoryItem in PlayerData.Inventory do
			if InventoryItem.Name == ItemName then
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

function InventoryService:CommitEquipment(Player: Player, NextEquipped: { [string]: string }, PreferredName: string?): (boolean, string?)
	local Success, Reason = InventoryGridService:SetEquippedItems(Player, NextEquipped, PreferredName)
	if not Success then
		AlertService:AlertPlayer(Player, Reason, "Warn")
	end

	return Success, Reason
end

function InventoryService:EquipUnequipItem(Player: Player, ItemName: string): (boolean, string?)
	local PlayerData = DataService:GetData(Player)
	local ItemData = ItemService:GetItemData(ItemName)

	if not ItemData then
		return false, "This item is not in your inventory."
	end

	local Character = Player.Character

	if not CanChangeEquippedItems(Character) then
		return false, "You cannot change equipment right now."
	end

	if ItemData.Class == "Equipable" then
		if PlayerData.Equipped[ItemData.Type] == ItemName then
			return self:UnequipEquipmentSlot(Player, ItemData.Type, ItemName)
		end

		return self:EquipEquipmentSlot(Player, ItemData.Type, ItemName)
	end

	local Item = self:GetRawPlayerItemByName(Player, ItemName)
	if ItemData.Class ~= "Weapon" or not Item or Item.Stack <= 0 then
		return false, "This weapon is not in your inventory."
	end

	local Ranged = ItemData.Type == "Bow"
	local WasEquipped = (if Ranged then PlayerData.Equipped.Bow else PlayerData.Equipped.Weapon) == ItemName
	if not Ranged and not WasEquipped then
		local StanceData = StanceService:GetStance(PlayerData.SelectedStance)

		if not StanceData or StanceData.WeaponType ~= ItemData.Type then
			AlertService:AlertPlayer(Player, "You cannot equip this weapon in this stance!", "Warn")
			return false, "You cannot equip this weapon in this stance!"
		end
	end

	local NextEquipped = InventoryEquipmentSlots.WithSlot(PlayerData.Equipped, if Ranged then "Bow" else "Weapon", if WasEquipped then nil else ItemName)
	local Success, Reason = self:CommitEquipment(Player, NextEquipped, if WasEquipped then nil else ItemName)
	if not Success then
		return false, Reason
	end

	if Ranged then
		if WasEquipped then
			BowService:UnequipItem(Player)
		else
			BowService:LoadBow(Player)
		end
	elseif Character then
		if Character:GetAttribute("WeaponEquipped") then
			WeaponService:Equip(Character, false, 1.5)
		end

		if not WasEquipped then
			Character:SetAttribute("Weapon", ItemName)
			Character:SetAttribute("WeaponType", ItemData.Type)
			WeaponService:LoadWeapon(
				Character,
				PlayerData.Equipped.Weapon,
				PlayerData.Equipped.LeftWeapon,
				PlayerData.SelectedStance
			)
		else
			WeaponService:UnloadWeapon(Character)
			Character:SetAttribute("Weapon", nil)
			Character:SetAttribute("WeaponType", nil)
			Character:SetAttribute("LeftWeapon", nil)
			Character:SetAttribute("LeftWeaponType", nil)
		end

		Character:SetAttribute("WeaponEquipped", false)
		ValuesService:UpdateDamage(Character)
	end

	self:UpdateUI(Player)
	return true
end
function InventoryService.Client:EquipUnequipItem(Player: Player, ItemName: string)
	self.Server:EquipUnequipItem(Player, ItemName)
end

function InventoryService:EquipEquipmentSlot(Player: Player, SlotName: string, ItemName: string): (boolean, string?)
	if InventoryEquipmentSlots.IsWeaponSlot(SlotName) then
		return self:SetWeaponEquipmentSlot(Player, SlotName, ItemName)
	end

	if not CanChangeEquippedItems(Player.Character) then
		return false, "You cannot change equipment right now."
	end

	local Success, Reason = InventoryGridService:SetEquipment(Player, SlotName, ItemName)
	if not Success then
		AlertService:AlertPlayer(Player, Reason, "Warn")
		return false, Reason
	end

	local Character = Player.Character
	if Character then
		EquipmentService:LoadEquipment(Character, SlotName, ItemName)
		ValuesService:UpdateEquipableValues(Character)
	end

	self:UpdateUI(Player)
	return true
end

function InventoryService:UnequipEquipmentSlot(Player: Player, SlotName: string, ItemName: string): (boolean, string?)
	if InventoryEquipmentSlots.IsWeaponSlot(SlotName) then
		return self:SetWeaponEquipmentSlot(Player, SlotName, ItemName, true)
	end

	if not CanChangeEquippedItems(Player.Character) then
		return false, "You cannot change equipment right now."
	end

	local Success, Reason = InventoryGridService:SetEquipment(Player, SlotName, nil, ItemName)
	if not Success then
		AlertService:AlertPlayer(Player, Reason, "Warn")
		return false, Reason
	end

	local Character = Player.Character
	if Character then
		EquipmentService:UnloadEquipment(Character, SlotName)
		ValuesService:UpdateEquipableValues(Character)
	end

	self:UpdateUI(Player)
	return true
end

function InventoryService.Client:UnequipEquipmentSlot(Player: Player, SlotName: string, ItemName: string)
	self.Server:UnequipEquipmentSlot(Player, SlotName, ItemName)
end

function InventoryService:UnequipLeftWeapon(Player: Player, UpdateUI: boolean?, LoadFallback: boolean?): (boolean, string?)
	local PlayerData = DataService:GetData(Player)
	local NextEquipped = InventoryEquipmentSlots.WithSlot(PlayerData.Equipped, "LeftWeapon", nil)
	local Success, Reason = self:CommitEquipment(Player, NextEquipped)
	if not Success then
		return false, Reason
	end

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

	return true
end

function InventoryService:EquipUnequipLeftItem(Player: Player, ItemName: string): (boolean, string?)
	local PlayerData = DataService:GetData(Player)
	local ItemData = ItemService:GetItemData(ItemName)

	if not ItemData or ItemData.Class ~= "Weapon" or ItemData.Type == "Bow" then
		return false, "This item is not a melee weapon."
	end

	local Character = Player.Character
	if not CanChangeEquippedItems(Character) then
		return false, "You cannot change equipment right now."
	end

	if PlayerData.Equipped.LeftWeapon == ItemName then
		return self:UnequipLeftWeapon(Player)
	end

	local StanceData = StanceService:GetStance(PlayerData.SelectedStance)
	if not StanceData or not StanceData.DualWield then
		AlertService:AlertPlayer(Player, "This stance cannot dual wield.", "Warn")
		return false, "This stance cannot dual wield."
	end

	if StanceData.WeaponType ~= ItemData.Type then
		AlertService:AlertPlayer(Player, "You cannot equip this weapon in this stance!", "Warn")
		return false, "You cannot equip this weapon in this stance!"
	end

	if not PlayerData.Equipped.Weapon then
		AlertService:AlertPlayer(Player, "Equip a right-hand weapon first.", "Warn")
		return false, "Equip a right-hand weapon first."
	end

	if PlayerData.Equipped.Weapon == ItemName then
		AlertService:AlertPlayer(Player, "This weapon is already in your right hand.", "Warn")
		return false, "This weapon is already in your right hand."
	end

	local Item = self:GetRawPlayerItemByName(Player, ItemName)
	if not Item or Item.Stack <= 0 then
		return false, "This weapon is not in your inventory."
	end

	local NextEquipped = InventoryEquipmentSlots.WithSlot(PlayerData.Equipped, "LeftWeapon", ItemName)
	local Success, Reason = self:CommitEquipment(Player, NextEquipped, ItemName)
	if not Success then
		return false, Reason
	end

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
	return true
end
function InventoryService.Client:EquipUnequipLeftItem(Player: Player, ItemName: string)
	self.Server:EquipUnequipLeftItem(Player, ItemName)
end

function InventoryService:GetWeaponEquipment(Player: Player): InventoryEquipmentSlots.WeaponEquipment
	local Data = DataService:GetData(Player)
	return InventoryEquipmentSlots.Resolve(Data.Equipped, StanceService:GetStance(Data.SelectedStance), ItemService:GetItemData(Data.Equipped.Weapon))
end

function InventoryService:SetWeaponEquipmentSlot(Player: Player, SlotName: string, ItemName: string, Unequip: boolean?): (boolean, string?)
	if not CanChangeEquippedItems(Player.Character) then
		return false, "You cannot change equipment right now."
	end

	local Data = DataService:GetData(Player)
	local Item = self:GetRawPlayerItemByName(Player, ItemName)
	local ItemData = ItemService:GetItemData(ItemName)
	local Equipment = self:GetWeaponEquipment(Player)
	if not Item or Item.Stack <= 0 or not ItemData or not InventoryEquipmentSlots.IsWeaponSlot(SlotName)
		or not InventoryEquipmentSlots.Accepts(ItemData, SlotName, Equipment) then
		return false, "This item does not belong in that slot."
	end
	if Unequip and Equipment[SlotName] ~= ItemName then
		return false, "Equipment changed. Try again."
	end
	if not Unequip and Equipment[SlotName] == ItemName then
		return true
	end

	if SlotName == "SecondKatana" then
		if Unequip or ItemName == Equipment.Katana then
			return self:UnequipLeftWeapon(Player)
		else
			return self:EquipUnequipLeftItem(Player, ItemName)
		end
	else
		local Stance = StanceService:GetStance(Data.SelectedStance)
		if not Unequip and SlotName == "Katana" and (not Stance or Stance.WeaponType ~= "Katana") then
			return false, "You cannot equip this weapon in this stance!"
		end

		return self:EquipUnequipItem(Player, ItemName)
	end
end

function InventoryService:GetInventoryLayout(Player: Player): ItemData
	local Layout = InventoryGridService:GetLayout(Player)
	local Data = DataService:GetData(Player)
	Layout.WeaponEquipment = self:GetWeaponEquipment(Player)
	Layout.Equipped = DeepCopy(Data.Equipped)
	Layout.Hotbar = DeepCopy(Data.Hotbar or {})

	return Layout
end

function InventoryService:GetInventory(Player: Player): ({ ItemData }, ItemData)
	local PlayerData = DataService:GetData(Player)
	local Layout = self:GetInventoryLayout(Player)
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
		Item.InHotbar = self:GetItemHotbarIndex(Player, Item.Name) ~= nil
		Item.UsesInventoryGrid = InventoryEquipmentSlots.UsesGrid(Item, PlayerData.Equipped, PlayerData.Hotbar or {})
		Item.InventoryPosition = Layout.Positions[Item.Name]
		Item.Rotated = Item.InventoryPosition and Item.InventoryPosition.Rotated or false

		if Item.Class ~= "Equipable" and Item.Class ~= "Weapon" then
			continue
		end

		if Item.Class == "Weapon" and Item.Type == "Bow" then
			Item.Equipped = PlayerData.Equipped.Bow == Item.Name
			Item.EquippedLeft = false
			Item.CanEquipLeft = false
		elseif Item.Class == "Weapon" then
			Item.Equipped = PlayerData.Equipped.Weapon == Item.Name
			Item.EquippedLeft = Layout.WeaponEquipment.SecondKatana == Item.Name
			Item.DefaultLeft = Item.EquippedLeft and PlayerData.Equipped.LeftWeapon == nil
			Item.CanEquipLeft = StanceData
				and StanceData.DualWield
				and StanceData.WeaponType == Item.Type
				and PlayerData.Equipped.Weapon ~= nil
				and PlayerData.Equipped.Weapon ~= Item.Name
		else
			Item.Equipped = self:IsEquipped(Player, Item.Name)
		end
	end

	return InventoryCopy, Layout
end
function InventoryService.Client:GetInventory(Player: Player): ({ ItemData }, ItemData)
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
	BowService = Knit.GetService("BowService")
	InventoryGridService = Knit.GetService("InventoryGridService")
end

function InventoryService:HandleInventoryAction(Player: Player, Request: any)
	if typeof(Request) ~= "table" or typeof(Request.Id) ~= "number" or Request.Id % 1 ~= 0
		or Request.Id < 1 or Request.Id > 2147483647 or typeof(Request.Name) ~= "string" then
		return
	end

	local Data = DataService:GetData(Player)
	if not Data then
		return
	end

	local Layout = self:GetInventoryLayout(Player)
	local Success, Reason = false, "Inventory changed. Try again."
	if Request.Revision == Layout.Revision then
		if Request.Kind == "Move" then
			Success, Reason = InventoryGridService:Move(Player, Request.Name, Request.Column, Request.Row, Request.Rotated, Request.Revision)
			if Success then
				self.Client.InventoryLayoutUpdated:Fire(Player, self:GetInventoryLayout(Player))
			end
		elseif Request.Kind == "Equip" then
			Success, Reason = self:EquipEquipmentSlot(Player, Request.Slot, Request.Name)
		elseif Request.Kind == "Unequip" then
			Success, Reason = self:UnequipEquipmentSlot(Player, Request.Slot, Request.Name)
		end
	end

	local Correction = if Success then nil else self:GetInventoryLayout(Player)
	self.Client.InventoryActionResult:Fire(Player, Request.Id, Success, Reason, Correction)
end

function InventoryService.KnitStart()
	InventoryService.Client.InventoryAction:Connect(function(Player: Player, Request: any)
		InventoryService:HandleInventoryAction(Player, Request)
	end)
end

return InventoryService
