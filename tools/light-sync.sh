#!/bin/bash
# light-sync.sh — 轻量 GitHub 同步（仅核心文件，无打包，避免 signal 137）
# 用法: light-sync.sh pull | push
set -u
REPO="normankoong-crypto/workbuddy-soul"
TOKEN_FILE="$HOME/.workbuddy/.github-token"
TOKEN="$(cat "$TOKEN_FILE" 2>/dev/null | tr -d '[:space:]')"
RAW="https://raw.githubusercontent.com/$REPO/main"
API="https://api.github.com/repos/$REPO/contents"

b64() { python3 -c "import base64,sys; print(base64.b64encode(open(sys.argv[1],'rb').read()).decode())" "$1"; }

pull_file() {
  local local="$1" remote="$2"
  local tmp="${local}.tmp"
  curl -sf "$RAW/$remote" -o "$tmp" 2>/dev/null || { rm -f "$tmp"; return; }
  if [ -s "$tmp" ]; then
    mv "$tmp" "$local"
    echo "  pulled: $remote (GitHub -> 本地)"
  else
    rm -f "$tmp"
  fi
}

push_file() {
  local local="$1" remote="$2"
  [ -f "$local" ] || { echo "  skip: 本地无 $remote"; return; }
  local content sha body
  content="$(b64 "$local")"
  sha="$(curl -sf -H "Authorization: Bearer $TOKEN" "$API/$remote" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('sha',''))" 2>/dev/null || true)"
  if [ -n "$sha" ]; then
    body="$(python3 -c "import json,sys; print(json.dumps({'message':sys.argv[1],'content':sys.argv[2],'sha':sys.argv[3]}))" "auto-sync: $remote @ $(date +%F\ %T)" "$content" "$sha")"
  else
    body="$(python3 -c "import json,sys; print(json.dumps({'message':sys.argv[1],'content':sys.argv[2]}))" "auto-sync: $remote @ $(date +%F\ %T)" "$content")"
  fi
  if curl -sf -X PUT -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d "$body" "$API/$remote" >/dev/null 2>&1; then
    echo "  pushed: $remote (本地 -> GitHub)"
  else
    echo "  push failed: $remote"
  fi
}

case "${1:-}" in
  pull)
    echo "[light-sync] pull"
    pull_file "$HOME/.workbuddy/DIALOGUE-LOG.md" "DIALOGUE-LOG.md"
    pull_file "$HOME/.workbuddy/MEMORY.md" "MEMORY.md"
    ;;
  push)
    echo "[light-sync] push"
    push_file "$HOME/.workbuddy/DIALOGUE-LOG.md" "DIALOGUE-LOG.md"
    ;;
  *)
    echo "usage: light-sync.sh pull | push"
    exit 1
    ;;
esac
