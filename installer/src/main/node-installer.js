// ============================================
// Node.js Installation Module
// ============================================

const { exec, execSync, spawn } = require('child_process');
const os = require('os');
const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');

const NODE_VERSION = '24.14.0';

// China-friendly Node.js mirror
const NODE_MIRROR = 'https://npmmirror.com/mirrors/node';
const NODE_OFFICIAL = 'https://nodejs.org/dist';

/**
 * Install Node.js with progress reporting
 */
async function install(onProgress) {
  const platform = process.platform;
  const arch = os.arch();

  onProgress({ stage: 'start', message: '正在准备安装 Node.js...' });

  // Determine the right Node.js version based on OS compatibility
  const { version, error: versionError } = determineNodeVersion();

  if (versionError || !version) {
    onProgress({ stage: 'error', message: '系统不兼容', percent: 0 });
    return { success: false, error: versionError || '无法确定适合的 Node.js 版本', incompatible: true };
  }

  onProgress({ stage: 'start', message: `将安装 Node.js ${version}...` });

  if (platform === 'darwin') {
    return await installOnMac(version, arch, onProgress);
  } else if (platform === 'win32') {
    return await installOnWindows(version, arch, onProgress);
  }

  return { success: false, error: '不支持的操作系统' };
}

/**
 * Smart Node.js version selection based on OS compatibility.
 *
 * Compatibility matrix (as of 2026):
 * ┌─────────────────────┬──────────────────────────────────┐
 * │ macOS version       │ Max supported Node.js            │
 * ├─────────────────────┼──────────────────────────────────┤
 * │ < 10.15 (< Catalina)│ 22.15.x (NOT enough for OC)     │
 * │ 10.15 - 11.x        │ 22.x LTS (22.22.1)              │
 * │ 12.x - 13.x         │ 24.x (full support)             │
 * │ 14.x+               │ 24.x (full support)             │
 * └─────────────────────┴──────────────────────────────────┘
 *
 * ┌─────────────────────┬──────────────────────────────────┐
 * │ Windows version     │ Max supported Node.js            │
 * ├─────────────────────┼──────────────────────────────────┤
 * │ < 10                │ NOT supported                    │
 * │ 10+                 │ 24.x (full support)              │
 * └─────────────────────┴──────────────────────────────────┘
 *
 * OpenClaw minimum requirement: Node.js ≥ 22.16.0
 * Node.js 22.16+ requires macOS 10.15+ (Catalina)
 *
 * Returns: { version, error }
 *   - version: the Node.js version string to install, or null if incompatible
 *   - error: error message if OS is too old, or null
 */
function determineNodeVersion() {
  if (process.platform === 'darwin') {
    try {
      const macVersion = execSync('sw_vers -productVersion', { encoding: 'utf-8' }).trim();
      const parts = macVersion.split('.').map(Number);
      const major = parts[0];
      const minor = parts[1] || 0;

      // macOS < 10.15: Cannot run Node 22.16+, which is OpenClaw's minimum
      // The highest Node.js these old systems support is 22.15.x, which is NOT enough
      if (major < 10 || (major === 10 && minor < 15)) {
        return {
          version: null,
          error: `你的系统是 macOS ${macVersion}，无法安装 OpenClaw 所需的 Node.js 22.16+。\n\n` +
                 `macOS ${macVersion} 最高只能支持 Node.js 22.15.x，但 OpenClaw 要求至少 22.16.0。\n\n` +
                 `请升级系统到至少 macOS 10.15 (Catalina)：\n` +
                 `  • 系统偏好设置 → 软件更新\n` +
                 `  • 或访问: https://support.apple.com/zh-cn/HT201372`,
        };
      }

      // macOS 10.15 - 11.x: Use Node 22.x LTS (supports 22.16+)
      if (major < 12) {
        return { version: '22.22.1', error: null };
      }

      // macOS 12+: Use latest Node 24.x
      return { version: NODE_VERSION, error: null };
    } catch {
      // Can't determine version, try latest
      return { version: NODE_VERSION, error: null };
    }
  }

  if (process.platform === 'win32') {
    const release = require('os').release();
    const major = parseInt(release.split('.')[0], 10);

    if (major < 10) {
      return {
        version: null,
        error: `你的系统是 Windows NT ${release}，无法安装 OpenClaw。\n\n` +
               `OpenClaw 需要 Node.js 22.16+，该版本仅支持 Windows 10 及以上。\n\n` +
               `请升级到 Windows 10 或 Windows 11。`,
      };
    }

    return { version: NODE_VERSION, error: null };
  }

  return { version: NODE_VERSION, error: null };
}

