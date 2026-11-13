return function(Grounding: any, OnlyCase: string?, OnlySpeed: number?): string
	local RunService = game:GetService("RunService")
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseTraversalPhysicsTests"
	Fixture.Parent = workspace
	local Origin = Vector3.new(0, 11200, 0)
	local Geometry = Instance.new("Folder")
	Geometry.Parent = Fixture
	local function Platform(Frame: CFrame, Size: Vector3): Part
		local Part = Instance.new("Part")
		Part.Anchored = true
		Part.Size = Size
		Part.CFrame = Frame
		Part.Parent = Geometry

		return Part
	end
	local Model = Instance.new("Model")
	Model:SetAttribute("GroundClearance", 5)
	Model:SetAttribute("GroundHalfWidth", 1)
	Model:SetAttribute("GroundHalfLength", 3)
	Model.Parent = Fixture
	local Root = Instance.new("Part")
	Root.CanCollide = false
	Root.Size = Vector3.new(2.5, 5.5, 7)
	Root.Parent = Model
	Model.PrimaryPart = Root
	Root:SetNetworkOwner(nil)
	local Attachment = Instance.new("Attachment")
	Attachment.Parent = Root
	local Motor = Instance.new("LinearVelocity")
	Motor.Attachment0 = Attachment
	Motor.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	Motor.PrimaryTangentAxis = Vector3.xAxis
	Motor.SecondaryTangentAxis = Vector3.zAxis
	Motor.RelativeTo = Enum.ActuatorRelativeTo.World
	Motor.ForceLimitsEnabled = true
	Motor.MaxForce = Root.AssemblyMass * 180
	Motor.Parent = Root
	local Vertical = Instance.new("LinearVelocity")
	Vertical.Name = "MountGroundVelocity"
	Vertical.Attachment0 = Attachment
	Vertical.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	Vertical.LineDirection = Vector3.yAxis
	Vertical.RelativeTo = Enum.ActuatorRelativeTo.World
	Vertical.Parent = Root
	local Orientation = Instance.new("AlignOrientation")
	Orientation.Name = "MountOrientation"
	Orientation.Attachment0 = Attachment
	Orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	Orientation.MaxTorque = math.huge
	Orientation.MaxAngularVelocity = 10
	Orientation.Responsiveness = 20
	Orientation.Parent = Root
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local Success, Error = pcall(function()
		for _, Case in { "Descent35", "Descent45", "SmallObjects", "WideStep" } do
			if OnlyCase and Case ~= OnlyCase then
				continue
			end
			for _, Speed in { 32, 80 } do
				if OnlySpeed and Speed ~= OnlySpeed then
					continue
				end
				Geometry:ClearAllChildren()
				Platform(CFrame.new(Origin - Vector3.yAxis), Vector3.new(200, 2, 300))
				local Height = 0
				if string.find(Case, "Descent") then
					Height = 25
					local Angle = math.rad(if Case == "Descent35" then 35 else 45)
					local Length = Height / math.sin(Angle)
					Platform(CFrame.new(Origin + Vector3.new(0, Height - 1, 35)), Vector3.new(50, 2, 50))
					Platform(CFrame.new(Origin + Vector3.new(0, Height * 0.5, 10 - math.cos(Angle) * Length * 0.5))
						* CFrame.Angles(-Angle, 0, 0) * CFrame.new(0, -0.5, 0), Vector3.new(50, 1, Length))
				elseif Case == "SmallObjects" then
					for Index, Rise in { 0.15, 0.5, 0.8, 1.2 } do
						Platform(CFrame.new(Origin + Vector3.new(0, Rise * 0.5, -Index * 12)), Vector3.new(20, Rise, 1.5))
					end
				else
					Platform(CFrame.new(Origin + Vector3.new(0, 1.25, -25)), Vector3.new(30, 2.5, 20))
				end
				Root.CFrame = CFrame.new(Origin + Vector3.new(0, Height + 5, 35))
				Root.AssemblyLinearVelocity = Vector3.new(0, 0, -Speed)
				Root.AssemblyAngularVelocity = Vector3.zero
				Orientation.CFrame = CFrame.identity
				local State = Grounding.Create(Model)
				local Elapsed, PeakLift, MinimumSpeed, LowestChest = 0, 0, math.huge, math.huge
				local Failure: string? = nil
				local Done = Instance.new("BindableEvent")
				local Before = RunService.PreSimulation:Connect(function(DeltaTime: number)
					local Okay, Result = pcall(function()
						local Travel = Grounding.ConstrainMovement(State, Vector3.new(0, 0, -Speed), DeltaTime)
						Motor.PlaneVelocity = Vector2.new(Travel.X, Travel.Z)
						Grounding.Update(State, DeltaTime)
					end)
					if not Okay then
						Failure = tostring(Result)
					end
				end)
				local After: RBXScriptConnection
				After = RunService.PostSimulation:Connect(function(DeltaTime: number)
					local Okay, Result = pcall(function()
						Grounding.Update(State, 0)
					end)
					if not Okay then
						Failure = tostring(Result)
					end
					Elapsed += DeltaTime
					PeakLift = math.max(PeakLift, Root.Position.Y - Origin.Y - 5)
					MinimumSpeed = math.min(MinimumSpeed, (Root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude)
					for _, X in { -1, 1 } do
						for _, Z in { -1, 1 } do
							local Corner = Root.CFrame:PointToWorldSpace(Vector3.new(Root.Size.X * X * 0.5, -Root.Size.Y * 0.5, Root.Size.Z * Z * 0.5))
							LowestChest = math.min(LowestChest, Corner.Y - Origin.Y)
						end
					end
					if Failure or Elapsed >= 7 or Root.Position.Z < Origin.Z - 55 then
						Before:Disconnect()
						After:Disconnect()
						Done:Fire()
					end
				end)
				Done.Event:Wait()
				Done:Destroy()
				assert(not Failure, tostring(Failure))
				Check(Root.Position.Z < Origin.Z - 55, Case .. " must remain traversable at " .. Speed .. ": " .. tostring(Root.Position))
				Check(MinimumSpeed > 1, Case .. " cannot create a complete stop: " .. MinimumSpeed)
				Check(LowestChest > -0.1, Case .. " cannot bury the chest at the ramp exit: " .. LowestChest)
				if Case == "SmallObjects" then
					Check(PeakLift < 0.25, "Small objects belong to the footstep, not a climb: " .. PeakLift)
				elseif Case == "WideStep" then
					Check(PeakLift > 2.2, "A genuine wide step must still raise the mount")
				end
			end
		end
	end)

	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorseTraversalPhysics: %d checks passed", Checks)
end
