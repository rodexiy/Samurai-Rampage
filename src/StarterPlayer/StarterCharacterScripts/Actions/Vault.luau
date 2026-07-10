local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)
local Player = game.Players.LocalPlayer
local Character = Player.Character
local Humanoid = Character:WaitForChild("Humanoid")
local DeviceController = Knit.GetController("DeviceController")
local AnimationController = Knit.GetController("AnimationController")
local Validate = require(game.ReplicatedStorage.Shared.Validate)
local Animator = AnimationController:GetAnimator(Character)

local VaultAnimLeft: AnimationTrack =
	Animator:LoadAnimation(game.ReplicatedStorage.Assets.Animations.Misc.Vault.VaultLeft)
local VaultAnimRight: AnimationTrack =
	Animator:LoadAnimation(game.ReplicatedStorage.Assets.Animations.Misc.Vault.VaultRight)

local GetModelMass = require(game.ReplicatedStorage.Shared.Utils.GetModelMass)
local SetAutoRotate = require(game.ReplicatedStorage.Shared.Utils.SetAutoRotate)

local Vaulting = false
local ForwardCheckDistance = 6
local VaultSpeed = 25
local MaxVaultMargin = 2

local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.RespectCanCollide = true

local OverParams = OverlapParams.new()
OverParams.FilterType = Enum.RaycastFilterType.Exclude
OverParams.RespectCanCollide = true

local function StopVault()
	if Vaulting then
		Vaulting = false
		VaultAnimLeft:Stop()
		VaultAnimRight:Stop()
	end
	SetAutoRotate(Character, true)
	Character:SetAttribute("Vaulting", false)
end

local function ValidateObstacle(hit, root)
	if not hit or not hit.Instance or not hit.Instance:IsA("BasePart") then
		return nil, nil
	end

	local obstacle = hit.Instance
	local obstacleTop = obstacle.Position.Y + (obstacle.Size.Y / 2)
	local charY = root.Position.Y

	if (obstacleTop - charY) > (0.5 + MaxVaultMargin) then
		return nil, nil
	end

	local forward = root.CFrame.LookVector
	local upForward = (forward + Vector3.new(0, 1, 0)).Unit
	local diagOrigin = Vector3.new(root.Position.X, obstacleTop + 1, root.Position.Z)
	local diagRay = workspace:Raycast(diagOrigin, upForward * 3, RayParams)
	if diagRay and diagRay.Instance and diagRay.Instance.CanCollide then
		return nil, nil
	end

	return hit, obstacleTop
end



local function CheckVaultable()
	local root = Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil, nil
	end

	local forward = root.CFrame.LookVector
	local blockSize = Vector3.new(2, 1, 0.01)
	local offsets = { -1.5, -0.5, 0.5 }

	local bestHit, bestTop = nil, nil

	for _, yOffset in ipairs(offsets) do
		local origin = root.CFrame * CFrame.new(0, yOffset, -blockSize.Z / 2)

		local result = workspace:Blockcast(origin, blockSize, forward * ForwardCheckDistance, RayParams)
	

		local validHit, obstacleTop = ValidateObstacle(result, root)
		if validHit then
			bestHit, bestTop = validHit, obstacleTop
		end
	end

	return bestHit, bestTop
end



local function IsClearPosition(targetPos, root)
	local size = Vector3.new(2,  2, 2)
	local cf = CFrame.new(targetPos)


	local overlap = workspace:GetPartBoundsInBox(cf, size, OverParams)
	for _, part in ipairs(overlap) do
		local minVolume = 0.2 * 0.2 * 0.2
		if part.CanCollide and not part:IsDescendantOf(Character) then
			if part.Size.X * part.Size.Y * part.Size.Z > minVolume then
				if part.Position.Y < targetPos.Y - (Humanoid.HipHeight * 0.5) then
					continue
				end

				return false
			end
		end
	end

	local forwardOffset = Vector3.new(0, Humanoid.HipHeight * 0.5, 0)
	local forwardOrigin = targetPos + forwardOffset
	local direction = root.CFrame.LookVector * 1.5

	local forwardCheck = workspace:Raycast(forwardOrigin, direction, RayParams)
	if forwardCheck and forwardCheck.Instance and forwardCheck.Instance.CanCollide then
		return false
	end

	return true
end


local vault = {
	callback = function(inputState, _inputObject)
		if inputState ~= Enum.UserInputState.Begin then
			return
		end
		if Vaulting then
			return
		end
	
		RayParams.FilterDescendantsInstances = { CollectionService:GetTagged("Entity"), workspace.NPCs }
		OverParams.FilterDescendantsInstances = { CollectionService:GetTagged("Entity"), workspace.NPCs  }

		local hit, obstacleTop = CheckVaultable()
		if not hit or not obstacleTop then
			return
		end

		local root = Character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end

		Vaulting = true
		Character:SetAttribute("Vaulting", true)
		root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)

		local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit

		local targetPos = root.Position + forward * 3
		targetPos = Vector3.new(targetPos.X, root.Position.Y + 1.5, targetPos.Z)

		if not IsClearPosition(targetPos, root) then
			StopVault()
			return
		end
		SetAutoRotate(Character, false)

		if math.random() < 0.5 then
			VaultAnimLeft:Play()
		else
			VaultAnimRight:Play()
		end

		root.AssemblyLinearVelocity = (forward * VaultSpeed * GetModelMass(Character)) * 0.013

		task.delay(0.6,function()
			StopVault()
		end)
	end,

	keys = { Enum.KeyCode.Space },
}


function vault.Start()
	Character:GetAttributeChangedSignal("Vaulting"):Connect(function()
		if not Character:GetAttribute("Vaulting") then
			StopVault()
		end
	end)
end

return vault
