local Knit = require(game.ReplicatedStorage.Packages.Knit)

local BaseBuildingService = Knit.CreateService({
	Name = "BaseBuildingService",
	Client = {},
})

local DataService

function BaseBuildingService:LoadBase() end

function BaseBuildingService.KnitInit()
	DataService = Knit.GetService("DataService")
end

function BaseBuildingService.KnitStart() end

return BaseBuildingService
