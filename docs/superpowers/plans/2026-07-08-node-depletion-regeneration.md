# Biomass Node Depletion + Regeneration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make biomass nodes regenerate after being left alone (delay-since-last-harvest model) and visually shrink/dim as they deplete and grow back as they regrow.

**Architecture:** All changes are confined to `scripts/resources/biomass_node.gd` and its test file. Regeneration runs as a deterministic `_physics_process` accumulator gated by a per-node "time since last harvest" timer; a full node disables its own physics processing until the next extraction re-enables it. Depletion is already implemented (SPI-1385); this plan adds regeneration and the visual feedback for both.

**Tech Stack:** Godot 4.7 (stable), GDScript, GUT 9.5.0, gdtoolkit (gdformat/gdlint).

## Global Constraints

- Godot 4.7.stable; GDScript with type hints on params and returns.
- Naming: `UPPER_SNAKE_CASE` constants, `snake_case` vars, leading `_` for private.
- gdlint: regular `var` declarations must precede `@onready var` (class-definitions-order).
- Run `gdformat` and `gdlint` on every changed `.gd` file before committing; both must be clean.
- New `class_name`/const changes need `godot --headless --import` before types resolve.
- `.gutconfig.json` sets `dirs`, so `-gtest=` is ignored — run the whole suite:
  `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.
- GUT silently skips a parse-errored test file and still prints "All tests passed" — after adding tests, grep the output for the test names and confirm the total test count rose.
- Conventional commits; footer `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- Baseline before this plan: **183 tests passing** (`test_biomass_node.gd` currently has 14 tests).

---

### Task 1: Biomass regeneration (delay-since-last-harvest)

**Files:**
- Modify: `scripts/resources/biomass_node.gd`
- Test: `tests/unit/test_biomass_node.gd`

**Interfaces:**
- Consumes: existing `BiomassNode` API — `max_biomass: int` (100), `current_biomass: int`, `regen_rate: float` (2.0), `regen_delay: float` (10.0), `harvest(amount: int) -> int`, `is_depleted() -> bool`, `signal biomass_changed(current, maximum)`, `signal biomass_depleted`.
- Produces: `signal fully_regenerated` (no args); regeneration behavior driven by `_physics_process`. Later tasks and consumers may connect to `fully_regenerated`.

**Behavior contract (from spec):**
- A full node does not process physics (`_ready` calls `set_physics_process(false)` after seeding `current_biomass`).
- A **successful** `harvest()` (extracted > 0) resets `_time_since_harvest = 0.0` and `_regen_progress = 0.0`, calls `set_physics_process(true)`, and `queue_redraw()`. A no-op harvest (amount ≤ 0 or depleted) changes nothing.
- `_physics_process(delta)`: if `current_biomass >= max_biomass` return; else `_time_since_harvest += delta`; if `< regen_delay` return; else accrue `_regen_progress += regen_rate * delta`, add the whole part to `current_biomass` (clamped to max), and on any increase emit `biomass_changed` + `queue_redraw()`; on reaching max, emit `fully_regenerated` and `set_physics_process(false)`.

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_biomass_node.gd`:

```gdscript
# --- Regeneration (SPI-1388) ---


func test_no_regen_before_delay_elapses() -> void:
	var node := _create_node()
	await get_tree().process_frame
	node.regen_delay = 0.2
	node.regen_rate = 1000.0
	node.harvest(60)  # current 40, resets regen countdown, enables processing
	for _i in range(5):  # ~0.083s elapsed, still < 0.2s delay
		await get_tree().physics_frame
	assert_eq(node.current_biomass, 40, "should not regrow before regen_delay elapses")


func test_regen_after_delay() -> void:
	var node := _create_node()
	await get_tree().process_frame
	node.regen_delay = 0.2
	node.regen_rate = 1000.0
	node.harvest(60)  # current 40
	for _i in range(40):  # ~0.67s elapsed, well past 0.2s delay
		await get_tree().physics_frame
	assert_gt(node.current_biomass, 40, "should regrow after regen_delay elapses")


