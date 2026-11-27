local Weapon = {}

local Players = game:GetService("Players")
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
local ValuesService = Knit.GetService("ValuesService")
local ClothService = Knit.GetService("ClothService")
local IntroCombatTutorialService = Knit.GetService("IntroCombatTutorialService")
local TalentService = Knit.GetService("TalentService")

local Validate = require(ReplicatedStorage.Shared.Validate)
local GetModelMass = require(ReplicatedStorage.Shared.Utils.GetModelMass)
local Stances = require(ReplicatedStorage.Shared.Index.Stances)

type M1FlowConfig = {
	InputBuffer: number,
	FinisherRecovery: number,
	WindupWalkSpeedMultiplier: number,
	SwingWalkSpeedMultiplier: number,
	SwingSlowdownDuration: number,
}

type M1Swing = {
	Animation: AnimationTrack,
	ChainAt: number?,
	Stance: string,
	Weapon: string?,
	BufferedInput: RBXScriptConnection?,
}

local M1Swings: { [Model]: M1Swing } = setmetatable({}, { __mode = "k" })

local function GetStanceData(Attacker: Model)
	return Stances[Attacker:GetAttribute("Stance")]
end

local function GetM1Flow(Attacker: Model): M1FlowConfig?
	local Stance = GetStanceData(Attacker)
	if not Stance or not Stance.M1Flow then
		return nil
	end

	local Player = Players:GetPlayerFromCharacter(Attacker)
	if Player and not Player:GetAttribute("InIntroCutscene") and not Attacker:GetAttribute("IntroTutorialAction") then
		return Stance.M1Flow
	end

	return nil
end

local function CanContinueM1(Attacker: Model, Swing: M1Swing): boolean
	return M1Swings[Attacker] == Swing
		and Swing.Animation.IsPlaying
		and Attacker:IsDescendantOf(workspace)
		and Attacker:GetAttribute("Stance") == Swing.Stance
		and Attacker:GetAttribute("Weapon") == Swing.Weapon
		and Attacker:GetAttribute("WeaponEquipped") == true
		and not WeaponService:DidCancel(Attacker)
end

local function ClearBufferedM1(Swing: M1Swing)
	if Swing.BufferedInput then
		Swing.BufferedInput:Disconnect()
		Swing.BufferedInput = nil
	end
end

local function BufferM1(Attacker: Model, Config: M1FlowConfig)
	local Swing = M1Swings[Attacker]
	if not Swing or not Swing.ChainAt or Swing.BufferedInput or not CanContinueM1(Attacker, Swing) then
		return
	end

	local ChainAt = Swing.ChainAt
	local TimeUntilChain = ChainAt - os.clock()
	if TimeUntilChain > Config.InputBuffer then
		return
	end

	Swing.BufferedInput = Attacker.AttributeChanged:Connect(function(Attribute: string)
		if not CanContinueM1(Attacker, Swing) then
			ClearBufferedM1(Swing)
			return
		end

		if Attribute ~= "AttackDebounce" or Attacker:GetAttribute("AttackDebounce") then
			return
		end

		ClearBufferedM1(Swing)
		if os.clock() >= ChainAt and GetM1Flow(Attacker) then
			Weapon.Attack(Attacker, { Server = {} })
		end
	end)
end

