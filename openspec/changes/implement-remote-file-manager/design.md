# Design: implement-remote-file-manager

## 1. Architecture Overview

### 1.1 Component split
在 `RemoraApp` 内拆成四个模块，避免 `FileTransferViewModel` 继续膨胀：

- `RemoteFileManagerViewModel`
  - 目录浏览、选择、多选、右键动作分发、粘贴板状态。
- `TransferCenter`
  - 上传/下载任务队列、并发调度、进度汇总。
- `RemoteTextEditorViewModel`
  - 文本加载、编码检测、脏状态、保存。
- `TerminalDirectorySyncBridge`
  - 维护 file manager 与 terminal 的当前目录一致性。

### 1.2 UI layout (single pane)
使用 SwiftUI 原生组件实现：

- 顶部工具栏：`Back`、`Refresh`、路径输入/面包屑、上传按钮。
- 主区域：远端目录 `Table`（name/size/modified/type）。
- 底部：`Transfer Queue`（任务、方向、速度、进度、状态）。
- 全部通过 `.contextMenu`、`.dropDestination(for: URL.self)` 实现交互。

## 2. Protocol and model changes

### 2.1 SFTP protocol extensions
扩展 `SFTPClientProtocol`（保持向后兼容，新增默认实现或新协议分层）：

- `download(path:progress:) async throws -> Data`
- `upload(fileURL:to:progress:) async throws`
- `stat(path:) async throws -> RemoteFileAttributes`
- `setAttributes(path:attributes:) async throws`
- `move(from:to:) async throws`
- `copy(from:to:) async throws`

新增模型：
- `RemoteFileAttributes`：权限位、owner/group、size、modifiedAt。
- `TransferProgressSnapshot`：bytesTransferred、totalBytes、speedBps、eta。
- `RemoteClipboardItem`：`copy`/`cut` + 源路径集合。

### 2.2 Backward compatibility
- 现有 `MockSFTPClient` 先补齐新增方法的 mock 语义。
- 旧 `FileTransferViewModel` 在迁移完成后删除，避免双模型并行。

## 3. Core interaction flows

### 3.1 Navigation
- 双击目录进入。
- `Back` 回到父目录。
- 路径栏支持手动输入并跳转。
- 切目录后立即触发远端列表刷新，并广播 `currentDirectoryDidChange` 给 `TerminalDirectorySyncBridge`。

### 3.2 Drag-and-drop upload
- 目录列表容器支持 drop：目标为当前目录。
- 每个目录行额外支持 drop：目标为该目录。
- 拖入 `URL` 后生成上传任务：
  - 文件：直接上传。
  - 目录：递归遍历并保持相对路径。
- 同名冲突策略首版弹窗选择：覆盖/跳过/重命名。

### 3.3 Download / multi-download / progress
- 支持多选后批量下载。
- 用户选择本地目标目录后，按远端相对路径写入。
- `TransferCenter` 使用 actor + 有界并发（默认 3）。
- 每个任务都发布 `Progress`，UI 展示：
  - 任务级百分比。
  - 总体聚合百分比（下载面板顶部）。

### 3.4 Context menu actions
统一在 `RemoteFileManagerViewModel.perform(_ action:)` 分发：

- 刷新：`refresh()`
- 删除：`remove(path)`（目录需要二次确认）
- 重命名：`rename(from:to:)`
- 复制/粘贴：更新 `RemoteClipboardItem` 并执行 copy/move
- 下载：单个/批量加入下载队列
- 移动至：弹出路径选择器后 `move(from:to:)`
- 编辑：打开 `RemoteTextEditor`
- 复制路径/复制名称：写入 `NSPasteboard`
- 属性：打开 `FilePropertiesSheet`，保存时 `setAttributes`
- 上传至当前目录（目录菜单）：打开 `NSOpenPanel` 选本地文件后上传到该目录

## 4. Embedded text editor

### 4.1 Open and decode
- 仅允许文本文件（按扩展名 + 内容采样判定）。
- 默认限制 2 MB；超限提示“只读打开”或拒绝编辑。
- UTF-8 优先，失败时尝试常见编码（GB18030/ISO-8859-1）并提示。

### 4.2 Save strategy
- 保存前比对远端 `modifiedAt`，检测并发修改。
- 保存流程：`Text -> Data -> upload(fileURL/data)`。
- 成功后刷新当前目录并更新任务/状态提示。

## 5. Properties editing

`FilePropertiesSheet` 支持首版可编辑项：
- 权限位（八进制，如 `755`）
- owner/group（可编辑时才显示可写）
- modified time

保存动作：
1. 校验输入合法性。
2. 调用 `setAttributes`。
3. 刷新列表并提示结果。

## 6. Terminal directory sync

### 6.1 Sync contract
- `TerminalRuntime` 新增 `@Published var workingDirectory: String?`。
- File manager 切目录时，调用 `runtime.changeDirectory(to:)`（自动发送 `cd`）。
- Terminal 侧通过 shell 输出事件更新 `workingDirectory`，file manager 订阅后自动跳转。

### 6.2 Tracking strategy
优先使用 OSC 7（shell 集成）追踪目录变化；无 OSC 7 时降级为节流 `pwd` 探测。

- 优先：解析 terminal 输出中的 OSC 7 路径事件。
- 降级：在回车执行后 debounce 调用 `pwd`，解析结果更新目录。

这样可同时兼顾准确性与兼容性，避免强依赖某个 shell 提示符格式。

## 7. Testing strategy

### 7.1 Unit tests
- `RemoteFileManagerViewModelTests`
  - 路径跳转、返回上级、剪贴板复制/粘贴状态机。
- `TransferCenterTests`
  - 并发上限、批量下载进度、失败重试与状态转移。
- `RemoteTextEditorViewModelTests`
  - 文本检测、编码处理、冲突检测。
- `TerminalDirectorySyncBridgeTests`
  - file->terminal、terminal->file 双向同步与防循环。

### 7.2 UI automation tests
扩展 `RemoraUIAutomationTests`：
- 文件列表目录跳转 + Back + Refresh。
- 右键菜单关键动作可触发。
- 多文件下载显示进度并结束。
- terminal 切目录后 file manager 自动跟随。

执行命令（必须）：
`REMORA_RUN_UI_TESTS=1 swift test --filter RemoraUIAutomationTests`

## 8. Rollout and migration
1. 引入新 ViewModel 与 `TransferCenter`，先保持旧 UI 可编译。
2. 切换到单栏远端 UI，替换旧双栏面板。
3. 接入右键动作与编辑器。
4. 接入 terminal 目录联动。
5. 删除旧 `FileTransferViewModel` 与无效 UI，补齐测试并收敛。
