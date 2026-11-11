return function(Animator: any, Grounding: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseBracingAnimationTests"
	Fixture.Parent = workspace
	local Targets = Instance.new("Folder")
	Targets.Parent = Fixture
	local Origin = Vector3.new(0, 9100, 0)
	local ActiveRig: any = nil
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local Success, Error = pcall(function()
		for _, Tier in { 1, 5 } do
			for _, Angle in { -60, 45, 60, 65 } do
				local Horse = (ReplicatedStorage.Assets.Models.Horses:FindFirstChild("Horse" .. Tier) :: Model):Clone()
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
				Horse:SetAttribute("GroundClearance", Height * 0.5)
				Horse:SetAttribute("GroundHalfWidth", Size.X * 0.3)
				Horse:SetAttribute("GroundHalfLength", Size.Z * 0.26)
				local Vertical = Instance.new("LinearVelocity")
				Vertical.Name = "MountGroundVelocity"
				Vertical.Parent = Root
				local Orientation = Instance.new("AlignOrientation")
				Orientation.Name = "MountOrientation"
				Orientation.Parent = Root
				local Plane = CFrame.new(Origin) * CFrame.Angles(math.rad(Angle), 0, 0)
				local Frame = Grounding.GetRotation(-Vector3.zAxis, Plane.UpVector, true)
				local RootHeight = Grounding.GetHeight(Origin, Origin, Plane.UpVector, Height * 0.5, Frame.UpVector)
				Horse:PivotTo(CFrame.new(0, RootHeight, 0) * Frame)
				Horse.Parent = Fixture
				local State = Grounding.Create(Horse)
				local Patches = {}
				for _, Offset in {
					Vector3.new(-State.HalfWidth, -State.Clearance, -State.HalfLength),
					Vector3.new(State.HalfWidth, -State.Clearance, -State.HalfLength),
					Vector3.new(-State.HalfWidth, -State.Clearance, State.HalfLength),
				} do
					local Point = Root.CFrame:PointToWorldSpace(Offset)
					Point = Vector3.new(Point.X, Grounding.GetHeight(Point, Origin, Plane.UpVector, 0), Point.Z)
					local Patch = Instance.new("Part")
					Patch.Anchored = true
					Patch.Size = Vector3.new(2.6, 0.2, 2.6)
					Patch.CFrame = CFrame.new(Point - Plane.UpVector * 0.1) * Plane.Rotation
					Patch.Parent = Fixture
					table.insert(Patches, Patch)
				end
				ActiveRig = Animator.Create(Horse, Targets)
				for FrameIndex = 1, 180 do
					Grounding.Update(State, 1 / 60)
					Animator.Update(ActiveRig, 1 / 60, FrameIndex / 60, 2, true)
				end
				Check(State.Grounded, "Foot support must keep the real horse above the rock")
				local Contacts = 0
				for _, Foot in ActiveRig.Feet do
					if Foot.Grounded then
						Contacts += 1
						Check((Foot.Hoof.TransformedWorldCFrame.Position - Foot.Target.WorldPosition).Magnitude < 0.45,
							"The actual hoof must reach its brace on a " .. Angle .. " degree rock")
						Check(Foot.Normal:Dot(Plane.UpVector) > 0.999, "The braced hoof must follow the rock's surface")
					end
				end
				Check(Contacts >= 3, "IK must brace at least three hooves when the center sample is missing")
				Animator.Destroy(ActiveRig)
				ActiveRig = nil
				Horse:Destroy()
				for _, Patch in Patches do
					Patch:Destroy()
				end
			end
		end
	end)

	if ActiveRig then
		Animator.Destroy(ActiveRig)
	end
	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorseBracingAnimation: %d checks passed", Checks)
end
