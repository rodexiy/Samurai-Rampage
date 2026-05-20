local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local MissionBoardService = Knit.CreateService({
	Name = "MissionBoardService",
	Client = { UpdateBoard = Knit.CreateSignal() },
})

local PlayerBoards = {}
local PlayerSelectedMission = {}
local AlertService
local LevelService
local TetsuService
local ObjectiveService

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
	-- "Find",
	-- "Rescue",
	-- "Obtain",
}

local Missions = {}

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
	if Player:GetAttribute("HasQuest") then
		AlertService:AlertPlayer(Player, "You already have an objective.", "Error")
		return false
	end
	if PlayerSelectedMission[Player] then
		AlertService:AlertPlayer(Player, "You already have an objective.", "Error")
		return false
	end

	if PlayerBoards[Player] then
		for _, Mission in PlayerBoards[Player] do
			if Mission.Id == Id then
				PlayerSelectedMission[Player] = Mission
				break
			end
		end
	end

	local Mission = PlayerSelectedMission[Player]
	if not Mission then
		return false
	end

	table.remove(PlayerBoards[Player], table.find(PlayerBoards[Player], Mission))
	Missions[Mission.Name]:Select(Player, Mission)

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
	ObjectiveService:ClearObjectives(Player, true)

	MissionBoardService:DestroyMission(Player)
end

function MissionBoardService:DestroyMission(Player: Player)
	local Mission = PlayerSelectedMission[Player]
	if not Mission then
		return
	end

	Missions[Mission.Name]:Destroy(Player, Mission)
	PlayerSelectedMission[Player] = nil
	ObjectiveService:ClearObjectives(Player)
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
	return PlayerSelectedMission[Player]
end

function MissionBoardService:ClearMissions(Player: Player)
	PlayerBoards[Player] = nil
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
