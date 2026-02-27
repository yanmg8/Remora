# Tasks: implement-real-ssh-terminal

Status allowed: `todo` | `in_progress` | `done`

## Milestone A - 传输层重构
- [ ] `status: todo` `id: A01` 抽象 `SSHTransportClientProtocol` 与 `SSHTransportSessionProtocol`。
- [ ] `status: todo` `id: A02` 让 `SessionManager` 只依赖抽象接口，不绑定具体实现。
- [ ] `status: todo` `id: A03` 把现有 `SystemSSHClient` 重命名/升级为 `OpenSSHProcessClient`。
- [ ] `status: todo` `id: A04` 补充参数策略（超时、keepalive、host key 策略）。
- [ ] `status: todo` `id: A05` 为参数构建与错误映射添加单元测试。

## Milestone B - 终端交互稳定性
- [ ] `status: todo` `id: B01` 修复 Enter 后输出偶发消失问题（重绘与 flush 时序）。
- [ ] `status: todo` `id: B02` 统一 CR/LF 处理，保证命令输出换行正确。
- [ ] `status: todo` `id: B03` 修复光标与最后字符间距偏差。
- [ ] `status: todo` `id: B04` 限制左右方向键越界到 prompt 前缀区域。
- [ ] `status: todo` `id: B05` 修复异常着色（同一行颜色污染/串色）并补回归测试。

## Milestone C - 多会话与可用性
- [ ] `status: todo` `id: C01` 支持多 host 并发连接并保持隔离。
- [ ] `status: todo` `id: C02` 优化 tab 切换时 session 绑定与焦点恢复。
- [ ] `status: todo` `id: C03` 对连接失败/断开提供明确错误提示与重试动作。
- [ ] `status: todo` `id: C04` 将 mock/real SSH 模式选择固化为可测试入口。

## Milestone D - 自动化测试与验收
- [ ] `status: todo` `id: D01` 扩展 UI 自动化：连续执行 5+ 命令并验证内容稳定。
- [ ] `status: todo` `id: D02` 扩展 UI 自动化：验证方向键、退格、回车行为一致性。
- [ ] `status: todo` `id: D03` 添加集成测试：连接->执行->断开->重连流程。
- [ ] `status: todo` `id: D04` 添加性能断言：输入延迟与帧耗时门限。
- [ ] `status: todo` `id: D05` 真实主机手工验收并记录 checklist。

## Milestone E - 下一阶段准备（可选）
- [ ] `status: todo` `id: E01` 形成 `libssh2` PoC 评估文档（仅评估，不替换主线）。
- [ ] `status: todo` `id: E02` 明确是否进入 `libssh2` 实装的 Go/No-Go 决策。
