<p align="center">
  <img src="./logo.png" alt="Remora logo" width="140" />
</p>

<h1 align="center">Remora</h1>

<p align="center"><strong>让你轻松连接任意 Shell。</strong></p>

<p align="center">
  一个使用 SwiftUI 构建的原生 macOS SSH + SFTP 工作台，内置自研高性能终端引擎。
</p>

<p align="center">
  <a href="./README.md">English</a> •
  <a href="#功能特性">功能特性</a> •
  <a href="#截图">截图</a> •
  <a href="#快速开始">快速开始</a> •
  <a href="#项目结构">项目结构</a> •
  <a href="#测试">测试</a> •
  <a href="#参与贡献">参与贡献</a>
</p>

---

## 为什么是 Remora？

Remora 聚焦在一个实用组合：

- 原生 macOS 体验的连接与会话管理。
- 面向 VT 渲染与输入性能的自研终端核心。
- SSH 与 SFTP 在一个工作区内协同完成。

## 功能特性

### 终端与会话

- SwiftUI 中内嵌原生终端视图（`NSView`）。
- 支持现代 TUI 常用的 ANSI/VT 能力。
- 参考 xterm 风格的文本选择体验：
  - 拖拽选择、双击选词。
  - 三击按逻辑行选择。
  - Option/Alt 矩形列选择。
  - 选择锚定到缓冲区（滚动时保持稳定）。
- 支持本地 Shell 与 SSH 会话。
- 支持多会话标签页与分栏工作区。
- 支持 SSH 会话快速重连入口。

### SSH 主机管理

- 主机目录支持分组、搜索、模板、收藏、最近连接。
- 侧边栏与顶部流程支持快速连接和快捷操作。
- 支持 Agent/密码/私钥认证，配合安全存储路径。
- 支持主机密钥信任确认流程。
- 支持按主机维护快捷命令（Quick Commands）。

### SFTP / 文件管理

- 本地 + 远程双面板文件浏览。
- 远程操作：新建文件/文件夹、重命名、移动、删除、复制/剪切/粘贴、上传/下载。
- 传输队列支持进度、状态与失败重试。
- 拖拽上传：
  - 拖到目录行：上传到该目录。
  - 拖到文件行或空白区：上传到当前目录。
  - 提供目标高亮与浮层文案提示（如 `上传到 /var/log`）。
- 文件操作提供即时反馈（copy/cut/delete/paste/upload/download 等）。
- 可选终端目录与文件管理目录同步。
- 支持按主机维护 FTP/SFTP 快捷路径（Quick Paths）。

### 应用体验

- 支持简体中文与英文。
- 支持浅色/深色/跟随系统外观。
- 支持可自定义快捷键（含冲突检测）。
- 设置页支持语言、外观、下载目录、指标采样与快捷键配置。
- 内置项目主页与问题反馈入口。
- 已连接 SSH 主机支持服务器指标/状态面板。

## 截图

### SSH 工作区

![Remora SSH workspace](./docs/screenshots/PixPin_2026-03-04_22-45-28.png)

### 终端（TUI 友好）

![Remora terminal TUI](./docs/screenshots/PixPin_2026-03-04_22-45-57.png)

### 文件管理 + 传输流程

![Remora file manager](./docs/screenshots/PixPin_2026-03-04_22-45-44.png)

## 快速开始

### 环境要求

- macOS 14+
- Xcode 15.4+（或 Swift 6 toolchain）

### 构建与运行

```bash
swift build
swift run RemoraApp
```

可选压力工具：

```bash
swift run terminal-stress
```

## 测试

运行核心测试：

```bash
swift test
```

运行 UI 自动化测试（按需开启）：

```bash
REMORA_RUN_UI_TESTS=1 swift test --filter RemoraUIAutomationTests
```

如果 `RemoraApp` 二进制路径非默认：

```bash
REMORA_RUN_UI_TESTS=1 REMORA_APP_BINARY=/abs/path/to/RemoraApp swift test --filter RemoraUIAutomationTests
```

## 项目结构

- `Sources/RemoraCore`：SSH/SFTP/会话/主机/安全/核心模型。
- `Sources/RemoraTerminal`：解析器、缓冲区、渲染器、终端输入/视图。
- `Sources/RemoraApp`：SwiftUI 应用、工作区 UI、设置、文件管理。
- `Sources/TerminalStressTool`：终端吞吐/压力工具。
- `Tests/*`：core、terminal、app 测试。
- `docs/`：清单、截图与运行说明文档。

## 参与贡献

欢迎贡献代码与建议。

- 提交 PR 前请先阅读 [`CONTRIBUTING.md`](./CONTRIBUTING.md)。
- Bug 或功能建议请使用 [GitHub Issues](https://github.com/wuuJiawei/Remora/issues)。

## 安全

请阅读 [`SECURITY.md`](./SECURITY.md) 了解负责任披露流程。

## 开源检查清单

见 [`docs/OPEN_SOURCE_CHECKLIST.md`](./docs/OPEN_SOURCE_CHECKLIST.md)。

## 更新日志

见 [`CHANGELOG.md`](./CHANGELOG.md)。

## 许可证

本项目采用 Apache License 2.0，详见 [`LICENSE`](./LICENSE)。
