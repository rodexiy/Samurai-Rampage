local Debris = game:GetService("Debris")
local Knit = require(game.ReplicatedStorage.Packages.Knit)
local ThunderWrath = {}

local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local CraterModule = require(game.ReplicatedStorage.Assets.Libraries.CraterModule)

local RenderController
local CameraController
local SoundEffectController

local Player = game.Players.LocalPlayer

local Assets = game.ReplicatedStorage.Assets.VFX.Skills.ThunderHeart

local LightningBolt = require(game.ReplicatedStorage.Assets.Libraries.LightningBolt)
local LightningSparks = require(game.ReplicatedStorage.Assets.Libraries.LightningBolt.LightningSparks)

function ThunderWrath.Charge(RenderData)
	SoundEffectController:PlaySoundEffect("MoltenSmashStart", true, RenderData.Character.PrimaryPart)
end

local SkillFolder = game.ReplicatedStorage.Assets.VFX.Skills.ThunderHeart

function ThunderWrath.Strike(RenderData)
	local End = CFrame.new(RenderData.End)
	local Start = CFrame.new(RenderData.End + Vector3.new(0, 20, 0))

	local Clouds = SkillFolder.ThunderWrathClouds:Clone()

	local OriginalSize = {}
	for _, Cloud in Clouds:GetDescendants() do
		if Cloud:IsA("BasePart") then
			OriginalSize[Cloud] = Cloud.Size
			Cloud.Size = Vector3.zero

			local Highlight = Instance.new("Highlight")
			Highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			Highlight.FillTransparency = 1
			Highlight.OutlineColor = Color3.fromRGB(124, 213, 255)
			Highlight.OutlineTransparency = 0.35
			Highlight.Parent = Cloud
		end
	end
	Clouds:PivotTo(Start)
	Clouds.Parent = workspace.VFX

	task.spawn(function()
		for _, Cloud in Clouds:GetDescendants() do
			if Cloud:IsA("BasePart") then
				task.spawn(function()
					for i = 0, 6 do
						local Size = OriginalSize[Cloud]
						Size = OriginalSize[Cloud] * (math.random(90, 110) / 100)

						local Time = math.random(25, 50) / 100

						local Offset = CFrame.new(Cloud.Position, Start.Position).LookVector

						TweenService
							:Create(Cloud, TweenInfo.new(Time, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
								Size = Size,
								Position = Start.Position
									+ Vector3.new(0, (Size.Y / 2) + 5, 0)
									- ((Offset * (Size.Y / 2)) / 2),
							})
							:Play()

						task.wait(Time)
					end

					TweenService:Create(
						Cloud,
						TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
						{ Size = Vector3.zero }
					):Play()
				end)
			end
		end
	end)

	local FloorVFX = Assets.Floor:Clone()
	FloorVFX:PivotTo(CFrame.new(End.Position))
	FloorVFX.Parent = workspace.VFX

	RenderController:EmitParticles(FloorVFX)

	Debris:AddItem(FloorVFX, 2)

	task.wait(0.75)

	RenderController:RenderParticles("ShakeScreen", "Explosion", {
		Character = Player.Character,
		Position = Start.Position,
		Duration = 1,
		Size = 5,
		MaxDistance = 120,
	})

	local VFX = Assets.ThunderWrath:Clone()
	VFX:PivotTo(End * CFrame.new(0, -0.75, 0))
	VFX.Parent = workspace.VFX

	RenderController:EmitParticles(VFX)

	local A1 = Instance.new("Attachment")
	A1.Parent = workspace.LightningHandler.PrimaryPart
	A1.WorldCFrame = Start * CFrame.new(0, 8, 0)

	local A2 = Instance.new("Attachment")
	A2.Parent = workspace.LightningHandler.PrimaryPart
	A2.WorldCFrame = End

	local amount = 5
	for i = 1, amount do
		local NewBolt = LightningBolt.new(A1, A2, 10)
		NewBolt.PulseSpeed = 15
		NewBolt.PulseLength = 20
		NewBolt.Thickness = 0.5
		NewBolt.FadeLength = 3
		NewBolt.AnimationSpeed = 10
		NewBolt.MinRadius = ((4 * amount) / (i + 1))
		NewBolt.MaxRadius = ((5 * amount) / (i + 1))
		NewBolt.Frequency = 5
		NewBolt.Color = Color3.fromRGB(0, 162, 255)

		if i == 3 then
			NewBolt.Color = Color3.fromRGB(255, 255, 255)
		end

		LightningSparks.new(NewBolt)
	end

	local CraterPosition = End.Position + Vector3.new(0, 1, 0)

	CraterModule:Spawn({
		Position = CraterPosition,
		AmountPerUnit = 1,
		Amount = 20,
		Angle = { 0, 360 },
		Radius = { 6, 7 },
		Size = { 2.5, 4 },

		Offset = {
			X = 0,
			Y = 0,
			Z = 0,
		},

		DespawnTime = 5,
	})

	for i = 1, 3 do
		CraterModule:ExplosionRocks({
			Position = CraterPosition, --> Position;
			Amount = 7, --> Amount of Rocks;
			Radius = {
				X = 2,
				Y = -2,
				Z = 2,
			},
			Size = { Vector3.one / 1.5, Vector3.one },
			Force = {
				X = { -45, 45 },
				Y = { 30, 50 },
				Z = { -45, 45 },
			},

			Trail = true,
			DespawnTime = 3,
		})

		task.wait(0.33)
	end

	Debris:AddItem(A1, 2)
	Debris:AddItem(VFX, 5)
	Debris:AddItem(Clouds, 5)

	Debris:AddItem(A2, 2)
end

function ThunderWrath.Start()
	RenderController = Knit.GetController("RenderController")
	CameraController = Knit.GetController("CameraController")
	SoundEffectController = Knit.GetController("SoundEffectController")
end

return ThunderWrath
