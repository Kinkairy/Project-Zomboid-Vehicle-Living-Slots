# VLS 橱柜显示 50、实际约 20：RC3.8 证据复核与最小修复候选

## 结论

**用户怀疑“旧问题在 3.8 中继续存在”，有新的源码证据支持。** 本次不是继续只看公开 3.7，而是检查 AG 带回、标为 `source/server_runtime` 的 RC3.8 文件。

可以确认的代码事实：生活槽仍以 20 为脚本默认容量；下柜 profile 仍为 50；已有 `init` 绑定只调用 `VLS.Damage.Init`，不恢复设备容器 profile。原来的访问检查也没有修正容量，客户端侧栏仍会自行恢复本地 profile。

**尚未确认的现场事实：故障发生那一刻，究竟哪个柜子、服务端实际容量是否为 20、哪一条原生事务检查拒绝。** 本包没有双端快照、容量变化时间线或失败交易。不能把源码路径直接写成已采集的数值。

可以据此准备窄范围的修复候选，重点为“生活槽每次初始化时，在保留损伤初始化的同时，逐零件恢复容量”。不建议直接按 AG 报告只在访问函数里加一行，然后宣布所有场景已经修复。

本次没有连接服务器、没有修改正式服、没有操作正式存档，也没有修改 GitHub 仓库。下面的 8 组测试是 Lua 5.4 隔离函数测试，不是游戏内验收。

## 一、输入和可追溯性

输入包：`VLS_sp-live_Cabinet_Evidence_20260910T065537Z.tar.gz`。

关键文件：

| 文件 | SHA-256 |
|---|---|
| `source/server_runtime/VLS_Config.lua` | `8da2fdd1baabae2a2fc269eb0a0850036927cb4320784549f4f61d1c2cbef4d3` |
| `source/server_runtime/VLS_ComponentDamage.lua` | `4e322c75e297fa3c0d04a573b10c3ef0488be29b296ff8316f68daf04e9a7615` |
| `source/server_runtime/VLS_Client.lua` | `49dfddd135d465752ea4dec5ad9673e05e456df0c73214ef43c421ea0ff37100` |
| `source/server_runtime/VLS_ApplianceServer.lua` | `1e84b318d97d658813796d8456f5505f25350742f33e192e85a48e892a03b651` |

`file_map.csv` 的 `actual_path` 写的是 `/tmp/.../source/server_runtime/...` 取证副本位置，`loaded_hash_status` 仍为 `not_proven`。所以这些文件适合做源码复核，但不能仅凭该 CSV 证明某个运行中进程或 Windows 客户端正在使用完全相同的字节。

`source/client_runtime` 和 `source/engine_excerpts` 都只有未采集说明。尤其不能把服务器副本中名为 `VLS_Client.lua` 的文件当作已经从 Windows 实际载荷取回的客户端文件。

源证据与原文件行号见配套 `VLS_Cabinet_RC38_Source_Evidence.md`，下文 E1—E17 均指该证据索引。

## 二、最重要的新发现：3.8 不是“没有 init”，而是 init 没有恢复容量

### 2.1 脚本绑定

`VLS_VanPatch.txt` 第 197 行为容量 20，第 204—208 行附近：

```text
lua
{
    create = VLS.Create.UniversalSlot,
    init = VLS.Damage.Init,
    update = VLS.Update.UniversalSlot,
}
```

同类绑定在包内共找到 16 处声明：

| 脚本 | 声明位置 |
|---|---|
| `VLS_VanPatch.txt` | 206、488 |
| `VLS_StepVanWaterPatch.txt` | 257、295、333、906、944、982、1066、1104 |
| `VLS_KI5CampersPatch.txt` | 25、92、159、231、303、370 |

这里统计的是模板中的声明次数，不是已经观察到的 16 辆车或 16 个故障柜。参见 E2、E3。

### 2.2 `VLS.Damage.Init` 真正做的事

`VLS_ComponentDamage.lua` 第 47—73 行：

```lua
function D.Init(vehicle)
    if isClient and isClient() then
        return nil
    end
    local state = samples[vehicle]
    if state then
        return state
    end
    -- 其后记录前后车体的耐久和受影响目标的物品 ID
    -- 不调用 ensureUniversalContainerProfile 或 syncUniversalSlot
end
```

该函数用 `samples[vehicle]` 缓存整辆车的损伤基线。它不是“每个柜子各自的容器初始化”，并没有容量修正。参见 E4。

