# Claude 守护

[![check](https://github.com/guiltyluce/claude-guard/actions/workflows/check.yml/badge.svg)](https://github.com/guiltyluce/claude-guard/actions/workflows/check.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Claude 守护是一个给官方 Claude Code CLI 使用的启动前门禁。它把我们本地已经验证过的官方链路检查沉淀成可复用脚本，避免在代理未开启、出口 IP 漂移、TLS 被中间人改写、IPv6 意外泄漏、或官方配置被旧 CC Switch/base URL 污染时启动 Claude Code。

当前版本：`0.2.3`

> 本项目不是 Anthropic 或 Claude Code 官方项目。

## 这个版本做什么

`v0.2.3` 包含启动前门禁、客户端指纹 tripwire、入口收敛脚本和运行中 dry-run guardian。启动 Claude Code 前会检查：

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

## 版本历史

### 0.2.3 - 开源发布整理

`0.2.3` 是首个公开发布版本，重点是把原本面向个人本机环境的项目整理成可以公开阅读、复用和贡献的开源仓库。

主要更新：

- 新增 MIT License，明确项目可以被复制、修改、分发和二次使用。
- 新增 `CONTRIBUTING.md`，说明如何提交 issue、PR、测试变更和处理文档更新。
- 新增 `SECURITY.md`，说明安全问题报告方式，以及本项目不接收 token、凭据、真实账号配置等敏感信息。
- 新增 `CODE_OF_CONDUCT.md`，补齐公开协作的基本行为约束。
- 新增 GitHub Actions workflow，push 和 PR 时自动运行 `./scripts/check.sh`。
- 将 README、示例配置、测试和技术文档中的本机路径、真实出口 IP、个人用户名等内容替换成通用示例。
- 移除脚本里的本机用户名默认值，避免新用户在默认环境里看到个人机器痕迹。

边界说明：

- 这是开源整理版本，不改变 `claude-guard` 的核心启动逻辑。
- 不新增请求转发、TLS 解包、base URL 改写、token 托管或指纹伪装能力。
- 公开仓库使用干净的单提交历史发布，避免把早期本机调试历史带入公共仓库。

验证：

- `./scripts/check.sh`
- GitHub Actions `check`
- fresh clone 后重新运行 smoke test 和敏感痕迹扫描。

### 0.2.2 - 入口收敛

`0.2.2` 解决的是入口一致性问题：避免用户有时从 `claude` 进入、有时从 `claude-official` 进入，导致其中一条路径绕过 guard。

主要更新：

- 新增 `scripts/install-entrypoint-shims.sh`。
- 将 `claude` 与 `claude-official` 两个入口统一收敛到同一个 `claude-guard` wrapper。
- 安装 shim 前自动备份已有入口，默认备份后缀为 `.bak-before-claude-guard-v0.2.2`。
- 保持原始 Claude CLI 路径写在配置文件的 `command` 字段里，避免 wrapper 递归调用自己。
- 新增入口 shim 安装 smoke test，验证 shim 可以正确生成并指向 guard。

设计意图：

- `0.2.2` 只处理“入口从哪里进”的问题。
- 客户端指纹检查仍归属于 `0.2.1`。
- 运行中 guardian 仍归属于 `0.2.0`。
- 这样每个版本的风险边界更清楚，回滚时可以按入口、指纹、watchdog 分层处理。

边界说明：

- 入口 shim 不改变 Claude Code 的请求目标。
- 入口 shim 不写入 `ANTHROPIC_BASE_URL`、不托管 OAuth token，也不替代官方 Claude CLI。

### 0.2.1 - 客户端指纹 Tripwire

`0.2.1` 新增客户端指纹预检，用来在启动前发现高风险客户端环境，而不是在请求已经发出后再补救。

主要更新：

- 新增 date/time watermark tripwire。
- 新增 `CLAUDE_GUARD_FINGERPRINT_MODE`，默认值为 `fail-active`。
- 新增 `CLAUDE_GUARD_LEGACY_PROFILE_MODE=warn`，用于提示旧 `~/.claude/settings.json` 中可能存在的 CC Switch/base URL 残留。
- 新增 active/strict 指纹检测回归测试。

默认判定逻辑：

- 如果当前 Claude Code 包没有已知 date/time watermark 逻辑，直接通过。
- 如果包含已知逻辑，但当前官方启动环境干净，只警告并继续。
- 如果包含已知逻辑，且当前环境存在 `ANTHROPIC_BASE_URL` 或高风险时区等激活条件，则拒绝启动。

可选模式：

- `off`：完全关闭该检查。
- `warn`：只提示风险，不阻断启动。
- `fail-active`：只在 watermark-capable 客户端和激活条件同时存在时阻断。
- `strict`：只要客户端含有已知逻辑就阻断。

边界说明：

- 该版本只做启动前风险判断。
- 不读取、清洗、转发或改写 Claude Code 发出的请求。
- 不尝试伪装 timezone、locale、设备指纹或系统环境。

### 0.2.0 - 运行中 Dry-Run Guardian

`0.2.0` 是从“启动前检查”扩展到“运行中观察”的版本。它关注 coffee time、休眠唤醒、网络波动、出口漂移等启动后才会发生的问题。

主要更新：

- 新增运行中 dry-run guardian。
- 默认每 60 秒低频检查出口 IP。
- 默认每 180 秒低频检查 `api.anthropic.com` 官方路径。
- 新增 sleep/wake gap 检测，识别长时间休眠、断网或系统暂停后的恢复场景。
- 新增本地日志 `~/.claude-guard/guard.log`。
- 新增 dry-run pause/resume 决策记录：记录“如果 action mode 可用，本来会 pause/resume”的状态变化。
- 新增备用 IP 查询源，默认从 `ipinfo.io` fallback 到 `api.ipify.org`。
- 新增 `allowed_cidrs` 支持，适合固定节点偶尔更换末段 IP 的场景。
- 修复 Clash/Mihomo fake-ip `::ffff:198.18.x.x` 被误判为公网 IPv6 泄漏的问题。
- 新增 watchdog 状态机测试。

默认行为：

- guardian 默认只观察和记录，不会暂停、恢复或 kill Claude Code。
- 运行中告警默认只写日志，不向 Claude Code TUI 输出内容。
- 如需终端提示，可设置 `CLAUDE_GUARD_DRY_RUN_STDERR=1`。
- 如需 macOS 通知，可设置 `CLAUDE_GUARD_NOTIFY=1`。

边界说明：

- `0.2.0` 有意拒绝不安全 action mode。
- 如果用户设置 `CLAUDE_GUARD_WATCHDOG_DRY_RUN=0`，当前版本会拒绝启动 action mode，而不是给出虚假的保护。
- 真正 pause/resume 必须由未来的 process-group runner 实现，确保 Claude 主进程和其子进程一起暂停或恢复。

### 0.1.0 - 启动前门禁

`0.1.0` 是初始版本，目标是在 Claude Code 启动前做一组 fail-closed 检查，避免在明显不安全或不符合预期的网络/配置环境里启动官方 Claude Code。

主要更新：

- 新增 `bin/claude-guard`。
- 支持从配置文件读取原始 Claude CLI 绝对路径。
- 支持出口 IP 白名单检查。
- 支持官方 API TLS/CONNECT 检查。
- 支持 IPv6 泄漏检查。
- 支持官方 settings 高风险残留检查。
- 支持 `--precheck-only`，只运行预检，不启动 Claude Code。
- 支持 `--version` 和 `--help`。
- 新增安装脚本、示例配置和 smoke test。

启动前检查覆盖：

- 当前出口 IP 是否在 `allowed_ips` 白名单内。
- `command` 是否是原始 Claude CLI 的绝对路径，避免递归调用 wrapper。
- `api.anthropic.com` 的 TLS 证书是否正常。
- 是否存在中间人证书、异常 issuer 或代理解包迹象。
- 是否存在公网 IPv6 泄漏。
- 官方 profile 的 settings 是否含有 `ANTHROPIC_BASE_URL`、`ANTHROPIC_AUTH_TOKEN`、`apiKeyHelper`、`PROXY_MANAGED` 等高风险残留。

边界说明：

- 初始版本只负责启动前检查。
- 不做运行中监控。
- 不管理 Claude Code 进程生命周期。
- 不替代用户的代理、VPN 或 Clash/Mihomo 配置。

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
