return function(Grounding: any, Avoidance: any, Steering: any): string
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseAvoidanceTests"
	Fixture.Parent = workspace
	local Origin = Vector3.new(0, 8200, 0)
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(1000, 2, 2000)
	Floor.Position = Origin - Vector3.yAxis
	Floor.Parent = Fixture
	local Wall = Instance.new("Part")
	Wall.Anchored = true
	Wall.Size = Vector3.new(16, 30, 2)
	Wall.Position = Origin + Vector3.new(0, 10, -30)
	Wall.Parent = Fixture
	local Model = Instance.new("Model")
	Model:SetAttribute("GroundClearance", 5)
	Model:SetAttribute("GroundHalfWidth", 1)
	Model:SetAttribute("GroundHalfLength", 3)
	Model.Parent = Fixture
	local Root = Instance.new("Part")
	Root.Anchored = true
	Root.CanCollide = false
	Root.Size = Vector3.new(2.5, 5.5, 7)
	Root.Parent = Model
	Model.PrimaryPart = Root
	local Vertical = Instance.new("LinearVelocity")
	Vertical.Name = "MountGroundVelocity"
	Vertical.Parent = Root
	local Orientation = Instance.new("AlignOrientation")
	Orientation.Name = "MountOrientation"
	Orientation.Parent = Root
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local Success, Error = pcall(function()
		for _, FPS in { 30, 60, 120 } do
			for _, Speed in { 17.6, 32, 80 } do
				Root.CFrame = CFrame.new(Origin + Vector3.new(0, 5, 30))
				Root.AssemblyLinearVelocity = Vector3.new(0, 0, -Speed)
				Orientation.CFrame = CFrame.identity
				local Ground = Grounding.Create(Model)
				local Steer = Steering.Create(Root.CFrame, Root.AssemblyLinearVelocity)
				local Avoid = Avoidance.Create()
				local MaximumSide, MinimumSpeed = 0, math.huge
				local Stats = { Speed = Speed, Acceleration = 40, TurnSpeed = 7 }
				for _ = 1, FPS * 12 do
					Grounding.Update(Ground, 1 / FPS)
					local Direction, Multiplier = Avoidance.Update(Avoid, Ground, -Vector3.zAxis, Speed, 1 / FPS)
					local Movement = Steering.Update(Steer, Root.CFrame, Root.AssemblyLinearVelocity,
						Direction, Stats, 1 / FPS, true, nil, Multiplier)
					local Travel = Grounding.ConstrainMovement(Ground, Movement, 1 / FPS)
					Ground.Heading = Steer.Heading
					Grounding.Update(Ground, 1 / FPS)
					local Rotation = Root.CFrame.Rotation:Lerp(Orientation.CFrame, 1 - math.exp(-20 / FPS))
					Root.CFrame = CFrame.new(Root.Position + Travel / FPS) * Rotation
					Root.AssemblyLinearVelocity = Travel
					Grounding.Update(Ground, 0)
					MaximumSide = math.max(MaximumSide, math.abs(Root.Position.X))
					MinimumSpeed = math.min(MinimumSpeed, Travel.Magnitude)
				end
				Check(MaximumSide > 10, "Steering must find a route beside the obstacle")
				Check(Root.Position.Z < Origin.Z - 45, "The detour must actually pass the obstacle at " .. Speed .. "/" .. FPS .. ": " .. tostring(Root.Position))
				Check(MinimumSpeed > 0.5, "An open detour must not become a complete stop: " .. MinimumSpeed)
				Check(Avoid.Weight < 0.05 and Avoid.SpeedMultiplier > 0.95, "Clear ground restores the player's course and speed")
			end
		end

		Root.CFrame = CFrame.new(Origin + Vector3.new(0, 5, -20))
		local Ground = Grounding.Create(Model)
		Grounding.Update(Ground, 0.1)
		local Avoid = Avoidance.Create()
		for _ = 1, 120 do
			Avoidance.Update(Avoid, Ground, -Vector3.zAxis, 32, 1 / 60)
		end
		local Direction = Avoidance.Update(Avoid, Ground, Vector3.zero, 32, 1 / 60)
		Check(Direction.Magnitude == 0, "Obstacle avoidance cannot move a horse with no movement input")
	end)

	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorseAvoidance: %d checks passed", Checks)
end
