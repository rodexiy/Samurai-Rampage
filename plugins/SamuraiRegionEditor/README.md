# Samurai Region Editor

Roblox Studio plugin for editing the invisible authoring volumes used by Samurai Rampage:

- `LightingRegions`
- `NamedRegions`
- `OSTRegions`
- `SoundRegions`
- `WorldWalls`

The plugin creates temporary, color-coded Workspace previews without changing the parts' saved transparency or storage location. Moving or scaling a preview synchronizes Position and Size back to its source part. It supports searching, selecting, focusing, locking/unlocking, and precise Position/Size editing with Studio Undo.

## Build

```powershell
rojo build default.project.json --output SamuraiRegionEditor.rbxmx
```

## Workflow

1. Open **Plugins > Samurai Rampage > Region Editor**.
2. Choose a category and select a volume from the list.
3. Use the plugin's Position and Size fields, or Studio's Move and Scale tools.
4. Use **Focus Selection** to jump the camera to a distant or fully transparent volume.
5. Toggle **Guides** when you want to hide all temporary outlines.

All property edits made by the plugin are undoable with Ctrl+Z.
