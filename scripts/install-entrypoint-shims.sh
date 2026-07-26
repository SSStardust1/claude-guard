#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_VERSION="$(tr -d '[:space:]' <"$ROOT_DIR/VERSION")"
PREFIX="${CLAUDE_GUARD_PREFIX:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"
GUARD_TARGET="$BIN_DIR/claude-guard"
BACKUP_SUFFIX="${CLAUDE_GUARD_BACKUP_SUFFIX:-bak-before-claude-guard-v${PROJECT_VERSION}}"

install_shim() {
  local name="$1"
  local target="$BIN_DIR/$name"
  local backup="$target.$BACKUP_SUFFIX"
  local tmp

  if [ -e "$target" ] && [ ! -e "$backup" ]; then
    cp -p "$target" "$backup"
    printf '已备份: %s\n' "$backup"
  fi

  tmp="$(mktemp)"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'set -euo pipefail\n'
    printf '\n'
    printf 'exec "%s" "$@"\n' "$GUARD_TARGET"
  } > "$tmp"

  install -m 0755 "$tmp" "$target"
  rm -f "$tmp"
  printf '已安装入口: %s -> %s\n' "$target" "$GUARD_TARGET"
}

mkdir -p "$BIN_DIR"
install -m 0755 "$ROOT_DIR/bin/claude-guard" "$GUARD_TARGET"
printf '已安装 guard: %s\n' "$GUARD_TARGET"

install_shim claude
install_shim claude-official

printf '入口已收敛：claude 与 claude-official 都会先进入 claude-guard。\n'
printf '请确认 ~/.safe-claude-official.json 的 command 仍指向原始 Claude CLI 绝对路径，而不是上述 shim。\n'
