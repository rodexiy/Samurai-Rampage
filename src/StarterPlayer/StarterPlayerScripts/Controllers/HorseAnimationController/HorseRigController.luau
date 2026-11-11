local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local HorseConfig = require(ReplicatedStorage.Shared.HorseConfig)
local HorseTerrainPredictionController = require(Players.LocalPlayer.PlayerScripts.Client.Controllers.HorseAnimationController.HorseTerrainPredictionController)
local HorseRiderController = require(Players.LocalPlayer.PlayerScripts.Client.Controllers.HorseAnimationController.HorseRiderController)
local HorseTailController = require(Players.LocalPlayer.PlayerScripts.Client.Controllers.HorseAnimationController.HorseTailController)
local Settings = HorseConfig.Animation
local Running = Settings.Running
local MinimumSupportNormal = math.cos(HorseConfig.Grounding.MaximumSupportSlope)
local HorseRigController = {}

local function Blend(From: number, To: number, Weight: number): number
	return From + (To - From) * Weight
end

type Pose = { Bone: Bone, Transform: CFrame }
export type Joint = {
	Bone: Bone,
	Rest: CFrame,
	Axis: Vector3,
	Angle: number,
	FrameAngle: number,
	AngleStep: number,
	Minimum: number,
	Maximum: number,
	Point: Vector2,
}
export type Foot = {
	Target: Attachment,
	Hoof: Bone,
	Joints: { Joint },
	ParentAxis: Vector3,
	MaximumReach: number,
	Rest: CFrame,
	Phase: number,
	RunPhase: number,
	Cycle: number,
	Front: boolean,
	Plant: Vector3?,
	Support: BasePart?,
	SupportPoint: Vector3?,
	Normal: Vector3,
	Grounded: boolean,
	InSwing: boolean,
	ForcedSwing: boolean,
	SwingAlpha: number,
	SwingDuration: number,
	SwingReady: boolean,
	SwingLocalStart: Vector3,
	SwingStartVelocity: Vector3,
	JustStarted: boolean,
	SwingGoal: Vector3,
	LastTarget: Vector3,
	SolverEnabled: boolean,
	Seeded: boolean,
	GroundHit: RaycastResult?,
	GroundFrame: CFrame?,
	Prediction: HorseTerrainPredictionController.Contact,
}
export type Rig = {
	Model: Model,
	Root: BasePart,
	Body: Bone,
	BodyRest: CFrame,
	BodyTransform: CFrame,
	BodyMotion: CFrame,
	Rider: HorseRiderController.State,
	Neck: Bone?,
	NeckAxis: Vector3,
	NeckYawAxis: Vector3,
	NeckYaw: number,
	LookPitch: number,
	TailMotion: HorseTailController.State,
	Poses: { Pose },
	Original: { [Bone]: CFrame },
	Feet: { Foot },
	Targets: BasePart,
	Params: RaycastParams,
	Scale: number,
	Phase: number,
	Speed: number,
	Gallop: number,
	Frequency: number,
	Velocity: Vector3,
	Quality: number,
	Elapsed: number,
	ProbeElapsed: number,
	LastFrame: CFrame,
	Normal: Vector3,
	BodyOffset: number,
	Epoch: number,
	Smooth: boolean,
	Prediction: HorseTerrainPredictionController.Motion,
	PredictionContacts: { HorseTerrainPredictionController.Contact },
	PredictionElapsed: number,
	IdleWeight: number,
	Resting: boolean,
}

local function GetBoneFrame(Bone: Bone, Cache: { [Instance]: CFrame }): CFrame
	local Existing = Cache[Bone]
	if Existing then
		return Existing
	end

	local Parent = Bone.Parent
	local Frame = CFrame.identity
	if Parent and Parent:IsA("Bone") then
		Frame = GetBoneFrame(Parent, Cache)
	elseif Parent and Parent:IsA("BasePart") then
		Frame = Parent.CFrame
	end

	Frame *= Bone.CFrame * Bone.Transform
	Cache[Bone] = Frame
	return Frame
end

local function GetPlant(Foot: Foot): Vector3?
	if Foot.Support and Foot.Support:IsDescendantOf(workspace) and Foot.SupportPoint then
		return Foot.Support.CFrame:PointToWorldSpace(Foot.SupportPoint)
	end

	return Foot.Plant
end

local function PlantFoot(Foot: Foot, Position: Vector3, Surface: Instance?)
	Foot.Plant = Position
	Foot.Support = if Surface and Surface:IsA("BasePart") then Surface else nil
	Foot.SupportPoint = if Foot.Support then Foot.Support.CFrame:PointToObjectSpace(Position) else nil
	Foot.InSwing = false
	Foot.ForcedSwing = false
end

local function ClearContacts(Rig: Rig)
	Rig.NeckYaw = 0
	Rig.LookPitch = 0
	HorseTailController.Reset(Rig.TailMotion)
	Rig.Prediction = HorseTerrainPredictionController.Create()
	local Heading = Rig.Root.CFrame.LookVector * Vector3.new(1, 0, 1)
	Rig.Prediction.Heading = if Heading.Magnitude > 0.001 then Heading.Unit else -Vector3.zAxis
	Rig.PredictionContacts = {}
	for _, Foot in Rig.Feet do
		Foot.Plant = nil
		Foot.Support = nil
		Foot.SupportPoint = nil
		Foot.InSwing = false
		Foot.ForcedSwing = false
		Foot.SwingReady = true
		Foot.Grounded = false
		Foot.Seeded = false
		Foot.GroundHit = nil
		Foot.GroundFrame = nil
		Foot.Prediction = HorseTerrainPredictionController.CreateContact(Foot.Front)
		table.insert(Rig.PredictionContacts, Foot.Prediction)
	end
	Rig.ProbeElapsed = Settings.FullInterval
	Rig.PredictionElapsed = Settings.Prediction.Interval
