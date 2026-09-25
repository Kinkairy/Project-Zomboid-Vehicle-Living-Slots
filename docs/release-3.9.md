# Mobile Living 3.9

Released on 2026-09-24; updated on 2026-09-25 for Project Zomboid B42.20, including multiplayer.
Workshop: https://steamcommunity.com/sharedfiles/filedetails/?id=3791192579

- Replace the small-appliance area with general-purpose overhead space.
- Fix small appliances taking over the ordinary crafting menu.
- Restore native crafting constructor fields and multiplayer appliance identity.
- Preserve native queued water actions and 3.8.12 liquid-transfer timing.
- Add combination washer/dryer and native trailer-fridge installation support.
- Fix fridge/freezer container selection, progressive laundry effects, shared
  auxiliary battery accounting, TV state and vehicle damage accounting.
- Use native equipment names, one wash-water setting and one wash/dry power
  setting; simplify purification text and remove the battery installation toggle.
- Allow washer installation without a tank; washing still requires clean water
  and auxiliary power, while drying requires only auxiliary power.
- Correct mutually exclusive roof fuel-can models.
- Remove the obsolete separate toaster test slot and its compatibility code.
  Items still installed in that obsolete slot are discarded. The current
  interchangeable coffee-maker/toaster slot is retained.
- DeRumba/skin-Mod adaptation and migration are deferred.

The release payload contains 236 files listed in `release-3.9.json`. The NUC test server and Windows subscription payload use the
same runtime. Source regression checks, native contract probes and targeted
player tests are distinct from exhaustive real-game acceptance.

The accepted RC3.9 crafting-isolation archive remains the owner's sole rollback baseline; this release does not promote a new recovery baseline. Prior standalone VLS backup packages
are retired. Git history and historical manifests are audit history, not active
rollback selections.
