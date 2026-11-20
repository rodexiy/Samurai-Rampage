local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Building = require(ReplicatedStorage.Shared.RealmBuilding)
local RealmTransformController = Knit.CreateController({ Name = "RealmTransformController" })
local Changed = Instance.new("BindableEvent")
local Selected = Instance.new("BindableEvent")
local Deselected = Instance.new("BindableEvent")
RealmTransformController.Changed = Changed.Event
RealmTransformController.Selected = Selected.Event
RealmTransformController.Deselected = Deselected.Event

local Player = Players.LocalPlayer
local Editor, Placement, Deletion, Pointer, Gizmo, Service, AlertController
local RENDER = "RealmTransformPreview"
local Active, Pending, Valid = false, false, false
local RequestId = 0
local Mode = "Move"
local Object: PVInstance? = nil
local Preview: Model? = nil
local Effects: Folder? = nil
local Highlight: Highlight? = nil
local Anchor: Part? = nil
local Bounds: Building.Bounds? = nil
local Origin = CFrame.identity
local Position, DragPosition = Vector3.zero, Vector3.zero
local Rotation, DragRotation = CFrame.identity, CFrame.identity
local HiddenParts: { [BasePart]: number } = {}
local WORLD_AXES = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }

function RealmTransformController:IsActive(): boolean
	return Active
end

function RealmTransformController:IsPending(): boolean
	return Pending
end

function RealmTransformController:GetMode(): string
	return Mode
end

function RealmTransformController:GetAnchor(): BasePart?
	return Anchor
end

local function ClearSelection()
	Pending, Valid = false, false
	Gizmo:Hide()
	if Preview then
		Preview:Destroy()
	end
	if Effects then
		Effects:Destroy()
	end
	for Part, Transparency in HiddenParts do
		if Part.Parent then
			Part.LocalTransparencyModifier = Transparency
		end
	end
	table.clear(HiddenParts)
	Object, Preview, Effects, Highlight, Anchor, Bounds = nil, nil, nil, nil, nil, nil
end

local function CreateSelectionEffects()
	Effects = Instance.new("Folder")
	Effects.Name = "RealmTransformEffects"
	Effects.Parent = workspace
	Highlight = Instance.new("Highlight")
	Highlight.FillColor = Color3.fromRGB(65, 145, 255)
	Highlight.OutlineColor = Highlight.FillColor
	Highlight.FillTransparency = 0.5
	Highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	Highlight.Parent = Effects
end

function RealmTransformController:Cancel()
	if not Active then
		return
	end
	Active = false
	RunService:UnbindFromRenderStep(RENDER)
	ClearSelection()
	Changed:Fire(false)
end

function RealmTransformController:Deselect()
	if not Active or not Editor:IsOpen() then
		self:Cancel()
		return
	end

	ClearSelection()
	CreateSelectionEffects()
	Deselected:Fire()
end

local function Refresh()
	local Realm = Editor:GetRealm()
	if not Preview or not Bounds or not Anchor or not Realm then
		return
	end
	local Frame = Building.GetTransform(Origin, Position, Rotation)
	Preview:PivotTo(Frame)
	local Box = Frame * Bounds.Offset
	local Half = Bounds.Size / 2
	local Height = math.abs(Box.RightVector.Y) * Half.X + math.abs(Box.UpVector.Y) * Half.Y + math.abs(Box.LookVector.Y) * Half.Z
	Anchor.Position = Box.Position - Vector3.yAxis * (Height + 1.5)
	local Exclude: { Instance } = { Preview, Effects }
	if Object then
		table.insert(Exclude, Object)
	end
	if Player.Character then
		table.insert(Exclude, Player.Character)
	end
	Valid = Building.IsClear(Realm, Bounds, Frame, Exclude, true)
	if Highlight then
		Highlight.Enabled = not Valid
	end
end

local function Step()
	local Realm = Editor:GetRealm()
	local Objects = Realm and Realm:FindFirstChild("PlacedObjects")
	if not Editor:IsOpen() or not Realm or (Object and Object.Parent ~= Objects) then
		RealmTransformController:Cancel()
		return
	end
	if Preview then
		local Axes = if Mode == "Move" then WORLD_AXES else Building.GetTransformAxes(Origin, Rotation)
		Gizmo:Render(Preview:GetPivot(), Axes)
	elseif Highlight then
		Highlight.Adornee = if Pointer:IsTouch() then nil else Pointer:GetTarget(Realm)
	end
end

function RealmTransformController:SetMode(NextMode: string)
	if not Preview or not Bounds or Pending or (NextMode ~= "Move" and NextMode ~= "Rotate") then
		return
	end
	Mode = NextMode
	Gizmo:Show(Mode, Bounds.Size)
	Step()
end

