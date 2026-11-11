return function(Grounding: any): string
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseObstacleTests"
	Fixture.Parent = workspace
	local Origin = Vector3.new(0, 7400, 0)
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
	local Wall = Instance.new("Part")
	Wall.Anchored = true
	Wall.Size = Vector3.new(100, 30, 0.2)
	Wall.CFrame = CFrame.new(Origin + Vector3.new(0, 10, -6))
	Wall.Parent = Fixture
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local Success, Error = pcall(function()
		for _, FPS in { 15, 30, 60, 120 } do
			for _, Speed in { 17.6, 44, 80 } do
				Root.CFrame = CFrame.new(Origin + Vector3.yAxis * 5)
				Root.AssemblyLinearVelocity = Vector3.zero
				local State = Grounding.Create(Model)
				Grounding.Update(State, 0)
				local Requested = Vector3.new(4, 0, -Speed)
				for _ = 1, FPS do
					-- Even if the motor cannot brake in one frame, it must never tunnel through a thin wall.
					Root.AssemblyLinearVelocity = Requested
					local Travel = Grounding.ConstrainMovement(State, Requested, 1 / FPS)
					Root.CFrame += Travel / FPS
					Grounding.Update(State, 1 / FPS)
					Check(Root.Position.Z - Root.Size.Z * 0.5 >= Wall.Position.Z + Wall.Size.Z * 0.5 - 0.01,
						"The full body stays in front of thin walls at " .. Speed .. " studs/s and " .. FPS .. " FPS")
				end
				Check(Root.Position.X > 3.9, "Blocking preserves motion along the wall")

				Root.CFrame = CFrame.new(Origin + Vector3.new(0, 5, -2))
				Grounding.Reset(State)
				Root.AssemblyLinearVelocity = Vector3.new(0, 0, -80)
				Grounding.ConstrainMovement(State, Vector3.zero, 0.1)
				Check(math.abs(Root.AssemblyLinearVelocity.Z) < 0.001,
					"Releasing input still brakes the existing wall-directed impulse")

				Root.CFrame = CFrame.new(Origin + Vector3.yAxis * 5)
				Grounding.Reset(State)
				Root.CFrame += Vector3.new(0, 0, -24)
				Root.AssemblyLinearVelocity = Vector3.new(0, 0, -80)
				Grounding.Update(State, 0.1)
				Check(Root.Position.Z - Root.Size.Z * 0.5 >= Wall.Position.Z + Wall.Size.Z * 0.5 - 0.01,
					"Sweeping the actual travelled path recovers a skipped physics frame")
			end
		end
		if game:GetService("PhysicsService"):IsCollisionGroupRegistered("LIMITS") then
			Wall.CollisionGroup = "LIMITS"
			Root.CFrame = CFrame.new(Origin + Vector3.yAxis * 5)
			Root.AssemblyLinearVelocity = Vector3.zero
			local State = Grounding.Create(Model)
			local Travel = Grounding.ConstrainMovement(State, Vector3.new(0, 0, -80), 0.1)
			Check(math.abs(Travel.Z) < 0.001, "World barriers use the character collision mask, including LIMITS")
			Wall.CollisionGroup = "Default"
		end
		Root.CFrame = CFrame.new(Origin + Vector3.new(0, 5, -2.3))
		Root.AssemblyLinearVelocity = Vector3.zero
		local Turning = Grounding.Create(Model)
		Root.CFrame *= CFrame.Angles(0, math.rad(20), 0)
		Grounding.Update(Turning, 1 / 60)
		for _, X in { -1, 1 } do
			for _, Z in { -1, 1 } do
				local Corner = Root.CFrame:PointToWorldSpace(Vector3.new(Root.Size.X * X * 0.5, 0, Root.Size.Z * Z * 0.5))
				Check(Corner.Z >= Wall.Position.Z + Wall.Size.Z * 0.5 - 0.01,
					"Turning beside a wall cannot rotate a body corner through it")
			end
		end
		Wall.CanCollide = false
		Root.CFrame = CFrame.new(Origin + Vector3.yAxis * 5)
		Root.AssemblyLinearVelocity = Vector3.zero
		local DecorationState = Grounding.Create(Model)
		Check(Grounding.ConstrainMovement(DecorationState, Vector3.new(0, 0, -80), 0.1).Z < -79,
			"Noncollidable decoration does not become an invisible barrier")
		Wall:Destroy()

		local Ramp = Instance.new("Part")
		Ramp.Anchored = true
		Ramp.Size = Vector3.new(100, 1, 60)
		Ramp.Parent = Fixture
		for _, Angle in { 35, 45, 55, 65, 80 } do
			local Pitch = math.rad(Angle)
			-- The upper face begins at z=-6, flush with the flat approach.
			Ramp.CFrame = CFrame.new(Origin + Vector3.new(0, math.sin(Pitch) * 30, -6 - math.cos(Pitch) * 30))
				* CFrame.Angles(Pitch, 0, 0) * CFrame.new(0, -0.5, 0)
			Root.CFrame = CFrame.new(Origin + Vector3.yAxis * 5)
			Root.AssemblyLinearVelocity = Vector3.zero
			local State = Grounding.Create(Model)
			Grounding.Update(State, 0)
			local Travel = Grounding.ConstrainMovement(State, Vector3.new(0, 0, -80), 0.1)
			if Angle <= 45 then
				Check(Travel.Z < -79, "Keep legal " .. Angle .. " degree hills climbable")
			else
				Check(math.abs(Travel.Z) < 0.001, "Block uphill entry into a " .. Angle .. " degree slope")
			end
		end
	end)

	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorseObstacle: %d checks passed", Checks)
end
