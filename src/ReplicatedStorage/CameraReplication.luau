local CameraReplication = {
	Radius = 300,
	SendInterval = 0.1,
	MinimumServerInterval = 0.08,
	KeepAlive = 0.5,
	Timeout = 1.5,
	Response = 16,
	MaximumCameraDistance = 512,
}

export type Frame = { Camera: CFrame, Movement: Vector3, Active: boolean }

local function IsFinite(Value: number): boolean
	return Value == Value and math.abs(Value) < math.huge
end

function CameraReplication.IsValid(Camera: any, Movement: any, Active: any): boolean
	if typeof(Camera) ~= "CFrame" or typeof(Movement) ~= "Vector3" or typeof(Active) ~= "boolean" then
		return false
	end

	for _, Value in { Camera:GetComponents() } do
		if not IsFinite(Value) then
			return false
		end
	end

	if not IsFinite(Movement.X) or not IsFinite(Movement.Y) or not IsFinite(Movement.Z)
		or Movement.Magnitude > 1.05 then
		return false
	end

	return math.abs(Camera.LookVector.Magnitude - 1) < 0.001
		and math.abs(Camera.UpVector.Magnitude - 1) < 0.001
		and math.abs(Camera.RightVector.Magnitude - 1) < 0.001
		and math.abs(Camera.LookVector:Dot(Camera.UpVector)) < 0.001
		and Camera.RightVector:Cross(Camera.UpVector):Dot(-Camera.LookVector) > 0.999
end

function CameraReplication.InRange(First: Vector3, Second: Vector3): boolean
	local Offset = First - Second

	return Offset:Dot(Offset) <= CameraReplication.Radius * CameraReplication.Radius
end

function CameraReplication.ShouldSend(Previous: Frame?, Current: Frame, Elapsed: number): boolean
	return Previous == nil or Elapsed >= CameraReplication.KeepAlive or Previous.Active ~= Current.Active
		or (Previous.Camera.Position - Current.Camera.Position).Magnitude >= 0.5
		or Previous.Camera.LookVector:Dot(Current.Camera.LookVector) < math.cos(math.rad(1))
		or Previous.Camera.UpVector:Dot(Current.Camera.UpVector) < math.cos(math.rad(1))
		or (Previous.Movement - Current.Movement).Magnitude >= 0.03
end

return CameraReplication
