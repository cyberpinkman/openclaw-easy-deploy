# ============================================
# 🦞 小龙虾环境自检脚本 (Windows)
# 检测电脑配置和已安装软件
# ============================================

$ErrorActionPreference = "Continue"

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
    Write-ColorOutput "  🦞 小龙虾环境自检 (Windows)" -Type Header
    Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Type Header
    Write-Host ""
}

# 检测系统信息
function Check-System {
    Write-ColorOutput "系统信息" -Type Step

    # Windows 版本
    $osInfo = Get-CimInstance Win32_OperatingSystem
    Write-ColorOutput "Windows 版本: $($osInfo.Caption) $($osInfo.Version)" -Type Info

    # 系统架构
    $arch = $env:PROCESSOR_ARCHITECTURE
    Write-ColorOutput "系统架构: $arch" -Type Info

    # PowerShell 版本
    $psVersion = $PSVersionTable.PSVersion.ToString()
    Write-ColorOutput "PowerShell 版本: $psVersion" -Type Info
}

# 检测硬件配置
function Check-Hardware {
    Write-ColorOutput "硬件配置" -Type Step

    # 内存
    $totalMem = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
    $memGB = [math]::Round($totalMem / 1GB, 2)

    Write-ColorOutput "内存: ${memGB}GB" -Type Info

    if ($memGB -lt 4) {
        Write-ColorOutput "内存过低 (低于 4GB)，建议更换设备" -Type Error
        return $false
    } elseif ($memGB -lt 8) {
        Write-ColorOutput "内存较低 (4-8GB)，可以运行但可能卡顿" -Type Warn
    } else {
        Write-ColorOutput "内存充足 (8GB+)" -Type OK
    }

    # 硬盘空间
    $freeSpace = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace
    $freeGB = [math]::Round($freeSpace / 1GB, 2)

    Write-ColorOutput "C盘可用空间: ${freeGB}GB" -Type Info

    if ($freeGB -lt 2) {
        Write-ColorOutput "硬盘空间不足，当前只有 ${freeGB}GB，最低需要 2GB" -Type Error
        Write-ColorOutput "建议先清理下载文件夹、回收站或不需要的大文件" -Type Info
        Write-ColorOutput "清理后再运行安装脚本，推荐保留 5GB+ 可用空间" -Type Info
        return $false
    } elseif ($freeGB -lt 5) {
        Write-ColorOutput "硬盘空间较少 (2-5GB)，建议清理" -Type Warn
    } else {
        Write-ColorOutput "硬盘空间充足 (5GB+)" -Type OK
    }

    return $true
}

# 检测 Node.js
function Check-Node {
    Write-ColorOutput "Node.js" -Type Step

    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue

    if ($nodeCmd) {
        $nodeVersion = (node -v 2>$null)
        $majorVersion = [int]($nodeVersion -replace 'v(\d+).*', '$1')

        Write-ColorOutput "已安装: $nodeVersion" -Type Info

        if ($majorVersion -ge 24) {
            Write-ColorOutput "版本满足推荐要求 (24+)" -Type OK
        } elseif ($majorVersion -ge 22) {
            Write-ColorOutput "版本满足最低要求 (22+)" -Type OK
        } else {
            Write-ColorOutput "版本过低 (低于 22)，需要升级" -Type Warn
            Write-ColorOutput "请运行 2-install-node.ps1 安装新版本" -Type Info
            return $false
        }

        # 检查 npm
        $npmVersion = (npm -v 2>$null)
        Write-ColorOutput "npm 版本: $npmVersion" -Type Info

        return $true
    } else {
        Write-ColorOutput "未安装 Node.js" -Type Warn
        Write-ColorOutput "请运行 2-install-node.ps1 进行安装" -Type Info
        return $false
    }
}

