#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/bin" "$TMP_DIR/profile" "$TMP_DIR/project/.claude"

cat >"$TMP_DIR/fake-claude" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

self_dir="$(cd "$(dirname "$0")" && pwd)"
if [ "${1:-}" = "--version" ]; then
  printf '2.1.220 (Claude Code)\n'
  exit 0
fi

env | sort >"$self_dir/fake-claude.env"
printf '%s\n' "$@" >"$self_dir/fake-claude.args"
touch "$self_dir/fake-claude.started"
EOF
chmod +x "$TMP_DIR/fake-claude"

cat >"$TMP_DIR/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ "${FAKE_CURL_FAIL:-0}" = "1" ]; then
  exit 7
fi
if printf '%s\n' "$*" | grep -q '/v1/messages'; then
  printf '%s' "${FAKE_CURL_STATUS:-405}"
fi
exit 0
EOF
chmod +x "$TMP_DIR/bin/curl"

cat >"$TMP_DIR/bin/lsof" <<EOF
#!/usr/bin/env bash
set -euo pipefail

if printf '%s\n' "\$*" | grep -q -- '-iTCP:15721'; then
  printf '4242\n'
  exit 0
fi
if printf '%s\n' "\$*" | grep -q -- '-d txt'; then
  printf 'p4242\nn%s\n' "\${FAKE_LISTENER_EXE:-$TMP_DIR/fake-cc-switch}"
  exit 0
fi
exit 1
EOF
chmod +x "$TMP_DIR/bin/lsof"

printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP_DIR/fake-cc-switch"
chmod +x "$TMP_DIR/fake-cc-switch"

cat >"$TMP_DIR/profile/settings.json" <<'EOF'
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://127.0.0.1:15721",
    "ANTHROPIC_AUTH_TOKEN": "PROXY_MANAGED"
  }
}
EOF

if command -v shasum >/dev/null 2>&1; then
  client_sha="$(shasum -a 256 "$TMP_DIR/fake-claude" | awk '{print $1}')"
else
  client_sha="$(sha256sum "$TMP_DIR/fake-claude" | awk '{print $1}')"
fi

cat >"$TMP_DIR/config.json" <<EOF
{
  "command": "$TMP_DIR/fake-claude",
  "config_dir": "$TMP_DIR/profile",
  "expected_base_url": "http://127.0.0.1:15721",
  "client_version": "2.1.220",
  "client_sha256": "$client_sha",
  "require_proxy_managed_token": true,
  "require_no_credentials": true,
  "check_endpoint": true,
  "endpoint_probe_path": "/v1/messages",
  "endpoint_probe_method": "OPTIONS",
  "endpoint_expected_statuses": [405],
  "endpoint_process_path": "$TMP_DIR/fake-cc-switch"
}
EOF

run_cc() {
  PATH="$TMP_DIR/bin:$PATH" \
    CLAUDE_CC_CONFIG="$TMP_DIR/config.json" \
    "$ROOT_DIR/bin/claude-cc" "$@"
}

run_cc --precheck-only >"$TMP_DIR/precheck.out"
grep -q 'CC Switch 通道预检通过' "$TMP_DIR/precheck.out"
if [ -e "$TMP_DIR/fake-claude.started" ]; then
  printf 'precheck unexpectedly started client\n' >&2
  exit 1
fi

ANTHROPIC_BASE_URL="https://unexpected.example" \
ANTHROPIC_AUTH_TOKEN="unexpected-token" \
CLAUDE_CONFIG_DIR="$TMP_DIR/unexpected-profile" \
CLAUDE_CODE_DISABLE_AGENT_VIEW=1 \
CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 \
CLAUDE_CODE_DISABLE_CRON=1 \
CLAUDE_CODE_DISABLE_WORKFLOWS=1 \
run_cc --probe

grep -qx "CLAUDE_CONFIG_DIR=$TMP_DIR/profile" "$TMP_DIR/fake-claude.env"
grep -qx 'DISABLE_UPDATES=1' "$TMP_DIR/fake-claude.env"
grep -qx 'DISABLE_TELEMETRY=1' "$TMP_DIR/fake-claude.env"
grep -qx 'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1' "$TMP_DIR/fake-claude.env"
if grep -Eq '^(ANTHROPIC_BASE_URL|ANTHROPIC_AUTH_TOKEN|CLAUDE_CODE_DISABLE_AGENT_VIEW|CLAUDE_CODE_DISABLE_BACKGROUND_TASKS|CLAUDE_CODE_DISABLE_CRON|CLAUDE_CODE_DISABLE_WORKFLOWS)=' \
  "$TMP_DIR/fake-claude.env"; then
  printf 'official or inherited route/lifecycle state leaked into CC lane\n' >&2
  exit 1
