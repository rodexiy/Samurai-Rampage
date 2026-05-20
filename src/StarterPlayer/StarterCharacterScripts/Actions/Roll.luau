local Knit = require(game.ReplicatedStorage.Packages.Knit)

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Validate = require(game.ReplicatedStorage.Shared.Validate)
local MovementService
local CameraController
local SoundEffectController
local DeviceController
local SkillTreeController

local Player = game.Players.LocalPlayer
local Character = Player.Character
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

local TeleportCharacter = require(game.ReplicatedStorage.Shared.Utils.TeleportCharacter)

local RollDirectionsAnimations = {
	Forward = Humanoid.Animator:LoadAnimation(game.ReplicatedStorage.Assets.Animations.Combat.Roll.Forward),
	Backward = Humanoid.Animator:LoadAnimation(game.ReplicatedStorage.Assets.Animations.Combat.Roll.Backward),
	Left = Humanoid.Animator:LoadAnimation(game.ReplicatedStorage.Assets.Animations.Combat.Roll.Left),
	Right = Humanoid.Animator:LoadAnimation(game.ReplicatedStorage.Assets.Animations.Combat.Roll.Right),
}
local Camera = game.Workspace.CurrentCamera

local GetModelMass = require(game.ReplicatedStorage.Shared.Utils.GetModelMass)

