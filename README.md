# Claude 守护

[![check](https://github.com/guiltyluce/claude-guard/actions/workflows/check.yml/badge.svg)](https://github.com/guiltyluce/claude-guard/actions/workflows/check.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Claude 守护是一个给官方 Claude Code CLI 使用的启动前门禁。它把我们本地已经验证过的官方链路检查沉淀成可复用脚本，避免在代理未开启、出口 IP 漂移、TLS 被中间人改写、IPv6 意外泄漏、或官方配置被旧 CC Switch/base URL 污染时启动 Claude Code。

当前版本：`0.2.3`

> 本项目不是 Anthropic 或 Claude Code 官方项目。

## 这个版本做什么

`v0.2.0` 包含启动前门禁和运行中 dry-run guardian。启动 Claude Code 前会检查：

- 当前出口 IP 是否在 `allowed_ips` 或 `allowed_cidrs` 白名单中。
- Claude 官方 API 是否通过指定代理的 HTTP CONNECT 隧道访问。
- TLS 证书是否由正常公共 CA 签发，且未出现 Charles、mitmproxy、Fiddler、ZScaler 等中间人痕迹。
- `api.anthropic.com` 是否无法通过公网 IPv6 直连，确保官方链路压在 IPv4；Mihomo/Clash fake-ip 的 `::ffff:198.18.x.x` 不会被误判为公网 IPv6。
- 官方 profile 的 `settings.json` 是否包含 `ANTHROPIC_BASE_URL`、`ANTHROPIC_AUTH_TOKEN`、`apiKeyHelper`、`127.0.0.1:15721`、`PROXY_MANAGED` 等高风险残留。
- 原始 Claude Code 客户端是否含有已知 date/time watermark 逻辑；如同时存在 `ANTHROPIC_BASE_URL` 或高风险时区等激活条件，则拒绝启动。
- 模型参数中是否误写 `fable5` 一类不存在或不安全的别名。

启动后会默认启动 dry-run guardian：

- 每 60 秒低频检查出口 IP。
- 每 180 秒低频检查 `api.anthropic.com` 官方路径。
- 检测长时间 sleep/wake gap。
- 记录“本来会 pause/resume”的动作，默认只写日志，不污染 Claude Code TUI。
- 写入本地日志 `~/.claude-guard/guard.log`。

它不会调用模型，不会使用账号 token，也不会消耗 Claude 额度。

## 不做什么

Claude 守护只做本地启动前检查和 dry-run 观察。它不做：

- TLS 中间人解包。
- Claude 请求转发、清洗或改写。
- `ANTHROPIC_BASE_URL` 改写。
- OAuth token 提取或转交第三方客户端。
- timezone、locale、设备指纹伪装。

请只在符合服务条款和本地法规的场景中使用。

## 安装

```bash
./scripts/install.sh
```

默认安装到：

```bash
~/.local/bin/claude-guard
```

如果要把日常入口也收敛到同一套 guard：

```bash
./scripts/install-entrypoint-shims.sh
```

它会安装或更新：

```bash
~/.local/bin/claude
~/.local/bin/claude-official
```

两个入口都会先进入 `~/.local/bin/claude-guard`。安装前会自动备份旧入口，默认备份后缀为 `.bak-before-claude-guard-v0.2.2`。

`v0.2.2` 只负责入口收敛；`v0.2.1` 负责客户端指纹 tripwire。这样两个风险边界分开，后续回滚也更清楚。

## 配置

复制示例配置：

```bash
cp config/safe-claude.example.json ~/.safe-claude-official.json
```

然后把 `command` 改成原始 Claude CLI 的绝对路径，不能写 `claude`，也不能写当前 wrapper 路径，否则会递归。

示例：

```json
{
  "command": "/usr/local/bin/claude",
  "allowed_ips": ["203.0.113.10"],
  "allowed_cidrs": ["203.0.113.0/24"]
}
```

`203.0.113.0/24` 是文档示例网段。实际使用时请替换成你自己的固定出口 IP 或 CIDR。

## 使用

只做预检，不启动 Claude：

```bash
claude-guard --precheck-only
```

预检通过后启动官方 Claude Code：

```bash
claude-guard
```

传递 Claude 参数：

```bash
claude-guard --model opus
```

## 关键环境变量

```bash
CLAUDE_GUARD_CONFIG=~/.safe-claude-official.json
CLAUDE_GUARD_SETTINGS=~/.claude-official/settings.json
CLAUDE_GUARD_PROXY=http://127.0.0.1:7897
CLAUDE_GUARD_IP_CHECK_URLS="https://ipinfo.io/ip https://api.ipify.org"
CLAUDE_GUARD_ASSUME_YES=1
CLAUDE_GUARD_WATCHDOG=1
CLAUDE_GUARD_WATCHDOG_DRY_RUN=1
CLAUDE_GUARD_DRY_RUN_STDERR=0
CLAUDE_GUARD_NOTIFY=0
CLAUDE_GUARD_FINGERPRINT_MODE=fail-active
CLAUDE_GUARD_LEGACY_PROFILE_MODE=warn
CLAUDE_GUARD_LOG_FILE=~/.claude-guard/guard.log
```

## 客户端指纹 Tripwire

`v0.2.1` 新增客户端指纹预检。它不会转发、修改、清洗或拦截 Claude Code 请求，只做启动前风险判断。

默认模式是：

```bash
CLAUDE_GUARD_FINGERPRINT_MODE=fail-active
```

含义：

- 如果当前 Claude Code 包没有已知 date/time watermark 逻辑，直接通过。
- 如果包含有已知逻辑，但官方启动环境干净，只给警告并继续。
- 如果包含有已知逻辑，且当前环境存在 `ANTHROPIC_BASE_URL` 或 `Asia/Shanghai` / `Asia/Urumqi` 等激活条件，则拒绝启动。

可选模式：

- `off`：关闭该检查。
- `warn`：只警告，不拒绝。
- `fail-active`：默认值，只在激活条件存在时拒绝。
- `strict`：只要客户端含有已知逻辑就拒绝。

`CLAUDE_GUARD_LEGACY_PROFILE_MODE=warn` 会检查 `~/.claude/settings.json` 的旧 CC Switch 残留并提示，但不会阻断官方入口，因为官方入口使用独立的 `~/.claude-official`。

## 当前边界

`v0.2.2` 默认只做 dry-run，不会真的暂停、恢复或 kill 正在运行的 Claude Code。

这是有意为之：当前 launcher 保持 Claude Code 作为前台 TUI 运行，不能安全地只暂停主 PID。真正 action mode 必须暂停整个 Claude 进程组，否则子进程可能继续执行或联网。`v0.2.2` 会在用户设置 `CLAUDE_GUARD_WATCHDOG_DRY_RUN=0` 时拒绝启动 action mode，而不是给出虚假的安全感。

真实 pause/resume 会放到下一版 process-group runner 中实现。

## 验证

```bash
./scripts/check.sh
```

当前测试覆盖：

- shell 语法检查。
- `--version` 输出。
- `--help` 输出。
- 入口 shim 安装路径。
- 缺失配置失败路径。
- `command` 非绝对路径失败路径。
- 客户端指纹 tripwire active/strict 失败路径。
- IP 检查备用源 fallback。
- `allowed_cidrs` 放行路径。
- dry-run guardian 状态机。
