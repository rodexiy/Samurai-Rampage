return function(Renderer: any, Source: MeshPart, Triangles: { any }): string
	local AssetService = game:GetService("AssetService")
	local Visual = Renderer.Build(Source, Renderer.Read(Source), Triangles)
	local Scale = Source.Size / Source.MeshSize
	local Checks, Index = 0, 0
	local Success, Error = pcall(function()
		for _, Interior in { false, true } do
			local ExpectedMin = Vector3.new(math.huge, math.huge, math.huge)
			local ExpectedMax = -ExpectedMin
			local Count = 0
			for _, Triangle in Triangles do
				if Triangle.Interior ~= Interior then
					continue
				end
				for _, Vertex in Triangle.Vertices do
					local Point = Source.CFrame:PointToWorldSpace(Vertex.Position * Scale)
					ExpectedMin, ExpectedMax = ExpectedMin:Min(Point), ExpectedMax:Max(Point)
					Count += 1
				end
			end
			if Count == 0 then
				continue
			end
			Index += 1
			local Part = Visual.Parts[Index]
			assert(Part, "Missing rendered mesh")
			local Mesh = AssetService:CreateEditableMeshAsync(Part.MeshContent)
			assert(Mesh, "Could not inspect the rendered mesh")
			local RenderedMin = Vector3.new(math.huge, math.huge, math.huge)
			local RenderedMax = -RenderedMin
			local RenderScale = Part.Size / Part.MeshSize
			for _, Vertex in Mesh:GetVertices() do
				local Point = Part.CFrame:PointToWorldSpace(Mesh:GetPosition(Vertex) * RenderScale)
				RenderedMin, RenderedMax = RenderedMin:Min(Point), RenderedMax:Max(Point)
			end
			Mesh:Destroy()
			assert((RenderedMin - ExpectedMin).Magnitude < 0.005, "Frozen mesh shifted or stretched its lower bounds")
			assert((RenderedMax - ExpectedMax).Magnitude < 0.005, "Frozen mesh shifted or stretched its upper bounds")
			assert((Part:GetPivot().Position - Source:GetPivot().Position).Magnitude < 0.005, "Changed the tree pivot")
			Checks += 3
		end
	end)
	Renderer.Destroy(Visual)
	assert(Success, Error)

	return tostring(Checks) .. " rendered tree mesh checks passed"
end
