return function(Balance: any): string
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseBalanceStabilityTests"
	Fixture.Parent = workspace
	local Origin = Vector3.new(0, 19000, 0)
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(100, 2, 100)
	Floor.Parent = Fixture
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = { Floor }
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local function Samples(Range: number): { any }
		Floor.CFrame = CFrame.new(Origin) * CFrame.Angles(0, 0, math.atan(Range * 0.5)) * CFrame.new(0, -1, 0)
		local Result = {}
		for _, X in { -1, 1 } do
			local Hit = workspace:Raycast(Origin + Vector3.new(X, 5, 0), -Vector3.yAxis * 10, Params)
			table.insert(Result, { Rest = Vector3.new(X, 0, 0), Hit = Hit, Frame = Floor.CFrame })
		end

		return Result
	end

	local Success, Error = pcall(function()
		local Frame = CFrame.new(Origin)
		local State = Balance.Create()
		for _ = 1, 120 do
			Balance.Update(State, Frame, 1, 1 / 60, Samples(0.8))
		end
		local Baseline = State.Offset
		Check(Baseline < -0.35, "A side slope engages body compensation")
		local Switches, PeakChange = 0, 0
		for Index = 1, 480 do
			local Input = Samples(0.8)
			if Index % 60 < 10 then
				Input[1].Hit = nil
			end
			local Previous = State.Offset
			Balance.Update(State, Frame, 1, 1 / 60, Input)
			if State.Offset >= -0.01 then
				Switches += 1
			end
			PeakChange = math.max(PeakChange, math.abs(State.Offset - Previous))
		end
		Check(Switches == 0 and math.abs(State.Offset - Baseline) < 0.005,
			"Short repeated loss of one side cannot turn compensation off")
		Check(PeakChange < 0.005, "A missed ground probe cannot jerk the compensation target")

		for _ = 1, 60 do
			local Input = Samples(0.8)
			Input[1].Hit = nil
			Balance.Update(State, Frame, 1, 1 / 60, Input)
		end
		Check(not State.Active and State.Offset == 0, "Old support expires after a genuine prolonged loss")

		Balance.Reset(State)
		Balance.Update(State, Frame, 1, 1 / 60, Samples(0.13))
		Check(not State.Active, "A small height difference does not engage balance")
		Balance.Update(State, Frame, 1, 1 / 60, Samples(0.17))
		Check(State.Active, "Crossing the engage threshold enables balance")
		for Index = 1, 120 do
			Balance.Update(State, Frame, 1, 1 / 60, Samples(if Index % 2 == 0 then 0.14 else 0.16))
			Check(State.Active, "Noise around the engage threshold cannot keep toggling balance")
		end
		Balance.Update(State, Frame, 1, 1 / 60, Samples(0.08))
		Check(not State.Active, "Balance releases below its separate release threshold")

		local Responses = {}
		for _, FPS in { 15, 30, 60, 120 } do
			Balance.Reset(State)
			for _ = 1, FPS do
				local Value = Balance.Update(State, Frame, 1, 1 / FPS, Samples(0.8))
				Check(Value <= 0 and Value >= -0.401, "The damped response cannot overshoot a fixed target")
			end
			table.insert(Responses, State.Offset)
		end
		Check(math.abs(Responses[1] - Responses[4]) < 0.001, "Balance response is consistent across frame rates")

		local MovingInput = Samples(0.8)
		Floor.CFrame += Vector3.yAxis * 0.1
		MovingInput[1].Hit = nil
		Balance.Update(State, Frame, 1, 1 / 60, MovingInput)
		local Held = State.Contacts[1]
		Check(Held ~= nil and State.Active, "Remembered support follows the moving platform during a brief miss")
		Check(State.Offset > Responses[4], "A rising platform continuously reduces the required body drop")

		local Input = Samples(0.8)
		for _, Sample in Input do
			Sample.Hit = nil
		end
		Balance.Update(State, Frame, 1, 1 / 60, Input)
		Check(not State.Active and next(State.Contacts) == nil, "Losing all support immediately discards contact memory")
		for _ = 1, 60 do
			Balance.Update(State, Frame, 1, 1 / 60, Input)
		end
		Check(State.Offset == 0 and State.Velocity == 0, "An airborne horse smoothly returns to neutral")

		Balance.Update(State, Frame, 1, 1 / 60, Samples(0.8))
		Balance.Reset(State)
		Check(State.Offset == 0 and State.Velocity == 0 and not State.Active and next(State.Contacts) == nil,
			"Teleport and quality resets clear both compensation and its velocity")

		local RemovedInput = Samples(0.8)
		Balance.Update(State, Frame, 1, 1 / 60, RemovedInput)
		Floor:Destroy()
		Balance.Update(State, Frame, 1, 1 / 60, RemovedInput)
		Check(not State.Active and next(State.Contacts) == nil, "Destroyed supports cannot survive in the balance cache")
	end)

	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorseBalanceStability: %d checks passed", Checks)
end
