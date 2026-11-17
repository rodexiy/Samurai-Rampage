return function(Service: any): string
	local RunService = game:GetService("RunService")
	local Terrain = workspace.Terrain
	local Minimum = Vector3.new(100000, 100000, 100000)
	local Destination = Minimum + Vector3.new(40, 8, 8)
	local Bounds = Region3int16.new(Vector3int16.new(25000, 25000, 25000), Vector3int16.new(25015, 25003, 25003))
	local Backup = Terrain:CopyRegion(Bounds)
	local Fixture = Instance.new("Folder")
	Fixture.Name = "TerrainRegionServiceTests"
	Fixture.Parent = workspace
	local Preset: TerrainRegion?
	local PlainPreset: TerrainRegion?
	local Checks = 0
	local Frame = 0
	local Clock = RunService.Heartbeat:Connect(function()
		Frame += 1
	end)

	local function Check(Condition: boolean, Message: string)
		assert(Condition, Message)
		Checks += 1
	end

	local function Owner(Name: string): Model
		local Model = Instance.new("Model")
		Model.Name = Name
		Model.Parent = Fixture

		return Model
	end

	local function MaterialAt(Position: Vector3): Enum.Material
		local Materials = Terrain:ReadVoxels(Region3.new(Position, Position + Vector3.one * 4), 4)

		return Materials[1][1][1]
	end

	local function Join(Actions: { () -> () })
		local Done = Instance.new("BindableEvent")
		local Remaining = #Actions
		local Failure: string?
		for _, Action in Actions do
			task.spawn(function()
				local Success, Error = pcall(Action)
				if not Success then
					Failure = tostring(Error)
				end
				Remaining -= 1
				if Remaining == 0 then
					Done:Fire()
				end
			end)
		end
		if Remaining > 0 then
			Done.Event:Wait()
		end
		Done:Destroy()
		assert(not Failure, Failure)
	end

	local Success, Error = pcall(function()
		Terrain:FillBlock(CFrame.new(Minimum + Vector3.new(32, 8, 8)), Vector3.new(64, 16, 16), Enum.Material.Rock)
		Terrain:FillBlock(CFrame.new(Minimum + Vector3.one * 8), Vector3.one * 16, Enum.Material.Air)
		Terrain:FillBlock(CFrame.new(Minimum + Vector3.new(4, 8, 8)), Vector3.new(8, 16, 16), Enum.Material.Grass)
		Terrain:FillBlock(CFrame.new(Minimum + Vector3.new(10, 8, 8)), Vector3.new(4, 16, 16), Enum.Material.Water)
		Preset = Terrain:CopyRegion(Region3int16.new(Bounds.Min, Vector3int16.new(25003, 25003, 25003)))
		Preset:SetAttribute("FormatVersion", 1)
		local First = Owner("First")
		local Second = Owner("Second")
		Preset:SetAttribute("VoxelResolution", 8)
		Check(not Service.Load(First, Preset, Destination), "Reject unsupported voxel resolutions")
		Preset:SetAttribute("VoxelResolution", 4)
		local Oversized = Terrain:CopyRegion(Region3int16.new(Vector3int16.new(1000, 1000, 1000), Vector3int16.new(1064, 1063, 1063)))
		local AcceptedOversized = Service.Load(First, Oversized, Destination)
		Oversized:Destroy()
		Check(not AcceptedOversized, "Reject presets exceeding the atomic runtime paste budget")
		Preset:SetAttribute("VoxelResolution", 4)

		Check(not Service.Load(First, Preset, Vector3.new(0 / 0, 0, 0)), "Reject NaN coordinates")
		Check(not Service.Load(First, Preset, Vector3.one * 131072), "Reject destinations outside the native cell grid")
		Preset:SetAttribute("FormatVersion", 2)
		Check(not Service.Load(First, Preset, Destination), "Reject unsupported preset versions")
		Preset:SetAttribute("FormatVersion", 1)

		Join({
			function()
				Check(Service.Load(First, Preset, Destination), "Load a native preset")
			end,
			function()
				Check(Service.Load(First, Preset, Destination), "Coalesce concurrent loads for the same owner")
			end,
		})
		Check(First:GetAttribute("TerrainLoaded") == true, "Publish readiness only after terrain is written")
		Check(MaterialAt(Minimum + Vector3.new(32, 0, 0)) == Enum.Material.Grass, "Preserve solid materials")
		Check(MaterialAt(Minimum + Vector3.new(40, 0, 0)) == Enum.Material.Water, "Preserve water")
		Check(MaterialAt(Minimum + Vector3.new(44, 0, 0)) == Enum.Material.Air, "Copy empty cells for an exact island")
		Check(not Service.Load(Second, Preset, Destination), "Reject overlapping islands")
		Check(not Service.Load(First, Preset, Destination + Vector3.xAxis * 16), "Reject moving a loaded owner without unloading")
		Check(Service.Unload(First), "Unload the island")
		Check(MaterialAt(Minimum + Vector3.new(32, 0, 0)) == Enum.Material.Rock, "Restore terrain that existed before loading")
		Check(Service.Unload(First), "Unloading twice is safe")

		local FirstFrame, SecondFrame = 0, 0
		Join({
			function()
				assert(Service.Load(First, Preset, Destination))
				FirstFrame = Frame
			end,
			function()
				assert(Service.Load(Second, Preset, Destination + Vector3.xAxis * 16))
				SecondFrame = Frame
			end,
		})
		Check(SecondFrame > FirstFrame, "Process different islands on separate Heartbeats")
		Check(Service.Unload(First) and Service.Unload(Second), "Release adjacent, non-overlapping islands")

		local Cancelled = Owner("Cancelled")
		Join({
			function()
				Check(not Service.Load(Cancelled, Preset, Destination), "Cancel an enqueued load")
			end,
			function()
				Check(Service.Unload(Cancelled), "Wait for cancellation and cleanup before returning")
			end,
		})
		Check(MaterialAt(Minimum + Vector3.new(32, 0, 0)) == Enum.Material.Rock, "A cancelled load leaves no terrain")

		local Destroyed = Owner("Destroyed")
		Join({
			function()
				Check(not Service.Load(Destroyed, Preset, Destination), "Cancel when an owner is destroyed before loading")
			end,
			function()
				Destroyed:Destroy()
			end,
		})
		Check(Service.Load(First, Preset, Destination), "Reuse a destination after cancellation")
		Check(Service.Unload(First), "Restore a reused destination")

		local LoadedOwner = Owner("DestroyedAfterLoad")
		assert(Service.Load(LoadedOwner, Preset, Destination))
		LoadedOwner:Destroy()
		Check(Service.Unload(LoadedOwner), "Restore terrain when an already-loaded owner is destroyed")
		Check(MaterialAt(Minimum + Vector3.new(32, 0, 0)) == Enum.Material.Rock, "Owner destruction restores the original terrain")

		PlainPreset = Preset:Clone()
		local Chunks = Instance.new("Folder")
		Chunks.Name = "RuntimeChunks"
		Chunks:SetAttribute("FormatVersion", 1)
		Chunks:SetAttribute("SizeInCells", Preset.SizeInCells)
		for X = 0, 2, 2 do
			local Chunk = Terrain:CopyRegion(Region3int16.new(Vector3int16.new(25000 + X, 25000, 25000), Vector3int16.new(25001 + X, 25003, 25003)))
			Chunk.Name = tostring(X)
			Chunk:SetAttribute("CellOffset", Vector3.xAxis * X)
			Chunk.Parent = Chunks
		end
		Chunks.Parent = Preset

		local Started = Frame
		Check(Service.Load(First, Preset, Destination), "Load a chunked preset")
		Check(Frame - Started >= 2, "Schedule individual chunks on separate Heartbeats")
		Check(First:GetAttribute("TerrainLoaded") == true, "Publish readiness after all chunks complete")
		Check(MaterialAt(Minimum + Vector3.new(40, 0, 0)) == Enum.Material.Water, "Preserve water across chunk boundaries")
		Check(Service.Unload(First), "Restore all chunk snapshots")
		Check(MaterialAt(Minimum + Vector3.new(32, 0, 0)) == Enum.Material.Rock, "Restore the first chunk")
		Check(MaterialAt(Minimum + Vector3.new(44, 0, 0)) == Enum.Material.Rock, "Restore the last chunk")

		local LastChunk = Chunks:FindFirstChild("2") :: TerrainRegion
		LastChunk.Parent = nil
		Check(not Service.Load(First, Preset, Destination), "Reject chunk coverage with gaps")
		LastChunk.Parent = Chunks
		LastChunk:SetAttribute("CellOffset", Vector3.zero)
		Check(not Service.Load(First, Preset, Destination), "Reject overlapping chunks")
		LastChunk:SetAttribute("CellOffset", Vector3.xAxis * 2)
		Chunks:SetAttribute("SizeInCells", Vector3.one * 5)
		Check(not Service.Load(First, Preset, Destination), "Reject stale chunk dimensions")
		Chunks:SetAttribute("SizeInCells", Preset.SizeInCells)

		Join({
			function()
				Check(not Service.Load(First, Preset, Destination), "Cancel between chunk writes")
			end,
			function()
				assert(Service.Load(Second, PlainPreset, Destination + Vector3.xAxis * 16))
				Check(not First:GetAttribute("TerrainLoaded"), "A partially written island is not ready")
				Check(Service.Unload(First), "Restore partially loaded islands")
				assert(Service.Unload(Second))
			end,
		})
		Check(MaterialAt(Minimum + Vector3.new(32, 0, 0)) == Enum.Material.Rock, "Partial cancellation restores applied chunks")
		Check(MaterialAt(Minimum + Vector3.new(44, 0, 0)) == Enum.Material.Rock, "Partial cancellation leaves unapplied chunks untouched")
	end)

	for _, Model in Fixture:GetChildren() do
		Service.Unload(Model)
	end
	Fixture:Destroy()
	Clock:Disconnect()
	Terrain:PasteRegion(Backup, Bounds.Min, true)
	Backup:Destroy()
	if Preset then
		Preset:Destroy()
	end
	if PlainPreset then
		PlainPreset:Destroy()
	end
	assert(Success, tostring(Error))

	return tostring(Checks) .. " terrain lifecycle checks passed"
end
