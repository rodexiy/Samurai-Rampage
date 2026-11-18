local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local InventoryEquipmentSlots = require(ReplicatedStorage.Shared.Utils.InventoryEquipmentSlots)
local InventoryStacks = require(ReplicatedStorage.Shared.Utils.InventoryStacks)

local StanceService = Knit.CreateService({
	Name = "StanceService",
	Client = {
		UpdateUI = Knit.CreateSignal(),
	},
})

local Stances = require(ReplicatedStorage.Shared.Index.Stances)

local ValuesService
local AlertService
local WeaponService
local InventoryService
local ItemService

local DataService

type ItemData = { [string]: any }

local function IsCompatibleWeapon(Item: ItemData?, WeaponType: string): boolean
	local Definition = Item and ItemService:GetItemData(Item.Name)
	return Item ~= nil and Item.Stack > 0 and Definition ~= nil
		and Definition.Class == "Weapon" and Definition.Type == WeaponType
end

local function FindWeapon(
	Inventory: { ItemData },
	WeaponType: string,
	Preferred: string?,
	Excluded: string?
): string?
	if Preferred and Preferred ~= Excluded and IsCompatibleWeapon(InventoryStacks.Find(Inventory, Preferred), WeaponType) then
		return Preferred
	end

	for _, Item in Inventory do
		local Id = InventoryStacks.Key(Item)
		if Id ~= Excluded and IsCompatibleWeapon(Item, WeaponType) then
			return Id
		end
	end

	return nil
end

function StanceService:UpdateUI(Player: Player)
	StanceService.Client.UpdateUI:Fire(Player, self:GetPlayerStances(Player))
end

function StanceService:GetStance(StanceName: string)
	return Stances[StanceName]
end

function StanceService:GetPlayerStances(Player: Player)
	local PlayerData = DataService:GetData(Player)

	local PlayerStances = {}

	for _, Stance in PlayerData.Stances do
		local StanceData = table.clone(self:GetStance(Stance))
		StanceData.Equipped = Stance == PlayerData.SelectedStance
		table.insert(PlayerStances, StanceData)
	end

	return PlayerStances
end
function StanceService.Client:GetPlayerStances(Player: Player)
	return self.Server:GetPlayerStances(Player)
end

function StanceService:GiveStance(Player: Player, StanceName: string)
	local PlayerData = DataService:GetData(Player)
	if not table.find(PlayerData.Stances, StanceName) then
		table.insert(PlayerData.Stances, StanceName)
		self:UpdateUI(Player)
		AlertService:AlertPlayer(Player, "You unlocked the " .. StanceName .. " Stance.", "Success")
	else
		AlertService:AlertPlayer(Player, "You already have this stance.", "Error")
	end
end

local function ApplyStance(
	Player: Player,
	StanceName: string,
	EquippedOverride: { [string]: string }?
): (boolean, string?)
	local PlayerData = DataService:GetData(Player)

	local DidChangeStance = PlayerData.SelectedStance ~= StanceName
	local PreviousWeapon = PlayerData.Equipped.Weapon
	local StanceData = StanceService:GetStance(StanceName)
	local DidChangeEquipment = false
	if DidChangeStance or StanceData.DualWield or EquippedOverride then
		local Equipped = InventoryService:GetInventoryLayout(Player).Equipped
		local NextEquipped = table.clone(EquippedOverride or Equipped)
		if not EquippedOverride then
			NextEquipped.Weapon = FindWeapon(PlayerData.Inventory, StanceData.WeaponType, Equipped.Weapon, nil)
			if StanceData.DualWield then
				NextEquipped.LeftWeapon = FindWeapon(
					PlayerData.Inventory,
					StanceData.WeaponType,
					Equipped.LeftWeapon,
					NextEquipped.Weapon
				)
				if not NextEquipped.Weapon or not NextEquipped.LeftWeapon then
					return false, "You need two separate katanas to use this stance."
				end
			end
		end
		if not StanceData.DualWield then
			NextEquipped.LeftWeapon = nil
		end

		local Success, Reason = InventoryService:CommitEquipment(Player, NextEquipped, NextEquipped.Weapon)
		if not Success then
			return false, Reason
		end
		DidChangeEquipment = Equipped.Weapon ~= NextEquipped.Weapon or Equipped.LeftWeapon ~= NextEquipped.LeftWeapon
	end

	PlayerData.SelectedStance = StanceName
	local Character = Player.Character

	if Character then
		if Character:GetAttribute("Stance") ~= StanceName or DidChangeEquipment then
			Character:SetAttribute("Stance", StanceName)
			if Character:GetAttribute("WeaponEquipped") then
				Character:SetAttribute("AnimationPreset", StanceName)
			end

			if PreviousWeapon ~= PlayerData.Equipped.Weapon or Character:GetAttribute("Weapon") ~= PlayerData.Equipped.Weapon then
				if Character:GetAttribute("WeaponEquipped") then
					WeaponService:Equip(Character, false, 1.5)
				end
				Character:SetAttribute("Weapon", PlayerData.Equipped.Weapon)
				if PlayerData.Equipped.Weapon then
					WeaponService:LoadWeapon(
						Character,
						PlayerData.Equipped.Weapon,
						PlayerData.Equipped.LeftWeapon,
						StanceName
					)
				else
					WeaponService:UnloadWeapon(Character)
				end
			end

			if StanceData.DualWield then
				WeaponService:LoadLeftWeapon(
					Character,
					PlayerData.Equipped.LeftWeapon,
					PlayerData.Equipped.Weapon,
					PlayerData.SelectedStance
				)
			else
				WeaponService:UnloadLeftWeapon(Character)
			end

			ValuesService:UpdateAll(Character, false)
		end
	end

	if DidChangeStance or DidChangeEquipment then
		InventoryService:UpdateUI(Player)
	end
	StanceService:UpdateUI(Player)

	return true
