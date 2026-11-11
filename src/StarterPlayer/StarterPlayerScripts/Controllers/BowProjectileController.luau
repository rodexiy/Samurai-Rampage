local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BowConfig = require(ReplicatedStorage.Shared.BowConfig)
local BowRaycast = require(ReplicatedStorage.Shared.Utils.BowRaycast)
local FastCast = require(ReplicatedStorage.Assets.Libraries.FastCast)
local BowProjectileController = Knit.CreateController({ Name = "BowProjectileController" })

type Shot = { Arrow: BasePart, Trail: Trail, Cast: any? }
local Caster = FastCast.new()
local Shots: { [number]: Shot } = {}
local Container: Folder
local Template: BasePart

local function AddTrail(Arrow: BasePart): Trail
	local Attachments: { Attachment } = {}
	for _, Side in { -1, 1 } do
		local Attachment = Instance.new("Attachment")
		Attachment.Name = if Side < 0 then "ArrowTrailLeft" else "ArrowTrailRight"
		Attachment.Position = Vector3.new(Side * BowConfig.ArrowTrailWidth * 0.5, 0, Arrow.Size.Z * 0.5)
		Attachment.Parent = Arrow
		table.insert(Attachments, Attachment)
	end

	local Trail = Instance.new("Trail")
	Trail.Name = "ArrowTrail"
	Trail.Attachment0 = Attachments[1]
	Trail.Attachment1 = Attachments[2]
	Trail.Lifetime = BowConfig.ArrowTrailLifetime
	Trail.MinLength = 0.05
	Trail.FaceCamera = true
	Trail.LightEmission = 0.7
	Trail.Color = ColorSequence.new(Color3.fromRGB(235, 235, 235))
	Trail.Transparency = NumberSequence.new(0.25, 1)
	Trail.WidthScale = NumberSequence.new(1, 0)
	Trail.Parent = Arrow
	return Trail
end

local function Launch(Id: number, Shooter: Player, Origin: Vector3, Velocity: Vector3, Acceleration: Vector3)
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	local Excluded: { Instance } = { Container }
	if Shooter.Character then
		table.insert(Excluded, Shooter.Character)
	end
	local Effects = workspace:FindFirstChild("VFX")
	if Effects then
		table.insert(Excluded, Effects)
	end
	Params.FilterDescendantsInstances = Excluded

	local Behavior = FastCast.newBehavior()
	Behavior.Acceleration = Acceleration
	Behavior.MaxDistance = BowConfig.MaxDistance
	Behavior.RaycastParams = Params
	Behavior.CanPierceFunction = BowRaycast.CanPierce
	Behavior.CosmeticBulletTemplate = Template
	Behavior.CosmeticBulletContainer = Container
	local Cast = Caster:Fire(Origin, Velocity.Unit, Velocity, Behavior)
	Cast.UserData.Id = Id
	local Arrow = Cast.RayInfo.CosmeticBulletObject :: BasePart
	Arrow.CFrame = BowConfig.GetArrowCFrame(Origin, Velocity, Arrow.Size.Z)
	if Shooter == Players.LocalPlayer then
		local Highlight = Instance.new("Highlight")
		Highlight.Name = "OwnArrowHighlight"
		Highlight.Adornee = Arrow
		Highlight.FillColor = Color3.fromRGB(255, 40, 40)
		Highlight.OutlineColor = Color3.fromRGB(255, 40, 40)
		Highlight.FillTransparency = 0.5
		Highlight.OutlineTransparency = 0
		Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		Highlight.Parent = Arrow
	end
	local Shot: Shot = { Cast = Cast, Arrow = Arrow, Trail = AddTrail(Arrow) }
	Shots[Id] = Shot
	Debris:AddItem(Arrow, BowConfig.MaxFlightTime + 6)
	task.delay(BowConfig.MaxFlightTime + 6, function()
		if Shots[Id] == Shot then
			if Shot.Cast then
				Shot.Cast:Terminate()
			end
			Shots[Id] = nil
		end
	end)
end

function BowProjectileController.KnitStart()
	Container = Instance.new("Folder")
	Container.Name = "BowProjectiles"
	Container.Parent = workspace:FindFirstChild("VFX") or workspace
	Template = ReplicatedStorage.Assets.Models.Bow.Arrow:Clone() :: BasePart
	Template.Name = "Arrow"
	Template.Anchored = true
	Template.CanCollide = false
	Template.CanTouch = false
	Template.CanQuery = false
	Template.Massless = true
	Template.PivotOffset = CFrame.new(0, 0, -Template.Size.Z * 0.5)
	for _, Script in Template:QueryDescendants("LuaSourceContainer") do
		Script:Destroy()
	end

	Caster.LengthChanged:Connect(function(_Cast: any, LastPoint: Vector3, Direction: Vector3, Length: number, Velocity: Vector3, Arrow: BasePart?)
		if Arrow then
			local Facing = if Velocity.Magnitude > 0.001 then Velocity else Direction
			Arrow.CFrame = BowConfig.GetArrowCFrame(LastPoint + Direction * Length, Facing, Arrow.Size.Z)
		end
	end)
	Caster.CastTerminating:Connect(function(Cast: any)
		local Shot = Shots[Cast.UserData.Id]
		if Shot then
			Shot.Cast = nil
			Shot.Trail.Enabled = false
		end
	end)
	Knit.GetService("BowService").Projectile:Connect(function(Action: string, Id: number, ...: any)
		if Action == "Launch" then
			Launch(Id, ...)
		elseif Action == "Hit" then
			local Position, Velocity, HitPart = ...
			local Shot = Shots[Id]
			if Shot then
				Shot.Trail.Enabled = false
				if Shot.Cast then
					Shot.Cast:Terminate()
				end
				local Facing = if Velocity.Magnitude > 0.001 then Velocity else Shot.Arrow.CFrame.LookVector
				Shot.Arrow.CFrame = BowConfig.GetArrowCFrame(Position, Facing, Shot.Arrow.Size.Z)
				if HitPart and HitPart:IsA("BasePart") and not HitPart:IsA("Terrain") and HitPart:IsDescendantOf(workspace) then
					local Weld = Instance.new("WeldConstraint")
					Weld.Part0 = HitPart
					Weld.Part1 = Shot.Arrow
					Weld.Parent = Shot.Arrow
					Shot.Arrow.Anchored = false
				end
			end
		end
	end)
end

return BowProjectileController