func test_regen_caps_at_max() -> void:
	var node := _create_node()
	await get_tree().process_frame
	node.regen_delay = 0.2
	node.regen_rate = 100000.0
	node.harvest(90)  # current 10
	for _i in range(60):
		await get_tree().physics_frame
	assert_eq(node.current_biomass, node.max_biomass, "regrowth should cap at max_biomass")


func test_partial_node_recovers() -> void:
	var node := _create_node()
	await get_tree().process_frame
	node.regen_delay = 0.2
	node.regen_rate = 1000.0
	node.harvest(50)  # current 50 (partial, never emptied)
	for _i in range(40):
		await get_tree().physics_frame
	assert_gt(node.current_biomass, 50, "a partially-drained node should recover")


func test_harvest_resets_regen_countdown() -> void:
	var node := _create_node()
	await get_tree().process_frame
	node.regen_delay = 0.3
	node.regen_rate = 1000.0
	node.harvest(60)  # current 40, t=0
	for _i in range(10):  # ~0.167s, still < 0.3s
		await get_tree().physics_frame
	node.harvest(5)  # current 35, resets t back to 0
	var after_second_harvest := node.current_biomass
	for _i in range(10):  # another ~0.167s; total since 2nd harvest < 0.3s
		await get_tree().physics_frame
	assert_eq(
		node.current_biomass,
		after_second_harvest,
		"a fresh harvest should reset the regen countdown (no premature regrowth)",
	)


func test_regen_emits_fully_regenerated_at_max() -> void:
	var node := _create_node()
	await get_tree().process_frame
	node.regen_delay = 0.2
	node.regen_rate = 100000.0
	node.harvest(50)  # current 50
	watch_signals(node)
	for _i in range(60):
		await get_tree().physics_frame
	assert_eq(node.current_biomass, node.max_biomass, "precondition: node back to max")
	assert_signal_emitted(node, "fully_regenerated")


func test_regen_emits_biomass_changed() -> void:
	var node := _create_node()
	await get_tree().process_frame
	node.regen_delay = 0.2
	node.regen_rate = 1000.0
	node.harvest(60)  # current 40
	watch_signals(node)
	for _i in range(40):
		await get_tree().physics_frame
	assert_signal_emitted(node, "biomass_changed")


func test_depleted_node_regenerates_and_is_harvestable_again() -> void:
	var node := _create_node()
	await get_tree().process_frame
	node.regen_delay = 0.2
	node.regen_rate = 1000.0
	node.harvest(100)  # fully depleted
	assert_true(node.is_depleted(), "precondition: node depleted")
	for _i in range(40):
		await get_tree().physics_frame
	assert_false(node.is_depleted(), "regrown node should no longer be depleted (AC5)")
```

- [ ] **Step 2: Run tests to verify they fail for the right reason**

Run:
```bash
cd /Users/jburbridge/Projects/swarm-dominion && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -40
```
Expected: the 8 new tests FAIL (nodes never regrow because `_physics_process` doesn't exist / `fully_regenerated` signal missing → `watch_signals`/`assert_signal_emitted` fails on an undeclared signal). Confirm the total test count rose from 183 to 191 (grep for `test_regen_after_delay` etc. to confirm collection — not a silent skip). The baseline 183 must still pass.

- [ ] **Step 3: Implement regeneration**

Edit `scripts/resources/biomass_node.gd`. Add the signal after the existing signals:

```gdscript
signal fully_regenerated
```

Add the private accumulators after `var current_biomass: int = 0`:

```gdscript
var _time_since_harvest: float = 0.0
var _regen_progress: float = 0.0
```

In `_ready()`, after `current_biomass = max_biomass` and the collision setup, disable processing on a full node:

```gdscript
	set_physics_process(false)
```

In `harvest(amount)`, inside the successful-extract path (after `current_biomass -= extracted` and the emits), add the regen reset + redraw. The method becomes:

```gdscript
func harvest(amount: int) -> int:
	var extracted: int = min(amount, current_biomass)
	if extracted <= 0:
		return 0
	current_biomass -= extracted
	_time_since_harvest = 0.0
	_regen_progress = 0.0
	set_physics_process(true)
	biomass_changed.emit(current_biomass, max_biomass)
	queue_redraw()
	if current_biomass <= 0:
		biomass_depleted.emit()
	return extracted
