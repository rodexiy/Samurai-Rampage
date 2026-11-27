local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local HitService = Knit.CreateService({
	Name = "HitService",
	Client = {},
})

HitService.HitResolved = Instance.new("BindableEvent")

local PostureService
local DebounceService
local DamageService
local RenderService
local WeaponService
local AnimationService
local BloodService
local BuffService
local SkillService
local InCombatService
local IntroCutsceneService
local IntroCombatTutorialService
local HorseService
local LagCompensationService
local PartyService

local CLASH_WINDOW = 0.05

type PendingMeleeHit = {
	ContactTime: number,
	Clashed: boolean,
	ResolveClash: () -> (),
}

local PendingMeleeHits: { [Model]: { [Model]: PendingMeleeHit } } = {}

local function UnregisterMeleeHit(Character: Model, Attacker: Model, Hit: PendingMeleeHit)
	local Targets = PendingMeleeHits[Attacker]
	if Targets and Targets[Character] == Hit then
		Targets[Character] = nil
		if next(Targets) == nil then
			PendingMeleeHits[Attacker] = nil
		end
	end
end

local function CanClash(Character: Model): boolean
	return Character.PrimaryPart ~= nil and Character:IsDescendantOf(workspace)
		and Character.Parent ~= workspace.NPCs and not Character:GetAttribute("Downed")
		and not Character:GetAttribute("Ragdoll") and not Character:GetAttribute("Mounted")
		and not Character:GetAttribute("Clashed") and not Character:GetAttribute("HeavyDeflect")
		and not Character:GetAttribute("InCell") and not Character:GetAttribute("InLabor")
		and Character:GetAttribute("IntroHealthFloor") == nil
end

local function AreEnemies(Character: Model, Attacker: Model): boolean
	local Defender = Players:GetPlayerFromCharacter(Character)
	local AttackingPlayer = Players:GetPlayerFromCharacter(Attacker)
	local Party = Defender and AttackingPlayer and PartyService:GetPlayerParty(AttackingPlayer)
	return not Party or table.find(Party.Members, Defender) == nil
end

function HitService:IsInFront(Attacker: Model, Character: Model)
	local amountForward = Character:GetPivot().LookVector
		:Dot(Attacker:GetPivot().Position - Character:GetPivot().Position)
	return amountForward > 0
end

local function CanLandMeleeHit(Character: Model, Attacker: Model): boolean
	if not CanClash(Character) or not DamageService:CanDamage(Character, Attacker) or Character:GetAttribute("RollIFrame") then
		return false
	end

	local Guarding = Character:GetAttribute("DeflectTime") or Character:GetAttribute("Blocking")
	return not Guarding or not HitService:IsInFront(Attacker, Character)
end

function HitService:ResolveHitResult(Character: Model, Attacker: Model, Damage: number, Data: { any }, Result: string?)
	if Result then
		HitService.HitResolved:Fire(Character, Attacker, Result, Data or {}, Damage)
	end

	return Result
end

function HitService:ApplyWeaponHitBuffs(Character: Model, Attacker: Model, _Data: { any })
	if Attacker:GetAttribute("SwordOnFire") then
		BuffService:AddBuff(Character, "Burn", "Burn", 2, 5, "int")
	elseif Attacker:GetAttribute("ConfettiOnSword") and Character:GetAttribute("IsGhost") then
		BuffService:AddBuff(Character, "Confetti", "Confetti", 1, 5, "int")
	end
end

