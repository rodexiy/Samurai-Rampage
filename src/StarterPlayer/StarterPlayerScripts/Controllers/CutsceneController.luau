local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local CutsceneController = Knit.CreateController({ Name = "CutsceneController" })

type FrameTransform = (CFrame, number) -> CFrame

type CameraState = {
	Camera: Camera,
	Character: Model,
	Frame: CFrame,
	Focus: CFrame,
	Fov: number,
	Subject: Instance?,
	MouseBehavior: Enum.MouseBehavior,
	MouseIcon: boolean,
	CutsceneAttribute: any,
	Transform: FrameTransform?,
}

local State: CameraState?
local Controls: any
local CutsceneUIController
local Pose = Instance.new("CFrameValue")
local Focus = Instance.new("Vector3Value")
local CameraTween: Tween?
local FocusTween: Tween?
local FovTween: Tween?
local BINDING = "CinematicSequenceCamera"

local function CancelTweens()
	for _, Tween in { CameraTween, FocusTween, FovTween } do
		Tween:Cancel()
	end
	CameraTween, FocusTween, FovTween = nil, nil, nil
end

function CutsceneController:Begin(Character: Model, Transform: FrameTransform?)
	self:Finish(true)
	local Camera = workspace.CurrentCamera
	assert(Camera, "Cutscene requires a camera")
	State = {
		Camera = Camera,
		Character = Character,
		Frame = Camera.CFrame,
		Focus = Camera.Focus,
		Fov = Camera.FieldOfView,
		Subject = Camera.CameraSubject,
		MouseBehavior = UserInputService.MouseBehavior,
		MouseIcon = UserInputService.MouseIconEnabled,
		CutsceneAttribute = Character:GetAttribute("CameraCutscene"),
		Transform = Transform,
	}
	Pose.Value = Camera.CFrame
	Focus.Value = Camera.Focus.Position
	Character:SetAttribute("CameraCutscene", true)
	Controls:Disable()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = false
	Camera.CameraType = Enum.CameraType.Scriptable

	RunService:BindToRenderStep(BINDING, Enum.RenderPriority.Camera.Value + 4, function(DeltaTime: number)
		if State and workspace.CurrentCamera == Camera then
			Camera.CameraType = Enum.CameraType.Scriptable
			Camera.CFrame = if State.Transform then State.Transform(Pose.Value, DeltaTime) else Pose.Value
			Camera.Focus = CFrame.new(Focus.Value)
		end
	end)
end

function CutsceneController:SetView(Frame: CFrame, Target: Vector3, Fov: number)
	CancelTweens()
	Pose.Value, Focus.Value = Frame, Target
	if State then
		State.Camera.CFrame = Frame
		State.Camera.Focus = CFrame.new(Target)
		State.Camera.FieldOfView = Fov
	end
end

function CutsceneController:MoveTo(Frame: CFrame, Target: Vector3, Fov: number, Duration: number): boolean
	local Current = State
	if not Current then
		return false
	end
	CancelTweens()
	local Info = TweenInfo.new(Duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	CameraTween = TweenService:Create(Pose, Info, { Value = Frame })
	FocusTween = TweenService:Create(Focus, Info, { Value = Target })
	FovTween = TweenService:Create(Current.Camera, Info, { FieldOfView = Fov })
	CameraTween:Play()
	FocusTween:Play()
	FovTween:Play()
	local Completed = CameraTween.Completed:Wait()
	return State == Current and Completed == Enum.PlaybackState.Completed
end

function CutsceneController:Finish(RestorePose: boolean?)
	local Previous = State
	State = nil
	CancelTweens()
	RunService:UnbindFromRenderStep(BINDING)
	if not Previous then
		return
	end

	local Camera = Previous.Camera
	Camera.FieldOfView = Previous.Fov
	Camera.CameraSubject = Previous.Subject
	if RestorePose then
		Camera.CFrame, Camera.Focus = Previous.Frame, Previous.Focus
	end
	Camera.CameraType = Enum.CameraType.Custom
	if Previous.Character.Parent then
		Previous.Character:SetAttribute("CameraCutscene", Previous.CutsceneAttribute)
	end
	UserInputService.MouseBehavior = Previous.MouseBehavior
	UserInputService.MouseIconEnabled = Previous.MouseIcon
	Controls:Enable()
end

function CutsceneController:ShowInstruction(Title: string, Message: string)
	CutsceneUIController:ShowInstruction(Title, Message)
end

function CutsceneController:HideInstruction()
	CutsceneUIController:Finish()
end

function CutsceneController.KnitInit()
	CutsceneUIController = Knit.GetController("CutsceneUIController")
	Controls = require(Players.LocalPlayer.PlayerScripts.PlayerModule):GetControls()
end

return CutsceneController
