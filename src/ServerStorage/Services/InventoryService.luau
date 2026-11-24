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
local InventoryChanged = Instance.new("BindableEvent")
InventoryService.Changed = InventoryChanged.Event

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
local FloorDropService
local InventoryStackService

local DeepCopy = require(ReplicatedStorage.Shared.Utils.DeepCopy)
local InventoryEquipmentSlots = require(ReplicatedStorage.Shared.Utils.InventoryEquipmentSlots)
local InventoryHotbarSlots = require(ReplicatedStorage.Shared.Utils.InventoryHotbarSlots)
local InventoryDeletion = require(ReplicatedStorage.Shared.Utils.InventoryDeletion)
local InventoryDropping = require(ReplicatedStorage.Shared.Utils.InventoryDropping)
local InventoryStacks = require(ReplicatedStorage.Shared.Utils.InventoryStacks)

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
	local PlayerData = InventoryStackService:GetData(Player)
	local InventoryData = {}
	for _, Item in PlayerData.Inventory do
		table.insert(InventoryData, ItemService:ImplementData(Item))
	end

	return InventoryData
end

function InventoryService:RemoveUnavailableItems(Player: Player)
	local Data = DataService:GetData(Player)
	if not Data then
		return
	end

	for Index = #Data.Inventory, 1, -1 do
		if not ItemService:GetItemData(Data.Inventory[Index].Name) then
			table.remove(Data.Inventory, Index)
		end
	end
	for _, Assignments in { Data.Hotbar, Data.Equipped } do
		for Slot, Name in Assignments do
			if not ItemService:GetItemData(Name) then
				Assignments[Slot] = nil
			end
		end
	end
	if Data.Backpack and Data.Backpack.Positions then
		InventoryStackService:Normalize(Data)
		local Changed = false
		for Name in Data.Backpack.Positions do
			if not InventoryStacks.Find(Data.Inventory, Name) then
				Data.Backpack.Positions[Name] = nil
				Changed = true
			end
		end
		if Changed then
			Data.Backpack.Revision = (Data.Backpack.Revision or 0) + 1
		end
	end

	StanceService:ValidateSelectedStance(Player)
end

function InventoryService:UpdateUI(Player: Player, HotbarToo: boolean)
	local Entries, Snapshot = self:GetInventory(Player)
	if HotbarToo then
		InventoryService.Client.HotbarUpdated:Fire(Player)
	end
	InventoryService.Client.InventoryUpdated:Fire(Player, Entries, Snapshot)
	InventoryChanged:Fire(Player)
end

function InventoryService:GetPlayerItemByName(Player: Player, ItemName: string): { any }
	local Item = self:GetRawPlayerItemByName(Player, ItemName)
	if Item then
		local Result = ItemService:ImplementData(Item)
		Result.Stack = InventoryStacks.Count(DataService:GetData(Player).Inventory, ItemName)
		return Result
	end
end

function InventoryService:GetRawPlayerStack(Player: Player, Id: string): ItemData?
	local Data = InventoryStackService:GetData(Player)
	return Data and InventoryStacks.Find(Data.Inventory, Id)
end

function InventoryService:GetPlayerStack(Player: Player, Id: string): ItemData?
	local Raw = self:GetRawPlayerStack(Player, Id)
	return Raw and ItemService:ImplementData(Raw)
end

function InventoryService:GetRawPlayerItemByName(Player: Player, ItemName: string): { any }
	local PlayerData = DataService:GetData(Player)
	for _, Item in PlayerData.Inventory do
		if Item.Name == ItemName then
			return Item
		end
	end
end

function InventoryService:CanReceiveItem(Player: Player, Item: ItemData): boolean
	return InventoryGridService:CanAdd(Player, Item)
end

