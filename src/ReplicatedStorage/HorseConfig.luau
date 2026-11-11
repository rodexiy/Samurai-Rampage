export type HorseStats = {
	ModelName: string,
	Speed: number,
	Acceleration: number,
	TurnSpeed: number,
}

local HorseConfig = {
	DefaultTier = 1,
	SpawnKey = Enum.KeyCode.H,
	DismountKey = Enum.KeyCode.Space,
	SpawnDistance = 14,
	SpawnCooldown = 2,
	MountDistance = 12,
	GroundProbeHeight = 12,
	GroundProbeDepth = 64,
	MinimumGroundNormal = 0.55,
	Braking = 65,
	PhysicsAcceleration = 180,
	Gaits = {
		TrotMultiplier = 0.4,
		GallopMultiplier = 0.72,
		TapGain = 0.25,
		TapWindow = 0.65,
		MinimumTapInterval = 0.12,
		TapGrace = 0.7,
		BoostDecay = 0.3,
		TransitionUp = 1.2,
		TransitionDown = 0.18,
		AnimationStartRatio = 0.44,
		AnimationFullRatio = 0.7,
	},
	Steering = {
		MinimumRadius = 6,
		LateralAcceleration = 90,
		LowSpeed = 10,
		MaximumTurnRate = math.rad(135),
		PivotTurnRate = math.rad(150),
		TurnAcceleration = math.rad(240),
		MaximumBank = math.rad(8),
		BankStrength = 0.35,
		BankResponse = 6,
		Avoidance = {
			LookAheadTime = 0.8,
			MinimumDistance = 8,
			MaximumDistance = 45,
			ScanInterval = 0.1,
			Response = 7,
			SidePreference = 0.45,
			MinimumSpeedMultiplier = 0.25,
		},
	},
	ValidationInterval = 0.5,
	PositionTolerance = 12,
	Tag = "HorseMount",
	-- Offset from the center of the horse's world-aligned bounding box to the rider's root.
	RiderOffset = CFrame.new(0, 3.2, 0.5),
	Grounding = {
		CollisionGroup = "HorseMount",
		MaximumSlope = math.rad(50),
		MaximumSupportSlope = math.rad(70),
		ObstacleSkin = 0.2,
		ObstacleQueryGroup = "Entity",
		ObstacleSweepDistance = 256,
		CharacterGroups = { "Entity", "BigEntity", "ForceField", "Carried" },
		ProbeInterval = 1 / 30,
		StepHeight = 3,
		DropDistance = 1.5,
		RecoveryHeight = 18,
		RecoveryTravel = 12,
		PenetrationTolerance = 0.25,
		PlaneTolerance = 0.6,
		ProbeTravel = 0.65,
		HeightResponse = 16,
		MaximumCorrectionSpeed = 12,
		MaximumVerticalSpeed = 80,
		SupportAcceleration = 1000,
		MaximumReleaseSpeed = 4,
		MaximumPitch = math.rad(50),
		MaximumRoll = math.rad(30),
		TiltResponse = 10,
	},
	Animation = {
		SmoothLocalRider = true,
		LocalNormalResponse = 18,
		PoseSeedResponse = 0.6,
		NeckTurn = {
			MaximumAngle = math.rad(22),
			LookAhead = 0.25,
			Response = 8,
		},
		RiderLook = {
			MaximumSpeed = 1.5,
			MaximumYaw = math.rad(40),
			MaximumPitch = math.rad(18),
			Interval = 0.1,
			KeepAlive = 0.5,
			Timeout = 1,
			MinimumChange = math.rad(1.5),
			Response = 7,
		},
		Tail = {
			Frequency = 2.2,
			Damping = 0.75,
			MaximumYaw = math.rad(22),
			MaximumLift = math.rad(22),
			MaximumDrop = math.rad(10),
			RunningLift = math.rad(12),
			TurnInfluence = 0.12,
			AccelerationInfluence = 0.002,
			MaximumAcceleration = 100,
			IdleSway = math.rad(4),
			GaitSway = math.rad(6),
			MovementSway = math.rad(7),
			SwishAngle = math.rad(18),
			SwishPeriod = 6,
			SwishDuration = 1.8,
		},
		FrontLeg = {
			MaximumForwardReach = 3.2,
			SwingReach = 1,
			SupportBend = math.rad(10),
			TerrainBend = math.rad(35),
			SwingBend = math.rad(65),
			FoldEnd = 0.3,
			ExtendStart = 0.45,
			ExtendEnd = 0.82,
			Response = 16,
		},
		Idle = {
			BlendSpeed = 3,
			Response = 7,
			PoseResponse = 10,
			FootTolerance = 0.16,
			FootDuration = 0.18,
			StepHeight = 0.25,
		},
		FullDistance = 90,
		MaxDistance = 240,
		FullInterval = 1 / 30,
		DistantInterval = 1 / 15,
		Prediction = {
			Enabled = true,
			Interval = 1 / 12,
			MaximumTime = 0.45,
			MaximumDistance = 24,
			MaximumAcceleration = 60,
			ProbeHeight = 4,
			ProbeDepth = 6,
			MaximumSurfaceRise = 2.5,
			MaximumFootRaise = 1.5,
			MaximumFootLower = 1.2,
			MaximumExtraLift = 0.9,
			MaximumLift = 2.4,
			LandingBlendTime = 0.12,
			Response = 10,
			MaximumBodyPitch = math.rad(4),
			MaximumBodyLift = 0.18,
		},
		StrideLength = 10,
		MinimumFrequency = 0.8,
		MaximumFrequency = 3.8,
		Running = {
			StartSpeed = 18,
			FullSpeed = 30,
			BlendResponse = 5,
			StrideLength = 20,
			MinimumFrequency = 1.3,
			MaximumFrequency = 2.8,
			StanceFraction = 0.24,
			PlantDistance = 3,
			StepHeight = 1.9,
			BodyBounce = 0.28,
			BodyPitch = math.rad(3),
			NeckPitch = math.rad(4),
			IKIterations = 20,
			MaximumJointSpeed = 12,
		},
		StanceFraction = 0.58,
		PlantDistance = 2.2,
		StepHeight = 1.3,
		HoofClearance = 0.08,
		ProbeHeight = 2.5,
		ProbeDepth = 2.5,
		MaximumLegExtension = 0.985,
		SettleDuration = 0.2,
		MinimumSwingDuration = 0.16,
		MaximumForwardReach = 2,
		MaximumBackwardReach = 2.8,
		MaximumJointSpeed = 12,
		MaximumHipSpeed = 5,
		BodyDrop = 0.4,
		BodyBounce = 0.13,
		MaximumTilt = math.rad(10),
		MoveThreshold = 0.6,
		IKIterations = 16,
		HoofPitchLimit = math.rad(35),
		-- Degrees relative to the bind pose, around the horse's side axis.
		FrontJointLimits = { { -30, 40 }, { -25, 25 }, { -25, 50 }, { -85, 8 }, { -15, 15 }, { -15, 15 }, { -35, 35 } },
		BackJointLimits = { { -35, 35 }, { -65, 25 }, { -8, 80 }, { -15, 15 }, { -15, 15 }, { -35, 35 } },
		Legs = {
			-- Running contacts: rear left, rear right, front left, front right.
			{ Prefix = "SK_L_F_leg_", Hoof = 7, Phase = 0, RunPhase = 0.5, Front = true },
			{ Prefix = "SK_R_F_leg_", Hoof = 7, Phase = 0.5, RunPhase = 0.38, Front = true },
			{ Prefix = "SK_L_B_leg_", Hoof = 6, Phase = 0.5, RunPhase = 0, Front = false },
			{ Prefix = "SK_R_B_leg_", Hoof = 6, Phase = 0, RunPhase = -0.12, Front = false },
		},
	},
	BlockedAttributes = {
		"Died", "Downed", "Ragdoll", "Carried", "Carrying", "InCell", "InLabor",
		"Meditating", "Climbing", "WallRunning", "Vaulting", "Rolling", "PostureBreak",
		"HeavyDeflect", "BeenDeflected", "RealmTeleporting", "CameraCutscene",
		"Attacking", "Attack", "Blocking", "BowDrawing", "UsingSkillCantAttack", "SkillLockMovement",
	},
	Tiers = {
		{ ModelName = "Horse1", Speed = 44, Acceleration = 24, TurnSpeed = 5 },
		{ ModelName = "Horse2", Speed = 52, Acceleration = 28, TurnSpeed = 5.5 },
		{ ModelName = "Horse3", Speed = 60, Acceleration = 32, TurnSpeed = 6 },
		{ ModelName = "Horse4", Speed = 70, Acceleration = 36, TurnSpeed = 6.5 },
		{ ModelName = "Horse5", Speed = 80, Acceleration = 40, TurnSpeed = 7 },
	} :: { HorseStats },
}

function HorseConfig.GetTier(Tier: number): HorseStats?
	return HorseConfig.Tiers[Tier]
end

function HorseConfig.CanMount(Character: Model): boolean
	local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
	if not Character.Parent or not Character.PrimaryPart or not Humanoid or Humanoid.Health <= 0 then
		return false
	end

	if Character.PrimaryPart.Anchored or Humanoid.Sit or Humanoid.PlatformStand then
		return false
	end

	for _, Attribute in HorseConfig.BlockedAttributes do
		if Character:GetAttribute(Attribute) then
			return false
		end
	end

	local SkillState = Character:GetAttribute("SkillState")
	return SkillState ~= "Charge" and SkillState ~= "Charged"
end

return HorseConfig
