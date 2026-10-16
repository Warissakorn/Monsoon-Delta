#!/usr/bin/env bash
# usage: bash tools/test.sh [filter]
GODOT="${GODOT:-godot}"
LOG="$(mktemp)"
if [ -n "$1" ]; then
  "$GODOT" --headless --path . --script res://tests/run_tests.gd -- "--filter=$1" 2>&1 | tee "$LOG"
else
  "$GODOT" --headless --path . --script res://tests/run_tests.gd 2>&1 | tee "$LOG"
fi
CODE=${PIPESTATUS[0]}
if grep -q "SCRIPT ERROR" "$LOG"; then
  echo "FAIL: SCRIPT ERROR detected during tests"
  CODE=1
fi
rm -f "$LOG"
exit $CODE