fi
grep -qx -- '--probe' "$TMP_DIR/fake-claude.args"

jq '.client_version = "2.1.170"' "$TMP_DIR/config.json" >"$TMP_DIR/wrong-version.json"
if PATH="$TMP_DIR/bin:$PATH" CLAUDE_CC_CONFIG="$TMP_DIR/wrong-version.json" \
  "$ROOT_DIR/bin/claude-cc" --precheck-only >"$TMP_DIR/wrong-version.out" 2>&1; then
  printf 'wrong version unexpectedly passed\n' >&2
  exit 1
fi
grep -q '客户端版本校验失败' "$TMP_DIR/wrong-version.out"

jq '.client_sha256 = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"' \
  "$TMP_DIR/config.json" >"$TMP_DIR/wrong-sha.json"
if PATH="$TMP_DIR/bin:$PATH" CLAUDE_CC_CONFIG="$TMP_DIR/wrong-sha.json" \
  "$ROOT_DIR/bin/claude-cc" --precheck-only >"$TMP_DIR/wrong-sha.out" 2>&1; then
  printf 'wrong SHA unexpectedly passed\n' >&2
  exit 1
fi
grep -q '客户端 SHA-256 校验失败' "$TMP_DIR/wrong-sha.out"

printf '{"oauthAccount":{"accessToken":"redacted"}}\n' >"$TMP_DIR/profile/.credentials.json"
if run_cc --precheck-only >"$TMP_DIR/credentials.out" 2>&1; then
  printf 'credentials contamination unexpectedly passed\n' >&2
  exit 1
fi
grep -q '凭据污染' "$TMP_DIR/credentials.out"
rm "$TMP_DIR/profile/.credentials.json"

jq '.env.ANTHROPIC_BASE_URL = "https://api.anthropic.com"' \
  "$TMP_DIR/profile/settings.json" >"$TMP_DIR/profile/settings.bad.json"
mv "$TMP_DIR/profile/settings.bad.json" "$TMP_DIR/profile/settings.json"
if run_cc --precheck-only >"$TMP_DIR/route.out" 2>&1; then
  printf 'route mismatch unexpectedly passed\n' >&2
  exit 1
fi
grep -q 'base URL 不匹配' "$TMP_DIR/route.out"
jq '.env.ANTHROPIC_BASE_URL = "http://127.0.0.1:15721"' \
  "$TMP_DIR/profile/settings.json" >"$TMP_DIR/profile/settings.fixed.json"
mv "$TMP_DIR/profile/settings.fixed.json" "$TMP_DIR/profile/settings.json"

printf '{"env":{"ANTHROPIC_BASE_URL":"https://api.anthropic.com"}}\n' \
  >"$TMP_DIR/project/.claude/settings.json"
if (
  cd "$TMP_DIR/project"
  run_cc --precheck-only
) >"$TMP_DIR/project-route.out" 2>&1; then
  printf 'project route override unexpectedly passed\n' >&2
  exit 1
fi
grep -q '项目设置试图改写 CC Switch 路由' "$TMP_DIR/project-route.out"
rm "$TMP_DIR/project/.claude/settings.json"

if run_cc --settings "$TMP_DIR/profile/settings.json" \
  >"$TMP_DIR/cli-settings.out" 2>&1; then
  printf 'CLI settings override unexpectedly passed\n' >&2
  exit 1
fi
grep -q '不允许覆盖 --settings' "$TMP_DIR/cli-settings.out"

if FAKE_CURL_FAIL=1 run_cc --precheck-only \
  >"$TMP_DIR/endpoint.out" 2>&1; then
  printf 'unavailable endpoint unexpectedly passed\n' >&2
  exit 1
fi
grep -q '本机 CC Switch 端点不可达' "$TMP_DIR/endpoint.out"

if FAKE_CURL_STATUS=200 run_cc --precheck-only \
  >"$TMP_DIR/protocol.out" 2>&1; then
  printf 'unexpected endpoint protocol status passed\n' >&2
  exit 1
fi
grep -q '协议探针异常' "$TMP_DIR/protocol.out"

if FAKE_LISTENER_EXE="$TMP_DIR/not-cc-switch" run_cc --precheck-only \
  >"$TMP_DIR/listener.out" 2>&1; then
  printf 'wrong listener identity unexpectedly passed\n' >&2
  exit 1
fi
grep -q '监听进程身份不匹配' "$TMP_DIR/listener.out"

printf 'cc lane policy ok\n'
