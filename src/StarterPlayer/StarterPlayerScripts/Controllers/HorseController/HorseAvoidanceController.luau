local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HorseConfig = require(ReplicatedStorage.Shared.HorseConfig)
local HorseGrounding = require(ReplicatedStorage.Shared.HorseGrounding)
local Settings = HorseConfig.Steering.Avoidance
local HorseAvoidanceController = {}

export type State = {
	Elapsed: number,
	Side: number,
	Direction: Vector3,
	Weight: number,
	TargetWeight: number,
	SpeedMultiplier: number,
	TargetSpeedMultiplier: number,
}

function HorseAvoidanceController.Create(): State
	return {
		Elapsed = Settings.ScanInterval, Side = 1, Direction = -Vector3.zAxis,
		Weight = 0, TargetWeight = 0, SpeedMultiplier = 1, TargetSpeedMultiplier = 1,
	}
end

local function Scan(State: State, Ground: HorseGrounding.State, Input: Vector3, Speed: number)
	local Distance = math.clamp(Speed * Settings.LookAheadTime, Settings.MinimumDistance, Settings.MaximumDistance)
	local Desired = Input.Unit
	local Forward = HorseGrounding.HorizontalDirection(Ground.Root.CFrame.LookVector)
	local SupportDistance = math.min(Distance, math.max(4, Speed * 0.3))
	local Clearance, Normal, Supported = HorseGrounding.ScanMovement(Ground, Desired, Distance, SupportDistance)
	local ForwardClearance, ForwardNormal = Clearance, Normal
	if Desired:Dot(Forward) < 0.999 then
		ForwardClearance, ForwardNormal = HorseGrounding.ScanMovement(Ground, Forward, Distance, SupportDistance)
	end
	if not Normal and not ForwardNormal then
		State.TargetWeight, State.TargetSpeedMultiplier = 0, 1
		return
	end

	local BestDirection, BestScore, BestSide = Forward, -math.huge, State.Side
	local BestClearance = 0
	for _, Angle in { 0, 30, -30, 60, -60, 90, -90 } do
		local Candidate = CFrame.fromAxisAngle(Vector3.yAxis, math.rad(Angle)):VectorToWorldSpace(Desired)
		local Free, Safe = Clearance, Supported
		if Angle ~= 0 then
			local CandidateClearance, _, HasGround = HorseGrounding.ScanMovement(Ground, Candidate, Distance, SupportDistance)
			Free, Safe = CandidateClearance, HasGround
		end
		if not Safe then
			continue
		end
		local Side = math.sign(Forward:Cross(Candidate).Y)
		local Preference = if Side ~= 0 and Side == State.Side then Settings.SidePreference else 0
		local Score = Free / Distance * 2 + Candidate:Dot(Desired) * 0.6 + Preference
		if Score > BestScore then
			BestDirection, BestScore, BestClearance = Candidate, Score, Free
			BestSide = if Side ~= 0 then Side else BestSide
		end
	end
	if BestScore == -math.huge or BestClearance < Ground.Root.Size.X then
		State.TargetWeight, State.TargetSpeedMultiplier = 0, Settings.MinimumSpeedMultiplier
		return
	end

	State.Direction, State.Side = BestDirection, BestSide
	State.TargetWeight = 1
	local TurnSpace = math.min(Clearance, ForwardClearance, BestClearance)
	local SafeSpeed = math.sqrt(math.max(0, TurnSpace * 0.7 - HorseConfig.Steering.MinimumRadius)
		* HorseConfig.Steering.LateralAcceleration)
	State.TargetSpeedMultiplier = math.clamp(SafeSpeed / math.max(Speed, 1), Settings.MinimumSpeedMultiplier, 1)
end

function HorseAvoidanceController.Update(State: State, Ground: HorseGrounding.State, Input: Vector3,
	Speed: number, DeltaTime: number): (Vector3, number)
	local Flat = Input * Vector3.new(1, 0, 1)
	if Flat.Magnitude < 0.01 or not Ground.Grounded then
		State.TargetWeight, State.TargetSpeedMultiplier = 0, 1
	else
		State.Elapsed += DeltaTime
		if State.Elapsed >= Settings.ScanInterval then
			State.Elapsed %= Settings.ScanInterval
			Scan(State, Ground, Flat, Speed)
		end
	end
	local Response = 1 - math.exp(-Settings.Response * DeltaTime)
	State.Weight += (State.TargetWeight - State.Weight) * Response
	State.SpeedMultiplier += (State.TargetSpeedMultiplier - State.SpeedMultiplier) * Response
	local Direction = Flat:Lerp(State.Direction * Flat.Magnitude, State.Weight)
	if Direction.Magnitude > 0.001 then
		Direction = Direction.Unit * Flat.Magnitude
	end

	return Direction, State.SpeedMultiplier
end

return HorseAvoidanceController
