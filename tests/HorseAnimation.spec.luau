-- Run on a Studio client with HorseAnimationController.HorseRigController.
return function(Animator: any): string
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local Origin = Players.LocalPlayer.Character.PrimaryPart.Position + Vector3.new(20, 25, 0)
	local Fixtures = Instance.new("Folder")
	Fixtures.Name = "HorseAnimationTests"
	Fixtures.Parent = workspace
	local Targets = Instance.new("Folder")
	Targets.Parent = Fixtures
	local Platform = Instance.new("Part")
	Platform.Anchored = true
	Platform.Size = Vector3.new(400, 2, 400)
	Platform.CFrame = CFrame.new(Origin - Vector3.yAxis)
	Platform.Parent = Fixtures

	local Checks = 0
	local ActiveRig: any = nil
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Advance(Duration: number, Quality: number, Move: ((number) -> ())?)
		local Done = Instance.new("BindableEvent")
		local Elapsed = 0
		local Failure: string? = nil
		local Connection: RBXScriptConnection
		Connection = RunService.PreSimulation:Connect(function(DeltaTime: number)
			local Success, Error = pcall(function()
				if Move then
					Move(DeltaTime)
				end
				Animator.Update(ActiveRig, DeltaTime, workspace:GetServerTimeNow(), Quality)
			end)
			if not Success then
				Failure = tostring(Error)
			end
			Elapsed += DeltaTime
			if Failure or Elapsed >= Duration then
				Connection:Disconnect()
				RunService.PostSimulation:Once(function()
					Done:Fire()
				end)
			end
		end)
		Done.Event:Wait()
		Done:Destroy()
		assert(not Failure, tostring(Failure))
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
		Horse:PivotTo(CFrame.new(Origin + Vector3.yAxis * (Height * 0.5)))
		Horse.Parent = Fixtures

		return Horse
	end

	local Success, Error = pcall(function()
		for Tier = 1, 5 do
			local Horse = CreateHorse(Tier)
			ActiveRig = Animator.Create(Horse, Targets)
			Check(ActiveRig ~= nil and #ActiveRig.Feet == 4, "Build the four leg chains for tier " .. Tier)
			Advance(0.3, 2, nil)
			for _, Foot in ActiveRig.Feet do
				Check(Foot.Grounded, "Each hoof finds the ground")
				local Difference = (Foot.Hoof.TransformedWorldCFrame.Position - Foot.Target.WorldPosition).Magnitude
				Check(Difference < 0.15, "Constrained IK reaches the planted hoof target: " .. Difference)
			end
			Animator.Destroy(ActiveRig)
			ActiveRig = nil
			Horse:Destroy()
		end

		local Horse = CreateHorse(1)
		ActiveRig = Animator.Create(Horse, Targets)
		Advance(0.3, 2, nil)
		local Foot = ActiveRig.Feet[1]
		local Planted = Foot.Target.WorldPosition
		Horse:PivotTo(Horse:GetPivot() + Vector3.new(0.1, 0, 0))
		Advance(1 / 60, 2, nil)
		Check((Foot.Target.WorldPosition - Planted).Magnitude < 0.01, "A stance hoof stays fixed while the body moves")

		Platform.CFrame += Vector3.new(0.2, 0, 0)
		Horse:PivotTo(Horse:GetPivot() + Vector3.new(0.2, 0, 0))
		Advance(1 / 60, 2, nil)
		Check((Foot.Target.WorldPosition - Planted - Vector3.new(0.2, 0, 0)).Magnitude < 0.01,
			"A planted hoof follows its moving support")

		local FlatFrame = Platform.CFrame
		Platform.CFrame *= CFrame.Angles(math.rad(8), 0, math.rad(4))
		Advance(0.3, 2, nil)
		Check(ActiveRig.Normal.Y < 0.999, "The body follows the ground slope")
		for _, Leg in ActiveRig.Feet do
			Check(Leg.Normal:Dot(Platform.CFrame.UpVector) > 0.999, "Hoof orientation follows the support normal")
		end
		Platform.CFrame = FlatFrame
		Advance(0.2, 2, nil)

		local MaximumLift = 0
		local MaximumSlide = 0
		local MinimumForward = table.create(4, math.huge)
		local MaximumForward = table.create(4, -math.huge)
		local MinimumHip = table.create(4, math.huge)
		local MaximumHip = table.create(4, -math.huge)
		local StanceSamples = 0
		local PreviousTarget: Vector3? = nil
		local PreviousStance = false
		Advance(1.5, 2, function(DeltaTime: number)
			local Actual = Foot.Hoof.TransformedWorldCFrame.Position
			MaximumLift = math.max(MaximumLift, Actual.Y - Origin.Y)
			local Stance = Foot.Grounded and not Foot.InSwing
			if Stance and PreviousStance and PreviousTarget then
				MaximumSlide = math.max(MaximumSlide, (Actual - PreviousTarget).Magnitude)
				StanceSamples += 1
			end
			PreviousTarget = Actual
			PreviousStance = Stance
			for Index, Leg in ActiveRig.Feet do
				local Forward = -Horse.PrimaryPart.CFrame:PointToObjectSpace(Leg.Hoof.TransformedWorldCFrame.Position).Z
				MinimumForward[Index] = math.min(MinimumForward[Index], Forward)
				MaximumForward[Index] = math.max(MaximumForward[Index], Forward)
				MinimumHip[Index] = math.min(MinimumHip[Index], Leg.Joints[Leg.SolveRoot].Angle)
				MaximumHip[Index] = math.max(MaximumHip[Index], Leg.Joints[Leg.SolveRoot].Angle)
				for JointIndex, Joint in Leg.Joints do
					local Offset = Joint.Rest:ToObjectSpace(Joint.Bone.Transform)
					local Compensated = Leg.Front and JointIndex == 2
					if Compensated then
						local Anchor = Leg.Joints[1]
						local Parent = Anchor.Bone.Parent :: Bone
						local Neutral = Parent.TransformedWorldCFrame * Anchor.Bone.CFrame * Anchor.Rest * Joint.Bone.CFrame * Joint.Rest
						Offset = Neutral:ToObjectSpace(Joint.Bone.TransformedWorldCFrame)
					end
					local Axis, Angle = Offset:ToAxisAngle()
					assert(Offset.Position.Magnitude < (if Compensated then 0.002 else 0.0001), "Leg bones must never translate or stretch")
					assert(Angle < 0.001 or math.abs(Axis:Dot(Joint.Axis)) > 0.999, "Leg bones must stay on their bind-pose hinge")
					assert(Joint.Angle >= Joint.Minimum - 0.001 and Joint.Angle <= Joint.Maximum + 0.001, "Respect anatomical bend limits")
				end
			end
			Horse:PivotTo(Horse:GetPivot() + Vector3.new(0, 0, -12 * DeltaTime))
		end)
		Check(MaximumLift > 0.5, "Swinging hooves lift clear of the floor")
		Check(StanceSamples > 5 and MaximumSlide < 0.12, "Actual supporting hooves do not slide through the trot: " .. MaximumSlide)
		for Index = 1, 4 do
			Check(MaximumForward[Index] - MinimumForward[Index] > 2.4, "The actual hoof advances and recedes through a full stride")
			Check(MaximumHip[Index] - MinimumHip[Index] > math.rad(12), "The shoulder/hip swings with the stride")
		end
		Check(ActiveRig.Feet[1].Phase == ActiveRig.Feet[4].Phase
			and ActiveRig.Feet[2].Phase == ActiveRig.Feet[3].Phase, "Trot uses diagonal pairs")

		for _, Speed in { 32, 56 } do
			local Low = math.huge
			local High = -math.huge
			local WorstError = 0
			Advance(1, 2, function(DeltaTime: number)
				local Actual = Foot.Hoof.TransformedWorldCFrame.Position
				local Forward = -(Horse.PrimaryPart.CFrame:PointToObjectSpace(Actual).Z - Foot.Rest.Position.Z)
				Low = math.min(Low, Forward)
				High = math.max(High, Forward)
				if Foot.Grounded and not Foot.InSwing then
					WorstError = math.max(WorstError, (Actual - Foot.Target.WorldPosition).Magnitude)
				end
				Horse:PivotTo(Horse:GetPivot() + Vector3.new(0, 0, -Speed * DeltaTime))
			end)
			Check(High - Low > 2.4, "The actual stride remains visible at speed " .. Speed)
			Check(WorstError < 0.45, "Supporting feet remain planted at speed " .. Speed .. ": " .. WorstError)
		end

		Advance(0.8, 2, nil)
		for _, Leg in ActiveRig.Feet do
			Check(not Leg.InSwing and Leg.Grounded, "Stopping finishes the step and plants all four hooves")
		end

		Horse:PivotTo(Horse:GetPivot() + Vector3.yAxis * 20)
		Advance(0.2, 2, nil)
		for _, Leg in ActiveRig.Feet do
			Check(not Leg.Grounded and Leg.Plant == nil, "Airborne legs release their ground anchors")
		end
		Horse:PivotTo(Horse:GetPivot() - Vector3.yAxis * 20)
		Advance(0.2, 2, nil)
		for _, Leg in ActiveRig.Feet do
			Check(Leg.Grounded, "Landing restores ground contact")
		end

		Advance(0.1, 1, nil)
		for _, Leg in ActiveRig.Feet do
			Check(not Leg.SolverEnabled, "Distant animation disables foot IK")
		end
		Animator.SetQuality(ActiveRig, 0)
		for _, Pose in ActiveRig.Poses do
			Check(Pose.Bone.Transform == Pose.Transform, "Culling restores the original pose")
		end

		local TargetPart = ActiveRig.Targets
		Animator.Destroy(ActiveRig)
		ActiveRig = nil
		Check(TargetPart.Parent == nil, "Removing a horse cleans up its world targets")
		Check(#Horse:QueryDescendants("IKControl") == 0, "Removing a horse cleans up its IK controls")
		Horse:Destroy()
	end)

	if ActiveRig then
		Animator.Destroy(ActiveRig)
	end
	Fixtures:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorseAnimation: %d checks passed", Checks)
end
