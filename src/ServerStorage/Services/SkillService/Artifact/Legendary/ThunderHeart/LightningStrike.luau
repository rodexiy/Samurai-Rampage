local ProximityPromptService = game:GetService("ProximityPromptService")
local LightningStrike = {}

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

local LightningBolt = require(game.ReplicatedStorage.Assets.Libraries.LightningBolt)
local LightningSparks = require(game.ReplicatedStorage.Assets.Libraries.LightningBolt.LightningSparks)

local Cooldown = 1
local Stamina = 20

local TeleportCharacter = require(game.ReplicatedStorage.Shared.Utils.TeleportCharacter)

function LightningStrike.Charge(Character: Model, Data: { RootCFrame: CFrame })
	DebounceService:AddDebounce(Character, "LightningStrikeDebounce", Cooldown, true)
	DebounceService:AddDebounce(Character, "UsingSkill", 2)

	BuffService:AddBuff(Character, "SkillElectrified", "Electrified", 0, 1.5, "int")
	SkillService:SetSkillData(Character, "LightningStrike", "Charge")
	LightningStrike.Strike(Character, Data)
end

function LightningStrike.Strike(Character: Model, Data: { RootCFrame: CFrame })
	if SkillService:GetSkillState(Character, "LightningStrike") ~= "Charge" then
		return
	end

	DebounceService:AddDebounce(Character, "LightningStrikeDebounce", Cooldown, true)

	local Root = Character.HumanoidRootPart
	local RootCFrame = Data.RootCFrame

	local MouseHit = Data.MouseHit.Position
	local Distance = math.min((RootCFrame.Position - MouseHit).Magnitude, 100)

	local MouseHit = (CFrame.new(Character:GetPivot().Position, MouseHit) * CFrame.new(0, 0, -Distance)).Position

	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = { workspace.Entity, workspace.FaceHeadFolder }

	local FinalHeight = MouseHit.Y + 25
	local cast: RaycastResult = workspace:Blockcast(
		CFrame.new(Character:GetPivot().Position, MouseHit),
		Vector3.new(2, 2, 2),
		CFrame.new(Character:GetPivot().Position, MouseHit).LookVector * (RootCFrame.Position - MouseHit).Magnitude,
		Params
	)

	if cast then
		MouseHit = cast.Position
	end

	local AmountOfNodes = math.min(math.ceil(Distance / 25), 4)

	local DistanceBetweenNodes = math.min((Distance / AmountOfNodes) * 0.8, 100)

	Root.Anchored = true
	local _, ry = CFrame.new(RootCFrame.Position, MouseHit):ToOrientation()
	local InitialCFrame = CFrame.new(RootCFrame.Position) * CFrame.Angles(0, ry, 0)
	TeleportCharacter(Character, InitialCFrame)

	local End
	for i = 1, AmountOfNodes do
		task.wait(0.125)

		local XOffset = 12.5
		if i == 1 then
			XOffset = 12.5
		elseif i % 2 == 0 then
			XOffset = -25
		else
			XOffset = 25
		end

		local Offset = CFrame.new(XOffset, 0, -DistanceBetweenNodes)

		local Start = Character:GetPivot()
		End = Start * Offset

		local cast: RaycastResult = workspace:Blockcast(
			CFrame.new(Character:GetPivot().Position, End.Position),
			Vector3.new(2, 2, 2),
			CFrame.new(Character:GetPivot().Position, End.Position).LookVector
				* (RootCFrame.Position - End.Position).Magnitude,
			Params
		)

		local Increment = (i * 5)

		if cast then
			End = CFrame.new(cast.Position + Vector3.new(0, Increment, 0)) * CFrame.Angles(End:ToOrientation())
		else
			End = CFrame.new(End.Position + Vector3.new(0, Increment, 0)) * CFrame.Angles(End:ToOrientation())
		end

		RenderService:RenderForAllPlayers(
			"LightningStrike",
			"Teleport",
			{ Character = Character, Start = Start, End = End }
		)

		TeleportCharacter(Character, End)
	end

	local Start = Character:GetPivot()

	local End = CFrame.new(MouseHit.X, MouseHit.Y + (5 * AmountOfNodes), MouseHit.Z)
		* CFrame.Angles(Character:GetPivot():ToOrientation())

	TeleportCharacter(Character, End)

	RenderService:RenderForAllPlayers(
		"LightningStrike",
		"Teleport",
		{ Character = Character, Start = Start, End = End }
	)

	task.wait(0.1)

	local ray = workspace:Raycast(Character:GetPivot().Position, Vector3.new(0, -250, 0), Params)

	local HitboxSize = Vector3.new(15, 15, 15)
	if ray then
		local HitPosition = ray.Position
		RenderService:RenderForAllPlayers(
			"LightningStrike",
			"Strike",
			{ Character = Character, HitPosition = HitPosition }
		)

		HitboxService:CreatePartHitbox(Character, {
			CFrame = CFrame.new(HitPosition.X, HitPosition.Y + (HitboxSize.Y / 2), HitPosition.Z),
			Size = HitboxSize,
			DontWeld = true,
			Frames = 3,
			IgnoreCheck = true,
		}, function(Enemy: Model)
			task.delay(LagCompensationService:GetCompensation(Enemy), function()
				local Damage = DamageService:CalculateDamage(Character, Enemy, 15, { "Artifact" })
				HitService:NormalHit(Enemy, Character, Damage, { By = "Skill", DontApplyForce = true })
			end)
		end)
	end

	task.wait(0.125)
	Root.Anchored = false

	SkillService:SetSkillData(Character, "LightningStrike", nil)
end

function LightningStrike.Cancel(Character: Model)
	DebounceService:RemoveDebounce(Character, "UsingSkill")
	DebounceService:RemoveDebounce(Character, "SkillLockMovement")
end

function LightningStrike.Caller(Humanoid: Humanoid, Data: { any })
	if Validate:CanUseSkill(Humanoid, 20) and not DebounceService:HaveDebounce(Humanoid, "LightningStrikeDebounce") then
		task.spawn(function()
			LightningStrike.Charge(Humanoid, Data)
		end)
		return true
	end
end

function LightningStrike.Start()
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

return LightningStrike
