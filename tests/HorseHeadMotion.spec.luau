return function(Animator: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage.Shared.HorseConfig)
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseHeadMotionTests"
	Fixture.Parent = workspace
	local Targets = Instance.new("Folder")
	Targets.Parent = Fixture
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(500, 2, 4000)
	Floor.Position = Vector3.new(0, 11899, 0)
	Floor.Parent = Fixture
	local Active: any = nil
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local Success, Error = pcall(function()
		for Tier, Stats in Config.Tiers do
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
			Horse:PivotTo(CFrame.new(0, 11900 + Height * 0.5, 0))
			Horse.Parent = Fixture
			Active = Animator.Create(Horse, Targets)
			local Head: any = nil
			for _, Joint in Active.Expression.Joints do
				if Joint.Kind == "Head" then
					Head = Joint
				end
			end
			assert(Head, "The imported head joint is required")
			local Nose = Horse:FindFirstChild("SK_nose", true) :: Bone
			local Parent = Head.Bone.Parent :: Bone
			local Chest = Horse:FindFirstChild("SK_spine_4", true) :: Bone
			local AnatomicalUp = Head.Bone.TransformedWorldCFrame:VectorToObjectSpace(Root.CFrame.UpVector)
			local Previous = 0
			for Stage, Multiplier in { Config.Gaits.TrotMultiplier, Config.Gaits.GallopMultiplier, 1 } do
				local Low, High, NoseLow, NoseHigh = math.huge, -math.huge, math.huge, -math.huge
				local WorldLow, WorldHigh = math.huge, -math.huge
				local ReachLow, ReachHigh = math.huge, -math.huge
				local Crossings, MaximumStep = 0, 0
				for Frame = 1, 240 do
					Horse:PivotTo(Horse:GetPivot() - Vector3.zAxis * Stats.Speed * Multiplier / 60)
					Animator.Update(Active, 1 / 60, 0, 2, true)
					MaximumStep = math.max(MaximumStep, math.abs(Head.Angle - Previous))
					if Frame > 120 then
						Low, High = math.min(Low, Head.Angle), math.max(High, Head.Angle)
						local Bind = Parent.TransformedWorldCFrame * Head.Bone.CFrame * Head.Rest
						local Tip = Bind:PointToObjectSpace(Nose.TransformedWorldCFrame.Position)
						local Lift = Tip:Dot(AnatomicalUp)
						NoseLow, NoseHigh = math.min(NoseLow, Lift), math.max(NoseHigh, Lift)
						local WorldLift = Root.CFrame:PointToObjectSpace(Nose.TransformedWorldCFrame.Position).Y
						WorldLow, WorldHigh = math.min(WorldLow, WorldLift), math.max(WorldHigh, WorldLift)
						local Reach = Root.CFrame.LookVector:Dot(Head.Bone.TransformedWorldCFrame.Position - Chest.TransformedWorldCFrame.Position)
						ReachLow, ReachHigh = math.min(ReachLow, Reach), math.max(ReachHigh, Reach)
						if Head.Angle * Previous < 0 then
							Crossings += 1
						end
					end
					Previous = Head.Angle
					Check(Head.Rest:ToObjectSpace(Head.Bone.Transform).Position.Magnitude < 0.0001,
						"Head motion cannot stretch the neck or translate a bone")
				end
				Check(High - Low > math.rad(({ 1.5, 5, 6 })[Stage]), "Each gait must visibly articulate the head on tier " .. Tier)
				Check(NoseHigh - NoseLow > ({ 0.02, 0.06, 0.08 })[Stage] * Active.Scale,
					"The muzzle must move independently of the rigid parent neck")
				Check(WorldHigh - WorldLow > ({ 0.18, 0.3, 0.4 })[Stage] * Active.Scale,
					"Combined neck motion must visibly move the head instead of cancelling out: " .. (WorldHigh - WorldLow))
				Check(Crossings >= 5 and MaximumStep < math.rad(4), "Head nodding must stay rhythmic and continuous")
				if Stage == 3 then
					Check(ReachHigh - ReachLow > 0.8 * Active.Scale,
						"Running must move the head forward and back relative to the chest: " .. (ReachHigh - ReachLow) / Active.Scale)
				end
			end
			for _ = 1, 180 do
				Animator.Update(Active, 1 / 60, 0, 2, true)
			end
			Check(math.abs(Head.Angle) < math.rad(0.35) and math.abs(Head.Yaw) < 0.0001,
				"Stopping must blend back to the quiet idle head motion")
			Animator.SetQuality(Active, 0)
			Check(Head.Bone.Transform == Head.Rest, "Culling must restore the original head pose")
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

	return string.format("HorseHeadMotion: %d checks passed", Checks)
end
