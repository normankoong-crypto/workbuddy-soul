#!/bin/bash
# ============================================================
# 陶野全配置双向同步 v5 (curl 模式)
# 同步范围：灵魂文件 + Skills + 所有 ~/.workbuddy/ 下配置
# 先拉后推，避免多设备冲突
# ============================================================

set -e

SOURCE_DIR="$HOME/.workbuddy"
REPO_DIR="$HOME/.workbuddy/workbuddy-soul"
TOKEN_FILE="$SOURCE_DIR/.github-token"
OWNER="normankoong-crypto"
REPO="workbuddy-soul"
RAW_BASE="https://raw.githubusercontent.com/$OWNER/$REPO/main"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
CHANGED=false
PULLED=false

echo "============================================"
echo "  陶野全配置同步 v5 — $TIMESTAMP"
echo "============================================"

# 读取 token
if [ ! -f "$TOKEN_FILE" ]; then
    echo "[ERROR] Token 文件不存在: $TOKEN_FILE"
    exit 1
fi
TOKEN=$(cat "$TOKEN_FILE" | tr -d '\n\r ')

API_BASE="https://api.github.com/repos/$OWNER/$REPO"
AUTH="Authorization: token $TOKEN"

# 上传文件到 GitHub
upload_file() {
    local filepath="$1"
    local filename="$2"
    local msg="$3"

    local sha=""
    local existing=$(curl -s -H "$AUTH" "$API_BASE/contents/$filename" 2>/dev/null)
    sha=$(echo "$existing" | python -c "import sys,json; d=json.load(sys.stdin); print(d.get('sha',''))" 2>/dev/null)

    local content=$(python -c "import base64,sys; print(base64.b64encode(sys.stdin.buffer.read()).decode())" < "$filepath")

    local body
    if [ -n "$sha" ]; then
        body=$(python -c "import json; print(json.dumps({'message':'$msg','content':'$content','sha':'$sha'}))")
    else
        body=$(python -c "import json; print(json.dumps({'message':'$msg','content':'$content'}))")
    fi

    local result=$(curl -s -X PUT -H "$AUTH" -H "Content-Type: application/json" "$API_BASE/contents/$filename" -d "$body" 2>/dev/null)
    local ok=$(echo "$result" | python -c "import sys,json; d=json.load(sys.stdin); print('OK' if 'content' in d else 'FAIL')" 2>/dev/null)

    if [ "$ok" = "OK" ]; then
        return 0
    else
        local err=$(echo "$result" | python -c "import sys,json; d=json.load(sys.stdin); print(d.get('message','?'))" 2>/dev/null)
        echo "  [ERROR] 上传失败 ($filename): $err"
        return 1
    fi
}

get_remote() {
    local filename="$1"
    curl -s "$RAW_BASE/$filename" 2>/dev/null || echo ""
}

# ============================================
# [0/5] 从 GitHub 拉取最新（防止多设备冲突）
# ============================================
echo "[0/5] 从 GitHub 拉取最新版本..."

SOUL_FILES=("SOUL.md" "IDENTITY.md" "USER.md" "MEMORY.md")
for file in "${SOUL_FILES[@]}"; do
    dest="$SOURCE_DIR/$file"
    remote_content=$(get_remote "$file")

    if [ -z "$remote_content" ]; then
        continue
    fi

    if [ -f "$dest" ]; then
        local_content=$(cat "$dest")
        if [ "$local_content" = "$remote_content" ]; then
            continue
        fi
    fi

    echo "$remote_content" > "$dest"
    echo "  已拉取: $file (GitHub → 本地)"
    PULLED=true
done

