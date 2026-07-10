local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local Player = game.Players.LocalPlayer
local Character = Player.Character
assert(Character, "[Climb] Character was not available.")

local Humanoid = Character:FindFirstChildOfClass("Humanoid") or Character:WaitForChild("Humanoid", 5)
assert(Humanoid, "[Climb] Humanoid was not available.")

local StaminaService
local MovementService
local DeviceController
local AnimationController
local SkillTreeController
local AlertController
local MoveVector

local Validate = require(game.ReplicatedStorage.Shared.Validate)

local Camera = workspace.CurrentCamera

local AlignPosition
local AlignOrientation

local ClimbSpeed = 10
local MaxClimbNormalY = 0.75
local MaxClimbAngle = math.rad(50)

local GetModelMass = require(game.ReplicatedStorage.Shared.Utils.GetModelMass)

local MoveAnimation: AnimationTrack
local SetAutoRotate = require(game.ReplicatedStorage.Shared.Utils.SetAutoRotate)

local function StopClimb(DontApplyForce)
	RunService:UnbindFromRenderStep("Climbing")
	Character:SetAttribute("Climbing", false)

	task.spawn(function()
		if MovementService then
			MovementService:Climb(false)
		end
	end)

	if MoveAnimation then
		MoveAnimation:Stop()
	end

	Humanoid.PlatformStand = false

	SetAutoRotate(Character, true)

	if AlignPosition then
		AlignPosition:Destroy()
		AlignPosition = nil
	end

	if AlignOrientation then
		AlignOrientation:Destroy()
		AlignOrientation = nil
	end

	task.defer(function()
		if not DontApplyForce then
			local Mass = GetModelMass(Character)
			Character.PrimaryPart:ApplyImpulse(Vector3.new(0, 2, 0) * Mass)
		end
	end)
end

local RayParams = RaycastParams.new()
RayParams.RespectCanCollide = true
RayParams.FilterType = Enum.RaycastFilterType.Exclude

local OverParams = OverlapParams.new()
OverParams.FilterType = Enum.RaycastFilterType.Exclude

local function refreshFilters()
	local Filter = {}
	local Entity = workspace:FindFirstChild("Entity")

	if Entity then
		table.insert(Filter, Entity)
	end

	for _, Instance in CollectionService:GetTagged("Unclimbable") do
		table.insert(Filter, Instance)
	end

	RayParams.FilterDescendantsInstances = Filter
	OverParams.FilterDescendantsInstances = Filter
end

refreshFilters()

local function GetPosition(ray)
	return (CFrame.new(ray.Position, ray.Position + ray.Normal) * CFrame.new(0, 0, -1.5)).Position
end

local CantMove = false
local MoveBlockId = 0

local function setupMoveVector()
	local PlayerScripts = Player:WaitForChild("PlayerScripts", 5)
	if not PlayerScripts then
		warn("[Climb] PlayerScripts was not available; falling back to keyboard climb input.")
		return
	end

	local PlayerModule = PlayerScripts:WaitForChild("PlayerModule", 5)
	if not PlayerModule then
		warn("[Climb] PlayerModule was not available; falling back to keyboard climb input.")
		return
	end

	local ControlModule = PlayerModule:WaitForChild("ControlModule", 5)
	if not ControlModule then
		warn("[Climb] ControlModule was not available; falling back to keyboard climb input.")
		return
	end

	MoveVector = require(ControlModule)
end

local function getMoveVector()
	if MoveVector then
		return MoveVector:GetMoveVector()
	end

	return Vector3.zero
end

local function blockMove()
	MoveBlockId += 1
	local BlockId = MoveBlockId
	local Timeout = os.clock() + 0.5

	CantMove = true
	task.spawn(function()
		while Character:GetAttribute("Climbing") and AlignPosition and AlignOrientation and os.clock() < Timeout do
			local diffPos = (Character:GetPivot().Position - AlignPosition.Position).Magnitude
			local diffRot = (Character:GetPivot().LookVector - AlignOrientation.CFrame.LookVector).Magnitude

			if diffPos <= 0.5 and diffRot <= 0.5 then
				break
			end

			task.wait()
		end

		if BlockId == MoveBlockId then
			CantMove = false
		end
	end)
end

local function isTerrain(ray)
	return ray.Instance == workspace.Terrain or ray.Instance:IsA("Terrain")
end

