# VLS 3.8.2 — AG 发布、并入 main 与全环境部署任务

## 结论

用户已完成实机测试，当前 VLS 修复版本可以作为正式版发布。

- 仓库：`Kinkairy/Project-Zomboid-Vehicle-Living-Slots`
- 3.8.1 正式基线：`6583f677ba9bb06756e726580376e712baba8626`
- 已测试通过的功能代码：`716b0d7d91c9104eb168fa77432cc625dcaf7870`
- 新正式版本：`3.8.2`
- Steam Workshop Item ID：`3791192579`
- 不创建新的 Workshop Item，必须更新现有条目。

**重要：不要继续改本轮已经验证通过的功能行为。** 除发布元数据、版本号、CHANGELOG/README/Workshop 文案外，不要重新设计护甲、保险杠、行李架、修理、拆解或 tooltip 逻辑。

---

## 1. 先确认 main 状态

执行前先拉取远端：

```bash
git fetch origin
```

检查：

```bash
git rev-parse origin/main
```

### 情况 A：`origin/main == 716b0d7d91c9104eb168fa77432cc625dcaf7870`

当前测试通过代码已经在 `main`，**不要再次 cherry-pick / merge 同一批提交**。直接以当前 `main` 做 3.8.2 发布元数据整理。

### 情况 B：main 已有后续提交

不要直接覆盖。先做：

```bash
git log --oneline --decorate --graph -20 origin/main
git diff 716b0d7d91c9104eb168fa77432cc625dcaf7870..origin/main -- workshop/Contents/mods/VehicleLivingSlots
```

如果后续提交只是本文档或发布元数据，可继续；如果有新的功能代码，先停止并报告，不要把已测试版本和未知改动混在同一个 3.8.2 发布里。

---

## 2. 3.8.2 必须包含的已测试修复

3.8.2 的功能代码以 `716b0d7...` 为准。本轮相对 3.8.1 的核心变化集中在：

- `common/media/lua/client/VLS_RoofCargoMenu.lua`
- `common/media/lua/shared/VLS_BodyArmor.lua`
- `common/media/lua/shared/VLS_RoofCargoActions.lua`
- `common/media/scripts/VLS_BodyArmorItems.txt`

发布内容包括：

- 车窗护甲 / 前后防撞杆可以使用车辆维修系统进行修理。
- 修理仍使用原版 `FixingManager` 结算，不使用自定义瞬间满修逻辑。
- 修理材料强度关系保持：`固定行李架 > 保险杠 > 窗户护甲`。
- 100% 固定设施仍可拆解；耐久不作为拆解开关。
- 固定行李架如果仍有挂载设备或容器内还有物品，禁止拆解；必须先全部卸下 / 清空。
- 护甲 / 防撞杆 0% 时物品仍占槽位，但外部模型隐藏；修理后模型恢复。
- “拆解”选项保持“拆解”名称。
- 鼠标 / 手柄焦点停在“拆解”上时，条件 tooltip 使用原版车辆维修界面的红绿条件提示风格。
- 现有碰撞吸收行为不改。

不要重新引入已撤回的历史测试补丁：

- `cc825e...` 旧护甲视觉补丁
- `3608ae...` 旧维护实现
- 历史 FIX1 全量覆盖包

如果活动副本中还残留下列旧测试文件，发布前清理：

```text
common/media/lua/shared/VLS_BodyArmorMaintenance.lua
common/media/lua/client/VLS_BodyArmorMaintenanceMenu.lua
common/media/scripts/VLS_BodyArmorFixing.txt
```

---

## 3. 正式版本号改为 3.8.2

### 3.1 VLS_Config.lua

文件：

```text
workshop/Contents/mods/VehicleLivingSlots/common/media/lua/shared/VLS_Config.lua
```

修改：

```lua
VLS.VERSION = "3.8.2"
```

`VLS.BUILD_ID` 不要继续保留旧的 `6ceb908-fix1`。本次建议写成：

```lua
VLS.BUILD_ID = "716b0d7-3.8.2"
```

这样能明确表示：3.8.2 的功能内容来自用户已经测试通过的 `716b0d7`。

### 3.2 README.md

把以下所有 3.8.1 文案更新到 3.8.2：

- 标题：`Vehicle Living Slots 3.8.2 / 房车生活`
- 中文多人版本提示：`版本：3.8.2`
- 英文版本提示：`Version: 3.8.2`

### 3.3 workshop/workshop.txt

保留：

```text
id=3791192579
visibility=private
```

不要改 Item ID，不要新建工坊条目。

把中英文版本提示从 3.8.1 改成 3.8.2：

```text
版本：3.8.2
Version: 3.8.2
```

### 3.4 CHANGELOG.md

在最上方新增：

```markdown
## 3.8.2

3.8.2：完善车窗护甲、前后防撞杆与固定行李架的维修 / 拆解流程；0% 护甲保留槽位但隐藏模型；拆解条件提示与原版车辆维修界面风格对齐，并调整护甲 / 防撞杆维修材料与修复强度。 / Improved repair and dismantle behavior for window armor, bumper guards and fixed roof racks; zero-condition armor remains installed while its model is hidden; dismantle requirements now follow the vanilla vehicle-mechanics tooltip style, with adjusted repair materials and repair strength.
```

不要把未验证的新功能写进 3.8.2。

---

## 4. 生成正式发布提交

版本元数据整理完成后，先检查差异：

```bash
git diff --stat
git diff
```

确认除了：

- 已测试的 `716b0d7` 功能代码
- VERSION / BUILD_ID
- README
- CHANGELOG
- workshop.txt
- 本 AG 交接文档

之外，没有其他无关修改。

创建正式提交，建议提交信息：

```text
Release Vehicle Living Slots 3.8.2
```

