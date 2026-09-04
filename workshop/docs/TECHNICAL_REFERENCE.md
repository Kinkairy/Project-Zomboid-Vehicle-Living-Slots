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

Outside tank intake searches four tiles on the inlet-facing side. It accepts
real water sources, not rain puddles on ordinary floor sprites. Menu visibility,
timed-action validation and server transfer share the same source, capacity,
purification-power and clean-water compatibility checks. The original vehicle
pathing and refuelling animation remain in use.

Vehicle-installed crafting and microwave windows remain vanilla UI. Narrow
context guards keep them valid only while the player, vehicle, installed item,
and required capability still match; ordinary world UI continues unchanged.

Water-source discovery searches the complete inlet-facing four-tile range.
Tank purification validates clean-water compatibility, remaining capacity, and
available power before mutation, preserves existing contents, and charges only
the amount accepted. A failed request changes neither endpoint nor battery.

Refrigeration uses one bounded, cycle-safe nested-container traversal. The
server processes only loaded vehicles with an appliance that needs management
and synchronizes food only after an actual state change. The client performs
its visible-state correction only for the currently open VLS appliance
container, avoiding a continuous whole-vehicle inventory scan.

Crafting, microwave, and television adapters share one idempotent reload hook.
Television channels, volume, media, and settings remain on the original game
actions; VLS adapts only the installed vehicle endpoint and auxiliary power.

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
