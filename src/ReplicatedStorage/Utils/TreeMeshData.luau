local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Geometry = require(ReplicatedStorage.Shared.Utils.TreeCuttingGeometry)

local TreeMeshData = {}
type Triangle = Geometry.Triangle
export type SourceData = { Triangles: { Triangle }, Min: Vector3, Max: Vector3 }
local Cache: { [string]: SourceData } = {}

function TreeMeshData.Read(Part: MeshPart, Check: Geometry.Checkpoint): SourceData
	local Key = Part.MeshId
	if Cache[Key] then
		return Cache[Key]
	end
	local Mesh = AssetService:CreateEditableMeshAsync(Part.MeshContent, { FixedSize = true })
	assert(Mesh, "EditableMesh memory budget exhausted")
	local Triangles = {}
	local Min = Vector3.new(math.huge, math.huge, math.huge)
	local Max = -Min

	local Success, Error = pcall(function()
		for _, Face in Mesh:GetFaces() do
			if Check then
				Check()
			end
			local Vertices, UVs, Normals, Colors =
				Mesh:GetFaceVertices(Face), Mesh:GetFaceUVs(Face), Mesh:GetFaceNormals(Face), Mesh:GetFaceColors(Face)
			local Polygon = {}
			for Index, Vertex in Vertices do
				local Position = Mesh:GetPosition(Vertex)
				Min, Max = Min:Min(Position), Max:Max(Position)
				Polygon[Index] = {
					Position = Position,
					Normal = Mesh:GetNormal(Normals[Index]),
					UV = Mesh:GetUV(UVs[Index]),
					Color = Mesh:GetColor(Colors[Index]),
					Alpha = Mesh:GetColorAlpha(Colors[Index]),
				}
			end
			for Index = 2, #Polygon - 1 do
				table.insert(
					Triangles,
					{ Vertices = { Polygon[1], Polygon[Index], Polygon[Index + 1] }, Interior = false }
				)
			end
		end
	end)
	Mesh:Destroy()
	assert(Success, Error)
	local BaseLimit = Min.Y + (Max.Y - Min.Y) * 0.08
	local Sealed = Geometry.SealBoundaries(Triangles, function(Loop: { Vector3 }): boolean
		for _, Point in Loop do
			if Point.Y > BaseLimit then
				return false
			end
		end
		return true
	end, Check)
	local Data = { Triangles = Sealed, Min = Min, Max = Max }
	Cache[Key] = Data

	return Data
end

return TreeMeshData
