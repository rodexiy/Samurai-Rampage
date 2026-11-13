local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

local HorseConfig = require(ReplicatedStorage.Shared.HorseConfig)
local Settings = HorseConfig.Grounding
local HorseGrounding = {}

local function MinimumNormal(): number
	return math.max(HorseConfig.MinimumGroundNormal, math.cos(Settings.MaximumSlope))
end

function HorseGrounding.IsWalkable(Normal: Vector3): boolean
	return Normal.Y >= MinimumNormal()
end

function HorseGrounding.IsSupportable(Normal: Vector3): boolean
	return Normal.Y >= math.cos(Settings.MaximumSupportSlope)
end

local function GetBodyUp(Root: BasePart): Vector3
	local Up = Root.CFrame.UpVector
	return if Up.Y >= 0.25 then Up else Vector3.yAxis
end

export type State = {
	Model: Model,
	Root: BasePart,
	Vertical: LinearVelocity,
	Orientation: AlignOrientation,
	Params: RaycastParams,
	ObstacleParams: RaycastParams,
	Clearance: number,
	HalfWidth: number,
	HalfLength: number,
	Heading: Vector3,
	PlanePoint: Vector3,
	Normal: Vector3,
	VisualNormal: Vector3,
	SurfaceVelocity: Vector3,
	Support: BasePart?,
	SupportPoint: Vector3?,
	SupportNormal: Vector3?,
	SupportVisualNormal: Vector3?,
	LastProbePosition: Vector3,
	LastMovementFrame: CFrame,
	BodyFloorHeight: number,
	HistoryPoint: Vector3?,
	HistoryNormal: Vector3?,
	HistoryTime: number,
	Elapsed: number,
	Grounded: boolean,
}

function HorseGrounding.HorizontalDirection(Direction: Vector3): Vector3
	local Horizontal = Direction * Vector3.new(1, 0, 1)
	return if Horizontal.Magnitude > 0.001 then Horizontal.Unit else -Vector3.zAxis
end

function HorseGrounding.GetRotation(Heading: Vector3, Normal: Vector3, Bracing: boolean?): CFrame
	local Frame = CFrame.lookAt(Vector3.zero, HorseGrounding.HorizontalDirection(Heading))
	local PitchLimit = if Bracing then Settings.MaximumSupportSlope else Settings.MaximumPitch
	local RollLimit = if Bracing then Settings.MaximumSupportSlope else Settings.MaximumRoll
	local Pitch = math.clamp(-math.atan2(Normal:Dot(Frame.LookVector), Normal.Y), -PitchLimit, PitchLimit)
	local Roll = math.clamp(-math.atan2(Normal:Dot(Frame.RightVector), Normal.Y), -RollLimit, RollLimit)

	return Frame * CFrame.Angles(Pitch, 0, Roll)
end

function HorseGrounding.GetHeight(Position: Vector3, PlanePoint: Vector3, Normal: Vector3, Clearance: number, Up: Vector3?): number
	local VerticalNormal = math.max(Normal.Y, math.cos(Settings.MaximumSupportSlope))
	local GroundY = PlanePoint.Y - ((Position.X - PlanePoint.X) * Normal.X + (Position.Z - PlanePoint.Z) * Normal.Z) / VerticalNormal

	-- Use the current body tilt rather than instantly lifting to the final slope pose.
	return GroundY + Clearance * math.max(0.5, (Up or Normal):Dot(Normal)) / VerticalNormal
end