end

function StanceService:HasRequiredWeapons(Player: Player, StanceName: string): boolean
	local StanceData = self:GetStance(StanceName)
	if not StanceData then
		return false
	end
	if not StanceData.DualWield then
		return true
	end

	local PlayerData = DataService:GetData(Player)
	if not PlayerData then
		return false
	end

	local Count = 0
	for _, Item in PlayerData.Inventory do
		if IsCompatibleWeapon(Item, StanceData.WeaponType) then
			Count += Item.Stack
			if Count >= 2 then
				return true
			end
		end
	end

	return false
end

function StanceService:ValidateSelectedStance(Player: Player)
	local PlayerData = DataService:GetData(Player)
	local StanceName = PlayerData and PlayerData.SelectedStance
	local StanceData = StanceName and self:GetStance(StanceName)
	if not StanceData or not StanceData.DualWield then
		return
	end

	local Equipped = InventoryStacks.Assignments(PlayerData, "Equipped")
	local Main = Equipped.Weapon and InventoryStacks.Find(PlayerData.Inventory, Equipped.Weapon)
	local Left = Equipped.LeftWeapon and InventoryStacks.Find(PlayerData.Inventory, Equipped.LeftWeapon)
	local HasMain = IsCompatibleWeapon(Main, StanceData.WeaponType)
	local HasLeft = IsCompatibleWeapon(Left, StanceData.WeaponType)
	if HasMain and HasLeft and Equipped.Weapon ~= Equipped.LeftWeapon then
		return
	end

	Equipped.Weapon = if HasMain then Equipped.Weapon elseif HasLeft then Equipped.LeftWeapon else nil
	self:ExitDualWield(Player, Equipped)
end

function StanceService:ExitDualWield(Player: Player, Equipped: { [string]: string }): (boolean, string?)
	return ApplyStance(Player, "Beginner", InventoryEquipmentSlots.WithSlot(Equipped, "LeftWeapon", nil))
end

function StanceService:EquipStance(Player: Player, StanceName: string): (boolean?, string?)
	local PlayerData = DataService:GetData(Player)
	if not PlayerData or not table.find(PlayerData.Stances, StanceName) then
		return
	end
	if not self:HasRequiredWeapons(Player, StanceName) then
		local Reason = "You need at least two katanas in your inventory to use this stance."
		AlertService:AlertPlayer(Player, Reason, "Warn")
		return false, Reason
	end

	return ApplyStance(Player, StanceName)
end
function StanceService.Client:EquipStance(Player: Player, StanceName: string)
	self.Server:EquipStance(Player, StanceName)
end

function StanceService.KnitInit()
	DataService = Knit.GetService("DataService")
	ValuesService = Knit.GetService("ValuesService")
	AlertService = Knit.GetService("AlertService")
	WeaponService = Knit.GetService("WeaponService")
	InventoryService = Knit.GetService("InventoryService")
	ItemService = Knit.GetService("ItemService")
end

function StanceService.KnitStart() end

return StanceService
