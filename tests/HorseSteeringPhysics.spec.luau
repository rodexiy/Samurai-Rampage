-- Run in Play mode. Exercises the same client solver with real constraints and a welded rider.
return function(Steering: any, Grounding: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local Config = require(ReplicatedStorage.Shared.HorseConfig)
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseSteeringPhysicsTests"
	Fixture.Parent = workspace
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(2000, 2, 2000)
	Floor.Position = Vector3.new(0, 3499, 0)
	Floor.Parent = Fixture
	local Horse = Instance.new("Model")
	Horse:SetAttribute("GroundClearance", 5)
	Horse:SetAttribute("GroundHalfWidth", 1)
	Horse:SetAttribute("GroundHalfLength", 3)
	Horse.Parent = Fixture
	local Root = Instance.new("Part")
	Root.Size = Vector3.new(2.5, 6, 7)
	Root.CanCollide = false
	Root.CFrame = CFrame.new(0, 3505, 0)
	Root.Parent = Horse
	Horse.PrimaryPart = Root
	local Rider = Instance.new("Part")
	Rider.CanCollide = false
	Rider.Massless = true
	Rider.CFrame = Root.CFrame * Config.RiderOffset
	Rider.Parent = Horse
	local Weld = Instance.new("WeldConstraint")
	Weld.Part0, Weld.Part1 = Root, Rider
	Weld.Parent = Root
	local Attachment = Instance.new("Attachment")
	Attachment.Parent = Root
	local Velocity = Instance.new("LinearVelocity")
	Velocity.Attachment0 = Attachment
	Velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	Velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	Velocity.PrimaryTangentAxis = Vector3.xAxis
	Velocity.SecondaryTangentAxis = Vector3.zAxis
	Velocity.ForceLimitsEnabled = true
	Velocity.MaxForce = Root.AssemblyMass * Config.PhysicsAcceleration
	Velocity.Parent = Root
	local Vertical = Instance.new("LinearVelocity")
	Vertical.Name = "MountGroundVelocity"
	Vertical.Attachment0 = Attachment
	Vertical.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	Vertical.LineDirection = Vector3.yAxis
	Vertical.Enabled = false
	Vertical.Parent = Root
	local Orientation = Instance.new("AlignOrientation")
	Orientation.Name = "MountOrientation"
	Orientation.Attachment0 = Attachment
	Orientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	Orientation.MaxTorque = math.huge
	Orientation.MaxAngularVelocity = 10
	Orientation.Responsiveness = 20
	Orientation.Parent = Root
	Root:SetNetworkOwner(nil)
	local Support = assert(Grounding.Create(Horse))
	local State = Steering.Create(Root.CFrame, Vector3.zero)
	local Side = 0
	local Moving = true
	local Failure: string? = nil
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local Simulation = RunService.PreSimulation:Connect(function(DeltaTime: number)
		local Ok, Error = pcall(function()
			local Heading = Grounding.HorizontalDirection(Root.CFrame.LookVector)
			local Input = if Moving then CFrame.fromAxisAngle(Vector3.yAxis, Side * math.pi / 2):VectorToWorldSpace(Heading) else Vector3.zero
			local Travel = Steering.Update(State, Root.CFrame, Root.AssemblyLinearVelocity, Input,
				Config.Tiers[5], DeltaTime, Support.Grounded, Root.AssemblyAngularVelocity)
			Travel = Grounding.ConstrainMovement(Support, Travel, DeltaTime)
			Velocity.PlaneVelocity = Vector2.new(Travel.X, Travel.Z)
			Support.Heading = State.Heading
			Grounding.Update(Support, DeltaTime, nil, nil, State.Bank)
		end)
		if not Ok then
			Failure = tostring(Error)
		end
	end)

	local function Advance(Duration: number, Sample: ((number, number) -> ())?)
		local Done = Instance.new("BindableEvent")
		local Elapsed = 0
		local Connection: RBXScriptConnection
		Connection = RunService.PostSimulation:Connect(function(DeltaTime: number)
			Elapsed += DeltaTime
			if Sample then
				local Ok, Error = pcall(Sample, Elapsed, DeltaTime)
				if not Ok then
					Failure = tostring(Error)
				end
			end
			if Failure or Elapsed >= Duration then
				Connection:Disconnect()
				Done:Fire()
			end
		end)
		Done.Event:Wait()
		Done:Destroy()
		assert(not Failure, tostring(Failure))
	end

	local Success, Error = pcall(function()
		Advance(2, nil)
		Check(Root.AssemblyLinearVelocity.Z < -54, "Reach gallop speed along the body")
		Side = -1
		local MinimumRadius = math.huge
		local MinimumAlignment = 1
		local MaximumBank = 0
		Advance(2, function(Elapsed: number, _DeltaTime: number)
			local Heading = Grounding.HorizontalDirection(Root.CFrame.LookVector)
			local FlatVelocity = Root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
			local Rate = math.abs(Root.AssemblyAngularVelocity.Y)
			if Elapsed > 1 and Rate > 0.01 then
				MinimumRadius = math.min(MinimumRadius, FlatVelocity.Magnitude / Rate)
				MinimumAlignment = math.min(MinimumAlignment, FlatVelocity.Unit:Dot(Heading))
				local Right = CFrame.lookAt(Vector3.zero, Heading).RightVector
				MaximumBank = math.max(MaximumBank, Root.CFrame.UpVector:Dot(Right))
			end
			assert(Rider.CFrame.UpVector:Dot(Root.CFrame.UpVector) > 0.999, "The welded rider follows the corner bank")
			local Feet = Root.Position - Root.CFrame.UpVector * 5
			assert(Feet.Y > 3499.6, "Banking cannot sink the mount into the floor")
		end)
		Check(MinimumRadius > 20 and MinimumRadius < 70, "Physical gallop follows a wide arc: " .. MinimumRadius)
		Check(MinimumAlignment > 0.98, "Physical travel stays aligned with the body: " .. MinimumAlignment)
		Check(MaximumBank > math.sin(math.rad(2)) and MaximumBank < math.sin(math.rad(9)), "Physical horse banks subtly into a right curve")
		Moving = false
		Advance(1.8, nil)
		Check(Root.AssemblyLinearVelocity.Magnitude < 1 and Root.CFrame.UpVector.Y > 0.999,
			"Braking stops and straightens the actual assembly")
		Moving, Side = true, 1
		Advance(2.5, nil)
		local Right = CFrame.lookAt(Vector3.zero, Grounding.HorizontalDirection(Root.CFrame.LookVector)).RightVector
		Check(Root.CFrame.UpVector:Dot(Right) < -math.sin(math.rad(2)), "Physical left curves bank in the opposite direction")
		Floor:Destroy()
		Advance(0.3, nil)
		Check(not Support.Grounded and Root.AssemblyLinearVelocity.Y < -20, "Curve steering preserves gravity when support disappears")
	end)

	Simulation:Disconnect()
	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorseSteeringPhysics: %d checks passed", Checks)
end