function HorseGrounding.Create(Model: Model): State?
	local Root = Model.PrimaryPart
	local Clearance = Model:GetAttribute("GroundClearance")
	local HalfWidth = Model:GetAttribute("GroundHalfWidth")
	local HalfLength = Model:GetAttribute("GroundHalfLength")
	if not Root or typeof(Clearance) ~= "number" or typeof(HalfWidth) ~= "number" or typeof(HalfLength) ~= "number" then
		return nil
	end

	local Vertical = Root:FindFirstChild("MountGroundVelocity") :: LinearVelocity?
	local Orientation = Root:FindFirstChild("MountOrientation") :: AlignOrientation?
	if not Vertical or not Orientation then
		return nil
	end

	local Filter: { Instance } = { Model }
	for _, Name in { "Horses", "Entity" } do
		local Folder = workspace:FindFirstChild(Name)
		if Folder then
			table.insert(Filter, Folder)
		end
	end
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = Filter
	Params.RespectCanCollide = true
	-- The probes must see the floor even though the horse's collision group ignores it.
	Params.CollisionGroup = "Default"
	local ObstacleParams = RaycastParams.new()
	ObstacleParams.FilterType = Enum.RaycastFilterType.Exclude
	ObstacleParams.FilterDescendantsInstances = Filter
	ObstacleParams.RespectCanCollide = true
	ObstacleParams.CollisionGroup = if PhysicsService:IsCollisionGroupRegistered(Settings.ObstacleQueryGroup)
		then Settings.ObstacleQueryGroup else "Default"

	return {
		Model = Model, Root = Root, Vertical = Vertical, Orientation = Orientation, Params = Params, ObstacleParams = ObstacleParams,
		Clearance = Clearance, HalfWidth = HalfWidth, HalfLength = HalfLength,
		Heading = HorseGrounding.HorizontalDirection(Root.CFrame.LookVector), PlanePoint = Vector3.zero,
		Normal = Vector3.yAxis, VisualNormal = Vector3.yAxis, SurfaceVelocity = Vector3.zero, Elapsed = Settings.ProbeInterval,
		LastProbePosition = Root.Position - GetBodyUp(Root) * Clearance, HistoryTime = -math.huge,
		LastMovementFrame = Root.CFrame,
		BodyFloorHeight = -math.huge,
		Grounded = false,
	}
end

function HorseGrounding.Reset(State: State)
	State.Heading = HorseGrounding.HorizontalDirection(State.Root.CFrame.LookVector)
	State.Elapsed = Settings.ProbeInterval
	State.Grounded = false
	State.Support = nil
	State.SupportPoint = nil
	State.SupportNormal = nil
	State.SupportVisualNormal = nil
	State.LastProbePosition = State.Root.Position - GetBodyUp(State.Root) * State.Clearance
	State.LastMovementFrame = State.Root.CFrame
	State.BodyFloorHeight = -math.huge
end

local function CastSurface(State: State, Point: Vector3, Rise: number, Drop: number, Recovery: boolean): RaycastResult?
	local Origin = Point + Vector3.yAxis * Rise
	local Bottom = Point.Y - Drop
	local Best: RaycastResult? = nil
	local ReferenceY: number? = nil
	if Recovery and State.HistoryPoint and State.HistoryNormal and os.clock() - State.HistoryTime < 1 then
		local Travel = (Point - State.HistoryPoint) * Vector3.new(1, 0, 1)
		if Travel.Magnitude <= Settings.RecoveryTravel then
			ReferenceY = State.HistoryPoint.Y
				- (Travel.X * State.HistoryNormal.X + Travel.Z * State.HistoryNormal.Z) / State.HistoryNormal.Y
		end
	end

	-- Skip invalid faces/upper layers; a ceiling must not hide the floor below it.
	for _ = 1, if Recovery then 6 else 3 do
		local Hit = workspace:Raycast(Origin, -Vector3.yAxis * (Origin.Y - Bottom), State.Params)
		if not Hit or Hit.Material == Enum.Material.Water then
			break
		end

		if HorseGrounding.IsSupportable(Hit.Normal) then
			if not Recovery then
				return Hit
			end
			local AboveFeet = Hit.Position.Y > Point.Y + Settings.PenetrationTolerance
			local BelowCeiling = not ReferenceY or Hit.Position.Y <= ReferenceY + Settings.StepHeight
			if AboveFeet and BelowCeiling and (not Best or Hit.Position.Y < Best.Position.Y) then
				Best = Hit
			end
		end

		local NextY = Hit.Position.Y - 0.05
		if NextY >= Origin.Y - 0.001 or NextY <= Bottom then
			break
		end
		Origin = Vector3.new(Point.X, NextY, Point.Z)
	end

	return Best
end

