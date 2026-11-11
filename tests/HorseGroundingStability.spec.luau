return function(Grounding: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage.Shared.HorseConfig)
	local Origin = Vector3.new(0, 2800, 0)
	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseGroundingStabilityTests"
	Fixture.Parent = workspace
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(60, 2, 60)
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
	Root.CFrame = CFrame.new(Origin + Vector3.yAxis * 5)
	Root.Parent = Model
	Model.PrimaryPart = Root
	local Vertical = Instance.new("LinearVelocity")
	Vertical.Name = "MountGroundVelocity"
	Vertical.Enabled = false
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
		local State = Grounding.Create(Model)
		Grounding.Update(State, 0.1)
		Check(State.Grounded, "Start supported")
		Floor.Size = Vector3.new(1.2, 2, 60)
		Grounding.Reset(State)
		Grounding.Update(State, 0.1)
		Check(State.Grounded, "A narrow path under the body remains walkable when all corner rays miss")

		Floor.Size = Vector3.new(60, 2, 60)
		Root.CFrame = CFrame.new(Origin - Vector3.yAxis * 3)
		Root.AssemblyLinearVelocity = Vector3.new(0, -40, 0)
		Grounding.Reset(State)
		Grounding.Update(State, 0.1)
		Check(State.Grounded and Root.Position.Y >= Origin.Y + 4.9, "Recover a horse buried deeper than the step limit")
		Check(Root.AssemblyLinearVelocity.Y <= 0.001 and math.abs(Vertical.LineVelocity) < 0.01,
			"Depenetration does not create launch velocity")
		Check(Vertical.ForceLimitsEnabled and Vertical.MaxForce < math.huge, "Suspension force stays finite")

		local Roof = Instance.new("Part")
		Roof.Anchored = true
		Roof.Size = Vector3.new(30, 1, 30)
		Roof.Position = Origin + Vector3.yAxis * 5.5
		Roof.Parent = Fixture
		Grounding.Reset(State)
		Grounding.Update(State, 0.1)
		Check(State.Grounded and State.PlanePoint.Y < Origin.Y + 0.01, "An overhead surface does not replace the actual floor")
		Check(math.abs(Vertical.LineVelocity) < 0.01, "A low roof cannot trigger an upward correction")
		Root.CFrame = CFrame.new(Origin - Vector3.yAxis * 3)
		Grounding.Reset(State)
		Grounding.Update(State, 0.1)
		Check(State.PlanePoint.Y < Origin.Y + 0.01 and Root.Position.Y < Origin.Y + 5.1,
			"Recovery skips the roof and chooses the lower floor")
		Roof:Destroy()

		local Step = Instance.new("Part")
		Step.Anchored = true
		Step.Size = Vector3.new(20, 2.5, 30)
		Step.Position = Origin + Vector3.new(10.25, 1.25, 0)
		Step.Parent = Fixture
		Grounding.Reset(State)
		Grounding.Update(State, 0.1)
		Check(State.Normal.Y > 0.999 and State.PlanePoint.Y < Origin.Y + 0.01,
			"Different corner heights do not create a fictitious support plane")
		Check(math.abs(Vertical.LineVelocity) < 0.01, "A ledge next to the body does not lift it")
		Step:Destroy()

		-- Move just the body beyond an edge while two rear corners remain above the platform.
		Floor.Size = Vector3.new(60, 2, 20)
		Floor.Position = Origin + Vector3.new(0, -1, 10)
		Root.CFrame = CFrame.new(Origin + Vector3.new(0, 5, 1))
		Grounding.Reset(State)
		Grounding.Update(State, 0.1)
		Check(State.Grounded, "Support the body before an edge")
		Root.CFrame += Vector3.new(0, 0, -2)
		Root.AssemblyLinearVelocity = Vector3.new(0, 60, -20)
		Grounding.Update(State, 0.001)
		Check(not State.Grounded and not Vertical.Enabled, "Recheck fast travel and release the body at the edge")
		Check(Root.AssemblyLinearVelocity.Y <= Config.Grounding.MaximumReleaseSpeed,
			"A climb impulse cannot become flight after losing support")

		Floor:Destroy()
		Root.AssemblyLinearVelocity = Vector3.new(0, -25, 0)
		Grounding.Update(State, 0.1)
		Check(Root.AssemblyLinearVelocity.Y == -25 and not Vertical.Enabled, "Airborne falling velocity remains free")
	end)

	Fixture:Destroy()
	assert(Success, tostring(Error))
	return string.format("HorseGroundingStability: %d checks passed", Checks)
end
