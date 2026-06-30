local Weapon = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)

local Debris = game:GetService("Debris")
local HitboxService = Knit.GetService("HitboxService")
local WeaponService = Knit.GetService("WeaponService")
local DebounceService = Knit.GetService("DebounceService")
local SoundEffectService = Knit.GetService("SoundEffectService")
local StaminaService = Knit.GetService("StaminaService")
local RenderService = Knit.GetService("RenderService")
local AnimationService = Knit.GetService("AnimationService")
local ExecutionService = Knit.GetService("ExecutionService")
local LagCompensationService = Knit.GetService("LagCompensationService")
local HitService = Knit.GetService("HitService")
local DamageService = Knit.GetService("DamageService")
local ValuesService = Knit.GetService("ValuesService")

local Validate = require(game.ReplicatedStorage.Shared.Validate)
local GetModelMass = require(game.ReplicatedStorage.Shared.Utils.GetModelMass)
local Stances = require(game.ReplicatedStorage.Shared.Index.Stances)

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

local function GetWeaponSide(Config: { [string]: any }?): string
	if not Config then
		return "Right"
	end

	return Config.WeaponSide or Config.SwordSide or Config.HandHitbox or "Right"
end

local function GetHitboxHand(Config: { [string]: any }?): string?
	local HandHitbox = Config and Config.HandHitbox
	if HandHitbox == "Left" or HandHitbox == "Right" then
		return HandHitbox
	end

	return nil
end

local function GetDamageMultiplier(Config: { [string]: any }?, DefaultMultiplier: number): number
	local DamageMultiplier = Config and (Config.DamageMultiplier or Config.DamageMult)
	if typeof(DamageMultiplier) == "number" then
		return DamageMultiplier
	end

	return DefaultMultiplier
end

Weapon.Attack = function(Attacker: Model, Data: { any })
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
	local WeaponSide = GetWeaponSide(M1Config)
	local AttackAdjustSpeed = Data.Server.AttackAdjustSpeed or 1
	AttackAnimation:AdjustSpeed(AttackAdjustSpeed)
	local AdjustedSubtract = AttackAdjustSpeed - 1

	local StartTime = tick()
	local AttackDuration = AttackAnimation.Length

	local SwordStaminaCost = ValuesService:GetWeaponStaminaCost(Attacker, WeaponSide)

	StaminaService:RemoveStamina(Attacker, SwordStaminaCost)
	DebounceService:AddDebounce(Attacker, "Attack", AttackDuration)
	DebounceService:AddDebounce(Attacker, "Attacking", AttackDuration + 0.15)
	DebounceService:AddDebounce(Attacker, "AttackDebounce", AttackDuration - 0.1)

	local AttackDelay = (M1Config and M1Config.HitboxDelay) or (AttackDuration * 0.2)
	local SecondsAdjusted = AttackDuration - (AttackDuration * AttackAdjustSpeed)
	AttackDelay = AttackDelay - AdjustedSubtract

	task.delay(AttackDelay, function()
		local Difference = tick() - StartTime
		local HitboxDuration = (AttackDuration - Difference) * 0.8

		local ShouldEnableSwordTrail = not M1Config or M1Config.EnableSwordTrail ~= false
		local ShouldPlaySwingSound = not M1Config or M1Config.PlaySwingSound ~= false

		if ShouldEnableSwordTrail then
			WeaponService:SwordTrailsEnabled(Attacker, true, WeaponSide)
		end

		local Swing: Sound?
		if ShouldPlaySwingSound then
			Swing = SoundEffectService:CustomSwordWoosh(Attacker, "M1")
			SoundEffectService:AddPitchEffect(Swing, 0.85, 1.25)
		end

		local function Cancel()
			if Swing then
				Swing:Stop()
				Swing:Destroy()
			end

			if ShouldEnableSwordTrail then
				WeaponService:SwordTrailsEnabled(Attacker, false, WeaponSide)
			end
		end

		if WeaponService:DidCancel(Attacker) or not AnimationService:GetAnimationFind(Attacker, "M1_") then
			Cancel()
			return
		end

		task.delay(M1Animation:GetAttribute("SlashDelay") or 0.2, function()
			WeaponService:ShowSlash(Attacker, M1Animation)
		end)

		local function HitCharacter(Character: Model, RayCFrame: CFrame?)
			local Damage = DamageService:CalculateDamage(Attacker, Character, 0, { "Weapon" }, WeaponSide)

			task.delay(LagCompensationService:GetCompensation(Character), function()
				local Context = HitService:NormalHit(
					Character,
					Attacker,
					Damage,
					{ RayCFrame = RayCFrame, FlingOnLast = true, By = "Weapon", Action = "Attack" }
				)

				if Context == "Hit" then
					local RootPart = Attacker:FindFirstChild("HumanoidRootPart")
					local BodyVelocity = Instance.new("BodyVelocity")
					BodyVelocity.MaxForce = Vector3.new(1, 0, 1) * 5000 * GetModelMass(Attacker)
					BodyVelocity.Velocity = Attacker:GetPivot().LookVector * 20
					BodyVelocity.P = 850
					BodyVelocity.Parent = RootPart

					Debris:AddItem(BodyVelocity, 0.1)

					local RootPart = Character:FindFirstChild("HumanoidRootPart")
					local BodyVelocity = Instance.new("BodyVelocity")
					BodyVelocity.MaxForce = Vector3.new(1, 0, 1) * 5000 * GetModelMass(Attacker)
					BodyVelocity.Velocity = Attacker:GetPivot().LookVector * 15
					BodyVelocity.P = 850
					BodyVelocity.Parent = RootPart

					Debris:AddItem(BodyVelocity, 0.1)
				end
			end)
		end

		if M1Config and M1Config.HitboxType == "Box" then
			local TotalDuration = HitboxDuration + SecondsAdjusted
			local Frames = M1Config.HitboxFrames or math.max(1, math.ceil(TotalDuration * 60))

			HitboxService:CreatePartHitbox(Attacker, {
				Size = M1Config.HitboxSize,
				Frames = Frames,
				Data = {
					Action = "Attack",
				},
			}, function(Character: Model)
				local CharacterRootPart = Character:FindFirstChild("HumanoidRootPart")
				local RayCFrame = CharacterRootPart
					and CFrame.new(CharacterRootPart.Position, CharacterRootPart.Position - Attacker:GetPivot().LookVector)
					or Character:GetPivot()

				HitCharacter(Character, RayCFrame)
			end)
			return
		end

		HitboxService:CharacterRaycastHitbox(Attacker, HitboxDuration + SecondsAdjusted, function(Character, Hit, Result)
			HitCharacter(Character, CFrame.new(Hit.Position, Result.Position + -Result.Normal))
		end, Cancel, {
			HandHitbox = GetHitboxHand(M1Config),
			Action = "Attack",
		})
	end)
