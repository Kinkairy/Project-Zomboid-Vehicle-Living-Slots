# VLS RC3.8 容量复核：原始源码证据摘录

来源：用户上传的 `VLS_sp-live_Cabinet_Evidence_20260910T065537Z.tar.gz`。
压缩包 SHA-256：`07ea15054d88751b3000ec0486729a4d36b07d6d1f9ab045ad25826ae2043403`。
下方 `L` 是包内原文件行号。`source/server_runtime` 是 AG 的分类名，不代表本次独立证明了当前进程加载路径或哈希。

## E1 — 源代码中的容量值
文件：`source/server_runtime/VLS_Config.lua`；原始行 51–64。

```text
L51: VLS.UNIVERSAL_PART_BY_FREEZER = {}
L52: for universalId, freezerId in pairs(VLS.FREEZER_PART_BY_UNIVERSAL) do
L53:     VLS.UNIVERSAL_PART_BY_FREEZER[freezerId] = universalId
L54: end
L55: -- Water entering a large-van tank is normalized to clean water immediately.
L56: VLS.WEAPON_CAPACITY = 40
L57: VLS.CABINET_CAPACITY = 10
L58: VLS.COUNTER_CAPACITY = 50
L59: VLS.MICROWAVE_CAPACITY = 5
L60: VLS.FRIDGE_CAPACITY = 20
L61: VLS.FREEZER_CAPACITY = 5
L62: -- The fridge is a continuous load. The microwave retains its separate,
L63: -- intermittent-use balance because it drains only while active.
L64: VLS.APPLIANCE_DRAIN_DISPLAY_SCALE = 1000
```

## E2 — 原版车辆生活槽的20容量与损伤init
文件：`source/server_runtime/VLS_VanPatch.txt`；原始行 187–212。

```text
L187:             mechanicArea = Back,
L188:             area = TruckBed,
L189:             category = VLSLiving,
L190:             itemType = Base.Mov_Cot;Base.Mattress;Base.SleepingBag_RedPlaid;Base.SleepingBag_BluePlaid;Base.SleepingBag_Green;Base.SleepingBag_GreenPlaid;Base.SleepingBag_Camo;Base.SleepingBag_Cheap_Green;Base.SleepingBag_Cheap_Blue;Base.SleepingBag_Cheap_Green2;Base.SleepingBag_Spiffo;Base.SleepingBag_HighQuality_Brown;Base.SleepingBag_Hide;Base.Mov_Microwave;Base.Mov_Microwave2;Base.Mov_FridgeMini;Base.Mov_SmallPineCabinet;Base.Mov_ModernCounter;Base.Mov_WoodenCounter;Base.Mov_SteelCounter;Base.Mov_BirchCounter;Base.Mov_OakCounter;Base.Mov_DarkCounter;Base.Mov_GreenCounter;Base.Mov_WhiteCounter;Base.WaterDispenserBottle;Base.TvAntique;Base.TvBlack;Base.TvWideScreen,
L191:             specificItem = false,
L192:             mechanicRequireKey = true,
L193:             durability = 3,
L194:             container
L195:             {
L196:                 seat = Bed,
L197:                 capacity = 20,
L198:                 conditionAffectsCapacity = false,
L199:                 test = VLS.ContainerAccess.UniversalSlot,
L200:                 soundMap = ContainerPut VehicleTrunkTransferItem,
L201:                 soundMap = ContainerTake VehicleTrunkTransferItem,
L202:             }
L203:             lua
L204:             {
L205:                 create = VLS.Create.UniversalSlot,
L206:                 init = VLS.Damage.Init,
L207:                 update = VLS.Update.UniversalSlot,
L208:             }
L209:             table install
L210:             {
L211:                 items
L212:                 {
```

## E3 — KI5生活槽的20容量与损伤init
文件：`source/server_runtime/VLS_KI5CampersPatch.txt`；原始行 1–32。

