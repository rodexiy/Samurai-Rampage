return function(Animator: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage.Shared.HorseConfig)
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseStartupAnimationTests"
	Fixture.Parent = workspace
	local Targets = Instance.new("Folder")
	Targets.Parent = Fixture
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(100, 2, 2000)
	Floor.Position = Vector3.new(0, 25999, -500)
	Floor.Parent = Fixture
	local Active: any = nil
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local Success, Error = pcall(function()
		for Tier, Stats in Config.Tiers do
			for _, FPS in { 30, 60, 120 } do
				for _, PriorTime in { 0, 55 / 60, 113 / 60 } do
					local Horse = (ReplicatedStorage.Assets.Models.Horses:FindFirstChild(Stats.ModelName) :: Model):Clone()
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
					Horse:PivotTo(CFrame.new(0, 26000 + Height * 0.5, 0))
					Horse.Parent = Fixture
					Active = Animator.Create(Horse, Targets)
					local function Step(Speed: number)
						Horse:PivotTo(Horse:GetPivot() - Vector3.zAxis * Speed / FPS)
						Animator.Update(Active, 1 / FPS, 0, 2, true)
					end
					for _ = 1, math.round(PriorTime * FPS) do
						Step(Stats.Speed)
					end
					for _ = 1, FPS * 3 do
						Step(0)
					end
					Check(Active.Resting and not Active.Feet[1].InSwing and not Active.Feet[2].InSwing,
						"Restart tests must begin from settled support")
					local Started, Completed, Folded = {}, {}, { 0, 0 }
					local FirstPair = false
					for Frame = 1, FPS * 1.5 do
						local Before = { Active.Feet[1].InSwing, Active.Feet[2].InSwing }
						Step(math.min(Stats.Speed * Config.Gaits.TrotMultiplier, Stats.Acceleration * Frame / FPS))
						for Index = 1, 2 do
							local Foot = Active.Feet[Index]
							if Foot.InSwing and not Before[Index] and not Started[Index] then
								Started[Index] = Frame / FPS
								Check(Foot.SwingDuration <= Config.Animation.StartStepDuration + 0.001,
									"A first recovery must not last for the unused support phase")
								if not FirstPair then
									Check(Index == 1 and Active.Feet[4].InSwing and not Active.Feet[2].InSwing and not Active.Feet[3].InSwing,
										"Startup must lift one diagonal pair regardless of the phase before stopping")
									FirstPair = true
								end
							end
							if Started[Index] and not Completed[Index] then
								Folded[Index] = math.max(Folded[Index], math.abs(Foot.Joints[4].Angle))
								if not Foot.InSwing and Before[Index] then
									Completed[Index] = Frame / FPS
								end
							end
						end
						if Active.Speed > Config.Animation.MoveThreshold then
							local Separation = (Active.Feet[1].Cycle - Active.Feet[2].Cycle) % 1
							Check(math.abs(Separation - 0.5) < 0.03, "Starting must keep the front legs staggered instead of retiming them together")
						end
					end
					Check(Started[1] and Started[1] <= 0.15, "The first leg must begin stepping promptly")
					for Index = 1, 2 do
						Check(Completed[Index] ~= nil and Completed[Index] - Started[Index] <= Config.Animation.StartStepDuration + 2 / FPS,
							"Each first step must finish before the next long recovery starts")
						Check(Folded[Index] > math.rad(30), "The first front steps must fold naturally instead of remaining straight")
					end
					Animator.Destroy(Active)
					Active = nil
					Horse:Destroy()
				end
			end
		end
	end)

	if Active then
		Animator.Destroy(Active)
	end
	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorseStartupAnimation: %d checks passed", Checks)
end