**容易引入的新错误：**直接把某个 `part` 的容量修正塞到 `D.Init` 的 `if state then return state end` 后面。这样同车第一次调用以后，后续生活槽可能都提前返回，出现只修好第一个柜子的情况。

正确方向是让容量恢复在独立的逐零件初始化中执行，不受损伤系统的按车缓存影响。

### 2.3 与 3.7 的直接比较

对证据包中 `github_baseline/VLS_Config.lua` 与 RC3.8 文件按完整命名函数段比较，下列四个函数段完全相同：

- `applyContainerProfile`
- `VLS.ensureUniversalContainerProfile`
- `VLS.syncUniversalSlot`
- `VLS.ContainerAccess.UniversalSlot`

因此，“版本号变成 3.8”没有自动消除这些旧逻辑。`Update.UniversalSlot` 等其他函数确实有变动，不能扩大成整个 Mod 没有变化。

## 三、50/20 分歧为什么仍然是有力假设

本次在 RC3.8 副本确认的路径如下：

1. 生活槽脚本默认 20，下柜 profile 为 50。（E1—E3）
2. `ensureUniversalContainerProfile` 能把当前容器正确设置为 profile 容量；并非设置函数本身不会写 50。（E5、E6）
3. 已有 init 只记录损伤基线，不恢复容量。（E4）
4. 普通生活槽的访问检查不修正容量；武器柜访问检查则有对应修正。（E8）
5. VLS 自建的家电追踪排除只有 storage 的车辆；它的分钟事件不会主动处理未被追踪的车。（E9、E10）
6. 客户端侧栏的 `buttonsAdded` 分支仍会调用 `ensureUniversalContainerProfile`，把本地副本恢复到 50。（E7）

但是，**不能把第 5 点错误地推导成“服务端储物柜绝不会更新”**。`VLS.Update.UniversalSlot` 自身仍会调用恢复函数；原版零件更新与 VLS 自建的家电追踪是两条调用路径。执行原更新函数时，20 可以恢复到 50。（E11）

要确认完整因果链，仍要知道实际引擎何时覆盖容量、当时原版更新是否执行，以及转移校验针对的对象。本包没有本机引擎摘录或这段时间线。

## 四、本次真正执行的 8 组隔离测试

运行条件：容器中的 Lua 5.4 共享库；直接执行包内完整 `VLS_Config.lua`、`VLS_KI5Campers_Config.lua`、`VLS_ComponentDamage.lua`、`VLS_ApplianceServer.lua`，以及客户端侧栏函数的原文摘录。只对 Java 游戏对象、事件容器和界面对象做替身。

**初始容量 20 是人为设置的测试前提，不是捕获的游戏重载结果；双端也是两个独立替身对象，不是联网客户端。** 测试没有执行真实物品转移、读取正式存档或模拟整套原生事务。

| 测试 | 观察到的结果 |
|---|---|
| 1. 两个柜子初始为 20，调用现有 `Damage.Init` | 两者仍为 20；同车复用同一个损伤缓存 |
| 2. 对容量 20 的柜子调用现有访问检查 | 返回允许访问，但容量仍为 20 |
| 3. 执行实际客户端侧栏刷新函数 | 本地替身变为 50；另一独立的服务端替身仍为 20 |
| 4. 只有柜子的车辆进入现有追踪逻辑并执行分钟回调 | 容量仍为 20 |
| 5. 显式调用现有 `Update.UniversalSlot` | 即使物品 ID 和 profile 版本都匹配，仍可恢复到 50；重复调用不重复写容量 |
| 6. 候选逐零件初始化，同车两柜和微波炉 | 分别恢复到 50、50、5；容器、原物品和内容对象身份不变；损伤缓存保留 |
| 7. 人为再次将容量改为 20，执行候选访问兜底 | 合法访问恢复 50；车外不合法访问不修正 |
| 8. KI5 profile 下的橱柜、小柜、冰箱 | 分别按配置为 50、10、20，不被统一设置成 50 |

8/8 测试通过表示上述函数行为被观察到，不表示已经完成游戏稳定性验收。原始输出在附包 `testing/results.txt`。

## 五、建议的最小修复候选

### 5.1 主修复：组合式的生活槽 init

新增一个生活槽专用回调，保留损伤初始化，并在每个零件上恢复容器 profile。

以下是与隔离测试中的候选逻辑对应的实现示意，**不是已经部署或游戏验收通过的补丁**：

