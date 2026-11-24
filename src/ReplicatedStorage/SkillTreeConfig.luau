local Config = {
	Version = 1,
	Names = { "Strength", "Resistance", "Vitality", "Agility", "Dexterity" },
	StarterSkills = { "Up Slash", "Barrage", "Floating Passage" },
	LegacyPermanentSkills = {
		"Oni Health Recovery", "Lightning Dash", "Heavens Recall", "Grapple",
		"Up Slash Block Break", "Longer Barrage", "Heavy Deflect",
	},
	Trees = {},
	Effects = {
		HeavyPostureMultiplier = 1.2, ContinuitySpeed = 1.12, SweepTargets = 3,
		ImpactPushMultiplier = 1.3, PressurePushMultiplier = 0.65,
		OpeningDuration = 2, OpeningDistance = 2,
		ParryStaminaDivisor = 1.45, FeintCost = 5, FeintCooldown = 3, FeintStep = 1.5,
		ParryRecovery = 0.15, ResponseDuration = 1.5, ResponsePosture = 10, ResponseRollCost = 3,
		LongRollDuration = 0.65, LongRollDistance = 1.3, ShortRollDuration = 0.35, ShortRollDistance = 0.75,
		ModerateFallLimit = 180, FallDamageMultiplier = 0.6,
		GuardRecoveryBonus = 0.02, GuardPushMultiplier = 0.7,
		PostureBreakDuration = 1.5, PostureBreakCooldown = 20,
		GuardSequenceWindow = 2, GuardSequenceHits = 3, GuardStamina = 8, GuardCooldown = 5,
		GuardWalkSpeed = 10, BlockRecovery = 0.4,
		RestRegeneration = 0.01,
		ExecutionHealFraction = 0.15, BurnDurationMultiplier = 0.6,
		CriticalHealthFraction = 0.25, SecondWindDelay = 4, SecondWindHealFraction = 0.1, SecondWindCooldown = 60,
		RecoveryDelay = 5, RecoveryFraction = 0.2, RecoveryCap = 0.1, CombatRecoveryCap = 0.15,
	},
}

local function Node(Name: string, Description: string, X: number, Y: number, Branches: { any }?, Options: { [string]: any }?): any
	local Definition = {
		Name = Name, Description = Description, Layout = { X = X, Y = Y },
		PointsRequired = 2, Passive = true, Branches = Branches,
	}
	for Key, Value in Options or {} do
		Definition[Key] = Value
	end

	return Definition
end

local function CreateTree(Name: string, Color: Color3, Description: string, Branches: { any }): any
	local function SetStat(Entries: { any })
		for _, Entry in Entries do
			Entry.Stat = Name
			SetStat(Entry.Branches or {})
		end
	end
	SetStat(Branches)

	return { Name = Name, Stat = Name, Color = Color, Description = Description, Layout = { X = 0, Y = 0 }, Branches = Branches }
end

