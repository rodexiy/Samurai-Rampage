local Knit = require(game.ReplicatedStorage.Packages.Knit)

local DataService = Knit.GetService("DataService")
local QuestService = Knit.GetService("QuestService")
local ObjectiveService = Knit.GetService("ObjectiveService")
local TetsuService = Knit.GetService("TetsuService")
local LevelService = Knit.GetService("LevelService")
local AlertService = Knit.GetService("AlertService")
local SideQuestService = Knit.GetService("SideQuestService")

local QUEST_NAME = "HanabiBandage"
local OBJECTIVE_NAME = "QuestHanabiBandage"
local TARGET_HEALING_HERBS = "HanabiHealingHerbs"

local HANABI_NPC_NAME = "Hanabi"
local HERB_ITEM_NAME = "HealingHerbs"
local BANDAGE_ITEM_NAME = "Bandage"
local HERBS_REQUIRED = 6
local BANDAGES_REQUIRED = 3
local GATHER_RADIUS = 100

local function GetHanabi(): Model?
	local NPCs = workspace:FindFirstChild("NPCs")
	local Hanabi = NPCs and NPCs:FindFirstChild(HANABI_NPC_NAME)
	if Hanabi and Hanabi:IsA("Model") then
		return Hanabi
	end
	return nil
end

local function GetHanabiPosition(): Vector3?
	local Hanabi = GetHanabi()
	return if Hanabi then Hanabi:GetPivot().Position else nil
end

local function GetInstancePosition(InstanceToCheck: Instance): Vector3?
	if InstanceToCheck:IsA("Model") then
		return InstanceToCheck:GetPivot().Position
	elseif InstanceToCheck:IsA("BasePart") then
		return InstanceToCheck.Position
	end

	local Model = InstanceToCheck:FindFirstAncestorWhichIsA("Model")
	if Model then
		return Model:GetPivot().Position
	end

	local Part = InstanceToCheck:FindFirstAncestorWhichIsA("BasePart")
	return if Part then Part.Position else nil
end

local function IsNearHanabi(InstanceToCheck: Instance): boolean
	local HanabiPosition = GetHanabiPosition()
	local InstancePosition = GetInstancePosition(InstanceToCheck)
	if not HanabiPosition or not InstancePosition then
		return false
	end

	return (InstancePosition - HanabiPosition).Magnitude <= GATHER_RADIUS
end

local function GetTargetAdornee(InstanceToCheck: Instance): BasePart?
	if InstanceToCheck:IsA("BasePart") then
		return InstanceToCheck
	elseif InstanceToCheck:IsA("Model") then
		return InstanceToCheck.PrimaryPart or InstanceToCheck:FindFirstChildWhichIsA("BasePart", true)
	end

	return InstanceToCheck:FindFirstAncestorWhichIsA("BasePart")
end

local function GetNearbyHealingHerbs(): { Model }
	local Pickables = workspace:FindFirstChild("Pickable")
	if not Pickables then
		return {}
	end

	local Herbs = {}
	for _, Pickable in Pickables:GetChildren() do
		if Pickable.Name == HERB_ITEM_NAME and Pickable:IsA("Model") and IsNearHanabi(Pickable) then
			table.insert(Herbs, Pickable)
		end
	end

	local HanabiPosition = GetHanabiPosition()
	if HanabiPosition then
		table.sort(Herbs, function(First, Second)
			return (First:GetPivot().Position - HanabiPosition).Magnitude
				< (Second:GetPivot().Position - HanabiPosition).Magnitude
		end)
	end

	return Herbs
end

local function GetQuest(Player: Player)
	local PlayerData = DataService:GetData(Player)
	return PlayerData and PlayerData.Quest
end

local function RefreshObjective(Player: Player)
	local Quest = GetQuest(Player)
	if not Quest then
		return
	end

	ObjectiveService:AddObjective(
		Player,
		OBJECTIVE_NAME,
		{
			{
				Name = "Gather Healing Herbs near Hanabi",
				TargetAmount = HERBS_REQUIRED,
				CurrentAmount = math.clamp(Quest.HerbsGathered or 0, 0, HERBS_REQUIRED),
			},
			{
				Name = "Craft Bandages",
				TargetAmount = BANDAGES_REQUIRED,
				CurrentAmount = math.clamp(Quest.BandagesCrafted or 0, 0, BANDAGES_REQUIRED),
			},
		},
		"Hanabi's Remedy",
		true
	)
end

local function RemoveHerbAreaTarget(Player: Player)
	local Quest = GetQuest(Player)
	if Quest and Quest.TargetName == TARGET_HEALING_HERBS then
		Quest.TargetName = nil
	end

	QuestService:RemoveTarget(Player, TARGET_HEALING_HERBS)
