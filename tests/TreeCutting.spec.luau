return function(Math: any, Geometry: any): string
	local Checks = 0
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Vertex(Point: Vector3): any
		return {
			Position = Point,
			Normal = Point.Unit,
			UV = Vector2.new((Point.X + 2) / 4, (Point.Z + 2) / 4),
			Color = Color3.new(1, 1, 1),
			Alpha = 1,
		}
	end

	local Cube = {}
	for _, Face in
		{
			{ Vector3.new(-2, -2, -2), Vector3.new(-2, -2, 2), Vector3.new(-2, 2, 2), Vector3.new(-2, 2, -2) },
			{ Vector3.new(2, -2, -2), Vector3.new(2, 2, -2), Vector3.new(2, 2, 2), Vector3.new(2, -2, 2) },
			{ Vector3.new(-2, -2, -2), Vector3.new(2, -2, -2), Vector3.new(2, -2, 2), Vector3.new(-2, -2, 2) },
			{ Vector3.new(-2, 2, -2), Vector3.new(-2, 2, 2), Vector3.new(2, 2, 2), Vector3.new(2, 2, -2) },
			{ Vector3.new(-2, -2, -2), Vector3.new(-2, 2, -2), Vector3.new(2, 2, -2), Vector3.new(2, -2, -2) },
			{ Vector3.new(-2, -2, 2), Vector3.new(2, -2, 2), Vector3.new(2, 2, 2), Vector3.new(-2, 2, 2) },
		}
	do
		for Index = 2, 3 do
			table.insert(
				Cube,
				{ Vertices = { Vertex(Face[1]), Vertex(Face[Index]), Vertex(Face[Index + 1]) }, Interior = false }
			)
		end
	end

	local function Contains(Triangles: { any }, Point: Vector3): boolean
		local Direction = Vector3.new(1, 0.137, 0.313).Unit
		local Distances = {}
		for _, Triangle in Triangles do
			local A, B, C = Triangle.Vertices[1].Position, Triangle.Vertices[2].Position, Triangle.Vertices[3].Position
			local AB, AC = B - A, C - A
			local P = Direction:Cross(AC)
			local Determinant = AB:Dot(P)
			if math.abs(Determinant) < 0.000001 then
				continue
			end
			local Offset = Point - A
			local U = Offset:Dot(P) / Determinant
			local Q = Offset:Cross(AB)
			local V = Direction:Dot(Q) / Determinant
			local Distance = AC:Dot(Q) / Determinant
			if U >= 0 and V >= 0 and U + V <= 1 and Distance > 0.000001 then
				local Duplicate = false
				for _, Previous in Distances do
					if math.abs(Previous - Distance) < 0.00001 then
						Duplicate = true
					end
				end
				if not Duplicate then
					table.insert(Distances, Distance)
				end
			end
		end

		return #Distances % 2 == 1
	end

	Check(Math.GetMaxHits(0.5) == 3 and Math.GetMaxHits(30) == 6, "Clamp resistance between 3 and 6 hits")
	local Previous = 0
	for Diameter = 1, 20 do
		local Hits = Math.GetMaxHits(Diameter)
		Check(Hits >= Previous, "Thicker trees cannot require fewer hits")
		Previous = Hits
	end
	for MaxHits = 3, 6 do
		local LastDepth, LastHeight, LastWidth = 0, 0, 0
		for Hit = 1, MaxHits - 1 do
			local Depth = Math.GetDepth(2, 0.3, Hit, MaxHits)
			local Height, Width = Math.GetOpening(2, Hit, MaxHits)
			Check(
				Depth > LastDepth and Height > LastHeight and Width > LastWidth,
				"Every visible hit enlarges the notch"
			)
			Check(Depth <= 1.7, "Keep wood connected until the final hit")
			LastDepth, LastHeight, LastWidth = Depth, Height, Width
		end
	end

	local OpenCube = {}
	for _, Triangle in Cube do
		local Bottom = true
		for _, V in Triangle.Vertices do
			if V.Position.Y ~= -2 then
				Bottom = false
			end
		end
		if not Bottom then
			table.insert(OpenCube, Triangle)
		end
	end
	Check(#Geometry.GetBoundaryLoops(OpenCube) == 1, "Recognize an open trunk bottom")
	local Sealed = Geometry.SealBoundaries(OpenCube)
	Check(#Geometry.GetBoundaryLoops(Sealed) == 0, "Close the bottom without editing the asset")
	local BottomFaces = 0
	for _, Triangle in Sealed do
		if Triangle.Interior and Triangle.Vertices[1].Normal.Y < -0.9 then
			BottomFaces += 1
		end
	end
	Check(BottomFaces == 2, "Create outward-facing wood faces on the bottom")
	local OpenTube = {}
	for _, Triangle in OpenCube do
		local Top = true
		for _, V in Triangle.Vertices do
			if V.Position.Y ~= 2 then
				Top = false
			end
		end
		if not Top then
			table.insert(OpenTube, Triangle)
		end
	end
	local BaseOnly = Geometry.SealBoundaries(OpenTube, function(Loop: { Vector3 }): boolean
		for _, Point in Loop do
			if Point.Y > -1.9 then
				return false
			end
		end
		return true
	end)
	Check(#Geometry.GetBoundaryLoops(BaseOnly) == 1, "Do not close distant branch ends when sealing the base")

	local Cut =
		{ Center = Vector3.zero, Direction = Vector3.xAxis, Radius = 2, Core = 0.5, Depth = 1.4, Width = 5, Height = 1 }
	local Localized = Geometry.Subtract(BaseOnly, Math.GetCutPlanes(Cut))
	for _, Triangle in Localized do
		if Triangle.Interior then
			local Bottom = true
			for _, V in Triangle.Vertices do
				if V.Position.Y > -1.9 then
					Bottom = false
				end
			end
			if not Bottom then
				for _, V in Triangle.Vertices do
					for _, Plane in Math.GetCutPlanes(Cut) do
						Check(
							Plane.Normal:Dot(V.Position) <= Plane.Distance + 0.001,
							"All new faces stay inside the notch"
						)
					end
				end
			end
		end
	end
	local TopStillOpen = false
	for _, Loop in Geometry.GetBoundaryLoops(Localized) do
		local AtTop = true
		for _, Point in Loop do
			if math.abs(Point.Y - 2) > 0.001 then
				AtTop = false
			end
		end
		if AtTop then
			TopStillOpen = true
		end
	end
	Check(TopStillOpen, "A local cut must not add wood caps at the top of the trunk")
	local Carved = Geometry.Subtract(Cube, Math.GetCutPlanes(Cut))
	Check(not Contains(Carved, Vector3.new(1.8, 0.03, 0.07)), "Remove real wood at the mouth of the V")
	Check(Contains(Carved, Vector3.new(1.8, 1, 0.07)), "Preserve wood above the V")
	Check(Contains(Carved, Vector3.zero), "Preserve the central connection")
	Cut.Direction = -Vector3.xAxis
	Carved = Geometry.Subtract(Carved, Math.GetCutPlanes(Cut))
	Check(not Contains(Carved, Vector3.new(-1.8, 0.03, 0.07)), "Allow a second cut on the opposite side")
	for Index = 1, 12 do
		local Point = Math.GetDirection(Index) * 0.4 + Vector3.new(0, 0.03, 0)
		Check(Contains(Carved, Point), "Opposing cuts must leave the core connected")
	end

	local Interior = 0
	for _, Triangle in Carved do
		if Triangle.Interior then
			Interior += 1
		end
		for _, V in Triangle.Vertices do
			Check(V.UV.X == V.UV.X and V.Normal.Magnitude > 0.9, "Generate finite UVs and normals")
		end
	end
	Check(Interior > 0, "Close the cut with interior faces")

	local Upper = Geometry.KeepInside(Carved, { Normal = -Vector3.yAxis, Distance = 0 })
	local Lower = Geometry.KeepInside(Carved, { Normal = Vector3.yAxis, Distance = 0 })
	Check(
		Contains(Upper, Vector3.new(0, 1, 0)) and not Contains(Upper, Vector3.new(0, -1, 0)),
		"Separate the upper trunk"
	)
	Check(Contains(Lower, Vector3.new(0, -1, 0)) and not Contains(Lower, Vector3.new(0, 1, 0)), "Separate the stump")

	local Origin = CFrame.new(5, 10, 20)
	local Pivot = Vector3.new(5, 0, 20)
	local Fallen = Math.GetFallPivot(Origin, Pivot, Vector3.xAxis, math.pi * 0.5, 1)
	Check((Fallen.Position - Vector3.new(5, 0, 30)).Magnitude < 0.001, "Fall toward the damaged side around the cut")

	return tostring(Checks) .. " tree cutting checks passed"
end
