local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local TutorialService = Knit.CreateService({
	Name = "TutorialService",
	Client = {},
})

local DataService
local QuestService
local ObjectiveService

local Missions = {}
local MissionsByName = {}

function TutorialService:GetMission(MissionName: string)
	return MissionsByName[MissionName]
end

function TutorialService:GetMissionData(Player: Player, MissionName: string, Create: boolean?)
	local PlayerData = DataService:GetData(Player)
	if not PlayerData then
		return
	end

	PlayerData.Story = PlayerData.Story or {}
	local MissionData = PlayerData.Story[MissionName]
	if Create and typeof(MissionData) ~= "table" then
		MissionData = {}
		PlayerData.Story[MissionName] = MissionData
	end

	return MissionData, PlayerData
end

function TutorialService:IsMissionCompleted(Player: Player, MissionName: string): boolean
	local MissionData = TutorialService:GetMissionData(Player, MissionName)
	return MissionData == true or (typeof(MissionData) == "table" and MissionData.Completed == true)
end

function TutorialService:IsMissionStep(Player: Player, MissionName: string, StepName: string): boolean
	local MissionData, PlayerData = TutorialService:GetMissionData(Player, MissionName)
	if not PlayerData or not PlayerData.Quest or PlayerData.Quest.Name ~= MissionName then
		return false
	end

	if typeof(MissionData) ~= "table" then
		local Mission = TutorialService:GetMission(MissionName)
		return Mission ~= nil and Mission.InitialStep == StepName
	end

	return MissionData.Step == StepName
end

function TutorialService:GetNextMission(Player: Player)
	for _, Mission in Missions do
		if TutorialService:IsMissionCompleted(Player, Mission.Name) then
			continue
		end

		if not Mission.Prerequisite or TutorialService:IsMissionCompleted(Player, Mission.Prerequisite) then
			return Mission
		end

		return nil
	end
end

function TutorialService:GetMissionNPC(Mission)
	local NPCs = workspace:FindFirstChild("NPCs")
	return NPCs and NPCs:FindFirstChild(Mission.NPC)
end

function TutorialService:GetMissionAdornee(Mission)
	local NPC = TutorialService:GetMissionNPC(Mission)
	if not NPC then
		return
	end

	local Adornee = NPC:FindFirstChild("HumanoidRootPart")
	if not Adornee and NPC:IsA("Model") then
		Adornee = NPC.PrimaryPart
	end

	return Adornee or NPC:FindFirstChildWhichIsA("BasePart", true)
end

function TutorialService:GetAvailableTargetName(MissionName: string): string
	return "AvailableStory:" .. MissionName
end

function TutorialService:RemoveMissionMarkers(Player: Player)
	for _, Mission in Missions do
		QuestService:RemoveTarget(Player, TutorialService:GetAvailableTargetName(Mission.Name))
	end
end

function TutorialService:CreateMissionMarker(Player: Player, Mission)
	local Adornee = TutorialService:GetMissionAdornee(Mission)
	if not Adornee then
		return false
	end

	local TargetName = TutorialService:GetAvailableTargetName(Mission.Name)
	QuestService:RemoveTarget(Player, TargetName)
	QuestService:CreateTarget(Player, TargetName, Adornee, {
		CompassMode = "MissionName",
		CompassLabel = Mission.DisplayName,
		WorldLabel = Mission.DisplayName,
		WorldHideDistance = true,
		WorldMaxDistance = Mission.MarkerDistance or 70,
	})

	return true
end

function TutorialService:EnsureMissionPrompt(Mission)
	if not Mission.CreatePrompt then
		return
	end

	local NPC = TutorialService:GetMissionNPC(Mission)
	if not NPC or NPC:FindFirstChildWhichIsA("ProximityPrompt", true) then
		return
	end

	local Prompt = Instance.new("ProximityPrompt")
	Prompt.Name = "StoryDialogPrompt"
	Prompt.ActionText = "Talk"
	Prompt.KeyboardKeyCode = Enum.KeyCode.F
	Prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	Prompt.Style = Enum.ProximityPromptStyle.Custom
	Prompt.HoldDuration = 0
	Prompt.MaxActivationDistance = 7
	Prompt.RequiresLineOfSight = false
	Prompt:SetAttribute("callback", "Dialog")
	Prompt:SetAttribute("NPC", Mission.NPC)
	Prompt.Parent = NPC
end

