local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Validate = require(ReplicatedStorage.Shared.Validate)
local TeleportCharacter = require(ReplicatedStorage.Shared.Utils.TeleportCharacter)
local GetModelMass = require(ReplicatedStorage.Shared.Utils.GetModelMass)
local RollDirection = require(ReplicatedStorage.Shared.Utils.RollDirection)
local SetAutoRotate = require(ReplicatedStorage.Shared.Utils.SetAutoRotate)
local TalentConfig = require(ReplicatedStorage.Shared.SkillTreeConfig)

local MovementService, CameraController, DeviceController, SkillTreeController
local Player = Players.LocalPlayer
local Character = Player.Character :: Model
local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
local RootPart = Character.PrimaryPart
assert(RootPart, "Character must have a PrimaryPart")

local Animator = Humanoid:WaitForChild("Animator") :: Animator
local RollDirectionsAnimations = {
	Forward = Animator:LoadAnimation(ReplicatedStorage.Assets.Animations.Combat.Roll.Forward),
	Backward = Animator:LoadAnimation(ReplicatedStorage.Assets.Animations.Combat.Roll.Backward),
	Left = Animator:LoadAnimation(ReplicatedStorage.Assets.Animations.Combat.Roll.Left),
	Right = Animator:LoadAnimation(ReplicatedStorage.Assets.Animations.Combat.Roll.Right),
}

local function GetMovement(): Vector3
	if Humanoid.MoveDirection.Magnitude > 0.001 then
		return Humanoid.MoveDirection
	end

	local Camera = workspace.CurrentCamera
	local X = (if UserInputService:IsKeyDown(Enum.KeyCode.D) then 1 else 0)
		- (if UserInputService:IsKeyDown(Enum.KeyCode.A) then 1 else 0)
	local Z = (if UserInputService:IsKeyDown(Enum.KeyCode.S) then 1 else 0)
		- (if UserInputService:IsKeyDown(Enum.KeyCode.W) then 1 else 0)
	if Camera and (X ~= 0 or Z ~= 0) then
		local Forward = Camera.CFrame.LookVector * Vector3.new(1, 0, 1)
		if Forward.Magnitude > 0.001 then
			return CFrame.lookAt(Vector3.zero, Forward):VectorToWorldSpace(Vector3.new(X, 0, Z))
		end
	end

	return Vector3.zero
end

local function AnimateCamera()
	local Elapsed = 0
	local Connection: RBXScriptConnection
	Connection = RunService.PreRender:Connect(function(DeltaTime: number)
		Elapsed += DeltaTime
		if Player.Character ~= Character or not RootPart.Parent or Elapsed >= 0.65 then
			Connection:Disconnect()
			CameraController:SetCustomCameraSubjectCFrameOffset(nil)
			return
		end

		local Depth = if Elapsed < 0.1 then Elapsed / 0.1
			elseif Elapsed < 0.35 then 1 else 1 - (Elapsed - 0.35) / 0.3
		CameraController:SetCustomCameraSubjectCFrameOffset(
			CameraController:GetDefaultCameraSubjectCFrameOffset() * CFrame.new(0, -Depth, 0)
		)
	end)
end

