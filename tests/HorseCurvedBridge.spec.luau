return function(Grounding: any): string
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseCurvedBridgeTests"
	Fixture.Parent = workspace
	local Origin = Vector3.new(0, 14000, 0)
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
		-- Narrow planks leave real gaps while their normals change along the arch.
		for Index = -12, 12 do
			local Z = Index * 3.2
			local Angle = math.atan(0.015 * Z)
			local Plank = Instance.new("Part")
			Plank.Anchored = true
			Plank.Size = Vector3.new(30, 0.5, 2.8 / math.cos(Angle))
			Plank.CFrame = CFrame.new(Origin + Vector3.new(0, 12 - 0.0075 * Z * Z, Z))
				* CFrame.Angles(Angle, 0, 0) * CFrame.new(0, -0.25, 0)
			Plank.Parent = Fixture
		end

		for _, Direction in { -1, 1 } do
			local State = Grounding.Create(Model)
			for Index = -180, 180 do
				local Z = Index * 0.2 * Direction
				local Normal = Vector3.new(0, 1, 0.015 * Z).Unit
				local Point = Origin + Vector3.new(0, 12 - 0.0075 * Z * Z, Z)
				local Heading = Vector3.zAxis * Direction
				Root.CFrame = CFrame.new(Point + Normal * 5) * Grounding.GetRotation(Heading, Normal)
				Root.AssemblyLinearVelocity = Heading * 32
				State.Heading = Heading
				if Index == -180 then
					Grounding.Reset(State)
				end
				local Before = Root.Position
				Grounding.Update(State, 1 / 60)
				Check(State.Grounded, "An arched plank bridge keeps support across seams at z=" .. Z)
				Check((Root.Position - Before).Magnitude < 0.5,
					"A bridge seam cannot teleport the mount at z=" .. Z .. ": " .. tostring(Root.Position - Before))
				local Velocity = Grounding.ConstrainMovement(State, Heading * 32, 1 / 60)
				Check(Velocity:Dot(Heading) > 31, "A bridge seam cannot trap the mount at z=" .. Z)
				if Index % 20 == 0 and Index < 120 then
					local Distance, Obstacle, Supported = Grounding.ScanMovement(State, Heading, 6, 6)
					Check(Distance > 5.99 and Obstacle == nil and Supported,
						"Avoidance must follow the arched deck across its seams at z=" .. Z)
				end
			end
		end
	end)

	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorseCurvedBridge: %d checks passed", Checks)
end
