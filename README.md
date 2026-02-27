
Remora

Hitch a ride to any shell.

A native macOS SSH & SFTP client built with SwiftUI, featuring a beautiful frosted-glass interface.

## MVP quick start

```bash
swift build
swift run RemoraApp
```

App 启动后：

1. 左侧 `Hosts` 可按分组/收藏/最近浏览并搜索主机。
2. 顶部 `Quick Connect` 支持按别名或地址直连。
3. 中间支持 `Tabs + 双 Pane 分屏`（Horizontal/Vertical）。
4. 右侧是双栏文件管理器（Local/Remote）和传输队列。
5. `Local` 组的示例主机会使用 Mock 终端；其他主机会走真实 SSH。

## Validation

```bash
swift test
swift run terminal-stress
```

## App Icon

- Source image: project root `logo.png`
- Generated icon file: `Resources/AppIcon.icns`
- Regenerate after updating logo:

```bash
./scripts/generate_app_icon.sh
```
