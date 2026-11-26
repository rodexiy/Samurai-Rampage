local AssetService = game:GetService("AssetService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.TreeCuttingConfig)
local Geometry = require(ReplicatedStorage.Shared.Utils.TreeCuttingGeometry)
local Math = require(ReplicatedStorage.Shared.Utils.TreeCuttingMath)
local MeshData = require(ReplicatedStorage.Shared.Utils.TreeMeshData)
local Work = require(ReplicatedStorage.Shared.Utils.TreeMeshWork)

local TreePhysicsService = Knit.CreateService({ Name = "TreePhysicsService", Client = {} })
local Tracked: { [Model]: boolean } = setmetatable({}, { __mode = "k" })
local Up = Vector3.yAxis

type Preparation = { Root: BasePart?, Error: string?, Cancelled: boolean, Pending: boolean, Finished: BindableEvent }
local Prepared: { [Model]: Preparation } = {}

local function ConfigureGroups()
	local Fallen, Ignored = Config.FallCollisionGroup, Config.EntityFallbackCollisionGroup
	for _, Name in { Fallen, Ignored } do
		if not PhysicsService:IsCollisionGroupRegistered(Name) then
			PhysicsService:RegisterCollisionGroup(Name)
		end
	end

	-- Unassigned NPC parts retain Default's interactions with everything except trees.
	for _, Group in PhysicsService:GetRegisteredCollisionGroups() do
		if Group.name ~= Ignored then
			PhysicsService:CollisionGroupSetCollidable(
				Ignored,
				Group.name,
				PhysicsService:CollisionGroupsAreCollidable("Default", Group.name)
			)
		end
		PhysicsService:CollisionGroupSetCollidable(Fallen, Group.name, Group.name == "Default")
	end
	PhysicsService:CollisionGroupSetCollidable(Ignored, Ignored, true)
	PhysicsService:CollisionGroupSetCollidable(Fallen, Ignored, false)
end

local function ProtectPart(Part: BasePart)
	local function Update()
		if Part.CollisionGroup == "Default" or not PhysicsService:IsCollisionGroupRegistered(Part.CollisionGroup) then
			Part.CollisionGroup = Config.EntityFallbackCollisionGroup
		elseif PhysicsService:IsCollisionGroupRegistered(Part.CollisionGroup) then
			PhysicsService:CollisionGroupSetCollidable(Config.FallCollisionGroup, Part.CollisionGroup, false)
		end
	end
	Update()
	Part:GetPropertyChangedSignal("CollisionGroup"):Connect(Update)
end

function TreePhysicsService:TrackEntity(Model: Model)
	if Tracked[Model] then
		return
	end
	Tracked[Model] = true
	for _, Part in Model:QueryDescendants("BasePart") :: { BasePart } do
		ProtectPart(Part)
	end
	Model.DescendantAdded:Connect(function(Instance: Instance)
		if Instance:IsA("BasePart") then
			ProtectPart(Instance)
		end
	end)
end

local function CreateCollider(Source: MeshPart, Height: number): MeshPart?
	local Data = MeshData.Read(Source, Work.Checkpoint)
	local Plane =
		Math.ToMeshPlane({ Normal = -Vector3.yAxis, Distance = -Height }, Source.CFrame, Source.Size / Source.MeshSize)
	local Triangles =
		Geometry.SealBoundaries(Geometry.KeepInside(Data.Triangles, Plane, Work.Checkpoint), nil, Work.Checkpoint)
	if #Triangles == 0 then
		return nil
	end
	local Min = Vector3.new(math.huge, math.huge, math.huge)
	local Max = -Min
	for _, Triangle in Triangles do
		Work.Checkpoint()
		for _, Vertex in Triangle.Vertices do
			Min, Max = Min:Min(Vertex.Position), Max:Max(Vertex.Position)
		end
	end
	local Center = (Min + Max) * 0.5
	local Scale = Source.Size / Source.MeshSize
	local Mesh = AssetService:CreateEditableMesh()
	assert(Mesh, "Could not allocate the tree physics mesh")
	local Collider: MeshPart? = nil

	local Success, Error = pcall(function()
		for _, Triangle in Triangles do
			Work.Checkpoint()
			local Vertices = {}
			for Index, Vertex in Triangle.Vertices do
				Vertices[Index] = Mesh:AddVertex(Vertex.Position - Center)
			end
			Mesh:AddTriangle(Vertices[1], Vertices[2], Vertices[3])
		end
		local Result, Frozen = AssetService:CreateDataModelContentAsync(Content.fromObject(Mesh))
		assert(Result == Enum.CreateContentResult.Success, tostring(Result))
		Collider = AssetService:CreateMeshPartAsync(
			Frozen,
			{ CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition }
		)
		Collider.Size = (Max - Min) * Scale
		Collider.CFrame = Source.CFrame * CFrame.new(Center * Scale)
	end)
	Mesh:Destroy()
	if not Success then
		if Collider then
			Collider:Destroy()
		end
		error(Error)
	end

	return Collider
end

local function BuildBody(Tree: Model, Point: Vector3, Radius: number): BasePart
	ConfigureGroups()
	local Body = Instance.new("Model")
	Body.Name = "TreePhysicsBody"
	Body.Archivable = false
	Body.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local Root = Instance.new("Part")
	Root.Name = "FallingBodyRoot"
	Root.Size = Vector3.one * 0.1
	Root.CFrame = Tree:GetPivot()
	Root.Transparency = 1
	Root.Anchored, Root.CanCollide, Root.CanTouch, Root.CanQuery = true, false, false, false
	Root.Massless = true
	Root.RootPriority = 127
	Root.CollisionGroup = Config.FallCollisionGroup
	Root.Parent = Body
	Body.PrimaryPart = Root
	local Count, Top = 0, Point.Y + 1

	for _, Source in Tree:QueryDescendants("BasePart") :: { BasePart } do
		if not string.find(Source.Name, "Trunk", 1, true) then
			continue
		end
		Top = math.max(Top, Source.Position.Y + Source.Size.Magnitude * 0.5)
		if not Source:IsA("MeshPart") then
			continue
		end
		local Success, Collider = pcall(CreateCollider, Source, Point.Y)
		if Success and Collider then
			Collider.Name = "TreeWorldCollider"
			Collider.Transparency = 1
			Collider.Anchored, Collider.CanCollide, Collider.CanTouch, Collider.CanQuery = true, true, false, false
			Collider.CollisionGroup = Config.FallCollisionGroup
			Collider.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.65, 0.05, 100, 100)
			Collider.Parent = Body
			Count += 1
		elseif not Success then
			warn("[TreePhysics] Could not build the trunk collider: " .. tostring(Collider))
		end
	end

	if Count == 0 then
		local Collider = Instance.new("Part")
		Collider.Name = "TreeWorldCollider"
		Collider.Shape = Enum.PartType.Cylinder
		Collider.Size = Vector3.new(Top - Point.Y, Radius * 2, Radius * 2)
		Collider.CFrame = CFrame.new(Point + Up * (Top - Point.Y) * 0.5) * CFrame.Angles(0, 0, math.pi * 0.5)
		Collider.Transparency = 1
		Collider.Anchored, Collider.CanCollide, Collider.CanTouch, Collider.CanQuery = true, true, false, false
		Collider.CollisionGroup = Config.FallCollisionGroup
		Collider.Material = Enum.Material.Wood
		Collider.Parent = Body
	end

	for _, Part in Body:QueryDescendants("BasePart") :: { BasePart } do
		if Part == Root then
			continue
		end
		local Weld = Instance.new("WeldConstraint")
		Weld.Part0, Weld.Part1 = Root, Part
		Weld.Parent = Part
	end
	if not Tree:IsDescendantOf(workspace) then
		Body:Destroy()
		error("Tree was removed while preparing physics")
	end
	Body.Parent = Tree
	local Reference = Instance.new("ObjectValue")
	Reference.Archivable = false
	Reference.Name, Reference.Value, Reference.Parent = "FallingBody", Root, Tree

	return Root
