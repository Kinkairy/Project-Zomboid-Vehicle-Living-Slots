# Cabinet Capacity Fix Validation

## 已执行

- 静态候选契约：5/5 通过。
- Lua 5.4、模拟 Java 对象、候选逻辑：8/8 通过。
- 原始 RC3.8 证据逻辑：8/8 通过。
- `review-tests/testing/run_review_tests.py`：8/8 通过；已兼容 `lua5.4` 与 `lua-5.4` 两种共享库解析名。
- 当前项目 VLS Lua 行为套件：4/4 文件通过。
- 候选源码版本标记：VehicleLivingSlots 与 VehicleLivingSlotsKI5Campers 均为 RC3.8。
- `source-manifest.csv`：8 条源码清单记录通过 CSV 解析。
- `capacity-snapshots.jsonl`：1 条脱敏记录通过 JSONL 解析；该记录明确标记未捕获真实现场。

## 可复现命令

在本目录执行：

```text
python3 candidate_static_verifier.py
python3 candidate_test_runner.py candidate
```

依赖 Lua 5.4 共享库。已验证环境为 Rocky Linux 9.7，root 安装 `lua-libs-5.4.4-4.el9.x86_64`，动态库为 `/lib64/liblua-5.4.so`。

## 尚未验证

- B42.20.4 实际游戏/Kahlua 加载顺序。
- 同一车辆多个柜子的真实显示容量和可转移容量。
- 原生 `hasRoomFor` 拒绝分支是否由该状态触发。
- 测试服重载后首次操作、保存/重连、原版和 KI5 变体。
- 正式服运行状态和 Workshop 运行包。

因此当前状态只能写为 `verified-offline-candidate`，不能写成“正式服已修复”。