local function GetBodySupport(State: State, Position: Vector3, Point: Vector3, Normal: Vector3): number
	local Frame, Size = State.Root.CFrame, State.Root.Size
	local Radius = (math.abs(Frame.RightVector:Dot(Normal)) * Size.X
		+ math.abs(Frame.UpVector:Dot(Normal)) * Size.Y + math.abs(Frame.LookVector:Dot(Normal)) * Size.Z) * 0.5
	local GroundY = HorseGrounding.GetHeight(Position, Point, Normal, 0)
	local BodyHeight = GroundY + (Radius + Settings.ObstacleSkin) / math.max(Normal.Y, math.cos(Settings.MaximumSupportSlope))

	return math.max(BodyHeight, State.BodyFloorHeight,
		HorseGrounding.GetHeight(Position, Point, Normal, State.Clearance, GetBodyUp(State.Root)))
end

local function GetBaseSurface(State: State, Point: Vector3, Hit: RaycastResult, Drop: number): RaycastResult
	local Tolerance = math.min(Settings.PenetrationTolerance, Settings.ObstacleSkin * 0.1)
	if State.Grounded and Hit.Normal:Dot(State.Normal) > 0.98
		and math.abs((Hit.Position - State.PlanePoint):Dot(State.Normal)) <= Tolerance then
		return Hit
	end

	local Offset = State.Heading * (Settings.StepOverLength * 0.5 + Settings.ObstacleSkin)
	local Front = CastSurface(State, Point + Offset, Settings.StepHeight, Drop + Settings.StepOverHeight, false)
	local Back = CastSurface(State, Point - Offset, Settings.StepHeight, Drop + Settings.StepOverHeight, false)
	if not Front or not Back or Front.Normal:Dot(Back.Normal) < 0.98 then
		return Hit
	end
	if math.abs((Front.Position - Back.Position):Dot(Back.Normal)) > Settings.PlaneTolerance then
		return Hit
	end

	local BaseY = HorseGrounding.GetHeight(Hit.Position, Back.Position, Back.Normal, 0)
	local Rise = Hit.Position.Y - BaseY
	if Rise > Tolerance and Rise <= Settings.StepOverHeight then
		-- A small object between two coherent floor samples belongs to the footstep, not the body suspension.
		return Back
	end

	return Hit
end

local function GetBodyFloorHeight(State: State): number
	local Root = State.Root
	local Height = -math.huge
	for _, X in { -1, 1 } do
		for _, Z in { -1, 1 } do
			local Corner = Root.CFrame:PointToWorldSpace(Vector3.new(
				Root.Size.X * X * 0.5, -Root.Size.Y * 0.5, Root.Size.Z * Z * 0.5))
			local Hit = CastSurface(State, Corner, Settings.StepHeight, Settings.DropDistance, false)
			if Hit then
				Hit = GetBaseSurface(State, Corner, Hit, Settings.DropDistance)
				local Clearance = Settings.ObstacleSkin / math.max(Hit.Normal.Y, math.cos(Settings.MaximumSupportSlope))
				Height = math.max(Height, Root.Position.Y + Hit.Position.Y + Clearance - Corner.Y)
			end
		end
	end

	return Height
end

local function FindFootSupport(State: State, CatchDistance: number): RaycastResult?
	local First: RaycastResult? = nil
	local Count = 0
	for _, Offset in {
		Vector3.new(-State.HalfWidth, -State.Clearance, -State.HalfLength),
		Vector3.new(State.HalfWidth, -State.Clearance, -State.HalfLength),
		Vector3.new(-State.HalfWidth, -State.Clearance, State.HalfLength),
		Vector3.new(State.HalfWidth, -State.Clearance, State.HalfLength),
	} do
		local Hit = CastSurface(State, State.Root.CFrame:PointToWorldSpace(Offset), Settings.StepHeight,
			math.max(CatchDistance, Settings.StepHeight), false)
		if Hit then
			if not First then
				First = Hit
			elseif Hit.Normal:Dot(First.Normal) < 0.94
				or math.abs((Hit.Position - First.Position):Dot(First.Normal)) > Settings.PlaneTolerance then
				return nil
			end
			Count += 1
		end
	end

	-- Three coherent contacts support a body above a crack; two rear feet cannot suspend it over a cliff.
	return if Count >= 3 then First else nil
