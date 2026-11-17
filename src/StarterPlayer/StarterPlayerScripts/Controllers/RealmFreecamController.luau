local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local RealmFreecamController = Knit.CreateController({ Name = "RealmFreecamController" })
local Player = Players.LocalPlayer
local Stopped = Instance.new("BindableEvent")
RealmFreecamController.Stopped = Stopped.Event

local ACTION = "MentalRealmFreecam"
local RENDER = "MentalRealmFreecam"
local NORMAL_SPEED = 64
local SHIFT_BOOST = 3
local Keys: { [Enum.KeyCode]: boolean } = {}
local LookTouch: InputObject? = nil
local MouseDelta = Vector2.zero
local MoveStick, LookStick = Vector2.zero, Vector2.zero
local TriggerUp, TriggerDown = 0, 0
local Looking = false

type CameraState = {
	Realm: Model,
	Character: Model,
	Camera: Camera,
	CameraType: Enum.CameraType,
	Subject: Instance?,
	Frame: CFrame,
	Focus: CFrame,
	FieldOfView: number,
	MouseBehavior: Enum.MouseBehavior,
	MouseIconEnabled: boolean,
	Cutscene: any,
	Controls: any,
	ControlsEnabled: boolean,
	Position: Vector3,
	Pitch: number,
	Yaw: number,
}

local State: CameraState? = nil

function RealmFreecamController.ClampPosition(Realm: Model, Position: Vector3): Vector3
	local Center = Realm:GetAttribute("TerrainCenter")
	local Size = Realm:GetAttribute("TerrainSize")
	if typeof(Center) ~= "Vector3" or typeof(Size) ~= "Vector3" then
		return Position
	end

	local Half = Size / 2 + Vector3.new(128, 256, 128)
	return Position:Max(Center - Half):Min(Center + Half)
end

function RealmFreecamController:IsActive(): boolean
	return State ~= nil
end

local function ResetInput()
	table.clear(Keys)
	MouseDelta = Vector2.zero
	MoveStick, LookStick = Vector2.zero, Vector2.zero
	TriggerUp, TriggerDown = 0, 0
	Looking = false
	LookTouch = nil
end

function RealmFreecamController:Stop()
	local Previous = State
	if not Previous then
		return
	end

	State = nil
	RunService:UnbindFromRenderStep(RENDER)
	ContextActionService:UnbindAction(ACTION)
	ResetInput()

	Previous.Character:SetAttribute("RealmEditing", false)
	Previous.Character:SetAttribute("CameraCutscene", Previous.Cutscene)
	if Previous.ControlsEnabled then
		Previous.Controls:Enable()
	end
	if workspace.CurrentCamera == Previous.Camera then
		Previous.Camera.CFrame = Previous.Frame
		Previous.Camera.Focus = Previous.Focus
		Previous.Camera.FieldOfView = Previous.FieldOfView
		Previous.Camera.CameraSubject = Previous.Subject
		Previous.Camera.CameraType = Previous.CameraType
	end
	UserInputService.MouseBehavior = Previous.MouseBehavior
	UserInputService.MouseIconEnabled = Previous.MouseIconEnabled
	Stopped:Fire()
end

local function SetFrame(Frame: CFrame)
	if not State then
		return
	end

	State.Position = RealmFreecamController.ClampPosition(State.Realm, Frame.Position)
	State.Pitch, State.Yaw = Frame:ToOrientation()
end

function RealmFreecamController:FocusPlayer()
	if not State or not State.Character.PrimaryPart then
		return
	end

	local Position = State.Character.PrimaryPart.Position
	SetFrame(CFrame.lookAt(Position + Vector3.new(0, 18, 28), Position))
end

local function Axis(Positive: Enum.KeyCode, Negative: Enum.KeyCode): number
	return (if Keys[Positive] then 1 else 0) - (if Keys[Negative] then 1 else 0)
end

local function Step(DeltaTime: number)
	local Current = State
	if not Current then
		return
	end
	if Player.Character ~= Current.Character or not Current.Realm.Parent or workspace.CurrentCamera ~= Current.Camera then
		RealmFreecamController:Stop()
		return
	end

	local Focused = UserInputService:GetFocusedTextBox() ~= nil
	local Delta = MouseDelta * 0.003 + LookStick * math.min(DeltaTime, 0.1) * Vector2.new(2, -2)
	MouseDelta = Vector2.zero
	if not Focused then
		Current.Pitch = math.clamp(Current.Pitch - Delta.Y, math.rad(-85), math.rad(85))
		Current.Yaw -= Delta.X
	end

	local Frame = CFrame.fromOrientation(Current.Pitch, Current.Yaw, 0)
	local Movement = Vector3.zero
	if not Focused then
		Movement = Vector3.new(Axis(Enum.KeyCode.D, Enum.KeyCode.A) + MoveStick.X,
			Axis(Enum.KeyCode.E, Enum.KeyCode.Q) + TriggerUp - TriggerDown,
			Axis(Enum.KeyCode.S, Enum.KeyCode.W) - MoveStick.Y)
	end
	if Movement.Magnitude > 1 then
		Movement = Movement.Unit
	end
	local Boost = if Keys[Enum.KeyCode.LeftShift] or Keys[Enum.KeyCode.RightShift] then SHIFT_BOOST else 1
	local WorldMovement = Frame:VectorToWorldSpace(Vector3.new(Movement.X, 0, Movement.Z)) + Vector3.yAxis * Movement.Y
	Current.Position = RealmFreecamController.ClampPosition(Current.Realm, Current.Position + WorldMovement * NORMAL_SPEED * Boost * math.min(DeltaTime, 0.1))
	Current.Camera.CameraType = Enum.CameraType.Scriptable
	Current.Camera.CFrame = CFrame.new(Current.Position) * Frame
	Current.Camera.Focus = Current.Camera.CFrame * CFrame.new(0, 0, -32)
	UserInputService.MouseBehavior = if Looking then Enum.MouseBehavior.LockCurrentPosition else Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = not Looking
