# AGENTS

## Project Overview

Remora 是一个原生 macOS SSH/SFTP 客户端，使用 Swift 6 + SwiftUI 构建，最低支持 macOS 14+。项目采用 Swift Package Manager 管理。

## Module Boundary Rules

| 模块 | 职责 |
|---|---|
| `RemoraCore` | SSH、SFTP、主机模型、凭据处理、主机密钥信任、共享会话抽象、ZMODEM 协议 |
| `RemoraTerminal` | SwiftTerm 适配层 + 终端视图集成 |
| `RemoraApp` | SwiftUI 应用外壳、工作区 UI、设置、文件管理器、传输流程 |

- `RemoraApp` 拥有面向用户的工作流和展示状态。
- `RemoraTerminal` 专注于终端集成，将 SwiftTerm 与应用层隔离。
- `RemoraCore` 拥有传输、持久化、安全和可复用的领域逻辑。
- App 层功能应优先依赖 `RemoraCore` 和 `RemoraTerminal`，不得在 UI 层重新实现协议或解析器行为。

## AI Coding Rules

### 最小变更原则
- **每次功能修改按最小功能变更来**，不做超出需求范围的重构或"顺手改进"。
- 新增功能只改动必要的文件，不扩散到无关模块。
- 如果一个功能涉及多个模块，按模块边界分层实现：Core → Terminal → App。
- 不引入新的外部依赖，除非功能无法用纯 Swift 实现且用户明确要求。

### 编码前必做
- 先阅读相关代码，理解现有模式和约定，再动手写代码。
- 新增 `@Published` 属性时，检查是否有自定义 `init(from decoder:)` 和 `CodingKeys`，必须同步更新。
- 新增设置项时，必须同时更新：`AppPreferencesSnapshot` 属性、`CodingKeys`、`init(from decoder:)`（用 `decodeIfPresent` + 默认值）、`defaultValue()`。
- 新增 UI 文本时，必须同时更新 `en.lproj/Localizable.strings` 和 `zh-Hans.lproj/Localizable.strings`。

### 编码中规范
- 不在 `RemoraTerminal` 中 override SwiftTerm 的非 `open` 方法，改用 delegate 回调或组合模式。
- SSH 连接参数修改必须考虑三种认证方式（key、agent、password+sshpass）的兼容性。
- 涉及进程管理（Process/PTY）的改动，必须考虑进程清理（app 退出、session 断开）。
- 异步写入 PTY 时必须保证顺序（串行队列），不能用并发 Task 写入。
- 信号处理器中只能调用 async-signal-safe 函数（`posix_spawn`、`waitpid`、`unlink`），不能用 `Process()`。

### 编码后验证
- 每次改动后必须 `swift build` 验证编译通过。
- 涉及 SSH 连接的改动，需考虑堡垒机多层跳转场景。
- 涉及二进制协议（ZMODEM 等）的改动，需考虑控制字符转义和 CRC 校验一致性。
- 新增的清理逻辑需覆盖三种退出方式：正常退出（Cmd+Q）、`kill` (SIGTERM)、`kill -HUP`。

### 调试日志
- 调试日志使用 `#if DEBUG` 包裹，或使用环境变量开关（参见 `REMORA_PTY_DEBUG`）。
- 功能完成后清理所有 `NSLog` 调试日志，保留 `#if DEBUG` 守卫的日志。
- 不在 Release 构建中输出敏感信息（密码、密钥路径、OTP 码）。

## Localization (i18n)

- 所有用户可见的文本必须使用 `tr(...)` 包裹（定义于 `Sources/RemoraApp/LocalizationHelpers.swift`）。
- 必须同步更新以下两个翻译文件：
  - `Sources/RemoraApp/Resources/en.lproj/Localizable.strings`（英文）
  - `Sources/RemoraApp/Resources/zh-Hans.lproj/Localizable.strings`（简体中文）
- 国际化通过 `L10n.tr()` 实现，支持运行时语言切换（通过 `AppPreferences` 中的 `languageModeRawValue`）。

## UI Rules

