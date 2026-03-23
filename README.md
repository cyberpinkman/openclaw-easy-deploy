# 🦞 小龙虾简易部署工具 (OpenClaw Easy Deploy)

帮助中国用户零门槛安装部署小龙虾 (OpenClaw Agent) 的工具。

## 🎯 适用人群

- 完全没有开发基础的新手
- 不会使用命令行的用户
- 在中国网络环境下遇到安装困难的用户

---

## 🚀 快速开始

### 方式一：安装程序（推荐，零基础用户首选）

下载安装程序，**双击运行**，全程鼠标操作，无需任何命令行知识。

| 系统 | 下载链接 | 备用下载 |
|------|----------|----------|
| Mac (.dmg) | [Gitee Releases](https://gitee.com/cyberpinkman/openclaw-easy-deploy/releases) | 网盘下载（见群公告） |
| Windows (.exe) | [Gitee Releases](https://gitee.com/cyberpinkman/openclaw-easy-deploy/releases) | 网盘下载（见群公告） |

安装程序会自动帮你：

- 🔍 检测系统环境和兼容性
- 📦 安装合适版本的 Node.js（智能适配你的系统）
- 🌐 检测网络并配置国内镜像源
- 🦞 安装小龙虾 (OpenClaw)
- 🎯 启动配置向导

**全程可视化**，有进度条、有弹窗提示，你只需要点击按钮即可。

> 💡 安装程序还支持**修复安装**和**卸载**功能。如果你的电脑已经安装过小龙虾，打开安装程序会自动检测并提供修复或卸载选项。
>
> 💡 **完全卸载**会优先按安装器记录的“安装前状态”回滚系统改动，例如 Git 镜像、npm 源，以及 onboarding 期间可能变更的系统代理。它不会无差别重置你当前电脑上的所有代理设置。

---

### 方式二：命令行安装（有终端基础的用户）

#### Mac 用户

打开「终端」，复制粘贴以下命令：

**Gitee（国内推荐）**
```bash
curl -fsSL https://gitee.com/cyberpinkman/openclaw-easy-deploy/raw/main/mac/install.sh | bash
```

**GitHub（有代理用户）**
```bash
curl -fsSL https://raw.githubusercontent.com/cyberpinkman/openclaw-easy-deploy/main/mac/install.sh | bash
```

#### Windows 用户

请按下面 3 步操作：

**第 1 步：以管理员身份打开 PowerShell**

在开始菜单里搜索 `PowerShell`，右键选择"**以管理员身份运行**"。

**第 2 步：先运行授权命令**

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

看到提示后输入 `Y` 并回车。

> 💡 这条授权命令通常只需要执行一次，后面再次安装或重装时一般不用重复输入。

**第 3 步：再运行一键安装命令**

**Gitee（国内推荐）**
```powershell
$tmp = Join-Path $env:TEMP "openclaw-install.ps1"; iwr -useb https://gitee.com/cyberpinkman/openclaw-easy-deploy/raw/main/windows/install.ps1 -OutFile $tmp; powershell -NoExit -ExecutionPolicy Bypass -File $tmp
```

**GitHub（有代理用户）**
```powershell
$tmp = Join-Path $env:TEMP "openclaw-install.ps1"; iwr -useb https://raw.githubusercontent.com/cyberpinkman/openclaw-easy-deploy/main/windows/install.ps1 -OutFile $tmp; powershell -NoExit -ExecutionPolicy Bypass -File $tmp
```

> 💡 提示：脚本会自动检测 PowerShell 版本，如版本过低会提示升级到 PowerShell 7（支持更好的中文显示）。如果仍有编码问题，可使用英文版：
> ```powershell
> $tmp = Join-Path $env:TEMP "openclaw-install-en.ps1"; iwr -useb https://gitee.com/cyberpinkman/openclaw-easy-deploy/raw/main/windows/install-en.ps1 -OutFile $tmp; powershell -NoExit -ExecutionPolicy Bypass -File $tmp
> ```

---

## 🗑️ 卸载小龙虾

### 使用安装程序卸载（推荐）

1. 打开安装程序（同安装时的 .dmg / .exe）
2. 安装程序会检测到已有安装，自动弹出选项
3. 选择「卸载」
4. 选择卸载方式：
   - **简单卸载**：移除小龙虾命令，保留你的配置数据（方便以后重装）
   - **完全卸载**：删除所有文件，并恢复安装器实际改动过的配置（Git 镜像、后台服务、npm 源等）

### 手动卸载

```bash
npm uninstall -g openclaw
```

如需清理配置数据，删除以下目录：
- Mac: `~/.openclaw` 和 `~/.config/openclaw`
- Windows: `%APPDATA%\openclaw` 和 `%LOCALAPPDATA%\openclaw`

---

## 🔧 独立脚本（高级用户）

如果遇到问题，可以使用独立脚本手动处理：

### Mac 用户

| 脚本 | 用途 | 使用场景 |
|------|------|----------|
| `1-check.sh` | 环境自检 | 只想看看当前环境状态 |
| `2-install-node.sh` | 安装 Node.js | 手动安装/升级 Node.js |
| `3-install-git.sh` | 配置 Git 镜像 | 手动配置/更换镜像源 |
| `4-install-openclaw.sh` | 安装小龙虾 | 手动安装/重装 OpenClaw |
| `5-diagnose.sh` | 故障诊断 | 小龙虾运行异常时 |

### Windows 用户

| 脚本 | 用途 | 使用场景 |
|------|------|----------|
| `1-check.ps1` | 环境自检 | 只想看看当前环境状态 |
| `2-install-node.ps1` | 安装 Node.js | 手动安装/升级 Node.js |
| `3-install-git.ps1` | 配置 Git 镜像 | 手动配置/更换镜像源 |
| `4-install-openclaw.ps1` | 安装小龙虾 | 手动安装/重装 OpenClaw |
| `5-diagnose.ps1` | 故障诊断 | 小龙虾运行异常时 |

---

## ⚙️ 系统要求

| 项目 | 最低要求 | 推荐配置 |
|------|----------|----------|
| 内存 | 4GB | 8GB+ |
| 硬盘空间 | 2GB 可用 | 5GB+ |
| Node.js | 22.16+ | 24.x |
| 操作系统 | macOS 10.15+ / Windows 10 | macOS 14+ / Windows 11 |

> ⚠️ **macOS 10.14 及更早版本**无法安装 OpenClaw：OpenClaw 要求 Node.js ≥ 22.16.0，而 macOS 10.14 最高仅支持 Node.js 22.15.x。请升级到至少 macOS 10.15 (Catalina)。

---

## ❓ 常见问题

### 安装 Node.js 失败

**Mac**: 确保已安装 Xcode 命令行工具：
```bash
xcode-select --install
```

**Windows**: 尝试手动下载安装包：https://nodejs.org

### Git 连接超时

如果你没有 VPN，安装程序/脚本会引导你配置国内镜像源。可用镜像：
- gitclone.com
- mirror.ghproxy.com
- ghproxy.net

### npm 安装慢

安装程序/脚本会引导你选择 npm 源，推荐：
- 淘宝源：https://registry.npmmirror.com
- 腾讯源：https://mirrors.cloud.tencent.com/npm/

### Windows 网关无法启动

Windows 系统下 `restart` 命令可能失效，诊断脚本会使用 `openclaw gateway` 命令启动网关。

### 安装后命令找不到

安装完成后可能需要：
- **Mac**: 关闭终端，重新打开
- **Windows**: 关闭 PowerShell，重新打开（以管理员身份）

### Windows 提示脚本执行被禁用

请先以**管理员身份**打开 PowerShell，运行：

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

输入 `Y` 确认后，再重新运行一键安装命令。

---

## ✅ 安装后先做什么？

安装完成后，先在终端或 PowerShell 里输入：

```bash
openclaw dashboard
```

这会自动打开小龙虾的 Web 控制台。

如果需要启动网关，再运行：

```bash
openclaw gateway
```

---

## 📞 获取帮助

- OpenClaw 官方文档：https://docs.openclaw.ai
- 社区支持：https://discord.com/invite/clawd
- 问题反馈：https://github.com/cyberpinkman/openclaw-easy-deploy/issues

---

## 📜 许可证

MIT License
