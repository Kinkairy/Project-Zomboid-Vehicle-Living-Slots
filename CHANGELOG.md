# Changelog

## 3.8.0

- Publishes the current RC3.8 Workshop payload for the base and KI5 adapter Mods.
- Repairs living-slot initialization and authorized access so each supported slot can
  restore its device container profile without replacing the original container.
- Adds the root-level `ag-handoff/` collaboration record with the task brief, sanitized
  evidence, review, patch, validation, and complete corrected source files.
- Offline candidate checks pass; in-game, save/reconnect, formal-server, and Workshop
  runtime acceptance remain unverified.

## 3.7.0

- Fixes multiplayer water-fill availability and rainy-ground false detection.
- Extends valid inlet-side water-source detection to four tiles, preserves
  existing tank contents on failed transfers, and charges only actual inflow.
- Reduces redundant refrigerator processing and keeps appliance UI hooks
  safe across reloads.

- Adds configurable living spaces to supported vanilla SUVs, PickUpVans, Vans,
  and StepVans while preserving the intended original seats.
- Supports beds, storage furniture, microwaves, mini fridges, televisions,
  water-dispenser bottles, auxiliary vehicle power, and clean-water tanks.
- Adds an optional adapter for four KI5 campers with two clean-water tanks and
  vehicle-specific living-space layouts.
- Uses KI5's original battery for living equipment, corrects propane-tank
  condition and remaining-material display, and allows a mounted propane tank
  to refill a carried blowtorch beside the camper.
- Keeps installed refrigerator, microwave, and television containers bound to
  their original item state when moved between supported vehicles, including
  cooling presentation, localized names, correct icons, and television media.
- Lets an installed approved cabinet provide the vanilla crafting surface and
  keeps the vehicle microwave settings window open while its vehicle context
  remains valid.
- Includes Simplified Chinese, Traditional Chinese, and English text and
  server-authoritative multiplayer synchronization.
