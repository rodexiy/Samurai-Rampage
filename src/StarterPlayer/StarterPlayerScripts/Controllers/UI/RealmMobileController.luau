local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Building = require(ReplicatedStorage.Shared.RealmBuilding)

local RealmMobileController = Knit.CreateController({ Name = "RealmMobileController" })
local Player = Players.LocalPlayer
local Editor, Placement, Deletion, Transform, Pointer, AlertController
local Billboard: BillboardGui? = nil
local Reticle: ScreenGui? = nil
local TransformGui: ScreenGui? = nil
local TransformControls: Frame? = nil
local SelectionGui: ScreenGui? = nil
local Effects: Folder? = nil
local Selection: Highlight? = nil
local Target: PVInstance? = nil
local TargetConnection: RBXScriptConnection? = nil
local Mode: string? = nil
local Buttons: { [string]: GuiButton } = {}

local MODES = {
	Select = { "Delete", "Color", "Move", "Transform", "Close" },
	Delete = { "Apply", "Close" },
	Place = { "Apply", "Rotate", "Close" },
	Transform = { "Move", "Rotate", "Apply", "Close" },
}

local function Clear()
	Mode, Target = nil, nil
	RunService:UnbindFromRenderStep("RealmTransformControls")
	if SelectionGui then
		SelectionGui:Destroy()
		SelectionGui = nil
	end
	if TransformGui then
		TransformGui:Destroy()
		TransformGui, TransformControls = nil, nil
	end
	if TargetConnection then
		TargetConnection:Disconnect()
		TargetConnection = nil
	end
	if Billboard then
		Billboard:Destroy()
		Billboard = nil
	end
	if Reticle then
		Reticle:Destroy()
		Reticle = nil
	end
	if Effects then
		Effects:Destroy()
		Effects, Selection = nil, nil
	end
	table.clear(Buttons)
end

function RealmMobileController:Close()
	if Mode == "Place" then
		Placement:Cancel()
	end
	if Transform:IsActive() then
		Transform:Cancel()
	end
	if Deletion:IsActive() then
		Deletion:Stop()
	end
	Clear()
end

local function ShowToolSelection()
	if SelectionGui then
		SelectionGui:Destroy()
		SelectionGui = nil
	end
	if Mode or not Pointer:IsTouch() or not Editor:IsOpen() or (not Deletion:IsActive() and not Transform:IsActive()) then
		return
	end
	local Template = ReplicatedStorage.Assets.Billboards:FindFirstChild("MobileBillboard")
	local Close = Template and Template:FindFirstChild("Close")
	if not Close or not Close:IsA("GuiButton") then
		return
	end

	SelectionGui = Instance.new("ScreenGui")
	SelectionGui.Name = "RealmToolSelection"
	SelectionGui.ResetOnSpawn = false
	SelectionGui.DisplayOrder = 31
	local Content = Instance.new("Frame")
	Content.AnchorPoint = Vector2.new(0.5, 1)
	Content.Position = UDim2.new(0.5, 0, 1, -24)
	Content.Size = UDim2.new(0.9, 0, 0, 56)
	Content.BackgroundTransparency = 1
	Content.Parent = SelectionGui
	local Constraint = Instance.new("UISizeConstraint")
	Constraint.MaxSize = Vector2.new(360, 56)
	Constraint.Parent = Content
	local Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(1, -56, 1, 0)
	Label.BackgroundTransparency = 1
	Label.Font = Enum.Font.GothamBold
	Label.TextSize = 16
	Label.TextWrapped = true
	Label.TextColor3 = Color3.new(1, 1, 1)
	Label.TextStrokeTransparency = 0.3
	Label.Text = if Transform:IsActive() then "Select an object to transform" else "Select an object to delete"
	Label.Parent = Content
	local Button = Close:Clone()
	Button.AnchorPoint = Vector2.new(0, 0.5)
	Button.Position = UDim2.new(1, -48, 0.5, 0)
	Button.Size = UDim2.fromOffset(48, 48)
	Button.Visible = true
	Button.Activated:Connect(function()
		RealmMobileController:Close()
	end)
	Button.Parent = Content
	SelectionGui.Parent = Player:WaitForChild("PlayerGui") :: PlayerGui