function InventoryService:GiveItemToPlayer(Player: Player, Item: { any }): number
	local PlayerData = InventoryStackService:GetData(Player)
	local Layout = InventoryGridService:GetLayout(Player)
	local AmountToAdd, Updates, NewItems, Positions = InventoryStackService:PlanAdd(PlayerData, Item, Layout)
	if AmountToAdd <= 0 then
		return 0
	end
	local HotbarChanged = false
	for _, Owned in PlayerData.Inventory do
		local Id = InventoryStacks.Key(Owned)
		if Updates[Id] then
			Owned.Stack = Updates[Id]
			local Tool = ToolService:GetToolFromPlayer(Player, Owned.Name, Id)
			if Tool then
				ToolService:CopyAttributesToTool(Tool, ItemService:ImplementData(Owned))
				HotbarChanged = true
			end
		end
	end
	for _, NewItem in NewItems do
		table.insert(PlayerData.Inventory, NewItem)
	end
	if #NewItems > 0 then
		PlayerData.Backpack.Positions = Positions
		PlayerData.Backpack.Revision += 1
	end

	InventoryService.Client.ItemAdded:Fire(Player, Item.DisplayName or Item.Name, AmountToAdd)
	InventoryService:UpdateUI(Player, HotbarChanged)

	return AmountToAdd
end

function InventoryService:RemoveItemFromHotbarByName(Player: Player, ItemName: string)
	local PlayerData = InventoryStackService:GetData(Player)
	local Item = InventoryStacks.Find(PlayerData.Inventory, ItemName)
	local Name = if Item then Item.Name else ItemName
	ToolService:RemoveToolFromPlayer(Player, Name, ItemName)
	local Removed = false
	for index, Id in InventoryStacks.Assignments(PlayerData, "Hotbar") do
		if Id == ItemName then
			PlayerData.Hotbar[index] = nil
			PlayerData.HotbarStackIds[index] = nil
			Removed = true
		end
	end
	return Removed
end

function InventoryService:GetItemHotbarIndex(Player: Player, ItemName: string)
	local PlayerData = InventoryStackService:GetData(Player)
	for index, Name in InventoryStacks.Assignments(PlayerData, "Hotbar") do
		if Name == ItemName then
			return index
		end
	end
end

function InventoryService:RemoveItemFromHotbar(Player: Player, Index: number, update: boolean)
	if not InventoryHotbarSlots.IsValidIndex(Index) then
		return
	end

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
			if not InventoryGridService:CanAdd(Player, { Name = ArtifactName, Stack = 1 }) then
				AlertService:AlertPlayer(Player, "Not enough backpack space.", "Warn")
				return
			end

			ToolService:RemoveToolFromPlayer(Player, ArtifactName)

			local ArtifactItem = ItemService:CreateItem(ArtifactName, 1)
			self:GiveItemToPlayer(Player, ArtifactItem)
			update = false
		end
	else
		local ItemName = InventoryStacks.Assignments(PlayerData, "Hotbar")[tostring(Index)]
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

function InventoryService:EquipToHotbar(Player: Player, ItemName: string, Index: number): (boolean, string?)
	if typeof(ItemName) ~= "string" or not InventoryHotbarSlots.IsValidIndex(Index) then
		return false, "Invalid hotbar slot."
	end

	local PlayerData = InventoryStackService:GetData(Player)
	local OwnedItem = self:GetPlayerStack(Player, ItemName)
	local ItemData = OwnedItem and ItemService:GetItemData(OwnedItem.Name)
	if not PlayerData or not InventoryHotbarSlots.Accepts(ItemData) then
		return false, "This item cannot be equipped to the hotbar."
	end

	if not OwnedItem or (OwnedItem.Stack and OwnedItem.Stack <= 0) then
		return false, "You do not own this item."
	end

	local ToolInIndex = self:GetToolInHotbarIndex(Player, Index)
	if ToolInIndex and ToolInIndex:GetAttribute("Class") == "Artifact" then
		AlertService:AlertPlayer(Player, "You have a artifact in this slot!", "Warn")
		return false, "There is an artifact in this slot."
	end
	self:RemoveItemFromHotbar(Player, Index)
	PlayerData.Hotbar[tostring(Index)] = nil
	PlayerData.HotbarStackIds[tostring(Index)] = nil

	local updateUI = true
	if ItemData.Class == "Artifact" then
		updateUI = false
		InventoryService:RemoveItemFromPlayer(Player, OwnedItem.Name, 1, true, ItemName)
	else
		self:RemoveItemFromHotbarByName(Player, ItemName)
		PlayerData.Hotbar[tostring(Index)] = OwnedItem.Name
		PlayerData.HotbarStackIds[tostring(Index)] = ItemName
	end

	ToolService:GiveToolToPlayer(Player, OwnedItem.Name, Index, true, ItemName)

	if updateUI then
		InventoryService:UpdateUI(Player, true)
	end

	return true
