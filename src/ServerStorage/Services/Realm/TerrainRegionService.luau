local RunService = game:GetService("RunService")

assert(RunService:IsServer(), "TerrainRegionService is server-only")

local TerrainRegionService = {}
local RESOLUTION = 4
local MAX_REGION_VOXELS = 4194304
local MAX_CHUNK_VOXELS = 262144

type Placement = {
	Corner: Vector3,
	Maximum: Vector3,
	Center: Vector3,
	Size: Vector3,
}

type Chunk = {
	Region: TerrainRegion,
	Offset: Vector3,
}

type Backup = {
	Region: TerrainRegion,
	Corner: Vector3,
}

type Job = {
	Execute: (() -> ())?,
	Completed: BindableEvent,
	Done: boolean,
	Success: boolean,
	Error: string?,
}

type RegionState = {
	Preset: TerrainRegion,
	Placement: Placement,
	Cancelled: boolean,
	Loaded: boolean,
	Backups: { Backup },
	LoadJob: Job,
	UnloadJob: Job?,
	DestroyConnection: RBXScriptConnection?,
}

local States: { [Model]: RegionState } = {}
local Queue: { [number]: Job } = {}
local Head, Tail = 1, 0
local Scheduled = false

local function NewJob(Execute: (() -> ())?): Job
	return {
		Execute = Execute,
		Completed = Instance.new("BindableEvent"),
		Done = false,
		Success = false,
	}
end

local function Complete(Job: Job, Success: boolean, Error: string?)
	Job.Success = Success
	Job.Error = Error
	Job.Done = true
	Job.Completed:Fire()

	task.defer(function()
		Job.Completed:Destroy()
	end)
end

local function ProcessNext()
	local Job = Queue[Head]
	Queue[Head] = nil
	Head += 1

	local Success, Error = pcall(Job.Execute :: () -> ())
	Complete(Job, Success, if Success then nil else tostring(Error))

	if Head <= Tail then
		RunService.Heartbeat:Once(ProcessNext)
	else
		Head, Tail = 1, 0
		Scheduled = false
	end
end

local function Enqueue(Execute: () -> ()): Job
	local Job = NewJob(Execute)
	Tail += 1
	Queue[Tail] = Job

	if not Scheduled then
		Scheduled = true
		RunService.Heartbeat:Once(ProcessNext)
	end

	return Job
end

local function Await(Job: Job): (boolean, string?)
	if not Job.Done then
		Job.Completed.Event:Wait()
	end

	return Job.Success, Job.Error
end

local function GetPlacement(Preset: TerrainRegion, Center: Vector3): Placement
	assert(typeof(Preset) == "Instance" and Preset:IsA("TerrainRegion"), "Expected a TerrainRegion preset")
	assert(typeof(Center) == "Vector3", "Expected a destination center in studs")
	for _, Component in { Center.X, Center.Y, Center.Z } do
		assert(Component == Component and math.abs(Component) < math.huge, "Invalid destination coordinates")
	end

	local Version = Preset:GetAttribute("FormatVersion")
	local Resolution = Preset:GetAttribute("VoxelResolution")
	assert(Version == nil or Version == 1, "Unsupported TerrainRegion preset version")
	assert(Resolution == nil or Resolution == RESOLUTION, "TerrainRegion requires a 4-stud voxel grid")

	local Cells = Preset.SizeInCells
	assert(Cells.X > 0 and Cells.Y > 0 and Cells.Z > 0, "Empty TerrainRegion preset")
	assert(Cells.X * Cells.Y * Cells.Z <= MAX_REGION_VOXELS, "Terrain preset exceeds 4194304 voxels")

	local Requested = Center / RESOLUTION - Cells / 2
	local Corner = Vector3.new(math.round(Requested.X), math.round(Requested.Y), math.round(Requested.Z))
	local Maximum = Corner + Cells
	assert(Corner.X >= -32768 and Corner.Y >= -32768 and Corner.Z >= -32768, "Terrain destination exceeds the cell grid")
	assert(Maximum.X <= 32768 and Maximum.Y <= 32768 and Maximum.Z <= 32768, "Terrain destination exceeds the cell grid")

	return {
		Corner = Corner,
		Maximum = Maximum,
		Center = (Corner + Cells / 2) * RESOLUTION,
		Size = Cells * RESOLUTION,
	}
