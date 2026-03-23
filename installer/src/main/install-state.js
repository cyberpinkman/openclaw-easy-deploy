// ============================================
// Installer state tracking for precise rollback
// ============================================

const { execSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const STATE_VERSION = 1;

function getStateFilePath() {
  const homeDir = os.homedir();
  if (process.platform === 'win32') {
    const appData = process.env.APPDATA || path.join(homeDir, 'AppData', 'Roaming');
    return path.join(appData, 'openclaw', 'install-state.json');
  }
  return path.join(homeDir, '.openclaw', 'install-state.json');
}

function ensureStateDir() {
  fs.mkdirSync(path.dirname(getStateFilePath()), { recursive: true });
}

function loadState() {
  try {
    return JSON.parse(fs.readFileSync(getStateFilePath(), 'utf8'));
  } catch {
    return {
      version: STATE_VERSION,
      createdAt: new Date().toISOString(),
      backups: {}
    };
  }
}

function saveState(state) {
  ensureStateDir();
  state.version = STATE_VERSION;
  state.updatedAt = new Date().toISOString();
  fs.writeFileSync(getStateFilePath(), JSON.stringify(state, null, 2), 'utf8');
}

function ensureBackup(key, collector) {
  const state = loadState();
  if (!state.backups[key]) {
    state.backups[key] = {
      capturedAt: new Date().toISOString(),
      value: collector()
    };
    saveState(state);
  }
  return state.backups[key].value;
}

function getBackup(key) {
  return loadState().backups[key]?.value ?? null;
}

function clearState() {
  try {
    fs.unlinkSync(getStateFilePath());
  } catch {
    // ignore missing state
  }
}

function safeExec(command) {
  try {
    return execSync(command, { encoding: 'utf8', stdio: 'pipe' }).trim();
  } catch {
    return null;
  }
}

function captureGitMirrorState() {
  const mirrors = [
    'https://gitclone.com',
    'https://mirror.ghproxy.com',
    'https://ghproxy.net'
  ];

  return mirrors.map((mirror) => {
    const output = safeExec(`git config --global --get-all url."${mirror}/github.com/".insteadOf`);
    return {
      mirror,
      values: output ? output.split('\n').map((value) => value.trim()).filter(Boolean) : []
    };
  });
}

function restoreGitMirrorState(snapshot) {
  const mirrors = Array.isArray(snapshot) ? snapshot : [];

  for (const { mirror } of mirrors) {
    try {
      execSync(`git config --global --unset-all url."${mirror}/github.com/".insteadOf`, { stdio: 'pipe' });
    } catch {
      // ignore missing config
    }
  }

  for (const { mirror, values } of mirrors) {
    for (const value of values || []) {
      execSync(
        `git config --global --add url."${mirror}/github.com/".insteadOf "${value}"`,
        { stdio: 'pipe' }
      );
    }
  }
}

function captureNpmRegistryState() {
  const output = safeExec('npm config get registry --location=user');
  if (!output || output === 'undefined' || output === 'null') {
    return { explicit: false, value: null };
  }
  return { explicit: true, value: output };
}

function restoreNpmRegistryState(snapshot) {
  if (!snapshot || !snapshot.explicit || !snapshot.value) {
    try {
      execSync('npm config delete registry', { stdio: 'pipe' });
    } catch {
      // ignore
    }
    return;
  }

  execSync(`npm config set registry ${snapshot.value}`, { stdio: 'pipe' });
}

function parseMacProxyOutput(output) {
  const result = {};
  for (const line of output.split('\n')) {
    const match = line.match(/^([^:]+):\s*(.*)$/);
    if (match) {
      result[match[1].trim()] = match[2].trim();
    }
  }
  return {
    enabled: result.Enabled === 'Yes',
    server: result.Server || '',
    port: result.Port || '',
    authenticated: result.Authenticated === 'Yes'
  };
}

function captureMacProxyState() {
  const servicesOutput = safeExec('networksetup -listallnetworkservices');
  const services = (servicesOutput || '')
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line && !line.includes('*') && !line.includes('denotes'));

  return services.map((service) => ({
    service,
    web: parseMacProxyOutput(safeExec(`networksetup -getwebproxy "${service}"`) || ''),
    secure: parseMacProxyOutput(safeExec(`networksetup -getsecurewebproxy "${service}"`) || ''),
    socks: parseMacProxyOutput(safeExec(`networksetup -getsocksfirewallproxy "${service}"`) || '')
  }));
}

