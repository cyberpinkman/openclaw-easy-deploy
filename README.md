# 🦞 小龙虾简易部署工具 (OpenClaw Easy Deploy)

帮助中国用户零门槛安装部署小龙虾 (OpenClaw Agent) 的工具。

## 🎯 适用人群

- 完全没有开发基础的新手
- 不会使用命令行的用户
- 在中国网络环境下遇到安装困难的用户

---

## 🚀 快速开始

### 方式一：安装程序（当前推荐 Windows 用户使用）

下载安装程序，**双击运行**，全程鼠标操作，无需任何命令行知识。

| 系统 | 下载链接 |
|------|----------|
| Windows (.exe) | [GitHub Releases](https://github.com/cyberpinkman/openclaw-easy-deploy/releases) |

安装程序会自动帮你：

- 🔍 检测系统环境和兼容性
- 📦 安装合适版本的 Node.js（智能适配你的系统）
- 🌐 检测网络并配置国内镜像源
- 🦞 安装小龙虾 (OpenClaw)
- 🎯 启动配置向导（自动在新终端窗口中打开）

**全程可视化**，有进度条、有弹窗提示，你只需要点击按钮即可。

如果安装失败，安装程序现在支持：

- 直接显示错误代码
- 一键复制诊断信息
- 把系统信息、错误详情和最近日志一起发给开发者排查

> ⚠️ macOS 图形安装包暂时下线，原因是正式的 Apple Developer 签名和 notarization 流程仍在准备中。为了避免 Mac 用户遇到“安装包无法打开”之类的系统拦截问题，当前请先使用下面的命令行安装方式。

安装程序内显示的开发者信息：

- 开发者：Pink 和他的 Codex
- 联系方式：cyberpink.xx@gmail.com
- 开源仓库：https://github.com/cyberpinkman/openclaw-easy-deploy

> 💡 安装程序还支持**修复安装**和**卸载**功能。如果你的电脑已经安装过小龙虾，打开安装程序会自动检测并提供修复或卸载选项。
>
> 💡 **完全卸载**会优先按安装器记录的“安装前状态”回滚系统改动，例如 Git 镜像、npm 源，以及 onboarding 期间可能变更的系统代理。它不会无差别重置你当前电脑上的所有代理设置。
>
> 💡 点击“启动配置向导”后，安装程序会在**新的终端窗口**里运行 `openclaw onboard --install-daemon`。如果没有看到新窗口弹出，请手动检查系统是否拦截了终端启动权限。

---

### 方式二：命令行安装（当前 Mac 用户请使用此方式）

#### Mac 用户

打开「终端」，复制粘贴以下命令：

**方式一：Gitee（国内推荐）**
```bash
curl -fsSL https://gitee.com/cyberpinkman/openclaw-easy-deploy/raw/main/mac/install.sh | bash
```

**GitHub**
```bash
curl -fsSL https://raw.githubusercontent.com/cyberpinkman/openclaw-easy-deploy/main/mac/install.sh | bash
```

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

安装程序和一键脚本都会优先尝试官方安装包，并在安装后自动检测 Node.js 是否可运行。

**Mac**: 大多数情况下不需要提前手动安装 Xcode 命令行工具；如果后续安装日志明确提示依赖编译失败，再执行：
```bash
xcode-select --install
```

**Windows**: 如果失败，优先检查是否被系统权限、杀毒软件或公司电脑策略拦截；仍不行再手动下载安装包：https://nodejs.org

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

安装完成后通常不需要额外处理；如果你是手动安装过 Node.js 或系统环境变量刷新较慢，可能需要：
- **Mac**: 关闭终端，重新打开
- **Windows**: 关闭 PowerShell，重新打开（以管理员身份）

### 点击“启动配置向导”后没有反应

安装器会尝试在新终端窗口中启动：

```bash
openclaw onboard --install-daemon
```

如果没有弹出新终端窗口，请尝试：
- 检查系统是否拦截了 Terminal / PowerShell 启动
- 关闭安装程序后重新打开再试
- 直接在终端或 PowerShell 中手动运行上面的命令

### 遇到报错但看不懂

如果安装程序出现失败页，请点击：

- `复制诊断信息`

然后把复制出来的内容连同问题现象一起发给开发者，这会比单独截图更容易定位问题。

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

如果还没有完成配置，也可以运行：

```bash
openclaw onboard --install-daemon
```

---

## 📞 获取帮助

- OpenClaw 官方文档：https://docs.openclaw.ai
- 社区支持：https://discord.com/invite/clawd
- 问题反馈：https://github.com/cyberpinkman/openclaw-easy-deploy/issues
- 开发者联系：cyberpink.xx@gmail.com
- 开源仓库：https://github.com/cyberpinkman/openclaw-easy-deploy

---

## 📜 许可证

MIT License
