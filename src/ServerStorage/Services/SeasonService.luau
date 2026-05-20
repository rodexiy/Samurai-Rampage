local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local SeasonService = Knit.CreateService({
	Name = "SeasonService",
	Client = {},
})

local CurrentSeason = "Spring"

local Seasons = {
	"Spring",
	"Summer",
	"Autumn",
	"Winter",
}
function SeasonService:GetRandomSeason()
	return Seasons[math.random(1, #Seasons)]
end

function SeasonService:NextSeason()
	local index = table.find(Seasons, CurrentSeason)

	if index then
		index = index + 1
		if index > #Seasons then
			index = 1
		end
		CurrentSeason = Seasons[index]
	end
end




function SeasonService:SetSeason(SeasonName: string)
	CurrentSeason = SeasonName
	workspace:SetAttribute("Season", CurrentSeason)
end

function SeasonService.KnitInit() end

function SeasonService.KnitStart()
	CurrentSeason = SeasonService:GetRandomSeason()

	while true do
		SeasonService:NextSeason()

		workspace:SetAttribute("Season", CurrentSeason)

		task.wait(math.random(30 * 60, 60 * 60))
	end
end

return SeasonService
