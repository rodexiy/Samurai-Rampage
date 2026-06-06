local ResourceContract = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)
local MissionBoardService = Knit.GetService("MissionBoardService")
local ObjectiveService = Knit.GetService("ObjectiveService")

local ObjectiveName = "MissionBoardResourceContract"

local Resources = {
	{
		ItemName = "WoodLog",
		DisplayName = "Wood Logs",
		Amount = { 8, 15 },
		ExpPerItem = 60,
		RequiredTool = "Axe",
	},
	{
		ItemName = "Coal",
		DisplayName = "Coal",
		Amount = { 6, 12 },
		ExpPerItem = 80,
		RequiredTool = "Pickaxe",
	},
	{
		ItemName = "IronOre",
		DisplayName = "Iron Ore",
		Amount = { 4, 8 },
		ExpPerItem = 110,
		RequiredTool = "Pickaxe",
	},
	{
		ItemName = "Crystal",
		DisplayName = "Crystals",
		Amount = { 3, 6 },
		ExpPerItem = 150,
		RequiredTool = "Pickaxe",
	},
	{
		ItemName = "GoldOre",
		DisplayName = "Gold Ore",
		Amount = { 2, 4 },
		ExpPerItem = 220,
		RequiredTool = "Pickaxe",
	},
}

function ResourceContract:Randomize(Player: Player)
	local Resource = Resources[math.random(1, #Resources)]
	local Amount = math.random(Resource.Amount[1], Resource.Amount[2])
	local Exp = Amount * Resource.ExpPerItem

	return {
		Name = "ResourceContract",
		DisplayName = "Gather " .. Resource.DisplayName,
		Description = "Requires: "
			.. Resource.RequiredTool
			.. "\nGather "
			.. Amount
			.. " "
			.. Resource.DisplayName
			.. " from natural resources.",
		Exp = Exp,
		Tetsu = math.floor(Exp * 0.4),
		MissionData = {
			ItemName = Resource.ItemName,
			DisplayName = Resource.DisplayName,
			RequiredTool = Resource.RequiredTool,
			TargetAmount = Amount,
			CurrentAmount = 0,
		},
		Image = "rbxassetid://127605539843467",
	}
end

function ResourceContract:Select(Player: Player, Mission: { any })
	local Data = Mission.MissionData

	ObjectiveService:AddObjective(Player, ObjectiveName, {
		{
			Name = "Gather " .. Data.DisplayName,
			TargetAmount = Data.TargetAmount,
			CurrentAmount = 0,
		},
	})
end

function ResourceContract:CollectResource(Player: Player, Mission: { any }, ItemName: string, Amount: number)
	local Data = Mission.MissionData
	if ItemName ~= Data.ItemName or Data.CurrentAmount >= Data.TargetAmount then
		return
	end

	local Progress = math.min(Amount, Data.TargetAmount - Data.CurrentAmount)
	Data.CurrentAmount += Progress
	ObjectiveService:UpdateProgress(Player, ObjectiveName, 1, Progress)

	if Data.CurrentAmount >= Data.TargetAmount then
		MissionBoardService:FinishedMission(Player, Mission)
	end
end

function ResourceContract:Destroy(Player: Player, Mission: { any }) end

return ResourceContract