```lua
VLS.Init = VLS.Init or {}

function VLS.Init.UniversalSlot(vehicle, part)
    if not vehicle or not part
            or part:getVehicle() ~= vehicle
            or vehicle:getPartById(part:getId()) ~= part
            or not VLS.isUniversalPart(part) then
        return
    end

    -- 保留 3.8 的损伤基线初始化。
    if VLS.Damage and VLS.Damage.Init then
        VLS.Damage.Init(vehicle)
    end

    -- 按零件执行，不受 Damage.Init 的按车辆缓存提前返回影响。
    VLS.ensureUniversalContainerProfile(part)
end
```

生活槽声明改为：

```text
lua
{
    create = VLS.Create.UniversalSlot,
    init = VLS.Init.UniversalSlot,
    update = VLS.Update.UniversalSlot,
}
```

注意：

- 只改确属生活槽的绑定；不要批量替换车顶架、迁移零件或其他用途的 init。
- 保留原 `create`、`update`、安装完成回调和所有稳定 ID。
- 不把 `D.Init` 整个换掉，不让原损伤系统失去基线。
- 不把容量修正放在按车只执行一次的分支后面。
- 核对当前游戏的加载顺序：回调执行时已安装物品、有效脚本和 ItemContainer 必须就绪。如果以后还有原生统计重算覆盖容量，需要在那条实际生命周期上补精确恢复；不能仅凭新增 init 就认为所有重载入口全覆盖。
- 不使用 `Create.UniversalSlot` 代替初始化来粗暴重跑所有家电同步，也不从修容量入口改微波炉计时、液体或食物状态。

### 5.2 辅助兜底：先校验访问身份，再恢复当前 profile

`VLS.ContainerAccess.UniversalSlot` 保留原有资格与位置要求，在许可通过后增加当前容器的精准恢复，例如：

```lua
function VLS.ContainerAccess.UniversalSlot(vehicle, part, character)
    if not part
            or not VLS.isStorageEquipment(part:getInventoryItem()) then
        return false
    end
    if not character or character:getVehicle() ~= vehicle then
        return false
    end
    if not vehicle or part:getVehicle() ~= vehicle
            or vehicle:getPartById(part:getId()) ~= part
            or not VLS.isUniversalPart(part) then
        return false
    end

    VLS.ensureUniversalContainerProfile(part)
    return true
end
```

这个示意对应隔离测试的访问候选行为。AG 实施时必须与实际其他包装器组合，不重复安装，不绕过原权限，不改原生转移结果。

优先用 `ensureUniversalContainerProfile`，不要在每次访问里直接调用完整 `syncUniversalSlot`：后者还会写设备 ID／profile 版本，遇到物品身份变化时重设微波炉状态和容器环境，超出了本次容量恢复的必要范围。（E6）

**访问兜底不是主修复的替代品。** 本包没有原生转移的调用链证明，尚不能保证该访问函数一定先于所有容量检查。AG 报告“加这一行就保证任何转移前恢复”的说法过强。（E14）

### 5.3 暂不做的事

不要把所有脚本默认 20 改成 50；不要把柜子伪装成冰箱；不要禁用 `hasRoomFor`；不要只改 UI；不要每帧遍历世界里的全部车辆；不要更换容器、清物资或回滚存档。

也不建议把所有 storage 无条件塞进家电计时器当作主要修复：这会增加无关遍历，仍不能保证重载后首次转移前就已恢复。若确实需要周期兜底，应与家电耗电处理分开、只追踪需要的已加载对象，并让生命周期恢复承担主要职责。

## 六、AG 报告中必须纠正的证据表述

### 6.1 没采集到的数据不能写成现场值

`report.md` 开头明确说未直接观察到故障，但随后第 23—25 行将客户端容量 50、服务端实际 20 写进表格；第 13 行还直接指定故障 part 为 `SeatBed`。

本包的 `snapshots/README`、`capacity_timeline.jsonl`、`transfer_attempts.jsonl` 都只有 `not_collected` 占位说明。因此这些值和对象必须标记为假设，故障零件不能被锁死为 `SeatBed`；也可能是原版其他生活槽或 KI5 槽。（E12、E13、E16）

### 6.2 不能混淆两套更新调度

`hasManagedAppliance` 不接收 storage，只能证明其自建家电追踪不处理 storage-only 车辆，不能证明 `VLS.Update.UniversalSlot` 没有经原版零件更新执行。后者在本次隔离测试里确实能恢复容量。

### 6.3 现有探针尚不足以配对故障