function HitService:Hit(Character: Model, Attacker: Model, Damage: number, Data: { any })
	if Character:GetAttribute("IntroTutorialProtected") then
		local Result = IntroCombatTutorialService:ResolveHit(Character, Attacker, Data)
		if Result then
			return Result
		end
	end

	if Character.Parent == workspace.NPCs then
		return
	end

	if Character:GetAttribute("ForceField") then
		return
	end

	if not DamageService:CanDamage(Character, Attacker) then
		return
	end

	if IntroCutsceneService:TryInterceptHit(Character, Damage, Attacker) then
		return "HeavyParry"
	end

	InCombatService:SetInCombat(Character, true, Attacker)

	if not Data.NoStun then
		SkillService:TryCancelSkillData(Character)
		DebounceService:AddDebounce(Character, "BeenHitted", 1)
		Character:SetAttribute("Blocking", false)
		AnimationService:StopAnimationFind(Character, "Block")

		if not Character:GetAttribute("Stunless") then
			AnimationService:StopAttackAnimations(Character)
		end
		AnimationService:PlayRandomAnimationFromFolder(Character, ReplicatedStorage.Assets.Animations.Combat.Hit)
	end

	DebounceService:AddDebounce(Attacker, "HasHitted", 0.35)

	if Data.By == "Weapon" then
		HitService:ApplyWeaponHitBuffs(Character, Attacker, Data)
	end

	if not Data.Ranged and Data.By ~= "Kick" then
		if not Attacker:GetAttribute("AttackedBeforeUnequip") or not BloodService:HasBloodOnBlade(Attacker) then
			BloodService:ApplyBloodOnBlade(Attacker)
		end
		Attacker:SetAttribute("AttackedBeforeUnequip", true)
	end
	--PostureService:DealPostureDamage(Character, Damage / 3, false, Attacker)

	if Data.By ~= "Kick" then
		RenderService:RenderForAllPlayers("Combat", "Blood", { Character = Character, Attacker = Attacker, Ranged = Data.Ranged })
	end
	local KnockedOff = false
	if Character:GetAttribute("Mounted") then
		local Direction = if Data.Ranged and typeof(Data.RayCFrame) == "CFrame" then Data.RayCFrame.LookVector else nil
		KnockedOff = HorseService:KnockOff(Character, Attacker, Direction)
	end

	if Data.FlingOnLast and not KnockedOff then
		WeaponService:TryFling(Character, Attacker)
	end

	DamageService:DealDamage(Character, Damage, Attacker)
	if Data.TalentPosture and Data.TalentPosture > 0 then
		PostureService:DealPostureDamage(Character, Data.TalentPosture, false, Attacker)
	end

	return "Hit"
end

function HitService:NormalHit(Character: Model, Attacker: Model, Damage: number, Data: { any })
	if Character:GetAttribute("IntroTutorialProtected") then
		local Result = IntroCombatTutorialService:ResolveHit(Character, Attacker, Data)
		if Result then
			return self:ResolveHitResult(Character, Attacker, Damage, Data, Result)
		end
	end

	if not DamageService:CanDamage(Character, Attacker) then
		return
	end

	if Data.By == "Kick" and Character:GetAttribute("RollIFrame") then
		return self:ResolveHitResult(Character, Attacker, Damage, Data, PostureService:Dodged(Character, Attacker))
	end

	local CanDeflect = Character:GetAttribute("DeflectTime")
		or (Data.IsFirearm == true and PostureService:CanAutoParryShot(Character))
	local Result
	if CanDeflect and HitService:IsInFront(Attacker, Character) then
		Result = PostureService:Deflected(Character, Attacker, Damage, Data)
	elseif Character:GetAttribute("Blocking") and HitService:IsInFront(Attacker, Character) then
		Result = PostureService:Blocked(Character, Attacker, Damage, Data)
	elseif Character:GetAttribute("RollIFrame") then
		Result = PostureService:Dodged(Character, Attacker)
	else
		Result = HitService:Hit(Character, Attacker, Damage, Data)
	end

	return HitService:ResolveHitResult(Character, Attacker, Damage, Data, Result)
end

