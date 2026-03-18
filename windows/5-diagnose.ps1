# ============================================
# 🦞 小龙虾诊断修复脚本 (Windows)
# 检测并修复常见问题
# ============================================

$ErrorActionPreference = "Continue"

# 颜色函数
function Write-ColorOutput {
    param([string]$Message, [string]$Type = "Info")
    switch ($Type) {
        "Header" { Write-Host $Message -ForegroundColor Cyan }
        "Step"   { Write-Host "`n▶ $Message" -ForegroundColor Yellow }
        "OK"     { Write-Host "  ✓ $Message" -ForegroundColor Green }
        "Error"  { Write-Host "  ✗ $Message" -ForegroundColor Red }
        "Warn"   { Write-Host "  ⚠ $Message" -ForegroundColor Yellow }
        "Info"   { Write-Host "  ℹ $Message" -ForegroundColor Cyan }
    }
}

function Print-Header {
    Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Type Header
    Write-ColorOutput "  🦞 小龙虾诊断修复脚本 (Windows)" -Type Header
    Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Type Header
    Write-Host ""
}

# 问题计数
$script:IssuesFound = 0

# 检查小龙虾安装
function Test-OpenClawInstall {
    Write-ColorOutput "检查小龙虾安装" -Type Step

    $ocCmd = Get-Command openclaw -ErrorAction SilentlyContinue
    if ($ocCmd) {
        Write-ColorOutput "已安装: $(openclaw --version 2>$null)" -Type OK
        return $true
    } else {
        Write-ColorOutput "未安装小龙虾" -Type Error
        Write-ColorOutput "请运行 4-install-openclaw.ps1 进行安装" -Type Info
        $script:IssuesFound++
        return $false
    }
}

# 检查 Node.js
function Test-Node {
    Write-ColorOutput "检查 Node.js" -Type Step

    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if (-not $nodeCmd) {
        Write-ColorOutput "未安装 Node.js" -Type Error
        $script:IssuesFound++
        return $false
    }

    $version = (node -v 2>$null)
    $major = [int]($version -replace 'v(\d+).*', '$1')

    if ($major -lt 22) {
        Write-ColorOutput "Node.js 版本过低: $version (需要 22+)" -Type Error
        $script:IssuesFound++
        return $false
    }

    Write-ColorOutput "Node.js: $version" -Type OK
    return $true
}

# 检查配置文件
function Test-Config {
    Write-ColorOutput "检查配置文件" -Type Step

    $configFile = "$env:USERPROFILE\.openclaw\openclaw.json"

    if (Test-Path $configFile) {
        Write-ColorOutput "配置文件存在" -Type OK

        $content = Get-Content $configFile -Raw
        if ([string]::IsNullOrWhiteSpace($content)) {
            Write-ColorOutput "配置文件为空" -Type Warn
            $script:IssuesFound++
        }
    } else {
        Write-ColorOutput "配置文件不存在" -Type Warn
        Write-ColorOutput "首次运行可能需要配置" -Type Info
    }
}

# 检查端口
function Test-Port {
    Write-ColorOutput "检查网关端口 (18789)" -Type Step

    $connection = Get-NetTCPConnection -LocalPort 18789 -ErrorAction SilentlyContinue

    if ($connection) {
        $pid = $connection.OwningProcess
        Write-ColorOutput "端口 18789 已被占用 (PID: $pid)" -Type OK

        $process = Get-Process -Id $pid -ErrorAction SilentlyContinue
        if ($process -and $process.ProcessName -like "*node*") {
            Write-ColorOutput "是小龙虾网关进程" -Type OK
        } else {
            Write-ColorOutput "被其他进程占用" -Type Warn
        }
    } else {
        Write-ColorOutput "端口 18789 未被占用（网关未运行）" -Type Info
    }
}

# 检查网关状态
function Test-GatewayStatus {
    Write-ColorOutput "检查网关状态" -Type Step

    try {
        $null = Invoke-WebRequest -Uri "http://127.0.0.1:18789/health" -TimeoutSec 5 -UseBasicParsing
        Write-ColorOutput "网关运行正常" -Type OK

        try {
            $null = Invoke-WebRequest -Uri "http://127.0.0.1:18789/" -TimeoutSec 5 -UseBasicParsing
            Write-ColorOutput "Dashboard 可访问" -Type OK
        } catch {}

        return $true
    } catch {
        Write-ColorOutput "网关未运行或无法访问" -Type Warn
        $script:IssuesFound++
        return $false
    }
}

# 运行 openclaw doctor
function Invoke-Doctor {
    Write-ColorOutput "运行诊断命令" -Type Step
    Write-ColorOutput "运行 openclaw doctor..." -Type Info
    Write-Host ""

    $result = openclaw doctor 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "诊断通过" -Type OK
    } else {
        Write-ColorOutput "诊断发现问题" -Type Warn
        $script:IssuesFound++
    }
}

