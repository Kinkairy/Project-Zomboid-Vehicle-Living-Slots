# Technical reference

## Package boundary

The repository ships two independent Mod directories in one Workshop payload:

- `VehicleLivingSlots`: standalone vanilla-vehicle support;
- `VehicleLivingSlotsKI5Campers`: optional adapter requiring the base Mod,
  KI5 Campers, and damnlib.

The adapter does not replace KI5 vehicle definitions. It adds VLS parts and
profiles to four exact script IDs, preserves native passenger/door/entry data,
and resolves KI5's original battery as the living-equipment power source.

## Shared behavior

Installable living spaces use one base capability path for storage, beds,
appliances, televisions, refrigeration, water-dispenser bottles, and server
synchronization. Clean-water tanks use Project Zomboid's fluid containers and
the original transfer panel. Incoming water purification and every appliance
power change are server-validated.

Vehicle-installed crafting and microwave windows remain vanilla UI. Narrow
context guards keep them valid only while the player, vehicle, installed item,
and required capability still match; ordinary world UI continues unchanged.

The KI5 adapter declares vehicle-specific part IDs, tank order, seat-diagram
positions, container icons, and propane sources. It does not duplicate the base
appliance, water, or power implementation.

## Multiplayer contract

Clients submit intent and stable object identities. The server re-resolves the
vehicle, part, item, actor distance/area, current state, capacity, and allowed
operation before mutation, then synchronizes the affected inventory items and
vehicle parts. Empty-before-removal guards prevent storage and fluid duplication.

## Release identity

Release `v3.6.0` is represented by the exact payload in `workshop/Contents`,
the matching manifest, and the SHA-256 record for the release ZIP.
