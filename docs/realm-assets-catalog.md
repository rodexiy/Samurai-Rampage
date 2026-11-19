# Realm asset catalog

The 34 models from `Workspace.ObjetsForRealm` were copied into the realm catalog. The staging originals remain in Workspace. Catalog objects have unique names, upright pivots and per-item `Cost_<resource>` attributes. The existing Simple Wood Stool remains unchanged at 2 WoodLog.

Drying racks, the well and the wooden crate are Decorations/Props. Only the anvil is currently in Utility/Workstations, with smithing functionality deferred. Map loot, harvesting tags and minecart event metadata were removed from the catalog copies. Visual components were preserved.

Tables, crates, pallets and carts opt into `SupportsPlacement`. The catalog has 35 items including the existing stool. Saved placements using the former Utility keys for the five recategorized props remain compatible.

WindShake and SmartBone tags are removed from the source hierarchy before cloning and immediately restored to the source afterward. Preview and viewport clones remain untagged. Final placed objects receive their original tags only after their transform and world parent have been set.

## Imported assets

| Category | Asset | Resource cost | Supports placement |
| --- | --- | --- | --- |
| Decorations/Fences | Bamboo Fence | 6 WoodLog, 2 StrongRope | No |
| Decorations/Fences | Wooden Fence | 3 WoodLog, 1 IronIngot | No |
| Decorations/Lamps | Tall Lantern | 8 Stone, 2 IronIngot, 1 Coal | No |
| Decorations/Lamps | Small Lantern | 4 Stone, 1 IronIngot, 1 Coal | No |
| Decorations/Lamps | Lantern Post | 6 WoodLog, 2 IronIngot, 1 RicePaper | No |
| Decorations/Lamps | Double Lantern Post | 10 WoodLog, 4 IronIngot, 2 RicePaper | No |
| Decorations/Ornaments | Stone Torii | 40 Stone, 2 StrongRope | No |
| Decorations/Props | Well | 20 Stone, 10 WoodLog, 2 StrongRope | No |
| Decorations/Props | Drying Rack 2 | 4 WoodLog, 2 Cloth, 1 StrongRope | No |
| Decorations/Props | Small Hay Pile | 4 PlantFiber | No |
| Decorations/Props | Drying Rack | 5 WoodLog, 3 Cloth, 1 StrongRope | No |
| Decorations/Props | Drying Rack 3 | 5 WoodLog, 3 Cloth, 1 StrongRope | No |
| Decorations/Props | Hay Pile | 8 PlantFiber, 1 StrongRope | No |
| Decorations/Props | Wood Crate | 4 WoodLog | Yes |
| Decorations/Props | Wooden Cart | 14 WoodLog, 4 IronIngot, 2 StrongRope | Yes |
| Decorations/Props | Wooden Cart 2 | 16 WoodLog, 4 IronIngot, 2 StrongRope | Yes |
| Decorations/Props | Wooden Pallet | 4 WoodLog | Yes |
| Decorations/Rocks | Boulder | 8 Stone | No |
| Decorations/Rocks | Large Boulder | 12 Stone | No |
| Decorations/Tables | Drawer Wooden Table | 8 WoodLog, 2 IronIngot | Yes |
| Decorations/Tables | Wooden Table | 6 WoodLog, 1 IronIngot | Yes |
| Decorations/Vegetation | Cherry Tree | 24 WoodLog, 12 PlantFiber | No |
| Decorations/Vegetation | Fallen Log | 10 WoodLog | No |
| Decorations/Vegetation | Bush 4 | 1 WoodLog, 3 PlantFiber | No |
| Decorations/Vegetation | Tree 5 | 8 WoodLog, 4 PlantFiber | No |
| Decorations/Vegetation | Tree 2 | 30 WoodLog, 10 PlantFiber | No |
| Decorations/Vegetation | Bush 1 | 1 WoodLog, 2 PlantFiber | No |
| Decorations/Vegetation | Mossy Fallen Log | 12 WoodLog, 5 PlantFiber | No |
| Decorations/Vegetation | Bush 2 | 4 PlantFiber | No |
| Decorations/Vegetation | Tree 3 | 20 WoodLog, 8 PlantFiber | No |
| Decorations/Vegetation | Tree 1 | 16 WoodLog, 6 PlantFiber | No |
| Decorations/Vegetation | Tree 4 | 20 WoodLog, 8 PlantFiber | No |
| Decorations/Vegetation | Bush 3 | 4 PlantFiber | No |
| Utility/Workstations | Anvil | 12 IronIngot, 4 Stone | No |

Invisible noncollidable effect carrier parts do not contribute to placement bounds or overlap blocking; visible decorations and collidable support parts still do.

