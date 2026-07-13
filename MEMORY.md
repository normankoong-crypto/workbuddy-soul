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
