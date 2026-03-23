// ============================================
// Environment Detection Module
// ============================================

const { execSync, exec } = require('child_process');
const os = require('os');
const fs = require('fs');

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
    if (xcodeCheck.status === 'error') results.canProceed = false;
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
      status: 'error',
      detail: '未安装或已损坏',
      message: '需要先安装 Xcode 命令行工具',
      action: 'install-xcode',
    };
  }
}

function checkNode() {
  try {
    const version = execSync('node -v', { encoding: 'utf-8', stdio: 'pipe' }).trim();
    const major = parseInt(version.replace('v', '').split('.')[0], 10);

    // Test if Node.js actually works
    execSync('node -e "console.log(1)"', { encoding: 'utf-8', stdio: 'pipe' });

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
      detail: '未安装',
      message: '需要安装 Node.js 22+',
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
  try {
    const version = execSync('openclaw --version', { encoding: 'utf-8', stdio: 'pipe' }).trim();
    return { name: '小龙虾 (OpenClaw)', status: 'ok', detail: version };
  } catch {
    return {
      name: '小龙虾 (OpenClaw)',
      status: 'warn',
      detail: '未安装',
      message: '需要安装',
    };
  }
}

module.exports = { detectAll };
