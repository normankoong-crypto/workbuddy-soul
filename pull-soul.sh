#!/bin/bash
# ============================================================
# 陶野灵魂拉取脚本 — 从 GitHub 下载最新灵魂文件到本地
# 适用于：新设备初始化、手机端修改后桌面同步、恢复备份
# ============================================================

set -e

SOURCE_DIR="$HOME/.workbuddy"
OWNER="normankoong-crypto"
REPO="workbuddy-soul"
RAW_BASE="https://raw.githubusercontent.com/$OWNER/$REPO/main"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
UPDATED=false

echo "============================================"
echo "  陶野灵魂拉取 (GitHub → 本地) — $TIMESTAMP"
echo "============================================"

SOUL_FILES=("SOUL.md" "IDENTITY.md" "USER.md" "MEMORY.md")

for file in "${SOUL_FILES[@]}"; do
    dest="$SOURCE_DIR/$file"
    remote_content=$(curl -s "$RAW_BASE/$file" 2>/dev/null)

    if [ -z "$remote_content" ]; then
        echo "  [SKIP] $file — 远程不存在"
        continue
    fi

    if [ -f "$dest" ]; then
        local_content=$(cat "$dest")
        if [ "$local_content" = "$remote_content" ]; then
            echo "  无变化: $file"
            continue
        fi
    fi

    echo "$remote_content" > "$dest"
    echo "  已更新: $file"
    UPDATED=true
done

echo "============================================"
if [ "$UPDATED" = true ]; then
    echo "  拉取完成！本地文件已与 GitHub 同步"
else
    echo "  所有文件已是最新"
fi
echo "============================================"
