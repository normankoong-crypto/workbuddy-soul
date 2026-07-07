#!/bin/bash
# 陶野全配置拉取脚本 v3 — 包含项目级记忆同步
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

SOUL_FILES=("SOUL.md" "IDENTITY.md" "USER.md" "MEMORY.md")

for file in "${SOUL_FILES[@]}"; do
    dest="$SOURCE_DIR/$file"
    python3 -c "
import urllib.request, os, sys
url = '$RAW_BASE/$file'
dest = '$dest'
try:
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=10) as r:
        content = r.read()
    remote = content.decode('utf-8', errors='replace')
    local = ''
    if os.path.exists(dest):
        with open(dest, 'r', encoding='utf-8', errors='replace') as f:
            local = f.read()
    if local == remote:
        print(f'  无变化: $file')
    else:
        with open(dest, 'w', encoding='utf-8') as f:
            f.write(remote)
        print(f'  已更新: $file')
        sys.exit(2)
except Exception as e:
    print(f'  [SKIP] $file — {e}')
    sys.exit(0)
" 2>&1
    [ $? -eq 2 ] && UPDATED=true
done

echo "[2/4] 拉取 Skills..."
python3 -c "
import urllib.request, os, sys, tempfile, tarfile
url = '$RAW_BASE/skills.tar.gz'
dest_dir = '$SOURCE_DIR'
try:
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=15) as r:
        data = r.read()
    if len(data) < 100:
        print('  skills.tar.gz 远程不存在，跳过')
        sys.exit(0)
    with tempfile.NamedTemporaryFile(suffix='.tar.gz', delete=False) as tmp:
        tmp.write(data)
        tmp_path = tmp.name
    skills_dir = os.path.join(dest_dir, 'skills')
    os.makedirs(skills_dir, exist_ok=True)
    with tarfile.open(tmp_path, 'r:gz') as tf:
        tf.extractall(skills_dir)
    os.unlink(tmp_path)
    print('  已更新: skills/')
    sys.exit(2)
except Exception as e:
    print(f'  [ERROR] skills: {e}')
    sys.exit(0)
" 2>&1
[ $? -eq 2 ] && UPDATED=true

echo "[3/4] 拉取项目记忆..."
python3 -c "
import urllib.request, os, sys, tempfile, tarfile, json

raw_base = '$RAW_BASE'
repo_dir = '$REPO_DIR'

# 尝试下载 project-memories.tar.gz
try:
    req = urllib.request.Request(raw_base + '/project-memories.tar.gz', headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=15) as r:
        data = r.read()
    if len(data) < 50:
        print('  远程无项目记忆，跳过')
        sys.exit(0)
    
    with tempfile.NamedTemporaryFile(suffix='.tar.gz', delete=False) as tmp:
        tmp.write(data)
        tmp_path = tmp.name
    
    pm_dir = os.path.join(repo_dir, 'project-memories')
    os.makedirs(pm_dir, exist_ok=True)
    
    with tarfile.open(tmp_path, 'r:gz') as tf:
        tf.extractall(pm_dir)
    os.unlink(tmp_path)
    
    # 读取路径映射并恢复
    paths_file = os.path.join(pm_dir, '.paths')
    if os.path.exists(paths_file):
        with open(paths_file, 'r') as f:
            paths = json.load(f)
    else:
        print('  无路径映射，跳过恢复')
        sys.exit(2)
    
    restored = 0
    for proj_name, proj_path in paths.items():
        src_dir = os.path.join(pm_dir, proj_name)
        if not os.path.isdir(src_dir):
            continue
        dst_dir = os.path.join(proj_path, '.workbuddy', 'memory')
        os.makedirs(dst_dir, exist_ok=True)
        for fname in os.listdir(src_dir):
            if fname.startswith('.'):
                continue
            src_file = os.path.join(src_dir, fname)
            dst_file = os.path.join(dst_dir, fname)
            with open(src_file, 'r', encoding='utf-8', errors='replace') as sf:
                content = sf.read()
            local = ''
            if os.path.exists(dst_file):
                with open(dst_file, 'r', encoding='utf-8', errors='replace') as df:
                    local = df.read()
            if content != local:
                with open(dst_file, 'w', encoding='utf-8') as df:
                    df.write(content)
                restored += 1
        if restored > 0:
            print(f'  已恢复: {proj_name} ({restored} 个文件)')
    
    sys.exit(2)
except urllib.request.HTTPError as e:
    if e.code == 404:
        print('  远程无项目记忆，跳过')
    else:
        print(f'  [ERROR] {e}')
    sys.exit(0)
except Exception as e:
    print(f'  [ERROR] 项目记忆: {e}')
    sys.exit(0)
" 2>&1
[ $? -eq 2 ] && UPDATED=true

echo "[4/4] 拉取仓库脚本更新..."
python3 -c "
import urllib.request, os, sys

raw_base = '$RAW_BASE'
repo_dir = '$REPO_DIR'

scripts = ['pull-soul.sh', 'sync-soul.sh']
updated = False
for s in scripts:
    try:
        req = urllib.request.Request(raw_base + '/' + s, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=10) as r:
            remote = r.read().decode('utf-8', errors='replace')
        dest = os.path.join(repo_dir, s)
        local = ''
        if os.path.exists(dest):
            with open(dest, 'r', encoding='utf-8', errors='replace') as f:
                local = f.read()
        if local != remote:
            with open(dest, 'w', encoding='utf-8') as f:
                f.write(remote)
            os.chmod(dest, 0o755)
            print(f'  已更新: {s}')
            updated = True
        else:
            print(f'  无变化: {s}')
    except Exception as e:
        print(f'  [SKIP] {s}: {e}')
sys.exit(2 if updated else 0)
" 2>&1
[ $? -eq 2 ] && UPDATED=true

echo "============================================"
if [ "$UPDATED" = true ]; then
    echo "  拉取完成！本地配置已与 GitHub 同步"
else
    echo "  所有配置已是最新"
fi
echo "============================================"
