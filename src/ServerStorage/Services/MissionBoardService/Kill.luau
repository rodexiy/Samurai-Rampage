local Kill = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)
local MissionBoardService = Knit.GetService("MissionBoardService")
local AIService = Knit.GetService("AIService")
local MobService = Knit.GetService("MobService")
local QuestService = Knit.GetService("QuestService")
local ObjectiveService = Knit.GetService("ObjectiveService")

local AllEnemies: { [Player]: { Model } } = {}

local function GetObjectiveName(Mission: { any }): string
	return "MissionBoardKill_" .. Mission.Id
end

local function GetTargetName(Mission: { any }, Index: number): string
	return "DONTSHOW_Kill_" .. Mission.Id .. "_" .. tostring(Index)
end

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

	if not AllEnemies[Player] then
		AllEnemies[Player] = {}
	end

	local AmountKilled = 0
	local EnemiesFromQuest = {}
	AllEnemies[Player][Mission.Id] = EnemiesFromQuest
	Mission.MissionData.ObjectiveName = GetObjectiveName(Mission)

	local AmountOfEnemies = Mission.MissionData.AmountOfEnemies

	local SubObjectives = {}
	table.insert(SubObjectives, {
		Name = "Hunt " .. AmountOfEnemies .. " enemies",
		TargetAmount = AmountOfEnemies,
		CurrentAmount = 0,
	})

	ObjectiveService:AddObjective(Player, Mission.MissionData.ObjectiveName, SubObjectives)

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
			if Mob.Parent and Mob:FindFirstChild("HumanoidRootPart") then
				QuestService:CreateTarget(Player, GetTargetName(Mission, i), Mob.HumanoidRootPart)
			end
		end)

		Mob:GetAttributeChangedSignal("Died"):Connect(function()
			if Mob:GetAttribute("Died") then
				local EnemyIndex = table.find(EnemiesFromQuest, Mob)
				if EnemyIndex then
					table.remove(EnemiesFromQuest, EnemyIndex)
				end
				QuestService:RemoveTarget(Player, GetTargetName(Mission, i))

				AmountKilled += 1

				ObjectiveService:UpdateProgress(Player, Mission.MissionData.ObjectiveName, 1, 1)

				if AmountKilled == AmountOfEnemies then
					MissionBoardService:FinishedMission(Player, Mission)
				end
			end
		end)
	end
end

function Kill:Destroy(Player: Player, Mission: { any })
	local PlayerEnemies = AllEnemies[Player]
	local EnemiesFromQuest = PlayerEnemies and PlayerEnemies[Mission.Id]

	if EnemiesFromQuest then
		for _, Enemy in EnemiesFromQuest do
			Enemy:Destroy()
		end
	end

	for i = 1, Mission.MissionData.AmountOfEnemies do
		QuestService:RemoveTarget(Player, GetTargetName(Mission, i))
	end

	if PlayerEnemies then
		PlayerEnemies[Mission.Id] = nil
		if next(PlayerEnemies) == nil then
			AllEnemies[Player] = nil
		end
	end
end

return Kill
