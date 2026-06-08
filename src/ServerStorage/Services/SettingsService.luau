local Knit = require(game.ReplicatedStorage.Packages.Knit)

local SettingsService = Knit.CreateService({
	Name = "SettingsService",
	Client = {},
})

local DataService
local ProfileTemplate = require(script.Parent.Data.ProfileTemplate)

local function ReconcileSettings(PlayerData)
	PlayerData.Settings = PlayerData.Settings or {}

	for SettingName, SettingValue in ProfileTemplate.Settings do
		if PlayerData.Settings[SettingName] == nil then
			PlayerData.Settings[SettingName] = SettingValue
		end
	end
end

function SettingsService:LoadSettings(Player: Player)
	local PlayerData = DataService:GetData(Player)
	ReconcileSettings(PlayerData)

	for SettingName, SettingValue in PlayerData.Settings do
		Player:SetAttribute(SettingName, SettingValue)
	end
end

function SettingsService:Toggle(Player: Player, Setting: string)
	local PlayerData = DataService:GetData(Player)
	ReconcileSettings(PlayerData)
	if PlayerData.Settings[Setting] == nil then
		return
	end

	PlayerData.Settings[Setting] = not PlayerData.Settings[Setting]
	Player:SetAttribute(Setting, PlayerData.Settings[Setting])
end

function SettingsService.Client:Toggle(Player: Player, Setting: string)
	self.Server:Toggle(Player, Setting)
end

function SettingsService:GetSettings(Player: Player)
	local PlayerData = DataService:GetData(Player)
	ReconcileSettings(PlayerData)

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
