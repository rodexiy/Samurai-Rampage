return function(Controller: any, Config: any): string
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Near(First: CFrame, Second: CFrame): boolean
		return (First.Position - Second.Position).Magnitude < 0.0001
			and (First.LookVector - Second.LookVector).Magnitude < 0.0001
			and (First.UpVector - Second.UpVector).Magnitude < 0.0001
	end

	local Time = Config.CameraSway.RollPeriod * 0.25
	local Position = Vector3.new(23, 45, -67)
	for _, ShipYaw in { 0, math.rad(53), math.rad(-125) } do
		local Ship = CFrame.new(8000, 0, -7000) * CFrame.Angles(0, ShipYaw, 0)
		local Front = CFrame.new(Position) * Ship.Rotation
		local Back = Front * CFrame.Angles(0, math.pi, 0)
		local FrontSway = Controller.GetSwayFrame(Front, Ship, Time, 1)
		local BackSway = Controller.GetSwayFrame(Back, Ship, Time, 1)
		local _, _, FrontRoll = Front:ToObjectSpace(FrontSway):ToOrientation()
		local _, _, BackRoll = Back:ToObjectSpace(BackSway):ToOrientation()
		Check(math.abs(FrontRoll - math.rad(Config.CameraSway.RollDegrees)) < 0.0001,
			"Facing the bow uses the configured ship roll")
		Check(math.abs(FrontRoll + BackRoll) < 0.0001, "Facing the stern reverses the perceived roll")

		local WorldTilt = FrontSway.Rotation * Front.Rotation:Inverse()
		for _, Yaw in { 0, math.pi / 2, math.pi, -math.pi / 2 } do
			for _, Pitch in { math.rad(-85), 0, math.rad(85) } do
				local View = Front * CFrame.Angles(0, Yaw, 0) * CFrame.Angles(Pitch, 0, 0)
				local Sway = Controller.GetSwayFrame(View, Ship, Time, 1)
				Check((Sway.Position - View.Position).Magnitude < 0.0001,
					"Sway preserves camera position, first-person offsets and shoulder collision")
				Check(Near(Sway.Rotation * View.Rotation:Inverse(), WorldTilt),
					"Every viewing direction shares the same ship-space tilt")
			end
		end

		Check(Near(Controller.GetSwayFrame(Front, Ship, Time, 0), Front), "Zero blend leaves the camera unchanged")
	end

	return string.format("BoatCameraSway: %d checks passed", Checks)
end
