local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BowConfig = require(ReplicatedStorage.Shared.BowConfig)
local HorseConfig = require(ReplicatedStorage.Shared.HorseConfig)
local MountedAim = require(ReplicatedStorage.Shared.Utils.MountedAim)
local HorseRiderStateController = require(Players.LocalPlayer.PlayerScripts.Client.Controllers.HorseRiderStateController)

local AimPoseController = {}
local Settings = BowConfig.AimPose

type JointPose = { Joint: Motor6D, Rest: CFrame }

export type State = {
	Waist: Motor6D,
	RightHip: Motor6D,
	LeftHip: Motor6D,
	WaistRest: CFrame,
	RightHipRest: CFrame,
	LeftHipRest: CFrame,
	Neck: JointPose?,
	RightShoulder: JointPose?,
	LeftShoulder: JointPose?,
	Yaw: number,
	Pitch: number,
	ArmPitch: number,
	ArmYaw: number,
	HeadPitch: number,
	HeadYaw: number,
	Applied: boolean,
}

local function Capture(Joint: Motor6D?): JointPose?
	return if Joint then { Joint = Joint, Rest = Joint.C0 } else nil
end

local function Rotate(Pose: JointPose?, Pitch: number, Yaw: number)
	if Pose and Pose.Joint.Enabled then
		Pose.Joint.C0 = CFrame.new(Pose.Rest.Position) * CFrame.Angles(0, Yaw, 0)
			* CFrame.Angles(Pitch, 0, 0) * Pose.Rest.Rotation
	end
end

local function GetPitch(Direction: Vector3): number
	return math.atan2(Direction.Y, Vector2.new(Direction.X, Direction.Z).Magnitude)
end

local function RotateAnimated(Pose: JointPose?, Rotation: CFrame)
	if not Pose or not Pose.Joint.Enabled then
		return
	end

	local Pivot = (Pose.Rest * Pose.Joint.Transform).Position
	Pose.Joint.C0 = CFrame.new(Pivot) * Rotation * CFrame.new(-Pivot) * Pose.Rest
end

local function ApplyBowAim(State: State, Torso: CFrame, Direction: Vector3,
	TargetPitch: number, Aiming: boolean, TurnHead: boolean, Alpha: number)
	-- The draw animation turns the torso sideways. Elevate around the aiming
	-- direction's right axis instead of the torso's right axis, which rolls the arms.
	local PitchAxis = CFrame.Angles(0, State.Yaw, 0).RightVector
	local ArmPitch = if Aiming then math.clamp(TargetPitch - State.Pitch, -Settings.MaximumArmPitch, Settings.MaximumArmPitch) else 0
	local ArmYaw = if Aiming then math.atan2(-Direction.X, -Direction.Z) - State.Yaw else 0
	ArmYaw = math.atan2(math.sin(ArmYaw), math.cos(ArmYaw))
	State.ArmPitch += (ArmPitch - State.ArmPitch) * Alpha
	State.ArmYaw += (ArmYaw - State.ArmYaw) * Alpha
	local ArmRotation = Torso.Rotation:Inverse() * CFrame.Angles(0, State.ArmYaw, 0)
		* CFrame.fromAxisAngle(PitchAxis, State.ArmPitch) * Torso.Rotation
	RotateAnimated(State.RightShoulder, ArmRotation)
	RotateAnimated(State.LeftShoulder, ArmRotation)

	local Neck = State.Neck
	if not Neck then
		return
	end

	-- The bow clip already counter-turns the head. Aim from its animated frame
	-- so this correction does not apply that turn a second time.
	local Head = Neck.Rest * Neck.Joint.Transform * Neck.Joint.C1:Inverse()
	local LocalAim = (Torso * Head):VectorToObjectSpace(Direction)
	local HeadPitch = if TurnHead then math.clamp(GetPitch(LocalAim), -Settings.MaximumHeadPitch, Settings.MaximumHeadPitch) else 0
	local HeadYaw = if TurnHead then math.clamp(math.atan2(-LocalAim.X, -LocalAim.Z),
		-Settings.MaximumHeadYaw, Settings.MaximumHeadYaw) else 0
	State.HeadPitch += (HeadPitch - State.HeadPitch) * Alpha
	State.HeadYaw += (HeadYaw - State.HeadYaw) * Alpha
	local HeadRotation = Head.Rotation * CFrame.Angles(0, State.HeadYaw, 0)
		* CFrame.Angles(State.HeadPitch, 0, 0) * Head.Rotation:Inverse()
	RotateAnimated(Neck, HeadRotation)
end

function AimPoseController.Create(Waist: Motor6D, RightHip: Motor6D, LeftHip: Motor6D,
	Neck: Motor6D?, RightShoulder: Motor6D?, LeftShoulder: Motor6D?): State
	return {
		Waist = Waist, RightHip = RightHip, LeftHip = LeftHip,
		WaistRest = Waist.C0, RightHipRest = RightHip.C0, LeftHipRest = LeftHip.C0,
		Neck = Capture(Neck), RightShoulder = Capture(RightShoulder), LeftShoulder = Capture(LeftShoulder),
		Yaw = 0, Pitch = 0, ArmPitch = 0, ArmYaw = 0, HeadPitch = 0, HeadYaw = 0, Applied = false,
	}
end

function AimPoseController.Reset(State: State)
	if State.Applied then
		State.Waist.C0 = State.WaistRest
		State.RightHip.C0 = State.RightHipRest
		State.LeftHip.C0 = State.LeftHipRest

		for _, Pose in { State.Neck, State.RightShoulder, State.LeftShoulder } do
			Pose.Joint.C0 = Pose.Rest
		end
	end

	State.Yaw, State.Pitch, State.ArmPitch, State.ArmYaw = 0, 0, 0, 0
	State.HeadPitch, State.HeadYaw = 0, 0
	State.Applied = false
