# Changelog

更完整的版本目标、设计边界和验证说明见 README 的“版本历史”部分。

## 0.2.4 - 2026-07-26

- 新增生命周期 fail-closed：要求关闭 background agents、background tasks、cron、dynamic workflows、Remote Control、deep-link registration 和自动更新。
- 拒绝 `--bg`、`claude agents`、Remote Control、额外 `--settings` 与 `--setting-sources` 覆盖。
- 新增当前项目 settings 扫描，阻止项目级 base URL、凭据、代理、CA、provider 和 retry watchdog 注入。
- 新增客户端 `client_version`、`client_sha256` 与 macOS `client_macos_team_id` 可选固定校验。
- 新增 `blocked_plugins`，可拒绝已知会派生 detached process 的插件；本机官方 profile 将 `codex@openai-codex` 列入阻止清单。
- 要求 `CLAUDE_CODE_RETRY_WATCHDOG` 不存在，避免无人值守时产生长时间自动重试。
- 限制子代理嵌套深度和并发数，并关闭 MCP 自动后台化。
- 风险设置报告只打印键路径，不再回显可能包含 token 的整行。
- 新增生命周期策略、项目设置污染、CLI 绕过、客户端身份与前台退出 sidecar 清理测试。
- 明确政策边界：不清洗指纹、不改写请求、不规避封禁，也不保证账号状态。

## 0.2.3 - 2026-07-01

- 开源发布整理：新增 MIT License、Contributing、Security Policy 和 GitHub Actions 检查。
- 将 README、示例配置、测试和技术文档中的本机路径 / 真实 IP 改为通用占位。
- 移除脚本里的本机用户名默认值。

## 0.2.2 - 2026-07-01

- 新增 `scripts/install-entrypoint-shims.sh`，把 `claude` 与 `claude-official` 两个入口统一收敛到同一个 `claude-guard`。
- 安装入口 shim 前自动备份旧文件，默认备份后缀为 `.bak-before-claude-guard-v0.2.2`。
- 将“入口收敛”与 `v0.2.1` 的客户端指纹 tripwire 分开发布，避免版本语义混在一起。
- 新增入口 shim 安装 smoke test。

## 0.2.1 - 2026-07-01

- 新增客户端 date/time watermark tripwire。
- 默认 `CLAUDE_GUARD_FINGERPRINT_MODE=fail-active`，只在已知 watermark-capable 客户端与激活条件同时存在时拒绝启动。
- 新增 `CLAUDE_GUARD_LEGACY_PROFILE_MODE=warn`，提示 `~/.claude/settings.json` 的旧 CC Switch/base URL 残留，但不阻断官方隔离入口。
- 新增 active/strict 指纹检测回归测试。

## 0.2.0 - 2026-07-01

- 新增运行中 dry-run guardian。
- 默认低频检查出口 IP 和 `api.anthropic.com` 官方路径。
- 新增 sleep/wake gap 检测。
- 新增本地日志 `~/.claude-guard/guard.log`。
- 新增 dry-run pause/resume 决策记录。
- 新增备用 IP 查询源，默认从 `ipinfo.io` fallback 到 `api.ipify.org`。
- 新增 `allowed_cidrs` 支持，固定节点换末段 IP 时可降低误伤。
- dry-run 运行中告警默认只写日志；需要 TUI 提示时可设置 `CLAUDE_GUARD_DRY_RUN_STDERR=1`。
- macOS 通知默认关闭；需要通知时可设置 `CLAUDE_GUARD_NOTIFY=1`。
- 明确拒绝不安全 action mode，避免只暂停 Claude 主 PID。
- 修复 Clash/Mihomo fake-ip `::ffff:198.18.x.x` 被误判为公网 IPv6 泄漏的问题。
- 新增 watchdog 状态机测试。

## 0.1.0 - 2026-06-28

初始版本。

- 新增 `claude-guard` 启动前门禁。
- 支持出口 IP 白名单检查。
- 支持官方 API TLS/CONNECT 检查。
- 支持 IPv6 泄漏检查。
- 支持官方 settings 高风险残留检查。
- 支持 `--precheck-only`、`--version`、`--help`。
- 新增安装脚本、示例配置、smoke test。
