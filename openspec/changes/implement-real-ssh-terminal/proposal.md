# Change Proposal: implement-real-ssh-terminal

## Why
当前 `Terminal` 已具备渲染和基础输入能力，但“真实 SSH 连接与命令执行”仍停留在最小可用层。要进入可验收版本，需要把 SSH 能力从“演示可用”提升到“多主机稳定可用”，并保证后续可扩展到 SFTP、连接策略、重连与安全策略。

## Decision Summary
结论：`libssh2` **可行，但不建议作为当前主线实现**。

建议路线：
1. V1 主线采用 **OpenSSH 子进程后端**（`/usr/bin/ssh`），快速获得成熟兼容性。
2. 在 `RemoraCore` 内抽象统一传输层接口，保证后续可插拔。
3. 将 `libssh2` 放入 V2 作为可选后端（在确有需求时再接入）。

## Why Not libssh2 as V1
- Swift 与 C 绑定成本高：需要大量 unsafe 封装、生命周期与线程模型管理。
- 协议与交互细节复杂：PTY、channel、window resize、agent、known_hosts、异常恢复都要自己补齐。
- 与系统生态兼容性较弱：`~/.ssh/config`、`ProxyJump`、硬件 key、企业环境策略复用度不如 OpenSSH 原生。
- 工程节奏风险高：短期目标是先交付稳定的“多 SSH + 命令执行”，libssh2 会显著拉长实现与验证周期。

## Why OpenSSH Process as V1
- 兼容性强：直接复用 macOS OpenSSH 能力与用户现有 SSH 生态。
- 风险低：认证、密钥、跳板、算法兼容交给 OpenSSH 处理。
- 演进自然：接口抽象后可平滑增加 `libssh2` 后端，不阻塞现在交付。

## Scope
### In Scope
- 多 SSH 会话并发连接（不同 host）。
- 交互式 shell（PTY）与命令执行。
- 基础连接状态管理（connecting/running/failed/stopped）。
- 输入输出稳定性修复（回车换行、光标定位、重绘时序）。
- 关键自动化测试（单测 + UI 自动化）。

### Out of Scope (this change)
- 完整 SFTP 实现替换。
- SSH agent forwarding 全配置 UI。
- `libssh2` 生产级接入。

## Success Criteria
- 可同时打开至少 3 个 SSH 会话并稳定交互。
- 连续输入命令时，不出现内容消失/重绘异常/光标越界。
- `swift test` 稳定通过，UI 自动化覆盖终端关键路径。
- 真实主机手工验收：连接、执行、回显、断开、重连。