end
function InventoryService.Client:EquipToHotbar(Player: Player, ItemName: string, Index: number)
	self.Server:EquipToHotbar(Player, ItemName, Index)
end

function InventoryService:MoveHotbarSlot(
	Player: Player,
	SourceIndex: number,
	Index: number,
	ItemName: string
): (boolean, string?)
	if not InventoryHotbarSlots.IsValidIndex(SourceIndex) or not InventoryHotbarSlots.IsValidIndex(Index) then
		return false, "Invalid hotbar slot."
	end

	local Data = DataService:GetData(Player)
	local Source = self:GetToolInHotbarIndex(Player, SourceIndex)
	if not Data or not Source or (Source:GetAttribute("Id") or Source.Name) ~= ItemName then
		return false, "The hotbar item changed. Try again."
	end
	if SourceIndex == Index then
		return true
	end

	local Target = self:GetToolInHotbarIndex(Player, Index)
	Data.Hotbar[tostring(Index)] = if Source:GetAttribute("Class") ~= "Artifact" then Source.Name else nil
	Data.Hotbar[tostring(SourceIndex)] = if Target and Target:GetAttribute("Class") ~= "Artifact"
		then Target.Name
		else nil
	Data.HotbarStackIds = Data.HotbarStackIds or {}
	Data.HotbarStackIds[tostring(Index)] = if Data.Hotbar[tostring(Index)]
		then Source:GetAttribute("Id") or Source.Name
		else nil
	Data.HotbarStackIds[tostring(SourceIndex)] = if Data.Hotbar[tostring(SourceIndex)]
		then Target:GetAttribute("Id") or Target.Name
		else nil
	Source:SetAttribute("HotbarIndex", Index)
	if Target then
		Target:SetAttribute("HotbarIndex", SourceIndex)
	end

	self:UpdateUI(Player, true)
	return true
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
	_Amount: (number | string)?,
	dontRemoveFromHotbar: boolean?,
	StackId: string?
)
	local Data = InventoryStackService:GetData(Player)
	local Remaining = if _Amount == "all" then InventoryStacks.Count(Data.Inventory, ItemName) else (_Amount or 1)
	if typeof(Remaining) ~= "number" or Remaining < 1 or Remaining >= math.huge or Remaining % 1 ~= 0 then
		return
	end

	for Index = #Data.Inventory, 1, -1 do
		local Item = Data.Inventory[Index]
		local Id = InventoryStacks.Key(Item)
		if Item.Name ~= ItemName or (StackId and Id ~= StackId) then
			continue
		end
		local Removed = math.min(Item.Stack, Remaining)
		Item.Stack -= Removed
		Remaining -= Removed
		if Item.Stack == 0 then
			if InventoryStacks.Assignments(Data, "Equipped").Bow == Id then
				BowService:UnequipItem(Player)
			end
			local Equipped = InventoryStacks.Assignments(Data, "Equipped")
			for _, Slot in { "Weapon", "LeftWeapon" } do
				if Equipped[Slot] == Id then
					Data.Equipped[Slot] = nil
					Data.EquippedStackIds[Slot] = nil
				end
			end

			if not dontRemoveFromHotbar then
				self:RemoveItemFromHotbarByName(Player, Id)
			end
			table.remove(Data.Inventory, Index)
		else
			local Tool = ToolService:GetToolFromPlayer(Player, ItemName, Id)
			if Tool then
				ToolService:CopyAttributesToTool(Tool, ItemService:ImplementData(Item))
			end
		end
		if Remaining == 0 then
			break
		end
	end

	StanceService:ValidateSelectedStance(Player)
	self:UpdateUI(Player, true)