local Roll = {
	callback = function(InputState: Enum.UserInputState, _InputObject: InputObject?)
		if InputState ~= Enum.UserInputState.Begin or not Validate:CanRoll(Character) then
			return
		end

		local FacingLocked = CameraController:IsFacingCamera()
		local WasRunning = Character:GetAttribute("Running") == true
		local Camera = workspace.CurrentCamera
		local Facing = RootPart.CFrame
		if FacingLocked and Camera then
			local Flat = Camera.CFrame.LookVector * Vector3.new(1, 0, 1)
			if Flat.Magnitude > 0.001 then
				Facing = CFrame.lookAt(RootPart.Position, RootPart.Position + Flat)
			end
		end
		local Direction, Movement = RollDirection.Resolve(Facing, GetMovement(), FacingLocked, WasRunning)
		local FirstPerson = Camera ~= nil and (Camera.CFrame.Position - Camera.Focus.Position).Magnitude <= 1
		CameraController:ReleaseRotation()
		if not FacingLocked and not FirstPerson then
			RootPart.CFrame = CFrame.lookAt(RootPart.Position, RootPart.Position + Movement)
		end
		Character:SetAttribute("RollClientDebounce", true)
		Character:SetAttribute("Rolling", true)
		local RollDuration, DistanceMultiplier = TalentConfig.GetRollProfile(
			SkillTreeController:IsSkillUnlocked("Long Roll"), SkillTreeController:IsSkillUnlocked("Short Roll")
		)
		task.delay(RollDuration, function()
			Character:SetAttribute("RollClientDebounce", false)
		end)
		local StartFrame = Character:GetPivot()
		task.spawn(function()
			MovementService:Roll(Direction, StartFrame)
		end)

		local Params = RaycastParams.new()
		Params.RespectCanCollide = true
		Params.FilterDescendantsInstances = CollectionService:GetTagged("Entity")
		Params:AddToFilter(Character)
		Params.FilterType = Enum.RaycastFilterType.Exclude

		local HasLightningDash = Character:GetAttribute("Race") == "Raijin"
			and SkillTreeController:IsSkillUnlocked("Lightning Dash")
		if HasLightningDash then
			local Hit = workspace:Raycast(RootPart.Position, Movement * 8, Params)
			local Distance = if Hit then math.max(0, Hit.Distance - 0.5) else 8
			TeleportCharacter(Character, Character:GetPivot() + Movement * Distance)
			return
		end

		local Animation = RollDirectionsAnimations[Direction] :: AnimationTrack
		Animation.Priority = Enum.AnimationPriority.Action
		Animation:Play()
		Animation:AdjustSpeed(0.5 / RollDuration)
		AnimateCamera()

		local WasAutoRotate = Humanoid.AutoRotate
		Humanoid.AutoRotate = false
		local Velocity = Instance.new("LinearVelocity")
		Velocity.Attachment0 = RootPart:WaitForChild("RootAttachment") :: Attachment
		Velocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		Velocity.MaxAxesForce = Vector3.new(1, 0, 1) * 25000
		Velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		Velocity.VectorVelocity = Movement * GetModelMass(Character) * 0.35 * DistanceMultiplier
		RootPart.AssemblyLinearVelocity = Vector3.new(Velocity.VectorVelocity.X,
			RootPart.AssemblyLinearVelocity.Y, Velocity.VectorVelocity.Z)
		Velocity.Parent = RootPart

		local Stopped = false
		local CollisionConnection: RBXScriptConnection?
		local function Stop()
			if Stopped then
				return
			end
			Stopped = true
			if CollisionConnection then
				CollisionConnection:Disconnect()
			end
			Velocity:Destroy()
			if RootPart.Parent then
				RootPart.AssemblyLinearVelocity = Vector3.new(0, RootPart.AssemblyLinearVelocity.Y, 0)
				if WasAutoRotate then
					SetAutoRotate(Character, true)
				end
			end
		end
		CollisionConnection = RunService.PreSimulation:Connect(function()
			if Player.Character ~= Character or not RootPart.Parent or not Character:GetAttribute("Rolling") then
				Stop()
				return
			end
			local Hit = workspace:Raycast(RootPart.Position, Movement * 3, Params)
			if Hit then
				Stop()
			end
		end)
		task.delay(0.15, Stop)
	end,

	keys = { Enum.KeyCode.Q },
}

function Roll.Start(_Services: any)
	MovementService = Knit.GetService("MovementService")
	CameraController = Knit.GetController("CameraController")
	DeviceController = Knit.GetController("DeviceController")
	SkillTreeController = Knit.GetController("SkillTreeController")

	DeviceController:BindAction("Roll", Roll.callback, "Roll", UDim2.fromScale(0.925, 0.65))
end

return Roll
