local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local SkillTreeSceneController = Knit.CreateController({ Name = "SkillTreeSceneController" })

type NodeVisual = {
	Object: PVInstance,
	Position: Vector3,
	Button: TextButton,
	Labels: { TextLabel },
	Stroke: UIStroke,
	Color: Color3,
	Root: boolean,
	Tree: string,
	OriginalColors: { [BasePart]: Color3 },
}

type TouchState = { Position: Vector2, Start: Vector2, Moved: boolean, NodeName: string? }
type ConnectionVisual = { Dots: { BasePart }, Required: string, Target: string, Color: Color3 }

local Screen: ScreenGui
local InputSurface: Frame
local Overlay: Frame
local World: Model
local SceneCamera: Camera
local Templates: Folder
local OnSelected: (string) -> ()
local Nodes: { [string]: NodeVisual } = {}
local Connections: { ConnectionVisual } = {}
local NodeParts: { [Instance]: string } = {}
local PickParams = RaycastParams.new()
PickParams.FilterType = Enum.RaycastFilterType.Include
PickParams.IgnoreWater = true
local Touches: { [InputObject]: TouchState } = {}
local Focus = Vector3.zero
local Distance = 100
local FitDistance = 100
type FocusMotion = {
	StartedAt: number,
	StartFocus: Vector3,
	TargetFocus: Vector3,
	StartDistance: number,
	TargetDistance: number,
}
local FocusTransition: FocusMotion? = nil
local FOCUS_DURATION = 0.35
local NODE_FOCUS_DISTANCE = 64
local Minimum = Vector2.zero
local Maximum = Vector2.zero
local Selected: string? = nil
local Dragging = false
local DragButton: Enum.UserInputType? = nil
local MouseNodeName: string? = nil
local MouseOffset = Vector2.zero
local MouseDragged = false
local DRAG_THRESHOLD = 8
local SavedMouseBehavior: Enum.MouseBehavior? = nil
local FIELD_OF_VIEW = 35
local SPACING = 32
local Yaw = 0
local Pitch = math.rad(60)
local Panning = false
local ROTATION_SPEED = 0.006
local SCENE_ORIGIN = Vector3.new(0, 50000, 0)
local CAMERA_BINDING = "SkillTreeSceneCamera"
type SavedCamera = {
	Camera: Camera,
	CameraType: Enum.CameraType,
	CFrame: CFrame,
	Focus: CFrame,
	FieldOfView: number,
	Subject: Instance?,
	MouseBehavior: Enum.MouseBehavior,
	MouseIconEnabled: boolean,
}
local CameraState: SavedCamera? = nil
local LightingState: { [string]: any } = {}
local Atmospheres: { Atmosphere } = {}
local Effects: { [PostEffect]: boolean } = {}
local Bloom: BloomEffect?
local SCENE_LIGHTING = {
	Ambient = Color3.fromRGB(145, 145, 165),
	OutdoorAmbient = Color3.fromRGB(120, 120, 140),
	Brightness = 2,
	FogStart = 999999,
	FogEnd = 1000000,
	ExposureCompensation = 0,
	GlobalShadows = false,
}

local function Position2D(Input: InputObject): Vector2
	return Vector2.new(Input.Position.X, Input.Position.Y)
end

local function MakePart(Name: string, Size: Vector3, Transform: CFrame, Color: Color3): Part
	local Part = Instance.new("Part")
	Part.Name = Name
	Part.Anchored = true
	Part.CanCollide = false
	Part.CanTouch = false
	Part.CanQuery = false
	Part.CastShadow = false
	Part.Size = Size
	Part.CFrame = CFrame.new(SCENE_ORIGIN) * Transform
	Part.Color = Color
	Part.Material = Enum.Material.Neon
	Part.Parent = World

	return Part
end

function SkillTreeSceneController:Project(Position: Vector3): (Vector2, number)
	local Projected = SceneCamera:WorldToViewportPoint(SCENE_ORIGIN + Position)
	return Vector2.new(Projected.X, Projected.Y), Projected.Z
end

