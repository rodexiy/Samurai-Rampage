local Players = game:GetService("Players")

local BowConfig = {
	WeaponName = "Bow",
	IsFirearm = false,
	Ammunition = { Arrow = 1 },
	AmmoWarning = "You need arrows to use the bow.",
	HandPart = "Left Arm",
	BackPart = "Torso",
	ArrowItem = "Arrow",
	MinDrawTime = 0.8,
	FullChargeTime = 1.5,
	MaxHoldTime = 5,
	ShotCooldown = 0.65,
	DrawWalkSpeed = 6,
	MinSpeed = 140,
	MaxSpeed = 750,
	MinDamage = 8,
	MaxDamage = 35,
	DistanceDamageRange = 200,
	DistanceDamageBonus = 0.5,
	DrawFovReduction = 16,
	DrawFovRestoreTime = 0.25,
	FocusFovReduction = 12,
	FocusFovTransitionTime = 0.2,
	FocusMaxMoveSpeed = 0.75,
	FocusExitMoveSpeed = 1.5,
	FocusMoveInputDeadzone = 0.05,
	FocusSettleTime = 0.12,
	AimSensitivityMultiplier = 0.6,
	FocusSensitivityMultiplier = 0.4,
	MaxDistance = 2000,
	MaxFlightTime = 8,
	ArrowTrailWidth = 0.045,
	ArrowTrailLifetime = 0.1,
	AimUpdateInterval = 0.08,
	SwayMaximumDegrees = 5,
	SwayGrowth = 1.2,
	CameraSwayScale = 0.22,
	CameraSwayResponse = 8,
	AimPose = {
		MaximumPitch = math.rad(85),
		TorsoPitchFraction = 0.25,
		MaximumTorsoPitch = math.rad(20),
		StandingMaximumYaw = math.rad(35),
		MaximumArmPitch = math.rad(85),
		MaximumHeadPitch = math.rad(60),
		MaximumHeadYaw = math.rad(45),
		Response = 14,
	},

	-- Posicao do arco guardado, relativa ao Torso (em studs): X lado, Y altura, Z costas.
	BackPosition = Vector3.new(-0.8, 0, 0.85),
	-- Rotacao em graus: X inclinacao, Y giro, Z diagonal.
	BackRotationDegrees = Vector3.new(0, -90, 0),
	HandOffset = CFrame.identity,
	ArrowOffset = Vector3.new(-0.75, 0, 0),
	-- Flecha na mao direita: posicao da traseira da flecha e rotacao em graus.
	NockedArrowPosition = Vector3.zero,
	NockedArrowRotationDegrees = Vector3.new(-64.9071, 23.8492, -80.0647),

	Animations = {
		Equip = { Name = "Bow Equip", Id = "rbxassetid://124332008129070" },
		Unequip = { Name = "Bow Unequip", Id = "rbxassetid://136083398740604" },
		Aim = { Name = "Bow Aim", Id = "rbxassetid://126473484245726" },
		Hold = { Name = "Bow Aim Hold", Id = "rbxassetid://98792967016289" },
		Shot = { Name = "Bow Aimed Shot", Id = "rbxassetid://123757796301226" },
		ShotLooped = { Name = "Bow Aimed Shot Looped", Id = "rbxassetid://121361457470273" },
		Shoot = { Name = "Bow Shoot", Id = "rbxassetid://76526074090352" },
		Pose = { Name = "Bow Pose", Id = "rbxassetid://123681337764234" },
	},
	CancelAttributes = {
		"Died", "Downed", "Ragdoll", "BeenHitted", "PostureBreak", "HeavyDeflect",
		"BeenDeflected", "Meditating", "Rolling", "RollClientDebounce", "Climbing",
		"Vaulting", "WallRunning", "CameraCutscene", "RealmTeleporting", "SkillLockMovement",
		"InCell", "InLabor", "Attacking", "Blocking", "UsingSkillCantAttack",
	},
}

function BowConfig.GetBackOffset(): CFrame
	local Rotation = BowConfig.BackRotationDegrees
	return CFrame.new(BowConfig.BackPosition)
		* CFrame.Angles(math.rad(Rotation.X), math.rad(Rotation.Y), math.rad(Rotation.Z))
end

function BowConfig.GetNockedArrowOffset(Length: number): CFrame
	local Rotation = BowConfig.NockedArrowRotationDegrees
	return CFrame.new(BowConfig.NockedArrowPosition)
		* CFrame.Angles(math.rad(Rotation.X), math.rad(Rotation.Y), math.rad(Rotation.Z))
		* CFrame.new(0, 0, -Length * 0.5)
end

