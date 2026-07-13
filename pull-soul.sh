#!/bin/bash
# ============================================================
# 陶野全配置拉取脚本 — 从 GitHub 下载最新配置到本地
# 适用：新设备初始化、手机端修改后桌面同步、恢复备份
# ============================================================

SOURCE_DIR="$HOME/.workbuddy"
REPO_DIR="$HOME/.workbuddy/workbuddy-soul"
OWNER="normankoong-crypto"
REPO="workbuddy-soul"
RAW_BASE="https://raw.githubusercontent.com/$OWNER/$REPO/main"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
UPDATED=false

echo "============================================"
echo "  陶野全配置拉取 (GitHub → 本地) — $TIMESTAMP"
echo "============================================"

# [1] 拉取灵魂文件
echo "[1/3] 拉取灵魂文件..."
SOUL_FILES=("SOUL.md" "IDENTITY.md" "USER.md" "MEMORY.md" "DIALOGUE-LOG.md")

for file in "${SOUL_FILES[@]}"; do
    dest="$SOURCE_DIR/$file"
    remote_content=$(curl -sf "$RAW_BASE/$file" 2>/dev/null || true)

    if [ -z "$remote_content" ]; then
        echo "  [SKIP] $file — 远程不存在"
        continue
    fi

    if [ -f "$dest" ]; then
        local_content=$(cat "$dest" 2>/dev/null || true)
        if [ "$local_content" = "$remote_content" ]; then
            echo "  无变化: $file"
            continue
        fi
    fi

    echo "$remote_content" > "$dest" && echo "  已更新: $file" && UPDATED=true
done

# [2] 拉取 Skills
echo "[2/3] 拉取 Skills..."
mkdir -p "$REPO_DIR" 2>/dev/null
SKILLS_HTTP=$(curl -sI "$RAW_BASE/skills.tar.gz" 2>/dev/null | grep -c "200" || true)
if [ "$SKILLS_HTTP" -gt 0 ]; then
    curl -s "$RAW_BASE/skills.tar.gz" -o "$REPO_DIR/.skills-pull.tar.gz" 2>/dev/null || true

    if [ -d "$SOURCE_DIR/skills" ]; then
        tar -czf "$REPO_DIR/.skills-local.tar.gz" -C "$SOURCE_DIR" skills/ 2>/dev/null || true
        if cmp -s "$REPO_DIR/.skills-pull.tar.gz" "$REPO_DIR/.skills-local.tar.gz" 2>/dev/null; then
            echo "  skills 无变化"
        else
            tar -xzf "$REPO_DIR/.skills-pull.tar.gz" -C "$SOURCE_DIR" 2>/dev/null && echo "  已更新: skills/" && UPDATED=true
        fi
        rm -f "$REPO_DIR/.skills-local.tar.gz" 2>/dev/null
    else
        tar -xzf "$REPO_DIR/.skills-pull.tar.gz" -C "$SOURCE_DIR" 2>/dev/null && echo "  已更新: skills/ (新建)" && UPDATED=true
    fi
    rm -f "$REPO_DIR/.skills-pull.tar.gz" 2>/dev/null
else
    echo "  skills.tar.gz 远程不存在，跳过"
fi

# [3] 拉取每日对话摘要
echo "[3/3] 拉取每日对话摘要..."
DS_HTTP=$(curl -sI "$RAW_BASE/daily-summaries.tar.gz" 2>/dev/null | grep -c "200" || true)
if [ "$DS_HTTP" -gt 0 ]; then
    curl -s "$RAW_BASE/daily-summaries.tar.gz" -o "$REPO_DIR/.ds-pull.tar.gz" 2>/dev/null || true

    if [ -d "$SOURCE_DIR/daily-summaries" ]; then
        tar -czf "$REPO_DIR/.ds-local.tar.gz" -C "$SOURCE_DIR" daily-summaries/ 2>/dev/null || true
        if cmp -s "$REPO_DIR/.ds-pull.tar.gz" "$REPO_DIR/.ds-local.tar.gz" 2>/dev/null; then
            echo "  daily-summaries 无变化"
        else
            tar -xzf "$REPO_DIR/.ds-pull.tar.gz" -C "$SOURCE_DIR" 2>/dev/null && echo "  已更新: daily-summaries/" && UPDATED=true
        fi
        rm -f "$REPO_DIR/.ds-local.tar.gz" 2>/dev/null
    else
        mkdir -p "$SOURCE_DIR/daily-summaries" 2>/dev/null
        tar -xzf "$REPO_DIR/.ds-pull.tar.gz" -C "$SOURCE_DIR" 2>/dev/null && echo "  已更新: daily-summaries/ (新建)" && UPDATED=true
    fi
    rm -f "$REPO_DIR/.ds-pull.tar.gz" 2>/dev/null
else
    echo "  daily-summaries.tar.gz 远程不存在，跳过"
fi

echo "============================================"
if [ "$UPDATED" = true ]; then
    echo "  拉取完成！本地配置已与 GitHub 同步"
else
    echo "  所有配置已是最新"
fi
echo "============================================"
