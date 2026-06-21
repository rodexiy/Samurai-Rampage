local Knit = require(game.ReplicatedStorage.Packages.Knit)

local DataService = Knit.GetService("DataService")
local TetsuService = Knit.GetService("TetsuService")
local LevelService = Knit.GetService("LevelService")
local ObjectiveService = Knit.GetService("ObjectiveService")
local QuestService = Knit.GetService("QuestService")
local InventoryService = Knit.GetService("InventoryService")
local ItemService = Knit.GetService("ItemService")
local AlertService = Knit.GetService("AlertService")
local StanceService = Knit.GetService("StanceService")

local OBJECTIVE_NAME = "TalkWithBlacksmith"

local STEP_TALK_GODOT = "TalkWithBlacksmith"
local STEP_MINE_RESOURCES = "MineResources"
local STEP_TALK_LUMBERJACK = "TalkWithLumberjack"
local STEP_CHOP_WOOD = "ChopWood"
local STEP_RETURN_TO_GODOT = "ReturnToGodot"
local STEP_CRAFT_KATANA = "CraftKatana"
local STEP_TALK_GODOT_AFTER_KATANA = "TalkWithGodotAfterKatana"
local STEP_COMPLETED = "Completed"

local TARGET_GODOT = "Talk with Godot"
local TARGET_TUTORIAL_ORES = "Tutorial Ores"
local TARGET_TUTORIAL_IRON_ORE = "Iron Ore"
local TARGET_TUTORIAL_COAL = "Coal"
local TARGET_LUMBERJACK = "Talk with Vasco"
local TARGET_WOOD = "Wood"
local TARGET_GODOT_FORGE = "Godot Forge"

local MissionDisplayName = "MAKING A KATANA"

local IRON_REQUIRED = 10
local COAL_REQUIRED = 10
local WOOD_REQUIRED = 5
local KATANA_NAME = "BasicKatana"
local BEGINNER_STANCE = "Beginner"
local MIN_LEVEL_AFTER_KATANA = 2

local function GetTargetPosition(Target: Instance?): Vector3?
	if not Target then
		return nil
	end

	if Target:IsA("BasePart") then
		return Target.Position
	end

	if Target:IsA("Model") then
		return Target:GetPivot().Position
	end

	local BasePart = Target:FindFirstChildWhichIsA("BasePart", true)
	if BasePart then
		return BasePart.Position
	end

	local Model = Target:FindFirstChildWhichIsA("Model", true)
	if Model then
		return Model:GetPivot().Position
	end

	return nil
end

local function GetStoryData(Player: Player)
	local PlayerData = DataService:GetData(Player)
	if not PlayerData then
		return nil, nil
	end

	PlayerData.Story = PlayerData.Story or {}

	local StoryData = PlayerData.Story.TalkWithBlacksmith
	if typeof(StoryData) ~= "table" then
		StoryData = {}
		PlayerData.Story.TalkWithBlacksmith = StoryData
	end

	StoryData.Step = StoryData.Step or STEP_TALK_GODOT
	StoryData.IronOre = StoryData.IronOre or 0
	StoryData.Coal = StoryData.Coal or 0
	StoryData.WoodLog = StoryData.WoodLog or 0

	return PlayerData, StoryData
end

local function GetInventoryAmount(Player: Player, ItemName: string): number
	local Item = InventoryService:GetPlayerItemByName(Player, ItemName)
	return if Item then Item.Stack or 0 else 0
end

local function SyncMiningProgress(Player: Player, StoryData)
	StoryData.IronOre = math.max(
		math.clamp(StoryData.IronOre or 0, 0, IRON_REQUIRED),
		math.clamp(GetInventoryAmount(Player, "IronOre"), 0, IRON_REQUIRED)
	)
	StoryData.Coal = math.max(
		math.clamp(StoryData.Coal or 0, 0, COAL_REQUIRED),
		math.clamp(GetInventoryAmount(Player, "Coal"), 0, COAL_REQUIRED)
	)
end

