return function(PoseController: any, RiderController: any, Settings: any): string
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

	local Character = Instance.new("Model")
	local Root = Instance.new("Part")
	Root.CanCollide = false
	Root.CFrame = CFrame.new(0, 100000, 0)
	Root.Parent = Character
	Character.PrimaryPart = Root
	Character.Parent = workspace
	Character:SetAttribute("InHorse", true)
	Character:SetAttribute("Bow", "Tanegashima")
	Character:SetAttribute("BowEquipped", true)
	local Joints: { Motor6D } = {}
	local function Joint(Rest: CFrame): Motor6D
		local Motor = Instance.new("Motor6D")
		Motor.C0 = Rest
		table.insert(Joints, Motor)

		return Motor
	end

	local Waist = Joint(CFrame.identity)
	local RightHip = Joint(CFrame.new(1, -1, 0))
	local LeftHip = Joint(CFrame.new(-1, -1, 0))
	local Neck = Joint(CFrame.new(0, 1, 0))
	local RightShoulder = Joint(CFrame.new(1, 0.5, 0))
	local LeftShoulder = Joint(CFrame.new(-1, 0.5, 0))
	local State = PoseController.Create(Waist, RightHip, LeftHip, Neck, RightShoulder, LeftShoulder)
	local CameraFrame = CFrame.Angles(0, math.rad(60), 0) * CFrame.Angles(math.rad(40), 0, 0)
	local MiddleSpeed = (Settings.RunningStartSpeed + Settings.RunningStopSpeed) * 0.5
	local function Update(Speed: number)
		Root.AssemblyLinearVelocity = Vector3.new(Speed, 0, 0)
		Check(PoseController.UpdateFromCFrame(State, Character, CameraFrame, 10), "Mounted pose stays active")
	end

	local Success, Error = pcall(function()
		Update(MiddleSpeed)
		Check(not RiderController.IsRunning(Character), "Fast riding does not start below the entry threshold")
		Check(not Near(Neck.C0, State.Neck.Rest), "Head follows the camera during slower riding")
		Update(Settings.RunningStartSpeed)
		Check(RiderController.IsRunning(Character), "Head and rider animation share the fast state")
		Check(Near(Neck.C0, State.Neck.Rest), "Fast riding without aiming removes head offsets")
		Check(not Near(RightShoulder.C0, State.RightShoulder.Rest), "Head suppression preserves arm aiming")
		Check(Near(Waist.C0 * RightHip.C0, State.WaistRest * State.RightHipRest)
			and Near(Waist.C0 * LeftHip.C0, State.WaistRest * State.LeftHipRest), "Leg poses remain unchanged")
		Update(MiddleSpeed)
		Check(Near(Neck.C0, State.Neck.Rest), "Head stays neutral inside the running hysteresis band")
		Character:SetAttribute("BowDrawing", true)
		Update(MiddleSpeed)
		Check(not Near(Neck.C0, State.Neck.Rest), "Aiming restores head movement even during fast riding")
		Character:SetAttribute("BowDrawing", false)
		Update(MiddleSpeed)
		Check(Near(Neck.C0, State.Neck.Rest), "Releasing aim suppresses head movement again")
		Update(Settings.RunningStopSpeed)
		Check(Near(Neck.C0, State.Neck.Rest), "Fast state includes the exact exit threshold")
		Update(Settings.RunningStopSpeed - 0.1)
		Check(not Near(Neck.C0, State.Neck.Rest), "Slowing below the exit threshold restores head movement")
		Root.AssemblyLinearVelocity = Vector3.new(0, 1000, 0)
		Check(not RiderController.IsRunning(Character), "Vertical movement does not trigger fast riding")
		Update(Settings.RunningStartSpeed)
		Character:SetAttribute("Bow", "Bow")
		Update(MiddleSpeed)
		Check(not Near(Neck.C0, State.Neck.Rest), "Other ranged weapons preserve their existing head behavior")
		Character:SetAttribute("Bow", "Tanegashima")
		Character:SetAttribute("InHorse", false)
		Character:SetAttribute("Running", true)
		Update(Settings.RunningStartSpeed)
		Check(Near(Neck.C0, State.Neck.Rest), "On-foot running still suppresses head movement")
		Check(not RiderController.IsRunning(Character), "Dismount clears the fast riding state")
		Character:SetAttribute("Running", false)
		Character:SetAttribute("InHorse", true)
		Update(MiddleSpeed)
		Check(not Near(Neck.C0, State.Neck.Rest), "Remounting starts with the entry threshold")
	end)

	PoseController.Reset(State)
	for _, Motor in Joints do
		Motor:Destroy()
	end
	Character:Destroy()
	assert(Success, tostring(Error))

	return string.format("MountedTanegashimaHead: %d checks passed", Checks)
end
