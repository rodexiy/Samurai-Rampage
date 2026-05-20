local Players = game:GetService("Players")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local LagCompensationService = Knit.CreateService({
	Name = "LagCompensationService",
	Client = {},
})

local LagCompensationUpdater: UnreliableRemoteEvent = game.ReplicatedStorage.Assets.Public.LagCompensationUpdater

function LagCompensationService.Update(Player: Player, Tick: number)
	local Character = Player.Character
	if not Character then
		return
	end

	local Ping = workspace:GetServerTimeNow() - Tick
	local PingClamp = math.clamp(Ping * 1.5, 0, 0.18)
	Character:SetAttribute("Ping", PingClamp)
end

function LagCompensationService:GetCompensation(Character: Model)
	local Player = Players:GetPlayerFromCharacter(Character)
	if not Player or Player:GetAttribute("LagCompensation") then
		return Character:GetAttribute("Ping") or 0
	end

	return 0
end

function LagCompensationService.KnitInit()
	LagCompensationUpdater.OnServerEvent:Connect(LagCompensationService.Update)
end

function LagCompensationService.KnitStart() end

return LagCompensationService
