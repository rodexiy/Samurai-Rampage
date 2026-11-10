-- Shared balance settings. XPRequired[1] is the cost of going from level 0 to 1.
local Progression = {
	Names = { "Strength", "Resistance", "Vitality", "Agility", "Dexterity", "Spirit" },
	MaxLevel = 10,
	PointsPerLevel = 1,
	-- 28,800 total XP: about eight hours at the reference training rates below.
	XPRequired = { 250, 450, 800, 1250, 1850, 2550, 3450, 4600, 6000, 7600 },
	-- Example: Strength = { 150, 250, ... } overrides the shared costs for that stat.
	StatXPRequired = {} :: { [string]: { number } },
	Training = {
		MeleeHit = 2, -- Reference: 30 landed hits per minute.
		Block = 4, -- Reference: 15 blocks per minute.
		Parry = 8, -- Reference: 7.5 parries per minute.
		Dodge = 6,
		Roll = 1,
		DamageTaken = 0.4, -- Reference: 150 actual combat damage per minute, including recovery.
		RunDistance = 0.037, -- Reference: base sprint speed 24, including agility's speed bonuses.
		Meditation = 1, -- XP per second, near a rug or with MeditateAnywhere.
		ArtifactSkill = 5,
		SampleInterval = 1,
		MaxRunDistancePerSecond = 100, -- Ignore teleports when measuring running.
	},
	Rewards = {
		Multiplier = 0.1, -- Scale rewards inherited from the general-level system.
		MaxXPPerStat = 120, -- Up to two minutes of reference training per reward and stat.
	},
	Bonuses = {
		Strength = { WeaponDamage = 2 },
		Resistance = { Stamina = 8, Posture = 5, WeaponResistance = 1 },
		Vitality = { Health = 10 },
		Agility = { RunMultiplier = 0.02, WalkSpeed = 0.3 },
		Dexterity = { StaminaCostReduction = 0.02 },
		Spirit = { ArtifactStrength = 3, Regeneration = 0.0005 },
	},
	RewardWeights = {
		Combat = { Strength = 1, Dexterity = 1 },
		Gathering = { Strength = 1, Resistance = 1 },
		Delivery = { Agility = 1, Resistance = 1 },
		Exploration = { Agility = 1 },
		Meditation = { Spirit = 1 },
		Healing = { Vitality = 1, Spirit = 1 },
	},
	Help = {
		Strength = "Gain XP by landing melee attacks and gathering resources.",
		Resistance = "Gain XP by blocking attacks and completing physical work.",
		Vitality = "Gain XP by taking damage in combat and completing healing tasks.",
		Agility = "Gain XP by sprinting, rolling, dodging attacks, and making deliveries.",
		Dexterity = "Gain XP by parrying attacks and completing combat challenges.",
		Spirit = "Gain XP by meditating near rugs and using artifact abilities.",
	},
}

export type Stat = { Level: number, XP: number }

function Progression.IsStat(Name: string): boolean
	return table.find(Progression.Names, Name) ~= nil
end

function Progression.GetXPRequired(Name: string, Level: number): number
	if Level >= Progression.MaxLevel then
		return 0
	end

	local Costs = Progression.StatXPRequired[Name] or Progression.XPRequired
	local Cost = Costs[math.max(0, math.floor(Level)) + 1]
	assert(typeof(Cost) == "number" and Cost > 0 and Cost < math.huge, "Missing or invalid XP cost for " .. Name)
	return Cost
end

function Progression.Advance(Stat: Stat, Name: string, Amount: number): number
	assert(Progression.IsStat(Name), "Unknown stat: " .. Name)
	if Amount ~= Amount or Amount < 0 or Amount == math.huge then
		return 0
	end

	local Previous = math.clamp(math.floor(Stat.Level), 0, Progression.MaxLevel)
	Stat.Level = Previous
	Stat.XP = math.max(0, Stat.XP) + Amount
	while Stat.Level < Progression.MaxLevel do
		local Required = Progression.GetXPRequired(Name, Stat.Level)
		if Stat.XP < Required then
			break
		end

		Stat.XP -= Required
		Stat.Level += 1
	end

	if Stat.Level == Progression.MaxLevel then
		Stat.XP = 0
	end

	return Stat.Level - Previous
end

return Progression
