local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local RealmDeletionController = Knit.CreateController({ Name = "RealmDeletionController" })
local Changed = Instance.new("BindableEvent")
local Completed = Instance.new("BindableEvent")
RealmDeletionController.Changed = Changed.Event
RealmDeletionController.Completed = Completed.Event

local Editor, Placement, Pointer, Service, AlertController
local RENDER = "RealmDeletionHover"
local Active = false
local Pending = false
local RequestId = 0
local Target: PVInstance? = nil
local Selection: Highlight? = nil
local Effects: Folder? = nil

local function SetTarget(Object: PVInstance?)
	if Target == Object then
		return
	end

	Target = Object
	if Selection then
		if Object then
			Selection.Adornee = Object
			Selection.Enabled = true
		else
			Selection.Enabled = false
			Selection.Adornee = nil
		end
	end
end

function RealmDeletionController:IsActive(): boolean
	return Active
end

function RealmDeletionController:IsPending(): boolean
	return Pending
end

function RealmDeletionController:Delete(Object: PVInstance): boolean
	local Realm = Editor:GetRealm()
	local Objects = Realm and Realm:FindFirstChild("PlacedObjects")
	if Pending or not Editor:IsOpen() or not Objects or Object.Parent ~= Objects
		or Object:GetAttribute("RealmId") ~= Players.LocalPlayer.UserId
		or typeof(Object:GetAttribute("PlacementId")) ~= "string" then
		return false
	end

	RequestId += 1
	local Id = RequestId
	Pending = true
	Service.Delete:Fire({ Id = Id, PlacementId = Object:GetAttribute("PlacementId") })
	SetTarget(nil)
	task.delay(8, function()
		if Pending and RequestId == Id then
			Pending = false
			AlertController:Alert("Deletion timed out. Please try again.", "Warn")
			Completed:Fire(false)
		end
	end)

	return true
end

function RealmDeletionController:Stop()
	if not Active then
		return
	end

	Active, Pending = false, false
	RunService:UnbindFromRenderStep(RENDER)
	SetTarget(nil)
	if Effects then
		Effects:Destroy()
		Effects = nil
	end
	Selection = nil
	Changed:Fire(false)
end

local function Step()
	local Realm = Editor:GetRealm()
	local Camera = workspace.CurrentCamera
	if not Active or not Editor:IsOpen() or not Realm or not Camera then
		RealmDeletionController:Stop()
		return
	end

	if Pending then
		SetTarget(nil)
		return
	end
	SetTarget(Pointer:GetTarget(Realm))
end

function RealmDeletionController:Toggle()
	if Active then
		self:Stop()
		return
	end
	if not Editor:IsOpen() or Pointer:IsTouch() or not UserInputService.MouseEnabled then
		return
	end
	Placement:Cancel()
	Active = true
	Effects = Instance.new("Folder")
	Effects.Name = "RealmDeletionEffects"
	Effects.Parent = workspace
	Selection = Instance.new("Highlight")
	Selection.Name = "RealmDeletionHighlight"
	Selection.FillColor = Color3.fromRGB(235, 55, 55)
	Selection.OutlineColor = Selection.FillColor
	Selection.FillTransparency = 0.35
	Selection.OutlineTransparency = 0
	Selection.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	Selection.Enabled = false
	-- Keep target changes scoped to this container to avoid workspace-wide rendering stalls.
	Selection.Parent = Effects
	RunService:BindToRenderStep(RENDER, Enum.RenderPriority.Last.Value + 2, Step)
	Changed:Fire(true)
end

function RealmDeletionController.KnitInit()
	Editor = Knit.GetController("RealmEditorController")
	Placement = Knit.GetController("RealmPlacementController")
	Pointer = Knit.GetController("RealmPointerController")
	AlertController = Knit.GetController("AlertController")
	Service = Knit.GetService("RealmBuildingService")
end

function RealmDeletionController.KnitStart()
	Editor.Changed:Connect(function(Open: boolean)
		if not Open then
			RealmDeletionController:Stop()
		end
	end)
	Placement.Started:Connect(function()
		RealmDeletionController:Stop()
	end)
	Service.DeletionResult:Connect(function(Id: number, Success: boolean, Reason: string?)
		if not Pending or Id ~= RequestId then
			return
		end
		Pending = false
		if not Success then
			AlertController:Alert(Reason or "Unable to delete object.", "Warn")
		end
		Completed:Fire(Success)
	end)
	UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
		if not Active or Processed or UserInputService:GetFocusedTextBox() then
			return
		end
		if Input.KeyCode == Enum.KeyCode.X then
			RealmDeletionController:Stop()
		elseif Input.UserInputType == Enum.UserInputType.MouseButton1 and not Pending and not Pointer:IsOverUI() then
			Step()
			if not Target then
				return
			end

			RealmDeletionController:Delete(Target)
		end
	end)
end

return RealmDeletionController