end

function HorseRigController.SetQuality(Rig: Rig, Quality: number)
	if Rig.Quality == Quality then
		return
	end

	Rig.Quality = Quality
	HorseRiderController.Reset(Rig.Rider)
	for _, Foot in Rig.Feet do
		Foot.SolverEnabled = Quality == 2
	end
	for _, Pose in Rig.Poses do
		Pose.Bone.Transform = Pose.Transform
	end

	ClearContacts(Rig)
	Rig.LastFrame = Rig.Root.CFrame
	Rig.Elapsed = 0
end

local function CreateFoot(Rig: Rig, Bones: { [string]: Bone }, Definition: any): Foot
	local First = Bones[Definition.Prefix .. "1"]
	local Hoof = Bones[Definition.Prefix .. Definition.Hoof]
	local Parent = First.Parent :: Bone
	local Rest = Rig.Root.CFrame:ToObjectSpace(Hoof.WorldCFrame)
	local Target = Instance.new("Attachment")
	Target.Name = Definition.Prefix .. "Target"
	Target.Parent = Rig.Targets
	Target.WorldCFrame = Hoof.WorldCFrame

	local Limits = if Definition.Front then Settings.FrontJointLimits else Settings.BackJointLimits
	local Joints: { Joint } = {}
	local Length = 0
	for Index = 1, Definition.Hoof do
		local Bone = Bones[Definition.Prefix .. Index]
		if Index > 1 then
			Length += (Bone.WorldPosition - Bones[Definition.Prefix .. (Index - 1)].WorldPosition).Magnitude
		end
		table.insert(Joints, {
			Bone = Bone, Rest = Rig.Original[Bone],
			-- Mirrored legs have different bind axes; derive each hinge from the bind pose.
			Axis = Bone.TransformedWorldCFrame:VectorToObjectSpace(Rig.Root.CFrame.RightVector).Unit,
			Angle = 0, FrameAngle = 0, AngleStep = math.huge,
			Minimum = math.rad(Limits[Index][1]), Maximum = math.rad(Limits[Index][2]),
			Point = Vector2.zero,
		})
	end

	return {
		Target = Target, Hoof = Hoof, Joints = Joints, Rest = Rest,
		MaximumReach = Length * Settings.MaximumLegExtension,
		ParentAxis = Parent.TransformedWorldCFrame:VectorToObjectSpace(Rig.Root.CFrame.RightVector).Unit,
		Phase = Definition.Phase, RunPhase = Definition.RunPhase, Cycle = Definition.Phase,
		Front = Definition.Front, Normal = Vector3.yAxis,
		Grounded = false, InSwing = false, ForcedSwing = false, SwingAlpha = 0,
		SwingDuration = Settings.SettleDuration, SwingReady = true,
		SwingGoal = Hoof.WorldPosition, LastTarget = Hoof.WorldPosition,
		SwingLocalStart = Rest.Position, SwingStartVelocity = Vector3.zero, JustStarted = false,
		SolverEnabled = false, Seeded = false,
		Prediction = HorseTerrainPredictionController.CreateContact(Definition.Front),
	}
end

function HorseRigController.Create(Model: Model, TargetFolder: Folder): Rig?
	local Root = Model.PrimaryPart
	if not Root then
		return nil
	end

	local Bones: { [string]: Bone } = {}
	local Poses = {}
	local Original: { [Bone]: CFrame } = {}
	for _, Bone in Model:QueryDescendants("Bone") :: { Bone } do
		Bones[Bone.Name] = Bone
		Original[Bone] = Bone.Transform
		table.insert(Poses, { Bone = Bone, Transform = Bone.Transform })
	end
	if not Bones.SK_root then
		return nil
	end
	for _, Definition in Settings.Legs do
		for Index = 1, Definition.Hoof do
			if not Bones[Definition.Prefix .. Index] then
				return nil
			end
		end
	end

	local Targets = Instance.new("Part")
	Targets.Name = Model.Name .. "_HoofTargets"
	Targets.Anchored = true
	Targets.Size = Vector3.one
	Targets.Transparency = 1
	Targets.CanCollide = false
	Targets.CanQuery = false
	Targets.CanTouch = false
	Targets.CastShadow = false
	Targets.CFrame = Root.CFrame
	Targets.Parent = TargetFolder

	local Filter: { Instance } = { Model, TargetFolder }
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

	-- Imported Model.Scale is not the horse's world size.
	local Scale = (Bones.SK_L_F_leg_2.WorldPosition - Bones.SK_L_F_leg_7.WorldPosition).Magnitude / 5.65
	local Rig: Rig = {
		Model = Model, Root = Root, Body = Bones.SK_root, Neck = Bones.SK_neck,
		BodyRest = Root.CFrame:ToObjectSpace(Bones.SK_root.TransformedWorldCFrame),
		BodyTransform = Original[Bones.SK_root],
		BodyMotion = CFrame.identity, Rider = HorseRiderController.Create(),
		NeckAxis = if Bones.SK_neck then Bones.SK_neck.TransformedWorldCFrame:VectorToObjectSpace(Root.CFrame.RightVector).Unit else Vector3.xAxis,
		NeckYawAxis = if Bones.SK_neck then Bones.SK_neck.TransformedWorldCFrame:VectorToObjectSpace(Root.CFrame.UpVector).Unit else Vector3.yAxis,
		NeckYaw = 0, LookPitch = 0,
		TailMotion = HorseTailController.Create(Root, Bones, Original),
		Poses = Poses, Original = Original, Feet = {}, Targets = Targets, Params = Params, Scale = Scale,
		Phase = 0, Speed = 0, Gallop = 0, Frequency = Settings.MinimumFrequency,
		Velocity = Vector3.zero, Quality = -1, Elapsed = 0, ProbeElapsed = 0,
		LastFrame = Root.CFrame, Normal = Vector3.yAxis, BodyOffset = 0,
		Epoch = Model:GetAttribute("GaitEpoch") or workspace:GetServerTimeNow(),
		Smooth = false,
		Prediction = HorseTerrainPredictionController.Create(), PredictionContacts = {}, PredictionElapsed = 0,
		IdleWeight = 1, Resting = true,
	}
	for _, Definition in Settings.Legs do
		table.insert(Rig.Feet, CreateFoot(Rig, Bones, Definition))
	end

	HorseRigController.SetQuality(Rig, 0)
	return Rig
