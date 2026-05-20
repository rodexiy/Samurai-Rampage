local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Player = game.Players.LocalPlayer
local Character = Player.Character
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

local Collector = require(game.ReplicatedStorage.Shared.Collector)
local Connections = Collector.new()

local Knit = require(game.ReplicatedStorage.Packages.Knit)
local DeviceController = Knit.GetController("DeviceController")

function getClosestEnemy()
	local dist = math.huge
	local closestEnemy
	local EnemiesInArea = {}

	for i, enemy in ipairs(game.Workspace.Entity:GetChildren()) do
		if enemy ~= Character then
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
		return false
	end
	return closestEnemy, EnemiesInArea
end
local Camera = workspace.CurrentCamera
local LockOn = {}
local enemyLocked

local ChangeDb = false
function ChangeTarget()
	local Delta = -UserInputService:GetMouseDelta().X

	if ChangeDb then
		return
	end
	if math.abs(Delta) > 10 then
		local _, Enemies = getClosestEnemy()
		local CameraPosition = Camera.CFrame.Position
		if not Enemies then
			return
		end
		local ClosestToAngle = math.huge
		local ClosestEnemy

		for _, Enemy in Enemies do
			if Enemy == enemyLocked then
				continue
			end

			local EnemyCFrame = Enemy:GetPivot()
			local EnemyPosition = EnemyCFrame.Position

			local _, angle = CFrame.new(CameraPosition, Vector3.new(EnemyPosition.X, CameraPosition.Y, EnemyPosition.Z))
				:ToOrientation()

			if angle < ClosestToAngle then
				ClosestToAngle = angle
				ClosestEnemy = Enemy
			end
		end

		if ClosestEnemy then
			Unlock()
			LockOn.callback(Enum.UserInputState.Begin)
			ChangeDb = true
			task.delay(0.15, function()
				ChangeDb = false
			end)
		end
	end
end

function Unlock()
	RunService:UnbindFromRenderStep("LockCameraRenderStep")
	Character:SetAttribute("LockedOnEnemy", false)

	Connections:DisconnectAll()

	if not enemyLocked then
		return
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	Camera.CameraType = Enum.CameraType.Custom
	UserInputService.MouseIconEnabled = true

	local highlight = enemyLocked:FindFirstChild("LockHighlight")

	if highlight then
		highlight:Destroy()
	end

	local billboard = enemyLocked.PrimaryPart:FindFirstChild("LockBillboard")

	if billboard then
		billboard:Destroy()
	end
end

local CameraPosition = Vector3.new(0, 3.5, 10)
local Params = RaycastParams.new()
Params.FilterType = Enum.RaycastFilterType.Exclude

LockOn.callback = function(inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return
	end

	local LockStatus = {
		[true] = function()
			local ClosestEnemy = getClosestEnemy()

			if not ClosestEnemy then
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

			RunService:BindToRenderStep("LockCameraRenderStep", Enum.RenderPriority.Camera.Value + 1, function(dt)
				if Character:GetAttribute("Died") or enemyLocked:GetAttribute("Downed") then
					Unlock()
					return
				end

				ChangeTarget()

				UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

				Params.FilterDescendantsInstances = { Workspace.Entity }

				local Lookat1 = CFrame.new(Character.Torso.CFrame.Position, enemyLocked.PrimaryPart.CFrame.Position)

				local Offseted = Lookat1 * CFrame.new(4.5, 3, 7.85)

				local PossiblePosition = Vector3.new(Offseted.X, Character.Torso.CFrame.Position.Y + 4.5, Offseted.Z)

				local PossibleDirection = (PossiblePosition - Character.Torso.CFrame.Position).Unit

				local Distance = (PossiblePosition - Character.Torso.CFrame.Position).Magnitude
				local ray = workspace:Raycast(Character.Torso.CFrame.Position, PossibleDirection * Distance, Params)
				if ray then
					PossiblePosition = ray.Position
				end

				local CameraCFrame = CFrame.new(PossiblePosition, enemyLocked.PrimaryPart.CFrame.Position)

				Camera.CFrame = Camera.CFrame:Lerp(CameraCFrame, 0.2 * (60 * dt))
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

function LockOn.Start() end

return LockOn
