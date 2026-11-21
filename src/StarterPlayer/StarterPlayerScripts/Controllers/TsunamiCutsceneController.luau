local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local IntroCutsceneConfig = require(ReplicatedStorage.Shared.IntroCutsceneConfig)
local TsunamiCutsceneController = Knit.CreateController({ Name = "TsunamiCutsceneController" })

type Sequence = {
	Token: string,
	Character: Model,
	Boss: Model,
	Revealed: boolean,
	Wave: Model?,
	WaveStartPosition: Vector3?,
	WaveTravelDistance: number?,
	Sound: Sound?,
	Values: { CFrameValue },
	Tweens: { Tween },
	Animations: { AnimationTrack },
}

type ParryState = {
	Token: string,
	Character: Model,
	Boss: Model,
	Tracks: { AnimationTrack },
}

local Player = Players.LocalPlayer
local Config = IntroCutsceneConfig.Tsunami
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

local function IsActive(Sequence: Sequence): boolean
	return Active == Sequence and Player.Character == Sequence.Character
		and Sequence.Character.Parent ~= nil and Sequence.Boss.Parent ~= nil
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

local function CreateWave(Sequence: Sequence, Ship: Model, Center: Vector3, Direction: Vector3, CameraPosition: Vector3): CFrame
	local Template = ReplicatedStorage.Assets.Models.TutorialCutscene:FindFirstChild(Config.ModelName) :: Model?
	assert(Template and Template:IsA("Model"), "Intro tsunami template is missing")
	local Wave = Template:Clone()
	Sequence.Wave = Wave
	Wave.Name = "IntroTsunami"
	for _, Instance in Wave:QueryDescendants("BasePart") do
		local Part = Instance :: BasePart
		Part.Anchored = true
		Part.CanCollide = false
		Part.CanTouch = false
		Part.CanQuery = false
	end

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
	Wave.Parent = workspace
	return AtCenter(Finish)
end

function TsunamiCutsceneController:PlayHeavyParry(Token: string, Character: Model, Boss: Model)
	if Player.Character ~= Character or Active or (Parry and Parry.Token == Token) then
		return
	end
	CancelParry()
	local State: ParryState = { Token = Token, Character = Character, Boss = Boss, Tracks = {} }
	Parry = State

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

	local WaveTween = TweenModel(Sequence, assert(Sequence.Wave, "Intro tsunami was removed"), WaveTarget,
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

function TsunamiCutsceneController.KnitInit()
	IntroCutsceneService = Knit.GetService("IntroCutsceneService")
	IntroCutsceneController = Knit.GetController("IntroCutsceneController")
	CutsceneController = Knit.GetController("CutsceneController")
	CutsceneUIController = Knit.GetController("CutsceneUIController")
	ShipAmbienceController = Knit.GetController("ShipAmbienceController")
	CombatMusicController = Knit.GetController("CombatMusicController")
	AnimationController = Knit.GetController("AnimationController")
	RenderController = Knit.GetController("RenderController")
end

function TsunamiCutsceneController.KnitStart()
	task.spawn(function()
		local Sound = Instance.new("Sound")
		Sound.SoundId = Config.SoundId
		local Success, Error = pcall(function()
			ContentProvider:PreloadAsync({ Sound })
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
