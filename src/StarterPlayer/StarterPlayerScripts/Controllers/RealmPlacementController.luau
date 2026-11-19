local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Building = require(ReplicatedStorage.Shared.RealmBuilding)
local Resources = require(ReplicatedStorage.Shared.RealmResources)

local RealmPlacementController = Knit.CreateController({ Name = "RealmPlacementController" })
local Finished = Instance.new("BindableEvent")
local Started = Instance.new("BindableEvent")
RealmPlacementController.Finished = Finished.Event
RealmPlacementController.Started = Started.Event

local Player = Players.LocalPlayer
local Editor, Pointer, ResourceController, Service, InventoryService, AlertController
local RENDER = "RealmPlacementPreview"
local Preview: PVInstance? = nil
local Anchor: BasePart? = nil
local Highlight: Highlight? = nil
local Selected: Building.AssetKey? = nil
local Bounds: Building.Bounds? = nil
local Angle = 0
local MoveOrientation: CFrame? = nil
local Hit: RaycastResult? = nil
local Valid = false
local Pending = false
local RequestId = 0
local Moving: PVInstance? = nil
local HiddenParts: { [BasePart]: number } = {}
local IgnoredInput: InputObject? = nil
local TouchPlacement = false
local PreviewCost: Resources.Cost? = nil
local OwnedResources: { [string]: number } = {}
local InventoryVersion = 0
local LastValidity: boolean? = nil
local Params = RaycastParams.new()
Params.FilterType = Enum.RaycastFilterType.Exclude

function RealmPlacementController:IsPending(): boolean
	return Pending
end

function RealmPlacementController:IsActive(): boolean
	return Preview ~= nil
end

function RealmPlacementController:IsTouchPlacement(): boolean
	return Preview ~= nil and TouchPlacement
end

function RealmPlacementController:GetAnchor(): BasePart?
	return Anchor
end

function RealmPlacementController:Cancel()
	if not Preview then
		return
	end

	RunService:UnbindFromRenderStep(RENDER)
	Preview:Destroy()
	if Anchor then
		Anchor:Destroy()
	end
	for Part, Transparency in HiddenParts do
		if Part.Parent then
			Part.LocalTransparencyModifier = Transparency
		end
	end
	table.clear(HiddenParts)
	Moving, IgnoredInput = nil, nil
	Preview, Anchor, Highlight, Selected, Bounds, Hit = nil, nil, nil, nil, nil, nil
	Pending, Valid = false, false
	PreviewCost, LastValidity = nil, nil
	MoveOrientation = nil
	Finished:Fire()
end

local function CanAfford(): boolean
	if not PreviewCost then
		return false
	end
	if not ResourceController:AreResourcesRequired() then
		return true
	end

	for Name, Amount in PreviewCost do
		if (OwnedResources[Name] or 0) < Amount then
			return false
		end
	end

	return true
end

local function Step()
	local Realm = Editor:GetRealm()
	local Camera = workspace.CurrentCamera
	if not Preview or not Bounds or not Anchor or not Camera or not Realm or not Editor:IsOpen() or (Moving and not Moving.Parent) then
		RealmPlacementController:Cancel()
		return
	end

	local Ray = Pointer:GetRay(nil, TouchPlacement)
	if not Ray then
		return
	end
	Hit = workspace:Raycast(Ray.Origin, Ray.Direction * 2048, Params)
	Valid = false
	if Hit then
		local Frame = Building.GetPlacement(Preview, Bounds, Hit, Angle, Realm:GetPivot().Position, MoveOrientation)
		Preview:PivotTo(Frame)
		local Box = Frame * Bounds.Offset
		Anchor.Position = Box.Position - Vector3.yAxis * (Bounds.Size.Y / 2 + 1)
		local Exclude: { Instance } = { Preview, Anchor }
		if Moving then
			table.insert(Exclude, Moving)
		end
		if Player.Character then
			table.insert(Exclude, Player.Character)
		end
		Valid = CanAfford() and Building.CanUseSurface(Realm, Hit, Preview) and Building.IsClear(Realm, Bounds, Frame, Exclude)
	else
		Preview:PivotTo(CFrame.new(Ray.Origin + Ray.Direction * 32))
		Anchor.Position = Preview:GetPivot().Position - Vector3.yAxis * (Bounds.Size.Y / 2 + 1)
	end

	if Highlight and LastValidity ~= Valid then
		LastValidity = Valid
		Highlight.Enabled = not Valid
	end
