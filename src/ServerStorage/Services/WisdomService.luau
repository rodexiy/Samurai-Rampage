local Knit = require(game.ReplicatedStorage.Packages.Knit)

local WisdomService = Knit.CreateService({
	Name = "WisdomService",
	Client = {
		WisdomUpdated = Knit.CreateSignal(),
	},
})

local DataService

local MAX_WISDOM = 200

function WisdomService:UpdateWisdom(Player: Player, Amount: number)
	Player:SetAttribute("Wisdom", Amount)
	WisdomService.Client.WisdomUpdated:Fire(Player, Amount)
end

function WisdomService:LoadAttributes(Player: Player)
	local PlayerData = DataService:GetData(Player)
	if not PlayerData then
		return
	end

	PlayerData.Wisdom = math.clamp(PlayerData.Wisdom or 0, 0, MAX_WISDOM)
	WisdomService:UpdateWisdom(Player, PlayerData.Wisdom)
end

function WisdomService:AddWisdom(Player: Player, Amount: number): number
	local PlayerData = DataService:GetData(Player)
	if not PlayerData then
		return 0
	end

	Amount = math.max(0, math.floor(Amount or 0))
	if Amount <= 0 then
		return PlayerData.Wisdom or 0
	end

	PlayerData.Wisdom = math.clamp((PlayerData.Wisdom or 0) + Amount, 0, MAX_WISDOM)
	WisdomService:UpdateWisdom(Player, PlayerData.Wisdom)

	return PlayerData.Wisdom
end

function WisdomService:SetWisdom(Player: Player, Amount: number): number
	local PlayerData = DataService:GetData(Player)
	if not PlayerData then
		return 0
	end

	PlayerData.Wisdom = math.clamp(math.floor(Amount or 0), 0, MAX_WISDOM)
	WisdomService:UpdateWisdom(Player, PlayerData.Wisdom)

	return PlayerData.Wisdom
end

function WisdomService:GetWisdom(Player: Player): number
	local PlayerData = DataService:GetData(Player)
	if not PlayerData then
		return 0
	end

	return PlayerData.Wisdom or 0
end

function WisdomService.Client:GetWisdom(Player: Player): number
	return self.Server:GetWisdom(Player)
end

function WisdomService.KnitInit()
	DataService = Knit.GetService("DataService")
end

return WisdomService
