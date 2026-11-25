local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local IntroCutsceneConfig = require(ReplicatedStorage.Shared.IntroCutsceneConfig)
local Constants = require(ReplicatedStorage.Shared.Constants)
local TsunamiCutsceneController = Knit.CreateController({ Name = "TsunamiCutsceneController" })

type Sequence = {
	Token: string,
	Character: Model,
	Boss: Model,
	Revealed: boolean,
	WakingUp: boolean?,
	Wave: Model?,
	Umibozu: Model?,
	WaveStartPosition: Vector3?,
	WaveTravelDistance: number?,
	Sound: Sound?,
	Values: { CFrameValue },
	Tweens: { Tween },
	Animations: { AnimationTrack },
	Grounding: {
		Restore: () -> (),
		Connections: { RBXScriptConnection },
	}?,
}

type ParryState = {
	Token: string,
	Character: Model,
	Boss: Model,
	Tracks: { AnimationTrack },
}

local Player = Players.LocalPlayer
local Config = IntroCutsceneConfig.Tsunami
local WakeUpConfig = IntroCutsceneConfig.WakeUp
local Active: Sequence?
local Parry: ParryState?
local IntroCutsceneService
local IntroCutsceneController
local CutsceneController
local CutsceneUIController
local ShipAmbienceController
local CombatMusicController
local AnimationController
local RenderController
local CameraController
local WakeUpAnimation = Instance.new("Animation")
WakeUpAnimation.Name = "IntroWakeUp"
WakeUpAnimation.AnimationId = IntroCutsceneConfig.WakeUp.AnimationId

local function IsActive(Sequence: Sequence): boolean
	return Active == Sequence and Player.Character == Sequence.Character
		and Sequence.Character.Parent ~= nil and (Sequence.WakingUp == true or Sequence.Boss.Parent ~= nil)
end

local function ApplyWaveShake(Sequence: Sequence, Frame: CFrame): CFrame
	local Shake = Config.CameraShake
	local Wave, Start, Distance = Sequence.Wave, Sequence.WaveStartPosition, Sequence.WaveTravelDistance
	if not Shake.Enabled or Player:GetAttribute("CameraShake") == false then
		return Frame
	end

	local Strength = Shake.WarningStrength
	if Wave and Wave.Parent and Start and Distance and Distance > 0 then
		local Progress = math.clamp((Wave:GetPivot().Position - Start).Magnitude / Distance, 0, 1)
		Strength += (1 - Strength) * Progress ^ Shake.RampPower
	end

	local Time = os.clock() * Shake.Frequency
	local Offset = Vector3.new(math.noise(Time, 11, 0), math.noise(Time, 23, 0) * 0.7, math.noise(Time, 37, 0) * 0.4)
		* (2 * Shake.PositionAmplitude * Strength)
	local Angle = math.rad(Shake.RotationDegrees) * Strength * 2

	return Frame * CFrame.new(Offset) * CFrame.Angles(
		math.noise(Time, 41, 0) * Angle,
		math.noise(Time, 53, 0) * Angle * 0.6,
		math.noise(Time, 67, 0) * Angle * 0.5
	)
end

local function ClearVisuals(Sequence: Sequence)
	if Sequence.Grounding then
		local Grounding = Sequence.Grounding
		for _, Connection in Grounding.Connections do
			Connection:Disconnect()
		end
		Grounding.Restore()
		Sequence.Grounding = nil
	end

	for _, Track in Sequence.Animations do
		Track:Stop(0.1)
		Track:Destroy()
	end
	Sequence.Animations = {}

	for _, Tween in Sequence.Tweens do
		Tween:Cancel()
	end
	for _, Value in Sequence.Values do
		Value:Destroy()
	end
	if Sequence.Wave then
		Sequence.Wave:Destroy()
		Sequence.Wave = nil
	end
	if Sequence.Umibozu then
		Sequence.Umibozu:Destroy()
		Sequence.Umibozu = nil
	end
	Sequence.WaveStartPosition = nil
	Sequence.WaveTravelDistance = nil
	Sequence.Tweens = {}
	Sequence.Values = {}
