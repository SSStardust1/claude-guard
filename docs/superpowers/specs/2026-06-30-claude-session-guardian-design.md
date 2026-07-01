# Claude Session Guardian Design

## Summary

`v0.2.0` adds a runtime session guardian for official Claude Code. The guardian protects the account and session during network drift without turning ordinary coffee-break Wi-Fi wobble into immediate task loss.

The design changes the original kill-oriented watchdog into a safer state machine:

```text
healthy -> degraded -> paused -> resume-pending -> healthy
```

The default action is dry-run observation first. When actions are enabled, the guardian pauses and resumes the Claude session instead of killing it. Automatic kill is not enabled by default.

## Goals

- Keep the `v0.1.0` startup precheck intact.
- Detect runtime exit-IP drift after Claude Code has already started.
- Detect repeated Anthropic API path failure through the configured proxy.
- Pause the whole Claude process group when the session becomes unsafe.
- Resume automatically only after the path is confirmed healthy again.
- Provide clear local feedback through terminal messages, macOS notifications when available, and a local log file.
- Avoid high-frequency probing and avoid sending model requests, auth tokens, prompts, or response content.

## Non-Goals

- Do not make the network more stable.
- Do not auto-restart Claude Code.
- Do not default to killing Claude Code.
- Do not modify Clash, Mihomo, Hiddify, system proxy, or VS Code configuration.
- Do not support Windows in this version.
- Do not guarantee an active streaming API call survives a pause. Pause is a safety brake, not a lossless transport feature.

## User Experience

By default, `claude-guard` remains the entry point.

```bash
claude-guard
```

Startup prechecks run first. If they pass, `claude-guard` launches official Claude Code and a sidecar guardian.

In dry-run mode, the guardian only logs what it would do:

```bash
CLAUDE_GUARD_WATCHDOG_DRY_RUN=1 claude-guard
```

In action mode, the guardian may pause or resume the Claude process group:

```bash
CLAUDE_GUARD_WATCHDOG_DRY_RUN=0 claude-guard
```

When the guardian pauses the session, the user should see a clear message:

```text
Claude Guardian: paused Claude session because exit IP drifted from 203.0.113.10 to 198.51.100.9.
```

When the route recovers, the user should see:

```text
Claude Guardian: route healthy again; resumed Claude session.
```

## Process Model

`claude-guard` should not directly `exec` Claude in `v0.2.0` when runtime guarding is enabled. Instead it launches Claude as a foreground child process in its own process group and keeps a lightweight monitor loop in the parent.

This is necessary because pause and resume must apply to Claude plus its child processes. Claude Code may run shell commands such as `git`, `npm`, `curl`, or test runners. Pausing only the Claude main PID can leave children running and still using the network.

The launcher must preserve terminal behavior as much as possible:

- Claude remains attached to the user's stdin/stdout/stderr.
- Ctrl+C behavior is forwarded to the Claude process group.
- On normal Claude exit, the guardian exits with Claude's exit code.
- On guardian termination, it should attempt to continue a paused Claude group before exiting unless it is intentionally stopping the session.

## State Machine

### States

`healthy`
: The expected exit IP is present and the Anthropic API path is healthy.

`degraded`
: One or more checks failed, but failure counts are below action thresholds.

`paused`
: The Claude process group has been paused or would have been paused in dry-run mode.

`resume-pending`
: The path appears healthy after a pause, but the guardian is waiting for consecutive healthy checks before resuming.

`exited`
: Claude exited normally or was terminated intentionally.

### Events

`ip_ok`
: Current IPv4 exit IP is in `allowed_ips`.

`ip_drift`
: Current IPv4 exit IP is not in `allowed_ips`.

`ip_unknown`
: Current exit IP could not be obtained.

`api_ok`
: `api.anthropic.com` is reachable through the configured proxy using HTTP CONNECT and valid TLS.

`api_fail`
: `api.anthropic.com` path check failed.

`wake_gap`
: The time since the previous guardian tick is greater than the configured wake gap. This usually means system sleep, network roaming, or long process suspension.

`claude_exit`
: Claude process exited.

### Default Thresholds

- IP check interval: `60s`.
- Anthropic API check interval: `180s`.
- Wake gap threshold: `120s`.
- IP drift pause threshold: `2` consecutive bad IP checks.
- API failure pause threshold: `3` consecutive API failures.
- Resume threshold: `2` consecutive fully healthy checks.
- Automatic kill after pause: disabled by default.

### Transition Rules

- `healthy + ip_drift` increments IP failure count. If below threshold, transition to `degraded`; if threshold reached, transition to `paused`.
- `healthy + api_fail` increments API failure count. If below threshold, transition to `degraded`; if threshold reached, transition to `paused`.
- `degraded + ip_ok + api_ok` resets failure counts and transitions to `healthy`.
- `degraded + threshold reached` transitions to `paused`.
- `paused + ip_ok + api_ok` transitions to `resume-pending` and increments healthy count.
- `resume-pending + ip_ok + api_ok` increments healthy count. If resume threshold is reached, resume the process group and transition to `healthy`.
- `resume-pending + any failure` resets healthy count and transitions back to `paused`.
- Any state plus `wake_gap` should immediately move to `resume-pending` if paused or `degraded` if running, forcing fresh validation before normal operation.
- Any state plus `claude_exit` transitions to `exited`.

## Checks

### Exit IP Check

The exit IP check uses the configured proxy and IPv4:

