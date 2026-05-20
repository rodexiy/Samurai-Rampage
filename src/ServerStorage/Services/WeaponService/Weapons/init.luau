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
local StanceService = Knit.GetService("StanceService")

local Validate = require(game.ReplicatedStorage.Shared.Validate)
local GetModelMass = require(game.ReplicatedStorage.Shared.Utils.GetModelMass)

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
	local AttackAdjustSpeed = Data.Server.AttackAdjustSpeed or 1
	AttackAnimation:AdjustSpeed(AttackAdjustSpeed)
	local AdjustedSubtract = AttackAdjustSpeed - 1

	local StartTime = tick()
	local AttackDuration = AttackAnimation.Length

	local SwordStaminaCost = Attacker:GetAttribute("SwordStaminaCost")

	StaminaService:RemoveStamina(Attacker, SwordStaminaCost)
	DebounceService:AddDebounce(Attacker, "Attack", AttackDuration)
	DebounceService:AddDebounce(Attacker, "Attacking", AttackDuration + 0.15)
	DebounceService:AddDebounce(Attacker, "AttackDebounce", AttackDuration)

	local AttackDelay = AttackAnimation:GetAttribute("HitboxDelay") or (AttackDuration * 0.2)
	local SecondsAdjusted = AttackDuration - (AttackDuration * AttackAdjustSpeed)
	AttackDelay = AttackDelay - AdjustedSubtract

	task.delay(AttackDelay, function()
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

		task.delay(M1Animation:GetAttribute("SlashDelay") or 0.2, function()
			WeaponService:ShowSlash(Attacker, M1Animation)
		end)

		local function OnHit(Character, RayCFrame)
				local Damage = DamageService:CalculateDamage(Attacker, Character, 0, { "Weapon" })

				task.delay(LagCompensationService:GetCompensation(Character), function()
					local Context = HitService:NormalHit(
						Character,
						Attacker,
						Damage,
						{ RayCFrame = RayCFrame, FlingOnLast = true, By = "Weapon" }
					)

					if Context == "Hit" then
						local RootPart = Attacker:FindFirstChild("HumanoidRootPart")
						local BodyVelocity = Instance.new("BodyVelocity")
						BodyVelocity.MaxForce = Vector3.new(1, 0, 1) * 5000 * GetModelMass(Attacker)
						BodyVelocity.Velocity = Attacker:GetPivot().LookVector * 20
						BodyVelocity.P = 850
						BodyVelocity.Parent = RootPart

						Debris:AddItem(BodyVelocity, 0.1)

						local EnemyRootPart = Character:FindFirstChild("HumanoidRootPart")
						local EnemyBodyVelocity = Instance.new("BodyVelocity")
						EnemyBodyVelocity.MaxForce = Vector3.new(1, 0, 1) * 5000 * GetModelMass(Attacker)
						EnemyBodyVelocity.Velocity = Attacker:GetPivot().LookVector * 15
						EnemyBodyVelocity.P = 850
						EnemyBodyVelocity.Parent = EnemyRootPart

						Debris:AddItem(EnemyBodyVelocity, 0.1)
					end
				end)
			end

			local StanceData = StanceService:GetStance(Attacker:GetAttribute("Stance"))
			local M1Config = StanceData and StanceData.M1 and StanceData.M1[Attacker:GetAttribute("ComboCounter")]
			local HitboxType = M1Config and M1Config.HitboxType

			if HitboxType == "Box" then
				local HitboxSize = (M1Config and M1Config.HitboxSize) or Vector3.new(5, 5, 5)
				local TotalDuration = HitboxDuration + SecondsAdjusted

				HitboxService:CreatePartHitbox(Attacker, {
					Size = HitboxSize,
					Frames = math.ceil(TotalDuration * 60),
				}, function(Character)
					if WeaponService:DidCancel(Attacker) then
						return
					end
					local EnemyRoot = Character:FindFirstChild("HumanoidRootPart")
					local RayCFrame = EnemyRoot and EnemyRoot.CFrame or Attacker:GetPivot()
					OnHit(Character, RayCFrame)
				end)

				task.delay(HitboxDuration + SecondsAdjusted, Cancel)
			else
				HitboxService:CharacterRaycastHitbox(
					Attacker,
					HitboxDuration + SecondsAdjusted,
					function(Character, Hit, Result)
						local RayCFrame = CFrame.new(Hit.Position, Result.Position + -Result.Normal)
						OnHit(Character, RayCFrame)
					end,
					Cancel
				)
			end
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

	local Damage = Attacker:GetAttribute("SwordDamage") * 2
	local SwordStaminaCost = Attacker:GetAttribute("SwordStaminaCost") * 2

	AnimationService:StopAnimationFind(Attacker, "Block")
	StaminaService:RemoveStamina(Attacker, SwordStaminaCost)
	DebounceService:AddDebounce(Attacker, "StrongAttack", AttackDuration)
	DebounceService:AddDebounce(Attacker, "Attack", AttackDuration)
	DebounceService:AddDebounce(Attacker, "Attacking", AttackDuration)
	DebounceService:AddDebounce(Attacker, "StrongAttackDebounce", 2)

	local StanceData = StanceService:GetStance(Attacker:GetAttribute("Stance"))
	local M2HitsConfig = StanceData and StanceData.M2 and StanceData.M2.Hits

	if M2HitsConfig then
		local TrailsActive = false
		local ActiveHitboxes = 0
		local Swing

		local function Cancel()
			if Swing then
				Swing:Stop()
				Swing:Destroy()
			end
			WeaponService:SwordTrailsEnabled(Attacker, false)
		end

		task.delay(0.1, function()
			WeaponService:ShowSlash(Attacker, AnimationInstance)
		end)

		ExecutionService:ExecuteInRange(Attacker)

		for _, HitConfig in M2HitsConfig do
			task.delay(HitConfig.Delay, function()
				if WeaponService:DidCancel(Attacker) or not AnimationService:GetAnimationFind(Attacker, "M2") then
					Cancel()
					return
				end

				if not TrailsActive then
					TrailsActive = true
					WeaponService:SwordTrailsEnabled(Attacker, true)
					Swing = SoundEffectService:CustomSwordWoosh(Attacker, "M2")
					SoundEffectService:AddPitchEffect(Swing, 0.85, 1.25)
				end

				ActiveHitboxes += 1

				HitboxService:CharacterRaycastHitbox(Attacker, HitConfig.Duration, function(Character, Hit, Result)
					local RayCFrame = CFrame.new(Hit.Position, Result.Position + -Result.Normal)
					task.delay(LagCompensationService:GetCompensation(Character), function()
						HitService:NormalHit(Character, Attacker, Damage, { RayCFrame = RayCFrame, By = "Weapon" })
					end)
				end, function()
					ActiveHitboxes -= 1
					if ActiveHitboxes <= 0 then
						Cancel()
					end
				end)
			end)
		end
	else
		task.delay(AttackAnimation:GetAttribute("HitboxDelay") or AttackDuration * 0.35, function()
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

			task.delay(0.1, function()
				WeaponService:ShowSlash(Attacker, AnimationInstance)
			end)

			ExecutionService:ExecuteInRange(Attacker)

			HitboxService:CharacterRaycastHitbox(Attacker, HitboxDuration, function(Character, Hit, Result)
				local RayCFrame = CFrame.new(Hit.Position, Result.Position + -Result.Normal)
				task.delay(LagCompensationService:GetCompensation(Character), function()
					HitService:NormalHit(Character, Attacker, Damage, { RayCFrame = RayCFrame, By = "Weapon" })
				end)
			end, Cancel)
		end)
	end
end

return Weapon