local function StartM1Movement(Attacker: Model, Swing: M1Swing, Config: M1FlowConfig, Duration: number)
	M1Swings[Attacker] = Swing
	Attacker:SetAttribute("M1WalkSpeedMultiplier", Config.WindupWalkSpeedMultiplier)

	Swing.Animation.Stopped:Once(function()
		ClearBufferedM1(Swing)
		if M1Swings[Attacker] == Swing then
			Attacker:SetAttribute("M1WalkSpeedMultiplier", 1)
		end
	end)

	task.delay(Duration, function()
		ClearBufferedM1(Swing)
		if M1Swings[Attacker] == Swing then
			M1Swings[Attacker] = nil
			Attacker:SetAttribute("M1WalkSpeedMultiplier", nil)
		end
	end)
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
	local Flow = GetM1Flow(Attacker)
	if not Validate:CanAttack(Attacker) then
		if Flow and Attacker:GetAttribute("AttackDebounce") then
			BufferM1(Attacker, Flow)
		end
		return
	end

	if Flow and not Attacker:GetAttribute("ComboDebounce") and WeaponService:IsLastAttack(Attacker) then
		Attacker:SetAttribute("ComboCounter", 0)
	end

	WeaponService:IncreaseComboCounter(Attacker)
	if Attacker:GetAttribute("ComboDebounce") then
		return
	end

	Attacker:SetAttribute("Running", false)

	AnimationService:StopAnimationFind(Attacker, "Block")
	AnimationService:StopAnimationFind(Attacker, "Deflected")
	AnimationService:StopAttackAnimations(Attacker)

	local AttackAnimation: AnimationTrack, M1Animation: Animation = WeaponService:PlayM1Animation(Attacker)
	local M1Config = GetM1Config(Attacker)
	local WeaponSide = GetWeaponSide(M1Config)
	local AttackAdjustSpeed = (Data.Server.AttackAdjustSpeed or 1) * TalentService:GetAttackSpeed(Attacker)
	AttackAnimation:AdjustSpeed(AttackAdjustSpeed)

	local StartTime = tick()
	local AttackDuration = AttackAnimation.Length / AttackAdjustSpeed
	local AttackingDuration = AttackDuration + 0.15
	local ChainDelay = math.max(0, AttackDuration - 0.1)
	local IsFinisher = Flow and WeaponService:IsLastAttack(Attacker)
	local AttackDebounce = if IsFinisher then AttackDuration + Flow.FinisherRecovery else ChainDelay
	local CurrentSwing: M1Swing?
	local SwordStaminaCost = ValuesService:GetWeaponStaminaCost(Attacker, WeaponSide)

	StaminaService:RemoveStamina(Attacker, SwordStaminaCost)
	DebounceService:AddDebounce(Attacker, "Attack", AttackDuration)
	DebounceService:AddDebounce(Attacker, "Attacking", AttackingDuration)
	if Flow then
		CurrentSwing = {
			Animation = AttackAnimation,
			ChainAt = if IsFinisher then nil else os.clock() + ChainDelay,
			Stance = Attacker:GetAttribute("Stance"),
			Weapon = Attacker:GetAttribute("Weapon"),
		}
		StartM1Movement(Attacker, CurrentSwing, Flow, AttackingDuration)
	end
	DebounceService:AddDebounce(Attacker, "AttackDebounce", AttackDebounce)

	local AttackDelay = ((M1Config and M1Config.HitboxDelay) or (AttackAnimation.Length * 0.2)) / AttackAdjustSpeed
	local TalentAttack = TalentService:BeginAttack(Attacker, false, AttackDelay, AttackDuration)

	-- The intro owns this first sword swing before any hitbox or delayed damage is created.
	if Attacker:GetAttribute("IntroTutorialArmed")
		and IntroCombatTutorialService:CaptureSwordAttack(Attacker, AttackAnimation, M1Animation, AttackDelay) then
		return
	end

	task.delay(AttackDelay, function()
		if not TalentService:ActivateAttack(Attacker, TalentAttack) then
			return
		end

		local MovementSwing = CurrentSwing
		if Flow and MovementSwing and CanContinueM1(Attacker, MovementSwing) then
			Attacker:SetAttribute("M1WalkSpeedMultiplier", Flow.SwingWalkSpeedMultiplier)
			task.delay(Flow.SwingSlowdownDuration, function()
				if CanContinueM1(Attacker, MovementSwing) then
					Attacker:SetAttribute("M1WalkSpeedMultiplier", 1)
				end
			end)
		end

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

		local StopClothSwing: (() -> ())?
		local function Cancel()
			if StopClothSwing then
				StopClothSwing()
			end

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

		StopClothSwing = ClothService:StartSwing(Attacker, HitboxDuration, WeaponSide)

		task.delay(M1Animation:GetAttribute("SlashDelay") or 0.2, function()
			WeaponService:ShowSlash(Attacker, M1Animation)
		end)

		local function HitCharacter(Character: Model, RayCFrame: CFrame?)
			if Character:GetAttribute("IntroTutorialProtected") then
				HitService:NormalHit(Character, Attacker, 0, {
					RayCFrame = RayCFrame,
					By = "Weapon",
					Action = "Attack",
				})
				return
			end

			if not DamageService:CanDamage(Character, Attacker) or not TalentService:AcceptTarget(Attacker, TalentAttack, Character) then
				return
			end
			local Damage = DamageService:CalculateDamage(Attacker, Character, 0, { "Weapon" }, WeaponSide)
			local PostureBonus = TalentService:GetPostureBonus(TalentAttack)

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
		end

		if M1Config and M1Config.HitboxType == "Box" then
			local TotalDuration = HitboxDuration
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

		HitboxService:CharacterRaycastHitbox(Attacker, HitboxDuration, function(Character, Hit, Result)
			HitCharacter(Character, CFrame.new(Hit.Position, Result.Position + -Result.Normal))
		end, Cancel, {
			HandHitbox = GetHitboxHand(M1Config),
			Action = "Attack",
		})
	end)
