# ============================================
# 🦞 小龙虾一键安装脚本 (Windows)
# 用户只需要运行这一条命令即可完成所有安装
# ============================================

$ErrorActionPreference = "Continue"

# ========== PowerShell 版本检测 ==========
$PSMinVersion = [version]"5.1"
$PSCurrentVersion = $PSVersionTable.PSVersion
$PSRecommendVersion = [version]"7.0"

if ($PSCurrentVersion -lt $PSMinVersion) {
    Write-Host ""
    Write-Host "  [ERROR] PowerShell 版本过低: $PSCurrentVersion" -ForegroundColor Red
    Write-Host "  最低要求: $PSMinVersion" -ForegroundColor Red
    Write-Host ""
    Write-Host "  请升级 PowerShell 后重试" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "按 Enter 键退出"
    return
}

if ($PSCurrentVersion -lt $PSRecommendVersion) {
    Write-Host ""
    Write-Host "  [!] 检测到 PowerShell $PSCurrentVersion" -ForegroundColor Yellow
    Write-Host "  [i] 推荐升级到 PowerShell 7+ 以获得更好的中文支持" -ForegroundColor Cyan
    Write-Host ""

    $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        $choice = Read-YesNoChoice -Prompt "  是否自动升级 PowerShell 7?" -Default $false
        if ($choice) {
            Write-Host "  [i] 正在安装 PowerShell 7..." -ForegroundColor Cyan
            try {
                winget install Microsoft.PowerShell --accept-source-agreements --accept-package-agreements
                Write-Host "  [OK] PowerShell 7 安装成功" -ForegroundColor Green
                Write-Host "  [i] 已安装 pwsh，后续重新运行脚本时可获得更好的中文显示" -ForegroundColor Yellow
                Write-Host "  [i] 当前安装流程将继续在这个 PowerShell 窗口中执行" -ForegroundColor Cyan
                Write-Host ""
                Read-Host "  按 Enter 键继续安装"
            } catch {
                Write-Host "  [!] 自动升级失败: $_" -ForegroundColor Yellow
                Write-Host "  [i] 将继续使用当前版本" -ForegroundColor Cyan
            }
        }
    }
    Write-Host ""
}

# 设置控制台编码为 UTF-8（解决中文乱码）
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
try { [Console]::InputEncoding = [System.Text.Encoding]::UTF8 } catch {}
try { $null = cmd /c "chcp 65001 >nul 2>&1" } catch {}


# 脚本版本
$ScriptVersion = "1.0.0"

# Node.js 目标版本
$NodeVersion = "24.14.0"

# 镜像源列表
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

# npm 源列表
$NpmRegistries = @{
    "1" = "https://registry.npmmirror.com"
    "2" = "https://mirrors.cloud.tencent.com/npm/"
    "3" = "https://registry.npmjs.org"
}

$NpmNames = @(
    "淘宝源 (推荐)",
    "腾讯源",
    "官方源 (需要代理)"
)

# 状态追踪
$script:NeedNode = $false
$script:NeedGitMirror = $false
$script:NeedOpenClaw = $false

# 颜色函数
function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                                           ║" -ForegroundColor Cyan
    Write-Host "  ║    🦞 小龙虾 OpenClaw 一键安装脚本        ║" -ForegroundColor Cyan
    Write-Host "  ║                                           ║" -ForegroundColor Cyan
    Write-Host "  ╚═══════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
    Write-Host "  $Message" -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
}

function Write-Substep {
    param([string]$Message)
    Write-Host ""
    Write-Host "▶ $Message" -ForegroundColor Cyan
}

function Write-OK {
    param([string]$Message)
    Write-Host "  ✓ $Message" -ForegroundColor Green
}

function Write-Err {
    param([string]$Message)
    Write-Host "  ✗ $Message" -ForegroundColor Red
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  ⚠ $Message" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Message)
    Write-Host "  ℹ $Message" -ForegroundColor Cyan
}

function Write-SuccessBox {
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║                                           ║" -ForegroundColor Green
    Write-Host "  ║           ✅ 安装完成！                   ║" -ForegroundColor Green
    Write-Host "  ║                                           ║" -ForegroundColor Green
    Write-Host "  ╚═══════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
}