```text
L1: module Base
L2: {
L3:     template vehicle VLSKI5CamperSlots3
L4:     {
L5:         part VLSKI5CamperSlot1
L6:         {
L7:             mechanicArea = Back,
L8:             area = TruckBed,
L9:             category = VLSLiving,
L10:             itemType = Base.Mov_Cot;Base.Mattress;Base.SleepingBag_RedPlaid;Base.SleepingBag_BluePlaid;Base.SleepingBag_Green;Base.SleepingBag_GreenPlaid;Base.SleepingBag_Camo;Base.SleepingBag_Cheap_Green;Base.SleepingBag_Cheap_Blue;Base.SleepingBag_Cheap_Green2;Base.SleepingBag_Spiffo;Base.SleepingBag_HighQuality_Brown;Base.SleepingBag_Hide;Base.Mov_Microwave;Base.Mov_Microwave2;Base.Mov_FridgeMini;Base.Mov_SmallPineCabinet;Base.Mov_ModernCounter;Base.Mov_WoodenCounter;Base.Mov_SteelCounter;Base.Mov_BirchCounter;Base.Mov_OakCounter;Base.Mov_DarkCounter;Base.Mov_GreenCounter;Base.Mov_WhiteCounter;Base.WaterDispenserBottle;Base.TvAntique;Base.TvBlack;Base.TvWideScreen,
L11:             specificItem = false,
L12:             mechanicRequireKey = true,
L13:             durability = 3,
L14:             container
L15:             {
L16:                 capacity = 20,
L17:                 conditionAffectsCapacity = false,
L18:                 test = VLS.ContainerAccess.UniversalSlot,
L19:                 soundMap = ContainerPut VehicleTrunkTransferItem,
L20:                 soundMap = ContainerTake VehicleTrunkTransferItem,
L21:             }
L22:             lua
L23:             {
L24:                 create = VLS.Create.UniversalSlot,
L25:                 init = VLS.Damage.Init,
L26:                 update = VLS.Update.UniversalSlot,
L27:             }
L28:             table install
L29:             {
L30:                 items
L31:                 {
L32:                     1 { tags = base:screwdriver, count = 1, keep = true, equip = primary, }
```

## E4 — Damage.Init按车辆缓存且不恢复容量
文件：`source/server_runtime/VLS_ComponentDamage.lua`；原始行 47–73。

```text
L47: function D.Init(vehicle)
L48:     if isClient and isClient() then
L49:         return nil
L50:     end
L51:     local state = samples[vehicle]
L52:     if state then
L53:         return state
L54:     end
L55:
L56:     state = { targets = setmetatable({}, { __mode = "k" }) }
L57:     for _, id in ipairs(FRONT) do
L58:         local part = vehicle:getPartById(id)
L59:         state[id] = { itemID = itemId(part and part:getInventoryItem()), condition = condition(part) }
L60:     end
L61:     for _, id in ipairs(REAR) do
L62:         local part = vehicle:getPartById(id)
L63:         state[id] = { itemID = itemId(part and part:getInventoryItem()), condition = condition(part) }
L64:     end
L65:     for index = 0, vehicle:getPartCount() - 1 do
L66:         local part = vehicle:getPartByIndex(index)
L67:         if isEligible(part) then
L68:             state.targets[part] = itemId(part:getInventoryItem())
L69:         end
L70:     end
L71:     samples[vehicle] = state
L72:     return state
L73: end
```

## E5 — 实际容量写入函数
文件：`source/server_runtime/VLS_Config.lua`；原始行 684–720。

```text
L684: local CONTAINER_PROFILE_VERSION = 2
L685:
L686: local function applyContainerProfile(container, profile, fallbackType)
L687:     if not container then return false end
L688:     local changed = false
L689:     local capacity = profile and profile.capacity or 0
L690:     if container:getCapacity() ~= capacity then
L691:         container:setCapacity(capacity)
L692:         changed = true
L693:     end
L694:     local containerType = profile and profile.containerType or fallbackType
L695:     local openSound = profile and profile.containerOpenSound or "VehicleTrunkOpen"
L696:     local closeSound = profile and profile.containerCloseSound or "VehicleTrunkClose"
L697:     local putSound = profile and profile.containerPutSound or "VehicleTrunkTransferItem"
L698:     local takeSound = profile and profile.containerTakeSound or "VehicleTrunkTransferItem"
L699:     if container:getType() ~= containerType then
L700:         container:setType(containerType)
L701:         changed = true
L702:     end
L703:     if container:getOpenSound() ~= openSound then
L704:         container:setOpenSound(openSound)
L705:         changed = true
L706:     end
L707:     if container:getCloseSound() ~= closeSound then
L708:         container:setCloseSound(closeSound)
L709:         changed = true
L710:     end
L711:     if container:getPutSound() ~= putSound then
L712:         container:setPutSound(putSound)
L713:         changed = true
L714:     end
L715:     if container:getTakeSound() ~= takeSound then
L716:         container:setTakeSound(takeSound)
L717:         changed = true
L718:     end
L719:     return changed
L720: end
```

