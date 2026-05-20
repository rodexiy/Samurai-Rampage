local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local Player = game.Players.LocalPlayer
local Character = Player.Character
local Humanoid = Character:WaitForChild("Humanoid")

local StaminaService = Knit.GetService("StaminaService")
local MovementService = Knit.GetService("MovementService")
local DeviceController = Knit.GetController("DeviceController")
local AnimationController = Knit.GetController("AnimationController")
local SkillTreeController = Knit.GetController("SkillTreeController")
local AlertController = Knit.GetController("AlertController")

local Validate = require(game.ReplicatedStorage.Shared.Validate)

local Camera = workspace.CurrentCamera

local AlignPosition
local AlignOrientation

local ClimbSpeed = 10

local GetModelMass = require(game.ReplicatedStorage.Shared.Utils.GetModelMass)

local Animator = AnimationController:GetAnimator(Character)

local MoveAnimation: AnimationTrack = Animator:LoadAnimation(game.ReplicatedStorage.Assets.Animations.Misc.Climb.Move)
local SetAutoRotate = require(game.ReplicatedStorage.Shared.Utils.SetAutoRotate)

local function StopClimb(DontApplyForce)
	RunService:UnbindFromRenderStep("Climbing")
	Character:SetAttribute("Climbing", false)

	task.spawn(function()
		MovementService:Climb(false)
	end)

	MoveAnimation:Stop()

	Humanoid.PlatformStand = false

	SetAutoRotate(Character, true)

	if AlignPosition then
		AlignPosition:Destroy()
	end

	if AlignOrientation then
		AlignOrientation:Destroy()
	end

	task.defer(function()
		if not DontApplyForce then
			local Mass = GetModelMass(Character)
			Character.PrimaryPart:ApplyImpulse(Vector3.new(0, 2, 0) * Mass)
		end
	end)
end

local RayParams = RaycastParams.new()
RayParams.FilterDescendantsInstances = { workspace.Entity, CollectionService:GetTagged("Unclimbable") }
RayParams.RespectCanCollide = true
RayParams.FilterType = Enum.RaycastFilterType.Exclude

local OverParams = OverlapParams.new()
OverParams.FilterDescendantsInstances = { workspace.Entity, CollectionService:GetTagged("Unclimbable") }
OverParams.FilterType = Enum.RaycastFilterType.Exclude

local function GetPosition(ray)
	return (CFrame.new(ray.Position, ray.Position + ray.Normal) * CFrame.new(0, 0, -1.5)).Position
end

local MoveVector = require(Player:WaitForChild("PlayerScripts").PlayerModule:WaitForChild("ControlModule"))

local CantMove = false

local function blockMove()
	CantMove = true
	task.spawn(function()
		local diffPos
		local diffRot
		repeat
			diffPos = (Character:GetPivot().Position - AlignPosition.Position).Magnitude
			diffRot = (Character:GetPivot().LookVector - AlignOrientation.CFrame.LookVector).Magnitude

			task.wait()
		until diffPos <= 0.5 and diffRot <= 0.5
		CantMove = false
	end)
end

local function filterPart(ray)
	local Part: BasePart = ray.Instance

	if not Part or Part:HasTag("Unclimbable") then
		return false
	end

	local size1 = Part.CFrame:VectorToWorldSpace(Part.Size)
	local size = CFrame.new(ray.Position, ray.Position + ray.Normal):VectorToWorldSpace(size1)
	local WorldSize = Vector3.new(math.abs(size.X), math.abs(size.Y), math.abs(size.Z))

	return WorldSize.X > 0.35 and WorldSize.Y > 0.35
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


		if not Validate:CanClimb(Character) then
			StopClimb(true)
			return
		end

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

		ClimbSpeed = 10

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
			local Drain = true
			while Character:GetAttribute("Climbing") do
				if not Drain or Character:GetAttribute("InCombat") then
					StaminaService:RemoveStamina(2.5)
				end
				task.wait(1)
			end
		end)

		if not MoveAnimation.IsPlaying then
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
				MoveAnimation:AdjustSpeed(0)

				return
			end

			local Direction = MoveVector:GetMoveVector()
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

			MoveAnimation:AdjustSpeed(AnimationSpeed)

			local vector = Vector2.new(X, Y).Unit

			local BottomRay = workspace:GetPartBoundsInBox(
				Character:GetPivot() * CFrame.new(0, -1, 0),
				Vector3.new(1, 0.5, 1),
				OverParams
			)
			if #BottomRay > 0 and Y < 0 then
				StopClimb()
				return
			end

			local TopRay = workspace:Raycast(
				Character:GetPivot().Position,
				Vector3.new(0, Character:GetPivot().UpVector * 1.5, 0),
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

				local angle = math.abs(math.acos(Character:GetPivot().LookVector:Dot(-FrontRay.Normal)))

				if angle > 50 then
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

DeviceController:BindAction("Climb", Climb.callback, "Climb", UDim2.fromScale(0.1, 0.2))

function Climb.Start()
	Character:GetAttributeChangedSignal("Climbing"):Connect(function()
		if not Character:GetAttribute("Climbing") then
			StopClimb()
		end
	end)
end

return Climb
