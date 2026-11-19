local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local RealmGizmoController = Knit.CreateController({ Name = "RealmGizmoController" })
local Began = Instance.new("BindableEvent")
local Dragged = Instance.new("BindableEvent")
RealmGizmoController.Began = Began.Event
RealmGizmoController.Dragged = Dragged.Event

type Segment = { Button: TextButton, Line: Frame, Axis: number, First: Vector3, Last: Vector3, Tip: boolean }
type DragState = {
	Input: InputObject, Axis: number, Direction: Vector3, Center: Vector3,
	Start: Vector2, ScreenDirection: Vector2, PixelsPerStud: number,
	Coordinate: number?, Radial: Vector3?, LastAngle: number, Angle: number,
}

local COLORS = { Color3.fromRGB(245, 75, 75), Color3.fromRGB(90, 225, 115), Color3.fromRGB(80, 150, 255) }
local LABELS = { "X", "Y", "Z" }
local SEGMENTS = 40
local MIN_RADIUS = 0.5
local MAX_RADIUS = 10
local Gui: ScreenGui? = nil
local Mode = "Move"
local Segments: { Segment } = {}
local Frame = CFrame.identity
local Axes = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }
local Radius = 5
local Drag: DragState? = nil
local LastCameraFrame: CFrame? = nil
local LastViewport = Vector2.zero
local LastFieldOfView = 0
local LastDragAxis = 0

local function Project(Point: Vector3): (Vector2, boolean)
	local Camera = workspace.CurrentCamera
	if not Camera then
		return Vector2.zero, false
	end
	local Screen = Camera:WorldToViewportPoint(Point)

	return Vector2.new(Screen.X, Screen.Y), Screen.Z > 0.1
end

local function GetRay(Position: Vector2): Ray?
	local Camera = workspace.CurrentCamera

	return if Camera then Camera:ViewportPointToRay(Position.X, Position.Y) else nil
end

local function AxisCoordinate(Ray: Ray, Center: Vector3, Direction: Vector3): number?
	local Dot = Ray.Direction:Dot(Direction)
	local Denominator = 1 - Dot * Dot
	if Denominator < 0.01 then
		return nil
	end
	local Offset = Ray.Origin - Center

	return (Offset:Dot(Direction) - Offset:Dot(Ray.Direction) * Dot) / Denominator
end

local function PlaneRadial(Ray: Ray, Center: Vector3, Normal: Vector3): Vector3?
	local Dot = Ray.Direction:Dot(Normal)
	if math.abs(Dot) < 0.03 then
		return nil
	end
	local Distance = (Center - Ray.Origin):Dot(Normal) / Dot
	local Radial = Ray.Origin + Ray.Direction * Distance - Center

	return if Distance > 0 and Radial.Magnitude > 0.01 then Radial.Unit else nil
end

local function BeginDrag(Segment: Segment, Input: InputObject)
	if Drag or (Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch) then
		return
	end
	local Position = if Input.UserInputType == Enum.UserInputType.Touch
		then Vector2.new(Input.Position.X, Input.Position.Y) else UserInputService:GetMouseLocation()
	local Ray = GetRay(Position)
	if not Ray then
		return
	end
	local Direction = Axes[Segment.Axis]
	local Center = Frame.Position
	local Radial = PlaneRadial(Ray, Center, Direction)
	local Tangent = if Mode == "Rotate" then Direction:Cross((Segment.First - Center).Unit) else Direction
	local StartPoint = if Mode == "Rotate" then Segment.First else Center
	local First = Project(StartPoint)
	local Last = Project(StartPoint + Tangent)
	local ScreenDirection = Last - First
	Drag = {
		Input = Input, Axis = Segment.Axis, Direction = Direction, Center = Center,
		Start = Position, ScreenDirection = if ScreenDirection.Magnitude > 0.01 then ScreenDirection.Unit else Vector2.xAxis,
		PixelsPerStud = math.max(ScreenDirection.Magnitude, 1),
		Coordinate = AxisCoordinate(Ray, Center, Direction), Radial = Radial, LastAngle = 0, Angle = 0,
	}
	Began:Fire(Segment.Axis)
