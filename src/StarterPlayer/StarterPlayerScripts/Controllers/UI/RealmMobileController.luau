local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Building = require(ReplicatedStorage.Shared.RealmBuilding)

local RealmMobileController = Knit.CreateController({ Name = "RealmMobileController" })
local Player = Players.LocalPlayer
local Editor, Placement, Deletion, Pointer, AlertController
local Billboard: BillboardGui? = nil
local Reticle: ScreenGui? = nil
local Effects: Folder? = nil
local Selection: Highlight? = nil
local Target: PVInstance? = nil
local TargetConnection: RBXScriptConnection? = nil
local Mode: string? = nil
local Buttons: { [string]: GuiButton } = {}

local MODES = {
	Select = { "Delete", "Color", "Move", "Close" },
	Delete = { "Apply", "Close" },
	Place = { "Apply", "Rotate", "Close" },
}

local function Clear()
	Mode, Target = nil, nil
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
	Clear()
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
	end
end

local function OnMove()
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
		if Mode == "Select" and not Deletion:IsPending() then
			Render("Delete")
		end
	end)
	Buttons.Color.Activated:Connect(function()
		AlertController:Alert("Color editing is coming later.", "Warn")
	end)
	Buttons.Move.Activated:Connect(OnMove)
	Buttons.Close.Activated:Connect(function()
		RealmMobileController:Close()
	end)
	Buttons.Apply.Activated:Connect(OnApply)
	Buttons.Rotate.Activated:Connect(function()
		if Mode == "Place" then
			Placement:Rotate()
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

function RealmMobileController:Select(Object: PVInstance): boolean
	local Realm = Editor:GetRealm()
	local Objects = Realm and Realm:FindFirstChild("PlacedObjects")
	if not Pointer:IsTouch() or not Editor:IsOpen() or Placement:IsActive() or Deletion:IsPending()
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
	Render("Select")
	TargetConnection = Object.AncestryChanged:Connect(function()
		if Object.Parent ~= Objects then
			Clear()
		end
	end)

	return true
end

function RealmMobileController.KnitInit()
	Editor = Knit.GetController("RealmEditorController")
	Placement = Knit.GetController("RealmPlacementController")
	Deletion = Knit.GetController("RealmDeletionController")
	Pointer = Knit.GetController("RealmPointerController")
	AlertController = Knit.GetController("AlertController")
end

function RealmMobileController.KnitStart()
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
		if Success and Mode == "Delete" then
			Clear()
		end
	end)
	UserInputService.TouchTapInWorld:Connect(function(Position: Vector2, Processed: boolean)
		local Realm = Editor:GetRealm()
		if Processed or Mode == "Delete" or not Pointer:IsTouch() or not Realm or not Editor:IsOpen() or Placement:IsActive()
			or Deletion:IsPending() or UserInputService:GetFocusedTextBox() then
			return
		end
		local Object = Pointer:GetTarget(Realm, Position)
		if Object then
			RealmMobileController:Select(Object)
		else
			Clear()
		end
	end)
end

return RealmMobileController
