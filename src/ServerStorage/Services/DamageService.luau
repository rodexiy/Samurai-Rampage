local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local DamageService = Knit.CreateService({
	Name = "DamageService",
	Client = {},
})

local MIN_PLAYER_COMBAT_LEVEL = 10

local PartyService
local EquipmentService
local ItemService
local SkillTreeService
local ArtifactService
local ValuesService
local StanceService
local DataService

local function GetPlayerLevel(Player: Player): number
	local PlayerData = DataService:GetData(Player)
	return (PlayerData and PlayerData.Level) or 0
end

function DamageService:CanDamage(Character: Model, Attacker: Model?): boolean
	if not Attacker then
		return true
	end

	local CharacterPlayer = Players:GetPlayerFromCharacter(Character)
	local AttackerPlayer = Players:GetPlayerFromCharacter(Attacker)
	if not CharacterPlayer or not AttackerPlayer or CharacterPlayer == AttackerPlayer then
		return true
	end

	return GetPlayerLevel(CharacterPlayer) >= MIN_PLAYER_COMBAT_LEVEL
		and GetPlayerLevel(AttackerPlayer) >= MIN_PLAYER_COMBAT_LEVEL
end

function DamageService:GetMultiplierTotalFromEquipments(Character: Model, MultiplierName: string)
	local EquipmentTypes = EquipmentService.EquipmentTypes
	local Amount = 0
	for _, Type in EquipmentTypes do
		local ItemName = Character:GetAttribute(Type)

		if ItemName then
			local ItemData = ItemService:GetItemData(ItemName)

			if not ItemData then
				continue
			end
			local AmountMultiplier = ItemData[MultiplierName] or 0
			Amount += AmountMultiplier
		end
	end

	return Amount
end

function DamageService:CalculateDamage(
	Attacker: Model,
	Enemy: Model,
	BaseDamage: number,
	Multipliers: { string },
	WeaponSide: string?
)
	local TotalStrength = 0
	local TotalResistance = 0
	for _, Multiplier in Multipliers do
		local NodeIncrease = 0
		if Multiplier == "Artifact" then
			NodeIncrease = BaseDamage
				* ((ValuesService:GetAmountUnlockedNodesMatch(Attacker, Attacker:GetAttribute("Artifact")) or 0) * 0.15)
		elseif Multiplier == "Weapon" then
			local StanceData = StanceService:GetStance(Attacker:GetAttribute("Stance")) or {}
			local SwordBaseDamage = StanceData.BaseDamage or 0
			SwordBaseDamage += ValuesService:GetWeaponAdditionalStat(Attacker, WeaponSide, "AdditionalDamage")

			BaseDamage += SwordBaseDamage
			NodeIncrease = ValuesService:GetAmountUnlockedNodesMatch(Attacker, "Kendo Proficiency")
		end

		BaseDamage += NodeIncrease

		local Resistance = DamageService:GetMultiplierTotalFromEquipments(Enemy, Multiplier .. "Resistance")
		local Strength = DamageService:GetMultiplierTotalFromEquipments(Attacker, Multiplier .. "Strength")
		TotalStrength += (Strength / 100)
		TotalResistance += (Resistance / 100)
	end

	local FinalDamage = math.max(0, BaseDamage + ((BaseDamage * TotalStrength) - (BaseDamage * TotalResistance)))

	return FinalDamage
end

function DamageService:IncrementDamage(Character: Model, Damage: number, Attacker: Model)
	if not Attacker or Attacker:GetAttribute("IsAI") then
		return
	end
	local Player = Players:GetPlayerFromCharacter(Attacker)

	if not Player then
		return
	end
	local DamageFolder = Character:FindFirstChild("DamageFolder")
	if not DamageFolder then
		DamageFolder = Instance.new("Folder")
		DamageFolder.Name = "DamageFolder"
		DamageFolder.Parent = Character
	end

	local DamageValue = DamageFolder:FindFirstChild(Player.UserId)
	if not DamageValue then
		DamageValue = Instance.new("NumberValue")
		DamageValue.Name = Player.UserId
		DamageValue.Parent = DamageFolder
	end

	DamageValue.Value = DamageValue.Value + Damage
end

function DamageService:DealDamage(Character: Model, Amount: number, Attacker: Model)
	if
		Character:GetAttribute("ForceField")
		or Character:GetAttribute("InLabor")
		or Character:GetAttribute("InCell")
	then
		return
	end

	if not DamageService:CanDamage(Character, Attacker) then
		return
	end

	local AttackerPlayer = Attacker and Players:GetPlayerFromCharacter(Attacker)
	local AttackerParty = PartyService:GetPlayerParty(AttackerPlayer)

	if AttackerParty then
		local CharacterPlayer = Players:GetPlayerFromCharacter(Character)
		if table.find(AttackerParty.Members, CharacterPlayer) then
			return
		end
	end

	local RemainingDamage = Character:GetAttribute("Health") - Amount
	Character:SetAttribute(
		"Health",
		math.clamp(Character:GetAttribute("Health") - Amount, 0, Character:GetAttribute("MaxHealth"))
	)

	DamageService:IncrementDamage(Character, Amount, Attacker)

	if Character:GetAttribute("Health") <= 0 and not Character:GetAttribute("Downed") then
		if Character:GetAttribute("IsAI") then
			if Character:GetAttribute("Lifes") > 1 then
				Character:SetAttribute("Lifes", Character:GetAttribute("Lifes") - 1)
				Character:SetAttribute("Health", Character:GetAttribute("MaxHealth"))
				Character:SetAttribute("Posture", 0)

				if RemainingDamage < 0 then
					task.defer(function()
						self:DealDamage(Character, math.abs(RemainingDamage), Attacker)
					end)
				end
				return
			end
		end
		Character:SetAttribute("Downed", true)
	end
end
function DamageService.Client:FallDamage(Player: Player, Velocity: number)
	local Character = Player.Character
	if Character then
		self.Server:DealDamage(Character, Velocity / 4)
	end
end

function DamageService.KnitInit()
	PartyService = Knit.GetService("PartyService")
	EquipmentService = Knit.GetService("EquipmentService")
	ItemService = Knit.GetService("ItemService")
	SkillTreeService = Knit.GetService("SkillTreeService")
	ArtifactService = Knit.GetService("ArtifactService")
	ValuesService = Knit.GetService("ValuesService")
	StanceService = Knit.GetService("StanceService")
	DataService = Knit.GetService("DataService")
end

function DamageService.KnitStart() end

return DamageService