// ========== macOS Installation ==========
async function installOnMac(version, arch, onProgress) {
  // Method 1: Try Homebrew first
  onProgress({ stage: 'checking', message: '检查 Homebrew...' });
  const hasBrew = commandExists('brew');

  if (hasBrew) {
    onProgress({ stage: 'installing', message: '通过 Homebrew 安装 Node.js...', percent: 20 });
    try {
      execSync('HOMEBREW_NO_AUTO_UPDATE=1 brew install node', {
        encoding: 'utf-8',
        timeout: 300000,
        env: { ...process.env, HOMEBREW_NO_AUTO_UPDATE: '1', HOMEBREW_NO_INSTALL_FROM_API: '1' },
      });

      if (verifyNode()) {
        onProgress({ stage: 'done', message: 'Node.js 安装成功', percent: 100 });
        return { success: true, version: getNodeVersion() };
      }
    } catch (err) {
      onProgress({ stage: 'fallback', message: 'Homebrew 安装失败，切换到官方安装包...', percent: 30 });
    }
  }

  // Method 2: Official .pkg installer
  return await installFromPkg(version, onProgress);
}

async function installFromPkg(version, onProgress) {
  const downloadUrl = `${NODE_MIRROR}/v${version}/node-v${version}.pkg`;
  const fallbackUrl = `${NODE_OFFICIAL}/v${version}/node-v${version}.pkg`;
  const tmpFile = path.join(os.tmpdir(), 'node-installer.pkg');

  onProgress({ stage: 'downloading', message: '正在下载 Node.js 安装包...', percent: 30 });

  try {
    await downloadFile(downloadUrl, fallbackUrl, tmpFile, (percent) => {
      const totalPercent = 30 + Math.round(percent * 0.5);
      onProgress({ stage: 'downloading', message: `正在下载... ${percent}%`, percent: totalPercent });
    });

    onProgress({ stage: 'installing', message: '正在安装 (可能需要输入管理员密码)...', percent: 80, needSudo: true });

    // Install using osascript for GUI sudo prompt
    execSync(
      `osascript -e 'do shell script "installer -pkg ${tmpFile} -target /" with administrator privileges'`,
      { encoding: 'utf-8', timeout: 120000 }
    );

    // Cleanup
    try { fs.unlinkSync(tmpFile); } catch { /* ignore */ }

    // Refresh PATH
    process.env.PATH = `/usr/local/bin:/opt/homebrew/bin:${process.env.PATH}`;

    if (verifyNode()) {
      onProgress({ stage: 'done', message: 'Node.js 安装成功!', percent: 100 });
      return { success: true, version: getNodeVersion() };
    }

    return { success: false, error: 'Node.js 安装后无法运行' };
  } catch (err) {
    try { fs.unlinkSync(tmpFile); } catch { /* ignore */ }
    return { success: false, error: `安装失败: ${err.message}` };
  }
}

// ========== Windows Installation ==========
async function installOnWindows(version, arch, onProgress) {
  // Method 1: Try winget
  onProgress({ stage: 'checking', message: '检查 winget...', percent: 10 });

  if (commandExists('winget')) {
    onProgress({ stage: 'installing', message: '通过 winget 安装 Node.js...', percent: 20 });
    try {
      execSync('winget install OpenJS.NodeJS --accept-source-agreements --accept-package-agreements', {
        encoding: 'utf-8',
        timeout: 300000,
      });

      refreshPathWindows();

      if (verifyNode()) {
        onProgress({ stage: 'done', message: 'Node.js 安装成功!', percent: 100 });
        return { success: true, version: getNodeVersion() };
      }
    } catch {
      onProgress({ stage: 'fallback', message: 'winget 安装失败，切换到官方安装包...', percent: 30 });
    }
  }

  // Method 2: Official .msi installer
  return await installFromMsi(version, arch, onProgress);
}

