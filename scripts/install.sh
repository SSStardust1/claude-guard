#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="${CLAUDE_GUARD_PREFIX:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"
TARGET="$BIN_DIR/claude-guard"

mkdir -p "$BIN_DIR"
install -m 0755 "$ROOT_DIR/bin/claude-guard" "$TARGET"

printf '已安装: %s\n' "$TARGET"
printf '示例配置: %s\n' "$ROOT_DIR/config/safe-claude.example.json"
printf '如果要替换当前 claude 入口，请先确认 ~/.safe-claude-official.json 的 command 指向原始 Claude CLI 绝对路径。\n'
