# Vehicle Living Slots / 房车生活

[简体中文](#简体中文) | [English](#english)

## 简体中文

Vehicle Living Slots（房车生活）是面向 Project Zomboid Build 42.20 的车辆生活空间 Mod。
它把原版家具、家电和流体容器接入受支持车辆，并继续使用原版维修、座位、物品栏和
TimedAction 流程。

- 当前版本：`3.5.0`
- 基础 Mod ID：`VehicleLivingSlots`（`RC3.3.1`）
- KI5 适配 Mod ID：`VehicleLivingSlotsKI5Campers`（`RC3.5.0`）
- Workshop ID：`3791192579`
- 外部依赖：基础 Mod 无；KI5 适配需要 KI5 Campers 和 damnlib
- 当前唯一认可回滚基线：`v3.5.0`

完整实现、协议、兼容规则和已知边界见
[TECHNICAL_REFERENCE.md](https://github.com/Kinkairy/Project-Zomboid-Vehicle-Living-Slots/blob/main/workshop/docs/TECHNICAL_REFERENCE.md)。

### 核心设计

- 原版逻辑优先：进入、切座、睡眠、休息、物品转移、微波炉和流体面板尽量复用原版流程。
- 只支持已经核对的精确车辆 script ID，不对未知车辆、残骸或烧毁车型做通配注入。
- 生活设备按 capability 统一实现；车型只声明生活槽、乘客位置、水箱和电源映射。
- 安装后的仍是原版物品，名称、耐久、内容物、电量和流体不转存到代理物品。
- 只有生活槽安装床铺时，对应乘客位置才可进入、休息和睡觉。
- 多人模式由服务器验证并提交最终状态；客户端只发送操作意图和对象 ID。
- KI5 适配层不重新打包或替换 KI5 资源，只把四个精确车型接入 VLS 通用能力。

### 架构

| 模块 | 职责 |
| --- | --- |
| `VLS_Config.lua` 与车辆脚本 | 车型 profile、设备 capability、生活槽、乘客、水箱和电源声明 |
| `VLS_Client.lua` 与共享 TimedAction | 圆形菜单、床位、微波炉、流体面板和容器侧栏 |
| `VLS_ApplianceServer.lua` | 电器、供电、制冷、流体和车辆零件同步 |
| `VLS_InstallGuard.lua` | 安装、拆卸、容器清空和 Moveable 身份校验 |
| 维修图模块 | 原版风格的设备预览、副电瓶和水箱附加图层 |
| `VLS_KI5Campers_*` | KI5 车型、座位图、双水箱、原电瓶和瓦斯适配 |

多人数据流：客户端发起菜单或 TimedAction，服务器按 ID 重新定位当前车辆、零件和原物品，
验证车型、距离、区域、容量和操作条件后才修改状态并同步结果。单人模式复用相同的共享规则，
不维护第二套玩法实现。

### 生活空间与设备

- 原版 SUV 和 PickUpVan 增加 1 个生活槽，Van 增加 3 个，StepVan 增加 5 个。
- KI5 的 Scamp 13、Scamp 16、Bambi 16 和 Flying Cloud 22 分别增加 2、3、3、4 个生活槽，
  同时保留 KI5 原有座位、门、储物和进入判定。
- 原版睡袋、行军床、床垫、柜子、操作台、微波炉、小冰箱、水桶和电视通过设备 profile
  获得床铺、储物、烹饪、制冷、用水或电视能力。
- 容器容量、类型和声音由设备 profile 决定。主容器、冷冻格或固定水箱未清空时不能拆卸。
- 维修界面显示物品本身的耐久和剩余材料，不用车辆 part 状态覆盖原物品数据。

### 供电与流体

所有受电设备走同一套电源接口。原版车辆使用 VLS 副电瓶；KI5 房车直接使用原有电瓶，不增加
第二块电瓶。微波炉、冰箱、电视和净水过程只消费这一份电源状态。

固定水箱、安装在生活槽中的原版水桶和玩家携带的流体容器使用同一个 endpoint 模型。车内
转移复用原版流体面板；车外加水采用原版车辆加油式持续动作。StepVan 配置 1 个固定水箱，
四种 KI5 房车统一配置 2 个固定水箱。

### 兼容与边界

- 目标版本仅为 Project Zomboid Build 42.20。
- 车辆、part、乘客和容器 ID 都属于存档接口；没有独立迁移设计时不会修改。
- 基础 Mod 可以单独使用；KI5 适配必须同时加载基础 Mod、KI5 Campers 和 damnlib。
- KI5 房车继续使用原有电瓶；适配层不增加 VLS 墙柜位，也不修改原有进入逻辑。
- KI5 瓦斯适配分开显示瓦斯桶耐久和剩余瓦斯，并提供服务端验证的车旁喷灯补气。
- VLS 不替换原版维修面板或整张车辆底图；生活槽保留在右侧列表，左图只增加必要图层。
- 未公开开发版的临时 ID 不属于迁移合同；`v3.5.0` 的当前 ID 集合是公开兼容边界。

### 仓库结构

```text
workshop/docs/TECHNICAL_REFERENCE.md                       完整技术参考
recovery/                                                  唯一认可的 3.5.0 恢复载体
workshop/Contents/mods/VehicleLivingSlots                  基础 Mod 源码与元数据
workshop/Contents/mods/VehicleLivingSlotsKI5Campers        KI5 适配源码与元数据
workshop/install_local.ps1                                 本地安装器
CHANGELOG.md                                               公开变更记录
CONTRIBUTING.md                                            贡献说明
SECURITY.md                                                漏洞报告方式
```

公开仓库不包含内部测试工具、服务器地址、发布凭据、原始日志或私有运维流程。

### 获取

Steam 创意工坊：[房车生活 / Mobile Living](https://steamcommunity.com/sharedfiles/filedetails/?id=3791192579)
（当前保持隐藏）。源码安装时，将 `workshop/Contents/mods` 下需要的 Mod 目录复制到
Project Zomboid Mods 目录。

这是非官方社区项目，与 The Indie Stone、KI5 和 damnlib 作者无隶属关系。VLS 原创代码和
文档采用 [MIT License](LICENSE)；[NOTICE.md](NOTICE.md) 中列出的维修图 PNG 不属于 MIT
授权范围。

## English

Vehicle Living Slots is a vehicle-living-space Mod for Project Zomboid Build 42.20. It connects
vanilla furniture, appliances, and fluid containers to supported vehicles while retaining the
vanilla mechanics, passenger, inventory, and TimedAction flows.

- Current release: `3.5.0`
- Base Mod ID: `VehicleLivingSlots` (`RC3.3.1`)
- KI5 adapter Mod ID: `VehicleLivingSlotsKI5Campers` (`RC3.5.0`)
- Workshop ID: `3791192579`
- External dependencies: none for the base Mod; KI5 Campers and damnlib for the adapter
- Sole accepted rollback baseline: `v3.5.0`

See
[TECHNICAL_REFERENCE.md](https://github.com/Kinkairy/Project-Zomboid-Vehicle-Living-Slots/blob/main/workshop/docs/TECHNICAL_REFERENCE.md)
for the complete implementation, protocol, compatibility rules, and known boundaries.

### Core Design

- Vanilla first: entry, seat switching, sleep, rest, item transfer, microwave, and fluid UI reuse
  original flows wherever possible.
- Only verified exact vehicle script IDs are supported; unknown, wrecked, and burnt vehicles never
  receive wildcard injection.
- Equipment capabilities are implemented once; vehicle profiles declare only slots, passengers,
  tanks, and power mapping.
- Installed equipment remains the original vanilla item, including name, condition, contents, charge,
  and fluids.
- A passenger position becomes usable only while its living slot contains bed-capable equipment.
- In multiplayer, the server validates and commits final state; clients submit intent and object IDs only.
- The KI5 adapter does not repackage or replace KI5 assets. It maps four exact vehicles into shared VLS
  capabilities.

### Architecture

| Module | Responsibility |
| --- | --- |
| `VLS_Config.lua` and vehicle scripts | Vehicle profiles, equipment capabilities, slots, passengers, tanks, and power |
| `VLS_Client.lua` and shared TimedActions | Radial menus, beds, microwave, fluid panel, and container sidebar |
| `VLS_ApplianceServer.lua` | Appliances, power, refrigeration, fluids, and vehicle-part synchronization |
| `VLS_InstallGuard.lua` | Installation, removal, empty-container, and Moveable-identity validation |
| Mechanics modules | Vanilla-style equipment previews and additive battery/tank overlays |
| `VLS_KI5Campers_*` | KI5 vehicles, seat diagrams, two tanks, native battery, and propane integration |

In multiplayer, the client starts a menu action or TimedAction. The server relocates the current vehicle,
part, and original item by ID, validates the profile, distance, area, capacity, and operation, and only
then changes state and synchronizes the result. Single-player reuses the same shared rules.

### Living Spaces and Equipment

- Vanilla SUV and PickUpVan profiles add one living slot, Van adds three, and StepVan adds five.
- KI5 Scamp 13, Scamp 16, Bambi 16, and Flying Cloud 22 add two, three, three, and four living slots
  respectively while retaining native seats, doors, storage, and entry checks.
- Vanilla sleeping bags, cots, mattresses, cabinets, counters, microwaves, mini fridges, water bottles,
  and televisions receive bed, storage, cooking, cooling, water, or television capabilities through
  equipment profiles.
- Capacity, container type, and sound come from the equipment profile. A non-empty main container,
  freezer, or fixed tank blocks removal.
- The mechanics UI presents item condition and remaining material without replacing original item data
  with vehicle-part condition.

### Power and Fluids

All powered equipment uses one power resolver. Vanilla vehicles use the VLS auxiliary battery; KI5
campers use their native battery and receive no second battery. Microwaves, refrigeration, televisions,
and water purification consume that one power state.

Fixed tanks, installed vanilla water bottles, and carried fluid containers use one endpoint model.
Interior transfer reuses the vanilla fluid panel; exterior filling uses a refuelling-style continuous
action. StepVan has one fixed tank, while every supported KI5 camper has two.

### Compatibility and Boundaries

- The supported target is Project Zomboid Build 42.20 only.
- Vehicle, part, passenger, and container IDs are save interfaces and are not changed without a separate
  migration design.
- The base Mod works alone. The KI5 adapter requires the base Mod, KI5 Campers, and damnlib.
- KI5 campers keep their native battery; the adapter adds no VLS locker and does not replace native entry.
- KI5 propane integration separates tank condition from remaining propane and provides a
  server-validated vehicle-side blowtorch refill.
- VLS does not replace the vanilla mechanics panel or complete base image. Living slots remain in the
  right-side list; only required layers are added to the diagram.
- Temporary IDs from unpublished builds are outside the migration contract. The `v3.5.0` ID set is the
  public compatibility boundary.

### Repository Layout

```text
workshop/docs/TECHNICAL_REFERENCE.md                       Complete technical reference
recovery/                                                  Sole accepted 3.5.0 recovery artifacts
workshop/Contents/mods/VehicleLivingSlots                  Base Mod source and metadata
workshop/Contents/mods/VehicleLivingSlotsKI5Campers        KI5 adapter source and metadata
workshop/install_local.ps1                                 Local installer
CHANGELOG.md                                               Public change history
CONTRIBUTING.md                                            Contribution guide
SECURITY.md                                                Vulnerability reporting
```

The public repository excludes internal test harnesses, server addresses, publishing credentials, raw
logs, and private operational procedures.

### Distribution

Steam Workshop: [Vehicle Living Slots / Mobile Living](https://steamcommunity.com/sharedfiles/filedetails/?id=3791192579)
(currently hidden). For a source installation, copy the required Mod directories under
`workshop/Contents/mods` into the Project Zomboid Mods directory.

This is an unofficial community project and is not affiliated with The Indie Stone, KI5, or the damnlib
authors. Original VLS code and documentation use the [MIT License](LICENSE); the mechanics-overlay PNG
files listed in [NOTICE.md](NOTICE.md) are excluded from MIT.