end

local function CanAim(Character: Model): boolean
	if Character:GetAttribute("BowEquipped") ~= true and Character:GetAttribute("BowDrawing") ~= true then
		return false
	end

	local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
	if Humanoid and Humanoid.Health <= 0 then
		return false
	end

	for _, Attribute in BowConfig.CancelAttributes do
		if Character:GetAttribute(Attribute) then
			return false
		end
	end

	return true
end

function AimPoseController.CanTurnHead(Character: Model): boolean
	local RidingFast = HorseRiderStateController.IsRunning(Character)
	if Character:GetAttribute("InHorse") == true and Character:GetAttribute("Bow") == "Tanegashima"
		and Character:GetAttribute("BowEquipped") == true then
		return Character:GetAttribute("BowDrawing") == true or not RidingFast
	end

	return Character:GetAttribute("Running") ~= true
end

function AimPoseController.UpdateFromCFrame(State: State, Character: Model, CameraFrame: CFrame, DeltaTime: number): boolean
	local TurnHead = AimPoseController.CanTurnHead(Character)
	local Root = Character.PrimaryPart
	if not Root or not CanAim(Character) then
		AimPoseController.Reset(State)
		return false
	end

	local Mounted = MountedAim.IsActive(Character)
	local IsBow = Character:GetAttribute("Bow") ~= "Tanegashima"
	local Aiming = not IsBow or Character:GetAttribute("BowDrawing") == true
	local MaximumYaw = if Mounted then HorseConfig.MountedAim.MaximumYaw else Settings.StandingMaximumYaw
	local Direction = if Mounted then MountedAim.ClampDirection(Root.CFrame, CameraFrame.LookVector) else CameraFrame.LookVector
	local TargetYaw = if Aiming then math.clamp(MountedAim.GetYaw(Root.CFrame, Direction), -MaximumYaw, MaximumYaw) else 0
	local TargetPitch = if Aiming then math.clamp(GetPitch(Root.CFrame:VectorToObjectSpace(Direction)), -Settings.MaximumPitch, Settings.MaximumPitch) else 0
	local Response = if Mounted then HorseConfig.MountedAim.TorsoResponse else Settings.Response
	local Alpha = 1 - math.exp(-Response * math.max(DeltaTime, 0))
	State.Yaw += (TargetYaw - State.Yaw) * Alpha
	State.Pitch += (math.clamp(TargetPitch * Settings.TorsoPitchFraction,
		-Settings.MaximumTorsoPitch, Settings.MaximumTorsoPitch) - State.Pitch) * Alpha

	local Waist = State.Waist
	local Rest = State.WaistRest
	Waist.C0 = CFrame.new(Rest.Position) * CFrame.Angles(0, State.Yaw, 0)
		* CFrame.Angles(State.Pitch, 0, 0) * Rest.Rotation

	-- Bow clips override RootJoint but leave the riding hip animations playing.
	-- Keep the legs in the riding torso frame, independent of the bow's authored turn.
	local AnimatedRest = Rest * Waist.Transform * Waist.C1:Inverse()
	local AnimatedTurn = Waist.C0 * Waist.Transform * Waist.C1:Inverse()
	local LegReference = AnimatedRest
	if Mounted and IsBow then
		local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
		local Animator = Humanoid and Humanoid:FindFirstChildWhichIsA("Animator")
		local RidingTransform = Animator and HorseRiderStateController.GetTorsoTransform(Animator)
		if RidingTransform then
			LegReference = Rest * RidingTransform * Waist.C1:Inverse()
		end
	end

	local Counter = AnimatedTurn:Inverse() * LegReference
	State.RightHip.C0 = Counter * State.RightHipRest
	State.LeftHip.C0 = Counter * State.LeftHipRest

	if IsBow then
		ApplyBowAim(State, AnimatedTurn, Root.CFrame:VectorToObjectSpace(Direction), TargetPitch, Aiming, TurnHead, Alpha)
		State.Applied = true
		return true
	end

	-- Account for the actual animated torso, including riding lean, before aiming arms and head.
	local LocalAim = (Root.CFrame * AnimatedTurn):VectorToObjectSpace(Direction)
	local RemainingPitch = GetPitch(LocalAim)
	State.ArmPitch += (math.clamp(RemainingPitch, -Settings.MaximumArmPitch, Settings.MaximumArmPitch) - State.ArmPitch) * Alpha
	local HeadPitch = if TurnHead then math.clamp(RemainingPitch, -Settings.MaximumHeadPitch, Settings.MaximumHeadPitch) else 0
	State.HeadPitch += (HeadPitch - State.HeadPitch) * Alpha
	local HeadYaw = math.atan2(-LocalAim.X, -LocalAim.Z)
	HeadYaw = if TurnHead then math.clamp(HeadYaw, -Settings.MaximumHeadYaw, Settings.MaximumHeadYaw) else 0
	State.HeadYaw += (HeadYaw - State.HeadYaw) * Alpha
	Rotate(State.RightShoulder, State.ArmPitch, 0)
	Rotate(State.LeftShoulder, State.ArmPitch, 0)
	Rotate(State.Neck, State.HeadPitch, State.HeadYaw)
	State.Applied = true

	return true
end

function AimPoseController.Update(State: State, Character: Model, Camera: Camera?, DeltaTime: number): boolean
	if not Camera or Camera.CameraType ~= Enum.CameraType.Custom then
		AimPoseController.Reset(State)
		return false
	end

	return AimPoseController.UpdateFromCFrame(State, Character, Camera.CFrame, DeltaTime)
end

return AimPoseController
