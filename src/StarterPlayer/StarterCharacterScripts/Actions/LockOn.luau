local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Player = Players.LocalPlayer
local Character = Player.Character :: Model
local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
local RootPart = Character.PrimaryPart
assert(RootPart, "Character must have a PrimaryPart")

local Collector = require(ReplicatedStorage.Shared.Collector)
local Connections = Collector.new()

local Knit = require(ReplicatedStorage.Packages.Knit)
local DeviceController = Knit.GetController("DeviceController")
local CameraController = Knit.GetController("CameraController")

local function getClosestEnemy(): (Model?, { Model })
	local dist = math.huge
	local closestEnemy
	local EnemiesInArea = {}

	for _, enemy in workspace.Entity:GetChildren() do
		if enemy:IsA("Model") and enemy ~= Character and not enemy:GetAttribute("Died") and not enemy:GetAttribute("Downed") then
			local Primary = enemy.PrimaryPart
			if not Primary then
				continue
			end
			local diff = (Primary.CFrame.Position - RootPart.CFrame.Position).Magnitude
			if diff < 50 then
				table.insert(EnemiesInArea, enemy)
				if diff <= dist then
					dist = diff
					closestEnemy = enemy
				end
			end
		end
	end

	if closestEnemy == nil then
		return nil, EnemiesInArea
	end
	return closestEnemy, EnemiesInArea
end
local Camera = workspace.CurrentCamera
local LockOn = {}
local enemyLocked: Model? = nil
local PreviousMouseBehavior = Enum.MouseBehavior.Default
local PreviousMouseIconEnabled = true
local PreviousMouseLocked: boolean? = nil
local SmoothedCameraPosition = Vector3.zero
local SmoothedFocus = Vector3.zero
local CombatZoomDistance = 8
local SmoothedZoomDistance = 8
local Unlock: () -> ()

local ChangeDb = false
local function ChangeTarget()
	local Delta = UserInputService:GetMouseDelta().X

	if ChangeDb then
		return
	end
	if math.abs(Delta) > 10 then
		local _, Enemies = getClosestEnemy()
		local CameraPosition = Camera.CFrame.Position
		if not enemyLocked or not enemyLocked.PrimaryPart then
			return
		end
		local CurrentDirection = Camera.CFrame:VectorToObjectSpace(enemyLocked.PrimaryPart.Position - CameraPosition)
		local CurrentAngle = math.atan2(CurrentDirection.X, -CurrentDirection.Z)
		local ClosestToAngle = math.huge
		local ClosestEnemy

		for _, Enemy in Enemies do
			if Enemy == enemyLocked then
				continue
			end

			local EnemyDirection = Camera.CFrame:VectorToObjectSpace(Enemy:GetPivot().Position - CameraPosition)
			local Angle = math.atan2(EnemyDirection.X, -EnemyDirection.Z) - CurrentAngle
			Angle = math.atan2(math.sin(Angle), math.cos(Angle))

			if Angle * Delta > 0 and math.abs(Angle) < ClosestToAngle then
				ClosestToAngle = math.abs(Angle)
				ClosestEnemy = Enemy
			end
		end

		if ClosestEnemy then
			local PreviousZoom = CombatZoomDistance
			Unlock()
			LockOn.callback(Enum.UserInputState.Begin, nil, ClosestEnemy, PreviousZoom)
			ChangeDb = true
			task.delay(0.15, function()
				ChangeDb = false
			end)
		end
	end
end

Unlock = function()
	RunService:UnbindFromRenderStep("LockCameraRenderStep")
	Character:SetAttribute("LockedOnEnemy", false)

	Connections:DisconnectAll()

	if not enemyLocked then
		return
	end
	Player:SetAttribute("MouseLocked", PreviousMouseLocked)
	UserInputService.MouseBehavior = PreviousMouseBehavior
	UserInputService.MouseIconEnabled = PreviousMouseIconEnabled
	if not Character:GetAttribute("CameraCutscene") then
		CameraController:SetCombatZoomDistance(CombatZoomDistance)
		Camera.CameraType = Enum.CameraType.Custom
		CameraController:BlendFromCurrentCamera()
	end

	local highlight = enemyLocked:FindFirstChild("LockHighlight")

	if highlight then
		highlight:Destroy()
	end

	local PrimaryPart = enemyLocked.PrimaryPart
	local billboard = PrimaryPart and PrimaryPart:FindFirstChild("LockBillboard")

	if billboard then
		billboard:Destroy()
	end

	enemyLocked = nil
end

