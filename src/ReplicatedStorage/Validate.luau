local RunService = game:GetService("RunService")

local GeneralCantAttributes = {
	"Died",
	"Ragdoll",
	"PostureBreak",
	"HeavyDeflect",
	"Meditating",
	"BeenDeflected",
	"InCell",
	"InLabor",
}

local function isFalse(Character, attributes)
	for _, att in attributes do
		if Character:GetAttribute(att) == true then
			return false
		end
	end
	return true
end

local function isTrue(Character, attributes)
	for _, att in attributes do
		if not Character:GetAttribute(att) then
			return false
		end
	end
	return true
end

local function IsSkillStateValid(Character)
	local state = Character:GetAttribute("SkillState")
	return state ~= "Charge" and state ~= "Charged"
end

local Validate = {}

function Validate:CanEquipWeapon(Character: Model)
	local Tool = Character:FindFirstChildWhichIsA("Tool")
	return isFalse(Character, GeneralCantAttributes)
		and isFalse(Character, {
			"Equipping",
			"Unequipping",
			"Blocking",
			"BeenDeflected",
			"HeavyDeflect",
			"Meditating",
			"EquipDebounce",
			"Attacking",
			"Climbing",
		})
		and isTrue(Character, { "Weapon" })
		and (Tool == nil or Tool:GetAttribute("CanBeEquippedWithWeapon"))
		and IsSkillStateValid(Character)
end

function Validate:CanRun(Character: Model)
	local Humanoid = Character:FindFirstChild("Humanoid")
	return isFalse(Character, GeneralCantAttributes)
		and isFalse(Character, {
			"UsingSkillCantAttack",
			"Blocking",
			"HasBlocked",
			"Attack",
			"Unequipping",
			"Climbing",
		})
		and Character:GetAttribute("Stamina") > 0
		and (Character:GetAttribute("IsAI") or (Humanoid and Humanoid.MoveDirection.Magnitude > 0))
		and IsSkillStateValid(Character)
end

function Validate:CanRoll(Character: Model)
	return isFalse(Character, GeneralCantAttributes)
		and isFalse(Character, {
			"UsingSkillCantAttack",
			"RollDebounce",
			"RollClientDebounce",
			"ClientStrongAttack",
			"ClientAttacking",
			"Vaulting",
			"WallRunning",
		})
		and (Character:GetAttribute("Race") == "Raijin" or not Character:GetAttribute("Blocking"))
		and Character:GetAttribute("Stamina") >= 5
		and IsSkillStateValid(Character)
end

function Validate:CanBlock(Character: Model)
	return isFalse(Character, GeneralCantAttributes)
		and isFalse(Character, {
			"UsingSkillCantAttack",
			"Climbing",
			"BlockDebounce",
			"Rolling",
			"Attack",
			"ClientAttacking",
			"WallRunning",
		})
		and isTrue(Character, { "WeaponEquipped" })
		and IsSkillStateValid(Character)
end

function Validate:CanAttack(Character: Model)
	local Tool = Character:FindFirstChildWhichIsA("Tool")
	local Player = game.Players:GetPlayerFromCharacter(Character)
	if Player and Player:GetAttribute("CantAttack") then
		return false
	end

	return not Tool
		and Character:GetAttribute("WeaponEquipped")
		and Character:GetAttribute("SwordStaminaCost") <= Character:GetAttribute("Stamina")
		and isFalse(Character, GeneralCantAttributes)
		and isFalse(Character, {
			"Blocking",
			"Rolling",
			"AttackDebounce",
			"Climbing",
			"ClientStrongAttack",
			"ClientBlocking",
			"StrongAttack",
			"UsingSkillCantAttack",
			"HasBlocked",
			"WallRunning",
			"HasDeflected",
			"Vaulting",
		})
		and IsSkillStateValid(Character)
		and (Character:GetAttribute("Stunless") or isFalse(Character, { "BeenHitted" }))
end

function Validate:CanStrongAttack(Character: Model)
	local Tool = Character:FindFirstChildWhichIsA("Tool")
	local Player = game.Players:GetPlayerFromCharacter(Character)
	if Player and Player:GetAttribute("CantAttack") then
		return false
	end

	return not Tool
		and Character:GetAttribute("WeaponEquipped")
		and Character:GetAttribute("SwordStaminaCost") * 2 <= Character:GetAttribute("Stamina")
		and isFalse(Character, GeneralCantAttributes)
		and isFalse(Character, {
			"Blocking",
			"Rolling",
			"Attacking",
			"ClientAttacking",
			"ClientStrongAttack",
			"StrongAttackDebounce",
			"Climbing",
			"UsingSkillCantAttack",
			"HasBlocked",
			"Vaulting",
			"WallRunning",
		})
		and IsSkillStateValid(Character)
		and (Character:GetAttribute("Stunless") or isFalse(Character, { "BeenHitted" }))
end

function Validate:CanUseSkill(Character: Model, StaminaCost: number)
	local Player = game.Players:GetPlayerFromCharacter(Character)
	if Player and Player:GetAttribute("CantAttack") then
		return false
	end

	return Character:GetAttribute("Stunless")
		or (
			isFalse(Character, GeneralCantAttributes)
			and isFalse(Character, {
				"UsingSkillCantAttack",
				"Blocking",
				"BeenHitted",
				"Rolling",
				"HasDeflected",
				"HasBlocked",
				"Attack",
				"Vaulting",
				"WallRunning",
			})
			and IsSkillStateValid(Character)
			and StaminaCost <= Character:GetAttribute("Stamina")
		)
end

function Validate:CanClimb(Character: Model)
	return isFalse(Character, GeneralCantAttributes)
		and isFalse(Character, {
			"Climbing",
			"ClimbDebounce",
			"Attacking",
			"BeenHitted",
			"Blocking",
			"HasBlocked",
			"Vaulting",
			"WallRunning",
		})
		and IsSkillStateValid(Character)
end

function Validate:CanWallRun(Character: Model)
	return isFalse(Character, GeneralCantAttributes)
		and isFalse(Character, {
			"Attacking",
			"BeenHitted",
			"Blocking",
			"HasBlocked",
			"Vaulting",
		})
		and IsSkillStateValid(Character)
end

function Validate:CanVault(Character: Model)
	return isFalse(Character, GeneralCantAttributes)
		and isFalse(Character, {
			"Attacking",
			"BeenHitted",
			"Blocking",
			"HasBlocked",
			"Vaulting",
			"WallRunning",
		})
		and IsSkillStateValid(Character)
end

return Validate
