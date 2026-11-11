return function(Animator: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseFrontLegCycleTests"
	Fixture.Parent = workspace
	local Targets = Instance.new("Folder")
	Targets.Parent = Fixture
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(100, 2, 2500)
	Floor.Position = Vector3.new(0, 4299, 0)
	Floor.Parent = Fixture
	local ActiveRig: any = nil
	local Checks = 0
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
		Horse:PivotTo(CFrame.new(0, 4300 + Height * 0.5, 0))
		Horse.Parent = Fixture

		return Horse
	end

	local Success, Error = pcall(function()
		for Tier = 1, 5 do
			local Horse = CreateHorse(Tier)
			ActiveRig = Animator.Create(Horse, Targets)
			for _, Speed in { 12, 32, 56 } do
				local Supported, Extended, Folded = { 0, 0 }, { 0, 0 }, { 0, 0 }
				local Alternating, WorstContact = 0, 0
				local MaximumReach, MaximumShoulder = { 0, 0 }, { 0, 0 }
				for Frame = 1, 360 do
					Horse:PivotTo(Horse:GetPivot() - Vector3.zAxis * Speed / 60)
					Animator.Update(ActiveRig, 1 / 60, 0, 2, true)
					if Frame <= 180 then
						continue
					end
					for Index = 1, 2 do
						local Foot = ActiveRig.Feet[Index]
						local Bend = math.abs(Foot.Joints[4].Angle)
						local Position = Horse.PrimaryPart.CFrame:PointToObjectSpace(Foot.Hoof.TransformedWorldCFrame.Position)
						MaximumReach[Index] = math.max(MaximumReach[Index], (Foot.Rest.Position.Z - Position.Z) / ActiveRig.Scale)
						MaximumShoulder[Index] = math.max(MaximumShoulder[Index], Foot.Joints[1].Angle)
						if not Foot.InSwing and Foot.Grounded then
							Supported[Index] += 1
							if Bend < math.rad(15) then
								Extended[Index] += 1
							end
							WorstContact = math.max(WorstContact, (Foot.Hoof.TransformedWorldCFrame.Position - Foot.Target.WorldPosition).Magnitude)
						elseif Foot.InSwing and Bend > math.rad(30) then
							Folded[Index] += 1
						end
					end
					local Left = math.abs(ActiveRig.Feet[1].Joints[4].Angle)
					local Right = math.abs(ActiveRig.Feet[2].Joints[4].Angle)
					if math.min(Left, Right) < math.rad(15) and math.max(Left, Right) > math.rad(30) then
						Alternating += 1
					end
				end
				for Index = 1, 2 do
					Check(Supported[Index] > 10 and Extended[Index] / Supported[Index] > 0.7,
						"The supporting front leg extends at speed " .. Speed .. ": " .. Extended[Index] .. "/" .. Supported[Index])
					Check(Folded[Index] > 10, "The same front leg folds during recovery at speed " .. Speed)
					Check(MaximumReach[Index] > 2.5 and MaximumShoulder[Index] > math.rad(22),
						"The front leg visibly reaches forward from the shoulder: " .. MaximumReach[Index] .. ", " .. math.deg(MaximumShoulder[Index]))
				end
				Check(Alternating > 20, "Front legs visibly alternate extension and flexion at speed " .. Speed .. ": " .. Alternating)
				Check(WorstContact < 0.45, "Extending the knee preserves ground contact: " .. WorstContact)
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

	return string.format("HorseFrontLegCycle: %d checks passed", Checks)
end
