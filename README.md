# Vehicle Living Slots 3.5.0 Technical Design / 房车生活 3.5.0 技术设计

[简体中文](#简体中文) | [English](#english)

## 简体中文

本文档说明当前公开版本的关键技术设计。适用范围：Project Zomboid Build 42.20，
Workshop `3791192579`，基础 Mod ID `VehicleLivingSlots`，KI5 适配 Mod ID
`VehicleLivingSlotsKI5Campers`，公开版本 `3.5.0`。

基础 Mod 的组件版本为 `RC3.3.1`；KI5 适配组件版本为 `RC3.5.0`。两者共同组成
`v3.5.0`，后者不会替换前者。

### 1. 最高实现原则

能由原版车辆零件、乘客位置、物品、容器、流体组件、TimedAction 和界面表达的行为，
优先复用原版。自建逻辑只负责原版没有的车辆生活能力：

- 把受支持的原版家具和家电安装到车辆生活空间；
- 把生活空间与床位、储物、电器、流体和车辆供电连接起来；
- 为固定水箱、车载家电和多人操作提供服务端权威校验；
- 以独立适配层把同一套能力接入四种 KI5 房车。

安装后的设备仍是原始物品。VLS 不把名称、耐久、内容物、电量或流体转存到代理物品，
也不为每种车型复制一套生活系统。

只支持已经核对的精确车辆 script ID。显示名、车型文字和模糊匹配不能让未知车辆、残骸或
烧毁车型进入支持范围。

### 2. 包边界与模块职责

一个 Workshop 载荷包含两个可选 Mod：

- `VehicleLivingSlots`：可独立使用的原版车辆支持；
- `VehicleLivingSlotsKI5Campers`：依赖基础 Mod、KI5 Campers 和 damnlib 的可选适配层。

| 模块 | 职责 |
| --- | --- |
| `VLS_Config.lua` | 车型档案、设备 capability、生活空间、水箱和供电接口 |
| 车辆脚本 | 为精确车型声明零件、乘客、容器、安装规则和交互区域 |
| `VLS_Client.lua` | 圆形菜单、座位、休息、睡眠、微波炉、电视和流体面板入口 |
| 共享 TimedAction | 休息、车外加水和车内流体转移 |
| `VLS_ApplianceServer.lua` | 家电、制冷、供电、流体和车辆零件的权威状态变更 |
| `VLS_InstallGuard.lua` | 安装物品身份、拆卸条件和容器清空校验 |
| 维修图模块 | 原版风格的物品预览、副电瓶、水箱和 KI5 附加图层 |
| `VLS_KI5Campers_*` | KI5 车型档案、座位图、双水箱、原电瓶和瓦斯适配 |

单人模式与多人模式使用同一套车型、设备和流体规则；多人模式把最终变更交给服务器提交。

### 3. 车型与生活空间模型

车型档案只声明车辆差异，通用能力由基础 Mod 统一实现：

- 原版 SUV 与 PickUpVan：1 个生活空间；
- 原版 Van：3 个生活空间；
- 原版 StepVan：5 个生活空间和 1 个固定水箱；
- KI5 Scamp 13：2 个生活空间和 2 个固定水箱；
- KI5 Scamp 16：3 个生活空间和 2 个固定水箱；
- KI5 Bambi 16：3 个生活空间和 2 个固定水箱；
- KI5 Flying Cloud 22：4 个生活空间和 2 个固定水箱。

每个生活空间拥有稳定的 vehicle part ID，并通过设备 profile 获得能力。车型档案只连接空间、
乘客、水箱、供电和交互区域；它不复制床铺、储物、制冷、净水或同步实现。

这些 part、passenger 和 container ID 是存档接口。没有单独迁移设计时不得重命名、复用或删除。

### 4. 原物品与容器状态

设备 profile 把原版物品映射为 `bed`、`storage`、`cooking`、`cooling`、
`waterDispenser` 或 `television` capability。当前支持睡袋、行军床、床垫、小型木柜、
八类原版直线下柜、两种微波炉、小冰箱、水桶和三种电视。

基础车辆另有独立绿色储物柜和副电瓶零件；KI5 适配不增加该储物柜，也不增加第二块电瓶。

容器容量、类型和声音来自设备 profile。小冰箱提供独立冷藏与冷冻容器；隐藏冷冻 part 只从
维修安装列表隐藏，不从物品栏侧栏隐藏。主容器、冷冻格、固定水箱或已占用床位未满足拆卸条件时，
服务器拒绝拆卸。

Moveable 物品可能没有稳定的普通物品类型，因此安装校验同时使用受控的原版 world sprite
映射。该映射只识别明确支持的家具，不全局替换原版 `VehicleUtils`。

### 5. 座位、进入、休息与睡眠

生活空间只有安装具有 `bed` capability 的设备时，才启用对应乘客位置。安装柜子、家电、
水桶或电视不会把空间变成座位。

进入、切座、退出和睡眠继续调用原版车辆菜单与座位流程。后方 `E` 键仍负责原版行李箱；
床位入口通过休息或睡眠动作提供，不覆盖行李箱交互。车辆睡眠质量只在车内床位路径读取设备
profile；同一睡袋、行军床或床垫放回地面后仍保持原版行为。

KI5 适配保留原有乘客、门、床位、储物、进入动画和座位数量。新增生活空间只与经过核对的
原有车内布局连接，不替换 KI5 的外部进入判定。

### 6. 供电、家电与制冷

所有用电能力通过同一个供电接口解析：

- 原版车辆使用 VLS 副电瓶；
- KI5 房车使用 KI5 原有 `Battery`，不安装第二块电瓶。

微波炉、小冰箱、电视和净水过程消费同一份车辆电源状态。微波炉界面继续使用原版
`ISMicrowaveUI`；VLS 只提供车辆安装物品所缺少的窄接口，并由服务器保存最终设置和耗电。

冰箱继续使用原版 `fridge` 与 `freezer` 容器及物品老化流程。VLS 只根据当前供电状态设置车辆
容器的冷藏、冷冻和断电环境，不建立平行食物或库存系统。

### 7. 水系统

安装水桶和固定水箱统一表示为“车辆流体端点”。端点保留原物品的 FluidContainer、容量、
当前液量和污染状态。

- 车内转移复用原版流体面板，在车载端点和玩家携带容器之间双向转移；
- 车外加水沿用车辆加油式持续动作，包括位置、朝向、动画、声音、中断和进度；
- 水源、玩家、进水口、容量、液体类型和净水耗电在提交前由服务器重新验证；
- 固定水箱未放空时不能拆卸，避免把装水水箱当作普通油箱搬运；
- KI5 两个水箱分别保持“水箱”和“副水箱”身份，并可在原版流体选择器中独立选择。

进入固定水箱的水只在供电接口能够支付本次净水成本时转为净水；VLS 不维护第二套污水系统，
也不会在电量不足时凭空生成净水。

### 8. 多人事务与同步

客户端只提交操作意图和稳定对象 ID，不提交可信的容量、电量、液量或物品状态。服务器在修改前：

1. 重新定位玩家、车辆、零件和原始物品；
2. 验证精确车型、part ID、物品类型、距离、区域和当前状态；
3. 验证容器容量、流体来源、目标余量和供电条件；
4. 执行一次状态变更；
5. 同步受影响的物品、容器和车辆零件。

菜单可见性和 TimedAction 本地校验只改善操作体验，不构成最终授权。最终状态始终以服务器
重新解析到的对象为准。

### 9. KI5 兼容边界与瓦斯

KI5 适配只注册四个精确车型，不复制、修改或重新打包 KI5、damnlib 的车辆、模型、纹理、
声音和脚本资源。基础 Mod 在未启用适配层时不加载任何 KI5 声明。

适配层对 KI5 原有功能只做四项修正或扩展：

- KI5 原有电瓶为全部生活设备供电；
- 瓦斯桶按 `condition / conditionMax` 显示真实物品耐久；
- 维修界面把剩余瓦斯和瓦斯桶耐久分开显示；
- 车旁已安装且有余量的瓦斯桶可为玩家背包中的未满喷灯补气。

喷灯补气只改变瓦斯来源端点。容量换算、动画、声音、手持模型和材料转移语义保持 Build 42
原版配方合同；服务器重新验证车辆瓦斯桶、玩家距离和喷灯所有权后再同步两件物品。

### 10. 维修图与客户端显示

VLS 不替换原版维修面板或整张车辆底图。生活空间和一般设备保留在原版右侧维修列表；左侧图
只增加确有机械位置的副电瓶和固定水箱。

原版车辆附加图层复用原版电瓶、油箱的轮廓和条件蒙版。白色框、连接线、条件颜色、缺件闪烁、
悬停和点击仍由原版维修图流程负责。KI5 继续拥有自己的底图，适配层只添加双水箱图层和必要的
座位标记布局。

维修行展示安装物品自身的耐久和剩余材料，不用 vehicle part 状态覆盖瓦斯、电池或流体物品数据。

### 11. 已知边界、验证与维护

- 当前只面向 Project Zomboid Build 42.20，最低版本为 `42.20.2`；
- 精确车型白名单以当前游戏和 KI5 脚本为依据，上游新增或改名车型不会自动获得支持；
- 运行时界面、寻路、动画、多人重连和存档恢复仍需真实游戏环境回归，静态测试不能替代实测；
- 基础 Mod 可单独启用；KI5 适配必须同时满足三个依赖；
- `v3.5.0` 是当前唯一版本载体和唯一认可回滚基线，基础组件 `RC3.3.1` 不是第二个公开版本；
- 修复必须从认可基线建立隔离候选，先通过私有门禁和测试档验收，再经明确授权发布；
- 不直接在正式服、客户端运行副本或 Workshop 载荷上开发和热改。

公开仓库只保留当前 Mod 载荷、单一恢复版本、安装器和必要文档；内部验证器、服务器地址、
发布凭据、原始日志和私有运维流程不公开。

更精简的包边界说明见
[TECHNICAL_REFERENCE.md](workshop/docs/TECHNICAL_REFERENCE.md)。Steam Workshop：
[房车生活 / Mobile Living](https://steamcommunity.com/sharedfiles/filedetails/?id=3791192579)
（当前保持隐藏）。

这是非官方社区项目，与 The Indie Stone、KI5 和 damnlib 作者无隶属关系。VLS 原创代码和文档
采用 [MIT License](LICENSE)；[NOTICE.md](NOTICE.md) 列出的维修图 PNG 不属于 MIT 授权范围。

## English

This document describes the key technical design of the current public release. Scope: Project
Zomboid Build 42.20, Workshop `3791192579`, base Mod ID `VehicleLivingSlots`, KI5 adapter Mod ID
`VehicleLivingSlotsKI5Campers`, public release `3.5.0`.

The base component is `RC3.3.1`; the KI5 adapter component is `RC3.5.0`. Together they form
`v3.5.0`; the adapter does not replace the base Mod.

### 1. Highest implementation principles

VLS reuses vanilla vehicle parts, passengers, items, containers, fluid components, TimedActions, and
UI flows wherever they can express the required behavior. Custom code is limited to capabilities that
vanilla vehicles do not provide:

- installing supported vanilla furniture and appliances in vehicle living spaces;
- connecting those spaces to beds, storage, appliances, fluids, and vehicle power;
- server-authoritative validation for tanks, appliances, and multiplayer operations; and
- an isolated adapter that connects the same capabilities to four KI5 campers.

Installed equipment remains the original item. Names, condition, contents, charge, and fluids are not
copied into proxy items, and vehicle families do not receive duplicate gameplay implementations.

Support is limited to audited exact vehicle script IDs. Display names and fuzzy matching cannot opt
unknown, wrecked, or burnt vehicles into the system.

### 2. Package boundary and module responsibilities

One Workshop payload contains two optional Mods:

- `VehicleLivingSlots`: standalone vanilla-vehicle support;
- `VehicleLivingSlotsKI5Campers`: optional adapter requiring the base Mod, KI5 Campers, and damnlib.

| Module | Responsibility |
| --- | --- |
| `VLS_Config.lua` | Vehicle profiles, equipment capabilities, living spaces, tanks, and power interfaces |
| Vehicle scripts | Exact parts, passengers, containers, install rules, and interaction areas |
| `VLS_Client.lua` | Radial menus, seats, rest, sleep, microwave, television, and fluid-panel entry points |
| Shared TimedActions | Rest, exterior filling, and interior fluid transfer |
| `VLS_ApplianceServer.lua` | Authoritative appliances, refrigeration, power, fluids, and part state |
| `VLS_InstallGuard.lua` | Install identity, removal conditions, and empty-container validation |
| Mechanics modules | Vanilla-style previews plus additive battery, tank, and KI5 layers |
| `VLS_KI5Campers_*` | KI5 profiles, seat layout, dual tanks, native battery, and propane integration |

Single-player and multiplayer use the same vehicle, equipment, and fluid rules. Multiplayer assigns the
final mutation to the server.

### 3. Vehicle and living-space model

Vehicle profiles declare differences while the base Mod implements shared capabilities:

- vanilla SUV and PickUpVan: one living space;
- vanilla Van: three living spaces;
- vanilla StepVan: five living spaces and one fixed water tank;
- KI5 Scamp 13: two living spaces and two fixed water tanks;
- KI5 Scamp 16: three living spaces and two fixed water tanks;
- KI5 Bambi 16: three living spaces and two fixed water tanks;
- KI5 Flying Cloud 22: four living spaces and two fixed water tanks.

Each living space has a stable vehicle part ID and receives behavior from an equipment profile. Vehicle
profiles connect spaces, passengers, tanks, power, and areas without duplicating bed, storage,
refrigeration, purification, or synchronization logic.

Part, passenger, and container IDs are save interfaces and are not renamed, reused, or removed without
a separate migration design.

### 4. Original items and container state

Equipment profiles map vanilla items to `bed`, `storage`, `cooking`, `cooling`, `waterDispenser`, or
`television` capabilities. Supported groups include sleeping bags, cots, mattresses, a small wooden
cabinet, eight vanilla straight lower-counter families, two microwaves, the mini fridge, water-dispenser
bottles, and three televisions.

Base vehicles also have dedicated green-locker and auxiliary-battery parts. The KI5 adapter adds neither
the locker nor a second battery.

Container capacity, type, and sounds come from the equipment profile. A mini fridge exposes separate
fridge and freezer containers; the hidden freezer part is omitted only from mechanics installation UI,
not from the inventory sidebar. Removal is rejected while a required main container, freezer, fixed tank,
or occupied bed is not safe to remove.

Because Moveables do not always retain a stable ordinary item type, installation also uses a scoped
allowlist of vanilla world sprites. This resolver recognizes only supported furniture and does not
replace vanilla `VehicleUtils` globally.

### 5. Seats, entry, rest, and sleep

A living space enables its passenger position only while bed-capable equipment is installed. Cabinets,
appliances, water bottles, and televisions do not turn a space into a seat.

Entry, seat switching, exit, and sleep continue through vanilla vehicle-menu and passenger flows. Rear
`E` remains the vanilla trunk action; bed access is exposed through Rest or Sleep instead of replacing
the trunk interaction. Vehicle sleep quality is read from the equipment profile only inside the vehicle,
so the same item keeps vanilla ground behavior after removal.

The KI5 adapter preserves native passengers, doors, beds, storage, entry animations, and seat counts.
Added living spaces connect only to audited interior layouts and do not replace KI5's exterior-entry
decision.

### 6. Power, appliances, and refrigeration

Every powered capability resolves through one interface:

- vanilla vehicles use the VLS auxiliary battery;
- KI5 campers use KI5's native `Battery` and receive no second battery.

Microwaves, refrigeration, televisions, and water purification consume the same vehicle power state.
Microwave interaction retains vanilla `ISMicrowaveUI`; VLS supplies only the narrow interface missing
from a vehicle-installed item, while the server stores final settings and consumption.

Refrigerators retain vanilla `fridge` and `freezer` containers and item-ageing behavior. VLS sets the
vehicle-container cooling, freezing, and unpowered environment from current power state instead of
creating a parallel food or inventory system.

### 7. Water system

Installed water-dispenser bottles and fixed tanks share one vehicle-fluid endpoint model. Each endpoint
retains the original item's FluidContainer, capacity, amount, and contamination state.

- interior transfer reuses the vanilla fluid panel for bidirectional transfer with carried containers;
- exterior filling follows a vehicle-refuelling-style TimedAction, including position, facing, animation,
  sound, cancellation, and progress;
- the server revalidates the source, player, inlet, capacity, fluid type, and purification cost;
- a fixed tank must be empty before removal; and
- KI5's two tanks retain separate Water Tank and Auxiliary Water Tank identities in the vanilla selector.

Water entering a fixed tank becomes clean only when the power interface can pay the purification cost.
VLS maintains no second sewage system and never creates clean water when power is insufficient.

### 8. Multiplayer transaction and synchronization

Clients submit intent and stable object IDs, not trusted capacity, power, fluid, or item state. Before a
mutation, the server:

1. re-resolves the player, vehicle, part, and original item;
2. validates the exact vehicle, part ID, item type, distance, area, and current state;
3. validates capacity, source amount, target space, and power requirements;
4. performs one state transition; and
5. synchronizes affected items, containers, and vehicle parts.

Menu visibility and local TimedAction checks improve usability but are not authorization. The final
decision always uses objects re-resolved by the server.

### 9. KI5 compatibility boundary and propane

The adapter registers only four exact vehicles. It does not copy, edit, or repackage KI5 or damnlib
vehicles, models, textures, sounds, or scripts. The base Mod loads no KI5 declarations when the adapter
is disabled.

The adapter changes or extends only four pieces of KI5-native behavior:

- KI5's native battery powers all living equipment;
- propane-tank condition is normalized as `condition / conditionMax`;
- mechanics rows show remaining propane separately from item condition; and
- a non-empty installed propane tank can refill an incomplete carried blowtorch beside the vehicle.

Blowtorch refill changes only the source endpoint. Capacity conversion, animation, sound, hand models,
and material-transfer semantics follow the Build 42 recipe contract. The server revalidates the installed
source, player distance, and recursive ownership of the torch before synchronizing both items.

### 10. Mechanics UI and client presentation

VLS does not replace the vanilla mechanics panel or complete vehicle base image. Living spaces and
general equipment remain in the vanilla right-side list; the left diagram receives only mechanically
located auxiliary-battery and fixed-tank layers.

Vanilla-vehicle layers reuse original battery and fuel-tank outlines and condition masks. White frames,
connectors, condition tint, missing-part flashing, hover, and selection remain owned by the vanilla
mechanics flow. KI5 continues to own its base diagrams; the adapter adds only dual-tank layers and the
required seat-marker layout.

Mechanics rows present the installed item's own condition and remaining material instead of replacing
propane, battery, or fluid item data with vehicle-part condition.

### 11. Known boundaries, verification, and maintenance

- The current target is Project Zomboid Build 42.20 with minimum version `42.20.2`.
- Exact allowlists follow currently audited game and KI5 scripts; upstream additions or renames are not
  supported automatically.
- Runtime UI, pathfinding, animation, multiplayer reconnect, and save restoration require real-game
  regression tests; static validation cannot replace them.
- The base Mod works alone; the KI5 adapter requires all three dependencies.
- `v3.5.0` is the sole public version and sole accepted rollback baseline. Base component `RC3.3.1` is
  not a second public release.
- Repairs branch from the accepted baseline, pass private gates and a test-world acceptance cycle, and
  require explicit authorization before publication.
- Development and hot edits never occur in formal-server, client-runtime, or Workshop payload copies.

The public repository contains only the current payload, sole recovery version, installer, and necessary
documentation. Internal validators, server addresses, publishing credentials, raw logs, and private
operations remain private.

For the compact package contract, see
[TECHNICAL_REFERENCE.md](workshop/docs/TECHNICAL_REFERENCE.md). Steam Workshop:
[Vehicle Living Slots / Mobile Living](https://steamcommunity.com/sharedfiles/filedetails/?id=3791192579)
(currently hidden).

This is an unofficial community project with no affiliation with The Indie Stone, KI5, or the damnlib
authors. Original VLS code and documentation use the [MIT License](LICENSE); mechanics-overlay PNGs
listed in [NOTICE.md](NOTICE.md) are excluded from MIT.
