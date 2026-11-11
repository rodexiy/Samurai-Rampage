return function(Steering: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage.Shared.HorseConfig)
	local Stats = Config.Tiers[5]
	local Settings = Config.Steering
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Frame(Heading: Vector3): CFrame
		return CFrame.lookAt(Vector3.zero, Heading)
	end

	local Initial = Frame(-Vector3.zAxis)
	local State = Steering.Create(Initial, -Vector3.zAxis * 56)
	local Travel = Steering.Update(State, Initial, -Vector3.zAxis * 56, Vector3.xAxis, Stats, 1 / 60, true)
	Check(Travel:Dot(-Vector3.zAxis) > 55.99 and math.abs(Travel.X) < 0.001,
		"A right input keeps travelling along the current body instead of strafing")
	Check(State.Heading:Dot(-Vector3.zAxis) > 0.999, "The first turn does not snap the body heading")
	Check(State.Speed == 56, "Steering preserves forward speed")
	Check(State.Bank == 0, "A commanded turn alone cannot bank a body that has not rotated")

	local function Circle(Speed: number, Side: number, FPS: number): (number, number, Vector3)
		local Rig = Steering.Create(Initial, -Vector3.zAxis * Speed)
		local Position = Vector3.zero
		for _ = 1, FPS * 4 do
			local Body = Frame(Rig.Heading)
			local Desired = CFrame.fromAxisAngle(Vector3.yAxis, Side * math.pi * 0.5):VectorToWorldSpace(Rig.Heading)
			local Movement = Steering.Update(Rig, Body, Body.LookVector * Speed, Desired * Speed / Stats.Speed,
				Stats, 1 / FPS, true)
			Position += Movement / FPS
			assert(Movement.Unit:Dot(Body.LookVector) > 0.9999, "Travel stays aligned to the physical body through the curve")
			assert(math.abs(Rig.Bank) <= Settings.MaximumBank + 0.0001, "Corner banking remains subtle")
		end

		return Speed / math.abs(Rig.TurnRate), Rig.Bank, Position
	end

	local SlowRadius, SlowBank = Circle(12, -1, 60)
	local FastRadius, FastBank, FastPosition = Circle(56, -1, 60)
	Check(FastRadius > SlowRadius * 3, "Galloping has a wider turning radius than slow travel")
	Check(math.abs(FastRadius - (Settings.MinimumRadius + 56 * 56 / Settings.LateralAcceleration)) < 0.01,
		"The moving horse respects its configured curve radius")
	Check(FastBank < -math.rad(2) and SlowBank < 0, "Right-hand curves bank inward")
	local _, LeftBank = Circle(56, 1, 60)
	Check(LeftBank > math.rad(2), "Left-hand curves bank inward in the opposite direction")
	for _, FPS in { 30, 120 } do
		local Radius, Bank, Position = Circle(56, -1, FPS)
		Check(math.abs(Radius - FastRadius) < 0.01 and math.abs(Bank - FastBank) < 0.002,
			"Steering and banking agree at " .. FPS .. " FPS")
		Check((Position - FastPosition).Magnitude < 2, "The curve trajectory is stable across frame rates")
	end

	State = Steering.Create(Initial, -Vector3.zAxis * 56)
	local Position = Vector3.zero
	for _ = 1, 30 do
		local Body = Frame(State.Heading)
		Travel = Steering.Update(State, Body, Body.LookVector * 56, Vector3.zAxis, Stats, 1 / 60, true)
		Position += Travel / 60
	end
	Check(Position.Z < -20 and math.abs(Position.X) > 2 and State.Speed == 56,
		"Opposite input makes a U-turn arc instead of reversing or stopping instantly")

	for _ = 1, 120 do
		local Body = Frame(State.Heading)
		Steering.Update(State, Body, Body.LookVector * State.Speed, Vector3.zero, Stats, 1 / 60, true)
	end
	Check(State.Speed == 0 and math.abs(State.TurnRate) < 0.0001 and math.abs(State.Bank) < 0.001,
		"Releasing input brakes and settles the steering and bank smoothly")

	State = Steering.Create(Initial, -Vector3.zAxis * 56)
	State.Bank = Settings.MaximumBank
	for _ = 1, 90 do
		Steering.Update(State, Initial, Vector3.zero, Vector3.xAxis, Stats, 1 / 60, false)
	end
	Check(math.abs(State.Bank) < 0.001, "An airborne or stationary mount releases the curve bank")

	State = Steering.Create(Initial, Vector3.zero)
	for _ = 1, 240 do
		local Body = Frame(State.Heading)
		Steering.Update(State, Body, Body.LookVector * State.Speed, -Vector3.zAxis * 0.5, Stats, 1 / 60, true)
	end
	Check(math.abs(State.Speed - Stats.Speed * 0.5) < 0.001, "Analog input retains proportional speed control")
	Check(State.Heading:Dot(-Vector3.zAxis) > 0.999, "Straight travel has no heading drift")

	return string.format("HorseSteering: %d checks passed", Checks)
end
