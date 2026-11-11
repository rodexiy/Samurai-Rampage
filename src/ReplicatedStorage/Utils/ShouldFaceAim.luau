return function(Character: Model): boolean
	if Character:GetAttribute("BowDrawing") == true then
		return true
	end

	if Character:GetAttribute("WeaponEquipped") == true then
		for _, Attribute in {
			"Attack", "Attacking", "StrongAttack", "ClientAttacking", "ClientStrongAttack", "Blocking", "ClientBlocking",
		} do
			if Character:GetAttribute(Attribute) == true then
				return true
			end
		end
	end

	local Root = Character.PrimaryPart
	local LookAtMouse = Root and Root:FindFirstChild("LookAtMouse") :: AlignOrientation?
	return LookAtMouse ~= nil and LookAtMouse.Enabled
end
