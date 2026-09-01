# Vehicle Living Slots / 房车生活

## 中文说明

房车生活将受支持的原版车辆及可选的 KI5 露营拖车改造成可自由配置的移动生活空间。玩家可通过
原版车辆维修与物品栏界面安装床铺、储物家具、生活电器、饮水设备、净水箱和车辆供电设备。

当前版本：Project Zomboid Build 42.20.2，**3.5.0**。`v3.5.0` 是当前唯一公开版本和
唯一认可回滚基准。

- Steam 工坊 ID：`3791192579`（工坊目前尚未公开）
- 原版车辆 Mod ID：`VehicleLivingSlots`（`RC3.3.1`）
- KI5 可选适配 Mod ID：`VehicleLivingSlotsKI5Campers`（`RC3.5.0`）

### 两种启用方式

#### 仅使用原版车辆

只启用 `VehicleLivingSlots`，不需要安装其他 Mod。

- SUV 和 PickUpVan：保留全部原版座位，增加 1 个生活空间。
- Van：保留前排两个座位，增加 3 个生活空间。
- StepVan：保留前排两个座位，增加 5 个生活空间和 1 个净水箱安装位。
- 不支持客运厢式车、车辆残骸和烧毁车辆。

#### 原版车辆与 KI5 露营拖车

同时启用 `VehicleLivingSlots` 和 `VehicleLivingSlotsKI5Campers`，并安装：

- [KI5 Campers](https://steamcommunity.com/sharedfiles/filedetails/?id=3670064951)
- [damnlib](https://steamcommunity.com/sharedfiles/filedetails/?id=3171167894)

适配 1987 Scamp 13、1987 Scamp 16、1961 Bambi 16 和 1954 Flying Cloud 22。适配层保留
KI5 原有座位、床铺、储物、电瓶和进入逻辑，并按车型增加 2–4 个可配置生活空间及两个净水箱
安装位。

### 功能

- 床铺：支持行军床、床垫和原版睡袋，可用于休息和睡觉。
- 储物：支持的原版柜子和操作台会成为车辆容器。
- 电器：支持微波炉、带冷冻格的小冰箱和电视机。
- 用水：支持饮水机水桶、净水箱和原版流体转移面板。
- 供电：生活设备使用副电瓶；KI5 房车直接使用其原有电瓶，无需第二块电瓶。
- 维修界面：显示水量、电量、瓦斯余量及对应物品本身的耐久。
- KI5 瓦斯：修正完好瓦斯桶被显示为 10% 的问题；安装有剩余瓦斯的瓦斯桶后，站在车旁即可
  为随身未充满的喷灯补充瓦斯。
- 多人游戏：物品、流体、电器和供电变化均由服务器验证。
- 语言：简体中文、繁体中文和英文。

### 安装

将 `workshop/Contents/mods` 下需要的一个或两个 Mod 目录复制到 Project Zomboid 的 Mods
目录。Windows 也可以使用仓库附带的安装脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\workshop\install_local.ps1
```

在长期游玩的世界中增加或移除车辆 Mod 前，请先备份存档。

### 仓库范围

不可变的 `v3.5.0` 标签和 Release 压缩包保存精确的 67 文件双 Mod 载荷。仓库只保留
3.5.0 回滚 ZIP、清单和校验值，不公开内部测试工具、CI、服务器运维资料、凭据、私有路径、
原始日志、缓存、重复工坊描述、本地发布文件、无关 Mod 或未确认可公开再分发的图片素材。

实现边界和多人同步方式见[技术说明](workshop/docs/TECHNICAL_REFERENCE.md)。VLS 原创代码、
文档、翻译和工具使用 [MIT License](LICENSE)。[NOTICE.md](NOTICE.md) 中列出的维修图 PNG
不属于 MIT 授权范围，其权利仍归原权利方所有。

这是非官方社区项目，与 The Indie Stone、KI5 和 damnlib 作者不存在隶属或背书关系。

---

## English

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
- KI5 propane: fixes the incorrect 10% display for an undamaged tank and allows
  a mounted tank with propane remaining to refill a carried blowtorch beside the
  camper.
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