function TutorialService:CreateTutorialMission(Player: Player)
	local PlayerData = DataService:GetData(Player)
	if not PlayerData then
		return
	end

	TutorialService:RemoveMissionMarkers(Player)

	local ActiveQuestName = PlayerData.Quest and PlayerData.Quest.Name
	local ActiveMission = ActiveQuestName and TutorialService:GetMission(ActiveQuestName)
	if ActiveMission then
		Player:SetAttribute("HasQuest", true)
		QuestService:CallQuestFunction(Player, "Resume")
		return
	elseif ActiveQuestName then
		return
	end

	local Mission = TutorialService:GetNextMission(Player)
	if not Mission then
		return
	end

	local MissionData = TutorialService:GetMissionData(Player, Mission.Name)
	local HasProgress = typeof(MissionData) == "table"
		and MissionData.Step ~= nil
		and MissionData.Step ~= Mission.InitialStep
	if HasProgress then
		QuestService:GiveQuest(Player, Mission.Name)
		return
	end

	TutorialService:CreateMissionMarker(Player, Mission)
end

function TutorialService:CanStartMission(Player: Player, MissionName: string): boolean
	local Mission = TutorialService:GetNextMission(Player)
	if not Mission or Mission.Name ~= MissionName then
		return false
	end

	local MissionData, PlayerData = TutorialService:GetMissionData(Player, MissionName)
	if not PlayerData or (PlayerData.Quest and PlayerData.Quest.Name) then
		return false
	end

	return typeof(MissionData) ~= "table"
		or MissionData.Step == nil
		or MissionData.Step == Mission.InitialStep
end

function TutorialService:StartMission(Player: Player, MissionName: string): boolean
	if not TutorialService:CanStartMission(Player, MissionName) then
		return false
	end

	TutorialService:RemoveMissionMarkers(Player)
	return QuestService:GiveQuest(Player, MissionName)
end

function TutorialService:CompleteMission(Player: Player, MissionName: string): boolean
	local MissionData = TutorialService:GetMissionData(Player, MissionName, true)
	if not MissionData then
		return false
	end

	MissionData.Step = "Completed"
	MissionData.Completed = true
	QuestService:RemoveTarget(Player, TutorialService:GetAvailableTargetName(MissionName))
	QuestService:RemoveQuest(Player)
	TutorialService:CreateTutorialMission(Player)
	return true
end

function TutorialService:SetStoryProgression(Player: Player, MissionName: string)
	local TargetMission = TutorialService:GetMission(MissionName)
	if not TargetMission then
		local MissionNames = {}
		for _, Mission in Missions do
			table.insert(MissionNames, Mission.Name)
		end
		return false, "Unknown story mission. Available missions: " .. table.concat(MissionNames, ", ")
	end

	local PlayerData = DataService:GetData(Player)
	if not PlayerData then
		return false, "Player data is not loaded."
	end

	if PlayerData.Quest and PlayerData.Quest.Name then
		QuestService:CallQuestFunction(Player, "Cancel")
		QuestService:RemoveQuest(Player)
	end

	ObjectiveService:ClearObjectives(Player)
	TutorialService:RemoveMissionMarkers(Player)
	PlayerData.Story = PlayerData.Story or {}

	local ReachedTarget = false
	for _, Mission in Missions do
		if ReachedTarget then
			PlayerData.Story[Mission.Name] = nil
			continue
		end

		local MissionData = PlayerData.Story[Mission.Name]
		if typeof(MissionData) ~= "table" then
			MissionData = {}
			PlayerData.Story[Mission.Name] = MissionData
		end

		MissionData.Step = "Completed"
		MissionData.Completed = true
		ReachedTarget = Mission.Name == MissionName
	end

	TutorialService:CreateTutorialMission(Player)
	local NextMission = TutorialService:GetNextMission(Player)
	return true, NextMission and NextMission.Name
end

function TutorialService:HasCompletedTutorial(Player: Player): boolean
	for _, Mission in Missions do
		if not TutorialService:IsMissionCompleted(Player, Mission.Name) then
			return false
		end
	end

	return true
end

function TutorialService.KnitInit()
	DataService = Knit.GetService("DataService")
	QuestService = Knit.GetService("QuestService")
	ObjectiveService = Knit.GetService("ObjectiveService")

	Missions = require(game.ServerStorage.Services.Index.StoryMissions)
	for _, Mission in Missions do
		MissionsByName[Mission.Name] = Mission
	end
end

function TutorialService.KnitStart()
	for _, Mission in Missions do
		TutorialService:EnsureMissionPrompt(Mission)
	end
end

return TutorialService