end

function InventoryService:MergeStacks(
	Player: Player,
	SourceId: string,
	TargetId: string,
	ExpectedSource: number,
	ExpectedTarget: number
): (boolean, string?)
	local Data = InventoryStackService:GetData(Player)
	if not Data then
		return false, "Inventory is not ready."
	end
	local Source, Target, Amount, Reason =
		InventoryStackService:PlanMerge(Data, SourceId, TargetId, ExpectedSource, ExpectedTarget)
	if not Source or not Target then
		return false, Reason
	end

	Target.Stack += Amount
	local Tool = ToolService:GetToolFromPlayer(Player, Target.Name, TargetId)
	if Tool then
		ToolService:CopyAttributesToTool(Tool, ItemService:ImplementData(Target))
	end
	local Layout = InventoryGridService:GetLayout(Player)
	Data.Backpack.Revision = Layout.Revision + 1
	self:RemoveItemFromPlayer(Player, Source.Name, Amount, false, SourceId)
	return true
end

function InventoryService:ConsumeToolItem(Player: Player, Name: string, Amount: number)
	local Tool = Player.Character and Player.Character:FindFirstChildWhichIsA("Tool")
	local Id = Tool and Tool.Name == Name and Tool:GetAttribute("Id") or nil
	self:RemoveItemFromPlayer(Player, Name, Amount, false, Id)
end

function InventoryService:DeleteItem(Player: Player, ItemName: string, ExpectedStack: number): (boolean, string?)
	if typeof(ItemName) ~= "string" or typeof(ExpectedStack) ~= "number" then
		return false, "Invalid item deletion."
	end
	local Data = DataService:GetData(Player)
	local Raw = Data and self:GetRawPlayerStack(Player, ItemName)
	local Item = Raw and ItemService:ImplementData(Raw)
	if not InventoryDeletion.CanDelete(Item) or self:IsEquipped(Player, ItemName) then
		return false, "This item cannot be deleted."
	end
	if Raw.Stack ~= ExpectedStack then
		return false, "The item quantity changed. Try again."
	end

	self:RemoveItemFromPlayer(Player, Raw.Name, ExpectedStack, false, ItemName)
	return true
end

function InventoryService:DropItem(
	Player: Player,
	ItemName: string,
	Amount: number,
	ExpectedStack: number
): (boolean, string?)
	if typeof(ItemName) ~= "string" or typeof(ExpectedStack) ~= "number" then
		return false, "Invalid item drop."
	end
	local Data = DataService:GetData(Player)
	local Raw = Data and self:GetRawPlayerStack(Player, ItemName)
	local Item = Raw and ItemService:ImplementData(Raw)
	if not InventoryDropping.CanDrop(Item) or self:IsEquipped(Player, ItemName) then
		return false, "This item cannot be dropped."
	end
	if Raw.Stack ~= ExpectedStack or not InventoryDropping.IsValidAmount(Amount, Raw.Stack) then
		return false, "The item quantity changed. Try again."
	end
	local Character = Player.Character
	local Root = Character and Character.PrimaryPart
	local Humanoid = Character and Character:FindFirstChildWhichIsA("Humanoid")
	if not Root or not Humanoid or Humanoid.Health <= 0 then
		return false, "You cannot drop items right now."
	end

	local Position = Root.Position + Root.CFrame.LookVector * 4
	if not FloorDropService:DropInventoryItem(Raw, Amount, Position) then
		return false, "The item could not be dropped."
	end
	self:RemoveItemFromPlayer(Player, Raw.Name, Amount, false, ItemName)
	return true
end

function InventoryService:IsEquipped(Player: Player, ItemName: string)
	local PlayerData = DataService:GetData(Player)

	InventoryStackService:Normalize(PlayerData)
	for _, Equipped in InventoryStacks.Assignments(PlayerData, "Equipped") do
		if Equipped == ItemName then
			return true
		end
	end

	return false
end