end

local function Probe(State: State)
	local Root = State.Root
	State.BodyFloorHeight = -math.huge
	local Feet = Root.Position - GetBodyUp(Root) * State.Clearance
	State.LastProbePosition = Feet
	local Falling = math.max(0, -Root.AssemblyLinearVelocity.Y)
	local CatchDistance = Settings.DropDistance + Falling * Settings.ProbeInterval * 2
	local Center = CastSurface(State, Feet, Settings.StepHeight, CatchDistance, false)
	if not Center then
		Center = CastSurface(State, Feet, Settings.RecoveryHeight, CatchDistance, true)
	end
	if not Center then
		Center = FindFootSupport(State, CatchDistance)
	end
	if Center then
		Center = GetBaseSurface(State, Feet, Center, CatchDistance)
	end

	State.Support = nil
	State.SupportPoint = nil
	State.SupportNormal = nil
	State.SupportVisualNormal = nil
	State.Grounded = Center ~= nil
	if not Center then
		State.Normal = Vector3.yAxis
		State.VisualNormal = Vector3.yAxis
		return
	end

	-- Position comes from the surface directly below the body, never an averaged
	-- plane connecting unrelated rocks, bridge edges or different floor levels.
	State.PlanePoint = Center.Position
	State.Normal = Center.Normal
	State.VisualNormal = Center.Normal
	local Points: { Vector3 } = {}
	local Coherent = true
	for Index, Offset in {
		Vector3.new(-State.HalfWidth, -State.Clearance, -State.HalfLength),
		Vector3.new(State.HalfWidth, -State.Clearance, -State.HalfLength),
		Vector3.new(-State.HalfWidth, -State.Clearance, State.HalfLength),
		Vector3.new(State.HalfWidth, -State.Clearance, State.HalfLength),
	} do
		local Point = Root.CFrame:PointToWorldSpace(Offset)
		local Hit = CastSurface(State, Point, Settings.StepHeight, CatchDistance, false)
		if not Hit or Hit.Normal:Dot(Center.Normal) < 0.94
			or math.abs((Hit.Position - Center.Position):Dot(Center.Normal)) > Settings.PlaneTolerance
		then
			Coherent = false
		else
			Points[Index] = Hit.Position
		end
	end

	if Coherent then
		local Across = Points[2] + Points[4] - Points[1] - Points[3]
		local Along = Points[3] + Points[4] - Points[1] - Points[2]
		local Fitted = Along:Cross(Across)
		if Fitted.Magnitude > 0.001 and Fitted.Unit.Y >= HorseConfig.MinimumGroundNormal
			and Fitted.Unit:Dot(Center.Normal) > 0.94
		then
			State.VisualNormal = Fitted.Unit
		end
	end
	if not Coherent or GetBodyUp(Root):Dot(Center.Normal) < 0.98 then
		-- A ramp and its landing can support different parts of the body at the same time.
		State.BodyFloorHeight = GetBodyFloorHeight(State)
	end

	local Height = GetBodySupport(State, Root.Position, Center.Position, Center.Normal)
	State.Grounded = Height - Root.Position.Y >= -CatchDistance
	if not State.Grounded then
		return
	end

	State.HistoryPoint = Center.Position
	State.HistoryNormal = Center.Normal
	State.HistoryTime = os.clock()
	local Part = if Center.Instance:IsA("BasePart") and not Center.Instance:IsA("Terrain") then Center.Instance else nil
	State.SurfaceVelocity = if Part then Part:GetVelocityAtPosition(Center.Position) else Vector3.zero
	if Part then
		State.Support = Part
		State.SupportPoint = Part.CFrame:PointToObjectSpace(Center.Position)
		State.SupportNormal = Part.CFrame:VectorToObjectSpace(Center.Normal)
		State.SupportVisualNormal = Part.CFrame:VectorToObjectSpace(State.VisualNormal)
	end
end

local function Slide(Velocity: Vector3, Normal: Vector3): Vector3
	local Horizontal = Normal * Vector3.new(1, 0, 1)
	if Horizontal.Magnitude < 0.001 then
		return Velocity
	end

	Horizontal = Horizontal.Unit

	return Velocity - Horizontal * math.min(0, Velocity:Dot(Horizontal))
