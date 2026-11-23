local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local PostureService = Knit.CreateService({
	Name = "PostureService",
	Client = {
		BlockRequest = Knit.CreateSignal(),
		BlockResult = Knit.CreateSignal(),
	},
})

local Validate = require(ReplicatedStorage.Shared.Validate)
local TalentConfig = require(ReplicatedStorage.Shared.SkillTreeConfig)
local Effects = TalentConfig.Effects

local BlockSequences: { [Model]: number } = setmetatable({}, { __mode = "k" })
local PendingBlocks: { [Model]: RBXScriptConnection } = setmetatable({}, { __mode = "k" })
local BlockObservers: { [Model]: RBXScriptConnection } = setmetatable({}, { __mode = "k" })

local DebounceService
local AnimationService
local RenderService
local WeaponService
local SoundEffectService
local StaminaService
local SkillTreeService
local QuestService
local TalentService

local GetModelMass = require(ReplicatedStorage.Shared.Utils.GetModelMass)

function PostureService:LastHitReset(Attacker: Model, Data: { any })
	if Attacker:GetAttribute("ComboCounter") == 5 and Data.By and Data.By == "Weapon" then
		Attacker:SetAttribute("ComboCounter", 0)
		DebounceService:RemoveDebounce(Attacker, "ComboDebounce")
	end
end