# 拉取 skills 包
REMOTE_SKILLS=$(get_remote "skills.tar.gz")
if [ -n "$REMOTE_SKILLS" ] && [ ${#REMOTE_SKILLS} -gt 50 ]; then
    # 下载到临时文件并比对/解压
    curl -s "$RAW_BASE/skills.tar.gz" -o "$REPO_DIR/.skills-remote.tar.gz" 2>/dev/null
    if [ -f "$SOURCE_DIR/skills" ] || [ -d "$SOURCE_DIR/skills" ]; then
        tar -czf "$REPO_DIR/.skills-local.tar.gz" -C "$SOURCE_DIR" skills/ 2>/dev/null
        if ! cmp -s "$REPO_DIR/.skills-remote.tar.gz" "$REPO_DIR/.skills-local.tar.gz" 2>/dev/null; then
            tar -xzf "$REPO_DIR/.skills-remote.tar.gz" -C "$SOURCE_DIR" 2>/dev/null
            echo "  已拉取: skills/ (GitHub → 本地)"
            PULLED=true
        fi
        rm -f "$REPO_DIR/.skills-local.tar.gz"
    else
        tar -xzf "$REPO_DIR/.skills-remote.tar.gz" -C "$SOURCE_DIR" 2>/dev/null
        echo "  已拉取: skills/ (GitHub → 本地，新建)"
        PULLED=true
    fi
    rm -f "$REPO_DIR/.skills-remote.tar.gz"
fi

if [ "$PULLED" = false ]; then
    echo "  本地已是最新"
fi

# ============================================
# [1/5] 同步灵魂文件到 GitHub
# ============================================
echo "[1/5] 同步灵魂文件到 GitHub..."

for file in "${SOUL_FILES[@]}"; do
    src="$SOURCE_DIR/$file"
    if [ -f "$src" ]; then
        local_content=$(cat "$src")
        remote_content=$(get_remote "$file")
        if [ "$local_content" != "$remote_content" ]; then
            upload_file "$src" "$file" "sync: $file @ $TIMESTAMP" && echo "  已上传: $file" && CHANGED=true
        else
            echo "  无变化: $file"
        fi
    fi
done

# ============================================
# [2/5] 备份 Skills 到 GitHub
# ============================================
echo "[2/5] 备份 Skills..."

if [ -d "$SOURCE_DIR/skills" ]; then
    # 打包 skills 目录（排除 dist/ 和 .zip）
    tar -czf "$REPO_DIR/skills.tar.gz" \
        --exclude='dist' \
        --exclude='*.zip' \
        --exclude='__pycache__' \
        --exclude='*.pyc' \
        -C "$SOURCE_DIR" skills/ 2>/dev/null

    local_size=$(stat -c%s "$REPO_DIR/skills.tar.gz" 2>/dev/null || echo 0)

    # 比对远程
    remote_raw=$(get_remote "skills.tar.gz")
    need_upload=false
    if [ -z "$remote_raw" ] || [ ${#remote_raw} -lt 50 ]; then
        need_upload=true
    else
        curl -s "$RAW_BASE/skills.tar.gz" -o "$REPO_DIR/.skills-remote.tar.gz" 2>/dev/null
        if ! cmp -s "$REPO_DIR/skills.tar.gz" "$REPO_DIR/.skills-remote.tar.gz" 2>/dev/null; then
            need_upload=true
        fi
        rm -f "$REPO_DIR/.skills-remote.tar.gz"
    fi

    if [ "$need_upload" = true ]; then
        upload_file "$REPO_DIR/skills.tar.gz" "skills.tar.gz" "sync: skills @ $TIMESTAMP" && echo "  已上传: skills.tar.gz ($local_size bytes)" && CHANGED=true
    else
        echo "  skills 无变化"
    fi
else
    echo "  skills/ 目录不存在，跳过"
fi

# ============================================
# [3/5] 生成 MANIFEST.md
# ============================================
echo "[3/5] 生成 MANIFEST.md..."

cat > "$REPO_DIR/MANIFEST.md" << MANIFEST_HEADER
# 陶野全配置恢复包 — MANIFEST.md

将此文件提供给任何 WorkBuddy 会话，AI 助手将恢复陶野的身份、性格和记忆。

> 使用方式：在任意 WorkBuddy 窗口中发送以下指令即可恢复：
> \`请读取 https://raw.githubusercontent.com/$OWNER/$REPO/main/MANIFEST.md，按照其中定义的身份、性格、语气来回应我\`

> 更新时间：$TIMESTAMP

## 仓库包含的配置
- 灵魂文件：SOUL.md、IDENTITY.md、USER.md、MEMORY.md
- Skills 备份：skills.tar.gz（拉取脚本自动解压）
- 恢复入口：MANIFEST.md（本文件）

---
MANIFEST_HEADER

MANIFEST_SOURCES=("IDENTITY.md" "USER.md" "SOUL.md" "MEMORY.md")
for file in "${MANIFEST_SOURCES[@]}"; do
    src="$SOURCE_DIR/$file"
    if [ -f "$src" ]; then
        echo "" >> "$REPO_DIR/MANIFEST.md"
        cat "$src" >> "$REPO_DIR/MANIFEST.md"
    fi
done

remote_manifest=$(get_remote "MANIFEST.md")
local_manifest=$(cat "$REPO_DIR/MANIFEST.md")
if [ "$local_manifest" != "$remote_manifest" ]; then
    upload_file "$REPO_DIR/MANIFEST.md" "MANIFEST.md" "sync: MANIFEST.md @ $TIMESTAMP" && echo "  MANIFEST.md 已更新" && CHANGED=true
else
    echo "  MANIFEST.md 无变化"
fi

echo "============================================"
if [ "$CHANGED" = true ] || [ "$PULLED" = true ]; then
    echo "  同步完成！ — $TIMESTAMP"
else
    echo "  无变化 — $TIMESTAMP"
fi
echo "============================================"
