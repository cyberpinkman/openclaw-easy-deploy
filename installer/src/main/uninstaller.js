// ============================================
// Uninstall / Repair Module
// ============================================

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const openclaw = require('./openclaw');
const installState = require('./install-state');

/**
 * Detect current OpenClaw installation status
 */
function detectInstallation() {
  const result = {
    installed: false,
    version: null,
    npmGlobalPath: null,
    configDir: null,
    dataFiles: [],
  };

  try {
    result.version = execSync('openclaw --version', { encoding: 'utf-8', stdio: 'pipe' }).trim();
    result.installed = true;
  } catch {
    return result;
  }

  // Find npm global path
  try {
    result.npmGlobalPath = execSync('npm root -g', { encoding: 'utf-8', stdio: 'pipe' }).trim();
  } catch { /* ignore */ }

  // Find OpenClaw config/data directories
  const homeDir = os.homedir();
  const possibleConfigDirs = [
    path.join(homeDir, '.openclaw'),
    path.join(homeDir, '.config', 'openclaw'),
  ];

  if (process.platform === 'win32') {
    const appData = process.env.APPDATA || path.join(homeDir, 'AppData', 'Roaming');
    const localAppData = process.env.LOCALAPPDATA || path.join(homeDir, 'AppData', 'Local');
    possibleConfigDirs.push(path.join(appData, 'openclaw'));
    possibleConfigDirs.push(path.join(localAppData, 'openclaw'));
  }

  for (const dir of possibleConfigDirs) {
    if (fs.existsSync(dir)) {
      result.dataFiles.push(dir);
      if (!result.configDir) result.configDir = dir;
    }
  }

  return result;
}

/**
 * Simple uninstall — remove OpenClaw but keep user data
 */
async function simpleUninstall(onProgress) {
  onProgress({ stage: 'start', message: '正在卸载小龙虾...', percent: 0 });

  try {
    // Stop any running processes
    onProgress({ stage: 'stopping', message: '停止运行中的服务...', percent: 10 });
    stopOpenClawProcesses();

    // npm uninstall
    onProgress({ stage: 'uninstalling', message: '卸载 openclaw npm 包...', percent: 40 });
    try {
      execSync('npm uninstall -g openclaw', { encoding: 'utf-8', timeout: 120000 });
    } catch {
      // Try with sudo on macOS
      if (process.platform === 'darwin') {
        try {
          const npmPath = execSync('which npm', { encoding: 'utf-8', stdio: 'pipe' }).trim();
          execSync(
            `osascript -e 'do shell script "${npmPath} uninstall -g openclaw" with administrator privileges'`,
            { encoding: 'utf-8', timeout: 120000 }
          );
        } catch (err) {
          return { success: false, error: `卸载失败: ${err.message}` };
        }
      }
    }

    onProgress({ stage: 'done', message: '卸载完成（已保留配置数据）', percent: 100 });
    return { success: true, mode: 'simple' };
  } catch (err) {
    return { success: false, error: err.message };
  }
}

/**
 * Complete uninstall — remove everything, restore all system changes
 */
async function completeUninstall(onProgress) {
  onProgress({ stage: 'start', message: '正在完全卸载小龙虾...', percent: 0 });

  try {
    // Stop processes
    onProgress({ stage: 'stopping', message: '停止运行中的服务...', percent: 5 });
    stopOpenClawProcesses();

    // Revert installer-managed system modifications
    onProgress({ stage: 'reverting-proxy', message: '恢复安装前的系统代理设置...', percent: 10 });
    restoreTrackedSystemProxy();

    onProgress({ stage: 'reverting-git', message: '恢复安装前的 Git 配置...', percent: 20 });
    restoreTrackedGitConfig();

    onProgress({ stage: 'reverting-daemon', message: '移除后台服务...', percent: 30 });
    removeDaemonService();

    // npm uninstall
    onProgress({ stage: 'uninstalling', message: '卸载 openclaw npm 包...', percent: 45 });
    try {
      execSync('npm uninstall -g openclaw', { encoding: 'utf-8', timeout: 120000 });
    } catch {
      if (process.platform === 'darwin') {
        try {
          const npmPath = execSync('which npm', { encoding: 'utf-8', stdio: 'pipe' }).trim();
          execSync(
            `osascript -e 'do shell script "${npmPath} uninstall -g openclaw" with administrator privileges'`,
            { encoding: 'utf-8', timeout: 120000 }
          );
        } catch { /* will try to continue cleanup */ }
      }
    }

    // Remove all data directories
    onProgress({ stage: 'cleanup', message: '删除所有配置和数据文件...', percent: 70 });
    // Even after npm uninstall, data dirs may remain
    removeDataDirectories();

    // Revert npm registry if it was changed
    onProgress({ stage: 'reverting-npm', message: '恢复安装前的 npm 源设置...', percent: 85 });
    restoreTrackedNpmRegistry();

    installState.clearState();

    onProgress({ stage: 'done', message: '完全卸载完成，所有数据已清除', percent: 100 });
    return { success: true, mode: 'complete' };
  } catch (err) {
    return { success: false, error: err.message };
  }
}

