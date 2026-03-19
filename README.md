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

以**管理员身份**打开「PowerShell」，复制粘贴以下命令：

**方式一：Gitee（国内推荐）**
```powershell
iwr -useb https://gitee.com/cyberpinkman/openclaw-easy-deploy/raw/main/windows/install-en.ps1 | iex
```

**方式二：GitHub（有代理用户）**
```powershell
iwr -useb https://raw.githubusercontent.com/cyberpinkman/openclaw-easy-deploy/main/windows/install-en.ps1 | iex
```

> 💡 提示：如果中文版显示乱码，请使用上述英文版脚本，功能完全相同。

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

---

## 📞 获取帮助

- OpenClaw 官方文档：https://docs.openclaw.ai
- 社区支持：https://discord.com/invite/clawd
- 问题反馈：https://github.com/cyberpinkman/openclaw-easy-deploy/issues

---

## 📜 许可证

MIT License
