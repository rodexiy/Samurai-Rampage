local Players = game:GetService("Players")
local Knit = require(game.ReplicatedStorage.Packages.Knit)

local RaceService = Knit.CreateService({
	Name = "RaceService",
	Client = {},
})

local RewardService
local SkillService
local DataService

local Races = require(game.ReplicatedStorage.Shared.Index.Races)
local RaceAssets = game.ReplicatedStorage.Assets.Races

function RaceService:GetRaceModel(Character: Model)
	local RaceName = Character:GetAttribute("Race")
	local RaceVariant = Character:GetAttribute("RaceVariant")
	if not RaceName or not RaceVariant then
		return
	end

	local Race = RaceAssets:FindFirstChild(RaceName)
	if not Race then
		return
	end

	return Race:FindFirstChild(RaceVariant)
end

function RaceService:LoadRaceAssets(Character: Model)
	local Player = Players:GetPlayerFromCharacter(Character)
	if Player then
		SkillService:LoadSkills(Player)
	end
end

function RaceService:RollRandomRace(Player: Player)
	local Race = RewardService:GetRandomRewardFromWeight(Races)

	DataService:GetData(Player).Race = Race
	RaceService:RollRandomVariant(Player)

	local Character = Player.Character
	if Character then
		if Character:GetAttribute("Race") then
			Character:SetAttribute("OldRace", Character:GetAttribute("Race"))
		end
		Character:SetAttribute("Race", Race)

		self:LoadRaceAssets(Character)
	end

	return Race
end

function RaceService:RollRandomVariant(Player: Player)
	local Character = Player.Character
	local PlayerData = DataService:GetData(Player)

	local Race = PlayerData.Race
	local Assets = RaceAssets:FindFirstChild(Race)
	if Assets then
		local Variants = Assets:GetChildren()
		local Variant = Variants[math.random(1, #Variants)]

		PlayerData.RaceVariant = Variant.Name

		if Character then
			Character:SetAttribute("RaceVariant", Variant.Name)
		end
	end
end

function RaceService:GetRaceData(RaceName: string)
	return Races[RaceName]
end

function RaceService.KnitInit()
	RewardService = Knit.GetService("RewardService")
	DataService = Knit.GetService("DataService")
	SkillService = Knit.GetService("SkillService")
end

function RaceService.KnitStart() end

return RaceService
