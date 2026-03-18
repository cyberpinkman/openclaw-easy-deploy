# ============================================
# 🦞 小龙虾安装脚本 (Windows)
# 安装 OpenClaw Agent
# ============================================

$ErrorActionPreference = "Continue"

# npm 源列表
$NpmRegistries = @{
    "1" = "https://registry.npmmirror.com"
    "2" = "https://mirrors.cloud.tencent.com/npm/"
    "3" = "https://repo.huaweicloud.com/repository/npm/"
    "4" = "https://registry.npmjs.org"
}

$NpmNames = @(
    "淘宝源 (npmmirror.com) - 推荐",
    "腾讯源",
    "华为源",
    "官方源 (需要代理)"
)

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
    Write-ColorOutput "  🦞 小龙虾安装脚本 (Windows)" -Type Header
    Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Type Header
    Write-Host ""
}

# 检查前置条件
function Test-Prerequisites {
    Write-ColorOutput "检查前置条件" -Type Step

    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if (-not $nodeCmd) {
        Write-ColorOutput "未安装 Node.js" -Type Error
        Write-ColorOutput "请先运行 2-install-node.ps1 安装 Node.js" -Type Info
        exit 1
    }

    $version = (node -v 2>$null)
    $major = [int]($version -replace 'v(\d+).*', '$1')

    if ($major -lt 22) {
        Write-ColorOutput "Node.js 版本过低 ($version)" -Type Error
        Write-ColorOutput "需要 Node.js 22.16 或更高版本" -Type Info
        exit 1
    }

    Write-ColorOutput "Node.js: $version" -Type OK

    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
    if (-not $npmCmd) {
        Write-ColorOutput "未找到 npm" -Type Error
        exit 1
    }

    Write-ColorOutput "npm: $(npm -v)" -Type OK

    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        Write-ColorOutput "Git: $(git --version 2>$null)" -Type OK
    } else {
        Write-ColorOutput "未安装 Git，建议运行 3-install-git.ps1" -Type Warn
    }
}

# 选择 npm 源
function Select-NpmRegistry {
    Write-ColorOutput "选择 npm 源" -Type Step

    $current = npm config get registry
    Write-ColorOutput "当前源: $current" -Type Info
    Write-Host ""
    Write-Host "请选择 npm 源：" -ForegroundColor Yellow
    Write-Host ""

    for ($i = 0; $i -lt $NpmNames.Count; $i++) {
        Write-Host "  $($i+1)) $($NpmNames[$i])"
    }
    Write-Host "  5) 保持当前设置"
    Write-Host ""

    $choice = Read-Host "请输入选项 (1-5)"

    switch ($choice) {
        { $_ -in "1", "2", "3", "4" } {
            npm config set registry $NpmRegistries[$choice]
            Write-ColorOutput "已切换到: $($NpmRegistries[$choice])" -Type OK
        }
        "5" {
            Write-ColorOutput "保持当前源: $current" -Type OK
        }
        default {
            Write-ColorOutput "无效选项，使用当前源" -Type Warn
        }
    }
}

# 检查现有安装
function Test-ExistingInstall {
    $ocCmd = Get-Command openclaw -ErrorAction SilentlyContinue
    if ($ocCmd) {
        Write-ColorOutput "检测到已安装的小龙虾" -Type Step
        Write-ColorOutput "当前版本: $(openclaw --version 2>$null)" -Type Info
        Write-Host ""
        $choice = Read-Host "是否重新安装/更新? (y/n)"

        if ($choice -ne "y" -and $choice -ne "Y") {
            Write-ColorOutput "跳过安装" -Type Info
            return $false
        }

        Write-ColorOutput "卸载旧版本..." -Type Info
        npm uninstall -g openclaw 2>$null
    }
    return $true
}

# 安装小龙虾
function Install-OpenClaw {
    Write-ColorOutput "安装小龙虾" -Type Step
    Write-ColorOutput "正在安装，请耐心等待..." -Type Info
    Write-Host ""

    $env:SHARP_IGNORE_GLOBAL_LIBVIPS = "1"

    $result = npm install -g openclaw@latest 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "安装成功" -Type OK
        return $true
    } else {
        Write-ColorOutput "安装失败" -Type Error
        Write-ColorOutput "可能的原因：" -Type Info
        Write-ColorOutput "1. 网络问题 - 尝试更换 npm 源后重试" -Type Info
        Write-ColorOutput "2. 权限问题 - 以管理员身份运行 PowerShell" -Type Info
        Write-ColorOutput "3. Node 版本问题 - 确保使用 Node.js 22+" -Type Info
        return $false
    }
}

# 验证安装
function Test-Installation {
    Write-ColorOutput "验证安装" -Type Step

    # 刷新环境变量
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    $ocCmd = Get-Command openclaw -ErrorAction SilentlyContinue
    if ($ocCmd) {
        Write-ColorOutput "小龙虾已安装: $(openclaw --version 2>$null)" -Type OK
        return $true
    } else {
        Write-ColorOutput "openclaw 命令未找到" -Type Error
        Write-ColorOutput "可能需要重启 PowerShell 或手动添加 PATH" -Type Info
        $npmPrefix = npm prefix -g
        Write-ColorOutput "npm 全局目录: $npmPrefix" -Type Info
        return $false
    }
}

# 运行 onboarding
function Start-Onboarding {
    Write-ColorOutput "启动配置向导" -Type Step
    Write-Host ""
    Write-Host "现在可以启动小龙虾的配置向导了" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "配置向导会帮助你："
    Write-Host "  • 设置 AI 模型提供商（需要 API Key）"
    Write-Host "  • 配置消息通道（WhatsApp、Telegram 等）"
    Write-Host "  • 安装后台服务"
    Write-Host ""

    $choice = Read-Host "是否启动配置向导? (y/n)"

    if ($choice -eq "y" -or $choice -eq "Y") {
        Write-ColorOutput "启动配置向导..." -Type Info
        Write-Host ""
        openclaw onboard --install-daemon
    } else {
        Write-ColorOutput "跳过配置向导" -Type Info
        Write-ColorOutput "稍后可以运行 'openclaw onboard' 进行配置" -Type Info
    }
}

# 显示下一步
function Show-NextSteps {
    Write-Host ""
    Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Type Header
    Write-ColorOutput "  ✅ 小龙虾安装完成" -Type Header
    Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Type Header
    Write-Host ""
    Write-Host "常用命令：" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  openclaw --help      查看帮助"
    Write-Host "  openclaw status      查看状态"
    Write-Host "  openclaw gateway     启动网关"
    Write-Host "  openclaw dashboard   打开控制面板"
    Write-Host "  openclaw doctor      诊断问题"
    Write-Host ""
    Write-Host "下一步：" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1. 运行 'openclaw gateway' 启动网关"
    Write-Host "  2. 打开浏览器访问 http://127.0.0.1:18789"
    Write-Host ""
    Write-Host "如遇问题，运行 5-diagnose.ps1 进行诊断修复" -ForegroundColor Cyan
    Write-Host ""
}

# 主函数
function Main {
    Clear-Host
    Print-Header

    Test-Prerequisites
    Select-NpmRegistry

    if (-not (Test-ExistingInstall)) { exit 0 }

    if (-not (Install-OpenClaw)) { exit 1 }
    if (-not (Test-Installation)) { exit 1 }

    Start-Onboarding
    Show-NextSteps
}

Main