end

local function SlideSurface(Velocity: Vector3, Normal: Vector3): Vector3
	return Velocity - Normal * math.min(0, Velocity:Dot(Normal))
end

local function CanCrossGroundEdge(State: State, Frame: CFrame, Hit: RaycastResult, Travel: Vector3): boolean
	local Horizontal = Travel * Vector3.new(1, 0, 1)
	if not State.Grounded or Horizontal.Magnitude < 0.001 or math.abs(Travel.Y) > Horizontal.Magnitude * 2 then
		return false
	end
	-- A continuous steep uphill face remains a barrier, regardless of the nearby height.
	if Hit.Normal.Y > 0.05 and not HorseGrounding.IsWalkable(Hit.Normal) then
		return false
	end

	local FeetY = Frame.Position.Y - Frame.UpVector.Y * State.Clearance
	local SamplePoint = Hit.Position + Horizontal.Unit * Settings.ObstacleSkin
	local Origin = Vector3.new(SamplePoint.X, FeetY + Settings.StepHeight + Settings.ObstacleSkin, SamplePoint.Z)
	local Top = workspace:Raycast(Origin,
		-Vector3.yAxis * (Settings.StepHeight + Settings.DropDistance + Settings.ObstacleSkin), State.ObstacleParams)

	return Top ~= nil and Top.Instance == Hit.Instance and HorseGrounding.IsWalkable(Top.Normal)
		and Top.Position.Y - FeetY <= Settings.StepHeight + 0.001
end

local function CastObstacle(State: State, Frame: CFrame, Travel: Vector3, MinimumY: number?): RaycastResult?
	if Travel.Magnitude < 0.001 then
		return nil
	end

	local Params = State.ObstacleParams
	for _ = 1, 4 do
		local Hit = workspace:Blockcast(Frame, State.Root.Size, Travel, Params)
		if not Hit then
			return nil
		end
		if Hit.Normal.Y < (MinimumY or MinimumNormal()) and Travel:Dot(Hit.Normal) < -0.001
			and not CanCrossGroundEdge(State, Frame, Hit, Travel) then
			return Hit
		end
		if Hit.Instance:IsA("Terrain") then
			return nil
		end
		local Filter = table.clone(Params.FilterDescendantsInstances)
		table.insert(Filter, Hit.Instance)
		local NextParams = RaycastParams.new()
		NextParams.FilterType = Enum.RaycastFilterType.Exclude
		NextParams.FilterDescendantsInstances = Filter
		NextParams.RespectCanCollide = true
		NextParams.CollisionGroup = State.ObstacleParams.CollisionGroup
		Params = NextParams
	end

	return nil
end

local function GetSteepNormal(State: State, Travel: Vector3): Vector3?
	if not State.Grounded or Travel.Magnitude < 0.001 then
		return nil
	end

	local Direction = Travel.Unit
	local Local = State.Root.CFrame:VectorToObjectSpace(Direction)
	local Reach = (math.abs(Local.X) * State.Root.Size.X + math.abs(Local.Z) * State.Root.Size.Z) * 0.5
	local Point = State.Root.Position + Direction * (Reach + Travel.Magnitude + Settings.ObstacleSkin)
	Point = Vector3.new(Point.X, HorseGrounding.GetHeight(Point, State.PlanePoint, State.Normal, 0), Point.Z)
	local Hit = workspace:Raycast(Point + Vector3.yAxis * Settings.StepHeight,
		-Vector3.yAxis * (Settings.StepHeight + Settings.DropDistance), State.Params)
	if Hit and Hit.Normal.Y < MinimumNormal() and Direction:Dot(Hit.Normal) < -0.001 then
		return Hit.Normal
	end

	return nil
end