end

local function GetRiderLook(Rig: Rig, Now: number, Direction: Vector3?): Vector3?
	if typeof(Rig.Model:GetAttribute("RiderUserId")) ~= "number" then
		return nil
	end
	if Direction then
		return Direction
	end
	local Time = Rig.Model:GetAttribute("RiderLookTime")
	local RemoteDirection = Rig.Model:GetAttribute("RiderLookDirection")
	if typeof(Time) == "number" and typeof(RemoteDirection) == "Vector3"
		and Now - Time >= -1 and Now - Time <= Settings.RiderLook.Timeout then
		return RemoteDirection
	end

	return nil
end

local function PoseBody(Rig: Rig, DeltaTime: number, Now: number, LookDirection: Vector3?)
	local Weight = math.clamp(Rig.Speed / 12, 0, 1)
	local TrotPulse = math.sin(Rig.Phase * math.pi * 4)
	local RunPulse = math.sin(Rig.Phase * math.pi * 2)
	local Pulse = Blend(TrotPulse, RunPulse, Rig.Gallop)
	local Bounce = Blend(Settings.BodyBounce, Running.BodyBounce, Rig.Gallop)
	local Normal = Rig.Normal
	local Pitch = math.clamp(-math.atan2(Normal:Dot(Rig.Root.CFrame.LookVector), Normal.Y), -Settings.MaximumTilt, Settings.MaximumTilt)
	local Roll = math.clamp(-math.atan2(Normal:Dot(Rig.Root.CFrame.RightVector), Normal.Y), -Settings.MaximumTilt, Settings.MaximumTilt)
	if Rig.Model:GetAttribute("GroundClearance") then
		-- The physical root tilts the complete mount and its rider together.
		Pitch = 0
		Roll = 0
	end
	Pitch += Rig.Prediction.BodyPitch
	local Grounded = Rig.Quality == 1
	for _, Foot in Rig.Feet do
		Grounded = Grounded or Foot.Grounded
	end
	local Drop = if Grounded then -Settings.BodyDrop * (1 - Rig.IdleWeight) else 0
	local TargetOffset = (Drop + Pulse * Bounce * Weight) * Rig.Scale + Rig.Prediction.BodyLift
	Rig.BodyOffset += (TargetOffset - Rig.BodyOffset) * (1 - math.exp(-12 * DeltaTime))

	local Rest = Rig.Root.CFrame * Rig.BodyRest
	Rig.BodyMotion = CFrame.new(0, Rig.BodyOffset, 0)
		* CFrame.Angles(Pitch + Pulse * Blend(0.012, Running.BodyPitch, Rig.Gallop) * Weight, 0, Roll)
	local Desired = Rig.Root.CFrame * Rig.BodyMotion * Rig.BodyRest
	Rig.Body.Transform = Rig.BodyTransform * Rest:ToObjectSpace(Desired)
	HorseRiderController.Update(Rig.Rider, Rig.Model, Rig.BodyMotion)

	local Idle = math.sin((Now - Rig.Epoch) * 1.8)
	if Rig.Neck then
		local Turn = Settings.NeckTurn
		local TargetYaw = math.clamp(Rig.Prediction.YawRate * Turn.LookAhead, -Turn.MaximumAngle, Turn.MaximumAngle)
		local TargetPitch = 0
		local Direction = GetRiderLook(Rig, Now, LookDirection)
		if Direction and Direction.Magnitude > 0.001 then
			local Look = Settings.RiderLook
			local Local = Rig.Root.CFrame:VectorToObjectSpace(Direction.Unit)
			local LookWeight = math.clamp(1 - Rig.Speed / Look.MaximumSpeed, 0, 1)
			local Yaw = math.clamp(math.atan2(-Local.X, -Local.Z), -Look.MaximumYaw, Look.MaximumYaw)
			TargetYaw = Blend(TargetYaw, Yaw, LookWeight)
			TargetPitch = math.clamp(math.asin(math.clamp(Local.Y, -1, 1)), -Look.MaximumPitch, Look.MaximumPitch) * LookWeight
		end
		Rig.NeckYaw += (TargetYaw - Rig.NeckYaw) * (1 - math.exp(-Turn.Response * DeltaTime))
		Rig.LookPitch += (TargetPitch - Rig.LookPitch) * (1 - math.exp(-Settings.RiderLook.Response * DeltaTime))
		Rig.Neck.Transform = Rig.Original[Rig.Neck] * CFrame.fromAxisAngle(Rig.NeckYawAxis, Rig.NeckYaw)
			* CFrame.fromAxisAngle(Rig.NeckAxis,
			Idle * 0.012 + Pulse * Blend(0.025, Running.NeckPitch, Rig.Gallop) * Weight + Rig.Prediction.BodyPitch * 0.4 + Rig.LookPitch)
	end
	HorseTailController.Update(Rig.TailMotion, Rig.Root.CFrame, Rig.Velocity, Rig.Prediction.YawRate,
		Rig.Phase, Now - Rig.Epoch, DeltaTime)
end

