local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HorseConfig = require(ReplicatedStorage.Shared.HorseConfig)
local Settings = HorseConfig.Animation.Prediction
local HorseTerrainPredictionController = {}

export type Motion = {
	Velocity: Vector3,
	Acceleration: Vector3,
	YawRate: number,
	Heading: Vector3,
	Time: number,
	BodyPitch: number,
	BodyLift: number,
}
export type Contact = {
	Front: boolean,
	Hit: RaycastResult?,
	Frame: CFrame?,
	FutureFrame: CFrame?,
	Time: number,
	ReferenceY: number,
	RestZ: number,
	RequiredLift: number,
	ExtraLift: number,
	HeightOffset: number,
}

function HorseTerrainPredictionController.Create(): Motion
	return {
		Velocity = Vector3.zero, Acceleration = Vector3.zero, YawRate = 0,
		Heading = -Vector3.zAxis, Time = 0, BodyPitch = 0, BodyLift = 0,
	}
end

function HorseTerrainPredictionController.CreateContact(Front: boolean): Contact
	return { Front = Front, Time = -math.huge, ReferenceY = 0, RestZ = 0, RequiredLift = 0, ExtraLift = 0, HeightOffset = 0 }
end

function HorseTerrainPredictionController.UpdateMotion(State: Motion, Frame: CFrame, Velocity: Vector3, YawRate: number?, DeltaTime: number)
	local Flat = Velocity * Vector3.new(1, 0, 1)
	local Heading = Frame.LookVector * Vector3.new(1, 0, 1)
	Heading = if Heading.Magnitude > 0.001 then Heading.Unit else State.Heading
	local Rate = YawRate or math.atan2(State.Heading:Cross(Heading).Y, State.Heading:Dot(Heading)) / math.max(DeltaTime, 0.001)
	local Acceleration = math.clamp((Flat.Magnitude - State.Velocity.Magnitude) / math.max(DeltaTime, 0.001),
		-Settings.MaximumAcceleration, Settings.MaximumAcceleration)
	local Response = 1 - math.exp(-8 * DeltaTime)
	State.Acceleration = State.Acceleration:Lerp((if Flat.Magnitude > 0.01 then Flat.Unit else Heading) * Acceleration, Response)
	State.YawRate += (math.clamp(Rate, -HorseConfig.Steering.MaximumTurnRate, HorseConfig.Steering.MaximumTurnRate) - State.YawRate) * Response
	State.Velocity, State.Heading = Flat, Heading
	State.Time += DeltaTime
end

function HorseTerrainPredictionController.GetFutureFrame(State: Motion, Frame: CFrame, Time: number, Scale: number): CFrame
	local Horizon = math.clamp(Time, 0, Settings.MaximumTime)
	local Speed = State.Velocity.Magnitude
	local Acceleration = if Speed > 0.001 then State.Acceleration:Dot(State.Velocity.Unit) else 0
	if Acceleration < -0.001 then
		Horizon = math.min(Horizon, Speed / -Acceleration)
	end
	local Angle = State.YawRate * Horizon
	local TravelTime = if math.abs(State.YawRate) > 0.001 then 2 * math.sin(Angle * 0.5) / State.YawRate else Horizon
	local Offset = CFrame.fromAxisAngle(Vector3.yAxis, Angle * 0.5):VectorToWorldSpace(State.Velocity) * TravelTime
		+ (if Speed > 0.001 then State.Velocity.Unit else Vector3.zero) * (Acceleration * 0.5 * Horizon * Horizon)
	local Limit = Settings.MaximumDistance * Scale
	if Offset.Magnitude > Limit then
		Offset = Offset.Unit * Limit
	end

	return CFrame.new(Frame.Position + Offset) * CFrame.fromAxisAngle(Vector3.yAxis, Angle) * Frame.Rotation
end

local function Cast(Point: Vector3, Scale: number, Params: RaycastParams): RaycastResult?
	local Origin = Point + Vector3.yAxis * Settings.ProbeHeight * Scale
	local Bottom = Point.Y - Settings.ProbeDepth * Scale
	for _ = 1, 3 do
		local Hit = workspace:Raycast(Origin, Vector3.new(0, Bottom - Origin.Y, 0), Params)
		if not Hit or Hit.Material == Enum.Material.Water then
			return nil
		end
		if Hit.Normal.Y >= math.cos(HorseConfig.Grounding.MaximumSupportSlope)
			and Hit.Position.Y - Point.Y <= Settings.MaximumSurfaceRise * Scale then
			return Hit
		end
		local NextY = Hit.Position.Y - 0.05 * Scale
		if NextY <= Bottom or NextY >= Origin.Y - 0.001 then
			return nil
		end
		Origin = Vector3.new(Point.X, NextY, Point.Z)
	end

	return nil
end