end

local function Overlaps(First: Placement, Second: Placement): boolean
	return First.Corner.X < Second.Maximum.X and First.Maximum.X > Second.Corner.X
		and First.Corner.Y < Second.Maximum.Y and First.Maximum.Y > Second.Corner.Y
		and First.Corner.Z < Second.Maximum.Z and First.Maximum.Z > Second.Corner.Z
end

local function GetChunks(Preset: TerrainRegion): { Chunk }
	local Cells = Preset.SizeInCells
	local Volume = Cells.X * Cells.Y * Cells.Z
	local Folder = Preset:FindFirstChild("RuntimeChunks")
	if not Folder then
		assert(Volume <= MAX_CHUNK_VOXELS, "Large terrain preset requires RuntimeChunks; run tools/BakeTerrainRegion.luau in Studio")
		return { { Region = Preset, Offset = Vector3.zero } }
	end

	assert(Folder:IsA("Folder") and Folder:GetAttribute("FormatVersion") == 1, "Invalid RuntimeChunks folder")
	assert(Folder:GetAttribute("SizeInCells") == Cells, "RuntimeChunks no longer match the preset dimensions; bake again")

	local Chunks: { Chunk } = {}
	local Bounds: { Placement } = {}
	local Covered = 0
	for _, Child in Folder:GetChildren() do
		assert(Child:IsA("TerrainRegion"), "RuntimeChunks must contain only TerrainRegion objects")

		local Offset = Child:GetAttribute("CellOffset")
		assert(typeof(Offset) == "Vector3", "Terrain chunk requires a CellOffset")
		for _, Component in { Offset.X, Offset.Y, Offset.Z } do
			assert(Component >= 0 and Component == math.floor(Component), "Invalid terrain chunk offset")
		end

		local Size = Child.SizeInCells
		local Maximum = Offset + Size
		local ChunkVolume = Size.X * Size.Y * Size.Z
		assert(Size.X > 0 and Size.Y > 0 and Size.Z > 0 and ChunkVolume <= MAX_CHUNK_VOXELS, "Terrain chunk exceeds the native paste budget")
		assert(Maximum.X <= Cells.X and Maximum.Y <= Cells.Y and Maximum.Z <= Cells.Z, "Terrain chunk exceeds the preset bounds")

		local Bound: Placement = { Corner = Offset, Maximum = Maximum, Center = Vector3.zero, Size = Size }
		for _, Other in Bounds do
			assert(not Overlaps(Bound, Other), "Terrain chunks overlap")
		end
		table.insert(Bounds, Bound)
		table.insert(Chunks, { Region = Child, Offset = Offset })
		Covered += ChunkVolume
	end
	assert(Covered == Volume, "Terrain chunks must cover the entire preset, including empty cells")

	table.sort(Chunks, function(First: Chunk, Second: Chunk): boolean
		return First.Region.Name < Second.Region.Name
	end)

	return Chunks
end

local function CellVector(Value: Vector3): Vector3int16
	return Vector3int16.new(Value.X, Value.Y, Value.Z)
end

local function Release(Owner: Model, State: RegionState)
	if State.DestroyConnection then
		State.DestroyConnection:Disconnect()
	end
	if Owner.Parent then
		Owner:SetAttribute("TerrainLoaded", false)
	end
	States[Owner] = nil
end

