local HorseSpringController = {}

-- Exact damped response for a fixed target over this frame; stable at distant animation update rates too.
function HorseSpringController.Step(Position: number, Velocity: number, Target: number,
	DeltaTime: number, Frequency: number, Damping: number): (number, number)
	local Omega = math.pi * 2 * Frequency
	local DecayRate = math.clamp(Damping, 0.01, 0.99) * Omega
	local Oscillation = math.sqrt(Omega * Omega - DecayRate * DecayRate)
	local Decay = math.exp(-DecayRate * DeltaTime)
	local Cosine, Sine = math.cos(Oscillation * DeltaTime), math.sin(Oscillation * DeltaTime)
	local Offset = Position - Target
	local NextOffset = Decay * (Offset * Cosine + (Velocity + DecayRate * Offset) / Oscillation * Sine)
	local NextVelocity = Decay * (Velocity * Cosine - (DecayRate * Velocity + Omega * Omega * Offset) / Oscillation * Sine)

	return Target + NextOffset, NextVelocity
end

return HorseSpringController
