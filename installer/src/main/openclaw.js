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

  refreshKnownToolPaths();

  // Uninstall old version if exists
  try {
    const existingOpenClaw = resolveOpenClawCommand();
    if (existingOpenClaw) {
      execSync(`"${existingOpenClaw.command}" --version`, { encoding: 'utf-8', stdio: 'pipe' });
    } else {
      throw new Error('not installed');
    }
    onProgress({ stage: 'uninstall', message: '卸载旧版本...', percent: 5 });
    try {
      const resolvedNpm = resolveNpmCommand();
      if (resolvedNpm) {
        execSync(`"${resolvedNpm.command}" uninstall -g openclaw`, { encoding: 'utf-8', stdio: 'pipe', timeout: 60000 });
      }
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
    const resolvedSpawn = resolveNpmInstallSpawn();
    if (!resolvedSpawn) {
      resolve({
        success: false,
        error: '未找到 npm 命令。请先确认 Node.js 已正确安装。',
        errorCode: 'OPENCLAW_NPM_NOT_FOUND',
      });
      return;
    }

    const child = spawn(resolvedSpawn.command, resolvedSpawn.args, {
      env: buildSpawnEnv({ SHARP_IGNORE_GLOBAL_LIBVIPS: '1' }),
      stdio: ['pipe', 'pipe', 'pipe'],
      windowsHide: true,
      ...resolvedSpawn.options,
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
          const version = getInstalledOpenClawVersion();
          onProgress({ stage: 'done', message: `安装成功! 版本: ${version}`, percent: 100 });
          resolve({ success: true, version });
        } catch {
          refreshKnownToolPaths();
          try {
            const version = getInstalledOpenClawVersion();
            onProgress({ stage: 'done', message: `安装成功! 版本: ${version}`, percent: 100 });
            resolve({ success: true, version });
          } catch {
            resolve({ success: true, version: '已安装 (需要重启终端查看版本)' });
          }
        }
      } else {
        resolve(classifyOpenClawInstallFailure(errOutput || output || `npm install 退出码: ${code}`));
      }
    });

    child.on('error', (err) => {
      resolve(classifyOpenClawInstallFailure(err.message));
    });

    // Timeout after 10 minutes
    setTimeout(() => {
      child.kill();
      resolve({ success: false, error: '安装超时 (10分钟)', errorCode: 'OPENCLAW_INSTALL_TIMEOUT' });
    }, 600000);
  });
}

