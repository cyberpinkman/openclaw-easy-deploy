// ============================================
// Node.js Installation Module
// ============================================

const { execSync } = require('child_process');
const os = require('os');
const fs = require('fs');
const path = require('path');
const https = require('https');
const http = require('http');

// Use a compatibility-aware strategy:
// - Older supported systems stay on Node 22 LTS
// - Modern systems use the current recommended 24.x line
const NODE_LTS_VERSION = '22.22.1';
const NODE_CURRENT_VERSION = '24.14.0';

// China-friendly Node.js mirror
const NODE_MIRROR = 'https://npmmirror.com/mirrors/node';
const NODE_OFFICIAL = 'https://nodejs.org/dist';

/**
 * Install Node.js with progress reporting
 */
async function install(onProgress) {
  const platform = process.platform;
  onProgress({ stage: 'start', message: '正在准备安装 Node.js...' });

  // Determine the right Node.js version based on OS compatibility
  const { version, error: versionError } = determineNodeVersion();

  if (versionError || !version) {
    onProgress({ stage: 'error', message: '系统不兼容', percent: 0 });
    return {
      success: false,
      error: versionError || '无法确定适合的 Node.js 版本',
      errorCode: 'NODE_SYSTEM_INCOMPATIBLE',
      incompatible: true,
    };
  }

  onProgress({ stage: 'start', message: `将安装 Node.js ${version}...` });

  if (platform === 'darwin') {
    return await installOnMac(version, onProgress);
  } else if (platform === 'win32') {
    return await installOnWindows(version, os.arch(), onProgress);
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

      // macOS 10.15 - 11.x: stay on Node 22 LTS for maximum compatibility
      if (major < 12) {
        return { version: NODE_LTS_VERSION, error: null };
      }

      // macOS 12+: use the current recommended 24.x line
      return { version: NODE_CURRENT_VERSION, error: null };
    } catch {
      return { version: NODE_CURRENT_VERSION, error: null };
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

    return { version: NODE_CURRENT_VERSION, error: null };
  }

  return { version: NODE_CURRENT_VERSION, error: null };
}

// ========== macOS Installation ==========
async function installOnMac(version, onProgress) {
  // Official .pkg is the most stable path for non-technical users.
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

    refreshNodePath();

    const verification = verifyNodeInstallation();
    if (verification.ok) {
      const suffix = verification.needsShellRefresh ? '，安装器已自动刷新环境' : '';
      onProgress({ stage: 'done', message: `Node.js 安装成功${suffix}!`, percent: 100 });
      return {
        success: true,
        version: verification.version,
        warning: verification.needsShellRefresh ? 'Node.js 已安装成功，安装器已自动刷新环境变量。' : undefined,
      };
    }

    return {
      success: false,
      error: verification.error || 'Node.js 安装后无法运行',
      errorCode: 'NODE_VERIFY_FAILED',
    };
  } catch (err) {
    try { fs.unlinkSync(tmpFile); } catch { /* ignore */ }
    return classifyNodeInstallerError(err, 'pkg');
  }
}