## E6 — profile恢复与元数据逻辑
文件：`source/server_runtime/VLS_Config.lua`；原始行 792–838。

```text
L792: function VLS.ensureUniversalContainerProfile(part)
L793:     if not VLS.isUniversalPart(part) then return nil end
L794:     local container = part:getItemContainer()
L795:     if not container then return nil end
L796:     local profile = VLS.getEquipmentProfile(part:getInventoryItem())
L797:     local changed = applyContainerProfile(container,
L798:         profile and profile.capacity and profile or nil,
L799:         VLS.UNIVERSAL_PART_ID)
L800:     return profile, changed
L801: end
L802:
L803: function VLS.syncUniversalSlot(part)
L804:     if not VLS.isUniversalPart(part) then return false end
L805:     local container = part:getItemContainer()
L806:     if not container then return false end
L807:     local item = part:getInventoryItem()
L808:     local profile = VLS.getEquipmentProfile(item)
L809:     local capability = profile and profile.capability
L810:     local vehicle = part:getVehicle()
L811:     local data = part:getModData()
L812:     local itemId = item and item:getID() or -1
L813:     local itemChanged = data.vlsEquipmentItemId ~= itemId
L814:     local profileChanged = data.vlsContainerProfileVersion
L815:         ~= CONTAINER_PROFILE_VERSION
L816:
L817:     -- Part modData and the installed item can arrive before the client-side
L818:     -- ItemContainer fields. Reapply the desired profile on every lifecycle
L819:     -- pass; applyContainerProfile itself writes only fields that differ.
L820:     local _, containerChanged = VLS.ensureUniversalContainerProfile(part)
L821:     data.vlsContainerProfileVersion = CONTAINER_PROFILE_VERSION
L822:
L823:     if (itemChanged or profileChanged)
L824:             and (capability == "cooking" or capability == "cooling")
L825:             and vehicle and vehicle.setNeedPartsUpdate then
L826:         vehicle:setNeedPartsUpdate(true)
L827:     end
L828:     if itemChanged then
L829:         data.vlsEquipmentItemId = itemId
L830:         data.vlsMicrowaveActive = false
L831:         data.vlsMicrowaveTimer = 0
L832:         data.vlsMicrowaveRemaining = 0
L833:         data.vlsMicrowaveTemperature = 90
L834:         container:setCustomTemperature(1.0)
L835:         container:setAgeFactor(1.0)
L836:     end
L837:     return itemChanged or profileChanged or containerChanged
L838: end
```

## E7 — 客户端侧栏刷新会修改本地容量
文件：`source/server_runtime/VLS_Client.lua`；原始行 1394–1428。

