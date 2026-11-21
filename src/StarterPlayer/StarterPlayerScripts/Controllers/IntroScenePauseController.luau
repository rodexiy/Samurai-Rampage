local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local IntroCutsceneConfig = require(ReplicatedStorage.Shared.IntroCutsceneConfig)
local IntroScenePauseController = Knit.CreateController({ Name = "IntroScenePauseController" })

local Emitters: { [ParticleEmitter]: number } = {}
local Tracks: { [AnimationTrack]: number } = {}
local Volumes: { [Sound | SoundGroup]: number } = {}
local Connections: { RBXScriptConnection } = {}
local Tweens: { Tween } = {}
local IntroCutsceneController
local LightningController

local function FreezeEmitter(Instance: Instance)
	if Instance:IsA("ParticleEmitter") and Emitters[Instance] == nil then
		Emitters[Instance] = Instance.TimeScale
		Instance.TimeScale = 0
	end
end

local function FreezeTrack(Track: AnimationTrack)
	if Tracks[Track] == nil then
		Tracks[Track] = Track.Speed
		Track:AdjustSpeed(0)
	end
end

local function LowerAudio(Instance: Instance)
	if (Instance:IsA("Sound") or Instance:IsA("SoundGroup")) and Volumes[Instance] == nil then
		Volumes[Instance] = Instance.Volume
		local Tween = TweenService:Create(Instance, TweenInfo.new(0.2), {
			Volume = Instance.Volume * IntroCutsceneConfig.CombatTutorial.AmbienceVolume,
		})
		table.insert(Tweens, Tween)
		Tween:Play()
	end
end

function IntroScenePauseController:Resume()
	for _, Connection in Connections do
		Connection:Disconnect()
	end
	for _, Tween in Tweens do
		Tween:Cancel()
	end
	for Emitter, Speed in Emitters do
		if Emitter.Parent then
			Emitter.TimeScale = Speed
		end
	end
	for Track, Speed in Tracks do
		if Track.IsPlaying then
			Track:AdjustSpeed(Speed)
		end
	end
	for Audio, Volume in Volumes do
		if Audio.Parent then
			Audio.Volume = Volume
		end
	end
	table.clear(Connections)
	table.clear(Tweens)
	table.clear(Emitters)
	table.clear(Tracks)
	table.clear(Volumes)
	IntroCutsceneController:SetSwayPaused(false)
	LightningController:SetStormPaused("IntroCutscene", false)
end

function IntroScenePauseController:Pause(Ship: Model, Actors: { Model })
	self:Resume()
	IntroCutsceneController:SetSwayPaused(true)
	LightningController:SetStormPaused("IntroCutscene", true)
	local Roots: { Model } = { Ship }
	for _, Actor in Actors do
		table.insert(Roots, Actor)
		local Humanoid = Actor:FindFirstChildWhichIsA("Humanoid")
		local Animator = Humanoid and Humanoid:FindFirstChildWhichIsA("Animator")
		if Animator then
			for _, Track in Animator:GetPlayingAnimationTracks() do
				FreezeTrack(Track)
			end
			table.insert(Connections, Animator.AnimationPlayed:Connect(FreezeTrack))
		end
	end
	for _, Root in Roots do
		for _, Emitter in Root:QueryDescendants("ParticleEmitter") do
			FreezeEmitter(Emitter)
		end
		table.insert(Connections, Root.DescendantAdded:Connect(FreezeEmitter))
	end

	for _, Name in { "IntroShipAmbience", "IntroCutsceneThunder", "CombatMusic" } do
		local Root = SoundService:FindFirstChild(Name)
		if Root then
			LowerAudio(Root)
			for _, Sound in Root:QueryDescendants("Sound") do
				LowerAudio(Sound)
			end
			table.insert(Connections, Root.DescendantAdded:Connect(LowerAudio))
		end
	end
	local Package = SoundService:FindFirstChild("SoundServicePackage")
	local Misc = Package and Package:FindFirstChild("Misc")
	local Rain = Misc and Misc:FindFirstChild("RainSound")
	if Rain then
		LowerAudio(Rain)
	end
end

function IntroScenePauseController.KnitInit()
	IntroCutsceneController = Knit.GetController("IntroCutsceneController")
	LightningController = Knit.GetController("LightningController")
end

return IntroScenePauseController
