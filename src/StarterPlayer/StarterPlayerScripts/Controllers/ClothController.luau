local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ClothGeometry = require(ReplicatedStorage.Shared.Utils.ClothGeometry)

local ClothController = Knit.CreateController({ Name = "ClothController" })

local ARROW_HOLE_RADIUS = 0.18
local BULLET_HOLE_RADIUS = 0.3
local SWORD_CUT_WIDTH = 0.06
local REGENERATION_DISTANCE = 1000
local DISTANCE_CHECK_INTERVAL = 1
local EPSILON = 1e-7

type Vertex = { Position: Vector3, Bones: { number }, Weights: { number } }
type Binding = { Bone: Bone, Inverse: CFrame }
type State = {
	Mesh: MeshPart, Editable: EditableMesh, Prepared: MeshPart, Original: MeshPart,
	Scale: Vector3, Vertices: { [number]: Vertex }, Faces: { [number]: { number } },
	Bindings: { [number]: Binding }, Applied: boolean,
	FaceGroups: { [number]: number },
	FaceOrigins: { [number]: number },
}
type FaceStyle = { UVs: { Vector2 }, Normals: { Vector3 }, Colors: { Color3 }, Alphas: { number } }
type Cut = { Face: number, Triangle: { number }, Polygons: { ClothGeometry.Polygon } }
type Stroke = { Start: Vector3, Finish: Vector3, Width: number }
export type BladeBatch = { [MeshPart]: { State: State, Marks: { [number]: { Stroke } } } }

local States: { [MeshPart]: State } = {}
local Loading: { [MeshPart]: {} } = {}
local Failed: { [MeshPart]: boolean } = {}
local DistantMeshes: { [MeshPart]: boolean } = {}
local RootConnections: { [Instance]: { RBXScriptConnection } } = {}
local RefreshPending = false

local function IsEnabled(): boolean
	return Players.LocalPlayer:GetAttribute("ClothCut") ~= false
end

local function DestroyState(State: State)
	if State.Applied and State.Mesh.Parent then
		local Texture = State.Mesh.TextureContent
		State.Mesh:ApplyMesh(State.Original)
		State.Mesh.TextureContent = Texture
	end

	State.Prepared:Destroy()
	State.Original:Destroy()
	State.Editable:Destroy()
end

local function LoadMesh(Mesh: MeshPart)
	if not IsEnabled() or States[Mesh] or Loading[Mesh] or Failed[Mesh] or DistantMeshes[Mesh] then
		return
	end

	local Token = {}
	Loading[Mesh] = Token
	task.spawn(function()
		local Editable: EditableMesh?
		local Prepared: MeshPart?
		local Original: MeshPart?
		local Success, Result = pcall(function(): State
			Editable = AssetService:CreateEditableMeshAsync(Mesh.MeshContent, { FixedSize = false })
			assert(Editable, "EditableMesh memory budget exhausted")
			Prepared = AssetService:CreateMeshPartAsync(Content.fromObject(Editable))
			Original = Mesh:Clone()
			Original:ClearAllChildren()

			local Scale = Mesh.Size / Mesh.MeshSize
			local Bones: { [string]: Bone } = {}
			for _, Bone in Mesh:QueryDescendants("Bone") :: { Bone } do
				Bones[Bone.Name] = Bone
			end

			local Bindings: { [number]: Binding } = {}
			for _, Id in Editable:GetBones() do
				local Bone = Bones[Editable:GetBoneName(Id)]
				if Bone then
					local Bind = Editable:GetBoneCFrame(Id)
					Bindings[Id] = { Bone = Bone, Inverse = (CFrame.new(Bind.Position * Scale) * Bind.Rotation):Inverse() }
				end
			end

			local Vertices: { [number]: Vertex } = {}
			for _, Id in Editable:GetVertices() do
				Vertices[Id] = {
					Position = Editable:GetPosition(Id), Bones = Editable:GetVertexBones(Id),
					Weights = Editable:GetVertexBoneWeights(Id),
				}
			end

			local Faces: { [number]: { number } } = {}
			local FaceOrigins: { [number]: number } = {}
			for _, Id in Editable:GetFaces() do
				Faces[Id] = Editable:GetFaceVertices(Id)
				FaceOrigins[Id] = Id
			end

			local Positions: { [number]: Vector3 } = {}
			for Id, Vertex in Vertices do
				Positions[Id] = Vertex.Position * Scale
			end
			local FaceGroups: { [number]: number } = {}
			for Group, Component in ClothGeometry.GetConnectedComponents(Faces, Positions) do
				for _, Face in Component.Faces do
					FaceGroups[Face] = Group
				end
			end

			return {
				Mesh = Mesh, Editable = Editable, Prepared = Prepared, Original = Original,
				Scale = Scale, Bindings = Bindings, Vertices = Vertices, Faces = Faces, Applied = false,
				FaceGroups = FaceGroups,
				FaceOrigins = FaceOrigins,
			}
		end)

		local Active = Loading[Mesh] == Token
		if Active then
			Loading[Mesh] = nil
		end
		if Success and Active and Mesh:IsDescendantOf(workspace) then
			States[Mesh] = Result
			return
		end

		if Prepared then
			Prepared:Destroy()
		end
		if Original then
			Original:Destroy()
		end
		if Editable then
			Editable:Destroy()
		end
		if not Success and Active then
			Failed[Mesh] = true
			warn("[ClothController] Cannot prepare " .. Mesh:GetFullName() .. ": " .. tostring(Result))
		end
	end)
