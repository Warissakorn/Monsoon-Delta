#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
TASK_LOG="$(mktemp)"
trap 'rm -f "$TASK_LOG"' EXIT
# Godot's editor can exit 0 even after reporting a script error. Check its log.
"$GODOT_BIN" --headless --editor --import --path . 2>&1 | tee "$TASK_LOG"
if grep -Eq 'SCRIPT ERROR:|^ERROR:' "$TASK_LOG"; then
  exit 1
fi
"$GODOT_BIN" --headless --path . --script res://tests/run_tests.gd -- "$@" 2>&1 | tee "$TASK_LOG"
if grep -Eq 'SCRIPT ERROR:|^ERROR:' "$TASK_LOG"; then
  exit 1
fi
