local Knit = require(game.ReplicatedStorage.Packages.Knit)

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
local PlayerService
local InCombatService

function HitService:IsInFront(Attacker: Model, Character: Model)
	local amountForward = Character:GetPivot().LookVector
		:Dot(Attacker:GetPivot().Position - Character:GetPivot().Position)
	return amountForward > 0
end

function HitService:ResolveHitResult(Character: Model, Attacker: Model, Damage: number, Data: { any }, Result: string?)
	if Result then
		HitService.HitResolved:Fire(Character, Attacker, Result, Data or {}, Damage)
	end

	return Result
end

function HitService:ApplyWeaponHitBuffs(Character: Model, Attacker: Model, Data: { any })
	if Attacker:GetAttribute("SwordOnFire") then
		BuffService:AddBuff(Character, "Burn", "Burn", 2, 5, "int")
	elseif Attacker:GetAttribute("ConfettiOnSword") and Character:GetAttribute("IsGhost") then
		BuffService:AddBuff(Character, "Confetti", "Confetti", 1, 5, "int")
	end
end

function HitService:Hit(Character: Model, Attacker: Model, Damage: number, Data: { any })
	if Character.Parent == workspace.NPCs then
		return
	end

	if Character:GetAttribute("ForceField") then
		return
	end

	if not DamageService:CanDamage(Character, Attacker) then
		return
	end

	InCombatService:SetInCombat(Character, true, Attacker)

	SkillService:TryCancelSkillData(Character)

	DebounceService:AddDebounce(Character, "BeenHitted", 1)
	DebounceService:AddDebounce(Attacker, "HasHitted", 0.35)

	if Data.By == "Weapon" then
		HitService:ApplyWeaponHitBuffs(Character, Attacker, Data)
	end

	Character:SetAttribute("Blocking", false)

	if not Attacker:GetAttribute("AttackedBeforeUnequip") or not BloodService:HasBloodOnBlade(Attacker) then
		BloodService:ApplyBloodOnBlade(Attacker)
	end
	Attacker:SetAttribute("AttackedBeforeUnequip", true)
	AnimationService:StopAnimationFind(Character, "Block")

	--PostureService:DealPostureDamage(Character, Damage / 3, false, Attacker)

	RenderService:RenderForAllPlayers("Combat", "Blood", { Character = Character, Attacker = Attacker })
	if not Character:GetAttribute("Stunless") then
		AnimationService:StopAttackAnimations(Character)
	end
	AnimationService:PlayRandomAnimationFromFolder(Character, game.ReplicatedStorage.Assets.Animations.Combat.Hit)

	if Data.FlingOnLast then
		WeaponService:TryFling(Character, Attacker)
	end

	DamageService:DealDamage(Character, Damage, Attacker)

	return "Hit"
end

function HitService:NormalHit(Character: Model, Attacker: Model, Damage: number, Data: { any })
	if not DamageService:CanDamage(Character, Attacker) then
		return
	end

	local Result
	if Character:GetAttribute("DeflectTime") and HitService:IsInFront(Attacker, Character) then
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
	PlayerService = Knit.GetService("PlayerService")
	InCombatService = Knit.GetService("InCombatService")
end

function HitService.KnitStart() end

return HitService
