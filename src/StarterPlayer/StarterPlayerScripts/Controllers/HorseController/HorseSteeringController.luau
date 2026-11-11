local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HorseConfig = require(ReplicatedStorage.Shared.HorseConfig)
local Settings = HorseConfig.Steering
local HorseSteeringController = {}

export type State = {
	Heading: Vector3,
	BodyHeading: Vector3,
	Speed: number,
	TurnRate: number,
	TurnSign: number,
	Bank: number,
}

local function Horizontal(Direction: Vector3): Vector3
	local Flat = Direction * Vector3.new(1, 0, 1)

	return if Flat.Magnitude > 0.001 then Flat.Unit else -Vector3.zAxis
end

local function Approach(Value: number, Target: number, Step: number): number
	return Value + math.clamp(Target - Value, -Step, Step)
end

local function SignedAngle(From: Vector3, To: Vector3): number
	return math.atan2(From:Cross(To).Y, math.clamp(From:Dot(To), -1, 1))
end

function HorseSteeringController.Create(Frame: CFrame, Velocity: Vector3): State
	local Heading = Horizontal(Frame.LookVector)

	return {
		Heading = Heading, BodyHeading = Heading,
		Speed = (Velocity * Vector3.new(1, 0, 1)).Magnitude,
		TurnRate = 0, TurnSign = 1, Bank = 0,
	}
end

local function Steer(State: State, Direction: Vector3, Stats: HorseConfig.HorseStats, DeltaTime: number)
	local DesiredRate = 0
	local Angle = 0
	if Direction.Magnitude > 0.01 then
		Angle = SignedAngle(State.Heading, Horizontal(Direction))
		if State.Heading:Dot(Direction.Unit) < -0.9999 and math.abs(State.Heading:Cross(Direction.Unit).Y) < 0.0001 then
			Angle = math.pi * State.TurnSign
		end
		if math.abs(Angle) > 0.001 then
			State.TurnSign = math.sign(Angle)
		end

		local Radius = Settings.MinimumRadius + State.Speed * State.Speed / Settings.LateralAcceleration
		local Blend = math.clamp(State.Speed / Settings.LowSpeed, 0, 1)
		Blend = Blend * Blend * (3 - 2 * Blend)
		local Limit = Settings.PivotTurnRate + (math.min(Settings.MaximumTurnRate, State.Speed / Radius)
			- Settings.PivotTurnRate) * Blend
		local StoppingRate = math.sqrt(2 * Settings.TurnAcceleration * math.abs(Angle))
		DesiredRate = math.clamp(Angle * Stats.TurnSpeed, -math.min(Limit, StoppingRate), math.min(Limit, StoppingRate))
	end

	State.TurnRate = Approach(State.TurnRate, DesiredRate, Settings.TurnAcceleration * DeltaTime)
	local Turn = State.TurnRate * DeltaTime
	if Direction.Magnitude > 0.01 and Turn * Angle > 0 and math.abs(Turn) > math.abs(Angle) then
		Turn = Angle
		State.TurnRate = 0
	end
	State.Heading = Horizontal(CFrame.fromAxisAngle(Vector3.yAxis, Turn):VectorToWorldSpace(State.Heading))
end

function HorseSteeringController.Update(State: State, Frame: CFrame, Velocity: Vector3, Direction: Vector3,
	Stats: HorseConfig.HorseStats, DeltaTime: number, Grounded: boolean, AngularVelocity: Vector3?, SpeedMultiplier: number?): Vector3
	local StepTime = math.clamp(DeltaTime, 0, 0.1)
	local Input = Direction * Vector3.new(1, 0, 1)
	local Throttle = math.clamp(Input.Magnitude, 0, 1)
	local Acceleration = if Throttle > 0.01 then Stats.Acceleration else HorseConfig.Braking
	local MaximumSpeed = Stats.Speed * math.clamp(SpeedMultiplier or 1, 0, 1)
	State.Speed = math.clamp(Approach(State.Speed, MaximumSpeed * Throttle, Acceleration * StepTime), 0, Stats.Speed)
	Steer(State, Input, Stats, StepTime)

	local BodyHeading = Horizontal(Frame.LookVector)
	local ActualSpeed = (Velocity * Vector3.new(1, 0, 1)).Magnitude
	local YawRate = if AngularVelocity then AngularVelocity.Y
		else SignedAngle(State.BodyHeading, BodyHeading) / math.max(DeltaTime, 0.001)
	State.BodyHeading = BodyHeading
	local Bank = 0
	if Grounded and DeltaTime > 0 and DeltaTime <= 0.3 then
		Bank = math.clamp(math.atan(ActualSpeed * YawRate / math.max(workspace.Gravity, 1)) * Settings.BankStrength,
			-Settings.MaximumBank, Settings.MaximumBank)
	end
	State.Bank += (Bank - State.Bank) * (1 - math.exp(-Settings.BankResponse * StepTime))

	-- Travel follows the physical body, even while its target heading is still turning.
	return BodyHeading * State.Speed
end

return HorseSteeringController
