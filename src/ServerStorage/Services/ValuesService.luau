local Players = game:GetService("Players")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local ValuesService = Knit.CreateService({
	Name = "ValuesService",
	Client = {},
})

local DataService
local ItemService
local StanceService
local RaceService
local SkillTreeService

local CharacterShared = require(game.ReplicatedStorage.Shared.CharacterShared)

function ValuesService:UpdateAll(Character: Model, SetToMax: boolean)
	if not Character then
		return
	end

	ValuesService:UpdateDamage(Character)
	ValuesService:UpdateMaxHealth(Character, SetToMax)
	ValuesService:UpdateMaxPosture(Character)
	ValuesService:UpdateMaxStamina(Character, SetToMax)
	ValuesService:UpdateWalkspeed(Character)
	ValuesService:UpdateRegeneration(Character)
end

function ValuesService:GetEquipmentAttributeValue(Character: Model, AttributeName: string)
	local TotalValue = 0
	for Name, Value in Character:GetAttributes() do
		if typeof(Value) ~= "string" then
			continue
		end

		local ItemData = ItemService:GetItemData(Value)
		if ItemData and ItemData[AttributeName] then
			TotalValue += ItemData[AttributeName]
		end
	end

	return TotalValue
end

function ValuesService:UpdateRegeneration(Character: Model)
	local NodeIncrease = 0
	local Player = Players:GetPlayerFromCharacter(Character)
	if Player then
		NodeIncrease = self:GetAmountUnlockedNodesMatch(Player, "Regeneration") * 0.01
	end

	Character:SetAttribute("Regeneration", 0.01 + NodeIncrease)
end

function ValuesService:UpdateDamage(Character: Model)
	local StanceData = StanceService:GetStance(Character:GetAttribute("Stance"))
	local WeaponData = ItemService:GetItemData(Character:GetAttribute("Weapon"))

	local EnergyConservation = 1

	local Kendo = 1
	local Player = Players:GetPlayerFromCharacter(Character)
	if Player then
		if SkillTreeService:IsSkillUnlocked(Player, "Energy Conservation") then
			EnergyConservation = 0.7
		end

		Kendo = self:GetAmountUnlockedNodesMatch(Player, "Kendo") * 2
	end

	local SwordBaseDamage = StanceData.BaseDamage or 0
	local SwordBaseStaminaCost = StanceData.BaseStaminaCost or 0

	if WeaponData then
		SwordBaseDamage += WeaponData.AdditionalDamage or 0
		SwordBaseStaminaCost += WeaponData.AdditionalStaminaCost or 0
	end

	Character:SetAttribute("SwordDamage", SwordBaseDamage + Kendo)

	Character:SetAttribute("SwordStaminaCost", SwordBaseStaminaCost * EnergyConservation)
end

function ValuesService:UpdateMaxHealth(Character: Model, SetToMax: boolean)
	if Character:GetAttribute("IsAI") then
		return
	end

	local NodeIncrease = 0
	local Player = Players:GetPlayerFromCharacter(Character)
	if Player then
		NodeIncrease = self:GetAmountUnlockedNodesMatch(Player, "Resistance") * 10
	end

	local ArmorIncrease = self:GetEquipmentAttributeValue(Character, "MaxHealthIncrease")

	local RaceData = RaceService:GetRaceData(Character:GetAttribute("Race") or "Human")
	local BASE_HEALTH = RaceData.BaseStats.MaxHealth

	Character:SetAttribute("MaxHealth", BASE_HEALTH + NodeIncrease + ArmorIncrease)

	if SetToMax then
		Character:SetAttribute("Health", Character:GetAttribute("MaxHealth"))
	end

	if Character:GetAttribute("Health") > Character:GetAttribute("MaxHealth") then
		Character:SetAttribute("Health", Character:GetAttribute("MaxHealth"))
	end
end

local BASE_POSTURE = 100
function ValuesService:UpdateMaxPosture(Character: Model)
	local StrengthPoints = (Character:GetAttribute("StrengthPoints") or 0)
	local PointsPosture = (StrengthPoints * 0.1)
	Character:SetAttribute("MaxPosture", BASE_POSTURE + PointsPosture)
end

function ValuesService:GetAmountUnlockedNodesMatch(Player: Player | Model, Pattern: string)
	if Player:IsA("Model") then
		Player = Players:GetPlayerFromCharacter(Player)
		if not Player then
			return 0
		end
	end

	local PlayerData = DataService:GetData(Player)

	local Amount = 0
	for _, Node in PlayerData.UnlockedNodes do
		if Node:find(Pattern) then
			Amount += 1
		end
	end

	return Amount
end

local BASE_STAMINA = 100
function ValuesService:UpdateMaxStamina(Character: Model, SetToMax: boolean)
	if Character:GetAttribute("IsAI") then
		Character:SetAttribute("MaxStamina", math.huge)
		Character:SetAttribute("Stamina", math.huge)
		return
	end

	local NodeIncrease = 0
	local Player = Players:GetPlayerFromCharacter(Character)
	if Player then
		NodeIncrease = self:GetAmountUnlockedNodesMatch(Player, "Stamina") * 10
	end

	local ArmorIncrease = self:GetEquipmentAttributeValue(Character, "MaxStaminaIncrease")

	Character:SetAttribute("MaxStamina", BASE_STAMINA + ArmorIncrease + NodeIncrease)

	if SetToMax then
		Character:SetAttribute("Stamina", Character:GetAttribute("MaxStamina"))
	end

	if Character:GetAttribute("Stamina") > Character:GetAttribute("MaxStamina") then
		Character:SetAttribute("Stamina", Character:GetAttribute("MaxStamina"))
	end
end

function ValuesService:UpdateWalkspeed(Character: Model)
	local SpeedPoints = (Character:GetAttribute("SpeedPoints") or 0)

	local Multiplier = SpeedPoints * 0.005

	local EquipableIncrease = self:GetEquipmentAttributeValue(Character, "RunspeedIncrease")
	local Clamped = math.clamp(Multiplier, 0, 0.35)

	Character:SetAttribute("RunSpeedMultiplier", 1 + Clamped)
	Character:SetAttribute("RunSpeedIncrease", EquipableIncrease)
	CharacterShared:UpdateWalkspeed(Character)
end

function ValuesService:UpdateEquipableValues(Character: Model)
	self:UpdateMaxHealth(Character)
	self:UpdateMaxStamina(Character)
	self:UpdateWalkspeed(Character)
end

function ValuesService.KnitInit()
	DataService = Knit.GetService("DataService")
	ItemService = Knit.GetService("ItemService")
	StanceService = Knit.GetService("StanceService")
	RaceService = Knit.GetService("RaceService")
	SkillTreeService = Knit.GetService("SkillTreeService")
end

function ValuesService.KnitStart() end

return ValuesService
