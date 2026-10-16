#!/usr/bin/env bash
# .claude/hooks/check_gd.sh — parse-check an edited .gd file; exit 2 sends errors back to Claude
FILE=$(jq -r '.tool_input.file_path // empty')
case "$FILE" in *.gd) ;; *) exit 0 ;; esac
cd "$CLAUDE_PROJECT_DIR" || exit 0
REL="res://${FILE#"$CLAUDE_PROJECT_DIR"/}"
godot --headless --path . --import > /dev/null 2>&1   # refresh class_name cache first
OUT=$(godot --headless --path . --check-only --script "$REL" 2>&1)
CODE=$?
if [ $CODE -ne 0 ] || echo "$OUT" | grep -q "SCRIPT ERROR"; then
  echo "$OUT" >&2
  exit 2
fi
exit 0