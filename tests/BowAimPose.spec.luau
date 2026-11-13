local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MountedAim = require(ReplicatedStorage.Shared.Utils.MountedAim)

return function(Controller: any, Clips: { [string]: { [string]: CFrame } }): string
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Near(First: CFrame, Second: CFrame): boolean
		return (First.Position - Second.Position).Magnitude < 0.0001
			and (First.RightVector - Second.RightVector).Magnitude < 0.0001
			and (First.UpVector - Second.UpVector).Magnitude < 0.0001
			and (First.LookVector - Second.LookVector).Magnitude < 0.0001
	end

	local Character = Instance.new("Model")
	local Root = Instance.new("Part")
	Root.Parent = Character
	Character.PrimaryPart = Root
	Character:SetAttribute("BowEquipped", true)
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
	local RightRotation = CFrame.Angles(0, math.pi / 2, 0)
	local LeftRotation = CFrame.Angles(0, -math.pi / 2, 0)
	local RightShoulder = Joint(CFrame.new(1, 0.5, 0) * RightRotation, CFrame.new(-0.5, 0.5, 0) * RightRotation)
	local LeftShoulder = Joint(CFrame.new(-1, 0.5, 0) * LeftRotation, CFrame.new(0.5, 0.5, 0) * LeftRotation)
	local State = Controller.Create(Waist, RightHip, LeftHip, Neck, RightShoulder, LeftShoulder)
	local function SetClip(Clip: { [string]: CFrame })
		Waist.Transform = Clip.Torso or CFrame.identity
		Neck.Transform = Clip.Head or CFrame.identity
		RightShoulder.Transform = Clip["Right Arm"] or CFrame.identity
		LeftShoulder.Transform = Clip["Left Arm"] or CFrame.identity
	end

	local Success, Error = pcall(function()
		Character:SetAttribute("Bow", "Bow")
		Character:SetAttribute("BowDrawing", true)
		for Name, Clip in Clips do
			SetClip(Clip)
			for _, Mounted in { false, true } do
				Character:SetAttribute("InHorse", Mounted)
				for _, Yaw in if Mounted then { -75, 0, 75 } else { -35, 0, 35 } do
					for _, Pitch in { -60, -30, 0, 30, 60 } do
						Controller.Reset(State)
						Root.CFrame = CFrame.Angles(0.15, 0.4, -0.1)
						local CameraFrame = Root.CFrame * CFrame.Angles(0, math.rad(Yaw), 0) * CFrame.Angles(math.rad(Pitch), 0, 0)
						local Direction = if Mounted then MountedAim.ClampDirection(Root.CFrame, CameraFrame.LookVector) else CameraFrame.LookVector
						local BaseTorso = State.WaistRest * Waist.Transform * Waist.C1:Inverse()
						local Elevation = Root.CFrame * CFrame.lookAt(Vector3.zero, Root.CFrame:VectorToObjectSpace(Direction))
						Check(Controller.UpdateFromCFrame(State, Character, CameraFrame, 10), "Bow pose applies: " .. Name)
						local Torso = Root.CFrame * Waist.C0 * Waist.Transform * Waist.C1:Inverse()
						local Head = Torso * Neck.C0 * Neck.Transform * Neck.C1:Inverse()
						Check(Head.LookVector:Dot(Direction) > 0.9999, "Animated head follows aim without a second sideways turn: " .. Name)
						for _, Shoulder in { State.RightShoulder, State.LeftShoulder } do
							local JointFrame = Shoulder.Rest * Shoulder.Joint.Transform
							local Actual = Torso * Shoulder.Joint.C0 * Shoulder.Joint.Transform * Shoulder.Joint.C1:Inverse()
							local Expected = Elevation * BaseTorso * JointFrame * Shoulder.Joint.C1:Inverse()
							Check(Near(Actual.Rotation, Expected.Rotation), "Both animated arms elevate in the firing plane instead of rolling: " .. Name)
							Check((Shoulder.Joint.C0 * Shoulder.Joint.Transform).Position:FuzzyEq(JointFrame.Position, 0.0001),
								"Animated shoulder pivot stays fixed: " .. Name)
							Check(Near(Shoulder.Joint.Transform, Clip[Shoulder.Joint == RightShoulder and "Right Arm" or "Left Arm"] or CFrame.identity),
								"Animator shoulder transforms remain intact")
						end
						Check(Near(Torso * RightHip.C0 * RightHip.C1:Inverse(), Root.CFrame * BaseTorso * State.RightHipRest * RightHip.C1:Inverse()),
							"Mounted legs retain their original animated pose")
					end
				end
			end
		end

		for Name, Clip in Clips do
			SetClip(Clip)
			for _, Mounted in { false, true } do
				Character:SetAttribute("InHorse", Mounted)
				Root.CFrame = CFrame.identity
				Character:SetAttribute("BowDrawing", true)
				Controller.UpdateFromCFrame(State, Character, CFrame.Angles(0, 0.5, 0) * CFrame.Angles(0.4, 0, 0), 10)
				Character:SetAttribute("BowDrawing", false)
				for _, Yaw in { -75, 0, 75 } do
					local CameraFrame = CFrame.Angles(0, math.rad(Yaw), 0) * CFrame.Angles(0.4, 0, 0)
					Check(Controller.UpdateFromCFrame(State, Character, CameraFrame, 10), "Equipped bow still updates its head outside aiming")
					Check(Near(Waist.C0, State.WaistRest), "Looking around with the bow does not turn the torso: " .. Name)
					Check(Near(RightShoulder.C0, State.RightShoulder.Rest) and Near(LeftShoulder.C0, State.LeftShoulder.Rest),
						"Looking around with the bow preserves both animated arm poses: " .. Name)
					Check(State.HeadPitch ~= 0 or State.HeadYaw ~= 0, "Head can still follow the camera outside aiming")
				end
				Character:SetAttribute("BowDrawing", true)
				Controller.UpdateFromCFrame(State, Character, CFrame.Angles(0, 0.5, 0) * CFrame.Angles(0.4, 0, 0), 10)
				Check(not Near(Waist.C0, State.WaistRest), "Drawing re-enables torso aiming")
				Check(not Near(LeftShoulder.C0, State.LeftShoulder.Rest), "Drawing re-enables arm aiming")
			end
		end
	end)

	Controller.Reset(State)
	for _, Motor in Joints do
		Motor:Destroy()
	end
	Character:Destroy()
	assert(Success, tostring(Error))

	return string.format("BowAimPose: %d checks passed", Checks)
end
