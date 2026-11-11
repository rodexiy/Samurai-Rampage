return function(Grounding: any): string
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage.Shared.HorseConfig)
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	for _, Angle in { -45, -25, 0, 25, 45 } do
		local Normal = CFrame.Angles(math.rad(Angle), 0, 0).UpVector
		local Rotation = Grounding.GetRotation(-Vector3.zAxis, Normal)
		Check(Rotation.UpVector:Dot(Normal) > 0.999, "The complete mount follows a " .. Angle .. " degree hill")
		local Height = Grounding.GetHeight(Vector3.zero, Vector3.zero, Normal, 5)
		local Frame = CFrame.new(0, Height, 0) * Rotation
		Check(math.abs(Normal:Dot(Frame:PointToWorldSpace(Vector3.new(0, -5, 0)))) < 0.001,
			"Slope compensation keeps the hoof plane on the ground")
		local RiderFrame = Frame * Config.RiderOffset
		Check(RiderFrame.UpVector:Dot(Frame.UpVector) > 0.9999, "The welded rider shares the complete mount's tilt")
	end
	local Limited = Grounding.GetRotation(-Vector3.zAxis, CFrame.Angles(math.rad(80), 0, 0).UpVector)
	Check(math.abs(math.asin(Limited.LookVector.Y)) <= Config.Grounding.MaximumPitch + 0.001, "Limit extreme pitch")
	Check(Grounding.HorizontalDirection(Vector3.yAxis) == -Vector3.zAxis, "Vertical headings have a finite fallback")

	local Fixture = Instance.new("Folder")
	Fixture.Name = "HorseGroundingTests"
	Fixture.Parent = workspace
	local Origin = Vector3.new(0, 2500, 0)
	local Floor = Instance.new("Part")
	Floor.Anchored = true
	Floor.Size = Vector3.new(120, 2, 120)
	Floor.CFrame = CFrame.new(Origin - Vector3.yAxis)
	Floor.Parent = Fixture
	local Model = Instance.new("Model")
	Model:SetAttribute("GroundClearance", 5)
	Model:SetAttribute("GroundHalfWidth", 1)
	Model:SetAttribute("GroundHalfLength", 3)
	Model.Parent = Fixture
	local Root = Instance.new("Part")
	Root.Size = Vector3.new(2.5, 5.5, 7)
	Root.CanCollide = false
	Root.Anchored = true
	Root.CFrame = CFrame.new(Origin + Vector3.yAxis * 5)
	Root.Parent = Model
	Model.PrimaryPart = Root
	local Vertical = Instance.new("LinearVelocity")
	Vertical.Name = "MountGroundVelocity"
	Vertical.Parent = Root
	local Orientation = Instance.new("AlignOrientation")
	Orientation.Name = "MountOrientation"
	Orientation.Parent = Root

	local Success, Error = pcall(function()
		local State = Grounding.Create(Model)
		Check(State ~= nil, "Build the common client/server suspension state")
		Grounding.Update(State, 0.1)
		Check(State.Grounded and Vertical.Enabled, "A nearby floor supplies vertical support")
		Check(math.abs(Vertical.LineVelocity) < 0.001, "Support does not drift on a flat floor")

		Floor.CFrame *= CFrame.Angles(math.rad(35), 0, 0)
		local Normal = Floor.CFrame.UpVector
		local PlanePoint = Floor.CFrame:PointToWorldSpace(Vector3.yAxis)
		Root.CFrame = CFrame.new(0, Grounding.GetHeight(Origin, PlanePoint, Normal, 5), 0)
		Grounding.Reset(State)
		Grounding.Update(State, 1)
		Check(State.Grounded, "Probe a steep hill without physical floor collision")
		Check(State.Normal:Dot(Normal) > 0.999, "The four support probes reconstruct the slope")
		Check(Orientation.CFrame.UpVector:Dot(Normal) > 0.999, "Tilt beyond the old ten-degree visual limit")

		Floor.CFrame = CFrame.new(Origin - Vector3.yAxis)
		Root.CFrame = CFrame.new(Origin + Vector3.yAxis * 5)
		Grounding.Reset(State)
		Grounding.Update(State, 0.1)
		Floor.CFrame += Vector3.yAxis * 0.5
		Grounding.Update(State, 0.001)
		Check(Root.Position.Y >= Origin.Y + 5.49 and math.abs(Vertical.LineVelocity) < 0.01,
			"Moving supports update between samples without adding launch velocity")

		local Wall = Instance.new("Part")
		Wall.Anchored = true
		Wall.Size = Vector3.new(20, 20, 1)
		Wall.CFrame = Root.CFrame * CFrame.new(0, 0, -5)
		Wall.Parent = Fixture
		local Travel = Grounding.ConstrainMovement(State, Vector3.new(4, 0, -32), 0.1)
		Check(math.abs(Travel.Z) < 0.001 and Travel.X == 4, "Walls block forward travel while preserving wall sliding")
		Wall:Destroy()

		local Bank = Config.Steering.MaximumBank
		Grounding.Update(State, 1, nil, nil, -Bank)
		Check(Orientation.CFrame.UpVector.X > 0.05, "A right curve banks the whole mount toward the right")
		local RiderFrame = Orientation.CFrame * Config.RiderOffset
		Check(RiderFrame.UpVector:Dot(Orientation.CFrame.UpVector) > 0.9999, "The rider shares the curve bank")
		Grounding.Update(State, 1, nil, nil, Bank)
		Check(Orientation.CFrame.UpVector.X < -0.05, "A left curve banks the whole mount toward the left")
		Grounding.Update(State, 1)
		Check(Orientation.CFrame.UpVector.Y > 0.9999, "Idle support removes the corner bank")

		Root.CFrame += Vector3.yAxis * 40
		Grounding.Reset(State)
		Grounding.Update(State, 1, nil, nil, Bank)
		Check(not State.Grounded and not Vertical.Enabled, "Leave vertical velocity free for gravity above a drop")
		Check(Orientation.CFrame.UpVector.Y > 0.9999, "An airborne horse cannot retain a ground corner bank")
		Floor:Destroy()
		Grounding.Reset(State)
		Grounding.Update(State, 0.1)
		Check(not Vertical.Enabled, "An absent floor cannot keep the horse hovering")
	end)

	Fixture:Destroy()
	assert(Success, tostring(Error))
	return string.format("HorseGrounding: %d checks passed", Checks)
end
