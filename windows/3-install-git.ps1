# ============================================
# 🦞 Git 安装与配置脚本 (Windows)
# 安装 Git 并配置 GitHub 镜像源（中国用户）
# ============================================

$ErrorActionPreference = "Continue"

# 镜像源列表（注意：hub.fastgit.xyz 已停服，已移除）
$GitMirrors = @{
    "1" = "https://gitclone.com"
    "2" = "https://mirror.ghproxy.com"
    "3" = "https://ghproxy.net"
}

$MirrorNames = @(
    "gitclone.com",
    "mirror.ghproxy.com",
    "ghproxy.net"
)

# 颜色函数
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )

    switch ($Type) {
        "Header" { Write-Host $Message -ForegroundColor Cyan }
        "Step"   { Write-Host "`n▶ $Message" -ForegroundColor Yellow }
        "OK"     { Write-Host "  ✓ $Message" -ForegroundColor Green }
        "Warn"   { Write-Host "  ⚠ $Message" -ForegroundColor Yellow }
        "Error"  { Write-Host "  ✗ $Message" -ForegroundColor Red }
        "Info"   { Write-Host "  ℹ $Message" -ForegroundColor Cyan }
        default  { Write-Host $Message }
    }
}

function Print-Header {
    Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Type Header
    Write-ColorOutput "  🦞 Git 安装与配置脚本 (Windows)" -Type Header
    Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Type Header
    Write-Host ""
}

# 检测代理
function Test-Proxy {
    Write-ColorOutput "检测网络代理" -Type Step

    $proxyFound = $false

    # 检查常见代理端口
    $proxyPorts = @(7890, 1080, 1087, 10809, 10808, 8080, 1086)
    foreach ($port in $proxyPorts) {
        $connection = Test-NetConnection -ComputerName 127.0.0.1 -Port $port -WarningAction SilentlyContinue
        if ($connection.TcpTestSucceeded) {
            Write-ColorOutput "检测到本地代理端口: $port" -Type Info
            $proxyFound = $true
            break
        }
    }

    # 检查环境变量
    if ($env:HTTP_PROXY -or $env:HTTPS_PROXY -or $env:http_proxy -or $env:https_proxy) {
        Write-ColorOutput "检测到代理环境变量" -Type OK
        $proxyFound = $true
    }

    return $proxyFound
}

# 测试 GitHub 连接
function Test-GitHubConnection {
    Write-ColorOutput "测试 GitHub 连接" -Type Step

    try {
        $null = Invoke-WebRequest -Uri "https://github.com" -TimeoutSec 15 -UseBasicParsing
        Write-ColorOutput "可以连接 GitHub" -Type OK
        return $true
    } catch {
        Write-ColorOutput "无法连接 GitHub" -Type Warn
        return $false
    }
}

# 安装 Git
function Install-Git {
    Write-ColorOutput "安装 Git" -Type Step

    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        $version = (git --version 2>$null) -replace 'git version (.*)', '$1'
        Write-ColorOutput "Git 已安装: $version" -Type OK
        return $true
    }

    Write-ColorOutput "Git 未安装，正在安装..." -Type Info

    # 尝试 winget
    $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        Write-ColorOutput "使用 winget 安装 Git..." -Type Info
        try {
            winget install Git.Git --accept-source-agreements --accept-package-agreements
            Write-ColorOutput "Git 安装成功" -Type OK
            return $true
        } catch {
            Write-ColorOutput "winget 安装失败: $_" -Type Warn
        }
    }

    # 尝试 Chocolatey
    $chocoCmd = Get-Command choco -ErrorAction SilentlyContinue
    if ($chocoCmd) {
        Write-ColorOutput "使用 Chocolatey 安装 Git..." -Type Info
        try {
            choco install git -y
            Write-ColorOutput "Git 安装成功" -Type OK
            return $true
        } catch {
            Write-ColorOutput "Chocolatey 安装失败: $_" -Type Warn
        }
    }

    # 手动下载
    Write-ColorOutput "请手动下载安装 Git for Windows:" -Type Info
    Write-ColorOutput "https://git-scm.com/download/win" -Type Info
    return $false
}

# 配置 Git 镜像
function Set-GitMirror {
    param([string]$MirrorUrl)

    Write-ColorOutput "配置 Git 镜像源: $MirrorUrl" -Type Step

    # 配置 URL 重写规则（仅 HTTPS，镜像站通常不支持 SSH）
    git config --global url."$MirrorUrl/github.com/".insteadOf "https://github.com/"

    # 测试配置
    Write-ColorOutput "测试镜像连接..." -Type Info

    try {
        $null = git ls-remote https://github.com 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "镜像配置成功" -Type OK
            return $true
        }
    } catch {}

    Write-ColorOutput "镜像连接失败，请尝试其他镜像源" -Type Warn
    return $false
}

