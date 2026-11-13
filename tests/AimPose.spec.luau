return function(Controller: any): string
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
	Root.Parent = Character
	Character.PrimaryPart = Root
	local Camera = Instance.new("Camera")
	Camera.CameraType = Enum.CameraType.Custom
	local Joints: { Motor6D } = {}
	local function Joint(Rest: CFrame, Offset: CFrame): Motor6D
		local Motor = Instance.new("Motor6D")
		Motor.C0, Motor.C1 = Rest, Offset
		table.insert(Joints, Motor)

		return Motor
	end

	local RootRest = CFrame.Angles(-math.pi / 2, 0, math.pi)
	local Waist = Joint(RootRest, RootRest)
	local RightHip = Joint(CFrame.new(1, -1, 0), CFrame.new(0.5, 1, 0))
	local LeftHip = Joint(CFrame.new(-1, -1, 0), CFrame.new(-0.5, 1, 0))
	local Neck = Joint(CFrame.new(0, 1, 0) * RootRest, CFrame.new(0, -0.5, 0) * RootRest)
	local RightShoulder = Joint(CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0), CFrame.identity)
	local LeftShoulder = Joint(CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, -math.pi / 2, 0), CFrame.identity)
	local State = Controller.Create(Waist, RightHip, LeftHip, Neck, RightShoulder, LeftShoulder)
	Character:SetAttribute("BowEquipped", true)
	Character:SetAttribute("BowDrawing", true)

	local Success, Error = pcall(function()
		for _, Mounted in { false, true } do
			Character:SetAttribute("InHorse", Mounted)
			for _, Yaw in if Mounted then { -75, 0, 75 } else { 0 } do
				for _, Pitch in { -85, -70, -30, 0, 30, 70, 85 } do
					Controller.Reset(State)
					Root.CFrame = CFrame.identity
					Camera.CFrame = CFrame.Angles(0, math.rad(Yaw), 0) * CFrame.Angles(math.rad(Pitch), 0, 0)
					local RightTransform = CFrame.Angles(-0.6, 0.1, 0.2)
					RightHip.Transform = RightTransform
					LeftHip.Transform = CFrame.Angles(-0.8, -0.1, -0.2)
					local RightRest = State.RightHipRest * RightHip.Transform * RightHip.C1:Inverse()
					local LeftRest = State.LeftHipRest * LeftHip.Transform * LeftHip.C1:Inverse()
					Check(Controller.Update(State, Character, Camera, 10), "Aim works standing and mounted")
					Check(math.abs(State.Pitch - math.clamp(math.rad(Pitch) * 0.25, -math.rad(20), math.rad(20))) < 0.0001,
						"Torso contributes a subtle share of vertical aim")
					local Torso = Waist.C0 * Waist.Transform * Waist.C1:Inverse()
					local ArmCorrection = RightShoulder.C0.Rotation * State.RightShoulder.Rest.Rotation:Inverse()
					Check((Torso.Rotation * ArmCorrection).LookVector:Dot(Camera.CFrame.LookVector) > 0.9999,
						"Arms point up and down toward the camera's aim")
					Check(Near(RightShoulder.C0 * State.RightShoulder.Rest:Inverse(),
						CFrame.new(RightShoulder.C0.Position) * CFrame.Angles(State.ArmPitch, 0, 0)
							* CFrame.new(-State.RightShoulder.Rest.Position)), "Arm pivots stay at the shoulders")
					Check(math.abs(State.HeadPitch) <= math.rad(60) + 0.0001, "Head stays within its pitch limit")
					if math.abs(Pitch) <= 70 then
						local HeadCorrection = Neck.C0.Rotation * State.Neck.Rest.Rotation:Inverse()
						Check((Torso.Rotation * HeadCorrection).LookVector:Dot(Camera.CFrame.LookVector) > 0.9999,
							"Head follows the same vertical target")
					end
					Check(Near(Torso * RightHip.C0 * RightHip.Transform * RightHip.C1:Inverse(), RightRest), "Right leg keeps its animated pose")
					Check(Near(Torso * LeftHip.C0 * LeftHip.Transform * LeftHip.C1:Inverse(), LeftRest), "Left leg keeps its animated pose")
					Check(Near(RightHip.Transform, RightTransform), "Aim preserves Animator transforms")
				end
			end
		end

		Character:SetAttribute("InHorse", true)
		Root.CFrame = CFrame.Angles(0.3, 0.5, -0.2)
		Waist.Transform = CFrame.new(0.1, 0.2, -0.1) * CFrame.Angles(-0.2, 0.1, 0.15)
		local Before = Root.CFrame * State.WaistRest * Waist.Transform * Waist.C1:Inverse()
		local RightBefore = Before * State.RightHipRest * RightHip.Transform * RightHip.C1:Inverse()
		Camera.CFrame = CFrame.Angles(0, 0.5, 0) * CFrame.Angles(0.7, 0, 0)
		Controller.Update(State, Character, Camera, 10)
		local After = Root.CFrame * Waist.C0 * Waist.Transform * Waist.C1:Inverse()
		Check(Near(After * RightHip.C0 * RightHip.Transform * RightHip.C1:Inverse(), RightBefore),
			"Compensation preserves riding pose on slopes with animated body lean")

		Character:SetAttribute("BowEquipped", false)
		Character:SetAttribute("BowDrawing", false)
		Check(not Controller.Update(State, Character, Camera, 1 / 60), "Stowing the weapon releases aim")
		Check(Near(Waist.C0, State.WaistRest) and Near(RightHip.C0, State.RightHipRest) and Near(LeftHip.C0, State.LeftHipRest),
			"Stowing restores torso and leg joints")
		Check(Near(Neck.C0, State.Neck.Rest) and Near(RightShoulder.C0, State.RightShoulder.Rest)
			and Near(LeftShoulder.C0, State.LeftShoulder.Rest), "Stowing restores head and both arms")
		Character:SetAttribute("BowDrawing", true)
		Check(Controller.Update(State, Character, Camera, 1 / 60), "Drawing enables the general aiming pose")
		Character:SetAttribute("Ragdoll", true)
		Check(not Controller.Update(State, Character, Camera, 1 / 60), "Ragdoll releases all aim offsets")
		Character:SetAttribute("Ragdoll", nil)
		Controller.Reset(State)
		Camera.CFrame = CFrame.Angles(math.rad(-70), 0, 0)
		Controller.Update(State, Character, Camera, 1 / 60)
		Check(State.Pitch < 0 and math.abs(State.Pitch) < math.rad(20), "Vertical aim blends smoothly")
		Camera.CameraType = Enum.CameraType.Scriptable
		Check(not Controller.Update(State, Character, Camera, 1 / 60), "Cutscene cameras release aim offsets")
	end)

	Controller.Reset(State)
	for _, Motor in Joints do
		Motor:Destroy()
	end
	Character:Destroy()
	Camera:Destroy()
	assert(Success, tostring(Error))

	return string.format("AimPose: %d checks passed", Checks)
end