```text
L1394: local function refreshVehicleContainerLabels(page, phase)
L1395:     if phase == "end" and page then
L1396:         processVisibleAppliances(page)
L1397:         return
L1398:     end
L1399:     if phase ~= "buttonsAdded" or not page then return end
L1400:     local freezerButtons = {}
L1401:     local hasFreezerButtons = false
L1402:     for _, button in ipairs(page.backpacks or {}) do
L1403:         local container = button.inventory
L1404:         local part = container and container:getVehiclePart()
L1405:         local vehicle = part and part:getVehicle()
L1406:         if VLS.isSupportedVehicle(vehicle) then
L1407:             local name
L1408:             if VLS.isFreezerPart(part) then
L1409:                 name = getText("IGUI_ContainerTitle_freezer")
L1410:             elseif VLS.isUniversalPart(part) then
L1411:                 name = VLS.getPartDisplayName(part,
L1412:                     getText("IGUI_VehiclePart" .. container:getType()))
L1413:             elseif part:getId() == VLS.WEAPON_PART_ID then
L1414:                 name = getText("IGUI_VehiclePart" .. part:getId())
L1415:             end
L1416:
L1417:             if name then
L1418:                 button.name = name
L1419:                 button.tooltip = name
L1420:                 local item = part:getInventoryItem()
L1421:                 if VLS.isUniversalPart(part)
L1422:                         and VLS.ensureUniversalContainerProfile then
L1423:                     VLS.ensureUniversalContainerProfile(part)
L1424:                 end
L1425:                 local iconType = container:getType()
L1426:                 if VLS.isFreezerPart(part) then
L1427:                     iconType = "freezer"
L1428:                 elseif VLS.isUniversalPart(part) then
```

## E8 — 访问检查对照
文件：`source/server_runtime/VLS_Config.lua`；原始行 1827–1841。

```text
L1827: VLS.ContainerAccess = VLS.ContainerAccess or {}
L1828:
L1829: function VLS.ContainerAccess.UniversalSlot(vehicle, part, character)
L1830:     if not part or not VLS.isStorageEquipment(part:getInventoryItem()) then return false end
L1831:     return character ~= nil and character:getVehicle() == vehicle
L1832: end
L1833:
L1834: function VLS.ContainerAccess.WeaponLocker(vehicle, part, character)
L1835:     VLS.syncWeaponLocker(part)
L1836:     if not part or not VLS.isAllowedItem(part, part:getInventoryItem()) then return false end
L1837:     local truckBed = vehicle and vehicle:getPartById("TruckBed")
L1838:     return truckBed ~= nil
L1839:         and character ~= nil
L1840:         and vehicle:canAccessContainer(truckBed:getIndex(), character)
L1841: end
```

## E9 — 柜子没有进入专用家电追踪
文件：`source/server_runtime/VLS_ApplianceServer.lua`；原始行 17–44。

```text
L17: local function hasManagedAppliance(vehicle)
L18:     local profile = vehicle and VLS.getVehicleProfile(vehicle)
L19:     if not profile then return false end
L20:     for _, partId in ipairs(profile.universalParts) do
L21:         local part = VLS.getInstalledPart(vehicle, partId)
L22:         local capability = part
L23:             and VLS.getEquipmentCapability(part:getInventoryItem()) or nil
L24:         if capability == "cooling" then return true end
L25:         if capability == "cooking"
L26:                 and part:getModData().vlsMicrowaveActive then
L27:             return true
L28:         end
L29:         if capability == "television" then
L30:             local deviceData = VLS.getTelevisionDeviceData(part)
L31:             if deviceData and deviceData:getIsTurnedOn() then return true end
L32:         end
L33:     end
L34:     return false
L35: end
L36:
L37: function VLS.Server.trackVehicle(vehicle)
L38:     if vehicle and VLS.isSupportedVehicle(vehicle)
L39:             and hasManagedAppliance(vehicle) then
L40:         trackedVehicles[vehicle:getId()] = true
L41:     elseif vehicle then
L42:         trackedVehicles[vehicle:getId()] = nil
L43:     end
L44: end
```

## E10 — 分钟事件仅遍历已追踪车辆
文件：`source/server_runtime/VLS_ApplianceServer.lua`；原始行 458–478。

```text
L458: local function onEveryOneMinute()
L459:     local currentHours = getGameTime():getWorldAgeHours()
L460:     local seen = {}
L461:     for vehicleId in pairs(trackedVehicles) do
L462:         local vehicle = getVehicleById(vehicleId)
L463:         if vehicle and vehicle:getSquare() and hasManagedAppliance(vehicle) then
L464:             processTrackedVehicle(vehicle, 1, currentHours, seen)
L465:         else
L466:             trackedVehicles[vehicleId] = nil
L467:         end
L468:     end
L469:     for itemId in pairs(cooledFood) do
L470:         if not seen[itemId] then cooledFood[itemId] = nil end
L471:     end
L472: end
L473:
L474: function VLS.Server.updateAppliance(vehicle, part, elapsedMinutes, forceRefresh, slotsSynced)
L475:     if not VLS.isUniversalPart(part) then return end
L476:     VLS.Server.trackVehicle(vehicle)
L477:     VLS.refreshApplianceEnvironment(vehicle, part, forceRefresh, slotsSynced)
L478: end
```

