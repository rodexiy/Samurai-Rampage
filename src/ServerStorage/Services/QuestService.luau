local Knit = require(game.ReplicatedStorage.Packages.Knit)

local QuestService = Knit.CreateService({
	Name = "QuestService",
	Client = {
		CreateTargetBillboard = Knit.CreateSignal(),
		CreateTargetBillboardAtPosition = Knit.CreateSignal(),
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

function QuestService:CreateTarget(Player: Player, Title: string, Parent: Instance, Options)
	QuestService.Client.CreateTargetBillboard:Fire(Player, Title, Parent, Options)
end

function QuestService:CreateTargetAtPosition(Player: Player, Title: string, Position: Vector3, Options)
	QuestService.Client.CreateTargetBillboardAtPosition:Fire(Player, Title, Position, Options)
end

function QuestService:RemoveTarget(Player: Player, Title: string)
	QuestService.Client.RemoveTargetBillboard:Fire(Player, Title)
end

function QuestService:MeetRequirements(Player: Player, QuestName: string)
	return true
end

function QuestService:CanAbandonQuest(Player: Player)
	local PlayerData = DataService:GetData(Player)
	local Quest = PlayerData and PlayerData.Quest
	local QuestName = Quest and Quest.Name
	local QuestData = QuestName and QuestService:GetQuestData(QuestName)

	return not QuestData or QuestData.CanAbandon ~= false
end

function QuestService:GiveQuest(Player: Player, QuestName: string, ...)
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
	Player:SetAttribute("HasQuest", false)
end

function QuestService:AbandonQuest(Player: Player)
	if not QuestService:CanAbandonQuest(Player) then
		AlertService:AlertPlayer(Player, "You cannot abandon this story mission.", "Error")
		return false
	end

	QuestService:CallQuestFunction(Player, "Cancel")
	QuestService:RemoveQuest(Player)
	ObjectiveService:ClearObjectives(Player)
	return true
end
function QuestService.Client:AbandonQuest(Player: Player)
	return self.Server:AbandonQuest(Player)
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
	QuestsData = require(game.ServerStorage.Services.Index.Quests)
end

return QuestService
