local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local CameraController = Knit.CreateController({
	Name = "CameraController",
})

local Camera = workspace.CurrentCamera
local camShake
local CameraShaker = require(game.ReplicatedStorage.Assets.Libraries.CameraShaker)

local Player = game.Players.LocalPlayer
local Character
local Humanoid
local RootPart
local Torso
local HeadSubject

local LerpAlpha = 0.35

local HeadSubjectCFrame = nil
local CustomOffsetCFrame = nil

function CameraController:Shake(preset)
	camShake:Shake(preset)
end

function CameraController:ShakeOnce(magnitude: number, roughness: number, fadeInTime: number, fadeOutTime: number)
	if Player:GetAttribute("CameraShake") then
		camShake:ShakeOnce(magnitude, roughness, fadeInTime, fadeOutTime)
	end
end

local Turn = 0
local Lerp = function(a, b, t)
	return a + (b - a) * t
end

function CameraController:BindShiftLock()
	CameraController:UnbindShiftLock()

	RunService:BindToRenderStep("CameraUpdateFirst", Enum.RenderPriority.Input.Value, function(dt)
		local TorsoCF = Torso.CFrame * (CustomOffsetCFrame or CameraController:GetDefaultCameraSubjectCFrameOffset())
		local rx, _, rz = TorsoCF:ToOrientation()
		local TorsoCF = CFrame.new(TorsoCF.Position) * CFrame.Angles(rx, 0, rz)
		local cf = HeadSubjectCFrame or TorsoCF
		local rx, _, rz = cf:ToOrientation()
		local newCF = CFrame.new(HeadSubject.CFrame.X, cf.Y, HeadSubject.CFrame.Z) * CFrame.Angles(rx, 0, rz)

		HeadSubject.CFrame = HeadSubject.CFrame:Lerp(newCF, 1)
		HeadSubject.CFrame = HeadSubject.CFrame:Lerp(HeadSubjectCFrame or TorsoCF, 1)

		if not UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			HeadSubject.CFrame = HeadSubject.CFrame:Lerp(newCF, 0.85)
			HeadSubject.CFrame = HeadSubject.CFrame:Lerp(HeadSubjectCFrame or TorsoCF, LerpAlpha)
			HeadSubject.CFrame = HeadSubjectCFrame or TorsoCF
		end
	end)

	RunService:BindToRenderStep("CameraLockUpdate", Enum.RenderPriority.Character.Value + 1, function(dt)
		local MouseDelta = UserInputService:GetMouseDelta()
		if Character:GetAttribute("LockedOnEnemy") or not Player:GetAttribute("CameraTilt") then
			Turn = Lerp(0, math.clamp(MouseDelta.X, -3, 3), (5 * dt))
		else
			Turn = Lerp(Turn, math.clamp(MouseDelta.X, -3, 3), (5 * dt))
		end
		Camera.CFrame = Camera.CFrame * CFrame.Angles(0, 0, math.rad(Turn))

		local Alpha = if Character:GetAttribute("LockedOnEnemy") then 1 else 0.2
		if
			UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
			and Humanoid.AutoRotate
			and not Character:GetAttribute("PostureBreak")
			and not Character:GetAttribute("Ragdoll")
			and not Character:GetAttribute("Meditating")
			and not Character:GetAttribute("HeavyDeflect")
			and Humanoid:GetState() ~= Enum.HumanoidStateType.Seated
		then
			Character:PivotTo(
				Character:GetPivot():Lerp(
					CFrame.lookAt(
						RootPart.Position,
						RootPart.Position + Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
					),
					Alpha * dt * 35
				)
			)
		end
	end)
end

function CameraController:UnbindShiftLock()
	RunService:UnbindFromRenderStep("CameraLockUpdate")
	RunService:UnbindFromRenderStep("CameraUpdateFirst")
end

function CameraController:LerpHeadSubject(Cframe: CFrame, alpha: number)
	if not HeadSubject then
		return
	end

	local lerped = HeadSubject.CFrame:Lerp(Cframe, alpha)
	HeadSubjectCFrame = lerped
end

function CameraController:SetCameraLerpAlpha(alpha: number)
	LerpAlpha = alpha or 0.35
end

function CameraController:SetDefaultCameraLerpAlpha()
	LerpAlpha = 0.35
end

function CameraController:SetCustomCameraSubjectCFrameOffset(offset: CFrame)
	CustomOffsetCFrame = offset
end

function CameraController:GetDefaultCameraSubjectCFrameOffset(): CFrame
	return CFrame.new(0, 0.9, 0)
end

function CameraController:SetDefaultCameraSubjectCFrameOffset(): CFrame
	HeadSubjectCFrame = nil
end

function UpdateSubject()
	if Player:GetAttribute("AnimationsInfluence") then
		if HeadSubject then
			Camera.CameraSubject = HeadSubject
		end
	else
		if Humanoid then
			Camera.CameraSubject = Humanoid
		end
	end
end

function UpdateCharacter()
	Character = Player.Character or Player.CharacterAdded:Wait()
	RootPart = Character:WaitForChild("HumanoidRootPart", 15)
	Humanoid = Character:WaitForChild("Humanoid", 15)
	HeadSubject = Character:FindFirstChild("HeadSubject")
	if not HeadSubject then
		HeadSubject = Instance.new("Part")
		HeadSubject.Name = "HeadSubject"
		HeadSubject.Anchored = true
		HeadSubject.CanCollide = false
		HeadSubject.Transparency = 1
		HeadSubject.Size = Vector3.new(1, 1, 1)
		HeadSubject.Massless = true
		HeadSubject:PivotTo(RootPart.CFrame)
		HeadSubject.Parent = Character
	end

	Torso = Character:WaitForChild("Torso", 15)

	UpdateSubject()

	CameraController:BindShiftLock()
end

function CameraController.KnitStart()
	Player.CharacterAdded:Connect(function()
		UpdateCharacter()
	end)

	task.spawn(function()
		UpdateCharacter()
	end)

	Player:GetAttributeChangedSignal("AnimationsInfluence"):Connect(function(value)
		UpdateSubject()
	end)

	camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value + 5, function(shakeCFrame)
		Camera.CFrame = Camera.CFrame * shakeCFrame
	end)
	camShake:Start()
end

return CameraController