function InventoryService:CommitEquipment(
	Player: Player,
	NextEquipped: { [string]: string },
	PreferredName: string?
): (boolean, string?)
	local Success, Reason = InventoryGridService:SetEquippedItems(Player, NextEquipped, PreferredName)
	if not Success then
		AlertService:AlertPlayer(Player, Reason, "Warn")
	end

	return Success, Reason
end

function InventoryService:EquipUnequipItem(Player: Player, ItemName: string): (boolean, string?)
	local PlayerData = InventoryStackService:GetData(Player)
	local ItemId = ItemName
	local Item = self:GetRawPlayerStack(Player, ItemId)
	local ItemData = Item and ItemService:GetItemData(Item.Name)

	if not ItemData then
		return false, "This item is not in your inventory."
	end

	local Character = Player.Character

	if not CanChangeEquippedItems(Character) then
		return false, "You cannot change equipment right now."
	end

	if ItemData.Class == "Equipable" then
		if InventoryStacks.Assignments(PlayerData, "Equipped")[ItemData.Type] == ItemId then
			return self:UnequipEquipmentSlot(Player, ItemData.Type, ItemName)
		end

		return self:EquipEquipmentSlot(Player, ItemData.Type, ItemName)
	end

	if ItemData.Class ~= "Weapon" or not Item or Item.Stack <= 0 then
		return false, "This weapon is not in your inventory."
	end

	local Ranged = ItemData.Type == "Bow"
	local Equipped = InventoryStacks.Assignments(PlayerData, "Equipped")
	local WasEquipped = (if Ranged then Equipped.Bow else Equipped.Weapon) == ItemId
	local StanceData = StanceService:GetStance(PlayerData.SelectedStance)
	if not Ranged and WasEquipped and StanceData and StanceData.DualWield then
		local NextEquipped = table.clone(Equipped)
		NextEquipped.Weapon = Equipped.LeftWeapon
		return StanceService:ExitDualWield(Player, NextEquipped)
	end
	if not Ranged and Equipped.LeftWeapon == ItemId then
		return false, "This weapon is already in your left hand."
	end

	if not Ranged and not WasEquipped then
		if not StanceData or StanceData.WeaponType ~= ItemData.Type then
			AlertService:AlertPlayer(Player, "You cannot equip this weapon in this stance!", "Warn")
			return false, "You cannot equip this weapon in this stance!"
		end
	end

	local NextEquipped = InventoryEquipmentSlots.WithSlot(
		Equipped,
		if Ranged then "Bow" else "Weapon",
		if WasEquipped then nil else ItemName
	)
	local Success, Reason = self:CommitEquipment(Player, NextEquipped, if WasEquipped then nil else ItemName)
	if not Success then
		return false, Reason
	end
	ItemName = Item.Name

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

	StanceService:ValidateSelectedStance(Player)
	self:UpdateUI(Player)
	return true
end
function InventoryService.Client:EquipUnequipItem(Player: Player, ItemName: string)
	if Player:GetAttribute("InIntroCutscene") then
		return
	end

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
		local Item = self:GetRawPlayerStack(Player, ItemName)
		EquipmentService:LoadEquipment(Character, SlotName, Item.Name)
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

function InventoryService:UnequipLeftWeapon(
	Player: Player,
	UpdateUI: boolean?
): (boolean, string?)
	local PlayerData = DataService:GetData(Player)
	local NextEquipped =
		InventoryEquipmentSlots.WithSlot(InventoryStacks.Assignments(PlayerData, "Equipped"), "LeftWeapon", nil)
	local StanceData = StanceService:GetStance(PlayerData.SelectedStance)
	if StanceData and StanceData.DualWield then
		return StanceService:ExitDualWield(Player, NextEquipped)
	end

	local Success, Reason = self:CommitEquipment(Player, NextEquipped)
	if not Success then
		return false, Reason
	end

	local Character = Player.Character
	if Character then
		WeaponService:UnloadLeftWeapon(Character)
		ValuesService:UpdateDamage(Character)
	end

	if UpdateUI ~= false then
		self:UpdateUI(Player)
	end

	return true
