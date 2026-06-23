local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local PostureService = Knit.CreateService({
	Name = "PostureService",
	Client = {},
})

local Validate = require(game.ReplicatedStorage.Shared.Validate)

local RequestBlock: UnreliableRemoteEvent = game.ReplicatedStorage.Assets.Public.RequestBlock

local DebounceService
local AnimationService
local RenderService
local WeaponService
local SoundEffectService
local StaminaService
local SkillTreeService
local LagCompensationService
local QuestService

local GetModelMass = require(game.ReplicatedStorage.Shared.Utils.GetModelMass)

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

	DebounceService:AddDebounce(Character, "HasDeflected", 0.25)

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
		local RootPart = Character:FindFirstChild("HumanoidRootPart")
		local BodyVelocity = Instance.new("BodyVelocity")
		BodyVelocity.MaxForce = Vector3.new(1, 0, 1) * 5000 * GetModelMass(Attacker)
		BodyVelocity.Velocity = CharacterLookVector * -25
		BodyVelocity.P = 850
		BodyVelocity.Parent = RootPart

		Debris:AddItem(BodyVelocity, 0.5)
	elseif not Data.DontApplyForce then
		local RootPart = Character:FindFirstChild("HumanoidRootPart")
		local BodyVelocity = Instance.new("BodyVelocity")
		BodyVelocity.MaxForce = Vector3.new(1, 0, 1) * 5000 * GetModelMass(Attacker)
		BodyVelocity.Velocity = CharacterLookVector * -17.5
		BodyVelocity.P = 850
		BodyVelocity.Parent = RootPart

		Debris:AddItem(BodyVelocity, 0.2)
	end

	if not Data.Ranged then
		AnimationService:StopAnimationFind(Attacker, "Deflected")
		AnimationService:StopAttackAnimations(Attacker)
		local CombatAnimations = WeaponService:GetCombatAnimationFolder(Attacker)
		local DeflectAnimations = CombatAnimations.Deflected:GetChildren()

		local Animation =
			AnimationService:PlayAnimation(Attacker, DeflectAnimations[math.random(1, #DeflectAnimations)])
		Animation.Priority = Enum.AnimationPriority.Action3
		Animation.Name = "Deflected"

		local AttackerPostureDamage = if Attacker:GetAttribute("IsAI") then Damage else Damage / 2
		PostureService:DealPostureDamage(Attacker, AttackerPostureDamage, not Attacker:GetAttribute("IsAI"), Character)
	end

	if not Character:GetAttribute("IsAI") then
		if SkillTreeService:IsSkillUnlocked(Character, "Deflect Stamina Recovery II") then
			StaminaService:AddStamina(Character, Damage / 1.15)
		elseif SkillTreeService:IsSkillUnlocked(Character, "Deflect Stamina Recovery I") then
			StaminaService:AddStamina(Character, Damage / 1.45)
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
	DebounceService:AddDebounce(Character, "HasBlocked", 0.65)

	if Character:GetAttribute("ForceField") then
		return
	end

	local CombatAnimations = WeaponService:GetCombatAnimationFolder(Character)
	AnimationService:PlayAnimation(Character, CombatAnimations.BlockHit)

	if Data.PostureBreak then
		PostureService:PostureBreak(Character, Attacker)
		return
	end
	PostureService:DealPostureDamage(Character, Damage * 2, false, Attacker)

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

function PostureService:Dodged(Character: Model, Attacker: Model)
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

	DebounceService:AddDebounce(Character, "PostureBreak", 2)
	AnimationService:PlayAnimation(Character, game.ReplicatedStorage.Assets.Animations.Combat.PostureBreak)
	SoundEffectService:PlaySoundEffect("PostureBreak", true, Character.PrimaryPart)

	Character:SetAttribute("Posture", 0)
	Character:SetAttribute("Blocking", false)
	AnimationService:StopAnimationFind(Character, "Block")

	DebounceService:RemoveDebounce(Character, "DeflectTime")

	RenderService:RenderForAllPlayers("Combat", "PostureBreak", { Character = Character })
end

function PostureService:DealPostureDamage(Character: Model, Damage: number, ByDeflect: boolean, Attacker: Model)
	if Character:GetAttribute("Downed") then
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

function PostureService:Block(Character: Model, State: boolean, manyRequests: boolean)
	if State then
		if Character:GetAttribute("Blocking") then
			return true
		end

		if Character:GetAttribute("IsAI") then
			Character:SetAttribute("Attacking", false)
			Character:SetAttribute("Attack", false)
		end

		if not Validate:CanBlock(Character) then
			-- Character:SetAttribute("Blocking", false)
			-- Character:SetAttribute("ClientBlocking", false)
			-- AnimationService:StopAnimationFind(Character, "Block")
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
function PostureService.Client:Block(Player: Player, State: boolean)
	local Character = Player.Character
	if Character then
		return self.Server:Block(Character, State)
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
end

function PostureService.KnitStart()
	RequestBlock.OnServerEvent:Connect(function(Player)
		local Character = Player.Character
		if Character then
			return PostureService:Block(Character, true)
		end
	end)
end

return PostureService
