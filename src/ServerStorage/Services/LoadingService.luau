local Knit = require(game.ReplicatedStorage.Packages.Knit)

local LoadingService = Knit.CreateService({
	Name = "LoadingService",
	Client = {},
})

function LoadingService:KnitClientLoaded(Player: Player)
	Player:SetAttribute("KnitClientLoaded", true)
end

function LoadingService:WaitForKnitClientLoaded(Player: Player)
	if Player:GetAttribute("KnitClientLoaded") then
		return true
	end

	repeat
		task.wait()
	until Player:GetAttribute("KnitClientLoaded") or not Player.Parent

	return Player:GetAttribute("KnitClientLoaded") == true
end

function LoadingService.Client:KnitClientLoaded(Player: Player)
	self.Server:KnitClientLoaded(Player)
end

function LoadingService.KnitInit() end

function LoadingService.KnitStart() end

return LoadingService
