local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Config = require(ReplicatedStorage.Shared.TreeCuttingConfig)
local Math = require(ReplicatedStorage.Shared.Utils.TreeCuttingMath)
local Meshes = require(Players.LocalPlayer.PlayerScripts.Client.Controllers.TreeCuttingController.TreeMeshController)

local TreeCuttingController = Knit.CreateController({ Name = "TreeCuttingController" })
type Entry = { Data: Meshes.SourceData, Triangles: { any }, Visual: Meshes.Visual }
type PreparedFall = { Top: Model, Stump: Model, Visuals: { Meshes.Visual }, Version: number, Origin: CFrame }
type State = {
	Cuts: { Math.Cut },
	Point: Vector3?,
	Prepared: PreparedFall?,
	Preparing: boolean,
	PreparationFinished: BindableEvent,
	Entries: { [MeshPart]: Entry },
	Hidden: { [BasePart]: number },
	Version: number,
	Rendered: number,
	Busy: boolean,
	Falling: boolean,
	Disposed: boolean,
	FallVisuals: { Meshes.Visual },
	Top: Model?,
	Stump: Model?,
	BodyConnections: { RBXScriptConnection },
}
type FallData = { Origin: CFrame, Point: Vector3, Body: BasePart?, Started: number }

local States: { [Model]: State } = {}
local Service
local PrepareFall: (Model, State) -> ()

local function DestroyPrepared(Prepared: PreparedFall)
	for _, Visual in Prepared.Visuals do
		Meshes.Destroy(Visual)
	end
	Prepared.Top:Destroy()
	Prepared.Stump:Destroy()
end

local function IsNamed(Part: BasePart, Name: string): boolean
	return string.find(Part.Name, Name, 1, true) ~= nil
end

local function Hide(State: State, Part: BasePart)
	if State.Hidden[Part] == nil then
		State.Hidden[Part] = Part.LocalTransparencyModifier
	end
	Part.LocalTransparencyModifier = 1
end

local function ClearEntries(State: State)
	for _, Entry in State.Entries do
		Meshes.Destroy(Entry.Visual)
	end
	table.clear(State.Entries)
end

local function Cleanup(Tree: Model)
	local State = States[Tree]
	if not State then
		return
	end
	State.Disposed = true
	if State.Prepared then
		DestroyPrepared(State.Prepared)
		State.Prepared = nil
	end
	State.PreparationFinished:Fire()
	if not State.Preparing then
		State.PreparationFinished:Destroy()
	end
	for _, Connection in State.BodyConnections do
		Connection:Disconnect()
	end
	ClearEntries(State)
	for _, Visual in State.FallVisuals do
		Meshes.Destroy(Visual)
	end
	if State.Top then
		State.Top:Destroy()
	end
	if State.Stump then
		State.Stump:Destroy()
	end
	for Part, Transparency in State.Hidden do
		if Part.Parent and not State.Falling then
			Part.LocalTransparencyModifier = Transparency
		end
	end
	States[Tree] = nil
end

local function GetState(Tree: Model): State
	if States[Tree] then
		return States[Tree]
	end
	local State: State = {
		Cuts = {},
		Preparing = false,
		PreparationFinished = Instance.new("BindableEvent"),
		Entries = {},
		Hidden = {},
		Version = 0,
		Rendered = 0,
		Busy = false,
		Falling = false,
		Disposed = false,
		FallVisuals = {},
		BodyConnections = {},
	}
	States[Tree] = State
	Tree.Destroying:Once(function()
		Cleanup(Tree)
	end)
	Tree.AncestryChanged:Connect(function()
		if not Tree:IsDescendantOf(workspace) then
			Cleanup(Tree)
		end
	end)

	return State
end

