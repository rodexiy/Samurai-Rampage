local Bandage = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local InventoryService = Knit.GetService("InventoryService")
local DebounceService = Knit.GetService("DebounceService")
local AlertService = Knit.GetService("AlertService")

local Players = game:GetService("Players")

local HealtRegen = 5

function Bandage.Activated(Character: Model, _Data: { any })
	local Player = Players:GetPlayerFromCharacter(Character)

	if Character:GetAttribute("AppleDebounce") then
		AlertService:AlertPlayer(Player, "Apple is on cooldown!")
		return
	end

	DebounceService:AddDebounce(Character, "AppleDebounce", 2.5)

	if Player then
		InventoryService:ConsumeToolItem(Player, "Apple", 1)
	end

	Character:SetAttribute(
		"Health",
		math.min(Character:GetAttribute("Health") + HealtRegen, Character:GetAttribute("MaxHealth"))
	)
end

return Bandage
