local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local RealmHistoryController = Knit.CreateController({ Name = "RealmHistoryController" })
local Changed = Instance.new("BindableEvent")
RealmHistoryController.Changed = Changed.Event

local ACTION = "RealmHistoryShortcuts"
local Editor, Placement, Deletion, Transform, Service, AlertController
local UndoCount, RedoCount = 0, 0
local Pending = false
local RequestId = 0

function RealmHistoryController:CanUndo(): boolean
	return Editor:IsOpen() and not Pending and UndoCount > 0
end

function RealmHistoryController:CanRedo(): boolean
	return Editor:IsOpen() and not Pending and RedoCount > 0
end

function RealmHistoryController:Request(Direction: string)
	if (Direction ~= "Undo" and Direction ~= "Redo") or Placement:IsPending() or Deletion:IsPending() or Transform:IsPending()
		or (Direction == "Undo" and not self:CanUndo()) or (Direction == "Redo" and not self:CanRedo()) then
		return
	end
	Placement:Cancel()
	Deletion:Stop()
	Transform:Cancel()
	Pending = true
	RequestId += 1
	local Id = RequestId
	Changed:Fire()
	Service.HistoryAction:Fire({ Id = Id, Direction = Direction })
	task.delay(8, function()
		if Pending and RequestId == Id then
			Pending = false
			Changed:Fire()
			AlertController:Alert("History request timed out. Please try again.", "Warn")
		end
	end)
end

local function Shortcut(_Name: string, State: Enum.UserInputState, _Input: InputObject): Enum.ContextActionResult
	local Control = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
	if not Editor:IsOpen() or not Control or UserInputService:GetFocusedTextBox() then
		return Enum.ContextActionResult.Pass
	end
	if State == Enum.UserInputState.Begin then
		local Shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		RealmHistoryController:Request(if Shift then "Redo" else "Undo")
	end

	return Enum.ContextActionResult.Sink
end

local function BindShortcuts(Open: boolean)
	Pending = false
	if Open then
		ContextActionService:BindActionAtPriority(ACTION, Shortcut, false, Enum.ContextActionPriority.High.Value + 200, Enum.KeyCode.Z)
	else
		ContextActionService:UnbindAction(ACTION)
		UndoCount, RedoCount = 0, 0
	end
	Changed:Fire()
end

function RealmHistoryController.KnitInit()
	Editor = Knit.GetController("RealmEditorController")
	Placement = Knit.GetController("RealmPlacementController")
	Deletion = Knit.GetController("RealmDeletionController")
	Transform = Knit.GetController("RealmTransformController")
	AlertController = Knit.GetController("AlertController")
	Service = Knit.GetService("RealmBuildingService")
end

function RealmHistoryController.KnitStart()
	Editor.Changed:Connect(BindShortcuts)
	BindShortcuts(Editor:IsOpen())
	Service.HistoryChanged:Connect(function(Undo: number, Redo: number)
		if Editor:IsOpen() then
			UndoCount, RedoCount = Undo, Redo
			Changed:Fire()
		end
	end)
	Service.HistoryResult:Connect(function(Id: number, Success: boolean, Reason: string?)
		if not Pending or Id ~= RequestId then
			return
		end
		Pending = false
		Changed:Fire()
		if not Success then
			AlertController:Alert(Reason or "Unable to change history.", "Warn")
		end
	end)
end

return RealmHistoryController
