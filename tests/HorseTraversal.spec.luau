return function(Grounding: any): string
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseTraversalTests"
	Fixture.Parent = workspace
	local Origin = Vector3.new(0, 10700, 0)
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(200, 2, 200)
	Floor.Position = Origin - Vector3.yAxis
	Floor.Parent = Fixture
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
	local Obstacle = Instance.new("Part")
	Obstacle.Anchored = true
	Obstacle.Parent = Fixture
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local Success, Error = pcall(function()
		for _, Height in { 0.15, 0.5, 0.8, 1.2 } do
			Obstacle.Size = Vector3.new(10, Height, 1.5)
			Obstacle.Position = Origin + Vector3.yAxis * Height * 0.5
			Root.CFrame = CFrame.new(Origin + Vector3.yAxis * 5)
			Root.AssemblyLinearVelocity = Vector3.zero
			local State = Grounding.Create(Model)
			Grounding.Update(State, 0.1)
			Check(State.Grounded and State.Support == Floor, "A short low object must leave the body supported by the base floor")
			Check(math.abs(Root.Position.Y - Origin.Y - 5) < 0.1, "Stepping over a small object must not lift the whole mount")
		end
		Obstacle.Size = Vector3.new(20, 0.8, 20)
		Obstacle.Position = Origin + Vector3.yAxis * 0.4
		Root.CFrame = CFrame.new(Origin + Vector3.yAxis * 5)
		local PlatformState = Grounding.Create(Model)
		Grounding.Update(PlatformState, 0.1)
		Check(PlatformState.Support == Obstacle and Root.Position.Y > Origin.Y + 5.7,
			"A broad platform must still become real support")

		Obstacle.Size = Vector3.new(20, 1.2, 1)
		Obstacle.Position = Origin + Vector3.new(0, 0.6, -5)
		Root.CFrame = CFrame.new(Origin + Vector3.yAxis * 4.8) * CFrame.Angles(math.rad(-45), 0, 0)
		Root.AssemblyLinearVelocity = Vector3.zero
		local State = Grounding.Create(Model)
		Grounding.Update(State, 0)
		Check(Grounding.ConstrainMovement(State, Vector3.new(0, 0, -32), 0.1).Z < -31,
			"A low edge must not block a body that is still pitched down after leaving a ramp")
		local Wall = Instance.new("Part")
		Wall.Anchored = true
		Wall.Size = Vector3.new(50, 30, 1)
		Wall.Position = Origin + Vector3.new(0, 10, -8)
		Wall.Parent = Fixture
		Check(math.abs(Grounding.ConstrainMovement(State, Vector3.new(0, 0, -80), 0.1).Z) < 0.001,
			"Stepping over an edge must not hide a wall behind it")
		Wall:Destroy()
		Obstacle:Destroy()

		for _, Pitch in { -50, -35, 35, 50 } do
			Root.CFrame = CFrame.new(Origin + Vector3.yAxis * 3) * CFrame.Angles(math.rad(Pitch), 0, 0)
			Grounding.Reset(State)
			Grounding.Update(State, 0.1)
			for _, X in { -1, 1 } do
				for _, Z in { -1, 1 } do
					local Corner = Root.CFrame:PointToWorldSpace(Vector3.new(Root.Size.X * X * 0.5, -Root.Size.Y * 0.5, Root.Size.Z * Z * 0.5))
					Check(Corner.Y >= Origin.Y - 0.01, "Landing with a tilted body must preserve chest clearance")
				end
			end
		end
	end)

	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorseTraversal: %d checks passed", Checks)
end
