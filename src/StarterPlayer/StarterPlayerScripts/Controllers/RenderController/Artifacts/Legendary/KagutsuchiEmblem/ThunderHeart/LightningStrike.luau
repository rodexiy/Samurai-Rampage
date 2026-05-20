local Debris = game:GetService("Debris")
local Knit = require(game.ReplicatedStorage.Packages.Knit)
local LightningStrike = {}

local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local CraterModule = require(game.ReplicatedStorage.Assets.Libraries.CraterModule)

local RenderController
local CameraController
local SoundEffectController

local Player = game.Players.LocalPlayer

local Assets = game.ReplicatedStorage.Assets.VFX.Skills.KagutsuchiEmblem.MoltenSmash

local LightningBolt = require(game.ReplicatedStorage.Assets.Libraries.LightningBolt)
local LightningSparks = require(game.ReplicatedStorage.Assets.Libraries.LightningBolt.LightningSparks)

function LightningStrike.Charge(RenderData)
	SoundEffectController:PlaySoundEffect("MoltenSmashStart", true, RenderData.Character.PrimaryPart)
end

local MiscFolder = game.ReplicatedStorage.Assets.VFX.Misc
local SkillFolder = game.ReplicatedStorage.Assets.VFX.Skills.ThunderHeart

function LightningStrike.Teleport(RenderData)
	local CharacterToRender = RenderData.Character
	local Start = RenderData.Start
	local End = RenderData.End

	local A1 = Instance.new("Attachment")
	A1.Parent = workspace.LightningHandler.PrimaryPart
	A1.WorldCFrame = Start

	local A2 = Instance.new("Attachment")
	A2.Parent = workspace.LightningHandler.PrimaryPart
	A2.WorldCFrame = CharacterToRender.HumanoidRootPart.CFrame

	local NewBolt = LightningBolt.new(A1, A2, 50)
	NewBolt.PulseSpeed = 20
	NewBolt.PulseLength = 2
	NewBolt.Thickness = 1
	NewBolt.FadeLength = 1
	NewBolt.AnimationSpeed = 20
	NewBolt.Frequency = 5
	NewBolt.Color = Color3.fromRGB(255, 255, 0)

	LightningSparks.new(NewBolt)

	local Lightning = MiscFolder.DashLightning:Clone()
	local Distance = (Start.Position - End.Position).Magnitude

	local MiddleCFrame = CFrame.new(Start.Position, End.Position)
		* CFrame.new(0, 0, -Distance / 2)
		* CFrame.Angles(0, math.rad(90), 0)
	Lightning.Size = Vector3.new(Distance, 3, 3)
	Lightning.Attach.Position = Lightning.Size / 2

	Lightning.CFrame = MiddleCFrame
	Lightning.Anchored = true
	Lightning.Parent = workspace.VFX
	RenderController:EmitParticles(Lightning)
	Debris:AddItem(Lightning, 2)
	Debris:AddItem(A1, 2)
	Debris:AddItem(A2, 2)

	local Sound = SoundEffectController:PlaySoundEffect("LightningTp", true, CharacterToRender.HumanoidRootPart)
	SoundEffectController:AddPitchEffect(Sound, 0.9, 1.1)
end

function LightningStrike.Strike(RenderData)
	local HitPosition = RenderData.HitPosition
	local VFX = SkillFolder.LightningStrike:Clone()

	VFX:PivotTo(CFrame.new(HitPosition) * CFrame.new(0, 7.35, 0))
	VFX.Parent = workspace.VFX
	RenderController:EmitParticles(VFX)

	RenderController:RenderParticles("ShakeScreen", "Explosion", {
		Character = Player.Character,
		Position = HitPosition,
		Size = 5,
	})

	local CraterPosition = HitPosition + Vector3.new(0, 3, 0)
	CraterModule:Spawn({
		Position = CraterPosition, --> Position
		AmountPerUnit = 1, --> Amount of Rocks Per Unit (1 would appear a single rock per angle step.)
		Amount = 20, --> Amount of rocks that will exist in the circle. (360 / Amount)
		Angle = { 10, 30 }, --> Random Angles (Y) axis.
		Radius = { 6, 7 }, --> Random Radius;
		Size = { 2.5, 3 }, --> Random Size (number only);

		Offset = {
			X = 0,
			Y = 0.5,
			Z = 0,
		}, --> Random offset (Y);

		DespawnTime = 2, --> Despawn Time
	})

	CraterModule:ExplosionRocks({
		Position = CraterPosition, --> Position;
		Amount = 10, --> Amount of Rocks;
		Radius = {
			X = 2,
			Y = -2,
			Z = 2,
		},
		Size = { Vector3.one, Vector3.one },
		Force = {
			X = { -45, 45 },
			Y = { 30, 50 },
			Z = { -45, 45 },
		},

		Trail = true, --> Enable / Disable
		DespawnTime = 1, --> Despawn Time.
	})

	Debris:AddItem(VFX, 3)
end

function LightningStrike.Start()
	RenderController = Knit.GetController("RenderController")
	CameraController = Knit.GetController("CameraController")
	SoundEffectController = Knit.GetController("SoundEffectController")
end

return LightningStrike