end

function RealmGizmoController:IsDragging(): boolean
	return Drag ~= nil
end

function RealmGizmoController:Hide()
	Drag = nil
	LastCameraFrame = nil
	if Gui then
		Gui:Destroy()
		Gui = nil
	end
	table.clear(Segments)
end

local function AddSegment(Axis: number, Tip: boolean)
	local Button = Instance.new("TextButton")
	Button.Name = LABELS[Axis] .. (if Tip then "Arrow" else "Handle")
	Button.AnchorPoint = Vector2.one / 2
	Button.BackgroundTransparency = 1
	Button.AutoButtonColor = false
	Button.Text = ""
	Button.ZIndex = 2
	Button.Parent = Gui
	local Line = Instance.new("Frame")
	Line.Name = "Line"
	Line.AnchorPoint = Vector2.one / 2
	Line.Position = UDim2.fromScale(0.5, 0.5)
	Line.BackgroundColor3 = COLORS[Axis]
	Line.BorderSizePixel = 0
	Line.Active = false
	Line.Parent = Button
	local Segment: Segment = { Button = Button, Line = Line, Axis = Axis, First = Vector3.zero, Last = Vector3.zero, Tip = Tip }
	if Tip then
		Line.BackgroundTransparency = 1
		local Label = Instance.new("TextLabel")
		Label.Size = UDim2.fromScale(1, 1)
		Label.BackgroundTransparency = 1
		Label.Text = "▲"
		Label.TextSize = 30
		Label.TextColor3 = COLORS[Axis]
		Label.TextStrokeTransparency = 0.4
		Label.Active = false
		Label.Parent = Button
	end
	Button.InputBegan:Connect(function(Input: InputObject)
		BeginDrag(Segment, Input)
	end)
	table.insert(Segments, Segment)
end

function RealmGizmoController:Show(NextMode: string, Size: Vector3)
	self:Hide()
	Mode = NextMode
	-- Scale with the object while keeping large models' controls within reach.
	Radius = math.clamp(Size.Magnitude / 2 * 1.2, MIN_RADIUS, MAX_RADIUS)

	Gui = Instance.new("ScreenGui")
	Gui.Name = "RealmTransformGizmo"
	Gui.IgnoreGuiInset = true
	Gui.ScreenInsets = Enum.ScreenInsets.None
	Gui.ResetOnSpawn = false
	Gui.DisplayOrder = 30
	Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	Gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	for Axis = 1, 3 do
		for _ = 1, (if Mode == "Rotate" then SEGMENTS else 2) do
			AddSegment(Axis, false)
		end
		if Mode == "Move" then
			AddSegment(Axis, true)
			AddSegment(Axis, true)
		end
	end
end

local function Draw(Segment: Segment, First: Vector3, Last: Vector3)
	Segment.First, Segment.Last = First, Last
	local A, VisibleA = Project(First)
	local B, VisibleB = Project(Last)
	local Delta = B - A
	local Button = Segment.Button
	Button.Visible = VisibleA and VisibleB and Delta.Magnitude > 0.5
	if not Button.Visible then
		return
	end
	Button.Position = UDim2.fromOffset((A.X + B.X) / 2, (A.Y + B.Y) / 2)
	Button.Size = UDim2.fromOffset(if Segment.Tip then 32 else Delta.Magnitude + 2, if Segment.Tip then 32 else 20)
	Button.Rotation = math.deg(math.atan2(Delta.Y, Delta.X)) + (if Segment.Tip then 90 else 0)
	Segment.Line.Size = UDim2.fromOffset(Delta.Magnitude + 1, if Drag and Drag.Axis == Segment.Axis then 5 else 3)
end

