// ============================================
// 🦞 OpenClaw Installer — Renderer Logic
// ============================================

(function () {
  'use strict';

  // ===== State =====
  const state = {
    currentPage: 'welcome',
    envResults: null,
    needNode: false,
    needGitMirror: false,
    needOpenClaw: false,
    installing: false,
  };

  // ===== DOM references =====
  const $ = (sel) => document.querySelector(sel);
  const $$ = (sel) => document.querySelectorAll(sel);

  // ===== Page Navigation =====
  const pages = ['welcome', 'detect', 'install', 'config', 'complete'];
  const specialPages = ['mode', 'uninstall', 'uninstall-progress', 'error'];

  function showPage(name) {
    // Hide all pages
    $$('.page').forEach((p) => p.classList.remove('active'));

    // Show target page
    const page = $(`#page-${name}`);
    if (page) {
      page.classList.add('active');
      state.currentPage = name;
    }

    // Update step indicators (only for main flow pages)
    const stepIdx = pages.indexOf(name);
    if (stepIdx >= 0) {
      $('#steps-bar').style.display = '';
      $$('.step-indicator').forEach((el, i) => {
        el.classList.remove('active', 'done');
        if (i < stepIdx) el.classList.add('done');
        if (i === stepIdx) el.classList.add('active');
      });
      $$('.step-line').forEach((el, i) => {
        el.classList.toggle('done', i < stepIdx);
      });
    } else {
      // Hide step bar on special pages
      $('#steps-bar').style.display = 'none';
    }
  }

  // ===== Initialization =====
  async function init() {
    // Check if OpenClaw is already installed
    try {
      const installation = await window.installer.detectInstallation();
      if (installation.installed) {
        $('#mode-version').textContent = `当前版本: ${installation.version || '未知'}`;
        showPage('mode');
        return;
      }
    } catch { /* not installed, proceed normally */ }

    showPage('welcome');
  }

  // ===== Event Listeners =====

  // --- Welcome page ---
  $('#btn-start').addEventListener('click', () => {
    showPage('detect');
    runDetection();
  });

  // --- Mode page (already installed) ---
  $('#btn-mode-reinstall').addEventListener('click', () => {
    showPage('welcome');
  });

  $('#btn-mode-repair').addEventListener('click', async () => {
    showPage('uninstall-progress');
    $('#uninstall-title').textContent = '正在修复安装...';
    await runRepair();
  });

  $('#btn-mode-uninstall').addEventListener('click', () => {
    showPage('uninstall');
  });

  // --- Uninstall page ---
  $('#btn-uninstall-back').addEventListener('click', () => {
    showPage('mode');
  });

  $('#btn-uninstall-simple').addEventListener('click', async () => {
    showPage('uninstall-progress');
    $('#uninstall-title').textContent = '正在卸载...';
    await runUninstall('simple');
  });

  $('#btn-uninstall-complete').addEventListener('click', async () => {
    showPage('uninstall-progress');
    $('#uninstall-title').textContent = '正在完全卸载...';
    await runUninstall('complete');
  });

  $('#btn-uninstall-close').addEventListener('click', () => {
    window.installer.quitApp();
  });

  // --- Detect page ---
  $('#btn-detect-back').addEventListener('click', () => showPage('welcome'));
  $('#btn-detect-next').addEventListener('click', () => {
    preparInstallPage();
    showPage('install');
  });

  // --- Install page ---
  $('#btn-install-start').addEventListener('click', () => runInstallation());
  $('#btn-install-next').addEventListener('click', () => showPage('config'));

  // --- Config page ---
  $('#btn-onboarding').addEventListener('click', async () => {
    await window.installer.runOnboarding();
    showPage('complete');
  });

  $('#btn-skip-config').addEventListener('click', () => showPage('complete'));

  // --- Complete page ---
  $('#btn-dashboard').addEventListener('click', () => window.installer.launchDashboard());
  $('#btn-gateway').addEventListener('click', () => window.installer.launchGateway());
  $('#btn-close').addEventListener('click', () => window.installer.quitApp());

  // --- Error page ---
  $('#btn-retry').addEventListener('click', () => {
    showPage('welcome');
  });

  // --- External links ---
  document.addEventListener('click', (e) => {
    const linkBtn = e.target.closest('[data-url]');
    if (linkBtn) {
      e.preventDefault();
      window.installer.openExternal(linkBtn.dataset.url);
    }
  });

  // --- Radio option styling ---
  document.addEventListener('change', (e) => {
    if (e.target.type === 'radio') {
      const group = e.target.closest('.radio-group');
      if (group) {
        group.querySelectorAll('.radio-option').forEach((opt) => opt.classList.remove('selected'));
        e.target.closest('.radio-option').classList.add('selected');
      }
    }
  });

  // --- Log toggle ---
  $('#btn-toggle-log').addEventListener('click', () => {
    const content = $('#log-content');
    const btn = $('#btn-toggle-log');
    if (content.classList.contains('expanded')) {
      content.classList.remove('expanded');
      btn.textContent = '展开';
    } else {
      content.classList.add('expanded');
      btn.textContent = '收起';
    }
  });

  // ===== Progress Listener =====
  window.installer.onProgress((data) => {
    if (data.component === 'node') {
      updateNodeProgress(data);
    } else if (data.component === 'openclaw') {
      updateOpenClawProgress(data);
    } else if (data.component === 'uninstall' || data.component === 'repair') {
      updateUninstallProgress(data);
    }
  });

  // ===== Environment Detection =====
  async function runDetection() {
    const checkList = $('#check-list');
    checkList.innerHTML = '';
    $('#detect-summary').style.display = 'none';
    $('#btn-detect-next').disabled = true;

    try {
      // Show loading items
      const loadingNames = ['操作系统', '内存', '磁盘空间'];
      if (window.installer.platform === 'darwin') loadingNames.push('Xcode 命令行工具');
      loadingNames.push('Node.js', 'Git', 'GitHub 连接', '小龙虾 (OpenClaw)');

      for (const name of loadingNames) {
        addCheckItem(checkList, name, 'loading');
      }

      // Run detection
      const results = await window.installer.detectEnvironment();
      state.envResults = results;
      state.needNode = results.needNode;
      state.needGitMirror = results.needGitMirror;
      state.needOpenClaw = results.needOpenClaw;

      // Update UI with results
      checkList.innerHTML = '';
      for (const check of results.checks) {
        addCheckResult(checkList, check);
      }

      // Show summary
      showDetectSummary(results);

      // Enable next button if can proceed
      if (results.canProceed) {
        $('#btn-detect-next').disabled = false;
      }
    } catch (err) {
      addCheckResult(checkList, {
        name: '检测失败',
        status: 'error',
        detail: err.message,
        message: '请关闭后重试',
      });
    }
  }

  function addCheckItem(container, name, status) {
    const div = document.createElement('div');
    div.className = `check-item ${status}`;
    div.dataset.name = name;

    const icons = { loading: '⏳', ok: '✅', warn: '⚠️', error: '❌' };
    div.innerHTML = `
      <div class="check-icon ${status === 'loading' ? 'loading' : ''}">${icons[status] || '⏳'}</div>
      <div class="check-info">
        <div class="check-name">${name}</div>
        <div class="check-detail">${status === 'loading' ? '检测中...' : ''}</div>
      </div>
    `;
    container.appendChild(div);
    return div;
  }

  function addCheckResult(container, check) {
    const div = document.createElement('div');
    div.className = `check-item ${check.status}`;
    div.dataset.name = check.name;

    const icons = { ok: '✅', warn: '⚠️', error: '❌' };
    const badgeLabels = { ok: '正常', warn: '需处理', error: '不满足' };

    div.innerHTML = `
      <div class="check-icon">${icons[check.status]}</div>
      <div class="check-info">
        <div class="check-name">${check.name}</div>
        <div class="check-detail">${check.detail || ''}${check.message ? ` — ${check.message}` : ''}</div>
      </div>
      <span class="check-badge ${check.status}">${badgeLabels[check.status]}</span>
    `;
    container.appendChild(div);
  }

  function showDetectSummary(results) {
    const summary = $('#detect-summary');
    const tasks = [];

    if (results.needNode) tasks.push('安装 Node.js');
    if (results.needGitMirror) tasks.push('配置 GitHub 镜像源');
    if (results.needOpenClaw) tasks.push('安装小龙虾 (OpenClaw)');

    if (!results.canProceed) {
      summary.innerHTML = `
        <div class="summary-title" style="color:var(--error)">⛔ 系统不满足最低要求</div>
        <p>请先解决上述标红的问题后，重新运行安装程序。</p>
      `;
    } else if (tasks.length === 0) {
      summary.innerHTML = `
        <div class="summary-title" style="color:var(--success)">✅ 所有组件已就绪</div>
        <p>你的系统已满足所有要求，无需额外安装。</p>
      `;
    } else {
      summary.innerHTML = `
        <div class="summary-title">📋 需要安装以下组件：</div>
        <ul>${tasks.map((t) => `<li>${t}</li>`).join('')}</ul>
      `;
    }

    summary.style.display = '';
  }

  // ===== Install Page Preparation =====
  function preparInstallPage() {
    const { needNode, needGitMirror, needOpenClaw } = state;

    // Show mirror/npm selection if needed
    if (needGitMirror) {
      $('#mirror-section').style.display = '';
    } else {
      $('#mirror-section').style.display = 'none';
    }

    // Always show npm source selection if OpenClaw needs to be installed
    if (needOpenClaw) {
      $('#npm-section').style.display = '';
    } else {
      $('#npm-section').style.display = 'none';
    }

    // Show/hide progress components
    if (needNode) {
      $('#progress-node').style.display = '';
    }
    if (needOpenClaw) {
      $('#progress-openclaw').style.display = '';
    }

    // Update description
    if (!needNode && !needOpenClaw) {
      $('#install-description').textContent = '所有组件已就绪，可以跳过此步骤';
      $('#btn-install-start').style.display = 'none';
      $('#btn-install-next').style.display = '';
      $('#btn-install-next').disabled = false;
    }
  }

  // ===== Installation Process =====
  async function runInstallation() {
    if (state.installing) return;
    state.installing = true;

    const btn = $('#btn-install-start');
    btn.disabled = true;
    btn.textContent = '安装中...';

    // Show progress area, log
    $('#progress-area').style.display = '';
    $('#log-area').style.display = '';
    $('#install-description').textContent = '正在安装...';

    // Hide config sections during install
    $('#mirror-section').style.display = 'none';
    $('#npm-section').style.display = 'none';

    try {
      // Step 1: Configure Git mirror if needed
      if (state.needGitMirror) {
        const mirrorIdx = parseInt(getSelectedRadio('mirror') || '0', 10);
        const mirrorResult = await window.installer.configureGitMirror(mirrorIdx);
        addLog(`Git 镜像: ${mirrorResult.success ? '配置成功' : mirrorResult.error}`);
      }

      // Step 2: Configure npm registry
      if (state.needOpenClaw) {
        const npmIdx = parseInt(getSelectedRadio('npm') || '0', 10);
        const npmResult = await window.installer.configureNpmRegistry(npmIdx);
        addLog(`npm 源: ${npmResult.success ? `已设置 ${npmResult.registry}` : npmResult.error}`);
      }

      // Step 3: Install Node.js if needed
      if (state.needNode) {
        addLog('开始安装 Node.js...');
        const nodeResult = await window.installer.installNode();

        if (!nodeResult.success) {
          if (nodeResult.incompatible) {
            showError(nodeResult.error);
            return;
          }
          showError(`Node.js 安装失败: ${nodeResult.error}`);
          return;
        }
        addLog(`Node.js 安装成功: ${nodeResult.version}`);
      }

      // Step 4: Install OpenClaw
      if (state.needOpenClaw) {
        addLog('开始安装小龙虾...');
        const ocResult = await window.installer.installOpenClaw();

        if (!ocResult.success) {
          showError(`小龙虾安装失败: ${ocResult.error}`);
          return;
        }
        addLog(`小龙虾安装成功: ${ocResult.version}`);
      }

      // Success!
      $('#install-description').textContent = '✅ 全部安装完成！';
      btn.style.display = 'none';
      $('#btn-install-next').style.display = '';
      $('#btn-install-next').disabled = false;
    } catch (err) {
      showError(`安装过程出错: ${err.message}`);
    } finally {
      state.installing = false;
    }
  }

  // ===== Progress Updates =====
  function updateNodeProgress(data) {
    const percent = data.percent || 0;
    $('#node-progress').style.width = `${percent}%`;
    $('#node-percent').textContent = `${percent}%`;
    if (data.message) $('#node-message').textContent = data.message;
    if (data.log) addLog(data.log);

    if (data.stage === 'done') {
      $('#node-progress').classList.add('done');
    }
  }

  function updateOpenClawProgress(data) {
    const percent = data.percent || 0;
    $('#openclaw-progress').style.width = `${percent}%`;
    $('#openclaw-percent').textContent = `${percent}%`;
    if (data.message) $('#openclaw-message').textContent = data.message;
    if (data.log) addLog(data.log);

    if (data.stage === 'done') {
      $('#openclaw-progress').classList.add('done');
    }
  }

  function updateUninstallProgress(data) {
    const percent = data.percent || 0;
    $('#uninstall-progress-bar').style.width = `${percent}%`;
    $('#uninstall-percent').textContent = `${percent}%`;
    if (data.message) {
      $('#uninstall-message').textContent = data.message;
      $('#uninstall-stage').textContent = data.message;
    }

    if (data.stage === 'done') {
      $('#uninstall-progress-bar').classList.add('done');
    }
  }

  // ===== Uninstall / Repair =====
  async function runUninstall(mode) {
    $('#uninstall-done').style.display = 'none';

    try {
      let result;
      if (mode === 'simple') {
        result = await window.installer.simpleUninstall();
      } else {
        result = await window.installer.completeUninstall();
      }

      if (result.success) {
        $('#uninstall-title').textContent = '✅ 卸载完成';
        $('#uninstall-message').textContent = mode === 'simple'
          ? '已卸载小龙虾，配置数据已保留'
          : '已完全卸载小龙虾，安装器管理的数据和配置已清理';
      } else {
        $('#uninstall-title').textContent = '❌ 卸载失败';
        $('#uninstall-message').textContent = result.error || '卸载过程中出现错误';
      }
    } catch (err) {
      $('#uninstall-title').textContent = '❌ 卸载失败';
      $('#uninstall-message').textContent = err.message;
    }

    $('#uninstall-done').style.display = '';
  }

  async function runRepair() {
    $('#uninstall-done').style.display = 'none';

    try {
      const result = await window.installer.repairInstall();

      if (result.success) {
        $('#uninstall-title').textContent = '✅ 修复完成';
        $('#uninstall-message').textContent = `小龙虾已修复，当前版本: ${result.version}`;
      } else {
        $('#uninstall-title').textContent = '❌ 修复失败';
        $('#uninstall-message').textContent = result.error || '修复过程中出现错误';
      }
    } catch (err) {
      $('#uninstall-title').textContent = '❌ 修复失败';
      $('#uninstall-message').textContent = err.message;
    }

    $('#uninstall-done').style.display = '';
  }

  // ===== Utilities =====
  function getSelectedRadio(name) {
    const checked = document.querySelector(`input[name="${name}"]:checked`);
    return checked ? checked.value : '0';
  }

  function addLog(text) {
    const logContent = $('#log-content');
    const line = document.createElement('div');
    line.className = 'log-line';
    line.textContent = text;
    logContent.appendChild(line);
    logContent.scrollTop = logContent.scrollHeight;
  }

  function showError(message) {
    $('#error-detail').textContent = message;
    showPage('error');
  }

  // ===== Start =====
  init();
})();