local function Refresh(Tree: Model, State: State)
	if State.Busy or State.Falling or State.Disposed then
		return
	end
	State.Busy = true
	local Success, Error = pcall(function()
		-- Engine mesh creation yields; coalesce any hits received while it is working.
		while State.Rendered ~= State.Version and not State.Falling and not State.Disposed do
			local Version = State.Version
			local Cuts = table.clone(State.Cuts)
			for _, Source in Tree:QueryDescendants("MeshPart") :: { MeshPart } do
				if not IsNamed(Source, "Trunk") then
					continue
				end
				local Data = Meshes.Read(Source)
				local Triangles = Data.Triangles
				for _, Cut in Cuts do
					Triangles = Meshes.Cut(Source, Triangles, Cut)
				end
				local Visual = Meshes.Build(Source, Data, Triangles)
				if State.Disposed or State.Falling or State.Version ~= Version then
					Meshes.Destroy(Visual)
					break
				end

				local Previous = State.Entries[Source]
				for _, Part in Visual.Parts do
					Part.Parent = workspace.VFX
				end
				Hide(State, Source)
				State.Entries[Source] = { Data = Data, Triangles = Triangles, Visual = Visual }
				if Previous then
					Meshes.Destroy(Previous.Visual)
				end
			end
			State.Rendered = Version
		end
	end)
	State.Busy = false
	if Success then
		PrepareFall(Tree, State)
	end
	if not Success then
		warn("[TreeCutting] Could not build the local cut: " .. tostring(Error))
	end
end

local function AddVisual(
	State: State,
	Prepared: PreparedFall,
	Model: Model,
	Source: MeshPart,
	Data: Meshes.SourceData,
	Triangles: { any }
)
	local Visual = Meshes.Build(Source, Data, Triangles)
	if State.Disposed then
		Meshes.Destroy(Visual)
		return
	end
	table.insert(Prepared.Visuals, Visual)
	for _, Part in Visual.Parts do
		Part.Parent = Model
	end
end

local function ReadFall(Tree: Model): FallData?
	local Origin, Point = Tree:GetAttribute("TreeFallOrigin"), Tree:GetAttribute("TreeFallPoint")
	local Started = Tree:GetAttribute("TreeFallStarted")
	local Reference = Tree:FindFirstChild("FallingBody") :: ObjectValue?
	if typeof(Origin) ~= "CFrame" or typeof(Point) ~= "Vector3" or typeof(Started) ~= "number" then
		return nil
	end

	return { Origin = Origin, Point = Point, Body = Reference and Reference.Value :: BasePart?, Started = Started }
end

local function DelayUntil(Time: number, Callback: () -> ())
	task.delay(math.max(0, Time - workspace:GetServerTimeNow()), Callback)
end

local function FollowBody(State: State, Tree: Model, Top: Model, InitialBody: BasePart?)
	local Attached = false
	local function TryAttach(): boolean
		if Attached or State.Disposed then
			return true
		end
		local Reference = Tree:FindFirstChild("FallingBody") :: ObjectValue?
		local Body = InitialBody or (Reference and Reference.Value :: BasePart?)
		if not Body or not Body:IsDescendantOf(workspace) then
			return false
		end
		Attached = true
		for _, Connection in State.BodyConnections do
			Connection:Disconnect()
		end
		table.clear(State.BodyConnections)
		Top:PivotTo(Body.CFrame)
		for _, Part in Top:QueryDescendants("BasePart") :: { BasePart } do
			Part.Anchored = false
			Part.CanCollide = false
			Part.Massless = true
			local Weld = Instance.new("WeldConstraint")
			Weld.Name = "TreeBodyWeld"
			Weld.Part0, Weld.Part1 = Body, Part
			Weld.Parent = Part
		end
		Top.PrimaryPart = Top:FindFirstChildWhichIsA("BasePart", true)
		return true
	end

	local function WatchReference(Reference: Instance)
		if Reference:IsA("ObjectValue") and Reference.Name == "FallingBody" then
			table.insert(State.BodyConnections, Reference:GetPropertyChangedSignal("Value"):Connect(TryAttach))
		end
	end

	if TryAttach() then
		return
	end
	local Reference = Tree:FindFirstChild("FallingBody")
	if Reference then
		WatchReference(Reference)
	end
	table.insert(
		State.BodyConnections,
		Tree.DescendantAdded:Connect(function(Instance: Instance)
			WatchReference(Instance)
			TryAttach()
		end)
	)
end

