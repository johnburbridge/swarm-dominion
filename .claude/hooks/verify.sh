#!/bin/bash
# Stop hook: before Claude finishes a turn, if any GDScript changed this session,
# run the same gates CI enforces (gdlint + headless GUT) and block (exit 2) on
# failure so delegated work never ends red.
#
# Tuning: this runs Godot headless and can take ~10-20s. To make it lint-only,
# comment out the "Tests" block below.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$PROJECT_DIR" || exit 0

input=$(cat)

# Loop guard: if this stop was itself triggered by the stop hook, let it finish.
active=$(printf '%s' "$input" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('stop_hook_active',False))" 2>/dev/null)
[ "$active" = "True" ] && exit 0

# Only run when GDScript actually changed (tracked, staged, or untracked).
changed=$( { git diff --name-only -- '*.gd';
             git diff --cached --name-only -- '*.gd';
             git ls-files --others --exclude-standard -- '*.gd'; } 2>/dev/null | sort -u )
[ -z "$changed" ] && exit 0

problems=""

# --- Lint (fast) ---
if command -v gdlint >/dev/null 2>&1; then
  if ! lint_out=$(gdlint scripts/ 2>&1); then
    problems="${problems}
### gdlint failed
${lint_out}
"
  fi
fi

# --- Tests (headless GUT) ---
if command -v godot >/dev/null 2>&1; then
  # Import first so new class_name scripts resolve (mirrors CI).
  godot --headless --import --quit >/dev/null 2>&1 || true
  test_out=$(godot --headless -s addons/gut/gut_cmdln.gd \
      -gdir=res://tests -ginclude_subdirs -gexit 2>&1)
  test_rc=$?
  if [ $test_rc -ne 0 ]; then
    problems="${problems}
### GUT tests failed (exit ${test_rc})
$(printf '%s' "$test_out" | tail -n 40)
"
  fi
fi

if [ -n "$problems" ]; then
  echo "Verification gate failed for changed GDScript — fix before finishing:" >&2
  printf '%s\n' "$problems" >&2
  exit 2
fi

exit 0