function RealmTransformController:Start(ObjectToEdit: PVInstance): boolean
	local Realm = Editor:GetRealm()
	local Objects = Realm and Realm:FindFirstChild("PlacedObjects")
	if not Active or Pending or Placement:IsPending() or Deletion:IsPending() or not Editor:IsOpen()
		or not Objects or ObjectToEdit.Parent ~= Objects or ObjectToEdit:GetAttribute("RealmId") ~= Player.UserId
		or typeof(ObjectToEdit:GetAttribute("PlacementId")) ~= "string" or #Building.GetParts(ObjectToEdit) == 0 then
		return false
	end
	ClearSelection()
	Placement:Cancel()
	Deletion:Stop()
	Object = ObjectToEdit
	Origin = ObjectToEdit:GetPivot()
	Position, Rotation = Origin.Position, CFrame.identity
	Effects = Instance.new("Folder")
	Effects.Name = "RealmTransformEffects"
	Effects.Parent = workspace
	Preview = Placement:CreatePreview(ObjectToEdit)
	Preview.Name = "RealmTransformPreview"
	Preview:PivotTo(Origin)
	Preview.Parent = Effects
	Bounds = Building.GetBounds(ObjectToEdit)
	Anchor = Instance.new("Part")
	Anchor.Name = "ControlsAnchor"
	Anchor.Anchored = true
	Anchor.Transparency = 1
	Anchor.CanCollide, Anchor.CanTouch, Anchor.CanQuery = false, false, false
	Anchor.Size = Vector3.one * 0.1
	Anchor.Parent = Effects
	Highlight = Instance.new("Highlight")
	Highlight.Adornee = Preview
	Highlight.Enabled = false
	Highlight.FillColor = Color3.fromRGB(235, 55, 55)
	Highlight.OutlineColor = Highlight.FillColor
	Highlight.FillTransparency = 0.35
	Highlight.OutlineTransparency = 0
	Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	Highlight.Parent = Preview
	for _, Part in Building.GetParts(ObjectToEdit) do
		HiddenParts[Part] = Part.LocalTransparencyModifier
		Part.LocalTransparencyModifier = 1
	end
	Refresh()
	self:SetMode(Mode)
	Selected:Fire()

	return true
end

function RealmTransformController:Toggle()
	if Active then
		self:Cancel()
		return
	end
	if not Editor:IsOpen() or Placement:IsPending() or Deletion:IsPending() then
		return
	end
	Placement:Cancel()
	Deletion:Stop()
	Active = true
	Mode = "Move"
	CreateSelectionEffects()
	RunService:BindToRenderStep(RENDER, Enum.RenderPriority.Last.Value + 4, Step)
	Changed:Fire(true)
end

function RealmTransformController:Apply(): boolean
	if not Object or not Preview or Pending then
		return false
	end
	local Frame = Preview:GetPivot()
	if (Frame.Position - Origin.Position).Magnitude < 0.001 and Frame.LookVector:Dot(Origin.LookVector) > 0.999999
		and Frame.UpVector:Dot(Origin.UpVector) > 0.999999 then
		self:Deselect()
		return true
	end
	Refresh()
	if not Valid then
		AlertController:Alert("This space is blocked or outside your realm.", "Warn")
		return false
	end
	Pending = true
	Gizmo:Hide()
	RequestId += 1
	local Id = RequestId
	Service.Transform:Fire({
		Id = Id, PlacementId = Object:GetAttribute("PlacementId"), Origin = Origin, Position = Position, Rotation = Rotation,
	})
	task.delay(8, function()
		if Pending and RequestId == Id then
			-- A late result may still commit; end this preview before another edit starts.
			RealmTransformController:Cancel()
			AlertController:Alert("Transform timed out. Please select the object again.", "Warn")
		end
	end)

	return true
end

function RealmTransformController.KnitInit()
	Editor = Knit.GetController("RealmEditorController")
	Placement = Knit.GetController("RealmPlacementController")
	Deletion = Knit.GetController("RealmDeletionController")
	Pointer = Knit.GetController("RealmPointerController")
	Gizmo = Knit.GetController("RealmGizmoController")
	AlertController = Knit.GetController("AlertController")
	Service = Knit.GetService("RealmBuildingService")
end

function RealmTransformController.KnitStart()
	Gizmo.Began:Connect(function(_Axis: number)
		DragPosition, DragRotation = Position, Rotation
	end)
	Gizmo.Dragged:Connect(function(Axis: number, Delta: number)
		if not Preview or Pending then
			return
		end
		local Direction = WORLD_AXES[Axis]
		if Mode == "Move" then
			Position = DragPosition + Direction * Delta
		else
			local Value = math.round(Delta / Building.RotationStep) * Building.RotationStep
			local Angles = Direction * math.rad(Value % 360)
			Rotation = DragRotation * CFrame.Angles(Angles.X, Angles.Y, Angles.Z)
		end
		Refresh()
	end)
	Editor.Changed:Connect(function(Open: boolean)
		if not Open then
			RealmTransformController:Cancel()
		end
	end)
	Placement.Started:Connect(function()
		RealmTransformController:Cancel()
	end)
	Deletion.Changed:Connect(function(Deleting: boolean)
		if Deleting then
			RealmTransformController:Cancel()
		end
	end)
	Service.TransformResult:Connect(function(Id: number, Success: boolean, Reason: string?)
		if not Pending or Id ~= RequestId then
			return
		end
		Pending = false
		if Success then
			RealmTransformController:Deselect()
		else
			RealmTransformController:SetMode(Mode)
			AlertController:Alert(Reason or "Unable to transform object.", "Warn")
		end
	end)
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
		RealmTransformController:Cancel()
	end)
	UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
		if not Active or Pending or Processed or UserInputService:GetFocusedTextBox() then
			return
		end
		if Input.KeyCode == Enum.KeyCode.X then
			RealmTransformController:Cancel()
		elseif Input.KeyCode == Enum.KeyCode.Return then
			RealmTransformController:Apply()
		elseif Input.KeyCode == Enum.KeyCode.R then
			RealmTransformController:SetMode(if Mode == "Move" then "Rotate" else "Move")
		elseif not Object and Input.UserInputType == Enum.UserInputType.MouseButton1 then
			local Realm = Editor:GetRealm()
			local Target = Realm and Pointer:GetTarget(Realm)
			if Target then
				RealmTransformController:Start(Target)
			end
		end
	end)
end

return RealmTransformController
