-- Run with the shared MountedAim module and client HorseAimController module.
return function(Aim: any, Rider: any): string
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

	local Limit = math.rad(75)
	for _, Heading in { -170, -90, 0, 90, 170 } do
		for _, Slope in { -35, 0, 35 } do
			local Reference = CFrame.Angles(0, math.rad(Heading), 0) * CFrame.Angles(math.rad(Slope), 0, math.rad(12))
			for _, Yaw in { -180, -120, -76, -75, -30, 0, 30, 75, 76, 120, 180 } do
				for _, Pitch in { -85, 0, 85 } do
					local Rotation = CFrame.Angles(0, math.rad(Heading + Yaw), 0) * CFrame.Angles(math.rad(Pitch), 0, 0)
					local Velocity = Rotation.LookVector * 750
					local Clamped = Aim.ClampDirection(Reference, Velocity)
					Check(math.abs(Aim.GetYaw(Reference, Clamped)) <= Limit + 0.00001, "Shot stays within 75 degrees")
					Check(math.abs(Clamped.Magnitude - Velocity.Magnitude) < 0.001, "Clamping preserves shot speed")
					Check(math.abs(Clamped.Y - Velocity.Y) < 0.001, "Clamping preserves vertical aim on slopes")
					if math.abs(Yaw) <= 75 then
						Check((Clamped - Velocity).Magnitude < 0.001, "Allowed shots keep their direction")
					end

					local Focus = Vector3.new(13, 8, -25)
					local Pose = CFrame.new(Focus - Rotation.LookVector * 12) * Rotation
					local CameraPose = Aim.ClampCamera(Reference, Pose, Focus)
					Check(math.abs(Aim.GetYaw(Reference, CameraPose.LookVector)) <= Limit + 0.00001, "Camera cannot aim behind rider")
					Check(math.abs((CameraPose.Position - Focus).Magnitude - 12) < 0.0001, "Camera orbit preserves zoom")
					Check(math.abs(CameraPose.LookVector.Y - Pose.LookVector.Y) < 0.0001, "Camera keeps pitch")
				end
			end
		end
	end
	Check(Aim.ClampDirection(CFrame.identity, Vector3.zero) == Vector3.zero, "Zero vectors remain finite")
	Check(Aim.ClampDirection(CFrame.identity, Vector3.yAxis) == Vector3.yAxis, "Vertical aim stays vertical")

	local Character = Instance.new("Model")
	local Root = Instance.new("Part")
	Root.Parent = Character
	Character.PrimaryPart = Root
	local Camera = Instance.new("Camera")
	Camera.CameraType = Enum.CameraType.Custom
	local Waist = Instance.new("Motor6D")
	Waist.C0 = CFrame.Angles(-math.pi / 2, 0, math.pi)
	Waist.C1 = Waist.C0
	local RightHip = Instance.new("Motor6D")
	RightHip.C0 = CFrame.new(1, -1, 0) * CFrame.Angles(0, math.pi / 2, 0)
	RightHip.C1 = CFrame.new(0.5, 1, 0) * CFrame.Angles(0, math.pi / 2, 0)
	local LeftHip = Instance.new("Motor6D")
	LeftHip.C0 = CFrame.new(-1, -1, 0) * CFrame.Angles(0, -math.pi / 2, 0)
	LeftHip.C1 = CFrame.new(-0.5, 1, 0) * CFrame.Angles(0, -math.pi / 2, 0)
	local State = Rider.Create(Waist, RightHip, LeftHip)

	local Success, Error = pcall(function()
		local Behind = Vector3.new(0, 0, 100)
		Check(Aim.ClampTarget(Character, Vector3.zero, Behind) == Behind, "Unmounted aiming remains unrestricted")
		Character:SetAttribute("InHorse", true)
		Check(not Aim.IsActive(Character), "Free look stays available with bow stowed")
		Character:SetAttribute("BowEquipped", true)
		Check(Aim.IsActive(Character), "Equipping the bow limits mounted aim")
		Check(math.abs(Aim.GetYaw(Root.CFrame, Aim.ClampTarget(Character, Vector3.zero, Behind))) <= Limit + 0.00001,
			"Targets behind the rider are clamped")

		for _, Yaw in { -120, -75, 0, 75, 120 } do
			for _, Lean in { -0.3, 0, 0.3 } do
				Root.CFrame = CFrame.new(5, 30, -10) * CFrame.Angles(0, 0.6, 0) * CFrame.Angles(0.2, 0, -0.1)
				Waist.Transform = CFrame.new(0.1, 0.2, -0.1) * CFrame.Angles(Lean, 0.1, -0.1)
				RightHip.Transform = CFrame.Angles(-0.7, 0.1, 0.2)
				LeftHip.Transform = CFrame.Angles(-0.6, -0.1, -0.2)
				local TorsoRest = Root.CFrame * State.WaistRest * Waist.Transform * Waist.C1:Inverse()
				local RightRest = TorsoRest * State.RightHipRest * RightHip.Transform * RightHip.C1:Inverse()
				local LeftRest = TorsoRest * State.LeftHipRest * LeftHip.Transform * LeftHip.C1:Inverse()
				Camera.CFrame = CFrame.Angles(0, 0.6 + math.rad(Yaw), 0)
				Check(Rider.Update(State, Character, Camera, 10), "Mounted bow rotates torso")
				Check(math.abs(State.Yaw - math.clamp(math.rad(Yaw), -Limit, Limit)) < 0.0001, "Torso reaches both 75 degree limits")
				local Turned = Root.CFrame * Waist.C0 * Waist.Transform * Waist.C1:Inverse()
				Check(Near(Turned * RightHip.C0 * RightHip.Transform * RightHip.C1:Inverse(), RightRest), "Right leg keeps animated world pose")
				Check(Near(Turned * LeftHip.C0 * LeftHip.Transform * LeftHip.C1:Inverse(), LeftRest), "Left leg keeps animated world pose")
			end
		end

		Rider.Reset(State)
		Check(Near(Waist.C0, State.WaistRest) and Near(RightHip.C0, State.RightHipRest)
			and Near(LeftHip.C0, State.LeftHipRest), "Reset restores all three joints")
		Camera.CFrame = CFrame.Angles(0, 0.6 + Limit, 0)
		Rider.Update(State, Character, Camera, 1 / 60)
		Check(State.Yaw > 0 and State.Yaw < Limit, "Torso blends toward aim")
		Character:SetAttribute("BowEquipped", false)
		Check(not Rider.Update(State, Character, Camera, 1 / 60), "Stowing bow releases torso")
		Check(Near(RightHip.C0, State.RightHipRest), "Stowing bow releases hip compensation")
		Character:SetAttribute("BowDrawing", true)
		Check(Aim.IsActive(Character), "Drawing also activates the aiming limit")
		Character:SetAttribute("InHorse", false)
		Check(not Rider.Update(State, Character, Camera, 1 / 60), "Dismount releases aiming")
	end)

	Rider.Reset(State)
	Camera:Destroy()
	Waist:Destroy()
	RightHip:Destroy()
	LeftHip:Destroy()
	Character:Destroy()
	assert(Success, tostring(Error))

	return string.format("MountedAim: %d checks passed", Checks)
end
