local ClothGeometry = {}

local EPSILON = 1e-7
local HOLE_SIDES = 12

export type Polygon = { Vector3 } -- Barycentric coordinates in the original triangle.
export type Component = { Faces: { number }, Area: number }

local CONNECTION_TOLERANCE = 1e-5

local function Point(Weights: Vector3, Triangle: { Vector3 }): Vector3
	return Triangle[1] * Weights.X + Triangle[2] * Weights.Y + Triangle[3] * Weights.Z
end

local function Clip(Polygon: Polygon, Triangle: { Vector3 }, Center: Vector3,
	Normal: Vector3, Limit: number, Inside: boolean): Polygon
	local Result: Polygon = {}
	local Previous = Polygon[#Polygon]
	if not Previous then
		return Result
	end

	local PreviousDistance = (Point(Previous, Triangle) - Center):Dot(Normal) - Limit
	for _, Current in Polygon do
		local Distance = (Point(Current, Triangle) - Center):Dot(Normal) - Limit
		local PreviousInside = if Inside then PreviousDistance <= 0 else PreviousDistance >= 0
		local CurrentInside = if Inside then Distance <= 0 else Distance >= 0
		if PreviousInside ~= CurrentInside then
			local Alpha = PreviousDistance / (PreviousDistance - Distance)
			table.insert(Result, Previous:Lerp(Current, Alpha))
		end

		if CurrentInside then
			table.insert(Result, Current)
		end

		Previous = Current
		PreviousDistance = Distance
	end

	return Result
end

function ClothGeometry.SegmentDistanceSquared(Origin: Vector3, Displacement: Vector3, PointPosition: Vector3): number
	local LengthSquared = Displacement:Dot(Displacement)
	local Alpha = if LengthSquared > EPSILON
		then math.clamp((PointPosition - Origin):Dot(Displacement) / LengthSquared, 0, 1) else 0
	local Offset = PointPosition - (Origin + Displacement * Alpha)

	return Offset:Dot(Offset)
end

function ClothGeometry.IntersectTriangle(Origin: Vector3, Displacement: Vector3, Triangle: { Vector3 }): number?
	local Edge1 = Triangle[2] - Triangle[1]
	local Edge2 = Triangle[3] - Triangle[1]
	local Cross = Displacement:Cross(Edge2)
	local Determinant = Edge1:Dot(Cross)
	if math.abs(Determinant) < EPSILON then
		return nil
	end

	local Offset = Origin - Triangle[1]
	local U = Offset:Dot(Cross) / Determinant
	if U < -EPSILON or U > 1 + EPSILON then
		return nil
	end

	local Q = Offset:Cross(Edge1)
	local V = Displacement:Dot(Q) / Determinant
	if V < -EPSILON or U + V > 1 + EPSILON then
		return nil
	end

	local Alpha = Edge2:Dot(Q) / Determinant
	return if Alpha >= -EPSILON and Alpha <= 1 + EPSILON then math.clamp(Alpha, 0, 1) else nil
end

local function Subtract(Triangle: { Vector3 }, Center: Vector3,
	Planes: { { Normal: Vector3, Limit: number } }, Initial: Polygon?): { Polygon }?
	local Remaining: Polygon = Initial or { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }
	local Outside: { Polygon } = {}

	for _, Plane in Planes do
		local Piece = Clip(Remaining, Triangle, Center, Plane.Normal, Plane.Limit, false)
		if #Piece >= 3 then
			table.insert(Outside, Piece)
		end

		Remaining = Clip(Remaining, Triangle, Center, Plane.Normal, Plane.Limit, true)
		if #Remaining < 3 then
			return nil
		end
	end

	local Area = Vector3.zero
	local First = Point(Remaining[1], Triangle)
	for Index = 2, #Remaining - 1 do
		Area += (Point(Remaining[Index], Triangle) - First):Cross(Point(Remaining[Index + 1], Triangle) - First)
	end

	return if Area.Magnitude > EPSILON then Outside else nil
end

-- Subtract a polygonal cylinder, keeping barycentric weights for UVs and skinning.
function ClothGeometry.CutTriangle(Triangle: { Vector3 }, Center: Vector3,
	Direction: Vector3, Radius: number): { Polygon }?
	local Reference = if math.abs(Direction.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
	local Tangent = Direction:Cross(Reference).Unit
	local Bitangent = Direction:Cross(Tangent).Unit
	local Planes = {}
	for Index = 0, HOLE_SIDES - 1 do
		local Angle = Index * math.pi * 2 / HOLE_SIDES
		table.insert(Planes, {
			Normal = Tangent * math.cos(Angle) + Bitangent * math.sin(Angle),
			Limit = Radius * math.cos(math.pi / HOLE_SIDES),
		})
	end

	return Subtract(Triangle, Center, Planes)
end

function ClothGeometry.IntersectTriangles(First: { Vector3 }, Second: { Vector3 }): (Vector3?, Vector3?)
	local Points: { Vector3 } = {}
	for _, Pair in { { First, Second }, { Second, First } } do
		for Index = 1, 3 do
			local Start = Pair[1][Index]
			local Displacement = Pair[1][Index % 3 + 1] - Start
			local Alpha = ClothGeometry.IntersectTriangle(Start, Displacement, Pair[2])
			if Alpha then
				table.insert(Points, Start + Displacement * Alpha)
			end
		end
	end

	local A, B
	local Longest = EPSILON
	for Index, PointA in Points do
		for Other = Index + 1, #Points do
			local Distance = (PointA - Points[Other]).Magnitude
			if Distance > Longest then
				Longest = Distance
				A, B = PointA, Points[Other]
			end
		end
	end

	return A, B
end

function ClothGeometry.CutPolygonAlongSegment(Polygon: Polygon, Triangle: { Vector3 }, Start: Vector3,
	Finish: Vector3, Width: number): { Polygon }?
	local Edge = Finish - Start
	local Normal = (Triangle[2] - Triangle[1]):Cross(Triangle[3] - Triangle[1])
	if Edge.Magnitude < EPSILON or Normal.Magnitude < EPSILON then
		return nil
	end

	local Along = Edge.Unit
	local Across = Normal.Unit:Cross(Along).Unit
	local HalfWidth = Width * 0.5
	local Center = (Start + Finish) * 0.5
	return Subtract(Triangle, Center, {
		{ Normal = Across, Limit = HalfWidth },
		{ Normal = -Across, Limit = HalfWidth },
		{ Normal = Along, Limit = Edge.Magnitude * 0.5 + HalfWidth },
		{ Normal = -Along, Limit = Edge.Magnitude * 0.5 + HalfWidth },
	}, Polygon)
end

function ClothGeometry.CutTriangleAlongSegment(Triangle: { Vector3 }, Start: Vector3,
	Finish: Vector3, Width: number): { Polygon }?
	return ClothGeometry.CutPolygonAlongSegment({ Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }, Triangle, Start, Finish, Width)
end

function ClothGeometry.Barycentric(Position: Vector3, Triangle: { Vector3 }): Vector3?
	local A, B, C = Triangle[2] - Triangle[1], Triangle[3] - Triangle[1], Position - Triangle[1]
	local AA, AB, BB, CA, CB = A:Dot(A), A:Dot(B), B:Dot(B), C:Dot(A), C:Dot(B)
	local Denominator = AA * BB - AB * AB
	if math.abs(Denominator) < 1e-12 then
		return nil
	end

	local Y, Z = (BB * CA - AB * CB) / Denominator, (AA * CB - AB * CA) / Denominator
	return Vector3.new(1 - Y - Z, Y, Z)
end

-- Use geometric edges because clipping creates duplicate vertices and T-junctions.
function ClothGeometry.GetConnectedComponents(Faces: { [number]: { number } },
	Positions: { [number]: Vector3 }, Groups: { [number]: number }?): { Component }
	local Parents: { [number]: number } = {}
	local VertexFaces: { [number]: number } = {}
	local Minimum = Vector3.new(math.huge, math.huge, math.huge)
	local Maximum = -Minimum
	local VertexCount = 0
	for Face, Triangle in Faces do
		Parents[Face] = Face
		for _, Id in Triangle do
			if not VertexFaces[Id] then
				VertexCount += 1
				local Position = Positions[Id]
				Minimum = Minimum:Min(Position)
				Maximum = Maximum:Max(Position)
				VertexFaces[Id] = Face
			end
		end
	end
	if VertexCount == 0 then
		return {}
	end

	local function Find(Face: number): number
		local Root = Face
		while Parents[Root] ~= Root do
			Root = Parents[Root]
		end
		while Parents[Face] ~= Face do
			local Parent = Parents[Face]
			Parents[Face] = Root
			Face = Parent
		end
		return Root
	end

	local function Collect(): { Component }
		local Components: { [number]: Component } = {}
		for Face, Triangle in Faces do
			local Root = Find(Face)
			local Component = Components[Root]
			if not Component then
				Component = { Faces = {}, Area = 0 }
				Components[Root] = Component
			end
			table.insert(Component.Faces, Face)
			local A, B, C = Positions[Triangle[1]], Positions[Triangle[2]], Positions[Triangle[3]]
			Component.Area += (B - A):Cross(C - A).Magnitude * 0.5
		end

		local Result: { Component } = {}
		for _, Component in Components do
			table.insert(Result, Component)
		end
		return Result
	end

	local Coincident: { [number]: { [Vector3]: number } } = {}
	for Face, Triangle in Faces do
		local Group = if Groups then Groups[Face] else 1
		local Points = Coincident[Group]
		if not Points then
			Points = {}
			Coincident[Group] = Points
		end
		for _, Id in Triangle do
			local Position = Positions[Id]
			local Other = Points[Position]
			if Other then
				local A, B = Find(Face), Find(Other)
				Parents[math.max(A, B)] = math.min(A, B)
			else
				Points[Position] = Face
			end
		end
	end

	local GroupRoots: { [number]: number } = {}
	local Connected = true
	for Face in Faces do
		local Group = if Groups then Groups[Face] else 1
		local Root = Find(Face)
		if GroupRoots[Group] and GroupRoots[Group] ~= Root then
			Connected = false
			break
		end
		GroupRoots[Group] = Root
	end
	if Connected then
		return Collect()
	end

	local CellSize = math.max((Maximum - Minimum).Magnitude / math.sqrt(VertexCount), CONNECTION_TOLERANCE * 4)
	local Grid: { [Vector3]: { number } } = {}
	for Id in VertexFaces do
		local Position = Positions[Id] / CellSize
		local Cell = Vector3.new(math.floor(Position.X), math.floor(Position.Y), math.floor(Position.Z))
		local Bucket = Grid[Cell]
		if not Bucket then
			Bucket = {}
			Grid[Cell] = Bucket
		end
		table.insert(Bucket, Id)
	end

	local ToleranceSquared = CONNECTION_TOLERANCE * CONNECTION_TOLERANCE
	for Face, Triangle in Faces do
		for Index = 1, 3 do
			local Start = Positions[Triangle[Index]]
			local Edge = Positions[Triangle[Index % 3 + 1]] - Start
			local LengthSquared = Edge:Dot(Edge)
			local Steps = math.max(1, math.ceil(Edge.Magnitude / CellSize))
			local Visited: { [Vector3]: boolean } = {}
			for Step = 0, Steps do
				local Sample = (Start + Edge * (Step / Steps)) / CellSize
				local X, Y, Z = math.floor(Sample.X), math.floor(Sample.Y), math.floor(Sample.Z)
				for DX = -1, 1 do
					for DY = -1, 1 do
						for DZ = -1, 1 do
							local Cell = Vector3.new(X + DX, Y + DY, Z + DZ)
							if Visited[Cell] then
								continue
							end
							Visited[Cell] = true
							local Bucket = Grid[Cell]
							if not Bucket then
								continue
							end
							for _, Id in Bucket do
								local Other = VertexFaces[Id]
								if Other == Face or (Groups and Groups[Face] ~= Groups[Other]) then
									continue
								end
								local Offset = Positions[Id] - Start
								local Alpha = if LengthSquared > ToleranceSquared
									then math.clamp(Offset:Dot(Edge) / LengthSquared, 0, 1) else 0
								local Distance = Offset - Edge * Alpha
								if Distance:Dot(Distance) <= ToleranceSquared then
									local A, B = Find(Face), Find(Other)
									Parents[math.max(A, B)] = math.min(A, B)
								end
							end
						end
					end
				end
			end
		end
	end

	return Collect()
end

return ClothGeometry
