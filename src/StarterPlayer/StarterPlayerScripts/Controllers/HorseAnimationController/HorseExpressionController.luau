local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local HorseConfig = require(ReplicatedStorage.Shared.HorseConfig)
local HorseSpringController = require(Players.LocalPlayer.PlayerScripts.Client.Controllers.HorseAnimationController.HorseSpringController)
local Idle = HorseConfig.Animation.Idle
local Spine = HorseConfig.Animation.Spine
local Head = HorseConfig.Animation.HeadMotion
local Running = HorseConfig.Animation.Running
local HorseExpressionController = {}

type Joint = {
	Bone: Bone, Rest: CFrame, Axis: Vector3, YawAxis: Vector3, RollAxis: Vector3,
	Kind: string, Index: number, Angle: number, Yaw: number, Roll: number,
	Velocity: number, YawVelocity: number, RollVelocity: number,
}
export type State = { Joints: { Joint } }

function HorseExpressionController.Create(Root: BasePart, Bones: { [string]: Bone }, Original: { [Bone]: CFrame }): State
	local Joints: { Joint } = {}
	for _, Definition in {
		{ "SK_spine_1", "Spine", 1 }, { "SK_spine_2", "Spine", 2 },
		{ "SK_spine_3", "Spine", 3 }, { "SK_spine_4", "Spine", 4 },
		{ "SK_neck_1", "Neck", 1 }, { "SK_neck_2", "Neck", 2 },
		{ "SK_head", "Head", 1 }, { "SK_Ear_L", "Ear", 1 }, { "SK_Ear_R", "Ear", 2 },
	} do
		local Bone = Bones[Definition[1]]
		if Bone then
			local Direction = if Definition[2] == "Ear" then Root.CFrame.LookVector else Root.CFrame.RightVector
			table.insert(Joints, {
				Bone = Bone, Rest = Original[Bone],
				Axis = Bone.TransformedWorldCFrame:VectorToObjectSpace(Direction).Unit,
				YawAxis = Bone.TransformedWorldCFrame:VectorToObjectSpace(Root.CFrame.UpVector).Unit,
				RollAxis = Bone.TransformedWorldCFrame:VectorToObjectSpace(Root.CFrame.LookVector).Unit,
				Kind = Definition[2], Index = Definition[3], Angle = 0, Yaw = 0, Roll = 0,
				Velocity = 0, YawVelocity = 0, RollVelocity = 0,
			})
		end
	end

	return { Joints = Joints }
end

function HorseExpressionController.Reset(State: State)
	for _, Joint in State.Joints do
		Joint.Angle = 0
		Joint.Yaw = 0
		Joint.Roll = 0
		Joint.Velocity = 0
		Joint.YawVelocity = 0
		Joint.RollVelocity = 0
		Joint.Bone.Transform = Joint.Rest
	end
end