- 所有 UI 变更必须同时支持 **Light Mode** 和 **Dark Mode**。优先使用代码库中已有的主题感知颜色/样式（参见 `AppAppearanceMode`），完成前需在两种外观下验证。
- 所有 UI 变更必须保持现有**原生 macOS 风格**。优先使用 SwiftUI 原生控件和行为，仅当代码库已建立自定义模式或产品明确要求时才引入自定义样式。
- 弹窗（alert）中的 TextField 不要加 `.textFieldStyle(.roundedBorder)`，macOS alert 会自动处理样式。
- 密码输入使用 `SecureField`，验证码输入使用 `TextField`。

## Git & Build Rules

- 从 `main` 分支创建功能分支。
- 提交保持小而有意义，使用祈使语气的提交信息（如 `Fix terminal selection anchor after scroll`）。
- 任何 git worktree 必须创建在仓库本地的 `.worktree/` 目录下，不得在仓库旁边或外部创建。
- 如果 worktree 路径在 SwiftPM/Xcode 构建后发生变化，须先清理构建缓存（`swift package clean` && `swift package reset`），以避免模块缓存路径错误。

## Development Environment

- **环境要求**：macOS 14+，Xcode 15.4+（或 Swift 6 工具链）
- **构建**：`swift build`
- **运行**：`swift run RemoraApp`
- **测试**：`swift test`
- **打包**：`bash scripts/package_macos.sh --version x.y.z`
- **UI 自动化测试**（可选）：`REMORA_RUN_UI_TESTS=1 swift test --filter RemoraUIAutomationTests`

## Pull Request Checklist

- [ ] 本地构建成功（`swift build`）
- [ ] 相关测试本地通过（`swift test`）
- [ ] 新行为尽可能包含测试
- [ ] 用户可见的变更包含国际化更新（`en` / `zh-Hans`）
- [ ] 行为或 API 变更时更新文档
- [ ] UI 变更在 Light / Dark 两种模式下验证通过
- [ ] PR 描述包含：变更内容、变更原因、测试方式
- [ ] UI 变更附带截图或 GIF

## Security

- 安全漏洞**不得**公开发布，需邮件报告至 `wujiawei0926@gmail.com`（主题前缀 `[Remora Security]`）。
- 重点安全关注领域：凭据/密钥处理、主机密钥验证、命令注入风险、路径遍历、敏感日志泄漏。
- SSH ControlMaster socket 文件存放在 `/tmp/remora-*.sock`，app 退出时必须清理。
- `ControlPersist` 设为 `no`，不允许后台保持连接。

## Code Style & Conventions

- Swift 工具链版本：6.0（`// swift-tools-version: 6.0`）
- 默认本地化语言：`en`
- 枚举偏好使用 `String` 原始值 + `CaseIterable` + `Identifiable` 模式（参见 `AppAppearanceMode`、`AppLanguageMode`）。
- 偏好设置通过 `AppPreferences` 单例 + `Codable` 快照模式管理（参见 `AppPreferencesSnapshot`）。
- 框架链接通过 `Package.swift` 中的 `linkerSettings` 显式声明。
- `@MainActor` 标注所有 UI 相关的类和结构体。
- 跨线程回调使用 `@Sendable`，在 MainActor 上下文中使用 `MainActor.assumeIsolated` 而非 `DispatchQueue.main.async`。

## Key Architecture Patterns

### SSH 连接
- 连接通过 `ProcessSSHShellSession` 管理，使用系统 `/usr/bin/ssh` + PTY。
- 密码认证支持 `sshpass`（优先）和 `SSH_ASKPASS`（回退）两种方式。
- 连接复用通过 `ControlMaster=auto` + `ControlPath=/tmp/remora-*.sock` 实现。
- 认证阶段检测通过 `detectSSHAuthStage` 分析 PTY 输出实现。

### 终端数据流
- 下行：SSH PTY → `SessionManager.AsyncStream` → `TerminalRuntime.flushOutputBatch` → `TerminalView.feed`
- 上行：`TerminalView.onInput` → `TerminalRuntime.enqueueInput` → `SessionManager.write`
- ZMODEM 拦截点在 `flushOutputBatch`，认证拦截也在此处。

### 偏好设置
- 新增设置项需同时修改 4 处：`AppPreferencesSnapshot` 属性声明、`CodingKeys` 枚举、`init(from decoder:)`、`defaultValue()`。
- 在 SwiftUI 视图中通过 `@RemoraStored(\.keyPath)` 读写。
- 在非视图代码中通过 `AppPreferences.shared.snapshot.keyPath` 读取。
