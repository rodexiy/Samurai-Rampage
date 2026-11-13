local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HorseConfig = require(ReplicatedStorage.Shared.HorseConfig)
local Settings = HorseConfig.Animation.Tail
local HorseTailController = {}

type Spring = { Position: number, Velocity: number }
type Segment = {
	Bone: Bone,
	Rest: CFrame,
	SwayAxis: Vector3,
	PitchAxis: Vector3,
	Weight: number,
	Frequency: number,
	Yaw: Spring,
	Pitch: Spring,
}
export type State = {
	Segments: { Segment },
	LastVelocity: Vector3,
	Initialized: boolean,
}

local function Step(Spring: Spring, Target: number, Frequency: number, DeltaTime: number)
	local Omega = Frequency * math.pi * 2
	local Damping = math.clamp(Settings.Damping, 0.01, 0.99)
	local Rate = Omega * math.sqrt(1 - Damping * Damping)
	local Decay = math.exp(-Damping * Omega * DeltaTime)
	local Cosine, Sine = math.cos(Rate * DeltaTime), math.sin(Rate * DeltaTime)
	local Offset, Velocity = Spring.Position - Target, Spring.Velocity
	Spring.Position = Target + Decay * (Offset * Cosine + (Velocity + Damping * Omega * Offset) * Sine / Rate)
	Spring.Velocity = Decay * (Velocity * Cosine - (Damping * Omega * Velocity + Omega * Omega * Offset) * Sine / Rate)
end

local function Limit(Spring: Spring, Minimum: number, Maximum: number)
	local Position = math.clamp(Spring.Position, Minimum, Maximum)
	if Position ~= Spring.Position then
		Spring.Velocity = 0
		Spring.Position = Position
	end
end

function HorseTailController.Create(Root: BasePart, Bones: { [string]: Bone }, Original: { [Bone]: CFrame }): State
	if not Settings.Enabled then
		return { Segments = {}, LastVelocity = Vector3.zero, Initialized = false }
	end

	local Tail: { Bone } = {}
	for Name, Bone in Bones do
		if Name:match("^SK_tail_%d+$") then
			table.insert(Tail, Bone)
		end
	end
	table.sort(Tail, function(First: Bone, Second: Bone): boolean
		return tonumber(First.Name:match("%d+$")) < tonumber(Second.Name:match("%d+$"))
	end)
	local Total = 0
	for Index = 1, #Tail do
		Total += 0.65 ^ (Index - 1)
	end
	local Segments: { Segment } = {}
	local SwayAxis = -Root.CFrame.LookVector
	if #Tail > 1 then
		local Direction = Tail[#Tail].WorldPosition - Tail[1].WorldPosition
		local Axis = Direction:Cross(Root.CFrame.RightVector)
		if Axis.Magnitude > 0.001 then
			-- A hanging tail swings around its fore/aft axis, rather than twisting around world up.
			SwayAxis = Axis.Unit
		end
	end
	for Index, Bone in Tail do
		table.insert(Segments, {
			Bone = Bone, Rest = Original[Bone], Weight = 0.65 ^ (Index - 1) / Total,
			SwayAxis = Bone.TransformedWorldCFrame:VectorToObjectSpace(SwayAxis).Unit,
			PitchAxis = Bone.TransformedWorldCFrame:VectorToObjectSpace(Root.CFrame.RightVector).Unit,
			Frequency = Settings.Frequency / (1 + (Index - 1) * 0.25),
			Yaw = { Position = 0, Velocity = 0 }, Pitch = { Position = 0, Velocity = 0 },
		})
	end

	return { Segments = Segments, LastVelocity = Vector3.zero, Initialized = false }
end

function HorseTailController.Reset(State: State)
	State.Initialized = false
	State.LastVelocity = Vector3.zero
	for _, Segment in State.Segments do
		Segment.Yaw.Position, Segment.Yaw.Velocity = 0, 0
		Segment.Pitch.Position, Segment.Pitch.Velocity = 0, 0
		if Settings.Enabled and Segment.Bone.Parent then
			Segment.Bone.Transform = Segment.Rest
		end
	end
end

function HorseTailController.Update(State: State, Frame: CFrame, Velocity: Vector3, YawRate: number,
	Phase: number, Time: number, DeltaTime: number)
	if not Settings.Enabled then
		return
	end

	local Acceleration = if State.Initialized and DeltaTime > 0
		then (Velocity - State.LastVelocity) / DeltaTime else Vector3.zero
	State.LastVelocity, State.Initialized = Velocity, true
	if Acceleration.Magnitude > Settings.MaximumAcceleration then
		Acceleration = Acceleration.Unit * Settings.MaximumAcceleration
	end
	local LocalAcceleration = Frame:VectorToObjectSpace(Acceleration)
	local Moving = math.clamp(Velocity.Magnitude / 32, 0, 1)
	local SwishTime = Time % Settings.SwishPeriod
	local Swish = if SwishTime < Settings.SwishDuration
		then math.sin(SwishTime / Settings.SwishDuration * math.pi) ^ 2 * math.sin(SwishTime * math.pi * 3) else 0
	local Inertia = YawRate * Settings.TurnInfluence - LocalAcceleration.X * Settings.AccelerationInfluence
	local Pitch = math.clamp(-Settings.RunningLift * Moving + LocalAcceleration.Z * Settings.AccelerationInfluence,
		-Settings.MaximumLift, Settings.MaximumDrop)

	for Index, Segment in State.Segments do
		local Sway = math.sin(Time * 1.3 - Index * 0.35) * Settings.IdleSway
			+ math.sin(Phase * math.pi * 2 - Index * 0.45) * Settings.GaitSway * Moving
			+ math.sin(Time * 4.2 - Index * 0.4) * Settings.MovementSway * Moving
			+ Swish * Settings.SwishAngle * (1 - Moving)
		local Yaw = math.clamp(Inertia + Sway, -Settings.MaximumYaw, Settings.MaximumYaw)
		Step(Segment.Yaw, Yaw * Segment.Weight, Segment.Frequency, DeltaTime)
		Step(Segment.Pitch, Pitch * Segment.Weight, Segment.Frequency, DeltaTime)
		Limit(Segment.Yaw, -Settings.MaximumYaw * Segment.Weight, Settings.MaximumYaw * Segment.Weight)
		Limit(Segment.Pitch, -Settings.MaximumLift * Segment.Weight, Settings.MaximumDrop * Segment.Weight)
		Segment.Bone.Transform = Segment.Rest * CFrame.fromAxisAngle(Segment.SwayAxis, Segment.Yaw.Position)
			* CFrame.fromAxisAngle(Segment.PitchAxis, Segment.Pitch.Position)
	end
end

return HorseTailController