function HorseExpressionController.Update(State: State, Time: number, Phase: number, Moving: number,
	Gallop: number, Sprint: number, DeltaTime: number)
	local Breath = math.sin(Time * math.pi * 2 / Idle.BreathingPeriod)
	local HeadPitch = Head.TrotPitch + (Head.GallopPitch + (Head.RunningPitch - Head.GallopPitch) * Sprint - Head.TrotPitch) * Gallop
	for _, Joint in State.Joints do
		local Angle = 0
		if Joint.Kind == "Spine" then
			local Delay = (Joint.Index - 1) * Spine.PhaseLag
			local Pulse = math.sin(Phase * math.pi * 4 + 0.6 - Delay) * (1 - Gallop)
				+ math.sin(Phase * math.pi * 2 + 0.6 - Delay) * Gallop
			local Gather = math.cos((Phase - Running.SuspensionPhase) * math.pi * 2 - Delay)
			Pulse += (Gather - Pulse) * Gallop * Sprint
			local Pitch = Spine.TrotPitch + (Spine.GallopPitch + (Spine.RunningPitch - Spine.GallopPitch) * Sprint - Spine.TrotPitch) * Gallop
			local Target = (Breath * 0.0004 * (1 - Moving) + Pulse * Pitch * Moving) * Spine.Weights[Joint.Index]
			Joint.Angle, Joint.Velocity = HorseSpringController.Step(Joint.Angle, Joint.Velocity,
				Target, DeltaTime, Spine.Frequency, Spine.Damping)
			-- A small traveling lateral wave lets the rib cage and loin yield independently of the rigid root.
			local Sway = Spine.TrotSway + (Spine.GallopSway + (Spine.RunningSway - Spine.GallopSway) * Sprint - Spine.TrotSway) * Gallop
			local Lateral = math.sin(Phase * math.pi * 2 - Delay * 1.5) * Sway * Moving * Spine.Weights[Joint.Index]
			Joint.Yaw, Joint.YawVelocity = HorseSpringController.Step(Joint.Yaw, Joint.YawVelocity,
				Lateral, DeltaTime, Spine.Frequency, Spine.Damping)
			Joint.Roll, Joint.RollVelocity = HorseSpringController.Step(Joint.Roll, Joint.RollVelocity,
				Lateral * 0.6, DeltaTime, Spine.Frequency, Spine.Damping)
			Angle = Joint.Angle
		elseif Joint.Kind == "Neck" then
			local Delay = Joint.Index * Head.PhaseLag
			local Pulse = math.sin(Phase * math.pi * 4 + 0.5 - Delay) * (1 - Gallop)
				+ math.sin(Phase * math.pi * 2 + 0.5 - Delay) * Gallop
			local Counter = -math.cos((Phase - Running.SuspensionPhase) * math.pi * 2 - Delay)
			Pulse += (Counter - Pulse) * Gallop * Sprint
			local Target = (Pulse * HeadPitch * Head.NeckFraction * Moving
				+ Breath * math.rad(0.15) * (1 - Moving)) * (if Joint.Index == 1 then 1 else 0.65)
			Joint.Angle, Joint.Velocity = HorseSpringController.Step(Joint.Angle, Joint.Velocity,
				Target, DeltaTime, Head.Frequency + (3 - Joint.Index) * 0.5, Head.Damping)
			Angle = Joint.Angle
		elseif Joint.Kind == "Head" then
			local Delay = Head.PhaseLag * 3
			local Pulse = math.sin(Phase * math.pi * 4 + 0.5 - Delay) * (1 - Gallop)
				+ math.sin(Phase * math.pi * 2 + 0.5 - Delay) * Gallop
			local Counter = -math.cos((Phase - Running.SuspensionPhase) * math.pi * 2 - Delay)
			Pulse += (Counter - Pulse) * Gallop * Sprint
			local Target = Pulse * HeadPitch * Moving + math.sin(Time * 0.65) * math.rad(0.3) * (1 - Moving)
			Joint.Angle, Joint.Velocity = HorseSpringController.Step(Joint.Angle, Joint.Velocity,
				Target, DeltaTime, Head.Frequency, Head.Damping)
			Joint.Yaw, Joint.YawVelocity = HorseSpringController.Step(Joint.Yaw, Joint.YawVelocity,
				math.sin(Phase * math.pi * 2 - Delay) * Head.Sway * Moving, DeltaTime, Head.Frequency, Head.Damping)
			Angle = Joint.Angle
		elseif Joint.Kind == "Ear" then
			local Cycle = (Time + Joint.Index * 2.1) % Idle.EarPeriod
			local Flick = if Cycle < 0.7 then math.sin(Cycle / 0.7 * math.pi) ^ 2 else 0
			Angle = (Flick * Idle.EarFlick * (1 - Moving) + Sprint * Moving * math.rad(3))
				* (if Joint.Index == 1 then 1 else -1)
		end
		Joint.Bone.Transform = Joint.Rest * CFrame.fromAxisAngle(Joint.Axis, Angle)
		if Joint.Kind == "Head" or Joint.Kind == "Spine" then
			Joint.Bone.Transform *= CFrame.fromAxisAngle(Joint.YawAxis, Joint.Yaw)
		end
		if Joint.Kind == "Spine" then
			Joint.Bone.Transform *= CFrame.fromAxisAngle(Joint.RollAxis, Joint.Roll)
		end
	end
end

return HorseExpressionController
