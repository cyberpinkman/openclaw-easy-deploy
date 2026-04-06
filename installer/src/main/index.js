// ============================================
// 🦞 OpenClaw Installer — Main Process
// ============================================

const { app, BrowserWindow, ipcMain, dialog, shell, clipboard } = require('electron');
const path = require('path');
const environment = require('./environment');
const nodeInstaller = require('./node-installer');
const gitConfig = require('./git-config');
const openclaw = require('./openclaw');
const uninstaller = require('./uninstaller');

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 680,
    height: 560,
    resizable: false,
    maximizable: false,
    fullscreenable: false,
    titleBarStyle: 'hiddenInset',
    backgroundColor: '#0f0f1a',
    icon: path.join(__dirname, '../renderer/assets/icon.png'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  mainWindow.loadFile(path.join(__dirname, '../renderer/index.html'));

  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: 'deny' };
  });

  if (process.argv.includes('--dev')) {
    mainWindow.webContents.openDevTools({ mode: 'detach' });
  }
}

app.whenReady().then(createWindow);
app.on('window-all-closed', () => app.quit());

// ===== IPC Handlers =====

// Initial mode detection: is OpenClaw already installed?
ipcMain.handle('detect-installation', async () => {
  return uninstaller.detectInstallation();
});

// Step 1: Environment detection
ipcMain.handle('detect-environment', async () => {
  return await environment.detectAll();
});

// Step 2: Install Node.js
ipcMain.handle('install-node', async () => {
  return await nodeInstaller.install((progress) => {
    mainWindow.webContents.send('install-progress', { component: 'node', ...progress });
  });
});

// Step 3: Configure Git mirror
ipcMain.handle('configure-git-mirror', async (event, mirrorIndex) => {
  return await gitConfig.configureMirror(mirrorIndex);
});

ipcMain.handle('configure-npm-registry', async (event, registryIndex) => {
  return await gitConfig.configureNpmRegistry(registryIndex);
});

// Step 4: Install OpenClaw
ipcMain.handle('install-openclaw', async () => {
  return await openclaw.install((progress) => {
    mainWindow.webContents.send('install-progress', { component: 'openclaw', ...progress });
  });
});

// Step 5: Launch & onboarding
ipcMain.handle('launch-dashboard', async () => openclaw.launchDashboard());
ipcMain.handle('launch-gateway', async () => openclaw.launchGateway());
ipcMain.handle('run-onboarding', async () => openclaw.runOnboarding());

// Uninstall / Repair
ipcMain.handle('simple-uninstall', async () => {
  return await uninstaller.simpleUninstall((progress) => {
    mainWindow.webContents.send('install-progress', { component: 'uninstall', ...progress });
  });
});

ipcMain.handle('complete-uninstall', async () => {
  return await uninstaller.completeUninstall((progress) => {
    mainWindow.webContents.send('install-progress', { component: 'uninstall', ...progress });
  });
});

ipcMain.handle('repair-install', async () => {
  return await uninstaller.repair((progress) => {
    mainWindow.webContents.send('install-progress', { component: 'repair', ...progress });
  });
});

// Utility
ipcMain.handle('open-external', async (event, url) => shell.openExternal(url));
ipcMain.handle('copy-text', async (event, text) => {
  clipboard.writeText(String(text || ''));
  return { success: true };
});
ipcMain.handle('quit-app', () => app.quit());