local function ProbeGround(Rig: Rig, Rest: Vector3, Point: Vector3): RaycastResult?
	local Origin = Vector3.new(Point.X, math.max(Rest.Y, Point.Y) + Settings.ProbeHeight * Rig.Scale, Point.Z)
	local Bottom = math.min(Rest.Y, Point.Y) - Settings.ProbeDepth * Rig.Scale
	local Hit = workspace:Raycast(Origin, Vector3.new(0, Bottom - Origin.Y, 0), Rig.Params)
	if Hit and Hit.Material ~= Enum.Material.Water and Hit.Normal.Y >= MinimumSupportNormal then
		return Hit
	end

	return nil
end

local function GetFootVelocity(Rig: Rig, Position: Vector3): Vector3
	local AngularVelocity = Vector3.yAxis * Rig.Prediction.YawRate

	return Rig.Velocity + AngularVelocity:Cross(Position - Rig.Root.Position)
end

local function BeginSwing(Rig: Rig, Foot: Foot, Goal: Vector3, Forced: boolean, Duration: number)
	Foot.SwingLocalStart = Rig.Root.CFrame:PointToObjectSpace(Foot.LastTarget)
	Foot.SwingStartVelocity = -Rig.Root.CFrame:VectorToObjectSpace(GetFootVelocity(Rig, Foot.LastTarget))
	Foot.SwingGoal = Goal
	Foot.SwingAlpha = 0
	Foot.SwingDuration = math.max(Duration, Settings.MinimumSwingDuration)
	Foot.JustStarted = true
	Foot.SwingReady = false
	Foot.InSwing = true
	Foot.ForcedSwing = Forced
	Foot.Support = nil
	Foot.SupportPoint = nil
end

local function GetSwingPosition(Rig: Rig, Foot: Foot): Vector3
	local Alpha = Foot.SwingAlpha
	local Square, Cube = Alpha * Alpha, Alpha * Alpha * Alpha
	local Goal = Rig.Root.CFrame:PointToObjectSpace(Foot.SwingGoal)
	local EndVelocity = -Rig.Root.CFrame:VectorToObjectSpace(GetFootVelocity(Rig, Foot.SwingGoal))
	-- Match the planted foot's velocity at both ends, in the moving body's frame.
	local Position = Foot.SwingLocalStart * (2 * Cube - 3 * Square + 1)
		+ Foot.SwingStartVelocity * Foot.SwingDuration * (Cube - 2 * Square + Alpha)
		+ Goal * (-2 * Cube + 3 * Square)
		+ EndVelocity * Foot.SwingDuration * (Cube - Square)
	if Foot.Front and not Rig.Resting then
		-- Reach from the shoulder in late swing, returning to the planted target at touchdown.
		local Reach = math.sin(math.clamp((Alpha - 0.35) / 0.65, 0, 1) * math.pi) ^ 2
		Position -= Vector3.zAxis * Reach * Settings.FrontLeg.SwingReach * Rig.Scale
	end
	-- Preserve the contact endpoints on slopes; only constrain overshoot between them.
	local ForwardLimit = if Foot.Front then Settings.FrontLeg.MaximumForwardReach else Settings.MaximumForwardReach
	local Forward = math.max(ForwardLimit * Rig.Scale,
		Foot.Rest.Position.Z - Foot.SwingLocalStart.Z, Foot.Rest.Position.Z - Goal.Z)
	local Backward = math.max(Settings.MaximumBackwardReach * Rig.Scale,
		Foot.SwingLocalStart.Z - Foot.Rest.Position.Z, Goal.Z - Foot.Rest.Position.Z)
	local Side = 0.35 * Rig.Scale
	Position = Vector3.new(math.clamp(Position.X,
		math.min(Foot.Rest.Position.X - Side, Foot.SwingLocalStart.X, Goal.X),
		math.max(Foot.Rest.Position.X + Side, Foot.SwingLocalStart.X, Goal.X)), Position.Y,
		math.clamp(Position.Z, Foot.Rest.Position.Z - Forward, Foot.Rest.Position.Z + Backward))
	local Lift = math.sin(Alpha * math.pi) ^ 2
	local Height = if Rig.Resting and Foot.ForcedSwing then Settings.Idle.StepHeight
		else Blend(Settings.StepHeight, Running.StepHeight, Rig.Gallop)

	return Rig.Root.CFrame:PointToWorldSpace(Position)
		+ Rig.Root.CFrame.UpVector * Lift * math.min(Height * Rig.Scale
			+ Foot.Prediction.ExtraLift, Settings.Prediction.MaximumLift * Rig.Scale)
end

local function CanSettleFoot(Rig: Rig, Foot: Foot): boolean
	for _, Other in Rig.Feet do
		if Other ~= Foot and Other.InSwing and Other.Phase ~= Foot.Phase then
			return false
		end
	end

	return true
end

local function AdvanceSwing(Foot: Foot, DeltaTime: number)
	if Foot.JustStarted then
		Foot.JustStarted = false
	else
		Foot.SwingAlpha = math.min(1, Foot.SwingAlpha + DeltaTime / Foot.SwingDuration)
	end
end

local function GetUnsupportedPosition(Rig: Rig, Foot: Foot, Rest: Vector3, Landing: Vector3,
	DeltaTime: number, Frequency: number, Stance: number, Reach: number, WantsSwing: boolean): Vector3
	local RaisedLanding = Landing + Rig.Root.CFrame.UpVector * Rig.Scale * 0.6
	if WantsSwing and Foot.SwingReady and not Foot.InSwing then
		BeginSwing(Rig, Foot, RaisedLanding, false, (1 - Foot.Cycle) / Frequency)
	end

	if Foot.InSwing then
		Foot.SwingGoal = RaisedLanding
		AdvanceSwing(Foot, DeltaTime)
		local Position = GetSwingPosition(Rig, Foot)
		if Foot.SwingAlpha >= 1 then
			Foot.InSwing = false
			Foot.ForcedSwing = false
		end

		return Position
	end

	local Travel = if Rig.Resting then 0 else Reach * (1 - 2 * math.clamp(Foot.Cycle / Stance, 0, 1))

	return Rest + Rig.Root.CFrame.LookVector * Travel + Rig.Root.CFrame.UpVector * Rig.Scale * 0.6
