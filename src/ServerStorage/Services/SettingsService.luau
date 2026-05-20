local Knit = require(game.ReplicatedStorage.Packages.Knit)

local SettingsService = Knit.CreateService({
	Name = "SettingsService",
	Client = {},
})

local DataService

function SettingsService:LoadSettings(Player: Player)
	local PlayerData = DataService:GetData(Player)
	for SettingName, SettingValue in PlayerData.Settings do
		Player:SetAttribute(SettingName, SettingValue)
	end
end

function SettingsService:Toggle(Player: Player, Setting: string)
	local PlayerData = DataService:GetData(Player)
	PlayerData.Settings[Setting] = not PlayerData.Settings[Setting]
	Player:SetAttribute(Setting, PlayerData.Settings[Setting])
end

function SettingsService.Client:Toggle(Player: Player, Setting: string)
	self.Server:Toggle(Player, Setting)
end

function SettingsService:GetSettings(Player: Player)
	local PlayerData = DataService:GetData(Player)
	return PlayerData.Settings
end

function SettingsService.Client:GetSettings(Player: Player)
	return self.Server:GetSettings(Player)
end

function SettingsService.KnitInit()
	DataService = Knit.GetService("DataService")
end

function SettingsService.KnitStart() end

return SettingsService
