local FloatingPassage = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)

local DebounceService = Knit.GetService("DebounceService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local SkillService = Knit.GetService("SkillService")
local AnimationService = Knit.GetService("AnimationService")
local RenderService = Knit.GetService("RenderService")
local HitboxService = Knit.GetService("HitboxService")
local HitService = Knit.GetService("HitService")
local LagCompensationService = Knit.GetService("LagCompensationService")
local TweenService = game:GetService("TweenService")
local WeaponService = Knit.GetService("WeaponService")
local SoundEffectService = Knit.GetService("SoundEffectService")
local StaminaService = Knit.GetService("StaminaService")
local DamageService = Knit.GetService("DamageService")
local MobService = Knit.GetService("MobService")

local GetModelMass = require(game.ReplicatedStorage.Shared.Utils.GetModelMass)

local Validate = require(game.ReplicatedStorage.Shared.Validate)
local Debounce = 25
local Speed = 0.5

local Assets = game.ReplicatedStorage.Assets.VFX.Skills.Kendo.FloatingPassage

function ChangeColor(CharacterToRender, VFX)
	for _, Particle in VFX:GetDescendants() do
		if Particle:IsA("ParticleEmitter") then
			if CharacterToRender:GetAttribute("SwordOnFire") then
				Particle.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 195, 112)),
					ColorSequenceKeypoint.new(0.154, Color3.fromRGB(255, 94, 19)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 6, 6)),
				})
			elseif CharacterToRender:GetAttribute("ConfettiOnSword") then
				Particle.Color = ColorSequence.new(Color3.fromRGB(168, 87, 235))
			end
		end
	end
end
function FloatingPassage.Charge(Attacker: Model, Data: { any })
	SkillService:SetSkillData(Attacker, "FloatingPassage", "Charge")

	local Animation: AnimationTrack = AnimationService:PlayAnimation(Attacker, "FloatingPassageRelease")
	Animation.Priority = Enum.AnimationPriority.Action4
	Animation:AdjustSpeed(Speed)

	RenderService:RenderForAllPlayers("Combat", "Kanji", { Character = Attacker })
	DebounceService:AddDebounce(Attacker, "UsingSkillCantAttack", 2.5)
	task.wait(0.25)

	if SkillService:GetSkillState(Attacker, "FloatingPassage") ~= "Charge" then
		FloatingPassage.Cancel(Attacker)
		return
	end

	FloatingPassage.Release(Attacker, Data)
end

function FloatingPassage.Release(Attacker: Model, Data: { any })
	SkillService:SetSkillData(Attacker, "FloatingPassage", "Release")
	WeaponService:SwordTrailsEnabled(Attacker, true)
	local Animation = AnimationService:GetAnimationFind(Attacker, "FloatingPassageRelease")
	if not Animation or not Animation.IsPlaying then
		FloatingPassage.Cancel(Attacker)
		return
	end
	local RootPart = Attacker:FindFirstChild("HumanoidRootPart")
	local VFX = Assets.FloatingPassage:Clone()
	VFX:PivotTo(
		RootPart:GetPivot() * CFrame.new(-0.126, -0.562, -2.254) * CFrame.Angles(0, math.rad(-180), math.rad(-15.14))
	)
	local Weld = Instance.new("WeldConstraint")
	Weld.Part0 = RootPart
	Weld.Part1 = VFX
	Weld.Parent = VFX
	ChangeColor(Attacker, VFX)
	local Current = 1
	VFX.Parent = workspace.VFX
	Animation:GetMarkerReachedSignal("StartHitbox"):Connect(function(duration)
		if Attacker:GetAttribute("PostureBreak") or Attacker:GetAttribute("Ragdoll") then
			FloatingPassage.Cancel(Attacker)
			return
		end

		if Current == 4 or Current == 5 then
			local BodyVelocity = Instance.new("BodyVelocity")
			BodyVelocity.MaxForce = Vector3.new(0, 1, 0) * 5000 * GetModelMass(Attacker)
			BodyVelocity.Velocity = Attacker:GetPivot().UpVector * (4.25 * Current)
			BodyVelocity.P = 850
			BodyVelocity.Parent = RootPart
			Debris:AddItem(BodyVelocity, 0.15)
			if Current == 5 then
				local AlignPosition = Instance.new("AlignPosition")
				AlignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
				AlignPosition.ForceLimitMode = Enum.ForceLimitMode.PerAxis
				AlignPosition.Attachment0 = RootPart.RootAttachment
				AlignPosition.MaxAxesForce = Vector3.new(0, 10 * GetModelMass(Attacker), 0)
				AlignPosition.Position = Attacker.Torso.Position
				AlignPosition.Responsiveness = 100
				AlignPosition.Parent = RootPart
				TweenService:Create(AlignPosition, TweenInfo.new(0.3), { Responsiveness = 5 }):Play()
				Debris:AddItem(AlignPosition, 0.3)
			end
		end
		RenderService:EmitParticles(VFX["A" .. Current])
		Current = Current + 1
		duration = duration + (duration - (duration * Speed))
		DebounceService:AddDebounce(Attacker, "Attack", duration)
		local Swing = SoundEffectService:CustomSwordWoosh(Attacker, "M1")
		SoundEffectService:AddPitchEffect(Swing, 0.9, 1.1)
		local HeavyDeflect = true
		local function Hitted(Character, hit)
			local Damage = DamageService:CalculateDamage(Attacker, Character, 5 + Current, { "Weapon" })
			task.delay(LagCompensationService:GetCompensation(Character), function()
				HitService:NormalHit(
					Character,
					Attacker,
					Damage,
					{ By = "Weapon", HeavyDeflect = (Current == 6 and HeavyDeflect) }
				)
			end)
		end
		task.wait(0.1)
		if Current == 5 or Current == 6 then
			HitboxService:CreatePartHitbox(Attacker, {
				Size = Vector3.new(15, 5.5, 13.5),
				CFrame = RootPart:GetPivot() * CFrame.new(0, -3, -7) * CFrame.Angles(math.rad(-35), 0, 0),
				Frames = 16,
				IgnoreCheck = true,
			}, Hitted)
		else
			HitboxService:CreatePartHitbox(
				Attacker,
				{ Size = Vector3.new(7.5, 7.5, 7.5), Frames = 16, IgnoreCheck = true },
				Hitted
			)
		end
	end)
	Animation.Ended:Connect(function()
		WeaponService:SwordTrailsEnabled(Attacker, false)
		SkillService:SetSkillData(Attacker, "FloatingPassage", nil)
	end)
	Debris:AddItem(VFX, 3)
end

function FloatingPassage.Cancel(Attacker)
	DebounceService:RemoveDebounce(Attacker, "FloatingPassageDebounce")
	DebounceService:RemoveDebounce(Attacker, "UsingSkillCantAttack")
	AnimationService:StopAnimationFind(Attacker, "FloatingPassageRelease")
end

function FloatingPassage.Caller(Attacker: Model, Data: { any })
	local StaminaCost = Attacker:GetAttribute("SwordStaminaCost") * 4
	if
		Validate:CanUseSkill(Attacker, StaminaCost)
		and Attacker:GetAttribute("WeaponEquipped")
		and not Attacker:GetAttribute("FloatingPassageDebounce")
	then
		DebounceService:AddDebounce(Attacker, "FloatingPassageDebounce", Debounce, true)

		StaminaService:RemoveStamina(Attacker, StaminaCost)
		task.spawn(function()
			FloatingPassage.Charge(Attacker, Data)
		end)

		return true
	end
	return false
end

function FloatingPassage.Start() end

return FloatingPassage