end

local function CancelParry()
	local Previous = Parry
	Parry = nil
	if not Previous then
		return
	end

	for _, Track in Previous.Tracks do
		Track:Stop(0.1)
		Track:Destroy()
	end
end

local function Cancel()
	CancelParry()
	local Previous = Active
	Active = nil
	if Previous then
		ClearVisuals(Previous)
		if Previous.Sound then
			Previous.Sound:Destroy()
		end
		CombatMusicController:Restore()
		CutsceneController:Finish(true)
		CutsceneUIController:Finish()
	end
end

local function TweenModel(Sequence: Sequence, Model: Model, Target: CFrame, Duration: number, EasingStyle: Enum.EasingStyle?): Tween
	local Value = Instance.new("CFrameValue")
	Value.Value = Model:GetPivot()
	table.insert(Sequence.Values, Value)
	Value.Changed:Connect(function(Frame: CFrame)
		if IsActive(Sequence) and Model.Parent then
			Model:PivotTo(Frame)
		end
	end)
	local Tween = TweenService:Create(Value, TweenInfo.new(Duration, EasingStyle or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		Value = Target,
	})
	table.insert(Sequence.Tweens, Tween)
	Tween:Play()
	return Tween
end

local function StopAttacks(Actor: Model)
	local Humanoid = Actor:FindFirstChildWhichIsA("Humanoid")
	local Animator = Humanoid and Humanoid:FindFirstChildWhichIsA("Animator")
	if Animator then
		for _, Track in Animator:GetPlayingAnimationTracks() do
			if Track.Priority.Value >= Enum.AnimationPriority.Action.Value then
				Track:Stop(0.1)
			end
		end
	end
end

local function PlayIdle(Sequence: Sequence, Actor: Model)
	StopAttacks(Actor)
	local Preset = ReplicatedStorage.Assets.Presets:FindFirstChild(Actor:GetAttribute("AnimationPreset") or "Default")
	local Idle = Preset and Preset:FindFirstChild("idle") or ReplicatedStorage.Assets.Presets.Default:FindFirstChild("idle")
	local Animation = if Idle and Idle:IsA("Animation") then Idle else Idle and Idle:FindFirstChildWhichIsA("Animation")
	if not Animation then
		return
	end

	local Track = AnimationController:PlayAnimation(Actor, Animation)
	if Track then
		Track.Name = "IntroTsunamiIdle"
		Track.Priority = Enum.AnimationPriority.Action
		Track.Looped = true
		Track:AdjustSpeed(1)
		table.insert(Sequence.Animations, Track)
	end
end

local function CloneVisualModel(ModelName: string, Name: string): Model
	local Template = ReplicatedStorage.Assets.Models.TutorialCutscene:FindFirstChild(ModelName) :: Model?
	assert(Template and Template:IsA("Model"), "Intro cutscene template is missing: " .. ModelName)
	local Model = Template:Clone()
	Model.Name = Name
	for _, Instance in Model:QueryDescendants("BasePart") do
		local Part = Instance :: BasePart
		Part.Anchored = true
		Part.CanCollide = false
		Part.CanTouch = false
		Part.CanQuery = false
	end

	return Model
end

local function CreateWave(Sequence: Sequence, Ship: Model, Center: Vector3, Direction: Vector3, CameraPosition: Vector3): CFrame
	local Wave = CloneVisualModel(Config.ModelName, "IntroTsunami")
	Sequence.Wave = Wave

	local Bounds, Size = Wave:GetBoundingBox()
	local LocalCenter = Wave:GetPivot():PointToObjectSpace(Bounds.Position)
	local _, ShipSize = Ship:GetBoundingBox()
	local Rotation = Ship:GetPivot().Rotation
	local Height = IntroCutsceneConfig.Lightning.SurfaceY + Size.Y * 0.5 + Config.WaveVerticalOffset
	local Distance = ShipSize.X * 0.5 + Size.X * 0.5 + Config.WaveGap
	local Start = Center + Direction * Distance
	-- End with the leading edge at the camera, rather than the model's center.
	local Finish = CameraPosition + Direction * (Size.X * 0.5 - Config.WaveEndPastCamera)
	-- The template travels along local -X, and its pivot is offset from its bounds.
	local function AtCenter(Position: Vector3): CFrame
		return CFrame.new(Position.X, Height, Position.Z) * Rotation * CFrame.new(-LocalCenter)
	end

	Wave:PivotTo(AtCenter(Start))
	Sequence.WaveStartPosition = Wave:GetPivot().Position
	Sequence.WaveTravelDistance = (AtCenter(Finish).Position - Wave:GetPivot().Position).Magnitude
	return AtCenter(Finish)
