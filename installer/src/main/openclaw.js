// ============================================
// OpenClaw Installation Module
// ============================================

const { exec, execSync, spawn } = require('child_process');
const { shell } = require('electron');
const installState = require('./install-state');

/**
 * Install OpenClaw via npm with progress reporting
 */
async function install(onProgress) {
  onProgress({ stage: 'start', message: '正在准备安装小龙虾...', percent: 0 });

  // Uninstall old version if exists
  try {
    execSync('openclaw --version', { encoding: 'utf-8', stdio: 'pipe' });
    onProgress({ stage: 'uninstall', message: '卸载旧版本...', percent: 5 });
    try {
      execSync('npm uninstall -g openclaw', { encoding: 'utf-8', stdio: 'pipe', timeout: 60000 });
    } catch { /* ignore */ }
  } catch { /* not installed */ }

  // Set environment variables
  process.env.SHARP_IGNORE_GLOBAL_LIBVIPS = '1';

  onProgress({ stage: 'installing', message: '正在安装小龙虾 (openclaw)...', percent: 10 });

  // Try install without sudo first
  const result = await runNpmInstall(onProgress, false);

  if (result.success) {
    return result;
  }

  // On macOS, try with sudo using osascript for GUI prompt
  if (process.platform === 'darwin') {
    onProgress({ stage: 'sudo', message: '普通安装失败，尝试使用管理员权限...', percent: 50, needSudo: true });
    const sudoResult = await runNpmInstallSudo(onProgress);
    if (sudoResult.success) {
      return sudoResult;
    }
  }

  return { success: false, error: result.error || '安装失败' };
}

function runNpmInstall(onProgress, isSudo) {
  return new Promise((resolve) => {
    const npmCmd = process.platform === 'win32' ? 'npm.cmd' : 'npm';
    const child = spawn(npmCmd, ['install', '-g', 'openclaw@latest'], {
      env: { ...process.env, SHARP_IGNORE_GLOBAL_LIBVIPS: '1' },
      stdio: ['pipe', 'pipe', 'pipe'],
    });

    let output = '';
    let errOutput = '';
    let lineCount = 0;

    child.stdout.on('data', (data) => {
      const text = data.toString();
      output += text;
      lineCount++;

      // Simulate progress based on npm output lines
      const percent = Math.min(10 + Math.round(lineCount * 2), 90);
      onProgress({
        stage: 'installing',
        message: '正在安装...',
        percent,
        log: text.trim(),
      });
    });

    child.stderr.on('data', (data) => {
      const text = data.toString();
      errOutput += text;

      // npm writes progress/warnings to stderr
      if (text.includes('npm warn') || text.includes('npm notice')) {
        onProgress({ stage: 'installing', message: '正在安装...', log: text.trim() });
      }
    });

    child.on('close', (code) => {
      if (code === 0) {
        // Verify installation
        try {
          const version = execSync('openclaw --version', { encoding: 'utf-8', stdio: 'pipe' }).trim();
          onProgress({ stage: 'done', message: `安装成功! 版本: ${version}`, percent: 100 });
          resolve({ success: true, version });
        } catch {
          // Try refresh PATH on Windows
          if (process.platform === 'win32') {
            refreshPathWindows();
          }
          try {
            const version = execSync('openclaw --version', { encoding: 'utf-8', stdio: 'pipe' }).trim();
            onProgress({ stage: 'done', message: `安装成功! 版本: ${version}`, percent: 100 });
            resolve({ success: true, version });
          } catch {
            resolve({ success: true, version: '已安装 (需要重启终端查看版本)' });
          }
        }
      } else {
        resolve({ success: false, error: errOutput || `npm install 退出码: ${code}` });
      }
    });

    child.on('error', (err) => {
      resolve({ success: false, error: err.message });
    });

    // Timeout after 10 minutes
    setTimeout(() => {
      child.kill();
      resolve({ success: false, error: '安装超时 (10分钟)' });
    }, 600000);
  });
}

function runNpmInstallSudo(onProgress) {
  return new Promise((resolve) => {
    try {
      const npmPath = execSync('which npm', { encoding: 'utf-8', stdio: 'pipe' }).trim();
      const cmd = `${npmPath} install -g openclaw@latest`;

      execSync(
        `osascript -e 'do shell script "${cmd}" with administrator privileges'`,
        { encoding: 'utf-8', timeout: 600000 }
      );

      try {
        const version = execSync('openclaw --version', { encoding: 'utf-8', stdio: 'pipe' }).trim();
        onProgress({ stage: 'done', message: `安装成功! 版本: ${version}`, percent: 100 });
        resolve({ success: true, version });
      } catch {
        resolve({ success: true, version: '已安装' });
      }
    } catch (err) {
      resolve({ success: false, error: err.message });
    }
  });
}

/**
 * Launch OpenClaw Dashboard (opens browser)
 */
async function launchDashboard() {
  try {
    const child = spawn('openclaw', ['dashboard'], {
      detached: true,
      stdio: 'ignore',
    });
    child.unref();
    return { success: true };
  } catch (err) {
    // Fallback: open URL directly
    shell.openExternal('http://127.0.0.1:18789');
    return { success: true };
  }
}

/**
 * Launch OpenClaw Gateway
 */
async function launchGateway() {
  try {
    const child = spawn('openclaw', ['gateway'], {
      detached: true,
      stdio: 'ignore',
    });
    child.unref();
    return { success: true };
  } catch (err) {
    return { success: false, error: err.message };
  }
}

/**
 * Run OpenClaw Onboarding in a terminal
 */
async function runOnboarding() {
  try {
    installState.ensureBackup('systemProxy', installState.captureSystemProxyState);

    if (process.platform === 'darwin') {
      execSync(
        `osascript -e 'tell application "Terminal" to do script "openclaw onboard --install-daemon"'`,
        { encoding: 'utf-8' }
      );
    } else if (process.platform === 'win32') {
      spawn('cmd.exe', ['/c', 'start', 'cmd', '/k', 'openclaw onboard --install-daemon'], {
        detached: true,
        stdio: 'ignore',
      });
    }
    return { success: true };
  } catch (err) {
    return { success: false, error: err.message };
  }
}

function refreshPathWindows() {
  if (process.platform === 'win32') {
    try {
      const machinePath = execSync(
        'reg query "HKLM\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Environment" /v Path',
        { encoding: 'utf-8', stdio: 'pipe' }
      ).match(/REG_\w+\s+(.*)/)?.[1] || '';
      const userPath = execSync(
        'reg query "HKCU\\Environment" /v Path',
        { encoding: 'utf-8', stdio: 'pipe' }
      ).match(/REG_\w+\s+(.*)/)?.[1] || '';
      process.env.PATH = `${machinePath};${userPath}`;
    } catch { /* ignore */ }
  }
}

module.exports = { install, launchDashboard, launchGateway, runOnboarding };