function restoreMacProxyState(snapshot) {
  for (const serviceState of snapshot || []) {
    const service = serviceState.service;
    restoreMacProxyEntry(service, 'web', serviceState.web);
    restoreMacProxyEntry(service, 'secure', serviceState.secure);
    restoreMacProxyEntry(service, 'socks', serviceState.socks);
  }
}

function restoreMacProxyEntry(service, kind, state) {
  if (!state) {
    return;
  }

  const commands = {
    web: {
      set: `networksetup -setwebproxy "${service}" "${state.server}" "${state.port}"`,
      enable: `networksetup -setwebproxystate "${service}" on`,
      disable: `networksetup -setwebproxystate "${service}" off`
    },
    secure: {
      set: `networksetup -setsecurewebproxy "${service}" "${state.server}" "${state.port}"`,
      enable: `networksetup -setsecurewebproxystate "${service}" on`,
      disable: `networksetup -setsecurewebproxystate "${service}" off`
    },
    socks: {
      set: `networksetup -setsocksfirewallproxy "${service}" "${state.server}" "${state.port}"`,
      enable: `networksetup -setsocksfirewallproxystate "${service}" on`,
      disable: `networksetup -setsocksfirewallproxystate "${service}" off`
    }
  };

  const command = commands[kind];
  if (!command) {
    return;
  }

  try {
    if (state.enabled && state.server && state.port) {
      execSync(command.set, { stdio: 'pipe' });
      execSync(command.enable, { stdio: 'pipe' });
    } else {
      execSync(command.disable, { stdio: 'pipe' });
    }
  } catch {
    // ignore unsupported services
  }
}

function readWindowsRegistryValue(name) {
  const output = safeExec(
    `reg query "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" /v ${name}`
  );

  if (!output) {
    return { exists: false, value: null };
  }

  const match = output.match(new RegExp(`${name}\\s+REG_\\w+\\s+(.*)$`, 'm'));
  return {
    exists: Boolean(match),
    value: match ? match[1].trim() : null
  };
}

function captureWindowsProxyState() {
  return {
    ProxyEnable: readWindowsRegistryValue('ProxyEnable'),
    ProxyServer: readWindowsRegistryValue('ProxyServer'),
    ProxyOverride: readWindowsRegistryValue('ProxyOverride'),
    AutoConfigURL: readWindowsRegistryValue('AutoConfigURL')
  };
}

function restoreWindowsProxyState(snapshot) {
  for (const [name, record] of Object.entries(snapshot || {})) {
    try {
      if (!record?.exists) {
        execSync(
          `reg delete "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" /v ${name} /f`,
          { stdio: 'pipe' }
        );
      } else {
        const type = name === 'ProxyEnable' ? 'REG_DWORD' : 'REG_SZ';
        execSync(
          `reg add "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" /v ${name} /t ${type} /d "${record.value}" /f`,
          { stdio: 'pipe' }
        );
      }
    } catch {
      // ignore restore failures per key
    }
  }
}

function captureSystemProxyState() {
  if (process.platform === 'darwin') {
    return { platform: 'darwin', value: captureMacProxyState() };
  }
  if (process.platform === 'win32') {
    return { platform: 'win32', value: captureWindowsProxyState() };
  }
  return { platform: process.platform, value: null };
}

function restoreSystemProxyState(snapshot) {
  if (!snapshot) {
    return;
  }

  if (snapshot.platform === 'darwin') {
    restoreMacProxyState(snapshot.value);
  } else if (snapshot.platform === 'win32') {
    restoreWindowsProxyState(snapshot.value);
  }
}

module.exports = {
  getStateFilePath,
  loadState,
  saveState,
  ensureBackup,
  getBackup,
  clearState,
  captureGitMirrorState,
  restoreGitMirrorState,
  captureNpmRegistryState,
  restoreNpmRegistryState,
  captureSystemProxyState,
  restoreSystemProxyState
};
