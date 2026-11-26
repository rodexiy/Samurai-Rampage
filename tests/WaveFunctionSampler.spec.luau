return function(WaveFunction: any): string
	local Positions = { Vector3.zero, Vector3.new(32, 0, -71), Vector3.new(-768, 4, 768) }
	local Sample = WaveFunction:CreateDisplacementSampler(Positions)
	local Checks = 0
	local function Near(Actual: Vector3, Expected: Vector3, Message: string)
		assert((Actual - Expected).Magnitude < 0.0001, Message)
		Checks += 1
	end

	for _, Time in { 0, 12.5, 1234, 1000000 } do
		local Values = Sample(Time)
		for Index, Position in Positions do
			Near(Values[Index], WaveFunction:GetDisplacement(Position, Time), "Default sampling preserves the original waves")
		end

		for _, Offset in { Vector3.new(512, 0, 0), Vector3.new(-512, 0, 1024), Vector3.new(0, 3, 0) } do
			local ValuesWithOffset = Sample(Time, nil, Offset)
			for Index, Position in Positions do
				Near(ValuesWithOffset[Index], WaveFunction:GetDisplacement(Position + Offset, Time),
					"Recentering preserves the phase and spatial wave-zone intensity")
			end
		end
	end

	local Previous = Sample(5)[2]
	local Selected = Sample(10, { 3, 1 }, Vector3.new(512, 0, -512))
	Near(Selected[2], Previous, "Unselected bones are not resampled")
	Near(Selected[1], WaveFunction:GetDisplacement(Positions[1] + Vector3.new(512, 0, -512), 10),
		"Sparse sampling keeps the original bone indices")
	Near(Selected[3], WaveFunction:GetDisplacement(Positions[3] + Vector3.new(512, 0, -512), 10),
		"Sparse sampling supports a reordered selection")
	local Saved = Selected[1]
	Near(Sample(20, {})[1], Saved, "An empty selection leaves existing displacements untouched")
	assert(Selected == Sample(21), "Sampling reuses its output array")
	Checks += 1

	return string.format("WaveFunctionSampler: %d checks passed", Checks)
end
