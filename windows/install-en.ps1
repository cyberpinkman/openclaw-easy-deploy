# OpenClaw Easy Install Script (English Version)
# For users with encoding issues

$ErrorActionPreference = "Continue"

# UTF-8 encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptVersion = "1.0.0"
$NodeVersion = "24.14.0"

$GitMirrors = @{
    "1" = "https://gitclone.com"
    "2" = "https://mirror.ghproxy.com"
    "3" = "https://ghproxy.net"
}

$MirrorNames = @("gitclone.com", "mirror.ghproxy.com", "ghproxy.net")

$NpmRegistries = @{
    "1" = "https://registry.npmmirror.com"
    "2" = "https://mirrors.cloud.tencent.com/npm/"
    "3" = "https://registry.npmjs.org"
}

$NpmNames = @("Taobao (Recommended)", "Tencent", "Official (Need Proxy)")

$script:NeedNode = $false
$script:NeedGitMirror = $false
$script:NeedOpenClaw = $false

function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  +===========================================+" -ForegroundColor Cyan
    Write-Host "  |                                           |" -ForegroundColor Cyan
    Write-Host "  |     [Lobster] OpenClaw Install Script     |" -ForegroundColor Cyan
    Write-Host "  |                                           |" -ForegroundColor Cyan
    Write-Host "  +===========================================+" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step($Message) {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host "  $Message" -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Yellow
}

function Write-Substep($Message) {
    Write-Host ""
    Write-Host "> $Message" -ForegroundColor Cyan
}

function Write-OK($Message) { Write-Host "  [OK] $Message" -ForegroundColor Green }
function Write-Err($Message) { Write-Host "  [X] $Message" -ForegroundColor Red }
function Write-Warn($Message) { Write-Host "  [!] $Message" -ForegroundColor Yellow }
function Write-Info($Message) { Write-Host "  [i] $Message" -ForegroundColor Cyan }

function Write-SuccessBox {
    Write-Host ""
    Write-Host "  +===========================================+" -ForegroundColor Green
    Write-Host "  |                                           |" -ForegroundColor Green
    Write-Host "  |         [OK] Install Complete!            |" -ForegroundColor Green
    Write-Host "  |                                           |" -ForegroundColor Green
    Write-Host "  +===========================================+" -ForegroundColor Green
    Write-Host ""
}

function Write-FailBox($Reason) {
    Write-Host ""
    Write-Host "  +===========================================+" -ForegroundColor Red
    Write-Host "  |                                           |" -ForegroundColor Red
    Write-Host "  |         [X] Install Failed                |" -ForegroundColor Red
    Write-Host "  |                                           |" -ForegroundColor Red
    Write-Host "  +===========================================+" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Reason: $Reason" -ForegroundColor Red
    Write-Host ""
}

function Read-NumberChoice($Prompt, $Min, $Max, $Default = $Min) {
    $maxAttempts = 5
    $attempt = 1
    while ($attempt -le $maxAttempts) {
        $choice = Read-Host $Prompt
        if ([string]::IsNullOrWhiteSpace($choice)) { return $Default }
        $choice = $choice.Trim()
        if ($choice -match '^\d+$') {
            $num = [int]$choice
            if ($num -ge $Min -and $num -le $Max) { return $num }
            Write-Warn "Enter number $Min to $Max (got: $num)"
        } else { Write-Warn "Enter a number, not: '$choice'" }
        $attempt++
    }
    Write-Warn "Max attempts reached, using default: $Default"
    return $Default
}

function Wait-Continue($Message = "Press Enter to continue...") {
    Write-Host ""
    Read-Host $Message | Out-Null
}

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Test-Environment {
    Write-Step "[Step 1] Checking System Environment"

    $osInfo = Get-CimInstance Win32_OperatingSystem
    $osVersion = [Environment]::OSVersion.Version
    $osMajor = $osVersion.Major

    Write-Info "Windows: $($osInfo.Caption)"
    Write-Info "Version: $osMajor.$($osVersion.Minor)"

    if ($osMajor -lt 10) {
        Write-Host ""
        Write-Err "+============================================+"
        Write-Err "|  [X] System version too old               |"
        Write-Err "+============================================+"
        Write-Host ""
        Write-Err "Your system: Windows $osMajor.$($osVersion.Minor)"
        Write-Err "Required: Windows 10+"
        Write-Host ""
        Write-Info "OpenClaw requires Node.js 22.16+"
        Write-Info "Node.js 22.x only supports Windows 10+"
        Write-Host ""
        Write-Host "Solutions:" -ForegroundColor Yellow
        Write-Host "  1. Upgrade Windows"
        Write-Host "  2. Use another PC (Windows 10/11, macOS 10.15+, Linux)"
        Write-Host "  3. Use a VPS"
        return $false
    }
    Write-OK "Windows version OK ($osMajor.$($osVersion.Minor) >= 10)"

    $totalMem = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
    $memGB = [math]::Round($totalMem / 1GB, 2)
    if ($memGB -lt 4) { Write-Err "RAM too low ($memGB GB), need 4GB+"; return $false }
    Write-OK "RAM: $memGB GB"

    $freeSpace = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'").FreeSpace
    $freeGB = [math]::Round($freeSpace / 1GB, 2)
    if ($freeGB -lt 2) { Write-Err "Disk space too low ($freeGB GB), need 2GB+"; return $false }
    Write-OK "Disk: $freeGB GB free"

    return $true
}

