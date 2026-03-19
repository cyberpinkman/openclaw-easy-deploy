# ============================================
# 🦞 Node.js 安装脚本 (Windows)
# 自动检测并安装 Node.js 24
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
    Write-ColorOutput "  🦞 Node.js 安装脚本 (Windows)" -Type Header
    Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Type Header
    Write-Host ""
    
    # 检测系统架构
    $arch = $env:PROCESSOR_ARCHITECTURE
    if ($arch -eq "AMD64") {
        Write-ColorOutput "系统架构: x64 (64位)" -Type Info
    } elseif ($arch -eq "ARM64") {
        Write-ColorOutput "系统架构: ARM64" -Type Info
    } else {
        Write-ColorOutput "系统架构: $arch" -Type Info
    }
    Write-Host ""
}

# Node.js 版本
$script:NodeVersion = "24.14.0"

# 获取当前 Node.js 版本
function Get-CurrentNodeVersion {
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        $version = (node -v 2>$null)
        $major = [int]($version -replace 'v(\d+).*', '$1')
        return $major
    }
    return 0
}

# 验证 Node.js 是否能正常运行
function Test-NodeExecution {
    Write-ColorOutput "验证 Node.js 运行状态" -Type Step

    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if (-not $nodeCmd) {
        Write-ColorOutput "Node.js 未找到" -Type Error
        return $false
    }

    # 测试 node 是否能正常执行
    try {
        $result = node -e "console.log('OK')" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "Node.js 运行正常" -Type OK
            return $true
        } else {
            Write-ColorOutput "Node.js 无法运行" -Type Error
            Write-ColorOutput "可能是架构不匹配或安装损坏" -Type Info
            return $false
        }
    } catch {
        Write-ColorOutput "Node.js 运行测试失败: $_" -Type Error
        return $false
    }
}

# 使用 winget 安装
function Install-ViaWinget {
    Write-ColorOutput "使用 winget 安装 Node.js 24" -Type Step

    $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wingetCmd) {
        Write-ColorOutput "winget 未安装" -Type Warn
        Write-ColorOutput "winget 需要 Windows 10 21H2 或 Windows 11" -Type Info
        Write-ColorOutput "请选择其他安装方式" -Type Info
        return $false
    }

    Write-ColorOutput "正在安装 Node.js 24 (Current 版本)..." -Type Info

    try {
        # 使用 OpenJS.NodeJS (Current 24.x) 而非 LTS (22.x)
        winget install OpenJS.NodeJS --accept-source-agreements --accept-package-agreements
        
        # 刷新环境变量
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        Start-Sleep -Seconds 2

        # 验证运行状态
        if (Test-NodeExecution) {
            Write-ColorOutput "Node.js 安装成功且运行正常" -Type OK
            return $true
        } else {
            Write-ColorOutput "winget 安装的 Node.js 无法运行，尝试其他方式..." -Type Warn
            return $false
        }
    } catch {
        Write-ColorOutput "winget 安装失败: $_" -Type Error
        return $false
    }
}

# 使用 Chocolatey 安装
function Install-ViaChocolatey {
    Write-ColorOutput "使用 Chocolatey 安装 Node.js" -Type Step

    $chocoCmd = Get-Command choco -ErrorAction SilentlyContinue
    if (-not $chocoCmd) {
        Write-ColorOutput "Chocolatey 未安装" -Type Warn
        Write-ColorOutput "正在安装 Chocolatey..." -Type Info

        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        } catch {
            Write-ColorOutput "Chocolatey 安装失败" -Type Error
            return $false
        }
    }

    Write-ColorOutput "正在安装 Node.js..." -Type Info

    try {
        choco install nodejs-lts -y
        
        # 刷新环境变量
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        Start-Sleep -Seconds 2

        # 验证运行状态
        if (Test-NodeExecution) {
            Write-ColorOutput "Node.js 安装成功且运行正常" -Type OK
            return $true
        } else {
            Write-ColorOutput "Chocolatey 安装的 Node.js 无法运行" -Type Warn
            return $false
        }
    } catch {
        Write-ColorOutput "Chocolatey 安装失败: $_" -Type Error
        return $false
    }
}

