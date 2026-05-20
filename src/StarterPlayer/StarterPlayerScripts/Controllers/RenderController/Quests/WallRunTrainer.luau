local WallRunTrainer = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)
local RenderController = Knit.GetController("RenderController")
local Player = game.Players.LocalPlayer

local Collector = require(game.ReplicatedStorage.Shared.Collector)
local LoadedQuest = nil
local LoadedConnections = Collector.new()

function WallRunTrainer.LoadQuest(RenderData)
	if LoadedQuest then
		LoadedQuest:Destroy()
		LoadedQuest = nil
	end
	LoadedConnections:DisconnectAll()

	LoadedQuest = game.ReplicatedStorage.Assets.Quests.WallRun:Clone()
	LoadedQuest.Parent = workspace

	LoadedConnections:Add(LoadedQuest.restart.Touched:Connect(function(hit)
		if hit:IsDescendantOf(Player.Character) then
			Player.Character:PivotTo(LoadedQuest.Respawn.CFrame)
		end
	end))
end

function WallRunTrainer.ExitQuest()
	if LoadedQuest then
		LoadedQuest:Destroy()
		LoadedQuest = nil
	end
	LoadedConnections:DisconnectAll()
end

return WallRunTrainer
