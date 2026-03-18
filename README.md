# 🦞 小龙虾简易部署工具 (OpenClaw Easy Deploy)

帮助中国用户零门槛安装部署小龙虾 (OpenClaw Agent) 的脚本工具集。

## 🎯 适用人群

- 完全没有开发基础的新手
- 不会使用命令行的用户
- 在中国网络环境下遇到安装困难的用户

## 📋 脚本说明

### Mac 用户 (macOS)

| 脚本 | 用途 | 使用场景 |
|------|------|----------|
| `1-check.sh` | 环境自检 | 检测电脑配置、已安装软件 |
| `2-install-node.sh` | 安装 Node.js | 没有安装 Node.js 或版本过低 |
| `3-install-git.sh` | 安装/配置 Git | 没有 Git 或需要配置镜像 |
| `4-install-openclaw.sh` | 安装小龙虾 | 安装 OpenClaw |
| `5-diagnose.sh` | 故障诊断修复 | 小龙虾运行异常时 |

### Windows 用户

| 脚本 | 用途 | 使用场景 |
|------|------|----------|
| `1-check.ps1` | 环境自检 | 检测电脑配置、已安装软件 |
| `2-install-node.ps1` | 安装 Node.js | 没有安装 Node.js 或版本过低 |
| `3-install-git.ps1` | 安装/配置 Git | 没有 Git 或需要配置镜像 |
| `4-install-openclaw.ps1` | 安装小龙虾 | 安装 OpenClaw |
| `5-diagnose.ps1` | 故障诊断修复 | 小龙虾运行异常时 |

## 🚀 快速开始

### Mac 用户

1. 打开「终端」
2. 执行以下命令下载并运行自检脚本：

**方式一：GitHub（有代理/VPN 用户）**
```bash
curl -fsSL https://raw.githubusercontent.com/cyberpinkman/openclaw-easy-deploy/main/mac/1-check.sh | bash
```

**方式二：Gitee（无代理用户，推荐）**
```bash
curl -fsSL https://gitee.com/cyberpinkman/openclaw-easy-deploy/raw/main/mac/1-check.sh | bash
```

3. 根据提示逐步执行后续脚本

### Windows 用户

1. 以管理员身份打开「PowerShell」
2. 执行以下命令：

**方式一：GitHub（有代理/VPN 用户）**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
iwr -useb https://raw.githubusercontent.com/cyberpinkman/openclaw-easy-deploy/main/windows/1-check.ps1 | iex
```

**方式二：Gitee（无代理用户，推荐）**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
iwr -useb https://gitee.com/cyberpinkman/openclaw-easy-deploy/raw/main/windows/1-check.ps1 | iex
```

3. 根据提示逐步执行后续脚本

## ⚙️ 系统要求

| 项目 | 最低要求 | 推荐配置 |
|------|----------|----------|
| 内存 | 4GB | 8GB+ |
| 硬盘空间 | 2GB 可用 | 5GB+ |
| Node.js | 22.16+ | 24.x |
| 操作系统 | macOS 12+ / Windows 10 | macOS 14+ / Windows 11 |

## 🔧 常见问题

### 安装 Node.js 失败

- **Mac**: 确保已安装 Xcode 命令行工具：`xcode-select --install`
- **Windows**: 尝试手动下载安装包：https://nodejs.org

### Git 连接超时

如果你没有 VPN，脚本会引导你配置国内镜像源。推荐镜像：
- https://gitclone.com
- https://hub.fastgit.xyz
- https://mirror.ghproxy.com

### npm 安装慢

脚本会引导你选择 npm 源，推荐：
- 淘宝源：https://registry.npmmirror.com
- 腾讯源：https://mirrors.cloud.tencent.com/npm/

### Windows 网关无法启动

Windows 系统下 `restart` 命令可能失效，诊断脚本会使用 `openclaw gateway` 命令启动网关。

## 📞 获取帮助

- OpenClaw 官方文档：https://docs.openclaw.ai
- 社区支持：https://discord.com/invite/clawd
- 问题反馈：https://github.com/cyberpinkman/openclaw-easy-deploy/issues

## 📜 许可证

MIT License