## E11 — 已有原版零件更新函数仍会恢复容量
文件：`source/server_runtime/VLS_Config.lua`；原始行 1120–1150。

```text
L1120: function VLS.Create.UniversalSlot(vehicle, part)
L1121:     VLS.syncUniversalSlot(part)
L1122:     VLS.syncFreezerSlot(vehicle, part and part:getId())
L1123:     VLS.syncTelevisionDevice(vehicle, part, false)
L1124:     VLS.refreshApplianceEnvironment(vehicle, part, true, true)
L1125:     if VLS.Server and VLS.Server.trackVehicle then
L1126:         VLS.Server.trackVehicle(vehicle)
L1127:     end
L1128: end
L1129:
L1130: function VLS.PartComplete.UniversalSlot(vehicle, part)
L1131:     VLS.syncUniversalSlot(part)
L1132:     VLS.syncFreezerSlot(vehicle, part and part:getId())
L1133:     VLS.syncTelevisionDevice(vehicle, part, true)
L1134:     VLS.refreshApplianceEnvironment(vehicle, part, true, true)
L1135:     if VLS.Server and VLS.Server.trackVehicle then
L1136:         VLS.Server.trackVehicle(vehicle)
L1137:     end
L1138: end
L1139:
L1140: function VLS.Update.UniversalSlot(vehicle, part, elapsedMinutes)
L1141:     if VLS.Damage then VLS.Damage.Update(vehicle) end
L1142:     local changed = VLS.syncUniversalSlot(part)
L1143:     if VLS.syncFreezerSlot(vehicle, part and part:getId()) then changed = true end
L1144:     if VLS.syncTelevisionDevice(vehicle, part, false) then changed = true end
L1145:     if VLS.Server and VLS.Server.updateAppliance then
L1146:         VLS.Server.updateAppliance(vehicle, part, elapsedMinutes or 0, changed, true)
L1147:     else
L1148:         VLS.refreshApplianceEnvironment(vehicle, part, changed, true)
L1149:     end
L1150: end
```

## E12 — AG明确没有现场观测
文件：`report.md`；原始行 3–8。

```text
L3: ## 1. Is "displays 50, rejects at ~20" observed in the live sp-live server?
L4:
L5: **Not directly observed during this collection session.** The player reported the symptom
L6: before this evidence collection. Source code analysis strongly supports that the divergence
L7: exists and explains the reported behavior. Runtime confirmation requires a diagnostic probe
L8: (see blockers.md).
```

## E13 — AG对故障对象与数值的未实测指认
文件：`report.md`；原始行 10–31。

```text
L10: ## 2. Which vehicle, part, installed item, and container?
L11:
L12: - Vehicle: not identified at runtime (no Lua execution capability via RCON)
L13: - Part ID: `SeatBed` (VLS universal slot part ID)
L14: - Installed item: one of `Base.Mov_ModernCounter`, `Base.Mov_WoodenCounter`,
L15:   `Base.Mov_SteelCounter`, `Base.Mov_BirchCounter`, `Base.Mov_OakCounter`,
L16:   `Base.Mov_DarkCounter`, `Base.Mov_GreenCounter`, `Base.Mov_WhiteCounter`
L17: - Container: the ItemContainer attached to the SeatBed VehiclePart
L18:
L19: ## 3. Client display / transfer / server actual capacity?
L20:
L21: | Side | Capacity | Source |
L22: |------|----------|--------|
L23: | Client UI | 50 | Set by `refreshVehicleContainerLabels` -> `ensureUniversalContainerProfile` on `buttonsAdded` phase |
L24: | Client transfer check | 50 | Client uses its local container state for pre-check |
L25: | Server actual | 20 | Set by vehicle script `container { capacity = 20 }`, not restored because storage is not in appliance tracking |
L26:
L27: ## 4. Which end and function/branch rejects?
L28:
L29: **Server side.** Most likely `ItemContainer.hasRoomFor()` or equivalent weight check
L30: comparing `getCapacityWeight()` against `getCapacity()` (= 20 on server).
L31: The exact Java branch is not observable without engine access.
```

