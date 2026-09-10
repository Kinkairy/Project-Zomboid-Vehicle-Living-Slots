# Cabinet Capacity AG 执行报告

状态：`verified-offline-candidate`。已完成 RC3.8 源码复核和隔离测试；没有游戏内、正式服或真实存档验收。

## 结果

| 修改前 | 修改后 |
|---|---|
| 16 处生活槽脚本绑定使用 `init = VLS.Damage.Init`；该初始化按车辆缓存，不能保证同车多个生活槽逐零件恢复容器 profile；合法访问只做资格判断。 | 新增 `VLS.Init.UniversalSlot(vehicle, part)`，先保留既有损伤初始化，再按零件恢复设备容器 profile；16 处生活槽绑定改用该回调；合法访问在身份和权限检查之后增加窄范围 profile 恢复。 |

候选改动限定为 4 个源码文件：

- `VLS_Config.lua`
- `VLS_VanPatch.txt`
- `VLS_StepVanWaterPatch.txt`
- `VLS_KI5CampersPatch.txt`

候选 diff SHA-256：`4212c6360c8d6b14ba089d87ff53621428697f766ce10e67c79cf8b7a87d32ae`。

## 验证

- 静态候选检查：5/5 通过。
- Lua 5.4 模拟 Java 对象候选检查：8/8 通过。
- 原始 RC3.8 证据检查：8/8 通过。
- 当前项目 VLS Lua 行为套件：4/4 文件通过。
- 测试环境：Rocky Linux 9.7，root 安装 `lua-libs-5.4.4-4.el9.x86_64`；未修改游戏运行环境。
- 公开仓库 RC3.8 发布记录以本次公开仓库 `main` 的提交历史为准；本报告不引用私有聚合仓库提交。

## 证据边界

没有捕获真实 50/20 现场快照、服务端实际容量值、失败转移事务分支或重载后的首次操作。因此不能写成“正式服已修复”。仍需在 B42.20.4 测试环境中验证显示容量、实际转移容量、保存/重连、原版与 KI5 变体，以及安装/拆卸回归。

## 安全边界

本次未部署正式服、未重启服务器或客户端、未操作存档、未运行时热修改、未上传 Workshop。
