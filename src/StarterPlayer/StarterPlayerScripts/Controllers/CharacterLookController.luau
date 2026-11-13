local Players = game:GetService("Players")

local AimPoseController = require(Players.LocalPlayer.PlayerScripts.Client.Controllers.AimPoseController)

local CharacterLookController = {}

export type State = {
	Character: Model,
	Root: BasePart,
	Head: BasePart,
	Torso: BasePart,
	Aim: AimPoseController.State,
}

local function FindJoint(Parent: Instance, Name: string): Motor6D?
	local Joint = Parent:FindFirstChild(Name)

	return if Joint and Joint:IsA("Motor6D") then Joint else nil
end

function CharacterLookController.Create(Character: Model): State?
	local Root = Character.PrimaryPart
	local Head = Character:FindFirstChild("Head") :: BasePart?
	local Torso = Character:FindFirstChild("Torso") :: BasePart?
	if not Root or not Head or not Head:IsA("BasePart") or not Torso or not Torso:IsA("BasePart") then
		return nil
	end

	local Waist = FindJoint(Root, "RootJoint")
	local Neck = FindJoint(Torso, "Neck")
	local RightHip, LeftHip = FindJoint(Torso, "Right Hip"), FindJoint(Torso, "Left Hip")
	local RightShoulder, LeftShoulder = FindJoint(Torso, "Right Shoulder"), FindJoint(Torso, "Left Shoulder")
	if not Waist or not Neck or not RightHip or not LeftHip or not RightShoulder or not LeftShoulder then
		return nil
	end

	Neck.MaxVelocity = 1 / 3
	return {
		Character = Character, Root = Root, Head = Head, Torso = Torso,
		Aim = AimPoseController.Create(Waist, RightHip, LeftHip, Neck, RightShoulder, LeftShoulder),
	}
end

function CharacterLookController.Reset(State: State)
	local Aim = State.Aim
	AimPoseController.Reset(Aim)
	Aim.Waist.C0 = Aim.WaistRest
	Aim.RightHip.C0 = Aim.RightHipRest
	Aim.LeftHip.C0 = Aim.LeftHipRest
	if Aim.Neck then
		Aim.Neck.Joint.C0 = Aim.Neck.Rest
	end
end

local function FollowCamera(State: State, CameraFrame: CFrame, DeltaTime: number)
	local Aim = State.Aim
	local Neck = Aim.Neck
	if not Neck then
		return
	end

	local Point = CameraFrame.Position + CameraFrame.LookVector * 1000
	local Offset = Point - State.Head.Position
	if Offset.Magnitude < 0.001 then
		return
	end

	local Alpha = 1 - math.exp(-30 * math.max(DeltaTime, 0))
	local Pitch = math.atan2(Offset.Y, Offset.Magnitude) * 0.5
	local Yaw = (-Offset.Unit):Cross(State.Root.CFrame.LookVector).Y
	local Mounted = State.Character:GetAttribute("InHorse") == true or State.Character:GetAttribute("Mounted") == true
	local NeckTarget = if AimPoseController.CanTurnHead(State.Character)
		then CFrame.new(Neck.Rest.Position) * CFrame.Angles(Pitch, Yaw, 0) * Neck.Rest.Rotation else Neck.Rest
	Neck.Joint.C0 = Neck.Joint.C0:Lerp(NeckTarget, Alpha)
	local WaistTarget = if Mounted then Aim.WaistRest else CFrame.new(Aim.WaistRest.Position)
		* CFrame.Angles(Pitch, Yaw * 0.5, 0) * Aim.WaistRest.Rotation
	Aim.Waist.C0 = Aim.Waist.C0:Lerp(WaistTarget, Alpha)

	local Rest = Aim.WaistRest * Aim.Waist.Transform * Aim.Waist.C1:Inverse()
	local Turned = Aim.Waist.C0 * Aim.Waist.Transform * Aim.Waist.C1:Inverse()
	local Counter = Turned:Inverse() * Rest
	Aim.RightHip.C0 = Counter * Aim.RightHipRest
	Aim.LeftHip.C0 = Counter * Aim.LeftHipRest
end

function CharacterLookController.Update(State: State, Owner: Player, CameraFrame: CFrame?, Active: boolean, DeltaTime: number)
	local Character = State.Character
	if not Active or not CameraFrame then
		CharacterLookController.Reset(State)
		return
	end

	if AimPoseController.UpdateFromCFrame(State.Aim, Character, CameraFrame, DeltaTime) then
		return
	end

	local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
	if Owner:GetAttribute("FollowCamera") ~= true or Character:GetAttribute("Climbing") or Character:GetAttribute("Meditating")
		or Character:GetAttribute("Ragdoll") or Character:GetAttribute("Died") or Character:GetAttribute("Downed")
		or (Humanoid and Humanoid.Health <= 0) then
		CharacterLookController.Reset(State)
		return
	end

	FollowCamera(State, CameraFrame, DeltaTime)
end

return CharacterLookController
