# 3.8.8 native delegation audit

This mod uses native menus, actions and resource operations wherever the native
object contract fits. A thin adapter is not a claim that every feature is native
or that every custom calculation has a verified native replacement.

| Area | Native owner | Retained vehicle adapter |
| --- | --- | --- |
| Roof attachment install/removal | Vehicle script requirements, ISInstallVehiclePart / ISUninstallVehiclePart, native callbacks and success calculation | Supported slot/rack ownership, item visuals, connected-generator removal guard; no tool requirement; Mechanics 1 recommendation |
| Petrol names | InventoryItem.getName -> FluidContainer.getUiName | Presentation provider passes the actual installed PetrolCan/JerryCan |
| Petrol collection | Original fill-fuel menu, onTakeFuelNew and ISTakeFuel portable-container effects | Vehicle service point, finite mounted source identity/debit and concurrency checks |
| Propane refill | ISHandcraftAction and Base.RefillBlowTorch; Java native recipe owns fuel use, replacement and condition | Installed-tank input binding, walking/turning, server serialization and validation; no hardcoded refill ratio |
| Generator | Real IsoGenerator; native context menu/actions and engine power, fuel, wear, noise and hazards | Ownership, service positioning, world-object lifecycle, movement disconnect and installed-object pickup suppression |
| Water | Native drinking/filling/washing effects and FluidContainer transfer | Vehicle tank identity, reservations, purification/battery policy and network ownership |
| Roof lights / repair | Native headlight updates and FixingManager | Roof geometry, main-battery wiring and supported-part association |
| Seats / mechanics lists | Original renderers, hit testing, selection and navigation | Display rows/coordinates, equipment icons, dynamic names and upstream duplicate virtual-seat filtering |
| TV / microwave / work surfaces | Native device/action/UI paths where compatible | Vehicle ownership, reach, timers and battery accounting |
| Cooling | Native food data and verified engine timing contracts | Bounded vehicle power/aging/freezing bridge; native world-parent power lookup is not a drop-in vehicle freezer API |
| Chassis / armor / fabricated racks | Native item/vehicle mass and vehicle parts | Mod-specific material scaling, armor and mass ownership rules |

The parked generator is a real engine object. The adapter does not simulate its
fuel use or substitute a custom generator action. Movement deactivates it before
removal because electricity is not controlled by the connected flag alone.
Interior equipment does not switch to the generator.

Propane server startup tolerates the client arrival position still replicating;
strict completion rechecks the service area, stopped vehicle, installed tank,
carried torch and ownership before native recipe effects. Cancellation completes
the native network action safely. Native recipe synchronization is not duplicated.

The latest roof changes remove tool declarations from ordinary attachment
configuration and the corresponding server tool check. Rack fabrication keeps
its existing tools. Native skills are recommendations used by success/failure
calculation; no separate VLS skill gate was introduced.

## Verification and limits

- 14 Lua suites / 1113 checks passed, covering real native Lua bodies with engine
  fixtures, resource conservation, action cancellation, UI restoration and
  actual supported vehicle profiles. These are not a live-game simulation.
- Actual B42.20 Kahlua/Java probes verified relevant vector, network-action and
  fluid contracts during the 3.8.8 repair lineage. Native naming bytecode confirms
  delegation to FluidContainer.getUiName().
- The 224-file runtime payload is identical across source, local client and
  isolated test server; exact hashes are in release-3.8.8.json.
- Owner tested fuel/propane services and chassis reduction (StepVan 2504 to 2004),
  then completed a targeted petrol-can uninstall/reinstall after a clean login.
  Latest client/server checks found no new errors.
- Six duplicate-ID messages from an earlier client session lacked attribution.
  Clean-login and isolated petrol install/removal checks did not reproduce them;
  they were not proven to come from VLS or from another mod.
- A one-time initial-mass-zero chassis skip is diagnostic, not a Lua exception.
  Known upstream VVA missing-template startup errors are outside this payload.

Full singleplayer/controller, every vehicle variant and all mod combinations
have not been exhaustively retested. No speculative cooling or fluid-dispatch
rewrite is included merely to reduce the amount of custom Lua.

## 3.8.12 small-appliance adapter

Radial and item-context crafting enter the same OpenHandcraftWindow adapter. A
detached original CraftBench supplies UI identity; it never becomes a world or
network-owned object. The native ISHandcraftAction owns recipe execution and
completion; the shared derived action validates installed vehicle/part/item and
auxiliary power, keeping output idempotence separate from native UI notification.
Native recipe definitions and ingredient/output callbacks remain unchanged.