end

local function CreateHerbAreaTarget(Player: Player)
	RemoveHerbAreaTarget(Player)

	local Quest = GetQuest(Player)
	if not Quest or (Quest.HerbsGathered or 0) >= HERBS_REQUIRED then
		return
	end

	Quest.TargetName = TARGET_HEALING_HERBS

	for _, Herb in GetNearbyHealingHerbs() do
		local Adornee = GetTargetAdornee(Herb)
		if not Adornee then
			continue
		end

		QuestService:CreateTarget(Player, TARGET_HEALING_HERBS, Adornee, {
			CompassMode = "MissionName",
			CompassLabel = "Healing Herbs",
			WorldLabel = "Healing Herbs",
			WorldMaxDistance = GATHER_RADIUS,
			WorldStudsOffset = Vector3.new(0, 1.5, 0),
		})
	end
end

return {
	Name = QUEST_NAME,
	QuestType = "Side",

	OnStart = function(Player: Player)
		if not SideQuestService:IsQuestUnlocked(Player, QUEST_NAME) then
			AlertService:AlertPlayer(Player, "Complete combat training before helping Hanabi.", "Warn")
			return false
		end

		if SideQuestService:IsQuestCompleted(Player, QUEST_NAME) then
			return false
		end

		if not GetHanabi() then
			AlertService:AlertPlayer(Player, "Hanabi is not available right now.", "Error")
			return false
		end

		local Quest = GetQuest(Player)
		if not Quest then
			return false
		end

		Quest.HerbsGathered = 0
		Quest.BandagesCrafted = 0
		Quest.BandageCrafted = nil

		SideQuestService:RemovePlayerMarker(Player, QUEST_NAME)
		CreateHerbAreaTarget(Player)
		RefreshObjective(Player)

		return true
	end,

	PickItem = function(Player: Player, ItemName: string, Amount: number, Pickable: Instance)
		if ItemName ~= HERB_ITEM_NAME or not IsNearHanabi(Pickable) then
			return
		end

		local Quest = GetQuest(Player)
		if not Quest or (Quest.HerbsGathered or 0) >= HERBS_REQUIRED then
			return
		end

		local AmountToAdd = math.min(Amount, HERBS_REQUIRED - (Quest.HerbsGathered or 0))
		Quest.HerbsGathered = (Quest.HerbsGathered or 0) + AmountToAdd
		ObjectiveService:UpdateProgress(Player, OBJECTIVE_NAME, 1, AmountToAdd)

		if Quest.HerbsGathered >= HERBS_REQUIRED then
			RemoveHerbAreaTarget(Player)
			AlertService:AlertPlayer(Player, "Craft " .. BANDAGES_REQUIRED .. " Bandages for Hanabi.", "Success")
		else
			CreateHerbAreaTarget(Player)
		end
	end,

	CraftItem = function(Player: Player, ItemName: string, CraftedAmount: number)
		if ItemName ~= BANDAGE_ITEM_NAME or CraftedAmount <= 0 then
			return
		end

		local Quest = GetQuest(Player)
		if not Quest or (Quest.BandagesCrafted or 0) >= BANDAGES_REQUIRED then
			return
		end

		if (Quest.HerbsGathered or 0) < HERBS_REQUIRED then
			AlertService:AlertPlayer(Player, "Gather Healing Herbs near Hanabi before crafting the Bandages.", "Warn")
			return
		end

		local AmountToAdd = math.min(CraftedAmount, BANDAGES_REQUIRED - (Quest.BandagesCrafted or 0))
		Quest.BandagesCrafted = (Quest.BandagesCrafted or 0) + AmountToAdd
		ObjectiveService:UpdateProgress(Player, OBJECTIVE_NAME, 2, AmountToAdd)

		if Quest.BandagesCrafted >= BANDAGES_REQUIRED then
			QuestService:CallQuestFunction(Player, "CompleteQuest")
		end
	end,

	CompleteQuest = function(Player: Player)
		RemoveHerbAreaTarget(Player)
		SideQuestService:MarkQuestCompleted(Player, QUEST_NAME)

		TetsuService:AddTetsu(Player, 50)
		LevelService:GiveExp(Player, 150)

		ObjectiveService:ClearObjectives(Player, true)
		QuestService:RemoveQuest(Player)
		SideQuestService:RefreshPlayerMarkers(Player)
	end,

	Cancel = function(Player: Player)
		RemoveHerbAreaTarget(Player)
		ObjectiveService:ClearObjective(Player, OBJECTIVE_NAME)
	end,
}