end

local function RevealUmibozu(Sequence: Sequence, Direction: Vector3): boolean
	local Settings = Config.Umibozu
	local Wave = assert(Sequence.Wave, "Intro tsunami was removed")
	local Umibozu = CloneVisualModel(Settings.ModelName, "IntroUmibozu")
	Sequence.Umibozu = Umibozu
	Umibozu:ScaleTo(Umibozu:GetScale() * Settings.Scale)

	local Bounds, Size = Umibozu:GetBoundingBox()
	local LocalCenter = Umibozu:GetPivot():PointToObjectSpace(Bounds.Position)
	local WaveBounds, WaveSize = Wave:GetBoundingBox()
	local Position = WaveBounds.Position + Direction * (WaveSize.X * 0.5 + Size.Z * 0.5 + Settings.BehindWaveGap)
	local Height = IntroCutsceneConfig.Lightning.SurfaceY + Size.Y * 0.5 + Settings.VerticalOffset
	local Rotation = CFrame.lookAt(Vector3.zero, Direction)
		* CFrame.Angles(math.rad(Settings.ForwardTiltDegrees), math.rad(Settings.YawDegrees), 0)
	local Target = CFrame.new(Position.X, Height, Position.Z) * Rotation * CFrame.new(-LocalCenter)
	local VerticalSize = math.abs(Rotation.RightVector.Y) * Size.X + math.abs(Rotation.UpVector.Y) * Size.Y
		+ math.abs(Rotation.LookVector.Y) * Size.Z
	Umibozu:PivotTo(Target - Vector3.yAxis * (VerticalSize + math.abs(Settings.VerticalOffset)))
	Umibozu.Parent = workspace

	local Rise = TweenModel(Sequence, Umibozu, Target, Settings.RiseTime)
	if Rise.Completed:Wait() ~= Enum.PlaybackState.Completed or not IsActive(Sequence) then
		return false
	end

	task.wait(Settings.HoldTime)
	return IsActive(Sequence)
end

function TsunamiCutsceneController:PlayHeavyParry(Token: string, Character: Model, Boss: Model)
	if Player.Character ~= Character or Active or (Parry and Parry.Token == Token) then
		return
	end
	CancelParry()
	local State: ParryState = { Token = Token, Character = Character, Boss = Boss, Tracks = {} }
	Parry = State
	CutsceneUIController:Prepare(false)
	CutsceneController:Begin(Character)

	for _, Actor in { Character, Boss } do
		StopAttacks(Actor)
		local Track = AnimationController:PlayAnimation(Actor, ReplicatedStorage.Assets.Animations.Combat.HeavyDeflect)
		if Track then
			Track.Name = "IntroHeavyParry"
			Track.Priority = Enum.AnimationPriority.Action4
			Track.Looped = false
			table.insert(State.Tracks, Track)
		end
		RenderController.Render({ Module = "Combat", Effect = "HeavyDeflect", Character = Actor, Attacker = Actor == Character and Boss or Character })
	end
	RenderController.Render({ Module = "Combat", Effect = "Deflect", Character = Character, Attacker = Boss })
end