```bash
curl -4 -x "$CLAUDE_GUARD_PROXY" -fsS --connect-timeout 5 --max-time 10 https://ipinfo.io/ip
```

The result is compared against `allowed_ips` from the safe config JSON.

### Anthropic API Path Check

The API path check targets `api.anthropic.com`, not `platform.claude.com`, because Claude Code's main transport depends on the API endpoint. `platform.claude.com` may be useful for manual diagnostics, but it must not be a hard runtime action condition.

The check must verify:

- IPv4 is used.
- The configured proxy is used.
- HTTP CONNECT is established.
- TLS verification succeeds.
- Certificate issuer does not look like Charles, mitmproxy, Fiddler, ZScaler, Clash, Surge, or a generic proxy/MITM.

This can reuse the existing `check_tls_host api.anthropic.com` logic.

## Pause And Resume

The guardian should use process group signals in action mode:

```bash
kill -STOP -- "-$CLAUDE_PGID"
kill -CONT -- "-$CLAUDE_PGID"
```

Using a process group is required so Claude and its child commands pause together.

In dry-run mode, the guardian must not send signals. It logs:

```text
DRY RUN: would pause process group 12345
DRY RUN: would resume process group 12345
```

## Sleep And Wake Handling

macOS sleep can pause both Claude and the guardian. On wake, Claude and the guardian may resume at nearly the same time. The guardian must detect a long tick gap before trusting previous state:

```text
if now - last_tick > wake_gap_seconds:
  treat as wake_gap
```

After `wake_gap`, the guardian should require fresh successful IP and API checks before resuming a paused group or considering the running group healthy.

## Logging And Notifications

Log file:

```text
~/.claude-guard/guard.log
```

Log entries must include timestamp, state, event, action, current IP when known, and reason.

Logs must not include:

- OAuth tokens.
- API keys.
- prompts.
- model responses.
- full Claude settings content.

On macOS, if `osascript` exists, the guardian may send notifications:

```bash
osascript -e 'display notification "..." with title "Claude Guardian"'
```

Notification failures must never stop the guardian.

## Configuration

Add these environment variables:

```bash
CLAUDE_GUARD_WATCHDOG=1
CLAUDE_GUARD_WATCHDOG_DRY_RUN=1
CLAUDE_GUARD_IP_INTERVAL=60
CLAUDE_GUARD_API_INTERVAL=180
CLAUDE_GUARD_WAKE_GAP_SECONDS=120
CLAUDE_GUARD_IP_BAD_THRESHOLD=2
CLAUDE_GUARD_API_BAD_THRESHOLD=3
CLAUDE_GUARD_RESUME_GOOD_THRESHOLD=2
CLAUDE_GUARD_KILL_AFTER_PAUSE_SECONDS=
CLAUDE_GUARD_LOG_FILE=~/.claude-guard/guard.log
```

`CLAUDE_GUARD_WATCHDOG_DRY_RUN` defaults to `1` for `v0.2.0`.

`CLAUDE_GUARD_KILL_AFTER_PAUSE_SECONDS` defaults to empty, meaning never auto-kill.

## Testing Strategy

Keep the default test suite offline and deterministic.

### Unit-Style State Tests

Add a small state-machine test harness that feeds synthetic events and checks actions.

Example scenarios:

- Healthy stays healthy on `ip_ok + api_ok`.
- One IP drift moves to degraded but does not pause.
- Two IP drifts produce pause action.
- Three API failures produce pause action.
- Paused session requires two healthy checks before resume.
- Failure during resume-pending returns to paused.
- Wake gap forces fresh validation.

### Shell Smoke Tests

Extend `./scripts/check.sh` to run:

- `bash -n` on all shell scripts.
- Version output check.
- Existing config validation failure checks.
- State-machine harness.

### Manual Integration Tests

Manual tests are allowed but not part of default CI:

- `CLAUDE_GUARD_WATCHDOG_DRY_RUN=1 claude-guard` with normal network.
- Simulated IP drift by temporarily setting `allowed_ips` to a fake IP.
- Simulated API failure by pointing `CLAUDE_GUARD_PROXY` to a closed local port.
- Action-mode pause/resume using a harmless long-running command instead of real Claude.

## Release Plan

`v0.2.0` should update:

- `VERSION`.
- `CHANGELOG.md`.
- `README.md`.
- `docs/roadmap.md`.
- Add runtime guardian implementation.
- Add deterministic tests.

After tests pass:

```bash
git tag -a v0.2.0 -m "Claude 守护 v0.2.0"
git push origin main v0.2.0
```

## Open Decision Locked For v0.2.0

The default behavior is dry-run. This intentionally avoids surprising process pauses on the first release of runtime guarding. Real pause/resume can be enabled after observing local logs and confirming thresholds are not too aggressive.

## Implementation Note For v0.2.0

The first implementation ships dry-run runtime guarding only. This is safer than pretending single-PID pause is equivalent to process-group pause.

The current launcher keeps Claude Code as the foreground TUI process and starts a sidecar monitor before `exec`. That preserves terminal behavior, but it does not create an isolated Claude process group. Because the safety requirement is to pause Claude plus child commands together, `CLAUDE_GUARD_WATCHDOG_DRY_RUN=0` is rejected in `v0.2.0`.

Real pause/resume requires a process-group or PTY runner that can preserve interactive terminal behavior while giving the guardian a safe group target. That is promoted to the next implementation step.
