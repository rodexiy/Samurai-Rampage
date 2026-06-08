local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local MissionBoardService = Knit.CreateService({
	Name = "MissionBoardService",
	Client = { UpdateBoard = Knit.CreateSignal() },
})

local PlayerBoards = {}
local PlayerSelectedMissions = {}
local AlertService
local LevelService
local TetsuService
local ObjectiveService
local MAX_ACTIVE_MISSIONS = 3

type MissionType = {
	Name: string,
	Description: string,
	Exp: number,
	Tetsu: number,
	MissionData: { any },
}

local MissionTypes = {
	"Kill",
	"ObtainLostItem",
	"ResourceContract",
	"DeliveryTimed",
	-- "Find",
	-- "Rescue",
	-- "Obtain",
}

local Missions = {}

local function GetActiveMissions(Player: Player): { any }
	if not PlayerSelectedMissions[Player] then
		PlayerSelectedMissions[Player] = {}
	end

	return PlayerSelectedMissions[Player]
end

local function GetMissionObjectiveName(Mission: { any }): string?
	return Mission.MissionData and Mission.MissionData.ObjectiveName
end

local function FindActiveMission(Player: Player, MissionOrId: any): (number?, { any }?)
	local ActiveMissions = GetActiveMissions(Player)
	local MissionId = if typeof(MissionOrId) == "table" then MissionOrId.Id else MissionOrId

	for Index, Mission in ActiveMissions do
		if Mission == MissionOrId or Mission.Id == MissionId then
			return Index, Mission
		end
	end

	return nil, nil
end

function MissionBoardService:RaycastDown(Position: Vector3)
	local Params = RaycastParams.new()
	Params.FilterDescendantsInstances = { workspace.Map.Vegetation.Trees, workspace.Entity }
	Params.FilterType = Enum.RaycastFilterType.Exclude

	local ray = workspace:Raycast(Position, Vector3.new(0, -10000, 0), Params)

	if ray then
		return ray.Position
	end
end

local MissionSpawns = workspace.Map.MissionSpawns:GetChildren()

function MissionBoardService:GetRandomPoint(Part: BasePart)
	local size = Part.Size

	local randomX = (math.random() - 0.5) * size.X
	local randomY = (math.random() - 0.5) * size.Y
	local randomZ = (math.random() - 0.5) * size.Z

	local HighPosition = Part.Position + Vector3.new(randomX, randomY, randomZ)

	local Position = MissionBoardService:RaycastDown(HighPosition)

	if Position then
		return Position
	end

	return MissionBoardService:GetRandomPointInSpawn()
end

local MissionSpawns 
local DuelSpawns

