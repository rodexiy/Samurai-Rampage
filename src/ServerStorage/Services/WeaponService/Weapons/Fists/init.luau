local Fists = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local Debris = game:GetService("Debris")
local HitboxService = Knit.GetService("HitboxService")
local WeaponService = Knit.GetService("WeaponService")
local DebounceService = Knit.GetService("DebounceService")
local SoundEffectService = Knit.GetService("SoundEffectService")
local StaminaService = Knit.GetService("StaminaService")
local AnimationService = Knit.GetService("AnimationService")
local ExecutionService = Knit.GetService("ExecutionService")
local HitService = Knit.GetService("HitService")
local DamageService = Knit.GetService("DamageService")
local TalentService = Knit.GetService("TalentService")

local Validate = require(ReplicatedStorage.Shared.Validate)
local GetModelMass = require(ReplicatedStorage.Shared.Utils.GetModelMass)
local Stances = require(ReplicatedStorage.Shared.Index.Stances)

local function GetStanceData(Attacker: Model)
	return Stances[Attacker:GetAttribute("Stance")]
end

local function GetM1Config(Attacker: Model)
	local StanceData = GetStanceData(Attacker)
	return StanceData and StanceData.M1 and StanceData.M1[Attacker:GetAttribute("ComboCounter")]
end

local function GetM2Config(Attacker: Model)
	local StanceData = GetStanceData(Attacker)
	return StanceData and StanceData.M2 and StanceData.M2.Hits and StanceData.M2.Hits[1]
end

Fists.Attack = function(Attacker: Model, Data: { any })
	if not Validate:CanAttack(Attacker) then
		return
	end

	WeaponService:IncreaseComboCounter(Attacker)
	if Attacker:GetAttribute("ComboDebounce") then
		return
	end

	Attacker:SetAttribute("Running", false)

	AnimationService:StopAnimationFind(Attacker, "Block")
	AnimationService:StopAnimationFind(Attacker, "Deflected")
	AnimationService:StopAttackAnimations(Attacker)

	local AttackAnimation, M1Animation: AnimationTrack = WeaponService:PlayM1Animation(Attacker)
	local M1Config = GetM1Config(Attacker)
	local AttackAdjustSpeed = (Data.Server.AttackAdjustSpeed or 1) * TalentService:GetAttackSpeed(Attacker)
	AttackAnimation:AdjustSpeed(AttackAdjustSpeed)

	local StartTime = tick()
	local AttackDuration = AttackAnimation.Length / AttackAdjustSpeed

	local SwordStaminaCost = Attacker:GetAttribute("SwordStaminaCost")

	StaminaService:RemoveStamina(Attacker, SwordStaminaCost)
	DebounceService:AddDebounce(Attacker, "Attack", AttackDuration)
	DebounceService:AddDebounce(Attacker, "Attacking", AttackDuration + 0.15)
	DebounceService:AddDebounce(Attacker, "AttackDebounce", AttackDuration)

	local AttackDelay = ((M1Config and M1Config.HitboxDelay) or (AttackAnimation.Length * 0.2)) / AttackAdjustSpeed
	local TalentAttack = TalentService:BeginAttack(Attacker, false, AttackDelay, AttackDuration)

	task.delay(AttackDelay, function()
		if not TalentService:ActivateAttack(Attacker, TalentAttack) then
			return
		end
		local Difference = tick() - StartTime
		local HitboxDuration = (AttackDuration - Difference) * 0.8

		WeaponService:SwordTrailsEnabled(Attacker, true)
		local Swing: Sound = SoundEffectService:CustomSwordWoosh(Attacker, "M1")

		SoundEffectService:AddPitchEffect(Swing, 0.85, 1.25)

		local function Cancel()
			Swing:Stop()
			Swing:Destroy()

			WeaponService:SwordTrailsEnabled(Attacker, false)
		end

		if WeaponService:DidCancel(Attacker) or not AnimationService:GetAnimationFind(Attacker, "M1_") then
			Cancel()
			return
		end

		HitboxService:CharacterRaycastHitbox(
			Attacker,
			HitboxDuration,
			function(Character, Hit, Result)
				if not DamageService:CanDamage(Character, Attacker) or not TalentService:AcceptTarget(Attacker, TalentAttack, Character) then
					return
				end
				local PostureBonus = TalentService:GetPostureBonus(TalentAttack)
				local Damage = DamageService:CalculateDamage(Attacker, Character, 0, { "Weapon" })
				local RayCFrame = CFrame.new(Hit.Position, Result.Position + -Result.Normal)

				HitService:MeleeHit(Character, Attacker, Damage, {
					RayCFrame = RayCFrame,
					FlingOnLast = true,
					By = "Weapon",
					Action = "Attack",
					TalentPosture = PostureBonus,
				}, function(Context: string?)
					if Context == "Hit" then
						local RootPart = Attacker.PrimaryPart
						local BodyVelocity = Instance.new("BodyVelocity")
						BodyVelocity.MaxForce = Vector3.new(1, 0, 1) * 5000 * GetModelMass(Attacker)
						BodyVelocity.Velocity = Attacker:GetPivot().LookVector * 20
						BodyVelocity.P = 850
						BodyVelocity.Parent = RootPart

						Debris:AddItem(BodyVelocity, 0.1)

						if Character:GetAttribute("Ragdoll") then
							return
						end

						local TargetRoot = Character.PrimaryPart
						local TargetVelocity = Instance.new("BodyVelocity")
						TargetVelocity.MaxForce = Vector3.new(1, 0, 1) * 5000 * GetModelMass(Attacker)
						TargetVelocity.Velocity = Attacker:GetPivot().LookVector * 15
						TargetVelocity.P = 850
						TargetVelocity.Parent = TargetRoot

						Debris:AddItem(TargetVelocity, 0.1)
					end
				end)
			end,
			Cancel,
			{
				HandHitbox = M1Animation:GetAttribute("HandHitbox"),
			}
		)
	end)
