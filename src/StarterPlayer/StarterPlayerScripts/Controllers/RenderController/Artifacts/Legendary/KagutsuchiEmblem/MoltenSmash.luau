local Debris = game:GetService("Debris")
local Knit = require(game.ReplicatedStorage.Packages.Knit)
local MoltenSmash = {}

local TweenService = game:GetService("TweenService")
local CraterModule = require(game.ReplicatedStorage.Assets.Libraries.CraterModule)

local RenderController
local CameraController
local SoundEffectController

local Player = game.Players.LocalPlayer

local Assets = game.ReplicatedStorage.Assets.VFX.Skills.KagutsuchiEmblem.MoltenSmash

function MoltenSmash.Charge(RenderData)
	SoundEffectController:PlaySoundEffect("MoltenSmashStart", true, RenderData.Character.PrimaryPart)
end

function MoltenSmash.Stomp(RenderData)
	local position: CFrame = RenderData.Position
	local size: Vector3 = RenderData.Size

	local casterRootCFrame = RenderData.RootCFrame
	local Character = Player.Character

	local Explosion = Assets.Explosion:Clone()

	local ExplosionCFrame = position * CFrame.new(0, -1.5, 0)
	for _, Part in RenderController:GetPartsWithParent(Explosion) do
		if Part:IsA("BasePart") then
			Part.Anchored = true
		end
	end
	Explosion:PivotTo(ExplosionCFrame)
	Explosion.Parent = workspace
	RenderController:EmitParticles(Explosion)

	local Distance = (Explosion:GetPivot().Position - Character:GetPivot().Position).Magnitude
	if Distance <= 32 then
		local Magnitude = (32 / Distance) / 1.5
		CameraController:ShakeOnce(Magnitude, 10, 0.5, 0.5)
	end
	SoundEffectController:PlaySoundEffect("MoltenSmashExplosion", true, Explosion)

	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = { workspace.Entity }
	local ray = workspace:Raycast(ExplosionCFrame.Position + Vector3.new(0, 1, 0), Vector3.new(0, -3, 0), Params)
	if ray then
		local Ground = Assets.Ground:Clone()
		for _, Part in RenderController:GetPartsWithParent(Ground) do
			Part.Anchored = true
		end
		Ground:PivotTo(CFrame.new(ray.Position) * CFrame.new(0, -1.5, 0))
		Ground.Parent = workspace
		Debris:AddItem(Ground.PointLight, 0.15)
		TweenService
			:Create(
				Ground.Crack,
				TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.In),
				{ Transparency = 1 }
			)
			:Play()
		Debris:AddItem(Ground, 2)
	end

	CraterModule:Spawn({
		Position = Explosion:GetPivot().Position, 
		AmountPerUnit = 1,
		Amount = 20,
		Angle = { 10, 30 },
		Radius = { 6, 7 }, 
		Size = { 2.5, 3 }, 

		Offset = {
			X = 0,
			Y = 0.5,
			Z = 0,
		},

		DespawnTime = 2,
	})

	CraterModule:ExplosionRocks({
		Position = ExplosionCFrame.Position, 
		Amount = 10,
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

		DebrisTemplate = game.ReplicatedStorage.Assets.VFX.Debris.OnFire,
		Trail = true,
		Direction = casterRootCFrame, 
		DespawnTime = 1,
	})

	Debris:AddItem(Explosion, 5)
end

function MoltenSmash.Hit(RenderData)
	local casterRootCFrame = RenderData.RootCFrame
	local FlashStrikeMultipleSlashes = game.ReplicatedStorage.VFX.Sword.FlashStrike.MultipleSlashes:Clone()
	FlashStrikeMultipleSlashes:PivotTo(casterRootCFrame)
	FlashStrikeMultipleSlashes.Parent = game.Workspace
	RenderController:EmitParticles(FlashStrikeMultipleSlashes.Main.Attachment)
	RenderController:EmitParticles(FlashStrikeMultipleSlashes.Stars)

	if RenderData.arguments.EmitDelayed then
		RenderController:EmitParticles(FlashStrikeMultipleSlashes.Main.DelayedHit)
	end

	Debris:AddItem(FlashStrikeMultipleSlashes, 5)
end

function MoltenSmash.Cancel(RenderData) end

function MoltenSmash.Start()
	RenderController = Knit.GetController("RenderController")
	CameraController = Knit.GetController("CameraController")
	SoundEffectController = Knit.GetController("SoundEffectController")
end

return MoltenSmash
