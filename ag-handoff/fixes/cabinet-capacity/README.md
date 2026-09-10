# 橱柜容量修复：直接应用包

状态：`verified-offline`，不是游戏内验收。修复对象是旧 RC3.8 的“生活槽没有逐零件恢复设备容量”缺口。本目录已有的四个完整修复文件已重新核对；本次增加可直接执行的 `apply.py` 和精确文件清单，不另外编写第二套容量逻辑。

## 修复内容

1. `VLS_Config.lua`：每个生活槽初始化时，保留 `VLS.Damage.Init(vehicle)`，然后对当前零件调用 `VLS.ensureUniversalContainerProfile(part)`。
2. Van、StepVan、KI5 的 16 处生活槽声明改用 `VLS.Init.UniversalSlot`。
3. 合法访问通过角色、车辆和零件身份检查后，再次恢复当前设备 profile，作为补充兜底。

柜子恢复为 50，小柜、冰箱、微波炉保持自己的容量。保持原零件、安装物品、容器及内容，不修复物品耐久，不重置微波炉计时，不添加全图轮询。没有备份、回滚或存档迁移功能。

## 给 AG 的执行指令

**直接使用本包完整文件，不重复开发，不再把已经做好的候选当成待实现任务。**

在项目根目录执行：

```bash
python3 ag-handoff/fixes/cabinet-capacity/apply.py --mods-root workshop/Contents/mods --write
```

Windows 可将 `python3` 改成 `python`。只有基础包、不使用 KI5 的工作副本，追加 `--base-only`。

目标是 `--mods-root` 明确指定的目录；四个文件按 `files/workshop/Contents/mods/` 下的相对路径对应。脚本不搜索服务器、不调用 Docker、SSH、RCON，不重启进程，也不自动发布工坊。对正式运行目录的部署仍沿用用户已给出的实际授权，不由这条源码应用命令暗中执行。

输出解释：

- `UPDATED`：目标是已核对的旧 RC3.8 文件，已写入本包修正版并逐字节复查。
- `ALREADY_FIXED`：文件已具有相同修复，跳过；这不是失败，也不能把再次运行当成新修复。
- `Different source`：目标还有其他改动，全部预检失败，不覆盖。按 `changes.patch` 将同一最小修改合并到新源码，保留无关改动，不把版本字符串相同当成文件相同。

不加 `--write` 只检查，不修改文件。清单按换行归一后的 SHA-256 判断，兼容 Windows CRLF；它不是第二份容量配置表。

**已知 GitHub `bb29431` 的 `workshop/` 已经包含同一修复。** 对该源码运行会显示四项 `ALREADY_FIXED`。本包用于让旧 RC3.8 工作副本实际得到相同修正，不会因为代码放进协作目录就自动改变运行中的正式服。代码若已在正式进程中生效但问题仍然存在，本包不是针对未知第二原因的新补丁，不能声称重复套用会解决。

## 本次实际验证

- 四份完整修复文件的 Git blob 与仓库 `bb29431` 候选一致。
- 真实执行 Lua 5.4 隔离函数检查：12/12 通过；同车多柜、重复初始化、权限拒绝、KI5 多容量和家电状态保留均覆盖。
- `changes.patch` 在旧 RC3.8 文件副本上通过 `git apply --check` 和实际应用，四个输出与完整修复文件一致。
- 应用脚本检查：7/7 通过，包括旧版应用、已修复跳过、混合状态、未知改动零写入拒绝、只检查不写入、CRLF 和基础包单独应用。

以上原始输出在 `lua-results.txt` 和 `application-results.txt`。隔离测试中的游戏对象为替身；没有读取真实柜子容量、执行游戏转移或重启服务器。不要把函数测试写成正式服故障已消除。

## 取证范围说明

本次指定的 `ag-handoff/evidence/cabinet-capacity/runtime-comparison-20260910.md` 经连接读取返回 404，未作为已读依据。没有因此重新向用户索要一整套日志；先交付上述已有源码依据的可应用修复。历史报告仍保留在 evidence 和 validation.md。
