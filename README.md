# Vehicle Living Slots / 房车生活

[简体中文](#简体中文) | [English](#english)

## 简体中文

Vehicle Living Slots 是建立在 Project Zomboid Build 42.20 原版车辆系统之上的生活空间
扩展层。它不重做车辆、座位、容器、电器和流体系统，而是把可安装生活设备接入原版维修、
物品栏、座位、TimedAction 和多人同步流程。

- 当前发布版本：`3.5.0`
- 基础 Mod：`VehicleLivingSlots`（`RC3.3.1`）
- 可选 KI5 适配：`VehicleLivingSlotsKI5Campers`（`RC3.5.0`）
- 最低游戏版本：`42.20.2`

完整实现记录见[技术参考](workshop/docs/TECHNICAL_REFERENCE.md)。

### 核心架构

```text
精确车型 profile
  -> 生活槽、乘客位置、水箱和电源映射
  -> 原版物品安装
  -> 通用设备能力
  -> 原版 UI / TimedAction
  -> 服务端验证、修改和同步
```

基础 Mod 负责全部通用能力；车型和兼容 Mod 只提供 profile 与位置映射。因此床铺、储物、
微波炉、冰箱、电视、供电和用水始终只有一套实现，不会按车型复制。

### 原版逻辑优先

车辆进入、切换座位、睡眠、休息、物品转移、微波炉面板、流体转移和维修安装尽量直接复用
原版流程。VLS 只在原版接口无法直接表示“安装在车辆上的家具”时增加局部适配器，不全局替换
原版菜单或 UI。

每个生活槽与一个隐藏乘客位置对应。只有槽内安装床铺时，该位置才可进入、休息和睡觉；安装
柜子或电器时，它仍是设备位置，不会变成虚假座位。

### Profile 与设备能力

只有登记过的精确车辆 script ID 才会进入 VLS：

| 车辆类别 | 新增生活槽 | 固定水箱 | 电源 |
| --- | ---: | ---: | --- |
| 原版 SUV / PickUpVan | 1 | 0 | VLS 副电瓶 |
| 原版 Van | 3 | 0 | VLS 副电瓶 |
| 原版 StepVan | 5 | 1 | VLS 副电瓶 |
| KI5 露营拖车 | 2–4 | 2 | KI5 原有电瓶 |

原版睡袋、行军床、床垫、柜子、操作台、微波炉、小冰箱、饮水机水桶和电视通过统一的设备
profile 转换为床铺、储物、烹饪、制冷、用水或电视能力。车型只声明有哪些槽，不直接实现
设备功能。

### 保留真实物品状态

安装到车辆上的仍是玩家持有的原版物品。物品类型、名称、耐久、内容物、电量和流体继续保存
在原物品与车辆 part 上，VLS 不创建代理物品或第二份持久化数据。

维修界面因此可以同时显示物品耐久和剩余材料。存储设备必须清空后才能拆卸，固定水箱必须
排空后才能拆卸，避免利用安装和拆卸复制物品或流体。

### 统一供电与流体

所有受电设备走同一套电源接口：原版车辆解析 VLS 副电瓶，KI5 房车解析其原有电瓶。微波炉、
冰箱、电视和净水过程只是统一耗电管线的消费者，不维护各自独立的电量。

固定水箱、安装在生活槽中的原版水桶和玩家携带的流体容器使用同一个流体 endpoint 模型。
车内转移复用原版流体面板；车外给固定水箱加水采用原版车辆加油式的持续动作。容量、净水
类型和余量显示继续由原版 `FluidContainer` 与维修界面负责。

### 多人服务端权威

客户端只发送操作意图以及车辆、零件和物品标识。服务端在提交时重新定位玩家、车辆、零件和
原物品，并验证车型 profile、距离、区域、当前状态、容量和允许操作，然后才修改容器、流体、
电量或设备状态并同步结果。

```text
客户端操作
  -> 服务端重新解析当前世界状态
  -> 验证身份、距离、零件、容量和材料
  -> 调用唯一的通用实现
  -> 同步物品与车辆零件
```

动作过程中发生的状态变化以服务端提交时的真实状态为准，不能依靠客户端旧快照完成重复转移
或越权操作。

### KI5 兼容层

KI5 适配层不重新打包或替换 KI5 的车辆资源和整车定义。它只为以下四个精确车型增加 VLS
profile：1987 Scamp 13、1987 Scamp 16、1961 Bambi 16 和 1954 Flying Cloud 22。

适配层保留 KI5 原有座位、门、储物、电瓶和进入判定，只增加 2–4 个生活槽、两个净水箱及
必要的座位连接。所有生活设备直接使用 KI5 原有电瓶，不增加第二块电瓶，也不增加 VLS 墙柜位。

KI5 瓦斯适配把瓦斯桶物品耐久与剩余瓦斯分开显示，并修正完好瓦斯桶被显示为 10% 的问题。
车旁喷灯补气保留原版动作形式，但完成时仍由服务端重新验证喷灯、车辆位置和瓦斯来源。

### 维修图与兼容边界

VLS 不替换原版维修面板或整张车辆底图。原版车辆左图只增加副电瓶和固定水箱；通用生活槽与
设备继续显示在右侧零件列表。新增图层把白色边框/连线与状态蒙版分开，继续使用原版条件色、
缺件闪烁、悬停和点击逻辑。

车辆、part、乘客和容器 ID 都属于存档接口。VLS 只注册已经核对的完整车型，不对未知车辆、
残骸或烧毁车型做通配注入；没有独立迁移设计时不会随意修改既有 ID。

VLS 原创代码和文档采用 [MIT License](LICENSE)。[NOTICE.md](NOTICE.md) 中列出的维修图 PNG
不属于 MIT 授权范围，其权利仍归原权利方所有。

---

## English

Vehicle Living Slots is a living-space extension layer built on the vanilla
Project Zomboid Build 42.20 vehicle system. It does not rebuild vehicles,
passengers, containers, appliances, or fluids. Instead, installable living
equipment is connected to the original mechanics, inventory, passenger,
TimedAction, and multiplayer synchronization flows.

- Current release: `3.5.0`
- Base Mod: `VehicleLivingSlots` (`RC3.3.1`)
- Optional KI5 adapter: `VehicleLivingSlotsKI5Campers` (`RC3.5.0`)
- Minimum game version: `42.20.2`

See the [technical reference](workshop/docs/TECHNICAL_REFERENCE.md) for the
complete implementation record.

### Core architecture

```text
exact vehicle profile
  -> living slots, passengers, tanks, and power mapping
  -> original inventory-item installation
  -> shared equipment capability
  -> vanilla UI / TimedAction
  -> server validation, mutation, and synchronization
```

The base Mod owns every shared capability. Vehicle classes and compatibility
Mods provide only profiles and layout mappings. Beds, storage, microwaves,
refrigeration, televisions, power, and water therefore have one implementation
rather than a copy per vehicle.

### Vanilla first

Vehicle entry, seat switching, sleep, rest, item transfer, the microwave panel,
fluid transfer, and mechanics installation reuse vanilla flows wherever
possible. VLS adds scoped adapters only where vanilla interfaces cannot directly
represent furniture installed as a vehicle part. It does not globally replace
vanilla menus or UI classes.

Each living slot maps to one hidden passenger position. That position becomes
enterable, restable, and sleepable only while the slot contains bed-capable
equipment. A cabinet or appliance remains equipment and never becomes a fake
seat.

### Profiles and equipment capabilities

Only exact registered vehicle script IDs enter VLS behavior:

| Vehicle class | Living slots | Fixed tanks | Power |
| --- | ---: | ---: | --- |
| Vanilla SUV / PickUpVan | 1 | 0 | VLS auxiliary battery |
| Vanilla Van | 3 | 0 | VLS auxiliary battery |
| Vanilla StepVan | 5 | 1 | VLS auxiliary battery |
| KI5 camper | 2–4 | 2 | Native KI5 battery |

Vanilla sleeping bags, cots, mattresses, cabinets, counters, microwaves, mini
fridges, water-dispenser bottles, and televisions are resolved through shared
equipment profiles into bed, storage, cooking, cooling, water, or television
capabilities. Vehicles declare slots; they do not implement devices.

### Real item state

The installed object remains the player's original vanilla item. Type, name,
condition, contents, charge, and fluid stay on the item and vehicle part. VLS
does not create proxy objects or a second persistent state model.

The mechanics UI can therefore show item condition and remaining material
separately. Storage must be empty before removal, and fixed tanks must contain
no water, preventing installation/removal from duplicating items or fluids.

### Unified power and fluids

Every powered appliance uses one power resolver. Vanilla vehicles resolve the
VLS auxiliary battery; KI5 campers resolve their native battery. Microwaves,
refrigeration, televisions, and water purification are consumers of the same
power pipeline and never maintain independent charge values.

Fixed tanks, installed vanilla water bottles, and carried portable containers
use one fluid-endpoint model. Interior transfer reuses the vanilla fluid panel;
exterior tank filling uses a vehicle-refuelling-style continuous action.
Capacity, clean-water type, and remaining amount stay owned by the vanilla
`FluidContainer` and mechanics presentation.

### Server-authoritative multiplayer

Clients submit intent plus vehicle, part, and item identities. At commit time,
the server relocates the actor, vehicle, part, and original item, validates the
profile, distance, area, current state, capacity, and operation, and only then
changes container, fluid, battery, or appliance state and synchronizes it.

```text
client action
  -> server resolves current world state
  -> validate identities, distance, parts, capacity, and material
  -> call the single shared implementation
  -> synchronize items and vehicle parts
```

Changes that happen while an action is running are judged from server state at
commit time, not from a stale client snapshot.

### KI5 adapter boundary

The KI5 adapter does not repackage or replace KI5 vehicle resources or complete
vehicle definitions. It registers VLS profiles only for 1987 Scamp 13, 1987
Scamp 16, 1961 Bambi 16, and 1954 Flying Cloud 22.

Native KI5 seats, doors, storage, battery, and entry validation remain. The
adapter adds two to four living slots, two clean-water tanks, and the required
seat links. All living equipment uses the native KI5 battery; no second battery
or VLS locker part is added.

Propane integration separates tank-item condition from remaining propane and
corrects the false 10% condition display. Vehicle-side blowtorch refill keeps
the vanilla action shape, while the server revalidates the torch, vehicle area,
and propane source at completion.

### Mechanics overlay and compatibility

VLS does not replace the vanilla mechanics panel or complete vehicle base
image. Vanilla profiles add only the auxiliary battery and fixed tank to the
left diagram; living slots and appliances remain in the right-side parts list.
White guides and condition masks stay separate so vanilla condition tint,
missing-part flash, hover, and click behavior remain intact.

Vehicle, part, passenger, and container IDs are save interfaces. VLS registers
only verified intact vehicles, never wildcard-injects unknown, wrecked, or burnt
variants, and does not change established IDs without a separate migration
design.

Original VLS code and documentation use the [MIT License](LICENSE). The
mechanics-overlay PNG files listed in [NOTICE.md](NOTICE.md) are excluded from
MIT and remain subject to their original rights.
