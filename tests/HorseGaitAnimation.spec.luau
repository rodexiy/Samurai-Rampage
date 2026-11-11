return function(Animator: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage.Shared.HorseConfig)
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseGaitAnimationTests"
	Fixture.Parent = workspace
	local Targets = Instance.new("Folder")
	Targets.Parent = Fixture
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(100, 2, 2000)
	Floor.Position = Vector3.new(0, 5099, 0)
	Floor.Parent = Fixture
	local Active: any = nil
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local Success, Error = pcall(function()
		for Tier, Stats in Config.Tiers do
			local Template = ReplicatedStorage.Assets.Models.Horses:FindFirstChild(Stats.ModelName) :: Model
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
			Horse:SetAttribute("HorseTier", Tier)
			Horse:PivotTo(CFrame.new(0, 5100 + Height * 0.5, 0))
			Horse.Parent = Fixture
			Active = Animator.Create(Horse, Targets)
			local Frequencies = {}
			for Index, Multiplier in { Config.Gaits.TrotMultiplier, Config.Gaits.GallopMultiplier, 1 } do
				for _ = 1, 150 do
					Horse:PivotTo(Horse:GetPivot() - Vector3.zAxis * Stats.Speed * Multiplier / 60)
					Animator.Update(Active, 1 / 60, 0, 2, true)
				end
				if Index == 1 then
					Check(Active.Gallop < 0.01, "Default movement is a diagonal trot for tier " .. Tier)
				else
					Check(Active.Gallop > 0.99, "Holding Shift and running use the gallop cycle")
				end
				table.insert(Frequencies, Active.Frequency)
			end
			Check(Frequencies[3] > Frequencies[2] + 0.1, "Repeated Shift presses produce a visibly faster running cadence")
			for _ = 1, 150 do
				Horse:PivotTo(Horse:GetPivot() - Vector3.zAxis * Stats.Speed * Config.Gaits.TrotMultiplier / 60)
				Animator.Update(Active, 1 / 60, 0, 2, true)
			end
			Check(Active.Gallop < 0.01, "Slowing down blends the animation back into the trot")
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

	return string.format("HorseGaitAnimation: %d checks passed", Checks)
end
