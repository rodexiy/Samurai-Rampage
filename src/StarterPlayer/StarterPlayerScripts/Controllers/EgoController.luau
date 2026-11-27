local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local EgoConfig = require(ReplicatedStorage.Shared.EgoConfig)
local Progression = require(ReplicatedStorage.Shared.StatProgression)
local CharacterShared = require(ReplicatedStorage.Shared.CharacterShared)

local EgoController = Knit.CreateController({ Name = "EgoController" })
local Player = Players.LocalPlayer
local EgoService
local CameraController
local CutsceneController
local CutsceneUIController
local Auras: { [Model]: Model } = {}
local SceneRevision = 0
local SceneActive = false
local SceneSource: Model?

type AudioState = { Root: BasePart, Id: string, Activation: Sound?, Loop: Sound? }
local Audio: { [Model]: AudioState } = {}

local function StopAudio(Character: Model)
	local State = Audio[Character]
	if not State then
		return
	end

	Audio[Character] = nil
	if State.Activation then
		State.Activation:Destroy()
	end
	if State.Loop then
		State.Loop:Destroy()
	end
end

local function PlaySound(Root: BasePart, Id: string, Name: string, Volume: number, Looped: boolean): Sound
	local Sound = Instance.new("Sound")
	Sound.Name = Name
	Sound.SoundId = Id
	Sound.Volume = Volume
	Sound.Looped = Looped
	Sound.RollOffMode = Enum.RollOffMode.Linear
	Sound.RollOffMinDistance = EgoConfig.SoundMinDistance
	Sound.RollOffMaxDistance = EgoConfig.SoundMaxDistance
	Sound.Parent = Root
	Sound:Play()

	return Sound
end

local function RefreshAudio(Character: Model, PlayActivation: boolean)
	local Id = Character:GetAttribute("EgoId")
	local Definition = Id and EgoConfig.Definitions[Id]
	local Root = Character.PrimaryPart
	if not Character:GetAttribute("EgoActive") or not Character.Parent or not Root or not Definition then
		StopAudio(Character)
		return
	end
	local Current = Audio[Character]
	if Current and Current.Root == Root and Current.Id == Id then
		return
	end

	StopAudio(Character)
	local State: AudioState = { Root = Root, Id = Id }
	Audio[Character] = State
	if Definition.LoopSound then
		State.Loop = PlaySound(Root, Definition.LoopSound, "EgoLoop", Definition.LoopVolume or 0.5, true)
	end
	if PlayActivation and Definition.ActivationSound then
		local Activation = PlaySound(Root, Definition.ActivationSound, "EgoActivation", Definition.ActivationVolume or 1, false)
		State.Activation = Activation
		Activation.Ended:Once(function()
			State.Activation = nil
			Activation:Destroy()
		end)
	end
end

local function ClearAura(Character: Model)
	local Aura = Auras[Character]
	if Aura then
		Auras[Character] = nil
		Aura:Destroy()
	end
end

local function RefreshAura(Character: Model)
	local Id = Character:GetAttribute("EgoId")
	local Definition = Id and EgoConfig.Definitions[Id]
	if not Character:GetAttribute("EgoActive") or not Character.Parent or not Definition then
		ClearAura(Character)
		return
	end

	local Root = Character.PrimaryPart
	if not Root then
		return
	end
	local Current = Auras[Character]
	if Current then
		if Current:GetAttribute("EgoId") == Id then
			return
		end
		ClearAura(Character)
	end
	local Asset = ReplicatedStorage.Assets.VFX.Ego:FindFirstChild(Definition.Aura)
	if not Asset or not Asset:IsA("Model") then
		return
	end

	local Aura = Asset:Clone() :: Model
	Aura.Name = "EgoAura"
	Aura:SetAttribute("EgoId", Id)
	Aura.PrimaryPart = Aura.PrimaryPart or Aura:FindFirstChildWhichIsA("BasePart")
	Aura:PivotTo(Root.CFrame)
	for _, Part in Aura:QueryDescendants("BasePart") :: { BasePart } do
		Part.Anchored = false
		Part.Massless = true
		Part.CanCollide = false
		Part.CanTouch = false
		Part.CanQuery = false

		local Weld = Instance.new("WeldConstraint")
		Weld.Part0, Weld.Part1 = Root, Part
		Weld.Parent = Part
	end

	Auras[Character] = Aura
	Aura.Parent = Character
end

function EgoController:CanUse(): boolean
	local Character = Player.Character
	if not Character or Character:GetAttribute("Loaded") ~= true then
		return false
	end
	for Attribute in EgoConfig.CancelStates do
		if Character:GetAttribute(Attribute) then
			return false
		end
	end
	for _, Name in Progression.Names do
		if (Player:GetAttribute(Name .. "Level") or 0) < EgoConfig.RequiredStatLevel then
			return false
		end
	end

	return true
end

function EgoController:Toggle()
	local Character = Player.Character
	if not Character or Player:GetAttribute("EditingMobileControls") or Player:GetAttribute("InIntroCutscene")
		or Character:GetAttribute("CameraCutscene") or workspace:GetAttribute("InMainMenu") then
		return
	end

	if not Character:GetAttribute("EgoActive") and not self:CanUse() then
		return
	end

	EgoService.Toggle:Fire()
