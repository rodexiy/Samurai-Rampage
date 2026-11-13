return function(Animator: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage.Shared.HorseConfig)
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseAnimationPolishTests"
	Fixture.Parent = workspace
	local Targets = Instance.new("Folder")
	Targets.Parent = Fixture
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(500, 2, 5000)
	Floor.Position = Vector3.new(0, 9899, 0)
	Floor.Parent = Fixture
	local Active: any = nil
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end
	local function Difference(A: number, B: number): number
		return math.abs((A - B + 0.5) % 1 - 0.5)
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
			Horse:PivotTo(CFrame.new(0, 9900 + Height * 0.5, 0))
			Horse.Parent = Fixture
			Active = Animator.Create(Horse, Targets)
			local SpineRest = {}
			for _, Joint in Active.Expression.Joints do
				if Joint.Kind == "Spine" then
					SpineRest[Joint.Bone] = Active.Body.TransformedWorldCFrame:PointToObjectSpace(Joint.Bone.TransformedWorldCFrame.Position)
				end
			end
			local CanterFrequency = 0
			local CanterFrontSpan, CanterRearSpan, CanterFrontLift = 0, 0, 0
			for Stage, Multiplier in { Config.Gaits.TrotMultiplier, Config.Gaits.GallopMultiplier, 1 } do
				local Contacts = {}
				local BodyLow, BodyHigh, PitchLow, PitchHigh = math.huge, -math.huge, math.huge, -math.huge
				local MaximumFrontBend, Extended, Recovery = 0, 0, 0
				local MaximumCurvature, MaximumSpineTravel = 0, 0
				local FrontSeparated, RearSeparated, Samples = 0, 0, 0
				local StrideLow, StrideHigh, Lift = {}, {}, {}
				local GatheredSamples, ExtendedReach = 0, 0
				local RetractedReach, RetractionAngle = { 0, 0 }, { 0, 0 }
				for Frame = 1, 240 do
					local Swing = {}
					for Index, Foot in Active.Feet do
						Swing[Index] = Foot.InSwing
					end
					Horse:PivotTo(Horse:GetPivot() - Vector3.zAxis * Stats.Speed * Multiplier / 60)
					Animator.Update(Active, 1 / 60, 0, 2, true)
					if Frame > 120 then
						Samples += 1
						local Front = Active.Feet[1].Hoof.TransformedWorldCFrame.Position - Active.Feet[2].Hoof.TransformedWorldCFrame.Position
						local Rear = Active.Feet[3].Hoof.TransformedWorldCFrame.Position - Active.Feet[4].Hoof.TransformedWorldCFrame.Position
						if math.abs(Front:Dot(Root.CFrame.LookVector)) > Active.Scale then
							FrontSeparated += 1
						end
						if math.abs(Rear:Dot(Root.CFrame.LookVector)) > Active.Scale then
							RearSeparated += 1
						end

						BodyLow, BodyHigh = math.min(BodyLow, Active.BodyMotion.Y), math.max(BodyHigh, Active.BodyMotion.Y)
						local Pitch = Active.BodyMotion:ToOrientation()
						PitchLow, PitchHigh = math.min(PitchLow, Pitch), math.max(PitchHigh, Pitch)
						local RearAngle, LoinAngle = 0, 0
						local Airborne, FrontZ, BackZ = true, 0, 0
						for _, Joint in Active.Expression.Joints do
							if Joint.Kind == "Spine" then
								local Local = Active.Body.TransformedWorldCFrame:PointToObjectSpace(Joint.Bone.TransformedWorldCFrame.Position)
								MaximumSpineTravel = math.max(MaximumSpineTravel, (Local - SpineRest[Joint.Bone]).Magnitude)
								assert(Joint.Rest:ToObjectSpace(Joint.Bone.Transform).Position.Magnitude < 0.0001,
									"Spine flexion must preserve bone lengths")
								if Joint.Index == 1 then
									RearAngle = Joint.Angle
								elseif Joint.Index == 2 then
									LoinAngle = Joint.Angle
								end
							end
						end
						MaximumCurvature = math.max(MaximumCurvature, math.abs(RearAngle - LoinAngle))
						for Index, Foot in Active.Feet do
							local Position = Root.CFrame:PointToObjectSpace(Foot.Hoof.TransformedWorldCFrame.Position)
							StrideLow[Index] = math.min(StrideLow[Index] or math.huge, -Position.Z)
							StrideHigh[Index] = math.max(StrideHigh[Index] or -math.huge, -Position.Z)
							Lift[Index] = math.max(Lift[Index] or 0, Position.Y - Foot.Rest.Position.Y)
							Airborne = Airborne and Foot.InSwing and Foot.Hoof.TransformedWorldCFrame.Position.Y > 9900 + 0.2 * Active.Scale
							if Foot.Front then
								FrontZ += Position.Z * 0.5
								if Foot.InSwing and Foot.SwingAlpha < Config.Animation.Running.FrontRetractionEnd then
									RetractedReach[Index] = math.max(RetractedReach[Index], Position.Z - Foot.Rest.Position.Z)
									local Shoulder = Root.CFrame:PointToObjectSpace(Foot.Joints[2].Bone.TransformedWorldCFrame.Position)
									RetractionAngle[Index] = math.max(RetractionAngle[Index],
										math.atan2(Position.Z - Shoulder.Z, Shoulder.Y - Position.Y))
								end
								if math.abs(Foot.Joints[4].Angle) < math.rad(15) then
									ExtendedReach = math.max(ExtendedReach, Foot.Rest.Position.Z - Position.Z)
								end
							else
								BackZ += Position.Z * 0.5
							end

							if Swing[Index] and not Foot.InSwing and Foot.Grounded then
								Contacts[Index] = Active.Phase
							end
							if Foot.Front then
								local Bend = math.abs(Foot.Joints[4].Angle)
								MaximumFrontBend = math.max(MaximumFrontBend, Bend)
								if Foot.InSwing and Foot.SwingAlpha > 0.72 then
									Recovery += 1
									if Bend < math.rad(15) then
										Extended += 1
									end
								end
							end
						end
						-- Gathered suspension brings the front/rear hoof pairs together under the body.
						if Airborne and math.abs(BackZ - FrontZ) < 3 * Active.Scale then
							GatheredSamples += 1
						end
					end
				end
				local FrontSpan = (StrideHigh[1] - StrideLow[1] + StrideHigh[2] - StrideLow[2]) * 0.5
				local RearSpan = (StrideHigh[3] - StrideLow[3] + StrideHigh[4] - StrideLow[4]) * 0.5
				local FrontLift = (Lift[1] + Lift[2]) * 0.5
				for Index = 1, 4 do
					Check(Contacts[Index] ~= nil, "Every gait must keep completing contacts on all legs")
				end
				Check(BodyHigh - BodyLow > ({ 0.1, 0.32, 0.38 })[Stage] * Active.Scale,
					"Torso movement must be visible in every gait: " .. (BodyHigh - BodyLow))
				Check(PitchHigh - PitchLow > math.rad(({ 2, 6, 8 })[Stage]), "The torso must pitch with the gait")
				Check(MaximumSpineTravel > ({ 0.025, 0.08, 0.13 })[Stage] * Active.Scale,
					"The spine must change shape independently of rigid body motion: " .. MaximumSpineTravel)
				Check(MaximumCurvature > math.rad(({ 1.3, 5, 8 })[Stage]), "The loin and rear must visibly bend against each other")
				if Stage == 1 then
					Check(Difference(Contacts[1], Contacts[4]) < 0.06 and Difference(Contacts[2], Contacts[3]) < 0.06,
						"The trot keeps its two diagonal beats")
				elseif Stage == 2 then
					CanterFrequency = Active.Frequency
					CanterFrontSpan, CanterRearSpan, CanterFrontLift = FrontSpan, RearSpan, FrontLift
					for Index = 1, 2 do
						Check(Lift[Index] > 0.58 * Active.Scale,
							"Both cantering forehooves must lift visibly during forward recovery: " .. Lift[Index] / Active.Scale)
					end
					Check(Active.Sprint < 0.01 and Difference(Contacts[1], Contacts[4]) < 0.06,
						"The collected gallop has its own diagonal middle beat")
					Check(Difference(Contacts[2], Contacts[3]) > 0.2, "The leading foreleg has a separate canter beat")
				else
					for Index = 1, 2 do
						Check(RetractedReach[Index] > 1.2 * Active.Scale and RetractionAngle[Index] > math.rad(12),
							"Both running forelegs must sweep visibly behind the chest after push-off: "
								.. RetractedReach[Index] / Active.Scale .. ", " .. math.deg(RetractionAngle[Index]))
					end
					Check(GatheredSamples > 0, "Running must include actual gathered suspension with all four hooves clear of the floor")
					Check(ExtendedReach > 3.2 * Active.Scale, "The running foreleg must reach forward with its carpus open: " .. ExtendedReach / Active.Scale)
					Check(FrontSpan > CanterFrontSpan * 1.3 and RearSpan > CanterRearSpan * 1.15,
						"Running must extend the actual front and rear strides beyond canter: "
							.. FrontSpan / CanterFrontSpan .. ", " .. RearSpan / CanterRearSpan)
					Check(FrontLift > CanterFrontLift * 1.4 and FrontLift > 0.9 * Active.Scale,
						"Running must visibly collect and lift the actual front hooves: " .. FrontLift / Active.Scale)
					Check(Difference(Contacts[1], Contacts[2]) > 0.16 and Difference(Contacts[3], Contacts[4]) > 0.16,
						"Running separates the leading and trailing hoof of each pair")
					Check(FrontSeparated / Samples > 0.4 and RearSeparated / Samples > 0.4,
						"Actual front and rear hooves must stride independently instead of bounding in pairs: "
							.. FrontSeparated .. "/" .. Samples .. ", " .. RearSeparated .. "/" .. Samples)
					Check(MaximumFrontBend < math.rad(50), "Flat running cannot retain an excessive front-leg fold: " .. math.deg(MaximumFrontBend))
					Check(Recovery > 5 and Extended / Recovery > 0.85, "Running front legs must open before touchdown")
					Check(Active.Sprint > 0.99 and Active.Frequency > CanterFrequency + 0.1,
						"Full running develops a distinct stride and cadence on tier " .. Tier)
					for Index = 1, 4 do
						for Other = Index + 1, 4 do
							Check(Difference(Contacts[Index], Contacts[Other]) > 0.07,
								"The extended gallop has four separate hoof contacts")
						end
					end
				end
			end

			local Low, High, EarMotion = math.huge, -math.huge, 0
			local Feet = {}
			local MaximumFootDrift = 0
			for Frame = 1, 600 do
				Animator.Update(Active, 1 / 60, 0, 2, true)
				if Frame < 120 then
					continue
				end
				Low, High = math.min(Low, Active.BodyMotion.Position.Y), math.max(High, Active.BodyMotion.Position.Y)
				for _, Joint in Active.Expression.Joints do
					if Joint.Kind == "Ear" then
						local _, Angle = Joint.Rest:ToObjectSpace(Joint.Bone.Transform):ToAxisAngle()
						EarMotion = math.max(EarMotion, Angle)
					end
				end
				for Index, Foot in Active.Feet do
					local Position = Foot.Hoof.TransformedWorldCFrame.Position
					Feet[Index] = Feet[Index] or Position
					MaximumFootDrift = math.max(MaximumFootDrift, (Position - Feet[Index]).Magnitude)
				end
			end
			Check(High - Low > 0.025 * Active.Scale, "Idle breathing moves the torso softly")
			Check(EarMotion > math.rad(5), "Idle includes occasional independent ear movement")
			Check(MaximumFootDrift < 0.04, "Breathing and weight shifts must preserve planted hooves: " .. MaximumFootDrift)
			Check(Active.Gallop < 0.01 and Active.Sprint < 0.01, "Stopping fully releases both moving gaits")
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

	return string.format("HorseAnimationPolish: %d checks passed", Checks)
end
