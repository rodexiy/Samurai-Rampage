# Mental Realm terrain

The server loader is at
`ServerStorage.Services.Services.Realm.TerrainRegionService`.
`RealmService` loads every chunk before setting `Loaded` or teleporting a
character, and restores the previous terrain before releasing the plot.

## Current preset

The island is `ServerStorage.ServerAssets.RealmTemplate.MentalRealm`.
Its source is `assets/terrain/MentalRealm.rbxm`, mapped into that folder by
Rojo without replacing the template's structures or resources. It contains
2,090,286 voxels (612 x 264 x 828 studs), prepared as 24 native terrain chunks.
No asset download or DataStore request is needed during play.

The template can be a Folder or Model. Its embedded `MentalRealm` TerrainRegion
is selected automatically. An explicit `TerrainPreset` string attribute selects
a matching child, or a preset in `ServerStorage.TerrainLibrary`. Legacy templates
without embedded terrain still fall back to `Ilha Mental` in that library.

TerrainRegion children stay in ServerStorage; realm instances only clone the
structures, resources and other gameplay objects.

## Alignment

When `Foundation.Baseplate` exists, it remains the realm model's PrimaryPart.
Otherwise, the model uses the preset's saved `SourceCenter` as its source pivot.
The current Folder template requires no Baseplate: its structures retain their
original positions relative to the saved island.

Optional placement controls:

- `TerrainOffset` (Vector3 attribute on the template): island center relative
  to the realm pivot, in studs; defaults to zero.
- An anchored, invisible `Foundation.TerrainOrigin` BasePart can mark the island's
  desired center and takes precedence over that offset.

Terrain uses world axes and a 4-stud grid, with no rotation. If snapping shifts
the center by up to two studs per axis, the realm model receives the same shift.

## Loading and cleanup

```luau
local ServerStorage = game:GetService("ServerStorage")
local TerrainRegionService = require(ServerStorage.Services.Services.Realm.TerrainRegionService)

local Preset = ServerStorage.ServerAssets.RealmTemplate:FindFirstChild("MentalRealm") :: TerrainRegion
local Success, Error = TerrainRegionService.Load(RealmModel, Preset, Vector3.new(4096, 0, 4096))
if not Success then
	warn(Error)
	return
end

-- Before removing/reusing the realm's plot:
local Restored, RestoreError = TerrainRegionService.Unload(RealmModel)
if not Restored then
	warn(RestoreError)
end
```

Both calls yield until their work finishes. Duplicate loads for the same owner,
preset and destination share completion. Unload cancels pending writes, waits
for load completion and restores every applied chunk. Owner destruction also
requests cleanup. Reservations cover the entire island until restoration ends;
overlapping islands are rejected. If restoration fails, the remaining snapshots
and reservation stay available for a subsequent Unload retry.

One chunk load or restoration runs per Heartbeat, with no permanent connection
or polling while idle. Concurrent islands take turns through the same queue.
Native chunk assets are shared; no voxel arrays or preset clones are created.
Each applied chunk has a native snapshot for restoration. Roblox replicates
terrain normally, and the existing streaming request runs before teleport.

## Preparing updated terrain

Small native TerrainRegions up to 262,144 voxels work directly. Larger presets
up to 4,194,304 voxels require a `RuntimeChunks` child Folder:

- `FormatVersion = 1` and `SizeInCells` attributes on the folder.
- TerrainRegion children with a `CellOffset` Vector3 relative to the preset's
  minimum cell.
- Each chunk contains at most 262,144 voxels; all chunks cover the entire preset,
  including air, without gaps or overlap.

To prepare a newly saved preset, select it and run the contents of
`tools/BakeTerrainRegion.luau` from Studio's Command Bar in edit mode. The tool
temporarily pastes the preset in a distant staging area, copies blocks of up to
64 x 64 x 64 cells, restores the staging area, and replaces RuntimeChunks.
Update the asset file when changing the saved terrain so Rojo preserves it.

The current MentalRealm asset is already prepared. Individual native chunk
operations are atomic; spacing them across frames does not guarantee a fixed
frame time on every server. Global material colors and water appearance are
not part of the preset.

## Validation

`tests/TerrainRegionService.spec.luau` checks native/chunked loading, frame
spacing, duplicate requests, water/air, validation, overlap rejection,
restoration and cancellation before and between chunk writes.
`tests/RealmTerrainIntegration.spec.luau` checks readiness, resource ownership,
teleport, plot reuse and the actual Folder template with its embedded island.
Profile/Knit dependencies are isolated in that integration fixture.