function RealmGizmoController:Render(Pivot: CFrame, Directions: { Vector3 })
	local Camera = workspace.CurrentCamera
	if not Gui or not Camera then
		return
	end
	local DragAxis = if Drag then Drag.Axis else 0
	if LastCameraFrame == Camera.CFrame and LastViewport == Camera.ViewportSize and LastFieldOfView == Camera.FieldOfView
		and LastDragAxis == DragAxis and Frame == Pivot and Axes[1] == Directions[1]
		and Axes[2] == Directions[2] and Axes[3] == Directions[3] then
		return
	end
	Frame, Axes = Pivot, Directions
	LastCameraFrame, LastViewport, LastFieldOfView = Camera.CFrame, Camera.ViewportSize, Camera.FieldOfView
	LastDragAxis = DragAxis

	local Index = 0
	for Axis = 1, 3 do
		if Mode == "Rotate" then
			local Direction = Directions[Axis]
			local Reference = if math.abs(Direction.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
			local U = Direction:Cross(Reference).Unit
			local V = Direction:Cross(U)
			for Segment = 1, SEGMENTS do
				local A, B = (Segment - 1) * math.pi * 2 / SEGMENTS, Segment * math.pi * 2 / SEGMENTS
				Index += 1
				Draw(Segments[Index], Pivot.Position + (U * math.cos(A) + V * math.sin(A)) * Radius,
					Pivot.Position + (U * math.cos(B) + V * math.sin(B)) * Radius)
			end
		else
			for Sign = -1, 1, 2 do
				Index += 1
				Draw(Segments[Index], Pivot.Position + Directions[Axis] * Sign * Radius * 0.2,
					Pivot.Position + Directions[Axis] * Sign * Radius)
			end
			for Sign = -1, 1, 2 do
				Index += 1
				Draw(Segments[Index], Pivot.Position + Directions[Axis] * Sign * Radius,
					Pivot.Position + Directions[Axis] * Sign * Radius * 1.1)
			end
		end
	end
end

local function UpdateDrag(Input: InputObject)
	local Current = Drag
	if not Current or (Input ~= Current.Input and Input.UserInputType ~= Enum.UserInputType.MouseMovement) then
		return
	end
	if Current.Input.UserInputType == Enum.UserInputType.Touch and Input ~= Current.Input then
		return
	end
	local Position = if Current.Input.UserInputType == Enum.UserInputType.Touch
		then Vector2.new(Input.Position.X, Input.Position.Y) else UserInputService:GetMouseLocation()
	local Ray = GetRay(Position)
	if not Ray then
		return
	end
	local Pixels = (Position - Current.Start):Dot(Current.ScreenDirection)
	if Mode == "Move" then
		local Coordinate = AxisCoordinate(Ray, Current.Center, Current.Direction)
		local Distance = if Coordinate and Current.Coordinate then Coordinate - Current.Coordinate else Pixels / Current.PixelsPerStud
		Dragged:Fire(Current.Axis, Distance)
	else
		local Radial = PlaneRadial(Ray, Current.Center, Current.Direction)
		if Radial and Current.Radial then
			local Angle = math.atan2(Current.Direction:Dot(Current.Radial:Cross(Radial)), Current.Radial:Dot(Radial))
			local Difference = (Angle - Current.LastAngle + math.pi) % (math.pi * 2) - math.pi
			Current.Angle += Difference
			Current.LastAngle = Angle
		else
			Current.Angle = Pixels / Current.PixelsPerStud / Radius
		end
		Dragged:Fire(Current.Axis, math.deg(Current.Angle))
	end
end

function RealmGizmoController.KnitStart()
	UserInputService.InputChanged:Connect(UpdateDrag)
	UserInputService.InputEnded:Connect(function(Input: InputObject)
		if Drag and (Input == Drag.Input or (Drag.Input.UserInputType == Enum.UserInputType.MouseButton1
			and Input.UserInputType == Enum.UserInputType.MouseButton1)) then
			Drag = nil
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		Drag = nil
	end)
end

return RealmGizmoController
