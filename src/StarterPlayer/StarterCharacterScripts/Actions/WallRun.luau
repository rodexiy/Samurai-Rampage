local RunService = game:GetService("RunService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local Player = game.Players.LocalPlayer
local Character = Player.Character
local Humanoid = Character:WaitForChild("Humanoid")

local StaminaService = Knit.GetService("StaminaService")
local DeviceController = Knit.GetController("DeviceController")
local AnimationController = Knit.GetController("AnimationController")
local SkillTreeController = Knit.GetController("SkillTreeController")
local Validate = require(game.ReplicatedStorage.Shared.Validate)

local Animator = AnimationController:GetAnimator(Character)
local AnimRight: AnimationTrack = Animator:LoadAnimation(game.ReplicatedStorage.Assets.Animations.Misc.WallRun.Right)
local AnimLeft: AnimationTrack = Animator:LoadAnimation(game.ReplicatedStorage.Assets.Animations.Misc.WallRun.Left)
local AnimRightJump: AnimationTrack =
	Animator:LoadAnimation(game.ReplicatedStorage.Assets.Animations.Misc.WallRun.RightJumpOff)
local AnimLeftJump: AnimationTrack =
	Animator:LoadAnimation(game.ReplicatedStorage.Assets.Animations.Misc.WallRun.LeftJumpOff)

local GetModelMass = require(game.ReplicatedStorage.Shared.Utils.GetModelMass)
local SetAutoRotate = require(game.ReplicatedStorage.Shared.Utils.SetAutoRotate)

local running = false
local sideRunning = nil
local lastRun = 0
local AlignVelocity
local currentNormal = nil

local WallCheckDistance = 1.65
local Duration = 3
local Cooldown = 1.5
local DrainRate = 15 -- per second
local MaxAngle = math.rad(90) -- ~50 degrees

local function getStamina()
	return Character:GetAttribute("Stamina") or 0
end

local function isAirborne()
	local state = Humanoid:GetState()
	return state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
end

local function stopRun()
	if running then
		running = false
		sideRunning = nil
		currentNormal = nil
		AnimRight:Stop()
		AnimLeft:Stop()
	end
	if AlignVelocity then
		AlignVelocity:Destroy()
		AlignVelocity = nil
	end

	RunService:UnbindFromRenderStep("WallRunCheck")
	SetAutoRotate(Character, true)
	Character:SetAttribute("WallRunning", false)
end

local RayParams = RaycastParams.new()
RayParams.FilterDescendantsInstances = { Character }
RayParams.FilterType = Enum.RaycastFilterType.Blacklist

local function checkWall()
	local root = Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil, nil
	end

	local origin = root.Position
	local look = root.CFrame.LookVector
	local rightVec = root.CFrame.RightVector

	local right = workspace:Raycast(origin + look * 1, rightVec * WallCheckDistance, RayParams)
	if right then
		return "Right", right
	end

	local left = workspace:Raycast(origin + look * 1, -rightVec * WallCheckDistance, RayParams)
	if left then
		return "Left", left
	end

	return nil, nil
end

local function jumpOff(side)
	local root = Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	AnimRight:Stop()
	AnimLeft:Stop()

	if side == "Right" then
		AnimRightJump:Play()
	elseif side == "Left" then
		AnimLeftJump:Play()
	end

	local awayVector
	if side == "Right" then
		awayVector = -root.CFrame.RightVector
	elseif side == "Left" then
		awayVector = root.CFrame.RightVector
	else
		awayVector = root.CFrame.LookVector
	end

	local mass = GetModelMass(Character)
	local jumpVelocity = (awayVector * 6) + (root.CFrame.LookVector * 6) + Vector3.new(0, 6, 0)
	root:ApplyImpulse(jumpVelocity * mass)

	stopRun()
end

local wallrun = {
	callback = function(inputState, _inputObject)
		if inputState ~= Enum.UserInputState.Begin then
			return
		end

		if running then
			jumpOff(sideRunning)
			return
		end

		if not isAirborne() then
			return
		end

		if tick() - lastRun < Cooldown then
			return
		end
		if not Validate:CanWallRun(Character) then
			return
		end
		
		if not RunService:IsStudio() then
			if not SkillTreeController:IsSkillUnlocked("WallRun") and not Player:GetAttribute("LearningWallRun") then
				return
			end
		end

		local side, ray = checkWall()
		if not side or not ray then
			return
		end

		local forward = Character:GetPivot().LookVector
		local angle = math.abs(math.acos(forward:Dot(-ray.Normal)))
		if angle > MaxAngle then
			return
		end

		local root = Character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end

		running = true
		sideRunning = side
		currentNormal = ray.Normal
		lastRun = tick()
		Character:SetAttribute("WallRunning", true)
		SetAutoRotate(Character, false)

		if side == "Right" then
			AnimLeft:Stop()
			AnimRight:Play()
		else
			AnimRight:Stop()
			AnimLeft:Play()
		end

		AlignVelocity = Instance.new("BodyVelocity")
		AlignVelocity.MaxForce = Vector3.new(1e4, 1e4, 1e4)
		AlignVelocity.Parent = root

		task.spawn(function()
			while running do
				task.wait()
			end
			stopRun()
		end)

		RunService:BindToRenderStep("WallRunCheck", Enum.RenderPriority.Character.Value + 1, function()
			if not running then
				return
			end
			local sideCheck, newRay = checkWall()
			if not sideCheck or sideCheck ~= sideRunning then
				stopRun()
				return
			end

			local forwardVec = Character:GetPivot().LookVector
			local newAngle = math.abs(math.acos(forwardVec:Dot(-newRay.Normal)))
			if newAngle > MaxAngle then
				stopRun()
				return
			end

			local forwardHit = workspace:Raycast(root.Position, forwardVec * 2, RayParams)
			if forwardHit and forwardHit.Instance and forwardHit.Instance.CanCollide then
				stopRun()
				return
			end

			if not Validate:CanWallRun(Character) then
				stopRun()
				return
			end

			currentNormal = newRay.Normal

			local alongWall = (forwardVec - forwardVec:Dot(currentNormal) * currentNormal).Unit
			AlignVelocity.Velocity = alongWall * 22
		end)
	end,

	keys = { Enum.KeyCode.Space },
}

DeviceController:BindAction("WallRun", wallrun.callback, "WallRun", UDim2.fromScale(0.2, 0.2))

function wallrun.Start()
	Character:GetAttributeChangedSignal("WallRunning"):Connect(function()
		if not Character:GetAttribute("WallRunning") then
			stopRun()
		end
	end)
end

return wallrun
