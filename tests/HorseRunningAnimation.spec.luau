-- Deterministic playback on the real imported rigs; accepts HorseRigController.
return function(Animator: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage.Shared.HorseConfig)
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseRunningAnimationTests"
	Fixture.Parent = workspace
	local Targets = Instance.new("Folder")
	Targets.Parent = Fixture
	local Origin = Vector3.new(0, 3200, 0)
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(100, 2, 3000)
	Floor.Position = Origin - Vector3.yAxis
	Floor.Parent = Fixture
	local ActiveRig: any = nil
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function CreateHorse(Tier: number): Model
		local Template = ReplicatedStorage.Assets.Models.Horses:FindFirstChild("Horse" .. Tier) :: Model
		local Horse = Template:Clone()
		for _, Part in Horse:QueryDescendants("BasePart") :: { BasePart } do
			Part.Anchored = true
			Part.CanCollide = false
		end
		local Bounds, Size = Horse:GetBoundingBox()
		local Height = math.abs(Bounds.RightVector.Y) * Size.X + math.abs(Bounds.UpVector.Y) * Size.Y
			+ math.abs(Bounds.LookVector.Y) * Size.Z
		local Root = Instance.new("Part")
		Root.Anchored = true
		Root.CanCollide = false
		Root.Transparency = 1
		Root.CFrame = CFrame.new(Bounds.Position)
		Root.Parent = Horse
		Horse.PrimaryPart = Root
		Horse:PivotTo(CFrame.new(Origin + Vector3.yAxis * Height * 0.5))
		Horse.Parent = Fixture

		return Horse
	end

	local function Step(Horse: Model, Speed: number, DeltaTime: number, Quality: number)
		Horse:PivotTo(Horse:GetPivot() - Vector3.zAxis * Speed * DeltaTime)
		Animator.Update(ActiveRig, DeltaTime, 0, Quality, true)
	end

	local Success, Error = pcall(function()
		for Tier = 1, 5 do
			local Horse = CreateHorse(Tier)
			ActiveRig = Animator.Create(Horse, Targets)
			for _ = 1, 120 do
				Step(Horse, 12, 1 / 60, 2)
			end
			Check(ActiveRig.Gallop < 0.01, "Slow travel keeps the diagonal trot")
			local TrotFrequency = ActiveRig.Frequency
			local PreviousWeight = ActiveRig.Gallop
			local MaximumWeightStep = 0
			local MaximumCycleStep = 0
			local AirSamples = 0
			local MaximumLift = 0
			local PreviousAngles: { [any]: number } = {}
			local MaximumRunningAngleStep = 0
			local MaximumGoalReach, MaximumTargetReach, MaximumHipSpeed = 0, 0, 0
			local MinimumSwingDuration = math.huge
			local PreviousTargets: { [any]: Vector3 } = {}
			local LiftOffSamples, MaximumLiftOffJump = 0, 0
			local Low, High = math.huge, -math.huge
			for Frame = 1, 300 do
				local PreviousCycles = {}
				for Index, Foot in ActiveRig.Feet do
					PreviousCycles[Index] = Foot.Cycle
				end
				Step(Horse, math.min(56, 12 + Frame * 40 / 60), 1 / 60, 2)
				MaximumWeightStep = math.max(MaximumWeightStep, math.abs(ActiveRig.Gallop - PreviousWeight))
				PreviousWeight = ActiveRig.Gallop
				local AllSwing = true
				for Index, Foot in ActiveRig.Feet do
					MaximumCycleStep = math.max(MaximumCycleStep, (Foot.Cycle - PreviousCycles[Index]) % 1)
					AllSwing = AllSwing and Foot.InSwing
					if Foot.InSwing then
						MinimumSwingDuration = math.min(MinimumSwingDuration, Foot.SwingDuration)
						local Goal = -Horse.PrimaryPart.CFrame:VectorToObjectSpace(Foot.SwingGoal
							- Horse.PrimaryPart.CFrame:PointToWorldSpace(Foot.Rest.Position)).Z
						MaximumGoalReach = math.max(MaximumGoalReach, Goal / ActiveRig.Scale)
						if Foot.SwingAlpha == 0 and PreviousTargets[Foot] then
							LiftOffSamples += 1
							MaximumLiftOffJump = math.max(MaximumLiftOffJump, (Foot.Target.WorldPosition - PreviousTargets[Foot]).Magnitude)
						end
					end
					PreviousTargets[Foot] = Foot.Target.WorldPosition
					if Frame > 180 then
						local Position = Foot.Hoof.TransformedWorldCFrame.Position
						local Target = Horse.PrimaryPart.CFrame:PointToObjectSpace(Foot.Target.WorldPosition)
						MaximumTargetReach = math.max(MaximumTargetReach, (Foot.Rest.Position.Z - Target.Z) / ActiveRig.Scale)
						MaximumLift = math.max(MaximumLift, Position.Y - Origin.Y)
						if Index == 1 then
							local Forward = -Horse.PrimaryPart.CFrame:PointToObjectSpace(Position).Z
							Low = math.min(Low, Forward)
							High = math.max(High, Forward)
						end
					end
					for JointIndex, Joint in Foot.Joints do
						local Previous = PreviousAngles[Joint]
						if Previous and JointIndex == 1 then
							MaximumHipSpeed = math.max(MaximumHipSpeed, math.abs(Joint.Angle - Previous) * 60)
						end
						if Previous and Frame > 180 then
							MaximumRunningAngleStep = math.max(MaximumRunningAngleStep, math.abs(Joint.Angle - Previous))
						end
						PreviousAngles[Joint] = Joint.Angle
						local Offset = Joint.Rest:ToObjectSpace(Joint.Bone.Transform)
						local Axis, Angle = Offset:ToAxisAngle()
						assert(Offset.Position.Magnitude < 0.0001, "Running never stretches the bones")
						assert(Angle < 0.001 or math.abs(Axis:Dot(Joint.Axis)) > 0.999, "Running preserves anatomical hinge axes")
						assert(Joint.Angle >= Joint.Minimum - 0.001 and Joint.Angle <= Joint.Maximum + 0.001,
							"Running preserves joint limits")
					end
				end
				if Frame > 180 and AllSwing then
					AirSamples += 1
				end
			end
			Check(ActiveRig.Gallop > 0.99, "High speed completes the running transition on tier " .. Tier)
			Check(MaximumWeightStep < 0.09 and MaximumCycleStep < 0.1, "Blend weights and leg cycles stay continuous")
			Check(MaximumGoalReach <= Config.Animation.MaximumForwardReach + 0.02,
				"Do not predict a landing several body lengths ahead: " .. MaximumGoalReach)
			Check(MaximumTargetReach <= math.max(Config.Animation.MaximumForwardReach, Config.Animation.FrontLeg.MaximumForwardReach) + 0.02,
				"The swing does not overshoot the anatomical reach: " .. MaximumTargetReach)
			Check(MinimumSwingDuration >= Config.Animation.MinimumSwingDuration,
				"A gait transition cannot rush a leg through a tiny swing duration")
			Check(MaximumHipSpeed <= Config.Animation.MaximumHipSpeed + 0.001,
				"The shoulder and hip advance at a controlled angular speed")
			Check(LiftOffSamples > 5 and MaximumLiftOffJump < 0.01, "Lifting a hoof does not teleport its target")
			Check(MaximumRunningAngleStep <= Config.Animation.Running.MaximumJointSpeed / 60 + 0.001,
				"Running bones cannot snap between IK solutions")
			Check(ActiveRig.Frequency > TrotFrequency and ActiveRig.Frequency <= Config.Animation.Running.MaximumFrequency + 0.001,
				"Running uses a longer stride instead of accelerating the trot")
			for _, Foot in ActiveRig.Feet do
				local Difference = math.abs((Foot.Cycle - ActiveRig.Phase - Foot.RunPhase + 0.5) % 1 - 0.5)
				Check(Difference < 0.02, "Each leg converges to the four-beat running order")
			end
			Check(AirSamples > 0, "The gallop has a suspension phase")
			Check(MaximumLift > 1 and High - Low > 3.5, "Running lifts and extends the actual hooves: " .. MaximumLift .. ", " .. (High - Low))

			for _ = 1, 180 do
				Step(Horse, 12, 1 / 60, 2)
			end
			Check(ActiveRig.Gallop < 0.01, "Slowing down returns smoothly to the trot")
			for _ = 1, 120 do
				Step(Horse, 0, 1 / 60, 2)
			end
			for _, Foot in ActiveRig.Feet do
				Check(Foot.Grounded and not Foot.InSwing, "Stopping settles all hooves")
			end
			for _ = 1, 180 do
				Step(Horse, 32, 1 / 60, 1)
			end
			Check(ActiveRig.Gallop > 0.99 and not ActiveRig.Feet[1].SolverEnabled,
				"Distant horses retain the running gait without enabling IK")
			Animator.Destroy(ActiveRig)
			ActiveRig = nil
			Horse:Destroy()
		end

		local Phases = {}
		for _, FPS in { 30, 60, 120 } do
			local Horse = CreateHorse(1)
			ActiveRig = Animator.Create(Horse, Targets)
			for _ = 1, FPS * 4 do
				Step(Horse, 56, 1 / FPS, 2)
			end
			Check(ActiveRig.Gallop > 0.99, "Running blend completes at " .. FPS .. " FPS")
			table.insert(Phases, ActiveRig.Phase)
			Animator.Destroy(ActiveRig)
			ActiveRig = nil
			Horse:Destroy()
		end
		for Index = 2, #Phases do
			local Difference = math.abs((Phases[Index] - Phases[1] + 0.5) % 1 - 0.5)
			Check(Difference < 0.1, "Running timing stays consistent across render rates: " .. Difference)
		end
	end)

	if ActiveRig then
		Animator.Destroy(ActiveRig)
	end
	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorseRunningAnimation: %d checks passed", Checks)
end
