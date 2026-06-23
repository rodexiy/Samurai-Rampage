# Samurai Item Configurator

Local Roblox Studio plugin for authoring Samurai Rampage equipable and weapon assets using the exact runtime structures expected by `EquipmentController` and `WeaponService`.

## Workflow

1. Select the raw item or an existing preset in Explorer.
2. Open **Plugins > Samurai Rampage > Item Configurator**.
3. Choose **Equipable** or **Weapon**, enter the exact item-data name, and generate the preview.
4. Position the generated preview objects around the dummy with Studio's Move and Rotate tools.
5. Validate, then save the preset.

Equipables may be one piece, or a Model whose direct children are named `Head`, `Torso`, `Left Arm`, `Right Arm`, `Left Leg`, and/or `Right Leg`. Compact names such as `LeftArm` and `RightArm` are accepted and normalized when saved. Weapons use models named `Weapon` and optionally `Sheath`, each with a direct `Handle` BasePart. Their previews include dedicated right- and left-hand held positions plus both sheath positions for dual wielding.

The plugin writes presets beneath `ReplicatedStorage.Assets.Equipables` or `ReplicatedStorage.Assets.Weapons`. Every write is undoable.