end

local function UpdateFoot(Rig: Rig, Foot: Foot, DeltaTime: number, Frequency: number, Stance: number, Probe: boolean, Predict: boolean)
	local Rest = Rig.Root.CFrame:PointToWorldSpace(Foot.Rest.Position)
	local Moving = Rig.Speed > Settings.MoveThreshold and not Rig.Resting
	local Phase = Foot.Cycle
	local WantsSwing = Moving and Phase >= Stance
	if not WantsSwing then
		Foot.SwingReady = true
	end
	local Plant = GetPlant(Foot)
	-- The outside legs travel farther around a turn than the inside legs.
	local ForwardSpeed = GetFootVelocity(Rig, Rest):Dot(Rig.Root.CFrame.LookVector)
	local Reach = math.clamp(ForwardSpeed * Stance * 0.5 / Frequency,
		-Settings.MaximumBackwardReach * Rig.Scale, Settings.MaximumForwardReach * Rig.Scale)
	local Landing = Rest + Rig.Root.CFrame.LookVector * (if Moving then Reach else 0)
	if Foot.InSwing then
		Foot.SwingGoal = Landing
	end
	local Point = if Foot.InSwing then Foot.SwingGoal else Plant or Rest
	if Probe then
		Foot.GroundHit = ProbeGround(Rig, Rest, Point)
		local Hit = Foot.GroundHit
		Foot.GroundFrame = if Hit and Hit.Instance:IsA("BasePart") and not Hit.Instance:IsA("Terrain") then Hit.Instance.CFrame else nil
	end
	local Hit = Foot.GroundHit
	if Hit and not Hit.Instance:IsDescendantOf(workspace) then
		Hit = nil
		Foot.GroundHit = nil
	end
	Foot.Grounded = Hit ~= nil
	local Position: Vector3
	if not Hit then
		Foot.Prediction.Hit = nil
		Foot.Prediction.HeightOffset = 0
		Foot.Plant = nil
		Foot.Support = nil
		Foot.SupportPoint = nil
		Foot.Normal = Rig.Root.CFrame.UpVector
		-- Missing a ground sample releases contact, but never cancels the leg's recovery arc.
		Position = GetUnsupportedPosition(Rig, Foot, Rest, Landing, DeltaTime, Frequency, Stance, Reach, WantsSwing)
	else
		local Normal = Hit.Normal
		local GroundPoint = Hit.Position
		if Rig.Smooth then
			if Foot.GroundFrame and Hit.Instance:IsA("BasePart") then
				local Change = Hit.Instance.CFrame * Foot.GroundFrame:Inverse()
				GroundPoint = Change:PointToWorldSpace(GroundPoint)
				Normal = Change:VectorToWorldSpace(Normal)
			end
			-- Reuse the sampled plane between probes; do not hold the animated foot at 30 Hz.
			local Offset = Point - GroundPoint
			local Height = GroundPoint.Y - (Offset.X * Normal.X + Offset.Z * Normal.Z) / math.max(Normal.Y, MinimumSupportNormal)
			GroundPoint = Vector3.new(Point.X, Height, Point.Z)
		end
		Foot.Normal = Normal
		local Ground = GroundPoint + Normal * Settings.HoofClearance * Rig.Scale
		if Predict and Moving then
			local Horizon = if Foot.InSwing then (1 - Foot.SwingAlpha) * Foot.SwingDuration
				else math.max(Settings.MinimumSwingDuration, (1 - Phase) / Frequency)
			HorseTerrainPredictionController.Sample(Rig.Prediction, Foot.Prediction, Rig.Root.CFrame,
				Rig.Root.CFrame:PointToObjectSpace(Landing), Horizon, GroundPoint.Y, Rig.Scale, Rig.Params)
		elseif not Moving or not Settings.Prediction.Enabled then
			Foot.Prediction.Hit = nil
		end
		if not Plant and not Foot.InSwing then
			PlantFoot(Foot, Ground, Hit.Instance)
			Plant = Ground
		end

		if WantsSwing and Foot.SwingReady and not Foot.InSwing then
			BeginSwing(Rig, Foot, Landing, false, (1 - Phase) / Frequency)
		elseif (not Moving and Foot.InSwing and not Foot.ForcedSwing) or (Rig.Resting and Plant and not Foot.InSwing
			and ((Plant - Rest) * Vector3.new(1, 0, 1)).Magnitude > Settings.Idle.FootTolerance * Rig.Scale
			and CanSettleFoot(Rig, Foot)) then
			-- Recenter the diagonal pairs with small steps, instead of freezing the last stride.
			BeginSwing(Rig, Foot, Rest, true, Settings.Idle.FootDuration)
		-- Moving feet recover on the gait's timing; lateral drift in a turn must not insert extra steps.
		elseif not Moving and Plant and not Foot.InSwing and (
			((Plant - Rest) * Vector3.new(1, 0, 1)).Magnitude > math.min(
				Blend(Settings.PlantDistance, Running.PlantDistance, Rig.Gallop) * 1.15, Settings.MaximumBackwardReach) * Rig.Scale
			or math.abs((Plant - Rest):Dot(Rig.Root.CFrame.RightVector)) > 0.35 * Rig.Scale
		) then
			BeginSwing(Rig, Foot, Landing, true, Settings.SettleDuration)
		end

		if Foot.InSwing then
			-- Finish the current arc even while the gait's contact timing is blending.
			AdvanceSwing(Foot, DeltaTime)
			local LandingY = Ground.Y
			if Rig.Smooth then
				local Offset = Foot.SwingGoal - GroundPoint
				local NormalY = math.max(Normal.Y, MinimumSupportNormal)
				LandingY = GroundPoint.Y - (Offset.X * Normal.X + Offset.Z * Normal.Z) / NormalY
					+ Settings.HoofClearance * Rig.Scale / NormalY
			end
			LandingY = HorseTerrainPredictionController.Adapt(Rig.Prediction, Foot.Prediction, LandingY,
				(1 - Foot.SwingAlpha) * Foot.SwingDuration, Rig.Scale, DeltaTime)
			local _, FutureNormal = HorseTerrainPredictionController.Resolve(Rig.Prediction, Foot.Prediction)
			if FutureNormal then
				local Weight = math.sin(Foot.SwingAlpha * math.pi) ^ 2 * 0.5
				Foot.Normal = Normal:Lerp(FutureNormal, Weight).Unit
			end
			Foot.SwingGoal = Vector3.new(Foot.SwingGoal.X, LandingY, Foot.SwingGoal.Z)
			Position = GetSwingPosition(Rig, Foot)
			if Foot.SwingAlpha >= 1 then
				PlantFoot(Foot, Foot.SwingGoal, Hit.Instance)
			end
		else
			Position = Plant or Ground
		end
	end

	Foot.LastTarget = Position
	Foot.Target.WorldCFrame = CFrame.new(Position) * Rig.Root.CFrame.Rotation * Foot.Rest.Rotation