end

local function CreateHint(): BasePart
	local Part = Instance.new("Part")
	Part.Name = "RealmPlacementHint"
	Part.Anchored = true
	Part.Transparency = 1
	Part.CanCollide, Part.CanQuery, Part.CanTouch = false, false, false
	Part.Size = Vector3.one * 0.1
	Part.Parent = workspace

	if TouchPlacement then
		return Part
	end

	local Billboard = Instance.new("BillboardGui")
	Billboard.Name = "Controls"
	Billboard.AlwaysOnTop = true
	Billboard.Size = UDim2.fromOffset(180, 60)
	Billboard.Adornee = Part
	Billboard.Parent = Part
	local Label = Instance.new("TextLabel")
	Label.BackgroundTransparency = 1
	Label.Size = UDim2.fromScale(1, 1)
	Label.FontFace = Font.fromId(12187366657, Enum.FontWeight.Bold)
	Label.TextSize = 20
	Label.TextColor3 = Color3.new(1, 1, 1)
	Label.TextStrokeTransparency = 0.3
	Label.Text = "X: Cancel\nR: Rotate"
	Label.Parent = Billboard

	return Part
end

function RealmPlacementController:CreatePreview(Asset: PVInstance): Model
	local Clone = Building.Clone(Asset)
	local Model: Model
	if Clone:IsA("Model") then
		Model = Clone
	else
		Model = Instance.new("Model")
		Model.WorldPivot = Clone:GetPivot()
		for Name, Value in Clone:GetAttributes() do
			Model:SetAttribute(Name, Value)
		end
		Clone.Parent = Model
	end
	Building.Prepare(Model, true)
	for _, Object in Model:QueryDescendants("Humanoid, Highlight") do
		Object:Destroy()
	end
	-- Transparent parts only enter the highlight pass inside a humanoid model.
	-- Nested models need their parts in that same render group, including unions.
	for _, Part in Building.GetParts(Model) do
		Part.Parent = Model
	end
	local Renderer = Instance.new("Humanoid")
	Renderer.Name = "PreviewRenderer"
	Renderer.EvaluateStateMachine = false
	Renderer.AutomaticScalingEnabled = false
	Renderer.RequiresNeck = false
	Renderer.BreakJointsOnDeath = false
	Renderer.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	Renderer.Parent = Model

	return Model
end

local function StartPreview(Asset: PVInstance, Key: Building.AssetKey?, Object: PVInstance?, Rotation: number)
	RealmPlacementController:Cancel()

	Selected = Key
	Moving = Object
	MoveOrientation = if Object and typeof(Object:GetAttribute("PlacementAngle")) ~= "number" then Object:GetPivot().Rotation else nil
	PreviewCost = if Object then {} else Resources.GetCost(Asset)
	TouchPlacement = Pointer:IsTouch()
	Preview = RealmPlacementController:CreatePreview(Asset)
	Bounds = Building.GetBounds(Asset)
	Preview.Name = "RealmPlacementPreview"
	Preview.Parent = workspace
	Anchor = CreateHint()
	Highlight = Instance.new("Highlight")
	Highlight.Name = "RealmPlacementHighlight"
	Highlight.Adornee = Preview
	Highlight.Enabled = false
	Highlight.FillColor = Color3.fromRGB(235, 55, 55)
	Highlight.OutlineColor = Highlight.FillColor
	Highlight.FillTransparency = 0.35
	Highlight.OutlineTransparency = 0
	Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	Highlight.Parent = Preview
	Angle = Rotation
	local Exclude: { Instance } = { Preview, Anchor }
	if Player.Character then
		table.insert(Exclude, Player.Character)
	end
	if Moving then
		table.insert(Exclude, Moving)
		for _, Part in Building.GetParts(Moving) do
			HiddenParts[Part] = Part.LocalTransparencyModifier
			Part.LocalTransparencyModifier = 1
		end
	end
	Params.FilterDescendantsInstances = Exclude
	Params.RespectCanCollide = true
	Step()
	RunService:BindToRenderStep(RENDER, Enum.RenderPriority.Last.Value + 2, Step)
	Started:Fire()
