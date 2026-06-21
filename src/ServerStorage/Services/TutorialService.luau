local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local TutorialService = Knit.CreateService({
    Name = "TutorialService",
    Client = {},
})

local DataService
local InventoryService
local QuestService

local function HasCompletedStoryQuest(StoryData): boolean
	return StoryData == true or (typeof(StoryData) == "table" and StoryData.Completed == true)
end

function TutorialService:CreateTutorialMission(Player: Player)
	local PlayerData = DataService:GetData(Player)
	if not PlayerData then
		return
	end

	PlayerData.Story = PlayerData.Story or {}

	local TalkWithBlacksmithData = PlayerData.Story.TalkWithBlacksmith
	if HasCompletedStoryQuest(TalkWithBlacksmithData) then
		return
	end

	if PlayerData.Quest and PlayerData.Quest.Name == "TalkWithBlacksmith" then
		Player:SetAttribute("HasQuest", true)
		QuestService:CallQuestFunction(Player, "Resume")
		return
	end

	if PlayerData.Quest and PlayerData.Quest.Name then
		return
	end

	QuestService:GiveQuest(Player, "TalkWithBlacksmith")
end

function TutorialService:HasCompletedTutorial(Player: Player)
	local PlayerData = DataService:GetData(Player)

	if PlayerData.SelectedStance and InventoryService:GetPlayerItemByName(Player, "BasicKatana") then
		return true
	end

	return false
end

function TutorialService.KnitInit()
	DataService = Knit.GetService("DataService")
	InventoryService = Knit.GetService("InventoryService")
	QuestService = Knit.GetService("QuestService")
end

return TutorialService