local function SyncWoodProgress(Player: Player, StoryData)
	StoryData.WoodLog = math.max(
		math.clamp(StoryData.WoodLog or 0, 0, WOOD_REQUIRED),
		math.clamp(GetInventoryAmount(Player, "WoodLog"), 0, WOOD_REQUIRED)
	)
end

local function ClearTargets(Player: Player)
	QuestService:RemoveTarget(Player, TARGET_GODOT)
	QuestService:RemoveTarget(Player, TARGET_TUTORIAL_ORES)
	QuestService:RemoveTarget(Player, TARGET_TUTORIAL_IRON_ORE)
	QuestService:RemoveTarget(Player, TARGET_TUTORIAL_COAL)
	QuestService:RemoveTarget(Player, TARGET_LUMBERJACK)
	QuestService:RemoveTarget(Player, TARGET_WOOD)
	QuestService:RemoveTarget(Player, TARGET_GODOT_FORGE)
end

local function SetTarget(Player: Player, TargetName: string, Position: Vector3?)
	ClearTargets(Player)

	if Position then
		QuestService:CreateTargetAtPosition(Player, TargetName, Position)
	end

	local PlayerData = DataService:GetData(Player)
	if PlayerData and PlayerData.Quest then
		PlayerData.Quest.TargetName = TargetName
	end
end

local function AddTalkWithGodotObjective(Player: Player)
	local NPCs = workspace:FindFirstChild("NPCs")
	local Godot = NPCs and NPCs:FindFirstChild("Godot")

	ObjectiveService:AddObjective(Player, OBJECTIVE_NAME, {
		{ Name = "Talk with Godot", TargetAmount = 1, CurrentAmount = 0 },
	}, MissionDisplayName, false)

	SetTarget(Player, TARGET_GODOT, GetTargetPosition(Godot))
end

local function GetTutorialOreTargetName(Ore: Instance): string?
	if Ore.Name == "Iron" or Ore.Name == "IronOre" or Ore.Name:find("Iron") then
		return TARGET_TUTORIAL_IRON_ORE
	elseif Ore.Name == "Coal" or Ore.Name:find("Coal") then
		return TARGET_TUTORIAL_COAL
	end

	return nil
end

local function AddTutorialOreTarget(Player: Player, Ore: Instance): boolean
	local TargetName = GetTutorialOreTargetName(Ore)
	local Position = GetTargetPosition(Ore)
	if not TargetName or not Position then
		return false
	end

	QuestService:CreateTargetAtPosition(Player, TargetName, Position)
	return true
end

local function AddTutorialOreTargets(Player: Player)
	ClearTargets(Player)

	local Ores = workspace:FindFirstChild("Ores")
	local TutorialOres = Ores and Ores:FindFirstChild("TutorialOres")
	if not TutorialOres then
		return
	end

	for _, Ore in TutorialOres:GetChildren() do
		if AddTutorialOreTarget(Player, Ore) then
			continue
		end

		for _, Child in Ore:GetChildren() do
			AddTutorialOreTarget(Player, Child)
		end
	end

	local PlayerData = DataService:GetData(Player)
	if PlayerData and PlayerData.Quest then
		PlayerData.Quest.TargetName = TARGET_TUTORIAL_IRON_ORE
	end
end

local function AddMiningObjective(Player: Player, StoryData)
	SyncMiningProgress(Player, StoryData)

	ObjectiveService:AddObjective(Player, OBJECTIVE_NAME, {
		{ Name = "Mine Iron Ore", TargetAmount = IRON_REQUIRED, CurrentAmount = StoryData.IronOre },
		{ Name = "Mine Coal", TargetAmount = COAL_REQUIRED, CurrentAmount = StoryData.Coal },
	}, MissionDisplayName, false)

	AddTutorialOreTargets(Player)
end

local function AddTalkWithLumberjackObjective(Player: Player)
	local NPCs = workspace:FindFirstChild("NPCs")
	local Vasco = NPCs and NPCs:FindFirstChild("Vasco")

	ObjectiveService:AddObjective(Player, OBJECTIVE_NAME, {
		{ Name = "Talk with Vasco", TargetAmount = 1, CurrentAmount = 0 },
	}, MissionDisplayName, false)

	SetTarget(Player, TARGET_LUMBERJACK, GetTargetPosition(Vasco))