function HorseGrounding.ScanMovement(State: State, Direction: Vector3, Distance: number,
	SupportDistance: number?): (number, Vector3?, boolean)
	local Avoidance = HorseConfig.Steering.Avoidance
	local Heading = HorseGrounding.HorizontalDirection(Direction)
	local MinimumY = math.cos(Avoidance.MinimumObstacleSlope)
	local Frame = State.Root.CFrame
	local Point = Frame.Position - GetBodyUp(State.Root) * State.Clearance
	local Normal = State.Normal
	local Supported = State.Grounded
	local Traveled = 0
	local Steps = math.max(1, math.ceil(Distance / Avoidance.PathSampleDistance))
	local Step = Distance / Steps

	for _ = 1, Steps do
		local Position = State.Root.Position + Heading * (Traveled + Step)
		local ExpectedY = HorseGrounding.GetHeight(Position, Point, Normal, 0)
		local Feet = Vector3.new(Position.X, ExpectedY, Position.Z)
		local Rise = math.max(Settings.StepHeight, Step * math.tan(Settings.MaximumSlope))
		local Surface = CastSurface(State, Feet, Rise, Settings.DropDistance, false)
		local Walkable = Surface ~= nil
			and (HorseGrounding.IsWalkable(Surface.Normal) or Heading:Dot(Surface.Normal) >= -0.01)
			and Surface.Position.Y - ExpectedY <= Settings.StepHeight + 0.001
		if Traveled < (SupportDistance or Distance) then
			Supported = Supported and Walkable
		end

		local NextFrame = CFrame.new(Position.X, Frame.Position.Y, Position.Z) * Frame.Rotation
		if Walkable and Surface then
			local Rotation = HorseGrounding.GetRotation(Heading, Surface.Normal, not HorseGrounding.IsWalkable(Surface.Normal))
			local Height = HorseGrounding.GetHeight(Position, Surface.Position, Surface.Normal, State.Clearance, Rotation.UpVector)
			NextFrame = CFrame.new(Position.X, Height, Position.Z) * Rotation
		end
		local Travel = NextFrame.Position - Frame.Position
		-- Follow each reachable tread/ramp instead of sweeping the whole route at the starting body height.
		local Hit = CastObstacle(State, Frame, Travel, MinimumY)
		if Hit then
			local Fraction = math.clamp(Hit.Distance / math.max(Travel.Magnitude, 0.001), 0, 1)
			return Traveled + Step * Fraction, Hit.Normal, Supported
		end
		if Surface and Surface.Normal.Y < MinimumY and Heading:Dot(Surface.Normal) < -0.001 then
			local Local = Frame:VectorToObjectSpace(Heading)
			local Reach = (math.abs(Local.X) * State.Root.Size.X + math.abs(Local.Z) * State.Root.Size.Z) * 0.5
			return math.max(0, Traveled + Step - Reach), Surface.Normal, Supported
		end
		if Walkable and Surface then
			Point, Normal = Surface.Position, Surface.Normal
		end
		Frame = NextFrame
		Traveled += Step
	end

	return Distance, nil, Supported
end

local function ResolveRotation(State: State): boolean
	local Root = State.Root
	local Previous = State.LastMovementFrame
	local _, Angle = Previous:ToObjectSpace(Root.CFrame):ToAxisAngle()
	if Angle < 0.002 then
		return false
	end

	local Fraction, Normal = 1, Vector3.zero
	local Size = Vector3.new(Settings.ObstacleSkin * 0.25, Root.Size.Y, Settings.ObstacleSkin * 0.25)
	for _, X in { -1, 1 } do
		for _, Z in { -1, 1 } do
			local Corner = Vector3.new(Root.Size.X * X * 0.5, 0, Root.Size.Z * Z * 0.5)
			local Start = Previous:PointToWorldSpace(Corner)
			local Travel = Root.CFrame:PointToWorldSpace(Corner) - Start
			if Travel.Magnitude < 0.001 then
				continue
			end
			local Hit = workspace:Blockcast(CFrame.new(Start) * Previous.Rotation, Size, Travel, State.ObstacleParams)
			if Hit and Hit.Normal.Y < MinimumNormal() and Travel:Dot(Hit.Normal) < -0.001
				and not CanCrossGroundEdge(State, Previous, Hit, Travel) then
				local Limit = math.max(0, Hit.Distance - Settings.ObstacleSkin) / Travel.Magnitude
				if Limit < Fraction then
					Fraction, Normal = Limit, Hit.Normal
				end
			end
		end
	end
	if Fraction >= 1 then
		return false
	end

	-- Restrict the turn without cancelling translation away from the obstacle.
	Root.CFrame = CFrame.new(Root.Position) * Previous.Rotation:Lerp(Root.CFrame.Rotation, Fraction)
	Root.AssemblyLinearVelocity = SlideSurface(Root.AssemblyLinearVelocity, Normal)

	return true