end

Fists.StrongAttack = function(Attacker: Model, _Data: { any })
	if not Validate:CanStrongAttack(Attacker) then
		return
	end

	local AttackAnimation, AnimationInstance: AnimationTrack =
		AnimationService:PlayAnimation(Attacker, WeaponService:GetStanceAnimationFolder(Attacker).M2)
	AttackAnimation.Priority = Enum.AnimationPriority.Action2

	local AttackDuration = AttackAnimation.Length
	local StartTime = tick()
	local M2Config = GetM2Config(Attacker)
	local AttackDelay = (M2Config and (M2Config.HitboxDelay or M2Config.Delay)) or AttackDuration * 0.35
	local TalentAttack = TalentService:BeginAttack(Attacker, true, AttackDelay, AttackDuration)

	local Damage = Attacker:GetAttribute("SwordDamage") * 2
	local SwordStaminaCost = Attacker:GetAttribute("SwordStaminaCost") * 2

	AnimationService:StopAnimationFind(Attacker, "Block")
	StaminaService:RemoveStamina(Attacker, SwordStaminaCost)
	DebounceService:AddDebounce(Attacker, "StrongAttack", AttackDuration)
	DebounceService:AddDebounce(Attacker, "Attack", AttackDuration)
	DebounceService:AddDebounce(Attacker, "Attacking", AttackDuration)
	DebounceService:AddDebounce(Attacker, "StrongAttackDebounce", 2)

	task.delay(AttackDelay, function()
		if not TalentService:ActivateAttack(Attacker, TalentAttack) then
			return
		end
		local Difference = tick() - StartTime
		local HitboxDuration = (AttackDuration - Difference) * 0.8
		WeaponService:SwordTrailsEnabled(Attacker, true)
		local Swing: Sound = SoundEffectService:CustomSwordWoosh(Attacker, "M2")
		SoundEffectService:AddPitchEffect(Swing, 0.85, 1.25)

		local function Cancel()
			Swing:Stop()
			Swing:Destroy()

			WeaponService:SwordTrailsEnabled(Attacker, false)
		end

		if WeaponService:DidCancel(Attacker) or not AnimationService:GetAnimationFind(Attacker, "M2") then
			Cancel()
			return
		end

		ExecutionService:ExecuteInRange(Attacker)

		HitboxService:CharacterRaycastHitbox(
			Attacker,
			HitboxDuration,
			function(Character, Hit, Result)
				if not DamageService:CanDamage(Character, Attacker) or not TalentService:AcceptTarget(Attacker, TalentAttack, Character) then
					return
				end
				local RayCFrame = CFrame.new(Hit.Position, Result.Position + -Result.Normal)

				HitService:MeleeHit(Character, Attacker, Damage, {
					RayCFrame = RayCFrame,
					By = "Weapon",
					Action = "StrongAttack",
				}, function(Context: string?)
					if Context == "Hit" then
						TalentService:OnHeavyHit(Attacker, Character)
					end
				end)
			end,
			Cancel,
			{
				HandHitbox = AnimationInstance:GetAttribute("HandHitbox"),
			}
		)
	end)
end

return Fists