记录最终 release commit SHA。后续 HK、NUC、测试服、Workshop **全部必须来自同一个 release commit**。

如果仓库发布习惯有 tag，则创建：

```text
v3.8.2
```

不要为了打 tag 再改源码。

---

## 5. 部署总原则

本次是正式发布，不再使用局部 hotfix 包。**服务器和 Workshop 都使用最终 release commit 的完整 `workshop/` payload。**

不得只复制 4 个修复文件到正式环境后就结束。

所有环境更新前必须先确认当前实际活动副本和 mount；不要根据历史路径盲目覆盖。

更新目标：

1. NUC 测试服
2. NUC 正式服
3. HK 正式服
4. Steam Workshop 现有 Item `3791192579`

---

## 6. NUC 部署

已知 NUC PZ 容器：

```text
正式服：project-zomboid-sp-live
测试服：project-zomboid-vls-ki5-test
```

历史上 VLS 可能同时出现在容器内 `mods` 和 Workshop 副本；写入前必须检查 Docker mount，找出实际 host 路径。

已知候选 host 路径包括：

```text
/home/aiops/private-state/pz-stage-a/data/mods/VehicleLivingSlots
/home/aiops/private-state/pz-stage-a/server/steamapps/workshop/content/108600/3791192579/mods/VehicleLivingSlots
```

容器内历史路径包括：

```text
/home/steam/Zomboid/mods/VehicleLivingSlots
/home/steam/pz-dedicated/steamapps/workshop/content/108600/3791192579/mods/VehicleLivingSlots
```

### NUC 操作要求

1. 检查：

```bash
docker ps -a --format '{{.Names}}'
docker inspect project-zomboid-sp-live
docker inspect project-zomboid-vls-ki5-test
```

2. 找出两服共享 / 独立的 VLS host mount。
3. 写文件前停止所有引用这些路径的 PZ 容器。
4. 用最终 3.8.2 release commit 的完整 Mod 内容更新活动副本。
5. 删除旧测试遗留文件。
6. 先启动测试服 `project-zomboid-vls-ki5-test` 做快速验收。
7. 测试通过后停止测试服，再启动正式服 `project-zomboid-sp-live`。
8. 不要让测试服和正式服同时占用同一正式运行资源。

### NUC 快速验收

至少确认：

- 启动日志无 Lua error。
- `VLS.VERSION == 3.8.2`。
- 老存档车辆原有设备、行李架、护甲仍在。
- 护甲 / 防撞杆 100% 可拆解。
- 损坏护甲 / 防撞杆可以修理。
- 0% 护甲槽位仍存在、模型隐藏。
- 行李架有挂载物 / 有库存时不能拆解；清空后可拆解。
- 手柄和鼠标菜单均正常。

---

## 7. HK 正式服部署

HK 正式服的具体容器名 / host 路径不要猜。

AG 先在 HK 主机上读取现有启动管理脚本、docker compose / systemd / Docker mount，确认：

- 当前正式服容器 / 服务名称
- PZ server install
- VLS 实际活动副本
- Workshop `3791192579` 实际 mount / content 路径

然后：

1. 正常停止 HK 正式服。
2. 用**同一个 3.8.2 release commit**更新完整 VLS Mod。
3. 清理旧测试遗留文件。
4. 确认 KI5 adapter 仍保持当前正式发布内容，不要误删或单独回滚。
5. 启动 HK 正式服。
6. 检查启动日志和 Mod 版本。
7. 不修改存档，不做存档迁移，不重新安装车辆部件。

如果 HK 上检测到多个 VLS 副本但无法唯一判断活动副本，停止并报告，禁止“全部覆盖碰碰运气”。

---

## 8. Steam Workshop 发布

Workshop 必须更新现有 Item：

```text
3791192579
```

不要新建 Item。

使用最终 3.8.2 release commit 中的完整：

```text
workshop/
```

进行上传，包含基础 Mod 及当前仓库内随 Workshop 发布的相关内容。

发布前核对：

```text
workshop/workshop.txt
id=3791192579
版本文案=3.8.2
visibility=private
```

发布后记录 Steam Workshop 上传结果 / 时间 / manifest 或 SteamCMD 输出。

Workshop 上传成功后，再确认 NUC / HK 实际服务器没有被 Steam 自动同步回旧版。

如果服务器使用 Workshop 自动更新，必须再次检查服务器上的：

```text
VLS_Config.lua
VLS.VERSION
VLS.BUILD_ID
```

应分别是：

```text
3.8.2
716b0d7-3.8.2
```

---

## 9. 最终一致性检查

AG 完成后必须给出一份最终执行结果，至少包含：

```text
GitHub main final SHA:
Git tag (if created):
VLS.VERSION:
VLS.BUILD_ID:

NUC test:
- container
- active VLS path
- deployed SHA / file hash
- startup result

NUC formal:
- container
- active VLS path
- deployed SHA / file hash
- startup result

HK formal:
- service/container
- active VLS path
- deployed SHA / file hash
- startup result

Steam Workshop:
- Item ID 3791192579
- upload result
- uploaded version 3.8.2 confirmed
```

最终四处必须是同一发布内容：

```text
GitHub main 3.8.2
= NUC test
= NUC formal
= HK formal
= Workshop 3791192579
```

任何一处不一致都不算完成。

---

## 10. 发布后清理

本 `ag-handoff/` 文档是 AG 协作记录，不属于 Workshop payload。

如果仓库仍遵循 3.8.1 发布时“正式 main 不保留协作导出目录”的规则，那么在 AG 已读取并完成发布后，可在**最后一个文档清理提交**中删除 `ag-handoff/`，但不要因为清理文档而改变 `workshop/` payload。

不要删除 CHANGELOG、README 或正式源码。
