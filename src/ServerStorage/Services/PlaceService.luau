local Knit = require(game.ReplicatedStorage.Packages.Knit)
local PlaceService = Knit.CreateService({
	Name = "PlaceService",
	Client = {},
})

local Places = {
	["Trading"] = 140116923448246,
	["SHURA"] = 104934022920218,
	["Hub"] = 108439269156897,
	["Arena"] = 137662639368401,
}

function PlaceService:IsPlace(PlaceName: string)
	if game.PlaceId == Places[PlaceName] then
		return true
	end
	return false
end

function PlaceService:GetPlaceId(PlaceName: string)
	return Places[PlaceName]
end

function PlaceService:IsTrading()
	return self:IsPlace("Trading")
end

function PlaceService:IsHub()
	return self:IsPlace("Hub")
end

function PlaceService:IsArena()
	return self:IsPlace("Arena")
end

function PlaceService:IsSHURA()
	return self:IsPlace("SHURA")
end

function PlaceService.KnitInit() end

function PlaceService.KnitStart() end

return PlaceService
