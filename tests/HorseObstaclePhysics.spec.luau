return function(Grounding: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local Config = require(ReplicatedStorage.Shared.HorseConfig)
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseObstaclePhysicsTests"
	Fixture.Parent = workspace
	local Origin = Vector3.new(0, 7800, 0)
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(200, 2, 300)
	Floor.Position = Origin - Vector3.yAxis
	Floor.Parent = Fixture
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
	Motor.MaxForce = Root.AssemblyMass * Config.PhysicsAcceleration
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
	Orientation.Responsiveness = 20
	Orientation.Parent = Root
	local Barrier = Instance.new("Part")
	Barrier.Anchored = true
	Barrier.Parent = Fixture
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local Success, Error = pcall(function()
		for _, Angle in { 0, 35, 55, 75 } do
			Root.CFrame = CFrame.new(Origin + Vector3.yAxis * 5)
			Root.AssemblyLinearVelocity = Vector3.new(0, 0, -80)
			Root.AssemblyAngularVelocity = Vector3.zero
			Orientation.CFrame = CFrame.identity
			if Angle == 0 then
				Barrier.Size = Vector3.new(100, 30, 0.2)
				Barrier.CFrame = CFrame.new(Origin + Vector3.new(0, 10, -12))
			else
				local Pitch = math.rad(Angle)
				Barrier.Size = Vector3.new(100, 1, 200)
				Barrier.CFrame = CFrame.new(Origin + Vector3.new(0, math.sin(Pitch) * 100, -6 - math.cos(Pitch) * 100))
					* CFrame.Angles(Pitch, 0, 0) * CFrame.new(0, -0.5, 0)
			end
			local State = Grounding.Create(Model)
			local Elapsed, LowestFeet = 0, math.huge
			local Done = Instance.new("BindableEvent")
			local Failure: string? = nil
			local Before = RunService.PreSimulation:Connect(function(DeltaTime: number)
				local Okay, Result = pcall(function()
					local Travel = Grounding.ConstrainMovement(State, Vector3.new(0, 0, -80), DeltaTime)
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
				local Feet = Root.Position - Root.CFrame.UpVector * 5
				local Height = if Angle == 35 and Feet.Z < -6 then (-Feet.Z - 6) * math.tan(math.rad(Angle)) else 0
				LowestFeet = math.min(LowestFeet, Feet.Y - Origin.Y - Height)
				Elapsed += DeltaTime
				if Failure or Elapsed >= 1.2 then
					Before:Disconnect()
					After:Disconnect()
					Done:Fire()
				end
			end)
			Done.Event:Wait()
			Done:Destroy()
			assert(not Failure, tostring(Failure))
			if Angle == 35 then
				Check(Root.Position.Z < -30, "Actual physics can still travel up a legal slope")
			elseif Angle == 0 then
				Check(Root.Position.Z - Root.Size.Z * 0.5 > -11.91,
					"Actual 80 studs/s momentum cannot carry the horse through a thin wall: " .. Root.Position.Z)
			else
				Check(Root.Position.Z > Origin.Z - 6, "Actual physics stops before an unclimbable slope")
			end
			Check(LowestFeet > -0.6, "The feet cannot sink into the approach or " .. Angle .. " degree ramp: " .. LowestFeet)
			Check(Root.AssemblyLinearVelocity.Y < 65, "Stopping against a steep obstacle cannot launch the mount")
		end
	end)

	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorseObstaclePhysics: %d checks passed", Checks)
end
