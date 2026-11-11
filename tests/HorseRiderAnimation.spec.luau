return function(Animator: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage.Shared.HorseConfig)
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseRiderAnimationTests"
	Fixture.Parent = workspace
	local Targets = Instance.new("Folder")
	Targets.Parent = Fixture
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(100, 2, 3000)
	Floor.Position = Vector3.new(0, 4699, 0)
	Floor.Parent = Fixture
	local ActiveRig: any = nil
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Near(First: CFrame, Second: CFrame): boolean
		local Difference = First:ToObjectSpace(Second)
		local _, Angle = Difference:ToAxisAngle()

		return Difference.Position.Magnitude < 0.002 and math.abs(Angle) < 0.001
	end

	local function CreateHorse(Tier: number): (Model, Part, Weld)
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
		Horse:PivotTo(CFrame.new(0, 4700 + Height * 0.5, 0))
		Horse:SetAttribute("RiderUserId", 1)
		Horse.Parent = Fixture

		local Rider = Instance.new("Part")
		Rider.Name = "CharacterRoot"
		Rider.CanCollide = false
		Rider.Massless = true
		Rider.CFrame = Root.CFrame * Config.RiderOffset
		Rider.Parent = Fixture
		local Joint = Instance.new("Weld")
		Joint.Name = "RiderWeld"
		Joint.Part0, Joint.Part1 = Root, Rider
		Joint.C0 = Config.RiderOffset
		Joint.Parent = Root

		return Horse, Rider, Joint
	end

	local Success, Error = pcall(function()
		for Tier = 1, 5 do
			local Horse, Rider, Joint = CreateHorse(Tier)
			local Root = Horse.PrimaryPart
			ActiveRig = Animator.Create(Horse, Targets)
			for _, Speed in { 12, 56 } do
				local Lowest, Highest = math.huge, -math.huge
				for Frame = 1, 180 do
					Horse:PivotTo(Horse:GetPivot() - Vector3.zAxis * Speed / 60)
					local Before = Root.CFrame
					Animator.Update(ActiveRig, 1 / 60, 0, 2, true)
					local AnimatedBody = ActiveRig.Body.TransformedWorldCFrame
					local Saddle = AnimatedBody * ActiveRig.BodyRest:Inverse() * Config.RiderOffset
					assert(Near(Root.CFrame * Joint.C0, Saddle), "The rider follows the actual animated body, not only the collider")
					assert(Near(Rider.CFrame, Saddle), "The character's physical root follows the saddle without a delayed frame")
					assert(Near(Root.CFrame, Before), "Animating the saddle cannot reposition the mount root")
					if Frame > 90 then
						Lowest = math.min(Lowest, Joint.C0.Position.Y)
						Highest = math.max(Highest, Joint.C0.Position.Y)
					end
				end
				Check(Highest - Lowest > 0.08, "The rider rises and falls through the gait at speed " .. Speed)
			end

			Root.CFrame *= CFrame.Angles(math.rad(20), 0, math.rad(8))
			Animator.Update(ActiveRig, 1 / 60, 0, 2, true)
			Check(Near(Rider.CFrame, Root.CFrame * ActiveRig.BodyMotion * Config.RiderOffset), "The rider shares saddle pitch and bank")
			Horse:SetAttribute("RiderUserId", nil)
			Animator.Update(ActiveRig, 1 / 60, 0, 2, true)
			Check(Near(Joint.C0, Config.RiderOffset), "Dismount restores the original attachment offset")
			Horse:SetAttribute("RiderUserId", 1)
			Animator.Update(ActiveRig, 1 / 60, 0, 2, true)
			Check(Near(Joint.C0, ActiveRig.BodyMotion * Config.RiderOffset), "Remount does not accumulate the old animation offset")
			Animator.SetQuality(ActiveRig, 0)
			Check(Near(Joint.C0, Config.RiderOffset), "Culling restores both horse and rider")
			Animator.Update(ActiveRig, 1 / 60, 0, 1, false)
			Check(Near(Joint.C0, ActiveRig.BodyMotion * Config.RiderOffset), "Distant riders also follow the locally animated saddle")
			Animator.Destroy(ActiveRig)
			ActiveRig = nil
			Check(Near(Joint.C0, Config.RiderOffset), "Removing the rig releases the visual attachment offset")
			Horse:Destroy()
			Rider:Destroy()
		end
	end)

	if ActiveRig then
		Animator.Destroy(ActiveRig)
	end
	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorseRiderAnimation: %d checks passed", Checks)
end
