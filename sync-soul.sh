#!/bin/bash
# 陶野全配置双向同步 v7 (python 模式 + 项目记忆)
# 先拉后推，避免多设备冲突
# 同步范围：灵魂文件 + Skills + 项目级记忆（每日日志 + 项目约定）

SOURCE_DIR="$HOME/.workbuddy"
REPO_DIR="$HOME/.workbuddy/workbuddy-soul"
TOKEN_FILE="$SOURCE_DIR/.github-token"
OWNER="normankoong-crypto"
REPO="workbuddy-soul"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
CHANGED=false
PULLED=false

echo "============================================"
echo "  陶野全配置同步 v7 — $TIMESTAMP"
echo "============================================"

# 读取 token
if [ ! -f "$TOKEN_FILE" ]; then
    echo "[WARN] Token 文件不存在: $TOKEN_FILE"
    echo "[WARN] 推送将跳过，仅执行拉取"
    TOKEN=""
else
    TOKEN=$(python3 -c "import os; print(open('$TOKEN_FILE').read().strip())" 2>/dev/null || echo "")
fi

# ============================================
# [0/7] 从 GitHub 拉取最新
# ============================================
echo "[0/7] 从 GitHub 拉取最新版本..."

python3 -c "
import urllib.request, os, sys, shutil, tempfile, tarfile

source_dir = '$SOURCE_DIR'
raw_base = 'https://raw.githubusercontent.com/$OWNER/$REPO/main'
files = ['SOUL.md', 'IDENTITY.md', 'USER.md', 'MEMORY.md']
pulled = False

for f in files:
    try:
        req = urllib.request.Request(raw_base + '/' + f, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=10) as r:
            remote = r.read().decode('utf-8', errors='replace')
        dest = os.path.join(source_dir, f)
        local = ''
        if os.path.exists(dest):
            with open(dest, 'r', encoding='utf-8', errors='replace') as fp:
                local = fp.read()
        if local != remote:
            # 原子写入 + 备份
            tmp_path = dest + '.tmp'
            with open(tmp_path, 'w', encoding='utf-8') as fp:
                fp.write(remote)
            if os.path.exists(dest) and os.path.getsize(dest) > 0:
                shutil.copy2(dest, dest + '.bak')
            os.replace(tmp_path, dest)
            print(f'  已拉取: {f} (.bak 已备份)')
            pulled = True
        else:
            print(f'  无变化: {f}')
    except:
        pass

