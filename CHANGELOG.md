# Changelog

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
