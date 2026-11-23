local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.SkillTreeConfig)
local Effects = Config.Effects

local TalentService = Knit.CreateService({ Name = "TalentService", Client = {} })
local SkillTreeService
local StaminaService
local DebounceService
local AnimationService
local States: { [Model]: any } = setmetatable({}, { __mode = "k" })

local function GetState(Character: Model): any
	local State = States[Character]
	if not State then
		State = {}
		States[Character] = State
	end

	return State
end

function TalentService:Has(Character: Model, Name: string): boolean
	return SkillTreeService:IsSkillUnlocked(Character, Name)
end

function TalentService:Step(Character: Model, Distance: number)
	local Root = Character.PrimaryPart
	if not Root or not Character.Parent then
		return
	end

	local Direction = Root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if Direction.Magnitude < 0.001 then
		return
	end
	Direction = Direction.Unit
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = { Character }
	Params.RespectCanCollide = true
	local Clearance = math.max(Root.Size.X, Root.Size.Z) / 2 + 0.2
	local Hit = workspace:Raycast(Root.Position, Direction * (Distance + Clearance), Params)
	if Hit then
		Distance = math.min(Distance, math.max(0, Hit.Distance - Clearance))
	end

	Character:PivotTo(Character:GetPivot() + Direction * Distance)
end

function TalentService:GetAttackSpeed(Character: Model): number
	local State = GetState(Character)
	local Ready = (State.ContinuityUntil or 0) > os.clock() and self:Has(Character, "Continuity")
	State.ContinuityUntil = nil

	return if Ready then Effects.ContinuitySpeed else 1
end

function TalentService:BeginAttack(Character: Model, Heavy: boolean, Windup: number, Duration: number): any
	local State = GetState(Character)
	local Attack = { Heavy = Heavy, WindupEnd = os.clock() + Windup, Ends = os.clock() + Duration, Targets = {}, Active = false }
	State.Attack = Attack
	if not Heavy then
		Attack.FirmResponse = (State.ResponseUntil or 0) > os.clock() and self:Has(Character, "Firm Response")
		if Attack.FirmResponse then
			State.ResponseUntil = nil
		end
		if (State.OpeningUntil or 0) > os.clock() and self:Has(Character, "Exploit Opening") then
			State.OpeningUntil = nil
			self:Step(Character, Effects.OpeningDistance)
		end
	end

	return Attack
end

function TalentService:ActivateAttack(Character: Model, Attack: any): boolean
	if GetState(Character).Attack ~= Attack or Attack.Cancelled or os.clock() > Attack.Ends then
		return false
	end
	Attack.Active = true
	return true
end

function TalentService:AcceptTarget(Character: Model, Attack: any, Target: Model): boolean
	if GetState(Character).Attack ~= Attack or Attack.Cancelled or not Attack.Active or Attack.Targets[Target] then
		return false
	end
	local Limit = if Attack.Heavy and not self:Has(Character, "Make Room") then 1 else Effects.SweepTargets
	local Count = 0
	for _ in Attack.Targets do
		Count += 1
	end
	if Attack.Heavy and not Character:GetAttribute("IsAI") and Count >= Limit then
		return false
	end

	Attack.Targets[Target] = true
	return true
end

function TalentService:GetPostureBonus(Attack: any): number
	if Attack.FirmResponse then
		Attack.FirmResponse = false
		return Effects.ResponsePosture
	end

	return 0
end

function TalentService:OnHeavyHit(Character: Model, Target: Model)
	if self:Has(Character, "Continuity") then
		GetState(Character).ContinuityUntil = os.clock() + Effects.OpeningDuration
	end

	local Root = Target.PrimaryPart
	if Root then
		local Multiplier = if self:Has(Character, "Heavy Impact") then Effects.ImpactPushMultiplier
			elseif self:Has(Character, "Close Pressure") then Effects.PressurePushMultiplier else 1
		Root.AssemblyLinearVelocity += Character:GetPivot().LookVector * 15 * Multiplier
	end
end

function TalentService:OnParry(Character: Model)
	GetState(Character).ResponseUntil = os.clock() + Effects.ResponseDuration
	if self:Has(Character, "Mobile Response") then
		Character:SetAttribute("TalentResponseRollUntil", workspace:GetServerTimeNow() + Effects.ResponseDuration)
	end
end

function TalentService:GetRollCost(Character: Model): number
	local State = GetState(Character)
	if (State.ResponseUntil or 0) > os.clock() and self:Has(Character, "Mobile Response") then
		State.ResponseUntil = nil
		Character:SetAttribute("TalentResponseRollUntil", nil)
		return Effects.ResponseRollCost
	end

	return 5
end