## E14 — AG建议访问同步即可保证所有转移前校正
文件：`report.md`；原始行 70–83。

```text
L70: ## 7. Next step: minimum modification location
L71:
L72: **Primary fix (narrowest):** Add `VLS.syncUniversalSlot(part)` or
L73: `VLS.ensureUniversalContainerProfile(part)` to
L74: `VLS.ContainerAccess.UniversalSlot()` in VLS_Config.lua (line ~1830).
L75:
L76: This mirrors what `ContainerAccess.WeaponLocker` already does (calls
L77: `syncWeaponLocker` before access check). It ensures capacity is restored
L78: to 50 before any transfer attempt, regardless of whether the vehicle is
L79: tracked by the appliance server.
L80:
L81: **Secondary consideration:** Also add `storage` to `hasManagedAppliance()`
L82: or create a separate tracking path for storage-only vehicles, to ensure
L83: periodic server-side restore even without an access check trigger.
```

## E15 — 现有探针尚未部署且输出字段不足
文件：`probe/minimal_capacity_probe.lua`；原始行 1–27。

```text
L1: -- Minimal VLS Capacity Probe (NOT DEPLOYED)
L2: -- This probe logs container capacity on access to confirm the 50/20 divergence.
L3: -- Deployment requires explicit authorization per task document section 6.3.
L4:
L5: local function logCapacityOnAccess(vehicle, part, character)
L6:     if not part or not VLS.isUniversalPart(part) then return end
L7:     local container = part:getItemContainer()
L8:     if not container then return end
L9:     local item = part:getInventoryItem()
L10:     local profile = VLS.getEquipmentProfile(item)
L11:     local profileCapacity = profile and profile.capacity or "nil"
L12:     local actualCapacity = container:getCapacity()
L13:     local weight = container:getCapacityWeight()
L14:     print(string.format("[VLS-CAP-PROBE] part=%s item=%s profileCap=%s actualCap=%d weight=%.2f",
L15:         part:getId(),
L16:         item and item:getFullType() or "nil",
L17:         tostring(profileCapacity),
L18:         actualCapacity,
L19:         weight))
L20: end
L21:
L22: -- Hook into ContainerAccess.UniversalSlot to log before access
L23: local origAccess = VLS.ContainerAccess.UniversalSlot
L24: VLS.ContainerAccess.UniversalSlot = function(vehicle, part, character)
L25:     logCapacityOnAccess(vehicle, part, character)
L26:     return origAccess(vehicle, part, character)
L27: end
```

## E16 — 未采集的现场文件

`snapshots/README`：
```text
not_collected: no runtime snapshots (no Lua execution capability)
```

`capacity_timeline.jsonl`：
```text
not_collected: no runtime capacity timeline
```

`transfer_attempts.jsonl`：
```text
not_collected: no runtime transfer observation
```

`source/client_runtime/README`：
```text
not_collected: no client runtime files accessible from server
```

`source/engine_excerpts/README`：
```text
not_collected: no engine excerpts available
```

## E17 — 日志复核

本次复核 `logs/server_docker.log` 共 245,770 行；按 UTF-8 读取。
文件 SHA-256：`1ffcd861ad6508a17dd40719f88fd35d2444f58366398eb0f31f9e2cc42cbc97`。
逐行忽略大小写检索 `capacity`、`hasRoomFor`、`actualCap`、`VLS-CAP-PROBE`、`ItemTransaction` 均无命中。
未检出这些字段不等于不存在容量拒绝，只能说明这个日志没有相应诊断字段。
最后一条时间戳为 `2026-09-10T06:55:15.885749407Z`，文件正常以换行结束。
最后一条 VLS 服务器版本记录是原日志 L242175：`[VehicleLivingSlots] Server version RC3.8`。
