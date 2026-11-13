local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HorseConfig = require(ReplicatedStorage.Shared.HorseConfig)
local Settings = HorseConfig.Animation
local Gallop = Settings.Gallop
local Running = Settings.Running
local HorseMotionController = {}

export type State = {
	Gallop: number,
	Sprint: number,
	Frequency: number,
	Stance: number,
	PlantDistance: number,
	StepHeight: number,
	SwingPeak: number,
	Bounce: number,
	BodyDrop: number,
	BodyPitch: number,
	NeckPitch: number,
}

local function Blend(From: number, To: number, Weight: number): number
	return From + (To - From) * Weight
end

local function SmoothWeight(Speed: number, Start: number, Finish: number): number
	local Weight = math.clamp((Speed - Start) / math.max(Finish - Start, 0.001), 0, 1)

	return Weight * Weight * (3 - 2 * Weight)
end

function HorseMotionController.Create(): State
	return {
		Gallop = 0, Sprint = 0, Frequency = Settings.MinimumFrequency, Stance = Settings.StanceFraction,
		PlantDistance = Settings.PlantDistance, StepHeight = Settings.StepHeight, SwingPeak = Settings.SwingPeak,
		Bounce = Settings.BodyBounce, BodyDrop = Settings.BodyDrop, BodyPitch = Settings.BodyPitch, NeckPitch = 0.025,
	}
end

function HorseMotionController.Blend(State: State, Trot: number, Canter: number, Sprint: number): number
	return Blend(Trot, Blend(Canter, Sprint, State.Sprint), State.Gallop)
end

function HorseMotionController.Phase(State: State, Trot: number, Canter: number, Sprint: number): number
	local Fast = Canter + ((Sprint - Canter + 0.5) % 1 - 0.5) * State.Sprint

	return Trot + ((Fast - Trot + 0.5) % 1 - 0.5) * State.Gallop
end

function HorseMotionController.Update(State: State, Speed: number, Scale: number, Tier: number?, DeltaTime: number)
	local Stats = if Tier then HorseConfig.GetTier(Tier) else nil
	local Start = if Stats then Stats.Speed * HorseConfig.Gaits.AnimationStartRatio else Running.StartSpeed * Scale
	local Finish = if Stats then Stats.Speed * HorseConfig.Gaits.AnimationFullRatio else Running.FullSpeed * Scale
	local SprintStart = if Stats then Stats.Speed * Running.StartRatio else Running.FullSpeed * Scale
	local SprintFinish = if Stats then Stats.Speed * Running.FullRatio else Running.FullSpeed * Scale * 1.6
	local Response = 1 - math.exp(-Running.BlendResponse * DeltaTime)
	State.Gallop += (SmoothWeight(Speed, Start, Finish) - State.Gallop) * Response
	State.Sprint += (SmoothWeight(Speed, SprintStart, SprintFinish) - State.Sprint) * Response

	local TrotFrequency = math.clamp(Speed / (Settings.StrideLength * Scale), Settings.MinimumFrequency, Settings.MaximumFrequency)
	local CanterFrequency = math.clamp(Speed / (Gallop.StrideLength * Scale), Gallop.MinimumFrequency, Gallop.MaximumFrequency)
	local SprintFrequency = math.clamp(Speed / (Running.StrideLength * Scale), Running.MinimumFrequency, Running.MaximumFrequency)
	if Stats then
		local Pace = math.clamp(Speed / (Stats.Speed * HorseConfig.Gaits.GallopMultiplier), 0, 1)
		CanterFrequency = Blend(Gallop.MinimumFrequency, Gallop.MaximumFrequency, Pace)
		SprintFrequency = Blend(Gallop.MaximumFrequency, Running.MaximumFrequency, State.Sprint)
	end
	State.Frequency = HorseMotionController.Blend(State, TrotFrequency, CanterFrequency, SprintFrequency)
	State.Stance = HorseMotionController.Blend(State, Settings.StanceFraction, Gallop.StanceFraction, Running.StanceFraction)
	State.PlantDistance = HorseMotionController.Blend(State, Settings.PlantDistance, Gallop.PlantDistance, Running.PlantDistance)
	State.StepHeight = HorseMotionController.Blend(State, Settings.StepHeight, Gallop.StepHeight, Running.StepHeight)
	State.SwingPeak = HorseMotionController.Blend(State, Settings.SwingPeak, Gallop.SwingPeak, Running.SwingPeak)
	State.Bounce = HorseMotionController.Blend(State, Settings.BodyBounce, Gallop.BodyBounce, Running.BodyBounce)
	State.BodyDrop = HorseMotionController.Blend(State, Settings.BodyDrop, Gallop.BodyDrop, Running.BodyDrop)
	State.BodyPitch = HorseMotionController.Blend(State, Settings.BodyPitch, Gallop.BodyPitch, Running.BodyPitch)
	State.NeckPitch = HorseMotionController.Blend(State, 0.025, Gallop.NeckPitch, Running.NeckPitch)
end

return HorseMotionController
