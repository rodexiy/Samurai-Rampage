local Knit = require(game.ReplicatedStorage.Packages.Knit)

local StaminaService = Knit.CreateService({
	Name = "StaminaService",
	Client = {},
})

function StaminaService:RemoveStamina(Character: Model, Amount: number)
	if not Character:GetAttribute("Stamina") then
		return
	end
	Character:SetAttribute(
		"Stamina",
		math.clamp(Character:GetAttribute("Stamina") - Amount, 0, Character:GetAttribute("MaxStamina"))
	)
end
function StaminaService.Client:RemoveStamina(Player: Player, Amount: number)
	local Character = Player.Character
	if Character then
		self.Server:RemoveStamina(Character, Amount)
	end
end

function StaminaService:AddStamina(Character: Model, Amount: number)
	Character:GetAttribute("Stamina")
	Character:SetAttribute(
		"Stamina",
		math.clamp(Character:GetAttribute("Stamina") + Amount, 0, Character:GetAttribute("MaxStamina"))
	)
end

function StaminaService.KnitInit() end

function StaminaService.KnitStart() end

return StaminaService