function HitService:MeleeHit(
	Character: Model,
	Attacker: Model,
	Damage: number,
	Data: { any },
	OnResolved: ((string?) -> ())?
)
	local function Publish(Result: string?)
		if OnResolved then
			OnResolved(Result)
		end
	end

	local function ResolveNormally()
		Publish(self:NormalHit(Character, Attacker, Damage, Data))
	end

	local function ResolveAsClash()
		Publish(self:ResolveHitResult(Character, Attacker, Damage, Data, "HeavyParry"))
	end

	local Compensation = LagCompensationService:GetCompensation(Character)
	if Character == Attacker or Damage <= 0 or not CanLandMeleeHit(Character, Attacker) or not CanClash(Attacker) then
		task.delay(Compensation, ResolveNormally)
		return
	end

	-- Compare hitbox contacts before each defender's lag compensation is applied.
	local ContactTime = os.clock()
	local ReverseTargets = PendingMeleeHits[Character]
	local ReverseHit = ReverseTargets and ReverseTargets[Attacker]
	if ReverseHit and ContactTime - ReverseHit.ContactTime < CLASH_WINDOW
		and CanLandMeleeHit(Attacker, Character) and AreEnemies(Character, Attacker) then
		ReverseHit.Clashed = true
		UnregisterMeleeHit(Attacker, Character, ReverseHit)
		PostureService:Clash(Character, Attacker)
		InCombatService:SetInCombat(Character, true, Attacker)
		InCombatService:SetInCombat(Attacker, true, Character)
		ReverseHit.ResolveClash()
		ResolveAsClash()
		return
	end

	local Hit: PendingMeleeHit = {
		ContactTime = ContactTime,
		Clashed = false,
		ResolveClash = ResolveAsClash,
	}
	local Targets = PendingMeleeHits[Attacker] or {}
	Targets[Character] = Hit
	PendingMeleeHits[Attacker] = Targets

	task.delay(Compensation, function()
		if Hit.Clashed then
			return
		end

		local Remaining = ContactTime + CLASH_WINDOW - os.clock()
		if Remaining <= 0 or not CanLandMeleeHit(Character, Attacker) then
			UnregisterMeleeHit(Character, Attacker, Hit)
			ResolveNormally()
			return
		end

		-- The defender's guard was checked at the normal resolution time. Only delay the damage.
		task.delay(Remaining, function()
			UnregisterMeleeHit(Character, Attacker, Hit)
			if not Hit.Clashed and Character:IsDescendantOf(workspace) and Attacker:IsDescendantOf(workspace) then
				Publish(self:ResolveHitResult(Character, Attacker, Damage, Data, self:Hit(Character, Attacker, Damage, Data)))
			end
		end)
	end)
end

function HitService:DodgeOnly(Character: Model, Attacker: Model, Damage: number, Data: { any })
	if not DamageService:CanDamage(Character, Attacker) then
		return
	end

	local Result
	if Character:GetAttribute("RollIFrame") then
		Result = PostureService:Dodged(Character, Attacker)
	else
		Result = HitService:Hit(Character, Attacker, Damage, Data)
	end

	return HitService:ResolveHitResult(Character, Attacker, Damage, Data, Result)
end

function HitService:DeflectOnly(Character: Model, Attacker: Model, Damage: number, Data: { any })
	if not DamageService:CanDamage(Character, Attacker) then
		return
	end

	local Result
	if Character:GetAttribute("DeflectTime") and HitService:IsInFront(Attacker, Character) then
		Result = PostureService:Deflected(Character, Attacker, Damage, Data)
	else
		Result = HitService:Hit(Character, Attacker, Damage, Data)
	end

	return HitService:ResolveHitResult(Character, Attacker, Damage, Data, Result)
end

function HitService.KnitInit()
	PostureService = Knit.GetService("PostureService")
	DebounceService = Knit.GetService("DebounceService")
	DamageService = Knit.GetService("DamageService")
	RenderService = Knit.GetService("RenderService")
	WeaponService = Knit.GetService("WeaponService")
	AnimationService = Knit.GetService("AnimationService")
	BloodService = Knit.GetService("BloodService")
	BuffService = Knit.GetService("BuffService")
	SkillService = Knit.GetService("SkillService")
	InCombatService = Knit.GetService("InCombatService")
	IntroCutsceneService = Knit.GetService("IntroCutsceneService")
	IntroCombatTutorialService = Knit.GetService("IntroCombatTutorialService")
	HorseService = Knit.GetService("HorseService")
	LagCompensationService = Knit.GetService("LagCompensationService")
	PartyService = Knit.GetService("PartyService")
end

function HitService.KnitStart() end

return HitService