end

local function UpdateDistance()
	local Character = Players.LocalPlayer.Character
	local Root = Character and Character.PrimaryPart
	if not Root then
		return
	end

	local Position = Root.Position
	local DistanceSquared = REGENERATION_DISTANCE * REGENERATION_DISTANCE
	for Mesh, State in States do
		local Offset = Mesh.Position - Position
		if State.Applied and Offset:Dot(Offset) >= DistanceSquared then
			States[Mesh] = nil
			DistantMeshes[Mesh] = true
			DestroyState(State)
		end
	end

	for Mesh in DistantMeshes do
		local Offset = Mesh.Position - Position
		if Offset:Dot(Offset) < DistanceSquared then
			DistantMeshes[Mesh] = nil
			LoadMesh(Mesh)
		end
	end
end

local function Refresh()
	RefreshPending = false
	local Eligible: { [MeshPart]: boolean } = {}
	for Root in RootConnections do
		if not IsEnabled() or not Root:IsDescendantOf(workspace) then
			continue
		end

		if Root:IsA("MeshPart") then
			Eligible[Root] = true
		end
		for _, Mesh in Root:QueryDescendants("MeshPart") :: { MeshPart } do
			Eligible[Mesh] = true
		end
	end

	for Mesh, State in States do
		if not Eligible[Mesh] then
			States[Mesh] = nil
			DestroyState(State)
		end
	end
	for Mesh in Loading do
		if not Eligible[Mesh] then
			Loading[Mesh] = nil
		end
	end
	for Mesh in Failed do
		if not Eligible[Mesh] then
			Failed[Mesh] = nil
		end
	end
	for Mesh in DistantMeshes do
		if not Eligible[Mesh] then
			DistantMeshes[Mesh] = nil
		end
	end
	for Mesh in Eligible do
		LoadMesh(Mesh)
	end
end

local function ScheduleRefresh()
	if not RefreshPending then
		RefreshPending = true
		task.defer(Refresh)
	end
end

local function TrackRoot(Root: Instance)
	if RootConnections[Root] then
		return
	end

	RootConnections[Root] = {
		Root.AncestryChanged:Connect(ScheduleRefresh),
		Root.DescendantAdded:Connect(ScheduleRefresh),
		Root.DescendantRemoving:Connect(ScheduleRefresh),
	}
	ScheduleRefresh()
end

