local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.KickConfig)
local Validate = require(ReplicatedStorage.Shared.Validate)
local CharacterShared = require(ReplicatedStorage.Shared.CharacterShared)

local KickController = Knit.CreateController({ Name = "KickController" })
local Player = Players.LocalPlayer
local Animations = ReplicatedStorage.Assets.Animations.Combat.Kick
local Tracks: { [Model]: AnimationTrack } = {}
local HitboxVisuals: { [Model]: { BoxHandleAdornment } } = {}
local KickService
local AnimationController

local function PlaySound(Character: Model, SoundId: string)
	local Root = Character.PrimaryPart
	if not Character.Parent or not Root then
		return
	end

	local Sound = Instance.new("Sound")
	Sound.Name = "KickSound"
	Sound.SoundId = SoundId
	Sound.Volume = 0.8
	Sound.RollOffMinDistance = 5
	Sound.RollOffMaxDistance = 70
	Sound.Parent = Root
	Sound.Ended:Once(function()
		Sound:Destroy()
	end)
	Debris:AddItem(Sound, 10)
	Sound:Play()
end

local function StopAnimation(Character: Model)
	local Track = Tracks[Character]
	if Track then
		Tracks[Character] = nil
		Track:Stop(0.03)
		Debris:AddItem(Track, 0.1)
	end
end

local function HideHitboxes(Character: Model)
	local Boxes = HitboxVisuals[Character]
	if not Boxes then
		return
	end

	HitboxVisuals[Character] = nil
	for _, Box in Boxes do
		Box:Destroy()
	end
end

local function CreateHitboxVisual(Root: BasePart, Name: string, Size: Vector3, Color: Color3): BoxHandleAdornment
	local Box = Instance.new("BoxHandleAdornment")
	Box.Name = Name
	Box.Adornee = Root
	Box.Size = Size
	Box.CFrame = CFrame.new(0, 0, -Size.Z / 2)
	Box.Color3 = Color
	Box.Transparency = 0.7
	Box.AlwaysOnTop = true
	Box.ZIndex = 1
	Box.Parent = Root
	return Box
end

local function ShowHitboxes(Character: Model, Started: number)
	if not Config.ShowHitboxes then
		return
	end

	HideHitboxes(Character)
	local Boxes: { BoxHandleAdornment } = {}
	HitboxVisuals[Character] = Boxes
	local Elapsed = workspace:GetServerTimeNow() - Started
	task.delay(math.max(0, Config.HitDelay - Elapsed), function()
		local Root = Character.PrimaryPart
		if HitboxVisuals[Character] ~= Boxes or not Character.Parent or not Root then
			return
		end

		table.insert(
			Boxes,
			CreateHitboxVisual(Root, "KickCharacterHitboxVisual", Config.HitboxSize, Color3.fromRGB(255, 70, 70))
		)
		table.insert(
			Boxes,
			CreateHitboxVisual(Root, "KickDoorHitboxVisual", Config.DoorHitboxSize, Color3.fromRGB(70, 170, 255))
		)
	end)
	task.delay(math.max(0, Config.HitDelay + Config.Duration - Elapsed), function()
		if HitboxVisuals[Character] == Boxes then
			HideHitboxes(Character)
		end
	end)
end

local function StopKick(Character: Model)
	StopAnimation(Character)
	HideHitboxes(Character)
end

local function PlayKick(Character: Model?, Side: string, Started: number)
	local Elapsed = workspace:GetServerTimeNow() - Started
	if not Character or not Character.Parent or Elapsed >= Config.HitDelay + Config.Duration then
		return
	end

	ShowHitboxes(Character, Started)
	PlaySound(Character, Config.SwingSound)
	-- The owning client replicates player animations; NPC tracks stay local to each observer.
	if Players:GetPlayerFromCharacter(Character) and Character ~= Player.Character then
		return
	end

	local Animation = Animations:FindFirstChild(Side) :: Animation?
	if not Animation then
		return
	end

	StopAnimation(Character)
	AnimationController:StopAttackAnimations(Character)
	AnimationController:StopAnimationFind(Character, "Block")
	local Track = AnimationController:PlayAnimation(Character, Animation)
	if not Track then
		return
	end

	Tracks[Character] = Track
	Track.Name = "Kick"
	Track.Priority = Enum.AnimationPriority.Action4
	Track.Looped = false
	Track.Stopped:Once(function()
		if Tracks[Character] == Track then
			Tracks[Character] = nil
		end
		Debris:AddItem(Track, 0.1)
	end)
end

function KickController:HandleInput(InputState: Enum.UserInputState)
	local Character = Player.Character
	if InputState == Enum.UserInputState.Begin and Character and Validate:CanKick(Character) then
		KickService.Request:Fire(Character)
	end
end

local function TrackCharacter(Character: Model)
	local DeviceController = Knit.GetController("DeviceController")
	DeviceController:BindAction("Kick", function(InputState: Enum.UserInputState)
		KickController:HandleInput(InputState)
	end, "Kick", UDim2.fromScale(0.65, 0.6))

	Character:GetAttributeChangedSignal("Kicking"):Connect(function()
		CharacterShared:UpdateBoth(Character)
	end)
end

function KickController.KnitStart()
	KickService = Knit.GetService("KickService")
	AnimationController = Knit.GetController("AnimationController")
	KickService.Started:Connect(PlayKick)
	KickService.Stopped:Connect(StopKick)
	KickService.Impact:Connect(function(Character: Model)
		PlaySound(Character, Config.HitSound)
	end)
	UserInputService.InputBegan:Connect(function(Input: InputObject, Processed: boolean)
		if not Processed and Input.KeyCode == Enum.KeyCode.G then
			KickController:HandleInput(Enum.UserInputState.Begin)
		end
	end)
	Player.CharacterAdded:Connect(TrackCharacter)
	Player.CharacterRemoving:Connect(StopKick)
	if Player.Character then
		TrackCharacter(Player.Character)
	end

	task.spawn(function()
		ContentProvider:PreloadAsync(Animations:GetChildren())
	end)
end

return KickController