function runNpmInstallSudo(onProgress) {
  return new Promise((resolve) => {
    try {
      const resolvedNpm = resolveNpmCommand();
      if (!resolvedNpm) {
        resolve({
          success: false,
          error: '未找到 npm 命令。请先确认 Node.js 已正确安装。',
          errorCode: 'OPENCLAW_NPM_NOT_FOUND',
        });
        return;
      }
      const npmPath = resolvedNpm.command;
      const cmd = `${npmPath} install -g openclaw@latest`;

      execSync(
        `osascript -e 'do shell script "${cmd}" with administrator privileges'`,
        { encoding: 'utf-8', timeout: 600000 }
      );

      try {
        refreshKnownToolPaths();
        const version = getInstalledOpenClawVersion();
        onProgress({ stage: 'done', message: `安装成功! 版本: ${version}`, percent: 100 });
        resolve({ success: true, version });
      } catch {
        resolve({ success: true, version: '已安装' });
      }
    } catch (err) {
      resolve(classifyOpenClawInstallFailure(err.message));
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
      const resolved = resolveOpenClawCommand();
      if (!resolved) {
        return { success: false, error: '未找到 openclaw 命令。请确认安装已完成后重试。' };
      }
      refreshKnownToolPaths();
      const command = `${shellQuote(resolved.command)} onboard --install-daemon`;
      const script = [
        'tell application "Terminal"',
        'activate',
        `do script ${toAppleScriptString(command)}`,
        'end tell',
      ].join('\n');

      execSync(`osascript <<'APPLESCRIPT'\n${script}\nAPPLESCRIPT`, { encoding: 'utf-8' });
    } else if (process.platform === 'win32') {
      const resolved = resolveOpenClawCommand();
      if (!resolved) {
        return { success: false, error: '未找到 openclaw 命令。请确认安装已完成后重试。' };
      }
      refreshKnownToolPaths();
      const powershell = resolveWindowsPowerShell();
      const command = `& ${toPowerShellLiteral(resolved.command)} onboard --install-daemon`;

      if (!powershell) {
        return { success: false, error: '未找到 PowerShell，无法打开交互式配置窗口。' };
      }

      await spawnDetached(powershell, ['-NoExit', '-Command', command], {
        shell: false,
        windowsHide: false,
      });
    }
    return { success: true, warning: '配置向导已在新终端窗口中启动。' };
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

function refreshKnownToolPaths() {
  if (process.platform === 'win32') {
    refreshPathWindows();
    const registryInstallPath = getWindowsNodeInstallPathFromRegistry();
    prependPathEntries([
      registryInstallPath || '',
      process.env.APPDATA ? path.join(process.env.APPDATA, 'npm') : '',
    ]);
  } else {
    prependPathEntries(['/usr/local/bin', '/opt/homebrew/bin']);
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
    // Windows process.env 里可能带有像 '=C:' 这样的伪环境变量。
    // 这些键不能原样传给 spawn 的 env，否则会触发 EINVAL。
    if (key.startsWith('=')) {
      continue;
    }

    if (/^path$/i.test(key)) {
      pathValue = String(value ?? '');
      continue;
    }
    normalized[key] = value == null ? '' : String(value);
  }

  normalized.Path = pathValue;
  return normalized;
}

function prependPathEntries(entries) {
  const delimiter = process.platform === 'win32' ? ';' : ':';
  const currentEntries = (process.env.PATH || '').split(delimiter).filter(Boolean);
  const deduped = [...new Set([...entries.filter(Boolean), ...currentEntries])];
  process.env.PATH = deduped.join(delimiter);
}

function resolveNpmCommand() {
  if (process.platform === 'win32') {
    refreshKnownToolPaths();

    const candidates = [];

    const registryInstallPath = getWindowsNodeInstallPathFromRegistry();
    if (registryInstallPath) {
      candidates.push(path.join(registryInstallPath, 'npm.cmd'));
      candidates.push(path.join(registryInstallPath, 'npm'));
    }

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

  prependPathEntries(['/usr/local/bin', '/opt/homebrew/bin']);

  const candidates = ['/usr/local/bin/npm', '/opt/homebrew/bin/npm'];
  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return { command: candidate, options: { shell: false } };
    }
  }

  return { command: 'npm', options: { shell: false } };
}

function resolveNpmInstallSpawn() {
  const resolvedNpm = resolveNpmCommand();
  if (!resolvedNpm) {
    return null;
  }

  if (process.platform === 'win32') {
    const cmdCommand = resolveWindowsCmdCommand();
    if (!cmdCommand) {
      return null;
    }
    const npmCommand = resolvedNpm.command.includes(' ') ? `"${resolvedNpm.command}"` : resolvedNpm.command;
    return {
      command: cmdCommand,
      args: ['/d', '/s', '/c', `${npmCommand} install -g openclaw@latest`],
      options: { shell: false },
    };
  }

  return {
    command: resolvedNpm.command,
    args: ['install', '-g', 'openclaw@latest'],
    options: resolvedNpm.options,
  };
}

function resolveWindowsCmdCommand() {
  if (process.platform !== 'win32') {
    return null;
  }

  const candidates = [];

  if (process.env.ComSpec) {
    candidates.push(process.env.ComSpec);
  }

  const systemRoot = process.env.SystemRoot || process.env.WINDIR || 'C:\\Windows';
  candidates.push(path.join(systemRoot, 'System32', 'cmd.exe'));
  candidates.push(path.join(systemRoot, 'Sysnative', 'cmd.exe'));

  const found = candidates.find((candidate) => candidate && fs.existsSync(candidate));
  return found || null;
}

function resolveWindowsPowerShell() {
  if (process.platform !== 'win32') {
    return null;
  }

  const candidates = [];

  if (process.env.SystemRoot || process.env.WINDIR) {
    const systemRoot = process.env.SystemRoot || process.env.WINDIR;
    candidates.push(path.join(systemRoot, 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe'));
  }

  try {
    const whereResult = execSync('where powershell', {
      encoding: 'utf-8',
      stdio: 'pipe',
    }).trim();
    candidates.push(...whereResult.split(/\r?\n/).filter(Boolean));
  } catch { /* ignore */ }

  return candidates.find((candidate) => candidate && fs.existsSync(candidate)) || null;
}

function resolveOpenClawCommand() {
  if (process.platform === 'win32') {
    refreshKnownToolPaths();

    const candidates = [];

    const npmDir = getNpmBinDir();
    if (npmDir) {
      candidates.push(path.join(npmDir, 'openclaw.cmd'));
      candidates.push(path.join(npmDir, 'openclaw'));
    }

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

  prependPathEntries(['/usr/local/bin', '/opt/homebrew/bin']);

  const unixCandidates = ['/usr/local/bin/openclaw', '/opt/homebrew/bin/openclaw'];
  for (const candidate of unixCandidates) {
    if (fs.existsSync(candidate)) {
      return { command: candidate, options: { shell: false } };
    }
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

function getInstalledOpenClawVersion() {
  const resolved = resolveOpenClawCommand();
  if (!resolved) {
    throw new Error('未找到 openclaw 命令');
  }

  return execSync(`"${resolved.command}" --version`, { encoding: 'utf-8', stdio: 'pipe' }).trim();
}

function getNpmBinDir() {
  try {
    if (process.platform === 'win32') {
      const candidates = [];
      const registryInstallPath = getWindowsNodeInstallPathFromRegistry();
      if (registryInstallPath) candidates.push(registryInstallPath);
      if (process.env.APPDATA) candidates.push(path.join(process.env.APPDATA, 'npm'));

      return candidates.find((candidate) => candidate && fs.existsSync(candidate)) || '';
    }

    const candidates = ['/usr/local/bin', '/opt/homebrew/bin'];
    return candidates.find((candidate) => candidate && fs.existsSync(path.join(candidate, 'npm'))) || '';
  } catch {
    return '';
  }
}

function getWindowsNodeInstallPathFromRegistry() {
  if (process.platform !== 'win32') {
    return '';
  }

  const queries = [
    'reg query "HKLM\\SOFTWARE\\Node.js" /v InstallPath',
    'reg query "HKLM\\SOFTWARE\\WOW6432Node\\Node.js" /v InstallPath',
  ];

  for (const query of queries) {
    try {
      const output = execSync(query, { encoding: 'utf-8', stdio: 'pipe' });
      const match = output.match(/InstallPath\s+REG_\w+\s+([^\r\n]+)/i);
      if (match?.[1]) {
        return match[1].trim();
      }
    } catch { /* ignore */ }
  }

  return '';
}

function shellQuote(value) {
  return `'${String(value).replace(/'/g, `'\\''`)}'`;
}

function toAppleScriptString(value) {
  return `"${String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
}

function toPowerShellLiteral(value) {
  return `'${String(value).replace(/'/g, "''")}'`;
}

function classifyOpenClawInstallFailure(rawMessage) {
  const raw = String(rawMessage || '');
  const lowered = raw.toLowerCase();

  if (lowered.includes('eacces') || lowered.includes('permission denied')) {
    return {
      success: false,
      error: raw || 'OpenClaw 安装失败：权限不足。',
      errorCode: 'OPENCLAW_PERMISSION_DENIED',
    };
  }

  if (lowered.includes('registry') || lowered.includes('network') || lowered.includes('fetch') || lowered.includes('econn') || lowered.includes('socket timeout')) {
    return {
      success: false,
      error: raw || 'OpenClaw 安装失败：网络或 npm 源连接异常。',
      errorCode: 'OPENCLAW_NETWORK_FAILED',
    };
  }

  if (lowered.includes('sharp') || lowered.includes('libvips') || lowered.includes('build') || lowered.includes('gyp')) {
    return {
      success: false,
      error: raw || 'OpenClaw 安装失败：依赖编译阶段出错。',
      errorCode: 'OPENCLAW_DEPENDENCY_BUILD_FAILED',
    };
  }

  if (lowered.includes('not found') || lowered.includes('未找到 npm')) {
    return {
      success: false,
      error: raw || 'OpenClaw 安装失败：未找到 npm。',
      errorCode: 'OPENCLAW_NPM_NOT_FOUND',
    };
  }

  return {
    success: false,
    error: raw || 'OpenClaw 安装失败。',
    errorCode: 'OPENCLAW_INSTALL_FAILED',
  };
}

module.exports = { install, launchDashboard, launchGateway, runOnboarding };
