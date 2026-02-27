# Design: implement-real-ssh-terminal

## 1. Architecture

### 1.1 Transport abstraction
在 `RemoraCore` 中引入可替换后端：

- `SSHTransportClientProtocol`
- `SSHTransportSessionProtocol`

当前 `SystemSSHClient` 升级为 `OpenSSHProcessClient`，作为默认实现。
后续可新增 `LibSSH2Client`，不改上层 `SessionManager` 与 UI。

### 1.2 Session lifecycle
`SessionManager` 维持 actor 模型，负责：
- `connect(host, pty)`
- `write(data)`
- `resize(pty)`
- `stop()`
- 输出流桥接（`AsyncStream<Data>`）

新增状态流（可选）供 UI 展示连接质量与错误信息。

## 2. OpenSSH backend detail (V1)

### 2.1 Process strategy
- 使用 `/usr/bin/ssh` 启动独立进程。
- 每个会话独立 `Process`，避免会话互相影响。
- 参数策略：
  - `-tt` 强制远端 PTY
  - `-p <port>`
  - `-o ConnectTimeout=<n>`
  - `-o ServerAliveInterval=<n>`
  - `-o ServerAliveCountMax=3`
  - `-o StrictHostKeyChecking=accept-new`（后续可配置）

### 2.2 IO and PTY
- 保持 stdin/stdout/stderr 非阻塞读取。
- stdout/stderr 统一回传到 terminal parser。
- `resize` 通过 `stty cols/rows` 维持首版兼容；后续可升级为本地 pseudo-terminal 驱动以获得更稳定行为。

### 2.3 Error handling
- 进程退出非 0：标准化映射到 `ShellSessionState.failed(reason)`。
- 写入失败：上抛并触发 UI 状态更新。
- 连接失败与认证失败统一错误域，避免 UI 文案碎片化。

## 3. Terminal integration
- `TerminalRuntime` 按 tab/pane 管理独立 runtime 实例。
- `onInput` 仅写入当前激活 session。
- 输出采用“队列 + 主线程 flush”策略，避免 UI 卡顿与闪烁。
- 强制把 `\r\n` / `\r` 正规化，确保换行显示一致。

## 4. Security and credential
- 凭据仅从 Keychain / 用户指定 key path 获取，不落盘明文。
- host key 复用 `HostKeyStore`，并将首次连接确认策略纳入后续 UI。
- 日志做脱敏（host、user 可见；密钥/口令不可见）。

## 5. Testing strategy

### 5.1 Unit tests
- OpenSSH 参数组装测试（端口、认证方式、超时）。
- SessionManager 生命周期测试（start/write/resize/stop）。
- 错误映射测试（exit code、pipe 失败）。

### 5.2 UI automation
- 自动连接 mock/real(可选) 会话。
- 连续输入多条命令并验证回显稳定。
- 验证 Enter 后内容不会消失。
- 验证左右方向键不会越界到 prompt 前缀区域。

### 5.3 Manual acceptance
- 至少 2 台真实 SSH 主机。
- 分别验证：连接、交互、断开、重连、并发切换。

## 6. Migration plan
1. 先重构接口与 `SystemSSHClient`（行为不变）。
2. 增量修复终端输入输出缺陷并补齐测试。
3. 打开真实 SSH 默认入口，保留 mock 模式用于回归。
4. 当 V1 验收后，再评估 `libssh2` PoC 的投入产出比。

## 7. libssh2 adoption gate (future)
只有满足以下条件才启动 `libssh2`：
- OpenSSH 子进程方案在性能或能力上成为明确瓶颈；
- 需要进程内统一管理 SSH + SFTP channel；
- 有资源承担 C 封装、内存安全、长期维护与安全升级。
