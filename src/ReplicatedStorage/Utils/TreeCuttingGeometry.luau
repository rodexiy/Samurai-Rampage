-- Triangle clipping has no dependency on the mesh being a valid CSG solid.
local Geometry = {}

export type Vertex = { Position: Vector3, Normal: Vector3, UV: Vector2, Color: Color3, Alpha: number }
export type Triangle = { Vertices: { Vertex }, Interior: boolean }
export type Plane = { Normal: Vector3, Distance: number }

local EPSILON = 0.0001
export type Checkpoint = (() -> ())?

local function Interpolate(A: Vertex, B: Vertex, Alpha: number): Vertex
	local Normal = A.Normal:Lerp(B.Normal, Alpha)
	return {
		Position = A.Position:Lerp(B.Position, Alpha),
		Normal = if Normal.Magnitude > EPSILON then Normal.Unit else A.Normal,
		UV = A.UV:Lerp(B.UV, Alpha),
		Color = A.Color:Lerp(B.Color, Alpha),
		Alpha = A.Alpha + (B.Alpha - A.Alpha) * Alpha,
	}
end

local function ClipPolygon(Polygon: { Vertex }, Plane: Plane, Inside: boolean): { Vertex }
	local Output = {}
	if #Polygon == 0 then
		return Output
	end
	local A = Polygon[#Polygon]
	local ADistance = Plane.Normal:Dot(A.Position) - Plane.Distance
	local Sign = if Inside then 1 else -1

	for _, B in Polygon do
		local BDistance = Plane.Normal:Dot(B.Position) - Plane.Distance
		local AIn, BIn = ADistance * Sign <= 0, BDistance * Sign <= 0
		if AIn ~= BIn then
			table.insert(Output, Interpolate(A, B, ADistance / (ADistance - BDistance)))
		end
		if BIn then
			table.insert(Output, B)
		end
		A, ADistance = B, BDistance
	end

	return Output
end

local function AddPolygon(Output: { Triangle }, Polygon: { Vertex }, Interior: boolean)
	for Index = 2, #Polygon - 1 do
		local A, B, C = Polygon[1], Polygon[Index], Polygon[Index + 1]
		if (B.Position - A.Position):Cross(C.Position - A.Position).Magnitude > EPSILON * EPSILON then
			table.insert(Output, { Vertices = { A, B, C }, Interior = Interior })
		end
	end
end

type Edge = { A: string, B: string }

local function EdgeKey(A: string, B: string): string
	return if A < B then A .. ":" .. B else B .. ":" .. A
end

local function CreateWelder(): ((Vector3) -> string, { [string]: Vector3 })
	local Points: { [string]: Vector3 } = {}
	local Exact: { [Vector3]: string } = {}
	local Buckets: { [number]: { [number]: { [number]: { string } } } } = {}
	local Count = 0

	local function Weld(Point: Vector3): string
		local Cached = Exact[Point]
		if Cached then
			return Cached
		end
		local X, Y, Z = math.floor(Point.X / EPSILON), math.floor(Point.Y / EPSILON), math.floor(Point.Z / EPSILON)
		for DX = -1, 1 do
			local Column = Buckets[X + DX]
			if not Column then
				continue
			end
			for DY = -1, 1 do
				local Row = Column[Y + DY]
				if not Row then
					continue
				end
				for DZ = -1, 1 do
					local Bucket = Row[Z + DZ]
					if Bucket then
						for _, Id in Bucket do
							if (Points[Id] - Point).Magnitude <= EPSILON then
								Exact[Point] = Id
								return Id
							end
						end
					end
				end
			end
		end

		Count += 1
		local Id = tostring(Count)
		Points[Id], Exact[Point] = Point, Id
		Buckets[X] = Buckets[X] or {}
		Buckets[X][Y] = Buckets[X][Y] or {}
		Buckets[X][Y][Z] = Buckets[X][Y][Z] or {}
		table.insert(Buckets[X][Y][Z], Id)
		return Id
	end

	return Weld, Points
end

local function TraceLoops(
	Points: { [string]: Vector3 },
	Edges: { [string]: Edge },
	Directed: boolean,
	Check: Checkpoint
): { { Vector3 } }
	local Adjacent: { [string]: { string } } = {}
	for Key, Edge in Edges do
		if Check then
			Check()
		end
		Adjacent[Edge.A] = Adjacent[Edge.A] or {}
		table.insert(Adjacent[Edge.A], Key)
		if not Directed then
			Adjacent[Edge.B] = Adjacent[Edge.B] or {}
			table.insert(Adjacent[Edge.B], Key)
		end
	end

	local Used: { [string]: boolean } = {}
	local Loops = {}
	for Key, First in Edges do
		if Check then
			Check()
		end
		if Used[Key] then
			continue
		end
		local Start, Current = First.A, First.A
		local NextKey: string? = Key
		local Path = { Start }
		local Visited: { [string]: number } = { [Start] = 1 }
		while NextKey do
			Used[NextKey] = true
			local Edge = Edges[NextKey]
			Current = if Edge.A == Current then Edge.B else Edge.A
			local Repeated = Visited[Current]
			if Repeated then
				local Loop = {}
				for Index = Repeated, #Path do
					table.insert(Loop, Points[Path[Index]])
				end
				if #Loop >= 3 then
					table.insert(Loops, Loop)
				end
				if Current == Start then
					break
				end
				for Index = #Path, Repeated + 1, -1 do
					Visited[Path[Index]] = nil
					table.remove(Path, Index)
				end
			else
				table.insert(Path, Current)
				Visited[Current] = #Path
			end
			NextKey = nil
			for _, Candidate in Adjacent[Current] or {} do
				if not Used[Candidate] then
					NextKey = Candidate
					break
				end
			end
		end
	end

	return Loops
end

local function GetSectionLoops(Triangles: { Triangle }, Plane: Plane, Check: Checkpoint): { { Vector3 } }
	local Weld, Points = CreateWelder()
	local Edges: { [string]: Edge } = {}
	for _, Triangle in Triangles do
		if Check then
			Check()
		end
		local Crossings: { string } = {}
		for Index = 1, 3 do
			local A = Triangle.Vertices[Index].Position
			local B = Triangle.Vertices[Index % 3 + 1].Position
			local DA, DB = Plane.Normal:Dot(A) - Plane.Distance, Plane.Normal:Dot(B) - Plane.Distance
			local Point: Vector3? = nil
			if math.abs(DA) <= EPSILON then
				Point = A
			elseif DA * DB < 0 then
				Point = A:Lerp(B, DA / (DA - DB))
			end
			if Point then
				local Id = Weld(Point)
				if not table.find(Crossings, Id) then
					table.insert(Crossings, Id)
				end
			end
		end
		if #Crossings == 2 then
			local A, B = Crossings[1], Crossings[2]
			Edges[EdgeKey(A, B)] = { A = A, B = B }
		end
	end

	return TraceLoops(Points, Edges, false, Check)
end

function Geometry.GetBoundaryLoops(Triangles: { Triangle }, Check: Checkpoint): { { Vector3 } }
	local Weld, Points = CreateWelder()
	local Edges: { [string]: Edge } = {}
	local Counts: { [string]: number } = {}
	for _, Triangle in Triangles do
		if Check then
			Check()
		end
		for Index = 1, 3 do
			local A = Weld(Triangle.Vertices[Index].Position)
			local B = Weld(Triangle.Vertices[Index % 3 + 1].Position)
			if A == B then
				continue
			end
			local Key = EdgeKey(A, B)
			Counts[Key] = (Counts[Key] or 0) + 1
			-- Reverse the shell edge so the cap faces out of the solid.
			Edges[Key] = { A = B, B = A }
		end
	end
	for Key, Count in Counts do
		if Count ~= 1 then
			Edges[Key] = nil
		end
	end

	return TraceLoops(Points, Edges, true, Check)
end

local function Cross2(A: Vector2, B: Vector2): number
	return A.X * B.Y - A.Y * B.X
end

local function TriangulateLoops(
	Loops: { { Vector3 } },
	SurfaceNormal: Vector3,
	Reverse: boolean,
	Check: Checkpoint
): { Triangle }
	local Axis = if math.abs(SurfaceNormal.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
	local U = SurfaceNormal:Cross(Axis).Unit
	local V = SurfaceNormal:Cross(U)
	local Normal = if Reverse then -SurfaceNormal else SurfaceNormal
	local Output = {}

	for _, Loop in Loops do
		if Check then
			Check()
		end
		local Vertices, Projected = {}, {}
		local Area = 0
		for Index, Point in Loop do
			local UV = Vector2.new(Point:Dot(U), Point:Dot(V))
			Projected[Index] = UV
			Vertices[Index] =
				{ Position = Point, Normal = Normal, UV = UV * 0.2, Color = Color3.new(1, 1, 1), Alpha = 1 }
		end
		for Index, Point in Projected do
			Area += Cross2(Point, Projected[Index % #Projected + 1])
		end
		local Order = {}
		for Index = 1, #Loop do
			Order[Index] = if Area >= 0 then Index else #Loop - Index + 1
		end

		while #Order >= 3 do
			local Found = false
			for Index, BIndex in Order do
				if Check then
					Check()
				end
				local AIndex = Order[(Index - 2) % #Order + 1]
				local CIndex = Order[Index % #Order + 1]
				local A, B, C = Projected[AIndex], Projected[BIndex], Projected[CIndex]
				local Cross = Cross2(B - A, C - B)
				if math.abs(Cross) < EPSILON * EPSILON then
					continue
				end
				if Cross < 0 then
					continue
				end
				local Contains = false
				for _, Other in Order do
					if Other == AIndex or Other == BIndex or Other == CIndex then
						continue
					end
					local P = Projected[Other]
					if Cross2(B - A, P - A) >= 0 and Cross2(C - B, P - B) >= 0 and Cross2(A - C, P - C) >= 0 then
						Contains = true
						break
					end
				end
				if not Contains then
					AddPolygon(
						Output,
						if Reverse
							then { Vertices[CIndex], Vertices[BIndex], Vertices[AIndex] }
							else { Vertices[AIndex], Vertices[BIndex], Vertices[CIndex] },
						true
					)
					table.remove(Order, Index)
					Found = true
					break
				end
			end
			if not Found then
				break
			end
		end
	end

	return Output
end

local function GetCaps(Triangles: { Triangle }, Plane: Plane, Reverse: boolean, Check: Checkpoint): { Triangle }
	return TriangulateLoops(GetSectionLoops(Triangles, Plane, Check), Plane.Normal, Reverse, Check)
end

function Geometry.SealBoundaries(
	Triangles: { Triangle },
	Include: (({ Vector3 }) -> boolean)?,
	Check: Checkpoint
): { Triangle }
	local Output = table.clone(Triangles)
	for _, Loop in Geometry.GetBoundaryLoops(Triangles, Check) do
		if Check then
			Check()
		end
		if Include and not Include(Loop) then
			continue
		end
		local Origin = Loop[1]
		local Normal = Vector3.zero
		for Index, Point in Loop do
			Normal += (Point - Origin):Cross(Loop[Index % #Loop + 1] - Origin)
		end
		if Normal.Magnitude > EPSILON * EPSILON then
			for _, Triangle in TriangulateLoops({ Loop }, Normal.Unit, false, Check) do
				table.insert(Output, Triangle)
			end
		end
	end

	return Output
end

function Geometry.Subtract(Triangles: { Triangle }, Planes: { Plane }, Check: Checkpoint): { Triangle }
	local Output = {}
	-- Temporary closure makes section tracing reliable, but these distant caps
	-- never enter the rendered mesh: only faces clipped into the notch are kept.
	local SectionSource = Geometry.SealBoundaries(Triangles, nil, Check)
	for _, Triangle in Triangles do
		if Check then
			Check()
		end
		local Remainder = Triangle.Vertices
		for _, Plane in Planes do
			AddPolygon(Output, ClipPolygon(Remainder, Plane, false), Triangle.Interior)
			Remainder = ClipPolygon(Remainder, Plane, true)
			if #Remainder < 3 then
				break
			end
		end
	end

	for Index, Plane in Planes do
		for _, Triangle in GetCaps(SectionSource, Plane, true, Check) do
			local Polygon = Triangle.Vertices
			for OtherIndex, Other in Planes do
				if OtherIndex ~= Index then
					Polygon = ClipPolygon(Polygon, Other, true)
				end
				if #Polygon < 3 then
					break
				end
			end
			AddPolygon(Output, Polygon, true)
		end
	end

	return Geometry.SealBoundaries(Output, function(Loop: { Vector3 }): boolean
		for _, Point in Loop do
			for _, Plane in Planes do
				if Plane.Normal:Dot(Point) - Plane.Distance > EPSILON * 4 * Plane.Normal.Magnitude then
					return false
				end
			end
		end
		return true
	end, Check)
end

function Geometry.KeepInside(Triangles: { Triangle }, Plane: Plane, Check: Checkpoint): { Triangle }
	local Output = {}
	for _, Triangle in Triangles do
		if Check then
			Check()
		end
		AddPolygon(Output, ClipPolygon(Triangle.Vertices, Plane, true), Triangle.Interior)
	end
	for _, Triangle in GetCaps(Geometry.SealBoundaries(Triangles, nil, Check), Plane, false, Check) do
		table.insert(Output, Triangle)
	end

	return Geometry.SealBoundaries(Output, function(Loop: { Vector3 }): boolean
		for _, Point in Loop do
			if math.abs(Plane.Normal:Dot(Point) - Plane.Distance) > EPSILON * 4 * Plane.Normal.Magnitude then
				return false
			end
		end
		return true
	end, Check)
end

return Geometry
