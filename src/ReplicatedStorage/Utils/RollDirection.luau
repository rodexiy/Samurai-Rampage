local RollDirection = {}

function RollDirection.Resolve(Frame: CFrame, Movement: Vector3, FacingLocked: boolean, Running: boolean): (string, Vector3)
	local Direction = Movement * Vector3.new(1, 0, 1)
	if Direction.Magnitude < 0.001 then
		Direction = Frame.LookVector * (if FacingLocked and not Running then -1 else 1)
		Direction *= Vector3.new(1, 0, 1)
	end
	if Direction.Magnitude < 0.001 then
		Direction = -Vector3.zAxis
	end
	Direction = Direction.Unit
	if not FacingLocked or Running then
		return "Forward", Direction
	end
	local Local = Frame:VectorToObjectSpace(Direction)
	if math.abs(Local.X) > math.abs(Local.Z) then
		return if Local.X > 0 then "Right" else "Left", Direction
	end

	return if Local.Z < 0 then "Forward" else "Backward", Direction
end

return RollDirection
