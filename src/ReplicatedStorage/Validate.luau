local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KickConfig = require(ReplicatedStorage.Shared.KickConfig)
local EgoConfig = require(ReplicatedStorage.Shared.EgoConfig)

local GeneralCantAttributes = {
	"Kicking",
	"EgoCutscene",
	"Bandaging",
	"IntroOpening",
	"Mounted",
	"Died",
	"Ragdoll",
	"PostureBreak",
	"HeavyDeflect",
	"Meditating",
	"RealmEditing",
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

local LessonActions = { Parry = "Block", Attack = "Attack", Dodge = "Roll", Kick = "Kick" }
local IntroCombatActions = { Attack = true, Block = true, Roll = true, Kick = true }

function Validate:CanPerformIntroAction(Character: Model, Action: string): boolean
	if Character:GetAttribute("EgoCutscene")
		or (Character:GetAttribute("EgoActive") and EgoConfig.BlockedActions[Action]) then
		return false
	end

	local Player = Players:GetPlayerFromCharacter(Character)
	if not Player or not Player:GetAttribute("InIntroCutscene") then
		return true
	end
	if Character:GetAttribute("IntroOpening") or Character:GetAttribute("IntroWakeUp") then
		return false
	end

	local Lesson = Character:GetAttribute("IntroTutorialAction")
	if Lesson then
		return LessonActions[Lesson] == Action
	end

	return IntroCombatActions[Action] == true
end

function Validate:CanEquipWeapon(Character: Model, AllowRangedSwitch: boolean?): boolean
	if Character:GetAttribute("IntroTutorialAction") then return false end
	if Character:GetAttribute("BowEquipped") and not AllowRangedSwitch then
		return false
	end

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
	if not self:CanPerformIntroAction(Character, "Run") then
		return false
	end

	if Character:GetAttribute("IntroTutorialAction") then return false end
	local Humanoid = Character:FindFirstChild("Humanoid")
	return isFalse(Character, GeneralCantAttributes)
		and isFalse(Character, {
			"Crouching",
			"BowDrawing",
			"UsingSkillCantAttack",
			"Blocking",
			"HasBlocked",
			"Attack",
			--"Unequipping",
			"Climbing",
		})
		and Character:GetAttribute("Stamina") > 0
		and (Character:GetAttribute("IsAI") or (Humanoid and Humanoid.MoveDirection.Magnitude > 0))
		and IsSkillStateValid(Character)
end

function Validate:CanRoll(Character: Model)
	if not self:CanPerformIntroAction(Character, "Roll") then
		return false
	end

	local Action = Character:GetAttribute("IntroTutorialAction")
	if Action and Action ~= "Dodge" then return false end
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
		and Character:GetAttribute("Stamina") >= (if Character:GetAttribute("TalentMobileResponse")
			and (Character:GetAttribute("TalentResponseRollUntil") or 0) > workspace:GetServerTimeNow() then 3 else 5)
		and IsSkillStateValid(Character)
end

function Validate:CanBlock(Character: Model)
	if not self:CanPerformIntroAction(Character, "Block") then
		return false
	end

	local Action = Character:GetAttribute("IntroTutorialAction")
	if Action and Action ~= "Parry" then return false end
	if Character:GetAttribute("BowEquipped") then
		return false
	end

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
	if not self:CanPerformIntroAction(Character, "Attack") then
		return false
	end

	local Action = Character:GetAttribute("IntroTutorialAction")
	if Action and Action ~= "Attack" then return false end
	if Character:GetAttribute("BowEquipped") then
		return false
	end

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
	if not self:CanPerformIntroAction(Character, "StrongAttack") then
		return false
	end

	if Character:GetAttribute("IntroTutorialAction") then return false end
	if Character:GetAttribute("BowEquipped") then
		return false
	end

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

function Validate:CanKick(Character: Model): boolean
	if not self:CanPerformIntroAction(Character, "Kick") then
		return false
	end

	local Player = Players:GetPlayerFromCharacter(Character)
	local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
	local Lesson = Character:GetAttribute("IntroTutorialAction")

	return Humanoid ~= nil and Humanoid.Health > 0 and Character.PrimaryPart ~= nil
		and (Character:GetAttribute("Stamina") or 0) >= KickConfig.StaminaCost
		and not (Player and Player:GetAttribute("CantAttack"))
		and not Character:FindFirstChildWhichIsA("Tool")
		and isFalse(Character, GeneralCantAttributes)
		and isFalse(Character, {
			"Downed", "IntroWakeUp", "KickDebounce", "Blocking", "ClientBlocking",
			"Rolling", "Attack", "Attacking", "ClientAttacking", "StrongAttack", "ClientStrongAttack",
			"BeenHitted", "UsingSkillCantAttack", "Climbing", "Vaulting", "WallRunning",
			"Equipping", "Unequipping", "BowDrawing", "HasBlocked", "HasDeflected",
		})
		and (Lesson == nil or Lesson == "Kick")
		and IsSkillStateValid(Character)
end

function Validate:CanUseSkill(Character: Model, StaminaCost: number)
	if not self:CanPerformIntroAction(Character, "Skill") then
		return false
	end

	if Character:GetAttribute("RealmEditing") or Character:GetAttribute("BowEquipped") or Character:GetAttribute("Mounted")
		or Character:GetAttribute("Kicking") then
		return false
	end

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
	if not self:CanPerformIntroAction(Character, "Climb") then
		return false
	end

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
	if not self:CanPerformIntroAction(Character, "WallRun") then
		return false
	end

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
	if not self:CanPerformIntroAction(Character, "Vault") then
		return false
	end

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