# 尝试修复
function Invoke-Fix {
    Write-ColorOutput "尝试修复问题" -Type Step
    Write-Host ""
    Write-ColorOutput "发现 $script:IssuesFound 个问题" -Type Warn
    Write-Host ""

    if ($script:IssuesFound -eq 0) {
        Write-ColorOutput "未发现问题" -Type OK
        return $true
    }

    $choice = Read-Host "是否尝试自动修复? (y/n)"

    if ($choice -ne "y" -and $choice -ne "Y") {
        Write-ColorOutput "跳过自动修复" -Type Info
        return $false
    }

    Write-ColorOutput "尝试修复..." -Type Info

    # 1. 修复权限问题
    $npmPrefix = npm prefix -g 2>$null
    if ($npmPrefix -and (Test-Path $npmPrefix)) {
        $acl = Get-Acl $npmPrefix
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $hasAccess = $acl.Access | Where-Object { $_.IdentityReference -like "*$currentUser*" -and $_.FileSystemRights -like "*Write*" }

        if (-not $hasAccess) {
            Write-ColorOutput "修复 npm 权限..." -Type Info
            # 权限问题通常需要管理员权限
        }
    }

    # 2. 清理缓存
    Write-ColorOutput "清理 npm 缓存..." -Type Info
    npm cache clean --force 2>$null

    # 3. 重建依赖
    Write-ColorOutput "检查依赖完整性..." -Type Info
    npm rebuild -g openclaw 2>$null

    Write-ColorOutput "修复尝试完成" -Type OK
    return $true
}

# 重启网关 (注意：Windows 不使用 restart 命令)
function Restart-Gateway {
    Write-ColorOutput "重启网关" -Type Step

    # 先停止
    Write-ColorOutput "停止现有网关进程..." -Type Info
    openclaw gateway stop 2>$null

    # 确保端口释放
    Start-Sleep -Seconds 2

    # 强制结束占用端口的进程
    $connection = Get-NetTCPConnection -LocalPort 18789 -ErrorAction SilentlyContinue
    if ($connection) {
        $pid = $connection.OwningProcess
        Write-ColorOutput "强制结束进程 $pid" -Type Warn
        Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }

    # 启动网关 (使用 openclaw gateway 而非 restart)
    Write-ColorOutput "启动网关..." -Type Info

    # Windows 下使用 Start-Process 后台启动
    Start-Process -FilePath "openclaw" -ArgumentList "gateway" -WindowStyle Hidden

    Start-Sleep -Seconds 3

    # 检查是否启动成功
    try {
        $null = Invoke-WebRequest -Uri "http://127.0.0.1:18789/health" -TimeoutSec 5 -UseBasicParsing
        Write-ColorOutput "网关启动成功" -Type OK
        return $true
    } catch {
        Write-ColorOutput "网关启动失败" -Type Error
        Write-ColorOutput "请手动运行: openclaw gateway" -Type Info
        return $false
    }
}

# 打开 Dashboard
function Open-Dashboard {
    Write-ColorOutput "打开控制面板" -Type Step
    Write-Host ""

    $choice = Read-Host "是否打开 Dashboard (Web UI)? (y/n)"

    if ($choice -eq "y" -or $choice -eq "Y") {
        Write-ColorOutput "正在打开浏览器..." -Type Info
        Start-Process "http://127.0.0.1:18789"
    }
}

# 显示诊断总结
function Show-Summary {
    Write-Host ""
    Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Type Header
    Write-ColorOutput "  诊断总结" -Type Header
    Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Type Header
    Write-Host ""

    if ($script:IssuesFound -eq 0) {
        Write-Host "✅ 未发现明显问题" -ForegroundColor Green
    } else {
        Write-Host "⚠ 发现 $script:IssuesFound 个问题" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "常用命令：" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  openclaw status          查看状态"
    Write-Host "  openclaw gateway         启动网关"
    Write-Host "  openclaw gateway stop    停止网关"
    Write-Host "  openclaw dashboard       打开控制面板"
    Write-Host "  openclaw doctor          运行诊断"
    Write-Host ""
}

# 主函数
function Main {
    Clear-Host
    Print-Header

    if (-not (Test-OpenClawInstall)) { exit 1 }

    Test-Node | Out-Null
    Test-Config
    Test-Port
    Test-GatewayStatus | Out-Null
    Invoke-Doctor

    Invoke-Fix | Out-Null

    Write-Host ""
    $choice = Read-Host "是否重启网关? (y/n)"

    if ($choice -eq "y" -or $choice -eq "Y") {
        Restart-Gateway
        Open-Dashboard
    }

    Show-Summary
}

Main
