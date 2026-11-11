return function(Animator: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage.Shared.HorseConfig)
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseIdlePoseTests"
	Fixture.Parent = workspace
	local Targets = Instance.new("Folder")
	Targets.Parent = Fixture
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(800, 2, 800)
	Floor.Position = Vector3.new(0, 4199, 0)
	Floor.Parent = Fixture
	local ActiveRig: any = nil
	local Checks = 0
	local MaximumIdleBend = 0
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
		Horse:SetAttribute("GroundClearance", Height * 0.5)
		Horse:PivotTo(CFrame.new(0, 4200 + Height * 0.5, 0))
		Horse.Parent = Fixture

		return Horse
	end

	local function Step(Horse: Model, Speed: number, FPS: number)
		Horse:PivotTo(Horse:GetPivot() - Vector3.zAxis * Speed / FPS)
		Animator.Update(ActiveRig, 1 / FPS, 0, 2, true)
	end

	local function CheckIdle(Horse: Model)
		Check(math.abs(ActiveRig.BodyOffset) < 0.02 * ActiveRig.Scale, "Idle restores the body's full standing height")
		for _, Foot in ActiveRig.Feet do
			Check(Foot.Grounded and not Foot.InSwing, "All four hooves support the stopped horse")
			local Local = Horse.PrimaryPart.CFrame:PointToObjectSpace(Foot.Target.WorldPosition) - Foot.Rest.Position
			Check((Local * Vector3.new(1, 0, 1)).Magnitude < Config.Animation.Idle.FootTolerance + 0.03,
				"Idle brings the hoof back beneath its resting leg: " .. Local.Magnitude)
			for _, Joint in Foot.Joints do
				MaximumIdleBend = math.max(MaximumIdleBend, math.abs(Joint.Angle))
				Check(math.abs(Joint.Angle) < math.rad(20), "Idle cannot retain a deep gait bend: " .. Joint.Bone.Name .. " " .. math.deg(Joint.Angle))
			end
		end
	end

	local Success, Error = pcall(function()
		for Tier = 1, 5 do
			local Horse = CreateHorse(Tier)
			ActiveRig = Animator.Create(Horse, Targets)
			for _ = 1, 90 do
				Step(Horse, 0, 60)
			end
			CheckIdle(Horse)
			for _, Speed in { 12, 56 } do
				for _ = 1, 90 + Tier * 3 do
					Step(Horse, Speed, 60)
				end
				for _ = 1, 120 do
					Step(Horse, 0, 60)
				end
				CheckIdle(Horse)
				local Positions = {}
				for Index, Foot in ActiveRig.Feet do
					Positions[Index] = Foot.Hoof.TransformedWorldCFrame.Position
				end
				for _ = 1, 60 do
					Step(Horse, 0, 60)
				end
				for Index, Foot in ActiveRig.Feet do
					Check((Foot.Hoof.TransformedWorldCFrame.Position - Positions[Index]).Magnitude < 0.02,
						"Standing does not keep stepping or changing the knee pose")
				end
			end
			Animator.SetQuality(ActiveRig, 1)
			for _ = 1, 30 do
				Animator.Update(ActiveRig, 1 / 30, 0, 1, false)
			end
			for _, Foot in ActiveRig.Feet do
				for _, Joint in Foot.Joints do
					Check(math.abs(Joint.Angle) < math.rad(1), "Distant idle also restores the relaxed bind pose")
				end
			end
			Animator.Destroy(ActiveRig)
			ActiveRig = nil
			Horse:Destroy()
		end
	end)

	if ActiveRig then
		Animator.Destroy(ActiveRig)
	end
	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorseIdlePose: %d checks passed, maximum idle bend %.1f degrees", Checks, math.deg(MaximumIdleBend))
end
