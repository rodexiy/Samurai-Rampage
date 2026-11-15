local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage.Packages.Knit)
local PlayerService = Knit.CreateService({
	Name = "PlayerService",
	Client = {},
})

local DataService
local CharacterService
local ItemService
local InventoryService
local GamepassService
local QuestService
local SettingsService
local PartyService
local RaceService
local PlaceService
local SkillTreeService
local MissionBoardService
local PrisonService
local KillStreakService
local WisdomService
local WisdomWorldService
local LoadingService
local TutorialService
local CombatTutorialService
local TriggerService
local StatService

function PlayerService:PlayerAdded(Player: Player)
	if Player:HasTag("Player") then
		return
	end
	Player:AddTag("Player")

	if PlaceService:IsTrading() then
		Player:SetAttribute("CantAttack", true)
	end

	DataService:LoadData(Player)

	repeat
		task.wait()
	until DataService:IsDataLoaded(Player)

	local PlayerData = DataService:GetData(Player)

	StatService:LoadPlayer(Player)
	KillStreakService:LoadPlayer(Player)
	SettingsService:LoadSettings(Player)

	GamepassService:LoadAttributes(Player)
	SkillTreeService:LoadAttributes(Player)
	WisdomService:LoadAttributes(Player)

	self:CheckFirstJoin(Player)

	Player:SetAttribute("Bounty", PlayerData.Bounty)
	Player:SetAttribute("Loaded", true)

	if not LoadingService:WaitForKnitClientLoaded(Player) then
		return
	end

	TriggerService:SendCompletedTriggers(Player)
	TutorialService:CreateTutorialMission(Player)
	CharacterService:LoadCharacter(Player)
end


local function ClearPlayerTools(Player: Player)
	local Backpack = Player:FindFirstChildOfClass("Backpack")
	if Backpack then
		for _, Tool in Backpack:GetChildren() do
			if Tool:IsA("Tool") then
				Tool:Destroy()
			end
		end
	end

	local StarterGear = Player:FindFirstChild("StarterGear")
	if StarterGear then
		for _, Tool in StarterGear:GetChildren() do
			if Tool:IsA("Tool") then
				Tool:Destroy()
			end
		end
	end

	local Character = Player.Character
	if Character then
		for _, Tool in Character:GetChildren() do
			if Tool:IsA("Tool") then
				Tool:Destroy()
			end
		end
	end
end

function PlayerService:CheckFirstJoin(Player: Player)
	local PlayerData = DataService:GetData(Player)
	InventoryService:RemoveUnavailableItems(Player)

	local success, err = pcall(function()
		QuestService:CallQuestFunction(Player, "Cancel")
	end)

	if not success then
		warn(err)
	end
	success, err = pcall(function()
		QuestService:RemoveQuest(Player)
	end)
	if not success then
		warn(err)
	end


	if not PlayerData.EyesColor then
		PlayerData.EyesColor = { math.random(0, 255), math.random(0, 255), math.random(0, 255) }
	end

	if not PlayerData.Race then
		RaceService:RollRandomRace(Player)
	end




	if not InventoryService:GetPlayerItemByName(Player, "Fists") then
		InventoryService:GiveItemToPlayer(Player, ItemService:CreateItem("Fists", 1))
	end

	PlayerData.LoadedFirstTime = true
end

function PlayerService:ResetDataAndRestartTutorial(Player: Player)
	if not DataService:IsDataLoaded(Player) then
		return false, "Data is not loaded."
	end

	pcall(function()
		QuestService:AbandonQuest(Player)
	end)
	pcall(function()
		MissionBoardService:DestroyMission(Player)
	end)
	pcall(function()
		WisdomWorldService:Cleanup(Player, "DataReset")
	end)
	pcall(function()
		PartyService:LeaveParty(Player)
	end)

	local PlayerData = DataService:ResetData(Player)
	if not PlayerData then
		return false, "Data reset failed."
	end

	ClearPlayerTools(Player)
	Player:SetAttribute("MeditateAnywhere", false)

	self:CheckFirstJoin(Player)

	StatService:LoadPlayer(Player)
	KillStreakService:LoadPlayer(Player)
	SettingsService:LoadSettings(Player)
	GamepassService:LoadAttributes(Player)
	SkillTreeService:LoadAttributes(Player)
	WisdomService:LoadAttributes(Player)

	InventoryService:UpdateUI(Player, true)

	Player:SetAttribute("Bounty", PlayerData.Bounty)
	Player:SetAttribute("Loaded", true)

	TriggerService:SendCompletedTriggers(Player)
	TutorialService:CreateTutorialMission(Player)
	CharacterService:LoadCharacter(Player)

	return true
end

function PlayerService:SaveData(Player: Player)
	KillStreakService:ResetIfLeavingPlayerCombat(Player)
	pcall(function()
		CombatTutorialService:HandlePlayerLeaving(Player)
	end)
	pcall(function()
		WisdomWorldService:Cleanup(Player, "PlayerRemoving")
	end)
	pcall(function()
		PrisonService:HandlePlayerLeave(Player)
	end)
	DataService:SaveData(Player)
	pcall(function()
		PartyService:LeaveParty(Player)
	end)
	pcall(function()
		QuestService:AbandonQuest(Player)
	end)
	pcall(function()
		MissionBoardService:DestroyMission(Player)
	end)

	local FaceHead = workspace.FaceHeadFolder:FindFirstChild(Player.Name .. "FaceHead")
	if FaceHead then
		FaceHead:Destroy()
	end
end

function PlayerService.KnitInit()
	DataService = Knit.GetService("DataService")
	CharacterService = Knit.GetService("CharacterService")
	ItemService = Knit.GetService("ItemService")
	InventoryService = Knit.GetService("InventoryService")
	GamepassService = Knit.GetService("GamepassService")
	QuestService = Knit.GetService("QuestService")
	SettingsService = Knit.GetService("SettingsService")
	PartyService = Knit.GetService("PartyService")
	RaceService = Knit.GetService("RaceService")
	PlaceService = Knit.GetService("PlaceService")
	SkillTreeService = Knit.GetService("SkillTreeService")
	MissionBoardService = Knit.GetService("MissionBoardService")
	PrisonService = Knit.GetService("PrisonService")
	KillStreakService = Knit.GetService("KillStreakService")
	WisdomService = Knit.GetService("WisdomService")
	WisdomWorldService = Knit.GetService("WisdomWorldService")
	LoadingService = Knit.GetService("LoadingService")
	TutorialService = Knit.GetService("TutorialService")
	CombatTutorialService = Knit.GetService("CombatTutorialService")
	TriggerService = Knit.GetService("TriggerService")
	StatService = Knit.GetService("StatService")
end

function PlayerService.KnitStart()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			PlayerService:PlayerAdded(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerService:SaveData(player)
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			PlayerService:PlayerAdded(player)
		end)
	end
end

return PlayerService
