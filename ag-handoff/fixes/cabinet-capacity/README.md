# Cabinet Capacity Fix Bundle

状态：`verified-offline-candidate`。这是给其他 Agent 复核、应用和继续验收的修复包，不代表正式服或游戏内已经验收。

注意：公开仓库 `Kinkairy/Project-Zomboid-Vehicle-Living-Slots` 的本次 RC3.8 发布会包含该候选源码。这个 fixes 包保留的是“RC3.8 修复前源码 -> 修复后源码”的独立应用材料，用于其他 Agent 从旧的 RC3.8 源码、恢复副本或新工作树继续处理；对当前公开仓库 `main` 重复应用前必须先做版本和 patch 检查。

## 根因

RC3.8 的生活槽脚本默认容量仍可为 20，而安装设备的容器 profile 可能是 50。现有 `VLS.Damage.Init(vehicle)` 按车辆缓存，首次初始化后可能直接返回；它不能保证同一车辆的每个生活槽零件都恢复自己的容器 profile。原访问函数也只做资格判断，未在合法访问后补偿 profile。

## 修改说明

与原源码相比，本包包含 4 个完整差异文件：

- 新增逐零件 `VLS.Init.UniversalSlot(vehicle, part)`，保留既有损伤初始化，再恢复该零件的 universal container profile。
- 将 16 个生活槽 `init` 绑定改为 `VLS.Init.UniversalSlot`。
- 在既有权限、角色、车辆、零件身份检查之后增加窄范围容量恢复。
- 不替换容器、不关闭 `hasRoomFor`、不把全部默认容量改成 50、不扫描所有车辆、不加入存档迁移。

## 适用基线

- 适用源码：Vehicle Living Slots RC3.8，Build 42.20.2+。
- 公开仓库：`Kinkairy/Project-Zomboid-Vehicle-Living-Slots`；发布提交以 `main` 的实际 Git 记录为准。
- 原始候选 patch SHA-256：`4212c6360c8d6b14ba089d87ff53621428697f766ce10e67c79cf8b7a87d32ae`。
- 本修复包不携带私有回滚路径或未公开的原始归档；回滚时应使用维护者保存的 RC3.8 基线，并重新核对其哈希。

不要把本包直接套到 GitHub RC3.7 或更早源码；先核对 `mod.info`、文件哈希和 Git 基线。

## 应用方法

1. 在独立工作树中确认目标是 RC3.8 修复前源码，并备份当前源文件或保留可恢复提交。
2. 从公开仓库根目录先运行 `git apply --check ag-handoff/fixes/cabinet-capacity/changes.patch`，再执行同一路径的 `git apply`；如果 patch 已应用、目标不是本包列出的 4 个文件，或版本不是 RC3.8，停止并重新核对版本。
3. 运行 `validation.md` 中的静态和 Lua 隔离测试，并将结果回写到对应 `ag-handoff/evidence/` 任务目录。
4. 仅在获得新的部署/重启授权后同步测试环境；不要把隔离测试结果写成游戏内或正式服验收。

修正后的完整文件位于 `files/workshop/Contents/mods/...`，可将 `files/workshop/Contents/mods/` 下的内容按原相对路径复制到项目的 `workshop/Contents/mods/`；它们是修复包载荷，不是当前线上运行目录。
