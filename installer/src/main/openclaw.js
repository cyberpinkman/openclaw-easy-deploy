// ============================================
// OpenClaw Installation Module
// ============================================

const { exec, execSync, spawn } = require('child_process');
const { shell } = require('electron');
const fs = require('fs');
const path = require('path');
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
    const resolvedNpm = resolveNpmCommand();
    if (!resolvedNpm) {
      resolve({ success: false, error: '未找到 npm 命令。请先确认 Node.js 已正确安装。' });
      return;
    }

    const child = spawn(resolvedNpm.command, ['install', '-g', 'openclaw@latest'], {
      env: buildSpawnEnv({ SHARP_IGNORE_GLOBAL_LIBVIPS: '1' }),
      stdio: ['pipe', 'pipe', 'pipe'],
      ...resolvedNpm.options,
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
  const resolved = resolveOpenClawCommand();

  if (!resolved) {
    shell.openExternal('http://127.0.0.1:18789');
    return { success: true, warning: '未找到 openclaw 命令，已尝试直接打开控制台地址' };
  }

  try {
    await spawnDetached(resolved.command, ['dashboard'], resolved.options);
    return { success: true };
  } catch (err) {
    shell.openExternal('http://127.0.0.1:18789');
    return { success: true, warning: err.message || '启动 dashboard 失败，已尝试直接打开控制台地址' };
  }
}

/**
 * Launch OpenClaw Gateway
 */
async function launchGateway() {
  const resolved = resolveOpenClawCommand();

  if (!resolved) {
    return {
      success: false,
      error: '未找到 openclaw 命令。请关闭安装器后重新打开终端，确认 `openclaw --version` 可以运行。',
    };
  }

  try {
    await spawnDetached(resolved.command, ['gateway'], resolved.options);
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

function buildSpawnEnv(extraEnv = {}) {
  const env = { ...process.env, ...extraEnv };

  if (process.platform !== 'win32') {
    return env;
  }

  const normalized = {};
  let pathValue = '';

  for (const [key, value] of Object.entries(env)) {
    if (/^path$/i.test(key)) {
      pathValue = String(value ?? '');
      continue;
    }
    normalized[key] = value == null ? '' : String(value);
  }

  normalized.Path = pathValue;
  return normalized;
}

function resolveNpmCommand() {
  if (process.platform === 'win32') {
    refreshPathWindows();

    const candidates = [];

    try {
      const whereResult = execSync('where npm', {
        encoding: 'utf-8',
        stdio: 'pipe',
      }).trim();
      candidates.push(...whereResult.split(/\r?\n/).filter(Boolean));
    } catch { /* ignore */ }

    try {
      const npmPrefix = execSync('npm prefix -g', {
        encoding: 'utf-8',
        stdio: 'pipe',
      }).trim();
      if (npmPrefix) {
        candidates.push(path.join(npmPrefix, 'npm.cmd'));
        candidates.push(path.join(npmPrefix, 'npm'));
      }
    } catch { /* ignore */ }

    if (process.env.APPDATA) {
      candidates.push(path.join(process.env.APPDATA, 'npm', 'npm.cmd'));
      candidates.push(path.join(process.env.APPDATA, 'npm', 'npm'));
    }

    const found = candidates.find((candidate) => candidate && fs.existsSync(candidate));
    if (found) {
      return { command: found, options: { shell: false } };
    }

    return { command: 'npm.cmd', options: { shell: false } };
  }

  return { command: 'npm', options: { shell: false } };
}

function resolveOpenClawCommand() {
  if (process.platform === 'win32') {
    refreshPathWindows();

    const candidates = [];

    try {
      const whereResult = execSync('where openclaw', {
        encoding: 'utf-8',
        stdio: 'pipe',
      }).trim();
      const whereCandidates = whereResult.split(/\r?\n/).filter(Boolean);
      candidates.push(...whereCandidates);
    } catch { /* ignore */ }

    try {
      const npmPrefix = execSync('npm prefix -g', {
        encoding: 'utf-8',
        stdio: 'pipe',
      }).trim();
      if (npmPrefix) {
        candidates.push(path.join(npmPrefix, 'openclaw.cmd'));
        candidates.push(path.join(npmPrefix, 'openclaw'));
      }
    } catch { /* ignore */ }

    if (process.env.APPDATA) {
      candidates.push(path.join(process.env.APPDATA, 'npm', 'openclaw.cmd'));
      candidates.push(path.join(process.env.APPDATA, 'npm', 'openclaw'));
    }

    const found = candidates.find((candidate) => candidate && fs.existsSync(candidate));
    if (found) {
      return { command: found, options: { shell: false } };
    }

    return null;
  }

  try {
    const binPath = execSync('which openclaw', {
      encoding: 'utf-8',
      stdio: 'pipe',
    }).trim();
    if (binPath) {
      return { command: binPath, options: { shell: false } };
    }
  } catch { /* ignore */ }

  return { command: 'openclaw', options: { shell: false } };
}

function spawnDetached(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    let settled = false;

    const child = spawn(command, args, {
      detached: true,
      stdio: 'ignore',
      env: buildSpawnEnv(),
      ...options,
    });

    child.once('spawn', () => {
      if (settled) return;
      settled = true;
      child.unref();
      resolve();
    });

    child.once('error', (err) => {
      if (settled) return;
      settled = true;
      reject(err);
    });
  });
}

module.exports = { install, launchDashboard, launchGateway, runOnboarding };
