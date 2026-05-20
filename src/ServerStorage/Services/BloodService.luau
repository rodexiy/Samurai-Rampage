local Knit = require(game.ReplicatedStorage.Packages.Knit)

local BloodService = Knit.CreateService({
	Name = "BloodService",
	Client = {},
})

function BloodService:GetBlades(Character: Model)
	local Assets = Character.Assets
	local WeaponFolder = Assets.Weapon
	local Weapon = WeaponFolder:FindFirstChild("Weapon")
	if not Weapon then
		return
	end

	local Blades = {}
	for _, Part in Weapon:GetDescendants() do
		if Part.Name == "Blade" and Part:IsA("BasePart") then
			table.insert(Blades, Part)
		end
	end

	return Blades
end

function BloodService:ApplyBloodOnBlade(Character: Model)
	local Blades = self:GetBlades(Character)
	if not Blades then
		return
	end

	for _, Blade in Blades do
		for _, _Blood in game.ReplicatedStorage.Assets.VFX.SwordBlood["1"]:GetChildren() do
			local Blood = _Blood:Clone()
			Blood.Parent = Blade
		end
	end
end

function BloodService:RemoveBloodFromBlade(Character: Model)
	local Blades = self:GetBlades(Character)
	if not Blades then
		return
	end

	for _, Blade in Blades do
		for _, Blood in Blade:GetChildren() do
			if Blood.Name == "Blood" then
				Blood:Destroy()
			end
		end
	end
end

function BloodService.KnitInit() end

function BloodService.KnitStart() end

return BloodService
