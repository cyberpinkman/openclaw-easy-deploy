// ============================================
// Environment Detection Module
// ============================================

const { execSync } = require('child_process');
const os = require('os');
const fs = require('fs');
const path = require('path');

/**
 * Detect all environment conditions
 * Returns an object with check results for UI display
 */
async function detectAll() {
  const results = {
    platform: process.platform,
    checks: [],
    needNode: false,
    needGitMirror: false,
    needOpenClaw: false,
    canProceed: true,
  };

  // 1. OS version
  const osCheck = checkOS();
  results.checks.push(osCheck);
  if (osCheck.status === 'error') results.canProceed = false;

  // 2. Memory
  const memCheck = checkMemory();
  results.checks.push(memCheck);
  if (memCheck.status === 'error') results.canProceed = false;

  // 3. Disk space
  const diskCheck = checkDisk();
  results.checks.push(diskCheck);
  if (diskCheck.status === 'error') results.canProceed = false;

  // 4. Xcode CLI Tools (macOS only)
  if (process.platform === 'darwin') {
    const xcodeCheck = checkXcode();
    results.checks.push(xcodeCheck);
  }

  // 5. Node.js
  const nodeCheck = checkNode();
  results.checks.push(nodeCheck);
  if (nodeCheck.status === 'warn') results.needNode = true;

  // 6. Git
  const gitCheck = checkGit();
  results.checks.push(gitCheck);

  // 7. GitHub connectivity
  const ghCheck = await checkGitHub();
  results.checks.push(ghCheck);
  if (ghCheck.status === 'warn') results.needGitMirror = true;

  // 8. OpenClaw
  const ocCheck = checkOpenClaw();
  results.checks.push(ocCheck);
  if (ocCheck.status === 'warn') results.needOpenClaw = true;

  return results;
}

function checkOS() {
  const platform = process.platform;

  if (platform === 'darwin') {
    try {
      const version = execSync('sw_vers -productVersion', { encoding: 'utf-8' }).trim();
      const [major, minor] = version.split('.').map(Number);
      const chip = os.arch() === 'arm64' ? 'Apple Silicon' : 'Intel';

      if (major < 10 || (major === 10 && minor < 15)) {
        return {
          name: '操作系统',
          status: 'error',
          detail: `macOS ${version} (${chip})`,
          message: '需要 macOS 10.15 (Catalina) 或更高版本',
        };
      }
      return {
        name: '操作系统',
        status: 'ok',
        detail: `macOS ${version} (${chip})`,
      };
    } catch {
      return { name: '操作系统', status: 'ok', detail: 'macOS (版本未知)' };
    }
  }

  if (platform === 'win32') {
    const release = os.release(); // e.g. "10.0.22621"
    const major = parseInt(release.split('.')[0], 10);
    if (major < 10) {
      return {
        name: '操作系统',
        status: 'error',
        detail: `Windows (NT ${release})`,
        message: '需要 Windows 10 或更高版本',
      };
    }
    return {
      name: '操作系统',
      status: 'ok',
      detail: `Windows (NT ${release})`,
    };
  }

  return { name: '操作系统', status: 'warn', detail: `${platform}`, message: '未测试的平台' };
}

function checkMemory() {
  const totalGB = Math.round(os.totalmem() / 1024 / 1024 / 1024);
  if (totalGB < 4) {
    return {
      name: '内存',
      status: 'error',
      detail: `${totalGB} GB`,
      message: '建议至少 4GB 内存',
    };
  }
  return { name: '内存', status: 'ok', detail: `${totalGB} GB` };
}

function checkDisk() {
  try {
    if (process.platform === 'darwin') {
      const output = execSync("df -g / | awk 'NR==2 {print $4}'", { encoding: 'utf-8' }).trim();
      const freeGB = parseInt(output, 10);
      if (freeGB < 2) {
        return { name: '磁盘空间', status: 'error', detail: `${freeGB} GB 可用`, message: '至少需要 2GB 可用空间' };
      }
      return { name: '磁盘空间', status: 'ok', detail: `${freeGB} GB 可用` };
    }
    if (process.platform === 'win32') {
      const output = execSync('wmic logicaldisk where "DeviceID=\'C:\'" get FreeSpace /value', { encoding: 'utf-8' });
      const match = output.match(/FreeSpace=(\d+)/);
      if (match) {
        const freeGB = Math.round(parseInt(match[1], 10) / 1024 / 1024 / 1024);
        if (freeGB < 2) {
          return { name: '磁盘空间', status: 'error', detail: `${freeGB} GB 可用`, message: '至少需要 2GB 可用空间' };
        }
        return { name: '磁盘空间', status: 'ok', detail: `${freeGB} GB 可用` };
      }
    }
  } catch { /* ignore */ }
  return { name: '磁盘空间', status: 'ok', detail: '未知' };
}

function checkXcode() {
  try {
    execSync('xcode-select -p', { encoding: 'utf-8', stdio: 'pipe' });
    execSync('xcrun --version', { encoding: 'utf-8', stdio: 'pipe' });
    return { name: 'Xcode 命令行工具', status: 'ok', detail: '已安装' };
  } catch {
    return {
      name: 'Xcode 命令行工具',
      status: 'warn',
      detail: '未安装或已损坏',
      message: '部分高级依赖可能需要，若后续安装失败再按提示安装即可',
      action: 'install-xcode',
    };
  }
}

