// ============================================
// Preload script — exposes safe APIs to renderer
// ============================================

const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('installer', {
  // Initial detection
  detectInstallation: () => ipcRenderer.invoke('detect-installation'),

  // Environment detection
  detectEnvironment: () => ipcRenderer.invoke('detect-environment'),

  // Component installation
  installNode: () => ipcRenderer.invoke('install-node'),
  configureGitMirror: (idx) => ipcRenderer.invoke('configure-git-mirror', idx),
  configureNpmRegistry: (idx) => ipcRenderer.invoke('configure-npm-registry', idx),
  installOpenClaw: () => ipcRenderer.invoke('install-openclaw'),

  // Launch & onboarding
  launchDashboard: () => ipcRenderer.invoke('launch-dashboard'),
  launchGateway: () => ipcRenderer.invoke('launch-gateway'),
  runOnboarding: () => ipcRenderer.invoke('run-onboarding'),

  // Uninstall / Repair
  simpleUninstall: () => ipcRenderer.invoke('simple-uninstall'),
  completeUninstall: () => ipcRenderer.invoke('complete-uninstall'),
  repairInstall: () => ipcRenderer.invoke('repair-install'),

  // Utilities
  openExternal: (url) => ipcRenderer.invoke('open-external', url),
  quitApp: () => ipcRenderer.invoke('quit-app'),

  // Progress listener
  onProgress: (callback) => {
    ipcRenderer.on('install-progress', (event, data) => callback(data));
  },

  platform: process.platform,
});