function TsunamiCutsceneController:Begin(Token: string, Character: Model, Boss: Model)
	if Player.Character ~= Character or (Active and Active.Token == Token) then
		return
	end
	Cancel()
	local Sequence: Sequence = {
		Token = Token, Character = Character, Boss = Boss, Revealed = false,
		Values = {}, Tweens = {}, Animations = {},
	}
	Active = Sequence
	CombatMusicController:FadeOut(Config.CombatMusicFadeTime)
	CutsceneUIController:Prepare(false)
	CutsceneController:Begin(Character, function(Frame: CFrame, DeltaTime: number): CFrame
		local Sway = IntroCutsceneController:ApplyCameraSway(Frame, DeltaTime)
		return ApplyWaveShake(Sequence, Sway)
	end)
	StopAttacks(Character)
	StopAttacks(Boss)
end

function TsunamiCutsceneController:Reveal(Token: string, Character: Model, Boss: Model, ShipName: string)
	local Sequence = Active
	if not Sequence or Sequence.Token ~= Token or Sequence.Revealed or not IsActive(Sequence) then
		return
	end
	Sequence.Revealed = true
	local Ships = workspace:WaitForChild(IntroCutsceneConfig.ShipsFolderName)
	local Ship = Ships:WaitForChild(ShipName, 10) :: Model?
	if not Ship or not IsActive(Sequence) then
		return
	end

	PlayIdle(Sequence, Character)
	PlayIdle(Sequence, Boss)

	local Center = Character:GetPivot().Position:Lerp(Boss:GetPivot().Position, 0.5)
	local Direction = (Ship:GetPivot().RightVector * Vector3.new(1, 0, 1)).Unit
	local Position = Center - Direction * Config.CameraBackOffset + Vector3.yAxis * Config.CameraHeight
	local Target = Center + Direction * Config.CameraLookDistance + Vector3.yAxis * Config.CameraLookHeight
	local Frame = CFrame.lookAt(Position, Target)
	CutsceneController:SetView(Frame, Target, Config.InitialFov)
	local WaveTarget = CreateWave(Sequence, Ship, Center, Direction, Position)

	if not RevealUmibozu(Sequence, Direction) then
		return
	end

	local Wave = assert(Sequence.Wave, "Intro tsunami was removed")
	Wave.Parent = workspace

	local Sound = Instance.new("Sound")
	Sound.Name = "IntroTsunami"
	Sound.SoundId = Config.SoundId
	Sound.Volume = Config.SoundVolume
	Sound.Parent = SoundService
	Sequence.Sound = Sound
	Sound.Ended:Once(function()
		Sound:Destroy()
	end)
	Debris:AddItem(Sound, 60)
	Sound:Play()

	local WaveTween = TweenModel(Sequence, Wave, WaveTarget,
		Config.ApproachTime, Enum.EasingStyle.Linear)
	task.spawn(function()
		CutsceneController:MoveTo(Frame, Target, Config.ImpactFov, Config.ApproachTime)
	end)
	local Completed = WaveTween.Completed:Wait()
	if Completed ~= Enum.PlaybackState.Completed or not IsActive(Sequence) then
		return
	end
	if not CutsceneUIController:FadeOut(Config.ImpactFadeTime) or not IsActive(Sequence) then
		return
	end

	ClearVisuals(Sequence)
	ShipAmbienceController:Stop()
	IntroCutsceneService.TsunamiFinished:Fire(Token)
end

local function GetGameplayView(Character: Model): (CFrame, Vector3)
	local Root = assert(Character.PrimaryPart, "Intro wake-up requires a PrimaryPart")
	local Target = Root.Position + Vector3.yAxis * WakeUpConfig.GameplayFocusHeight
	local Position = CameraController:GetCollisionSafePosition(Target, Root.CFrame:PointToWorldSpace(WakeUpConfig.GameplayOffset))
	return CFrame.lookAt(Position, Target), Target
end

local function ReleaseWakeUp(Sequence: Sequence)
	if not IsActive(Sequence) then
		return
	end

	ClearVisuals(Sequence)
	if Sequence.Sound then
		Sequence.Sound:Destroy()
	end
	Active = nil
	CutsceneController:Finish()
	CameraController:BlendFromCurrentCamera()
	CutsceneUIController:Finish()
	CombatMusicController:Restore()
	IntroCutsceneService.WakeUpFinished:Fire(Sequence.Token)
