local Kill = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)
local MissionBoardService = Knit.GetService("MissionBoardService")
local AIService = Knit.GetService("AIService")
local MobService = Knit.GetService("MobService")
local QuestService = Knit.GetService("QuestService")
local ObjectiveService = Knit.GetService("ObjectiveService")

local AllEnemies: { [Player]: { Model } } = {}

function Kill:Randomize(Player: Player)
	local AmountOfEnemies = math.random(1, 4)
	local Description = AmountOfEnemies == 1 and "Defeat 1 enemy" or ("Defeat " .. AmountOfEnemies .. " enemies")
	local BaseExp = 200
	local RandomFactor = math.random(BaseExp * 0.95, BaseExp * 1.05) / 100

	local Exp = math.floor((BaseExp * AmountOfEnemies) * RandomFactor)

	return {
		Name = "Kill",
		DisplayName = "Hunt " .. AmountOfEnemies .. " enemies",
		Description = Description,
		Exp = Exp,
		Tetsu = math.floor(Exp * 0.3),
		MissionData = {
			AmountOfEnemies = AmountOfEnemies,
		},
		Image = "rbxassetid://111227102549888",
	}
end

function Kill:Select(Player: Player, Mission: { any })
	local EnemiesSpawnPosition = MissionBoardService:GetRandomPointInSpawn()

	if AllEnemies[Player] then
		for _, Enemy in AllEnemies[Player] do
			Enemy:Destroy()
		end
	end

	local AmountKilled = 0
	local EnemiesFromQuest = {}
	AllEnemies[Player] = EnemiesFromQuest

	local AmountOfEnemies = Mission.MissionData.AmountOfEnemies

	local SubObjectives = {}
	table.insert(SubObjectives, {
		Name = "Hunt " .. AmountOfEnemies .. " enemies",
		TargetAmount = AmountOfEnemies,
		CurrentAmount = 0,
	})

	ObjectiveService:AddObjective(Player, "MissionBoardKill", SubObjectives)

	for i = 1, AmountOfEnemies do
		local RandomMobPosition = EnemiesSpawnPosition + Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
		local Mob = MobService:SpawnMob(
			"Bandit",
			CFrame.new(RandomMobPosition) * CFrame.Angles(0, math.rad(math.random(0, 360)), 0),
			"Bandit"
		)
		AIService:AddAI(Mob, "Bandit", "Bandit")

		table.insert(EnemiesFromQuest, Mob)

		task.delay(1, function()
			QuestService:CreateTarget(Player, "DONTSHOW_Kill_" .. tostring(i), Mob.HumanoidRootPart)
		end)

		Mob:GetAttributeChangedSignal("Died"):Connect(function()
			if Mob:GetAttribute("Died") then
				table.remove(AllEnemies[Player], table.find(AllEnemies[Player], Mob))
				QuestService:RemoveTarget(Player, "DONTSHOW_Kill_" .. tostring(i))

				AmountKilled += 1

				ObjectiveService:UpdateProgress(Player, "MissionBoardKill", 1, 1)

				if AmountKilled == AmountOfEnemies then
					MissionBoardService:FinishedMission(Player, Mission)
				end
			end
		end)
	end
end

function Kill:Destroy(Player: Player, Mission: { any })
	if AllEnemies[Player] then
		for _, Enemy in AllEnemies[Player] do
			Enemy:Destroy()
		end
	end

	for i = 1, Mission.MissionData.AmountOfEnemies do
		QuestService:RemoveTarget(Player, "DONTSHOW_Kill_" .. tostring(i))
	end

	AllEnemies[Player] = nil
end

return Kill