// ========== Windows Installation ==========
async function installOnWindows(version, arch, onProgress) {
  // Official .msi is the most stable path for non-technical users.
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

    refreshNodePath();

    // Give Windows Installer a moment to finish registry and PATH writes.
    await new Promise((r) => setTimeout(r, 3000));

    const verification = verifyNodeInstallation();
    if (verification.ok) {
      const suffix = verification.needsShellRefresh ? '，安装器已自动刷新环境' : '';
      onProgress({ stage: 'done', message: `Node.js 安装成功${suffix}!`, percent: 100 });
      return {
        success: true,
        version: verification.version,
        warning: verification.needsShellRefresh ? 'Node.js 已安装成功，安装器已自动刷新环境变量。' : undefined,
      };
    }

    return {
      success: false,
      error: verification.error || 'Node.js 安装后无法运行',
      errorCode: 'NODE_VERIFY_FAILED',
    };
  } catch (err) {
    try { fs.unlinkSync(tmpFile); } catch { /* ignore */ }
    return classifyNodeInstallerError(err, 'msi');
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

function verifyNodeInstallation() {
  const candidatePaths = getNodeCandidatePaths();
  let sawInstalledBinary = false;

  for (const candidate of candidatePaths) {
    if (!candidate) continue;

    try {
      const version = execSync(`"${candidate}" -v`, { encoding: 'utf-8', stdio: 'pipe' }).trim();
      execSync(`"${candidate}" -e "console.log(1)"`, { encoding: 'utf-8', stdio: 'pipe' });

      sawInstalledBinary = true;
      addNodeDirToPath(path.dirname(candidate));

      const currentNode = getNodeCommandPath();
      const needsShellRefresh = !currentNode || path.resolve(currentNode) !== path.resolve(candidate);

      return { ok: true, version, nodePath: candidate, needsShellRefresh };
    } catch {
      if (fs.existsSync(candidate)) {
        sawInstalledBinary = true;
      }
    }
  }

  return {
    ok: false,
    error: sawInstalledBinary ? 'Node.js 已安装，但当前系统环境尚未正确识别。' : '未找到可用的 Node.js 可执行文件。',
  };
}

function getNodeCandidatePaths() {
  const paths = [];

  const currentNode = getNodeCommandPath();
  if (currentNode) paths.push(currentNode);

  if (process.platform === 'darwin') {
    paths.push('/usr/local/bin/node', '/opt/homebrew/bin/node');
  } else if (process.platform === 'win32') {
    const programFiles = process.env.ProgramFiles || 'C:\\Program Files';
    const localAppData = process.env.LOCALAPPDATA || '';
    const registryInstallPath = getWindowsNodeInstallPathFromRegistry();
    paths.push(
      registryInstallPath ? path.join(registryInstallPath, 'node.exe') : '',
      path.join(programFiles, 'nodejs', 'node.exe'),
      localAppData ? path.join(localAppData, 'Programs', 'nodejs', 'node.exe') : ''
    );
  }

  return [...new Set(paths.filter(Boolean))];
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

function getNodeCommandPath() {
  try {
    if (process.platform === 'win32') {
      return execSync('where node', { encoding: 'utf-8', stdio: 'pipe' })
        .split(/\r?\n/)
        .map((line) => line.trim())
        .find(Boolean) || null;
    }

    return execSync('which node', { encoding: 'utf-8', stdio: 'pipe' }).trim();
  } catch {
    return null;
  }
}

function addNodeDirToPath(dir) {
  if (!dir) return;

  const delimiter = process.platform === 'win32' ? ';' : ':';
  const current = (process.env.PATH || '').split(delimiter).filter(Boolean);

  if (!current.includes(dir)) {
    process.env.PATH = [dir, ...current].join(delimiter);
  }
}

function refreshNodePath() {
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
  } else {
    process.env.PATH = `/usr/local/bin:/opt/homebrew/bin:${process.env.PATH}`;
  }
}

function classifyNodeInstallerError(err, method) {
  const raw = String(err?.message || err || '');
  const lowered = raw.toLowerCase();

  if (lowered.includes('http') || lowered.includes('download') || lowered.includes('timeout') || lowered.includes('下载')) {
    return {
      success: false,
      error: `Node.js 安装包下载失败: ${raw}`,
      errorCode: 'NODE_DOWNLOAD_FAILED',
    };
  }

  if (lowered.includes('administrator privileges') || lowered.includes('installer') || lowered.includes('msiexec') || lowered.includes('权限')) {
    return {
      success: false,
      error: `Node.js 安装程序执行失败: ${raw}`,
      errorCode: method === 'pkg' ? 'NODE_PKG_INSTALL_FAILED' : 'NODE_MSI_INSTALL_FAILED',
    };
  }

  return {
    success: false,
    error: `Node.js 安装失败: ${raw}`,
    errorCode: 'NODE_INSTALL_FAILED',
  };
}

module.exports = { install };
