local Workspace = game:GetService("Workspace")
local Fireball = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)
local HitboxService
local RenderService
local SkillService
local DebounceService

local RagdollService
local HitService
local BuffService
local AnimationService
local StaminaService
local LagCompensationService
local DamageService

local Validate = require(game.ReplicatedStorage.Shared.Validate)
local GetModelMass = require(game.ReplicatedStorage.Shared.Utils.GetModelMass)
local SetAutoRotate = require(game.ReplicatedStorage.Shared.Utils.SetAutoRotate)

local Cooldown = 20
local Stamina = 20
local BaseDamage = 30

local FORWARD_DISTANCE = 50

function Fireball.Charge(Character: Model, Data: { RootCFrame: CFrame })
	print(Data)
	DebounceService:AddDebounce(Character, "FireballDebounce", Cooldown, true)
	SkillService:SetSkillData(Character, "Fireball", "Charge")

	StaminaService:RemoveStamina(Character, Stamina)

	local CharacterCFrame = Data.RootCFrame
	local Origin = (CharacterCFrame * CFrame.new(1, 2, 0)).Position

	local angle = 25
	local rad = math.rad(angle)
	local forward = math.cos(rad)
	local down = math.sin(rad)

	local Direction = (CharacterCFrame.LookVector * forward - CharacterCFrame.UpVector * down).Unit * FORWARD_DISTANCE

	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = { Workspace.Entity, Workspace.FaceHeadFolder }

	local result = workspace:Raycast(Origin, Direction, Params)

	AnimationService:PlayAnimation(Character, "Fireball")
	DebounceService:AddDebounce(Character, "SkillLockMovement", 1)
	DebounceService:AddDebounce(Character, "UsingSkillCantAttack", 1)
	DebounceService:AddDebounce(Character, "Attack", 1)
	RenderService:RenderForAllPlayers("Combat", "DodgeKanji", { Character = Character })

	if result then
		RenderService:RenderForAllPlayers(
			"Fireball",
			"Charge",
			{ Character = Character, GroundFireCFrame = CFrame.new(result.Position) }
		)
	else
		RenderService:RenderForAllPlayers("Fireball", "Charge", {
			Character = Character,
		})

		task.wait(0.5)

		Fireball.Cancel(Character)
		return
	end

	if result then
		local GroundFireCFrame = CFrame.new(result.Position) * CFrame.Angles(Data.RootCFrame:ToOrientation())

		SetAutoRotate(Character, false)

		local FireballCharge = game.ReplicatedStorage.Assets.Animations.Skills.Artifacts.KagutsuchiEmblem.Fireball
		AnimationService:PlayAnimation(Character, FireballCharge)

		task.wait(1.1)
		SetAutoRotate(Character, true)
		Data.GroundFireCFrame = GroundFireCFrame
		Fireball.Throw(Character, Data)
	end
end

function Fireball.Throw(Character: Model, Data: { RootCFrame: CFrame, GroundFireCFrame: CFrame })
	if SkillService:GetSkillState(Character, "Fireball") ~= "Charge" then
		return
	end

	SkillService:SetSkillData(Character, "Fireball", "Release")

	RenderService:RenderForAllPlayers("Fireball", "Release", {
		Character = Character,
		GroundFireCFrame = Data.GroundFireCFrame,
	})

	task.wait(0.5)

	local hitboxes = {
		[1] = {
			Type = "Part",
			Size = Vector3.new(7.48, 12, 7.48),
			Offset = -3.74,
		},
		[2] = {
			Type = "Part",
			Size = Vector3.new(12.491, 12, 12.491),
			Offset = -11.72,
		},
		[3] = {
			Type = "Circle",
			Radius = 12,
			Offset = -25,
		},
	}

	local function EnemyHitted(Enemy: Model)
		local RealDamage = DamageService:CalculateDamage(Character, Enemy, BaseDamage, { "Artifact" })
		DamageService:DealDamage(Enemy, RealDamage, Character)
		BuffService:AddBuff(Enemy, "Burn", "Burn", 1, 5, "%")
	end

	local Hitted = {}
	for _, hitbox in hitboxes do
		if hitbox.Type == "Part" then
			HitboxService:CreatePartHitbox(Character, {
				Size = hitbox.Size,
				CFrame = Data.GroundFireCFrame * CFrame.new(0, 0, hitbox.Offset),
				Hitted = Hitted,
			}, EnemyHitted)
		elseif hitbox.Type == "Circle" then
			HitboxService:CreateCircleHitbox(Character, {
				Radius = hitbox.Radius,
				CFrame = Data.GroundFireCFrame * CFrame.new(0, 0, hitbox.Offset),
				Hitted = Hitted,
			}, EnemyHitted)
		end

		task.wait(0.1)
	end

	task.wait(3)

	SkillService:SetSkillData(Character, "Fireball", nil)
end

function Fireball.Cancel(Character: Model)
	DebounceService:RemoveDebounce(Character, "UsingSkill")
	DebounceService:RemoveDebounce(Character, "SkillLockMovement")
	AnimationService:StopAnimationFind(Character, "Fireball")
	SkillService:SetSkillData(Character, "Fireball", nil)

	RenderService:RenderForAllPlayers("Fireball", "Cancel", {
		Character = Character,
	})

	SetAutoRotate(Character, true)
end

function Fireball.Caller(Humanoid: Humanoid, Data: { any })
	if Validate:CanUseSkill(Humanoid, 20) and not DebounceService:HaveDebounce(Humanoid, "FireballDebounce") then
		task.spawn(function()
			Fireball.Charge(Humanoid, Data)
		end)
		return true
	end
end

function Fireball.Start()
	DebounceService = Knit.GetService("DebounceService")
	SkillService = Knit.GetService("SkillService")
	RagdollService = Knit.GetService("RagdollService")
	HitboxService = Knit.GetService("HitboxService")
	RenderService = Knit.GetService("RenderService")
	HitService = Knit.GetService("HitService")
	BuffService = Knit.GetService("BuffService")
	AnimationService = Knit.GetService("AnimationService")
	StaminaService = Knit.GetService("StaminaService")
	LagCompensationService = Knit.GetService("LagCompensationService")
	DamageService = Knit.GetService("DamageService")
end

return Fireball
