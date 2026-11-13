return function(Animator: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage.Shared.HorseConfig)
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseBodyFluidityTests"
	Fixture.Parent = workspace
	local Targets = Instance.new("Folder")
	Targets.Parent = Fixture
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(100, 2, 2000)
	Floor.Position = Vector3.new(0, 15999, -800)
	Floor.Parent = Fixture
	local Active: any = nil
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local Success, Error = pcall(function()
		for _, Tier in { 1, 5 } do
			local Peaks = {}
			for _, FPS in { 30, 60, 120 } do
				local Stats = Config.GetTier(Tier)
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
				Horse:PivotTo(CFrame.new(0, 16000 + Height * 0.5, 0))
				Horse.Parent = Fixture
				Active = Animator.Create(Horse, Targets)
				local Rear: any = nil
				local Chest: any = nil
				local Head: any = nil
				for _, Joint in Active.Expression.Joints do
					if Joint.Kind == "Head" then
						Head = Joint
					elseif Joint.Kind == "Spine" and Joint.Index == 1 then
						Rear = Joint
					elseif Joint.Kind == "Spine" and Joint.Index == 4 then
						Chest = Joint
					end
				end
				assert(Rear and Chest and Head, "The real spine and head bones are required")
				local Yaw, Roll, Wave = 0, 0, 0
				for Frame = 1, FPS * 4 do
					Horse:PivotTo(Horse:GetPivot() - Vector3.zAxis * Stats.Speed / FPS)
					Animator.Update(Active, 1 / FPS, 0, 2, true)
					if Frame > FPS * 2 then
						Yaw = math.max(Yaw, math.abs(Rear.Yaw))
						Roll = math.max(Roll, math.abs(Rear.Roll))
						Wave = math.max(Wave, math.abs(Rear.Yaw - Chest.Yaw / Config.Animation.Spine.Weights[4]))
						for _, Joint in Active.Expression.Joints do
							Check(Joint.Rest:ToObjectSpace(Joint.Bone.Transform).Position.Magnitude < 0.0001,
								"Fluid body motion must not stretch or translate the skin bones")
						end
					end
				end
				Check(Yaw > math.rad(0.5) and Roll > math.rad(0.3), "The rib cage must yield laterally during running")
				Check(Yaw < math.rad(1.2) and Roll < math.rad(0.8), "Secondary torso motion must stay subtle")
				Check(Wave > math.rad(0.4), "The wave must travel along the spine instead of turning it as one rigid part")
				table.insert(Peaks, Yaw)

				local Before = Head.Angle
				Animator.Update(Active, 1 / FPS, 0, 2, true)
				Check(math.abs(Head.Angle - Before) < math.rad(5), "Releasing movement must not snap the head")
				for _ = 1, FPS * 4 do
					Animator.Update(Active, 1 / FPS, 0, 2, true)
				end
				Check(math.abs(Rear.Yaw) < 0.0001 and math.abs(Rear.Roll) < 0.0001,
					"Stopping must settle the secondary torso motion")
				Animator.SetQuality(Active, 0)
				Check(Rear.Bone.Transform == Rear.Rest and Head.Bone.Transform == Head.Rest,
					"Culling must restore the bind pose without residual spring motion")
				Animator.Destroy(Active)
				Active = nil
				Horse:Destroy()
			end
			Check(math.abs(Peaks[1] - Peaks[3]) < Peaks[3] * 0.1,
				"Secondary motion must keep its amplitude between 30 and 120 FPS")
		end
	end)

	if Active then
		Animator.Destroy(Active)
	end
	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorseBodyFluidity: %d checks passed", Checks)
end
