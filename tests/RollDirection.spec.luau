return function(RollDirection: any): string
	local Checks = 0
	local Frame = CFrame.Angles(0, math.rad(63), 0)
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	for _, Movement in { Frame.LookVector, -Frame.LookVector, Frame.RightVector, -Frame.RightVector, Vector3.zero } do
		local Animation, Direction = RollDirection.Resolve(Frame, Movement, false, false)
		Check(Animation == "Forward", "The free camera always uses the forward dash animation")
		Check(math.abs(Direction.Magnitude - 1) < 0.001 and math.abs(Direction.Y) < 0.001, "Dash movement is normalized and horizontal")
	end
	for _, Entry in {
		{ Movement = Frame.LookVector, Animation = "Forward" },
		{ Movement = -Frame.LookVector, Animation = "Backward" },
		{ Movement = Frame.RightVector, Animation = "Right" },
		{ Movement = -Frame.RightVector, Animation = "Left" },
	} do
		local Animation, Movement = RollDirection.Resolve(Frame, Entry.Movement, true, false)
		Check(Animation == Entry.Animation and Movement:Dot(Entry.Movement) > 0.999, "Locked dash uses the direction relative to the character")
	end
	local Animation, Movement = RollDirection.Resolve(Frame, Vector3.zero, false, false)
	Check(Animation == "Forward" and Movement:Dot(Frame.LookVector) > 0.999, "A stationary free dash moves forward")
	Animation, Movement = RollDirection.Resolve(Frame, Vector3.zero, true, false)
	Check(Animation == "Backward" and Movement:Dot(Frame.LookVector) < -0.999, "A stationary locked dash retains its backward dodge")
	Animation, Movement = RollDirection.Resolve(Frame, -Frame.RightVector, true, true)
	Check(Animation == "Forward" and Movement:Dot(-Frame.RightVector) > 0.999, "Running uses a forward dash animation without reversing movement")

	return tostring(Checks) .. " dash direction checks passed"
end
