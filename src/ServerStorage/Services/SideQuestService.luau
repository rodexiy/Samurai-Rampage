local Players = game:GetService("Players")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local SideQuestService = Knit.CreateService({
	Name = "SideQuestService",
	Client = {},
})

local SIDE_QUEST_ICON = "rbxassetid://403653614"
local COMBAT_TUTORIAL_MISSION = "LearnTheBasics"

local SideQuests = {
	HanabiBandage = {
		QuestName = "HanabiBandage",
		DisplayName = "Hanabi's Remedy",
		NPC = "Hanabi",
		CompletedFlag = "HanabiBandageCompleted",
		MarkerDistance = 70,
		CompassDistance = 300,
		PromptName = "HanabiSideQuestPrompt",
	},
}

local DataService
local LoadingService
local QuestService
local TutorialService

local PlayerConnections = {}

local function GetMarkerName(QuestName: string): string
	return "AvailableSideQuest:" .. QuestName
end

local function GetNPC(NPCName: string): Model?
	local NPCs = workspace:FindFirstChild("NPCs")
	local NPC = NPCs and NPCs:FindFirstChild(NPCName)
	if NPC and NPC:IsA("Model") then
		return NPC
	end
	return nil
end

local function GetNPCAdornee(NPCName: string): Instance?
	local NPC = GetNPC(NPCName)
	if not NPC then
		return nil
	end

	return NPC:FindFirstChild("Head")
		or NPC:FindFirstChild("HumanoidRootPart")
		or NPC.PrimaryPart
		or NPC:FindFirstChildWhichIsA("BasePart", true)
end

local function GetPromptParent(NPCName: string): Instance?
	local NPC = GetNPC(NPCName)
	if not NPC then
		return nil
	end

	return NPC:FindFirstChild("HumanoidRootPart") or NPC.PrimaryPart or NPC:FindFirstChildWhichIsA("BasePart", true)
end

local function GetPlayerData(Player: Player)
	return if DataService and DataService:IsDataLoaded(Player) then DataService:GetData(Player) else nil
end

function SideQuestService:IsQuestCompleted(Player: Player, QuestName: string): boolean
	local Quest = SideQuests[QuestName]
	local PlayerData = Quest and GetPlayerData(Player)
	if not Quest or not PlayerData then
		return false
	end

	PlayerData.NPCs = PlayerData.NPCs or {}
	return PlayerData.NPCs[Quest.CompletedFlag] == true
end

function SideQuestService:MarkQuestCompleted(Player: Player, QuestName: string)
	local Quest = SideQuests[QuestName]
	local PlayerData = Quest and GetPlayerData(Player)
	if not Quest or not PlayerData then
		return
	end

	PlayerData.NPCs = PlayerData.NPCs or {}
	PlayerData.NPCs[Quest.CompletedFlag] = true
end

function SideQuestService:IsQuestUnlocked(Player: Player, QuestName: string): boolean
	if not SideQuests[QuestName] then
		return false
	end

	return TutorialService:IsMissionCompleted(Player, COMBAT_TUTORIAL_MISSION)
end

function SideQuestService:CanShowQuestMarker(Player: Player, QuestName: string): boolean
	local PlayerData = GetPlayerData(Player)
	if
		not PlayerData
		or not self:IsQuestUnlocked(Player, QuestName)
		or self:IsQuestCompleted(Player, QuestName)
	then
		return false
	end

	local ActiveQuestName = PlayerData.Quest and PlayerData.Quest.Name
	return ActiveQuestName == nil
end

function SideQuestService:CanOfferQuest(Player: Player, QuestName: string): boolean
	local PlayerData = GetPlayerData(Player)
	if
		not PlayerData
		or not self:IsQuestUnlocked(Player, QuestName)
		or self:IsQuestCompleted(Player, QuestName)
	then
		return false
	end

	local ActiveQuestName = PlayerData.Quest and PlayerData.Quest.Name
	return ActiveQuestName == nil