local function GetWorldVertices(State: State): { [number]: Vector3 }
	local Transforms: { [number]: CFrame } = {}
	for Id, Binding in State.Bindings do
		Transforms[Id] = Binding.Bone.TransformedWorldCFrame * Binding.Inverse
	end

	local Positions: { [number]: Vector3 } = {}
	for Id, Vertex in State.Vertices do
		local Position = Vertex.Position * State.Scale
		local World = Vector3.zero
		local Total = 0
		for Index, BoneId in Vertex.Bones do
			local Weight = Vertex.Weights[Index] or 0
			local Transform = Transforms[BoneId]
			if Transform and Weight > 0 then
				World += Transform:PointToWorldSpace(Position) * Weight
				Total += Weight
			end
		end

		Positions[Id] = if Total > EPSILON then World / Total else State.Mesh.CFrame:PointToWorldSpace(Position)
	end

	return Positions
end

local function ReadStyle(Editable: EditableMesh, Face: number): FaceStyle
	local Style: FaceStyle = { UVs = {}, Normals = {}, Colors = {}, Alphas = {} }
	for _, Id in Editable:GetFaceUVs(Face) do
		table.insert(Style.UVs, Editable:GetUV(Id))
	end
	for _, Id in Editable:GetFaceNormals(Face) do
		table.insert(Style.Normals, Editable:GetNormal(Id))
	end
	for _, Id in Editable:GetFaceColors(Face) do
		table.insert(Style.Colors, Editable:GetColor(Id))
		table.insert(Style.Alphas, Editable:GetColorAlpha(Id))
	end

	return Style
end

