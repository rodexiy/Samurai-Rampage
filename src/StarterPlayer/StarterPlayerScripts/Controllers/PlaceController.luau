local Knit = require(game.ReplicatedStorage.Packages.Knit)

local PlaceController = Knit.CreateController({
	Name = "PlaceController",
})
local Places = {
	["Trading"] = 140116923448246,
	["SHURA"] = 104934022920218,
	["Hub"] = 108439269156897,
	["Arena"] = 137662639368401,
}

function PlaceController:IsPlace(PlaceName: string)
	if game.PlaceId == Places[PlaceName] then
		return true
	end
	return false
end

function PlaceController:GetPlaceId(PlaceName: string)
	return Places[PlaceName]
end

function PlaceController:IsTrading()
	return self:IsPlace("Trading")
end

function PlaceController:IsHub()
	return self:IsPlace("Hub")
end

function PlaceController:IsArena()
	return self:IsPlace("Arena")
end

function PlaceController:IsSHURA()
	return self:IsPlace("SHURA")
end

function PlaceController.KnitInit() end

function PlaceController.KnitStart() end

return PlaceController