```

Add the regeneration loop:

```gdscript
func _physics_process(delta: float) -> void:
	if current_biomass >= max_biomass:
		return
	_time_since_harvest += delta
	if _time_since_harvest < regen_delay:
		return
	_regen_progress += regen_rate * delta
	var whole := int(_regen_progress)
	if whole <= 0:
		return
	_regen_progress -= float(whole)
	var before := current_biomass
	current_biomass = min(current_biomass + whole, max_biomass)
	if current_biomass == before:
		return
	biomass_changed.emit(current_biomass, max_biomass)
	queue_redraw()
	if current_biomass >= max_biomass:
		_regen_progress = 0.0
		fully_regenerated.emit()
		set_physics_process(false)
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd /Users/jburbridge/Projects/swarm-dominion && godot --headless --import 2>&1 | tail -3 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | grep -E "^(Scripts|Tests|Passing|Failing)"
```
Expected: **Tests 191, Passing 191, Failing 0**. The prior 183 (including the SPI-1382/1385 node tests) stay green — full nodes disable processing, and the default 10s `regen_delay` keeps regrowth clear of the existing synchronous harvest tests.

- [ ] **Step 5: Refactor + format/lint**

Review for clarity (no behavior change). Then:
```bash
cd /Users/jburbridge/Projects/swarm-dominion && gdformat scripts/resources/biomass_node.gd tests/unit/test_biomass_node.gd && gdlint scripts/resources/biomass_node.gd tests/unit/test_biomass_node.gd
```
Expected: both clean. Re-run the suite; still 191 passing.

- [ ] **Step 6: Commit**

```bash
cd /Users/jburbridge/Projects/swarm-dominion && git add scripts/resources/biomass_node.gd tests/unit/test_biomass_node.gd && git commit -m "feat: regenerate biomass nodes after a harvest lull (SPI-1388)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Depletion + regeneration visuals

**Files:**
- Modify: `scripts/resources/biomass_node.gd`
- Test: `tests/unit/test_biomass_node.gd`

**Interfaces:**
- Consumes: `current_biomass`, `max_biomass` from Task 1's node.
- Produces: `const MAX_DRAW_RADIUS: float = 20.0`, `const MIN_DRAW_RADIUS: float = 6.0`, `const MIN_DRAW_ALPHA: float = 0.4`, and a pure helper `display_radius_for_ratio(ratio: float) -> float`. `_draw()` scales the node's circles by this radius and dims their alpha as the node empties.

**Note on testing:** `_draw()` rendering is not unit-testable headless, so tests target the pure `display_radius_for_ratio` mapping (mirrors `HealthBar._get_color_for_ratio`). Task 1 already calls `queue_redraw()` on every biomass change, so once `_draw` scales, both depletion (AC3) and regrowth (AC6) redraw automatically.

- [ ] **Step 1: Write the failing tests**

Append to `tests/unit/test_biomass_node.gd`:

```gdscript
# --- Visual feedback (SPI-1388) ---
# Expected constants (asserted as literals so RED fails cleanly at the missing
# method rather than a parse error on a not-yet-existing const):
#   MAX_DRAW_RADIUS = 20.0, MIN_DRAW_RADIUS = 6.0


func test_display_radius_full_is_max() -> void:
	var node := _create_node()
	await get_tree().process_frame
	assert_eq(node.display_radius_for_ratio(1.0), 20.0, "full node draws at max radius")


func test_display_radius_empty_is_husk_floor() -> void:
	var node := _create_node()
	await get_tree().process_frame
	assert_eq(node.display_radius_for_ratio(0.0), 6.0, "empty node draws at the husk floor")
	assert_gt(node.display_radius_for_ratio(0.0), 0.0, "husk floor must be > 0 (stays visible)")


func test_display_radius_is_monotonic() -> void:
	var node := _create_node()
	await get_tree().process_frame
	var r_low := node.display_radius_for_ratio(0.25)
	var r_high := node.display_radius_for_ratio(0.75)
	assert_gt(r_high, r_low, "radius should grow with the biomass ratio")
	var r_mid := node.display_radius_for_ratio(0.5)
	assert_gt(r_mid, 6.0, "mid radius above the floor")
	assert_lt(r_mid, 20.0, "mid radius below the max")


func test_display_radius_clamps_out_of_range() -> void:
	var node := _create_node()
	await get_tree().process_frame
	assert_eq(node.display_radius_for_ratio(2.0), 20.0, "ratio > 1 clamps to max radius")
	assert_eq(node.display_radius_for_ratio(-1.0), 6.0, "ratio < 0 clamps to the floor")
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
cd /Users/jburbridge/Projects/swarm-dominion && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -30
```
Expected: the 4 new tests FAIL with `Invalid call. Nonexistent function 'display_radius_for_ratio'`. Confirm total rose 191 → 195 (grep for `test_display_radius_full_is_max`). Baseline stays green.

