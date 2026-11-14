local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local InventoryEquipmentSlots = require(ReplicatedStorage.Shared.Utils.InventoryEquipmentSlots)

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
		AlertService:AlertPlayer(Player, "You unlocked the " .. StanceName .. " Stance.", "Success")
	else
		AlertService:AlertPlayer(Player, "You already have this stance.", "Error")
	end
end

function StanceService:EquipStance(Player: Player, StanceName: string): (boolean?, string?)
	local PlayerData = DataService:GetData(Player)

	if table.find(PlayerData.Stances, StanceName) then
		local DidChangeStance = PlayerData.SelectedStance ~= StanceName
		local PreviousWeapon = PlayerData.Equipped.Weapon
		local StanceData = self:GetStance(StanceName)
		if DidChangeStance then
			local NextEquipped = InventoryEquipmentSlots.WithSlot(PlayerData.Equipped, "LeftWeapon", nil)
			local CurrentWeaponData = ItemService:GetItemData(PreviousWeapon)
			if not CurrentWeaponData or CurrentWeaponData.Type ~= StanceData.WeaponType then
				NextEquipped.Weapon = nil
				for _, Item in PlayerData.Inventory do
					local ItemData = ItemService:GetItemData(Item.Name)
					if Item.Stack > 0 and ItemData and ItemData.Class == "Weapon" and ItemData.Type == StanceData.WeaponType then
						NextEquipped.Weapon = Item.Name
						break
					end
				end
			end

			local Success, Reason = InventoryService:CommitEquipment(Player, NextEquipped, NextEquipped.Weapon)
			if not Success then
				return false, Reason
			end
		end

		PlayerData.SelectedStance = StanceName
		local Character = Player.Character

		if Character then
			if Character:GetAttribute("Stance") ~= StanceName then
				Character:SetAttribute("Stance", StanceName)
				if Character:GetAttribute("WeaponEquipped") then
					Character:SetAttribute("AnimationPreset", StanceName)
				end

				if PreviousWeapon ~= PlayerData.Equipped.Weapon then
					if Character:GetAttribute("WeaponEquipped") then
						WeaponService:Equip(Character, false, 1.5)
					end
					Character:SetAttribute("Weapon", PlayerData.Equipped.Weapon)
					if PlayerData.Equipped.Weapon then
						WeaponService:LoadWeapon(Character, PlayerData.Equipped.Weapon, PlayerData.Equipped.LeftWeapon, StanceName)
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

		if DidChangeStance then
			InventoryService:UpdateUI(Player)
		end

		return true
	end
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
