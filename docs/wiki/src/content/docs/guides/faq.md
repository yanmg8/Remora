---
title: 常见问题
description: 常见问题解答。
---

## 如何保存密码？

Remora 会将配置与已保存密码写入本机 `~/.config/remora` JSON 文件。首次连接时，应用会询问是否保存密码。

## 支持哪些 SSH 密钥格式？

Remora 支持以下 SSH 密钥格式：

- RSA (2048/4096 位)
- ED25519
- ECDSA (256/384/521 位)

## 如何导入现有 SSH 配置？

Remora 可以从以下来源导入 SSH 配置：

- SSH config 文件 (`~/.ssh/config`)
- Remora JSON / CSV 文件（从其他 Remora 导出）
- WindTerm 配置
- electerm 配置
- Xshell 配置
- PuTTY 配置

## 终端支持哪些功能？

Remora 终端支持：

- ANSI/VT100/VT220 转义序列
- 256 色和真彩色
- xterm 鼠标报告
- 文本选择和复制

## SFTP 传输失败怎么办？

1. 检查网络连接
2. 确认服务器 SFTP 服务正常运行
3. 查看传输日志获取详细错误信息
4. 重试失败的传输任务
