return function(Model: Model): number
	local mass = 0
	for _, part: BasePart in Model:QueryDescendants("BasePart") do
		if not part.Anchored and not part.Massless then
			mass += part:GetMass()
		end
	end
	return mass
end