function PostureService:Deflected(Character: Model, Attacker: Model, Damage: number, Data: { any })
	if Data.ExtendDeflectTime and Character:GetAttribute("Blocking") then
		DebounceService:AddDebounce(Character, "DeflectTime", Data.ExtendDuration or 0.125)
	end

	if Character:GetAttribute("ForceField") then
		return
	end

	local IsCounter = false

	if not Data.Ranged then
		PostureService:LastHitReset(Attacker, Data)

		DebounceService:RemoveDebounce(Attacker, "BlockDebounce")
		DebounceService:AddDebounce(Attacker, "BeenDeflected", 0.75)
	end

	TalentService:OnParry(Character)
	DebounceService:AddDebounce(Character, "HasDeflected", if TalentService:Has(Character, "Retake Initiative") then Effects.ParryRecovery else 0.25)

	AnimationService:StopAnimationFind(Character, "Deflected")
	local CombatAnimations = WeaponService:GetCombatAnimationFolder(Character)
	local DeflectAnimations = CombatAnimations.Deflected:GetChildren()
	local Animation = AnimationService:PlayAnimation(Character, DeflectAnimations[math.random(1, #DeflectAnimations)])
	Animation.Priority = Enum.AnimationPriority.Action3
	Animation.Name = "Deflected"

	local _, ry = Character:GetPivot():ToOrientation()
	local CharacterLookVector = (CFrame.new(Character:GetPivot().Position) * CFrame.Angles(0, ry, 0)).LookVector
	if Data.HeavyDeflect then
		DebounceService:AddDebounce(Character, "HeavyDeflect", 0.85)
		local Player = Players:GetPlayerFromCharacter(Character)
		if Player then
			RenderService:RenderForAllPlayers("Combat", "HeavyDeflect", { Character = Character, Attacker = Attacker })
		end

		AnimationService:PlayAnimation(Character, game.ReplicatedStorage.Assets.Animations.Combat.HeavyDeflect)
		local RootPart = Character.PrimaryPart
		local BodyVelocity = Instance.new("BodyVelocity")
		BodyVelocity.MaxForce = Vector3.new(1, 0, 1) * 5000 * GetModelMass(Attacker)
		BodyVelocity.Velocity = CharacterLookVector * -25 * (if TalentService:Has(Character, "Firm Footing") then Effects.GuardPushMultiplier else 1)
		BodyVelocity.P = 850
		BodyVelocity.Parent = RootPart

		Debris:AddItem(BodyVelocity, 0.5)
	elseif not Data.DontApplyForce then
		local RootPart = Character.PrimaryPart
		local BodyVelocity = Instance.new("BodyVelocity")
		BodyVelocity.MaxForce = Vector3.new(1, 0, 1) * 5000 * GetModelMass(Attacker)
		BodyVelocity.Velocity = CharacterLookVector * -17.5 * (if TalentService:Has(Character, "Firm Footing") then Effects.GuardPushMultiplier else 1)
		BodyVelocity.P = 850
		BodyVelocity.Parent = RootPart

		Debris:AddItem(BodyVelocity, 0.2)
	end

	if not Data.Ranged then
		AnimationService:StopAnimationFind(Attacker, "Deflected")
		AnimationService:StopAttackAnimations(Attacker)
		local AttackerAnimations = WeaponService:GetCombatAnimationFolder(Attacker)
		local AttackerDeflectAnimations = AttackerAnimations.Deflected:GetChildren()

		local AttackerAnimation =
			AnimationService:PlayAnimation(Attacker, AttackerDeflectAnimations[math.random(1, #AttackerDeflectAnimations)])
		AttackerAnimation.Priority = Enum.AnimationPriority.Action3
		AttackerAnimation.Name = "Deflected"

		local AttackerPostureDamage = if Attacker:GetAttribute("IsAI") then Damage else Damage / 2
		PostureService:DealPostureDamage(Attacker, AttackerPostureDamage, not Attacker:GetAttribute("IsAI"), Character)
	end

	if not Character:GetAttribute("IsAI") then
		if SkillTreeService:IsSkillUnlocked(Character, "Deflect Stamina Recovery") then
			StaminaService:AddStamina(Character, Damage / Effects.ParryStaminaDivisor)
		else
			StaminaService:AddStamina(Character, Damage / 2)
		end
	end

	local DeflectedPostureDamage = if Character:GetAttribute("IsAI") then Damage else Damage / 2
	PostureService:DealPostureDamage(Character, DeflectedPostureDamage, true, Attacker)

	RenderService:RenderForAllPlayers("Combat", "Deflect", {
		Character = Character,
		Attacker = Attacker,
		RayCFrame = Data.RayCFrame,
		IsCounter = IsCounter,
		Ranged = Data.Ranged,
	})

	return "Deflect"
end

function PostureService:Blocked(Character: Model, Attacker: Model, Damage: number, Data: { any })
	DebounceService:AddDebounce(Attacker, "BeenBlocked", 0.15)
	DebounceService:AddDebounce(Character, "HasBlocked", if TalentService:Has(Character, "Defensive Retreat") then Effects.BlockRecovery else 0.65)

	if Character:GetAttribute("ForceField") then
		return
	end

	local CombatAnimations = WeaponService:GetCombatAnimationFolder(Character)
	AnimationService:PlayAnimation(Character, CombatAnimations.BlockHit)

	if Data.PostureBreak then
		PostureService:PostureBreak(Character, Attacker)
		return
	end
	local Multiplier = if Data.Action == "StrongAttack" and TalentService:Has(Attacker, "Committed Attack") then Effects.HeavyPostureMultiplier else 1
	PostureService:DealPostureDamage(Character, Damage * 2 * Multiplier + (Data.TalentPosture or 0), false, Attacker)
	if not Character:GetAttribute("PostureBreak") then
		TalentService:OnBlock(Character)
	end

	if not Data.Ranged then
		AnimationService:StopAttackAnimations(Attacker)
		PostureService:LastHitReset(Attacker, Data)
		AnimationService:PlayAnimation(Attacker, CombatAnimations.BlockHit)
	end

	RenderService:RenderForAllPlayers(
		"Combat",
		"Block",
		{ Character = Character, Attacker = Attacker, RayCFrame = Data.RayCFrame, Ranged = Data.Ranged }
	)

	return "Block"
end

function PostureService:Dodged(Character: Model, _Attacker: Model)
	if Character:GetAttribute("ForceField") then
		return
	end

	RenderService:RenderForAllPlayers("Combat", "Dodge", { Character = Character })
	return "Dodge"
end

function PostureService:PostureBreak(Character: Model, Attacker: Model)
	if Character:GetAttribute("PostureBreak") then
		return
	end

	Attacker:SetAttribute("ComboCounter", math.max(0, Attacker:GetAttribute("ComboCounter") - 2))
	DebounceService:RemoveDebounce(Attacker, "ComboDebounce")

	DebounceService:RemoveDebounce(Character, "BlockDebounce")

	DebounceService:AddDebounce(Character, "PostureBreak", TalentService:GetPostureBreakDuration(Character))
	TalentService:OnGuardBreak(Attacker)
	AnimationService:PlayAnimation(Character, game.ReplicatedStorage.Assets.Animations.Combat.PostureBreak)
	SoundEffectService:PlaySoundEffect("PostureBreak", true, Character.PrimaryPart)

	Character:SetAttribute("Posture", 0)
	Character:SetAttribute("Blocking", false)
	AnimationService:StopAnimationFind(Character, "Block")

	DebounceService:RemoveDebounce(Character, "DeflectTime")

	RenderService:RenderForAllPlayers("Combat", "PostureBreak", { Character = Character })
end

function PostureService:DealPostureDamage(Character: Model, Damage: number, ByDeflect: boolean, Attacker: Model)
	if Character:GetAttribute("Downed") or Character:GetAttribute("IntroWakeUp") then
		return
	end
	Character:SetAttribute(
		"Posture",
		math.clamp(Character:GetAttribute("Posture") + Damage, 0, Character:GetAttribute("MaxPosture"))
	)

	if not ByDeflect and Character:GetAttribute("Posture") >= Character:GetAttribute("MaxPosture") then
		PostureService:PostureBreak(Character, Attacker)
	end
end

function PostureService:RecoverPostureDamage(Character: Model, Amount: number)
	Character:SetAttribute(
		"Posture",
		math.clamp(Character:GetAttribute("Posture") - Amount, 0, Character:GetAttribute("MaxPosture"))
	)
end

function PostureService:Block(Character: Model, State: boolean): boolean
	if State then
		if Character:GetAttribute("Blocking") then
			return true
		end

		if Character:GetAttribute("IsAI") then
			Character:SetAttribute("Attacking", false)
			Character:SetAttribute("Attack", false)
		end

		if not Validate:CanBlock(Character) then
			return false
		end

		AnimationService:StopAttackAnimations(Character)

		Character:SetAttribute("Blocking", true)

		local Player = Players:GetPlayerFromCharacter(Character)
		if Player then
			QuestService:CallQuestFunction(Player, "CombatAction", "Block")
		end

		if Character:GetAttribute("DeflectTime") then
			return true
		end

		if Character:GetAttribute("IsAI") then
			local CombatFolder = WeaponService:GetCombatAnimationFolder(Character)
			if CombatFolder then
				AnimationService:PlayAnimation(Character, CombatFolder.Block)
			end
		end

		local Penality = 0
		local difference = tick() - (Character:GetAttribute("StopBlockingTick") or 0)

		if difference < 0.07 then
			Penality = 0.15
		end

		if Character:GetAttribute("IsAI") then
			Penality = 0
		end

		if Penality > 0 then
			Character:SetAttribute("AppliedPenality", true)
		end

		if Penality == 0 then
			DebounceService:AddDebounce(Character, "DeflectTime", 0.175)
		end
		return true
	else
		if not Character:GetAttribute("Blocking") then
			return false
		end
		if Character:GetAttribute("AppliedPenality") then
			Character:SetAttribute("AppliedPenality", false)
		end

		if Character:GetAttribute("IsAI") then
			AnimationService:StopAnimationFind(Character, "Block")
		end

		Character:SetAttribute("Blocking", false)
		Character:SetAttribute("StopBlockingTick", tick())
		return false
	end
end
local function CancelPendingBlock(Character: Model)
	local Connection = PendingBlocks[Character]
	if Connection then
		PendingBlocks[Character] = nil
		Connection:Disconnect()
	end
end

function PostureService:RequestBlock(Player: Player, Character: Model, State: boolean, Sequence: number)
	if typeof(Character) ~= "Instance" or not Character:IsA("Model") or Player.Character ~= Character
		or typeof(State) ~= "boolean" or typeof(Sequence) ~= "number"
		or Sequence ~= Sequence or Sequence <= 0 or Sequence >= math.huge or Sequence % 1 ~= 0 then
		return
	end

	if Sequence <= (BlockSequences[Character] or 0) then
		return
	end

	BlockSequences[Character] = Sequence
	CancelPendingBlock(Character)
	local function PublishBlock()
		if Player.Character == Character then
			self.Client.BlockResult:Fire(Player, Character, BlockSequences[Character], Character:GetAttribute("Blocking") == true)
		end
	end

	if not BlockObservers[Character] then
		BlockObservers[Character] = Character:GetAttributeChangedSignal("Blocking"):Connect(PublishBlock)
		Character.Destroying:Connect(function()
			BlockSequences[Character] = nil
			PendingBlocks[Character] = nil
			BlockObservers[Character] = nil
		end)
	end

	if not State then
		self:Block(Character, false)
		PublishBlock()
		return
	end

	local function TryBlock()
		if Player.Character ~= Character or BlockSequences[Character] ~= Sequence
			or not Character:IsDescendantOf(workspace) or Character:GetAttribute("RealmEditing") then
			CancelPendingBlock(Character)
			return
		end

		if not Validate:CanBlock(Character) then
			return
		end

		-- Disconnect before Block changes attributes and triggers another attempt.
		CancelPendingBlock(Character)
		self:Block(Character, true)
	end

	PendingBlocks[Character] = Character.AttributeChanged:Connect(TryBlock)
	TryBlock()
	if BlockSequences[Character] == Sequence then
		PublishBlock()
	end
end

function PostureService.KnitInit()
	DebounceService = Knit.GetService("DebounceService")
	AnimationService = Knit.GetService("AnimationService")
	RenderService = Knit.GetService("RenderService")
	WeaponService = Knit.GetService("WeaponService")
	SoundEffectService = Knit.GetService("SoundEffectService")
	StaminaService = Knit.GetService("StaminaService")
	SkillTreeService = Knit.GetService("SkillTreeService")
	QuestService = Knit.GetService("QuestService")
	TalentService = Knit.GetService("TalentService")
end

function PostureService.KnitStart()
	PostureService.Client.BlockRequest:Connect(function(Player: Player, Character: Model, State: boolean, Sequence: number)
		PostureService:RequestBlock(Player, Character, State, Sequence)
	end)
end

return PostureService
