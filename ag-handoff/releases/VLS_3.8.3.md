# VLS 3.8.3 / B42.20 / multiplayer

Base: public `764380753d1e2871fc3fb02d824e72930a2fac69` (materials1). Existing slot/item IDs, capacities, models, armor, fabrication tiers and optional KI5 dependencies are preserved. No save migration, historical refunds, bulb item, or new Java dependency.

## Four changes

1. `VLS_ComponentDamage.lua`: only the fitted rack, not mounted cargo, receives the rack's propagated collision damage. Remove the spotlight item-deletion branch. Native item consumption/use and non-roof managed parts remain separate.
2. `VLS_RoofLights.lua`: refresh existing as well as new light objects. The full-condition target effective distance/intensity is 48/1.0 (previous configuration 36/0.75); dot remains 0.75. Normalize attenuation against the Torch item's condition maximum via the native effective-output getters, without changing item condition, maximum, or inserted battery. Apply on init/install and when relevant part/item/light state changes, not on every frame. Reuse native headlight switching/engine-off battery drain. Only VLS roof lamps are configured. Rendered brightness and multiplayer registration still require an in-game A/B check; additive or proportional screen brightness is not promised.
3. Shared installed-propane refilling in the base mod; KI5 only contributes its profiles. Roof tanks require the existing fixed rack. Keep KI5 conversion (70 source-use units per torch-use), animation and inventory-menu flow. Bind the actual tank item ID; never silently debit a replacement/second tank. No new KI5 dependency for ordinary vehicles. Both sides must use the new command contract.
4. Tank-inlet washing: base mod and KI5 tanks discovered by existing water profiles. Exterior only, stopped vehicle, correct inlet-side floor/position, installed-tank item identity, real water fluid and sufficient volume required. World context menu: Water tank washing / Wash yourself / dirty items. Inventory context menu: Wash using water tank. Native item transfer precedes queued clothing washing. No additional engine/electricity requirement or new purification. Does not advertise the tank as a global water source to unrelated Mods.

## Washing implementation and boundaries

The new shared classes `VLSWashYourselfFromTank` and `VLSWashClothingFromTank` retain constructor arguments as identically named fields (character, vehicleId, partId, tankId, and item for clothing). The server reconstructs tank identity; no Lua mock sink is a serialized constructor argument. Movement cancels via the base timed action. Position, ownership and amount are checked again at authoritative completion.

Native `ISWashYourself` / `ISWashClothing` own animations, sounds, soap consumption, dirty/bloody state, item conversion and wetness. Only facing and water-source resolution are adapted. A transient sink is passed locally inside completion. The real tank is debited first, once, without yielding; the native completion consumes that reserved budget. No world-object proxy, duplicated free water, or globally overridden wash callback is installed.

Full integer body-part washing uses `floor(available)` and may be partial. Clothing must have its full native required amount. Queued garments each recheck available water and stop when unavailable. Native soap rules remain, rather than inventing a mandatory-soap rule. If an external/native callback raises after partial cleaning, the already spent water is synchronized and not refunded (to avoid free repeated cleaning); the error is logged, and the same action cannot debit again. This error case can lose water and is not a transactional rollback of arbitrary third-party effects.

## Locales and versioning

Both Mod metadata sets and runtime version constants are 3.8.3. `VLS.BUILD_ID` is `release-3.8.3-20260917`. The propane and washing UI keys are generated from their EN/CN/CH catalogs. Full locale key/placeholder parity and all 197 runtime hashes are checked by `tools/validate_release_383.py` against `release-3.8.3.json`.

## Tests and live acceptance

Regression suites load real changed Lua; Java/native objects are mocked. Washing tests load the actual native washing Lua from `Project-Zomboid-Community-Modding/ProjectZomboid-Vanilla-Lua` at `8a906692ac56f9d40c078d654eea6c70491cbc62` (mirror commit labelled B42.20.2), rather than inventing the native completion body. The source mirror is an input reference, not proof of the user's exact installed B42.20 patch level.

Run Lua 5.1 syntax checks and `tools/test_vls_regressions.lua`, `tools/test_vls_material_tiers.lua`, `tools/test_roof_cargo_damage.lua`, `tools/test_vehicle_propane.lua`, `tools/test_vls_lights.lua`, plus `tools/test_vls_wash.lua <repo> <native-Lua-root>`. Run all three translation generators in check mode and the release verifier. CI results, not this document alone, establish whether they pass.

No live NUC, Windows, renderer, Steam Workshop, save/rejoin or controller acceptance is claimed. In game, check: rack/cargo collision isolation; 0/1/4 lamps on the same road at night after reload; refill with and without KI5; self/clothes washing, low water, cancelling, two players and changed tank. Update client and server together. Old pinned deployment/upload packages do not contain this release and must not be reused as 3.8.3.