function SkillTreeSceneController:GetNodeAtPosition(Position: Vector2): string?
	-- InputObject.Position and ScreenPointToRay both account for the GUI inset.
	local Ray = SceneCamera:ScreenPointToRay(Position.X, Position.Y)
	local Hit = workspace:Raycast(Ray.Origin, Ray.Direction * 5000, PickParams)
	if Hit then
		local Name = NodeParts[Hit.Instance]
		if Name then
			return Name
		end
	end

	-- Small models still have a forgiving target when the camera is far away.
	local Closest: string? = nil
	local ClosestDistance = 24
	local ClosestDepth = math.huge
	for Name, Node in Nodes do
		local Point, OnScreen = SceneCamera:WorldToScreenPoint(SCENE_ORIGIN + Node.Position)
		if OnScreen and Node.Button.Visible then
			local PixelDistance = (Vector2.new(Point.X, Point.Y) - Position).Magnitude
			if
				PixelDistance < ClosestDistance
				or (math.abs(PixelDistance - ClosestDistance) < 0.5 and Point.Z < ClosestDepth)
			then
				Closest = Name
				ClosestDistance = PixelDistance
				ClosestDepth = Point.Z
			end
		end
	end

	return Closest
end

function SkillTreeSceneController:Render()
	if not InputSurface or not Screen.Enabled or not CameraState then
		return
	end

	if FocusTransition then
		local Progress = math.clamp((os.clock() - FocusTransition.StartedAt) / FOCUS_DURATION, 0, 1)
		local Alpha = TweenService:GetValue(Progress, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		Focus = FocusTransition.StartFocus:Lerp(FocusTransition.TargetFocus, Alpha)
		Distance = FocusTransition.StartDistance
			+ (FocusTransition.TargetDistance - FocusTransition.StartDistance) * Alpha
		if Progress >= 1 then
			FocusTransition = nil
		end
	end

	Focus = Vector3.new(
		math.clamp(Focus.X, Minimum.X - SPACING, Maximum.X + SPACING),
		Focus.Y,
		math.clamp(Focus.Z, Minimum.Y - SPACING, Maximum.Y + SPACING)
	)
	local Offset = Vector3.new(math.sin(Yaw) * math.cos(Pitch), math.sin(Pitch), math.cos(Yaw) * math.cos(Pitch))
	if workspace.CurrentCamera ~= SceneCamera then
		Screen.Enabled = false
		return
	end
	SceneCamera.CameraType = Enum.CameraType.Scriptable
	SceneCamera.FieldOfView = FIELD_OF_VIEW
	SceneCamera.CFrame = CFrame.lookAt(SCENE_ORIGIN + Focus + Offset * Distance, SCENE_ORIGIN + Focus)
	SceneCamera.Focus = CFrame.new(SCENE_ORIGIN + Focus)

	for _, Node in Nodes do
		local Point, Depth = self:Project(Node.Position)
		local PixelSpacing = SPACING
			* InputSurface.AbsoluteSize.Y
			/ (2 * math.max(Depth, 1) * math.tan(math.rad(FIELD_OF_VIEW / 2)))
		Node.Button.Size =
			UDim2.fromOffset(math.clamp(PixelSpacing * 0.7, 44, 72), math.clamp(PixelSpacing * 0.7, 44, 72))
		Node.Button.Position = UDim2.fromOffset(Point.X, Point.Y)
		Node.Button.Visible = Depth > 0
			and Point.X > -100
			and Point.Y > -100
			and Point.X < InputSurface.AbsoluteSize.X + 100
			and Point.Y < InputSurface.AbsoluteSize.Y + 100
	end
end

function SkillTreeSceneController:Pan(Delta: Vector2)
	self:CancelFocus()
	local UnitsPerPixel = 2
		* Distance
		* math.tan(math.rad(FIELD_OF_VIEW / 2))
		/ math.max(InputSurface.AbsoluteSize.Y, 1)
	local Right = Vector3.new(math.cos(Yaw), 0, -math.sin(Yaw))
	local Up = Vector3.new(-math.sin(Yaw), 0, -math.cos(Yaw))
	Focus += (-Right * Delta.X + Up * Delta.Y / math.max(math.abs(math.sin(Pitch)), 0.2)) * UnitsPerPixel
	self:Render()
end

function SkillTreeSceneController:Orbit(Delta: Vector2)
	self:CancelFocus()
	Yaw = (Yaw - Delta.X * ROTATION_SPEED) % (math.pi * 2)
	Pitch = math.clamp(Pitch + Delta.Y * ROTATION_SPEED, math.rad(-80), math.rad(85))
	self:Render()
end

function SkillTreeSceneController:Zoom(Factor: number)
	self:CancelFocus()
	Distance = math.clamp(Distance * Factor, 18, math.min(math.max(FitDistance * 1.5, 100), 1600))
	self:Render()
end

function SkillTreeSceneController:ResetView()
	self:CancelFocus()
	local Size = InputSurface.AbsoluteSize
	local Aspect = Size.X / math.max(Size.Y, 1)
	local HalfField = math.rad(FIELD_OF_VIEW / 2)
	local MinimumHalfField = math.min(HalfField, math.atan(math.tan(HalfField) * math.max(Aspect, 0.1)))
	local Center = Vector3.new((Minimum.X + Maximum.X) / 2, 5, (Minimum.Y + Maximum.Y) / 2)
	local Radius = 16
	for _, Node in Nodes do
		Radius = math.max(Radius, (Node.Position - Center).Magnitude + 12)
	end
	FitDistance = Radius / math.sin(MinimumHalfField)
	Distance = FitDistance
	Yaw = 0
	Pitch = math.rad(60)
	Focus = Center
	self:Render()
end

function SkillTreeSceneController:StopInput()
	self:CancelFocus()
	Dragging = false
	DragButton = nil
	MouseNodeName = nil
	MouseOffset = Vector2.zero
	MouseDragged = false
	Panning = false
	table.clear(Touches)
	if SavedMouseBehavior then
		UserInputService.MouseBehavior = SavedMouseBehavior
		SavedMouseBehavior = nil
	end
end

function SkillTreeSceneController:BeginInput(Input: InputObject, NodeName: string?)
	if not Screen.Enabled then
		return
	end

	self:CancelFocus()
	if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
		NodeName = self:GetNodeAtPosition(Position2D(Input)) or NodeName
	end

	if Touches[Input] and NodeName then
		Touches[Input].NodeName = NodeName
	end

	if
		Input.UserInputType == Enum.UserInputType.MouseButton1
		or Input.UserInputType == Enum.UserInputType.MouseButton2
		or Input.UserInputType == Enum.UserInputType.MouseButton3
	then
		if Dragging then
			if DragButton == Input.UserInputType and NodeName then
				MouseNodeName = NodeName
			end
			return
		end

		Dragging = true
		DragButton = Input.UserInputType
		MouseNodeName = NodeName
		MouseOffset = Vector2.zero
		MouseDragged = false
		Panning = Input.UserInputType ~= Enum.UserInputType.MouseButton2
		SavedMouseBehavior = SavedMouseBehavior or UserInputService.MouseBehavior
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	elseif Input.UserInputType == Enum.UserInputType.Touch and not Touches[Input] then
		local Position = Position2D(Input)
		Touches[Input] = { Position = Position, Start = Position, Moved = false, NodeName = NodeName }

		if self:GetTouchCount() > 1 then
			for _, Touch in Touches do
				Touch.Moved = true
			end
		end
	end
end

function SkillTreeSceneController:GetTouchCount(): number
	local Count = 0
	for _ in Touches do
		Count += 1
	end
	return Count
end

local function TouchGeometry(): (Vector2, number)
	local Positions = {}
	local Center = Vector2.zero
	for _, Touch in Touches do
		table.insert(Positions, Touch.Position)
		Center += Touch.Position
	end

	return Center / math.max(#Positions, 1), if #Positions == 2 then (Positions[1] - Positions[2]).Magnitude else 0
end

function SkillTreeSceneController:MoveInput(Input: InputObject)
	if not Screen.Enabled then
		return
	end

	if Dragging and Input.UserInputType == Enum.UserInputType.MouseMovement then
		local Delta = Vector2.new(Input.Delta.X, Input.Delta.Y)
		MouseOffset += Delta
		MouseDragged = MouseDragged or MouseOffset.Magnitude > DRAG_THRESHOLD
		if DragButton == Enum.UserInputType.MouseButton1 and not MouseDragged then
			return
		end

		if
			Panning
			or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		then
			self:Pan(Delta)
		else
			self:Orbit(Delta)
		end
	elseif Touches[Input] then
		local Touch = Touches[Input]
		local PreviousCenter, PreviousDistance = TouchGeometry()
		Touch.Position = Position2D(Input)
		Touch.Moved = Touch.Moved or (Touch.Position - Touch.Start).Magnitude > 8
		local Center, PinchDistance = TouchGeometry()

		if self:GetTouchCount() == 1 then
			if Touch.Moved then
				self:Orbit(Center - PreviousCenter)
			end
		else
			if PinchDistance > 1 and PreviousDistance > 1 then
				self:Zoom(PreviousDistance / PinchDistance)
			end
			self:Pan(Center - PreviousCenter)
		end
	elseif Input.UserInputType == Enum.UserInputType.MouseWheel then
		local Position = UserInputService:GetMouseLocation() - InputSurface.AbsolutePosition
		local Size = InputSurface.AbsoluteSize
		if Position.X >= 0 and Position.Y >= 0 and Position.X <= Size.X and Position.Y <= Size.Y then
			self:Zoom(0.85 ^ Input.Position.Z)
		end
	end
end

function SkillTreeSceneController:EndInput(Input: InputObject)
	if Dragging and Input.UserInputType == DragButton then
		local ClickedNode = if DragButton == Enum.UserInputType.MouseButton1 and not MouseDragged
			then MouseNodeName
			else nil
		Dragging = false
		DragButton = nil
		MouseNodeName = nil
		MouseOffset = Vector2.zero
		MouseDragged = false
		Panning = false
		if SavedMouseBehavior then
			UserInputService.MouseBehavior = SavedMouseBehavior
			SavedMouseBehavior = nil
		end

		if Screen.Enabled and ClickedNode then
			OnSelected(ClickedNode)
		end
	end

	local Touch = Touches[Input]
	if not Touch then
		return
	end

	if Screen.Enabled and not Touch.Moved and Touch.NodeName then
		OnSelected(Touch.NodeName)
	end
	Touches[Input] = nil
end

function SkillTreeSceneController:OpenScene()
	local SceneLighting = Lighting :: any
	if CameraState then
		return
	end

	SceneCamera = workspace.CurrentCamera
	CameraState = {
		Camera = SceneCamera,
		CameraType = SceneCamera.CameraType,
		CFrame = SceneCamera.CFrame,
		Focus = SceneCamera.Focus,
		FieldOfView = SceneCamera.FieldOfView,
		Subject = SceneCamera.CameraSubject,
		MouseBehavior = UserInputService.MouseBehavior,
		MouseIconEnabled = UserInputService.MouseIconEnabled,
	}
	for Property, Value in SCENE_LIGHTING do
		LightingState[Property] = SceneLighting[Property]
		SceneLighting[Property] = Value
	end
	for _, Child in Lighting:GetChildren() do
		if Child:IsA("Atmosphere") then
			table.insert(Atmospheres, Child)
			Child.Parent = nil
		elseif Child:IsA("PostEffect") then
			Effects[Child] = Child.Enabled
			Child.Enabled = false
		end
	end
	Bloom = Instance.new("BloomEffect")
	Bloom.Name = "SkillTreeBloom"
	Bloom.Intensity = 0.5
	Bloom.Size = 24
	Bloom.Threshold = 1.2
	Bloom.Parent = Lighting
	World.Parent = workspace
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	self:ResetView()
	RunService:BindToRenderStep(CAMERA_BINDING, Enum.RenderPriority.Camera.Value + 10, function()
		self:Render()
		if CameraState then
			UserInputService.MouseBehavior = if Dragging
				then Enum.MouseBehavior.LockCurrentPosition
				else Enum.MouseBehavior.Default
		end
	end)
end

function SkillTreeSceneController:CloseScene()
	local SceneLighting = Lighting :: any
	self:StopInput()
	RunService:UnbindFromRenderStep(CAMERA_BINDING)
	World.Parent = nil
	local Previous = CameraState
	if not Previous then
		return
	end
	CameraState = nil

	if workspace.CurrentCamera == Previous.Camera then
		Previous.Camera.CFrame = Previous.CFrame
		Previous.Camera.Focus = Previous.Focus
		Previous.Camera.FieldOfView = Previous.FieldOfView
		Previous.Camera.CameraSubject = Previous.Subject
		Previous.Camera.CameraType = Previous.CameraType
	end
	UserInputService.MouseBehavior = Previous.MouseBehavior
	UserInputService.MouseIconEnabled = Previous.MouseIconEnabled
	if Bloom then
		Bloom:Destroy()
		Bloom = nil
	end
	for Property, Value in LightingState do
		SceneLighting[Property] = Value
	end
	for Effect, Enabled in Effects do
		Effect.Enabled = Enabled
	end
	for _, Atmosphere in Atmospheres do
		Atmosphere.Parent = Lighting
	end
	table.clear(LightingState)
	table.clear(Effects)
	table.clear(Atmospheres)
end

function SkillTreeSceneController:Create(Gui: ScreenGui, Callback: (string) -> ())
	Screen = Gui
	OnSelected = Callback
	Templates = ReplicatedStorage.Assets.Models:WaitForChild("SkillTree") :: Folder
	SceneCamera = workspace.CurrentCamera
	World = Instance.new("Model")
	World.Name = "LocalSkillTreeScene"
	PickParams.FilterDescendantsInstances = { World }
	World:SetAttribute("SceneOrigin", SCENE_ORIGIN)

	InputSurface = Instance.new("Frame")
	InputSurface.Name = "SkillTreeInput"
	InputSurface.Size = UDim2.fromScale(1, 1)
	InputSurface.BackgroundTransparency = 1
	InputSurface.Active = true
	InputSurface.ZIndex = 1
	InputSurface.Parent = Screen
	Overlay = Instance.new("Frame")
	Overlay.Name = "NodeLabels"
	Overlay.Size = UDim2.fromScale(1, 1)
	Overlay.BackgroundTransparency = 1
	Overlay.ZIndex = 2
	Overlay.Parent = Screen

	InputSurface.InputBegan:Connect(function(Input: InputObject)
		self:BeginInput(Input)
	end)
	UserInputService.InputChanged:Connect(function(Input: InputObject)
		self:MoveInput(Input)
	end)
	UserInputService.InputEnded:Connect(function(Input: InputObject)
		self:EndInput(Input)
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		self:StopInput()
	end)
	InputSurface:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:ResetView()
	end)
	Screen:GetPropertyChangedSignal("Enabled"):Connect(function()
		if Screen.Enabled then
			self:OpenScene()
		else
			self:CloseScene()
		end
	end)
	Players.LocalPlayer.CharacterRemoving:Connect(function()
		Screen.Enabled = false
	end)
	if Screen.Enabled then
		self:OpenScene()
	end
end

function SkillTreeSceneController:Clear()
	self:StopInput()
	World:ClearAllChildren()
	Overlay:ClearAllChildren()
	table.clear(Nodes)
	table.clear(NodeParts)
	table.clear(Connections)
	Selected = nil
	Minimum = Vector2.zero
	Maximum = Vector2.zero
end

function SkillTreeSceneController:AddNode(Name: string, Position: Vector3, Color: Color3, Root: boolean, Tree: string)
	local Template = Templates:FindFirstChild(Name) or Templates:FindFirstChild(Tree)
	if not Template or not (Template:IsA("Model") or Template:IsA("BasePart")) then
		warn("Skill tree model missing: " .. Name)
		return
	end

	local Object = Template:Clone() :: PVInstance
	Object.Name = Name
	Object:SetAttribute("SkillTree", Tree)
	local Parts = Object:QueryDescendants("BasePart")
	if Object:IsA("BasePart") then
		table.insert(Parts, Object)
	end
	local OriginalColors: { [BasePart]: Color3 } = {}
	for _, Part: BasePart in Parts do
		OriginalColors[Part] = Part.Color
		Part.Anchored = true
		Part.CanCollide = false
		Part.CanTouch = false
		Part.CanQuery = Part.Transparency < 1
		NodeParts[Part] = Name
	end
	for _, Script in Object:QueryDescendants("BaseScript") do
		Script:Destroy()
	end

	local Bounds, Size
	if Object:IsA("Model") then
		Bounds, Size = Object:GetBoundingBox()
	else
		local Part = Object :: BasePart
		Bounds, Size = Part.CFrame, Part.Size
	end
	local Center = Position + Vector3.new(0, Size.Y / 2, 0)
	Object:PivotTo(CFrame.new(SCENE_ORIGIN + Center - Bounds.Position) * Object:GetPivot())
	Object.Parent = World
	Minimum = Vector2.new(math.min(Minimum.X, Position.X), math.min(Minimum.Y, Position.Z))
	Maximum = Vector2.new(math.max(Maximum.X, Position.X), math.max(Maximum.Y, Position.Z))

	local Button = Instance.new("TextButton")
	Button.Name = Name
	Button.AnchorPoint = Vector2.new(0.5, 0.5)
	Button.Size = UDim2.fromOffset(if Root then 72 else 46, if Root then 72 else 46)
	Button.Text = ""
	Button.BackgroundTransparency = 1
	Button.ZIndex = 2
	Button.Parent = Overlay
	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(1, 0)
	Corner.Parent = Button
	local Stroke = Instance.new("UIStroke")
	Stroke.Color = Color
	Stroke.Thickness = 1
	Stroke.Transparency = 0.55
	Stroke.Parent = Button
	local Labels: { TextLabel } = {}
	for _, Billboard in Object:QueryDescendants("BillboardGui") do
		Billboard.Enabled = true
		if not Billboard.Adornee and Billboard.Parent and Billboard.Parent:IsA("BasePart") then
			Billboard.Adornee = Billboard.Parent
		end
		for _, Label: TextLabel in Billboard:QueryDescendants("TextLabel") do
			Label.Text = Name
			Label.TextColor3 = Color
			Label.Visible = true
			table.insert(Labels, Label)
		end
	end
	Button.InputBegan:Connect(function(Input: InputObject)
		self:BeginInput(Input, Name)
	end)
	Button.Activated:Connect(function(Input: InputObject)
		if
			Input.UserInputType ~= Enum.UserInputType.Touch
			and Input.UserInputType ~= Enum.UserInputType.MouseButton1
			and Screen.Enabled
		then
			OnSelected(Name)
		end
	end)
	Nodes[Name] = {
		Object = Object,
		Position = Center,
		Button = Button,
		Labels = Labels,
		Stroke = Stroke,
		Color = Color,
		Root = Root,
		Tree = Tree,
		OriginalColors = OriginalColors,
	}
end

local function CloneDot(Name: string, Position: Vector3, Size: number, Parent: Instance): BasePart?
	local Template = Templates:FindFirstChild("Dot")
	if not Template or not Template:IsA("BasePart") then
		warn("Skill tree Dot model missing")
		return nil
	end

	local Dot = Template:Clone()
	Dot.Name = Name
	Dot.Size = Vector3.new(Size, Size, Size)
	Dot.CFrame = CFrame.new(SCENE_ORIGIN + Position) * Template.CFrame.Rotation
	Dot.Anchored = true
	Dot.CanCollide = false
	Dot.CanTouch = false
	Dot.CanQuery = false
	Dot.CastShadow = false
	Dot.Material = Enum.Material.Neon
	Dot.Parent = Parent

	return Dot
end

function SkillTreeSceneController:AddConnection(Required: string, Target: string)
	local Start, Finish = Nodes[Required], Nodes[Target]
	if not Start or not Finish then
		return
	end

	local From = Vector3.new(Start.Position.X, 2, Start.Position.Z)
	local To = Vector3.new(Finish.Position.X, 2, Finish.Position.Z)
	local Group = Instance.new("Folder")
	Group.Name = Required .. "To" .. Target
	Group:SetAttribute("RequiredNode", Required)
	Group:SetAttribute("TargetNode", Target)
	local Dots: { BasePart } = {}
	for Index = 1, 3 do
		local Dot = CloneDot("Dot" .. Index, From:Lerp(To, Index / 4), 1.8, Group)
		if Dot then
			Dot.Color = Finish.Color
			table.insert(Dots, Dot)
		end
	end
	Group.Parent = World
	table.insert(Connections, { Dots = Dots, Required = Required, Target = Target, Color = Finish.Color })
end

function SkillTreeSceneController:SetNodeState(Name: string, Learned: boolean, Allowed: boolean, Points: number?)
	local Node = Nodes[Name]
	if not Node then
		return
	end

	local Color = if Learned or Node.Root
		then Node.Color
		elseif Allowed then Node.Color:Lerp(Color3.new(1, 1, 1), 0.3)
		else Node.Color:Lerp(Color3.fromRGB(25, 25, 32), 0.5)
	for Part, OriginalColor in Node.OriginalColors do
		Part.Color = if Learned or Node.Root
			then OriginalColor
			elseif Allowed then OriginalColor:Lerp(Color3.new(1, 1, 1), 0.12)
			else OriginalColor:Lerp(Color3.new(0, 0, 0), 0.35)
	end
	Node.Stroke.Color = Color
	Node.Stroke.Thickness = if Name == Selected then 3 else 1
	Node.Stroke.Transparency = if Name == Selected or Learned then 0 else 0.55
	for _, Label in Node.Labels do
		Label.TextColor3 = Color
		Label.Text = Name
	end
	Node.Button:SetAttribute("Points", Points)
end

function SkillTreeSceneController:SetConnectionState(Learned: { [string]: boolean })
	for _, Connection in Connections do
		local Active = Learned[Connection.Required]
		for _, Dot in Connection.Dots do
			Dot.Color = if Active then Connection.Color else Connection.Color:Lerp(Color3.new(0, 0, 0), 0.5)
			Dot.Transparency = if Learned[Connection.Target] then 0 elseif Active then 0.25 else 0.35
		end
	end
end

function SkillTreeSceneController:Select(Name: string?)
	Selected = Name
	for NodeName, Node in Nodes do
		Node.Stroke.Thickness = if NodeName == Name then 3 else 1
	end
	self:Render()
end

function SkillTreeSceneController:CancelFocus()
	FocusTransition = nil
end

function SkillTreeSceneController:FocusNode(Name: string)
	local Node = Nodes[Name]
	if not Node or Node.Root then
		return
	end

	FocusTransition = {
		StartedAt = os.clock(),
		StartFocus = Focus,
		TargetFocus = Node.Position,
		StartDistance = Distance,
		TargetDistance = math.min(Distance, NODE_FOCUS_DISTANCE),
	}
	self:Render()
end

function SkillTreeSceneController:Finish()
	-- Tile the enclosure because Roblox clamps a BasePart dimension to 2048 studs.
	local Axes = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }
	for Index, Normal in Axes do
		local TangentA = Axes[Index % 3 + 1]
		local TangentB = Axes[(Index + 1) % 3 + 1]
		local Size = Vector3.new(2000, 2000, 2000) - Normal * 1996
		for _, Sign in { -1, 1 } do
			for _, First in { -1, 1 } do
				for _, Second in { -1, 1 } do
					local Position = Normal * Sign * 2000 + TangentA * First * 1000 + TangentB * Second * 1000
					MakePart("BlackBackdrop", Size, CFrame.new(Position), Color3.new(0, 0, 0))
				end
			end
		end
	end
	local Center = (Minimum + Maximum) / 2
	local Span = Maximum - Minimum + Vector2.new(2000, 2000)

	for X = math.floor((Minimum.X - 36) / SPACING) * SPACING, Maximum.X + 36, SPACING do
		MakePart("Grid", Vector3.new(0.035, 0.035, Span.Y), CFrame.new(X, -0.15, Center.Y), Color3.fromRGB(9, 9, 20))
	end
	for Z = math.floor((Minimum.Y - 36) / SPACING) * SPACING, Maximum.Y + 36, SPACING do
		MakePart("Grid", Vector3.new(Span.X, 0.035, 0.035), CFrame.new(Center.X, -0.15, Z), Color3.fromRGB(9, 9, 20))
	end
	self:ResetView()
end

return SkillTreeSceneController
