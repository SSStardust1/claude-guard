# 启动前守护设计

`v0.1.0` 的目标是把官方 Claude Code 启动前的关键风险收敛到一个脚本里。它不改变现有 CC Switch/GPT 工作流，也不接管其他 AI 应用的代理配置。

## 入口

用户执行：

```bash
claude-guard [claude args...]
```

脚本读取安全配置：

```json
{
  "command": "/absolute/path/to/original/claude",
  "allowed_ips": ["203.0.113.10"],
  "allowed_cidrs": ["203.0.113.0/24"]
}
```

`command` 必须是原始 Claude CLI 的绝对路径，避免递归调用 wrapper。

## 检查顺序

1. 检查依赖：`curl`、`jq`。
2. 检查安全配置存在且 `command` 合法。
3. 检查官方 settings 文件存在。
4. 检查官方 settings 不含反代/base URL/托管 token 残留。
5. 检查默认 `~/.claude` 是否存在旧 CC Switch 残留，默认只警告。
6. 检查原始 Claude Code 客户端是否含有已知 date/time watermark 逻辑，并判断是否存在激活条件。
7. 检查模型参数没有误写已知危险别名。
8. 通过指定代理和备用 IP 源获取当前 IPv4 出口。
9. 检查 `api.anthropic.com` TLS 和 HTTP CONNECT。
10. 以 warn 模式检查 `platform.claude.com`。
11. 检查 `api.anthropic.com` IPv6 不可达。
12. 如果当前 IP 在 `allowed_ips` 或 `allowed_cidrs` 白名单中，允许启动 Claude。

## Fail closed

以下情况直接拒绝启动：

- 缺少配置。
- `command` 不是绝对路径。
- 官方 settings 包含 `ANTHROPIC_BASE_URL`、`apiKeyHelper`、`PROXY_MANAGED` 等残留。
- watermark-capable 客户端与 `ANTHROPIC_BASE_URL` 或高风险时区等激活条件同时存在。
- `api.anthropic.com` TLS/CONNECT 检查失败。
- IPv6 可直连 `api.anthropic.com`。
- 当前出口 IP 不在白名单，且用户未手动输入 `unsafe`。

## 非目标

- 不在运行中持续监控网络。
- 不自动重启 Claude。
- 不修改 Clash/Mihomo 配置。
- 不读取或打印 Claude token。
