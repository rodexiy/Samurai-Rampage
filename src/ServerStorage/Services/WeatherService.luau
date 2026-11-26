local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local WeatherService = Knit.CreateService({
	Name = "WeatherService",
	Client = {
		HumidityChanged = Knit.CreateSignal(),
	},
})

-- Each 30-minute slot independently has a 20% chance of precipitation.
local WEATHER_INTERVAL = 30 * 60
local RAIN_CHANCE = 0.2

local WeatherRandom = Random.new()
local CurrentHumidity = 0.5
local WeatherTimer: thread? = nil

local function changeWeather(IsRaining: boolean)
	if IsRaining then
		CurrentHumidity = WeatherRandom:NextNumber(0.85, 1)
	else
		CurrentHumidity = WeatherRandom:NextNumber(0.25, 0.7)
	end

	workspace:SetAttribute("Humidity", CurrentHumidity)
	WeatherService.Client.HumidityChanged:FireAll(CurrentHumidity)
end

local function checkWeather()
	changeWeather(WeatherRandom:NextNumber() < RAIN_CHANCE)

	WeatherTimer = task.delay(WEATHER_INTERVAL, checkWeather)
end

function WeatherService.Client:GetHumidity(_Player: Player): number
	return CurrentHumidity
end

function WeatherService:BindWeather()
	if WeatherTimer then
		task.cancel(WeatherTimer)
		WeatherTimer = nil
	end

	changeWeather(false)
	WeatherTimer = task.delay(WEATHER_INTERVAL, checkWeather)
end

function WeatherService.KnitInit() end

function WeatherService.KnitStart()
	WeatherService:BindWeather()
end

return WeatherService
