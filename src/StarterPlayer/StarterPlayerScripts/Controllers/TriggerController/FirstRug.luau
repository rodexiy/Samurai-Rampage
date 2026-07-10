local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local CharacterShared = require(game.ReplicatedStorage.Shared.CharacterShared)

local Trigger = {}

local Player = Players.LocalPlayer
local TRIGGER_NAME = script.Name
local RUG_NAME = "Kawasaki Shrine"
local CAMERA_BIND_NAME = "FirstRugTriggerCamera"
local CAMERA_PART_NAMES = { "CameraPart", "Camera" }
local FOCUS_DURATION = 3
local ZOOM_FOV = 25
local MOVE_TIME = 0.7
local TURN_TIME = 0.7

local IsPlaying = false
Trigger.TriggerName = TRIGGER_NAME

local function GetCurrentCamera(): Camera
	return workspace.CurrentCamera
end

local function FindNamedPart(Parent: Instance, Names: { string }): BasePart?
	for _, Name in Names do
		local InstanceFound = Parent:FindFirstChild(Name, true)
		if InstanceFound and InstanceFound:IsA("BasePart") then
			return InstanceFound
		end
	end

	return nil
end

local function FindCameraPart(TriggerInstance: Instance, Rug: Instance): BasePart?
	return FindNamedPart(TriggerInstance, CAMERA_PART_NAMES) or FindNamedPart(Rug, CAMERA_PART_NAMES)
end

local function GetFocusPosition(InstanceToFocus: Instance): Vector3?
	if InstanceToFocus:IsA("BasePart") or InstanceToFocus:IsA("Model") then
		return InstanceToFocus:GetPivot().Position
	end

	local BasePart = InstanceToFocus:FindFirstChildWhichIsA("BasePart", true)
	return BasePart and BasePart.Position or nil
end

local function LookAtPosition(CameraPosition: Vector3, FocusPosition: Vector3, Fallback: CFrame): CFrame
	if (FocusPosition - CameraPosition).Magnitude < 0.1 then
		return Fallback
	end

	return CFrame.lookAt(CameraPosition, FocusPosition)
end

local function StopPlayer(Character: Model)
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	local RootPart = Character:FindFirstChild("HumanoidRootPart")
	local WasSkillLocked = Character:GetAttribute("SkillLockMovement") == true
	local WasAutoRotate = Humanoid and Humanoid.AutoRotate

	Character:SetAttribute("Running", false)
	Character:SetAttribute("SkillLockMovement", true)
	CharacterShared:UpdateBoth(Character)

	if Humanoid then
		Humanoid:Move(Vector3.zero)
		Humanoid.WalkSpeed = 0
		Humanoid.JumpPower = 0
		Humanoid.AutoRotate = false
	end

	if RootPart then
		RootPart.AssemblyLinearVelocity = Vector3.zero
		RootPart.AssemblyAngularVelocity = Vector3.zero
	end

	return function()
		if not Character.Parent then
			return
		end

		Character:SetAttribute("SkillLockMovement", WasSkillLocked)
		CharacterShared:UpdateBoth(Character)

		if Humanoid and Humanoid.Parent then
			Humanoid.AutoRotate = WasAutoRotate
		end
	end
end

local function RestoreCamera(Camera: Camera, OriginalState)
	RunService:UnbindFromRenderStep(CAMERA_BIND_NAME)

	Camera.CFrame = OriginalState.CFrame
	Camera.FieldOfView = OriginalState.FieldOfView
	Camera.CameraSubject = OriginalState.CameraSubject
	Camera.CameraType = OriginalState.CameraType
end

local function FocusCamera(CameraPart: BasePart, ShrinePosition: Vector3)
	local Camera = GetCurrentCamera()
	local OriginalState = {
		CameraType = Camera.CameraType,
		CameraSubject = Camera.CameraSubject,
		FieldOfView = Camera.FieldOfView,
		CFrame = Camera.CFrame,
	}

	local CameraCFrame = Instance.new("CFrameValue")
	CameraCFrame.Value = Camera.CFrame

	RunService:UnbindFromRenderStep(CAMERA_BIND_NAME)
	Camera.CameraType = Enum.CameraType.Scriptable
	Camera.CFrame = CameraCFrame.Value

	RunService:BindToRenderStep(CAMERA_BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		Camera.CameraType = Enum.CameraType.Scriptable
		Camera.CFrame = CameraCFrame.Value
	end)

	local CameraPartCFrame = CameraPart.CFrame
	local ShrineCFrame = LookAtPosition(CameraPartCFrame.Position, ShrinePosition, CameraPartCFrame)

	local MoveTween = TweenService:Create(
		CameraCFrame,
		TweenInfo.new(MOVE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Value = CameraPartCFrame }
	)
	local FovTween = TweenService:Create(
		Camera,
		TweenInfo.new(MOVE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ FieldOfView = ZOOM_FOV }
	)

	MoveTween:Play()
	FovTween:Play()
	MoveTween.Completed:Wait()

	local TurnTween = TweenService:Create(
		CameraCFrame,
		TweenInfo.new(TURN_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ Value = ShrineCFrame }
	)

	TurnTween:Play()
	TurnTween.Completed:Wait()
	task.wait(FOCUS_DURATION)

	RestoreCamera(Camera, OriginalState)
	CameraCFrame:Destroy()
end

function Trigger.Enter(TriggerController, TriggerInstance: Instance)
	if IsPlaying or TriggerController:IsCompleted(TRIGGER_NAME) then
		return
	end

	IsPlaying = true

	local Character = Player.Character or Player.CharacterAdded:Wait()
	local Rugs = workspace:FindFirstChild("Rugs")
	local Rug = Rugs and Rugs:FindFirstChild(RUG_NAME)

	if not Character or not Rug then
		IsPlaying = false
		return
	end

	local CameraPart = FindCameraPart(TriggerInstance, Rug)
	local ShrinePosition = GetFocusPosition(Rug)

	if not CameraPart or not ShrinePosition then
		IsPlaying = false
		return
	end

	local ResumePlayer = StopPlayer(Character)
	local Success, Result = pcall(function()
		FocusCamera(CameraPart, ShrinePosition)
	end)

	ResumePlayer()

	if not Success then
		RunService:UnbindFromRenderStep(CAMERA_BIND_NAME)
		warn(Result)
		IsPlaying = false
		return
	end

	TriggerController:TriggerCompleted(TRIGGER_NAME)
	IsPlaying = false
end

return Trigger
