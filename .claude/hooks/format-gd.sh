#!/bin/bash
# PostToolUse hook: auto-format a GDScript file right after Claude edits it.
# Receives the tool-call JSON on stdin; formats only .gd files that exist.
# Always exits 0 (advisory) so a formatting hiccup never blocks the edit.

input=$(cat)
file=$(printf '%s' "$input" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null)

case "$file" in
  *.gd) : ;;   # continue
  *) exit 0 ;;
esac

[ -f "$file" ] || exit 0
command -v gdformat >/dev/null 2>&1 || exit 0

gdformat "$file" >/dev/null 2>&1
exit 0