-- Wait for pending writes, then restore each applied chunk before releasing the plot.
function TerrainRegionService.Unload(Owner: Model): (boolean, string?)
	local State = States[Owner]
	if not State then
		return true
	end

	State.Cancelled = true
	if Owner.Parent then
		Owner:SetAttribute("TerrainLoaded", false)
	end
	if State.UnloadJob then
		return Await(State.UnloadJob)
	end

	local UnloadJob = NewJob()
	State.UnloadJob = UnloadJob
	Await(State.LoadJob)

	local Success, Error = true, nil
	for Index = #State.Backups, 1, -1 do
		local Backup = State.Backups[Index]
		Success, Error = Await(Enqueue(function()
			workspace.Terrain:PasteRegion(Backup.Region, CellVector(Backup.Corner), true)
			Backup.Region:Destroy()
			table.remove(State.Backups, Index)
		end))
		if not Success then
			break
		end
	end

	if Success then
		Release(Owner, State)
	else
		-- Retain unrestored snapshots and the reservation so cleanup can be retried.
		State.UnloadJob = nil
	end
	Complete(UnloadJob, Success, Error)

	return Success, Error
end

-- Native chunk assets are shared by all islands. No voxel arrays or preset clones.
function TerrainRegionService.Load(Owner: Model, Preset: TerrainRegion, Center: Vector3): (boolean, string?)
	if typeof(Owner) ~= "Instance" or not Owner:IsA("Model") or not Owner:IsDescendantOf(workspace) then
		return false, "Terrain owner must be a Model in the Workspace"
	end

	local Valid, Result, Prepared = pcall(function(): (Placement, { Chunk })
		return GetPlacement(Preset, Center), GetChunks(Preset)
	end)
	if not Valid then
		return false, tostring(Result)
	end
	local Placement = Result :: Placement
	local Chunks = Prepared :: { Chunk }
	local Existing = States[Owner]
	if Existing then
		if Existing.Cancelled or Existing.Preset ~= Preset or Existing.Placement.Corner ~= Placement.Corner then
			return false, "Unload the owner's previous terrain before loading another preset or destination"
		end

		local Success, Error = Await(Existing.LoadJob)
		return Success and Existing.Loaded and not Existing.Cancelled, Error
	end

	for _, Other in States do
		if Overlaps(Placement, Other.Placement) then
			return false, "Terrain destination overlaps another active or unloading island"
		end
	end

	local State: RegionState = {
		Preset = Preset,
		Placement = Placement,
		Cancelled = false,
		Loaded = false,
		Backups = {},
		LoadJob = NewJob(),
	}
	States[Owner] = State
	State.DestroyConnection = Owner.Destroying:Connect(function()
		State.Cancelled = true
		task.defer(function()
			local Success, Error = TerrainRegionService.Unload(Owner)
			if not Success then
				warn("[TerrainRegion] Unable to restore a destroyed owner's terrain:", Error)
			end
		end)
	end)

	local Success, Error = true, nil
	for _, Chunk in Chunks do
		if State.Cancelled then
			break
		end

		Success, Error = Await(Enqueue(function()
			if State.Cancelled or not Owner:IsDescendantOf(workspace) then
				State.Cancelled = true
				return
			end

			local Corner = Placement.Corner + Chunk.Offset
			local Maximum = Corner + Chunk.Region.SizeInCells - Vector3.one
			local Bounds = Region3int16.new(CellVector(Corner), CellVector(Maximum))
			local Snapshot = workspace.Terrain:CopyRegion(Bounds)
			table.insert(State.Backups, { Region = Snapshot, Corner = Corner })
			workspace.Terrain:PasteRegion(Chunk.Region, CellVector(Corner), true)
		end))
		if not Success then
			break
		end
	end

	Success = Success and not State.Cancelled and Owner:IsDescendantOf(workspace)
	if Success then
		State.Loaded = true
		Owner:SetAttribute("TerrainCenter", Placement.Center)
		Owner:SetAttribute("TerrainSize", Placement.Size)
		Owner:SetAttribute("TerrainLoaded", true)
	end
	Complete(State.LoadJob, Success, if Success then nil else Error or "Terrain load cancelled")

	if not Success then
		local Restored, RestoreError = TerrainRegionService.Unload(Owner)
		if not Restored then
			return false, string.format("Terrain load failed (%s); restoration failed (%s)", tostring(Error), tostring(RestoreError))
		end
		return false, Error or "Terrain load cancelled"
	end

	return true
end

return TerrainRegionService
