local Knit = require(game.ReplicatedStorage.Packages.Knit)
local Players = game:GetService("Players")

type SubObjective = {
	Name: string,
	TargetAmount: number,
	CurrentAmount: number,
}

type Objective = {
	Name: string,
	Objectives: { SubObjective },
}

local ObjectiveService = Knit.CreateService({
	Name = "ObjectiveService",
	Client = {
		ObjectiveAdded = Knit.CreateSignal(),
		ObjectiveUpdated = Knit.CreateSignal(),
		ObjectiveCleared = Knit.CreateSignal(),
	},
})

local PlayerObjectives: { [Player]: { [string]: Objective } } = {}

local function GetOrCreatePlayerObjectives(Player: Player): { [string]: Objective }
	if not PlayerObjectives[Player] then
		PlayerObjectives[Player] = {}
	end
	return PlayerObjectives[Player]
end

function ObjectiveService:AddObjective(Player: Player, Name: string, ObjectiveData: { SubObjective })
	local Objectives = GetOrCreatePlayerObjectives(Player)
	Objectives[Name] = {
		Name = Name,
		Objectives = ObjectiveData,
	}
	self.Client.ObjectiveAdded:Fire(Player, Name, Objectives[Name])
end

function ObjectiveService:ClearObjectives(Player: Player, Completed: boolean)
	self.Client.ObjectiveCleared:Fire(Player, Completed)
end

function ObjectiveService:UpdateProgress(Player: Player, ObjectiveName: string, Index: number, Amount: number)
	local Objectives = GetOrCreatePlayerObjectives(Player)
	local Objective = Objectives[ObjectiveName]

	if not Objective then
		return
	end
	local SubObjective = Objective.Objectives[Index]
	if not SubObjective then
		return
	end
	SubObjective.CurrentAmount = math.clamp(SubObjective.CurrentAmount + Amount, 0, SubObjective.TargetAmount)
	self.Client.ObjectiveUpdated:Fire(Player, SubObjective)
end

function ObjectiveService:GetObjectives(Player: Player): { [string]: Objective }
	return GetOrCreatePlayerObjectives(Player)
end

function ObjectiveService.Client:GetObjectives(Player: Player)
	return self.Server:GetObjectives(Player)
end

function ObjectiveService:KnitInit() end

function ObjectiveService:KnitStart()
	Players.PlayerRemoving:Connect(function(Player)
		PlayerObjectives[Player] = nil
	end)
end

return ObjectiveService