LockOn.callback = function(inputState: Enum.UserInputState, _Input: InputObject?, TargetOverride: Model?, ZoomOverride: number?)
	if inputState ~= Enum.UserInputState.Begin or Character:GetAttribute("BowEquipped") then
		return
	end

	local LockStatus = {
		[true] = function()
			Camera = workspace.CurrentCamera
			if not Camera or Camera.CameraType ~= Enum.CameraType.Custom
				or Character:GetAttribute("RealmTeleporting") or Character:GetAttribute("CameraCutscene")
			then
				return
			end

			local ClosestEnemy = TargetOverride or getClosestEnemy()

			if not ClosestEnemy or not ClosestEnemy.PrimaryPart or not ClosestEnemy.Parent then
				return
			end

			if Character:GetAttribute("Died") then
				return
			end

			if Character:GetAttribute("Meditating") then
				return
			end

			if ClosestEnemy:GetAttribute("Downed") then
				return
			end

			if not ClosestEnemy then
				return
			end

			enemyLocked = ClosestEnemy
			PreviousMouseBehavior = UserInputService.MouseBehavior
			PreviousMouseIconEnabled = UserInputService.MouseIconEnabled
			PreviousMouseLocked = Player:GetAttribute("MouseLocked")
			SmoothedCameraPosition = Camera.CFrame.Position
			SmoothedFocus = Camera.Focus.Position
			CombatZoomDistance = ZoomOverride or CameraController:GetCombatZoomDistance()
			SmoothedZoomDistance = CombatZoomDistance
			Connections:Add(UserInputService.InputChanged:Connect(function(Input: InputObject, GameProcessed: boolean)
				if GameProcessed or Input.UserInputType ~= Enum.UserInputType.MouseWheel then
					return
				end

				local Minimum, Maximum = CameraController:GetCombatZoomLimits()
				CombatZoomDistance = math.clamp(CombatZoomDistance - Input.Position.Z * 1.25, Minimum, Maximum)
			end))
			Connections:Add(enemyLocked:GetAttributeChangedSignal("Died"):Connect(function()
				Unlock()
			end))

			Connections:Add(enemyLocked:GetAttributeChangedSignal("Downed"):Connect(function()
				Unlock()
			end))

			local highlight = Instance.new("Highlight")
			highlight.Name = "LockHighlight"
			highlight.FillTransparency = 1
			highlight.OutlineColor = Color3.fromRGB(244, 0, 0)
			highlight.OutlineTransparency = 0.25
			highlight.Parent = enemyLocked

			Character:SetAttribute("LockedOnEnemy", true)
			Player:SetAttribute("MouseLocked", false)

			Camera.CameraType = Enum.CameraType.Scriptable
			UserInputService.MouseIconEnabled = false

			RunService:BindToRenderStep("LockCameraRenderStep", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
				if not Character.Parent or not enemyLocked or not enemyLocked.Parent or not enemyLocked.PrimaryPart
					or Character:GetAttribute("Died") or Character:GetAttribute("Meditating")
					or Character:GetAttribute("RealmTeleporting")
					or Character:GetAttribute("CameraCutscene")
					or enemyLocked:GetAttribute("Died") or enemyLocked:GetAttribute("Downed")
					or workspace.CurrentCamera ~= Camera
				then
					Unlock()
					return
				end

				local MouseUnlocked = CameraController:IsMouseUnlocked()
				if not MouseUnlocked then
					ChangeTarget()
				end
				if not enemyLocked or not enemyLocked.PrimaryPart then
					return
				end

				UserInputService.MouseBehavior = if MouseUnlocked then Enum.MouseBehavior.Default else Enum.MouseBehavior.LockCenter
				UserInputService.MouseIconEnabled = MouseUnlocked

				local PlayerFocus = RootPart.Position + Vector3.new(0, 1.2, 0)
				local EnemyFocus = enemyLocked.PrimaryPart.Position + Vector3.new(0, 1, 0)
				local Difference = EnemyFocus - PlayerFocus
				if Difference.Magnitude > 65 then
					Unlock()
					return
				end

				local FlatDirection = Difference * Vector3.new(1, 0, 1)
				if FlatDirection.Magnitude < 0.001 then
					return
				end

				local Facing = CFrame.lookAt(PlayerFocus, PlayerFocus + FlatDirection)
				local Alpha = 1 - math.exp(-10 * math.max(dt, 0))
				SmoothedZoomDistance += (CombatZoomDistance - SmoothedZoomDistance) * Alpha
				local DesiredPosition = (Facing * CFrame.new(2.15 * CameraController:GetShoulderSide(), 1.8, SmoothedZoomDistance)).Position
				DesiredPosition = CameraController:GetCollisionSafePosition(PlayerFocus, DesiredPosition)
				SmoothedCameraPosition = CameraController:GetCollisionSafePosition(
					PlayerFocus,
					SmoothedCameraPosition:Lerp(DesiredPosition, Alpha)
				)
				SmoothedFocus = SmoothedFocus:Lerp(PlayerFocus:Lerp(EnemyFocus, 0.45), Alpha)
				if (SmoothedFocus - SmoothedCameraPosition).Magnitude > 0.001 then
					Camera.CFrame = CFrame.lookAt(SmoothedCameraPosition, SmoothedFocus)
					Camera.Focus = CFrame.new(SmoothedFocus)
				end

				if Humanoid.AutoRotate and not Character:GetAttribute("Ragdoll")
					and not Character:GetAttribute("PostureBreak") and not Character:GetAttribute("HeavyDeflect")
					and not Character:GetAttribute("Climbing")
				then
					RootPart.CFrame = RootPart.CFrame:Lerp(
						CFrame.lookAt(RootPart.Position, RootPart.Position + FlatDirection),
						1 - math.exp(-15 * math.max(dt, 0))
					)
				end
			end)
		end,

		[false] = function()
			Unlock()
		end,
	}

	if LockStatus[not Character:GetAttribute("LockedOnEnemy")] then
		LockStatus[not Character:GetAttribute("LockedOnEnemy")]()
	end
end

LockOn.keys = { Enum.KeyCode.T }

DeviceController:BindAction("LockOn", LockOn.callback, "LockOn", UDim2.fromScale(0.175, 0.2))

function LockOn.Start()
	Character:GetAttributeChangedSignal("BowEquipped"):Connect(function()
		if Character:GetAttribute("BowEquipped") then
			Unlock()
		end
	end)

	Character:GetAttributeChangedSignal("CameraCutscene"):Connect(function()
		if Character:GetAttribute("CameraCutscene") then
			Unlock()
		end
	end)

	local RemovingConnection: RBXScriptConnection? = nil
	RemovingConnection = Player.CharacterRemoving:Connect(function(RemovingCharacter: Model)
		if RemovingCharacter == Character then
			Unlock()
			if RemovingConnection then
				RemovingConnection:Disconnect()
			end
		end
	end)
end

return LockOn
