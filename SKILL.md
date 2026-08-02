---
name: claude-guard
description: Claude Code 双通道版本治理与启动门禁。当用户需要锁定可审计的 Claude Code 稳定版本、防止自动更新引入回归、区分"客户端变化"与"网络/服务端变化"、或想在保留官方通道严格性的同时用独立通道跟进新版工程能力时使用。提供版本验包（SHA-256+签章）、出口与 TLS 检查、双通道 profile 隔离与回退基线。
---

# claude-guard — 给 Claude Code 上个门禁 🚦

## 一句话

CLI 自动更新一时爽，回归翻车火葬场。
claude-guard 让你的 Claude Code **官方通道锁版本、可审计、fail-closed**，
同时开一条独立通道追新——两条通道 profile 隔离、互不污染。

## 双通道架构（v2.0）

| 入口 | 干什么 | 策略 |
| --- | --- | --- |
| `claude` / `claude-official` | 官方 Claude 模型 | 固定验包版本 + 前台 fail-closed，出口 IP / HTTP CONNECT / TLS issuer / IPv6 全检 |
| `claude-cc` | 本机 CC Switch 兼容链路 | 独立 profile 独立追新，保留 background agent / plugin / hook 工程能力 |

硬边界：

- 官方通道**不读取** CC Switch 的 base URL 或 token；CC 通道**不加载**官方 profile 或文件凭据
- 两条通道都关闭客户端自动更新——任何版本切换必须先过：版本验证 → SHA-256 → macOS 签章 → 回归测试，才改固定指针
- CC 通道关闭 telemetry / OTel exporter / 非必要网络流量，但不阉割核心推理、工具、agent 能力
- 客户端切换不打断运行中的旧进程，下次执行 `claude` 才生效

## 为什么要保留历史基线

新版本出现 TUI / TLS / session resume / 插件 / gateway 回归时，
一份**可复现的历史基线**能帮你一刀切开"客户端变了"还是"网络变了"——
这是排障时最值钱的对照组。二进制不入 Git，本机保存原始包 + SHA-256 + 签章信息。

## 怎么用

1. `scripts/install.sh` 安装入口，`bin/claude-guard` / `bin/claude-cc` 两个入口各管一条通道
2. `scripts/check.sh` 做启动前检查（出口、TLS、进程身份、profile 路由）
3. 升级流程见 `docs/`：验包 → 签章 → 回归 → 改指针，一步不能少

## 边界声明

非 Anthropic 官方项目。不修改 Claude Code 本体，只做版本治理与启动检查。

## 项目

MIT · https://github.com/wetlink/claude-guard
