# Claude Session Guardian Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `v0.2.0` runtime guarding for official Claude Code with dry-run-first pause/resume behavior.

**Architecture:** Keep `bin/claude-guard` as the user-facing launcher and startup precheck. Add a deterministic state reducer test harness so runtime decisions can be tested without real Claude or network. Implement runtime monitoring inside `claude-guard` using low-frequency IP/API checks, process-group pause/resume actions in non-dry-run mode, and local logging.

**Tech Stack:** Bash, curl, jq, POSIX process signals, macOS-compatible shell tests.

---

### Task 1: State Machine Harness

**Files:**
- Create: `tests/watchdog_state_machine.sh`
- Modify: `scripts/check.sh`

- [ ] **Step 1: Add deterministic event tests**

Create `tests/watchdog_state_machine.sh` with a pure shell reducer that mirrors the guardian state rules from `docs/superpowers/specs/2026-06-30-claude-session-guardian-design.md`.

The test scenarios must cover:

- one IP drift only degrades.
- two IP drifts pause.
- three API failures pause.
- two healthy checks after pause resume.
- a failure during resume-pending returns to paused.
- wake gap from healthy degrades.

- [ ] **Step 2: Wire the harness into checks**

Update `scripts/check.sh` to run `tests/watchdog_state_machine.sh` after `tests/smoke.sh`.

- [ ] **Step 3: Run the harness**

Run:

```bash
./scripts/check.sh
```

Expected:

```text
smoke ok
watchdog state machine ok
```

### Task 2: Runtime Guardian Implementation

**Files:**
- Modify: `bin/claude-guard`

- [ ] **Step 1: Add v0.2.0 config defaults**

Update the script version to `0.2.0` and add these variables:

```bash
WATCHDOG_ENABLED="${CLAUDE_GUARD_WATCHDOG:-1}"
WATCHDOG_DRY_RUN="${CLAUDE_GUARD_WATCHDOG_DRY_RUN:-1}"
IP_INTERVAL="${CLAUDE_GUARD_IP_INTERVAL:-60}"
API_INTERVAL="${CLAUDE_GUARD_API_INTERVAL:-180}"
WAKE_GAP_SECONDS="${CLAUDE_GUARD_WAKE_GAP_SECONDS:-120}"
IP_BAD_THRESHOLD="${CLAUDE_GUARD_IP_BAD_THRESHOLD:-2}"
API_BAD_THRESHOLD="${CLAUDE_GUARD_API_BAD_THRESHOLD:-3}"
RESUME_GOOD_THRESHOLD="${CLAUDE_GUARD_RESUME_GOOD_THRESHOLD:-2}"
KILL_AFTER_PAUSE_SECONDS="${CLAUDE_GUARD_KILL_AFTER_PAUSE_SECONDS:-}"
LOG_FILE="${CLAUDE_GUARD_LOG_FILE:-$HOME/.claude-guard/guard.log}"
```

- [ ] **Step 2: Add logging and notification helpers**

Add helper functions:

- `log_guard level message`
- `notify_guard message`
- `pause_group pgid reason`
- `resume_group pgid reason`

The helpers must not print token, prompt, or response content.

- [ ] **Step 3: Add single-check helpers for runtime**

Add helpers:

- `get_current_ip_once`
- `is_allowed_ip ip`
- `check_api_path_once`

They should reuse existing proxy/TLS behavior but return status instead of exiting the whole script.

- [ ] **Step 4: Add watchdog loop**

Add `run_watchdog claude_pid claude_pgid` that:

- tracks `state`, `ip_bad_count`, `api_bad_count`, `resume_good_count`, `last_tick`, `last_api_check`, and `paused_since`.
- checks IP every loop.
- checks API only when due.
- detects wake gap.
- pauses only in non-dry-run mode.
- resumes only after enough healthy checks.
- never kills by default.
- exits when Claude process exits.

- [ ] **Step 5: Launch Claude with process-group guard**

Replace the final `exec env -i ... "$CLAUDE_BIN"` block with:

- direct `exec` when `CLAUDE_GUARD_WATCHDOG=0`.
- guarded launch when watchdog is enabled.

The guarded launch should start Claude in a separate process group when `setsid` is available, start the watchdog, wait for Claude, then stop the watchdog and exit with Claude's exit code.

### Task 3: Docs And Version

**Files:**
- Modify: `VERSION`
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/roadmap.md`

- [ ] **Step 1: Update version**

Set `VERSION` to:

```text
0.2.0
```

- [ ] **Step 2: Update README**

Document:

- dry-run default.
- how to disable watchdog.
- how to enable action mode.
- log path.
- limitations of pause/resume.

- [ ] **Step 3: Update changelog and roadmap**

Add `0.2.0 - 2026-07-01` to `CHANGELOG.md`.

Mark `v0.2.0` roadmap as implemented and move future improvements to `v0.3.0`.

### Task 4: Verification And Publish

**Files:**
- No additional source files.

- [ ] **Step 1: Run project checks**

Run:

```bash
./scripts/check.sh
```

Expected:

```text
smoke ok
watchdog state machine ok
```

- [ ] **Step 2: Run version check**

Run:

```bash
bin/claude-guard --version
```

Expected:

```text
claude-guard 0.2.0
```

- [ ] **Step 3: Commit and push**

Commit:

```bash
git add .
git commit -m "feat: add claude session guardian v0.2.0"
git push -u origin codex/claude-session-guardian-v0.2.0
```

Do not tag `v0.2.0` until the branch is reviewed or merged.
