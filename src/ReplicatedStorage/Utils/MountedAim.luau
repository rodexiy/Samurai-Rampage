local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HorseConfig = require(ReplicatedStorage.Shared.HorseConfig)

local MountedAim = {}

function MountedAim.IsActive(Character: Model?): boolean
	return Character ~= nil and Character:GetAttribute("InHorse") == true
		and (Character:GetAttribute("BowEquipped") == true or Character:GetAttribute("BowDrawing") == true)
end

local function GetHeading(Reference: CFrame): CFrame
	local Forward = Reference.LookVector * Vector3.new(1, 0, 1)
	Forward = if Forward.Magnitude > 0.0001 then Forward.Unit else -Vector3.zAxis

	return CFrame.lookAt(Vector3.zero, Forward)
end

function MountedAim.GetYaw(Reference: CFrame, Direction: Vector3): number
	local LocalDirection = GetHeading(Reference):VectorToObjectSpace(Direction)
	if Vector2.new(LocalDirection.X, LocalDirection.Z).Magnitude < 0.0001 then
		return 0
	end

	return math.atan2(-LocalDirection.X, -LocalDirection.Z)
end

function MountedAim.ClampDirection(Reference: CFrame, Direction: Vector3): Vector3
	local Yaw = MountedAim.GetYaw(Reference, Direction)
	local Limit = HorseConfig.MountedAim.MaximumYaw
	local Correction = math.clamp(Yaw, -Limit, Limit) - Yaw

	-- Rotate around world up so pitch and projectile speed stay unchanged on slopes.
	return CFrame.Angles(0, Correction, 0):VectorToWorldSpace(Direction)
end

function MountedAim.ClampTarget(Character: Model?, Origin: Vector3, Target: Vector3): Vector3
	local Root = Character and Character.PrimaryPart
	if not Root or not MountedAim.IsActive(Character) then
		return Target
	end

	return Origin + MountedAim.ClampDirection(Root.CFrame, Target - Origin)
end

function MountedAim.ClampCamera(Reference: CFrame, Pose: CFrame, Focus: Vector3): CFrame
	local Yaw = MountedAim.GetYaw(Reference, Pose.LookVector)
	local Limit = HorseConfig.MountedAim.MaximumYaw
	local Rotation = CFrame.Angles(0, math.clamp(Yaw, -Limit, Limit) - Yaw, 0)

	return CFrame.new(Focus + Rotation:VectorToWorldSpace(Pose.Position - Focus)) * Rotation * Pose.Rotation
end

return MountedAim
