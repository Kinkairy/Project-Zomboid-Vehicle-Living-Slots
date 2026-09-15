# 小箱子核查与发电机安装去扳手修补

日期：2026-09-16。

## 当前交付状态

这里只新增核查记录与可执行的源码修补脚本 `apply_generator_fix.py`。**运行源码尚未应用本修补，也未部署、上传工坊、重启或操作存档。** 不要把本目录的提交误当成游戏已加载修复。

审查的公开运行源码提交：`4eba8ee90449ae738efc266d6c6bf1dc9ac66b6b`。修补器核对三个目标文件的 Git blob SHA，而不是要求 HEAD 必须停在这个提交；仅文档变化不会阻止应用，有未知功能变化则停止。

## 1. 小箱子：物品种类与朝向要分开

在本次查到的公开原版脚本快照中，明确命名为 Small Chest 的家具物品为 `Base.Mov_SmallChest`，其代表贴图是 `furniture_storage_02_28`。同一文件还分别定义了 `Mov_MilitaryCrate`、`Mov_CardboardBox` 等不同容器；不能把它们按中文名称或大小一概当作同一个车顶零件。

公开 B42 MoreBuilds 的 MetalChest 放置定义把以下四个贴图归入同一个箱子：

- `furniture_storage_02_28`（northSprite）
- `furniture_storage_02_29`（sprite / previewSprite）
- `furniture_storage_02_30`（southSprite）
- `furniture_storage_02_31`（eastSprite）

这支持“同款箱子有四个朝向资源”的判断，不是四种独立物品。该放置定义是交叉核验来源，**并不等于已经读取用户当前 B42.20 的全部运行时贴图属性或已安装 Mod**。

当前 VLS 在 `VLS_RoofCargo.lua` 中只给 `_28` 添加了 `supportedMoveableSprites` 映射；`VLS.resolveEquipmentType()` 先匹配 fullType / scriptType，前两者不匹配时才依赖贴图。因此其余朝向存在兜底漏认路径，但截图中的那只箱子仍需读取 fullType、scriptType、worldSprite、condition 才能确定原因。菜单候选与原版 tooltip 的类型统计也不能混为一谈。

本修补**不修改小箱子识别、容量、物品类型或白名单**。先核查用户实际物品，不能为消除 0/1 而放行任意箱子、伪造类型或把所有家具归为 Mov_SmallChest。

参考：

- [公开原版物品脚本快照](https://github.com/wink-/pzmcp/blob/44483447a32ce48fa1dff602b046bfbc15f7c45a/media/scripts/moveables/moveables_containers.txt)
- [B42 MoreBuilds 放置定义（MetalChest）](https://github.com/ProjectSky/MoreBuilds/blob/0429a4fa357872ba96f3170c9117b20e40d54fab/42/media/lua/shared/MoreBuildings/providers/definitions/Storage.lua)
- [VLS 小箱子配置](https://github.com/Kinkairy/Project-Zomboid-Vehicle-Living-Slots/blob/4eba8ee90449ae738efc266d6c6bf1dc9ac66b6b/workshop/Contents/mods/VehicleLivingSlots/common/media/lua/shared/VLS_RoofCargo.lua)

## 2. 发电机：只去掉安装时的扳手

原版 `ISTakeGenerator:complete()` 把同一个发电机物品同时设为主手和副手。当前两套 VLS 模板却在发电机的 `table install` 中要求 `base:wrench` 并 `equip = primary`；原版维修菜单会据此排入装备工具的动作。服务端安装检测还另行检查扳手，不能只删提示或只改客户端。

修补器仅修改以下三处：

1. `common/media/scripts/VLS_VehicleRoofAdapters.txt` 的 `VLSRoofReusableParts -> VLSRoofGenerator -> table install`：移除扳手 items 块。
2. `common/media/scripts/VLS_StepVanRoofRackAdjustment.txt` 的 `VLSRoofCargoTemplate -> VLSRoofGenerator -> table install`：移除同样的 items 块。
3. `common/media/lua/shared/VLS_RoofCargo.lua` 的 `R.InstallTest()` 服务端分支：仅对发电机安装免除扳手检测，保留角色存活、车辆对应、已安装行李架、槽位未占用、开关等检查。

不改原版双手搬运规则；不添加第三只手、不强制清空手持物、不新建替代发电机。继续使用同一实体物品及现有安装完成流程。四个既有发电机类型均保留：`Generator / Generator_Old / Generator_Yellow / Generator_Blue`。

**发电机拆卸仍需扳手。** 小箱子、瓦斯罐、备胎、车顶灯、行李架及护甲的工具、配方、模型和损伤逻辑都不变。既有 skill、time、requireInstalled 和安装动作的物品归属校验保留。此次不重编号、不发布版本，也不动 KI5 适配包。

参考：

- [原版发电机拿取动作](https://github.com/Project-Zomboid-Community-Modding/ProjectZomboid-Vanilla-Lua/blob/8a906692ac56f9d40c078d654eea6c70491cbc62/shared/TimedActions/ISTakeGenerator.lua)
- [原版车辆安装的工具装备流程](https://github.com/Project-Zomboid-Community-Modding/ProjectZomboid-Vanilla-Lua/blob/8a906692ac56f9d40c078d654eea6c70491cbc62/client/Vehicles/ISUI/ISVehiclePartMenu.lua)

## 3. AG 应用方式

在公开 VLS 源码仓库根目录操作，不要在 Steam 下载目录、存档目录或某个 Mod 运行目录执行。先检查本地差异并取得本目录；不要覆盖本地未提交工作。

预览并核验（不写入）：

```bash
python ag-handoff/fixes/generator-install-no-wrench-20260916/apply_generator_fix.py --repo .
```

确认为三个预期文件后应用：

```bash
python ag-handoff/fixes/generator-install-no-wrench-20260916/apply_generator_fix.py --repo . --apply
git diff --check
git diff --stat
```

脚本只需 Python 3.9+、Git 和标准库；保留文件 BOM / CRLF，全部目标核验后才写入，支持重复执行无额外变化。源文件 SHA 不符时会停止，不要添加强制覆盖选项。处理的是目标模板中的 generator，不会把文件中其他同名模型覆盖块、所有扳手要求或整个车顶实现一起删掉。

## 4. 验证范围与待验收

已在工作容器完成 6 个 Python 单测和 24 项 Lua 5.4 模拟对象分支断言。覆盖目标模板定位、重复同名模型、仅删除安装扳手、拆卸表不变、CRLF/BOM、重复运行、未知源版本拒绝、并发修改保护，以及服务器发电机无扳手、其他零件仍需扳手、缺行李架、已占槽、禁用、错误车辆、死亡角色、原版客户端否决、四种发电机类型与错误/缺失物品的校验。

这些是**离线源码片段与模拟对象验证，不是 B42.20 实机测试**；也没有在用户的完整本地源码 checkout 中执行修补器。

实机验收需在客户端与服务端应用相同源码后进行：先按原版方式双手搬起发电机，不带任何扳手，从维修界面安装；确认没有装备扳手或自动放下发电机的动作，只有同一台发电机从人物库存转为车顶安装物，油量/耐久保留。分别检验四种发电机、StepVan 与使用可复用模板的受支持车型、鼠标和手柄入口；中断/重连无重复或丢失；缺行李架或关闭沙盒时仍不能安装；拆卸及其他车顶装备的扳手要求仍有效。

本脚本不会部署或重启。运行时更换必须同时更新客户端和服务端并重新加载 Mod；不要用旧的全量 FIX1 覆盖包替代这三个定点变更。
