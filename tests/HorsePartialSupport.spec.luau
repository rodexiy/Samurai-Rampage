return function(Grounding: any): string
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorsePartialSupportTests"
	Fixture.Parent = workspace
	local Origin = Vector3.new(0, 8700, 0)
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
		for _, Angle in { -55, -35, 0, 35, 55, 65 } do
			local Plane = CFrame.new(Origin) * CFrame.Angles(math.rad(Angle), 0, 0)
			local Normal = Plane.UpVector
			local Rotation = Grounding.GetRotation(-Vector3.zAxis, Normal)
			local Height = Grounding.GetHeight(Origin, Origin, Normal, 5, Rotation.UpVector)
			Root.CFrame = CFrame.new(0, Height, 0) * Rotation
			local Patches = {}
			for Index, Offset in { Vector3.new(-1, -5, -3), Vector3.new(1, -5, -3), Vector3.new(-1, -5, 3) } do
				local Point = Root.CFrame:PointToWorldSpace(Offset)
				Point = Vector3.new(Point.X, Grounding.GetHeight(Point, Origin, Normal, 0), Point.Z)
				local Patch = Instance.new("Part")
				Patch.Anchored = true
				Patch.Size = Vector3.new(0.7, 0.2, 0.7)
				Patch.CFrame = CFrame.new(Point - Normal * 0.1) * Plane.Rotation
				Patch.Parent = Fixture
				Patches[Index] = Patch
			end
			local State = Grounding.Create(Model)
			Grounding.Update(State, 0.1)
			Check(State.Grounded and Vertical.Enabled, "Three foot contacts must support a missing center sample at " .. Angle .. " degrees")
			Check(State.Normal:Dot(Normal) > 0.999, "Partial support must retain the actual rock's normal")
			local Feet = Root.Position - Root.CFrame.UpVector * 5
			Check((Feet - Origin):Dot(Normal) > -0.1, "Detaching the center must not bury the foot plane")
			if math.abs(Angle) > 50 then
				Check(not Grounding.IsWalkable(Normal) and Grounding.IsSupportable(Normal), "Bracing on a rock does not permit climbing it")
			end
			for _, Patch in Patches do
				Patch:Destroy()
			end
			Grounding.Update(State, 0.1)
			Check(not State.Grounded and not Vertical.Enabled, "Losing every foot contact must still release gravity")
		end
	end)

	Fixture:Destroy()
	assert(Success, tostring(Error))

	return string.format("HorsePartialSupport: %d checks passed", Checks)
end