# 下载官方安装包（根据架构自动选择）
function Install-ViaOfficial {
    Write-ColorOutput "下载官方安装包" -Type Step

    # 检测架构并选择正确的下载链接
    $arch = $env:PROCESSOR_ARCHITECTURE
    if ($arch -eq "ARM64") {
        $msiSuffix = "arm64.msi"
        $archName = "ARM64"
    } else {
        $msiSuffix = "x64.msi"
        $archName = "x64"
    }

    $downloadUrl = "https://nodejs.org/dist/v$script:NodeVersion/node-v$script:NodeVersion-$msiSuffix"
    $installerPath = "$env:TEMP\node-installer.msi"

    Write-ColorOutput "系统架构: $archName" -Type Info
    Write-ColorOutput "下载地址: $downloadUrl" -Type Info
    Write-ColorOutput "正在下载..." -Type Info

    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
    } catch {
        Write-ColorOutput "下载失败: $_" -Type Error
        Write-ColorOutput "请手动下载: https://nodejs.org" -Type Info
        return $false
    }

    Write-ColorOutput "正在安装，请按提示操作..." -Type Info

    try {
        Start-Process msiexec.exe -ArgumentList "/i `"$installerPath`" /passive /norestart" -Wait
        Write-ColorOutput "安装完成" -Type OK

        # 清理
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

        # 刷新环境变量
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        Start-Sleep -Seconds 2

        # 验证运行状态
        if (Test-NodeExecution) {
            Write-ColorOutput "Node.js 安装成功且运行正常" -Type OK
            return $true
        } else {
            Write-ColorOutput "Node.js 安装完成但无法运行" -Type Error
            Write-ColorOutput "可能存在系统兼容性问题" -Type Info
            return $false
        }
    } catch {
        Write-ColorOutput "安装失败: $_" -Type Error
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        return $false
    }
}

# 验证安装
function Test-Installation {
    Write-ColorOutput "最终验证" -Type Step

    # 刷新环境变量
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    # 等待一下让安装完成
    Start-Sleep -Seconds 2

    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue

    if ($nodeCmd) {
        $version = (node -v 2>$null)
        $npmVersion = (npm -v 2>$null)

        Write-ColorOutput "Node.js 版本: $version" -Type OK
        Write-ColorOutput "npm 版本: $npmVersion" -Type OK

        $major = [int]($version -replace 'v(\d+).*', '$1')
        if ($major -ge 22) {
            Write-ColorOutput "版本满足要求" -Type OK
            
            # 测试运行
            try {
                $result = node -e "console.log('OK')" 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-ColorOutput "Node.js 运行正常" -Type OK
                    return $true
                } else {
                    Write-ColorOutput "Node.js 无法运行" -Type Error
                    return $false
                }
            } catch {
                Write-ColorOutput "Node.js 运行测试失败" -Type Error
                return $false
            }
        } else {
            Write-ColorOutput "版本仍然过低" -Type Error
            return $false
        }
    } else {
        Write-ColorOutput "Node.js 未找到" -Type Error
        Write-ColorOutput "请关闭当前 PowerShell 窗口，重新打开后再试" -Type Info
        return $false
    }
}

# 主函数
function Main {
    Clear-Host
    Print-Header

    # 检查当前版本
    $currentMajor = Get-CurrentNodeVersion

    if ($currentMajor -ge 24) {
        Write-ColorOutput "Node.js 24 已安装 ($(node -v))" -Type OK
        
        # 验证是否能运行
        if (Test-NodeExecution) {
            Write-ColorOutput "Node.js 运行正常，无需重复安装" -Type OK
            exit 0
        } else {
            Write-ColorOutput "Node.js 已安装但无法运行，需要重新安装" -Type Warn
        }
    } elseif ($currentMajor -ge 22) {
        Write-ColorOutput "当前 Node.js 版本: $(node -v)" -Type Info
        Write-ColorOutput "版本满足最低要求，建议升级到 24" -Type Info

        $choice = Read-Host "是否升级到 Node.js 24? (y/n)"
        if ($choice -ne "y" -and $choice -ne "Y") {
            Write-ColorOutput "跳过安装" -Type Info
            exit 0
        }
    } else {
        Write-ColorOutput "当前 Node.js 版本过低或未安装" -Type Info
    }

    # 选择安装方式
    Write-Host ""
    Write-Host "请选择安装方式：" -ForegroundColor Yellow
    Write-Host "  1) winget (推荐)"
    Write-Host "  2) Chocolatey"
    Write-Host "  3) 官方安装包 (自动适配架构)"
    Write-Host ""

    $choice = Read-Host "请输入选项 (1-3)"

    $success = $false

    switch ($choice) {
        "1" { $success = Install-ViaWinget }
        "2" { $success = Install-ViaChocolatey }
        "3" { $success = Install-ViaOfficial }
        default {
            Write-ColorOutput "无效选项" -Type Error
            exit 1
        }
    }

    # 如果第一种方式失败，尝试其他方式
    if (-not $success) {
        Write-Host ""
        Write-ColorOutput "第一种方式安装失败，尝试使用官方安装包..." -Type Warn
        $success = Install-ViaOfficial
    }

    if (-not $success) {
        Write-ColorOutput "所有安装方式都失败了" -Type Error
        Write-ColorOutput "请手动下载安装: https://nodejs.org" -Type Info
        exit 1
    }

    # 最终验证
    $installed = Test-Installation

    Write-Host ""
    Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Type Header

    if ($installed) {
        Write-ColorOutput "  ✅ Node.js 安装完成" -Type Header
    } else {
        Write-ColorOutput "  ⚠ Node.js 安装完成，但可能需要重启 PowerShell" -Type Header
    }

    Write-ColorOutput "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -Type Header
    Write-Host ""
    Write-Host "下一步: 运行 3-install-git.ps1 安装/配置 Git" -ForegroundColor Yellow
    Write-Host ""
}

# 运行
Main
