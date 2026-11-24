return function(Config: any, Progression: any): number
	local Checks = 0
	local function Check(Value: boolean, Message: string)
		assert(Value, Message)
		Checks += 1
	end
	local Nodes = Progression.Index(Config.Trees)
	local Count = 0
	for _ in Nodes do
		Count += 1
	end
	Check(Count == 31 and #Config.Names == 5, "Five attribute trees contain thirty-one talents")

	local Layouts = {}
	for _, Stat in Config.Names do
		local Tree = Config.Trees[Stat]
		local Names, Positions, Coordinates = {}, {}, {}
		Coordinates["0,0"] = true
		for Name, Node in Nodes do
			if Node.Stat == Stat then
				table.insert(Names, Name)
				local Position = tostring(Node.Layout.X) .. "," .. tostring(Node.Layout.Y)
				Check(not Coordinates[Position], "Nodes cannot overlap the root or another talent")
				Coordinates[Position] = true
				table.insert(Positions, Position)
			end
		end
		table.sort(Positions)
		local Layout = table.concat(Positions, ";")
		Check(not Layouts[Layout], "Each tree has its own layout")
		Layouts[Layout] = true
		local Seen, Reachable, Routes = {}, {}, 0
		local function Explore(Unlocked: { string })
			local Sorted = table.clone(Unlocked)
			table.sort(Sorted)
			local Key = table.concat(Sorted, ";")
			if Seen[Key] then
				return
			end
			Seen[Key] = true
			local Data = { Stats = { [Stat] = { Level = 10 } }, UnlockedNodes = Unlocked, SkillTreeVersion = Config.Version }
			local Advanced = false
			for _, Name in Names do
				if Progression.CanUnlock(Data, Name, Nodes) then
					Advanced = true
					Reachable[Name] = true
					local Next = table.clone(Unlocked)
					table.insert(Next, Name)
					Explore(Next)
				end
			end
			if not Advanced then
				Routes += 1
				Check(#Unlocked == 5 and Progression.GetPoints(Data, Stat, Nodes) == 0, "Every purchase order finishes with five talents for ten points")
				local Reversed = {}
				for Index = #Unlocked, 1, -1 do
					table.insert(Reversed, Unlocked[Index])
				end
				Data.UnlockedNodes = Reversed
				Progression.Reconcile(Data, Nodes, Config.Version)
				Check(#Data.UnlockedNodes == 5, "Reconciliation preserves valid talents regardless of saved order")
			end
		end
		Explore({})
		Check(if Stat == "Agility" then Routes > 2 else Routes == (if Stat == "Vitality" then 1 else 2),
			"Preferences and optional traversal talents produce complete routes")
		for _, Name in Names do
			Check(Reachable[Name], "Every talent is reachable: " .. Name)
		end
		Check(Tree.Branches[1].Stat == Stat, "Tree talents use their own attribute points")
	end
	local Agility = { Stats = { Agility = { Level = 10 } }, UnlockedNodes = {} }
	for _, Name in { "Climb Speed", "WallRun", "Vault" } do
		Check(not Progression.CanUnlock(Agility, Name, Nodes), "Optional traversal talents still require Climb: " .. Name)
	end
	table.insert(Agility.UnlockedNodes, "Climb")
	for _, Name in { "Climb Speed", "WallRun", "Vault" } do
		Check(Progression.CanUnlock(Agility, Name, Nodes), "Traversal talents unlock independently after Climb: " .. Name)
	end
	for _, Name in { "Travel Breath", "Controlled Landing", "Long Roll" } do
		Check(Progression.CanUnlock(Agility, Name, Nodes), "The main route does not require optional traversal talents: " .. Name)
		table.insert(Agility.UnlockedNodes, Name)
	end
	Check(Progression.GetPoints(Agility, "Agility", Nodes) == 2, "Skipping optional talents leaves two points after a roll preference")
	Agility.OtherSkills = { "WallRun" }
	Check(not Progression.CanUnlock(Agility, "WallRun", Nodes), "Trainer unlocks cannot be purchased again")
	Check(Progression.GetPoints(Agility, "Agility", Nodes) == 2, "Trainer unlocks do not spend attribute points")
	local Convergence = { Stats = { Vitality = { Level = 10 } }, UnlockedNodes = { "Rest Recovery", "Burn Resistance", "Second Wind" } }
	Check(not Progression.CanUnlock(Convergence, "Recovery Reserve", Nodes), "Converging branches require every prerequisite")
	table.insert(Convergence.UnlockedNodes, "Health Recovery")
	Check(Progression.CanUnlock(Convergence, "Recovery Reserve", Nodes), "Completing the branches opens the converging talent")
	local Migrated = { Stats = { Vitality = { Level = 10 } }, SkillTreeVersion = Config.Version,
		UnlockedNodes = { "Efficient Dressing", "Rest Recovery", "Preserved Dressing", "Health Recovery", "Last Breath" } }
	Progression.Reconcile(Migrated, Nodes, Config.Version)
	Check(#Migrated.UnlockedNodes == 2 and Progression.GetPoints(Migrated, "Vitality", Nodes) == 6, "Retired item talents refund points and preserve existing valid talents")
	Check(#Migrated.RetiredSkillNodes == 3, "Removed purchases remain archived")

	local Data = { Stats = { Strength = { Level = 1 }, Agility = { Level = 10 } }, UnlockedNodes = {} }
	Check(not Progression.CanUnlock(Data, "Committed Attack", Nodes), "Points from another tree cannot cover an insufficient balance")
	Data.Stats.Strength.Level = 2
	local LegacyNodes = table.clone(Nodes)
	LegacyNodes["Committed Attack"] = table.clone(Nodes["Committed Attack"])
	LegacyNodes["Committed Attack"].LevelRequired = 100
	Check(Progression.CanUnlock(Data, "Committed Attack", LegacyNodes), "Sufficient points unlock a talent without a separate level gate")
	Data.Stats.Strength.Level = 10
	Check(not Progression.CanUnlock(Data, "Continuity", Nodes), "Later nodes require the previous talent")
	Data.UnlockedNodes = { "Committed Attack", "Committed Attack", "Make Room", "Unknown" }
	Data.SkillTreeVersion = Config.Version
	Progression.Reconcile(Data, Nodes, Config.Version)
	Check(#Data.UnlockedNodes == 1 and Data.UnlockedNodes[1] == "Committed Attack", "Duplicate, unknown and orphan nodes are removed")
	Check(Progression.GetPoints(Data, "Strength", Nodes) == 8, "Points derive from valid purchases")
	local Duration, Distance = Config.GetRollProfile(true, false)
	local ShortDuration, ShortDistance = Config.GetRollProfile(false, true)
	Check(Duration > 0.5 and Distance > 1 and ShortDuration < 0.5 and ShortDistance < 1, "Roll preferences trade distance for recovery")
	return Checks
end
