export type Definition = {
	Aura: string,
	ActivationSound: string?,
	LoopSound: string?,
	ActivationVolume: number?,
	LoopVolume: number?,
}

local EgoConfig = {
	Definitions = {
		["1"] = {
			Aura = "1",
			ActivationSound = "rbxassetid://9043338526",
			LoopSound = "rbxassetid://9112840575",
			ActivationVolume = 1,
			LoopVolume = 0.5,
		},
		["2"] = {
			Aura = "2",
			ActivationSound = "rbxassetid://9043338954",
			LoopSound = "rbxassetid://9112840575",
			ActivationVolume = 1,
			LoopVolume = 0.5,
		},
	} :: { [string]: Definition },
	RequiredStatLevel = 3,
	Radius = 50,
	SampleInterval = 0.25,
	ToggleCooldown = 0.5,
	CutsceneDuration = 2,
	CutsceneCooldown = 30,
	CutsceneDistance = 20,
	CutscenePowerRatio = 2.5,
	CutsceneLevelGap = 12,
	CutsceneFov = 35,
	BlockedActions = {
		Run = true, Attack = true, StrongAttack = true, Block = true, Roll = true,
		Kick = true, Skill = true, Climb = true, WallRun = true, Vault = true,
	},
}

function EgoConfig.GetPressure(SourceLevel: number, TargetLevel: number, Distance: number): (number, number)
	local Proximity = math.clamp(1 - Distance / EgoConfig.Radius, 0, 1)
	local Ratio = (SourceLevel + 6) / (TargetLevel + 6)
	local Ceiling = math.clamp(40 * Ratio, 0, if TargetLevel > SourceLevel then 20 else 100)
	local GainPerSecond = 10 + 20 * math.clamp((Ratio - 1) / 3, 0, 1)

	return Ceiling * Proximity, GainPerSecond * Proximity
end

function EgoConfig.ShouldPlayCutscene(SourceLevel: number, TargetLevel: number, Distance: number): boolean
	return Distance <= EgoConfig.CutsceneDistance
		and SourceLevel - TargetLevel >= EgoConfig.CutsceneLevelGap
		and (SourceLevel + 6) / (TargetLevel + 6) >= EgoConfig.CutscenePowerRatio
end

return EgoConfig
