return function(Geometry: any): string
	local Checks = 0
	local Triangle = { Vector3.new(-2, -2, 0), Vector3.new(2, -2, 0), Vector3.new(0, 2, 0) }
	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Position(Coordinate: Vector3): Vector3
		return Triangle[1] * Coordinate.X + Triangle[2] * Coordinate.Y + Triangle[3] * Coordinate.Z
	end

	Check(Geometry.IntersectTriangle(Vector3.new(0, 0, -1), Vector3.zAxis * 2, Triangle) == 0.5,
		"Front-facing projectile segments must hit the fabric")
	Check(Geometry.IntersectTriangle(Vector3.new(0, 0, 1), -Vector3.zAxis * 2, Triangle) == 0.5,
		"Back-facing projectile segments must also hit the fabric")
	Check(Geometry.IntersectTriangle(Vector3.new(0, 0, -2), Vector3.zAxis, Triangle) == nil,
		"A cloth beyond the segment endpoint must not be hit")
	Check(Geometry.IntersectTriangle(Vector3.new(3, 0, -1), Vector3.zAxis * 2, Triangle) == nil,
		"A near miss must not make a hole")
	Check(Geometry.IntersectTriangle(Vector3.zero, Vector3.xAxis, Triangle) == nil,
		"Parallel segments must not divide by zero")
	Check(Geometry.CutTriangle(Triangle, Vector3.new(10, 0, 0), Vector3.zAxis, 0.4) == nil,
		"Triangles outside a hole must stay untouched")

	local Radius = 0.4
	local Polygons = Geometry.CutTriangle(Triangle, Vector3.zero, Vector3.zAxis, Radius)
	Check(Polygons ~= nil and #Polygons > 0, "A hole inside a coarse triangle must preserve the surrounding fabric")
	local Area = 0
	for _, Polygon in Polygons do
		for Index = 2, #Polygon - 1 do
			local A, B, C = Position(Polygon[1]), Position(Polygon[Index]), Position(Polygon[Index + 1])
			Area += (B - A):Cross(C - A).Magnitude * 0.5
			Check(Geometry.IntersectTriangle(Vector3.new(0, 0, -1), Vector3.zAxis * 2, { A, B, C }) == nil,
				"No generated triangle may fill the center of the hole")
		end
		for _, Coordinate in Polygon do
			Check(math.abs(Coordinate.X + Coordinate.Y + Coordinate.Z - 1) < 1e-5,
				"Clipping must retain normalized barycentric weights for skinning and textures")
		end
	end

	local HoleArea = 12 * Radius * Radius * math.sin(math.pi * 2 / 12) * 0.5
	Check(math.abs(Area - (8 - HoleArea)) < 1e-4,
		"The cut must remove only the hole area without overlapping or losing surrounding fabric")
	local Complete = Geometry.CutTriangle(Triangle, Vector3.zero, Vector3.zAxis, 10)
	Check(Complete ~= nil and #Complete == 0, "A completely covered triangle must disappear")

	local Blade = { Vector3.new(-3, 0, -1), Vector3.new(3, 0, -1), Vector3.new(3, 0, 1) }
	local Start, Finish = Geometry.IntersectTriangles(Triangle, Blade)
	Check(Start ~= nil and Finish ~= nil and (Finish - Start).Magnitude > 0.5,
		"A blade swept across fabric must produce an intersection segment")
	Check(math.abs(Start.Z) < 1e-5 and math.abs(Finish.Y) < 1e-5,
		"The slash must lie on both the blade surface and the fabric")
	local Slit = Geometry.CutTriangleAlongSegment(Triangle, Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0), 0.06)
	Check(Slit ~= nil and #Slit > 0, "A sword must leave fabric on both sides of its slit")
	local SlitArea = 0
	local OutsidePreserved = false
	for _, Polygon in Slit do
		for Index = 2, #Polygon - 1 do
			local A, B, C = Position(Polygon[1]), Position(Polygon[Index]), Position(Polygon[Index + 1])
			SlitArea += (B - A):Cross(C - A).Magnitude * 0.5
			Check(Geometry.IntersectTriangle(Vector3.new(0, 0, -1), Vector3.zAxis * 2, { A, B, C }) == nil,
				"The sword slit must be open through the mesh")
			OutsidePreserved = OutsidePreserved or Geometry.IntersectTriangle(Vector3.new(0, 1, -1), Vector3.zAxis * 2, { A, B, C }) ~= nil
		end
	end
	Check(math.abs(SlitArea - 7.88) < 1e-4 and OutsidePreserved,
		"A slash must remove only a thin strip and preserve nearby fabric")
	Check(Geometry.CutTriangleAlongSegment(Triangle, Vector3.zero, Vector3.zero, 0.06) == nil,
		"A stationary blade must not cut fabric")

	local function MeshFromPolygons(Pieces: { { Vector3 } }): ({ [number]: { number } }, { [number]: Vector3 })
		local Faces, Positions = {}, {}
		local NextVertex = 0
		for _, Polygon in Pieces do
			for Index = 2, #Polygon - 1 do
				local Face = {}
				for _, Coordinate in { Polygon[1], Polygon[Index], Polygon[Index + 1] } do
					NextVertex += 1
					Positions[NextVertex] = Position(Coordinate)
					table.insert(Face, NextVertex)
				end
				table.insert(Faces, Face)
			end
		end
		return Faces, Positions
	end

	local RingFaces, RingPositions = MeshFromPolygons(Polygons)
	Check(#Geometry.GetConnectedComponents(RingFaces, RingPositions) == 1,
		"A hole's surrounding triangles must stay connected despite duplicate vertex IDs")
	local SlitFaces, SlitPositions = MeshFromPolygons(Slit)
	Check(#Geometry.GetConnectedComponents(SlitFaces, SlitPositions) == 2,
		"A real slit must produce two separate pieces without welding across the gap")
	local TJunctionFaces = { { 1, 2, 3 }, { 4, 5, 6 } }
	local TJunctionPositions = {
		Vector3.new(0, 0, 0), Vector3.new(4, 0, 0), Vector3.new(0, 2, 0),
		Vector3.new(1, 0, 0), Vector3.new(2, 0, 0), Vector3.new(1, -1, 0),
	}
	Check(#Geometry.GetConnectedComponents(TJunctionFaces, TJunctionPositions) == 1,
		"A subdivided edge must connect to an unsplit neighboring edge")
	Check(#Geometry.GetConnectedComponents(TJunctionFaces, TJunctionPositions, { 1, 2 }) == 2,
		"Independent original panels must retain their separate identities")
	Check(#Geometry.GetConnectedComponents({}, {}) == 0, "An empty cloth must have no fragments")

	local Coordinate = Geometry.Barycentric((Triangle[1] + Triangle[2] + Triangle[3]) / 3, Triangle)
	Check(Coordinate ~= nil and (Coordinate - Vector3.one / 3).Magnitude < 1e-5,
		"Captured cuts must map back to their original material coordinates")
	Check(Geometry.Barycentric(Vector3.zero, { Vector3.zero, Vector3.zero, Vector3.zero }) == nil,
		"Degenerate triangles must not produce invalid material coordinates")
	local Pieces = { { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis } }
	for _, Y in { -0.5, 0.5 } do
		local Remaining = {}
		for _, Polygon in Pieces do
			local Cut = Geometry.CutPolygonAlongSegment(Polygon, Triangle, Vector3.new(-3, Y, 0), Vector3.new(3, Y, 0), 0.06)
			if Cut then
				for _, Piece in Cut do
					table.insert(Remaining, Piece)
				end
			else
				table.insert(Remaining, Polygon)
			end
		end
		Pieces = Remaining
	end
	local BatchFaces, BatchPositions = MeshFromPolygons(Pieces)
	Check(#Geometry.GetConnectedComponents(BatchFaces, BatchPositions) == 3,
		"Multiple recorded strokes must be subtracted together without filling an earlier slit")

	return string.format("Cloth geometry: %d checks passed", Checks)
end