# 读取数字选项（带验证和重试）
function Read-NumberChoice {
    param(
        [string]$Prompt,
        [int]$Min,
        [int]$Max,
        [int]$Default = $Min
    )

    $maxAttempts = 5
    $attempt = 1

    while ($attempt -le $maxAttempts) {
        # 直接使用 Read-Host，不通过子 shell
        $choice = Read-Host $Prompt

        # 空输入，使用默认值
        if ([string]::IsNullOrWhiteSpace($choice)) {
            Write-Info "使用默认选项: $Default"
            return $Default
        }

        # 去除空白字符
        $choice = $choice.Trim()

        # 验证是否为数字
        if ($choice -match '^\d+$') {
            $num = [int]$choice
            # 验证范围
            if ($num -ge $Min -and $num -le $Max) {
                return $num
            } else {
                Write-Warn "请输入 $Min 到 $Max 之间的数字 (当前: $num)"
            }
        } else {
            Write-Warn "请输入数字，而不是: '$choice'"
        }

        $attempt++
    }

    # 超过重试次数，使用默认值并继续
    Write-Warn "已达到最大尝试次数，使用默认选项: $Default"
    return $Default
}

function Write-FailBox {
    param([string]$Reason)
    Write-Host ""
    Write-Host "  ╔═══════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "  ║                                           ║" -ForegroundColor Red
    Write-Host "  ║           ❌ 安装失败                     ║" -ForegroundColor Red
    Write-Host "  ║                                           ║" -ForegroundColor Red
    Write-Host "  ╚═══════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "  失败原因: $Reason" -ForegroundColor Red
    Write-Host ""
}

function Show-DiskSpaceHelp {
    param([double]$FreeGB)

    Write-Host ""
    Write-Host "  磁盘空间不足，暂时无法继续安装。" -ForegroundColor Red
    Write-Host "  当前 C 盘可用空间: ${FreeGB}GB" -ForegroundColor Yellow
    Write-Host "  最低要求: 2GB，可用空间建议 5GB 以上" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  建议先做以下任一操作：" -ForegroundColor Cyan
    Write-Host "  1. 清理下载文件夹和回收站"
    Write-Host "  2. 删除不需要的大文件或旧安装包"
    Write-Host "  3. 运行 Windows 磁盘清理"
    Write-Host "  4. 清理后重新运行安装脚本"
    Write-Host ""
}

function Wait-Continue {
    param([string]$Message = "按 Enter 继续...")
    Write-Host ""
    Read-Host $Message | Out-Null
}

function Clear-PendingConsoleInput {
    try {
        while ([Console]::KeyAvailable) {
            [void][Console]::ReadKey($true)
        }
    } catch {
        # 某些宿主环境不支持 KeyAvailable，忽略即可
    }
}

