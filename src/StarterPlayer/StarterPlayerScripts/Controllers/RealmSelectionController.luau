local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local RealmSelectionController = Knit.CreateController({ Name = "RealmSelectionController" })
local Editor, Placement, Deletion, Pointer
local RENDER = "RealmSelectionHover"
local Target: PVInstance? = nil
local Effects: Folder? = nil
local Selection: Highlight? = nil

local function SetTarget(Object: PVInstance?)
	if Target == Object then
		return
	end
	Target = Object
	if Selection then
		Selection.Enabled = false
		Selection.Adornee = Object
		Selection.Enabled = Object ~= nil
	end
end

local function Step()
	local Realm = Editor:GetRealm()
	if Pointer:IsTouch() or not Editor:IsOpen() or not Realm or Placement:IsActive() or Deletion:IsActive() then
		SetTarget(nil)
		return
	end

	SetTarget(Pointer:GetTarget(Realm))
end

local function Bind(Open: boolean)
	RunService:UnbindFromRenderStep(RENDER)
	SetTarget(nil)
	if Effects then
		Effects:Destroy()
		Effects, Selection = nil, nil
	end
	if not Open or not UserInputService.MouseEnabled then
		return
	end

	Effects = Instance.new("Folder")
	Effects.Name = "RealmSelectionEffects"
	Effects.Parent = workspace
	Selection = Instance.new("Highlight")
	Selection.Name = "RealmSelectionHighlight"
	Selection.Enabled = false
	Selection.FillColor = Color3.fromRGB(65, 145, 255)
	Selection.OutlineColor = Selection.FillColor
	Selection.FillTransparency = 0.5
	Selection.DepthMode = Enum.HighlightDepthMode.Occluded
	Selection.Parent = Effects
	RunService:BindToRenderStep(RENDER, Enum.RenderPriority.Last.Value + 3, Step)
end

function RealmSelectionController.KnitInit()
	Editor = Knit.GetController("RealmEditorController")
	Placement = Knit.GetController("RealmPlacementController")
	Deletion = Knit.GetController("RealmDeletionController")
	Pointer = Knit.GetController("RealmPointerController")
end

function RealmSelectionController.KnitStart()
	Editor.Changed:Connect(Bind)
	Bind(Editor:IsOpen())
	UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
		if Pointer:IsTouch() or Processed or Input.UserInputType ~= Enum.UserInputType.MouseButton1 or UserInputService:GetFocusedTextBox()
			or not Editor:IsOpen() or Placement:IsActive() or Deletion:IsActive() then
			return
		end
		Step()
		if Target then
			local Object = Target
			SetTarget(nil)
			Placement:StartMoving(Object, Input)
		end
	end)
end

return RealmSelectionController
