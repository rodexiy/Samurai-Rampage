local Knit = require(game.ReplicatedStorage.Packages.Knit)

local RugService = Knit.CreateService({
	Name = "RugService",
	Client = {
		UnlockedRug = Knit.CreateSignal(),
	},
})

local DataService
local AlertService
local RenderService
local LevelService

function RugService:UnlockRug(Player: Player)
	local Character = Player.Character
	if not Character then
		return
	end

	if not workspace:FindFirstChild("Rugs") then
		return
	end

	local PlayerData = DataService:GetData(Player)
	for _, Rug in workspace.Rugs:GetChildren() do
		local Distance = (Rug:GetPivot().Position - Character:GetPivot().Position).Magnitude
		if Distance < 10 then
			if not table.find(PlayerData.UnlockedRugs, Rug.Name) then
				table.insert(PlayerData.UnlockedRugs, Rug.Name)
				RenderService:RenderForAllPlayers("Misc", "MeditateNewRug", { Character = Character })
				AlertService:AlertPlayer(Player, "Unlocked " .. Rug.Name .. "!", "Success")
				LevelService:GiveExp(Player, 100)
				RugService.Client.UnlockedRug:Fire(Player, PlayerData.UnlockedRugs)
			end
		end
	end
end

function RugService.Client:UnlockRug(Player: Player)
	self.Server:UnlockRug(Player)
end

function RugService:GetUnlockedRugs(Player: Player)
	local PlayerData = DataService:GetData(Player)
	return PlayerData.UnlockedRugs
end

function RugService.Client:GetUnlockedRugs(Player: Player)
	return self.Server:GetUnlockedRugs(Player)
end

function RugService.KnitInit()
	DataService = Knit.GetService("DataService")
	AlertService = Knit.GetService("AlertService")
	RenderService = Knit.GetService("RenderService")
	LevelService = Knit.GetService("LevelService")
end

function RugService.KnitStart() end

return RugService
