return function(Replication: any, Tilt: any, Look: any): string
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Near(First: CFrame, Second: CFrame): boolean
		local Difference = First:ToObjectSpace(Second)
		local _, Angle = Difference:ToAxisAngle()

		return Difference.Position.Magnitude < 0.0001 and math.abs(Angle) < 0.001
	end

	Check(Replication.IsValid(CFrame.identity, Vector3.zero, true), "Accept camera frames and stationary movement")
	Check(Replication.IsValid(CFrame.Angles(0.4, -0.6, 0.2), Vector3.yAxis, false), "Climbing movement and non-gameplay camera flags are valid")
	for _, Frame in { "camera", Vector3.zero, CFrame.new(0 / 0, 0, 0), CFrame.new(math.huge, 0, 0),
		CFrame.new(0, 0, 0, 2, 0, 0, 0, 1, 0, 0, 0, 1) } do
		Check(not Replication.IsValid(Frame, Vector3.zero, true), "Reject malformed camera transforms")
	end
	for _, Movement in { "move", Vector3.new(0 / 0, 0, 0), Vector3.new(0, math.huge, 0), Vector3.new(2, 0, 0) } do
		Check(not Replication.IsValid(CFrame.identity, Movement, true), "Reject invalid movement vectors")
	end
	Check(not Replication.IsValid(CFrame.identity, Vector3.zero, "true"), "Validate the camera mode flag")
	Check(Replication.InRange(Vector3.zero, Vector3.new(300, 0, 0)), "Include players exactly 300 studs away")
	Check(not Replication.InRange(Vector3.zero, Vector3.new(300.01, 0, 0)), "Exclude players beyond 300 studs")
	Check(not Replication.InRange(Vector3.zero, Vector3.new(0, 301, 0)), "Distance includes vertical separation")
	local First = { Camera = CFrame.identity, Movement = Vector3.zero, Active = true }
	Check(Replication.ShouldSend(nil, First, 0), "Send the first snapshot")
	Check(not Replication.ShouldSend(First, First, 0.1), "Skip unchanged frames before keepalive")
	Check(Replication.ShouldSend(First, First, Replication.KeepAlive), "Stationary players still send keepalives")
	Check(Replication.ShouldSend(First, { Camera = CFrame.Angles(0.1, 0, 0), Movement = Vector3.zero, Active = true }, 0.1), "Send camera turns")
	Check(Replication.ShouldSend(First, { Camera = CFrame.identity, Movement = Vector3.xAxis, Active = true }, 0.1), "Send movement changes")
	Check(Replication.ShouldSend(First, { Camera = CFrame.identity, Movement = Vector3.zero, Active = false }, 0.1), "Send cutscene transitions")

	local Fixture = Instance.new("Folder")
	Fixture.Name = "CameraReplicationTests"
	Fixture.Parent = workspace
	local Character = Instance.new("Model")
	Character.Parent = Fixture
	local function Part(Name: string, Position: Vector3): Part
		local Object = Instance.new("Part")
		Object.Name, Object.Anchored = Name, true
		Object.Position = Position
		Object.Parent = Character

		return Object
	end

	local Root = Part("HumanoidRootPart", Vector3.new(0, 18000, 0))
	Character.PrimaryPart = Root
	local Torso = Part("Torso", Root.Position)
	Part("Head", Root.Position + Vector3.yAxis * 1.5)
	local Humanoid = Instance.new("Humanoid")
	Humanoid.Parent = Character
	local function Joint(Name: string, Parent: BasePart, Rest: CFrame, Offset: CFrame): Motor6D
		local Object = Instance.new("Motor6D")
		Object.Name, Object.C0, Object.C1 = Name, Rest, Offset
		Object.Parent = Parent

		return Object
	end

	local RootRest = CFrame.Angles(-math.pi / 2, 0, math.pi)
	local Waist = Joint("RootJoint", Root, RootRest, RootRest)
	Joint("Neck", Torso, CFrame.new(0, 1, 0) * RootRest, CFrame.new(0, -0.5, 0) * RootRest)
	Joint("Right Hip", Torso, CFrame.new(1, -1, 0), CFrame.identity)
	Joint("Left Hip", Torso, CFrame.new(-1, -1, 0), CFrame.identity)
	local RightShoulder = Joint("Right Shoulder", Torso, CFrame.new(1, 0.5, 0), CFrame.identity)
	local LeftShoulder = Joint("Left Shoulder", Torso, CFrame.new(-1, 0.5, 0), CFrame.identity)
	local TiltState = assert(Tilt.Create(Character))
	local LookState = assert(Look.Create(Character))
	local Owner: any = {
		GetAttribute = function(): boolean
			return true
		end,
	}

	local Success, Error = pcall(function()
		Tilt.Update(TiltState, Vector3.xAxis, 0.1)
		Check(not Near(Waist.C1, TiltState.Rest), "Replicated movement drives tilt without Humanoid.MoveDirection")
		Tilt.Reset(TiltState)
		Check(Near(Waist.C1, TiltState.Rest), "Out-of-range or timeout restores tilt")
		Character:SetAttribute("InHorse", true)
		Tilt.Update(TiltState, Vector3.xAxis, 0.1)
		Check(Near(Waist.C1, TiltState.Rest), "Mounted characters cannot receive walking tilt")
		Character:SetAttribute("BowEquipped", true)
		local CameraFrame = CFrame.new(Root.Position) * CFrame.Angles(0, math.rad(75), 0) * CFrame.Angles(math.rad(45), 0, 0)
		Look.Update(LookState, Owner, CameraFrame, true, 10)
		Check(LookState.Aim.Pitch > 0 and LookState.Aim.ArmPitch > 0 and LookState.Aim.HeadPitch > 0,
			"Remote camera frames drive torso, arms and head")
		Check(math.abs(LookState.Aim.Yaw - math.rad(75)) < 0.0001, "Remote riders keep the 75 degree yaw limit")
		Look.Update(LookState, Owner, nil, false, 0.1)
		Check(Near(Waist.C0, LookState.Aim.WaistRest), "Missing packets restore the torso")
		Check(Near(RightShoulder.C0, LookState.Aim.RightShoulder.Rest)
			and Near(LeftShoulder.C0, LookState.Aim.LeftShoulder.Rest), "Missing packets restore both arms")
		Character:SetAttribute("BowEquipped", false)
		Character:SetAttribute("InHorse", false)
		Look.Update(LookState, Owner, CameraFrame, true, 0.1)
		Check(not Near(LookState.Aim.Neck.Joint.C0, LookState.Aim.Neck.Rest), "Normal camera-follow also works for remote players")
		Character:SetAttribute("Ragdoll", true)
		Look.Update(LookState, Owner, CameraFrame, true, 0.1)
		Check(Near(Waist.C0, LookState.Aim.WaistRest), "Ragdoll releases remote camera poses")
	end)

	Tilt.Reset(TiltState)
	Look.Reset(LookState)
	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("CameraReplication: %d checks passed", Checks)
end