end

Weapon.StrongAttack = function(Attacker: Model, _Data: { any })
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
	local TalentAttack = TalentService:BeginAttack(Attacker, true, AttackDelay, AttackDuration)
	local SlashDelay = M2Config and M2Config.SlashDelay
	

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
		if not TalentService:ActivateAttack(Attacker, TalentAttack) then
			return
		end
		local Difference = tick() - StartTime
		local HitboxDuration = (AttackDuration - Difference) * 0.8
		WeaponService:SwordTrailsEnabled(Attacker, true, WeaponSide)
		local Swing: Sound = SoundEffectService:CustomSwordWoosh(Attacker, "M2")
		SoundEffectService:AddPitchEffect(Swing, 0.85, 1.25)

		local StopClothSwing: (() -> ())?
		local function Cancel()
			if StopClothSwing then
				StopClothSwing()
			end

			Swing:Stop()
			Swing:Destroy()

			WeaponService:SwordTrailsEnabled(Attacker, false, WeaponSide)
		end

		if WeaponService:DidCancel(Attacker) or not AnimationService:GetAnimationFind(Attacker, "M2") then
			Cancel()
			return
		end

		StopClothSwing = ClothService:StartSwing(Attacker, HitboxDuration, WeaponSide)

		if not SlashDelay then
			task.delay(0.1, function()
				WeaponService:ShowSlash(Attacker, AnimationInstance)
			end)
		end
		

		ExecutionService:ExecuteInRange(Attacker)

		HitboxService:CharacterRaycastHitbox(Attacker, HitboxDuration, function(Character, Hit, Result)
			if not DamageService:CanDamage(Character, Attacker) or not TalentService:AcceptTarget(Attacker, TalentAttack, Character) then
				return
			end
			local RayCFrame = CFrame.new(Hit.Position, Result.Position + -Result.Normal)
			local Damage = DamageService:CalculateDamage(Attacker, Character, 0, { "Weapon" }, WeaponSide) * DamageMultiplier

			HitService:MeleeHit(Character, Attacker, Damage, {
				RayCFrame = RayCFrame,
				By = "Weapon",
				Action = "StrongAttack",
			}, function(Context: string?)
				if Context == "Hit" then
					TalentService:OnHeavyHit(Attacker, Character)
				end
			end)
		end, Cancel, {
			HandHitbox = GetHitboxHand(M2Config),
			Action = "StrongAttack",
		})
	end)
end

return Weapon