- [ ] **Step 3: Implement the visual helper + `_draw`**

Edit `scripts/resources/biomass_node.gd`. Add the constants near the top (after the exports, before `var current_biomass`, keeping `var` before any `@onready`):

```gdscript
const MAX_DRAW_RADIUS: float = 20.0
const MIN_DRAW_RADIUS: float = 6.0
const MIN_DRAW_ALPHA: float = 0.4
```

Add the pure helper:

```gdscript
func display_radius_for_ratio(ratio: float) -> float:
	return lerpf(MIN_DRAW_RADIUS, MAX_DRAW_RADIUS, clampf(ratio, 0.0, 1.0))
```

Replace the existing fixed-radius `_draw()`:

```gdscript
func _draw() -> void:
	draw_circle(Vector2.ZERO, 20.0, Color(0.4, 0.9, 0.3, 0.8))
	draw_circle(Vector2.ZERO, 14.0, Color(0.3, 1.0, 0.2, 0.6))
```

with a ratio-scaled version (outer circle at the display radius, inner at 70% of it, alpha dimmed as the node empties):

```gdscript
func _draw() -> void:
	var ratio: float = 0.0
	if max_biomass > 0:
		ratio = clampf(float(current_biomass) / float(max_biomass), 0.0, 1.0)
	var radius := display_radius_for_ratio(ratio)
	var dim := lerpf(MIN_DRAW_ALPHA, 1.0, ratio)
	draw_circle(Vector2.ZERO, radius, Color(0.4, 0.9, 0.3, 0.8 * dim))
	draw_circle(Vector2.ZERO, radius * 0.7, Color(0.3, 1.0, 0.2, 0.6 * dim))
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd /Users/jburbridge/Projects/swarm-dominion && godot --headless --import 2>&1 | tail -3 && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | grep -E "^(Scripts|Tests|Passing|Failing)"
```
Expected: **Tests 195, Passing 195, Failing 0**.

- [ ] **Step 5: Refactor + format/lint**

```bash
cd /Users/jburbridge/Projects/swarm-dominion && gdformat scripts/resources/biomass_node.gd tests/unit/test_biomass_node.gd && gdlint scripts/resources/biomass_node.gd tests/unit/test_biomass_node.gd
```
Expected: both clean. Re-run the suite; still 195 passing.

- [ ] **Step 6: Commit**

```bash
cd /Users/jburbridge/Projects/swarm-dominion && git add scripts/resources/biomass_node.gd tests/unit/test_biomass_node.gd && git commit -m "feat: scale biomass node visuals with remaining biomass (SPI-1388)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Notes for the implementer

- **Live-test after both tasks (optional but recommended):** run the game
  (`godot --path . scenes/main/main.tscn`), harvest a node to empty, watch it
  shrink/dim, stop harvesting, and confirm it grows back after ~10s (default
  `regen_delay`). To make the manual test quick, you can temporarily lower
  `regen_delay` in `main.gd._spawn_biomass_nodes()` — but revert before commit.
- **Do not** change `harvest_radius` or the `HarvestArea`/collision — the gameplay
  harvest range is intentionally independent of the drawn radius.
- **CHANGELOG:** after both tasks land, add a one-line M3 entry under
  `[Unreleased] / Added` for node depletion + regeneration (SPI-1388).