end

function InventoryService:EquipUnequipLeftItem(Player: Player, ItemName: string): (boolean, string?)
	local PlayerData = InventoryStackService:GetData(Player)
	local ItemId = ItemName
	local Item = self:GetRawPlayerStack(Player, ItemId)
	local ItemData = Item and ItemService:GetItemData(Item.Name)
	local Equipped = InventoryStacks.Assignments(PlayerData, "Equipped")

	if not ItemData or ItemData.Class ~= "Weapon" or ItemData.Type == "Bow" then
		return false, "This item is not a melee weapon."
	end

	local Character = Player.Character
	if not CanChangeEquippedItems(Character) then
		return false, "You cannot change equipment right now."
	end

	if Equipped.LeftWeapon == ItemId then
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

	if Equipped.Weapon == ItemId then
		AlertService:AlertPlayer(Player, "This weapon is already in your right hand.", "Warn")
		return false, "This weapon is already in your right hand."
	end

	if not Item or Item.Stack <= 0 then
		return false, "This weapon is not in your inventory."
	end

	local NextEquipped = InventoryEquipmentSlots.WithSlot(Equipped, "LeftWeapon", ItemId)
	local Success, Reason = self:CommitEquipment(Player, NextEquipped, ItemName)
	if not Success then
		return false, Reason
	end

	if Character then
		Character:SetAttribute("LeftWeapon", Item.Name)
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
	return InventoryEquipmentSlots.Resolve(
		InventoryStacks.Assignments(Data, "Equipped"),
		StanceService:GetStance(Data.SelectedStance),
		ItemService:GetItemData(Data.Equipped.Weapon)
	)
end

function InventoryService:SetWeaponEquipmentSlot(
	Player: Player,
	SlotName: string,
	ItemName: string,
	Unequip: boolean?
): (boolean, string?)
	if not CanChangeEquippedItems(Player.Character) then
		return false, "You cannot change equipment right now."
	end

	local Data = DataService:GetData(Player)
	local Item = self:GetRawPlayerStack(Player, ItemName)
	local ItemData = Item and ItemService:GetItemData(Item.Name)
	local Equipment = self:GetWeaponEquipment(Player)
	if
		not Item
		or Item.Stack <= 0
		or not ItemData
		or not InventoryEquipmentSlots.IsWeaponSlot(SlotName)
		or not InventoryEquipmentSlots.Accepts(ItemService:ImplementData(Item), SlotName, Equipment)
	then
		return false, "This item does not belong in that slot."
	end
	if Unequip and Equipment[SlotName] ~= ItemName then
		return false, "Equipment changed. Try again."
	end
	if not Unequip and Equipment[SlotName] == ItemName then
		return true
	end

	if SlotName == "SecondKatana" then
		if Unequip then
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

function InventoryService:SetBackpackTier(Player: Player, Tier: any): (boolean, string?)
	local Success, Reason = InventoryGridService:SetBackpackTier(Player, Tier)
	if not Success then
		return false, Reason
	end

	self.Client.InventoryLayoutUpdated:Fire(Player, self:GetInventoryLayout(Player))

	return true
end

function InventoryService:GetInventoryLayout(Player: Player): ItemData
	local Layout = InventoryGridService:GetLayout(Player)
	local Data = DataService:GetData(Player)
	Layout.WeaponEquipment = self:GetWeaponEquipment(Player)
	Layout.Equipped = InventoryStacks.Assignments(Data, "Equipped")
	Layout.Hotbar = InventoryStacks.Assignments(Data, "Hotbar")

	return Layout
end

