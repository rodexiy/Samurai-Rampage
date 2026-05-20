local Knit = require(game.ReplicatedStorage.Packages.Knit)

local StanceService = Knit.CreateService({
	Name = "StanceService",
	Client = {
		UpdateUI = Knit.CreateSignal(),
	},
})

local Stances = require(game.ReplicatedStorage.Shared.Index.Stances)

local ValuesService
local AlertService
local WeaponService
local InventoryService
local ItemService

local DataService

function StanceService:UpdateUI(Player: Player)
	local PlayerData = DataService:GetData(Player)

	StanceService.Client.UpdateUI:Fire(Player, self:GetPlayerStances(Player))
end

function StanceService:GetStance(StanceName: string)
	print(Stances)
	return Stances[StanceName]
end

function StanceService:GetPlayerStances(Player: Player)
	local PlayerData = DataService:GetData(Player)

	local Stances = {}
	
	for _, Stance in PlayerData.Stances do
		print(PlayerData.Stances, Stance, self:GetStance(Stance))
		local StanceData = table.clone(self:GetStance(Stance))
		StanceData.Equipped = Stance == PlayerData.SelectedStance
		table.insert(Stances, StanceData)
	end

	return Stances
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

function StanceService:EquipStance(Player: Player, StanceName: string)
	local PlayerData = DataService:GetData(Player)

	if table.find(PlayerData.Stances, StanceName) then
		PlayerData.SelectedStance = StanceName
		local Character = Player.Character

		if Character then
			if Character:GetAttribute("Stance") ~= StanceName then
				Character:SetAttribute("Stance", StanceName)
				if Character:GetAttribute("WeaponEquipped") then
					Character:SetAttribute("AnimationPreset", StanceName)
				end

				local StanceData = self:GetStance(StanceName)
				local CurrentWeaponData = ItemService:GetItemData(Character:GetAttribute("Weapon"))

				if StanceData.WeaponType ~= CurrentWeaponData.Type then
					for _, Item in PlayerData.Inventory do
						local ItemData = ItemService:GetItemData(Item.Name)
						if ItemData.Type == StanceData.WeaponType then
							InventoryService:EquipUnequipItem(Player, Item.Name)
							break
						end
					end
				end

				ValuesService:UpdateAll(Character, false)
			end
		end
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