function checkNode() {
  const resolvedNode = resolveNodeBinary();
  if (!resolvedNode) {
    return {
      name: 'Node.js',
      status: 'warn',
      detail: '未安装',
      message: '需要安装 Node.js 22+',
    };
  }

  try {
    const version = execSync(`"${resolvedNode}" -v`, { encoding: 'utf-8', stdio: 'pipe' }).trim();
    const major = parseInt(version.replace('v', '').split('.')[0], 10);

    // Test if Node.js actually works
    execSync(`"${resolvedNode}" -e "console.log(1)"`, { encoding: 'utf-8', stdio: 'pipe' });

    if (major < 22) {
      return {
        name: 'Node.js',
        status: 'warn',
        detail: `${version} (需要升级到 22+)`,
        message: '版本过低，需要安装新版本',
      };
    }
    return { name: 'Node.js', status: 'ok', detail: version };
  } catch {
    return {
      name: 'Node.js',
      status: 'warn',
      detail: '已安装但当前环境无法正常调用',
      message: '建议通过安装器重新安装或修复 Node.js',
    };
  }
}

function checkGit() {
  try {
    const output = execSync('git --version', { encoding: 'utf-8', stdio: 'pipe' }).trim();
    const version = output.replace('git version ', '');
    return { name: 'Git', status: 'ok', detail: `v${version}` };
  } catch {
    return {
      name: 'Git',
      status: 'warn',
      detail: '未安装',
      message: '需要安装 Git',
    };
  }
}

async function checkGitHub() {
  return new Promise((resolve) => {
    const https = require('https');
    const req = https.get('https://github.com', { timeout: 10000 }, (res) => {
      resolve({ name: 'GitHub 连接', status: 'ok', detail: '可以连接' });
    });
    req.on('error', () => {
      resolve({
        name: 'GitHub 连接',
        status: 'warn',
        detail: '无法连接',
        message: '需要配置镜像源',
      });
    });
    req.on('timeout', () => {
      req.destroy();
      resolve({
        name: 'GitHub 连接',
        status: 'warn',
        detail: '连接超时',
        message: '需要配置镜像源',
      });
    });
  });
}

function checkOpenClaw() {
  const resolvedOpenClaw = resolveOpenClawBinary();
  if (!resolvedOpenClaw) {
    return {
      name: '小龙虾 (OpenClaw)',
      status: 'warn',
      detail: '未安装',
      message: '需要安装',
    };
  }

  try {
    const version = execSync(`"${resolvedOpenClaw}" --version`, { encoding: 'utf-8', stdio: 'pipe' }).trim();
    return { name: '小龙虾 (OpenClaw)', status: 'ok', detail: version };
  } catch {
    return {
      name: '小龙虾 (OpenClaw)',
      status: 'warn',
      detail: '已安装但当前环境无法正常调用',
      message: '建议通过安装器重新安装或修复',
    };
  }
}

function resolveNodeBinary() {
  const candidates = [];

  try {
    if (process.platform === 'win32') {
      const whereResult = execSync('where node', { encoding: 'utf-8', stdio: 'pipe' }).trim();
      candidates.push(...whereResult.split(/\r?\n/).filter(Boolean));
    } else {
      const whichResult = execSync('which node', { encoding: 'utf-8', stdio: 'pipe' }).trim();
      if (whichResult) candidates.push(whichResult);
    }
  } catch { /* ignore */ }

  if (process.platform === 'darwin') {
    candidates.push('/usr/local/bin/node', '/opt/homebrew/bin/node');
  } else if (process.platform === 'win32') {
    const programFiles = process.env.ProgramFiles || 'C:\\Program Files';
    const localAppData = process.env.LOCALAPPDATA || '';
    const registryInstallPath = getWindowsNodeInstallPathFromRegistry();
    if (registryInstallPath) candidates.push(path.join(registryInstallPath, 'node.exe'));
    candidates.push(path.join(programFiles, 'nodejs', 'node.exe'));
    if (localAppData) candidates.push(path.join(localAppData, 'Programs', 'nodejs', 'node.exe'));
  }

  return [...new Set(candidates)].find((candidate) => candidate && fs.existsSync(candidate)) || '';
}

function resolveOpenClawBinary() {
  const candidates = [];

  try {
    if (process.platform === 'win32') {
      const whereResult = execSync('where openclaw', { encoding: 'utf-8', stdio: 'pipe' }).trim();
      candidates.push(...whereResult.split(/\r?\n/).filter(Boolean));
    } else {
      const whichResult = execSync('which openclaw', { encoding: 'utf-8', stdio: 'pipe' }).trim();
      if (whichResult) candidates.push(whichResult);
    }
  } catch { /* ignore */ }

  if (process.platform === 'darwin') {
    candidates.push('/usr/local/bin/openclaw', '/opt/homebrew/bin/openclaw');
  } else if (process.platform === 'win32') {
    const appData = process.env.APPDATA || '';
    const localAppData = process.env.LOCALAPPDATA || '';
    if (appData) {
      candidates.push(path.join(appData, 'npm', 'openclaw.cmd'));
      candidates.push(path.join(appData, 'npm', 'openclaw'));
    }
    if (localAppData) {
      candidates.push(path.join(localAppData, 'Programs', 'nodejs', 'openclaw.cmd'));
    }
  }

  return [...new Set(candidates)].find((candidate) => candidate && fs.existsSync(candidate)) || '';
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

module.exports = { detectAll };
