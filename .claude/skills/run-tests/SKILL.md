---
name: run-tests
description: Run the Swarm Dominion GUT test suite headless (optionally a single test file/dir), reporting pass/fail. Use when asked to "run tests", "run the tests", "check tests pass", or to verify GDScript changes before finishing.
---

# Run Tests (GUT, headless)

Runs the project's [GUT](addons/gut) unit tests exactly as CI does, on the canonical Godot (4.7).

## Full suite

```bash
# Import first so new class_name scripts resolve (needed after adding files).
godot --headless --import --quit || true

godot --headless -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests -ginclude_subdirs -gexit
```

Exit code `0` = all passed; non-zero = failures (or a crash). Look for the
`Run Summary` block and `---- All tests passed! ----`.

## A single test file or directory

```bash
# One file
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_biomass_node.gd -gexit

# One directory
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

## Notes

- Tests live in `tests/unit/` and `tests/integration/`; config in `.gutconfig.json`.
- After adding a **new** `.gd` file with a `class_name`, always run the
  `--import` step first or GUT may report "Could not find type".
- Also lint before finishing: `gdlint scripts/` and `gdformat --check scripts/`.
- The project Stop hook (`.claude/hooks/verify.sh`) runs lint + this suite
  automatically when GDScript changed, so a clean finish is already gated.
