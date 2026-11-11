return function(Animator: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage.Shared.HorseConfig)
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseTurningAnimationTests"
	Fixture.Parent = workspace
	local Targets = Instance.new("Folder")
	Targets.Parent = Fixture
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(500, 2, 500)
	Floor.Position = Vector3.new(0, 6499, 0)
	Floor.Parent = Fixture
	local ActiveRig: any = nil
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local Success, Error = pcall(function()
		for _, Tier in { 1, 5 } do
			for _, FPS in { 30, 60, 120 } do
				for _, Multiplier in { Config.Gaits.TrotMultiplier, Config.Gaits.GallopMultiplier, 1 } do
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
					Horse:SetAttribute("HorseTier", Tier)
					Horse:PivotTo(CFrame.new(0, 6500 + Height * 0.5, 0))
					Horse.Parent = Fixture
					ActiveRig = Animator.Create(Horse, Targets)
					local Speed = Config.GetTier(Tier).Speed * Multiplier
					local Rate = math.min(Config.Steering.MaximumTurnRate,
						Speed / math.max(Config.Steering.MinimumRadius, Speed * Speed / Config.Steering.LateralAcceleration))
					local Starts, Completed, Forced = { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, 0
					local Lowest, Highest = {}, {}
					for Frame = 1, FPS * 8 do
						local Time = Frame / FPS
						local Yaw = if Time < 4 then Rate else -Rate
						local Angle = Yaw / FPS
						Horse:PivotTo(Horse:GetPivot() * CFrame.Angles(0, Angle * 0.5, 0)
							* CFrame.new(0, 0, -Speed / FPS) * CFrame.Angles(0, Angle * 0.5, 0))
						local Before = {}
						for Index, Foot in ActiveRig.Feet do
							Before[Index] = { Swing = Foot.InSwing, Alpha = Foot.SwingAlpha }
						end
						Animator.Update(ActiveRig, 1 / FPS, Time, 2, true)
						if Time < 2 then
							continue
						end
						for Index, Foot in ActiveRig.Feet do
							if Foot.InSwing and not Before[Index].Swing then
								Starts[Index] += 1
								if Foot.ForcedSwing then
									Forced += 1
								end
							end
							if not Foot.InSwing and Before[Index].Swing then
								Check(Foot.SwingAlpha >= 1, "Turning must finish the current recovery arc")
								Completed[Index] += 1
							end
							if Foot.InSwing and Before[Index].Swing then
								Check(Foot.SwingAlpha >= Before[Index].Alpha, "Steering cannot rewind a hoof")
							end
							local Forward = Foot.Rest.Position.Z - Root.CFrame:PointToObjectSpace(Foot.Hoof.TransformedWorldCFrame.Position).Z
							Lowest[Index] = math.min(Lowest[Index] or math.huge, Forward)
							Highest[Index] = math.max(Highest[Index] or -math.huge, Forward)
						end
					end
					Check(Forced == 0, string.format("Regular curves must preserve the gait instead of corrective steps: tier %d, %d FPS, %.2f gait, %d corrections", Tier, FPS, Multiplier, Forced))
					for Index = 1, 4 do
						Check(Completed[Index] > 5 and math.abs(Starts[Index] - Completed[Index]) <= 1,
							"Each leg must keep completing strides through both steering directions")
						Check((Highest[Index] - Lowest[Index]) / ActiveRig.Scale > 2,
							"Both inner and outer legs must retain a full forward/backward movement")
					end
					Animator.Destroy(ActiveRig)
					ActiveRig = nil
					Horse:Destroy()
				end
			end
		end
	end)

	if ActiveRig then
		Animator.Destroy(ActiveRig)
	end
	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorseTurningAnimation: %d checks passed", Checks)
end