`probe/minimal_capacity_probe.lua` 未部署，它只输出 part、物品类型、profile 容量、当前容量和计重，缺少车辆 ID、端别、安装物品 ID、有效容量、请求 ID、原始拒绝分支和时间关系，也没有限流。两个车的同名槽会混在一起。

不能仅部署该文件就宣称已收集完整现场证据；还要确认依赖初始化和实际入口加载顺序。此次保持未部署，符合之前的权限边界。（E15）

### 6.4 文件清单小问题

`manifest.sha256` 的 44 个其他条目校验通过。它还列入了自身的哈希，自身条目不匹配；这是清单自引用问题，不能据此说源码损坏。下次生成清单应排除清单自身。

JSONL 占位文件里的 `not_collected: ...` 并非合法 JSON 行。建议使用合法对象，例如 `{"status":"not_collected","reason":"no runtime channel"}`，避免后续程序把占位解析失败误当作日志损坏。

## 七、给 AG 的下一步指令

### 本轮可执行范围：候选源码和离线验证，不自动部署

1. 以本次带回的 RC3.8 副本为对照，定位真实 canonical 工作区和生产加载文件；记录实际原路径，不能再把 `/tmp` 副本当生产加载路径。保留未提交修改。
2. 优先实现第五节的生活槽逐零件 init；保留 `VLS.Damage.Init`。补访问兜底，但不把它当作已验证的所有转移前置点。
3. 提供最小 diff。范围原则上是 `VLS_Config.lua` 和实际生效的三个生活槽脚本，新增状态、网络命令或全局扫描都必须说明必要性。
4. 回归同车多个柜子、其他容量 profile、重复初始化、损伤基线保留、安装物品和内容对象身份不变。不得把同车只测第一个柜子当完成。
5. 将原生容量检查顺序列为待确认项，不编造 engine_excerpts。优先利用已安装游戏中的源码或可用本地分析工具，只把有关函数摘录带回；不上传整个游戏 JAR，不安装外部运行依赖。
6. 交付 `candidate.diff`、修改前后哈希、离线测试源码和原始输出、仍缺少的现场证据。**候选尚未完成真实游戏重载／转移验收时，不写“正式服已修复”。**

### 现场部分的最小目标，不再重新收一大包普通日志

真正仍缺的是一次“同车、同零件、同一次尝试”的端到端记录，而不是更多没有容量字段的启动日志。

只有获得单独授权、且有可行的只读查询或观测入口后，再收：

- 端别、游戏会话与时间、车辆 ID／scriptName、part ID、已安装物品 ID／类型。
- 观测前的 profile.capacity、`getCapacity()`、以真实操作者调用的 `getEffectiveCapacity(character)`、`getCapacityWeight()`、座位占用。
- 选中 UI 容器与转移实际目标的零件关系、外层容器链、待转移物品 ID 与未装备计重。
- 自然操作的请求或事务标识、实际许可／拒绝结果；能定位时记录真正拒绝的源码分支。
- 原有恢复函数被自然调用前后值；记录必须先于恢复，不能取证脚本先调用恢复函数再打印“原值”。

这里不能把 `part:getModData()` 一概当成绝对只读 getter：在某些引擎实现中它会惰性创建表。先核对当前版本；能用 `hasModData()` 检查就先检查，不为了诊断写入新字段。观测只读取已存在对象，避免调用副作用未知的访问测试。

官方 API 能确认容量、有效容量与计重是不同查询，但不能代替本机 B42.20.4 的实现验证：

- https://projectzomboid.com/modding/zombie/inventory/ItemContainer.html
- https://projectzomboid.com/modding/zombie/vehicles/VehiclePart.html

**现有权限没有放开：**只看正式 `sp-live` 的已有证据；不启动未玩的测试档、不重启正式服、不热改运行源码、不拆柜、不清库存、不改角色、不推主分支或发布工坊。没有现成观测能力，就如实保留这一阻塞，先完成候选和离线工作，不循环要求用户重复下载普通日志。

## 八、交付物解释

- 本文：复核结论与 AG 最小修复候选。
- `VLS_Cabinet_RC38_Source_Evidence.md`：包内原文及准确行号。
- 附带测试 ZIP：实际执行的 8 组 Lua 5.4 隔离检查、替身定义、候选逻辑示意、运行结果及最小源码证据副本。无需正式存档或原始大日志。

**一句话：RC3.8 的 init 只管损伤，不管容量；应保留它，再增加每个生活槽的容量恢复。这个修复点有源码和隔离函数测试支持，但不能把它写成已经捕获了正式服 50→20 的全过程。**
