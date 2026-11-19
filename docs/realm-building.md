# Realm building

`RealmEdit` is the existing `StarterGui` ScreenGui. It starts disabled and opens with
the realm editor. Terrain editing and the remaining tools stay deferred.
Left click places a copy; the asset remains selected. R rotates clockwise by 15°;
X cancels placement and restores the list. Placement and persistence are authoritative
on the server through Knit signals.

## Asset catalog

The catalog reads folders dynamically:

```text
ReplicatedStorage.Assets.RealmAssets
  Decorations
    <category>
      <Model or BasePart>
  Utility
    <category>
      <Model or BasePart>
```

The existing `Decorations/Chair/Simple Wood Stool` keeps its original catalog key.
The 34 models staged in `Workspace.ObjetsForRealm` were copied into Decorations
(`Vegetation`, `Rocks`, `Fences`, `Tables`, `Lamps`, `Props`, `Ornaments`) and Utility
(`Workstations`). Drying racks, the well and the wooden crate are in `Decorations/Props`.
The originals remain in Workspace. See
[the asset catalog](realm-assets-catalog.md) for every model and its initial resource cost.
Specialized Utility functions and terrain editing remain deferred.

ALL is the first category in each build tab and lists every object from that tab.
Search matches item names, display names, categories and descriptions, ignoring case
and extra whitespace. Searching the category screen searches the entire tab; searching
inside a category stays in that category. Placement keys always retain the real category.

## Asset attributes

| Attribute | Default | Meaning |
| --- | --- | --- |
| `DisplayName` (string) | instance name | Name shown in the list and details |
| `Description` (string) | empty | Hover description |
| `Icon` (string) | empty | Optional image content ID; otherwise use a viewport |
| `PlacementType` (string) | `Floor` | `Wall` attaches to vertical surfaces; otherwise stays upright on floors |
| `SupportsPlacement` (boolean) | false | A placed object can support objects on its upward facing surfaces |
| `SupportsWallPlacement` (boolean) | false | A placed object can support wall mounted objects |
| `PlacementSurface` (string, on a surface or ancestor) | absent | Explicit `Floor` or `Wall` support surface |
| `Cost_<item name>` (positive integer) | absent | Units of an inventory resource consumed per placement, e.g. `Cost_WoodLog = 2` |

For finer control, put invisible collidable support parts in a model's `BuildingAreas`
folder and set their `PlacementSurface` attribute. Avoid extending support parts
outside the intended placement surface. Bounds include visible or collidable BaseParts;
fully invisible noncollidable effect carriers do not enlarge the placement bounds or
block other objects. Keep support geometry within the intended footprint.
Wall assets should face local -Z.
All placed parts are anchored. Embedded scripts are removed from clones; future
Utility behavior should be attached by server services using the placement metadata.

Use `RealmBuilding.Clone` when creating catalog copies: it removes WindShake and
SmartBone before cloning and restores the source immediately. Preview and viewport
copies stay untagged. World placement, loading and history restoration call the returned
tag restoration function after positioning and parenting the final object.

## Placement and saves

`ReplicatedStorage.Shared.RealmBuilding` contains the shared geometry and settings.
`GridEnabled` is false; `GridSize` is prepared for future snapping relative to the
realm origin, including wall planes. The server reconstructs placement from a verified
surface hit, checks ownership, player state, realm bounds, collidable world geometry
and placed object geometry (including noncollidable decorations). A bounding box is conservative for irregular shapes. Floor objects remain
upright on slopes; terrain penetration beyond the contact point is not yet sampled.

Objects are stored in `Data.Realm.PlacedObjects` as an asset key and twelve CFrame
components relative to the realm pivot, so moving to a different realm plot preserves
the layout. The normal profile saving flow persists these records. Missing assets are
skipped on load while their records remain intact. Keep asset and category names stable
until a migration mechanism is added. The initial cap is 1,000 objects per realm.

## Desktop deletion

`RealmEdit.Tools.Delete` toggles deletion mode. Entering it cancels placement and hides
the catalog temporarily. Hovering a placed object highlights the entire object in red;
left click deletes it. X, clicking Delete again, choosing a build tab or leaving the
editor exits the mode. World raycasts respect occlusion and clicks over active UI are
ignored. Only direct children of the owner's `PlacedObjects` folder with a saved
placement ID are eligible. Template structures, terrain and removable resources cannot
be deleted with this tool. Deletion removes the saved record, so objects stay deleted
after reloading. Mobile uses the confirmation flow described below.

