# VLS 3.8.2 materials1: fabrication costs by supported body family

Base commit: `fbfa94b5a48a1bb867e8141d630fa75701463628`.
This is a source change, not proof of a Workshop upload or a live deployment.
The displayed Mod version stays 3.8.2; identify this build by commit and file hashes.

## Original behavior

`VLS_RoofCargo.lua` returned one shared rack recipe for every vehicle. `VLS_BodyArmor.lua` registered one window recipe and one bumper recipe for every armor slot. The menu, authoritative material plan, installation completion and dismantling already resolve `R.fabricationSpec(part)`.

The original rack costs 10 MetalBar, 4 SmallSheetMetal, 4 Screws, 1 Tarp, 10 BlowTorch uses and 4 WeldingRods uses. One window guard costs 2/1/2/0/10/1 in the same order; one bumper costs 6/2/4/0/10/2. Salvage attempts were also fixed.

## New defaults

These are explicit gameplay tiers for the existing supported body families, not a physical area measurement. Paint/job variants of a body use the same tier. Existing supported script IDs are checked first; name prefixes cannot enable unknown vehicles.

- StepVan family: 100%, original costs retained.
- Van and VanSeats families: 75%.
- SUV and PickUpVan families: 50%.

Every material quantity and fabrication consumable-use count is rounded up independently. No item is split or rounded to zero. Costs are independent of cargo capacity and current condition.

| Part, per installation | Body family | MetalBar | SmallSheetMetal | Screws | Tarp | BlowTorch uses | WeldingRods uses |
|---|---|---:|---:|---:|---:|---:|---:|
| Rack | SUV / PickUpVan | 5 | 2 | 2 | 1 | 5 | 2 |
| Rack | Van / VanSeats | 8 | 3 | 3 | 1 | 8 | 3 |
| Rack | StepVan | 10 | 4 | 4 | 1 | 10 | 4 |
| Window guard | SUV / PickUpVan | 1 | 1 | 1 | 0 | 5 | 1 |
| Window guard | Van / VanSeats | 2 | 1 | 2 | 0 | 8 | 1 |
| Window guard | StepVan | 2 | 1 | 2 | 0 | 10 | 1 |
| Front or rear bumper | SUV / PickUpVan | 3 | 1 | 2 | 0 | 5 | 1 |
| Front or rear bumper | Van / VanSeats | 5 | 2 | 3 | 0 | 8 | 2 |
| Front or rear bumper | StepVan | 6 | 2 | 4 | 0 | 10 | 2 |

Integer rounding means Van and StepVan window guards have the same solid-item inputs, but different torch consumption. This change does not increase any recipe above its previous cost.

## Consistency and scope

`R.fabricationSpec(part)` returns fresh scaled materials/uses/salvage tables for recipes explicitly marked `scaleWithVehicle`. The menu and server therefore use one calculation, without changing shared base tables when switching vehicles. Installation still revalidates carried inventory at completion. Other registered fabrication recipes are not implicitly scaled.

Salvage success parameters are unchanged. The maximum number of return attempts for each material is reduced to no more than its new construction input. It is not a guaranteed full refund. Tarp and fuel/rods are still not returned. Existing installed parts are not replaced or refunded; their future dismantling uses the new body-family recipe, including old parts built at the previous higher cost. There is no save migration or historical cost tracking.

Unchanged: all slot/item IDs, models, textures, rack capacities, armor durability and damage compensation, installation skills/tools, XP and action duration, native repair recipes, and the existing 10-use dismantling torch cost. Empty-rack/attachment checks remain; 0% and 100% parts remain dismantlable when otherwise valid. KI5 camper runtime files are unchanged; no armor/rack support is added to new models.

## Validation

Run `lua5.1 tools/test_vls_material_tiers.lua .` and `lua5.1 tools/test_vls_regressions.lua .` from the repo root. The material suite loads actual VLS recipe, action and mechanics-menu Lua with mocked native objects. It covers all 106 current adapter variants, exact menu quantities, server debit, shortages and late inventory changes, salvage upper bounds, callback preservation, unchanged capacities and dismantling guards. It is not a PZ Java-engine or multiplayer playtest.

Both server and client need the same updated runtime. Do not reuse the earlier audit1 deployment/upload ZIP as though it contained this change: those packages pin the previous source. Rebuild/re-pin the complete payload and its manifest; never suppress a hash mismatch or upload a two-file patch as a complete Workshop item. No server process, local source tree, save or Workshop item is modified by this Git commit alone.
