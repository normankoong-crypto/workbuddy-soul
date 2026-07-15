# 陶野 · 用户级记忆

## 全配置双向同步规则 (GitHub ↔ 本地)

**这是铁律，每次涉及 ~/.workbuddy/ 下任何文件的改动都必须遵守：**

### 工作流：先拉 → 再改 → 后推

1. **改之前**：`bash ~/.workbuddy/workbuddy-soul/pull-soul.sh` — 从 GitHub 拉最新
2. **改完之后**：`bash ~/.workbuddy/workbuddy-soul/sync-soul.sh` — 推回 GitHub
3. **新会话开始时**：跑一次 pull-soul.sh，确保本地是最新的

### 同步范围
- 灵魂文件：SOUL.md、IDENTITY.md、USER.md、MEMORY.md
- Skills 目录：~/.workbuddy/skills/
- 每日对话摘要：~/.workbuddy/daily-summaries/（跨设备对话上下文）
- MANIFEST.md：每次 sync 自动重新生成

### 关键路径
- 仓库位置：~/.workbuddy/workbuddy-soul/
- GitHub Token：~/.workbuddy/.github-token（已写入有效 token，推送正常）
- 同步脚本：~/.workbuddy/workbuddy-soul/sync-soul.sh（推送）/ pull-soul.sh（拉取）
- 脚本不依赖 git，纯 curl + GitHub API

### Token 状态
- ~/.workbuddy/.github-token 已填入 token（2026-07-07）
- 第一个 token 被 GitHub 自动撤销（疑似 Secret Scanning 触发），等待 Norman 提供新 token
- 拉取不受影响（公开仓库）

## 设备清单（别名：私人电脑=个人电脑=mac电脑=苹果电脑；公司电脑=工作电脑=惠普电脑）
- **苹果电脑 / Mac**（当前这台）：陶野的主场，完整部署了灵魂仓库 + 同步脚本
- **惠普电脑**：公司工作电脑，之前已配过灵魂仓库 + token

## Norman 的背景
- 杭州，吉利工作
- 负责印尼和马来市场的电动皮卡国际销售
- 偶尔涉及吉利集团其他乘用车业务

## 每日对话摘要规则
- 路径：~/.workbuddy/daily-summaries/YYYY-MM-DD.md
- 每次聊完重要内容后，追加摘要到当天的文件
- 摘要格式：时间段 + 关键话题 + 重要决定/操作
- 通过 sync-soul.sh / pull-soul.sh 随灵魂文件一起同步到 GitHub
- 目的：让另一台设备上的陶野能快速了解之前聊过什么

## DIALOGUE-LOG.md 设备分块约定（跨设备）
- 文件：~/.workbuddy/DIALOGUE-LOG.md。两台设备各写一个扁平块：`## YYYY-MM-DD · 苹果` 与 `## YYYY-MM-DD · 惠普`，互不影响、不嵌套。
- 铁律：每台设备只写自己的 `· 设备` 块、只读不碰对方块；先 pull 再改再 push。
- 错峰：惠普 17:00，苹果 10:00 + 16:00（整点；16:00 避锁屏18:00、避惠普17:00、且整点最稳）。`BYMINUTE` 分钟级调度被平台解析错误（17:30 算成 16:54），故苹果第二点用整点16:00。
- 苹果自动化 id（2026-07-15 删旧重建）：10:00=`automation-1784123660708`、16:00=`automation-1784123660735`，均 ACTIVE。
- 对话摘要生成机制（pending 缓冲，已验证）：
  - 主对话(陶野)实时把要点追加到 `~/.workbuddy/pending-summary.md` 的 `## 日期 · 苹果` 段（本机只写苹果段）。
  - 自动化：pull → 读 pending 苹果段 → 合并进 DIALOGUE-LOG 的 `## 日期 · 苹果` 块(无则新建) → 清空 pending 该段 → light-sync 推送。
  - **不依赖 conversation_search**（实测搜"当天"返回0条，先天不可用）。
- 自动化改用轻量同步脚本 `light-sync.sh`（实测不被137杀）：
  - 路径 `~/.workbuddy/workbuddy-soul/light-sync.sh`，用法 `bash light-sync.sh pull|push`
  - 仅用 curl/API 拉取 DIALOGUE-LOG.md + MEMORY.md、推送 DIALOGUE-LOG.md；不打包 skills/ds，故不会触发 signal 137
  - 已推仓库 `tools/light-sync.sh` 备份。**替代 sync-soul.sh 用于自动化**（sync-soul.sh 在本会话 Bash 沙箱必被137杀，且原第[0/6]步会覆盖本地改动，已修防覆盖但仍过重）

## sync-soul.sh 重要修复（防覆盖本地改动）
- 旧版 sync-soul.sh 第 [0/6] 步会无条件用远程覆盖本地（当 local≠remote 时），导致「改完再 sync」时本地改动被吞掉、且自动化编辑的内容推不上去
- 已改为非破坏性：第 [0/6] 步仅在本地文件不存在时才拉取；本地已存在且与远程不同则保留本地改动
- 拉取统一由 pull-soul.sh 负责（改之前拉）；sync-soul.sh 只负责推送
- ⚠️ 惠普电脑的 sync-soul.sh 也需应用同样的修复，否则那边改动同样会被吞