end

local function AddWoodObjective(Player: Player, StoryData)
	SyncWoodProgress(Player, StoryData)

	local Map = workspace:FindFirstChild("Map")
	local Vegetation = Map and Map:FindFirstChild("Vegetation")
	local Trees = Vegetation and Vegetation:FindFirstChild("Trees")

	ObjectiveService:AddObjective(Player, OBJECTIVE_NAME, {
		{ Name = "Collect Wood Logs", TargetAmount = WOOD_REQUIRED, CurrentAmount = StoryData.WoodLog },
	}, MissionDisplayName, false)

	SetTarget(Player, TARGET_WOOD, GetTargetPosition(Trees))
end

local function AddReturnToGodotObjective(Player: Player)
	AddTalkWithGodotObjective(Player)
end

local function AddCraftKatanaObjective(Player: Player)
	local Important = workspace:FindFirstChild("Important")
	local GodotForge = Important and Important:FindFirstChild("GodotForge")

	ObjectiveService:AddObjective(Player, OBJECTIVE_NAME, {
		{ Name = "Craft a Katana", TargetAmount = 1, CurrentAmount = 0 },
	}, MissionDisplayName, false)

	SetTarget(Player, TARGET_GODOT_FORGE, GetTargetPosition(GodotForge))
end

local function GiveItemOnce(Player: Player, ItemName: string, SuccessMessage: string)
	if InventoryService:GetPlayerItemByName(Player, ItemName) then
		return
	end

	local Item = ItemService:CreateItem(ItemName, 1)
	if not Item then
		return
	end

	InventoryService:GiveItemToPlayer(Player, Item)
	AlertService:AlertPlayer(Player, SuccessMessage, "Success")
end

local function GivePickaxe(Player: Player)
	GiveItemOnce(Player, "Pickaxe", "Pickaxe was added to your inventory.")
end

local function GiveAxe(Player: Player)
	GiveItemOnce(Player, "Axe", "Axe was added to your inventory.")
end

local function GiveAndEquipBeginnerStance(Player: Player)
	local PlayerData = DataService:GetData(Player)
	if not PlayerData then
		return
	end

	PlayerData.Stances = PlayerData.Stances or {}
	if not table.find(PlayerData.Stances, BEGINNER_STANCE) then
		StanceService:GiveStance(Player, BEGINNER_STANCE)
	end

	StanceService:EquipStance(Player, BEGINNER_STANCE)
end

local function EnsureMinimumLevel(Player: Player, MinimumLevel: number)
	local PlayerData = DataService:GetData(Player)
	if not PlayerData then
		return
	end

	while PlayerData.Level < MinimumLevel do
		local PreviousLevel = PlayerData.Level
		local ExpNeeded = LevelService:GetRemainExpToLevelUp(PlayerData.Level, PlayerData.Exp)
		LevelService:GiveExp(Player, math.max(0, math.ceil(ExpNeeded)))

		PlayerData = DataService:GetData(Player)
		if not PlayerData or PlayerData.Level <= PreviousLevel then
			break
		end
	end
end

local function HasFinishedMining(StoryData): boolean
	return StoryData.IronOre >= IRON_REQUIRED and StoryData.Coal >= COAL_REQUIRED
end

local function HasFinishedWood(StoryData): boolean
	return StoryData.WoodLog >= WOOD_REQUIRED
end

local function FinishMining(Player: Player)
	local _, StoryData = GetStoryData(Player)
	if not StoryData or StoryData.Step ~= STEP_MINE_RESOURCES then
		return false
	end

	StoryData.Step = STEP_TALK_LUMBERJACK
	AddTalkWithLumberjackObjective(Player)
	return true
end

