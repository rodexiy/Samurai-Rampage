local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HorseConfig = require(ReplicatedStorage.Shared.HorseConfig)

local HorseRiderStateController = {}
local RunningCharacters: { [Model]: boolean } = setmetatable({}, { __mode = "k" })

function HorseRiderStateController.GetTorsoTransform(Animator: Animator): CFrame?
	local Settings = HorseConfig.RiderAnimations
	local IdleWeight, RunningWeight = 0, 0
	for _, Track in Animator:GetPlayingAnimationTracks() do
		local Animation = Track.Animation
		if Animation and Animation.AnimationId == Settings.Idle then
			IdleWeight += Track.WeightCurrent
		elseif Animation and Animation.AnimationId == Settings.Running then
			RunningWeight += Track.WeightCurrent
		end
	end

	local TotalWeight = IdleWeight + RunningWeight
	if TotalWeight <= 0 then
		return nil
	end

	return Settings.TorsoTransforms.Idle:Lerp(Settings.TorsoTransforms.Running, RunningWeight / TotalWeight)
end

function HorseRiderStateController.IsRunning(Character: Model): boolean
	local Root = Character.PrimaryPart
	if Character:GetAttribute("InHorse") ~= true or not Root then
		RunningCharacters[Character] = nil
		return false
	end

	-- The rider and horse share an assembly, so they have the same linear velocity.
	local Speed = (Root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	local Settings = HorseConfig.RiderAnimations
	local Threshold = if RunningCharacters[Character] then Settings.RunningStopSpeed else Settings.RunningStartSpeed
	local Running = Speed >= Threshold
	RunningCharacters[Character] = Running

	return Running
end

return HorseRiderStateController