function TalentService:OnBlock(Character: Model)
	if not self:Has(Character, "Economical Guard") then
		return
	end

	local State = GetState(Character)
	local Now = os.clock()
	State.BlockCount = if Now - (State.LastBlock or 0) <= Effects.GuardSequenceWindow then (State.BlockCount or 0) + 1 else 1
	State.LastBlock = Now
	if State.BlockCount >= Effects.GuardSequenceHits and Now >= (State.GuardReady or 0) then
		State.BlockCount = 0
		State.GuardReady = Now + Effects.GuardCooldown
		StaminaService:AddStamina(Character, Effects.GuardStamina)
	end
end

function TalentService:GetPostureBreakDuration(Character: Model): number
	local State = GetState(Character)
	if self:Has(Character, "Rise Again") and os.clock() >= (State.RiseReady or 0) then
		State.RiseReady = os.clock() + Effects.PostureBreakCooldown
		return Effects.PostureBreakDuration
	end

	return 2
end

function TalentService:OnGuardBreak(Attacker: Model)
	GetState(Attacker).OpeningUntil = os.clock() + Effects.OpeningDuration
end

function TalentService:TryFeint(Character: Model): boolean
	local State = GetState(Character)
	local Attack = State.Attack
	if not Attack or Attack.Heavy or Attack.Active or Attack.Cancelled or os.clock() >= Attack.WindupEnd
		or os.clock() < (State.FeintReady or 0) or not self:Has(Character, "Feint")
		or not Character:GetAttribute("WeaponEquipped") or (Character:GetAttribute("Stamina") or 0) < Effects.FeintCost then
		return false
	end
	for _, Attribute in { "Died", "Downed", "Ragdoll", "PostureBreak", "BeenHitted", "BeenDeflected", "HeavyDeflect", "IntroTutorialAction" } do
		if Character:GetAttribute(Attribute) then
			return false
		end
	end

	Attack.Cancelled = true
	State.FeintReady = os.clock() + Effects.FeintCooldown
	StaminaService:RemoveStamina(Character, Effects.FeintCost)
	AnimationService:StopAttackAnimations(Character)
	for _, Attribute in { "Attack", "Attacking", "AttackDebounce" } do
		DebounceService:RemoveDebounce(Character, Attribute)
	end
	if self:Has(Character, "Moving Feint") then
		self:Step(Character, Effects.FeintStep)
	end

	return true
end

local function RestoreRecovery(Character: Model, State: any, Token: number, Amount: number): number
	if not Character.Parent or State.DamageToken ~= Token or Character:GetAttribute("Died") or Character:GetAttribute("Downed") then
		return 0
	end
	local Health = Character:GetAttribute("Health") or 0
	local Maximum = Character:GetAttribute("MaxHealth") or 100
	if Health <= 0 then
		return 0
	end
	local Heal = math.max(0, math.min(Amount, Maximum - Health, Maximum * Effects.CombatRecoveryCap - State.WindowHealing))
	State.WindowHealing += Heal
	Character:SetAttribute("Health", Health + Heal)

	return Heal
end

function TalentService:RecordDamage(Character: Model, Attacker: Model?, Damage: number)
	if Damage <= 0 then
		return
	end
	local State = GetState(Character)
	State.DamageToken = (State.DamageToken or 0) + 1
	State.WindowHealing = 0
	local Token = State.DamageToken
	local Health = Character:GetAttribute("Health") or 0
	local Maximum = Character:GetAttribute("MaxHealth") or 100
	if not Attacker or Attacker == Character or Health <= 0 or Character:GetAttribute("Died") or Character:GetAttribute("Downed") then
		return
	end

	if self:Has(Character, "Second Wind") and Health <= Maximum * Effects.CriticalHealthFraction then
		task.delay(Effects.SecondWindDelay, function()
			if State.DamageToken ~= Token or not Character.Parent or not self:Has(Character, "Second Wind")
				or os.clock() < (State.SecondWindReady or 0) then
				return
			end
			local CurrentMaximum = Character:GetAttribute("MaxHealth") or 100
			if (Character:GetAttribute("Health") or 0) > CurrentMaximum * Effects.CriticalHealthFraction then
				return
			end
			if RestoreRecovery(Character, State, Token, CurrentMaximum * Effects.SecondWindHealFraction) > 0 then
				State.SecondWindReady = os.clock() + Effects.SecondWindCooldown
			end
		end)
	end
	if self:Has(Character, "Recovery Reserve") then
		task.delay(Effects.RecoveryDelay, function()
			if self:Has(Character, "Recovery Reserve") then
				local CurrentMaximum = Character:GetAttribute("MaxHealth") or 100
				RestoreRecovery(Character, State, Token, math.min(Damage * Effects.RecoveryFraction, CurrentMaximum * Effects.RecoveryCap))
			end
		end)
	end
end

function TalentService.KnitInit()
	SkillTreeService = Knit.GetService("SkillTreeService")
	StaminaService = Knit.GetService("StaminaService")
	DebounceService = Knit.GetService("DebounceService")
	AnimationService = Knit.GetService("AnimationService")
end

function TalentService.KnitStart()
	Players.PlayerRemoving:Connect(function(Player: Player)
		if Player.Character then
			States[Player.Character] = nil
		end
	end)
end

return TalentService
