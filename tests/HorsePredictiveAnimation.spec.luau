-- Real imported meshes: anticipate a step without moving planted feet or extending the stride.
return function(Animator: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage.Shared.HorseConfig)
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorsePredictiveAnimationTests"
	Fixture.Parent = workspace
	local Targets = Instance.new("Folder")
	Targets.Parent = Fixture
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(100, 2, 1000)
	Floor.Position = Vector3.new(0, 3999, 0)
	Floor.Parent = Fixture
	local Step = Instance.new("Part")
	Step.Anchored = true
	Step.Size = Vector3.new(12, 1.2, 6)
	Step.Parent = Fixture
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
		Horse:PivotTo(CFrame.new(0, 4000 + Height * 0.5, 0))
		Horse.Parent = Fixture

		return Horse
	end

	local function Advance(Horse: Model)
		Horse:PivotTo(Horse:GetPivot() - Vector3.zAxis * 12 / 120)
		Animator.Update(ActiveRig, 1 / 120, 0, 2, true)
	end

	local Success, Error = pcall(function()
		for Tier = 1, 5 do
			Step.CanCollide = false
			local Horse = CreateHorse(Tier)
			ActiveRig = Animator.Create(Horse, Targets)
			for _ = 1, 120 do
				Advance(Horse)
			end
			local Edge = Horse.PrimaryPart.Position.Z - 8
			Step.Position = Vector3.new(0, 4000.6, Edge - 3)
			Step.CanCollide = true
			local EarlySamples, EarlyGoalHeight, EarlyPitch, StanceSamples = 0, 0, 0, 0
			local CachedSamples = 0
			local PreviousTargets: { [any]: Vector3 } = {}
			local PreviousStance: { [any]: boolean } = {}
			local PreviousForecast: { [any]: CFrame } = {}
			for _ = 1, 120 do
				Advance(Horse)
				for _, Foot in ActiveRig.Feet do
					local Rest = Horse.PrimaryPart.CFrame:PointToWorldSpace(Foot.Rest.Position)
					if Foot.Front and Foot.Prediction.Hit and Foot.Prediction.Hit.Instance == Step
						and Foot.GroundHit and Foot.GroundHit.Instance == Floor and Rest.Z > Edge + 0.5 then
						EarlySamples += 1
						EarlyPitch = math.max(EarlyPitch, ActiveRig.Prediction.BodyPitch)
						if Foot.InSwing then
							EarlyGoalHeight = math.max(EarlyGoalHeight, Foot.SwingGoal.Y - 4000)
						end
						if PreviousForecast[Foot] == Foot.Prediction.FutureFrame then
							CachedSamples += 1
						end
					end
					local Stance = Foot.Grounded and not Foot.InSwing
					if Stance and PreviousStance[Foot] and PreviousTargets[Foot] then
						Check((Foot.Target.WorldPosition - PreviousTargets[Foot]).Magnitude < 0.01,
							"Anticipation cannot move a hoof that is planted on the current floor")
						StanceSamples += 1
					end
					PreviousTargets[Foot], PreviousStance[Foot] = Foot.Target.WorldPosition, Stance
					PreviousForecast[Foot] = Foot.Prediction.FutureFrame
					for JointIndex, Joint in Foot.Joints do
						local Offset = Joint.Rest:ToObjectSpace(Joint.Bone.Transform)
						local Compensated = Foot.Front and JointIndex == 2
						if Compensated then
							local Anchor = Foot.Joints[1]
							local Parent = Anchor.Bone.Parent :: Bone
							local Neutral = Parent.TransformedWorldCFrame * Anchor.Bone.CFrame * Anchor.Rest * Joint.Bone.CFrame * Joint.Rest
							Offset = Neutral:ToObjectSpace(Joint.Bone.TransformedWorldCFrame)
						end
						local Axis, Angle = Offset:ToAxisAngle()
						assert(Offset.Position.Magnitude < (if Compensated then 0.002 else 0.0001)
							and (Angle < 0.001 or math.abs(Axis:Dot(Joint.Axis)) > 0.999),
							"Terrain anticipation preserves the mesh's anatomical hinges")
					end
				end
			end
			Check(EarlySamples > 3 and EarlyGoalHeight > 0.2, "Prepare the actual front legs before the step on tier " .. Tier)
			Check(EarlyPitch > math.rad(0.1), "Prepare the visual body while its current support is still flat")
			Check(StanceSamples > 5 and CachedSamples > 2, "Keep planted contacts and reuse predictions between render frames")
			Animator.SetQuality(ActiveRig, 1)
			Animator.Update(ActiveRig, 1 / 15, 0, 1, false)
			for _, Foot in ActiveRig.Feet do
				Check(Foot.Prediction.Hit == nil, "Distant horses do not perform terrain prediction")
			end
			Animator.Destroy(ActiveRig)
			ActiveRig = nil
			Horse:Destroy()
		end
		Check(Config.Animation.Prediction.Enabled, "Terrain prediction is enabled by default")
	end)

	if ActiveRig then
		Animator.Destroy(ActiveRig)
	end
	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorsePredictiveAnimation: %d checks passed", Checks)
end