end

function TreePhysicsService:Prepare(Tree: Model, Point: Vector3, Radius: number)
	if Prepared[Tree] then
		return
	end
	local Preparation: Preparation = { Cancelled = false, Pending = true, Finished = Instance.new("BindableEvent") }
	Prepared[Tree] = Preparation
	Tree.Destroying:Once(function()
		Prepared[Tree] = nil
		Preparation.Cancelled = true
		Preparation.Finished:Fire()
		if not Preparation.Pending then
			Preparation.Finished:Destroy()
		end
	end)

	task.spawn(function()
		local Success, Result = pcall(BuildBody, Tree, Point, Radius)
		Preparation.Pending = false
		if Preparation.Cancelled then
			if Success and Result.Parent then
				Result.Parent:Destroy()
			end
		elseif Success then
			Preparation.Root = Result
		else
			Preparation.Error = tostring(Result)
		end
		Preparation.Finished:Fire()
		if Preparation.Cancelled then
			Preparation.Finished:Destroy()
		end
	end)
end

function TreePhysicsService:IsPrepared(Tree: Model): boolean
	local Preparation = Prepared[Tree]
	return Preparation ~= nil and Preparation.Root ~= nil and not Preparation.Cancelled
end

function TreePhysicsService:CreateBody(Tree: Model, Point: Vector3, Radius: number): BasePart
	self:Prepare(Tree, Point, Radius)
	local Preparation = Prepared[Tree]
	assert(Preparation, "Tree was removed before preparing physics")
	while Preparation.Pending and not Preparation.Cancelled do
		Preparation.Finished.Event:Wait()
	end
	assert(not Preparation.Cancelled and Preparation.Root, Preparation.Error or "Tree was removed before falling")

	return Preparation.Root
end

function TreePhysicsService:Release(Root: BasePart, Direction: Vector3)
	for _, Part in Root.Parent:QueryDescendants("BasePart") :: { BasePart } do
		Part.CanCollide = Part ~= Root
		Part.Anchored = false
	end
	Root:SetNetworkOwner(nil)
	Root.AssemblyAngularVelocity = Up:Cross(Direction).Unit * Config.FallAngularSpeed
	Root.AssemblyLinearVelocity = Direction * Config.FallPushSpeed
end

function TreePhysicsService.KnitStart()
	ConfigureGroups()
	for _, Humanoid in workspace:QueryDescendants("Humanoid") :: { Humanoid } do
		local Model = Humanoid.Parent
		if Model and Model:IsA("Model") then
			TreePhysicsService:TrackEntity(Model)
		end
	end
	workspace.DescendantAdded:Connect(function(Instance: Instance)
		if Instance:IsA("Humanoid") and Instance.Parent and Instance.Parent:IsA("Model") then
			TreePhysicsService:TrackEntity(Instance.Parent)
		end
	end)
end

return TreePhysicsService