end

local function ResolveMovement(State: State)
	local Root = State.Root
	local Travel = Root.Position - State.LastMovementFrame.Position
	-- Large explicit teleports are handled by the service's existing position validation.
	if Travel.Magnitude > Settings.ObstacleSweepDistance then
		return
	end
	ResolveRotation(State)
	if Travel.Magnitude < 0.001 then
		return
	end

	local Hit = CastObstacle(State, State.LastMovementFrame, Travel)
	if not Hit then
		return
	end

	local Distance = math.max(0, Hit.Distance - Settings.ObstacleSkin)
	local BeforeContact = Travel.Unit * Distance
	local Remainder = SlideSurface(Travel - BeforeContact, Hit.Normal)
	local Position = State.LastMovementFrame.Position + BeforeContact
	local Second = CastObstacle(State, CFrame.new(Position) * Root.CFrame.Rotation, Remainder)
	if Second then
		Remainder = Remainder.Unit * math.max(0, Second.Distance - Settings.ObstacleSkin)
	end
	Root.CFrame = CFrame.new(Position + Remainder) * Root.CFrame.Rotation
	Root.AssemblyLinearVelocity = SlideSurface(Root.AssemblyLinearVelocity, Hit.Normal)
end

function HorseGrounding.ConstrainMovement(State: State, Velocity: Vector3, DeltaTime: number): Vector3
	local Actual = State.Root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	for _, Candidate in { Actual, Velocity } do
		local Travel = Candidate * math.max(DeltaTime, 0)
		if Travel.Magnitude < 0.001 then
			continue
		end

		local Hit = CastObstacle(State, State.Root.CFrame, Travel + Travel.Unit * Settings.ObstacleSkin)
		local Normal = if Hit then Hit.Normal else GetSteepNormal(State, Travel)
		if Normal then
			Velocity = Slide(Velocity, Normal)
			-- Stop the existing impulse as well as the motor target, before entering the obstacle.
			State.Root.AssemblyLinearVelocity = Slide(State.Root.AssemblyLinearVelocity, Normal)
		end
	end

	return Velocity
end

