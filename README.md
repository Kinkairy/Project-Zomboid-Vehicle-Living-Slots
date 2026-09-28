# Mobile Living 3.10.2

Vehicle living equipment for Project Zomboid **B42.20**, including multiplayer
and dedicated servers. Workshop item: **3791192579**.

## 3.10.2 controller and initialization fix

Resolves native controller icon getters before reading texture offsets in both
seat-map paths. Defers vehicle callback registration until the native server
module is available, and retries chassis/frame mass changes after native physics
initialization. F700 advances to 0.1.2. Published to the existing Workshop item;
268 independently downloaded files match this source. In-game acceptance remains
separate. See [3.10.2 release notes](docs/release-3.10.2.md).

## 3.10.1 mechanics-window fix

Corrects the native `drawLine(texture, x, y, x2, y2, thickness, a, r, g, b)` calls
in both KI5 adapters. Regression coverage loads the installed B42.21.0 wrapper
and checks both addon load orders, all 11 vehicle models and draw-failure cleanup.
The optional F700 adapter is now 0.1.1. Gameplay acceptance remains separate.

See [3.10.1 release notes](docs/release-3.10.1.md).

## Installation

Enable `VehicleLivingSlots` for supported vanilla vehicles. For KI5 campers,
also enable `VehicleLivingSlotsKI5Campers` and install [Campers!](https://steamcommunity.com/sharedfiles/filedetails/?id=3670064951)
and [that DAMN Library](https://steamcommunity.com/sharedfiles/filedetails/?id=3171167894).
The Shasta models require Campers! v0.940b or later. KI5/DAMN assets are not bundled.
For KI5 F700 vehicles, also enable VehicleLivingSlotsKI5F700 and install
['87 Ford B700/F700 Trucks](https://steamcommunity.com/sharedfiles/filedetails/?id=3110911330)
and that DAMN Library. The optional adapter supports the armored bank truck,
SWAT van, and School, Prison and Military Buses.


## Vehicle equipment

| Vehicle family | Added living positions | Added water tanks | Base roof storage |
| --- | ---: | ---: | ---: |
| SUV / PickUpVan | 1 | 0 | 250 |
| Cargo Van | 3 | 0 | 300 |
| Passenger VanSeats | 0 | 0 | 300 |
| StepVan | 5 | 1 | 400 |
| KI5 Scamp 13 | 2 | 2 | Upstream layout |
| KI5 Scamp 16 / Bambi 16 / Shasta Airflyte / Shasta Astrodome | 3 | 2 | Upstream layout |
| KI5 Flying Cloud 22 | 4 | 2 | Upstream layout |
| KI5 F700 armored bank truck | 7 | 2 | Upstream layout |
| KI5 F700 SWAT van | 6 convertible rear seats | 2 | Upstream layout |
| KI5 B700 School / Prison / Military Bus | 14 convertible rear seats | 4 | Upstream layout |

F700 SWAT and Bus rear positions accept either their native driver-style seat
or living equipment in a single mechanics row. The adapter preserves native
passenger and entry/exit positions. All five vehicles have four overhead
positions. Buses have two auxiliary batteries alongside the original starter
battery, and reuse shared water, roof fuel-can and generator services.
Vehicle-specific layouts stay in the optional adapters; common equipment
behavior is supplied by the main module.

The roof whitelist contains 106 vanilla script/paint/job variants, not 106
separate vehicle models. Existing seats remain. Living positions accept supported
beds, cabinets, refrigerators, microwaves, televisions, washing machines,
clothing dryers and water-dispenser bottles.
Van and StepVan also have a weapon-locker position. Installed non-bed equipment
uses native white equipment blocks in the seat map.

Fabricated roof racks, chassis improvements, window armor and bumper guards use
vehicle-class material costs. Rack attachments include a generator, petrol cans,
propane tanks, a small chest, a packed tent, spare tires and four spotlights;
slot counts vary by body. All roof attachments install and uninstall without
tools. Native **Mechanics 1** is the recommendation used by the original success
calculation, not a custom hard gate. Fabricating the rack retains its tools and
skills. Spotlights use the original headlight switch and main battery.

## Cabin combination washer/dryer

A living position can hold the vanilla Blue Combo Washer/Dryer
(`Base.Mov_BlueComboWasherDryer`, all four world facings). Standalone white
washing machines and dryers are no longer installation choices. Installation
and removal use the normal vehicle actions. The inventory window reuses the
native combination-machine buttons and controller labels for on/off and mode
switching; no second mode menu is added.

The shared vehicle power adapter draws from the installed auxiliary battery. Installation does not require a water tank; starting a wash requires a tank containing clean water. Washing also
uses the installed vehicle water tank: default 5 clean-water units over a
90-game-minute cycle. Drying uses no water. If power or water is exhausted, the
cycle pauses; replenish and turn it on to resume. Switching modes stops and
resets the old cycle. The sandbox has one combo installation switch, wash-water
cost and one shared wash/dry power cost. Disabling installation retains existing
devices. The small-appliance switch and per-craft power setting remain separate.

The authoritative vehicle cycle updates clothing wetness, blood and dirt during
washing, and reduces wetness during drying. Completion also applies the final
cycle result. Container and item changes are synchronized for multiplayer.
This adapter uses native item fields; it is not a native map machine instance.

## Vehicle quick menus

Four independent sandbox switches are enabled by default. Each menu requires
the corresponding installed equipment.

- **Generator:** native information, fuel, repair, connection and on/off actions
  from beside the vehicle. Supplies nearby buildings while parked. Movement stops
  and disconnects it; parking again does not automatically reconnect it. Interior
  appliances continue using their existing vehicle battery.
- **Petrol:** native Collect Fuel menu fills carried containers from installed
  roof cans and debits the finite source. Red gas cans and military jerrycans
  retain native fluid capacities and dynamic names, including their empty state.
- **Propane:** native Refill Blowtorch recipe uses the installed tank and the
  actual carried blowtorch. Walking to the service point is included.
- **Water:** native drinking, filling and washing actions use installed VLS
  tanks. Incoming purification consumes vehicle power. Empty tanks before removal.

KI5 integration provides propane and VLS water services; it does not add roof
generator or petrol-can positions to KI5 campers.

## Source and validation

Runtime files are in `workshop/Contents/mods`. `translations/catalog.json` is the
single EN/CN/CH runtime catalog; `translations/workshop-description.json` holds
the three Workshop descriptions. Validate with:

```sh
python tools/build_translations.py
```

Public source regression suites are in `tests/`; the private multi-mod workspace
keeps them under `tests/vehicle-living-slots/`. Lua suites accept the mod root as
the first argument; native-action suites also accept the installed game
`media/lua` directory as the second argument. Java probes require a local game
installation, a JDK and a separate temporary work directory. Public CI checks
syntax, catalogs, runtime hashes and source-only suites without bundling game code.

Use `--write` after an intentional catalog edit. The Workshop description text,
BBCode and publication VDF must agree. Keep `AnimSets/.gitkeep` and
`actiongroups/.gitkeep` in both mods and version folders: the empty directories
are required by the native loader.

See [THIN-SHELL-AUDIT.md](THIN-SHELL-AUDIT.md) for native delegation boundaries,
[release-3.9.json](release-3.9.json) for exact runtime hashes, and
[NOTICE.md](NOTICE.md) for asset rights. Historical release manifests remain as source history. **3.9 is the sole
owner-selected rollback baseline**; older standalone VLS backups are retired.
See [3.9 release notes](docs/release-3.9.md) for changes and evidence boundaries.

## 3.8.11 native cargo access

Cargo adaptation follows the vehicle's existing native inside-access callback, not a Van/StepVan model allowlist. Original seat indices and areas remain unchanged; only VLS-added positions are excluded from the passenger-count query. An installed living bed delegates cargo-area access to the same native callback using existing original passenger areas. Outside-only cargo and original front/rear restrictions remain intact.

The 97 VLS profiles are each tested under all three native cargo callback contracts, not asserted to use the same policy. The tests cover all installed bed types, original seats and exterior states. Runtime scripts are not rebound. This is source-level validation, not a live PZ/Kahlua or multiplayer certification.

## 3.8.12 small appliances

The interchangeable small-appliance slot accepts a native coffee maker or toaster.
It uses auxiliary battery power. Installed devices keep their native item names;
an empty slot contributes no radial entry. The shared lightning shortcut and
inventory-item Craft menu use one native workbench adapter, original recipes and
completion callbacks. No separate addon is required.

Owner-tested local crafting was accepted before publication. Both native coffee
recipes passed the two-entry completion/power checks; real native workbench
components were verified against the matching installed game definitions. This
release does not claim exhaustive coffee-maker, controller or multiplayer testing.

3.8.12：新增车载小电器位，支持咖啡机和烤面包机。 / Added a vehicle small-appliance slot supporting coffee makers and toasters.

## 3.9

This release includes the multiplayer crafting constructor fix, queued native
water actions, trailer fridge support, freezer container selection repair,
progressive laundry updates, shared auxiliary power accounting, native appliance
names, simplified settings, TV state recovery, damage accounting and roof fuel
can visibility fixes. Liquid transfer retains the native timing used in 3.8.12.

The obsolete separate toaster test slot and its compatibility logic are removed.
Any item left in that obsolete slot is discarded; the current interchangeable
coffee-maker/toaster slot remains. DeRumba adaptation is deferred.

The Workshop download and deployed test/client payload match the 235-file
release manifest. Automated checks and targeted player tests do not constitute
exhaustive gameplay or multiplayer certification.

## Optional F700 adapter (0.1.0 source candidate)

Enable `VehicleLivingSlotsKI5F700` alongside Mobile Living **3.9**, `87fordB700`
and `damnlib`. Bank retains its original two seats and adds seven living positions.
SWAT keeps its original eight passengers: each of the six rear seats has a separate
living-space part. Both mechanics rows remain visible when empty, and only one
side can be installed at a time. Original seats and beds remain usable; other
living equipment does not become a seat. Both models have four overhead positions,
two water tanks and auxiliary power. Bus conversion is not enabled.

The independent adapter owns conversion, native transaction guards, per-vehicle
seat binding and the paired UI. This increment leaves the core and Campers runtime
files unchanged from the approved UI candidate. See [the design and audit](docs/F700-INDEPENDENT-ADAPTER.md).

Source tests and native API checks are complete; deployment and multiplayer/gameplay
acceptance remain pending. The server and client still run the earlier package.