local function AddVertex(State: State, Triangle: { number }, Weights: Vector3): number
	local Position = Vector3.zero
	local Influences: { [number]: number } = {}
	for Index, Weight in { Weights.X, Weights.Y, Weights.Z } do
		local Vertex = State.Vertices[Triangle[Index]]
		Position += Vertex.Position * Weight
		for BoneIndex, BoneId in Vertex.Bones do
			Influences[BoneId] = (Influences[BoneId] or 0) + (Vertex.Weights[BoneIndex] or 0) * Weight
		end
	end

	local Sorted: { { Id: number, Weight: number } } = {}
	for Id, Weight in Influences do
		if Weight > EPSILON then
			table.insert(Sorted, { Id = Id, Weight = Weight })
		end
	end
	table.sort(Sorted, function(A: { Weight: number }, B: { Weight: number }): boolean
		return A.Weight > B.Weight
	end)

	local Bones, BoneWeights = {}, {}
	local Total = 0
	for Index = 1, math.min(4, #Sorted) do
		table.insert(Bones, Sorted[Index].Id)
		table.insert(BoneWeights, Sorted[Index].Weight)
		Total += Sorted[Index].Weight
	end
	for Index, Weight in BoneWeights do
		BoneWeights[Index] = Weight / Total
	end

	local Id = State.Editable:AddVertex(Position)
	if #Bones > 0 then
		State.Editable:SetVertexBones(Id, Bones)
		State.Editable:SetVertexBoneWeights(Id, BoneWeights)
	end
	State.Vertices[Id] = {
		Position = Position, Bones = State.Editable:GetVertexBones(Id),
		Weights = State.Editable:GetVertexBoneWeights(Id),
	}

	return Id
end

local function AddFace(State: State, Triangle: { number }, Weights: { Vector3 }, Style: FaceStyle, Group: number, Origin: number)
	local Vertices, UVs, Normals, Colors = {}, {}, {}, {}
	for _, Coordinate in Weights do
		table.insert(Vertices, AddVertex(State, Triangle, Coordinate))
		local UV, Normal, Color, Alpha = Vector2.zero, Vector3.zero, Vector3.zero, 0
		for Index, Weight in { Coordinate.X, Coordinate.Y, Coordinate.Z } do
			UV += (Style.UVs[Index] or Vector2.zero) * Weight
			Normal += (Style.Normals[Index] or Vector3.yAxis) * Weight
			local SourceColor = Style.Colors[Index] or Color3.new(1, 1, 1)
			Color += Vector3.new(SourceColor.R, SourceColor.G, SourceColor.B) * Weight
			Alpha += (Style.Alphas[Index] or 1) * Weight
		end

		table.insert(UVs, State.Editable:AddUV(UV))
		table.insert(Normals, State.Editable:AddNormal(if Normal.Magnitude > EPSILON then Normal.Unit else Vector3.yAxis))
		table.insert(Colors, State.Editable:AddColor(Color3.new(Color.X, Color.Y, Color.Z), Alpha))
	end

	local Face = State.Editable:AddTriangle(Vertices[1], Vertices[2], Vertices[3])
	State.Editable:SetFaceUVs(Face, UVs)
	State.Editable:SetFaceNormals(Face, Normals)
	State.Editable:SetFaceColors(Face, Colors)
	State.Faces[Face] = Vertices
	State.FaceGroups[Face] = Group
	State.FaceOrigins[Face] = Origin
end

local function RemoveDetachedPieces(State: State)
	local Positions: { [number]: Vector3 } = {}
	for Id, Vertex in State.Vertices do
		Positions[Id] = Vertex.Position * State.Scale
	end

	local Components = ClothGeometry.GetConnectedComponents(State.Faces, Positions, State.FaceGroups)
	local Largest: { [number]: ClothGeometry.Component } = {}
	for _, Component in Components do
		local Group = State.FaceGroups[Component.Faces[1]]
		local Previous = Largest[Group]
		if not Previous or Component.Area > Previous.Area then
			Largest[Group] = Component
		end
	end

	for _, Component in Components do
		local Group = State.FaceGroups[Component.Faces[1]]
		if Largest[Group] == Component then
			continue
		end

		for _, Face in Component.Faces do
			State.Editable:RemoveFace(Face)
			State.Faces[Face] = nil
			State.FaceGroups[Face] = nil
			State.FaceOrigins[Face] = nil
		end
	end
end

local function ApplyCuts(State: State, Cuts: { Cut })
	for _, Cut in Cuts do
		local Style = ReadStyle(State.Editable, Cut.Face)
		for _, Polygon in Cut.Polygons do
			for Index = 2, #Polygon - 1 do
				local Weights = { Polygon[1], Polygon[Index], Polygon[Index + 1] }
				local A, B = Weights[2] - Weights[1], Weights[3] - Weights[1]
				if A:Cross(B).Magnitude > EPSILON then
					AddFace(State, Cut.Triangle, Weights, Style, State.FaceGroups[Cut.Face], State.FaceOrigins[Cut.Face])
				end
			end
		end

		State.Editable:RemoveFace(Cut.Face)
		State.Faces[Cut.Face] = nil
		State.FaceGroups[Cut.Face] = nil
		State.FaceOrigins[Cut.Face] = nil
	end

	if #Cuts > 0 then
		RemoveDetachedPieces(State)
	end
	State.Editable:RemoveUnused()
	local UsedVertices: { [number]: boolean } = {}
	for _, Triangle in State.Faces do
		for _, Id in Triangle do
			UsedVertices[Id] = true
		end
	end
	for Id in State.Vertices do
		if not UsedVertices[Id] then
			State.Vertices[Id] = nil
		end
	end

	if not State.Applied and #Cuts > 0 then
		local Texture = State.Mesh.TextureContent
		State.Mesh:ApplyMesh(State.Prepared)
		State.Mesh.TextureContent = Texture
		State.Applied = true
	end
end

local function PunchHole(State: State, Positions: { [number]: Vector3 }, Center: Vector3, Direction: Vector3, Radius: number)
	local Cuts: { Cut } = {}
	for Face, Triangle in State.Faces do
		local World = { Positions[Triangle[1]], Positions[Triangle[2]], Positions[Triangle[3]] }
		local Polygons = ClothGeometry.CutTriangle(World, Center, Direction, Radius)
		if Polygons then
			table.insert(Cuts, { Face = Face, Triangle = Triangle, Polygons = Polygons })
		end
	end

	ApplyCuts(State, Cuts)
end

local function MaterialPoint(State: State, Triangle: { number }, Coordinate: Vector3): Vector3
	return (State.Vertices[Triangle[1]].Position * Coordinate.X + State.Vertices[Triangle[2]].Position * Coordinate.Y
		+ State.Vertices[Triangle[3]].Position * Coordinate.Z) * State.Scale
end

function ClothController:CollectBladeCuts(Batch: BladeBatch, PreviousBase: Vector3, PreviousTip: Vector3, Base: Vector3, Tip: Vector3): boolean
	if not IsEnabled() or ((Base - PreviousBase).Magnitude < EPSILON and (Tip - PreviousTip).Magnitude < EPSILON) then
		return false
	end

	local Sweeps = { { PreviousBase, PreviousTip, Tip }, { PreviousBase, Tip, Base } }
	local Center = (PreviousBase + PreviousTip + Base + Tip) * 0.25
	local SweepRadius = math.max((PreviousBase - Center).Magnitude, (PreviousTip - Center).Magnitude,
		(Base - Center).Magnitude, (Tip - Center).Magnitude)
	local Hit = false
	for Mesh, State in States do
		if not Mesh:IsDescendantOf(workspace) or (Mesh.Position - Center).Magnitude > Mesh.Size.Magnitude * 1.5 + SweepRadius then
			continue
		end

		local Positions = GetWorldVertices(State)
		for Face, Triangle in State.Faces do
			local World = { Positions[Triangle[1]], Positions[Triangle[2]], Positions[Triangle[3]] }
			local Start, Finish
			for _, Sweep in Sweeps do
				local A, B = ClothGeometry.IntersectTriangles(World, Sweep)
				if A and B then
					if not Start then
						Start, Finish = A, B
					else
						local Points = { Start, Finish, A, B }
						local Longest = (Finish - Start).Magnitude
						for Index, Point in Points do
							for Other = Index + 1, #Points do
								local Distance = (Point - Points[Other]).Magnitude
								if Distance > Longest then
									Start, Finish, Longest = Point, Points[Other], Distance
								end
							end
						end
					end
				end
			end

			if Start and Finish then
				local A = ClothGeometry.Barycentric(Start, World)
				local B = ClothGeometry.Barycentric(Finish, World)
				local Normal = (World[2] - World[1]):Cross(World[3] - World[1])
				if not A or not B or Normal.Magnitude < EPSILON then
					continue
				end

				local Across = Normal.Unit:Cross((Finish - Start).Unit)
				local Offset = ClothGeometry.Barycentric(Start + Across * (SWORD_CUT_WIDTH * 0.5), World)
				if not Offset then
					continue
				end
				local Entry = Batch[Mesh]
				if not Entry or Entry.State ~= State then
					Entry = { State = State, Marks = {} }
					Batch[Mesh] = Entry
				end
				local Origin = State.FaceOrigins[Face]
				local Marks = Entry.Marks[Origin]
				if not Marks then
					Marks = {}
					Entry.Marks[Origin] = Marks
				end
				local RestStart = MaterialPoint(State, Triangle, A)
				table.insert(Marks, {
					Start = RestStart, Finish = MaterialPoint(State, Triangle, B),
					Width = (MaterialPoint(State, Triangle, Offset) - RestStart).Magnitude * 2,
				})
				Hit = true
			end
		end
	end

	return Hit
end

function ClothController:CommitBladeCuts(Batch: BladeBatch): boolean
	local Hit = false
	if IsEnabled() then
		for Mesh, Entry in Batch do
			local State = Entry.State
			if States[Mesh] ~= State or not Mesh:IsDescendantOf(workspace) then
				continue
			end

			local Cuts: { Cut } = {}
			for Face, Triangle in State.Faces do
				local Marks = Entry.Marks[State.FaceOrigins[Face]]
				if not Marks then
					continue
				end
				local Rest = { State.Vertices[Triangle[1]].Position * State.Scale,
					State.Vertices[Triangle[2]].Position * State.Scale, State.Vertices[Triangle[3]].Position * State.Scale }
				local Polygons: { ClothGeometry.Polygon } = { { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis } }
				local Changed = false
				for _, Mark in Marks do
					local Remaining = {}
					for _, Polygon in Polygons do
						local Pieces = ClothGeometry.CutPolygonAlongSegment(Polygon, Rest, Mark.Start, Mark.Finish, Mark.Width)
						if Pieces then
							Changed = true
							for _, Piece in Pieces do
								table.insert(Remaining, Piece)
							end
						else
							table.insert(Remaining, Polygon)
						end
					end
					Polygons = Remaining
					if #Polygons == 0 then
						break
					end
				end
				if Changed then
					table.insert(Cuts, { Face = Face, Triangle = Triangle, Polygons = Polygons })
				end
			end
			if #Cuts > 0 then
				ApplyCuts(State, Cuts)
				Hit = true
			end
		end
	end

	table.clear(Batch)
	return Hit
end

function ClothController:CutByBlade(PreviousBase: Vector3, PreviousTip: Vector3, Base: Vector3, Tip: Vector3): boolean
	local Batch: BladeBatch = {}
	self:CollectBladeCuts(Batch, PreviousBase, PreviousTip, Base, Tip)
	return self:CommitBladeCuts(Batch)
end

function ClothController:HitByProjectile(Origin: Vector3, Displacement: Vector3,
	IsFirearm: boolean, HitCloths: { [MeshPart]: boolean }): boolean
	if not IsEnabled() or Displacement.Magnitude < EPSILON then
		return false
	end

	local Hit = false
	for Mesh, State in States do
		if HitCloths[Mesh] or not Mesh:IsDescendantOf(workspace) then
			continue
		end

		local BoundsRadius = Mesh.Size.Magnitude * 1.5
		if ClothGeometry.SegmentDistanceSquared(Origin, Displacement, Mesh.Position) > BoundsRadius * BoundsRadius then
			continue
		end

		local Positions = GetWorldVertices(State)
		local Closest: number?
		for _, Triangle in State.Faces do
			local Alpha = ClothGeometry.IntersectTriangle(Origin, Displacement,
				{ Positions[Triangle[1]], Positions[Triangle[2]], Positions[Triangle[3]] })
			if Alpha and (not Closest or Alpha < Closest) then
				Closest = Alpha
			end
		end

		if Closest then
			PunchHole(State, Positions, Origin + Displacement * Closest, Displacement.Unit,
				if IsFirearm then BULLET_HOLE_RADIUS else ARROW_HOLE_RADIUS)
			HitCloths[Mesh] = true
			Hit = true
		end
	end

	return Hit
end

function ClothController.KnitStart()
	Players.LocalPlayer:GetAttributeChangedSignal("ClothCut"):Connect(ScheduleRefresh)

	local Elapsed = 0
	RunService.Heartbeat:Connect(function(DeltaTime: number)
		Elapsed += DeltaTime
		if Elapsed >= DISTANCE_CHECK_INTERVAL then
			Elapsed %= DISTANCE_CHECK_INTERVAL
			UpdateDistance()
		end
	end)

	CollectionService:GetInstanceAddedSignal("Cloth"):Connect(TrackRoot)
	CollectionService:GetInstanceRemovedSignal("Cloth"):Connect(function(Root: Instance)
		local Connections = RootConnections[Root]
		if Connections then
			for _, Connection in Connections do
				Connection:Disconnect()
			end
			RootConnections[Root] = nil
		end
		ScheduleRefresh()
	end)

	for _, Root in CollectionService:GetTagged("Cloth") do
		TrackRoot(Root)
	end
end

return ClothController
