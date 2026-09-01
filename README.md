# Vehicle Living Slots / 房车生活

Vehicle Living Slots turns supported vanilla vehicles and optional KI5 campers
into configurable mobile living spaces. Players can install beds, storage,
appliances, water equipment, clean-water tanks, and vehicle power through the
normal vehicle and inventory interfaces.

Current release: **3.5.0** for Project Zomboid Build 42.20.2. Version 3.5.0
is the current and sole accepted rollback baseline.

- Steam Workshop ID: `3791192579` (the Workshop item is not public yet)
- Vanilla Mod ID: `VehicleLivingSlots` (`RC3.3.1`)
- Optional KI5 Mod ID: `VehicleLivingSlotsKI5Campers` (`RC3.5.0`)

## Two ways to use it

### Vanilla vehicles

Enable `VehicleLivingSlots` only. It has no external Mod dependency.

- SUV and PickUpVan: keeps every original seat and adds one living space.
- Van: keeps two front seats and adds three living spaces.
- StepVan: keeps two front seats, adds five living spaces, and adds one
  clean-water tank position.
- Passenger Vans, wrecks, and burnt vehicles are excluded.

### Vanilla vehicles and KI5 campers

Enable both `VehicleLivingSlots` and `VehicleLivingSlotsKI5Campers`, then install:

- [KI5 Campers](https://steamcommunity.com/sharedfiles/filedetails/?id=3670064951)
- [damnlib](https://steamcommunity.com/sharedfiles/filedetails/?id=3171167894)

The adapter supports 1987 Scamp 13, 1987 Scamp 16, 1961 Bambi 16, and 1954
Flying Cloud 22. It preserves KI5's original seats, beds, storage, battery, and
entry behavior while adding two to four configurable living spaces and two
clean-water tank positions.

## Features

- Beds: cots, mattresses, and vanilla sleeping bags for resting and sleeping.
- Storage: supported vanilla cabinets and counters appear as vehicle containers.
- Appliances: microwaves, mini fridges with freezer space, and televisions.
- Water: water-dispenser bottles, clean-water tanks, and the vanilla fluid
  transfer panel.
- Power: vehicle living equipment draws from the auxiliary or KI5 battery.
- Maintenance: water, battery, propane material, and item condition use the
  vehicle mechanics window.
- Multiplayer: inventory, fluid, appliance, and power changes are validated by
  the server.
- Languages: Simplified Chinese, Traditional Chinese, and English.

## Installation

Copy one or both directories under `workshop/Contents/mods` into the Project
Zomboid Mods directory. The optional installer can perform the same copy on
Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\workshop\install_local.ps1
```

Back up long-running worlds before adding or removing vehicle Mods.

## Repository policy

The immutable `v3.5.0` tag and release archive preserve the exact 67-file
two-module payload. The repository retains only the 3.5.0 rollback ZIP,
manifest, and checksum. Internal test harnesses, CI configuration, server
operations, credentials, private paths, raw logs, caches, redundant Workshop
description copies, publisher-local build files, unrelated Mods, and artwork
without confirmed public redistribution provenance are excluded.

Implementation and multiplayer behavior are summarized in the
[technical reference](workshop/docs/TECHNICAL_REFERENCE.md).

Original VLS code, documentation, translations, and tools are licensed under
the [MIT License](LICENSE). The mechanics-overlay PNG files described in
[NOTICE.md](NOTICE.md) are excluded from MIT and remain subject to their
original Project Zomboid rights.

This is an unofficial community project and is not affiliated with The Indie
Stone, KI5, or the damnlib authors.
