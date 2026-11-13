return function(Animator: any, Tail: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage.Shared.HorseConfig)
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseSecondaryMotionTests"
	Fixture.Parent = workspace
	local Targets = Instance.new("Folder")
	Targets.Parent = Fixture
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(400, 2, 400)
	Floor.Position = Vector3.new(0, 4899, 0)
	Floor.Parent = Fixture
	local Active: any = nil
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
		Horse:SetAttribute("GaitEpoch", 0)
		Horse:PivotTo(CFrame.new(0, 4900 + Height * 0.5, 0))
		Horse.Parent = Fixture

		return Horse
	end

	local Success, Error = pcall(function()
		for Tier = 1, 5 do
			local Horse = CreateHorse(Tier)
			local TailPoses: { [Bone]: CFrame } = {}
			if not Config.Animation.Tail.Enabled then
				for _, Bone in Horse:QueryDescendants("Bone") :: { Bone } do
					if Bone.Name:match("^SK_tail") then
						Bone.Transform = CFrame.Angles(0.04 * Tier, -0.03, 0.02)
						TailPoses[Bone] = Bone.Transform
					end
				end
			end
			Active = Animator.Create(Horse, Targets)
			Check(#Active.TailMotion.Segments == (if Config.Animation.Tail.Enabled then 6 else 0),
				"Disabled tail motion must not take control of the tail bones")
			Horse:SetAttribute("RiderUserId", 1)
			for _ = 1, 120 do
				Animator.Update(Active, 1 / 60, 0, 2, true, Vector3.new(1, 0.5, -1).Unit)
			end
			Check(Active.NeckYaw < -math.rad(30) and Active.LookPitch > math.rad(10), "A stationary rider can look right and up")
			Check(math.abs(Active.NeckYaw) <= Config.Animation.RiderLook.MaximumYaw + 0.001,
				"Camera look cannot twist the neck beyond its anatomical limit")
			Horse:SetAttribute("RiderLookDirection", Vector3.new(-1, -0.5, -1).Unit)
			Horse:SetAttribute("RiderLookTime", 0)
			for _ = 1, 120 do
				Animator.Update(Active, 1 / 60, 0, 2, false)
			end
			Check(Active.NeckYaw > math.rad(30) and Active.LookPitch < -math.rad(10), "Other clients reproduce the replicated rider gaze")
			for _ = 1, 120 do
				Animator.Update(Active, 1 / 60, 3, 2, false)
			end
			Check(math.abs(Active.NeckYaw) < 0.001 and math.abs(Active.LookPitch) < 0.001, "Expired gaze returns the neck to center")
			for _ = 1, 120 do
				Horse:PivotTo(Horse:GetPivot() - Vector3.zAxis * 12 / 60)
				Animator.Update(Active, 1 / 60, 3, 2, true, Vector3.xAxis)
			end
			Check(math.abs(Active.NeckYaw) < math.rad(1), "Camera look yields to movement while the horse is walking")

			local Motion = Active.TailMotion
			if not Config.Animation.Tail.Enabled then
				for _, Quality in { 1, 0, 2 } do
					Animator.SetQuality(Active, Quality)
					Animator.Update(Active, 1 / 60, 4, Quality, true)
					Tail.Reset(Motion)
					Tail.Update(Motion, CFrame.identity, -Vector3.zAxis * 80, 1.5, 0.5, 4, 1 / 60)
					for Bone, Pose in TailPoses do
						Check(Bone.Transform == Pose, "Animation, resets and culling must leave disabled tail transforms untouched")
					end
				end
				Animator.Destroy(Active)
				Active = nil
				for Bone, Pose in TailPoses do
					Check(Bone.Transform == Pose, "Removing the rig must not overwrite an externally posed tail")
				end
				Horse:Destroy()
				continue
			end
			local Tip = Motion.Segments[6].Bone
			for _, Moving in { false, true } do
				Tail.Reset(Motion)
				local Minimum, Maximum = math.huge, -math.huge
				for Frame = 1, 360 do
					local Time = Frame / 60
					Tail.Update(Motion, Horse.PrimaryPart.CFrame,
						if Moving then Horse.PrimaryPart.CFrame.LookVector * 32 else Vector3.zero,
						0, Time * 2.8 % 1, Time, 1 / 60)
					local Lateral = Horse.PrimaryPart.CFrame:PointToObjectSpace(Tip.TransformedWorldCFrame.Position).X
					Minimum = math.min(Minimum, Lateral)
					Maximum = math.max(Maximum, Lateral)
				end
				Check(Maximum - Minimum > 0.35 * Active.Scale,
					"The actual tail tip visibly sways sideways, rather than only spinning in place: " .. (Maximum - Minimum))
			end
			Tail.Reset(Motion)
			for _ = 1, 120 do
				Tail.Update(Motion, CFrame.identity, -Vector3.zAxis * 32, -1.5, 0, 2, 1 / 60)
			end
			local Turn = 0
			local Lift = 0
			for _, Segment in Motion.Segments do
				Turn += Segment.Yaw.Position
				Lift += Segment.Pitch.Position
				local Delta = Segment.Rest:ToObjectSpace(Segment.Bone.Transform)
				Check(Delta.Position.Magnitude < 0.0001, "Tail motion never translates or stretches a bone")
			end
			Check(Turn < -0.05 and Lift < -0.05, "Running and turning trail and lift the tail")
			for _ = 1, 120 do
				Tail.Update(Motion, CFrame.identity, -Vector3.zAxis * 32, 1.5, 0, 2, 1 / 60)
			end
			local Opposite = 0
			for _, Segment in Motion.Segments do
				Opposite += Segment.Yaw.Position
			end
			Check(Opposite > 0.05, "Tail inertia reverses with the turn")
			local Profiles = {}
			for _, FPS in { 30, 60, 120 } do
				Tail.Reset(Motion)
				for _ = 1, FPS * 2 do
					Tail.Update(Motion, CFrame.identity, -Vector3.zAxis * 32, 1, 0.2, 2, 1 / FPS)
				end
				table.insert(Profiles, Motion.Segments[6].Yaw.Position)
			end
			Check(math.abs(Profiles[1] - Profiles[3]) < 0.001, "Tail damping is independent of frame rate")
			Tail.Reset(Motion)
			for _, Segment in Motion.Segments do
				Check(Segment.Bone.Transform == Segment.Rest, "Culling restores every tail segment")
			end
			Animator.Destroy(Active)
			Active = nil
			Horse:Destroy()
		end
	end)

	if Active then
		Animator.Destroy(Active)
	end
	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorseSecondaryMotion: %d checks passed", Checks)
end
