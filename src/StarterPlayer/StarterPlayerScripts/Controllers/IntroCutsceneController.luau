local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local IntroCutsceneConfig = require(ReplicatedStorage.Shared.IntroCutsceneConfig)
local Constants = require(ReplicatedStorage.Shared.Constants)

local IntroCutsceneController = Knit.CreateController({
	Name = "IntroCutsceneController",
})

local Player = Players.LocalPlayer
local RainSound: Sound
local LightningController
local ShipAmbienceController
local CutsceneController
local CutsceneUIController
local CameraController
local AnimationController
local IntroCutsceneService
local ActiveToken: string?
local OpeningCharacter: Model?
local SwayWeight = 0
local ShipRotation = CFrame.identity
local IntroClouds: Clouds?
local OriginalCloudColor: Color3?
local SwayPausedAt: number?
local SwayTimeOffset = 0

local function GetHeadPosition(Actor: Model): Vector3
	local Head = Actor:FindFirstChild("Head") :: BasePart?
	return if Head then Head.Position else Actor:GetPivot().Position + Vector3.yAxis * 2
end

local function GetLockOnView(Character: Model, Boss: Model): (CFrame, Vector3)
	local PlayerFocus = Character:GetPivot().Position + Vector3.new(0, 1.2, 0)
	local EnemyFocus = Boss:GetPivot().Position + Vector3.yAxis
	local Difference = (EnemyFocus - PlayerFocus) * Vector3.new(1, 0, 1)
	local Facing = CFrame.lookAt(PlayerFocus, PlayerFocus + Difference)
	local Position = (Facing * CFrame.new(2.15 * CameraController:GetShoulderSide(), 1.8, IntroCutsceneConfig.Opening.CombatZoom)).Position
	Position = CameraController:GetCollisionSafePosition(PlayerFocus, Position)
	local Target = PlayerFocus:Lerp(EnemyFocus, 0.45)
	return CFrame.lookAt(Position, Target), Target
end

function IntroCutsceneController:PlayOpening(Token: string, Character: Model, ShipName: string, BossName: string)
	if ActiveToken == Token or Player.Character ~= Character then
		return
	end
	ActiveToken = Token
	OpeningCharacter = Character
	ShipAmbienceController:Stop()
	CutsceneUIController:Prepare()

	local ShipFolder = workspace:WaitForChild(IntroCutsceneConfig.ShipsFolderName)
	local Ship = ShipFolder:WaitForChild(ShipName, 15) :: Model?
	local Boss = workspace.Entity:WaitForChild(BossName, 15) :: Model?
	if not Ship or not Boss or ActiveToken ~= Token or Player.Character ~= Character then
		return
	end

	local function IsActive(): boolean
		return ActiveToken == Token and Player.Character == Character and Character.Parent ~= nil and Boss.Parent ~= nil
	end
	local Opening = IntroCutsceneConfig.Opening
	CutsceneController:Begin(Character, function(Frame: CFrame, DeltaTime: number): CFrame
		return self:ApplyCameraSway(Frame, DeltaTime)
	end)
	local ShipFrame = Ship:GetPivot()
	local EstablishTarget = ShipFrame:PointToWorldSpace(Opening.EstablishFocus)
	local Establish = CFrame.lookAt(ShipFrame:PointToWorldSpace(Opening.EstablishOffset), EstablishTarget)
	CutsceneController:SetView(Establish, EstablishTarget, Opening.EstablishFov)
	if not CutsceneUIController:FadeIn(Opening.FadeTime) or not IsActive() then
		return
	end
	if not CutsceneController:MoveTo(Establish, EstablishTarget, Opening.EstablishFov, Opening.EstablishTime) or not IsActive() then
		return
	end

	local BossTarget = GetHeadPosition(Boss)
	local BossView = CFrame.lookAt(Boss:GetPivot():PointToWorldSpace(Opening.BossCameraOffset), BossTarget)
	CutsceneController:SetView(BossView, BossTarget, Opening.BossFov)
	ShipAmbienceController:Start()
	CutsceneUIController:Say(IntroCutsceneConfig.BossName, Opening.BossLine, Opening.BossLineTime)
	if not CutsceneController:MoveTo(BossView, BossTarget, Opening.BossFov, Opening.BossLineTime) or not IsActive() then
		return
	end

	local PlayerTarget = GetHeadPosition(Character)
	local Profile = CFrame.lookAt(Character:GetPivot():PointToWorldSpace(Opening.PlayerCameraOffset), PlayerTarget)
	local ProfileEnd = CFrame.lookAt(Profile.Position + Profile.RightVector * Opening.PlayerCameraTravel, PlayerTarget)
	CutsceneController:SetView(Profile, PlayerTarget, Opening.PlayerFov)
	CutsceneUIController:Say("You", Opening.PlayerLine, Opening.PlayerLineTime)
	if not CutsceneController:MoveTo(ProfileEnd, PlayerTarget, Opening.PlayerFov, Opening.PlayerLineTime) or not IsActive() then
		return
	end

	CutsceneUIController:ClearDialogue()
	local CombatView, CombatFocus = GetLockOnView(Character, Boss)
	if not CutsceneController:MoveTo(CombatView, CombatFocus, Constants.DEFAULT_FIELD_OF_VIEW, Opening.TransitionTime) or not IsActive() then
		return
	end
	IntroCutsceneService.OpeningFinished:Fire(Token)