# 检测 Git
function Check-Git {
    Write-ColorOutput "Git" -Type Step

    $gitCmd = Get-Command git -ErrorAction SilentlyContinue

    if ($gitCmd) {
        $gitVersion = (git --version 2>$null) -replace 'git version (.*)', '$1'
        Write-ColorOutput "已安装: $gitVersion" -Type Info
        Write-ColorOutput "Git 已就绪" -Type OK

        # 检测是否能连接 GitHub
        Write-ColorOutput "检测 GitHub 连接..." -Type Info

        try {
            $null = Invoke-WebRequest -Uri "https://github.com" -TimeoutSec 10 -UseBasicParsing
            Write-ColorOutput "可以连接 GitHub" -Type OK
        } catch {
            Write-ColorOutput "无法连接 GitHub，可能需要配置镜像或使用代理" -Type Warn
            Write-ColorOutput "请运行 3-install-git.ps1 配置镜像" -Type Info
        }

        return $true
    } else {
        Write-ColorOutput "未安装 Git" -Type Warn
        Write-ColorOutput "请运行 3-install-git.ps1 进行安装" -Type Info
        return $false
    }
}

# 检测 OpenClaw
function Check-OpenClaw {
    Write-ColorOutput "小龙虾 (OpenClaw)" -Type Step

    $ocCmd = Get-Command openclaw -ErrorAction SilentlyContinue

    if ($ocCmd) {
        $ocVersion = (openclaw --version 2>$null)
        Write-ColorOutput "已安装: $ocVersion" -Type Info
        Write-ColorOutput "小龙虾已安装" -Type OK

        # 检测网关状态
        Write-ColorOutput "检测网关状态..." -Type Info

        try {
            $null = Invoke-WebRequest -Uri "http://127.0.0.1:18789/health" -TimeoutSec 5 -UseBasicParsing
            Write-ColorOutput "网关运行正常" -Type OK
        } catch {
            Write-ColorOutput "网关未运行" -Type Warn
            Write-ColorOutput "如需启动网关，请运行: openclaw gateway" -Type Info
            Write-ColorOutput "或运行 5-diagnose.ps1 进行诊断修复" -Type Info
        }

        return $true
    } else {
        Write-ColorOutput "未安装小龙虾" -Type Warn
        Write-ColorOutput "请先完成 Node.js 和 Git 的安装" -Type Info
        Write-ColorOutput "然后运行 4-install-openclaw.ps1 进行安装" -Type Info
        return $false
    }
}

# 生成建议
function Generate-Recommendation {
    Write-ColorOutput "📋 检测结果与建议" -Type Step

    Write-Host ""
    Write-Host "根据检测结果，建议按以下顺序执行脚本：" -ForegroundColor Green
    Write-Host ""

    # 检查是否需要安装 Node.js
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if (-not $nodeCmd) {
        Write-Host "  1️⃣  运行 2-install-node.ps1 安装 Node.js"
    } else {
        $nodeVersion = (node -v 2>$null)
        $majorVersion = [int]($nodeVersion -replace 'v(\d+).*', '$1')
        if ($majorVersion -lt 22) {
            Write-Host "  1️⃣  运行 2-install-node.ps1 升级 Node.js"
        } else {
            Write-Host "  ✅ Node.js 已就绪，跳过步骤 2"
        }
    }

    # 检查是否需要安装/配置 Git
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCmd) {
        Write-Host "  2️⃣  运行 3-install-git.ps1 安装 Git"
    } else {
        try {
            $null = Invoke-WebRequest -Uri "https://github.com" -TimeoutSec 10 -UseBasicParsing
            Write-Host "  ✅ Git 已就绪，跳过步骤 3"
        } catch {
            Write-Host "  2️⃣  运行 3-install-git.ps1 配置镜像源"
        }
    }

    # 检查是否需要安装小龙虾
    $ocCmd = Get-Command openclaw -ErrorAction SilentlyContinue
    if (-not $ocCmd) {
        Write-Host "  3️⃣  运行 4-install-openclaw.ps1 安装小龙虾"
    } else {
        Write-Host "  ✅ 小龙虾已安装"
        Write-Host "  💡 如遇问题，运行 5-diagnose.ps1 进行诊断"
    }

    Write-Host ""
    Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Type Header
}

# 主函数
function Main {
    Clear-Host
    Print-Header

    Check-System
    Check-Hardware | Out-Null
    Check-Node | Out-Null
    Check-Git | Out-Null
    Check-OpenClaw | Out-Null

    Generate-Recommendation
}

# 运行
Main
