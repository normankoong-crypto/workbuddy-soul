# DIALOGUE-LOG.md — 对话摘要日志

> 跨设备对话同步用。每日自动整理当天重要对话摘要，追加到本文件。
> 新设备/新会话启动时，拉取本文件即可了解近期聊过的内容。

---

## 2026-07-13

- **话题：跨设备对话同步方案**
  - Norman 提出想同步不同设备上的聊天记录摘要
  - 确定方案：方案2（DIALOGUE-LOG.md 文件）+ 方案3（定时自动整理）
  - 已将 DIALOGUE-LOG.md 加入 sync-soul.sh / pull-soul.sh 同步列表
  - 修复了 curl 未检查 HTTP 状态码导致 404 内容覆盖本地文件的 bug（curl -s → curl -sf）
  - 修复了 upload_file 大文件上传 bug（shell 变量传 base64 超长度限制 → python 读写临时文件 + cat 管道）
  - Mac 上创建了两个每小时定时任务：灵魂自动同步 + 对话摘要整理
  - 同步验证通过，零报错
