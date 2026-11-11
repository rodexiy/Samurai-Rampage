return function(Animator: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage.Shared.HorseConfig)
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseUnevenTerrainAnimationTests"
	Fixture.Parent = workspace
	local Targets = Instance.new("Folder")
	Targets.Parent = Fixture
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(500, 2, 2000)
	Floor.Parent = Fixture
	local Step = Instance.new("Part")
	Step.Anchored = true
	Step.Parent = Fixture
	local ActiveRig: any = nil
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local Success, Error = pcall(function()
		for _, Tier in { 1, 5 } do
			for _, Pitch in { -35, 35 } do
				for _, Playback in {
					{ FPS = 30, Multiplier = Config.Gaits.TrotMultiplier },
					{ FPS = 60, Multiplier = Config.Gaits.TrotMultiplier },
					{ FPS = 120, Multiplier = Config.Gaits.TrotMultiplier },
					{ FPS = 60, Multiplier = Config.Gaits.GallopMultiplier },
					{ FPS = 60, Multiplier = 1 },
				} do
					local FPS = Playback.FPS
					Floor.CFrame = CFrame.new(0, 6899, 0) * CFrame.Angles(math.rad(Pitch), 0, math.rad(12))
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
					Horse:SetAttribute("GroundClearance", Height * 0.5)
					Horse:PivotTo(Floor.CFrame * CFrame.new(0, 1 + Height * 0.5, 0))
					Horse.Parent = Fixture
					ActiveRig = Animator.Create(Horse, Targets)
					local Previous, Completed = {}, { 0, 0, 0, 0 }
					local GapLow, GapHigh = {}, {}
					local Speed = Config.GetTier(Tier).Speed * Playback.Multiplier
					Step.Size = Vector3.new(100, 1.2, Speed * 0.8)
					Step.CFrame = Floor.CFrame * CFrame.new(0, 1.6, -Speed * 3.4)
					local Lengths, Locked, Samples = {}, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }
					for Index, Foot in ActiveRig.Feet do
						local Length = 0
						for JointIndex = 2, #Foot.Joints do
							Length += (Foot.Joints[JointIndex].Bone.WorldPosition - Foot.Joints[JointIndex - 1].Bone.WorldPosition).Magnitude
						end
						Lengths[Index] = Length
					end
					local BodyHeight = 0
					for Frame = 1, FPS * 5 do
						local Time = Frame / FPS
						Floor.CanCollide = Time < 2 or Time >= 2.5
						Step.CanCollide = Floor.CanCollide
						-- Follow the slope while the body responds to small changes in clearance and pitch.
						local Bob = math.sin(Time * 3) * 0.6
						local TerrainHeight = if Time >= 3 and Time < 3.8 then 1.2 else 0
						BodyHeight += (TerrainHeight - BodyHeight) * (1 - math.exp(-8 / FPS))
						Horse:PivotTo(Floor.CFrame * CFrame.new(0, 1 + Height * 0.5 + Bob + BodyHeight, -Speed * Time)
							* CFrame.Angles(math.rad(5) * math.sin(Time * 2), 0, 0))
						Animator.Update(ActiveRig, 1 / FPS, Time, 2, true)
						for Index, Foot in ActiveRig.Feet do
							if Previous[Index] and Previous[Index].Swing and not Foot.InSwing then
								Check(Foot.SwingAlpha >= 1, "A missed terrain sample cannot cancel a moving leg mid-stride")
								Completed[Index] += 1
							end
							Previous[Index] = { Swing = Foot.InSwing }
							if Time > 2.1 and Time < 2.5 then
								local Angle = Foot.Joints[1].Angle
								GapLow[Index] = math.min(GapLow[Index] or math.huge, Angle)
								GapHigh[Index] = math.max(GapHigh[Index] or -math.huge, Angle)
							end
							for _, Joint in Foot.Joints do
								Check(Joint.Angle >= Joint.Minimum - 0.001 and Joint.Angle <= Joint.Maximum + 0.001,
									"Uneven ground must preserve the anatomical bend limits")
							end
						end
						if Time > 1 and Floor.CanCollide then
							for Index, Foot in ActiveRig.Feet do
								local Distance = (Foot.Hoof.TransformedWorldCFrame.Position - Foot.Joints[1].Bone.TransformedWorldCFrame.Position).Magnitude
								Samples[Index] += 1
								if Distance / Lengths[Index] > 0.995 then
									Locked[Index] += 1
								end
							end
						end
						Floor.CanCollide = true
					end
					for Index = 1, 4 do
						Check(Completed[Index] > 4, "Each leg keeps completing steps on a slope")
						Check(GapHigh[Index] - GapLow[Index] > math.rad(5), "Each leg keeps moving through a missing ground sample")
						Check(Locked[Index] / Samples[Index] < 0.05,
							"The actual leg must not lock into full extension over uneven terrain: " .. Locked[Index] .. "/" .. Samples[Index])
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

	return string.format("HorseUnevenTerrainAnimation: %d checks passed", Checks)
end