end

local function GetFrontFlexion(Rig: Rig, Foot: Foot): number
	if Rig.Resting then
		return 0
	end
	local Alpha = Foot.SwingAlpha
	if not Foot.SolverEnabled then
		local Distance = Blend(Settings.PlantDistance, Running.PlantDistance, Rig.Gallop)
		local Stance = math.min(Blend(Settings.StanceFraction, Running.StanceFraction, Rig.Gallop),
			Distance * Rig.Scale * 2 * Rig.Frequency / math.max(Rig.Speed, 1))
		Alpha = math.clamp((Foot.Cycle - Stance) / (1 - Stance), 0, 1)
	elseif not Foot.InSwing then
		return if Foot.Grounded then 0 else 0.5
	end
	local Fold = math.clamp(Alpha / Settings.FrontLeg.FoldEnd, 0, 1)
	local Extend = math.clamp((Alpha - Settings.FrontLeg.ExtendStart)
		/ (Settings.FrontLeg.ExtendEnd - Settings.FrontLeg.ExtendStart), 0, 1)
	Fold = Fold * Fold * (3 - 2 * Fold)
	Extend = Extend * Extend * (3 - 2 * Extend)

	return Fold * (1 - Extend)
end

local function SeedLeg(Rig: Rig, Foot: Foot, DeltaTime: number)
	local Phase = Foot.Cycle
	local Weight = math.clamp(Rig.Speed / 10, 0, 1)
	local Swing = if Foot.InSwing then math.sin(Foot.SwingAlpha * math.pi) else 0
	local Hip = math.cos(Phase * math.pi * 2) * Blend(0.36, 0.52, Rig.Gallop) * Weight
	if Foot.SolverEnabled then
		local Rest = Rig.Root.CFrame:PointToWorldSpace(Foot.Rest.Position)
		local Forward = (Foot.LastTarget - Rest):Dot(Rig.Root.CFrame.LookVector)
		Hip = math.atan2(Forward, 6 * Rig.Scale)
	else
		Swing = math.max(0, -math.sin(Phase * math.pi * 2)) * Weight
	end
	Swing *= Blend(1, 1.2, Rig.Gallop)
	local FrontFlexion = if Foot.Front then GetFrontFlexion(Rig, Foot) else 0

	for Index, Joint in Foot.Joints do
		local Seed = 0
		if Index == 1 then
			Seed = Hip
		elseif Foot.Front and Index == 3 then
			Seed = FrontFlexion * 0.12
		elseif Foot.Front and Index == 4 then
			Seed = -Settings.FrontLeg.SwingBend * FrontFlexion
		elseif not Foot.Front and Index == 2 then
			Seed = -0.08 - Swing * 0.6
		elseif not Foot.Front and Index == 3 then
			Seed = 0.1 + Swing * 0.8
		end

		-- Keep the last solved bend instead of choosing a new knee pose every frame.
		Seed *= 1 - Rig.IdleWeight
		local Response = Blend(Settings.PoseSeedResponse, Settings.Idle.PoseResponse, Rig.IdleWeight)
		if Foot.Front then
			Response = math.max(Response, Settings.FrontLeg.Response)
		end
		local Angle = if Foot.SolverEnabled and Foot.Seeded and Index ~= 1
			then Joint.Angle + (Seed - Joint.Angle) * (1 - math.exp(-Response * DeltaTime)) else Seed
		Joint.Angle = math.clamp(Angle, Joint.Minimum, Joint.Maximum)
	end
	Foot.Seeded = true
end

