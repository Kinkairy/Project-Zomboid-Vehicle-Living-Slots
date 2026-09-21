# Mobile Living 3.8.8

Vehicle living equipment for Project Zomboid **B42.20**, including multiplayer
and dedicated servers. Workshop item: **3791192579**.

## Installation

Enable `VehicleLivingSlots` for supported vanilla vehicles. For KI5 campers,
also enable `VehicleLivingSlotsKI5Campers` and install [Campers!](https://steamcommunity.com/sharedfiles/filedetails/?id=3670064951)
and [that DAMN Library](https://steamcommunity.com/sharedfiles/filedetails/?id=3171167894).
The Shasta models require Campers! v0.940b or later. KI5/DAMN assets are not bundled.

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

The roof whitelist contains 106 vanilla script/paint/job variants, not 106
separate vehicle models. Existing seats remain. Living positions accept supported
beds, cabinets, refrigerators, microwaves, televisions and water-dispenser bottles.
Van and StepVan also have a weapon-locker position. Installed non-bed equipment
uses native white equipment blocks in the seat map.

Fabricated roof racks, chassis improvements, window armor and bumper guards use
vehicle-class material costs. Rack attachments include a generator, petrol cans,
propane tanks, a small chest, a packed tent, spare tires and four spotlights;
slot counts vary by body. All roof attachments install and uninstall without
tools. Native **Mechanics 1** is the recommendation used by the original success
calculation, not a custom hard gate. Fabricating the rack retains its tools and
skills. Spotlights use the original headlight switch and main battery.

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
[release-3.8.8.json](release-3.8.8.json) for exact runtime hashes, and
[NOTICE.md](NOTICE.md) for asset rights. Previous release manifests remain in Git history; 3.8.8 is the selected sole
rollback version.

The current payload passed 14 Lua suites / 1113 checks and targeted multiplayer
owner testing. Mock-based tests and Java contract probes are not exhaustive
singleplayer, controller or multiplayer compatibility certification. An earlier
session logged six duplicate-item-ID messages without a VLS stack; a subsequent
clean-login and isolated petrol uninstall/reinstall check did not reproduce them.
The source of that earlier transient remains unknown.
