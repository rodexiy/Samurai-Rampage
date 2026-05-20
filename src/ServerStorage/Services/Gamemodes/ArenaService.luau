local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")
local TeleportService = game:GetService("TeleportService")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local ArenaService = Knit.CreateService({
	Name = "ArenaService",
	Client = {},
})

local PlaceService
local AlertService
local CharacterService
local DataService

function ArenaService:WaitForPlayers()
	local TeleportData

	game.Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("CantAttack", true)
		player:SetAttribute("NoForceField", true)
	end)
	for _, player in game.Players:GetPlayers() do
		player:SetAttribute("CantAttack", true)
		player:SetAttribute("NoForceField", true)
	end

	if RunService:IsStudio() then
		TeleportData = {
			Red = {
				"Player1",
			},
			Blue = {
				"Player2",
			},
		}
	end

	while not TeleportData do
		for _, Player: Player in Players:GetPlayers() do
			if Player:GetJoinData().TeleportData then
				TeleportData = Player:GetJoinData().TeleportData
				break
			end
		end
		task.wait(1)
	end

	local AllPlayersJoinend = false
	local AllPlayersName = {}
	local BlueAlive = {}
	local RedAlive = {}

	for _, Name in TeleportData.Red do
		table.insert(AllPlayersName, Name)
		table.insert(RedAlive, Name)
	end

	for _, Name in TeleportData.Blue do
		table.insert(AllPlayersName, Name)
		table.insert(BlueAlive, Name)
	end

	local function GetPlayerTeam(Player: Player)
		for TeamName, Team in TeleportData do
			if table.find(Team, Player.Name) then
				return TeamName, Teams:FindFirstChild(TeamName)
			end
		end
	end

	game.Players.PlayerRemoving:Connect(function(Player: Player)
		local TeamName, _ = GetPlayerTeam(Player)
		if TeamName == "Red" then
			table.remove(RedAlive, table.find(RedAlive, Player.Name))
		elseif TeamName == "Blue" then
			table.remove(BlueAlive, table.find(BlueAlive, Player.Name))
		end
	end)

	local Counter = 60
	while not AllPlayersJoinend do
		if Counter <= 0 then
			break
		end
		local AllJoined = true
		for _, PlayerName in AllPlayersName do
			local Player = Players:FindFirstChild(PlayerName)

			if not Player or not Player.Character then
				AllJoined = false
				break
			end
		end

		if AllJoined then
			AllPlayersJoinend = true
		end

		AlertService:AlertAll("Waiting for players: " .. Counter)
		Counter -= 1
		task.wait(1)
	end

	if not AllPlayersJoinend then
		game.Players.PlayerAdded:Connect(function(player)
			TeleportService:Teleport(PlaceService:GetPlaceId("Hub"), player)
		end)

		AlertService:AlertAll("Teleporting to hub...", "Warn")
		for _, Player: Player in Players:GetPlayers() do
			TeleportService:Teleport(PlaceService:GetPlaceId("Hub"), Player)
		end
		return
	end

	local Counter = 10
	while Counter > 0 do
		AlertService:AlertAll("Starting game in: " .. Counter)
		Counter -= 1
		task.wait(1)
	end

	AlertService:AlertAll("Teleporting to arena...", "Warn")

	for _, Player: Player in Players:GetPlayers() do
		local TeamName, Team = GetPlayerTeam(Player)
		Player.Team = Team
	end

	for _, Player: Player in Players:GetPlayers() do
		Player:SetAttribute("CantAttack", nil)
		task.spawn(function()
			local TeamName, Team = GetPlayerTeam(Player)

			CharacterService:LoadCharacter(Player)
			local Character
			repeat
				Character = Player.Character
				task.wait()
			until Character and Character:GetAttribute("Loaded")
			local RootPart = Character:WaitForChild("HumanoidRootPart")
			RootPart.Anchored = true
			RootPart.CFrame = workspace[TeamName].CFrame * CFrame.new(0, 3, 0)
			task.delay(0.1, function()
				RootPart.Anchored = false
			end)

			Character:GetAttributeChangedSignal("Died"):Connect(function()
				if TeamName == "Red" then
					table.remove(RedAlive, table.find(RedAlive, Player.Name))
				elseif TeamName == "Blue" then
					table.remove(BlueAlive, table.find(BlueAlive, Player.Name))
				end
				Player:SetAttribute("CantAttack", true)
				Player.Team = Teams.Waiting
			end)
		end)
	end

	local TeamWinner

	while not TeamWinner do
		if #RedAlive == 0 then
			TeamWinner = "Blue"
		elseif #BlueAlive == 0 then
			TeamWinner = "Red"
		end
		task.wait(1)
	end

	AlertService:AlertAll("Team " .. TeamWinner .. " won!", "Success")
	local Counter = 5
	while Counter > 0 do
		AlertService:AlertAll("Teleporting to hub in: " .. Counter)
		Counter -= 1
		task.wait(1)
	end

	for _, Player: Player in Players:GetPlayers() do
		TeleportService:Teleport(PlaceService:GetPlaceId("Hub"), Player)
	end
	AlertService:AlertAll("Teleporting...", "Success")
end

function ArenaService.KnitInit()
	PlaceService = Knit.GetService("PlaceService")
	DataService = Knit.GetService("DataService")
	AlertService = Knit.GetService("AlertService")
	CharacterService = Knit.GetService("CharacterService")
end

function ArenaService.KnitStart()
	if PlaceService:IsArena() then
		ArenaService:WaitForPlayers()
	end
end

return ArenaService