local _LinearVelocity
local Roll = {
	callback = function(inputState, inputObject)
		if inputState ~= Enum.UserInputState.Begin then
			return
		end
		if not Validate:CanRoll(Character) then
			return
		end

		Character:SetAttribute("RollClientDebounce", true)
		task.delay(0.5, function()
			Character:SetAttribute("RollClientDebounce", false)
		end)
		Character:SetAttribute("Rolling", true)

		local function MapKeys()
			local result = Vector3.new(0, 0, 0)

			if UserInputService:IsKeyDown(Enum.KeyCode.D) then
				result += Vector3.new(1, 0, 0)
			end

			if UserInputService:IsKeyDown(Enum.KeyCode.A) then
				result += Vector3.new(-1, 0, 0)
			end

			if UserInputService:IsKeyDown(Enum.KeyCode.W) then
				result += Vector3.new(0, 0, 1)
			end

			if UserInputService:IsKeyDown(Enum.KeyCode.S) then
				if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
					result += Vector3.new(0, 0, -1)
				else
					if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.D) then
						result = Vector3.new(0, 0, 1)
					else
						result += Vector3.new(0, 0, 1)
					end
				end
			end

			if result.Magnitude == 0 then
				result = Vector3.new(0, 0, -1)
			end

			return result
		end

		local function GetDirectionFromMap(map: Vector3)
			local dir = "Backward"

			if map.X == 1 then
				dir = "Right"
			end
			if map.X == -1 then
				dir = "Left"
			end

			if map.Z == 1 then
				dir = "Forward"
			end
			if map.Z == -1 then
				dir = "Backward"
			end

			if
				UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter
				and Humanoid.MoveDirection.Magnitude ~= 0
			then
				dir = "Forward"
			end

			return dir
		end

		local Direction = "Backward"

		local MoveDirection = Humanoid.MoveDirection
		local StarterDirection
		local map

		local function UpdateMoveDirection()
			if StarterDirection then
				return
			end

			map = MapKeys()
			local dir = GetDirectionFromMap(map)
			map = map.Unit

			Direction = dir
			StarterDirection = Direction
		end
		UpdateMoveDirection()

		task.spawn(function()
			MovementService:Roll(Direction, Character:GetPivot())
		end)

		local reversed = Vector3.new(map.X, 0, -map.Z).Unit

		local ForwardRayParams = RaycastParams.new()
		ForwardRayParams.RespectCanCollide = true

		ForwardRayParams.FilterDescendantsInstances = { CollectionService:GetTagged("Entity") }
		ForwardRayParams.FilterType = Enum.RaycastFilterType.Exclude

		if Character:GetAttribute("Race") == "Raijin"  then
			local LookDirection =
				CFrame.new(RootPart.CFrame.Position, (RootPart.CFrame * CFrame.new(reversed)).Position).LookVector.Unit

			local ForwardRay = Workspace:Raycast(RootPart:GetPivot().Position, LookDirection * 8, ForwardRayParams)
			if not ForwardRay then
				TeleportCharacter(Character, Character:GetPivot() * CFrame.new(reversed * 8))
			else
				TeleportCharacter(Character, Character:GetPivot() * CFrame.new(reversed * ForwardRay.Distance))
			end

			return
		end

		local RollAnimation = RollDirectionsAnimations[Direction] :: AnimationTrack
		if RollAnimation then
			RollAnimation.Priority = Enum.AnimationPriority.Action
			RollAnimation:Play()
		end

		task.spawn(function()
			for i = 0.1, 1, 0.1 do
				CameraController:SetCustomCameraSubjectCFrameOffset(
					CameraController:GetDefaultCameraSubjectCFrameOffset() * CFrame.new(0, -i, 0)
				)
				task.wait()
			end

			task.wait(0.25)
			local i = 1
			while i >= 0.1 do
				i -= 0.05
				CameraController:SetCustomCameraSubjectCFrameOffset(
					CameraController:GetDefaultCameraSubjectCFrameOffset() * CFrame.new(0, -i, 0)
				)
				task.wait()
			end

			CameraController:SetCustomCameraSubjectCFrameOffset(nil)
		end)

		local VelocityMultiplier = 200

		if Humanoid.MoveDirection.Magnitude == 0 then
			MoveDirection = -RootPart.CFrame.LookVector
		end

		local LinearVelocity = Instance.new("LinearVelocity")
		LinearVelocity.Attachment0 = RootPart.RootAttachment
		LinearVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		LinearVelocity.Visible = true
		LinearVelocity.MaxAxesForce = Vector3.new(1, 0, 1) * 25000
		LinearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector

		LinearVelocity.VectorVelocity = (
			CFrame.new(RootPart.CFrame.Position, RootPart.CFrame.Position + MoveDirection).LookVector
			* (GetModelMass(Character))
		) * 0.35
		RootPart.AssemblyLinearVelocity = Vector3.new(
			LinearVelocity.VectorVelocity.X,
			RootPart.AssemblyLinearVelocity.Y,
			LinearVelocity.VectorVelocity.Z
		)
		LinearVelocity.Parent = RootPart

		task.delay(0.15, function()
			LinearVelocity:Destroy()
			RootPart.AssemblyLinearVelocity = Vector3.new(0, RootPart.AssemblyLinearVelocity.Y, 0)
		end)

		task.spawn(function()
			while LinearVelocity and VelocityMultiplier > 38 and Character:GetAttribute("Rolling") do
				local LookDirection = CFrame.new(
					RootPart.CFrame.Position,
					(RootPart.CFrame * CFrame.new(reversed)).Position
				).LookVector.Unit

				local ForwardRay = Workspace:Raycast(RootPart:GetPivot().Position, LookDirection * 28, ForwardRayParams)
				if ForwardRay and ForwardRay.Distance <= 3 then
					RootPart.AssemblyLinearVelocity = Vector3.new(0, RootPart.AssemblyLinearVelocity.Y, 0)
					break
				end

				task.wait()
			end
		end)

		StarterDirection = nil
	end,

	keys = { Enum.KeyCode.Q },
}

function Roll.Start(_srvs)
	MovementService = Knit.GetService("MovementService")
	CameraController = Knit.GetController("CameraController")
	SoundEffectController = Knit.GetController("SoundEffectController")
	DeviceController = Knit.GetController("DeviceController")
	SkillTreeController = Knit.GetController("SkillTreeController")

	DeviceController:BindAction("Roll", Roll.callback, "Roll", UDim2.fromScale(0.925, 0.65))
end

return Roll