end

local function GroundWakeUpPose(Sequence: Sequence, Track: AnimationTrack)
	local Root = Sequence.Character.PrimaryPart
	local Joint = Root and Root:FindFirstChild("RootJoint") :: Motor6D?
	local Torso = Joint and Joint.Part1
	if not Root or not Joint or not Torso then
		return
	end

	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = { Sequence.Character, workspace.Entity }
	Params.IgnoreWater = true
	Params.RespectCanCollide = true
	local Ground = workspace:Raycast(Torso.Position + Vector3.yAxis * 12, -Vector3.yAxis * 128, Params)
	if not Ground then
		return
	end

	local Frame, Size = Torso.CFrame, Torso.Size
	local HalfHeight = (math.abs(Frame.RightVector.Y) * Size.X
		+ math.abs(Frame.UpVector.Y) * Size.Y + math.abs(Frame.LookVector.Y) * Size.Z) * 0.5
	local Offset = Ground.Position.Y - (Frame.Position.Y - HalfHeight)
	local OriginalTransform = Joint.Transform
	local function RestoreGrounding()
		if Joint.Parent then
			Joint.Transform = OriginalTransform
		end
	end

	local function ApplyGrounding()
		-- Keep the lying pose on the sand, then blend back as the character stands.
		local Progress = if Track.Length > 0 then Track.TimePosition / Track.Length else 0
		local Weight = 1 - math.clamp((Progress - 0.6) / 0.4, 0, 1)
		local Basis = Root.CFrame * Joint.C0
		local LocalOffset = Basis:VectorToObjectSpace(Vector3.yAxis * (Offset * Weight))
		OriginalTransform = Joint.Transform
		Joint.Transform = CFrame.new(LocalOffset) * OriginalTransform
	end

	Sequence.Grounding = {
		Restore = RestoreGrounding,
		Connections = {
			RunService.PreAnimation:Connect(RestoreGrounding),
			RunService.PreSimulation:Connect(ApplyGrounding),
		},
	}
	ApplyGrounding()
end

local function WaitForWakeUp(Sequence: Sequence, Track: AnimationTrack): boolean
	local Finished = false
	local Gate = Instance.new("BindableEvent")
	Track.Ended:Once(function()
		if not Finished then
			Finished = true
			Gate:Fire()
		end
	end)
	task.delay(WakeUpConfig.AnimationTimeout, function()
		if not Finished then
			Finished = true
			warn("Intro wake-up animation timed out")
			Track:Stop(0)
			Gate:Fire()
		end
	end)
	Track:AdjustSpeed(1)
	Gate.Event:Wait()
	Gate:Destroy()
	return IsActive(Sequence)
end

function TsunamiCutsceneController:WakeUp(Token: string, Character: Model, SpawnFrame: CFrame)
	local Sequence = Active
	if not Sequence or Sequence.Token ~= Token or Sequence.WakingUp or Player.Character ~= Character
		or Sequence.Character ~= Character or not Character.Parent then
		return
	end

	Sequence.WakingUp = true
	ClearVisuals(Sequence)
	if Sequence.Sound then
		Sequence.Sound:Destroy()
		Sequence.Sound = nil
	end
	assert(Character.PrimaryPart, "Intro wake-up requires a PrimaryPart")
	local Humanoid = assert(Character:FindFirstChildWhichIsA("Humanoid"), "Intro wake-up requires a Humanoid")
	local Animator = assert(Humanoid:FindFirstChildWhichIsA("Animator"), "Intro wake-up requires an Animator")
	StopAttacks(Character)
	CutsceneController:Begin(Character)
	CutsceneUIController:Prepare()
	local Target = SpawnFrame.Position
	CutsceneController:SetView(CFrame.lookAt(Target + Vector3.yAxis * WakeUpConfig.CameraHeight, Target, SpawnFrame.LookVector),
		Target, WakeUpConfig.CameraFov)

	local Track = Animator:LoadAnimation(WakeUpAnimation)
	Track.Priority = Enum.AnimationPriority.Action4
	Track.Looped = false
	table.insert(Sequence.Animations, Track)
	-- Reveal the first pose before allowing the character to stand up.
	ContentProvider:PreloadAsync({ WakeUpAnimation })
	if not IsActive(Sequence) then
		return
	end
	Character:PivotTo(SpawnFrame)
	Track:Play(0, 1, 0)
	RunService.PostSimulation:Wait()
	if not IsActive(Sequence) then
		return
	end
	GroundWakeUpPose(Sequence, Track)
	RunService.PostSimulation:Wait()
	if not CutsceneUIController:FadeIn(WakeUpConfig.FadeTime) or not IsActive(Sequence) then
		return
	end
	if not WaitForWakeUp(Sequence, Track) then
		return
	end

	local Frame, Focus = GetGameplayView(Character)
	CameraController:SetZoomDistance((Frame.Position - Focus).Magnitude)
	if CutsceneController:MoveTo(Frame, Focus, Constants.DEFAULT_FIELD_OF_VIEW, WakeUpConfig.TransitionTime) then
		ReleaseWakeUp(Sequence)
	end