# 清除镜像配置
function Clear-MirrorConfig {
    Write-ColorOutput "清除 Git 镜像配置" -Type Step

    $mirrors = @(
        "https://gitclone.com",
        "https://mirror.ghproxy.com",
        "https://ghproxy.net"
    )

    foreach ($mirror in $mirrors) {
        git config --global --unset url."$mirror/github.com/".insteadOf 2>$null
    }

    Write-ColorOutput "已清除镜像配置" -Type OK
}

# 选择镜像源
function Select-Mirror {
    Write-Host ""
    Write-Host "请选择 GitHub 镜像源：" -ForegroundColor Yellow
    Write-Host ""

    for ($i = 0; $i -lt $MirrorNames.Count; $i++) {
        Write-Host "  $($i+1)) $($MirrorNames[$i])"
    }

    Write-Host "  4) 不使用镜像（我有代理）"
    Write-Host "  5) 清除现有镜像配置"
    Write-Host ""

    $choice = Read-Host "请输入选项 (1-5)"

    switch ($choice) {
        { $_ -in "1", "2", "3" } {
            $mirrorUrl = $GitMirrors[$choice]
            Set-GitMirror -MirrorUrl $mirrorUrl | Out-Null
        }
        "4" {
            Clear-MirrorConfig
            Write-ColorOutput "将使用直连或代理访问 GitHub" -Type OK
        }
        "5" {
            Clear-MirrorConfig
        }
        default {
            Write-ColorOutput "无效选项" -Type Error
            return $false
        }
    }

    return $true
}

# 配置 Git 用户信息
function Set-GitUser {
    Write-ColorOutput "Git 用户配置（可选）" -Type Step

    $currentName = git config --global user.name 2>$null
    $currentEmail = git config --global user.email 2>$null

    if ($currentName -and $currentEmail) {
        Write-ColorOutput "已配置: $currentName <$currentEmail>" -Type OK
        return
    }

    Write-Host ""
    $choice = Read-Host "是否配置 Git 用户信息? (y/n)"

    if ($choice -eq "y" -or $choice -eq "Y") {
        $username = Read-Host "请输入用户名"
        $email = Read-Host "请输入邮箱"

        git config --global user.name "$username"
        git config --global user.email "$email"

        Write-ColorOutput "Git 用户信息配置完成" -Type OK
    } else {
        Write-ColorOutput "跳过用户配置" -Type Info
    }
}

# 主函数
function Main {
    Clear-Host
    Print-Header

    # 询问是否有代理
    Write-Host "你是否拥有 VPN/加速器/代理？" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  如果有，请确保已开启代理，然后继续"
    Write-Host "  如果没有，脚本会帮你配置 GitHub 镜像源"
    Write-Host ""
    Read-Host "按 Enter 继续..."

    # 检测代理
    $hasProxy = Test-Proxy
    if ($hasProxy) {
        Write-ColorOutput "检测到代理，建议直接连接" -Type Info
    } else {
        Write-ColorOutput "未检测到代理" -Type Info
    }

    # 安装 Git
    $gitInstalled = Install-Git
    if (-not $gitInstalled) {
        Write-ColorOutput "Git 安装失败，请手动安装后重试" -Type Error
        exit 1
    }

    # 刷新环境变量
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    # 测试连接
    $canConnect = Test-GitHubConnection
    if ($canConnect) {
        Write-ColorOutput "可以正常访问 GitHub，无需配置镜像" -Type OK
    } else {
        Write-ColorOutput "无法访问 GitHub，需要配置镜像源" -Type Warn
        Select-Mirror | Out-Null
    }

    # 配置用户信息
    Set-GitUser

    Write-Host ""
    Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Type Header
    Write-ColorOutput "  ✅ Git 配置完成" -Type Header
    Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Type Header
    Write-Host ""
    Write-Host "当前 Git 配置:" -ForegroundColor Yellow
    Write-Host ""

    git config --global --list 2>$null | Where-Object { $_ -match "(url\..*\.insteadof|user\.)" }

    Write-Host ""
    Write-Host "下一步: 运行 4-install-openclaw.ps1 安装小龙虾" -ForegroundColor Yellow
    Write-Host "如需更换镜像源，可重新运行此脚本" -ForegroundColor Cyan
    Write-Host ""
}

# 运行
Main