function InventoryService:GetInventory(Player: Player): ({ ItemData }, ItemData)
	local PlayerData = DataService:GetData(Player)
	local Layout = self:GetInventoryLayout(Player)
	local InventoryCopy = DeepCopy(PlayerData.Inventory)
	local StanceData = StanceService:GetStance(PlayerData.SelectedStance)
	local HotbarItems = {}
	for _, Id in Layout.Hotbar do
		HotbarItems[Id] = true
	end

	for _, Item in InventoryCopy do
		local Id = InventoryStacks.Key(Item)
		local ItemData = ItemService:GetItemData(Item.Name)
		Item.StackData = InventoryStacks.Metadata(Item)
		Item.Description = ItemData.Description
		Item.Rarity = ItemData.Rarity
		Item.DisplayName = ItemData.DisplayName
		Item.Type = ItemData.Type
		Item.Class = ItemData.Class
		Item.Hidden = ItemData.Hidden
		Item.InHotbar = HotbarItems[Id] == true
		Item.UsesInventoryGrid = InventoryEquipmentSlots.UsesGrid(Item, Layout.Equipped, Layout.Hotbar)
		Item.InventoryPosition = Layout.Positions[Id]
		Item.Rotated = Item.InventoryPosition and Item.InventoryPosition.Rotated or false

		if Item.Class ~= "Equipable" and Item.Class ~= "Weapon" then
			continue
		end

		if Item.Class == "Weapon" and Item.Type == "Bow" then
			Item.Equipped = Layout.Equipped.Bow == Id
			Item.EquippedLeft = false
			Item.CanEquipLeft = false
		elseif Item.Class == "Weapon" then
			Item.Equipped = Layout.Equipped.Weapon == Id
			Item.EquippedLeft = Layout.WeaponEquipment.SecondKatana == Id
			Item.DefaultLeft = false
			Item.CanEquipLeft = StanceData
				and StanceData.DualWield
				and StanceData.WeaponType == Item.Type
				and PlayerData.Equipped.Weapon ~= nil
				and Layout.Equipped.Weapon ~= Id
		else
			Item.Equipped = Layout.Equipped[Item.Type] == Id
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
	FloorDropService = Knit.GetService("FloorDropService")
	InventoryStackService = Knit.GetService("InventoryStackService")
end

function InventoryService:HandleInventoryAction(Player: Player, Request: any)
	if
		typeof(Request) ~= "table"
		or typeof(Request.Id) ~= "number"
		or Request.Id % 1 ~= 0
		or Request.Id < 1
		or Request.Id > 2147483647
		or typeof(Request.Name) ~= "string"
	then
		return
	end

	local Data = DataService:GetData(Player)
	if not Data then
		return
	end

	local Layout = self:GetInventoryLayout(Player)
	local Success, Reason = false, "Inventory changed. Try again."
	if Player:GetAttribute("InIntroCutscene")
		and (Request.Kind == "Equip" or Request.Kind == "Unequip")
		and InventoryEquipmentSlots.IsWeaponSlot(Request.Slot) then
		Reason = "You cannot change weapons during the introduction."
	elseif Request.Kind == "MoveHotbar" then
		Success, Reason = self:MoveHotbarSlot(Player, Request.SourceIndex, Request.Index, Request.Name)
	elseif Request.Revision == Layout.Revision then
		if Request.Kind == "Move" then
			Success, Reason = InventoryGridService:Move(
				Player,
				Request.Name,
				Request.Column,
				Request.Row,
				Request.Rotated,
				Request.Revision
			)
			if Success then
				self.Client.InventoryLayoutUpdated:Fire(Player, self:GetInventoryLayout(Player))
			end
		elseif Request.Kind == "Merge" then
			Success, Reason = self:MergeStacks(Player, Request.Name, Request.Target, Request.Stack, Request.TargetStack)
		elseif Request.Kind == "Equip" then
			Success, Reason = self:EquipEquipmentSlot(Player, Request.Slot, Request.Name)
		elseif Request.Kind == "Unequip" then
			Success, Reason = self:UnequipEquipmentSlot(Player, Request.Slot, Request.Name)
		elseif Request.Kind == "Hotbar" then
			Success, Reason = self:EquipToHotbar(Player, Request.Name, Request.Index)
		elseif Request.Kind == "Delete" then
			Success, Reason = self:DeleteItem(Player, Request.Name, Request.Stack)
		elseif Request.Kind == "Drop" then
			Success, Reason = self:DropItem(Player, Request.Name, Request.Amount, Request.Stack)
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
