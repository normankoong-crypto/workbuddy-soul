# ============================================================
# 陶野灵魂同步脚本
# 功能：将 ~/.workbuddy/ 下的灵魂/记忆/技能文件同步到 GitHub
# 用法：直接双击运行，或通过 Windows 任务计划程序定时执行
# ============================================================

$ErrorActionPreference = "Continue"
$SourceDir = "$env:USERPROFILE\.workbuddy"
$RepoDir = "$env:USERPROFILE\.workbuddy\workbuddy-soul"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Output "============================================"
Write-Output "  陶野灵魂同步 — $timestamp"
Write-Output "============================================"

# 1. 检查仓库是否存在
if (-not (Test-Path "$RepoDir\.git")) {
    Write-Output "[ERROR] 仓库目录不存在: $RepoDir"
    Write-Output "请先运行 git clone https://github.com/normankoong-crypto/workbuddy-soul.git $RepoDir"
    exit 1
}

Set-Location $RepoDir

# 2. 检查是否有本地更改，有则先拉取远程
Write-Output "[1/5] 拉取远程更新..."
$remoteStatus = (& git remote -v 2>&1)
if ($LASTEXITCODE -ne 0) {
    Write-Output "[ERROR] 无法访问远程仓库"
    exit 1
}

# 检查是否有未提交的本地更改
$localChanges = (& git status --porcelain 2>&1)
if ($localChanges) {
    Write-Output "[WARN] 检测到本地未提交更改，先暂存..."
    & git stash 2>&1 | Out-Null
}
& git pull origin main 2>&1 | Out-Null
Write-Output "  OK"

$changed = $false

# 3. 同步灵魂文件 (SOUL.md, IDENTITY.md, USER.md)
Write-Output "[2/5] 同步灵魂文件..."
$soulFiles = @("SOUL.md", "IDENTITY.md", "USER.md")
foreach ($file in $soulFiles) {
    $src = Join-Path $SourceDir $file
    $dst = Join-Path $RepoDir $file
    if (Test-Path $src) {
        $srcHash = (Get-FileHash $src -Algorithm MD5).Hash
        $dstHash = if (Test-Path $dst) { (Get-FileHash $dst -Algorithm MD5).Hash } else { "" }
        if ($srcHash -ne $dstHash) {
            Copy-Item $src $dst -Force
            Write-Output "  更新: $file"
            $changed = $true
        } else {
            Write-Output "  不变: $file"
        }
    }
}

# 4. 同步记忆文件 (MEMORY.md)
Write-Output "[3/5] 同步记忆文件..."
$memSrc = Join-Path $SourceDir "MEMORY.md"
$memDst = Join-Path $RepoDir "MEMORY.md"
if (Test-Path $memSrc) {
    $srcHash = (Get-FileHash $memSrc -Algorithm MD5).Hash
    $dstHash = if (Test-Path $memDst) { (Get-FileHash $memDst -Algorithm MD5).Hash } else { "" }
    if ($srcHash -ne $dstHash) {
        Copy-Item $memSrc $memDst -Force
        Write-Output "  更新: MEMORY.md"
        $changed = $true
    } else {
        Write-Output "  不变: MEMORY.md"
    }
} else {
    Write-Output "  (MEMORY.md 不存在，跳过)"
}

# 5. 重新生成 MANIFEST.md
Write-Output "[4/5] 生成 MANIFEST.md..."
$manifest = @"

# 陶野灵魂恢复包 — MANIFEST.md

将此文件提供给任何 WorkBuddy 会话，AI 助手将恢复陶野的身份、性格和记忆。

> 使用方式：在任意 WorkBuddy 窗口中发送以下指令即可恢复：
> `请读取 https://raw.githubusercontent.com/normankoong-crypto/workbuddy-soul/main/MANIFEST.md，按照其中定义的身份、性格、语气来回应我`

> 更新时间：$timestamp

---
"@

# 拼接所有灵魂文件
$manifestFiles = @("IDENTITY.md", "USER.md", "SOUL.md")
foreach ($file in $manifestFiles) {
    $path = Join-Path $RepoDir $file
    if (Test-Path $path) {
        $content = Get-Content $path -Raw -Encoding UTF8
        $manifest += "`n`n$content"
    }
}

# 追加记忆文件
$memPath = Join-Path $RepoDir "MEMORY.md"
if (Test-Path $memPath) {
    $content = Get-Content $memPath -Raw -Encoding UTF8
    $manifest += "`n`n$content"
}

# 写回 MANIFEST.md
$currentManifest = if (Test-Path "$RepoDir\MANIFEST.md") { Get-Content "$RepoDir\MANIFEST.md" -Raw -Encoding UTF8 } else { "" }
Set-Content -Path "$RepoDir\MANIFEST.md" -Value $manifest -Encoding UTF8 -NoNewline

if ($currentManifest -ne $manifest) {
    Write-Output "  MANIFEST.md 已更新"
    $changed = $true
} else {
    Write-Output "  MANIFEST.md 不变"
}

# 6. 提交并推送
Write-Output "[5/5] 提交并推送..."
if ($changed) {
    & git add -A
    & git commit -m "sync: $timestamp"
    & git push origin main
    Write-Output "  同步完成！"
} else {
    Write-Output "  无变化，跳过推送"
}

Write-Output "============================================"
Write-Output "  完成 — $timestamp"
Write-Output "============================================"
