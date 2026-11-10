local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)

type RotationState = {
	Viewport: ViewportFrame,
	Camera: Camera,
	Model: Model,
	Input: InputObject?,
	LastPosition: Vector2,
	Center: CFrame,
	PivotOffset: CFrame,
	CurrentRotation: CFrame,
	TargetRotation: CFrame,
}

local ViewportRotationController = Knit.CreateController({
	Name = "ViewportRotationController",
})

local ROTATION_PER_VIEWPORT = math.pi * 2
local ROTATION_RESPONSE = 24
local ROTATION_EPSILON = 0.0001

local ActiveRotation: RotationState? = nil
local RenderConnection: RBXScriptConnection? = nil
local BoundViewports: { [ViewportFrame]: boolean } = setmetatable({}, { __mode = "k" })

function ViewportRotationController:StopRotation(Viewport: ViewportFrame?)
	if not Viewport or (ActiveRotation and ActiveRotation.Viewport == Viewport) then
		ActiveRotation = nil

		if RenderConnection then
			RenderConnection:Disconnect()
			RenderConnection = nil
		end
	end
end

function ViewportRotationController:RenderRotation(DeltaTime: number)
	local State = ActiveRotation
	if not State then
		return
	end

	if not State.Model.Parent or State.Viewport.CurrentCamera ~= State.Camera then
		self:StopRotation()
		return
	end

	if not State.CurrentRotation:FuzzyEq(State.TargetRotation, ROTATION_EPSILON) then
		local Alpha = 1 - math.exp(-ROTATION_RESPONSE * DeltaTime)
		State.CurrentRotation = State.CurrentRotation:Lerp(State.TargetRotation, Alpha)
		if State.CurrentRotation:FuzzyEq(State.TargetRotation, ROTATION_EPSILON) then
			State.CurrentRotation = State.TargetRotation
		end

		State.Model:PivotTo(State.Center * State.CurrentRotation * State.PivotOffset)
	end

	if not State.Input and State.CurrentRotation:FuzzyEq(State.TargetRotation, ROTATION_EPSILON) then
		self:StopRotation()
	end
end

function ViewportRotationController:BeginRotation(Viewport: ViewportFrame, Input: InputObject): boolean
	if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then
		return false
	end

	if ActiveRotation and ActiveRotation.Input then
		return false
	end

	local Camera = Viewport.CurrentCamera
	local Model = Viewport:FindFirstChildWhichIsA("Model")
	if not Camera or not Model then
		return false
	end

	local Bounds = Model:GetBoundingBox()
	local Center = CFrame.new(Bounds.Position)
	self:StopRotation()

	ActiveRotation = {
		Viewport = Viewport,
		Camera = Camera,
		Model = Model,
		Input = Input,
		LastPosition = Vector2.new(Input.Position.X, Input.Position.Y),
		Center = Center,
		PivotOffset = Center:ToObjectSpace(Model:GetPivot()),
		CurrentRotation = CFrame.identity,
		TargetRotation = CFrame.identity,
	}
	RenderConnection = RunService.PreRender:Connect(function(DeltaTime: number)
		self:RenderRotation(DeltaTime)
	end)

	return true
end

function ViewportRotationController:UpdateRotation(Input: InputObject)
	local State = ActiveRotation
	if not State or not State.Input then
		return
	end

	if not State.Model.Parent or State.Viewport.CurrentCamera ~= State.Camera then
		self:StopRotation()
		return
	end

	local IsMouseDrag = State.Input.UserInputType == Enum.UserInputType.MouseButton1
		and Input.UserInputType == Enum.UserInputType.MouseMovement
	if not IsMouseDrag and Input ~= State.Input then
		return
	end

	local Position = Vector2.new(Input.Position.X, Input.Position.Y)
	local Delta = Position - State.LastPosition
	State.LastPosition = Position
	if Delta.Magnitude == 0 then
		return
	end

	local ViewportSize = math.min(State.Viewport.AbsoluteSize.X, State.Viewport.AbsoluteSize.Y)
	local ReferenceSize = if ViewportSize > 0 then ViewportSize else 400
	local Angle = Delta.Magnitude / ReferenceSize * ROTATION_PER_VIEWPORT
	local Axis = State.Camera.CFrame.UpVector * Delta.X + State.Camera.CFrame.RightVector * Delta.Y
	local Rotation = CFrame.fromAxisAngle(Axis.Unit, Angle)
	State.TargetRotation = Rotation * State.TargetRotation
end

function ViewportRotationController:EndRotation(Input: InputObject)
	local State = ActiveRotation
	if not State or not State.Input then
		return
	end

	if Input == State.Input or (Input.UserInputType == Enum.UserInputType.MouseButton1
		and State.Input.UserInputType == Enum.UserInputType.MouseButton1) then
		State.Input = nil
	end
end

function ViewportRotationController:BindViewport(Viewport: ViewportFrame)
	if BoundViewports[Viewport] then
		return
	end

	BoundViewports[Viewport] = true
	Viewport.Active = true
	Viewport.InputBegan:Connect(function(Input: InputObject)
		self:BeginRotation(Viewport, Input)
	end)
	Viewport.Destroying:Connect(function()
		self:StopRotation(Viewport)
	end)
end

function ViewportRotationController.KnitStart()
	UserInputService.InputChanged:Connect(function(Input: InputObject)
		ViewportRotationController:UpdateRotation(Input)
	end)
	UserInputService.InputEnded:Connect(function(Input: InputObject)
		ViewportRotationController:EndRotation(Input)
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		ViewportRotationController:StopRotation()
	end)
end

return ViewportRotationController