local function filterPart(ray)
	local Part = ray.Instance

	if not Part or CollectionService:HasTag(Part, "Unclimbable") then
		return false
	end

	if isTerrain(ray) then
		return ray.Material ~= Enum.Material.Water and math.abs(ray.Normal.Y) <= MaxClimbNormalY
	end

	if not Part:IsA("BasePart") then
		return false
	end

	local size1 = Part.CFrame:VectorToWorldSpace(Part.Size)
	local size = CFrame.new(ray.Position, ray.Position + ray.Normal):VectorToWorldSpace(size1)
	local WorldSize = Vector3.new(math.abs(size.X), math.abs(size.Y), math.abs(size.Z))

	return WorldSize.X > 0.35 and WorldSize.Y > 0.35
end

local function isGroundBelow()
	local BottomParts = workspace:GetPartBoundsInBox(
		Character:GetPivot() * CFrame.new(0, -1, 0),
		Vector3.new(1, 0.5, 1),
		OverParams
	)
	if #BottomParts > 0 then
		return true
	end

	local BottomRay = workspace:Raycast(Character:GetPivot().Position, Vector3.new(0, -2, 0), RayParams)
	return BottomRay and isTerrain(BottomRay) and BottomRay.Normal.Y > MaxClimbNormalY
end

local function getSurfaceAngle(ray)
	local Dot = math.clamp(Character:GetPivot().LookVector:Dot(-ray.Normal), -1, 1)
	return math.acos(Dot)
end