function BowConfig.GetImpactSoundType(HitInstance: Instance?, Material: Enum.Material?): string
	local Target = HitInstance
	while Target and Target ~= workspace do
		if Target:IsA("Model") and Players:GetPlayerFromCharacter(Target) then
			return "Player"
		end
		Target = Target.Parent
	end

	if not Material and HitInstance and HitInstance:IsA("BasePart") and not HitInstance:IsA("Terrain") then
		Material = HitInstance.Material
	end
	if Material == Enum.Material.Metal or Material == Enum.Material.DiamondPlate
		or Material == Enum.Material.CorrodedMetal or Material == Enum.Material.Foil then
		return "Metal"
	elseif Material == Enum.Material.Wood or Material == Enum.Material.WoodPlanks then
		return "Wood"
	end

	return "Default"
end

function BowConfig.CanUse(Character: Model): boolean
	local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
	if not Character.Parent or not Character.PrimaryPart or not Humanoid or Humanoid.Health <= 0 then
		return false
	end

	for _, Attribute in BowConfig.CancelAttributes do
		if Character:GetAttribute(Attribute) then
			return false
		end
	end

	local SkillState = Character:GetAttribute("SkillState")
	return SkillState ~= "Charge" and SkillState ~= "Charged"
		and Character:FindFirstChildWhichIsA("Tool") == nil
end

function BowConfig.IsValidAim(Point: any): boolean
	return typeof(Point) == "Vector3" and Point.X == Point.X and Point.Y == Point.Y and Point.Z == Point.Z
		and math.abs(Point.X) < 1e6 and math.abs(Point.Y) < 1e6 and math.abs(Point.Z) < 1e6
end

function BowConfig.GetCharge(Elapsed: number): number
	return math.clamp(Elapsed / BowConfig.FullChargeTime, 0, 1)
end

function BowConfig.GetDamage(Charge: number, Distance: number): number
	local BaseDamage = BowConfig.MinDamage + (BowConfig.MaxDamage - BowConfig.MinDamage) * math.clamp(Charge, 0, 1)
	local DistanceBonus = math.clamp(Distance / BowConfig.DistanceDamageRange, 0, 1) * BowConfig.DistanceDamageBonus
	return BaseDamage * (1 + DistanceBonus)
end

function BowConfig.GetOrigin(Character: Model): Vector3?
	local Bow = Character:FindFirstChild("BowModel") :: Model?
	if Bow and Bow.PrimaryPart then
		return Bow.PrimaryPart.CFrame:PointToWorldSpace(BowConfig.ArrowOffset)
	end

	return nil
end

local function GetOverdrawProgress(Elapsed: number): number
	local Progress = math.clamp((Elapsed - BowConfig.FullChargeTime)
		/ (BowConfig.MaxHoldTime - BowConfig.FullChargeTime), 0, 1)
	return (Progress * Progress * (3 - 2 * Progress)) ^ BowConfig.SwayGrowth
end

function BowConfig.GetSway(Elapsed: number, Seed: number): Vector2
	local Strength = math.rad(BowConfig.SwayMaximumDegrees) * GetOverdrawProgress(Elapsed)
	local Phase = Seed * 0.017
	return Vector2.new(
		math.sin(Elapsed * 2.1 + Phase),
		math.sin(Elapsed * 1.65 + Phase * 1.3)
	) * Strength
end

function BowConfig.GetDrawCameraSway(Elapsed: number, Seed: number): CFrame
	local Sway = BowConfig.GetSway(Elapsed, Seed) * BowConfig.CameraSwayScale
	return CFrame.Angles(Sway.Y, Sway.X, Sway.X * 0.12)
end

function BowConfig.GetAimTarget(Origin: Vector3, AimPoint: Vector3, Elapsed: number, Seed: number): Vector3
	local Offset = AimPoint - Origin
	if Offset.Magnitude < 0.01 then
		Offset = Vector3.new(0, 0, -1)
	end

	local Sway = BowConfig.GetSway(Elapsed, Seed)
	local Direction = (CFrame.lookAt(Vector3.zero, Offset.Unit) * CFrame.Angles(Sway.Y, Sway.X, 0)).LookVector
	return Origin + Direction * math.min(Offset.Magnitude, BowConfig.MaxDistance)
end

function BowConfig.GetVelocity(Origin: Vector3, AimPoint: Vector3, Elapsed: number, Seed: number): Vector3
	local TargetOffset = BowConfig.GetAimTarget(Origin, AimPoint, Elapsed, Seed) - Origin
	local Speed = BowConfig.MinSpeed + (BowConfig.MaxSpeed - BowConfig.MinSpeed) * BowConfig.GetCharge(Elapsed)
	return TargetOffset.Unit * Speed
end

function BowConfig.GetArrowCFrame(Tip: Vector3, Direction: Vector3, Length: number): CFrame
	local Forward = if Direction.Magnitude > 0.001 then Direction.Unit else Vector3.new(0, 0, -1)
	local Up = if math.abs(Forward:Dot(Vector3.yAxis)) > 0.999 then Vector3.zAxis else Vector3.yAxis
	-- The current mesh points along local -Z; keep its tip on FastCast's trajectory.
	return CFrame.lookAt(Tip, Tip + Forward, Up) * CFrame.new(0, 0, Length * 0.5)
end

return BowConfig