end

function TsunamiCutsceneController.KnitInit()
	IntroCutsceneService = Knit.GetService("IntroCutsceneService")
	IntroCutsceneController = Knit.GetController("IntroCutsceneController")
	CutsceneController = Knit.GetController("CutsceneController")
	CutsceneUIController = Knit.GetController("CutsceneUIController")
	ShipAmbienceController = Knit.GetController("ShipAmbienceController")
	CombatMusicController = Knit.GetController("CombatMusicController")
	AnimationController = Knit.GetController("AnimationController")
	RenderController = Knit.GetController("RenderController")
	CameraController = Knit.GetController("CameraController")
end

function TsunamiCutsceneController.KnitStart()
	task.spawn(function()
		local Sound = Instance.new("Sound")
		Sound.SoundId = Config.SoundId
		local Success, Error = pcall(function()
			ContentProvider:PreloadAsync({ Sound, WakeUpAnimation })
		end)
		Sound:Destroy()
		if not Success then
			warn("Unable to preload tsunami sound:", Error)
		end
	end)

	IntroCutsceneService.TsunamiParry:Connect(function(Token: string, Character: Model, Boss: Model)
		TsunamiCutsceneController:PlayHeavyParry(Token, Character, Boss)
	end)
	IntroCutsceneService.TsunamiStarted:Connect(function(Token: string, Character: Model, Boss: Model)
		TsunamiCutsceneController:Begin(Token, Character, Boss)
	end)
	IntroCutsceneService.TsunamiRevealed:Connect(function(Token: string, Character: Model, Boss: Model, ShipName: string)
		local Success, Error = xpcall(function()
			TsunamiCutsceneController:Reveal(Token, Character, Boss, ShipName)
		end, debug.traceback)
		if not Success then
			warn("Intro tsunami failed:", Error)
		end
	end)
	IntroCutsceneService.WakeUpStarted:Connect(function(Token: string, Character: Model, SpawnFrame: CFrame)
		local Success, Error = xpcall(function()
			TsunamiCutsceneController:WakeUp(Token, Character, SpawnFrame)
		end, debug.traceback)
		if not Success then
			warn("Intro wake-up failed:", Error)
			local Sequence = Active
			if Sequence and Sequence.Token == Token and IsActive(Sequence) then
				local Frame, Focus = GetGameplayView(Character)
				CutsceneController:SetView(Frame, Focus, Constants.DEFAULT_FIELD_OF_VIEW)
				ReleaseWakeUp(Sequence)
			end
		end
	end)
	Player.CharacterRemoving:Connect(function(Character: Model)
		if (Active and Active.Character == Character) or (Parry and Parry.Character == Character) then
			Cancel()
		end
	end)
	Player:GetAttributeChangedSignal("InIntroCutscene"):Connect(function()
		if not Player:GetAttribute("InIntroCutscene") then
			Cancel()
		end
	end)
end

return TsunamiCutsceneController