end

local function InputAction(_Name: string, InputState: Enum.UserInputState, Input: InputObject): Enum.ContextActionResult
	if not State then
		return Enum.ContextActionResult.Pass
	end
	local Pressed = InputState == Enum.UserInputState.Begin
	local Released = InputState == Enum.UserInputState.End or InputState == Enum.UserInputState.Cancel
	if Released then
		Keys[Input.KeyCode] = nil
	elseif Pressed and not UserInputService:GetFocusedTextBox() then
		Keys[Input.KeyCode] = true
	end
	if Input.UserInputType == Enum.UserInputType.MouseButton2 then
		Looking = Pressed or (Looking and not Released)
	end

	return if UserInputService:GetFocusedTextBox() then Enum.ContextActionResult.Pass else Enum.ContextActionResult.Sink
end

function RealmFreecamController:Start(Realm: Model): boolean
	if State then
		return true
	end

	local Character = Player.Character
	local Camera = workspace.CurrentCamera
	if not Character or not Character.PrimaryPart or not Camera or Character:GetAttribute("CameraCutscene") then
		return false
	end
	local PlayerModule = require(Players.LocalPlayer.PlayerScripts:WaitForChild("PlayerModule") :: ModuleScript)
	local Controls = PlayerModule:GetControls()
	local Pitch, Yaw = Camera.CFrame:ToOrientation()
	State = {
		Realm = Realm, Character = Character, Camera = Camera,
		CameraType = Camera.CameraType, Subject = Camera.CameraSubject,
		Frame = Camera.CFrame, Focus = Camera.Focus, FieldOfView = Camera.FieldOfView,
		MouseBehavior = UserInputService.MouseBehavior, MouseIconEnabled = UserInputService.MouseIconEnabled,
		Cutscene = Character:GetAttribute("CameraCutscene"), Controls = Controls,
		ControlsEnabled = Controls.controlsEnabled ~= false,
		Position = Camera.CFrame.Position, Pitch = Pitch, Yaw = Yaw,
	}
	ResetInput()
	Controls:Disable()
	Character:SetAttribute("RealmEditing", true)
	Character:SetAttribute("CameraCutscene", true)
	Camera.CameraType = Enum.CameraType.Scriptable
	self:FocusPlayer()

	ContextActionService:BindActionAtPriority(ACTION, InputAction, false, Enum.ContextActionPriority.High.Value + 100,
		Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Q, Enum.KeyCode.E,
		Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift,
		Enum.UserInputType.MouseButton2)
	RunService:BindToRenderStep(RENDER, Enum.RenderPriority.Last.Value + 1, Step)

	return true
end

function RealmFreecamController.KnitStart()
	UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
		if State and not Processed and Input.UserInputType == Enum.UserInputType.Touch
			and Input.Position.X > State.Camera.ViewportSize.X * 0.4 and not LookTouch then
			LookTouch = Input
		end
	end)
	UserInputService.InputChanged:Connect(function(Input: InputObject)
		if not State then
			return
		end
		if (Input.UserInputType == Enum.UserInputType.MouseMovement and Looking) or Input == LookTouch then
			MouseDelta += Vector2.new(Input.Delta.X, Input.Delta.Y)
		elseif Input.KeyCode == Enum.KeyCode.Thumbstick1 then
			MoveStick = if Input.Position.Magnitude > 0.15 then Vector2.new(Input.Position.X, Input.Position.Y) else Vector2.zero
		elseif Input.KeyCode == Enum.KeyCode.Thumbstick2 then
			LookStick = if Input.Position.Magnitude > 0.15 then Vector2.new(Input.Position.X, Input.Position.Y) else Vector2.zero
		elseif Input.KeyCode == Enum.KeyCode.ButtonR2 then
			TriggerUp = Input.Position.Z
		elseif Input.KeyCode == Enum.KeyCode.ButtonL2 then
			TriggerDown = Input.Position.Z
		end
	end)
	UserInputService.InputEnded:Connect(function(Input: InputObject)
		if Input == LookTouch then
			LookTouch = nil
		end
	end)
	UserInputService.WindowFocusReleased:Connect(ResetInput)
	GuiService.MenuOpened:Connect(function()
		RealmFreecamController:Stop()
	end)
end

return RealmFreecamController
