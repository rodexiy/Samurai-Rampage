local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.DoorConfig)

local DoorImpactService = Knit.CreateService({ Name = "DoorImpactService", Client = {} })
local DamageService
local KnockbackService

type Motion = { Frame: CFrame, Linear: Vector3, Angular: Vector3, Center: Vector3 }
type FlyingDoor = {
	Door: Model,
	Attacker: Model,
	Root: BasePart,
	Hitbox: Part,
	Motion: Motion,
	HitCharacters: { [Model]: boolean },
	Age: number,
	IdleTime: number,
	DestroyConnection: RBXScriptConnection?,
}

local Active: { [Model]: FlyingDoor } = {}
local Targets: { Model } = {}
local TargetMotions: { [Model]: Motion } = {}
local PreConnection: RBXScriptConnection?
local PostConnection: RBXScriptConnection?

local function Capture(Root: BasePart, Frame: CFrame): Motion
	return {
		Frame = Frame,
		Linear = Root.AssemblyLinearVelocity,
		Angular = Root.AssemblyAngularVelocity,
		Center = Root.AssemblyCenterOfMass,
	}
end

local function VelocityAt(MotionData: Motion, Point: Vector3): Vector3
	return MotionData.Linear + MotionData.Angular:Cross(Point - MotionData.Center)
end

local function GetCharacter(Part: BasePart): Model?
	local Object: Instance? = Part.Parent
	while Object and Object ~= workspace do
		if Object:IsA("Model") and Object:FindFirstChildWhichIsA("Humanoid") then
			return Object
		end
		Object = Object.Parent
	end
	return nil
end

local function OverlapContact(Frame: CFrame, Size: Vector3, Position: Vector3): (Vector3, Vector3)
	local LocalPosition = Frame:PointToObjectSpace(Position)
	local Half = Size / 2
	local Closest = Vector3.new(
		math.clamp(LocalPosition.X, -Half.X, Half.X),
		math.clamp(LocalPosition.Y, -Half.Y, Half.Y),
		math.clamp(LocalPosition.Z, -Half.Z, Half.Z)
	)
	local Offset = LocalPosition - Closest
	local Normal = if Offset.Magnitude > 0.001 then Frame:VectorToWorldSpace(Offset.Unit) else Vector3.zero
	return Frame:PointToWorldSpace(Closest), Normal
end

function DoorImpactService:Stop(Door: Model)
	local State = Active[Door]
	if not State then
		return
	end
	Active[Door] = nil
	if State.DestroyConnection then
		State.DestroyConnection:Disconnect()
	end
	State.Hitbox:Destroy()

	if next(Active) == nil then
		if PreConnection then
			PreConnection:Disconnect()
			PreConnection = nil
		end
		if PostConnection then
			PostConnection:Disconnect()
			PostConnection = nil
		end
		table.clear(Targets)
		table.clear(TargetMotions)
	end
end

function DoorImpactService:CaptureMotion()
	table.clear(Targets)
	table.clear(TargetMotions)
	for _, Object in CollectionService:GetTagged("Entity") do
		if
			Object:IsA("Model")
			and Object:IsDescendantOf(workspace)
			and Object.PrimaryPart
			and Object:FindFirstChildWhichIsA("Humanoid")
		then
			table.insert(Targets, Object)
			TargetMotions[Object] = Capture(Object.PrimaryPart, Object.PrimaryPart.CFrame)
		end
	end
	for _, State in Active do
		if State.Root.Parent and State.Hitbox.Parent then
			State.Motion = Capture(State.Root, State.Hitbox.CFrame)
		end
	end
end

local function CanHit(State: FlyingDoor, Character: Model): boolean
	local Root = Character.PrimaryPart
	return Character ~= State.Attacker
		and not State.HitCharacters[Character]
		and Root ~= nil
		and not Root.Anchored
		and Character:IsDescendantOf(workspace)
		and Character.Parent ~= workspace.NPCs
		and not Character:GetAttribute("InCell")
		and not Character:GetAttribute("InLabor")
		and not Character:GetAttribute("RollIFrame")
		and DamageService:CanDamage(Character, State.Attacker)
end

function DoorImpactService:TryImpact(
	State: FlyingDoor,
	Character: Model,
	Frame: CFrame,
	Point: Vector3,
	Normal: Vector3
): boolean
	if not CanHit(State, Character) then
		return false
	end
	local TargetRoot = Character.PrimaryPart :: BasePart
	local BeforePoint = State.Motion.Frame:PointToWorldSpace(Frame:PointToObjectSpace(Point))
	local DoorVelocity = VelocityAt(State.Motion, BeforePoint)
	if DoorVelocity.Magnitude < Config.ImpactStopSpeed then
		return false
	end
	local TargetMotion = TargetMotions[Character] or Capture(TargetRoot, TargetRoot.CFrame)
	local TargetPoint = TargetMotion.Frame:PointToWorldSpace(TargetRoot.CFrame:PointToObjectSpace(Point))
	local RelativeVelocity = DoorVelocity - VelocityAt(TargetMotion, TargetPoint)
	local Speed = if Normal.Magnitude > 0.001 then RelativeVelocity:Dot(Normal.Unit) else RelativeVelocity.Magnitude
	if Speed < Config.ImpactMinSpeed or RelativeVelocity.Magnitude <= 0.001 then
		return false
	end

	local Travel = Point - BeforePoint
	if Travel.Magnitude > 0.001 then
		local Params = RaycastParams.new()
		Params.FilterType = Enum.RaycastFilterType.Exclude
		Params.FilterDescendantsInstances = { State.Door, State.Attacker, Character }
		Params.RespectCanCollide = true
		if workspace:Raycast(BeforePoint, Travel, Params) then
			return false
		end
	end

	State.HitCharacters[Character] = true
	local Velocity = RelativeVelocity.Unit * math.min(Speed * Config.KnockbackImpulse, Config.ImpactMaxKnockbackSpeed)
	task.spawn(function()
		if Character.Parent then
			KnockbackService:FlingWithVelocity(Character, Velocity)
		end
	end)
	return true
