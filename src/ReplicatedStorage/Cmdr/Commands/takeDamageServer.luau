local Knit = require(game.ReplicatedStorage.Packages.Knit)

return function(Context, Amount: number)
	local Player = Context.Executor
	local Character = Player and Player.Character
	if not Character then
		return "No character found."
	end

	Amount = math.max(0, Amount)
	if Amount <= 0 then
		return "Damage amount must be greater than 0."
	end

	local DamageService = Knit.GetService("DamageService")
	local HadForceField = Character:GetAttribute("ForceField")
	Character:SetAttribute("ForceField", false)
	DamageService:DealDamage(Character, Amount)
	Character:SetAttribute("ForceField", HadForceField)

	return string.format("Took %s damage.", Amount)
end
