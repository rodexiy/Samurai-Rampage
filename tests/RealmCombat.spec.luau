-- Run with fresh copies of the production shared validation and ranged config.
return function(Validate: any, BowConfig: any): string
	local Checks = 0
	local Character = Instance.new("Model")
	local Root = Instance.new("Part")
	Root.Parent = Character
	Character.PrimaryPart = Root
	local Humanoid = Instance.new("Humanoid")
	Humanoid.Parent = Character
	Character.Parent = Instance.new("Folder")
	Character:SetAttribute("Weapon", "Katana")
	Character:SetAttribute("WeaponEquipped", true)
	Character:SetAttribute("Stamina", 100)
	Character:SetAttribute("SwordStaminaCost", 1)

	local function Check(Value: boolean, Message: string)
		assert(Value, Message)
		Checks += 1
	end

	local Success, Error = pcall(function()
		for _, Method in { "CanEquipWeapon", "CanAttack", "CanStrongAttack", "CanBlock", "CanRoll", "CanUseSkill" } do
			Check(Validate[Method](Validate, Character, 0) == true, `{Method} should work before editing`)
			Character:SetAttribute("RealmEditing", true)
			Check(Validate[Method](Validate, Character, 0) == false, `{Method} must reject Realm editing`)
			Character:SetAttribute("Stunless", true)
			Check(Validate[Method](Validate, Character, 0) == false, `{Method} must reject editing even with Stunless`)
			Character:SetAttribute("Stunless", nil)
			Character:SetAttribute("RealmEditing", false)
			Check(Validate[Method](Validate, Character, 0) == true, `{Method} should recover after editing`)
		end

		Character:SetAttribute("WeaponEquipped", false)
		Check(BowConfig.CanUse(Character), "Ranged weapons should work before editing")
		Character:SetAttribute("RealmEditing", true)
		Check(not BowConfig.CanUse(Character), "Ranged weapons must reject Realm editing")
		Character:SetAttribute("RealmEditing", false)
		Check(BowConfig.CanUse(Character), "Ranged weapons should recover after editing")
	end)

	local Container = Character.Parent
	Character:Destroy()
	Container:Destroy()
	assert(Success, Error)

	return `RealmCombat: {Checks} checks passed`
end
