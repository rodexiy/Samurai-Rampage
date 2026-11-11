return function(Prediction: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage.Shared.HorseConfig)
	local Settings = Config.Animation.Prediction
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local State = Prediction.Create()
	State.Velocity = -Vector3.zAxis * 20
	local Future = Prediction.GetFutureFrame(State, CFrame.identity, 0.4, 1)
	Check((Future.Position - Vector3.new(0, 0, -8)).Magnitude < 0.001, "Look ahead by the remaining travel time")
	State.YawRate = -1
	Future = Prediction.GetFutureFrame(State, CFrame.identity, 0.4, 1)
	Check(Future.Position.X > 1 and Future.LookVector.X > 0.3, "Right turns sample a curved landing instead of a straight ray")
	State.YawRate = 1
	Future = Prediction.GetFutureFrame(State, CFrame.identity, 0.4, 1)
	Check(Future.Position.X < -1 and Future.LookVector.X < -0.3, "Left curves mirror the predicted arc")
	State.YawRate = 0
	State.Acceleration = -Vector3.zAxis * 20
	Future = Prediction.GetFutureFrame(State, CFrame.identity, 0.4, 1)
	Check(Future.Position.Z < -9, "Acceleration shifts the next support ahead")
	State.Velocity = -Vector3.zAxis * 2
	State.Acceleration = Vector3.zAxis * 60
	Future = Prediction.GetFutureFrame(State, CFrame.identity, 0.4, 1)
	Check(Future.Position.Z <= 0 and Future.Position.Z > -0.1, "Braking forecasts a stop without inventing backwards movement")
	State.Velocity, State.Acceleration = -Vector3.zAxis * 200, Vector3.zero
	Future = Prediction.GetFutureFrame(State, CFrame.identity, 10, 1)
	Check(Future.Position.Magnitude <= Settings.MaximumDistance + 0.001, "Clamp the prediction horizon and range")

	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseTerrainPredictionTests"
	Fixture.Parent = workspace
	local BaseY = 3800
	local function Part(Name: string, Position: Vector3, Size: Vector3): Part
		local Object = Instance.new("Part")
		Object.Name, Object.Position, Object.Size = Name, Position, Size
		Object.Anchored = true
		Object.Parent = Fixture

		return Object
	end
	local Floor = Part("Floor", Vector3.new(0, BaseY - 1, 0), Vector3.new(100, 2, 100))
	local Step = Part("UpcomingStep", Vector3.new(0, BaseY + 1, -13), Vector3.new(6, 2, 16))
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = { Fixture }
	Params.RespectCanCollide = true
	local Frame = CFrame.new(0, BaseY + 5, 0)
	local Success, Error = pcall(function()
		State = Prediction.Create()
		State.Velocity = -Vector3.zAxis * 20
		local Contact = Prediction.CreateContact(true)
		Prediction.Sample(State, Contact, Frame, Vector3.new(0, -5, 0), 0.4, BaseY, 1, Params)
		Check(Contact.Hit and Contact.Hit.Instance == Step, "Find an elevated support before the horse reaches it")
		Check(Contact.FutureFrame.Position.Z < -7 and Frame.Position.Z == 0, "The sample belongs to the future body position")
		local Goal = BaseY
		for _ = 1, 30 do
			Goal = Prediction.Adapt(State, Contact, BaseY, 0.4, 1, 1 / 60)
		end
		Check(Goal > BaseY + 1 and Goal <= BaseY + Settings.MaximumFootRaise + 0.001,
			"Prepare the hoof height early while respecting its vertical reach")
		local AlmostLanded = Prediction.Adapt(State, Contact, BaseY, 0.001, 1, 1 / 120)
		Check(AlmostLanded - BaseY < 0.001, "The forecast fades continuously before touchdown without a late drop")
		Goal = Prediction.Adapt(State, Contact, BaseY, 0, 1, 1 / 60)
		Check(Goal == BaseY, "Touchdown hands height control back to the actual floor")

		local Front, Back = Prediction.CreateContact(true), Prediction.CreateContact(false)
		Prediction.Sample(State, Front, Frame, Vector3.new(0, -5, -3), 0.4, BaseY, 1, Params)
		Prediction.Sample(State, Back, Frame, Vector3.new(0, -5, 4), 0.4, BaseY, 1, Params)
		for _ = 1, 60 do
			Prediction.UpdateBody(State, { Front, Back }, 1, 1 / 60, true)
		end
		Check(State.BodyPitch > math.rad(2) and State.BodyPitch <= Settings.MaximumBodyPitch,
			"The visual body prepares for the step before reaching its edge")
		for _ = 1, 120 do
			Prediction.UpdateBody(State, { Front, Back }, 1, 1 / 60, false)
		end
		Check(math.abs(State.BodyPitch) < 0.001 and math.abs(State.BodyLift) < 0.001, "No body anticipation remains while unsupported")

		Step.CanCollide = false
		local Rock = Part("IntermediateRock", Vector3.new(0, BaseY + 0.6, -16 / 3), Vector3.new(3, 1.2, 0.8))
		Prediction.Sample(State, Contact, Frame, Vector3.new(0, -5, 0), 0.4, BaseY, 1, Params)
		Check(Contact.Hit and Contact.Hit.Instance == Floor and Contact.RequiredLift > 0.5,
			"An intermediate rock increases clearance even when the landing itself is flat")
		Rock.CanCollide = false
		State.YawRate = -1
		local CurveFrame = Prediction.GetFutureFrame(State, Frame, 0.4, 1)
		local CurveRock = Part("CurvedSupport", CurveFrame.Position + Vector3.new(0, -4.5, 0), Vector3.new(0.8, 1, 0.8))
		Prediction.Sample(State, Contact, Frame, Vector3.new(0, -5, 0), 0.4, BaseY, 1, Params)
		Check(Contact.Hit and Contact.Hit.Instance == CurveRock, "The next support follows the curved travel path")
		State.YawRate = 0
		Prediction.Sample(State, Contact, Frame, Vector3.new(0, -5, 0), 0.4, BaseY, 1, Params)
		Check(Contact.Hit and Contact.Hit.Instance == Floor, "Changing direction replans the landing instead of keeping the old target")
		CurveRock:Destroy()
		local Ceiling = Part("Overhead", Vector3.new(0, BaseY + 3.25, -8), Vector3.new(5, 0.5, 5))
		Prediction.Sample(State, Contact, Frame, Vector3.new(0, -5, 0), 0.4, BaseY, 1, Params)
		Check(Contact.Hit and Contact.Hit.Instance == Floor, "Do not choose an overhead surface as the next support")
		Ceiling:Destroy()
		local Before = Prediction.Resolve(State, Contact)
		Floor.CFrame += Vector3.yAxis * 0.25
		local After = Prediction.Resolve(State, Contact)
		Check(Before and After and math.abs(After.Y - Before.Y - 0.25) < 0.001, "Cached predictions follow moving supports between probes")
		State.Time += 1
		Check(Prediction.Resolve(State, Contact) == nil, "Expire stale predictions instead of reusing an obsolete landing")
		Prediction.Sample(State, Contact, Frame, Vector3.new(0, -5, 0), 0.4, BaseY, 1, Params)
		Floor:Destroy()
		Check(Prediction.Resolve(State, Contact) == nil, "A removed support invalidates its prediction immediately")
		Prediction.Sample(State, Contact, Frame, Vector3.new(0, -5, 0), 0.4, BaseY, 1, Params)
		Check(Contact.Hit == nil, "A gap cannot become a predicted floor")
		Goal = Prediction.Adapt(State, Contact, BaseY, 0, 1, 1 / 60)
		Check(Goal == BaseY, "A missing future support cannot hold a hoof above the real contact")
	end)

	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorseTerrainPrediction: %d checks passed", Checks)
end
