local Knit = require(game.ReplicatedStorage.Packages.Knit)

local ObjectiveService = Knit.GetService("ObjectiveService")
local QuestService = Knit.GetService("QuestService")
local TutorialService = Knit.GetService("TutorialService")
local LevelService = Knit.GetService("LevelService")
local CombatTutorialService = Knit.GetService("CombatTutorialService")

local LearnTheBasics = {}

LearnTheBasics.Name = "LearnTheBasics"
LearnTheBasics.DisplayName = "BASIC TRAINING"
LearnTheBasics.TargetName = "Mikoto"
LearnTheBasics.StepTalk = "TalkWithMikoto"
LearnTheBasics.StepPractice = "PracticeBasics"
LearnTheBasics.StepReturn = "ReturnToMikoto"

function LearnTheBasics:GetData(Player: Player)
	local MissionData = TutorialService:GetMissionData(Player, LearnTheBasics.Name, true)
	if not MissionData then
		return
	end

	MissionData.Step = MissionData.Step or LearnTheBasics.StepTalk
	return MissionData
end

function LearnTheBasics:ClearTargets(Player: Player)
	QuestService:RemoveTarget(Player, LearnTheBasics.TargetName)
end

function LearnTheBasics:SetMikotoTarget(Player: Player)
	LearnTheBasics:ClearTargets(Player)

	local Mission = TutorialService:GetMission(LearnTheBasics.Name)
	local Adornee = Mission and TutorialService:GetMissionAdornee(Mission)
	if Adornee then
		QuestService:CreateTarget(Player, LearnTheBasics.TargetName, Adornee)
	end

	local _, PlayerData = TutorialService:GetMissionData(Player, LearnTheBasics.Name)
	if PlayerData and PlayerData.Quest then
		PlayerData.Quest.TargetName = LearnTheBasics.TargetName
	end
end

function LearnTheBasics:ShowTalkObjective(Player: Player, ObjectiveText: string)
	ObjectiveService:AddObjective(Player, LearnTheBasics.Name, {
		{ Name = ObjectiveText, TargetAmount = 1, CurrentAmount = 0 },
	}, LearnTheBasics.DisplayName, false)
	LearnTheBasics:SetMikotoTarget(Player)
end

function LearnTheBasics:ShowTalkMarker(Player: Player)
	ObjectiveService:ClearObjective(Player, LearnTheBasics.Name)
	LearnTheBasics:SetMikotoTarget(Player)
end

function LearnTheBasics:ClearTrainingProgress(MissionData)
	MissionData.CombatTutorialPhase = nil
	MissionData.CombatTutorialProgress = nil
end

function LearnTheBasics:ResetAsNeverStarted(Player: Player)
	local _, PlayerData = TutorialService:GetMissionData(Player, LearnTheBasics.Name)
	if not PlayerData then
		return false
	end

	PlayerData.Story = PlayerData.Story or {}
	PlayerData.Story[LearnTheBasics.Name] = nil

	if PlayerData.Quest and PlayerData.Quest.Name == LearnTheBasics.Name then
		QuestService:RemoveQuest(Player)
	end

	LearnTheBasics:ClearTargets(Player)
	CombatTutorialService:EndTraining(Player, true)
	ObjectiveService:ClearObjective(Player, LearnTheBasics.Name)
	TutorialService:CreateTutorialMission(Player)

	return true
end

function LearnTheBasics:FinishPractice(Player: Player)
	local MissionData = LearnTheBasics:GetData(Player)
	if not MissionData or MissionData.Step ~= LearnTheBasics.StepPractice then
		return false
	end

	MissionData.Step = LearnTheBasics.StepReturn
	LearnTheBasics:ClearTrainingProgress(MissionData)
	CombatTutorialService:EndTraining(Player, true)
	LearnTheBasics:ShowTalkObjective(Player, "Return to Mikoto")
	return true
end

function LearnTheBasics:StartTraining(Player: Player)
	local MissionData = LearnTheBasics:GetData(Player)
	if not MissionData or MissionData.Step ~= LearnTheBasics.StepTalk then
		return false
	end

	MissionData.Step = LearnTheBasics.StepPractice
	MissionData.CombatTutorialPhase = 1
	MissionData.CombatTutorialProgress = 0
	LearnTheBasics:ClearTargets(Player)

	if CombatTutorialService:StartTraining(Player, true) then
		return true
	end

	MissionData.Step = LearnTheBasics.StepTalk
	LearnTheBasics:ClearTrainingProgress(MissionData)
	LearnTheBasics:ShowTalkMarker(Player)
	return false
end

function LearnTheBasics:Resume(Player: Player)
	local MissionData = LearnTheBasics:GetData(Player)
	if not MissionData or MissionData.Completed then
		return false
	end

	if MissionData.Step == LearnTheBasics.StepPractice then
		LearnTheBasics:ResetAsNeverStarted(Player)
		return false
	elseif MissionData.Step == LearnTheBasics.StepReturn then
		LearnTheBasics:ShowTalkObjective(Player, "Return to Mikoto")
	else
		MissionData.Step = LearnTheBasics.StepTalk
		LearnTheBasics:ShowTalkMarker(Player)
	end

	return true
end

function LearnTheBasics:CompleteQuest(Player: Player)
	local MissionData = LearnTheBasics:GetData(Player)
	if not MissionData or MissionData.Step ~= LearnTheBasics.StepReturn then
		return false
	end

	LearnTheBasics:ClearTargets(Player)
	CombatTutorialService:EndTraining(Player, false)
	ObjectiveService:ClearObjective(Player, LearnTheBasics.Name, true)
	LevelService:GiveExp(Player, 100)
	TutorialService:CompleteMission(Player, LearnTheBasics.Name)
	return true
end

return {
	Name = LearnTheBasics.Name,
	QuestType = "Story",
	Requirements = {},
	Persistent = true,
	CanAbandon = false,

	OnStart = function(Player: Player)
		return LearnTheBasics:Resume(Player)
	end,

	Resume = function(Player: Player)
		return LearnTheBasics:Resume(Player)
	end,

	StartTraining = function(Player: Player)
		return LearnTheBasics:StartTraining(Player)
	end,

	FinishPractice = function(Player: Player)
		return LearnTheBasics:FinishPractice(Player)
	end,

	CompleteQuest = function(Player: Player)
		return LearnTheBasics:CompleteQuest(Player)
	end,

	Cancel = function(Player: Player)
		LearnTheBasics:ClearTargets(Player)
		CombatTutorialService:EndTraining(Player, true)
		ObjectiveService:ClearObjective(Player, LearnTheBasics.Name)
		return true
	end,
}