local function FinishWood(Player: Player)
	local _, StoryData = GetStoryData(Player)
	if not StoryData or StoryData.Step ~= STEP_CHOP_WOOD then
		return false
	end

	StoryData.Step = STEP_RETURN_TO_GODOT
	AddReturnToGodotObjective(Player)
	return true
end

local function FinishCraftKatana(Player: Player)
	local _, StoryData = GetStoryData(Player)
	if not StoryData or StoryData.Step ~= STEP_CRAFT_KATANA then
		return false
	end

	StoryData.CraftedKatana = true
	StoryData.Step = STEP_TALK_GODOT_AFTER_KATANA
	GiveAndEquipBeginnerStance(Player)
	EnsureMinimumLevel(Player, MIN_LEVEL_AFTER_KATANA)
	AddReturnToGodotObjective(Player)
	return true
end

local function StartMining(Player: Player)
	local _, StoryData = GetStoryData(Player)
	if
		not StoryData
		or StoryData.Completed
		or (StoryData.Step ~= STEP_TALK_GODOT and StoryData.Step ~= STEP_MINE_RESOURCES)
	then
		return false
	end

	GivePickaxe(Player)
	StoryData.Step = STEP_MINE_RESOURCES
	SyncMiningProgress(Player, StoryData)

	if HasFinishedMining(StoryData) then
		return FinishMining(Player)
	end

	AddMiningObjective(Player, StoryData)
	return true
end

local function StartWoodcutting(Player: Player)
	local _, StoryData = GetStoryData(Player)
	if
		not StoryData
		or StoryData.Completed
		or (StoryData.Step ~= STEP_TALK_LUMBERJACK and StoryData.Step ~= STEP_CHOP_WOOD)
	then
		return false
	end

	GiveAxe(Player)
	StoryData.Step = STEP_CHOP_WOOD
	SyncWoodProgress(Player, StoryData)

	if HasFinishedWood(StoryData) then
		return FinishWood(Player)
	end

	AddWoodObjective(Player, StoryData)
	return true
end

local function StartCraftKatana(Player: Player)
	local _, StoryData = GetStoryData(Player)
	if
		not StoryData
		or StoryData.Completed
		or (StoryData.Step ~= STEP_RETURN_TO_GODOT and StoryData.Step ~= STEP_CRAFT_KATANA)
	then
		return false
	end

	StoryData.Step = STEP_CRAFT_KATANA
	if InventoryService:GetPlayerItemByName(Player, KATANA_NAME) then
		return FinishCraftKatana(Player)
	end

	AddCraftKatanaObjective(Player)
	return true
end

local function AddCollectedResource(Player: Player, ItemName: string, Amount: number)
	local _, StoryData = GetStoryData(Player)
	if not StoryData or StoryData.Completed then
		return false
	end

	if StoryData.Step == STEP_MINE_RESOURCES then
		if ItemName == "IronOre" then
			local PreviousAmount = StoryData.IronOre
			StoryData.IronOre = math.clamp(StoryData.IronOre + Amount, 0, IRON_REQUIRED)
			ObjectiveService:UpdateProgress(Player, OBJECTIVE_NAME, 1, StoryData.IronOre - PreviousAmount)
		elseif ItemName == "Coal" then
			local PreviousAmount = StoryData.Coal
			StoryData.Coal = math.clamp(StoryData.Coal + Amount, 0, COAL_REQUIRED)
			ObjectiveService:UpdateProgress(Player, OBJECTIVE_NAME, 2, StoryData.Coal - PreviousAmount)
		else
			return false
		end

		if HasFinishedMining(StoryData) then
			FinishMining(Player)
		end

		return true
	elseif StoryData.Step == STEP_CHOP_WOOD then
		if ItemName ~= "WoodLog" then
			return false
		end

		local PreviousAmount = StoryData.WoodLog
		StoryData.WoodLog = math.clamp(StoryData.WoodLog + Amount, 0, WOOD_REQUIRED)
		ObjectiveService:UpdateProgress(Player, OBJECTIVE_NAME, 1, StoryData.WoodLog - PreviousAmount)

		if HasFinishedWood(StoryData) then
			FinishWood(Player)
		end

		return true
	end

	return false
