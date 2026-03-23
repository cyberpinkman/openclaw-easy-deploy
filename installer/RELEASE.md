# OpenClaw 安装程序发布说明

这个文档面向维护者，说明图形安装器的打包、签名和发布流程。

## 作者信息

- 开发者：Pink 和他的 Codex
- 联系方式：cyberpink.xx@gmail.com
- 开源仓库：https://github.com/cyberpinkman/openclaw-easy-deploy

这部分信息会显示在安装器界面和 README 中，用于让用户知道维护者是谁。

## 先理解一件事：作者声明不等于代码签名

安装器里展示“开发者：Pink 和他的 Codex”，只是产品层面的署名。

真正的代码签名是另一套机制：

- macOS 依赖 Apple Developer ID Application 证书，并建议做 notarization
- Windows 依赖 Authenticode 代码签名证书

所以：

- 内测包可以不签名，但系统会给出更明显的安全提示
- 面向公开用户分发时，最好补签名

## 图标资源

当前已经使用自定义图标：

- `src/renderer/assets/icon.png`
- `src/renderer/assets/icon.icns`
- `src/renderer/assets/icon.ico`

如果以后要换图标，建议从一张 1024x1024 的正方形 PNG 开始，再重新生成 `.icns` 和 `.ico`。

## 本地构建

```bash
cd installer
npm ci
```

### macOS

```bash
npm run build:mac
npm run build:mac:universal
```

### Windows

```bash
npm run build:win:x64
npm run build:win:arm64
```

默认输出目录：

- `installer/dist/`

## 推荐发布矩阵

当前最实用的分发组合是：

- macOS `universal` DMG
- Windows `x64` NSIS 安装包

如果未来 Windows ARM 用户变多，再额外发布 `arm64`。

## macOS 签名与 notarization

如果要做正式的 macOS 分发，需要准备：

- Apple Developer Program 账号
- `Developer ID Application` 证书
- Apple 团队 ID
- 一个 app-specific password

`electron-builder` 常见依赖信息包括：

- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_TEAM_ID`
- `CSC_LINK`
- `CSC_KEY_PASSWORD`

未配置时也可以正常打包，但产物会是未签名版本。

## Windows 签名

如果要减少 SmartScreen 告警，建议准备 Authenticode 代码签名证书。

常见做法是给 `electron-builder` 提供：

- `CSC_LINK`
- `CSC_KEY_PASSWORD`

如果没有证书，也可以先发布未签名版本给小范围测试用户。

## 发布前自测清单

每次发版前，至少确认：

1. 全新系统上能完成环境检测
2. Node.js 缺失时能顺利安装
3. GitHub 不通时镜像配置确实生效
4. OpenClaw 安装成功后能正常启动 onboarding
5. 修复安装能复用正常安装逻辑
6. 简单卸载不会删数据
7. 完全卸载会按 install-state 回滚实际改动，而不是粗暴清代理
8. 安装器窗口、Dock 图标、DMG/EXE 图标都已显示自定义图标

## 推荐发布流程

1. 在仓库根目录确认工作区干净
2. 在 `installer/` 里执行 `npm ci`
3. 构建目标平台产物
4. 在一台干净机器上做安装/修复/卸载回归
5. 上传到 GitHub Releases 和 Gitee Releases
6. 更新 README 下载说明或 release note

## 当前已知非阻塞项

- 如果没有真实签名证书，公开用户第一次安装时仍会看到系统安全提示
- 目前默认发布流程更适合维护者手动执行，尚未接 CI/CD 自动发版