function Read-YesNoChoice {
    param(
        [string]$Prompt,
        [bool]$Default = $true,
        [int]$MaxAttempts = 5
    )

    $defaultHint = if ($Default) { "Y/n" } else { "y/N" }
    $defaultText = if ($Default) { "y" } else { "n" }

    Start-Sleep -Milliseconds 150
    Clear-PendingConsoleInput

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $choice = Read-Host "$Prompt [$defaultHint]"

        if ([string]::IsNullOrWhiteSpace($choice)) {
            Write-Info "未输入，使用默认选项: $defaultText"
            return $Default
        }

        $normalized = $choice.Trim().ToLowerInvariant()
        if ($normalized -in @("y", "yes")) {
            return $true
        }
        if ($normalized -in @("n", "no")) {
            return $false
        }

        Write-Warn "请输入 y 或 n（当前输入: '$choice'）"
    }

    Write-Warn "已达到最大尝试次数，使用默认选项: $defaultText"
    return $Default
}

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# 检测系统环境
function Test-Environment {
    Write-Step "📋 第 1 步：检测系统环境"

    # Windows 版本
    $osInfo = Get-CimInstance Win32_OperatingSystem
    $osVersion = [Environment]::OSVersion.Version
    $osMajor = $osVersion.Major
    $osMinor = $osVersion.Minor
    
    Write-Info "Windows: $($osInfo.Caption)"
    Write-Info "版本号: $osMajor.$osMinor"

    # ========== 系统兼容性检查（关键）==========
    # OpenClaw 需要 Node.js 22.16+
    # Node.js 22.x 需要 Windows 10 (10.0) 或更高
    if ($osMajor -lt 10) {
        Write-Host ""
        Write-Err "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        Write-Err "  ⛔ 系统版本过低，无法安装 OpenClaw"
        Write-Err "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        Write-Host ""
        Write-Err "你的系统: Windows $osMajor.$osMinor"
        Write-Err "最低要求: Windows 10"
        Write-Host ""
        Write-Info "原因：OpenClaw 需要 Node.js 22.16+，而 Node.js 22.x"
        Write-Info "      仅支持 Windows 10 及以上版本"
        Write-Host ""
        Write-Host "解决方案：" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  1. 升级 Windows（推荐）" -ForegroundColor Cyan
        Write-Host "     - 设置 → 更新和安全 → Windows 更新"
        Write-Host ""
        Write-Host "  2. 使用其他电脑" -ForegroundColor Cyan
        Write-Host "     - Windows 10/11"
        Write-Host "     - macOS 10.15+"
        Write-Host "     - Linux"
        Write-Host ""
        Write-Host "  3. 使用云服务器" -ForegroundColor Cyan
        Write-Host "     - 阿里云、腾讯云等 VPS"
        Write-Host ""
        return $false
    }
    Write-OK "系统版本兼容 (Windows $osMajor.$osMinor >= 10)"

    # 内存
    $totalMem = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
    $memGB = [math]::Round($totalMem / 1GB, 2)

    if ($memGB -lt 4) {
        Write-Err "内存过低 (${memGB}GB)，建议至少 4GB"
        return $false
    }
    Write-OK "内存: ${memGB}GB"

    # 硬盘空间
    $freeSpace = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace
    $freeGB = [math]::Round($freeSpace / 1GB, 2)

    if ($freeGB -lt 2) {
        Write-Err "硬盘空间不足 (${freeGB}GB)"
        Show-DiskSpaceHelp -FreeGB $freeGB
        return $false
    }
    Write-OK "可用空间: ${freeGB}GB"

    # 检查是否以管理员运行
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Warn "建议以管理员身份运行"
        Write-Info "某些安装步骤可能需要管理员权限"
    }

    return $true
}

# 检测 Node.js
function Test-Node {
    Write-Substep "检测 Node.js"

    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if (-not $nodeCmd) {
        Write-Warn "未安装 Node.js"
        $script:NeedNode = $true
        return $false
    }

    $version = (node -v 2>$null)
    $major = [int]($version -replace 'v(\d+).*', '$1')

    Write-Info "已安装: $version"

    if ($major -lt 22) {
        Write-Warn "版本过低 (需要 22+)，需要升级"
        $script:NeedNode = $true
        return $false
    }

    Write-OK "版本满足要求"
    return $true
}

