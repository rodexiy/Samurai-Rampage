return function(Model: Model): number
	local mass = 0
	for _, part: BasePart in Model:GetDescendants() do
		if part:IsA("BasePart") and not part.Anchored and not part.Massless then
			mass += part.AssemblyMass
		end
	end
	return mass
end
