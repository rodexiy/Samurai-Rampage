local Players = game:GetService("Players")

local Knit = require(game.ReplicatedStorage.Packages.Knit)
local DataService = Knit.GetService("DataService")
local TetsuService = Knit.GetService("TetsuService")
local QuestService = Knit.GetService("QuestService")
local LevelService = Knit.GetService("LevelService")
local AlertService = Knit.GetService("AlertService")
local ObjectiveService = Knit.GetService("ObjectiveService")

local Collector = require(game.ReplicatedStorage.Shared.Collector)

local function GetTarget(Player: Player): Model | false
	local InDistance = {}
	local Character = Player.Character
	for _, PlayerTarget in Players:GetPlayers() do
		if PlayerTarget ~= Player then
			local TargetCharacter = PlayerTarget.Character
			if TargetCharacter and Character then
				table.insert(InDistance, TargetCharacter)
			end
		end
	end
	if #InDistance == 0 then
		return false
	end
	return InDistance[math.random(1, #InDistance)]
end

return {
	Name = "Assassinate",
	QuestType = "Kill",
	Requirements = {},

	OnStart = function(Player: Player)
		local Target: Model | false = GetTarget(Player)
		if not Target then
			AlertService:AlertPlayer(Player, "There is no one to assassinate", "Error")
			return false
		end

		local PlayerData = DataService:GetData(Player)
		PlayerData.Quest.KillCount = 0
		PlayerData.Quest.TargetName = Target.Name

		QuestService:CreateTarget(Player, Target.Name, Target.PrimaryPart)

		ObjectiveService:AddObjective(Player, "QuestAssassinate", {
			{
				Name = "Eliminate " .. Target.Name,
				TargetAmount = 1,
				CurrentAmount = 0,
			},
		})

		local Collection = Collector.new()

		Collection:Add(Target:GetPropertyChangedSignal("Parent"):Connect(function()
			if Target.Parent == nil then
				QuestService:RemoveQuest(Player)
				ObjectiveService:ClearObjectives(Player)
				Collection:Destroy()
			end
		end))

		Collection:Add(Player:GetPropertyChangedSignal("Parent"):Connect(function()
			if Player.Parent == nil then
				QuestService:RemoveQuest(Player)
				ObjectiveService:ClearObjectives(Player)
				Collection:Destroy()
			end
		end))

		if Player.Character then
			Collection:Add(Player.Character:GetAttributeChangedSignal("Died"):Connect(function()
				if Player.Character and Player.Character:GetAttribute("Died") then
					QuestService:RemoveQuest(Player)
					ObjectiveService:ClearObjectives(Player)
					Collection:Destroy()
				end
			end))
		end

		return true
	end,

	Kill = function(Player: Player, Entity: Model)
		local PlayerData = DataService:GetData(Player)
		if PlayerData.Quest.TargetName ~= Entity.Name then
			return
		end

		PlayerData.Quest.KillCount += 1
		ObjectiveService:UpdateProgress(Player, "QuestAssassinate", 1, 1)

		if PlayerData.Quest.KillCount >= 1 then
			QuestService:CallQuestFunction(Player, "CompleteQuest")
		end
	end,

	CompleteQuest = function(Player: Player)
		TetsuService:AddTetsu(Player, 150)
		LevelService:GiveExp(Player, 300)
		ObjectiveService:ClearObjectives(Player, true)
	end,
}