function Test-Node {
    Write-Substep "Checking Node.js"
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if (-not $nodeCmd) { Write-Warn "Node.js not installed"; $script:NeedNode = $true; return $false }
    $version = (node -v 2>$null)
    $major = [int]($version -replace 'v(\d+).*', '$1')
    Write-Info "Installed: $version"
    if ($major -lt 22) { Write-Warn "Version too old (need 22+), upgrading"; $script:NeedNode = $true; return $false }
    Write-OK "Version OK"
    return $true
}

function Install-Node {
    Write-Step "[Step 2] Installing Node.js $NodeVersion"

    $arch = $env:PROCESSOR_ARCHITECTURE
    Write-Info "Architecture: $arch"

    $installed = $false
    $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        Write-Info "Using winget..."
        try { winget install OpenJS.NodeJS --accept-source-agreements --accept-package-agreements; $installed = $true }
        catch { Write-Warn "winget failed: $_" }
    }

    if (-not $installed) {
        Write-Info "Downloading official package..."
        $msiSuffix = if ($arch -eq "ARM64") { "-arm64" } else { "-x64" }
        $url = "https://nodejs.org/dist/v$NodeVersion/node-v$NodeVersion$msiSuffix.msi"
        $tmp = "$env:TEMP\node-installer.msi"
        Write-Info "URL: $url"
        try {
            Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
            Write-Info "Installing..."
            Start-Process msiexec.exe -ArgumentList "/i `"$tmp`" /passive /norestart" -Wait
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            $installed = $true
        } catch { Write-Err "Download failed: $_"; Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }

    if ($installed) {
        Refresh-Path; Start-Sleep -Seconds 2
        $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
        if ($nodeCmd) {
            Write-OK "Node.js installed: $(node -v)"
            Write-OK "npm version: $(npm -v)"
            try { $null = node -e "console.log('OK')" 2>&1; Write-OK "Node.js working"; return $true }
            catch { Write-Err "Node.js installed but not working"; return $false }
        }
        Write-Warn "Node.js installed, restart PowerShell"
        return $true
    }
    Write-Err "Node.js installation failed"
    Write-Host ""
    Write-Host "Manual install: https://nodejs.org" -ForegroundColor Yellow
    return $false
}

function Test-Git {
    Write-Substep "Checking Git and GitHub"
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCmd) {
        Write-Warn "Git not installed, installing..."
        $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetCmd) {
            try { winget install Git.Git --accept-source-agreements --accept-package-agreements; Refresh-Path }
            catch { Write-Err "Git install failed"; Write-Info "Manual: https://git-scm.com/download/win"; return $false }
        }
    }
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if ($gitCmd) { Write-OK "Git: $(git --version 2>$null)" }
    Write-Info "Testing GitHub connection..."
    try { $null = Invoke-WebRequest -Uri "https://github.com" -TimeoutSec 15 -UseBasicParsing; Write-OK "GitHub reachable"; return $true }
    catch { Write-Warn "Cannot reach GitHub"; $script:NeedGitMirror = $true; return $false }
}

function Set-GitMirror {
    Write-Step "[Step 3] Configuring GitHub Mirror"
    Write-Host ""
    Write-Host "Cannot reach GitHub, need mirror" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Select mirror (enter number):" -ForegroundColor Cyan
    for ($i = 0; $i -lt $MirrorNames.Count; $i++) { Write-Host "  $($i+1)) $($MirrorNames[$i])" }
    Write-Host ""
    $choice = Read-NumberChoice "Select [1-3, default 1]" 1 $MirrorNames.Count 1
    $mirrorUrl = $GitMirrors[$choice.ToString()]
    Write-Info "Selected: $($MirrorNames[$choice-1])"
    Write-Info "Configuring: $mirrorUrl"
    foreach ($key in $GitMirrors.Keys) { git config --global --unset url."$($GitMirrors[$key])/github.com/".insteadOf 2>$null }
    git config --global url."$mirrorUrl/github.com/".insteadOf "https://github.com/"
    Write-OK "Mirror configured"
    return $true
}

function Test-OpenClaw {
    Write-Substep "Checking OpenClaw"
    $ocCmd = Get-Command openclaw -ErrorAction SilentlyContinue
    if ($ocCmd) {
        Write-OK "Installed: $(openclaw --version 2>$null)"
        $choice = Read-Host "Reinstall/Update? (y/n)"
        if ($choice -eq "y" -or $choice -eq "Y") { $script:NeedOpenClaw = $true; return $false }
        return $true
    }
    Write-Warn "OpenClaw not installed"
    $script:NeedOpenClaw = $true
    return $false
}

function Select-NpmRegistry {
    Write-Host ""
    Write-Host "Select npm registry:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $NpmNames.Count; $i++) { Write-Host "  $($i+1)) $($NpmNames[$i])" }
    Write-Host ""
    $choice = Read-NumberChoice "Select [1-3, default 1]" 1 $NpmNames.Count 1
    $registry = $NpmRegistries[$choice.ToString()]
    Write-Info "Selected: $($NpmNames[$choice-1])"
    npm config set registry $registry
    Write-OK "Set: $registry"
}

function Install-OpenClaw {
    Write-Step "[Step 4] Installing OpenClaw"
    Select-NpmRegistry

    $ocCmd = Get-Command openclaw -ErrorAction SilentlyContinue
    if ($ocCmd) { Write-Info "Removing old version..."; npm uninstall -g openclaw 2>$null }

    Write-Info "Installing, please wait..."
    Write-Host ""
    $env:SHARP_IGNORE_GLOBAL_LIBVIPS = "1"
    $result = npm install -g openclaw@latest 2>&1

    if ($LASTEXITCODE -eq 0) {
        Refresh-Path; Start-Sleep -Seconds 2
        $ocCmd = Get-Command openclaw -ErrorAction SilentlyContinue
        if ($ocCmd) { Write-OK "OpenClaw installed: $(openclaw --version)"; return $true }
        Write-Warn "Installed, restart PowerShell to use"
        return $true
    }
    Write-Err "OpenClaw installation failed"
    Write-Host ""
    Write-Host "Try: npm install -g openclaw" -ForegroundColor Yellow
    return $false
}

function Start-Onboarding {
    Write-Step "[Step 5] Configure OpenClaw"
    Write-Host ""
    Write-Host "Now configure AI model and messaging channels" -ForegroundColor Cyan
    Write-Host ""
    $choice = Read-Host "Start config wizard? (y/n)"
    if ($choice -eq "y" -or $choice -eq "Y") {
        Write-Info "Starting wizard..."
        openclaw onboard --install-daemon
    } else {
        Write-Info "Skipped. Run 'openclaw onboard' later"
    }
}

function Show-Complete {
    Write-SuccessBox
    Write-Host "OpenClaw installed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Yellow
    Write-Host "  openclaw status      Check status"
    Write-Host "  openclaw gateway     Start gateway"
    Write-Host "  openclaw dashboard   Open control panel"
    Write-Host "  openclaw --help      Show help"
    Write-Host ""
    Write-Host "Next:" -ForegroundColor Yellow
    Write-Host "  1. Run: openclaw gateway"
    Write-Host "  2. Open: http://127.0.0.1:18789"
    Write-Host ""
    Write-Host "Docs: " -NoNewline; Write-Host "https://docs.openclaw.ai"
}

function Show-Failed($Step) {
    Write-FailBox -Reason $Step
    Write-Host "Fix and rerun:" -ForegroundColor Yellow
    Write-Host "  iwr -useb https://raw.githubusercontent.com/cyberpinkman/openclaw-easy-deploy/main/windows/install-en.ps1 | iex"
}

function Main {
    Write-Header
    Write-Host "This script will install everything automatically." -ForegroundColor Cyan
    Write-Host "Just watch, press Enter occasionally, and wait." -ForegroundColor Cyan
    Write-Host ""
    Wait-Continue "Ready? Press Enter to start..."

    if (-not (Test-Environment)) { Show-Failed "System requirements not met"; exit 1 }
    $null = Test-Node
    $null = Test-Git
    $null = Test-OpenClaw

    if ($script:NeedNode) {
        Write-Host ""
        $choice = Read-Host "Need to install Node.js, continue? (y/n)"
        if ($choice -ne "y" -and $choice -ne "Y") { Show-Failed "User cancelled Node.js install"; exit 1 }
        if (-not (Install-Node)) { Show-Failed "Node.js install failed"; exit 1 }
    }

    if ($script:NeedGitMirror) {
        Write-Host ""
        $choice = Read-Host "Need GitHub mirror, continue? (y/n)"
        if ($choice -eq "y" -or $choice -eq "Y") { $null = Set-GitMirror }
        else { Write-Warn "Skipping mirror, install may fail" }
    }

    if ($script:NeedOpenClaw) {
        if (-not (Install-OpenClaw)) { Show-Failed "OpenClaw install failed"; exit 1 }
    } else { Write-Step "[Lobster] OpenClaw"; Write-OK "Already installed, skipped" }

    Start-Onboarding
    Show-Complete
}

Main