Config.Trees.Strength = CreateTree("Strength", Color3.fromRGB(163, 0, 0), "Improve melee impact and exploit openings.", {
	Node("Committed Attack", "Heavy attacks deal 20% more posture damage against a guard.", -1, 0, {
		Node("Continuity", "After landing a heavy attack, your next basic attack starts 12% faster within two seconds.", -2, 0, {
			Node("Make Room", "Heavy attacks can hit up to three nearby targets instead of one.", -2, -1, {
				Node("Heavy Impact", "Heavy attacks push enemies 30% farther. Exclusive with Close Pressure.", -3, -2, nil, { ChoiceGroup = "StrengthPreference" }),
				Node("Close Pressure", "Heavy attacks push enemies 35% less, keeping them close. Exclusive with Heavy Impact.", -1, -2, nil, { ChoiceGroup = "StrengthPreference" }),
				Node("Exploit Opening", "After breaking a guard, your next basic attack within two seconds advances up to two studs.", -2, -3, nil, { RequiresAny = { "Heavy Impact", "Close Pressure" } }),
			}),
		}),
	}),
})
Config.Trees.Dexterity = CreateTree("Dexterity", Color3.fromRGB(144, 146, 156), "Improve precision, feints and parry responses.", {
	Node("Deflect Stamina Recovery", "Successful parries restore more stamina.", 0, -1, {
		Node("Feint", "Right-click during a basic melee attack windup to cancel it. Costs 5 stamina; three second cooldown.", -1, -2, {
			Node("Moving Feint", "A successful feint also steps forward up to 1.5 studs, respecting walls.", -1, -3),
		}),
		Node("Retake Initiative", "After a successful parry, return to attacking sooner.", 1, -2, {
			Node("Firm Response", "Your next basic attack within 1.5 seconds of a parry deals 10 extra posture damage. Exclusive with Mobile Response.", 0.5, -3, nil, { ChoiceGroup = "DexterityPreference" }),
			Node("Mobile Response", "Your next roll within 1.5 seconds of a parry costs 3 stamina. Exclusive with Firm Response.", 1.5, -3, nil, { ChoiceGroup = "DexterityPreference" }),
		}),
	}),
})
Config.Trees.Agility = CreateTree("Agility", Color3.fromRGB(172, 142, 85), "Improve traversal and choose your roll preference.", {
	Node("Climb", "Climb walls by pressing G.", 1, 0, {
		Node("Climb Speed", "Climb walls faster.", 0, -1),
		Node("WallRun", "Run along walls by jumping again beside a wall while airborne.", 1, 1, nil, { TrainerUnlock = true }),
		Node("Vault", "Jump over low obstacles.", 2, 1),
		Node("Travel Breath", "Running and climbing no longer drain stamina outside combat.", 2, -1, {
			Node("Controlled Landing", "Take 40% less damage from moderate falls. Extreme falls remain dangerous.", 2, -2, {
				Node("Long Roll", "Roll farther, but return to attacking later. Invulnerability is unchanged. Exclusive with Short Roll.", 1.5, -3, nil, { ChoiceGroup = "AgilityPreference" }),
				Node("Short Roll", "Roll a shorter distance, but return to attacking sooner. Invulnerability is unchanged. Exclusive with Long Roll.", 2.5, -3, nil, { ChoiceGroup = "AgilityPreference" }),
			}),
		}),
	}),
})
Config.Trees.Resistance = CreateTree("Resistance", Color3.fromRGB(189, 83, 22), "Manage blocking, pressure and posture recovery.", {
	Node("Recompose Guard", "Recover posture faster after lowering your guard while neither attacking nor taking hits.", 0, -1, {
		Node("Firm Footing", "Reduce defensive knockback by 30%. Does not prevent guard breaks.", -1, -2, {
			Node("Economical Guard", "Three blocks within two seconds restore 8 stamina. Five second cooldown. Exclusive with Mobile Guard.", -1, -3, nil, { ChoiceGroup = "ResistancePreference" }),
		}),
		Node("Rise Again", "Recover from a posture break in 1.5 seconds instead of two. Twenty second cooldown.", 1, -2, {
			Node("Mobile Guard", "Move faster while blocking. Exclusive with Economical Guard.", 1, -3, nil, { ChoiceGroup = "ResistancePreference" }),
		}),
		Node("Defensive Retreat", "Return to movement sooner after blocking a hit. Adds no invulnerability.", 0, -4, nil, {
			RequiresAll = { "Firm Footing", "Rise Again" }, RequiresAny = { "Economical Guard", "Mobile Guard" },
		}),
	}),
})
Config.Trees.Vitality = CreateTree("Vitality", Color3.fromRGB(62, 159, 32), "Recover naturally, resist burns and survive combat.", {
	Node("Rest Recovery", "Regenerate an additional 1% maximum health per second outside combat while not downed.", 0, -1, {
		Node("Burn Resistance", "Burns expire 40% sooner. Does not grant immunity.", -1, -2),
		Node("Health Recovery", "Executing a valid enemy restores 15% maximum health. Does not stack with Oni recovery.", 0, -2),
		Node("Second Wind", "After a combat hit leaves you at 25% health or less, avoid further damage for four seconds to restore 10% maximum health. Sixty second cooldown.", 1, -2),
		Node("Recovery Reserve", "After five seconds without damage, recover 20% of the last combat hit, capped at 10% maximum health. Combined with Second Wind, recovery is capped at 15% maximum health per hit.", 0, -3, nil, {
			RequiresAll = { "Burn Resistance", "Health Recovery", "Second Wind" },
		}),
	}),
})

function Config.GetRollProfile(Long: boolean, Short: boolean): (number, number)
	if Long then
		return Config.Effects.LongRollDuration, Config.Effects.LongRollDistance
	elseif Short then
		return Config.Effects.ShortRollDuration, Config.Effects.ShortRollDistance
	end

	return 0.5, 1
end

return Config