end

local function WatchCharacter(Character: Model)
	local function RequestOpening()
		if Player.Character == Character and Character:GetAttribute("Loaded") and Player:GetAttribute("InIntroCutscene") then
			IntroCutsceneService.RequestOpening:Fire(Character)
		end
	end

	if Player:GetAttribute("InIntroCutscene") then
		CutsceneUIController:Prepare()
	end
	Character:GetAttributeChangedSignal("Loaded"):Connect(RequestOpening)
	RequestOpening()
end

local function UpdateCloudColor(Active: boolean)
	if Active then
		if not IntroClouds then
			IntroClouds = workspace.Terrain:FindFirstChildWhichIsA("Clouds") :: Clouds?
			if IntroClouds then
				OriginalCloudColor = IntroClouds.Color
				IntroClouds.Color = IntroCutsceneConfig.Environment.CloudColor
			end
		end
	else
		if IntroClouds and IntroClouds.Parent and OriginalCloudColor then
			IntroClouds.Color = OriginalCloudColor
		end

		IntroClouds = nil
		OriginalCloudColor = nil
	end
end

local function GetIntroShip(): Model?
	local Ships = workspace:FindFirstChild(IntroCutsceneConfig.ShipsFolderName)
	local Ship = Ships and Ships:FindFirstChild("Ship_" .. Player.UserId) :: Model?
	return if Ship and Ship:IsA("Model") then Ship else nil
end

local function GetLightningCenter(): Vector3?
	local Ship = GetIntroShip()
	return if Ship then Ship:GetPivot().Position else nil
end

function IntroCutsceneController.GetSwayFrame(Frame: CFrame, ShipFrame: CFrame, Time: number, Weight: number): CFrame
	local Config = IntroCutsceneConfig.CameraSway
	local Roll = math.sin(Time * 2 * math.pi / math.max(Config.RollPeriod, 0.1)) * math.rad(Config.RollDegrees)
	local Pitch = math.sin(Time * 2 * math.pi / math.max(Config.PitchPeriod, 0.1) + math.pi / 3)
		* math.rad(Config.PitchDegrees)
	local Tilt = CFrame.Angles(Pitch * Weight, 0, Roll * Weight)
	local Rotation = ShipFrame.Rotation

	-- Rotate around the camera in ship axes, so turning around reverses the apparent roll.
	return CFrame.new(Frame.Position) * Rotation * Tilt * Rotation:Inverse() * Frame.Rotation
end

function IntroCutsceneController:SetSwayPaused(Paused: boolean)
	local Now = workspace:GetServerTimeNow()
	if Paused and not SwayPausedAt then
		SwayPausedAt = Now
	elseif not Paused and SwayPausedAt then
		SwayTimeOffset += Now - SwayPausedAt
		SwayPausedAt = nil
	end
end

function IntroCutsceneController:GetCombatView(Character: Model, Boss: Model): (CFrame, Vector3)
	return GetLockOnView(Character, Boss)
end

function IntroCutsceneController:ReleaseOpeningView(Character: Model, Boss: Model)
	CutsceneController:Finish()
	CutsceneUIController:Finish()
	Character:SetAttribute("CameraCutscene", false)
	Character:SetAttribute("IntroOpening", false)
	if not Character:GetAttribute("LockedOnEnemy") then
		local LockOn = require(Players.LocalPlayer.Character.Client.Actions.LockOn)
		LockOn.callback(Enum.UserInputState.Begin, nil, Boss, IntroCutsceneConfig.Opening.CombatZoom)
	end
end