local function SolveLeg(Rig: Rig, Foot: Foot, Cache: { [Instance]: CFrame }, DeltaTime: number)
	local FrontFlexion = if Foot.Front then GetFrontFlexion(Rig, Foot) else 0
	local SupportBend = Settings.FrontLeg.SupportBend
	if Foot.Front and Foot.Grounded then
		local Rest = Rig.Root.CFrame:PointToWorldSpace(Foot.Rest.Position)
		local Raised = (Foot.LastTarget - Rest):Dot(Rig.Root.CFrame.UpVector) / Rig.Scale
		SupportBend += Settings.FrontLeg.TerrainBend * math.clamp((Raised - 0.2) / Settings.Prediction.MaximumFootRaise, 0, 1)
	end
	for Index, Joint in Foot.Joints do
		Joint.FrameAngle = Joint.Angle
		local Speed = if Index == 1 then Settings.MaximumHipSpeed
			else Blend(Settings.MaximumJointSpeed, Running.MaximumJointSpeed, Rig.Gallop)
		Joint.AngleStep = if Foot.Seeded then Speed * DeltaTime else math.huge
	end
	SeedLeg(Rig, Foot, DeltaTime)
	for _, Joint in Foot.Joints do
		Joint.Angle = math.clamp(Joint.Angle, Joint.FrameAngle - Joint.AngleStep, Joint.FrameAngle + Joint.AngleStep)
	end
	local Parent = Foot.Joints[1].Bone.Parent :: Bone
	local ParentFrame = GetBoneFrame(Parent, Cache)
	local Hinge = ParentFrame:VectorToWorldSpace(Foot.ParentAxis).Unit
	local Up = Rig.Root.CFrame.UpVector
	Up = (Up - Hinge * Up:Dot(Hinge)).Unit
	local Back = Hinge:Cross(Up).Unit
	local Frame = ParentFrame
	local Origin = (Frame * Foot.Joints[1].Bone.CFrame).Position

	for _, Joint in Foot.Joints do
		Frame *= Joint.Bone.CFrame * Joint.Rest * CFrame.fromAxisAngle(Joint.Axis, Joint.Angle)
		local Offset = Frame.Position - Origin
		Joint.Point = Vector2.new(Offset:Dot(Up), Offset:Dot(Back))
	end

	if Foot.SolverEnabled then
		local Offset = Foot.LastTarget - Origin
		local Target = Vector2.new(Offset:Dot(Up), Offset:Dot(Back))
		if Target.Magnitude > Foot.MaximumReach then
			Target = Target.Unit * Foot.MaximumReach
		end
		local Last = #Foot.Joints
		local SolveCount = if Foot.Front then 4 else 3
		local HipSeed = Foot.Joints[1].Angle
		local Iterations = if Foot.Grounded and not Foot.InSwing
			then math.round(Blend(Settings.IKIterations, Running.IKIterations, Rig.Gallop)) else Settings.IKIterations
		for _ = 1, Iterations do
			if (Foot.Joints[Last].Point - Target).Magnitude < 0.04 then
				break
			end
			for Index = SolveCount, 1, -1 do
				local Joint = Foot.Joints[Index]
				local ToTip = Foot.Joints[Last].Point - Joint.Point
				local ToGoal = Target - Joint.Point
				local Delta = math.atan2(ToTip.X * ToGoal.Y - ToTip.Y * ToGoal.X, ToTip:Dot(ToGoal))
				local Minimum = math.max(Joint.Minimum, Joint.FrameAngle - Joint.AngleStep)
				local Maximum = math.min(Joint.Maximum, Joint.FrameAngle + Joint.AngleStep)
				if Index == 1 then
					Minimum = math.max(Minimum, HipSeed - 0.2)
					Maximum = math.min(Maximum, HipSeed + 0.2)
				elseif Foot.Front and Index == 4 then
					local Bend = Blend(SupportBend, -Joint.Minimum, FrontFlexion)
					-- Release the carpus before touchdown without exceeding this frame's angular speed.
					Minimum = math.max(Minimum, math.min(-Bend, Joint.FrameAngle + Joint.AngleStep))
					Maximum = math.min(Maximum, math.max(-Settings.FrontLeg.SwingBend * FrontFlexion
						+ SupportBend, Joint.FrameAngle - Joint.AngleStep))
				end
				local Angle = math.clamp(Joint.Angle + Delta, Minimum, Maximum)
				Delta = Angle - Joint.Angle
				Joint.Angle = Angle
				local Cosine, Sine = math.cos(Delta), math.sin(Delta)
				for Child = Index + 1, Last do
					local Point = Foot.Joints[Child].Point - Joint.Point
					Foot.Joints[Child].Point = Joint.Point + Vector2.new(Point.X * Cosine - Point.Y * Sine, Point.X * Sine + Point.Y * Cosine)
				end
			end
		end
	end

	-- Compensate the toe pitch at its own hinge, without twisting the leg.
	local Total = 0
	for Index = 1, #Foot.Joints - 1 do
		Total += Foot.Joints[Index].Angle
	end
	local Pitch = -math.atan2(Foot.Normal:Dot(Rig.Root.CFrame.LookVector), Foot.Normal:Dot(Rig.Root.CFrame.UpVector))
	local Toe = Foot.Joints[#Foot.Joints]
	Toe.Angle = math.clamp(Pitch - Total,
		math.max(-Settings.HoofPitchLimit, Toe.FrameAngle - Toe.AngleStep),
		math.min(Settings.HoofPitchLimit, Toe.FrameAngle + Toe.AngleStep))
	for _, Joint in Foot.Joints do
		Joint.Bone.Transform = Joint.Rest * CFrame.fromAxisAngle(Joint.Axis, Joint.Angle)
	end
end

function HorseRigController.Update(Rig: Rig, DeltaTime: number, Now: number, Quality: number, Smooth: boolean?, LookDirection: Vector3?)
	HorseRigController.SetQuality(Rig, Quality)
	local SmoothRider = Smooth == true
	if Rig.Smooth ~= SmoothRider then
		Rig.LastFrame = Rig.Root.CFrame
		Rig.Smooth = SmoothRider
	end
	if Quality == 0 then
		return
	end

	local Frame = Rig.Root.CFrame
	local Displacement = Frame.Position - Rig.LastFrame.Position
	Rig.LastFrame = Frame
	if Displacement.Magnitude > 12 * Rig.Scale or DeltaTime > 0.3 then
		ClearContacts(Rig)
		Displacement = Vector3.zero
	end

	local Measured = Displacement / math.max(DeltaTime, 0.001)
	if Measured.Magnitude > 90 * Rig.Scale then
		Measured = Measured.Unit * 90 * Rig.Scale
	end
	local Response = 1 - math.exp(-10 * DeltaTime)
	Rig.Velocity = Rig.Velocity:Lerp(Measured, Response)
	local HorizontalSpeed = (Measured * Vector3.new(1, 0, 1)).Magnitude
	Rig.Speed += (HorizontalSpeed - Rig.Speed) * Response
	Rig.Resting = HorizontalSpeed < Settings.MoveThreshold and Rig.Speed < Settings.Idle.BlendSpeed
	local Idle = 1 - math.clamp(Rig.Speed / Settings.Idle.BlendSpeed, 0, 1)
	if Rig.Resting then
		Idle = 1
	end
	Rig.IdleWeight += (Idle - Rig.IdleWeight) * (1 - math.exp(-Settings.Idle.Response * DeltaTime))
	HorseTerrainPredictionController.UpdateMotion(Rig.Prediction, Frame, Rig.Velocity,
		if Rig.Root.Anchored then nil else Rig.Root.AssemblyAngularVelocity.Y, DeltaTime)
	local Tier = Rig.Model:GetAttribute("HorseTier")
	local Stats = if typeof(Tier) == "number" then HorseConfig.GetTier(Tier) else nil
	local StartSpeed = if Stats then Stats.Speed * HorseConfig.Gaits.AnimationStartRatio else Running.StartSpeed * Rig.Scale
	local FullSpeed = if Stats then Stats.Speed * HorseConfig.Gaits.AnimationFullRatio else Running.FullSpeed * Rig.Scale
	local RunWeight = math.clamp((Rig.Speed - StartSpeed) / (FullSpeed - StartSpeed), 0, 1)
	RunWeight = RunWeight * RunWeight * (3 - 2 * RunWeight)
	Rig.Gallop += (RunWeight - Rig.Gallop) * (1 - math.exp(-Running.BlendResponse * DeltaTime))
	local TrotFrequency = math.clamp(Rig.Speed / (Settings.StrideLength * Rig.Scale), Settings.MinimumFrequency, Settings.MaximumFrequency)
	local RunFrequency = math.clamp(Rig.Speed / (Running.StrideLength * Rig.Scale), Running.MinimumFrequency, Running.MaximumFrequency)
	local Frequency = Blend(TrotFrequency, RunFrequency, Rig.Gallop)
	Rig.Frequency = Frequency
	if Rig.Speed > Settings.MoveThreshold then
		Rig.Phase = (Rig.Phase + Frequency * DeltaTime) % 1
		for _, Foot in Rig.Feet do
			local Offset = Blend(Foot.Phase, Foot.RunPhase, Rig.Gallop)
			local Predicted = (Foot.Cycle + Frequency * DeltaTime) % 1
			local Error = (Rig.Phase + Offset - Predicted + 0.5) % 1 - 0.5
			-- Retiming never rewinds a leg or resets its planted contact.
			local Limit = Frequency * 0.45 * DeltaTime
			Foot.Cycle = (Predicted + math.clamp(Error, -Limit, Limit)) % 1
		end
	end

	Rig.ProbeElapsed += DeltaTime
	Rig.PredictionElapsed += DeltaTime
	local Probe = Rig.ProbeElapsed >= Settings.FullInterval
	local Predict = Settings.Prediction.Enabled and Rig.PredictionElapsed >= Settings.Prediction.Interval
	if Quality == 2 and (Rig.Smooth or Probe) then
		local PlantDistance = Blend(Settings.PlantDistance, Running.PlantDistance, Rig.Gallop)
		local Stance = math.min(Blend(Settings.StanceFraction, Running.StanceFraction, Rig.Gallop),
			PlantDistance * Rig.Scale * 2 * Frequency / math.max(Rig.Speed, 1))
		local Normal = Vector3.zero
		local Contacts = 0
		for _, Foot in Rig.Feet do
			UpdateFoot(Rig, Foot, if Rig.Smooth then DeltaTime else Rig.ProbeElapsed, Frequency, Stance, Probe, Predict)
			if Foot.Grounded then
				Normal += Foot.Normal
				Contacts += 1
			end
		end
		if Probe then
			Rig.ProbeElapsed %= Settings.FullInterval
		end
		if Predict then
			Rig.PredictionElapsed %= Settings.Prediction.Interval
		end
		HorseTerrainPredictionController.UpdateBody(Rig.Prediction, Rig.PredictionContacts, Rig.Scale, DeltaTime, Contacts > 0)
		local TargetNormal = if Contacts > 0 then Normal.Unit else Vector3.yAxis
		Rig.Normal = if Rig.Smooth then Rig.Normal:Lerp(TargetNormal, 1 - math.exp(-Settings.LocalNormalResponse * DeltaTime)).Unit else TargetNormal
	elseif Quality == 1 then
		Rig.Normal = Vector3.yAxis
		HorseTerrainPredictionController.UpdateBody(Rig.Prediction, Rig.PredictionContacts, Rig.Scale, DeltaTime, false)
	end

	PoseBody(Rig, DeltaTime, Now, LookDirection)
	local Cache: { [Instance]: CFrame } = {}
	for _, Foot in Rig.Feet do
		-- Support transforms can change between the 30 Hz ground probes.
		if Foot.Grounded and not Foot.InSwing then
			local Plant = GetPlant(Foot)
			if Plant then
				Foot.LastTarget = Plant
				Foot.Target.WorldPosition = Plant
			end
		end

		SolveLeg(Rig, Foot, Cache, DeltaTime)
	end
end

function HorseRigController.Destroy(Rig: Rig)
	HorseRiderController.Reset(Rig.Rider)
	for _, Pose in Rig.Poses do
		if Pose.Bone.Parent then
			Pose.Bone.Transform = Pose.Transform
		end
	end
	Rig.Targets:Destroy()
end

return HorseRigController
