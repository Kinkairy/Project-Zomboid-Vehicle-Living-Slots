# VLS 3.9 native delegation and shared-adapter audit

Published 2026-09-24 for B42.20. Version 3.9 is the owner-selected sole rollback
baseline. Native behavior is reused where the vehicle identity permits it;
vehicle-only power and container bridges remain explicit below.

| Area | Native owner | Retained single adapter / outcome |
| --- | --- | --- |
| Living-space, pantry and ordinary roof installation/removal | ISInstallVehiclePart / ISUninstallVehiclePart, original requirements, success calculation and item transaction | Shared installation policy; TV uninstall copies current companion presets before the native transaction. Removed the TV install subclass and global instanceof replacement. |
| Fixed rack, armor, chassis fabrication | Native vehicle/item objects and action shell | One R.installFixed materials/rollback transaction, with part specifications and chassis commit/rollback callbacks. These are mod-specific fabrication features, not duplicate furniture installation. |
| Repairs | ISFixVehiclePartAction / FixingManager | Shared position/material preconditions for fabricated parts; visual refresh after original repair. No second repair-success or condition formula. |
| Collision forwarding / armor | Native vehicle damage remains the source | D.Update is the single settlement entry: sample impact for rack, settle armor absorption, rebase both consumers. Tick, rack callback and mechanics completion use this same path. Armor and rack have different effects, not duplicate damage charges. |
| Maintenance boundaries | Original install/uninstall/repair completion | Settle pending real damage before maintenance, rebase both rack and armor afterward, including side windows and native exceptions. Prevent maintenance loss from being misread as collision. |
| Auxiliary power | Native battery item and part-used-delta synchronization | VLS.VehiclePower owns unit conversion, charge/capacity checks, debit, reservation/settlement, rollback and sync. Fridge, microwave, television, combo, pantry crafts and water purification reuse it. Client inspection cannot debit/refund. |
| Native power equipment | Native headlight and IsoGenerator engines | Roof lights retain main-battery/headlight updates; parked real generator retains native fuel, wear, power, sound and hazards. No second simulated source and no forced conversion to auxiliary power. |
| Cooling | Native food/container fields | Existing shared bounded vehicle cooling/aging/freezing bridge; client projects server snapshots using the same shared math. Map-parent power lookup has no direct auxiliary-battery provider. Trailer fridge uses the mini-fridge implementation. |
| Microwave | Original microwave UI, native food/container behavior | Vehicle identity, settings command and elapsed-time controller; battery arithmetic now delegates to VehiclePower. Native stove commands require a world object. |
| Television | Native DeviceData, radio UI/media actions and packets | Companion part identity/power view; only shared vehicle adapter charges power. Device useDelta is zero to avoid a second native battery charge. |
| Combo laundry | Original Base item, vehicle installation, native inventory getControl/joypad methods and SyncItemFields/container packets | One server vehicle cycle for both modes, five water units by default, auxiliary battery. Switch resets old cycle; resource loss pauses. No white machines, separate mode-enable switches or custom client cleaning replay. |
| Pantry crafting | Original recipes, HandcraftLogic execution, output callbacks and ISHandcraftAction lifecycle | All entry menus share the same vehicle craft adapter. Bind logic on the action instance; no temporary global HandcraftLogic.new replacement. |
| Water / washing | Native callbacks, Fill All iteration, bag return, washing effects and action queue | Finite vehicle fluid identity and authority. Native body/clothes/bandage update and turning use a scoped actual-vehicle receiver, restored after errors. Purification reserves/refunds through shared power. |
| Vehicle rest | ISRestAction start/update/progress | Native start reused; vehicle identity/bed validation and server binding remain where native code assumes a map bed. |
| Petrol / propane | Native portable-fuel effects and native refill recipe | Mounted-source identity/debit, service position and serialized authority; no hardcoded replacement recipe or second fuel conversion. |
| Cargo / seats / mechanics UI | Native access queries, rendering and navigation | Scoped vehicle view, slot display and preview texture; native source functions remain the decision owner where compatible. |
| Chassis / material scaling | Native mass, parts and items | Mod-specific percentage reduction and recipes; one chassis sync and shared fabrication specification path, with idempotence and rollback tests. |

## Concrete regression and boundaries

The previous armor loop kept a separate source-condition baseline. Mechanics
completion rebased only rack damage. Four tests reproduced wrong armor absorption
of maintenance loss (hood and side window), pending impact settlement and native
exception handling. They failed before the fix and pass afterward. Repeated
entries settle the same impact once; destroyed native windows are not revived;
god-mode updates do not defer a later damage charge.

Native world washer/dryer and freezer power reads the world object's map square
through ItemContainer.isPowered / IsoObject.checkObjectPowered. A vehicle part
cannot supply that grid-power identity via an exposed Lua provider. Reparenting
its container would also change native ContainerID network ownership. This
release does not inject map power, create a parallel fake world appliance or
add a Java dependency. The fallback is explicit: laundry effects update during the
vehicle cycle and apply the final result at completion, using native item fields. Native
world-machine sounds/noise and every transfer-lock behavior are not claimed as
identical. Automated coverage does not replace exhaustive real-game testing.

## Verification

The 3.9 release rechecks runtime syntax, generated EN/CN/CH catalogs, exact
235-file hashes, source regression suites, native cargo callbacks, native
constructor parameter contracts and the actual inventory-button selection path.
Fixtures identify where engine objects are mocked. Earlier Kahlua action
serialization probes remain part of the recorded evidence.

The independently downloaded Workshop package and deployed NUC test/Windows
client payload match `release-3.9.json`. English mod names and packaged icons
are verified. Exhaustive gameplay, controller and multiplayer acceptance are
not implied. See `docs/release-3.9.md` for current changes and removed legacy
slot behavior; historical release manifests are not selected rollback baselines.