function HorseTerrainPredictionController.Sample(State: Motion, Contact: Contact, Frame: CFrame, LocalLanding: Vector3,
	Time: number, GroundY: number, Scale: number, Params: RaycastParams)
	local Horizon = math.clamp(Time, 0, Settings.MaximumTime)
	local Future = HorseTerrainPredictionController.GetFutureFrame(State, Frame, Horizon, Scale)
	local Landing = Future:PointToWorldSpace(LocalLanding)
	local Hit = Cast(Landing, Scale, Params)
	Contact.Hit = Hit
	Contact.Frame = if Hit and Hit.Instance:IsA("BasePart") and not Hit.Instance:IsA("Terrain") then Hit.Instance.CFrame else nil
	Contact.FutureFrame = Future
	Contact.Time, Contact.ReferenceY, Contact.RestZ = State.Time, Landing.Y, LocalLanding.Z
	Contact.RequiredLift = 0
	-- Two samples along the curved travel path catch obstacles before the next support.
	for Index = 1, 2 do
		local Alpha = Index / 3
		local StepFrame = HorseTerrainPredictionController.GetFutureFrame(State, Frame, Horizon * Alpha, Scale)
		local Obstacle = Cast(StepFrame:PointToWorldSpace(LocalLanding), Scale, Params)
		if Obstacle then
			local Baseline = GroundY + ((if Hit then Hit.Position.Y else GroundY) - GroundY) * Alpha
			Contact.RequiredLift = math.max(Contact.RequiredLift,
				math.clamp((Obstacle.Position.Y - Baseline) * 0.8, 0, Settings.MaximumExtraLift * Scale))
		end
	end
end

function HorseTerrainPredictionController.Resolve(State: Motion, Contact: Contact): (Vector3?, Vector3?)
	local Hit = Contact.Hit
	if not Hit or not Hit.Instance:IsDescendantOf(workspace) or State.Time - Contact.Time > Settings.Interval * 3 + 0.1 then
		return nil, nil
	end
	if Contact.Frame and Hit.Instance:IsA("BasePart") then
		local Change = Hit.Instance.CFrame * Contact.Frame:Inverse()
		return Change:PointToWorldSpace(Hit.Position), Change:VectorToWorldSpace(Hit.Normal)
	end

	return Hit.Position, Hit.Normal
end

function HorseTerrainPredictionController.Adapt(State: Motion, Contact: Contact, GroundY: number, Remaining: number,
	Scale: number, DeltaTime: number): (number, number)
	local Point = HorseTerrainPredictionController.Resolve(State, Contact)
	local Weight = math.clamp(Remaining / Settings.LandingBlendTime, 0, 1)
	Weight = Weight * Weight * (3 - 2 * Weight)
	local Offset = if Point then math.clamp(Point.Y + HorseConfig.Animation.HoofClearance * Scale - GroundY,
		-Settings.MaximumFootLower * Scale, Settings.MaximumFootRaise * Scale) else 0
	local Response = 1 - math.exp(-Settings.Response * DeltaTime)
	Contact.HeightOffset += (Offset - Contact.HeightOffset) * Response
	Contact.ExtraLift += ((if Point then Contact.RequiredLift else 0) - Contact.ExtraLift) * Response
	-- Fade after smoothing so no residual prediction can snap down at touchdown.
	return GroundY + Contact.HeightOffset * Weight, Contact.ExtraLift
end

function HorseTerrainPredictionController.UpdateBody(State: Motion, Contacts: { Contact }, Scale: number, DeltaTime: number, Supported: boolean)
	local Front, Back, FrontZ, BackZ, FrontCount, BackCount = 0, 0, 0, 0, 0, 0
	if Supported then
		for _, Contact in Contacts do
			local Point = HorseTerrainPredictionController.Resolve(State, Contact)
			if Point then
				local Delta = math.clamp(Point.Y - Contact.ReferenceY, -Settings.MaximumFootLower * Scale, Settings.MaximumFootRaise * Scale)
				if Contact.Front then
					Front += Delta
					FrontZ += Contact.RestZ
					FrontCount += 1
				else
					Back += Delta
					BackZ += Contact.RestZ
					BackCount += 1
				end
			end
		end
	end
	local Pitch, Lift = 0, 0
	if FrontCount > 0 and BackCount > 0 then
		Front, Back = Front / FrontCount, Back / BackCount
		Pitch = math.clamp(math.atan2(Front - Back, math.max(Scale, BackZ / BackCount - FrontZ / FrontCount)),
			-Settings.MaximumBodyPitch, Settings.MaximumBodyPitch)
		Lift = math.clamp((Front + Back) * 0.08, -Settings.MaximumBodyLift * Scale, Settings.MaximumBodyLift * Scale)
	end
	local Response = 1 - math.exp(-Settings.Response * 0.5 * DeltaTime)
	State.BodyPitch += (Pitch - State.BodyPitch) * Response
	State.BodyLift += (Lift - State.BodyLift) * Response
end

return HorseTerrainPredictionController
