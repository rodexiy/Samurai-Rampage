local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HorseConfig = require(ReplicatedStorage.Shared.HorseConfig)
local HorseRiderStateController = require(Players.LocalPlayer.PlayerScripts.Client.Controllers.HorseRiderStateController)

local HorseMountedAnimationController = {}
local Settings = HorseConfig.RiderAnimations

export type State = {
	Animator: Animator?,
	Idle: AnimationTrack?,
	Running: AnimationTrack?,
	Active: AnimationTrack?,
}

local function LoadTrack(Animator: Animator, Name: string, AnimationId: string): AnimationTrack
	local Animation = Instance.new("Animation")
	Animation.Name = Name
	Animation.AnimationId = AnimationId

	local Track = Animator:LoadAnimation(Animation)
	Track.Looped = true
	-- Bow poses and shots override the keyed upper-body joints while riding continues.
	Track.Priority = Enum.AnimationPriority.Movement
	Animation:Destroy()

	return Track
end

function HorseMountedAnimationController.Create(): State
	return {}
end

function HorseMountedAnimationController.Reset(State: State)
	for _, Track in { State.Idle, State.Running } do
		Track:Stop(0)
		Track:Destroy()
	end

	State.Animator = nil
	State.Idle = nil
	State.Running = nil
	State.Active = nil
end

function HorseMountedAnimationController.Update(State: State, Character: Model?, Horse: Model?)
	local Running = Character ~= nil and HorseRiderStateController.IsRunning(Character)
	local Root = Horse and Horse.PrimaryPart
	local Humanoid = Character and Character:FindFirstChildWhichIsA("Humanoid")
	local Animator = Humanoid and Humanoid:FindFirstChildWhichIsA("Animator")
	if not Horse or not Horse:IsDescendantOf(workspace) or not Root or not Character
		or Character:GetAttribute("InHorse") ~= true or not Humanoid or Humanoid.Health <= 0 or not Animator
	then
		HorseMountedAnimationController.Reset(State)
		return
	end

	if State.Animator ~= Animator then
		HorseMountedAnimationController.Reset(State)
		State.Animator = Animator
		State.Idle = LoadTrack(Animator, "HorseMountedIdle", Settings.Idle)
		State.Running = LoadTrack(Animator, "HorseMountedRunning", Settings.Running)
	end

	local Track = if Running then State.Running else State.Idle
	if State.Active ~= Track then
		if State.Active then
			State.Active:Stop(Settings.FadeTime)
		end

		State.Active = Track
	end

	if Track and not Track.IsPlaying then
		Track:Play(Settings.FadeTime)
	end
end

return HorseMountedAnimationController
