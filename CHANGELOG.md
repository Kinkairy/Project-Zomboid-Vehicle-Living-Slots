# Changelog

## 3.8.3 capacity1 — 2026-09-17

- Add 100 base capacity to every supported roof rack: StepVan 400, Van/VanSeats 300, SUV/PickUpVan 250.
- Reconcile existing installed rack capacities in place; preserve cargo and condition.
- Keep fabrication materials, interior storage and the four original 3.8.3 changes unchanged.

## 3.8.3

- Keep rack damage, but exclude mounted cargo (including spotlights) from propagated crash damage. 不再连带损坏架上货物；不再連帶損壞架上貨物。
- Reconfigure existing roof lights on load/install, target 48 distance / 1.0 intensity at full normalized condition, and retain native switching/battery drain. 修正射灯刷新与照明参数；修正射燈刷新與照明參數。
- Share installed-propane blowtorch refilling between the base mod and optional KI5 adapter, with tank item identity checks. 车顶瓦斯罐可给喷枪充气；車頂瓦斯罐可給噴槍充氣。
- Add exterior tank-inlet washing with native effects, shared timed-action constructors, authoritative real-water debit and source identity/position checks. 水箱旁可清洗身体及衣物；水箱旁可清洗身體及衣物。
- Preserve materials1 body-family costs, all existing slot/item IDs, models and capacities. No live deployment, save migration or Workshop upload is implied.

## 3.8.2

- 修复无法安装发电机和小箱子的问题。 / Fixed issues preventing generators and small chests from being installed.
- 修复 KI5 房车喷枪充气菜单显示语言键值；提供简中、繁中和英文文字。 / Fixed the untranslated KI5 camper blowtorch refill label in Simplified Chinese, Traditional Chinese and English.
- 保留已合入的护甲、保险杠维修与拆解实现；本次不修改碰撞和维修结算。 / Preserves the existing armor/bumper maintenance implementation without changing collision or repair calculations in this metadata update.

## 3.8.1

3.8.1：新增车窗护甲与前后防撞杠，修复破损外观、储物容量和设备交互问题。 / Added window armor and bumper guards; fixed damage visuals, storage capacity and appliance interactions.

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
