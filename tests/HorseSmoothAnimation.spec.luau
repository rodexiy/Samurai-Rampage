return function(Animator: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage.Shared.HorseConfig)
	local OriginalInterval = Config.Animation.FullInterval
	local Origin = Vector3.new(0, 2400, 0)
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseSmoothAnimationTests"
	Fixture.Parent = workspace
	local Targets = Instance.new("Folder")
	Targets.Parent = Fixture
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(500, 2, 500)
	Floor.Position = Origin - Vector3.yAxis
	Floor.Parent = Fixture

	local Checks = 0
	local ActiveRig: any = nil
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function CreateHorse(): Model
		local Horse = ReplicatedStorage.Assets.Models.Horses.Horse1:Clone()
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

	local function Step(Horse: Model, Rig: any, DeltaTime: number)
		Horse:PivotTo(Horse:GetPivot() + Vector3.new(0, 0, -12 * DeltaTime))
		Animator.Update(Rig, DeltaTime, 0, 2, true)
	end

	local Success, Error = pcall(function()
		local Phases = {}
		for _, FPS in { 30, 60, 120 } do
			local Horse = CreateHorse()
			ActiveRig = Animator.Create(Horse, Targets)
			for _ = 1, FPS * 2 do
				Step(Horse, ActiveRig, 1 / FPS)
			end
			table.insert(Phases, ActiveRig.Phase)
			Check(ActiveRig.Smooth and ActiveRig.Quality == 2, "Use full animation quality for the rider")
			Check(math.abs(ActiveRig.Speed - 12) < 0.01, "Animation speed follows travel at " .. FPS .. " FPS")
			Animator.Destroy(ActiveRig)
			ActiveRig = nil
			Horse:Destroy()
		end
		for Index = 2, #Phases do
			local Difference = math.abs((Phases[Index] - Phases[1] + 0.5) % 1 - 0.5)
			Check(Difference < 0.06, "Gait timing remains stable across render rates")
		end

		local Horse = CreateHorse()
		ActiveRig = Animator.Create(Horse, Targets)
		local Swing: any = nil
		for _ = 1, 240 do
			Step(Horse, ActiveRig, 1 / 120)
			for _, Foot in ActiveRig.Feet do
				if Foot.InSwing and Foot.SwingAlpha > 0.2 and Foot.SwingAlpha < 0.6 then
					Swing = Foot
					break
				end
			end
			if Swing then
				break
			end
		end
		Check(Swing ~= nil, "Find an airborne hoof in the trot")
		local CachedHit = Swing.GroundHit
		Check(CachedHit ~= nil, "The foot has a sampled ground plane")
		Config.Animation.FullInterval = 10
		for _ = 1, 4 do
			local Before = Swing.Target.WorldPosition
			Step(Horse, ActiveRig, 1 / 120)
			Check((Swing.Target.WorldPosition - Before).Magnitude > 0.001, "The foot moves on each render frame between ground probes")
			Check(Swing.GroundHit == CachedHit, "Smooth playback reuses the ground query instead of raycasting every render frame")
		end

		Floor.CFrame += Vector3.yAxis * 0.25
		Step(Horse, ActiveRig, 1 / 120)
		Check(Swing.GroundHit == CachedHit, "A moving support does not force extra probes")
		Check(math.abs(Swing.SwingGoal.Y - Origin.Y - 0.25 - Config.Animation.HoofClearance * ActiveRig.Scale) < 0.001,
			"Cached ground follows the moving support during swing")
		for _, Foot in ActiveRig.Feet do
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
				Check(Offset.Position.Magnitude < (if Compensated then 0.002 else 0.0001)
					and (Angle < 0.001 or math.abs(Axis:Dot(Joint.Axis)) > 0.999),
					"Render smoothing preserves anatomical hinges")
			end
		end

		Floor:Destroy()
		Step(Horse, ActiveRig, 1 / 120)
		Check(not Swing.Grounded, "A removed support releases the foot before the next scheduled probe")
		Config.Animation.FullInterval = OriginalInterval
		local Before = ActiveRig.Phase
		Animator.Update(ActiveRig, 1 / 120, 0, 2, false)
		Check(not ActiveRig.Smooth and (ActiveRig.Phase - Before) % 1 <= Config.Animation.MaximumFrequency / 120 + 0.001,
			"Dismount hands playback back without advancing the gait twice")
	end)

	Config.Animation.FullInterval = OriginalInterval
	if ActiveRig then
		Animator.Destroy(ActiveRig)
	end
	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorseSmoothAnimation: %d checks passed", Checks)
end