local function BuildFall(Tree: Model, State: State, Origin: CFrame, Height: number, Version: number): PreparedFall
	local Top, Stump = Instance.new("Model"), Instance.new("Model")
	Top.Name, Stump.Name = "FallingTree", "TreeStump"
	local Prepared: PreparedFall = { Top = Top, Stump = Stump, Visuals = {}, Version = Version, Origin = Origin }
	local Snapshots: { BasePart } = {}
	local Originals: { [BasePart]: BasePart } = {}
	local Cuts = table.clone(State.Cuts)
	local Rebase = Origin * Tree:GetPivot():Inverse()

	for _, Source in Tree:QueryDescendants("BasePart") :: { BasePart } do
		if not IsNamed(Source, "Trunk") and not IsNamed(Source, "Canopy") then
			continue
		end
		local Copy = Source:Clone()
		Copy.CFrame = Rebase * Source.CFrame
		Copy.LocalTransparencyModifier = 0
		Copy.Anchored, Copy.CanCollide, Copy.CanQuery, Copy.CanTouch = true, false, false, false
		for _, Tag in Copy:GetTags() do
			Copy:RemoveTag(Tag)
		end
		table.insert(Snapshots, Copy)
		Originals[Copy] = Source
	end

	local Success, Error = pcall(function()
		for _, Copy in Snapshots do
			if Copy:IsA("MeshPart") and IsNamed(Copy, "Trunk") then
				local Entry = State.Entries[Originals[Copy] :: MeshPart]
				local SourceData = if Entry then Entry.Data else Meshes.Read(Copy)
				local Triangles = SourceData.Triangles
				if Entry and State.Rendered == Version then
					Triangles = Entry.Triangles
				else
					for _, Cut in Cuts do
						Triangles = Meshes.Cut(Copy, Triangles, Cut)
					end
				end
				local Upper, Lower = Meshes.Split(Copy, Triangles, Height)
				AddVisual(State, Prepared, Top, Copy, SourceData, Upper)
				AddVisual(State, Prepared, Stump, Copy, SourceData, Lower)
			else
				Copy:Clone().Parent = Top
			end
		end
	end)
	if not Success and not State.Disposed then
		warn("[TreeCutting] Could not split the visual trunk: " .. tostring(Error))
		for _, Visual in Prepared.Visuals do
			Meshes.Destroy(Visual)
		end
		table.clear(Prepared.Visuals)
		Top:ClearAllChildren()
		Stump:ClearAllChildren()
		for _, Copy in Snapshots do
			Copy:Clone().Parent = Top
		end
	end
	for _, Copy in Snapshots do
		Copy:Destroy()
	end
	Top.WorldPivot, Stump.WorldPivot = Origin, Origin

	return Prepared
end

PrepareFall = function(Tree: Model, State: State)
	if State.Preparing or State.Falling or State.Disposed or not State.Point then
		return
	end
	State.Preparing = true
	task.spawn(function()
		local Success, Error = pcall(function()
			while not State.Disposed and not State.Falling and State.Point do
				if #State.Cuts > 0 and State.Rendered ~= State.Version then
					break
				end
				if State.Prepared and State.Prepared.Version == State.Version then
					break
				end
				local Version = State.Version
				local Prepared = BuildFall(Tree, State, Tree:GetPivot(), State.Point.Y, Version)
				if State.Disposed or State.Version ~= Version then
					DestroyPrepared(Prepared)
				else
					local Previous = State.Prepared
					Prepared.Top.Name, Prepared.Stump.Name = "PreparedTreeFall", "PreparedTreeStump"
					for _, Model in { Prepared.Top, Prepared.Stump } do
						for _, Part in Model:QueryDescendants("BasePart") :: { BasePart } do
							Part.LocalTransparencyModifier = 1
						end
						Model.Parent = workspace.VFX
					end
					State.Prepared = Prepared
					if Previous then
						DestroyPrepared(Previous)
					end
				end
			end
		end)
		State.Preparing = false
		State.PreparationFinished:Fire()
		if State.Disposed then
			State.PreparationFinished:Destroy()
		elseif not Success then
			warn("[TreeCutting] Could not prepare the fall: " .. tostring(Error))
		end
	end)
end

