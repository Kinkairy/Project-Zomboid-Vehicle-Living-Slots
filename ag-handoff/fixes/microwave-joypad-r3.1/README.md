# R3.1：微波炉窗口手柄 A 键修正

状态：`verified-offline`。此项还没有实体手柄或游戏内验收。
适用对象：此前交付的 R3 严格新版。本次只改 VLS_Client.lua 的一个客户端按键函数；服务器和通信协议不变，不恢复旧版兼容。

## 根因

R3 把 onVLSMicrowaveJoypadDown 全部交给 ISPanelJoypad.onJoypadDown。原版父级先检查当前聚焦控件：温度/计时旋钮会先接收 A，然后返回，所以界面虽然显示 A 开启，却没有调用开启按钮。焦点在关闭按钮上时还可能点到关闭。

本补丁让 A 直接调用 ui.ok:forceClick() 一次，B 直接调用 ui.close:forceClick() 一次，随后 return。其他按键继续交给父级，方向键处理不变。forceClick 保留按钮启用/可见检查，不绕过缺电和身份校验。B 关闭的是面板，不是主动停止设备。

## AG 直接执行

在已经整合 R3 的源码工作区根目录执行：

```bash
python3 ag-handoff/fixes/microwave-joypad-r3.1/apply.py --repo . --write
```

Windows 使用 python。只修改这个路径：

```text
workshop/Contents/mods/VehicleLivingSlots/common/media/lua/client/VLS_Client.lua
```

脚本只替换唯一匹配的旧函数，保留其他源码；同时在本协作目录 files/workshop/.../VLS_Client.lua 生成完整修正版。不加 --write 只生成，不修改根目录源码。已应用时输出 ALREADY_FIXED。目标不是 R3 或函数已有其他修改时，拒绝覆盖；对照 changes.patch 合并这一处，不要覆盖用户后续修改。

本目录的完整文件由 apply.py 从本地 R3 源码生成，不要把尚未生成的 files/ 目录当成已有载荷。聊天下载包 VLS_Microwave_Joypad_R31_Fix_AG.zip 已包含准确 R3 基线的完整修正文件和可重跑测试。补丁和完整覆盖二选一，不重复执行。

## 使用方法

前提是客户端、服务器已经统一使用 R3 严格新版。本次只需要更新客户端的这一处 UI 代码，服务器代码无新增修改；如部署统一 Mod 包可按既有发布流程同步同一源码包。客户端完全退出游戏再启动、重新打开微波炉窗口，不拆装设备、不清档。若尚未完成 R3 两端更新，本补丁不能替代那个更新。

只在已获授权的范围部署或重启；此次协作目录提交不部署正式服，不更新工坊。不要增加回滚、迁移或兼容旧命令功能。合入源码时保留灌水、橱柜容量、设备身份、维修选择等所有 R3 既有修正。

## 最小验收

电量正常、微波炉确已安装时：焦点分别停在温度、计时旋钮上按 A，均应只执行一次开关；状态同步后再次按 A 应停止，不同一按键先开后关。按 B 关闭面板一次，方向键调节和鼠标操作仍正常。禁用的开关不应被 A 绕过。

AG 交回实际文件指纹、采用路径和是否完成以上游戏内操作。不把离线通过写成游戏内通过。

## 本轮证据

21/21 定点 Lua 检查通过，包含原 R3 在两个旋钮焦点下不触发开启的复现；6/6 应用/差异补丁检查通过；完整客户端通过语法解析。游戏对象为替身，没有启动游戏或操作实体手柄。上一轮 R3 测试的父级替身省略了旋钮优先分支，这是当时漏测的原因；本轮使用实际读取的原版父级按键方法摘录。

原版来源：Project-Zomboid-Community-Modding/ProjectZomboid-Vanilla-Lua，提交 8a906692ac56f9d40c078d654eea6c70491cbc62，client/ISUI/ISPanelJoypad.lua:onJoypadDown、client/ISUI/ISButton.lua:forceClick、client/ISUI/Fireplace/ISMicrowaveUI.lua:onGainJoypadFocus。

准确 R3 输入 SHA-256：6c883eff8a0f2bb3f45e9f0934aee9251ff4a411592952d70bc6e06bd5e22eea

本次完整输出 SHA-256：1cf523243245fd889f07b7596cf80db2c5b0dd1bded75324294e157234901986