local Climb = {
	callback = function(inputState, inputObject)
		if inputState ~= Enum.UserInputState.Begin then
			return
		end

		if Character:GetAttribute("LearningWallRun") then
			AlertController:Alert("Cannot climb while learning wall run", "Error")
			return
		end
		if Character:GetAttribute("Climbing") then
			StopClimb(true)
			return
		end

		if not SkillTreeController:IsSkillUnlocked("Climb") then
			return
		end

		if not Validate:CanClimb(Character) then
			StopClimb(true)
			return
		end

		refreshFilters()

		local FindRay = workspace:Raycast(Character:GetPivot().Position, Character:GetPivot().LookVector * 3, RayParams)

		if not FindRay then
			return
		end

		if not filterPart(FindRay) then
			return
		end

		task.spawn(function()
			MovementService:Climb(true)
		end)
		Character:SetAttribute("Climbing", true)

		if SkillTreeController:IsSkillUnlocked("Climb Speed") then
			ClimbSpeed = 15
		else
			ClimbSpeed = 10
		end

		Humanoid.PlatformStand = true
		SetAutoRotate(Character, false)

		AlignPosition = Instance.new("AlignPosition")
		AlignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
		AlignPosition.Attachment0 = Character.HumanoidRootPart.RootAttachment
		AlignPosition.RigidityEnabled = true
		AlignPosition.Position = GetPosition(FindRay)
		AlignPosition.Parent = Character

		AlignOrientation = Instance.new("AlignOrientation")
		AlignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		AlignOrientation.Attachment0 = Character.HumanoidRootPart.RootAttachment
		AlignOrientation.RigidityEnabled = true
		AlignOrientation.CFrame = CFrame.new(FindRay.Position, FindRay.Position - FindRay.Normal)
		AlignOrientation.Parent = Character

		task.spawn(function()
			local Drain = SkillTreeController:IsSkillUnlocked("No Climb Stamina Drain")
			while Character:GetAttribute("Climbing") do
				if not Drain or Character:GetAttribute("InCombat") then
					StaminaService:RemoveStamina(2.5)
				end
				task.wait(1)
			end
		end)

		if MoveAnimation and not MoveAnimation.IsPlaying then
			MoveAnimation:Play()
		end

		RunService:BindToRenderStep("Climbing", Enum.RenderPriority.Character.Value + 1, function(dt)
			if Character:GetAttribute("Stamina") < 1 or Character:GetAttribute("BeenHitted") then
				StopClimb(true)
				return
			end

			local CharacterX = Character:GetPivot():ToOrientation()
			if math.abs(math.deg(CharacterX)) > 45 then
				StopClimb()
				return
			end

			if CantMove then
				return
			end
			if Humanoid.MoveDirection.Magnitude == 0 then
				if MoveAnimation then
					MoveAnimation:AdjustSpeed(0)
				end

				return
			end

			local Direction = getMoveVector()
			local X = Direction.X
			local Y = -Direction.Z

			if UserInputService:IsKeyDown(Enum.KeyCode.D) then
				X = 1
			end

			if UserInputService:IsKeyDown(Enum.KeyCode.A) then
				X = -1
			end

			if UserInputService:IsKeyDown(Enum.KeyCode.W) then
				Y = 1
			end

			if UserInputService:IsKeyDown(Enum.KeyCode.S) then
				Y = -1
			end

			local AnimationSpeed = 1
			if Y ~= 0 then
				AnimationSpeed = Y
			end

			if MoveAnimation then
				MoveAnimation:AdjustSpeed(AnimationSpeed)
			end

			local vector = Vector2.new(X, Y)
			if vector.Magnitude == 0 then
				if MoveAnimation then
					MoveAnimation:AdjustSpeed(0)
				end

				return
			end
			vector = vector.Unit

			if isGroundBelow() and Y < 0 then
				StopClimb()
				return
			end

			local TopRay = workspace:Raycast(
				Character:GetPivot().Position,
				Character:GetPivot().UpVector * 1.5,
				RayParams
			)
			if TopRay and Y > 0 then
				return
			end

			if X ~= 0 then
				local SideRay = workspace:Raycast(
					(Character:GetPivot() * CFrame.new(0, 0, -1)).Position,
					(Character:GetPivot().RightVector * X) * 1.5,
					RayParams
				)

				if SideRay then
					if not filterPart(SideRay) then
						StopClimb()
						return
					end

					AlignPosition.Position = (
						CFrame.new(SideRay.Position, SideRay.Position - SideRay.Normal)
						* CFrame.new((X * 1), 0, 1.5)
					).Position
					AlignOrientation.CFrame = CFrame.new(SideRay.Position, SideRay.Position - SideRay.Normal)
					blockMove()
					return
				end
			end

			local FrontRay =
				workspace:Raycast(Character:GetPivot().Position, Character:GetPivot().LookVector * 3, RayParams)
			if FrontRay then
				if not filterPart(FrontRay) then
					StopClimb()
					return
				end
				local NewCFrame = CFrame.new(FrontRay.Position, FrontRay.Position - FrontRay.Normal)

				local angle = getSurfaceAngle(FrontRay)

				if angle > MaxClimbAngle then
					StopClimb()
					return
				end

				local Position = GetPosition(FrontRay)
				AlignPosition.Position = (CFrame.new(Position, Position - FrontRay.Normal) * CFrame.new(
					vector.X * dt * ClimbSpeed,
					vector.Y * dt * ClimbSpeed,
					0
				)).Position

				AlignOrientation.CFrame = NewCFrame
				return
			end

			local turnOrigin = Character:GetPivot().Position + (Character:GetPivot().LookVector * 1.75)

			local CheckTurnOriginRay =
				workspace:Raycast(turnOrigin, -(Character:GetPivot().LookVector * 1.75), RayParams)

			local turnDirection = (UserInputService:IsKeyDown(Enum.KeyCode.D) and -Character:GetPivot().RightVector)
				or Character:GetPivot().RightVector

			local TurnRay = workspace:Raycast(turnOrigin, turnDirection, RayParams)

			if not CheckTurnOriginRay and TurnRay then
				if FrontRay and FrontRay.Instance ~= FrontRay.Instance then
					return
				end

				if not filterPart(TurnRay) then
					StopClimb()
					return
				end
				AlignPosition.Position = GetPosition(TurnRay)
				AlignOrientation.CFrame = CFrame.new(TurnRay.Position, TurnRay.Position - TurnRay.Normal)

				blockMove()
			end

			if not FrontRay and not TurnRay then
				StopClimb()
			end
		end)
	end,

	keys = { Enum.KeyCode.G },
}

function Climb.Start()
	StaminaService = Knit.GetService("StaminaService")
	MovementService = Knit.GetService("MovementService")
	DeviceController = Knit.GetController("DeviceController")
	AnimationController = Knit.GetController("AnimationController")
	SkillTreeController = Knit.GetController("SkillTreeController")
	AlertController = Knit.GetController("AlertController")

	local Animator = AnimationController:GetAnimator(Character)
	MoveAnimation = Animator:LoadAnimation(game.ReplicatedStorage.Assets.Animations.Misc.Climb.Move)

	task.spawn(setupMoveVector)

	DeviceController:BindAction("Climb", Climb.callback, "Climb", UDim2.fromScale(0.1, 0.2))

	Character:GetAttributeChangedSignal("Climbing"):Connect(function()
		if not Character:GetAttribute("Climbing") then
			StopClimb()
		end
	end)
end

return Climb