end

function RealmPlacementController:Start(Key: Building.AssetKey): boolean
	local Asset = Building.Resolve(Key)
	if not Asset or not Editor:IsOpen() or #Building.GetParts(Asset) == 0 then
		return false
	end
	StartPreview(Asset, Key, nil, 0)

	return true
end

function RealmPlacementController:StartMoving(Object: PVInstance, Input: InputObject?): boolean
	local Realm = Editor:GetRealm()
	local Objects = Realm and Realm:FindFirstChild("PlacedObjects")
	if not Editor:IsOpen() or not Objects or Object.Parent ~= Objects or Object:GetAttribute("RealmId") ~= Player.UserId
		or typeof(Object:GetAttribute("PlacementId")) ~= "string" or #Building.GetParts(Object) == 0 then
		return false
	end
	local Rotation = Object:GetAttribute("PlacementAngle")
	if typeof(Rotation) ~= "number" then
		Rotation = 0
	end
	StartPreview(Object, nil, Object, Rotation)
	IgnoredInput = Input
	task.defer(function()
		if IgnoredInput == Input then
			IgnoredInput = nil
		end
	end)

	return true
end

function RealmPlacementController:Rotate()
	if Preview and not Pending then
		Angle = (Angle + Building.RotationStep) % 360
		Step()
	end
end

function RealmPlacementController:Apply(): boolean
	if not Preview or Pending then
		return false
	end
	Step()
	if not Valid or not Hit then
		return false
	end
	Pending = true
	RequestId += 1
	local Id = RequestId
	local Request = { Id = Id, Asset = Selected, Position = Hit.Position, Normal = Hit.Normal, Angle = Angle }
	if Moving then
		Request.PlacementId = Moving:GetAttribute("PlacementId")
		Service.Move:Fire(Request)
	else
		Service.Place:Fire(Request)
	end
	task.delay(8, function()
		if Pending and RequestId == Id then
			Pending = false
			AlertController:Alert("Placement timed out. Please try again.", "Warn")
		end
	end)

	return true
end

local function PlacementResult(Id: number, Success: boolean, Reason: string?)
	if not Pending or Id ~= RequestId then
		return
	end
	Pending = false
	if Success then
		if Moving then
			RealmPlacementController:Cancel()
		else
			Step()
		end
	else
		AlertController:Alert(Reason or "Unable to place object.", "Warn")
	end
end

function RealmPlacementController.KnitInit()
	Editor = Knit.GetController("RealmEditorController")
	Pointer = Knit.GetController("RealmPointerController")
	ResourceController = Knit.GetController("RealmResourceController")
	AlertController = Knit.GetController("AlertController")
	Service = Knit.GetService("RealmBuildingService")
	InventoryService = Knit.GetService("InventoryService")
end

function RealmPlacementController.KnitStart()
	local function UpdateResources(Entries: { any })
		InventoryVersion += 1
		table.clear(OwnedResources)
		for _, Item in Entries do
			OwnedResources[Item.Name] = (OwnedResources[Item.Name] or 0) + (Item.Stack or 0)
		end
	end
	InventoryService.InventoryUpdated:Connect(UpdateResources)
	local Version = InventoryVersion
	task.spawn(function()
		local Success, Entries = pcall(function(): { any }
			return InventoryService:GetInventory()
		end)
		if Success and InventoryVersion == Version then
			UpdateResources(Entries)
		end
	end)

	Editor.Changed:Connect(function(Active: boolean)
		Service.Editing:Fire(Active)
		if not Active then
			RealmPlacementController:Cancel()
		end
	end)
	Service.PlacementResult:Connect(PlacementResult)
	Service.MovementResult:Connect(PlacementResult)
	UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
		if not Preview or TouchPlacement or Processed or Input == IgnoredInput or UserInputService:GetFocusedTextBox() then
			return
		end
		if Input.KeyCode == Enum.KeyCode.X and not Pending then
			RealmPlacementController:Cancel()
		elseif Input.KeyCode == Enum.KeyCode.R and not Pending then
			RealmPlacementController:Rotate()
		elseif Input.UserInputType == Enum.UserInputType.MouseButton1 and not Pending and not Pointer:IsOverUI() then
			RealmPlacementController:Apply()
		end
	end)
end

return RealmPlacementController
