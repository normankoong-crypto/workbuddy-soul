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

## Norman 的近期动态 / 兴趣
- 2026-07-23：Norman 表示「要开始投资」，通过播客了解到《柏基投资之道》（The Baillie Gifford Way，李正/韩圣海 著，湛庐文化 2025-11）。对长期成长投资、耐心资本理念感兴趣。
- 解读：Norman 目前是投资新手（起步阶段）。聊投资话题时优先给「先活下来、资产配置、别追涨杀跌」的底层框架，再谈进阶理念；柏基式「押注下一个特斯拉」的打法不适合新手直接照搬。

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

## 简报自动化规则
- 「东南亚汽车市场每日简报」（automation-1782981137699，每天 11:15）按 Norman 定义：**仅工作日（周一~周五）出报，周末（周六、周日）不出**。周一版覆盖上周五~本周一（含整个周末新闻）。
- ⚠️ 勿将周末无简报误判为「缺失/需补」——这是既定设计。2026-07-27 陶野曾误判，已更正。

## Norman 的协作偏好 / 工作习惯
- **极度厌恶做 PPT**：自认 PPT 技术差，遇到「内容多」的 PPT 会因预期痛苦而逃避拖延。
- 应对：涉及 PPT/汇报类任务时，主动提出「我来做设计执行、你定内容」的分包方案；不要只催他做。
- 2026-08-18：Norman 有个重要 PPT 要做，自述逃避中，但表示「具体做的话我自己搞」。
- 2026-08-18 深度背景：当前重要 PPT = **换领导后的第一次汇报**。6月刚入职做市场调研，原招他的领导（人好、负责）已离职，业务面临考验。Norman 内心渴望建功立业但恐惧失败→易逃避；PPT 对他触发「大脑过载」。已约定：未来帮他建立最佳 PPT 工作流/自动化工具（AI PPT 生成、固定母版、Markdown→PPT 等），把"排版"从他身上剥离。

## Norman 的健康/营养（2026-08-18 起）
- recomp 期（控糖控卡），最大诉求=皮肤好+抗氧化；自述很少被晒到。
- 当前补剂：金维他21多维元素片 2片/天（维C仅50mg/天，不足）。
- 建议方案：维C 另补100mg/天（日总计~150mg）；桑葚干20g/400ml泡水当抗氧化饮品（护牙：吸管+漱口）；虾青素胶囊4-6mg/天随餐（脂溶需油脂），因很少吃三文鱼/蟹，虾仁是唯一食物虾青素源。
- 食物向：高维C水果(猕猴桃/草莓/芭乐)+熟番茄(番茄红素)+核桃奇亚(Omega-3)+绿茶。