function IntroCutsceneController:ApplyCameraSway(Frame: CFrame, DeltaTime: number): CFrame
	local Active = false
	local Character = Player.Character
	local Root = Character and Character.PrimaryPart
	if IntroCutsceneConfig.CameraSway.Enabled and Player:GetAttribute("InIntroStorm") and Root then
		local Ship = GetIntroShip()
		if Ship then
			local ShipFrame = Ship:GetPivot()
			Active = (Root.Position - ShipFrame.Position).Magnitude <= IntroCutsceneConfig.ExclusionRadius
			ShipRotation = ShipFrame.Rotation
		end
	end

	local Target = if Active then 1 else 0
	local Alpha = if SwayPausedAt then 0 else 1 - math.exp(-IntroCutsceneConfig.CameraSway.BlendResponse * math.max(DeltaTime, 0))
	SwayWeight += (Target - SwayWeight) * Alpha
	if SwayWeight < 0.0001 then
		SwayWeight = 0
		return Frame
	end

	return IntroCutsceneController.GetSwayFrame(Frame, ShipRotation, (SwayPausedAt or workspace:GetServerTimeNow()) - SwayTimeOffset, SwayWeight)
end

local function UpdateIntroEnvironment()
	if Player:GetAttribute("InIntroStorm") then
		UpdateCloudColor(true)

		if not RainSound.IsPlaying then
			RainSound:Play()
		end
		LightningController:StartStorm("IntroCutscene", GetLightningCenter, IntroCutsceneConfig.Lightning)
	else
		RainSound:Stop()
		LightningController:StopStorm("IntroCutscene")
		UpdateCloudColor(false)
	end
end

local function UpdateIntroEffects()
	if Player:GetAttribute("InIntroCutscene") then
		CutsceneUIController:Prepare()
	else
		ActiveToken = nil
		ShipAmbienceController:Stop()
		CutsceneController:Finish(true)
		CutsceneUIController:Finish()
	end
end

function IntroCutsceneController.KnitInit()
	LightningController = Knit.GetController("LightningController")
	ShipAmbienceController = Knit.GetController("ShipAmbienceController")
	CutsceneController = Knit.GetController("CutsceneController")
	CutsceneUIController = Knit.GetController("CutsceneUIController")
	CameraController = Knit.GetController("CameraController")
	AnimationController = Knit.GetController("AnimationController")
	IntroCutsceneService = Knit.GetService("IntroCutsceneService")
end

function IntroCutsceneController.KnitStart()
	IntroCutsceneService.OpeningStarted:Connect(function(Token: string, Character: Model, ShipName: string, BossName: string)
		task.spawn(function()
			local Success, Error = xpcall(function()
				IntroCutsceneController:PlayOpening(Token, Character, ShipName, BossName)
			end, debug.traceback)
			if not Success then
				warn("Intro opening failed:", Error)
			end
		end)
	end)
	IntroCutsceneService.DrawSword:Connect(function(Token: string, Character: Model, Boss: Model)
		if Token ~= ActiveToken then
			return
		end
		for _, Actor in { Character, Boss } do
			local Animations = AnimationController:GetCombatAnimationFolder(Actor)
			AnimationController:PlayAnimation(Actor, Animations.EquipDraw)
		end
	end)
	IntroCutsceneService.CombatStarted:Connect(function(Token: string, Character: Model, Boss: Model)
		if Token ~= ActiveToken or Player.Character ~= Character then
			return
		end

		ActiveToken = nil
		IntroCutsceneController:ReleaseOpeningView(Character, Boss)
	end)
	Player.CharacterAdded:Connect(WatchCharacter)
	Player.CharacterRemoving:Connect(function(Character: Model)
		if Character == OpeningCharacter then
			ShipAmbienceController:Stop()
			ActiveToken = nil
			OpeningCharacter = nil
			CutsceneController:Finish(true)
			CutsceneUIController:Finish()
		end
	end)

	RainSound = SoundService:WaitForChild("SoundServicePackage"):WaitForChild("Misc"):WaitForChild("RainSound") :: Sound
	RainSound.Looped = true

	Player:GetAttributeChangedSignal("InIntroCutscene"):Connect(UpdateIntroEffects)
	Player:GetAttributeChangedSignal("InIntroStorm"):Connect(UpdateIntroEnvironment)
	UpdateIntroEffects()
	UpdateIntroEnvironment()
	if Player.Character then
		WatchCharacter(Player.Character)
	end
end

return IntroCutsceneController