end

function DoorImpactService:CheckCollision(State: FlyingDoor, DeltaTime: number)
	if #Targets == 0 then
		return
	end
	local Previous = State.Motion.Frame
	local Current = State.Hitbox.CFrame
	local Delta = Current.Position - Previous.Position
	local Size = State.Hitbox.Size
	local Radius = Size.Magnitude / 2
	local BroadSize = Vector3.new(math.abs(Delta.X), math.abs(Delta.Y), math.abs(Delta.Z)) + Vector3.one * Radius * 2
	local Params = OverlapParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = Targets
	local Candidates: { [Model]: boolean } = {}
	for _, Part in
		workspace:GetPartBoundsInBox(CFrame.new((Previous.Position + Current.Position) / 2), BroadSize, Params)
	do
		local Character = GetCharacter(Part)
		if Character and CanHit(State, Character) then
			Candidates[Character] = true
		end
	end
	if next(Candidates) == nil then
		return
	end

	local _, Angle = Previous:ToObjectSpace(Current):ToAxisAngle()
	local Rotation = math.max(math.abs(Angle), State.Motion.Angular.Magnitude * DeltaTime)
	local Steps = math.clamp(math.ceil(Rotation / math.rad(Config.ImpactRotationStep)), 1, Config.ImpactMaxSubsteps)
	for Character in Candidates do
		local Overlap = OverlapParams.new()
		Overlap.FilterType = Enum.RaycastFilterType.Include
		Overlap.FilterDescendantsInstances = { Character }
		local Cast = RaycastParams.new()
		Cast.FilterType = Enum.RaycastFilterType.Include
		Cast.FilterDescendantsInstances = { Character }
		for Index = 0, Steps do
			local Frame = Previous:Lerp(Current, Index / Steps)
			local Overlaps = workspace:GetPartBoundsInBox(Frame, Size, Overlap)
			if #Overlaps > 0 then
				local Point, Normal = OverlapContact(Frame, Size, Overlaps[1].Position)
				if self:TryImpact(State, Character, Frame, Point, Normal) then
					break
				end
			end
			if Index < Steps then
				local EndFrame = Previous:Lerp(Current, (Index + 1) / Steps)
				local Movement = EndFrame.Position - Frame.Position
				if Movement.Magnitude > 0.001 then
					local Hit = workspace:Blockcast(Frame, Size, Movement, Cast)
					if Hit then
						local ImpactFrame = Frame + Movement.Unit * Hit.Distance
						if self:TryImpact(State, Character, ImpactFrame, Hit.Position, -Hit.Normal) then
							break
						end
					end
				end
			end
		end
	end
end

function DoorImpactService:Step(DeltaTime: number)
	for Door, State in Active do
		if not Door.Parent or not State.Root.Parent or not State.Hitbox.Parent then
			self:Stop(Door)
			continue
		end
		State.Age += DeltaTime
		local Speed = math.max(State.Root.AssemblyLinearVelocity.Magnitude, State.Motion.Linear.Magnitude)
			+ math.max(State.Root.AssemblyAngularVelocity.Magnitude, State.Motion.Angular.Magnitude)
				* State.Hitbox.Size.Magnitude
				/ 2
		State.IdleTime = if Speed < Config.ImpactStopSpeed then State.IdleTime + DeltaTime else 0
		if State.Age >= Config.DebrisLifetime or State.IdleTime >= Config.ImpactStopDelay then
			self:Stop(Door)
		else
			self:CheckCollision(State, DeltaTime)
		end
	end
end

function DoorImpactService:Track(Door: Model, Attacker: Model)
	self:Stop(Door)
	local Root = Door.PrimaryPart
	if not Root then
		return
	end
	local Bounds, Size = Door:GetBoundingBox()
	local Hitbox = Instance.new("Part")
	Hitbox.Name = "DoorImpactHitbox"
	Hitbox.Size = Size
	Hitbox.CFrame = Bounds
	Hitbox.Transparency = 1
	Hitbox.CanCollide = false
	Hitbox.CanTouch = false
	Hitbox.CanQuery = false
	Hitbox.Massless = true
	Hitbox.RootPriority = -127
	Hitbox.Parent = Door
	local Weld = Instance.new("WeldConstraint")
	Weld.Part0 = Root
	Weld.Part1 = Hitbox
	Weld.Parent = Hitbox
	local State: FlyingDoor = {
		Door = Door,
		Attacker = Attacker,
		Root = Root,
		Hitbox = Hitbox,
		Motion = Capture(Root, Bounds),
		HitCharacters = {},
		Age = 0,
		IdleTime = 0,
	}
	Active[Door] = State
	State.DestroyConnection = Door.Destroying:Connect(function()
		self:Stop(Door)
	end)
	if not PreConnection then
		PreConnection = RunService.PreSimulation:Connect(function()
			self:CaptureMotion()
		end)
		PostConnection = RunService.PostSimulation:Connect(function(DeltaTime: number)
			self:Step(DeltaTime)
		end)
	end
end

function DoorImpactService.KnitInit()
	DamageService = Knit.GetService("DamageService")
	KnockbackService = Knit.GetService("KnockbackService")
end

return DoorImpactService
