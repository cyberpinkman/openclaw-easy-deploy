# 🦞 小龙虾简易部署工具 (OpenClaw Easy Deploy)

帮助中国用户零门槛安装部署小龙虾 (OpenClaw Agent) 的脚本工具集。

## 🎯 适用人群

- 完全没有开发基础的新手
- 不会使用命令行的用户
- 在中国网络环境下遇到安装困难的用户

---

## 🚀 快速开始（推荐）

### Mac 用户

打开「终端」，复制粘贴以下命令：

**方式一：Gitee（国内推荐）**
```bash
curl -fsSL https://gitee.com/cyberpinkman/openclaw-easy-deploy/raw/main/mac/install.sh | bash
```

**方式二：GitHub（有代理用户）**
```bash
curl -fsSL https://raw.githubusercontent.com/cyberpinkman/openclaw-easy-deploy/main/mac/install.sh | bash
```

### Windows 用户

请按下面 3 步操作：

**第 1 步：以管理员身份打开 PowerShell**

在开始菜单里搜索 `PowerShell`，右键选择“**以管理员身份运行**”。

**第 2 步：先运行授权命令**

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

看到提示后输入 `Y` 并回车。

> 💡 这条授权命令通常只需要执行一次，后面再次安装或重装时一般不用重复输入。

**第 3 步：再运行一键安装命令**

**方式一：Gitee（国内推荐）**
```powershell
$tmp = Join-Path $env:TEMP "openclaw-install.ps1"; iwr -useb https://gitee.com/cyberpinkman/openclaw-easy-deploy/raw/main/windows/install.ps1 -OutFile $tmp; powershell -NoExit -ExecutionPolicy Bypass -File $tmp
```

**方式二：GitHub（有代理用户）**
```powershell
$tmp = Join-Path $env:TEMP "openclaw-install.ps1"; iwr -useb https://raw.githubusercontent.com/cyberpinkman/openclaw-easy-deploy/main/windows/install.ps1 -OutFile $tmp; powershell -NoExit -ExecutionPolicy Bypass -File $tmp
```

> 💡 提示 1：这一步是为了避免系统默认禁止脚本执行，必须先手动授权一次。即使把授权命令写进安装脚本开头，也可能因为系统策略限制而先报错，所以最稳妥的方式是你先手动运行上面的授权命令。
>
> 💡 提示 2：脚本会自动检测 PowerShell 版本，如版本过低会提示升级到 PowerShell 7（支持更好的中文显示）。如果仍有编码问题，可使用英文版：
> ```powershell
> $tmp = Join-Path $env:TEMP "openclaw-install-en.ps1"; iwr -useb https://gitee.com/cyberpinkman/openclaw-easy-deploy/raw/main/windows/install-en.ps1 -OutFile $tmp; powershell -NoExit -ExecutionPolicy Bypass -File $tmp
> ```

---

## 📖 安装脚本做什么？

一条命令后，脚本会自动：

1. ✅ 检测你的系统环境
2. ✅ 检测并安装 Node.js（如果没有或版本过低）
3. ✅ 检测 GitHub 连接，必要时配置镜像源
4. ✅ 安装小龙虾 (OpenClaw)
5. ✅ 启动配置向导

你需要做的：
- 看着屏幕
- 偶尔按 Enter 或输入 y/n
- 等待完成

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
| 操作系统 | macOS 12+ / Windows 10 | macOS 14+ / Windows 11 |

---

## ❓ 常见问题

### 安装 Node.js 失败

**Mac**: 确保已安装 Xcode 命令行工具：
```bash
xcode-select --install
```

**Windows**: 尝试手动下载安装包：https://nodejs.org

### Git 连接超时

如果你没有 VPN，脚本会引导你配置国内镜像源。可用镜像：
- gitclone.com
- mirror.ghproxy.com
- ghproxy.net

### npm 安装慢

脚本会引导你选择 npm 源，推荐：
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