end

local function OnToolsChanged()
	if (Mode == "Transform" and not Transform:IsActive()) or (Mode == "Delete" and not Deletion:IsActive()) then
		Clear()
	end
	ShowToolSelection()
end

local function Render(NextMode: string)
	Mode = NextMode
	local Names = MODES[NextMode]
	for Name, Button in Buttons do
		local Index = table.find(Names, Name)
		Button.Visible = Index ~= nil
		Button.LayoutOrder = Index or 0
	end
	if Billboard then
		Billboard.Size = UDim2.fromOffset(#Names * 56 - 8, 56)
	end
	if TransformControls then
		TransformControls.Size = UDim2.fromOffset(#Names * 56 - 8, 56)
	end
	if Selection then
		Selection.FillColor = if NextMode == "Delete" then Color3.fromRGB(235, 55, 55) else Color3.fromRGB(65, 145, 255)
		Selection.OutlineColor = Selection.FillColor
	end
end

local function OnApply()
	if Mode == "Place" then
		Placement:Apply()
	elseif Mode == "Delete" and Target then
		Deletion:Delete(Target)
	elseif Mode == "Transform" then
		Transform:Apply()
	end
end

local function OnMove()
	if Mode == "Transform" then
		Transform:SetMode("Move")
		return
	end
	if Mode ~= "Select" or not Target or Deletion:IsPending() then
		return
	end

	local Object = Target
	Placement:StartMoving(Object, nil)
end

local function CreateBillboard(Anchor: BasePart): boolean
	local Assets = ReplicatedStorage:FindFirstChild("Assets")
	local Billboards = Assets and Assets:FindFirstChild("Billboards")
	local Template = Billboards and Billboards:FindFirstChild("MobileBillboard")
	if not Template or not Template:IsA("BillboardGui") then
		AlertController:Alert("MobileBillboard is missing.", "Warn")
		return false
	end

	Billboard = Template:Clone()
	Billboard.Name = "RealmMobileBillboard"
	Billboard.Adornee = Anchor
	Billboard.AlwaysOnTop = true
	Billboard.Active = true
	Billboard.Enabled = true
	Billboard.StudsOffset = Vector3.zero
	Billboard.StudsOffsetWorldSpace = Vector3.zero
	Billboard.MaxDistance = math.huge
	local Layout = Billboard:FindFirstChildWhichIsA("UIListLayout")
	if Layout then
		Layout.Padding = UDim.new(0, 8)
		Layout.SortOrder = Enum.SortOrder.LayoutOrder
	end
	for _, Button in Billboard:GetChildren() do
		if Button:IsA("GuiButton") then
			Button.Size = UDim2.fromOffset(48, 48)
			Button.Active = true
			Buttons[Button.Name] = Button
		end
	end
	Buttons.Delete.Activated:Connect(function()
		if Mode == "Select" and not Deletion:IsPending() and Deletion:Start() then
			Render("Delete")
		end
	end)
	Buttons.Color.Activated:Connect(function()
		AlertController:Alert("Color editing is coming later.", "Warn")
	end)
	Buttons.Move.Activated:Connect(OnMove)
	Buttons.Transform.Activated:Connect(function()
		if Mode == "Select" and Target then
			local Object = Target
			Transform:Toggle()
			Transform:Start(Object)
		end
	end)
	Buttons.Close.Activated:Connect(function()
		RealmMobileController:Close()
	end)
	Buttons.Apply.Activated:Connect(OnApply)
	Buttons.Rotate.Activated:Connect(function()
		if Mode == "Place" then
			Placement:Rotate()
		elseif Mode == "Transform" then
			Transform:SetMode("Rotate")
		end
	end)
	-- Interactive BillboardGuis must live in PlayerGui; Adornee follows the world anchor.
	Billboard.Parent = Player:WaitForChild("PlayerGui") :: PlayerGui

	return true
end

local function ShowPlacement()
	Clear()
	if not Placement:IsTouchPlacement() then
		return
	end
	local Anchor = Placement:GetAnchor()
	if not Anchor or not CreateBillboard(Anchor) then
		Placement:Cancel()
		return
	end
	Render("Place")
	Reticle = Instance.new("ScreenGui")
	Reticle.Name = "RealmPlacementReticle"
	Reticle.ResetOnSpawn = false
	Reticle.IgnoreGuiInset = true
	Reticle.ScreenInsets = Enum.ScreenInsets.None
	Reticle.DisplayOrder = 20
	local Dot = Instance.new("Frame")
	Dot.Name = "Cursor"
	Dot.AnchorPoint = Vector2.one / 2
	Dot.Position = UDim2.fromScale(0.5, 0.5)
	Dot.Size = UDim2.fromOffset(8, 8)
	Dot.BackgroundColor3 = Color3.new(1, 1, 1)
	Dot.Active = false
	Dot.Parent = Reticle
	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(1, 0)
	Corner.Parent = Dot
	local Stroke = Instance.new("UIStroke")
	Stroke.Color = Color3.new(0, 0, 0)
	Stroke.Thickness = 1.5
	Stroke.Parent = Dot
	Reticle.Parent = Player.PlayerGui
end

local function ShowTransform()
	Clear()
	local Anchor = Transform:GetAnchor()
	if not Anchor or not CreateBillboard(Anchor) then
		Transform:Cancel()
		return
	end
	-- Reuse the MobileBillboard controls in screen space so touch hit areas stay
	-- predictable and the confirmation buttons remain reachable at screen edges.
	TransformGui = Instance.new("ScreenGui")
	TransformGui.Name = "RealmTransformControls"
	TransformGui.IgnoreGuiInset = true
	TransformGui.ScreenInsets = Enum.ScreenInsets.None
	TransformGui.ResetOnSpawn = false
	TransformGui.DisplayOrder = 31
	TransformControls = Instance.new("Frame")
	TransformControls.Name = "Buttons"
	TransformControls.AnchorPoint = Vector2.new(0.5, 0)
	TransformControls.BackgroundTransparency = 1
	TransformControls.Parent = TransformGui
	if Billboard then
		for _, Child in Billboard:GetChildren() do
			Child.Parent = TransformControls
		end
		Billboard:Destroy()
		Billboard = nil
	end
	Render("Transform")
	local Hint = Instance.new("TextLabel")
	Hint.Name = "TransformMode"
	Hint.BackgroundTransparency = 1
	Hint.AnchorPoint = Vector2.new(0.5, 0)
	Hint.Size = UDim2.fromOffset(280, 24)
	Hint.Font = Enum.Font.GothamBold
	Hint.TextSize = 16
	Hint.TextColor3 = Color3.new(1, 1, 1)
	Hint.TextStrokeTransparency = 0.3
	Hint.Parent = TransformGui
	TransformGui.Parent = Player:WaitForChild("PlayerGui") :: PlayerGui
	RunService:BindToRenderStep("RealmTransformControls", Enum.RenderPriority.Last.Value + 5, function()
		local Camera = workspace.CurrentCamera
		if not Camera or not TransformControls then
			return
		end
		local Point = Camera:WorldToViewportPoint(Anchor.Position)
		local HalfWidth = math.max(140, TransformControls.AbsoluteSize.X / 2) + 12
		local View = Camera.ViewportSize
		TransformControls.Visible = Point.Z > 0
		TransformControls.Position = UDim2.fromOffset(
			math.clamp(Point.X, HalfWidth, math.max(HalfWidth, View.X - HalfWidth)),
			math.clamp(Point.Y + 12, 12, math.max(12, View.Y - 96)))
		Hint.Visible = TransformControls.Visible
		Hint.Position = TransformControls.Position + UDim2.fromOffset(0, 56)
		Hint.Text = if Transform:GetMode() == "Move" then "Move" else "Rotate · 15°"
	end)
end

function RealmMobileController:Select(Object: PVInstance): boolean
	local Realm = Editor:GetRealm()
	local Objects = Realm and Realm:FindFirstChild("PlacedObjects")
	if not Pointer:IsTouch() or not Editor:IsOpen() or Placement:IsActive() or Deletion:IsPending() or Transform:IsActive()
		or not Objects or Object.Parent ~= Objects or Object:GetAttribute("RealmId") ~= Player.UserId
		or typeof(Object:GetAttribute("PlacementId")) ~= "string" then
		return false
	end
	Clear()
	Target = Object
	Effects = Instance.new("Folder")
	Effects.Name = "RealmMobileEffects"
	Effects.Parent = workspace
	local Bounds = Building.GetBounds(Object)
	local Anchor = Instance.new("Part")
	Anchor.Name = "ControlsAnchor"
	Anchor.Anchored = true
	Anchor.Transparency = 1
	Anchor.CanCollide, Anchor.CanQuery, Anchor.CanTouch = false, false, false
	Anchor.Size = Vector3.one * 0.1
	Anchor.Position = (Object:GetPivot() * Bounds.Offset).Position - Vector3.yAxis * (Bounds.Size.Y / 2 + 1)
	Anchor.Parent = Effects
	Selection = Instance.new("Highlight")
	Selection.Name = "Selection"
	Selection.Adornee = Object
	Selection.DepthMode = Enum.HighlightDepthMode.Occluded
	Selection.FillTransparency = 0.5
	Selection.Parent = Effects
	if not CreateBillboard(Anchor) then
		Clear()
		return false
	end
	Render(if Deletion:IsActive() then "Delete" else "Select")
	TargetConnection = Object.AncestryChanged:Connect(function()
		if Object.Parent ~= Objects then
			Clear()
			ShowToolSelection()
		end
	end)

	return true
end

function RealmMobileController.KnitInit()
	Editor = Knit.GetController("RealmEditorController")
	Placement = Knit.GetController("RealmPlacementController")
	Deletion = Knit.GetController("RealmDeletionController")
	Transform = Knit.GetController("RealmTransformController")
	Pointer = Knit.GetController("RealmPointerController")
	AlertController = Knit.GetController("AlertController")
end

function RealmMobileController.KnitStart()
	Transform.Selected:Connect(ShowTransform)
	Transform.Changed:Connect(OnToolsChanged)
	Deletion.Changed:Connect(OnToolsChanged)
	Transform.Deselected:Connect(function()
		if Transform:GetAnchor() then
			return
		end
		if Mode == "Transform" then
			Clear()
		end
		ShowToolSelection()
	end)
	Placement.Started:Connect(ShowPlacement)
	Placement.Finished:Connect(function()
		if Mode == "Place" then
			Clear()
		end
	end)
	Editor.Changed:Connect(function(Open: boolean)
		if not Open then
			Clear()
		end
	end)
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
		RealmMobileController:Close()
	end)
	Deletion.Completed:Connect(function(Success: boolean)
		if Success then
			if Mode == "Delete" then
				Clear()
			end
			ShowToolSelection()
		end
	end)
	UserInputService.TouchTapInWorld:Connect(function(Position: Vector2, Processed: boolean)
		local Realm = Editor:GetRealm()
		if Processed or Mode == "Delete" or not Pointer:IsTouch() or not Realm or not Editor:IsOpen() or Placement:IsActive()
			or Deletion:IsPending() or UserInputService:GetFocusedTextBox() then
			return
		end
		local Object = Pointer:GetTarget(Realm, Position)
		if Transform:IsActive() then
			if not Transform:GetAnchor() and Object then
				Transform:Start(Object)
			end
			return
		end
		if Object then
			RealmMobileController:Select(Object)
		else
			Clear()
			ShowToolSelection()
		end
	end)
end

return RealmMobileController
