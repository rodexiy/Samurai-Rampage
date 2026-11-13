return function(Grounding: any, Avoidance: any, Steering: any): string
	local RunService = game:GetService("RunService")
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseAvoidancePhysicsTests"
	Fixture.Parent = workspace
	local Origin = Vector3.new(0, 9500, 0)
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(500, 2, 500)
	Floor.Position = Origin - Vector3.yAxis
	Floor.Parent = Fixture
	local Wall = Instance.new("Part")
	Wall.Anchored = true
	Wall.Size = Vector3.new(16, 30, 2)
	Wall.Position = Origin + Vector3.new(0, 10, -25)
	Wall.Parent = Fixture
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
		for _, Speed in { 17.6, 80 } do
			Root.CFrame = CFrame.new(Origin + Vector3.new(0, 5, 35))
			Root.AssemblyLinearVelocity = Vector3.new(0, 0, -Speed)
			Root.AssemblyAngularVelocity = Vector3.zero
			Orientation.CFrame = CFrame.identity
			local Ground = Grounding.Create(Model)
			local Avoid = Avoidance.Create()
			local Steer = Steering.Create(Root.CFrame, Root.AssemblyLinearVelocity)
			local Stats = { Speed = Speed, Acceleration = 40, TurnSpeed = 7 }
			Grounding.Update(Ground, 0.1)
			local Elapsed, MaximumSide, MinimumSpeed = 0, 0, math.huge
			local Failure: string? = nil
			local Done = Instance.new("BindableEvent")
			local Before = RunService.PreSimulation:Connect(function(DeltaTime: number)
				local Okay, Result = pcall(function()
					local Direction, Multiplier = Avoidance.Update(Avoid, Ground, -Vector3.zAxis, Speed, DeltaTime)
					local Movement = Steering.Update(Steer, Root.CFrame, Root.AssemblyLinearVelocity,
						Direction, Stats, DeltaTime, Ground.Grounded, Root.AssemblyAngularVelocity, Multiplier)
					local Travel = Grounding.ConstrainMovement(Ground, Movement, DeltaTime)
					Motor.PlaneVelocity = Vector2.new(Travel.X, Travel.Z)
					Ground.Heading = Steer.Heading
					Grounding.Update(Ground, DeltaTime, nil, nil, Steer.Bank)
				end)
				if not Okay then
					Failure = tostring(Result)
				end
			end)
			local After: RBXScriptConnection
			After = RunService.PostSimulation:Connect(function(DeltaTime: number)
				local Okay, Result = pcall(function()
					Grounding.Update(Ground, 0)
				end)
				if not Okay then
					Failure = tostring(Result)
				end
				Elapsed += DeltaTime
				MaximumSide = math.max(MaximumSide, math.abs(Root.Position.X))
				MinimumSpeed = math.min(MinimumSpeed, (Root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude)
				if Failure or Elapsed >= 12 or Root.Position.Z < Origin.Z - 45 then
					Before:Disconnect()
					After:Disconnect()
					Done:Fire()
				end
			end)
			Done.Event:Wait()
			Done:Destroy()
			assert(not Failure, tostring(Failure))
			Check(Root.Position.Z < Origin.Z - 45, "Native physics must complete the detour at " .. Speed .. ": " .. tostring(Root.Position))
			Check(MaximumSide > 10, "Native physics must carry the body around the side of the obstacle")
			Check(MinimumSpeed > 0.5, "An open route must not stop the horse: " .. MinimumSpeed)
		end
	end)

	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorseAvoidancePhysics: %d checks passed", Checks)
end