end

local function CraftItem(Player: Player, ItemName: string)
	local _, StoryData = GetStoryData(Player)
	if not StoryData or StoryData.Step ~= STEP_CRAFT_KATANA or ItemName ~= KATANA_NAME then
		return false
	end

	return FinishCraftKatana(Player)
end

local function Resume(Player: Player)
	local _, StoryData = GetStoryData(Player)
	if not StoryData or StoryData.Completed then
		return false
	end

	if StoryData.Step == STEP_MINE_RESOURCES then
		GivePickaxe(Player)
		SyncMiningProgress(Player, StoryData)
		if HasFinishedMining(StoryData) then
			return FinishMining(Player)
		end
		AddMiningObjective(Player, StoryData)
	elseif StoryData.Step == STEP_TALK_LUMBERJACK then
		AddTalkWithLumberjackObjective(Player)
	elseif StoryData.Step == STEP_CHOP_WOOD then
		GiveAxe(Player)
		SyncWoodProgress(Player, StoryData)
		if HasFinishedWood(StoryData) then
			return FinishWood(Player)
		end
		AddWoodObjective(Player, StoryData)
	elseif StoryData.Step == STEP_RETURN_TO_GODOT then
		AddReturnToGodotObjective(Player)
	elseif StoryData.Step == STEP_CRAFT_KATANA then
		if InventoryService:GetPlayerItemByName(Player, KATANA_NAME) then
			return FinishCraftKatana(Player)
		end
		AddCraftKatanaObjective(Player)
	elseif StoryData.Step == STEP_TALK_GODOT_AFTER_KATANA then
		EnsureMinimumLevel(Player, MIN_LEVEL_AFTER_KATANA)
		AddReturnToGodotObjective(Player)
	elseif StoryData.Step == STEP_COMPLETED then
		StoryData.Completed = true
		return false
	else
		StoryData.Step = STEP_TALK_GODOT
		AddTalkWithGodotObjective(Player)
	end

	return true
end

return {
	Name = "TalkWithBlacksmith",
	QuestType = "Story",
	Requirements = {},
	Persistent = true,
	CanAbandon = false,

	OnStart = function(Player: Player)
		return Resume(Player)
	end,

	Resume = function(Player: Player)
		return Resume(Player)
	end,

	StartMining = function(Player: Player)
		return StartMining(Player)
	end,

	StartWoodcutting = function(Player: Player)
		return StartWoodcutting(Player)
	end,

	StartCraftKatana = function(Player: Player)
		return StartCraftKatana(Player)
	end,

	CollectResource = function(Player: Player, ItemName: string, Amount: number)
		return AddCollectedResource(Player, ItemName, Amount)
	end,

	CraftItem = function(Player: Player, ItemName: string)
		return CraftItem(Player, ItemName)
	end,

	CompleteQuest = function(Player: Player)
		local _, StoryData = GetStoryData(Player)
		if StoryData then
			StoryData.Step = STEP_COMPLETED
			StoryData.Completed = true
			StoryData.IronOre = math.clamp(StoryData.IronOre or 0, 0, IRON_REQUIRED)
			StoryData.Coal = math.clamp(StoryData.Coal or 0, 0, COAL_REQUIRED)
			StoryData.WoodLog = math.clamp(StoryData.WoodLog or 0, 0, WOOD_REQUIRED)
		end

		GiveAndEquipBeginnerStance(Player)
		ClearTargets(Player)
		TetsuService:AddTetsu(Player, 150)
		LevelService:GiveExp(Player, 300)
		EnsureMinimumLevel(Player, MIN_LEVEL_AFTER_KATANA)
		ObjectiveService:ClearObjective(Player, OBJECTIVE_NAME, true)
		QuestService:RemoveQuest(Player)
		return true
	end,

	Cancel = function(Player: Player)
		ClearTargets(Player)
		ObjectiveService:ClearObjective(Player, OBJECTIVE_NAME)
		return true
	end,
}