function HorseGrounding.Update(State: State, DeltaTime: number, Direction: Vector3?, TurnSpeed: number?, Bank: number?)
	local Integrated = State.LastMovementFrame:ToObjectSpace(State.Root.CFrame)
	local _, RotationStep = Integrated:ToAxisAngle()
	local AfterPhysics = DeltaTime == 0 and (Integrated.Position.Magnitude > 0.001 or RotationStep > 0.001)
	ResolveMovement(State)
	HorseGrounding.ConstrainMovement(State, Vector3.zero, DeltaTime)
	local WasSupported = State.Grounded or State.Vertical.Enabled
	if Direction and Direction.Magnitude > 0.01 then
		local Heading = HorseGrounding.HorizontalDirection(Direction)
		local Rotation = CFrame.lookAt(Vector3.zero, State.Heading):Lerp(CFrame.lookAt(Vector3.zero, Heading), 1 - math.exp(-(TurnSpeed or 6) * DeltaTime))
		State.Heading = HorseGrounding.HorizontalDirection(Rotation.LookVector)
	end

	State.Elapsed += DeltaTime
	local Feet = State.Root.Position - GetBodyUp(State.Root) * State.Clearance
	if AfterPhysics or State.Elapsed >= Settings.ProbeInterval or (Feet - State.LastProbePosition).Magnitude >= Settings.ProbeTravel then
		State.Elapsed = 0
		Probe(State)
	end
	if State.Support and State.SupportPoint and State.SupportNormal then
		if State.Support:IsDescendantOf(workspace) then
			State.PlanePoint = State.Support.CFrame:PointToWorldSpace(State.SupportPoint)
			State.Normal = State.Support.CFrame:VectorToWorldSpace(State.SupportNormal)
			if State.SupportVisualNormal then
				State.VisualNormal = State.Support.CFrame:VectorToWorldSpace(State.SupportVisualNormal)
			end
			State.SurfaceVelocity = State.Support:GetVelocityAtPosition(State.PlanePoint)
		else
			State.Grounded = false
		end
	end

	if not HorseGrounding.IsSupportable(State.Normal) then
		State.Grounded = false
	end
	local Mass = State.Root.AssemblyMass
	if Mass == math.huge then
		Mass = State.Root.Mass
	end
	State.Vertical.ForceLimitsEnabled = true
	State.Vertical.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	State.Vertical.MaxForce = Mass * (workspace.Gravity + Settings.SupportAcceleration)
	State.Vertical.Enabled = State.Grounded
	if State.Grounded then
		local Height = GetBodySupport(State, State.Root.Position, State.PlanePoint, State.Normal)
		local Error = Height - State.Root.Position.Y
		if Error > Settings.PenetrationTolerance then
			-- Resolve penetration by position, not an upward launch velocity.
			State.Root.CFrame += Vector3.yAxis * Error
			local Velocity = State.Root.AssemblyLinearVelocity
			State.Root.AssemblyLinearVelocity = Vector3.new(Velocity.X, math.max(0, Velocity.Y), Velocity.Z)
			State.LastProbePosition = State.Root.Position - GetBodyUp(State.Root) * State.Clearance
			Error = 0
		end
		local RelativeVelocity = State.Root.AssemblyLinearVelocity - State.SurfaceVelocity
		local SlopeVelocity = -(RelativeVelocity.X * State.Normal.X + RelativeVelocity.Z * State.Normal.Z) / State.Normal.Y
		local Correction = math.clamp(Error * Settings.HeightResponse, -Settings.MaximumCorrectionSpeed, Settings.MaximumCorrectionSpeed)
		local HorizontalTravel = RelativeVelocity * Vector3.new(1, 0, 1) * DeltaTime
		local ClimbVelocity = SlopeVelocity + Correction
		if DeltaTime > 0.001 and HorizontalTravel.Magnitude > 0.001 then
			local FuturePosition = State.Root.Position + HorizontalTravel
			local FutureFeet = FuturePosition - GetBodyUp(State.Root) * State.Clearance
			local FutureGround = CastSurface(State, FutureFeet, Settings.StepHeight, Settings.DropDistance, false)
			if FutureGround then
				FutureGround = GetBaseSurface(State, FutureFeet, FutureGround, Settings.DropDistance)
				local FutureHeight = GetBodySupport(State, FuturePosition, FutureGround.Position, FutureGround.Normal)
				-- Start the vertical climb in the same physics step as entering the ramp.
				ClimbVelocity = math.max(ClimbVelocity, (FutureHeight - State.Root.Position.Y) / DeltaTime)
			end
		end
		State.Vertical.LineVelocity = math.clamp(
			State.SurfaceVelocity.Y + ClimbVelocity,
			-Settings.MaximumVerticalSpeed, Settings.MaximumVerticalSpeed
		)
	elseif WasSupported then
		-- A climb correction must not turn into a jump when support ends.
		local Velocity = State.Root.AssemblyLinearVelocity
		if Velocity.Y > Settings.MaximumReleaseSpeed then
			State.Root.AssemblyLinearVelocity = Vector3.new(Velocity.X, Settings.MaximumReleaseSpeed, Velocity.Z)
		end
	end

	local Normal = if State.Grounded then State.VisualNormal else Vector3.yAxis
	local Lean = if State.Grounded then math.clamp(Bank or 0, -HorseConfig.Steering.MaximumBank, HorseConfig.Steering.MaximumBank) else 0
	local Target = HorseGrounding.GetRotation(State.Heading, Normal, State.Grounded and not HorseGrounding.IsWalkable(Normal))
		* CFrame.Angles(0, 0, Lean)
	State.Orientation.CFrame = State.Orientation.CFrame:Lerp(Target, 1 - math.exp(-Settings.TiltResponse * DeltaTime))
	State.LastMovementFrame = State.Root.CFrame
end

return HorseGrounding