local function StartFall(Tree: Model, Data: FallData?)
	Data = Data or ReadFall(Tree)
	if not Data or not Tree:IsDescendantOf(workspace) then
		return
	end
	local State = GetState(Tree)
	if State.Falling or State.Disposed then
		return
	end
	State.Falling = true
	while State.Preparing and not State.Disposed do
		State.PreparationFinished.Event:Wait()
	end
	if State.Disposed then
		return
	end
	local Prepared = State.Prepared
	State.Prepared = nil
	if not Prepared or Prepared.Version ~= State.Version then
		if Prepared then
			DestroyPrepared(Prepared)
		end
		Prepared = BuildFall(Tree, State, Data.Origin, Data.Point.Y, State.Version)
	end
	if State.Disposed then
		DestroyPrepared(Prepared)
		return
	end
	local Top, Stump = Prepared.Top, Prepared.Stump
	Top.Name, Stump.Name = "FallingTree", "TreeStump"
	for _, Model in { Top, Stump } do
		for _, Part in Model:QueryDescendants("BasePart") :: { BasePart } do
			Part.LocalTransparencyModifier = 0
		end
	end
	if Prepared.Origin ~= Data.Origin then
		Top:PivotTo(Data.Origin)
		Stump:PivotTo(Data.Origin)
	end
	State.Top, State.Stump, State.FallVisuals = Top, Stump, Prepared.Visuals
	ClearEntries(State)
	for _, Source in Tree:QueryDescendants("BasePart") :: { BasePart } do
		if IsNamed(Source, "Trunk") or IsNamed(Source, "Canopy") then
			Hide(State, Source)
		end
	end
	Top.Parent, Stump.Parent = workspace.VFX, workspace.VFX
	FollowBody(State, Tree, Top, Data.Body)

	DelayUntil(Data.Started + Config.StumpLifetime, function()
		if not State.Disposed then
			Stump:Destroy()
		end
	end)
	DelayUntil(Data.Started + Config.FallDuration + Config.CanopyLifetimeAfterFall, function()
		if State.Disposed then
			return
		end
		for _, Part in Top:QueryDescendants("BasePart") :: { BasePart } do
			if IsNamed(Part, "Canopy") then
				Part:Destroy()
			end
		end
	end)
	DelayUntil(Data.Started + Config.FallDuration + Config.TrunkLifetimeAfterFall, function()
		Cleanup(Tree)
	end)
end

function TreeCuttingController.KnitInit()
	Service = Knit.GetService("TreeCuttingService")
end

function TreeCuttingController.KnitStart()
	Service.Prepare:Connect(function(Tree: Model, Point: Vector3, Hitter: Player)
		if Hitter == Players.LocalPlayer or not Tree or not Tree:IsDescendantOf(workspace) then
			return
		end
		local State = GetState(Tree)
		State.Point = Point
		PrepareFall(Tree, State)
	end)
	Service.Cut:Connect(function(Tree: Model, Cut: Math.Cut)
		if not Tree or not Tree:IsDescendantOf(workspace) then
			return
		end
		local State = GetState(Tree)
		if State.Falling or Cut.Felling then
			return
		end
		State.Point = Cut.Center
		local Replaced = false
		for Index, Previous in State.Cuts do
			if Previous.Direction:Dot(Cut.Direction) > 0.999 then
				State.Cuts[Index] = Cut
				Replaced = true
				break
			end
		end
		if not Replaced then
			table.insert(State.Cuts, Cut)
		end
		State.Version += 1
		task.spawn(Refresh, Tree, State)
	end)
	Service.Felled:Connect(function(Tree: Model, Data: FallData)
		if Tree then
			task.spawn(StartFall, Tree, Data)
		end
	end)
	CollectionService:GetInstanceAddedSignal("FelledTree"):Connect(function(Tree: Instance)
		if Tree:IsA("Model") then
			task.spawn(StartFall, Tree, nil)
		end
	end)
	for _, Tree in CollectionService:GetTagged("FelledTree") do
		if Tree:IsA("Model") then
			task.spawn(StartFall, Tree, nil)
		end
	end
end

return TreeCuttingController
