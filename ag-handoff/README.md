# VLS AG Handoff

这是 Vehicle Living Slots（VLS）Mod 与其他 Agent 协作、交接和复核的固定目录。
它位于 `workshop/` 外，协作资料与实际 Mod 载荷分开：实际可加载文件仍在 `workshop/`，本目录只记录任务、证据、评审结论和可复现材料。

## 协作规则

- `tasks/` 放置写给 AG 的定向任务；一个问题一个 Markdown 文件。
- `evidence/<task>/` 放置 AG 执行结果、发现、脱敏现场记录、源码清单、哈希和可复现实验材料。
- `reviews/` 放置负责人对证据的结论、修复要求、验收门槛和下一步决定。
- 所有状态必须明确标为 `task`、`candidate`、`verified-offline`、`deployed-test` 或 `accepted`；离线测试不能写成游戏内验收。
- 其他 Agent 接手前，先读取当前项目 dossier、VLS handoff、任务文件和对应证据，再核对 live Git/source/runtime 状态。
- 未经明确授权，不部署正式服、不重启客户端或服务端、不操作存档、不上传 Workshop、不强制推送。
- 不提交密码、token、cookie、私钥、`.env`、完整存档或未脱敏玩家/车辆标识。
- 每次修复只改任务声明的范围；无关 Mod 和已有脏工作树必须保留。

## 当前任务索引

- [cabinet-capacity](tasks/cabinet-capacity.md)：RC3.8 柜子显示容量 50、实际容量可能为 20 的定向排查任务。

## 当前证据与评审

- [执行报告](evidence/cabinet-capacity/report.md)
- [源码清单](evidence/cabinet-capacity/source-manifest.csv)
- [容量现场记录](evidence/cabinet-capacity/capacity-snapshots.jsonl)
- [复核结论与修复要求](reviews/cabinet-capacity-review.md)
