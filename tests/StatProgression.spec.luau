-- Run this module in Studio with require(ReplicatedStorage.Shared.StatProgression).
return function(Progression: { [string]: any }): number
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local First = Progression.GetXPRequired("Strength", 0)
	local Second = Progression.GetXPRequired("Strength", 1)
	local Stat = { Level = 0, XP = 0 }
	Progression.Advance(Stat, "Strength", First - 1)
	Check(Stat.Level == 0 and Stat.XP == First - 1, "Insufficient XP must not level up")
	Check(Progression.Advance(Stat, "Strength", 1) == 1, "An exact threshold grants one level")
	Check(Stat.Level == 1 and Stat.XP == 0, "Exact threshold leaves zero XP")

	local Overflow = { Level = 0, XP = 0 }
	local Remainder = Progression.GetXPRequired("Strength", 2) / 2
	Check(Progression.Advance(Overflow, "Strength", First + Second + Remainder) == 2, "One reward can grant multiple levels")
	Check(Overflow.Level == 2 and Overflow.XP == Remainder, "Overflow XP must be retained")

	local Other = { Level = 0, XP = 0 }
	Progression.Advance(Other, "Vitality", 1)
	Check(Overflow.Level == 2 and Other.Level == 0 and Other.XP == 1, "Attributes progress independently")

	local Total = 0
	for Level = 0, Progression.MaxLevel - 1 do
		Total += Progression.GetXPRequired("Strength", Level)
	end
	local Capped = { Level = 0, XP = 0 }
	Check(Progression.Advance(Capped, "Strength", Total + 99999) == Progression.MaxLevel, "Large awards stop at the cap")
	Check(Capped.Level == Progression.MaxLevel and Capped.XP == 0, "Max level stores no excess XP")
	Check(Progression.GetXPRequired("Strength", Capped.Level) == 0, "Max level has no next threshold")

	for _, Invalid in { -10, math.huge, 0 / 0 } do
		local Unchanged = { Level = 0, XP = 0 }
		Progression.Advance(Unchanged, "Strength", Invalid)
		Check(Unchanged.Level == 0 and Unchanged.XP == 0, "Invalid XP must not change progression")
	end

	local Previous = Progression.StatXPRequired.Strength
	local Override = table.clone(Progression.XPRequired)
	Override[1] = First * 2
	Progression.StatXPRequired.Strength = Override
	local Success, Error = pcall(function()
		Check(Progression.GetXPRequired("Strength", 0) == First * 2, "Per-attribute costs override the common curve")
		Check(Progression.GetXPRequired("Vitality", 0) == First, "Overrides do not affect other attributes")
	end)
	Progression.StatXPRequired.Strength = Previous
	assert(Success, Error)

	local ReferenceRates = {
		Strength = 30 / 60 * Progression.Training.MeleeHit,
		Resistance = 15 / 60 * Progression.Training.Block,
		Vitality = 150 / 60 * Progression.Training.DamageTaken,
		Dexterity = 7.5 / 60 * Progression.Training.Parry,
		Spirit = Progression.Training.Meditation,
	}
	for Name, Rate in ReferenceRates do
		local Seconds = 0
		for Level = 0, Progression.MaxLevel - 1 do
			Seconds += Progression.GetXPRequired(Name, Level) / Rate
		end

		Check(math.abs(Seconds / 3600 - 8) < 0.1, Name .. " should take about eight hours at the reference rate")
	end

	local SprintSeconds = 0
	for Level = 0, Progression.MaxLevel - 1 do
		local Speed = 24 * (1 + Level * Progression.Bonuses.Agility.RunMultiplier)
		SprintSeconds += Progression.GetXPRequired("Agility", Level) / (Speed * Progression.Training.RunDistance)
	end

	Check(math.abs(SprintSeconds / 3600 - 8) < 0.1, "Agility should take about eight hours including its speed bonuses")

	return Checks
end