# 安装 Node.js
function Install-Node {
    Write-Step "📦 第 2 步：安装 Node.js $NodeVersion"

    # 检测系统架构
    $arch = $env:PROCESSOR_ARCHITECTURE
    $archName = if ($arch -eq "AMD64") { "x64 (64位)" } elseif ($arch -eq "ARM64") { "ARM64" } else { $arch }
    Write-Info "系统架构: $archName"

    $installed = $false

    # 方法 1: 官方安装包（优先，最适合小白）
    if (-not $installed) {
        Write-Info "下载官方安装包..."

        # 根据架构选择正确的下载链接
        $msiSuffix = if ($arch -eq "ARM64") { "-arm64" } else { "-x64" }
        $downloadUrl = "https://nodejs.org/dist/v$NodeVersion/node-v$NodeVersion$msiSuffix.msi"
        $installerPath = "$env:TEMP\node-installer.msi"

        Write-Info "下载地址: $downloadUrl"

        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
            Write-Info "正在安装..."
            Start-Process msiexec.exe -ArgumentList "/i `"$installerPath`" /passive /norestart" -Wait
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
            $installed = $true
        } catch {
            Write-Err "下载失败: $_"
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        }
    }

    # 方法 2: winget（作为兜底）
    if (-not $installed) {
        $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetCmd) {
            Write-Info "官方安装包失败，尝试使用 winget..."
            try {
                winget install OpenJS.NodeJS --accept-source-agreements --accept-package-agreements
                $installed = $true
            } catch {
                Write-Warn "winget 安装失败: $_"
            }
        }
    }

    if ($installed) {
        # 刷新环境变量
        Refresh-Path
        Start-Sleep -Seconds 2

        $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
        if ($nodeCmd) {
            Write-OK "Node.js 安装成功: $(node -v)"
            Write-OK "npm 版本: $(npm -v)"

            # 测试 Node.js 是否能正常运行
            try {
                $testResult = node -e "console.log('OK')" 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-OK "Node.js 运行正常"
                    return $true
                } else {
                    Write-Err "Node.js 安装成功但无法运行"
                    Write-Err "可能存在系统兼容性问题"
                    Show-NodeInstallHelp
                    return $false
                }
            } catch {
                Write-Err "Node.js 运行测试失败"
                Show-NodeInstallHelp
                return $false
            }
        } else {
            Write-Warn "Node.js 已安装，但需要重启 PowerShell"
            Write-Info "请关闭此窗口，重新打开 PowerShell 后再运行此脚本"
            return $false
        }
    }

    Write-Err "Node.js 安装失败"
    Show-NodeInstallHelp
    return $false
}

# 显示 Node.js 安装帮助
function Show-NodeInstallHelp {
    Write-Host ""
    Write-Host "────────────────────────────────────────" -ForegroundColor Yellow
    Write-Host "  手动安装 Node.js 的方法：" -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  方法 1: 下载官方安装包"
    Write-Host "    访问: https://nodejs.org"
    Write-Host "    下载 LTS 版本并安装"
    Write-Host ""
    Write-Host "  方法 2: 使用 Chocolatey"
    Write-Host "    choco install nodejs-lts"
    Write-Host ""
    Write-Host "────────────────────────────────────────" -ForegroundColor Yellow
}

# 检测 Git
function Test-Git {
    Write-Substep "检测 Git 和 GitHub 连接"

    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCmd) {
        Write-Warn "未安装 Git，正在安装..."

        $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetCmd) {
            try {
                winget install Git.Git --accept-source-agreements --accept-package-agreements
                Refresh-Path
            } catch {
                Write-Err "Git 安装失败"
                Write-Info "请手动安装: https://git-scm.com/download/win"
                return $false
            }
        } else {
            Write-Err "Git 安装失败"
            Write-Info "请手动安装: https://git-scm.com/download/win"
            return $false
        }
    }

    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) {
        $version = (git --version 2>$null) -replace 'git version (.*)', '$1'
        Write-OK "Git: $version"
    }

    # 测试 GitHub 连接
    Write-Info "测试 GitHub 连接..."
    try {
        $null = Invoke-WebRequest -Uri "https://github.com" -TimeoutSec 15 -UseBasicParsing
        Write-OK "可以连接 GitHub"
        return $true
    } catch {
        Write-Warn "无法连接 GitHub"
        $script:NeedGitMirror = $true
        return $false
    }
}

# 配置 Git 镜像
function Set-GitMirror {
    Write-Step "🌐 第 3 步：配置 GitHub 镜像源"

    Write-Host ""
    Write-Host "你无法直接连接 GitHub，需要配置镜像源" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "请选择镜像源 (直接输入数字即可)：" -ForegroundColor Cyan
    Write-Host ""

    for ($i = 0; $i -lt $MirrorNames.Count; $i++) {
        Write-Host "  $($i+1)) $($MirrorNames[$i])"
    }

    Write-Host ""
    Write-Host "提示: 输入 1、2 或 3，然后按 Enter" -ForegroundColor Cyan
    Write-Host ""

    $choice = Read-NumberChoice -Prompt "请选择 [1-3，默认1]" -Min 1 -Max $MirrorNames.Count -Default 1

    $choiceStr = $choice.ToString()
    $mirrorUrl = $GitMirrors[$choiceStr]
    $mirrorName = $MirrorNames[$choice - 1]

    Write-Info "你选择了: $mirrorName"
    Write-Info "配置镜像: $mirrorUrl"

    # 清除旧配置
    foreach ($key in $GitMirrors.Keys) {
        git config --global --unset url."$($GitMirrors[$key])/github.com/".insteadOf 2>$null
    }

    # 设置新配置
    git config --global url."$mirrorUrl/github.com/".insteadOf "https://github.com/"

    Write-OK "镜像配置成功"
    return $true
}

# 检测 OpenClaw
function Test-OpenClaw {
    Write-Substep "检测小龙虾 (OpenClaw)"

    $ocCmd = Get-Command openclaw -ErrorAction SilentlyContinue
    if ($ocCmd) {
        $version = (openclaw --version 2>$null)
        Write-OK "已安装: $version"

        Write-Host ""
        $choice = Read-YesNoChoice -Prompt "是否重新安装/更新?" -Default $false
        if ($choice) {
            $script:NeedOpenClaw = $true
            return $false
        }

        return $true
    } else {
        Write-Warn "未安装小龙虾"
        $script:NeedOpenClaw = $true
        return $false
    }
}

# 选择 npm 源
function Select-NpmRegistry {
    Write-Host ""
    Write-Host "请选择 npm 源 (直接输入数字即可)：" -ForegroundColor Cyan
    Write-Host ""

    for ($i = 0; $i -lt $NpmNames.Count; $i++) {
        Write-Host "  $($i+1)) $($NpmNames[$i])"
    }

    Write-Host ""
    Write-Host "提示: 输入 1、2 或 3，然后按 Enter" -ForegroundColor Cyan
    Write-Host ""

    $choice = Read-NumberChoice -Prompt "请选择 [1-3，默认1]" -Min 1 -Max $NpmNames.Count -Default 1

    $choiceStr = $choice.ToString()
    $registry = $NpmRegistries[$choiceStr]
    $registryName = $NpmNames[$choice - 1]

    Write-Info "你选择了: $registryName"
    npm config set registry $registry
    Write-OK "已设置: $registry"
}

# 安装 OpenClaw
function Install-OpenClaw {
    Write-Step "🦞 第 4 步：安装小龙虾 (OpenClaw)"

    # 先选择 npm 源
    Select-NpmRegistry

    # 如果已有安装，先卸载
    $ocCmd = Get-Command openclaw -ErrorAction SilentlyContinue
    if ($ocCmd) {
        Write-Info "卸载旧版本..."
        npm uninstall -g openclaw 2>$null
    }

    Write-Info "正在安装，请耐心等待..."
    Write-Info "这可能需要几分钟..."
    Write-Host ""

    # 设置环境变量
    $env:SHARP_IGNORE_GLOBAL_LIBVIPS = "1"

    # 直接运行 npm install，让用户看到输出
    npm install -g openclaw@latest

    if ($LASTEXITCODE -eq 0) {
        # 刷新环境变量
        Refresh-Path
        Start-Sleep -Seconds 2

        $ocCmd = Get-Command openclaw -ErrorAction SilentlyContinue
        if ($ocCmd) {
            Write-OK "小龙虾安装成功: $(openclaw --version)"
            return $true
        } else {
            Write-Warn "安装成功，但需要重启 PowerShell"
            Write-Info "请关闭此窗口，重新打开 PowerShell"
            return $true
        }
    }

    # 安装失败，显示错误
    Write-Host ""
    Write-Err "小龙虾安装失败 (exit code: $LASTEXITCODE)"
    Show-OpenClawInstallHelp

    # 暂停让用户看到错误
    Write-Host ""
    Read-Host "按 Enter 键退出..."

    return $false
}

# 显示 OpenClaw 安装帮助
function Show-OpenClawInstallHelp {
    Write-Host ""
    Write-Host "────────────────────────────────────────" -ForegroundColor Yellow
    Write-Host "  安装失败，请尝试：" -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1. 检查网络连接"
    Write-Host "  2. 尝试更换 npm 源后重新运行此脚本"
    Write-Host "  3. 手动安装: npm install -g openclaw"
    Write-Host ""
    Write-Host "  如需帮助，访问: https://docs.openclaw.ai"
    Write-Host ""
    Write-Host "────────────────────────────────────────" -ForegroundColor Yellow
}

# 运行配置向导
function Start-Onboarding {
    Write-Step "🎯 第 5 步：配置小龙虾"

    Write-Host ""
    Write-Host "现在需要配置小龙虾的 AI 模型和消息通道" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "配置向导会帮助你："
    Write-Host "  • 设置 AI 模型提供商（需要 API Key）"
    Write-Host "  • 配置消息通道（WhatsApp、Telegram、Discord 等）"
    Write-Host "  • 安装后台服务（可选）"
    Write-Host ""

    $choice = Read-YesNoChoice -Prompt "是否启动配置向导?" -Default $true

    if ($choice) {
        Write-Info "启动配置向导..."
        Write-Host ""
        openclaw onboard --install-daemon
    } else {
        Write-Info "跳过配置向导"
        Write-Info "稍后可以运行 'openclaw onboard' 进行配置"
    }
}

# 显示完成信息
function Show-Complete {
    Write-SuccessBox

    Write-Host "小龙虾已成功安装！" -ForegroundColor Green
    Write-Host ""
    Write-Host "常用命令：" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  openclaw status      查看状态"
    Write-Host "  openclaw gateway     启动网关"
    Write-Host "  openclaw dashboard   打开控制面板"
    Write-Host "  openclaw --help      查看帮助"
    Write-Host ""
    Write-Host "下一步：" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1. 运行 openclaw gateway 启动网关"
    Write-Host "  2. 打开浏览器访问 http://127.0.0.1:18789"
    Write-Host ""
    Write-Host "文档：" -ForegroundColor Yellow -NoNewline
    Write-Host " https://docs.openclaw.ai"
    Write-Host "社区：" -ForegroundColor Yellow -NoNewline
    Write-Host " https://discord.com/invite/clawd"
    Write-Host ""
}

# 显示失败信息
function Show-Failed {
    param([string]$Step)

    Write-FailBox -Reason $Step

    Write-Host "解决后重新运行：" -ForegroundColor Yellow
    Write-Host ""
    Write-Host '  $tmp = Join-Path $env:TEMP "openclaw-install.ps1"; iwr -useb https://gitee.com/cyberpinkman/openclaw-easy-deploy/raw/main/windows/install.ps1 -OutFile $tmp; powershell -NoExit -ExecutionPolicy Bypass -File $tmp'
    Write-Host ""
    Write-Host "或使用 GitHub：" -ForegroundColor Cyan
    Write-Host ""
    Write-Host '  $tmp = Join-Path $env:TEMP "openclaw-install.ps1"; iwr -useb https://raw.githubusercontent.com/cyberpinkman/openclaw-easy-deploy/main/windows/install.ps1 -OutFile $tmp; powershell -NoExit -ExecutionPolicy Bypass -File $tmp'
    Write-Host ""
}

# 主函数
function Main {
    Write-Header

    Write-Host "这个脚本会帮你完成所有安装，你只需要：" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1. 看着屏幕"
    Write-Host "  2. 偶尔按一下 Enter 或输入 y/n"
    Write-Host "  3. 等待完成"
    Write-Host ""

    Wait-Continue "准备好了吗？按 Enter 开始..."

    # 第 1 步：检测环境
    if (-not (Test-Environment)) {
        Show-Failed -Step "系统环境不满足要求"
        return
    }

    # 检测 Node.js
    $null = Test-Node

    # 检测 Git
    $null = Test-Git

    # 检测 OpenClaw
    $null = Test-OpenClaw

    # 第 2 步：安装 Node.js（如果需要）
    if ($script:NeedNode) {
        Write-Host ""
        $choice = Read-YesNoChoice -Prompt "需要安装 Node.js，是否继续?" -Default $true
        if (-not $choice) {
            Show-Failed -Step "用户取消安装 Node.js"
            return
        }

        if (-not (Install-Node)) {
            Show-Failed -Step "Node.js 安装失败"
            return
        }
    }

    # 第 3 步：配置镜像（如果需要）
    if ($script:NeedGitMirror) {
        Write-Host ""
        $choice = Read-YesNoChoice -Prompt "需要配置 GitHub 镜像源，是否继续?" -Default $true
        if (-not $choice) {
            Write-Warn "跳过镜像配置，后续安装可能失败"
        } else {
            $null = Set-GitMirror
        }
    }

    # 第 4 步：安装 OpenClaw（如果需要）
    if ($script:NeedOpenClaw) {
        if (-not (Install-OpenClaw)) {
            Show-Failed -Step "小龙虾安装失败"
            return
        }
    } else {
        Write-Step "🦞 小龙虾"
        Write-OK "已安装，跳过"
    }

    # 第 5 步：配置向导
    Start-Onboarding

    # 完成
    Show-Complete
}

# 运行
try {
    Main
} catch {
    Show-Failed -Step "脚本发生未处理异常: $($_.Exception.Message)"
} finally {
    Wait-Continue "安装脚本已结束，按 Enter 返回 PowerShell..."
}