try:
    req = urllib.request.Request(raw_base + '/skills.tar.gz', headers={'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=15) as r:
        data = r.read()
    if len(data) > 100:
        with tempfile.NamedTemporaryFile(suffix='.tar.gz', delete=False) as tmp:
            tmp.write(data)
            tmp_path = tmp.name
        skills_dir = os.path.join(source_dir, 'skills')
        os.makedirs(skills_dir, exist_ok=True)
        with tarfile.open(tmp_path, 'r:gz') as tf:
            tf.extractall(skills_dir)
        os.unlink(tmp_path)
        print('  已拉取: skills/')
        pulled = True
    else:
        print('  skills 无变化')
except:
    pass

sys.exit(2 if pulled else 0)
" 2>&1
[ $? -eq 2 ] && PULLED=true

# ============================================
# [1/7] 同步灵魂文件
# ============================================
echo "[1/7] 同步灵魂文件到 GitHub..."

if [ -z "$TOKEN" ]; then
    echo "  [SKIP] Token 为空，跳过推送"
else
    python3 - << 'PYEOF'
import urllib.request, json, base64, os, sys

token = open(os.path.expanduser('~/.workbuddy/.github-token')).read().strip()
owner = 'normankoong-crypto'
repo = 'workbuddy-soul'
source_dir = os.path.expanduser('~/.workbuddy')
timestamp = os.popen('date "+%Y-%m-%d %H:%M:%S"').read().strip()
changed = False

files = ['SOUL.md', 'IDENTITY.md', 'USER.md', 'MEMORY.md']

for f in files:
    src = os.path.join(source_dir, f)
    if not os.path.exists(src):
        continue
    with open(src, 'r', encoding='utf-8', errors='replace') as fp:
        local = fp.read()
    try:
        req = urllib.request.Request(
            f'https://raw.githubusercontent.com/{owner}/{repo}/main/{f}',
            headers={'User-Agent': 'Mozilla/5.0'}
        )
        with urllib.request.urlopen(req, timeout=10) as r:
            remote = r.read().decode('utf-8', errors='replace')
    except:
        remote = ''
    if local == remote:
        print(f'  无变化: {f}')
        continue
    sha = ''
    try:
        req2 = urllib.request.Request(
            f'https://api.github.com/repos/{owner}/{repo}/contents/{f}',
            headers={'Authorization': f'token {token}', 'User-Agent': 'Mozilla/5.0'}
        )
        with urllib.request.urlopen(req2, timeout=10) as r:
            meta = json.load(r)
            sha = meta.get('sha', '')
    except:
        pass
    content_b64 = base64.b64encode(local.encode('utf-8')).decode('ascii')
    body = {'message': f'sync: {f} @ {timestamp}', 'content': content_b64}
    if sha:
        body['sha'] = sha
    data = json.dumps(body).encode('utf-8')
    req3 = urllib.request.Request(
        f'https://api.github.com/repos/{owner}/{repo}/contents/{f}',
        data=data,
        headers={
            'Authorization': f'token {token}',
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0'
        },
        method='PUT'
    )
    try:
        with urllib.request.urlopen(req3, timeout=15) as r:
            resp = json.load(r)
            if 'content' in resp:
                print(f'  已上传: {f}')
                changed = True
            else:
                print(f'  [ERROR] 上传失败 ({f})')
    except Exception as e:
        print(f'  [ERROR] 上传失败 ({f}): {e}')

sys.exit(2 if changed else 0)
PYEOF
    [ $? -eq 2 ] && CHANGED=true
fi

# ============================================
# [2/7] 备份 Skills
# ============================================
echo "[2/7] 备份 Skills..."

if [ -z "$TOKEN" ]; then
    echo "  [SKIP] Token 为空"
elif [ -d "$SOURCE_DIR/skills" ]; then
    python3 - << 'PYEOF'
import urllib.request, json, base64, os, sys, tarfile, io

token = open(os.path.expanduser('~/.workbuddy/.github-token')).read().strip()
owner = 'normankoong-crypto'
repo = 'workbuddy-soul'
source_dir = os.path.expanduser('~/.workbuddy')
timestamp = os.popen('date "+%Y-%m-%d %H:%M:%S"').read().strip()

skills_dir = os.path.join(source_dir, 'skills')
if not os.path.isdir(skills_dir):
    print('  skills/ 不存在，跳过')
    sys.exit(0)

buf = io.BytesIO()
with tarfile.open(fileobj=buf, mode='w:gz') as tf:
    tf.add(skills_dir, arcname='skills')
buf.seek(0)
local_b64 = base64.b64encode(buf.read()).decode('ascii')

sha = ''
try:
    req = urllib.request.Request(
        f'https://api.github.com/repos/{owner}/{repo}/contents/skills.tar.gz',
        headers={'Authorization': f'token {token}', 'User-Agent': 'Mozilla/5.0'}
    )
    with urllib.request.urlopen(req, timeout=10) as r:
        meta = json.load(r)
        sha = meta.get('sha', '')
except:
    pass

body = {'message': f'sync: skills @ {timestamp}', 'content': local_b64}
if sha:
    body['sha'] = sha
data = json.dumps(body).encode('utf-8')

req2 = urllib.request.Request(
    f'https://api.github.com/repos/{owner}/{repo}/contents/skills.tar.gz',
    data=data,
    headers={
        'Authorization': f'token {token}',
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0'
    },
    method='PUT'
)
try:
    with urllib.request.urlopen(req2, timeout=30) as r:
        resp = json.load(r)
        if 'content' in resp:
            print('  已上传: skills.tar.gz')
            sys.exit(2)
        else:
            print('  [ERROR] 上传失败')
except Exception as e:
    print(f'  [ERROR] 上传失败: {e}')
PYEOF
    [ $? -eq 2 ] && CHANGED=true
else
    echo "  skills/ 目录不存在，跳过"
fi

# ============================================
# [3/7] 收集项目级记忆
# ============================================
echo "[3/7] 收集项目级记忆..."

python3 - << 'PYEOF'
import os, json, shutil, sys

repo_dir = os.path.expanduser('~/.workbuddy/workbuddy-soul')
pm_dir = os.path.join(repo_dir, 'project-memories')
os.makedirs(pm_dir, exist_ok=True)

# 从 .paths 读取已有项目映射
paths_file = os.path.join(pm_dir, '.paths')
paths = {}
if os.path.exists(paths_file):
    with open(paths_file, 'r') as f:
        paths = json.load(f)

# 扫描 home 目录下所有 .workbuddy/memory/ 目录，找到项目级记忆
home = os.path.expanduser('~')
found = 0
for root, dirs, files in os.walk(home):
    if root.count(os.sep) - home.count(os.sep) > 4:
        dirs.clear()
        continue
    if '.workbuddy' in dirs:
        # 跳过 ~/.workbuddy 自身（那是用户级，不是项目级）
        wb_dir = os.path.join(root, '.workbuddy')
        if wb_dir == os.path.expanduser('~/.workbuddy'):
            continue
        memory_dir = os.path.join(wb_dir, 'memory')
        if os.path.isdir(memory_dir):
            proj_name = os.path.basename(root)
            if proj_name == '' or proj_name == os.path.expanduser('~'):
                proj_name = os.path.basename(os.path.dirname(root)) or 'home'
            # 复制项目记忆到仓库
            dst_dir = os.path.join(pm_dir, proj_name)
            os.makedirs(dst_dir, exist_ok=True)
            for fname in os.listdir(memory_dir):
                if fname.startswith('.'):
                    continue
                src = os.path.join(memory_dir, fname)
                dst = os.path.join(dst_dir, fname)
                if os.path.isfile(src):
                    shutil.copy2(src, dst)
                    found += 1
            # 更新路径映射
            paths[proj_name] = root
    # 跳过 .workbuddy 内部和隐藏目录
    dirs[:] = [d for d in dirs if d != '.workbuddy' and not d.startswith('.')]

# 写入路径映射
with open(paths_file, 'w') as f:
    json.dump(paths, f, indent=2)

if found > 0:
    print(f'  收集完成: {found} 个文件来自 {len(paths)} 个项目')
    for name, p in paths.items():
        print(f'    {name}: {p}')
    sys.exit(2)
else:
    print('  未发现项目记忆文件')
    sys.exit(0)
PYEOF
[ $? -eq 2 ] && CHANGED=true

# ============================================
# [4/7] 上传项目记忆到 GitHub
# ============================================
echo "[4/7] 上传项目记忆到 GitHub..."

if [ -z "$TOKEN" ]; then
    echo "  [SKIP] Token 为空"
elif [ -d "$REPO_DIR/project-memories" ]; then
    python3 - << 'PYEOF'
import urllib.request, json, base64, os, sys, tarfile, io

token = open(os.path.expanduser('~/.workbuddy/.github-token')).read().strip()
owner = 'normankoong-crypto'
repo = 'workbuddy-soul'
repo_dir = os.path.expanduser('~/.workbuddy/workbuddy-soul')
timestamp = os.popen('date "+%Y-%m-%d %H:%M:%S"').read().strip()

pm_dir = os.path.join(repo_dir, 'project-memories')
buf = io.BytesIO()
with tarfile.open(fileobj=buf, mode='w:gz') as tf:
    tf.add(pm_dir, arcname='project-memories')
buf.seek(0)
local_b64 = base64.b64encode(buf.read()).decode('ascii')

sha = ''
try:
    req = urllib.request.Request(
        f'https://api.github.com/repos/{owner}/{repo}/contents/project-memories.tar.gz',
        headers={'Authorization': f'token {token}', 'User-Agent': 'Mozilla/5.0'}
    )
    with urllib.request.urlopen(req, timeout=10) as r:
        meta = json.load(r)
        sha = meta.get('sha', '')
except:
    pass

body = {'message': f'sync: project-memories @ {timestamp}', 'content': local_b64}
if sha:
    body['sha'] = sha
data = json.dumps(body).encode('utf-8')

req2 = urllib.request.Request(
    f'https://api.github.com/repos/{owner}/{repo}/contents/project-memories.tar.gz',
    data=data,
    headers={
        'Authorization': f'token {token}',
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0'
    },
    method='PUT'
)
try:
    with urllib.request.urlopen(req2, timeout=30) as r:
        resp = json.load(r)
        if 'content' in resp:
            print('  已上传: project-memories.tar.gz')
            sys.exit(2)
        else:
            print('  [ERROR] 上传失败')
except Exception as e:
    print(f'  [ERROR] 上传失败: {e}')
PYEOF
    [ $? -eq 2 ] && CHANGED=true
else
    echo "  project-memories/ 为空，跳过"
fi

# ============================================
# [5/7] 生成 MANIFEST.md
# ============================================
echo "[5/7] 生成 MANIFEST.md..."

python3 - << 'PYEOF'
import os, sys, shutil
repo_dir = os.path.join(source_dir, 'workbuddy-soul')
timestamp = os.popen('date "+%Y-%m-%d %H:%M:%S"').read().strip()
owner = 'normankoong-crypto'
repo = 'workbuddy-soul'

manifest = f"""# 陶野全配置恢复包 — MANIFEST.md

将此文件提供给任何 WorkBuddy 会话，AI 助手将恢复陶野的身份、性格和记忆。

> 使用方式：在任意 WorkBuddy 窗口中发送以下指令即可恢复：
> `请读取 https://raw.githubusercontent.com/{owner}/{repo}/main/MANIFEST.md，按照其中定义的身份、性格、语气来回应我`

> 更新时间：{timestamp}

## 仓库包含的配置
- 灵魂文件：SOUL.md、IDENTITY.md、USER.md、MEMORY.md
- Skills 备份：skills.tar.gz（拉取脚本自动解压）
- 项目记忆：project-memories.tar.gz（各项目的每日日志和约定）
- 恢复入口：MANIFEST.md（本文件）
- 同步脚本：pull-soul.sh、sync-soul.sh

---

"""

files = ['IDENTITY.md', 'USER.md', 'SOUL.md', 'MEMORY.md']
for f in files:
    src = os.path.join(source_dir, f)
    if os.path.exists(src):
        with open(src, 'r', encoding='utf-8', errors='replace') as fp:
            manifest += '\n' + fp.read() + '\n'

manifest_path = os.path.join(repo_dir, 'MANIFEST.md')
# 备份旧 MANIFEST，再写入
if os.path.exists(manifest_path) and os.path.getsize(manifest_path) > 0:
    shutil.copy2(manifest_path, manifest_path + '.bak')
with open(manifest_path, 'w', encoding='utf-8') as fp:
    fp.write(manifest)

print('  MANIFEST.md 已生成 (.bak 已备份)')
PYEOF

if [ -n "$TOKEN" ]; then
    python3 - << 'PYEOF'
import urllib.request, json, base64, os, sys

token = open(os.path.expanduser('~/.workbuddy/.github-token')).read().strip()
owner = 'normankoong-crypto'
repo = 'workbuddy-soul'
repo_dir = os.path.expanduser('~/.workbuddy/workbuddy-soul')
timestamp = os.popen('date "+%Y-%m-%d %H:%M:%S"').read().strip()

manifest_path = os.path.join(repo_dir, 'MANIFEST.md')
with open(manifest_path, 'r', encoding='utf-8') as fp:
    content = fp.read()

try:
    req = urllib.request.Request(
        f'https://raw.githubusercontent.com/{owner}/{repo}/main/MANIFEST.md',
        headers={'User-Agent': 'Mozilla/5.0'}
    )
    with urllib.request.urlopen(req, timeout=10) as r:
        remote = r.read().decode('utf-8', errors='replace')
except:
    remote = ''

if content == remote:
    print('  MANIFEST.md 无变化')
    sys.exit(0)

sha = ''
try:
    req2 = urllib.request.Request(
        f'https://api.github.com/repos/{owner}/{repo}/contents/MANIFEST.md',
        headers={'Authorization': f'token {token}', 'User-Agent': 'Mozilla/5.0'}
    )
    with urllib.request.urlopen(req2, timeout=10) as r:
        meta = json.load(r)
        sha = meta.get('sha', '')
except:
    pass

content_b64 = base64.b64encode(content.encode('utf-8')).decode('ascii')
body = {'message': f'sync: MANIFEST.md @ {timestamp}', 'content': content_b64}
if sha:
    body['sha'] = sha
data = json.dumps(body).encode('utf-8')

req3 = urllib.request.Request(
    f'https://api.github.com/repos/{owner}/{repo}/contents/MANIFEST.md',
    data=data,
    headers={
        'Authorization': f'token {token}',
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0'
    },
    method='PUT'
)
try:
    with urllib.request.urlopen(req3, timeout=15) as r:
        resp = json.load(r)
        if 'content' in resp:
            print('  MANIFEST.md 已上传')
            sys.exit(2)
        else:
            print('  [ERROR] MANIFEST.md 上传失败')
except Exception as e:
    print(f'  [ERROR] MANIFEST.md 上传失败: {e}')
PYEOF
    [ $? -eq 2 ] && CHANGED=true
else
    echo "  [SKIP] Token 为空，MANIFEST.md 未上传"
fi

# ============================================
# [6/7] 上传更新后的同步脚本
# ============================================
echo "[6/7] 上传同步脚本..."

if [ -n "$TOKEN" ]; then
    python3 - << 'PYEOF'
import urllib.request, json, base64, os, sys

token = open(os.path.expanduser('~/.workbuddy/.github-token')).read().strip()
owner = 'normankoong-crypto'
repo = 'workbuddy-soul'
repo_dir = os.path.expanduser('~/.workbuddy/workbuddy-soul')
timestamp = os.popen('date "+%Y-%m-%d %H:%M:%S"').read().strip()
changed = False

scripts = ['pull-soul.sh', 'sync-soul.sh']
for s in scripts:
    src = os.path.join(repo_dir, s)
    if not os.path.exists(src):
        continue
    with open(src, 'r', encoding='utf-8', errors='replace') as f:
        local = f.read()
    try:
        req = urllib.request.Request(
            f'https://raw.githubusercontent.com/{owner}/{repo}/main/{s}',
            headers={'User-Agent': 'Mozilla/5.0'}
        )
        with urllib.request.urlopen(req, timeout=10) as r:
            remote = r.read().decode('utf-8', errors='replace')
    except:
        remote = ''
    if local == remote:
        print(f'  无变化: {s}')
        continue
    sha = ''
    try:
        req2 = urllib.request.Request(
            f'https://api.github.com/repos/{owner}/{repo}/contents/{s}',
            headers={'Authorization': f'token {token}', 'User-Agent': 'Mozilla/5.0'}
        )
        with urllib.request.urlopen(req2, timeout=10) as r:
            meta = json.load(r)
            sha = meta.get('sha', '')
    except:
        pass
    content_b64 = base64.b64encode(local.encode('utf-8')).decode('ascii')
    body = {'message': f'sync: {s} @ {timestamp}', 'content': content_b64}
    if sha:
        body['sha'] = sha
    data = json.dumps(body).encode('utf-8')
    req3 = urllib.request.Request(
        f'https://api.github.com/repos/{owner}/{repo}/contents/{s}',
        data=data,
        headers={
            'Authorization': f'token {token}',
            'Content-Type': 'application/json',
            'User-Agent': 'Mozilla/5.0'
        },
        method='PUT'
    )
    try:
        with urllib.request.urlopen(req3, timeout=15) as r:
            resp = json.load(r)
            if 'content' in resp:
                print(f'  已上传: {s}')
                changed = True
    except Exception as e:
        print(f'  [ERROR] {s}: {e}')
sys.exit(2 if changed else 0)
PYEOF
    [ $? -eq 2 ] && CHANGED=true
fi

echo "============================================"
if [ "$CHANGED" = true ] || [ "$PULLED" = true ]; then
    echo "  同步完成！ — $TIMESTAMP"
else
    echo "  无变化 — $TIMESTAMP"
fi
echo "============================================"