Refunds use the server's saved `ResourcesSpent` snapshot, never client input or the
asset's current price. Each resource returns `floor(amount * 7 / 10)` units to the inventory.
If the backpack cannot receive the entire refund, the remainder is saved in
`Data.Realm.PendingResourceRefunds` and retried when inventory contents change or a realm
loads. Deleting the same placement again cannot refund twice.

Costs live on each catalog model or part as `Cost_<inventory item name>` attributes.
Any item with Class `Resource` is supported, including future resource definitions.
The existing Simple Wood Stool has `Cost_WoodLog = 2`. Invalid costs reject placement;
objects with no cost attributes remain free. Legacy saved objects without paid costs
refund nothing. New placements validate all ingredients across every inventory stack
before debiting anything, then save the actual debit in `ResourcesSpent`. Canceled or
rejected placements consume nothing, and moving an object does not charge again.
The details panel displays owned/required quantities and highlights missing ingredients.

## Undo and redo

On desktop, `Tools.Back` and Ctrl+Z undo the latest placement or deletion;
`Tools.Forward` and Ctrl+Shift+Z redo it. Shortcuts are active only in the realm
editor and leave text editing shortcuts alone when a TextBox has focus. Applying
history cancels the current placement/deletion mode; pending object requests must
finish first. Unavailable history buttons are dimmed.

The server keeps at most **100 actions total**, including the redo branch. Recording
a new placement or deletion after undo discards that branch. Failed actions and history
replays do not create new entries. History survives closing and reopening the editor
while the same realm is loaded; it clears when the realm unloads or the player leaves.
History itself is kept in memory. The resulting placements and deletions use the normal
profile save flow.

Restoring an object preserves its ID, transform, saved cost and position in the saved
list. Missing assets, blocked positions and object limits reject restoration without
advancing the history cursor. Undoing placement returns its entire saved cost; redoing
placement consumes that same saved cost. Undoing deletion removes its 70% refund from
pending credits and/or the inventory; redoing deletion returns that refund once. If the
required resources are unavailable, history is rejected without advancing its cursor.

## Selecting and moving objects

The default desktop editor highlights owned placed objects in blue. Clicking an object
starts a translucent move preview; R rotates by 15 degrees and X cancels. The selecting
click is ignored by placement so it cannot immediately confirm the move. On confirmation
the server moves the same instance, updates its saved transform and records a Move action
for undo/redo. Moving preserves placement identity, resource costs and object count.
It does not spend resources or issue refunds. Cancel restores the original local visibility
without changing the server placement.

`RealmPointerController` provides a common pointer ray and GUI blocking checks for move,
delete and placement. Raw `GetMouseLocation()` coordinates use `ViewportPointToRay()`;
GUI hit tests use the position after subtracting the GUI inset. Visible geometry occludes
selection. Invisible parts and BuildingAreas within a placed object do not select it.
Both hover highlights remain under dedicated folders, and only change when the target
changes. The moving original is excluded from surface and overlap queries.

## Mobile editing

`RealmMobileController` clones `ReplicatedStorage.Assets.Billboards.MobileBillboard`
into PlayerGui and attaches it to a world anchor so its buttons receive touch input.
Touch input is selected through `UserInputService.PreferredInput`; desktop tools and
mouse hover selection are hidden while touch is preferred.

Tapping owned placed geometry opens Delete, Color, Move and Close, with a blue selection.
Color is displayed only; changing colors remains deferred. Delete changes the selection
to red and shows only Apply and Close. Apply uses the same server deletion, history and
70% refund handling as desktop; Close dismisses confirmation without deleting anything.

Move starts the existing translucent preview. New catalog objects use the same mobile
placement flow. A cursor marks the center of the camera viewport, and the preview follows
the ray from that point instead of following the finger. The billboard follows the preview
and shows Apply, Rotate and Close. Rotate advances clockwise by 15 degrees; Apply reuses
server validation, overlap blocking and saving. Applying a new object keeps placing copies;
applying a move finishes it. Close cancels and restores the original object when moving.
Leaving the editor removes the billboard, selection and cursor.
