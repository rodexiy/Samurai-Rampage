local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BowConfig = require(ReplicatedStorage.Shared.BowConfig)
local RangedWeaponConfig = require(ReplicatedStorage.Shared.RangedWeaponConfig)
local BowRaycast = require(ReplicatedStorage.Shared.Utils.BowRaycast)
local FastCast = require(ReplicatedStorage.Assets.Libraries.FastCast)
local BowProjectileController = Knit.CreateController({ Name = "BowProjectileController" })

type Shot = {
	Arrow: BasePart, Trail: Trail, Cast: any?,
	IsFirearm: boolean, CleanupAt: number?,
}
local Caster = FastCast.new()
local Shots: { [number]: Shot } = {}
local Container: Folder
local Template: BasePart
local TracerTemplate: BasePart
local BirdController

local function DestroyShot(Id: number, Shot: Shot)
	if Shots[Id] ~= Shot then
		return
	end

	Shots[Id] = nil
	Shot.Arrow:Destroy()
end

local function FinishTracer(Id: number, Shot: Shot)
	local Deadline = os.clock() + Shot.Trail.Lifetime
	Shot.CleanupAt = Deadline
	task.delay(Shot.Trail.Lifetime, function()
		if Shot.CleanupAt == Deadline then
			DestroyShot(Id, Shot)
		end
	end)
end

local function AddTrail(Arrow: BasePart, Config: any): Trail
	local Width = if Config.IsFirearm then Config.TracerWidth else Config.ArrowTrailWidth
	local Attachments: { Attachment } = {}
	for _, Side in { -1, 1 } do
		local Attachment = Instance.new("Attachment")
		Attachment.Name = if Side < 0 then "ArrowTrailLeft" else "ArrowTrailRight"
		Attachment.Position = Vector3.new(Side * Width * 0.5, 0, Arrow.Size.Z * 0.5)
		Attachment.Parent = Arrow
		table.insert(Attachments, Attachment)
	end

	local Trail = Instance.new("Trail")
	Trail.Name = if Config.IsFirearm then "TanegashimaShotTrail" else "ArrowTrail"
	Trail.Attachment0 = Attachments[1]
	Trail.Attachment1 = Attachments[2]
	Trail.Lifetime = if Config.IsFirearm then Config.TracerLifetime else Config.ArrowTrailLifetime
	Trail.MaxLength = if Config.IsFirearm then Config.TracerLength else 0
	Trail.MinLength = 0.05
	Trail.FaceCamera = true
	Trail.LightEmission = if Config.IsFirearm then 1 else 0.7
	Trail.Color = ColorSequence.new(if Config.IsFirearm then Config.TracerColor else Color3.fromRGB(235, 235, 235))
	Trail.Transparency = NumberSequence.new(0.25, 1)
	Trail.WidthScale = NumberSequence.new(1, 0)
	Trail.Parent = Arrow
	return Trail
end

local function Launch(Id: number, Shooter: Player, Origin: Vector3, Velocity: Vector3, Acceleration: Vector3, _ServerTime: number, ItemName: string?)
	local Config = RangedWeaponConfig.Get(ItemName)
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	local Excluded = BowRaycast.GetExclusions(Shooter.Character)
	table.insert(Excluded, Container)
	Params.FilterDescendantsInstances = Excluded

	local Behavior = FastCast.newBehavior()
	Behavior.Acceleration = Acceleration
	Behavior.MaxDistance = Config.MaxDistance
	Behavior.RaycastParams = Params
	Behavior.CanPierceFunction = BowRaycast.CanPierce
	Behavior.CosmeticBulletTemplate = if Config.IsFirearm then TracerTemplate else Template
	Behavior.CosmeticBulletContainer = Container
	local Cast = Caster:Fire(Origin, Velocity.Unit, Velocity, Behavior)
	Cast.UserData.Id = Id
	local Arrow = Cast.RayInfo.CosmeticBulletObject :: BasePart
	Arrow.CFrame = BowConfig.GetArrowCFrame(Origin, Velocity, Arrow.Size.Z)
	if Shooter == Players.LocalPlayer and not Config.IsFirearm then
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
	local Shot: Shot = { Arrow = Arrow, Trail = AddTrail(Arrow, Config), Cast = Cast, IsFirearm = Config.IsFirearm }
	Shots[Id] = Shot
	Debris:AddItem(Arrow, Config.MaxFlightTime + 6)
	task.delay(Config.MaxFlightTime + 6, function()
		if Shots[Id] == Shot then
			if Shot.Cast then
				Shot.Cast:Terminate()
			end
			DestroyShot(Id, Shot)
		end
	end)
end

function BowProjectileController.KnitInit()
	BirdController = Knit.GetController("BirdController")
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

	TracerTemplate = Instance.new("Part")
	TracerTemplate.Name = "TanegashimaTracer"
	TracerTemplate.Size = Vector3.new(0.1, 0.1, 0.1)
	TracerTemplate.Transparency = 1
	TracerTemplate.Anchored = true
	TracerTemplate.CanCollide = false
	TracerTemplate.CanTouch = false
	TracerTemplate.CanQuery = false
	TracerTemplate.Massless = true

	Caster.LengthChanged:Connect(function(Cast: any, LastPoint: Vector3, Direction: Vector3, Length: number, Velocity: Vector3, Arrow: BasePart?)
		local Shot = Shots[Cast.UserData.Id]
		if Shot then
			BirdController:HitByProjectile(LastPoint, Direction * Length, Velocity)
		end

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
			if Shot.IsFirearm then
				FinishTracer(Cast.UserData.Id, Shot)
			end
		end
	end)
	Knit.GetService("BowService").Projectile:Connect(function(Action: string, Id: number, ...: any)
		if Action == "Launch" then
			Launch(Id, ...)
		elseif Action == "Hit" then
			local Position, Velocity, HitPart = ...
			local Shot = Shots[Id]
			if Shot then
				local Facing = if Velocity.Magnitude > 0.001 then Velocity else Shot.Arrow.CFrame.LookVector
				Shot.Arrow.CFrame = BowConfig.GetArrowCFrame(Position, Facing, Shot.Arrow.Size.Z)
				Shot.Trail.Enabled = false
				if Shot.Cast then
					Shot.Cast:Terminate()
				end
				if Shot.IsFirearm then
					FinishTracer(Id, Shot)
					return
				end
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
