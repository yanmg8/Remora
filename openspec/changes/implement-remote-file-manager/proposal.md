# Change Proposal: implement-remote-file-manager

## Why
当前文件管理能力仍是第一版：
- UI 是本地/远端双栏，不符合当前产品目标（只看服务器文件）。
- 传输队列缺少实时进度与批量下载能力。
- 没有内置编辑器、属性编辑、完整右键菜单。
- 缺少与 terminal 工作目录的双向联动。

这部分已经是剩余的最后一块核心能力，若不补齐，会直接影响“SSH + 文件管理”闭环体验。

## Decision Summary
采用“**单栏远端文件管理器 + 传输中心 + 目录联动桥**”方案，基于现有 SwiftUI 架构演进：

1. UI 从双栏改为单栏远端列表（`Table/List + contextMenu + dropDestination`）。
2. 传输能力改为 actor 化 `TransferCenter`，支持并发、批量、实时进度。
3. 扩展 `SFTPClientProtocol`，补足下载/上传进度、属性读写、移动/复制。
4. 新增 `RemoteTextEditor`（文本文件编辑）与 `FilePropertiesSheet`（属性编辑）。
5. 引入 `TerminalDirectorySyncBridge`，实现：
   - File Manager 切目录 -> Terminal 自动 `cd`
   - Terminal 切目录 -> File Manager 自动跟随

## Scope
### In Scope
- 单栏显示远端目录，支持路径跳转、返回上层、刷新。
- 拖拽上传：
  - 拖到空白区上传到当前目录。
  - 拖到目录行上传到该目录。
- 批量下载（多选）与下载进度展示（单任务 + 总体）。
- 内置文本编辑器（打开、编辑、保存、编码与大小限制提示）。
- 右键操作：刷新、删除、重命名、复制、粘贴、下载、移动至、编辑、复制路径、复制名称、属性（可编辑）、上传至当前目录（目录菜单）。
- 与 terminal 工作目录联动。

### Out of Scope
- 二进制文件可视化编辑（仅支持文本编辑）。
- 断点续传与校验（保留到后续增强）。
- 全功能 ACL/extended attributes 编辑（首版聚焦 chmod/chown/timestamp）。

## Success Criteria
- 单栏远端文件浏览与路径导航稳定可用。
- 拖拽上传成功率可稳定复现（目录/当前路径两种投放）。
- 多文件下载可并发执行，UI 可看到进度与状态。
- 文本编辑保存可回写远端文件，错误可提示。
- 右键菜单能力完整，操作后列表状态正确刷新。
- terminal 与 file manager 目录联动在常见 shell（bash/zsh）下稳定可用。
- 自动化覆盖：核心逻辑单测 + UI 自动化关键路径通过。
