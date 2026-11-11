local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HorseConfig = require(ReplicatedStorage.Shared.HorseConfig)
local Settings = HorseConfig.Gaits
local HorseGaitController = {}

export type State = {
	Held: boolean,
	Boost: number,
	LastTap: number,
	Multiplier: number,
}

function HorseGaitController.Create(): State
	return { Held = false, Boost = 0, LastTap = -math.huge, Multiplier = Settings.TrotMultiplier }
end

function HorseGaitController.SetHeld(State: State, Held: boolean, Now: number)
	if State.Held == Held then
		return
	end
	State.Held = Held
	if not Held then
		return
	end
	local Interval = Now - State.LastTap
	if Interval < Settings.MinimumTapInterval then
		return
	end
	if Interval <= Settings.TapWindow then
		State.Boost = math.min(1, State.Boost + Settings.TapGain)
	end
	State.LastTap = Now
end

function HorseGaitController.Cancel(State: State)
	State.Held = false
	State.Boost = 0
	State.LastTap = -math.huge
end

function HorseGaitController.Update(State: State, DeltaTime: number, Now: number, Moving: boolean): number
	if not Moving then
		State.Boost = 0
		State.LastTap = -math.huge
	elseif Now - State.LastTap > Settings.TapGrace then
		State.Boost = math.max(0, State.Boost - Settings.BoostDecay * DeltaTime)
	end
	local Target = Settings.TrotMultiplier
	if Moving then
		Target += (1 - Settings.TrotMultiplier) * State.Boost
		if State.Held then
			Target = math.max(Target, Settings.GallopMultiplier)
		end
	end
	local Rate = if Target > State.Multiplier then Settings.TransitionUp else Settings.TransitionDown
	State.Multiplier += math.clamp(Target - State.Multiplier, -Rate * DeltaTime, Rate * DeltaTime)

	return State.Multiplier
end

return HorseGaitController
