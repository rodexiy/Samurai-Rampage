-- Run from the Studio Command Bar with one saved TerrainRegion selected.
local Selection = game:GetService("Selection")
local RunService = game:GetService("RunService")

assert(not RunService:IsRunning(), "Bake terrain in Studio edit mode")

local Preset = Selection:Get()[1]
assert(Preset and Preset:IsA("TerrainRegion"), "Select one saved TerrainRegion")

local Cells = Preset.SizeInCells
local StagingCorner = Vector3.new(25000, 25000, 25000)
local Last = StagingCorner + Cells - Vector3.one
assert(Last.X <= 32767 and Last.Y <= 32767 and Last.Z <= 32767, "Preset exceeds the staging area")

local function CellVector(Value: Vector3): Vector3int16
	return Vector3int16.new(Value.X, Value.Y, Value.Z)
end

local Bounds = Region3int16.new(CellVector(StagingCorner), CellVector(Last))
local Backup = workspace.Terrain:CopyRegion(Bounds)
local Chunks = Instance.new("Folder")
Chunks.Name = "RuntimeChunks"
Chunks:SetAttribute("FormatVersion", 1)
Chunks:SetAttribute("SizeInCells", Cells)

local Success, Error = pcall(function()
	workspace.Terrain:PasteRegion(Preset, CellVector(StagingCorner), true)

	for X = 0, Cells.X - 1, 64 do
		for Y = 0, Cells.Y - 1, 64 do
			for Z = 0, Cells.Z - 1, 64 do
				local Offset = Vector3.new(X, Y, Z)
				local Size = (Cells - Offset):Min(Vector3.one * 64)
				local Minimum = StagingCorner + Offset
				local Maximum = Minimum + Size - Vector3.one
				local Chunk = workspace.Terrain:CopyRegion(Region3int16.new(CellVector(Minimum), CellVector(Maximum)))
				Chunk.Name = string.format("Chunk_%03d_%03d_%03d", X, Y, Z)
				Chunk:SetAttribute("CellOffset", Offset)
				Chunk.Parent = Chunks

				task.wait()
			end
		end
	end
end)

local Restored, RestoreError = pcall(function()
	workspace.Terrain:PasteRegion(Backup, CellVector(StagingCorner), true)
end)
if Restored then
	Backup:Destroy()
else
	-- Retain the snapshot if restoration fails so the user can retry safely.
	Backup.Name = "TerrainBakeRecovery"
	Backup:SetAttribute("RestoreCorner", StagingCorner)
	Backup.Parent = Preset
end

if not Success or not Restored then
	Chunks:Destroy()
	error(tostring(Error or RestoreError))
end

local Previous = Preset:FindFirstChild("RuntimeChunks")
if Previous then
	Previous:Destroy()
end
Chunks.Parent = Preset

return #Chunks:GetChildren()
