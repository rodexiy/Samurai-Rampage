local Bandage = {}

local Knit = require(game.ReplicatedStorage.Packages.Knit)
local InventoryService = Knit.GetService("InventoryService")
local DebounceService = Knit.GetService("DebounceService")
local AlertService = Knit.GetService("AlertService")

local Players = game:GetService("Players")

local StaminaRegen = 10

function Bandage.Activated(Character: Model, Data: { any })
	local Player = Players:GetPlayerFromCharacter(Character)

	if Character:GetAttribute("BlueberryDebounce") then
		AlertService:AlertPlayer(Player, "Blueberry is on cooldown!")
		return
	end

	DebounceService:AddDebounce(Character, "BlueberryDebounce", 2.5)

	if Player then
		InventoryService:RemoveItemFromPlayer(Player, "Blueberry", 1)
	end

	Character:SetAttribute(
		"Stamina",
		math.min(Character:GetAttribute("Stamina") + StaminaRegen, Character:GetAttribute("MaxStamina"))
	)
end

return Bandage
