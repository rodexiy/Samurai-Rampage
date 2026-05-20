local ProximityPromptService = game:GetService("ProximityPromptService")
local ThunderWrath = {}

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

local Cooldown = 1
local Stamina = 20

function ThunderWrath.Charge(Character: Model, Data: { RootCFrame: CFrame })
	SkillService:SetSkillData(Character, "ThunderWrath", "Charge")

	task.wait(0.5)

	SkillService:SetSkillData(Character, "ThunderWrath", "Charged")
end

function ThunderWrath.Strike(Character: Model, Data: { RootCFrame: CFrame })
	if SkillService:GetSkillState(Character, "ThunderWrath") ~= "Charged" and not Character:GetAttribute("IsAI") then
		return
	end

	AnimationService:StopAnimationFind(Character, "ThunderWrathStart")
	SkillService:SetSkillData(Character, "ThunderWrath", "Active")
	DebounceService:AddDebounce(Character, "ThunderWrathDebounce", Cooldown, true)

	DebounceService:AddDebounce(Character, "UsingSkillCantAttack", 1.35)

	AnimationService:PlayAnimation(
		Character,
		game.ReplicatedStorage.Assets.Animations.Skills.Artifacts.ThunderHeart.ThunderWrathRelease
	)

	local MaxPosition = SkillService:GetPositionInRange(Data.RootCFrame.Position, Data.MousePosition, 80)
	local End = SkillService:GetGroundInMousePosition(MaxPosition) or MaxPosition

	RenderService:RenderForAllPlayers("ThunderWrath", "Strike", { Character = Character, End = End })

	local _, ry = Data.RootCFrame:ToOrientation()
	local Size = Vector3.new(15, 35, 15)

	HitboxService:CreatePartHitbox(Character, {
		CFrame = CFrame.new(End) * CFrame.new(0, Size.Y / 2, 0) * CFrame.Angles(0, ry, 0),
		Size = Size,
		DontWeld = true,
		Frames = 5,
	}, function(Enemy: Model)
		RenderService:RenderForPlayer(Enemy, "Combat", "IncomingHit", { Character = Character })
	end)

	task.wait(0.75)

	for i = 1, 5 do
		HitboxService:CreatePartHitbox(Character, {
			CFrame = CFrame.new(End) * CFrame.new(0, Size.Y / 2, 0) * CFrame.Angles(0, ry, 0),
			Size = Size,
			DontWeld = true,
			Frames = 5,
		}, function(Enemy: Model)
			task.delay(LagCompensationService:GetCompensation(Enemy), function()
				local Damage = DamageService:CalculateDamage(Character, Enemy, 10, { "Artifact" })
				HitService:NormalHit(Enemy, Character, Damage, { By = "Skill", DontApplyForce = true, Ranged = true })
				BuffService:AddBuff(Enemy, "Electrified", "Electrified", 0, 0.5, "int")
			end)
		end)

		task.wait(0.15)
	end

	SkillService:SetSkillData(Character, "ThunderWrath", nil)
end

function ThunderWrath.Cancel(Character: Model)
	DebounceService:RemoveDebounce(Character, "UsingSkill")
	DebounceService:RemoveDebounce(Character, "SkillLockMovement")
end

function ThunderWrath.Caller(Character: Model, Data: { any })
	if DebounceService:HaveDebounce(Character, "ThunderWrathDebounce") then
		return false
	end

	if Character:GetAttribute("IsAI") and Validate:CanUseSkill(Character, 20) then
		task.spawn(function()
			ThunderWrath.Strike(Character, Data)
		end)
		return true
	end

	if Data.InputState == Enum.UserInputState.Begin then
		if Validate:CanUseSkill(Character, 20) then
			task.spawn(function()
				ThunderWrath.Charge(Character, Data)
			end)
			return true
		end
	else
		if SkillService:GetSkillState(Character, "ThunderWrath") == "Charged" then
			task.spawn(function()
				ThunderWrath.Strike(Character, Data)
			end)
			return true
		else
			if not SkillService:WaitForRelease(Character, "ThunderWrath") then
				return false
			end
			task.spawn(function()
				ThunderWrath.Strike(Character, Data)
			end)

			return true
		end
	end
end

function ThunderWrath.Start()
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

return ThunderWrath
