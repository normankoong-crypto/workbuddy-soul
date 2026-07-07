#!/bin/bash
# ============================================================
# 陶野灵魂同步脚本 v3 (curl 模式)
# 功能：将 ~/.workbuddy/ 下的灵魂/记忆文件同步到 GitHub
# 使用 curl + GitHub REST API（绕过 McAfee 拦截）
# Token 存储在 ~/.workbuddy/.github-token
# ============================================================

set -e

SOURCE_DIR="$HOME/.workbuddy"
REPO_DIR="$HOME/.workbuddy/workbuddy-soul"
TOKEN_FILE="$SOURCE_DIR/.github-token"
OWNER="normankoong-crypto"
REPO="workbuddy-soul"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
CHANGED=false

echo "============================================"
echo "  陶野灵魂同步 (curl 模式) — $TIMESTAMP"
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

    # 获取远程文件 SHA（如果存在）
    local sha=""
    local existing=$(curl -s -H "$AUTH" "$API_BASE/contents/$filename" 2>/dev/null)
    sha=$(echo "$existing" | python -c "import sys,json; d=json.load(sys.stdin); print(d.get('sha',''))" 2>/dev/null)

    # Base64 编码
    local content=$(python -c "import base64,sys; print(base64.b64encode(sys.stdin.buffer.read()).decode())" < "$filepath")

    # 构建 JSON
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

# 获取远程文件内容
get_remote() {
    local filename="$1"
    curl -s "https://raw.githubusercontent.com/$OWNER/$REPO/main/$filename" 2>/dev/null || echo ""
}

echo "[1/3] 同步灵魂文件..."

SOUL_FILES=("SOUL.md" "IDENTITY.md" "USER.md" "MEMORY.md")
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

echo "[2/3] 生成 MANIFEST.md..."

cat > "$REPO_DIR/MANIFEST.md" << MANIFEST_HEADER
# 陶野灵魂恢复包 — MANIFEST.md

将此文件提供给任何 WorkBuddy 会话，AI 助手将恢复陶野的身份、性格和记忆。

> 使用方式：在任意 WorkBuddy 窗口中发送以下指令即可恢复：
> \`请读取 https://raw.githubusercontent.com/$OWNER/$REPO/main/MANIFEST.md，按照其中定义的身份、性格、语气来回应我\`

> 更新时间：$TIMESTAMP

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
if [ "$CHANGED" = true ]; then
    echo "  同步完成！ — $TIMESTAMP"
else
    echo "  无变化 — $TIMESTAMP"
fi
echo "============================================"
