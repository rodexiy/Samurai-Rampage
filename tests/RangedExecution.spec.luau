return function(CreateExecution: (any) -> any, CreateBow: (any) -> any): string
	local Checks = 0
	local function Check(Value: boolean, Message: string)
		assert(Value, Message)
		Checks += 1
	end
	local function Character(Attributes: { [string]: any }): any
		return {
			Parent = true, PrimaryPart = { CFrame = CFrame.identity },
			GetAttribute = function(_Self: any, Name: string): any
				return Attributes[Name]
			end,
			SetAttribute = function(_Self: any, Name: string, Value: any)
				Attributes[Name] = Value
			end,
		}
	end

	local Attacker = Character({ Health = 50, MaxHealth = 100, Stamina = 5, MaxStamina = 100 })
	local Player = {}
	local Executed, Kills, Quests, Blood, Boxes = 0, 0, 0, 0, 0
	local Targets = {}
	local Execution = CreateExecution({
		Players = { GetPlayerFromCharacter = function(_Self: any, Target: any): any
			return if Target == Attacker then Player else nil
		end },
		Instance = { new = function(): any
			return { Fire = function(_Self: any, Source: any, Target: any)
				Check(Source == Attacker and Target:GetAttribute("Died") == true, "Emit execution only after marking the victim dead")
				Executed += 1
			end }
		end },
		Services = {
			HitboxService = { GetCharactersInBoxArea = function(): { any }
				Boxes += 1
				return Targets
			end },
			RenderService = { RenderForAllPlayers = function()
				Blood += 1
			end },
			QuestService = { CallQuestFunction = function(_Self: any, Owner: any, Action: string)
				Check(Owner == Player and Action == "Kill", "Use the normal execution quest credit")
				Quests += 1
			end },
			SkillTreeService = { IsSkillUnlocked = function(): boolean
				return false
			end },
			KillStreakService = { HandlePlayerKill = function()
				Kills += 1
			end },
		},
	})
	local HitResult: string? = "Hit"
	local KnockDown = false
	local Bow = CreateBow({
		ExecutionService = Execution,
		HitService = { NormalHit = function(_Self: any, Target: any): string?
			if KnockDown then
				Target:SetAttribute("Downed", true)
			end
			return if Target:GetAttribute("ForceField") then nil else HitResult
		end },
	})

	for _, Weapon in { "Bow", "Tanegashima" } do
		local Victim = Character({ Downed = true })
		local Previous = Executed
		Bow:ResolveProjectileHit(Victim, Attacker, 3, { By = Weapon, Ranged = true })
		Check(Victim:GetAttribute("Died") == true and Executed == Previous + 1, Weapon .. " executes an already downed victim")
		Check(Kills == Executed and Quests == Executed, "Ranged executions count toward kill streaks and quests")
		Bow:ResolveProjectileHit(Victim, Attacker, 3, { By = Weapon, Ranged = true })
		Check(Executed == Previous + 1, "Repeated projectile hits cannot execute or reward the same victim twice")
	end
	Check(Blood == 0 and Boxes == 0, "Ranged execution uses the actual hit target without a melee range scan or duplicate blood")
	Check(Attacker:GetAttribute("Stamina") == 100, "Preserve the execution stamina reward")

	local Standing = Character({ Downed = false })
	KnockDown = true
	local Previous = Executed
	Bow:ResolveProjectileHit(Standing, Attacker, 65, { Ranged = true })
	Check(Standing:GetAttribute("Downed") == true and not Standing:GetAttribute("Died") and Executed == Previous,
		"A shot that first downs a victim must not also execute them")
	KnockDown = false
	for _, Outcome in { "Blocked", "Deflected", "Dodged", "NoHit" } do
		HitResult = if Outcome == "NoHit" then nil else Outcome
		local Protected = Character({ Downed = true })
		Bow:ResolveProjectileHit(Protected, Attacker, 65, { Ranged = true })
		Check(not Protected:GetAttribute("Died") and Executed == Previous, Outcome .. " cannot trigger an execution")
	end
	HitResult = "Hit"
	local Shielded = Character({ Downed = true, ForceField = true })
	Bow:ResolveProjectileHit(Shielded, Attacker, 65, { Ranged = true })
	Check(not Shielded:GetAttribute("Died") and Executed == Previous, "A rejected force-field hit cannot execute")
	local NoRewards = Character({ Downed = true, NoRewards = true })
	Bow:ResolveProjectileHit(NoRewards, Attacker, 65, { Ranged = true })
	Check(NoRewards:GetAttribute("Died") == true and Executed == Previous + 1 and Kills == Previous and Quests == Previous,
		"Preserve execution events while respecting NoRewards")

	local MeleeVictim = Character({ Downed = true })
	Targets = { Attacker, MeleeVictim }
	Execution:ExecuteInRange(Attacker)
	Check(MeleeVictim:GetAttribute("Died") == true and Blood == 1 and Boxes == 1,
		"Existing melee execution still uses the same shared completion path")
	Check(not Execution:Execute(Attacker, Attacker), "Cannot execute yourself")
	Check(not Execution:Execute(Attacker, Character({ Downed = false })), "Cannot execute a standing victim")
	local AI = Character({ IsAI = true })
	Check(not Execution:Execute(AI, Character({ IsAI = true, Downed = true })), "Preserve AI-versus-AI execution restrictions")

	return string.format("Ranged execution: %d checks passed", Checks)
end
