return function(Grounding: any, Avoidance: any): string
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseAvoidanceTerrainTests"
	Fixture.Parent = workspace
	local Origin = Vector3.new(0, 17400, 0)
	local Geometry = Instance.new("Folder")
	Geometry.Parent = Fixture
	local function Part(Position: Vector3, Size: Vector3, Pitch: number?): Part
		local Object = Instance.new("Part")
		Object.Anchored = true
		Object.Size = Size
		Object.CFrame = CFrame.new(Origin + Position) * CFrame.Angles(Pitch or 0, 0, 0)
		Object.Parent = Geometry

		return Object
	end
	Part(-Vector3.yAxis, Vector3.new(500, 2, 500))
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
	local function Ground(Position: Vector3, Heading: Vector3?): any
		Root.CFrame = CFrame.new(Origin + Position) * CFrame.lookAt(Vector3.zero, Heading or -Vector3.zAxis)
		Root.AssemblyLinearVelocity = Vector3.zero
		local State = Grounding.Create(Model)
		Grounding.Update(State, 0.1)
		Check(State.Grounded, "The route starts on solid ground")

		return State
	end
	local function ClearRoute(Position: Vector3, Name: string, Heading: Vector3?)
		local Direction = Heading or -Vector3.zAxis
		local State = Ground(Position, Direction)
		local Distance, Normal, Supported = Grounding.ScanMovement(State, Direction, 85, 10)
		Check(Normal == nil and Distance > 84.9 and Supported,
			Name .. " must remain traversable throughout the long preview: " .. Distance .. ", " .. tostring(Normal))
		for _, Speed in { 17.6, 32, 80 } do
			local Avoid = Avoidance.Create()
			for _ = 1, 30 do
				local Movement, Multiplier = Avoidance.Update(Avoid, State, Direction, Speed, 1 / 60)
				Check(Movement:Dot(Direction) > 0.999 and Multiplier > 0.999,
					Name .. " must not turn or slow the horse")
			end
		end
	end

	local Success, Error = pcall(function()
		local Wall = Part(Vector3.new(0, 15, -72), Vector3.new(16, 40, 2))
		local State = Ground(Vector3.new(0, 5, 0))
		local Distance, Normal = Grounding.ScanMovement(State, -Vector3.zAxis, 90)
		Check(Normal ~= nil and Distance > 60 and Distance < 72, "Detect a real wall beyond the old 45-stud preview")
		local Avoid = Avoidance.Create()
		for _ = 1, 30 do
			Avoidance.Update(Avoid, State, -Vector3.zAxis, 80, 1 / 60)
		end
		Check(Avoid.Weight > 0.8, "Running must start turning before reaching the old preview distance")
		Wall:Destroy()

		for Index = 1, 20 do
			local Height = Index * 0.65
			Part(Vector3.new(0, Height * 0.5, -9 - Index * 3), Vector3.new(14, Height, 3))
		end
		Part(Vector3.new(0, 6.5, -105), Vector3.new(14, 13, 72))
		ClearRoute(Vector3.new(0, 5, 0), "Staircase entrance")
		ClearRoute(Vector3.new(0, 8.25, -24), "Middle of staircase")
		ClearRoute(Vector3.new(0, 18, -78), "Descending staircase", Vector3.zAxis)
		Wall = Part(Vector3.new(0, 23, -80), Vector3.new(14, 20, 2))
		State = Ground(Vector3.new(0, 5, 0))
		Distance, Normal = Grounding.ScanMovement(State, -Vector3.zAxis, 90)
		Check(Normal ~= nil and Distance > 65 and Distance < 80, "Following the steps must not hide a wall on the upper landing")
		Wall:Destroy()
		Geometry:ClearAllChildren()
		Part(-Vector3.yAxis, Vector3.new(500, 2, 500))

		local Angle = math.rad(25)
		Part(Vector3.new(0, 9, -35), Vector3.new(14, 1, 40), Angle)
		Part(Vector3.new(0, 17.4, -95), Vector3.new(14, 1, 84))
		for _, Side in { -1, 1 } do
			Part(Vector3.new(Side * 7.8, 19.5, -95), Vector3.new(1, 4, 84))
		end
		ClearRoute(Vector3.new(0, 5, 0), "Raised bridge ramp and deck")
		ClearRoute(Vector3.new(0, 22.9, -75), "Narrow bridge between railings")
		ClearRoute(Vector3.new(0, 22.9, -75), "Descending bridge ramp", Vector3.zAxis)

		Geometry:ClearAllChildren()
		Part(-Vector3.yAxis, Vector3.new(500, 2, 500))
		local Ramp = Part(Vector3.new(0, 9, -35), Vector3.new(20, 1, 40), math.rad(65))
		State = Ground(Vector3.new(0, 5, 0))
		Distance, Normal = Grounding.ScanMovement(State, -Vector3.zAxis, 85)
		Check(Normal ~= nil and Normal.Y < 0.5 and Distance < 40, "A genuinely steep uphill face still triggers a detour")

		local Plane = Ramp.CFrame:PointToWorldSpace(Vector3.yAxis * 0.5)
		local Slope = Ramp.CFrame.UpVector
		local Position = Origin + Vector3.new(0, 0, -39)
		local Height = Grounding.GetHeight(Position, Plane, Slope, 5)
		Root.CFrame = CFrame.new(Position.X, Height, Position.Z) * Grounding.GetRotation(Vector3.zAxis, Slope, true)
		State = Grounding.Create(Model)
		Grounding.Update(State, 0.1)
		Distance, Normal = Grounding.ScanMovement(State, Vector3.zAxis, 80, 10)
		Check(Normal == nil and Distance > 79.9, "A supported steep descent must not be mistaken for an uphill barrier")
	end)

	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorseAvoidanceTerrain: %d checks passed", Checks)
end