end

Weapon.StrongAttack = function(Attacker: Model, Data: { any })
	if not Validate:CanStrongAttack(Attacker) then
		return
	end

	local AttackAnimation, AnimationInstance: AnimationTrack =
		AnimationService:PlayAnimation(Attacker, WeaponService:GetStanceAnimationFolder(Attacker).M2)
	AttackAnimation.Priority = Enum.AnimationPriority.Action2

	local AttackDuration = AttackAnimation.Length
	local StartTime = tick()
	local M2Config = GetM2Config(Attacker)
	local WeaponSide = GetWeaponSide(M2Config)
	local DamageMultiplier = GetDamageMultiplier(M2Config, 2)
	local AttackDelay = (M2Config and (M2Config.HitboxDelay or M2Config.Delay)) or AttackDuration * 0.35
	local SlashDelay = M2Config.SlashDelay
	

	local SwordStaminaCost = ValuesService:GetWeaponStaminaCost(Attacker, WeaponSide) * DamageMultiplier

	AnimationService:StopAnimationFind(Attacker, "Block")
	StaminaService:RemoveStamina(Attacker, SwordStaminaCost)
	DebounceService:AddDebounce(Attacker, "StrongAttack", AttackDuration)
	DebounceService:AddDebounce(Attacker, "Attack", AttackDuration)
	DebounceService:AddDebounce(Attacker, "Attacking", AttackDuration)
	DebounceService:AddDebounce(Attacker, "StrongAttackDebounce", 2)

	if SlashDelay then
		task.delay(SlashDelay, function()
			if WeaponService:DidCancel(Attacker) or not AnimationService:GetAnimationFind(Attacker, "M2") then
				return
			end
			WeaponService:ShowSlash(Attacker, AnimationInstance)
		end)
	end

	task.delay(AttackDelay, function()
		local Difference = tick() - StartTime
		local HitboxDuration = (AttackDuration - Difference) * 0.8
		WeaponService:SwordTrailsEnabled(Attacker, true, WeaponSide)
		local Swing: Sound = SoundEffectService:CustomSwordWoosh(Attacker, "M2")
		SoundEffectService:AddPitchEffect(Swing, 0.85, 1.25)

		local function Cancel()
			Swing:Stop()
			Swing:Destroy()

			WeaponService:SwordTrailsEnabled(Attacker, false, WeaponSide)
		end

		if WeaponService:DidCancel(Attacker) or not AnimationService:GetAnimationFind(Attacker, "M2") then
			Cancel()
			return
		end

		if not SlashDelay then
			task.delay(0.1, function()
				WeaponService:ShowSlash(Attacker, AnimationInstance)
			end)
		end
		

		ExecutionService:ExecuteInRange(Attacker)

		HitboxService:CharacterRaycastHitbox(Attacker, HitboxDuration, function(Character, Hit, Result)
			local RayCFrame = CFrame.new(Hit.Position, Result.Position + -Result.Normal)
			local Damage = DamageService:CalculateDamage(Attacker, Character, 0, { "Weapon" }, WeaponSide) * DamageMultiplier

			task.delay(LagCompensationService:GetCompensation(Character), function()
				HitService:NormalHit(Character, Attacker, Damage, {
					RayCFrame = RayCFrame,
					By = "Weapon",
					Action = "StrongAttack",
				})
			end)
		end, Cancel, {
			HandHitbox = GetHitboxHand(M2Config),
			Action = "StrongAttack",
		})
	end)
end

return Weapon
