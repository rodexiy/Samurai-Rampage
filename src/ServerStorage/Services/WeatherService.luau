local Knit = require(game.ReplicatedStorage.Packages.Knit)

local WeatherService = Knit.CreateService({
	Name = "WeatherService",
	Client = {},
})

function WeatherService:BindWeather()
	workspace:SetAttribute("WeatherRandomFactor", math.random(1, 99999))
end

function WeatherService.KnitInit() end

function WeatherService.KnitStart()
	WeatherService:BindWeather()
end

return WeatherService
