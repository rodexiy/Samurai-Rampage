local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.TreeCuttingConfig)
local Geometry = require(ReplicatedStorage.Shared.Utils.TreeCuttingGeometry)
local Math = require(ReplicatedStorage.Shared.Utils.TreeCuttingMath)
local MeshData = require(ReplicatedStorage.Shared.Utils.TreeMeshData)
local Work = require(ReplicatedStorage.Shared.Utils.TreeMeshWork)
local TreeMeshController = {}

type Triangle = Geometry.Triangle
export type SourceData = MeshData.SourceData
export type Visual = { Parts: { MeshPart } }

local Building = false
local BuildFinished = Instance.new("BindableEvent")

function TreeMeshController.Read(Part: MeshPart): SourceData
	return MeshData.Read(Part, Work.Checkpoint)
end

function TreeMeshController.Destroy(Visual: Visual)
	for _, Part in Visual.Parts do
		Part:Destroy()
	end
end

local function CreatePart(Source: MeshPart, _Data: SourceData, Triangles: { Triangle }, Interior: boolean): MeshPart?
	local Selected = {}
	for _, Triangle in Triangles do
		Work.Checkpoint()
		if Triangle.Interior == Interior then
			table.insert(Selected, Triangle)
		end
	end
	if #Selected == 0 then
		return nil
	end
	local Min = Vector3.new(math.huge, math.huge, math.huge)
	local Max = -Min
	for _, Triangle in Selected do
		Work.Checkpoint()
		for _, Vertex in Triangle.Vertices do
			Min, Max = Min:Min(Vertex.Position), Max:Max(Vertex.Position)
		end
	end
	local Center = (Min + Max) * 0.5
	local Scale = Source.Size / Source.MeshSize
	local Mesh = AssetService:CreateEditableMesh()
	assert(Mesh, "EditableMesh memory budget exhausted")
	local Part: MeshPart? = nil

	local Success, Error = pcall(function()
		local Positions: { [string]: number } = {}
		for _, Triangle in Selected do
			Work.Checkpoint()
			local Vertices, Normals, UVs, Colors = {}, {}, {}, {}
			for Index, Vertex in Triangle.Vertices do
				local Key = string.format(
					"%d,%d,%d",
					math.round(Vertex.Position.X * 100000),
					math.round(Vertex.Position.Y * 100000),
					math.round(Vertex.Position.Z * 100000)
				)
				local Id = Positions[Key]
				if not Id then
					Id = Mesh:AddVertex(Vertex.Position - Center)
					Positions[Key] = Id
				end
				Vertices[Index] = Id
				Normals[Index] = Mesh:AddNormal(Vertex.Normal)
				UVs[Index] = Mesh:AddUV(Vertex.UV)
				Colors[Index] = Mesh:AddColor(Vertex.Color, Vertex.Alpha)
			end
			local Face = Mesh:AddTriangle(Vertices[1], Vertices[2], Vertices[3])
			Mesh:SetFaceNormals(Face, Normals)
			Mesh:SetFaceUVs(Face, UVs)
			Mesh:SetFaceColors(Face, Colors)
		end

		-- Cuts are static between hits. Freeze the result so it does not retain a
		-- full dynamic EditableMesh buffer alongside other client mesh systems.
		local Result, Frozen = AssetService:CreateDataModelContentAsync(Content.fromObject(Mesh))
		assert(Result == Enum.CreateContentResult.Success, "Could not freeze the tree mesh: " .. tostring(Result))
		local Generated = AssetService:CreateMeshPartAsync(Frozen, { CollisionFidelity = Enum.CollisionFidelity.Box })
		Part = Source:Clone()
		Part:ApplyMesh(Generated)
		Generated:Destroy()
		-- Frozen content drops unused vertices and recenters its bounds. Size and
		-- position each piece by its actual bounds instead of stretching it to the tree.
		Part.Size = Part.MeshSize * Scale
		Part.PivotOffset = CFrame.new(-Center * Scale) * Source.PivotOffset
		Part.CFrame = Source.CFrame * CFrame.new(Center * Scale)
		Part.TextureContent = Source.TextureContent
		Part.LocalTransparencyModifier = 0
		Part.Anchored = true
		Part.CanCollide = false
		Part.CanTouch = false
		Part.CanQuery = false
		for _, Tag in Part:GetTags() do
			Part:RemoveTag(Tag)
		end

		if Interior then
			for _, Child in Part:GetChildren() do
				if Child:IsA("SurfaceAppearance") or Child:IsA("Texture") or Child:IsA("Decal") then
					Child:Destroy()
				end
			end
			Part.TextureID = ""
			Part.Color = Config.WoodColor
			Part.Material = Enum.Material.Wood
			Part.DoubleSided = true
		end
	end)

	if not Success then
		if Part then
			Part:Destroy()
		end
		Mesh:Destroy()
		error(Error)
	end

	Mesh:Destroy()
	return Part
end

function TreeMeshController.Build(Source: MeshPart, Data: SourceData, Triangles: { Triangle }): Visual
	-- One scratch mesh at a time keeps the dynamic budget available to cloth.
	while Building do
		BuildFinished.Event:Wait()
	end
	Building = true
	local Visual: Visual = { Parts = {} }
	local Success, Error = pcall(function()
		for _, Interior in { false, true } do
			local Part = CreatePart(Source, Data, Triangles, Interior)
			if Part then
				table.insert(Visual.Parts, Part)
			end
		end
	end)
	Building = false
	BuildFinished:Fire()
	if not Success then
		TreeMeshController.Destroy(Visual)
		error(Error)
	end

	return Visual
end

function TreeMeshController.Cut(Source: MeshPart, Triangles: { Triangle }, Cut: Math.Cut): { Triangle }
	local Planes = {}
	for _, Plane in Math.GetCutPlanes(Cut) do
		table.insert(Planes, Math.ToMeshPlane(Plane, Source.CFrame, Source.Size / Source.MeshSize))
	end

	return Geometry.Subtract(Triangles, Planes, Work.Checkpoint)
end

function TreeMeshController.Split(
	Source: MeshPart,
	Triangles: { Triangle },
	Height: number
): ({ Triangle }, { Triangle })
	local Scale = Source.Size / Source.MeshSize
	local Upper = Math.ToMeshPlane({ Normal = -Vector3.yAxis, Distance = -Height }, Source.CFrame, Scale)
	local Lower = Math.ToMeshPlane({ Normal = Vector3.yAxis, Distance = Height }, Source.CFrame, Scale)

	return Geometry.KeepInside(Triangles, Upper, Work.Checkpoint),
		Geometry.KeepInside(Triangles, Lower, Work.Checkpoint)
end

return TreeMeshController
