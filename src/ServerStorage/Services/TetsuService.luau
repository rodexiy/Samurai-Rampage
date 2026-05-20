local Knit = require(game.ReplicatedStorage.Packages.Knit)

local TetsuService = Knit.CreateService({
	Name = "TetsuService",
	Client = {
		TetsuUpdated = Knit.CreateSignal(),
	},
})

local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local DataService

function TetsuService:UpdateTetsu(Player: Player, Amount: number)
	TetsuService.Client.TetsuUpdated:Fire(Player, Amount)
end

function TetsuService:HaveTetsu(Player: Player, Amount: number): boolean
	local PlayerData = DataService:GetData(Player)
	return PlayerData.Tetsu >= Amount
end

function TetsuService:AddTetsu(Player: Player, Amount: number): number
	local PlayerData = DataService:GetData(Player)
	PlayerData.Tetsu += Amount

	if not RunService:IsStudio() then
		AnalyticsService:LogEconomyEvent(
			Player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Tetsu",
			Amount,
			PlayerData.Tetsu,
			Enum.AnalyticsEconomyTransactionType.Gameplay.Name
		)
	end
	TetsuService:UpdateTetsu(Player, PlayerData.Tetsu)
	return PlayerData.Tetsu
end

function TetsuService:RemoveTetsu(Player: Player, Amount: number): boolean
	local PlayerData = DataService:GetData(Player)
	if TetsuService:HaveTetsu(Player, Amount) then
		PlayerData.Tetsu -= Amount

		if not RunService:IsStudio() then
			AnalyticsService:LogEconomyEvent(
				Player,
				Enum.AnalyticsEconomyFlowType.Sink,
				"Tetsu",
				Amount,
				PlayerData.Tetsu,
				Enum.AnalyticsEconomyTransactionType.Gameplay.Name
			)
		end

		TetsuService:UpdateTetsu(Player, PlayerData.Tetsu)
		return true
	end

	return false
end

function TetsuService:SetTetsu(Player: Player, Amount: number): number
	local PlayerData = DataService:GetData(Player)

	local TetsuDiff = math.abs(Amount - PlayerData.Tetsu)

	if not RunService:IsStudio() then
		AnalyticsService:LogEconomyEvent(
			Player,
			Enum.AnalyticsEconomyFlowType.Source,
			"Tetsu",
			TetsuDiff,
			Amount,
			Enum.AnalyticsEconomyTransactionType.Gameplay.Name
		)
	end
	PlayerData.Tetsu = Amount

	TetsuService:UpdateTetsu(Player, PlayerData.Tetsu)
	return PlayerData.Tetsu
end

function TetsuService:GetTetsu(Player: Player): number
	local PlayerData = DataService:GetData(Player)
	return PlayerData.Tetsu
end
function TetsuService.Client:GetTetsu(Player: Player): number
	return self.Server:GetTetsu(Player)
end

function TetsuService.KnitInit()
	DataService = Knit.GetService("DataService")
end

return TetsuService