async function installFromMsi(version, arch, onProgress) {
  const archSuffix = arch === 'arm64' ? '-arm64' : '-x64';
  const downloadUrl = `${NODE_MIRROR}/v${version}/node-v${version}${archSuffix}.msi`;
  const fallbackUrl = `${NODE_OFFICIAL}/v${version}/node-v${version}${archSuffix}.msi`;
  const tmpFile = path.join(os.tmpdir(), 'node-installer.msi');

  onProgress({ stage: 'downloading', message: '正在下载 Node.js 安装包...', percent: 30 });

  try {
    await downloadFile(downloadUrl, fallbackUrl, tmpFile, (percent) => {
      const totalPercent = 30 + Math.round(percent * 0.5);
      onProgress({ stage: 'downloading', message: `正在下载... ${percent}%`, percent: totalPercent });
    });

    onProgress({ stage: 'installing', message: '正在安装...', percent: 80 });

    execSync(`msiexec /i "${tmpFile}" /passive /norestart`, {
      encoding: 'utf-8',
      timeout: 300000,
    });

    try { fs.unlinkSync(tmpFile); } catch { /* ignore */ }

    refreshPathWindows();

    // Wait a moment for PATH to settle
    await new Promise((r) => setTimeout(r, 3000));

    if (verifyNode()) {
      onProgress({ stage: 'done', message: 'Node.js 安装成功!', percent: 100 });
      return { success: true, version: getNodeVersion() };
    }

    return { success: false, error: 'Node.js 安装成功但需要重启终端' };
  } catch (err) {
    try { fs.unlinkSync(tmpFile); } catch { /* ignore */ }
    return { success: false, error: `安装失败: ${err.message}` };
  }
}

// ========== Utilities ==========

function downloadFile(primaryUrl, fallbackUrl, dest, onProgress) {
  return new Promise((resolve, reject) => {
    const tryDownload = (url, isFallback) => {
      const client = url.startsWith('https') ? https : http;

      const req = client.get(url, { timeout: 30000 }, (res) => {
        // Handle redirects
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          tryDownload(res.headers.location, isFallback);
          return;
        }

        if (res.statusCode !== 200) {
          if (!isFallback && fallbackUrl) {
            tryDownload(fallbackUrl, true);
            return;
          }
          reject(new Error(`下载失败 (HTTP ${res.statusCode})`));
          return;
        }

        const totalSize = parseInt(res.headers['content-length'] || '0', 10);
        let downloaded = 0;
        const file = fs.createWriteStream(dest);

        res.on('data', (chunk) => {
          downloaded += chunk.length;
          if (totalSize > 0) {
            const percent = Math.round((downloaded / totalSize) * 100);
            onProgress(percent);
          }
        });

        res.pipe(file);
        file.on('finish', () => {
          file.close();
          resolve();
        });
        file.on('error', (err) => {
          fs.unlinkSync(dest);
          reject(err);
        });
      });

      req.on('error', (err) => {
        if (!isFallback && fallbackUrl) {
          tryDownload(fallbackUrl, true);
          return;
        }
        reject(err);
      });

      req.on('timeout', () => {
        req.destroy();
        if (!isFallback && fallbackUrl) {
          tryDownload(fallbackUrl, true);
          return;
        }
        reject(new Error('下载超时'));
      });
    };

    tryDownload(primaryUrl, false);
  });
}

function commandExists(cmd) {
  try {
    if (process.platform === 'win32') {
      execSync(`where ${cmd}`, { encoding: 'utf-8', stdio: 'pipe' });
    } else {
      execSync(`which ${cmd}`, { encoding: 'utf-8', stdio: 'pipe' });
    }
    return true;
  } catch {
    return false;
  }
}

function verifyNode() {
  try {
    execSync('node -e "console.log(1)"', { encoding: 'utf-8', stdio: 'pipe' });
    return true;
  } catch {
    return false;
  }
}

function getNodeVersion() {
  try {
    return execSync('node -v', { encoding: 'utf-8', stdio: 'pipe' }).trim();
  } catch {
    return 'unknown';
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

module.exports = { install };