end

local function CancelForAction(Character: Model): boolean
	if Character ~= Player.Character or not Character:GetAttribute("EgoActive") then
		return false
	end
	for Attribute in EgoConfig.CancelStates do
		if Character:GetAttribute(Attribute) then
			Character:SetAttribute("EgoActive", false)
			CharacterShared:UpdateBoth(Character)
			EgoService.Cancel:Fire()
			return true
		end
	end

	return false
end

local function FinishScene()
	if not SceneActive then
		return
	end

	SceneActive = false
	SceneSource = nil
	SceneRevision += 1
	CutsceneController:Finish(true)
	CutsceneUIController:Finish()
end

local function PlayScene(Source: Model?, Duration: number?)
	if not Source then
		FinishScene()
		return
	end

	local Character = Player.Character
	local Head = Source:FindFirstChild("Head") :: BasePart?
	local Root = Source.PrimaryPart
	if SceneActive or CutsceneController:IsActive() or not Character or not Head or not Root
		or Player:GetAttribute("InCombat") or Player:GetAttribute("InIntroCutscene")
		or Character:GetAttribute("CameraCutscene") or Player:GetAttribute("InDialog") then
		return
	end

	SceneActive = true
	SceneSource = Source
	SceneRevision += 1
	local Revision = SceneRevision
	local Time = 0
	local Length = Duration or EgoConfig.CutsceneDuration
	local StartingFov = if workspace.CurrentCamera then math.min(workspace.CurrentCamera.FieldOfView, 55) else 55
	local function GetView(): CFrame
		local Distance = 5.5 - 1.5 * math.clamp(Time / Length, 0, 1)
		return CFrame.lookAt(Head.Position + Root.CFrame.LookVector * Distance + Root.CFrame.RightVector * 0.5, Head.Position)
	end

	CutsceneController:Begin(Character, function(Frame: CFrame, DeltaTime: number): CFrame
		if not Head.Parent or not Root.Parent then
			return Frame
		end
		Time += DeltaTime
		return GetView()
	end)
	CutsceneUIController:Prepare(false)
	CutsceneUIController:SetBarHeight(0, 0)
	CutsceneUIController:SetBarHeight(0.22, 0.4)
	CutsceneController:SetView(GetView(), Head.Position, StartingFov)
	task.spawn(function()
		if SceneActive and SceneRevision == Revision then
			CutsceneController:MoveTo(GetView(), Head.Position, math.min(StartingFov, EgoConfig.CutsceneFov), 0.4)
		end
	end)
	task.delay(Length, function()
		if SceneRevision == Revision then
			FinishScene()
		end
	end)
end

local function TrackCharacter(Character: Model)
	Character.AttributeChanged:Connect(function(Attribute: string)
		if EgoConfig.CancelStates[Attribute] then
			CancelForAction(Character)
		end
	end)

	local WasActive = Character:GetAttribute("EgoActive") == true
	Character:GetAttributeChangedSignal("EgoActive"):Connect(function()
		local Active = Character:GetAttribute("EgoActive") == true
		if Active and CancelForAction(Character) then
			return
		end

		if Active and not WasActive and Character == Player.Character then
			CameraController:PulseFieldOfView(-12, 0.12)
			CameraController:ShakeOnce(2, 8, 0.1, 2.9)
		end
		WasActive = Active

		RefreshAudio(Character, Active)
		RefreshAura(Character)
	end)
	Character:GetAttributeChangedSignal("EgoId"):Connect(function()
		RefreshAura(Character)
		RefreshAudio(Character, true)
	end)
	Character:GetPropertyChangedSignal("PrimaryPart"):Connect(function()
		RefreshAura(Character)
		RefreshAudio(Character, false)
	end)
	Character.Destroying:Once(function()
		StopAudio(Character)
		ClearAura(Character)
		if Character == SceneSource or Character == Player.Character then
			FinishScene()
		end
	end)
	RefreshAura(Character)
	RefreshAudio(Character, false)
end

local function TrackPlayer(OtherPlayer: Player)
	OtherPlayer.CharacterAdded:Connect(TrackCharacter)
	OtherPlayer.CharacterRemoving:Connect(function(Character: Model)
		StopAudio(Character)
		ClearAura(Character)
		if OtherPlayer == Player or Character == SceneSource then
			FinishScene()
		end
	end)
	if OtherPlayer.Character then
		TrackCharacter(OtherPlayer.Character)
	end
end

function EgoController.KnitInit()
	EgoService = Knit.GetService("EgoService")
	CameraController = Knit.GetController("CameraController")
	CutsceneController = Knit.GetController("CutsceneController")
	CutsceneUIController = Knit.GetController("CutsceneUIController")
end

function EgoController.KnitStart()
	EgoService.Cutscene:Connect(PlayScene)
	Players.PlayerAdded:Connect(TrackPlayer)
	for _, OtherPlayer in Players:GetPlayers() do
		TrackPlayer(OtherPlayer)
	end
	Player:GetAttributeChangedSignal("InCombat"):Connect(function()
		if Player:GetAttribute("InCombat") then
			FinishScene()
		end
	end)
end

return EgoController
