return {
	BreakImpulse = 1, -- Multiplier for the detached door panel's launch strength.
	BreakSound = "rbxassetid://103518062249191",
	KnockbackImpulse = 1.4, -- Multiplier for the impact velocity transferred to a character.
	ImpactMinSpeed = 15, -- Minimum closing speed, in studs/second, to trigger ragdoll.
	ImpactMaxKnockbackSpeed = 120,
	ImpactStopSpeed = 2,
	ImpactStopDelay = 0.25,
	ImpactRotationStep = 10, -- Degrees per rotational collision sample.
	ImpactMaxSubsteps = 12,
	BreakSpeed = 25,
	BreakUpSpeed = 2,
	BreakSpin = Vector3.new(2, 4, 1),
	DebrisLifetime = 8,
	RespawnDelay = 60,
	CollisionDelay = 0.2,
}