end

function SideQuestService:RemovePlayerMarker(Player: Player, QuestName: string)
	QuestService:RemoveTarget(Player, GetMarkerName(QuestName))
end

function SideQuestService:RefreshPlayerMarkers(Player: Player)
	if not Player.Parent or not DataService:IsDataLoaded(Player) or not Player:GetAttribute("KnitClientLoaded") then
		return
	end

	for QuestName, Quest in SideQuests do
		self:RemovePlayerMarker(Player, QuestName)

		if not self:CanShowQuestMarker(Player, QuestName) then
			continue
		end

		local Adornee = GetNPCAdornee(Quest.NPC)
		if not Adornee then
			continue
		end

		QuestService:CreateTarget(Player, GetMarkerName(QuestName), Adornee, {
			CompassMode = "MissionName",
			CompassLabel = Quest.DisplayName,
			CompassIconImage = SIDE_QUEST_ICON,
			CompassMaxDistance = Quest.CompassDistance,
			WorldIconImage = SIDE_QUEST_ICON,
			WorldIconColor = Color3.new(1, 1, 1),
			WorldIconOnly = true,
			WorldHideDistance = true,
			WorldMaxDistance = Quest.MarkerDistance,
			WorldStudsOffset = Vector3.new(0, 2.6, 0),
		})
	end
end

function SideQuestService:EnsureQuestPrompt(Quest)
	local NPC = GetNPC(Quest.NPC)
	if not NPC then
		return
	end

	for _, Descendant in NPC:GetDescendants() do
		if Descendant:IsA("ProximityPrompt") and Descendant:GetAttribute("NPC") == Quest.NPC then
			return
		end
	end

	local Parent = GetPromptParent(Quest.NPC)
	if not Parent then
		return
	end

	local Prompt = Instance.new("ProximityPrompt")
	Prompt.Name = Quest.PromptName
	Prompt.ActionText = "Talk"
	Prompt.KeyboardKeyCode = Enum.KeyCode.F
	Prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	Prompt.Style = Enum.ProximityPromptStyle.Custom
	Prompt.HoldDuration = 0
	Prompt.MaxActivationDistance = 7
	Prompt.RequiresLineOfSight = false
	Prompt:SetAttribute("callback", "Dialog")
	Prompt:SetAttribute("NPC", Quest.NPC)
	Prompt.Parent = Parent
end

function SideQuestService:TrackPlayer(Player: Player)
	if PlayerConnections[Player] then
		return
	end

	PlayerConnections[Player] = Player:GetAttributeChangedSignal("HasQuest"):Connect(function()
		SideQuestService:RefreshPlayerMarkers(Player)
	end)

	task.spawn(function()
		repeat
			task.wait()
		until not Player.Parent or DataService:IsDataLoaded(Player)

		if not Player.Parent or not LoadingService:WaitForKnitClientLoaded(Player) then
			return
		end

		SideQuestService:RefreshPlayerMarkers(Player)
	end)
end

function SideQuestService.KnitInit()
	DataService = Knit.GetService("DataService")
	LoadingService = Knit.GetService("LoadingService")
	QuestService = Knit.GetService("QuestService")
	TutorialService = Knit.GetService("TutorialService")
end

function SideQuestService.KnitStart()
	for _, Quest in SideQuests do
		SideQuestService:EnsureQuestPrompt(Quest)
	end

	Players.PlayerAdded:Connect(function(Player)
		SideQuestService:TrackPlayer(Player)
	end)

	Players.PlayerRemoving:Connect(function(Player)
		if PlayerConnections[Player] then
			PlayerConnections[Player]:Disconnect()
			PlayerConnections[Player] = nil
		end
	end)

	for _, Player in Players:GetPlayers() do
		SideQuestService:TrackPlayer(Player)
	end
end

return SideQuestService
