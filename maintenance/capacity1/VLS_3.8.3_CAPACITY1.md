# VLS 3.8.3 capacity1 — fixed roof rack capacity +100

Baseline public commit: `8cac58cff9433b43701d829e2e5cae5758dbfd77`.
Version remains **3.8.3**; build ID is `release-3.8.3-capacity1-20260917`.

| Body family (including currently supported variants) | Before | After |
|---|---:|---:|
| StepVan | 300 | 400 |
| Van / VanSeats | 200 | 300 |
| SUV / PickUpVan | 150 | 250 |

All 106 registered scripts receive exactly +100 base rack capacity. This does not
add rack support to KI5 campers or unsupported vehicles. Character traits or
other Mods may separately affect effective capacity.

## Implementation

Update `R.rackCapacities`, the five native rack container definitions (including
the reusable default), and the fixed-rack item maximum. Only the fixed rack
receives the increase: small chests remain 10, and interior storage, water and
propane capacities are unchanged. Material-tier calculations stay independent
of capacity, so fabrication costs do not increase.

`R.syncFixedRackCapacity` writes absolute capacities to the same installed item,
vehicle part and ItemContainer during init, native part update and rack access.
It never increments a saved value repeatedly, replaces the item/container,
removes inventory, resets condition or creates a missing rack. The server sends
an item update only when the installed item's maximum changes; clients also
reconcile local capacity. Both peers must update. Native capacity APIs used:
`VehiclePart.getContainerCapacity/setContainerCapacity`, `ItemContainer.getCapacity/setCapacity`,
and `InventoryItem.getMaxCapacity/setMaxCapacity`.

Existing installed racks are updated in place when loaded/updated/accessed;
no reinstall or container emptying is required by this code. This is not an
external save-file editor or world-wide scan. Old on-disk saves have not been
run in a live game here, so load/rejoin and actual UI inventory acceptance remain
part of in-game validation.

Two existing rack UI strings no longer claim universal 300 capacity or repair-only
removal. They are generated from `translations/vls-roof-capacity-ui.json`;
other translated keys are unchanged. Release hashes and deployment pins must be
regenerated; the earlier 3.8.3 ZIP remains the pre-increase build.

## Verification

`tools/test_roof_capacity.lua` tests every supported script, existing loaded racks,
client access, repeated init/update, preserved inventory/condition, zero condition,
wrong/missing parts, empty slots, unchanged recipes, and native template values.
The original six regression suites must also pass. These are actual-source Lua
tests with mocked game objects, not a multiplayer/renderer acceptance test.

This source change and generated update package do not execute on the user's
Windows/NUC, publish to Steam Workshop, change save files or restart a live server.

## 简体中文

行李架基础容量统一增加100：StepVan 400，Van/VanSeats 300，SUV/PickUpVan 250。
旧车已安装的行李架在加载/更新/访问时原位校正，无需重装，不清空物品，不重复叠加。
保持3.8.3及之前四项功能，材料消耗不变。客户端与服务器需要同时使用本构建。

## 繁體中文

行李架基礎容量統一增加100：StepVan 400，Van/VanSeats 300，SUV/PickUpVan 250。
舊車已安裝的行李架在載入/更新/存取時原位校正，無須重裝，不清空物品，不重複疊加。
維持3.8.3及之前四項功能，材料消耗不變。客戶端與伺服器需要同時使用本構建。
