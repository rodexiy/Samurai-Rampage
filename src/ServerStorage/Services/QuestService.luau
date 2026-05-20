local Knit = require(game.ReplicatedStorage.Packages.Knit)

local QuestService = Knit.CreateService({
	Name = "QuestService",
	Client = {
		CreateTargetBillboard = Knit.CreateSignal(),
		RemoveTargetBillboard = Knit.CreateSignal(),
	},
})

local AlertService
local MissionBoardService
local ObjectiveService

local DataService

local QuestsData
function QuestService:GetQuestData(QuestName: string)
	return QuestsData[QuestName]
end

function QuestService:CreateTarget(Player: Player, Title: string, Parent: Instance)
	QuestService.Client.CreateTargetBillboard:Fire(Player, Title, Parent)
end

function QuestService:RemoveTarget(Player: Player, Title: string)
	QuestService.Client.RemoveTargetBillboard:Fire(Player, Title)
end

function QuestService:MeetRequirements(Player: Player, QuestName: string)
	return true
end

function QuestService:GiveQuest(Player: Player, QuestName: string, ...)
	if MissionBoardService:GetPlayerSelectedMission(Player) ~= nil then
		AlertService:AlertPlayer(Player, "You already have an objective.", "Error")
		return false
	end
	if not QuestService:MeetRequirements(Player, QuestName) then
		return false
	end

	QuestService:RemoveQuest(Player)

	local PlayerData = DataService:GetData(Player)

	if PlayerData.Quest.Name ~= nil then
		AlertService:AlertPlayer(Player, "You already have an objective.", "Error")
		return false
	end
	PlayerData.Quest = {
		Name = QuestName,
	}

	local callback = QuestService:CallQuestFunction(Player, "OnStart", ...)
	if not callback then
		QuestService:RemoveQuest(Player)
		return false
	else
		Player:SetAttribute("HasQuest", true)
	end

	return true
end

function QuestService:RemoveQuest(Player: Player)
	local PlayerData = DataService:GetData(Player)

	if PlayerData.Quest then
		if PlayerData.Quest.TargetName then
			QuestService:RemoveTarget(Player, PlayerData.Quest.TargetName)
		end
		QuestService:RemoveTarget(Player, PlayerData.Quest.Name)
	end

	PlayerData.Quest = {}
	MissionBoardService:DestroyMission(Player)
	Player:SetAttribute("HasQuest", false)
end

function QuestService:AbandonQuest(Player: Player)
	QuestService:CallQuestFunction(Player, "Cancel")
	QuestService:RemoveQuest(Player)
	ObjectiveService:ClearObjectives(Player)
end
function QuestService.Client:AbandonQuest(Player: Player)
	self.Server:AbandonQuest(Player)
end

function QuestService:CallQuestFunction(Player: Player, FunctionName: string, ...: any)
	if not Player or not Player:IsA("Player") then
		return false
	end

	local PlayerData = DataService:GetData(Player)
	local Quest = PlayerData.Quest
	if not Quest then
		return
	end
	local QuestName = Quest.Name
	local QuestData = QuestService:GetQuestData(QuestName)

	if not QuestData or not QuestData[FunctionName] then
		return false
	end

	return QuestData[FunctionName](Player, ...)
end

function QuestService.KnitInit()
	AlertService = Knit.GetService("AlertService")
	DataService = Knit.GetService("DataService")
	MissionBoardService = Knit.GetService("MissionBoardService")
	ObjectiveService = Knit.GetService("ObjectiveService")
end

function QuestService.KnitStart()
	QuestsData = require(game.ReplicatedStorage.Shared.Index.Quests)
end

return QuestService
