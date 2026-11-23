local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local TalentConfig = require(ReplicatedStorage.Shared.SkillTreeConfig)

local BuffService = Knit.CreateService({
	Name = "BuffService",
	Client = {},
})

local Buffs = {}

local SkillTreeService

local function sum(base: number, value: number, operation: string)
	if operation == "int" then
		return value
	elseif operation == "%" then
		return (base * value) / 100
	elseif operation == "*" then
		return base * value
	end
end

-- retorna se o Character possui o buff com o mesmo nome
function BuffService:HasBuff(Character: Model, BuffName: string): boolean
	for _, v in Buffs[Character] or {} do
		if v.Name == BuffName then
			return true
		end
	end
	return false
end

--[[ chama as funções para dar update ]]
function BuffService:UpdateCharacterBuff(Character: Model, BuffType: string)
	local BuffTypes = {
		Burn = function()
			local ActiveBuffs = BuffService:GetBuffsByType(Character, "Burn")
			local Damage = BuffService:GetBuffsFromType(Character, "Burn", 0)
			Character:SetAttribute("BurnDamage", Damage)
			if ActiveBuffs and #ActiveBuffs > 0 then
				Character:AddTag("Burn")
			else
				Character:RemoveTag("Burn")
			end
		end,

		Confetti = function()
			local ActiveBuffs = BuffService:GetBuffsByType(Character, "Confetti")
			if ActiveBuffs and #ActiveBuffs > 0 then
				Character:AddTag("Confetti")
			else
				Character:RemoveTag("Confetti")
			end
		end,

		Electrified = function()
			local ActiveBuffs = BuffService:GetBuffsByType(Character, "Electrified")
			if ActiveBuffs and #ActiveBuffs > 0 then
				Character:AddTag("Electrified")
			else
				Character:RemoveTag("Electrified")
			end
		end,
	}

	if BuffTypes[BuffType] then
		BuffTypes[BuffType]()
	end
end

-- retorna os buffs
function BuffService:GetBuffsFromType(Character: Model, Type: string, Base: number)
	local CharacterBuffs = BuffService:GetAllBuffs(Character)

	if not CharacterBuffs then
		return 0
	end

	local total = 0
	local added = {}
	for _, buff in CharacterBuffs do
		if buff.Type ~= Type then
			continue
		end
		if table.find(added, buff.Name) then
			continue
		end
		table.insert(added, buff.Name)

		total += sum(Base, buff.Value, buff.ValueType)
	end

	return total
end

function BuffService:GetAllBuffs(Character: Model)
	return Buffs[Character]
end

function BuffService:RemoveBuffsByType(Character: Model, BuffType: string)
	if not Buffs[Character] then
		return
	end
	for i, v in Buffs[Character] do
		if v.Type == BuffType then
			Buffs[Character][i] = nil
		end
	end

	BuffService:UpdateCharacterBuff(Character, BuffType)
end

function BuffService:GetBuffsByType(Character: Model, BuffType: string)
	local buffs = {}
	if not Buffs[Character] then
		return
	end
	for _, v in Buffs[Character] do
		if v.Type == BuffType then
			table.insert(buffs, v)
		end
	end

	return buffs
end

function BuffService:RemoveBuffByName(Character: Model, BuffName: string)
	if not Buffs[Character] then
		return
	end
	for i, v in Buffs[Character] do
		if v.Name == BuffName then
			table.remove(Buffs[Character], i)
			return true
		end
	end

	return false
end

function BuffService:RemoveBuffByIndex(Character: Model, Index: string)
	if not Buffs[Character] then
		return
	end
	table.remove(Buffs[Character], Index)

	return true
end

function BuffService:AddBuff(
	Character: Model,
	Name: string,
	Type: string,
	Value: number,
	Duration: number,
	ValueType: "int" | "%" | "*"
)
	ValueType = ValueType or "int"
	if Type == "Burn" and SkillTreeService:IsSkillUnlocked(Character, "Burn Resistance") then
		Duration *= TalentConfig.Effects.BurnDurationMultiplier
	end

	if not Buffs[Character] then
		Buffs[Character] = {}
		Character.Destroying:Once(function()
			Buffs[Character] = nil
		end)
	end

	local Buff = { Name = Name, Type = Type, Value = Value, ValueType = ValueType }
	task.delay(Duration, function()
		if not Buffs[Character] then
			return
		end
		local Index = table.find(Buffs[Character], Buff)
		if Index then
			BuffService:RemoveBuffByIndex(Character, Index)
		end
		if not BuffService:HasBuff(Character, Name) then
			BuffService:UpdateCharacterBuff(Character, Type)
		end
	end)

	table.insert(Buffs[Character], Buff)
	BuffService:UpdateCharacterBuff(Character, Type)
end

function BuffService.KnitInit()
	SkillTreeService = Knit.GetService("SkillTreeService")
end

return BuffService
