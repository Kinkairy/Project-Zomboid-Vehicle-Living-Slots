# RC3.8 手柄安装菜单与既有问题：AG 修复交付

状态：`candidate`；已有离线记录，不是这批功能的游戏内验收。
源码基线：`b436d6cb687804d156e15e178773e18df5733e55`。

## AG 从这里开始

这是上一轮提供的同一批修复，不重新设计功能。交付采用自包含差异包：`baseline/` 保存准确的输入源码，`changes.patch` 保存八个文件的全部修改，`manifest.json` 保存前后校验值。无需访问聊天附件、联网下载或寻找私有源码。

在仓库根目录执行一条命令，展开八个完整修正文件：

```bash
python3 ag-handoff/fixes/rc38-controller-audit-batch/materialize.py
```

Windows 可使用 `python`。需要已有 Python 3 和 Git，不安装任何游戏依赖。

完成后八个完整文件位于本目录的 `files/workshop/Contents/mods/VehicleLivingSlots/common/media/`，保持原相对路径。成功必须输出 `READY 8/8`。脚本只在协作目录生成文件，不修改根目录 `workshop/`、不部署游戏、不联网、不重启进程。

**不要把 `baseline/` 当成修正后的文件安装。它只是差异包的输入。** `files/` 是运行展开命令后生成的，不应把尚未展开的目录说成已存在八份修正版。

## 八个目标文件

以下路径相对 `workshop/Contents/mods/VehicleLivingSlots/common/media/`：

| 路径 | 本批修改 |
|---|---|
| `lua/client/VLS_VehicleMechanicsIcons.lua` | 修正具体物品子菜单的父级，处理手柄确认安装后菜单残留。 |
| `lua/client/VLS_Client.lua` | 异步上车后休息；转水请求编号、回执、15 秒超时释放；微波炉旧窗口身份；食物服务端快照校正。 |
| `lua/server/VLS_ApplianceServer.lua` | 转水回执及短期重复请求去重；微波炉按实际游戏时间结算；设备 ID 校验；食物快照；净水提交顺序。 |
| `lua/shared/VLS_Config.lua` | 微波炉设备更换时清理旧计时基准；注水口同楼层检查。保留已验证有效的橱柜容量初始化。 |
| `lua/shared/VLS_InstallGuard.lua` | 修正电视拆卸失败的随机判断，补不损坏失败反馈。 |
| `lua/shared/Translate/CN/IG_UI.json` | 简体中文转水失败、超时提示。 |
| `lua/shared/Translate/CH/IG_UI.json` | 繁体中文转水失败、超时提示。 |
| `lua/shared/Translate/EN/IG_UI.json` | 英文转水失败、超时提示。 |

本批客户端和服务端通信变更必须配套使用，不能只换客户端。没有改变完全冻结时零老化的既有平衡参数。没有新增外部依赖、全图修复轮询、存档迁移或回滚模块。

## 如何合入源码

1. 先运行上述展开命令，校验八个输出与 manifest 一致。生成的是已确定的候选，不让 AG 按文字另外写一套。
2. 核对实际维护源码或生成模板。目标已等于 `after_sha256` 时跳过，不能重复添加函数/回调；目标等于 `before_sha256` 时可使用本包完整文件或差异补丁。存在其他后续修改时，保留那些修改，只合并本 patch 对应改动，不能把较新文件整体替换成旧基线。
3. 对基线匹配的源码工作区，可从该工作区根目录执行以下命令；`PATCH` 使用本交付目录中 patch 的实际绝对路径：

```bash
PATCH=/absolute/path/to/ag-handoff/fixes/rc38-controller-audit-batch/changes.patch
git apply --check "$PATCH"
git apply "$PATCH"
```

完整文件覆盖与差异补丁二选一，不要各执行一次。出现冲突先检查是否已应用或基线变化，不使用强制覆盖。`materialize.py` 不是部署脚本。

## 最简单的游戏检查

由 AG 先确认批准用于验证的客户端和服务端均加载本批文件，再让用户做正常操作：

- 手柄使用之前残留的家具菜单路径，进入具体物品后确认；菜单应全部关闭，动作正常开始，焦点可继续操作。再测 B 取消与鼠标操作。
- 从车外选择床位“休息”，走到车旁并进入后应开始休息，不用二次点击。
- 至少一端为车载水箱或已安装饮水桶，转少量水；正常结束后可继续操作，水量相符，不无限锁住。超时先核对水量，不连续重发。
- 微波炉到时停止、中途停止各一次；设置和设备状态正常。精确耗电由 AG 用原始数值测试，不靠整数百分比目测。
- 原有橱柜累计计重超过 20 但未满时仍可继续放物品；关开物品栏、下次正常重连不退步。冰箱食物不出现明显跳变。

电视随机分支、迟到/重复转水回执、精确耗电、旧设备窗口、跨楼层、食物快照及净水拒绝路径由 AG 定点检查，不让用户反复拆装碰概率。不能用两只随身瓶之间的原版转水作为本批车载转水验收。

## 证据与边界

`evidence/prior-offline-results.txt` 保留上一轮 32/32 行为用例的原始输出，使用游戏对象替身，不是真实手柄或联机验收。该轮完整测试 harness 不在本交付内；不能假装运行本目录的一条命令就重跑了 32 项。

本次交付复查记录见 `evidence/packaging-results.txt` 与 `evidence/materialize-results.txt`：5 个 Lua 语法检查、3 个 JSON 检查、差异实际应用、八个输出字节比对，以及全量展开和重复展开均实际完成；本次没有重新运行那 32 项行为用例。没有启动游戏或连接正式服。

本次写入仅涉及协作目录，没有合并到根目录运行源码、重启或发布工坊。AG 应把实际应用 diff、客户端/服务端验证状态和发现的问题写到 `ag-handoff/evidence/rc38-controller-audit-batch/`；不得把橱柜已获用户确认扩大为这一整批都已验收。部署、重启和工坊发布仍按用户明确授权执行。
