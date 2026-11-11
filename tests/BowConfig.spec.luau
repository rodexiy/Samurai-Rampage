-- Run this suite in Studio with require(ReplicatedStorage.Shared.BowConfig).
return function(Config: any): string
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	Check(Config.GetCharge(-1) == 0, "Negative elapsed time must not produce negative power")
	Check(Config.GetCharge(0) == 0, "A quick shot starts at minimum power")
	Check(Config.GetCharge(0.75) == 0.5, "Charge progresses over 1.5 seconds")
	Check(Config.GetCharge(1.5) == 1 and Config.GetCharge(5) == 1, "Overholding cannot exceed maximum power")
	Check(Config.GetDamage(1, 0) == Config.MaxDamage, "Point-blank shots retain their base damage")
	Check(Config.GetDamage(1, Config.DistanceDamageRange) == Config.MaxDamage * (1 + Config.DistanceDamageBonus),
		"Long-range shots gain the full distance bonus")
	Check(Config.GetDamage(1, Config.DistanceDamageRange * 0.5) == Config.MaxDamage * (1 + Config.DistanceDamageBonus * 0.5),
		"Distance damage grows progressively")
	Check(Config.GetDamage(1, Config.MaxDistance * 2) == Config.GetDamage(1, Config.DistanceDamageRange),
		"Distance damage must stop growing at the configured maximum")
	Check(Config.GetDamage(1, -10) == Config.MaxDamage, "Negative distance cannot reduce base damage")
	Check(Config.GetDamage(0, Config.DistanceDamageRange) == Config.MinDamage * (1 + Config.DistanceDamageBonus),
		"Distance scales the damage of partially charged shots too")
	Check(Config.IsValidAim(Vector3.new(5, 10, 20)), "A finite world point should be accepted")
	Check(not Config.IsValidAim(nil) and not Config.IsValidAim(CFrame.identity), "Reject invalid remote argument types")
	Check(not Config.IsValidAim(Vector3.new(0 / 0, 0, 0)), "Reject NaN aim coordinates")
	Check(not Config.IsValidAim(Vector3.new(math.huge, 0, 0)), "Reject infinite aim coordinates")
	Check(not Config.IsValidAim(Vector3.new(1e7, 0, 0)), "Reject coordinates beyond the world limit")

	local Surface = Instance.new("Part")
	for Material, Expected in {
		[Enum.Material.Metal] = "Metal",
		[Enum.Material.DiamondPlate] = "Metal",
		[Enum.Material.CorrodedMetal] = "Metal",
		[Enum.Material.Foil] = "Metal",
		[Enum.Material.Wood] = "Wood",
		[Enum.Material.WoodPlanks] = "Wood",
		[Enum.Material.Plastic] = "Default",
		[Enum.Material.Concrete] = "Default",
		[Enum.Material.Grass] = "Default",
	} do
		Surface.Material = Material
		Check(Config.GetImpactSoundType(Surface) == Expected, "Choose the correct impact sound for " .. Material.Name)
	end
	Check(Config.GetImpactSoundType(workspace.Terrain, Enum.Material.Wood) == "Wood", "Terrain hits must use the raycast material")
	Check(Config.GetImpactSoundType(nil) == "Default", "A missing hit instance must use the generic impact")
	Surface:Destroy()

	local Origin = Vector3.zero
	local Target = Vector3.new(0, 0, -40)
	local Velocity = Config.GetVelocity(Origin, Target, 0, 0)
	local FlightTime = 40 / -Velocity.Z
	local Acceleration = Vector3.new(0, -196.2, 0)
	local Impact = Origin + Velocity * FlightTime + Acceleration * (FlightTime * FlightTime / 2)
	Check(Velocity.Y == 0 and Impact.Y < Target.Y, "A level shot must launch level and drop below the aim point under gravity")
	Check(math.abs(Velocity.Magnitude - Config.MinSpeed) < 0.001, "A quick shot must use minimum speed")
	local FullVelocity = Config.GetVelocity(Origin, Target, 1.5, 45)
	Check(math.abs(FullVelocity.Magnitude - Config.MaxSpeed) < 0.001, "Full charge must use maximum speed")
	local Unreachable = Config.GetVelocity(Origin, Vector3.new(0, 1000, -400), 0, 0)
	Check(Unreachable.Magnitude == Unreachable.Magnitude and math.abs(Unreachable.Magnitude - Config.MinSpeed) < 0.001,
		"An unreachable target must still produce a finite projectile velocity")
	local Coincident = Config.GetVelocity(Origin, Origin, 0, 0)
	Check(math.abs(Coincident.Magnitude - Config.MinSpeed) < 0.001, "An aim point at the origin must not produce NaN")
	Check(Config.GetSway(4, 123) == Config.GetSway(4, 123), "Server and client sway must be deterministic")
	Check(Config.GetSway(4, 123) ~= Config.GetSway(4, 456), "Different draw seeds must produce different sway")

	for _, Pitch in { -75, -45, 0, 45, 75 } do
		local CameraPose = CFrame.Angles(math.rad(Pitch), 0, 0)
		local AimPoint = CameraPose.LookVector * 100
		local AimTarget = Config.GetAimTarget(Origin, AimPoint, 4, 123)
		local CameraSpace = CameraPose:PointToObjectSpace(AimTarget)
		Check(CameraSpace.Z < 0, "The cursor must remain in front of the camera at pitch " .. Pitch)
		Check(math.abs(math.atan2(CameraSpace.Y, -CameraSpace.Z)) < math.rad(Config.SwayMaximumDegrees + 1),
			"Vertical aim must follow the camera instead of the horizon at pitch " .. Pitch)
	end

	local SwayTarget = Config.GetAimTarget(Origin, Target, 4, 123)
	local SwayVelocity = Config.GetVelocity(Origin, Target, 4, 123)
	local SwayFlightTime = (SwayTarget * Vector3.new(1, 0, 1)).Magnitude
		/ (SwayVelocity * Vector3.new(1, 0, 1)).Magnitude
	local SwayImpact = Origin + SwayVelocity * SwayFlightTime + Acceleration * (SwayFlightTime * SwayFlightTime / 2)
	local SwayDrop = SwayImpact - SwayTarget
	Check(math.abs(SwayDrop.X) < 0.001 and math.abs(SwayDrop.Z) < 0.001 and SwayDrop.Y < 0,
		"A swayed shot must fall below its indicated initial aim direction")

	for _, Elapsed in { 0, 0.75, 1.5, 4.9 } do
		for _, AimPoint in { Vector3.new(0, 0, -400), Vector3.new(60, 80, -150), Vector3.new(-60, -80, -150) } do
			local ExpectedTarget = Config.GetAimTarget(Origin, AimPoint, Elapsed, 123)
			local ShotVelocity = Config.GetVelocity(Origin, AimPoint, Elapsed, 123)
			local Direction = (ExpectedTarget - Origin).Unit
			Check(ShotVelocity.Unit:Dot(Direction) > 0.99999, "Every charge level must launch toward the cursor without extra elevation")
			local TravelTime = (ExpectedTarget - Origin).Magnitude / ShotVelocity.Magnitude
			local Position = Origin + ShotVelocity * TravelTime + Acceleration * (TravelTime * TravelTime / 2)
			local Drop = Position - ExpectedTarget
			Check(math.abs(Drop.X) < 0.001 and math.abs(Drop.Z) < 0.001 and Drop.Y < 0,
				"Every charge level must keep the initial aim direction while falling under gravity")
		end
	end

	local OriginalPosition = Config.BackPosition
	local OriginalRotation = Config.BackRotationDegrees
	Config.BackPosition = Vector3.new(1, 2, 3)
	Config.BackRotationDegrees = Vector3.new(0, 90, 0)
	local BackOffset = Config.GetBackOffset()
	Check(BackOffset.Position == Config.BackPosition, "Editing BackPosition must directly update the torso offset")
	Check(BackOffset.LookVector:Dot(Vector3.new(-1, 0, 0)) > 0.99999, "Back rotation must use degrees")
	Config.BackPosition = OriginalPosition
	Config.BackRotationDegrees = OriginalRotation

	local PeakSway = 0
	for Index = 0, 100 do
		local Sway = Config.GetSway(4 + Index / 100, 123)
		PeakSway = math.max(PeakSway, math.abs(Sway.X), math.abs(Sway.Y))
	end
	Check(PeakSway > math.rad(2) and PeakSway <= math.rad(4), "Overholding should produce a reduced sway between two and four degrees")
	for _, Seed in { 0, 123, 456 } do
		for _, Elapsed in { -1, 0, 0.75, 1.499, Config.FullChargeTime } do
			Check(Config.GetSway(Elapsed, Seed) == Vector2.zero, "The bow must have no sway until fully charged")
			Check(Config.GetDrawCameraSway(Elapsed, Seed) == CFrame.identity, "The camera must remain steady until fully charged")
		end
	end
	Check(Config.GetSway(Config.FullChargeTime + 0.001, 123).Magnitude < 0.000001,
		"Sway must begin smoothly after full charge")
	Check(Config.GetDrawCameraSway(4, 123) == Config.GetDrawCameraSway(4, 123), "Draw camera sway must be deterministic")
	local EarlyPeak = 0
	local LatePeak = 0
	for Index = 0, 100 do
		local EarlyPitch, EarlyYaw = Config.GetDrawCameraSway(1.6 + Index / 200, 123):ToOrientation()
		local LatePitch, LateYaw = Config.GetDrawCameraSway(4 + Index / 100, 123):ToOrientation()
		EarlyPeak = math.max(EarlyPeak, math.abs(EarlyPitch), math.abs(EarlyYaw))
		LatePeak = math.max(LatePeak, math.abs(LatePitch), math.abs(LateYaw))
	end
	Check(LatePeak > EarlyPeak * 2, "Camera sway should increase while overholding")
	Check(LatePeak < math.rad(1), "Camera sway should stay below one degree")
	local PeakCameraSpeed = 0
	for Index = 0, 499 do
		local Current = Config.GetDrawCameraSway(Index / 100, 123)
		local Next = Config.GetDrawCameraSway((Index + 1) / 100, 123)
		local _, Angle = Current:ToObjectSpace(Next):ToAxisAngle()
		PeakCameraSpeed = math.max(PeakCameraSpeed, Angle * 100)
	end
	Check(PeakCameraSpeed < math.rad(4), "The camera should sway slowly without rapid tremor")

	local Tip = Vector3.new(10, 20, 30)
	local ArrowLength = 2.7
	for _, ArrowVelocity in {
		Vector3.new(0, 0, -110), Vector3.new(0, 60, -110), Vector3.new(0, -60, -110),
		Vector3.yAxis, -Vector3.yAxis, Vector3.zero,
	} do
		local Pose = Config.GetArrowCFrame(Tip, ArrowVelocity, ArrowLength)
		local MeshTip = Pose:PointToWorldSpace(Vector3.new(0, 0, -ArrowLength * 0.5))
		Check((MeshTip - Tip).Magnitude < 0.001, "The mesh tip must match the cast position during flight and impact")
		Check(Pose.LookVector.X == Pose.LookVector.X, "Vertical or zero velocity must not produce an invalid arrow rotation")
		if ArrowVelocity.Magnitude > 0 then
			Check(Pose.LookVector:Dot(ArrowVelocity.Unit) > 0.99999, "The arrow must point along its current falling velocity")
		end
	end
	local Nock = Config.GetNockedArrowOffset(ArrowLength)
	local Tail = Nock:PointToWorldSpace(Vector3.new(0, 0, ArrowLength * 0.5))
	Check((Tail - Config.NockedArrowPosition).Magnitude < 0.001, "The -Z mesh must keep its tail at the drawing hand")

	local Container = Instance.new("Folder")
	local Character = Instance.new("Model")
	Character.Parent = Container
	local Root = Instance.new("Part")
	Root.Parent = Character
	Character.PrimaryPart = Root
	local Humanoid = Instance.new("Humanoid")
	Humanoid.Parent = Character
	Check(Config.CanUse(Character), "A healthy character can use the bow")
	for _, Attribute in Config.CancelAttributes do
		Character:SetAttribute(Attribute, true)
		Check(not Config.CanUse(Character), Attribute .. " must prevent drawing or shooting")
		Character:SetAttribute(Attribute, nil)
	end
	Character:SetAttribute("SkillState", "Charge")
	Check(not Config.CanUse(Character), "Charging another skill must prevent shooting")
	Character:SetAttribute("SkillState", nil)
	local Tool = Instance.new("Tool")
	Tool.Parent = Character
	Check(not Config.CanUse(Character), "Holding a tool must prevent using the bow")
	Container:Destroy()

	return string.format("BowConfig: %d checks passed", Checks)
end
