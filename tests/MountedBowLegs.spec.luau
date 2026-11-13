local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HorseConfig = require(ReplicatedStorage.Shared.HorseConfig)

return function(Controller: any, RiderController: any, RidingClips: { [string]: { [string]: CFrame } },
	BowClips: { [string]: { [string]: CFrame } }): string
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Near(First: CFrame, Second: CFrame): boolean
		return (First.Position - Second.Position).Magnitude < 0.0001
			and (First.RightVector - Second.RightVector).Magnitude < 0.0001
			and (First.UpVector - Second.UpVector).Magnitude < 0.0001
			and (First.LookVector - Second.LookVector).Magnitude < 0.0001
	end

	local Character = Instance.new("Model")
	local Root = Instance.new("Part")
	Root.Parent = Character
	Character.PrimaryPart = Root
	Root.CFrame = CFrame.Angles(0.2, 0.3, -0.15)
	local Humanoid = Instance.new("Humanoid")
	Humanoid.Parent = Character
	local Animator = Instance.new("Animator")
	Animator.Parent = Humanoid
	Character:SetAttribute("Bow", "Bow")
	Character:SetAttribute("BowEquipped", true)
	Character:SetAttribute("InHorse", true)
	local Joints: { Motor6D } = {}
	local function Joint(Rest: CFrame, Offset: CFrame): Motor6D
		local Motor = Instance.new("Motor6D")
		Motor.C0, Motor.C1 = Rest, Offset
		table.insert(Joints, Motor)

		return Motor
	end

	local Rest = CFrame.Angles(-math.pi / 2, 0, math.pi)
	local Waist = Joint(Rest, Rest)
	local RightHip = Joint(CFrame.new(1, -1, 0), CFrame.new(0.5, 1, 0))
	local LeftHip = Joint(CFrame.new(-1, -1, 0), CFrame.new(-0.5, 1, 0))
	local State = Controller.Create(Waist, RightHip, LeftHip)
	local Tracks: any = {}
	local FakeAnimator: any = { GetPlayingAnimationTracks = function(): any
		return Tracks
	end }
	local GetTorsoTransform = RiderController.GetTorsoTransform
	RiderController.GetTorsoTransform = function(_Animator: Animator): CFrame?
		return GetTorsoTransform(FakeAnimator)
	end

	local Success, Error = pcall(function()
		Check(GetTorsoTransform(FakeAnimator) == nil, "Missing riding tracks use the normal pose path")
		for _, Name in { "Idle", "Running" } do
			Check(Near(HorseConfig.RiderAnimations.TorsoTransforms[Name], RidingClips[Name].Torso),
				"Configured torso reference matches the actual riding animation: " .. Name)
		end

		for _, Weight in { 0, 0.25, 0.5, 0.75, 1 } do
			Tracks = {
				{ Animation = { AnimationId = HorseConfig.RiderAnimations.Idle }, WeightCurrent = 1 - Weight },
				{ Animation = { AnimationId = HorseConfig.RiderAnimations.Running }, WeightCurrent = Weight },
				{ Animation = { AnimationId = "unrelated" }, WeightCurrent = 1 },
			}
			local RidingTorso = RidingClips.Idle.Torso:Lerp(RidingClips.Running.Torso, Weight)
			Check(Near(GetTorsoTransform(FakeAnimator), RidingTorso), "Reference follows the actual riding crossfade")
			RightHip.Transform = RidingClips.Idle["Right Leg"]:Lerp(RidingClips.Running["Right Leg"], Weight)
			LeftHip.Transform = RidingClips.Idle["Left Leg"]:Lerp(RidingClips.Running["Left Leg"], Weight)
			local OriginalRight, OriginalLeft = RightHip.Transform, LeftHip.Transform
			local RidingFrame = Root.CFrame * State.WaistRest * RidingTorso * Waist.C1:Inverse()
			local ExpectedRight = RidingFrame * State.RightHipRest * RightHip.Transform * RightHip.C1:Inverse()
			local ExpectedLeft = RidingFrame * State.LeftHipRest * LeftHip.Transform * LeftHip.C1:Inverse()
			for _, Clip in BowClips do
				Waist.Transform = Clip.Torso or CFrame.identity
				for _, Drawing in { true, false } do
					Character:SetAttribute("BowDrawing", Drawing)
					for _, Yaw in { -75, 0, 75 } do
						for _, Pitch in { -60, 0, 60 } do
							local Camera = Root.CFrame * CFrame.Angles(0, math.rad(Yaw), 0) * CFrame.Angles(math.rad(Pitch), 0, 0)
							Check(Controller.UpdateFromCFrame(State, Character, Camera, 10), "Mounted bow pose remains active")
							local Torso = Root.CFrame * Waist.C0 * Waist.Transform * Waist.C1:Inverse()
							Check(Near(Torso * RightHip.C0 * RightHip.Transform * RightHip.C1:Inverse(), ExpectedRight),
								"Right leg retains the horse pose through bow animation and aim changes")
							Check(Near(Torso * LeftHip.C0 * LeftHip.Transform * LeftHip.C1:Inverse(), ExpectedLeft),
								"Left leg retains the horse pose through bow animation and aim changes")
							Check(Near(RightHip.Transform, OriginalRight) and Near(LeftHip.Transform, OriginalLeft),
								"Riding hip animation transforms remain untouched")
						end
					end
				end
			end
		end

		Character:SetAttribute("InHorse", false)
		Controller.UpdateFromCFrame(State, Character, Root.CFrame, 10)
		Check(Near(RightHip.C0, State.RightHipRest) and Near(LeftHip.C0, State.LeftHipRest), "Dismount releases mounted compensation")
		Controller.Reset(State)
		Check(Near(RightHip.C0, State.RightHipRest) and Near(LeftHip.C0, State.LeftHipRest), "Reset restores both hip offsets")
	end)

	RiderController.GetTorsoTransform = GetTorsoTransform
	Controller.Reset(State)
	for _, Motor in Joints do
		Motor:Destroy()
	end
	Character:Destroy()
	assert(Success, tostring(Error))

	return string.format("MountedBowLegs: %d checks passed", Checks)
end
