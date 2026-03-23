// ============================================
// Git Mirror & NPM Registry Configuration
// ============================================

const { execSync } = require('child_process');
const installState = require('./install-state');

const GIT_MIRRORS = [
  { name: 'gitclone.com', url: 'https://gitclone.com' },
  { name: 'mirror.ghproxy.com', url: 'https://mirror.ghproxy.com' },
  { name: 'ghproxy.net', url: 'https://ghproxy.net' },
];

const NPM_REGISTRIES = [
  { name: '淘宝源 (推荐)', url: 'https://registry.npmmirror.com' },
  { name: '腾讯源', url: 'https://mirrors.cloud.tencent.com/npm/' },
  { name: '官方源 (需要代理)', url: 'https://registry.npmjs.org' },
];

/**
 * Configure Git mirror for GitHub access
 * @param {number} mirrorIndex - 0-based index into GIT_MIRRORS
 */
function configureMirror(mirrorIndex) {
  const idx = Math.max(0, Math.min(mirrorIndex, GIT_MIRRORS.length - 1));
  const mirror = GIT_MIRRORS[idx];

  try {
    installState.ensureBackup('gitMirror', installState.captureGitMirrorState);

    // Clear all old mirrors
    for (const m of GIT_MIRRORS) {
      try {
        execSync(`git config --global --unset url."${m.url}/github.com/".insteadOf`, {
          encoding: 'utf-8', stdio: 'pipe',
        });
      } catch { /* may not exist */ }
    }

    // Set new mirror (HTTPS only).
    // Use --add so multiple insteadOf rules coexist instead of overwriting each other.
    execSync(
      `git config --global --add url."${mirror.url}/github.com/".insteadOf "https://github.com/"`,
      { encoding: 'utf-8', stdio: 'pipe' }
    );

    return { success: true, mirror: mirror.name };
  } catch (err) {
    return { success: false, error: err.message };
  }
}

/**
 * Configure npm registry
 * @param {number} registryIndex - 0-based index into NPM_REGISTRIES
 */
function configureNpmRegistry(registryIndex) {
  const idx = Math.max(0, Math.min(registryIndex, NPM_REGISTRIES.length - 1));
  const registry = NPM_REGISTRIES[idx];

  try {
    installState.ensureBackup('npmRegistry', installState.captureNpmRegistryState);
    execSync(`npm config set registry ${registry.url}`, {
      encoding: 'utf-8', stdio: 'pipe',
    });
    return { success: true, registry: registry.name, url: registry.url };
  } catch (err) {
    return { success: false, error: err.message };
  }
}

/**
 * Get mirror/registry lists for UI display
 */
function getMirrorList() {
  return GIT_MIRRORS.map((m, i) => ({ index: i, name: m.name, url: m.url }));
}

function getRegistryList() {
  return NPM_REGISTRIES.map((r, i) => ({ index: i, name: r.name, url: r.url }));
}

module.exports = {
  configureMirror,
  configureNpmRegistry,
  getMirrorList,
  getRegistryList,
  GIT_MIRRORS,
  NPM_REGISTRIES,
};
