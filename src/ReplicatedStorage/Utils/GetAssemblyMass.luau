return function(Model: Model): number
	local Mass = 0
	local Assemblies: { [BasePart]: boolean } = {}

	for _, Part: BasePart in Model:QueryDescendants("BasePart") do
		local Root = Part.AssemblyRootPart or Part
		if Root.Anchored or Assemblies[Root] then
			continue
		end

		Assemblies[Root] = true
		local AssemblyMass = Root.AssemblyMass
		if AssemblyMass > 0 and AssemblyMass < math.huge then
			Mass += AssemblyMass
		end
	end

	return Mass
end