function MissionBoardService:GetRandomPointInDuelSpawn()
	local DuelSpawns = ServerStorage.DuelSpawns:GetChildren()

	local Part = DuelSpawns[math.random(#DuelSpawns)]
	return MissionBoardService:GetRandomPoint(Part)
end

function MissionBoardService:GetRandomPointInSpawn()
	local Part = MissionSpawns[math.random(#MissionSpawns)]

	return MissionBoardService:GetRandomPoint(Part)
end

function MissionBoardService:SelectMission(Player: Player, Id: string)
	local ActiveMissions = GetActiveMissions(Player)
	if #ActiveMissions >= MAX_ACTIVE_MISSIONS then
		AlertService:AlertPlayer(Player, "You can only have " .. MAX_ACTIVE_MISSIONS .. " board missions at once.", "Error")
		return false
	end

	local Mission
	if PlayerBoards[Player] then
		for _, BoardMission in PlayerBoards[Player] do
			if BoardMission.Id == Id then
				Mission = BoardMission
				break
			end
		end
	end

	if not Mission then
		return false
	end

	table.remove(PlayerBoards[Player], table.find(PlayerBoards[Player], Mission))
	table.insert(ActiveMissions, Mission)

	local Success = Missions[Mission.Name]:Select(Player, Mission)
	if Success == false then
		table.remove(ActiveMissions, table.find(ActiveMissions, Mission))
		return false
	end

	return true
end
function MissionBoardService.Client:Select(Player: Player, Id: string)
	return self.Server:SelectMission(Player, Id)
end

function MissionBoardService:GetPlayerBoard(Player: Player)
	return PlayerBoards[Player]
end

function MissionBoardService:OpenBoard(Player: Player)
	if not PlayerBoards[Player] then
		PlayerBoards[Player] = {}

		for i = 1, 5 do
			local MissionType = MissionTypes[math.random(#MissionTypes)]
			local Mission = Missions[MissionType]:Randomize(Player)
			Mission.Id = HttpService:GenerateGUID(false):sub(1, 8)
			table.insert(PlayerBoards[Player], Mission)
		end

		MissionBoardService.Client.UpdateBoard:Fire(Player, PlayerBoards[Player])
	end
end

function MissionBoardService:FinishedMission(Player: Player, Mission: { any })
	if Missions[Mission.Name].Reward then
		Missions[Mission.Name]:Reward(Player, Mission)
	end

	LevelService:GiveExp(Player, Mission.Exp)
	TetsuService:AddTetsu(Player, Mission.Tetsu)
	local ObjectiveName = GetMissionObjectiveName(Mission)
	if ObjectiveName then
		ObjectiveService:ClearObjective(Player, ObjectiveName, true)
	end

	MissionBoardService:DestroyMission(Player, Mission, true)
end

function MissionBoardService:DestroyMission(Player: Player, MissionOrId: any?, SkipObjectiveClear: boolean?)
	local ActiveMissions = GetActiveMissions(Player)
	if not MissionOrId then
		for Index = #ActiveMissions, 1, -1 do
			MissionBoardService:DestroyMission(Player, ActiveMissions[Index], SkipObjectiveClear)
		end
		return
	end

	local Index, Mission = FindActiveMission(Player, MissionOrId)
	if not Mission then
		return
	end

	Missions[Mission.Name]:Destroy(Player, Mission)
	table.remove(ActiveMissions, Index)

	local ObjectiveName = GetMissionObjectiveName(Mission)
	if ObjectiveName and not SkipObjectiveClear then
		ObjectiveService:ClearObjective(Player, ObjectiveName)
	end
end

function MissionBoardService:RerollMissions(Player: Player)
	if PlayerBoards[Player] then
		table.clear(PlayerBoards[Player])
	end

	PlayerBoards[Player] = nil

	MissionBoardService:OpenBoard(Player)
end
function MissionBoardService.Client:RerollMissions(Player: Player)
	self.Server:RerollMissions(Player)
end

function MissionBoardService:GetPlayerSelectedMission(Player: Player)
	local ActiveMissions = GetActiveMissions(Player)
	if #ActiveMissions == 0 then
		return nil
	end

	return ActiveMissions
end

function MissionBoardService:CallMissionFunction(Player: Player, FunctionName: string, ...: any)
	local ActiveMissions = GetActiveMissions(Player)
	if #ActiveMissions == 0 then
		return false
	end

	local Called = false
	local ActiveMissionsSnapshot = table.clone(ActiveMissions)
	for _, Mission in ActiveMissionsSnapshot do
		local MissionModule = Missions[Mission.Name]
		if MissionModule and MissionModule[FunctionName] then
			local Result = MissionModule[FunctionName](MissionModule, Player, Mission, ...)
			if Result ~= false then
				Called = true
			end
		end
	end

	return Called
end

function MissionBoardService:ClearMissions(Player: Player)
	PlayerBoards[Player] = nil
	MissionBoardService:DestroyMission(Player)
	PlayerSelectedMissions[Player] = nil
end

function MissionBoardService.KnitInit()
	local MissionSpawnsFolder
	if workspace:FindFirstChild("Map") then
		 MissionSpawnsFolder = workspace.Map:FindFirstChild("MissionSpawns")
	end
	
	if MissionSpawnsFolder then
		MissionSpawns = MissionSpawnsFolder:GetChildren()
	end
	
	local DuelSpawnsFolder = ServerStorage:FindFirstChild("DuelSpawns")
	if DuelSpawnsFolder then
		DuelSpawns = DuelSpawnsFolder:GetChildren()
	end
	
	AlertService = Knit.GetService("AlertService")
	LevelService = Knit.GetService("LevelService")
	TetsuService = Knit.GetService("TetsuService")
	ObjectiveService = Knit.GetService("ObjectiveService")

	for _, MissionModule in script:GetChildren() do
		Missions[MissionModule.Name] = require(MissionModule)
	end
end

function MissionBoardService.KnitStart() end

return MissionBoardService
