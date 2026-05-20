local DataStoreService = game:GetService("DataStoreService")
local Debris = game:GetService("Debris")
local Knit = require(game.ReplicatedStorage.Packages.Knit)
local Fireball = {}

local TweenService = game:GetService("TweenService")
local CraterModule = require(game.ReplicatedStorage.Assets.Libraries.CraterModule)

local RenderController
local CameraController
local SoundEffectController

local Player = game.Players.LocalPlayer

local PsychoRocks = require(game.ReplicatedStorage.Assets.Libraries.PsychoRocks)

local Assets = game.ReplicatedStorage.Assets.VFX.Skills.KagutsuchiEmblem.Fireball

function Fireball.Charge(RenderData)
	local Character = RenderData.Character
	local RootCFrame = RenderData.RootCFrame
	local Ball = RenderController:CreateInstance(Fireball, Character, Assets.Meteor:Clone())

	Ball:PivotTo(RootCFrame * CFrame.new(1, 1, 0))
	Ball:ScaleTo(0.3)
	Ball.Parent = workspace.VFX

	local RightArm = Character:FindFirstChild("Right Arm")
	local Cleanup
	if RightArm then
		Ball:PivotTo(RightArm.CFrame * CFrame.new(0, -1, 0))

		Cleanup = RenderController:RenderSteppedWeldConstraint(RightArm, Ball)
	end

	task.spawn(function()
		PsychoRocks:Spawn({
			Amount = 15,
			Shape = "Circle",
			Speed = { 6, 9 },
			Lifetime = { 0.4, 0.85 },
			RockSize = { 0.5, 0.9 },
			AreaSize = Vector3.new(8, 0, 8),
			Trail = false,
			CFrame = Character:GetPivot(),
			Inner = 2,
			Drop = true,
		})
	end)
	task.wait(0.65)

	if Cleanup then
		Cleanup()
	end

	local Meteor = Ball:FindFirstChild("Meteor")

	if not Meteor then
		return
	end

	SoundEffectController:PlaySoundEffect("FireballSpawn", true, Meteor)

	task.defer(function()
		RenderController:TweenModelScale(Ball, 1.25, TweenInfo.new(0.5))

		local UpTween = TweenService:Create(Meteor, TweenInfo.new(0.5), {
			CFrame = CFrame.new(Meteor.CFrame.Position) * CFrame.new(0, 5, 0) * CFrame.Angles(
				Meteor:GetPivot():ToOrientation()
			),
		})

		UpTween:Play()
		task.wait(0.5)
		UpTween:Cancel()
	end)
end

function Fireball.Release(RenderData)
	local Ball = RenderController:GetInstance(Fireball, RenderData.Character, "Meteor")
	print(Ball:GetChildren())
	local Meteor = Ball.Meteor

	RenderController:EmitParticles(Meteor.EmitHand)

	local GroundFireCFrame = RenderData.GroundFireCFrame

	TweenService:Create(Meteor, TweenInfo.new(0.5), {
		CFrame = GroundFireCFrame,
	}):Play()

	SoundEffectController:PlaySoundEffect("FireballMovement", true, Meteor)

	task.wait(0.5)
	RenderController:EmitParticles(Meteor.Explode)

	task.spawn(function()
		RenderController:TweenModelScale(Ball, 0.1, TweenInfo.new(0.5))

		task.delay(0.5, function()
			RenderController:DestroyInstance(Fireball, RenderData.Character, "Meteor")
		end)
	end)

	local GroundFire = Assets.GroundFire:Clone()
	GroundFire:PivotTo(GroundFireCFrame)
	GroundFire.Parent = workspace.VFX

	task.spawn(function()
		for i = 1, 3 do
			local Explosion = GroundFire.GroundFire.Impact[i]
			SoundEffectController:PlaySoundEffect("FireballExplosion", true, Explosion)
			task.wait(0.1)

			CraterModule:Spawn({
				Position = Explosion:GetPivot().Position,
				AmountPerUnit = 1,
				Amount = 20 * math.sqrt(i),
				Angle = { 10, 30 },
				Radius = { 6 * math.sqrt(i), 7 * math.sqrt(i) },
				Size = { 2.5 * math.sqrt(i), 3 * math.sqrt(i) },

				Offset = {
					X = 0,
					Y = 0.5,
					Z = 0,
				},

				DespawnTime = 2,
			})

			CraterModule:ExplosionRocks({
				Position = Explosion.Position,
				Amount = 10,
				Radius = {
					X = 2,
					Y = -2,
					Z = 2,
				},
				Size = { Vector3.one, Vector3.one },
				Force = {
					X = { -22, 22 },
					Y = { 15, 25 },
					Z = { -20, 20 },
				},

				DebrisTemplate = game.ReplicatedStorage.Assets.VFX.Debris.OnFire,
				Trail = true,
				Direction = RenderData.GroundFireCFrame,
				DespawnTime = 1,
			})
		end
	end)

	--RenderController:EmitParticles(GroundFire)

	RenderController.Render({
		Character = Player.Character,
		Position = GroundFireCFrame.Position,
		Module = "ShakeScreen",
		Effect = "Explosion",
		MaxDistance = 50,
		Duration = 0.1,
		Size = 20,
	})
end

function Fireball.Hit(RenderData) end

function Fireball.Cancel(RenderData)
	local Meteor = RenderController:GetInstance(Fireball, RenderData.Character, "Meteor")
	RenderController:DestroyInstance(Fireball, RenderData.Character, "Meteor")

	if Meteor then
		RenderController:TweenModelScale(Meteor, 0.1, TweenInfo.new(0.5))

		task.delay(0.5, function()
			Meteor:Destroy()
		end)
	end
end

function Fireball.Start()
	RenderController = Knit.GetController("RenderController")
	CameraController = Knit.GetController("CameraController")
	SoundEffectController = Knit.GetController("SoundEffectController")
end

return Fireball