/**
 * Repair — reinstall OpenClaw without removing config
 */
async function repair(onProgress) {
  onProgress({ stage: 'start', message: '正在修复安装...', percent: 0 });

  try {
    // Uninstall current version
    onProgress({ stage: 'uninstalling', message: '移除当前版本...', percent: 20 });
    try {
      execSync('npm uninstall -g openclaw', { encoding: 'utf-8', timeout: 120000 });
    } catch { /* ignore */ }

    // Reinstall using the same fallback logic as the normal installer.
    onProgress({ stage: 'reinstalling', message: '重新安装最新版本...', percent: 40 });
    const reinstallResult = await openclaw.install((progress) => {
      onProgress(progress);
    });

    if (!reinstallResult.success) {
      return { success: false, error: reinstallResult.error || '重新安装失败' };
    }

    onProgress({ stage: 'done', message: `修复完成! 版本: ${reinstallResult.version}`, percent: 100 });
    return { success: true, version: reinstallResult.version };
  } catch (err) {
    return { success: false, error: err.message };
  }
}

// ========== Helper Functions ==========

function stopOpenClawProcesses() {
  try {
    if (process.platform === 'win32') {
      execSync('taskkill /f /im openclaw.exe 2>nul', { stdio: 'pipe' });
      // Also kill Node processes that might be OpenClaw gateway
      execSync('taskkill /f /fi "WINDOWTITLE eq openclaw*" 2>nul', { stdio: 'pipe' });
    } else {
      execSync('pkill -f "openclaw" 2>/dev/null || true', { stdio: 'pipe' });
    }
  } catch { /* no processes running */ }
}

function restoreTrackedSystemProxy() {
  const backup = installState.getBackup('systemProxy');
  if (backup) {
    installState.restoreSystemProxyState(backup);
  }
}

function restoreTrackedGitConfig() {
  const backup = installState.getBackup('gitMirror');
  if (backup) {
    installState.restoreGitMirrorState(backup);
  }
}

function removeDaemonService() {
  if (process.platform === 'darwin') {
    const homeDir = os.homedir();
    const plistPaths = [
      path.join(homeDir, 'Library', 'LaunchAgents', 'com.openclaw.gateway.plist'),
      path.join(homeDir, 'Library', 'LaunchAgents', 'com.openclaw.daemon.plist'),
    ];

    for (const plist of plistPaths) {
      if (fs.existsSync(plist)) {
        try {
          execSync(`launchctl unload "${plist}"`, { stdio: 'pipe' });
        } catch { /* ignore */ }
        try { fs.unlinkSync(plist); } catch { /* ignore */ }
      }
    }
  } else if (process.platform === 'win32') {
    // Remove Windows scheduled task or service
    try {
      execSync('schtasks /delete /tn "OpenClawGateway" /f', { stdio: 'pipe' });
    } catch { /* ignore */ }
    try {
      execSync('sc delete OpenClawGateway', { stdio: 'pipe' });
    } catch { /* ignore */ }
  }
}

function removeDataDirectories() {
  const homeDir = os.homedir();
  const dirsToRemove = [
    path.join(homeDir, '.openclaw'),
    path.join(homeDir, '.config', 'openclaw'),
  ];

  if (process.platform === 'win32') {
    const appData = process.env.APPDATA || path.join(homeDir, 'AppData', 'Roaming');
    const localAppData = process.env.LOCALAPPDATA || path.join(homeDir, 'AppData', 'Local');
    dirsToRemove.push(path.join(appData, 'openclaw'));
    dirsToRemove.push(path.join(localAppData, 'openclaw'));
  }

  for (const dir of dirsToRemove) {
    if (fs.existsSync(dir)) {
      try {
        fs.rmSync(dir, { recursive: true, force: true });
      } catch { /* permission issue, ignore */ }
    }
  }
}

function restoreTrackedNpmRegistry() {
  const backup = installState.getBackup('npmRegistry');
  if (backup) {
    installState.restoreNpmRegistryState(backup);
  }
}

module.exports = {
  detectInstallation,
  simpleUninstall,
  completeUninstall,
  repair,
};
