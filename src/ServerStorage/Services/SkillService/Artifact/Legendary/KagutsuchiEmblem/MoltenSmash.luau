local MoltenSmash = {}

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
function MoltenSmash.Charge(Character: Model, Data: { RootCFrame: CFrame })
	DebounceService:AddDebounce(Character, "MoltenSmashDebounce", Cooldown, true)
	SkillService:SetSkillData(Character, "MoltenSmash", "Charge")

	StaminaService:RemoveStamina(Character, Stamina)

	RenderService:RenderForAllPlayers("MoltenSmash", "Charge", { Character = Character })
	DebounceService:AddDebounce(Character, "SkillLockMovement", 1)
	DebounceService:AddDebounce(Character, "UsingSkillCantAttack", 1)
	DebounceService:AddDebounce(Character, "Attack", 1)

	RenderService:RenderForAllPlayers("Combat", "DodgeKanji", { Character = Character })

	SetAutoRotate(Character, false)

	local MoltenSmashCharge =
		game.ReplicatedStorage.Assets.Animations.Skills.Artifacts.KagutsuchiEmblem.MoltenSmashCharge
	AnimationService:PlayAnimation(Character, MoltenSmashCharge)

	task.wait(0.65)
	SetAutoRotate(Character, true)

	MoltenSmash.Stomp(Character, Data)
end

function MoltenSmash.Stomp(Character: Model, Data: { RootCFrame: CFrame })
	if SkillService:GetSkillState(Character, "MoltenSmash") ~= "Charge" then
		return
	end

	SkillService:SetSkillData(Character, "MoltenSmash", "Stomp")

	local size = Vector3.new(12.5, 12.5, 12.5)
	local steps = 3
	local stepPosition = 5
	local startOffSet = 5

	local initialPosition = Data.RootCFrame

	for step = 1, steps, 1 do
		local position = initialPosition * CFrame.new(0, 0, -(startOffSet + (stepPosition * ((step * 2.5) - 2.5))))

		local Params = RaycastParams.new()
		Params.FilterDescendantsInstances = { workspace.Entity, workspace.FaceHeadFolder }
		Params.FilterType = Enum.RaycastFilterType.Exclude

		local ray = workspace:Raycast(position.Position + Vector3.new(0, 1, 0), Vector3.new(0, -10, 0), Params)

		if not ray then
			task.wait(0.35)
			continue
		end

		local position = CFrame.new(ray.Position + Vector3.new(0, 3, 0)) * CFrame.Angles(position:ToOrientation())

		RenderService:RenderForAllPlayers(
			"MoltenSmash",
			"Stomp",
			{ Character = Character, Position = position, Size = size }
		)

		task.wait(0.1)

		HitboxService:CreatePartHitbox(
			Character,
			{ Size = size, CFrame = position, Frames = 20, DontWeld = true },
			function(Enemy)
				task.delay(LagCompensationService:GetCompensation(Enemy), function()
					local Damage = DamageService:CalculateDamage(Character, Enemy, 15, { "Artifact" })
					local Context = HitService:DodgeOnly(Enemy, Character, Damage, { Type = "Skill" })

					if Context == "Hit" then
						RagdollService:Ragdoll(Enemy)
						Enemy.HumanoidRootPart:ApplyImpulse(Vector3.new(0, 50, 0) * GetModelMass(Enemy))
						task.delay(1, function()
							RagdollService:Unragdoll(Enemy)
						end)

						BuffService:AddBuff(Enemy, "Burn", "Burn", 2, 5, "int")
					end
				end)
			end
		)
		task.wait(0.25)
	end

	SkillService:SetSkillData(Character, "MoltenSmash", nil)
end

function MoltenSmash.Cancel(Character: Model)
	DebounceService:RemoveDebounce(Character, "UsingSkill")
	DebounceService:RemoveDebounce(Character, "SkillLockMovement")

	SetAutoRotate(Character, true)
end

function MoltenSmash.Caller(Humanoid: Humanoid, Data: { any })
	if Validate:CanUseSkill(Humanoid, 20) and not DebounceService:HaveDebounce(Humanoid, "MoltenSmashDebounce") then
		task.spawn(function()
			MoltenSmash.Charge(Humanoid, Data)
		end)
		return true
	end
end

function MoltenSmash.Start()
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

return MoltenSmash
