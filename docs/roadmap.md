# Roadmap

## v0.1.0

启动前门禁。

- 出口 IP 白名单。
- 官方 API TLS/CONNECT 检查。
- IPv6 泄漏检查。
- 官方 settings 残留检查。
- 预检模式和基础测试。

## v0.2.0

Claude Session Guardian：运行中 dry-run 安全观察。

- 默认 dry-run，记录本来会 pause/resume 的动作。
- 运行时低频检查出口 IP 和 `api.anthropic.com` 官方路径。
- IP 漂移或 API 连续失败后记录 would-pause。
- 网络恢复且连续验证通过后记录 would-resume。
- 检测 macOS 休眠/唤醒 gap，恢复前强制重新验证网络路径。
- 记录本地日志，不记录 token 和会话内容。
- 拒绝不安全 action mode，避免只暂停 Claude 主 PID。

## v0.3.0

进程组 action runner 和更完整的诊断体验。

- 实现可安全暂停/恢复整个 Claude 进程组的 runner。
- 增加 `doctor` 子命令。
- 输出最近一次启动门禁报告。
- 可选生成脱敏诊断包。
