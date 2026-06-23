local Knit = require(game.ReplicatedStorage.Packages.Knit)

local ObjectiveService = Knit.GetService("ObjectiveService")
local QuestService = Knit.GetService("QuestService")
local TutorialService = Knit.GetService("TutorialService")
local LevelService = Knit.GetService("LevelService")

local LearnTheBasics = {}

LearnTheBasics.Name = "LearnTheBasics"
LearnTheBasics.DisplayName = "BASIC TRAINING"
LearnTheBasics.TargetName = "Talk with Mikoto"
LearnTheBasics.StepTalk = "TalkWithMikoto"
LearnTheBasics.StepPractice = "PracticeBasics"
LearnTheBasics.StepReturn = "ReturnToMikoto"

LearnTheBasics.RequiredAttacks = 3
LearnTheBasics.RequiredBlocks = 1
LearnTheBasics.RequiredRolls = 1

function LearnTheBasics:GetData(Player: Player)
	local MissionData = TutorialService:GetMissionData(Player, LearnTheBasics.Name, true)
	if not MissionData then
		return
	end

	MissionData.Step = MissionData.Step or LearnTheBasics.StepTalk
	MissionData.Attacks = MissionData.Attacks or 0
	MissionData.Blocks = MissionData.Blocks or 0
	MissionData.Rolls = MissionData.Rolls or 0
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

function LearnTheBasics:ShowPracticeObjective(Player: Player, MissionData)
	ObjectiveService:AddObjective(Player, LearnTheBasics.Name, {
		{
			Name = "Practice basic attacks",
			TargetAmount = LearnTheBasics.RequiredAttacks,
			CurrentAmount = MissionData.Attacks,
		},
		{
			Name = "Practice blocking",
			TargetAmount = LearnTheBasics.RequiredBlocks,
			CurrentAmount = MissionData.Blocks,
		},
		{
			Name = "Practice dodging",
			TargetAmount = LearnTheBasics.RequiredRolls,
			CurrentAmount = MissionData.Rolls,
		},
	}, LearnTheBasics.DisplayName, false)
	LearnTheBasics:ClearTargets(Player)
end

function LearnTheBasics:HasFinishedPractice(MissionData): boolean
	return MissionData.Attacks >= LearnTheBasics.RequiredAttacks
		and MissionData.Blocks >= LearnTheBasics.RequiredBlocks
		and MissionData.Rolls >= LearnTheBasics.RequiredRolls
end

function LearnTheBasics:FinishPractice(Player: Player)
	local MissionData = LearnTheBasics:GetData(Player)
	if not MissionData or MissionData.Step ~= LearnTheBasics.StepPractice then
		return false
	end

	MissionData.Step = LearnTheBasics.StepReturn
	LearnTheBasics:ShowTalkObjective(Player, "Return to Mikoto")
	return true
end

function LearnTheBasics:StartTraining(Player: Player)
	local MissionData = LearnTheBasics:GetData(Player)
	if not MissionData or MissionData.Step ~= LearnTheBasics.StepTalk then
		return false
	end

	MissionData.Step = LearnTheBasics.StepPractice
	LearnTheBasics:ShowPracticeObjective(Player, MissionData)
	return true
end

function LearnTheBasics:CombatAction(Player: Player, Action: string)
	local MissionData = LearnTheBasics:GetData(Player)
	if not MissionData or MissionData.Step ~= LearnTheBasics.StepPractice then
		return false
	end

	if Action == "Attack" and MissionData.Attacks < LearnTheBasics.RequiredAttacks then
		MissionData.Attacks += 1
		ObjectiveService:UpdateProgress(Player, LearnTheBasics.Name, 1, 1)
	elseif Action == "Block" and MissionData.Blocks < LearnTheBasics.RequiredBlocks then
		MissionData.Blocks += 1
		ObjectiveService:UpdateProgress(Player, LearnTheBasics.Name, 2, 1)
	elseif Action == "Roll" and MissionData.Rolls < LearnTheBasics.RequiredRolls then
		MissionData.Rolls += 1
		ObjectiveService:UpdateProgress(Player, LearnTheBasics.Name, 3, 1)
	else
		return false
	end

	if LearnTheBasics:HasFinishedPractice(MissionData) then
		LearnTheBasics:FinishPractice(Player)
	end

	return true
end

function LearnTheBasics:Resume(Player: Player)
	local MissionData = LearnTheBasics:GetData(Player)
	if not MissionData or MissionData.Completed then
		return false
	end

	if MissionData.Step == LearnTheBasics.StepPractice then
		if LearnTheBasics:HasFinishedPractice(MissionData) then
			return LearnTheBasics:FinishPractice(Player)
		end
		LearnTheBasics:ShowPracticeObjective(Player, MissionData)
	elseif MissionData.Step == LearnTheBasics.StepReturn then
		LearnTheBasics:ShowTalkObjective(Player, "Return to Mikoto")
	else
		MissionData.Step = LearnTheBasics.StepTalk
		LearnTheBasics:ShowTalkObjective(Player, "Talk with Mikoto")
	end

	return true
end

function LearnTheBasics:CompleteQuest(Player: Player)
	local MissionData = LearnTheBasics:GetData(Player)
	if not MissionData or MissionData.Step ~= LearnTheBasics.StepReturn then
		return false
	end

	LearnTheBasics:ClearTargets(Player)
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

	CombatAction = function(Player: Player, Action: string)
		return LearnTheBasics:CombatAction(Player, Action)
	end,

	CompleteQuest = function(Player: Player)
		return LearnTheBasics:CompleteQuest(Player)
	end,

	Cancel = function(Player: Player)
		LearnTheBasics:ClearTargets(Player)
		ObjectiveService:ClearObjective(Player, LearnTheBasics.Name)
		return true
	end,
}
