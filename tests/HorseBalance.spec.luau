return function(Animator: any, Grounding: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseBalanceTests"
	Fixture.Parent = workspace
	local Targets = Instance.new("Folder")
	Targets.Parent = Fixture
	local Origin = Vector3.new(0, 16000, 0)
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(100, 2, 500)
	Floor.Parent = Fixture
	local ActiveRig: any = nil
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local Success, Error = pcall(function()
		for _, Heading in { -Vector3.zAxis, Vector3.xAxis } do
			for _, Angle in { -65, -35, 35, 65 } do
				local Normal = (CFrame.lookAt(Vector3.zero, Heading) * CFrame.Angles(math.rad(20), 0, math.rad(Angle))).UpVector
				for _, Bank in { -math.rad(5), 0, math.rad(5) } do
					local Rotation = Grounding.GetRotation(Heading, Normal, true, Bank)
					local Roll = math.atan2(Rotation.RightVector.Y, Rotation.UpVector.Y)
					Check(math.abs(Roll) <= math.rad(8.01), "Turning and steep support must share the lateral lean limit")
				end
			end
		end

		for _, Tier in { 1, 5 } do
			for _, Angle in { -35, -25, -15, 15, 25, 35 } do
				local Plane = CFrame.new(Origin) * CFrame.Angles(0, 0, math.rad(Angle))
				Floor.CFrame = Plane * CFrame.new(0, -1, 0)
				local Template = ReplicatedStorage.Assets.Models.Horses:FindFirstChild("Horse" .. Tier) :: Model
				local Horse = Template:Clone()
				for _, Part in Horse:QueryDescendants("BasePart") :: { BasePart } do
					Part.Anchored = true
					Part.CanCollide = false
				end
				local Bounds, Size = Horse:GetBoundingBox()
				local Clearance = (math.abs(Bounds.RightVector.Y) * Size.X + math.abs(Bounds.UpVector.Y) * Size.Y
					+ math.abs(Bounds.LookVector.Y) * Size.Z) * 0.5
				local Root = Instance.new("Part")
				Root.Anchored = true
				Root.CanCollide = false
				Root.CFrame = CFrame.new(Bounds.Position)
				Root.Parent = Horse
				Horse.PrimaryPart = Root
				Horse:SetAttribute("GroundClearance", Clearance)
				local Rotation = Grounding.GetRotation(-Vector3.zAxis, Plane.UpVector)
				local Height = Grounding.GetHeight(Origin, Origin, Plane.UpVector, Clearance, Rotation.UpVector)
				Horse:PivotTo(CFrame.new(0, Height, 0) * Rotation)
				Horse.Parent = Fixture
				ActiveRig = Animator.Create(Horse, Targets)
				for Frame = 1, 180 do
					Animator.Update(ActiveRig, 1 / 60, Frame / 60, 2, true)
				end

				local Roll = math.atan2(Root.CFrame.RightVector.Y, Root.CFrame.UpVector.Y)
				Check(math.abs(Roll) > math.rad(1) and math.abs(Roll) <= math.rad(8.01),
					"A side slope keeps a small body lean, including on steep support")
				local Uphill, Downhill = {}, {}
				for _, Foot in ActiveRig.Feet do
					Check(Foot.Grounded and not Foot.InSwing, "All four legs must support the balanced horse")
					local Hoof = Foot.Hoof.TransformedWorldCFrame.Position
					local Gap = (Hoof - Foot.Target.WorldPosition).Magnitude
					Check(Gap < 0.35 * ActiveRig.Scale,
						"Each hoof must reach its own terrain height at " .. Angle .. " degrees: " .. Gap)
					local Hip = Foot.Joints[Foot.SolveRoot].Bone.TransformedWorldCFrame.Position
					local Extension = (Hoof - Hip).Magnitude / Foot.MaximumReach
					local Side = if Foot.Rest.Position.X * Angle > 0 then Uphill else Downhill
					table.insert(Side, Extension)
					for _, Joint in Foot.Joints do
						Check(Joint.Angle >= Joint.Minimum - 0.001 and Joint.Angle <= Joint.Maximum + 0.001,
							"Balancing preserves anatomical joint limits")
					end
				end
				Check((Uphill[1] + Uphill[2]) * 0.5 < (Downhill[1] + Downhill[2]) * 0.5 - 0.015,
					"The uphill legs flex more than the downhill legs")
				local ContactError, ContactSamples = 0, 0
				for Frame = 1, 120 do
					Horse:PivotTo(Horse:GetPivot() - Vector3.zAxis * 16 / 60)
					Animator.Update(ActiveRig, 1 / 60, 3 + Frame / 60, 2, true)
					for _, Foot in ActiveRig.Feet do
						if Frame > 30 and Foot.Grounded and not Foot.InSwing then
							ContactError += (Foot.Hoof.TransformedWorldCFrame.Position - Foot.Target.WorldPosition).Magnitude
							ContactSamples += 1
						end
					end
				end
				Check(ContactSamples > 30 and ContactError / ContactSamples < 0.35 * ActiveRig.Scale,
					"The legs keep reaching their supports while walking across a side slope")
				Animator.Destroy(ActiveRig)
				ActiveRig = nil
				Horse:Destroy()
			end
		end
	end)

	if ActiveRig then
		Animator.Destroy(ActiveRig)
	end
	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorseBalance: %d checks passed", Checks)
end
