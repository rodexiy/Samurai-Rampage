local Bandage = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)
local InventoryService = Knit.GetService("InventoryService")
local DebounceService = Knit.GetService("DebounceService")
local AlertService = Knit.GetService("AlertService")

local Players = game:GetService("Players")

local HealtRegen = 15

function Bandage.Activated(Character: Model, Data: { any })
	local Player = Players:GetPlayerFromCharacter(Character)

	if Character:GetAttribute("BandageDebounce") then
		AlertService:AlertPlayer(Player, "Bandage is on cooldown!")
		return
	end

	DebounceService:AddDebounce(Character, "BandageDebounce", 10)

	if Player then
		InventoryService:RemoveItemFromPlayer(Player, "Bandage", 1)
	end

	Character:SetAttribute(
		"Health",
		math.min(Character:GetAttribute("Health") + HealtRegen, Character:GetAttribute("MaxHealth"))
	)
end

return Bandage
