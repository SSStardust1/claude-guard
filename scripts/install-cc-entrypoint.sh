#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_VERSION="$(tr -d '[:space:]' <"$ROOT_DIR/VERSION")"
PREFIX="${CLAUDE_GUARD_PREFIX:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"
TARGET="$BIN_DIR/claude-cc"
BACKUP_SUFFIX="${CLAUDE_GUARD_BACKUP_SUFFIX:-bak-before-claude-guard-v${PROJECT_VERSION}}"
BACKUP="$TARGET.$BACKUP_SUFFIX"

mkdir -p "$BIN_DIR"

if [ -e "$TARGET" ] && [ ! -e "$BACKUP" ]; then
  cp -p "$TARGET" "$BACKUP"
  printf '已备份: %s\n' "$BACKUP"
fi

install -m 0755 "$ROOT_DIR/bin/claude-cc" "$TARGET"

printf '已安装 CC Switch 入口: %s\n' "$TARGET"
printf '示例配置: %s\n' "$ROOT_DIR/config/safe-claude-cc.example.json"
printf '请确认 ~/.safe-claude-cc.json 固定了独立客户端版本、SHA-256 与本机 CC Switch 端点。\n'
